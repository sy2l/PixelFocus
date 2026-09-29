/*
 * GameEngine.swift
 * PixelFocus
 *
 * Version: 1.0
 * Date: 15 janvier 2026
 *
 * Moteur de règles:
 * - Appliquer quotas 15/20 (gratuit) et premium illimité.
 * - Gérer reward: 1 session = 5 pixels.
 * - Streak (daily du jour terminée): boosters tous les 3 jours, +1 tous les 18 jours (cap 12).
 * - Boosters: 1 booster = 5 pixels; gagnés (limite/jour) puis achetés (sans limite).
 * - Défi du mois: compteur de sessions terminées par mois.
 * - Tokens: 30 min -> protection token (cap 3/jour), mode "resume remaining time".
 * - Bonus >30: dailyPixels (expire fin de journée, cap 10).
 * - Daily non finie -> toFinalize, jouable jusqu'à la fin de l'année.
 * - Weekly / Monthly -> toFinalize sans purge.
 */

import Foundation
import SwiftData

// MARK: - GameEngine
@MainActor
final class GameEngine {
    
    // MARK: - Properties
    private let modelContext: ModelContext
    private let rulesetProvider: () -> RulesetDTO?

    // MARK: - Init
    init(modelContext: ModelContext, rulesetProvider: @escaping () -> RulesetDTO?) {
        self.modelContext = modelContext
        self.rulesetProvider = rulesetProvider
    }

    // MARK: - Session Quota Management
    
    /// Vérifie si une session peut être démarrée (quota non atteint)
    func canStartSession(minutes: Int, isPremium: Bool, todayISO: String) throws -> Bool {
        guard let ruleset = rulesetProvider() else { return false }
        guard ruleset.sessions.allowedMinutes.contains(minutes) else { return false }

        // 25/30 sont illimités, 15/20 limités pour gratuit
        let profile = isPremium ? ruleset.quotas.premium : ruleset.quotas.free
        let max = profile.dailyMaxByMinutes["\(minutes)"] ?? -1
        if max < 0 { return true } // -1 = illimité

        let quota = try fetchOrCreateQuota(todayISO: todayISO)
        let used = (minutes == 15) ? quota.used15 : quota.used20
        return used < max
    }

    /// Enregistre le début d'une session (incrémente le quota)
    func registerSessionStart(minutes: Int, isPremium: Bool, todayISO: String) throws {
        guard let ruleset = rulesetProvider() else { return }
        let profile = isPremium ? ruleset.quotas.premium : ruleset.quotas.free
        let max = profile.dailyMaxByMinutes["\(minutes)"] ?? -1
        guard max >= 0 else { return } // Pas de quota à incrémenter si illimité

        let quota = try fetchOrCreateQuota(todayISO: todayISO)
        if minutes == 15 { quota.used15 += 1 }
        if minutes == 20 { quota.used20 += 1 }
        try modelContext.save()
    }

    // MARK: - Session Completion
    
    /// Applique les récompenses d'une session terminée
    /// - dailyDateISO: date de la daily si l'œuvre est une daily (nil sinon). La série ne compte
    ///   que si c'est la daily du jour qui est terminée.
    func applyCompletedSession(
        artworkId: String,
        minutes: Int,
        todayISO: String,
        dailyDateISO: String?,
        didExceed30By extraMinutes: Int
    ) throws {
        guard let ruleset = rulesetProvider() else { return }

        // 1) Progress: +5 pixels (+ complétion + série)
        try revealPixels(
            artworkId: artworkId,
            count: ruleset.sessions.pixelsPerCompletedSession,
            todayISO: todayISO,
            dailyDateISO: dailyDateISO,
            ruleset: ruleset
        )

        // 2) Token protection si 30min
        if minutes == ruleset.tokens.protection.grantOnCompletedMinutes {
            try grantProtectionTokenIfPossible(todayISO: todayISO)
        }

        // 3) Bonus >30 (dailyPixels)
        if ruleset.sessions.over30.enabled, extraMinutes > 0 {
            try applyOver30DailyBonus(extraMinutes: extraMinutes, todayISO: todayISO, ruleset: ruleset)
        }

        // 4) Défi du mois: compteur de sessions terminées dans le mois
        let stats = try fetchOrCreateMonthStats(monthISO: DateParsing.monthFromISODay(todayISO) ?? todayISO)
        stats.completedSessions += 1

        try modelContext.save()
    }

    // MARK: - Boosters

    enum BoosterError: LocalizedError {
        case noneAvailable
        case artworkAlreadyCompleted

        var errorDescription: String? {
            switch self {
            case .noneAvailable:
                return "Aucun booster utilisable aujourd'hui."
            case .artworkAlreadyCompleted:
                return "Cette œuvre est déjà terminée."
            }
        }
    }

