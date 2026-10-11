import Foundation
import CryptoKit

struct APIError: Error, LocalizedError, Sendable {
    let status: Int
    let message: String
    let retryAfter: TimeInterval?
    var errorDescription: String? { message }
    var retryable: Bool { status == 408 || status == 429 || status >= 500 }
}
private struct Failure: Decodable { let error: String }
actor APIClient {
    let baseURL: URL
    private let tokenStore: TokenStore
    private let session: URLSession
    init(baseURL: URL, tokenStore: TokenStore = TokenStore(), session: URLSession? = nil) {
        self.baseURL = baseURL; self.tokenStore = tokenStore
        if let session { self.session = session } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.urlCache = nil; configuration.httpCookieStorage = nil
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            self.session = URLSession(configuration: configuration)
        }
    }
    func setToken(_ token: String) throws { try tokenStore.save(token) }
    func clearToken() throws { try tokenStore.delete() }
    func tokenDigest() throws -> String? { try tokenStore.read().map { SHA256.hash(data: Data($0.utf8)).map { String(format: "%02x", $0) }.joined() } }
    func hasToken() throws -> Bool { try tokenStore.read() != nil }
    func get<T: Decodable & Sendable>(_ path: String) async throws -> T { try await request(path, method: "GET", body: nil, idempotencyKey: nil) }
    func mutate<B: Encodable & Sendable, T: Decodable & Sendable>(_ path: String, method: String = "POST", body: B, idempotencyKey: String = UUID().uuidString) async throws -> T {
        try await request(path, method: method, body: JSONCoding.encoder().encode(body), idempotencyKey: idempotencyKey)
    }
    private func request<T: Decodable & Sendable>(_ path: String, method: String, body: Data?, idempotencyKey: String?) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(path), cachePolicy: .reloadIgnoringLocalCacheData); request.httpMethod = method; request.httpBody = body; request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = try tokenStore.read() { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let idempotencyKey { request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key") }
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200...299).contains(response.statusCode) else {
            let message = (try? JSONDecoder().decode(Failure.self, from: data).error) ?? "Request failed (\(response.statusCode))."
            throw APIError(status: response.statusCode, message: message, retryAfter: RetryPolicy.retryAfter(response.value(forHTTPHeaderField: "Retry-After")))
        }
        return try JSONCoding.decoder().decode(T.self, from: data)
    }
}
struct EmptyBody: Codable, Sendable {}
