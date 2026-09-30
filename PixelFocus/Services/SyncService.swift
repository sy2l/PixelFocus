/*
 * SyncService.swift
 * PixelFocus
 *
 * Synchronisation avec l'API PixelFocus (voir server/README.md et GAME_DESIGN.md §5).
 *
 * 1. Compte anonyme créé automatiquement (jeton dans le trousseau, partagé via iCloud)
 * 2. Envoi des événements locaux non synchronisés (idempotent)
 * 3. Récupération des événements des autres appareils + des droits (achats validés)
 * 4. Rejeu des événements distants dans la base locale (progression, boosters, série, badges…)
 *
 * L'app reste entièrement utilisable hors ligne: la synchronisation reprend dès que possible.
 */

import Foundation
import SwiftData
import UIKit

// MARK: - SyncService
@MainActor
final class SyncService: ObservableObject {

    enum Status: Equatable {
        case notConfigured
        case idle
        case syncing
        case failed(String)
    }

    private enum Keys {
        static let cursor = "sync.cursor"
        static let lastSyncAt = "sync.lastSyncAt"
        static let appleLinked = "sync.appleLinked"
        static let purchasedBoostersTotal = "sync.purchasedBoostersTotal"
    }

    // MARK: - Published State
    @Published private(set) var status: Status
    @Published private(set) var lastSyncAt: Date?
    @Published private(set) var isAppleLinked: Bool

    // MARK: - Dependencies
    private let modelContext: ModelContext
    private let entitlements: EntitlementStore
    private let rulesetProvider: () -> RulesetDTO?
    private let importArtwork: @MainActor (String) -> Void
    private let defaults: UserDefaults

    /// Faux tant qu'un achat de boosters n'a pas encore été validé par le serveur (PurchaseManager)
    var canReconcilePurchasedBoosters: @MainActor () -> Bool = { true }

    private var isRunning = false

    // MARK: - Init
    init(
        modelContext: ModelContext,
        entitlements: EntitlementStore,
        rulesetProvider: @escaping () -> RulesetDTO?,
        importArtwork: @escaping @MainActor (String) -> Void,
        defaults: UserDefaults = .standard
    ) {
        self.modelContext = modelContext
        self.entitlements = entitlements
        self.rulesetProvider = rulesetProvider
        self.importArtwork = importArtwork
        self.defaults = defaults
        self.status = AppConfig.isSyncConfigured ? .idle : .notConfigured
        self.lastSyncAt = defaults.object(forKey: Keys.lastSyncAt) as? Date
        self.isAppleLinked = defaults.bool(forKey: Keys.appleLinked)
    }

    // MARK: - Account

    /// Identifiant du compte serveur (utilisé comme appAccountToken des achats App Store)
    var userId: UUID? {
        KeychainStore.string(for: .userId).flatMap(UUID.init(uuidString:))
    }

    private func client() throws -> APIClient {
        guard let baseURL = AppConfig.apiBaseURL else { throw APIError.notConfigured }
        return APIClient(baseURL: baseURL, token: KeychainStore.string(for: .apiToken))
    }

    /// Crée le compte anonyme si nécessaire
    func ensureAccount() async throws {
        guard KeychainStore.string(for: .apiToken) == nil else { return }
        let response = try await client().createAnonymous(
            firstLaunchAt: entitlements.firstLaunchDate,
            deviceName: UIDevice.current.model
        )
        KeychainStore.set(response.token, for: .apiToken)
        KeychainStore.set(response.userId, for: .userId)
        defaults.set(0, forKey: Keys.cursor)
    }

    // MARK: - Sync

