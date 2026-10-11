import Foundation
import CryptoKit

struct PendingDraft: Codable, Sendable, Identifiable {
    let id: String
    var payload: ProjectDraft
    let createdAt: Date
    var attempts: Int
    var error: String?
    var safeToEdit: Bool?
}
private struct DurableMutation: Codable, Sendable { let id: String; let fingerprint: String }
private struct SavedIdentity: Codable, Sendable { let user: User; let tokenDigest: String }
actor ProjectRepository {
    private let api: APIClient
    private let store: LocalStore
    private var inFlightDrafts: Set<String> = []
    private var mutationKeys: [String: String] = [:]
    private(set) var user: User?
    private(set) var servingCachedData = false
    init(api: APIClient, store: LocalStore) { self.api = api; self.store = store }
    func authenticate(email: String, password: String, displayName: String? = nil) async throws -> User {
        struct Credentials: Encodable, Sendable { let email: String; let password: String; let displayName: String? }
        let auth: AuthResponse = try await api.mutate(displayName == nil ? "auth/login" : "auth/register", body: Credentials(email: email, password: password, displayName: displayName))
        try await api.setToken(auth.token)
        let identity = SavedIdentity(user: auth.user, tokenDigest: Self.digest(auth.token))
        try await store.put(identity, key: "identity", scope: "session", kind: "identity")
        user = auth.user; return auth.user
    }
    func restoreSession() async throws -> User? {
        guard let digest = try await api.tokenDigest() else { return nil }
        let identities: [SavedIdentity] = try await store.values(scope: "session", kind: "identity")
        do { let remote: User = try await api.get("auth/me"); user = remote; return remote }
        catch where Self.isOffline(error) { user = identities.first(where: { $0.tokenDigest == digest })?.user; return user }
        catch { try await api.clearToken(); try await store.remove(scope: "session"); user = nil; throw error }
    }
    func logout() async throws {
        // Local credential revocation must succeed even when the network is unavailable.
        let _: OKResponse? = try? await api.mutate("auth/logout", body: EmptyBody())
        try await api.clearToken(); try await store.remove(scope: "session"); user = nil
    }
    func accountID() throws -> String { guard let user else { throw APIError(status: 401, message: "Sign in to continue.", retryAfter: nil) }; return user.id }
    func cachedProjects() async throws -> [Project] { try await store.values(scope: accountID(), kind: "project") }
    func projects() async throws -> [Project] {
        let scope = try accountID()
        do {
            let result: [Project] = try await api.get("projects")
            try requireScope(scope)
            servingCachedData = false
            for p in result { try await store.put(p, key: p.id, scope: scope, kind: "project") }
            return result
        } catch where Self.isOffline(error) { servingCachedData = true; return try await cachedProjects() }
    }
    func project(id: String) async throws -> Project {
        let scope = try accountID()
        do { let result: Project = try await api.get("projects/\(id)"); try requireScope(scope); servingCachedData = false; try await store.put(result, key: id, scope: scope, kind: "project"); return result }
        catch where Self.isOffline(error) { servingCachedData = true; if let cached = try await cachedProjects().first(where: { $0.id == id }) { return cached }; throw error }
    }
    func clients() async throws -> [Client] {
        let scope = try accountID()
        do { let result: [Client] = try await api.get("clients"); try requireScope(scope); for c in result { try await store.put(c, key: c.id, scope: scope, kind: "client") }; return result }
        catch where Self.isOffline(error) { return try await store.values(scope: scope, kind: "client") }
    }
    func createClient(name: String, email: String, phone: String? = nil) async throws -> Client {
        struct Input: Encodable, Sendable { let name: String; let email: String; let phone: String? }
        let scope = try accountID()
        let result: Client = try await api.mutate("clients", body: Input(name: name, email: email, phone: phone)); try requireScope(scope); try await store.put(result, key: result.id, scope: scope, kind: "client"); return result
    }
    func pendingDrafts() async throws -> [PendingDraft] { try await store.values(scope: accountID(), kind: "draft") }
    func createProject(draft: ProjectDraft) async throws -> Project? {
        let scope = try accountID()
        let operation = PendingDraft(id: UUID().uuidString, payload: draft, createdAt: Date(), attempts: 0, error: nil, safeToEdit: false)
        try await store.put(operation, key: operation.id, scope: scope, kind: "draft")
        do { return try await submit(operation, scope: scope) }
        catch where Self.isOffline(error) { return nil }
    }
    func flushDrafts() async throws {
        let scope = try accountID()
        for draft in try await pendingDrafts().sorted(by: { $0.createdAt < $1.createdAt }) {
            if inFlightDrafts.contains(draft.id) { continue }
            _ = try await submit(draft, scope: scope)
        }
    }
    func updateDraft(id: String, payload: ProjectDraft) async throws {
        guard !inFlightDrafts.contains(id) else { throw APIError(status: 409, message: "This draft is synchronizing.", retryAfter: nil) }
        inFlightDrafts.insert(id); defer { inFlightDrafts.remove(id) }
        let scope = try accountID()
        guard var draft = try await pendingDrafts().first(where: { $0.id == id }), draft.safeToEdit == true else { throw APIError(status: 409, message: "This request may have reached the server. Synchronize before changing it.", retryAfter: nil) }
        guard !payload.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, payload.title.count <= 200, payload.description.count <= 5000 else { throw APIError(status: 400, message: "Enter a title under 200 characters and description under 5000 characters.", retryAfter: nil) }
        try requireScope(scope); draft.payload = payload; draft.error = nil
        try await store.put(draft, key: id, scope: scope, kind: "draft")
    }
    func discardDraft(id: String) async throws {
        guard !inFlightDrafts.contains(id) else { throw APIError(status: 409, message: "This draft is synchronizing.", retryAfter: nil) }
        inFlightDrafts.insert(id); defer { inFlightDrafts.remove(id) }
        let scope = try accountID()
        guard let draft = try await pendingDrafts().first(where: { $0.id == id }), draft.safeToEdit == true else { throw APIError(status: 409, message: "Synchronize this uncertain request before discarding it.", retryAfter: nil) }
        try requireScope(scope); try await store.remove(key: id, scope: scope, kind: "draft")
    }
    private func submit(_ draft: PendingDraft, scope: String) async throws -> Project {
        guard !inFlightDrafts.contains(draft.id) else { throw APIError(status: 409, message: "This draft is synchronizing.", retryAfter: nil) }
        inFlightDrafts.insert(draft.id); defer { inFlightDrafts.remove(draft.id) }
        let saved: [PendingDraft] = try await store.values(scope: scope, kind: "draft")
        guard var submitting = saved.first(where: { $0.id == draft.id }) else { throw APIError(status: 404, message: "Draft was removed.", retryAfter: nil) }
        submitting.safeToEdit = false
        try await store.put(submitting, key: draft.id, scope: scope, kind: "draft")
        do {
            try requireScope(scope)
            let result: Project = try await api.mutate("projects", body: submitting.payload, idempotencyKey: draft.id)
            try requireScope(scope)
            try await store.put(result, key: result.id, scope: scope, kind: "project")
            try await store.remove(key: draft.id, scope: scope, kind: "draft"); return result
        } catch {
            submitting.attempts += 1; submitting.safeToEdit = Self.definitelyNotSent(error); submitting.error = error.localizedDescription
            try await store.put(submitting, key: draft.id, scope: scope, kind: "draft"); throw error
        }
    }
    func updateProject(id: String, status: ProjectStatus, version: Int) async throws -> Project {
        struct Update: Encodable, Sendable { let status: ProjectStatus; let version: Int }
        let scope = try accountID()
        let result: Project = try await api.mutate("projects/\(id)", method: "PATCH", body: Update(status: status, version: version)); try requireScope(scope); try await store.put(result, key: result.id, scope: scope, kind: "project"); return result
    }
    func createInvoice(projectID: String, items: [InvoiceItemDraft], dueAt: Date? = nil) async throws -> Invoice {
        struct Input: Encodable, Sendable { let items: [InvoiceItemDraft]; let dueAt: Date? }
        return try await authoritativeMutation("projects/\(projectID)/invoices", body: Input(items: items, dueAt: dueAt))
    }
    func invoiceAction(id: String, action: String) async throws -> Invoice {
        guard ["issue", "void", "reconcile"].contains(action) else { throw APIError(status: 400, message: "Invalid invoice action.", retryAfter: nil) }
        return try await authoritativeMutation("invoices/\(id)/\(action)", body: EmptyBody())
    }
    func share(projectID: String) async throws -> ShareLink { try await authoritativeMutation("projects/\(projectID)/share", body: EmptyBody()) }
    func delivery(projectID: String, release: Bool) async throws -> DeliveryResult { try await authoritativeMutation("projects/\(projectID)/delivery/\(release ? "release" : "revoke")", body: EmptyBody()) }
    private func authoritativeMutation<B: Encodable & Sendable, T: Decodable & Sendable>(_ path: String, body: B) async throws -> T {
        let scope = try accountID()
        var input = Data(path.utf8); input.append(try JSONCoding.encoder().encode(body))
        let fingerprint = SHA256.hash(data: input).map { String(format: "%02x", $0) }.joined()
        let memoKey = scope + ":" + fingerprint
        let saved: [DurableMutation] = try await store.values(scope: scope, kind: "mutation")
        let key = mutationKeys[memoKey] ?? saved.first(where: { $0.fingerprint == fingerprint })?.id ?? UUID().uuidString
        mutationKeys[memoKey] = key
        try await store.put(DurableMutation(id: key, fingerprint: fingerprint), key: fingerprint, scope: scope, kind: "mutation")
        // A lost response keeps its key. Repeating this operation cannot create another financial effect.
        let result: T = try await api.mutate(path, body: body, idempotencyKey: key)
        try requireScope(scope)
        try await store.remove(key: fingerprint, scope: scope, kind: "mutation"); mutationKeys.removeValue(forKey: memoKey)
        return result
    }
    private func requireScope(_ scope: String) throws { guard user?.id == scope else { throw APIError(status: 401, message: "Account changed; refresh this screen.", retryAfter: nil) } }
    static func isOffline(_ error: Error) -> Bool {
        if let error = error as? APIError { return error.retryable }
        guard let error = error as? URLError else { return false }
        return [.notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed, .dataNotAllowed, .internationalRoamingOff, .callIsActive, .resourceUnavailable].contains(error.code)
    }
    static func definitelyNotSent(_ error: Error) -> Bool {
        guard let error = error as? URLError else { return false }
        return [.notConnectedToInternet, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed].contains(error.code)
    }
    private static func digest(_ token: String) -> String { SHA256.hash(data: Data(token.utf8)).map { String(format: "%02x", $0) }.joined() }
}