    /// Nombre de boosters utilisables maintenant (gagnés dans la limite du jour + achetés).
    /// Lecture seule: peut être appelé pendant le rendu d'une vue.
    func usableBoosters(isPremium: Bool, todayISO: String) throws -> Int {
        guard let ruleset = rulesetProvider(),
              let wallet = try modelContext.fetch(FetchDescriptor<SDWallet>()).first else { return 0 }

        let limit = BoosterPolicy.dailyEarnedLimit(isPremium: isPremium, rules: ruleset.boosters)
        let usedToday = wallet.earnedBoostersUsedDayISO == todayISO ? wallet.earnedBoostersUsedToday : 0
        let earnedUsable = max(0, min(wallet.earnedBoosters, limit - usedToday))
        return earnedUsable + wallet.purchasedBoosters
    }

    /// Utilise un booster sur une œuvre (l'accès à l'œuvre est vérifié par l'appelant).
    /// - Returns: le stock consommé (gagné ou acheté)
    @discardableResult
    func useBooster(
        artworkId: String,
        isPremium: Bool,
        todayISO: String,
        dailyDateISO: String?
    ) throws -> BoosterSource {
        guard let ruleset = rulesetProvider() else { throw BoosterError.noneAvailable }

        let progress = try fetchOrCreateProgress(artworkId: artworkId)
        guard progress.state != .completed else { throw BoosterError.artworkAlreadyCompleted }

        let wallet = try fetchOrCreateWallet()
        wallet.resetDailyIfNeeded(todayISO: todayISO)

        guard let source = BoosterPolicy.nextSource(
            earned: wallet.earnedBoosters,
            purchased: wallet.purchasedBoosters,
            earnedUsedToday: wallet.earnedBoostersUsedToday,
            dailyEarnedLimit: BoosterPolicy.dailyEarnedLimit(isPremium: isPremium, rules: ruleset.boosters)
        ) else {
            throw BoosterError.noneAvailable
        }

        switch source {
        case .earned:
            wallet.earnedBoosters -= 1
            wallet.earnedBoostersUsedToday += 1
        case .purchased:
            wallet.purchasedBoosters -= 1
        }

        try revealPixels(
            artworkId: artworkId,
            count: ruleset.boosters.pixelsPerBooster,
            todayISO: todayISO,
            dailyDateISO: dailyDateISO,
            ruleset: ruleset
        )

        try modelContext.save()
        return source
    }

    /// Premium: +N boosters gagnés au début de chaque mois (une fois par mois).
    func grantPremiumMonthlyBoostersIfNeeded(isPremium: Bool, currentMonthISO: String) throws {
        guard isPremium, let ruleset = rulesetProvider() else { return }
        let wallet = try fetchOrCreateWallet()
        guard BoosterPolicy.shouldGrantPremiumMonthly(
            lastGrantMonthISO: wallet.premiumGrantMonthISO,
            currentMonthISO: currentMonthISO
        ) else { return }

        wallet.earnedBoosters = BoosterPolicy.addingEarned(
            current: wallet.earnedBoosters,
            amount: ruleset.boosters.premiumMonthlyGrant,
            cap: ruleset.boosters.earnedCap
        )
        wallet.premiumGrantMonthISO = currentMonthISO
        try modelContext.save()
    }

    // MARK: - Month Stats

    /// Sessions terminées dans le mois (défi du mois)
    func completedSessions(monthISO: String) throws -> Int {
        let descriptor = FetchDescriptor<SDMonthStats>(
            predicate: #Predicate { $0.monthISO == monthISO }
        )
        return try modelContext.fetch(descriptor).first?.completedSessions ?? 0
    }

    // MARK: - Reveal

    /// Révèle des pixels sur une œuvre, marque la complétion et met à jour la série
    /// si la daily du jour vient d'être terminée. Ne sauvegarde pas (l'appelant sauvegarde).
    private func revealPixels(
        artworkId: String,
        count: Int,
        todayISO: String,
        dailyDateISO: String?,
        ruleset: RulesetDTO
    ) throws {
        let progress = try fetchOrCreateProgress(artworkId: artworkId)
        let wasCompleted = progress.state == .completed

        progress.revealedCount += count
        progress.updatedAt = Date()

        if let totalPixels = try fetchArtworkTotalPixels(artworkId: artworkId),
           progress.revealedCount >= totalPixels {
            progress.state = .completed
        }

        // Série: uniquement quand la daily DU JOUR passe à "terminée"
        if !wasCompleted,
           progress.state == .completed,
           let dailyDateISO,
           dailyDateISO == todayISO {
            try updateStreakOnDailyCompleted(todayISO: todayISO, ruleset: ruleset)
        }
    }

    // MARK: - Finalize & Purge Policies

