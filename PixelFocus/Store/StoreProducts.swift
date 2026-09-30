/*
 * StoreProducts.swift
 * PixelFocus
 *
 * Identifiants des produits App Store (identiques côté serveur: server/src/Products.php).
 * Voir GAME_DESIGN.md §1 à §4 pour les prix.
 *
 * | Produit                         | Type                 | Prix    |
 * |---------------------------------|----------------------|---------|
 * | premium.monthly                 | Abonnement (1 mois)  | 2,99 €  |
 * | premium.yearly                  | Abonnement (1 an)    | 24,99 € |
 * | lifetime                        | Non-consommable      | 69,99 € |
 * | lifetime.member                 | Non-consommable      | 49,99 € (abonnés uniquement) |
 * | boosters.1 / .5 / .15           | Consommable          | 0,99 € / 3,99 € / 9,99 € |
 * | monthly.AAAA_MM                 | Non-consommable      | 1,99 €  |
 * | monthly.AAAA_MM.reduced         | Non-consommable      | 0,99 €  |
 * | pack.<id> / pack.<id>.archive   | Non-consommable      | 3,99 € / 2,99 € |
 */

import Foundation

enum StoreProducts {
    static let prefix = "com.sy2l.pixelfocus."

    static let premiumMonthly = prefix + "premium.monthly"
    static let premiumYearly = prefix + "premium.yearly"
    static let lifetime = prefix + "lifetime"
    static let lifetimeMember = prefix + "lifetime.member"

    /// Boosters: identifiant -> nombre de boosters
    static let boosters: [String: Int] = [
        prefix + "boosters.1": 1,
        prefix + "boosters.5": 5,
        prefix + "boosters.15": 15
    ]

    static var boosterIdsSorted: [String] {
        boosters.sorted { $0.value < $1.value }.map(\.key)
    }

    static let subscriptions: Set<String> = [premiumMonthly, premiumYearly]
    static let lifetimes: Set<String> = [lifetime, lifetimeMember]

    /// Image du mois à l'unité: "2026-10" -> "com.sy2l.pixelfocus.monthly.2026_10" (+ ".reduced")
    static func monthly(monthISO: String, reduced: Bool) -> String {
        prefix + "monthly." + monthISO.replacingOccurrences(of: "-", with: "_") + (reduced ? ".reduced" : "")
    }

    /// "com.sy2l.pixelfocus.monthly.2026_10(.reduced)" -> "monthly_2026_10_main"
    static func monthlyArtworkId(productId: String) -> String? {
        guard productId.hasPrefix(prefix + "monthly.") else { return nil }
        var month = String(productId.dropFirst((prefix + "monthly.").count))
        if month.hasSuffix(".reduced") {
            month = String(month.dropLast(".reduced".count))
        }
        guard month.count == 7 else { return nil }
        return "monthly_\(month)_main"
    }

    /// Tous les identifiants à charger (produits fixes + images du mois des mois donnés)
    static func allIdentifiers(monthISOs: [String]) -> [String] {
        var ids = [premiumMonthly, premiumYearly, lifetime, lifetimeMember] + boosterIdsSorted
        for month in monthISOs {
            ids.append(monthly(monthISO: month, reduced: false))
            ids.append(monthly(monthISO: month, reduced: true))
        }
        return ids
    }
}
