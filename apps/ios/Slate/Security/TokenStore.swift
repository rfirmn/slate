import Foundation
import Security

struct TokenStore: Sendable {
    private let service: String
    private let account: String
    init(service: String = "com.slate.creator", account: String = "bearer") { self.service = service; self.account = account }
    func read() throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true; query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data, let token = String(data: data, encoding: .utf8) else { throw KeychainError(status: status) }
        return token
    }
    func save(_ token: String) throws {
        let attributes: [String: Any] = [kSecValueData as String: Data(token.utf8), kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        let updated = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if updated == errSecItemNotFound {
            let inserted = SecItemAdd(baseQuery.merging(attributes) { _, new in new } as CFDictionary, nil)
            guard inserted == errSecSuccess else { throw KeychainError(status: inserted) }
        } else if updated != errSecSuccess { throw KeychainError(status: updated) }
    }
    func delete() throws { let status = SecItemDelete(baseQuery as CFDictionary); guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError(status: status) } }
    private var baseQuery: [String: Any] { [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account] }
}
struct KeychainError: Error, LocalizedError { let status: OSStatus; var errorDescription: String? { "Secure credential storage failed (\(status))." } }
