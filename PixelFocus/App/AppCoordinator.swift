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

// MARK: - AppCoordinator
@MainActor
final class AppCoordinator: ObservableObject {

    // MARK: - Published State
    @Published private(set) var isReady: Bool = false
    @Published private(set) var loadingErrorMessage: String?

    @Published private(set) var ruleset: RulesetDTO?
    @Published private(set) var catalog: CatalogDTO?

    // MARK: - Dependencies
    private var modelContext: ModelContext?
    private let jsonLoader: JSONContentLoader = JSONContentLoader()

    // Long-term scalable services
    private var contentStore: ContentStore?
    private var engine: GameEngine?
    private var sessionManager: SessionManager?

    // MARK: - Public Accessors
    
    func getEngine() -> GameEngine? { engine }
    func getSessionManager() -> SessionManager? { sessionManager }
    func getContentStore() -> ContentStore? { contentStore }

    // MARK: - Setup
    
    /// Configure le coordinateur avec le ModelContext SwiftData
    func configure(modelContext: ModelContext) {
        // Configure une seule fois
        if self.modelContext != nil { return }
        self.modelContext = modelContext

        let store = ContentStore(loader: jsonLoader, modelContext: modelContext)
        self.contentStore = store

        let gameEngine = GameEngine(modelContext: modelContext, rulesetProvider: { [weak self] in
            self?.ruleset
        })
        self.engine = gameEngine

        self.sessionManager = SessionManager()
    }

    /// Charge le contenu initial si nécessaire
    func loadInitialContentIfNeeded() {
        guard let contentStore, engine != nil else { return }
        guard !isReady else { return }

        do {
            try contentStore.loadInitialContent()
            self.ruleset = contentStore.ruleset
            self.catalog = contentStore.catalog

            self.isReady = true
            self.loadingErrorMessage = nil
        } catch {
            self.loadingErrorMessage = "Erreur chargement contenu: \(error)"
            self.isReady = false
            return
        }

        applyDatePolicies()
    }

    /// Œuvres échues -> "à finaliser", puis purge (daily toFinalize purgées le 4).
    /// Appelé au lancement et à chaque retour au premier plan (l'app peut rester ouverte après minuit).
    func applyDatePolicies(now: Date = Date()) {
        guard isReady, let engine, let catalog else { return }
        do {
            try engine.finalizeEndedArtworks(catalog: catalog, currentDate: now)
            try engine.enforcePurgePolicies(currentDate: now)
        } catch {
            self.loadingErrorMessage = "Erreur mise à jour des œuvres: \(error)"
        }
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
    
    /// Vérifie si l'œuvre monthly est premium
    func isMonthlyPremium() -> Bool {
        guard let catalog else { return false }
        let monthISO = DateParsing.currentMonthISO(date: Date())
        return catalog.monthly.first(where: { $0.month == monthISO })?.isPremium ?? false
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
        guard let ruleset, let modelContext else { return nil }

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
