/*
 * EntitlementStore.swift
 * PixelFocus
 *
 * Point d'entrée unique pour "qui a droit à quoi" (voir GAME_DESIGN.md §2 et §5).
 *
 * Objectifs:
 * - Exposer le statut Premium (et la date de fin d'abonnement pour le cadeau de fin de Premium).
 * - Exposer les images du mois achetées à l'unité.
 * - Calculer l'accès à une image du mois via MonthlyAccessPolicy.
 *
 * Note:
 * - V1: le Premium est encore simulé (interrupteur dans Réglages) et aucun achat n'est branché.
 *   StoreKit (étape 3) viendra alimenter ce store sans changer son interface.
 * - La clé "isPremiumUser" reste partagée avec @AppStorage dans les vues existantes.
 */

import Foundation
import Combine

// MARK: - EntitlementStore
@MainActor
final class EntitlementStore: ObservableObject {

    // MARK: - Keys
    private enum Keys {
        static let isPremium = "isPremiumUser"
        static let premiumLapsedAt = "premiumLapsedAt"
        static let purchasedMonthlyIds = "purchasedMonthlyIds"
    }

    // MARK: - Published State
    @Published private(set) var premium: PremiumStatus
    @Published private(set) var purchasedMonthlyIds: Set<String>

    let firstLaunchDate: Date

    // MARK: - Dependencies
    private let defaults: UserDefaults

    // MARK: - Init
    init(defaults: UserDefaults = .standard, firstLaunchDate: Date? = nil) {
        self.defaults = defaults
        self.firstLaunchDate = firstLaunchDate ?? FirstLaunchStore.firstLaunchDate()

        let lapsedInterval = defaults.object(forKey: Keys.premiumLapsedAt) as? TimeInterval
        self.premium = PremiumStatus(
            isActive: defaults.bool(forKey: Keys.isPremium),
            lapsedAt: lapsedInterval.map { Date(timeIntervalSince1970: $0) }
        )
        self.purchasedMonthlyIds = Set(defaults.stringArray(forKey: Keys.purchasedMonthlyIds) ?? [])
    }

    // MARK: - Premium

    var isPremium: Bool { premium.isActive }

    /// Active/désactive le Premium. À la désactivation, on mémorise la date de fin
    /// (l'image du mois en cours reste offerte jusqu'à la fin du mois).
    func setPremium(_ isActive: Bool, now: Date = Date()) {
        guard isActive != premium.isActive else { return }

        premium.isActive = isActive
        premium.lapsedAt = isActive ? nil : now

        defaults.set(isActive, forKey: Keys.isPremium)
        if let lapsedAt = premium.lapsedAt {
            defaults.set(lapsedAt.timeIntervalSince1970, forKey: Keys.premiumLapsedAt)
        } else {
            defaults.removeObject(forKey: Keys.premiumLapsedAt)
        }
    }

    // MARK: - Monthly

    func isMonthlyPurchased(artworkId: String) -> Bool {
        purchasedMonthlyIds.contains(artworkId)
    }

    /// Accès à l'image du mois `artworkId` (mois `monthISO`).
    func monthlyAccess(
        artworkId: String,
        monthISO: String,
        completedSessionsInMonth: Int,
        rules: MonthlyAccessRulesDTO,
        now: Date = Date()
    ) -> MonthlyAccess {
        MonthlyAccessPolicy.access(
            monthISO: monthISO,
            now: now,
            firstLaunch: firstLaunchDate,
            premium: premium,
            isPurchased: isMonthlyPurchased(artworkId: artworkId),
            completedSessionsInMonth: completedSessionsInMonth,
            rules: rules
        )
    }
}