    /// Passe en "toFinalize" les œuvres commencées mais non terminées dont la période est échue:
    /// - daily: le jour est passé
    /// - weekly: la semaine est terminée
    /// - monthly: le mois est terminé
    /// Renseigne aussi la date/mois de l'œuvre sur la progression (utilisé par la purge et l'UI).
    func finalizeEndedArtworks(catalog: CatalogDTO, currentDate: Date) throws {
        for entry in catalog.daily where DatePolicy.isDayISO(entry.date, before: currentDate) {
            try moveToFinalizeIfUnfinished(artworkId: entry.artworkId) { progress in
                progress.artworkDateISO = entry.date
            }
        }

        for entry in catalog.weekly where DatePolicy.isDayISO(entry.endDate, before: currentDate) {
            try moveToFinalizeIfUnfinished(artworkId: entry.artworkId) { progress in
                progress.artworkDateISO = entry.startDate
            }
        }

        for entry in catalog.monthly where DatePolicy.isMonthISO(entry.month, before: currentDate) {
            try moveToFinalizeIfUnfinished(artworkId: entry.artworkId) { progress in
                progress.artworkMonthISO = entry.month
            }
        }

        try modelContext.save()
    }

    /// Applique les politiques de purge (daily toFinalize purgées en janvier de l'année suivante).
    /// Weekly et monthly ne sont jamais purgées.
    func enforcePurgePolicies(currentDate: Date) throws {
        guard let ruleset = rulesetProvider() else { return }
        let januaryDay = ruleset.finalizeRules.daily.purgeFinalizeOnJanuaryDayOfNextYear

        let toFinalizeRaw = ProgressState.toFinalize.rawValue
        let allToFinalize = try modelContext.fetch(
            FetchDescriptor<SDProgress>(predicate: #Predicate { $0.stateRaw == toFinalizeRaw })
        )

        for progress in allToFinalize {
            guard let artwork = try fetchArtwork(artworkId: progress.artworkId),
                  artwork.mode == "daily",
                  let dateISO = progress.artworkDateISO else { continue }

            if DatePolicy.shouldPurgeDailyFinalize(
                dailyDateISO: dateISO,
                currentDate: currentDate,
                januaryDay: januaryDay
            ) {
                modelContext.delete(progress)
            }
        }
        try modelContext.save()
    }

    /// Passe une progression existante "active" et incomplète en "toFinalize".
    /// Une œuvre jamais commencée n'a pas de progression: rien à faire.
    private func moveToFinalizeIfUnfinished(
        artworkId: String,
        annotate: (SDProgress) -> Void
    ) throws {
        let descriptor = FetchDescriptor<SDProgress>(
            predicate: #Predicate { $0.artworkId == artworkId }
        )
        guard let progress = try modelContext.fetch(descriptor).first,
              progress.state == .active,
              let totalPixels = try fetchArtworkTotalPixels(artworkId: artworkId),
              progress.revealedCount < totalPixels else { return }

        annotate(progress)
        progress.state = .toFinalize
        progress.updatedAt = Date()
    }

    // MARK: - Protection Token Helpers
    
    /// Vérifie si un token de protection est disponible
    func canUseProtectionToken(todayISO: String) throws -> Bool {
        let wallet = try fetchOrCreateWallet()
        wallet.resetDailyIfNeeded(todayISO: todayISO)
        return wallet.protectionTokensAvailable > 0
    }
    
    /// Consomme un token de protection
    func consumeProtectionToken(todayISO: String) throws {
        let wallet = try fetchOrCreateWallet()
        wallet.resetDailyIfNeeded(todayISO: todayISO)
        if wallet.protectionTokensAvailable > 0 {
            wallet.protectionTokensAvailable -= 1
            try modelContext.save()
        }
    }

    // MARK: - Private Helpers
    
    private func grantProtectionTokenIfPossible(todayISO: String) throws {
        guard let ruleset = rulesetProvider() else { return }
        let wallet = try fetchOrCreateWallet()
        
        wallet.resetDailyIfNeeded(todayISO: todayISO)
        
        let dailyCap = ruleset.tokens.protection.dailyCap
        if wallet.protectionTokensEarnedToday < dailyCap {
            wallet.protectionTokensAvailable += ruleset.tokens.protection.grantAmount
            wallet.protectionTokensEarnedToday += 1
        }
    }

    private func applyOver30DailyBonus(extraMinutes: Int, todayISO: String, ruleset: RulesetDTO) throws {
        let wallet = try fetchOrCreateWallet()
        wallet.resetDailyIfNeeded(todayISO: todayISO)
        
        let bonus = ruleset.sessions.over30.dailyBonus
        let pixelsToAdd = (extraMinutes / bonus.extraMinutesStep) * bonus.grantPerStep.pixels
        let maxPixels = bonus.dailyCap.maxPixels
        
        let newTotal = min(wallet.dailyBonusPixelsAvailable + pixelsToAdd, maxPixels)
        wallet.dailyBonusPixelsAvailable = newTotal
    }

    private func updateStreakOnDailyCompleted(todayISO: String, ruleset: RulesetDTO) throws {
        guard ruleset.streak.enabled else { return }
        
        let streak = try fetchOrCreateStreak()

        // Déjà compté aujourd'hui: pas de double incrément ni de double récompense
        if streak.lastCompletedDayISO == todayISO { return }

        // Vérifie si c'est un jour consécutif
        if let lastDay = streak.lastCompletedDayISO,
           let lastDate = DateParsing.dateFromISODay(lastDay),
           let todayDate = DateParsing.dateFromISODay(todayISO),
           DatePolicy.isYesterday(lastDate, relativeTo: todayDate) {
            streak.current += 1
        } else {
            // Premier jour ou série cassée
            streak.current = 1
        }

        streak.lastCompletedDayISO = todayISO
        streak.updateLongestIfNeeded()

        // Historique des jours actifs + badges
        try recordActiveDayAndUnlockBadges(todayISO: todayISO)

        // Récompense en boosters (tous les 3 jours, +1 tous les 18 jours)
        let reward = BoosterPolicy.streakReward(streakDay: streak.current, rewards: ruleset.streak.boosterRewards)
        if reward > 0 {
            let wallet = try fetchOrCreateWallet()
            wallet.earnedBoosters = BoosterPolicy.addingEarned(
                current: wallet.earnedBoosters,
                amount: reward,
                cap: ruleset.boosters.earnedCap
            )
        }
    }

    /// Enregistre le jour actif et débloque les nouveaux badges (voir BadgePolicy).
    private func recordActiveDayAndUnlockBadges(todayISO: String) throws {
        let dayDescriptor = FetchDescriptor<SDActiveDay>(
            predicate: #Predicate { $0.dayISO == todayISO }
        )
        if try modelContext.fetch(dayDescriptor).isEmpty {
            modelContext.insert(SDActiveDay(dayISO: todayISO))
        }

        var activeDays = Set(try modelContext.fetch(FetchDescriptor<SDActiveDay>()).map(\.dayISO))
        activeDays.insert(todayISO)

        let ownedBadgeIds = Set(try modelContext.fetch(FetchDescriptor<SDBadge>()).map(\.badgeId))
        for badgeId in BadgePolicy.earnedBadgeIds(activeDays: activeDays) where !ownedBadgeIds.contains(badgeId) {
            modelContext.insert(SDBadge(badgeId: badgeId))
        }
    }

    private func fetchOrCreateMonthStats(monthISO: String) throws -> SDMonthStats {
        let descriptor = FetchDescriptor<SDMonthStats>(
            predicate: #Predicate { $0.monthISO == monthISO }
        )
        if let existing = try modelContext.fetch(descriptor).first {
            return existing
        }
        let created = SDMonthStats(monthISO: monthISO)
        modelContext.insert(created)
        return created
    }

    // MARK: - Fetch/Create Helpers
    
    private func fetchOrCreateQuota(todayISO: String) throws -> SDDailyQuota {
        let descriptor = FetchDescriptor<SDDailyQuota>(
            predicate: #Predicate { $0.dayISO == todayISO }
        )
        if let existing = try modelContext.fetch(descriptor).first {
            return existing
        }
        let created = SDDailyQuota(dayISO: todayISO)
        modelContext.insert(created)
        return created
    }

    private func fetchOrCreateProgress(artworkId: String) throws -> SDProgress {
        let descriptor = FetchDescriptor<SDProgress>(
            predicate: #Predicate { $0.artworkId == artworkId }
        )
        if let existing = try modelContext.fetch(descriptor).first {
            return existing
        }
        let created = SDProgress(artworkId: artworkId)
        modelContext.insert(created)
        return created
    }

    private func fetchOrCreateWallet() throws -> SDWallet {
        let descriptor = FetchDescriptor<SDWallet>()
        if let existing = try modelContext.fetch(descriptor).first {
            return existing
        }
        let created = SDWallet()
        modelContext.insert(created)
        return created
    }

    private func fetchOrCreateStreak() throws -> SDStreak {
        let descriptor = FetchDescriptor<SDStreak>()
        if let existing = try modelContext.fetch(descriptor).first {
            return existing
        }
        let created = SDStreak()
        modelContext.insert(created)
        return created
    }

    private func fetchArtwork(artworkId: String) throws -> SDArtwork? {
        let descriptor = FetchDescriptor<SDArtwork>(
            predicate: #Predicate { $0.artworkId == artworkId }
        )
        return try modelContext.fetch(descriptor).first
    }

    private func fetchArtworkTotalPixels(artworkId: String) throws -> Int? {
        guard let artwork = try fetchArtwork(artworkId: artworkId) else { return nil }
        return artwork.totalPixels
    }
}
