import Foundation
import Security

actor KeychainSessionStore: SessionStore {
    private let service = "com.docmostly.session"
    private let account = "docmostly-auth"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func save(_ session: StoredSession) async throws {
        let data = try encoder.encode(session)
        let identity: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        // Update in place so a failed write never discards the previously stored session.
        let updates: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let updateStatus = SecItemUpdate(identity as CFDictionary, updates as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw KeychainSessionStoreError.unhandledStatus(updateStatus)
        }

        let addStatus = SecItemAdd(identity.merging(updates) { _, new in new } as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainSessionStoreError.unhandledStatus(addStatus)
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
