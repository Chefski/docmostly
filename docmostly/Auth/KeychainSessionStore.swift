import Foundation
import Security

actor KeychainSessionStore: SessionStore {
    private let service = "com.docmostly.session"
    private let account = "docmostly-auth"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func save(_ session: StoredSession) async throws {
        let data = try encoder.encode(session)
        try await clear()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainSessionStoreError.unhandledStatus(status)
        }
    }

    func load() async throws -> StoredSession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainSessionStoreError.unhandledStatus(status)
        }

        guard let data = result as? Data else {
            throw KeychainSessionStoreError.invalidData
        }

        return try decoder.decode(StoredSession.self, from: data)
    }

    func clear() async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainSessionStoreError.unhandledStatus(status)
        }
    }
}
