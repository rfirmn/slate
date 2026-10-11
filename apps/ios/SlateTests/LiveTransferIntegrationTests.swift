import XCTest
@testable import Slate

/// Opt-in: run with SLATE_INTEGRATION=1 and a reachable API + PostgreSQL + S3.
final class LiveTransferIntegrationTests: XCTestCase {
    func testRealMultipartPauseResumeAndVerifiedCompletion() async throws {
        guard ProcessInfo.processInfo.environment["SLATE_INTEGRATION"] == "1" else { throw XCTSkip("Set SLATE_INTEGRATION=1 with the local API and object storage running.") }
        let configured = ProcessInfo.processInfo.environment["SLATE_API_URL"]
        let endpoint = configured?.isEmpty == false ? configured! : "http://localhost:3000"
        let id = UUID().uuidString
        let tokens = TokenStore(service: "com.slate.integration", account: id)
        defer { try? tokens.delete() }
        let api = APIClient(baseURL: try XCTUnwrap(URL(string: endpoint)), tokenStore: tokens)
        let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("Integration-\(id)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let importer = try MediaImporter(root: root.appendingPathComponent("Staging", isDirectory: true))
        let store = try await LocalStore(storeURL: root.appendingPathComponent("queue.sqlite"))
        let repository = ProjectRepository(api: api, store: store)
        let user = try await repository.authenticate(email: "native-\(id)@example.test", password: "SlateIntegration1!", displayName: "Native integration")
        let client = try await repository.createClient(name: "Native integration client", email: "client@example.test")
        let offlineAPI = APIClient(baseURL: URL(string: "http://localhost:65534")!, tokenStore: tokens)
        let offlineRepository = ProjectRepository(api: offlineAPI, store: store)
        let restored = try await offlineRepository.restoreSession()
        XCTAssertEqual(restored?.id, user.id)
        let offlineResult = try await offlineRepository.createProject(draft: ProjectDraft(title: "Offline metadata", description: "No connection", clientId: client.id, deliverables: [DeliverableDraft(title: "Document", type: "FILE", expectedQuantity: 1)]))
        XCTAssertNil(offlineResult)
        let pending = try await offlineRepository.pendingDrafts()
        let editable = try XCTUnwrap(pending.first)
        XCTAssertEqual(editable.safeToEdit, true)
        var editedPayload = editable.payload; editedPayload.title = "Edited offline title"
        try await offlineRepository.updateDraft(id: editable.id, payload: editedPayload)
        let edited = try await offlineRepository.pendingDrafts().first
        XCTAssertEqual(edited?.id, editable.id); XCTAssertEqual(edited?.payload.title, editedPayload.title)
        try await offlineRepository.discardDraft(id: editable.id)
        let discarded = try await offlineRepository.pendingDrafts()
        XCTAssertTrue(discarded.isEmpty)
        let projectResult = try await repository.createProject(draft: ProjectDraft(title: "Native multipart integration", description: "Real 17 MiB background multipart bytes", clientId: client.id, deliverables: [DeliverableDraft(title: "Document", type: "FILE", expectedQuantity: 1)]))
        let project = try XCTUnwrap(projectResult)
        let source = importer.root.appendingPathComponent("fixture.pdf")
        FileManager.default.createFile(atPath: source.path, contents: Data("%PDF-1.4\n% Slate integration fixture\n".utf8))
        let handle = try FileHandle(forWritingTo: source)
        try handle.seekToEnd()
        let chunk = Data(repeating: 65, count: 1024 * 1024)
        for _ in 0..<17 { try handle.write(contentsOf: chunk) }
        try handle.close()
        let file = try await importer.inspect(source, filename: "fixture.pdf", mimeType: "application/pdf")
        // Seed an actual remote part, then restore stale local progress as after a process crash.
        struct Input: Encodable, Sendable { let projectId: String; let filename: String; let mimeType: String; let sizeBytes: Int64; let contentHash: String }
        let createKey = UUID().uuidString
        let sessionBeforeCrash: TransferSession = try await api.mutate("transfers", body: Input(projectId: project.id, filename: file.filename, mimeType: file.mimeType, sizeBytes: file.sizeBytes, contentHash: file.contentHash), idempotencyKey: createKey)
        let signed: SignedPart = try await api.mutate("transfers/\(sessionBeforeCrash.id)/parts/1/sign", body: EmptyBody())
        let firstPart = try await importer.partFile(source: file.fileURL, recordID: id, part: 1, partSize: sessionBeforeCrash.partSize, totalBytes: file.sizeBytes)
        var request = URLRequest(url: signed.url); request.httpMethod = "PUT"
        let (_, response) = try await URLSession.shared.upload(for: request, fromFile: firstPart)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        try importer.remove(firstPart)
        let queued = TransferRecord(id: id, ownerID: user.id, projectID: project.id, file: file, createdAt: Date(), state: .paused, session: sessionBeforeCrash, uploadedBytes: 0, retryCount: 0, nextRetryAt: nil, error: nil, bindings: [], createKey: createKey, completeKey: UUID().uuidString, cancelKey: UUID().uuidString)
        try await store.put(queued, key: queued.id, scope: user.id, kind: "transfer")
        let engine = await TransferCoordinator(api: api, store: store, media: importer, backgroundIdentifier: "com.slate.integration.\(id)")
        try await engine.setAccount(ownerID: user.id)
        await engine.setCellularAllowed(true)
        let paused = await engine.transfers().first { $0.id == queued.id }
        XCTAssertEqual(paused?.state, .paused)
        XCTAssertEqual(paused?.uploadedBytes, sessionBeforeCrash.partSize)
        XCTAssertEqual(paused?.session?.parts.map(\.partNumber), [1])
        let saved: [TransferRecord] = try await store.values(scope: user.id, kind: "transfer")
        XCTAssertEqual(saved.first?.state, .paused)
        XCTAssertEqual(saved.first?.createKey, queued.createKey)
        try await engine.resume(id: queued.id)
        let deadline = Date().addingTimeInterval(180)
        var completed: TransferRecord?
        while Date() < deadline {
            if let record = await engine.transfers().first(where: { $0.id == queued.id }) {
                XCTAssertLessThanOrEqual(record.bindings.count, 2)
                XCTAssertFalse(record.bindings.contains { $0.partNumber == 1 }, "Confirmed first part must not be retransmitted")
                if record.state == .completed { completed = record; break }
                if record.state == .failed { XCTFail(record.error ?? "Transfer failed"); break }
            }
            try await Task.sleep(for: .milliseconds(250))
        }
        let result = try XCTUnwrap(completed, "Real background transfer did not complete within 180 seconds.")
        let session = try XCTUnwrap(result.session)
        let authoritative: TransferSession = try await api.get("transfers/\(session.id)")
        XCTAssertEqual(authoritative.status, "COMPLETED")
        let remote = try await repository.project(id: project.id)
        let media = try XCTUnwrap(remote.media.first)
        XCTAssertEqual(media.status, "VERIFIED")
        XCTAssertEqual(media.contentHash, file.contentHash)
        XCTAssertEqual(media.sizeBytes, file.sizeBytes)
        XCTAssertEqual(result.uploadedBytes, file.sizeBytes)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.fileURL.path))
        // A stale local journal must accept a completion that beat cancellation on the server.
        let raceID = UUID().uuidString
        let stale = TransferRecord(id: raceID, ownerID: user.id, projectID: project.id, file: file, createdAt: Date(), state: .paused, session: sessionBeforeCrash, uploadedBytes: 0, retryCount: 0, nextRetryAt: nil, error: nil, bindings: [], createKey: createKey, completeKey: queued.completeKey, cancelKey: UUID().uuidString)
        try await store.put(stale, key: raceID, scope: user.id, kind: "transfer")
        let recoveredEngine = await TransferCoordinator(api: api, store: store, media: importer, backgroundIdentifier: "com.slate.integration.race.\(id)")
        try await recoveredEngine.setAccount(ownerID: user.id)
        try await recoveredEngine.cancel(id: raceID)
        let reconciled = await recoveredEngine.transfers().first { $0.id == raceID }
        XCTAssertEqual(reconciled?.state, .completed)
        XCTAssertNil(reconciled?.error)
        try await recoveredEngine.setAccount(ownerID: nil)
        try await engine.setAccount(ownerID: nil)
        try await repository.logout()
        try await store.close()
    }
}