    /// Synchronise maintenant (sans effet si une synchronisation est déjà en cours)
    func syncNow() async {
        guard AppConfig.isSyncConfigured else {
            status = .notConfigured
            return
        }
        guard !isRunning else { return }
        isRunning = true
        status = .syncing
        defer { isRunning = false }

        do {
            try await ensureAccount()
            try await pushPendingEvents()
            try await pullRemoteState()
            lastSyncAt = Date()
            defaults.set(lastSyncAt, forKey: Keys.lastSyncAt)
            status = .idle
        } catch {
            if let apiError = error as? APIError, case .server(let statusCode, _, _) = apiError, statusCode == 401 {
                // Jeton refusé (compte supprimé ailleurs): un nouveau compte sera créé à la prochaine synchronisation
                KeychainStore.remove(.apiToken)
                KeychainStore.remove(.userId)
                defaults.set(0, forKey: Keys.cursor)
            }
            status = .failed(error.localizedDescription)
        }
    }

    private func pushPendingEvents() async throws {
        let descriptor = FetchDescriptor<SDEvent>(
            predicate: #Predicate { $0.isSynced == false },
            sortBy: [SortDescriptor(\.occurredAt)]
        )
        let pending = try modelContext.fetch(descriptor)
        guard !pending.isEmpty else { return }

        let api = try client()
        for start in stride(from: 0, to: pending.count, by: 200) {
            let batch = Array(pending[start..<min(start + 200, pending.count)])
            let response = try await api.postEvents(batch.map(\.apiEvent))

            // Acceptés, doublons et refusés sont traités (un refus ne sera jamais accepté plus tard)
            let handled = Set(response.accepted + response.duplicates + response.rejected.compactMap(\.id))
            for event in batch where handled.contains(event.id) {
                event.isSynced = true
            }
            try modelContext.save()
        }
    }

    private func pullRemoteState() async throws {
        let api = try client()
        var cursor = defaults.integer(forKey: Keys.cursor)
        var hasMore = true

        while hasMore {
            let state = try await api.getState(since: cursor)
            try applyRemoteEvents(state.events)

            cursor = state.cursor
            hasMore = state.hasMore
            defaults.set(cursor, forKey: Keys.cursor)

            isAppleLinked = state.user.appleLinked
            defaults.set(isAppleLinked, forKey: Keys.appleLinked)

            entitlements.applyServer(state.entitlements)
            defaults.set(state.entitlements.purchasedBoostersTotal, forKey: Keys.purchasedBoostersTotal)
            try reconcilePurchasedBoosters(serverTotal: state.entitlements.purchasedBoostersTotal)
        }
    }

    // MARK: - Achats

    /// Fait valider un achat App Store par le serveur puis applique les droits renvoyés
    func validateApplePurchase(transactionId: UInt64) async throws {
        try await ensureAccount()
        let result = try await client().postApplePurchase(transactionId: String(transactionId))
        entitlements.applyServer(result)
        defaults.set(result.purchasedBoostersTotal, forKey: Keys.purchasedBoostersTotal)
        try reconcilePurchasedBoosters(serverTotal: result.purchasedBoostersTotal)
    }

