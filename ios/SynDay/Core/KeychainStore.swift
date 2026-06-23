import Foundation
import Security

enum KeychainStore {
    private static let service = "cloud.catclaw.synday"
    private static let accessTokenAccount = "supabase_access_token"
    private static let refreshTokenAccount = "supabase_refresh_token"
    private static let userIdAccount = "user_id"

    static func saveAccessToken(_ token: String) {
        save(token, account: accessTokenAccount)
    }

    static func accessToken() -> String? {
        read(account: accessTokenAccount)
    }

    static func saveRefreshToken(_ token: String) {
        save(token, account: refreshTokenAccount)
    }

    static func refreshToken() -> String? {
        read(account: refreshTokenAccount)
    }

    static func saveUserID(_ id: String) {
        save(id, account: userIdAccount)
    }

    static func userID() -> String? {
        read(account: userIdAccount)
    }

    static func clearAll() {
        delete(account: accessTokenAccount)
        delete(account: refreshTokenAccount)
        delete(account: userIdAccount)
    }

    private static func save(_ value: String, account: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
    }

    private static func read(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    private static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
