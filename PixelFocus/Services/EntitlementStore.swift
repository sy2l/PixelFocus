/*
 * EntitlementStore.swift
 * PixelFocus
 *
 * Point d'entrée unique pour "qui a droit à quoi" (voir GAME_DESIGN.md §2 et §5).
 *
 * Sources des droits (combinées):
 * - StoreKit: achats de cet appareil / de ce compte Apple (PurchaseManager)
 * - Serveur: achats validés sur n'importe quel appareil, iOS ou Android (SyncService)
 * - Debug: interrupteur "Premium simulé", uniquement dans les versions de développement
 *
 * Calcule aussi l'accès à une image du mois via MonthlyAccessPolicy.
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
        static let debugPremium = "debugPremium"
        static let storePremium = "storePremium"
        static let serverPremium = "serverPremium"
    }

    // MARK: - Published State
    @Published private(set) var premium: PremiumStatus
    @Published private(set) var purchasedMonthlyIds: Set<String>
    @Published private(set) var debugPremium: Bool

    let firstLaunchDate: Date

    // MARK: - Sources
    private var storePremium: Bool
    private var serverPremium: Bool

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
        self.storePremium = defaults.bool(forKey: Keys.storePremium)
        self.serverPremium = defaults.bool(forKey: Keys.serverPremium)
        #if DEBUG
        self.debugPremium = defaults.bool(forKey: Keys.debugPremium)
        #else
        self.debugPremium = false
        #endif
    }

    // MARK: - Premium

    var isPremium: Bool { premium.isActive }

    /// Droits issus de StoreKit (PurchaseManager)
    func applyStore(isPremium: Bool, monthlyArtworkIds: Set<String>, now: Date = Date()) {
        storePremium = isPremium
        defaults.set(isPremium, forKey: Keys.storePremium)
        addPurchasedMonthlies(monthlyArtworkIds)
        refreshPremium(now: now)
    }

    /// Droits issus du serveur (SyncService)
    func applyServer(_ entitlements: APIEntitlements, now: Date = Date()) {
        serverPremium = entitlements.premium.active
        defaults.set(serverPremium, forKey: Keys.serverPremium)
        addPurchasedMonthlies(Set(entitlements.monthlyArtworkIds))
        refreshPremium(now: now)
    }

    /// Premium simulé (versions de développement uniquement)
    func setDebugPremium(_ isActive: Bool, now: Date = Date()) {
        #if DEBUG
        debugPremium = isActive
        defaults.set(isActive, forKey: Keys.debugPremium)
        refreshPremium(now: now)
        #endif
    }

    /// Remet tout à zéro (suppression du compte)
    func reset() {
        storePremium = false
        serverPremium = false
        debugPremium = false
        purchasedMonthlyIds = []
        premium = .none
        for key in [Keys.isPremium, Keys.premiumLapsedAt, Keys.purchasedMonthlyIds, Keys.debugPremium, Keys.storePremium, Keys.serverPremium] {
            defaults.removeObject(forKey: key)
        }
    }

    /// Recalcule le statut Premium. À la fin d'un abonnement, on mémorise la date
    /// (l'image du mois en cours reste offerte jusqu'à la fin du mois).
    private func refreshPremium(now: Date) {
        let isActive = storePremium || serverPremium || debugPremium
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

    private func addPurchasedMonthlies(_ ids: Set<String>) {
        let merged = purchasedMonthlyIds.union(ids)
        guard merged != purchasedMonthlyIds else { return }
        purchasedMonthlyIds = merged
        defaults.set(Array(merged).sorted(), forKey: Keys.purchasedMonthlyIds)
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
