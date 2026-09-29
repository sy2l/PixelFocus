/*
 * FirstLaunchStore.swift
 * PixelFocus
 *
 * Date du premier lancement, conservée dans le trousseau (iCloud si disponible).
 *
 * Objectifs:
 * - Déterminer l'image du mois offerte à l'installation (voir GAME_DESIGN.md §2.1).
 * - Résister à la désinstallation/réinstallation (le trousseau survit, contrairement à UserDefaults).
 *
 * Note:
 * - On tente d'abord un élément synchronisé iCloud; s'il est refusé, on retombe sur un élément local.
 */

import Foundation
import Security

// MARK: - FirstLaunchStore
enum FirstLaunchStore {

    private static let service = "com.sy2l.PixelFocus"
    private static let account = "firstLaunchDate"

    /// Retourne la date du premier lancement; l'enregistre à `now` si elle n'existe pas encore.
    static func firstLaunchDate(now: Date = Date()) -> Date {
        if let stored = read() {
            return stored
        }
        write(now)
        return now
    }

    // MARK: - Keychain

    private static func read() -> Date? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let interval = TimeInterval(String(decoding: data, as: UTF8.self)) else {
            return nil
        }
        return Date(timeIntervalSince1970: interval)
    }

    private static func write(_ date: Date) {
        let data = Data(String(date.timeIntervalSince1970).utf8)

        var attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecAttrSynchronizable as String: true,
            kSecValueData as String: data
        ]

        if SecItemAdd(attributes as CFDictionary, nil) != errSecSuccess {
            // iCloud Keychain indisponible: élément local uniquement
            attributes.removeValue(forKey: kSecAttrSynchronizable as String)
            SecItemAdd(attributes as CFDictionary, nil)
        }
    }
}
