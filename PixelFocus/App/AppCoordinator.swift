/*
 * AppCoordinator.swift
 * PixelFocus
 *
 * Version: 1.0
 * Date: 15 janvier 2026
 *
 * Coordinateur global de l'application (scalable long terme).
 *
 * Rôle:
 * - Charger le contenu JSON (ruleset + catalog)
 * - Importer les artworks au besoin (SwiftData)
 * - Exposer GameEngine + SessionManager
 * - Centraliser la navigation "métier" (démarrer daily, etc.)
 *
 * Technique:
 * - ObservableObject injecté via .environmentObject
 * - Dépend de ModelContext (SwiftData)
 */

import Foundation
import SwiftData
import SwiftUI
import Combine

// MARK: - AppCoordinator
@MainActor
final class AppCoordinator: ObservableObject {

    // MARK: - Published State
    @Published private(set) var isReady: Bool = false
    @Published private(set) var loadingErrorMessage: String?

    @Published private(set) var ruleset: RulesetDTO?
    @Published private(set) var catalog: CatalogDTO?

    // MARK: - Dependencies

    // Long-term scalable services
    private var contentStore: ContentStore?
    private var engine: GameEngine?
    private var sessionManager: SessionManager?

    /// Droits d'accès (Premium, achats, image offerte). Injecté aussi en EnvironmentObject.
    let entitlements: EntitlementStore
    /// Synchronisation avec le serveur (compte, événements, droits)
    let syncService: SyncService
    /// Achats App Store (StoreKit 2)
    let purchaseManager: PurchaseManager

    let modelContext: ModelContext
    private var cancellables = Set<AnyCancellable>()
    /// Garde le conteneur en mémoire pour les aperçus Xcode
    private var previewContainer: ModelContainer?

    /// Règles du jeu partagées avec les services créés avant le chargement du contenu
    private let rulesetBox: RulesetBox

    // MARK: - Init