    /// Boosters achetés restants = total acheté (serveur, remboursements déduits) - boosters achetés utilisés
    private func reconcilePurchasedBoosters(serverTotal: Int) throws {
        guard canReconcilePurchasedBoosters() else { return }
        let type = EventType.boosterUsed.rawValue
        let used = try modelContext.fetch(FetchDescriptor<SDEvent>(predicate: #Predicate { $0.type == type }))
            .filter { $0.payload?["source"]?.stringValue == "purchased" }
            .count
        let wallet = try fetchOrCreateWallet()
        wallet.purchasedBoosters = max(0, serverTotal - used)
        try modelContext.save()
    }

    // MARK: - Se connecter avec Apple

    /// Rattache le compte à "Se connecter avec Apple". Si ce compte Apple est déjà connu
    /// (autre appareil), le serveur fusionne et renvoie un nouveau jeton: on récupère alors tout l'historique.
    func linkApple(identityToken: String) async throws {
        try await ensureAccount()
        try await pushPendingEvents()

        let response = try await client().linkApple(identityToken: identityToken)
        if response.merged, let token = response.token {
            KeychainStore.set(token, for: .apiToken)
            KeychainStore.set(response.userId, for: .userId)
            defaults.set(0, forKey: Keys.cursor)
        }
        isAppleLinked = true
        defaults.set(true, forKey: Keys.appleLinked)
        await syncNow()
    }

    // MARK: - Suppression du compte

    /// Supprime le compte sur le serveur (si configuré) puis toutes les données locales
    func deleteAccountAndLocalData() async throws {
        if AppConfig.isSyncConfigured, KeychainStore.string(for: .apiToken) != nil {
            try await client().deleteAccount()
        }

        try modelContext.delete(model: SDEvent.self)
        try modelContext.delete(model: SDProgress.self)
        try modelContext.delete(model: SDWallet.self)
        try modelContext.delete(model: SDStreak.self)
        try modelContext.delete(model: SDDailyQuota.self)
        try modelContext.delete(model: SDMonthStats.self)
        try modelContext.delete(model: SDActiveDay.self)
        try modelContext.delete(model: SDBadge.self)
        try modelContext.save()

        KeychainStore.remove(.apiToken)
        KeychainStore.remove(.userId)
        for key in [Keys.cursor, Keys.lastSyncAt, Keys.appleLinked, Keys.purchasedBoostersTotal] {
            defaults.removeObject(forKey: key)
        }
        entitlements.reset()
        lastSyncAt = nil
        isAppleLinked = false
        status = AppConfig.isSyncConfigured ? .idle : .notConfigured
    }

    // MARK: - Rejeu des événements distants

    /// Applique les événements venus d'un autre appareil (ceux déjà connus localement sont ignorés)
    private func applyRemoteEvents(_ events: [APIEvent]) throws {
        guard !events.isEmpty else { return }
        var activeDaysChanged = false

        for remote in events {
            let remoteId = remote.id.lowercased()
            let existing = try modelContext.fetch(FetchDescriptor<SDEvent>(predicate: #Predicate { $0.id == remoteId }))
            guard existing.isEmpty, let type = EventType(rawValue: remote.type) else { continue }

            let occurredAt = ISO8601DateFormatter.api.date(from: remote.occurredAt) ?? Date()
            var payloadObject: [String: JSONValue]?
            if case .object(let object)? = remote.payload {
                payloadObject = object
            }
            modelContext.insert(SDEvent(
                id: remoteId,
                type: type,
                artworkId: remote.artworkId,
                payload: payloadObject,
                occurredAt: occurredAt,
                isSynced: true
            ))

            let payload = remote.payload
            switch type {
            case .sessionCompleted:
                if let artworkId = remote.artworkId {
                    try reveal(artworkId: artworkId, pixels: payload?["pixels"]?.intValue ?? defaultPixels)
                }
                let stats = try fetchOrCreateMonthStats(monthISO: DatePolicy.isoMonthString(for: occurredAt))
                stats.completedSessions += 1

            case .boosterUsed:
                if let artworkId = remote.artworkId {
                    try reveal(artworkId: artworkId, pixels: payload?["pixels"]?.intValue ?? defaultPixels)
                }
                if payload?["source"]?.stringValue == "earned" {
                    let wallet = try fetchOrCreateWallet()
                    wallet.earnedBoosters = max(0, wallet.earnedBoosters - 1)
                }
                // Boosters achetés: recalculés depuis le serveur (reconcilePurchasedBoosters)

            case .boosterEarned:
                let wallet = try fetchOrCreateWallet()
                wallet.earnedBoosters = BoosterPolicy.addingEarned(
                    current: wallet.earnedBoosters,
                    amount: payload?["amount"]?.intValue ?? 1,
                    cap: rulesetProvider()?.boosters.earnedCap ?? 12
                )
                if payload?["reason"]?.stringValue == "premium_monthly", let month = payload?["month"]?.stringValue {
                    // L'octroi mensuel Premium n'est fait qu'une fois, tous appareils confondus
                    wallet.premiumGrantMonthISO = max(wallet.premiumGrantMonthISO ?? "", month)
                }

            case .protectionTokenEarned:
                let wallet = try fetchOrCreateWallet()
                wallet.protectionTokensAvailable += payload?["amount"]?.intValue ?? 1

            case .protectionTokenUsed:
                let wallet = try fetchOrCreateWallet()
                wallet.protectionTokensAvailable = max(0, wallet.protectionTokensAvailable - 1)

            case .dayActive:
                if let dayISO = payload?["dayISO"]?.stringValue {
                    let days = try modelContext.fetch(FetchDescriptor<SDActiveDay>(predicate: #Predicate { $0.dayISO == dayISO }))
                    if days.isEmpty {
                        modelContext.insert(SDActiveDay(dayISO: dayISO))
                        activeDaysChanged = true
                    }
                }

            case .badgeUnlocked:
                if let badgeId = payload?["badgeId"]?.stringValue {
                    let badges = try modelContext.fetch(FetchDescriptor<SDBadge>(predicate: #Predicate { $0.badgeId == badgeId }))
                    if badges.isEmpty {
                        modelContext.insert(SDBadge(badgeId: badgeId, unlockedAt: occurredAt))
                    }
                }

            case .monthlyUnlocked:
                break
            }
        }

        if activeDaysChanged {
            try recomputeStreak()
        }
        try modelContext.save()
    }

    private var defaultPixels: Int {
        rulesetProvider()?.sessions.pixelsPerCompletedSession ?? 5
    }

    private func reveal(artworkId: String, pixels: Int) throws {
        importArtwork(artworkId)

        let progress: SDProgress
        if let existing = try modelContext.fetch(FetchDescriptor<SDProgress>(predicate: #Predicate { $0.artworkId == artworkId })).first {
            progress = existing
        } else {
            progress = SDProgress(artworkId: artworkId)
            modelContext.insert(progress)
        }
        progress.revealedCount += pixels
        progress.updatedAt = Date()

        if let artwork = try modelContext.fetch(FetchDescriptor<SDArtwork>(predicate: #Predicate { $0.artworkId == artworkId })).first,
           progress.revealedCount >= artwork.totalPixels {
            progress.state = .completed
        }
    }

    /// Série et record recalculés depuis l'ensemble des jours actifs (tous appareils)
    private func recomputeStreak() throws {
        let calendar = BadgePolicy.isoCalendar
        let dates = try modelContext.fetch(FetchDescriptor<SDActiveDay>())
            .compactMap { DateParsing.dateFromISODay($0.dayISO, calendar: calendar) }
            .sorted()
        guard let last = dates.last else { return }

        // Série en cours = suite de jours consécutifs se terminant au dernier jour actif
        var current = 1
        for index in stride(from: dates.count - 1, to: 0, by: -1) {
            if calendar.dateComponents([.day], from: dates[index - 1], to: dates[index]).day == 1 {
                current += 1
            } else {
                break
            }
        }

        let streak: SDStreak
        if let existing = try modelContext.fetch(FetchDescriptor<SDStreak>()).first {
            streak = existing
        } else {
            streak = SDStreak()
            modelContext.insert(streak)
        }
        streak.current = current
        streak.lastCompletedDayISO = DatePolicy.isoDayString(for: last, calendar: calendar)
        streak.longestStreak = max(streak.longestStreak, BadgePolicy.longestStreak(dates: dates, calendar: calendar))
    }

    // MARK: - Helpers

    private func fetchOrCreateWallet() throws -> SDWallet {
        if let wallet = try modelContext.fetch(FetchDescriptor<SDWallet>()).first {
            return wallet
        }
        let wallet = SDWallet()
        modelContext.insert(wallet)
        return wallet
    }

    private func fetchOrCreateMonthStats(monthISO: String) throws -> SDMonthStats {
        if let stats = try modelContext.fetch(FetchDescriptor<SDMonthStats>(predicate: #Predicate { $0.monthISO == monthISO })).first {
            return stats
        }
        let stats = SDMonthStats(monthISO: monthISO)
        modelContext.insert(stats)
        return stats
    }
}
