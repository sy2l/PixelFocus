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
 * - Streak: tous les 5 jours -> +5 bankedPixels (cap 5).
 * - Tokens: 30 min -> protection token (cap 3/jour), mode "resume remaining time".
 * - Bonus >30: dailyPixels (expire fin de journée, cap 10).
 * - Daily non finie -> toFinalize jusqu'au 4 du mois suivant.
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
    func applyCompletedSession(
        artworkId: String,
        minutes: Int,
        todayISO: String,
        isDaily: Bool,
        didExceed30By extraMinutes: Int
    ) throws {
        guard let ruleset = rulesetProvider() else { return }

        // 1) Progress: +5 pixels
        let progress = try fetchOrCreateProgress(artworkId: artworkId)
        progress.revealedCount += ruleset.sessions.pixelsPerCompletedSession
        progress.updatedAt = Date()

        // 2) Token protection si 30min
        if minutes == ruleset.tokens.protection.grantOnCompletedMinutes {
            try grantProtectionTokenIfPossible(todayISO: todayISO)
        }

        // 3) Bonus >30 (dailyPixels)
        if ruleset.sessions.over30.enabled, extraMinutes > 0 {
            try applyOver30DailyBonus(extraMinutes: extraMinutes, todayISO: todayISO, ruleset: ruleset)
        }

        // 4) Vérification de complétion (basée sur le total de pixels de l'œuvre)
        if let totalPixels = try fetchArtworkTotalPixels(artworkId: artworkId) {
            if progress.revealedCount >= totalPixels {
                progress.state = .completed
            }
        }

        // 5) Streak: uniquement quand une Daily est complétée
        if isDaily, progress.state == .completed {
            try updateStreakOnDailyCompleted(todayISO: todayISO, ruleset: ruleset)
        }

        try modelContext.save()
    }

    // MARK: - Banked Pixels
    
    /// Dépense des pixels stockés sur une œuvre
    func spendBankedPixels(artworkId: String, amount: Int) throws {
        guard let ruleset = rulesetProvider() else { return }
        guard ruleset.banks.bankedPixels.enabled else { return }
        
        let wallet = try fetchOrCreateWallet()
        let toSpend = min(amount, wallet.bankedPixels)
        guard toSpend > 0 else { return }
        
        wallet.bankedPixels -= toSpend
        
        let progress = try fetchOrCreateProgress(artworkId: artworkId)
        progress.revealedCount += toSpend * ruleset.banks.bankedPixels.spendEffect.pixels
        progress.updatedAt = Date()
        
        // Vérification de complétion
        if let totalPixels = try fetchArtworkTotalPixels(artworkId: artworkId) {
            if progress.revealedCount >= totalPixels {
                progress.state = .completed
            }
        }
        
        try modelContext.save()
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

    /// Applique les politiques de purge (daily toFinalize purgées le 4 du mois suivant).
    /// Weekly et monthly ne sont jamais purgées.
    func enforcePurgePolicies(currentDate: Date) throws {
        guard let ruleset = rulesetProvider() else { return }
        let purgeDay = ruleset.finalizeRules.daily.purgeFinalizeOnDayOfNextMonth

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
                purgeDay: purgeDay
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
        
        // Vérifie si c'est un jour consécutif
        if let lastDay = streak.lastCompletedDayISO {
            if let lastDate = DateParsing.dateFromISODay(lastDay),
               let todayDate = DateParsing.dateFromISODay(todayISO) {
                if DatePolicy.isYesterday(lastDate, relativeTo: todayDate) {
                    // Jour consécutif
                    streak.current += 1
                } else if !DatePolicy.isSameDay(lastDate, todayDate) {
                    // Pas consécutif, reset
                    streak.current = 1
                }
                // Si même jour, on ne fait rien
            }
        } else {
            // Premier jour
            streak.current = 1
        }
        
        streak.lastCompletedDayISO = todayISO
        streak.updateLongestIfNeeded()
        
        // Récompense tous les X jours consécutifs
        let rewardEvery = ruleset.streak.rewardEveryConsecutiveDays
        if streak.current > 0 && streak.current % rewardEvery == 0 {
            try grantStreakReward(ruleset: ruleset)
        }
    }
    
    private func grantStreakReward(ruleset: RulesetDTO) throws {
        let wallet = try fetchOrCreateWallet()
        let reward = ruleset.streak.reward.pixels
        let cap = ruleset.banks.bankedPixels.cap
        
        wallet.bankedPixels = min(wallet.bankedPixels + reward, cap)
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
