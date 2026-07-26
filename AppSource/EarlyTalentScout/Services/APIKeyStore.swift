import Foundation
import Security

enum APIKeyStore {
    private static let service = "com.example.Internd"
    private static let legacyService = "com.example.EarlyTalentScout"
    private static let account = "openai-api-key"

    static func read() -> String? {
        read(service: service) ?? read(service: legacyService)
    }

    static func save(_ key: String) throws {
        let normalizedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedKey.isEmpty else { throw KeychainError.emptyKey }
        let data = Data(normalizedKey.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var creation = query
            creation[kSecValueData as String] = data
            creation[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            guard SecItemAdd(creation as CFDictionary, nil) == errSecSuccess else {
                throw KeychainError.saveFailed
            }
        } else if status != errSecSuccess {
            throw KeychainError.saveFailed
        }
    }

    private static func read(service: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    enum KeychainError: LocalizedError {
        case saveFailed, emptyKey
        var errorDescription: String? {
            switch self {
            case .saveFailed: "The API key could not be saved to Keychain."
            case .emptyKey: "Paste an API key before saving."
            }
        }
    }
}
