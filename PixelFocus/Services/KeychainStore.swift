/*
 * KeychainStore.swift
 * PixelFocus
 *
 * Petites valeurs secrètes dans le trousseau (jeton d'API, identifiant de compte).
 *
 * - Synchronisé via le trousseau iCloud quand il est disponible: un nouvel iPhone/iPad
 *   du même compte Apple retrouve le même compte PixelFocus.
 * - Survit à la désinstallation de l'app.
 */

import Foundation
import Security

enum KeychainStore {

    private static let service = "com.sy2l.PixelFocus.sync"

    enum Key: String {
        case apiToken
        case userId
    }

    static func string(for key: Key) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    static func set(_ value: String, for key: Key) {
        remove(key)

        var attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecAttrSynchronizable as String: true,
            kSecValueData as String: Data(value.utf8)
        ]
        if SecItemAdd(attributes as CFDictionary, nil) != errSecSuccess {
            // Trousseau iCloud indisponible: élément local uniquement
            attributes.removeValue(forKey: kSecAttrSynchronizable as String)
            SecItemAdd(attributes as CFDictionary, nil)
        }
    }

    static func remove(_ key: Key) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]
        SecItemDelete(query as CFDictionary)
    }
}