    init(modelContext: ModelContext, entitlements: EntitlementStore? = nil) {
        let entitlementStore = entitlements ?? EntitlementStore()
        let store = ContentStore(loader: JSONContentLoader(), modelContext: modelContext)
        let rulesetBox = RulesetBox()
        let gameEngine = GameEngine(modelContext: modelContext, rulesetProvider: { rulesetBox.value })
        let sync = SyncService(
            modelContext: modelContext,
            entitlements: entitlementStore,
            rulesetProvider: { rulesetBox.value },
            importArtwork: { artworkId in try? store.ensureArtworkImported(artworkId: artworkId) }
        )

        self.entitlements = entitlementStore
        self.modelContext = modelContext
        self.rulesetBox = rulesetBox
        self.contentStore = store
        self.engine = gameEngine
        self.sessionManager = SessionManager()
        self.syncService = sync
        self.purchaseManager = PurchaseManager(
            entitlements: entitlementStore,
            syncService: sync,
            creditBoosters: { amount in try? gameEngine.creditPurchasedBoosters(amount) }
        )

        // Quand le statut Premium change (achat, fin d'abonnement): octroi mensuel éventuel + rafraîchissement
        entitlementStore.$premium
            .removeDuplicates()
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.applyDatePolicies()
                    self.objectWillChange.send()
                }
            }
            .store(in: &cancellables)
    }

    /// Coordinateur sur une base en mémoire (aperçus Xcode)
    convenience init() {
        let container = AppSchema.makeContainer(inMemory: true)
        self.init(modelContext: container.mainContext)
        self.previewContainer = container
    }

    // MARK: - Public Accessors

    func getEngine() -> GameEngine? { engine }
    func getSessionManager() -> SessionManager? { sessionManager }
    func getContentStore() -> ContentStore? { contentStore }

    /// Charge le contenu initial si nécessaire
    func loadInitialContentIfNeeded() {
        guard let contentStore, engine != nil else { return }
        guard !isReady else { return }

        do {
            try contentStore.loadInitialContent()
            self.ruleset = contentStore.ruleset
            self.rulesetBox.value = contentStore.ruleset
            self.catalog = contentStore.catalog

            self.isReady = true
            self.loadingErrorMessage = nil
        } catch {
            self.loadingErrorMessage = "Erreur chargement contenu: \(error)"
            self.isReady = false
            return
        }

        applyDatePolicies()
        purchaseManager.start(monthISOs: purchasableMonthISOs())
        requestSync()
    }

    /// Mois dont l'image est achetable à l'unité (jusqu'au mois en cours)
    private func purchasableMonthISOs(now: Date = Date()) -> [String] {
        let current = DatePolicy.isoMonthString(for: now)
        return (catalog?.monthly.map(\.month) ?? []).filter { $0 <= current }
    }

    // MARK: - Sync

    /// Lance une synchronisation en arrière-plan (sans effet si déjà en cours ou non configurée)
    func requestSync() {
        Task { await syncService.syncNow() }
    }

    /// Œuvres échues -> "à finaliser", puis purge (daily toFinalize purgées le 4).
    /// Appelé au lancement et à chaque retour au premier plan (l'app peut rester ouverte après minuit).
    func applyDatePolicies(now: Date = Date()) {
        guard isReady, let engine, let catalog else { return }
        do {
            try engine.finalizeEndedArtworks(catalog: catalog, currentDate: now)
            try engine.enforcePurgePolicies(currentDate: now)
            try engine.grantPremiumMonthlyBoostersIfNeeded(
                isPremium: entitlements.isPremium,
                currentMonthISO: DatePolicy.isoMonthString(for: now)
            )
        } catch {
            self.loadingErrorMessage = "Erreur mise à jour des œuvres: \(error)"
        }
    }

    // MARK: - Premium

    /// Premium simulé (versions de développement uniquement, pour tester sans achat)
    func setDebugPremium(_ isActive: Bool) {
        entitlements.setDebugPremium(isActive)
    }

    // MARK: - Session Start

    enum SessionStartError: LocalizedError {
        case engineUnavailable
        case locked
        case quotaReached(minutes: Int)

        var errorDescription: String? {
            switch self {
            case .engineUnavailable:
                return "Moteur non disponible."
            case .locked:
                return "Cette œuvre n'est pas encore disponible."
            case .quotaReached(let minutes):
                return "Quota du jour atteint pour \(minutes) min. Essaie 25 ou 30 min."
            }
        }
    }

    /// Vérifie l'accès et le quota, puis enregistre le début de session.
    /// En cas de succès, l'appelant présente FocusSessionHostView.
    func startSession(artworkId: String, minutes: Int, now: Date = Date()) throws {
        guard let engine else { throw SessionStartError.engineUnavailable }
        guard canPlay(artworkId: artworkId, now: now) else { throw SessionStartError.locked }

        let todayISO = DatePolicy.isoDayString(for: now)
        let isPremium = entitlements.isPremium
        guard try engine.canStartSession(minutes: minutes, isPremium: isPremium, todayISO: todayISO) else {
            throw SessionStartError.quotaReached(minutes: minutes)
        }
        try engine.registerSessionStart(minutes: minutes, isPremium: isPremium, todayISO: todayISO)
    }

    // MARK: - Monthly Access

    /// Mois ISO d'une œuvre monthly du catalogue (nil si ce n'est pas une monthly)
    func monthlyMonthISO(forArtworkId artworkId: String) -> String? {
        catalog?.monthly.first(where: { $0.artworkId == artworkId })?.month
    }

    /// Date ISO d'une daily du catalogue (nil si ce n'est pas une daily)
    func dailyDateISO(forArtworkId artworkId: String) -> String? {
        catalog?.daily.first(where: { $0.artworkId == artworkId })?.date
    }

    /// Sessions terminées dans un mois (défi du mois)
    func completedSessions(monthISO: String) -> Int {
        (try? engine?.completedSessions(monthISO: monthISO)) ?? 0
    }

    /// Accès à une œuvre. Daily et weekly sont toujours accessibles; nil = pas une monthly.
    func monthlyAccess(forArtworkId artworkId: String, now: Date = Date()) -> MonthlyAccess? {
        guard let ruleset, let monthISO = monthlyMonthISO(forArtworkId: artworkId) else { return nil }
        return entitlements.monthlyAccess(
            artworkId: artworkId,
            monthISO: monthISO,
            completedSessionsInMonth: completedSessions(monthISO: monthISO),
            rules: ruleset.monthlyAccess,
            now: now
        )
    }

    /// Vrai si l'utilisateur peut jouer cette œuvre (sessions, boosters)
    /// - Daily: jouable de sa date jusqu'à la fin de son année (pas de daily future)
    /// - Weekly: jouable dès le lundi de sa semaine (pas de weekly future)
    /// - Monthly: selon MonthlyAccessPolicy (et pas de monthly future)
    func canPlay(artworkId: String, now: Date = Date()) -> Bool {
        let todayISO = DatePolicy.isoDayString(for: now)

        if let dailyDate = dailyDateISO(forArtworkId: artworkId) {
            return dailyDate <= todayISO && dailyDate.prefix(4) == todayISO.prefix(4)
        }
        if let weekly = catalog?.weekly.first(where: { $0.artworkId == artworkId }) {
            return weekly.startDate <= todayISO
        }
        if let monthISO = monthlyMonthISO(forArtworkId: artworkId) {
            guard monthISO <= DatePolicy.isoMonthString(for: now) else { return false }
            return monthlyAccess(forArtworkId: artworkId, now: now)?.isGranted ?? false
        }
        return true
    }

    // MARK: - Content Selection Helpers
    
    /// Retourne l'ID de l'œuvre daily du jour
    func todayDailyArtworkId() -> String? {
        guard let catalog else { return nil }
        let todayISO = DatePolicy.isoDayString(for: Date())
        return catalog.daily.first(where: { $0.date == todayISO })?.artworkId
    }

    /// Retourne l'ID de l'œuvre weekly en cours
    func currentWeeklyArtworkId() -> String? {
        guard let catalog else { return nil }
        let today = Date()

        for entry in catalog.weekly {
            if DateParsing.isDate(today, withinISOStart: entry.startDate, isoEnd: entry.endDate) {
                return entry.artworkId
            }
        }
        return nil
    }

    /// Retourne l'ID de l'œuvre monthly en cours
    func currentMonthlyArtworkId() -> String? {
        guard let catalog else { return nil }
        let monthISO = DateParsing.currentMonthISO(date: Date())
        return catalog.monthly.first(where: { $0.month == monthISO })?.artworkId
    }

    // MARK: - Import Helpers
    
    /// S'assure qu'une œuvre est importée dans SwiftData
    func ensureArtworkImported(artworkId: String) throws {
        guard let contentStore else { return }
        try contentStore.ensureArtworkImported(artworkId: artworkId)
    }
    
    // MARK: - Quota Helpers

    /// Retourne le nombre de sessions restantes pour une durée donnée.
    /// - Returns:
    ///   - nil si quota illimité
    ///   - sinon un Int >= 0
    func remainingQuota(for minutes: Int, isPremium: Bool) -> Int? {
        guard let ruleset else { return nil }

        let quotaProfile = isPremium ? ruleset.quotas.premium : ruleset.quotas.free
        let dailyMaxSessions = quotaProfile.dailyMaxByMinutes["\(minutes)"] ?? -1

        // -1 = illimité
        if dailyMaxSessions < 0 { return nil }

        let todayISO = DatePolicy.isoDayString(for: Date())

        do {
            let descriptor = FetchDescriptor<SDDailyQuota>(
                predicate: #Predicate { $0.dayISO == todayISO }
            )

            if let quota = try modelContext.fetch(descriptor).first {
                let usedSessionsForMinutes = (minutes == 15) ? quota.used15 : quota.used20
                return Swift.max(0, dailyMaxSessions - usedSessionsForMinutes)
            }

            // Aucun quota trouvé aujourd'hui -> 0 utilisé
            return dailyMaxSessions
        } catch {
            // En cas d'erreur, on renvoie une valeur safe
            return dailyMaxSessions
        }
    }

}

// MARK: - RulesetBox
/// Référence partagée vers les règles, chargées après la création des services
final class RulesetBox {
    var value: RulesetDTO?
}
