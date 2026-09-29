/*
 * RulesetDTO.swift
 * PixelFocus
 *
 * Version: 1.0
 * Date: 15 janvier 2026
 *
 * Modèles DTO pour décoder ruleset.json.
 *
 * Objectifs:
 * - Décoder les règles globales (sessions, quotas, tokens, streak, boosters, accès monthly, purge).
 * - Garder une séparation nette entre JSON (DTO) et persistance SwiftData.
 *
 * Notes:
 * - DTO = "Data Transfer Object" (lecture seule)
 * - Les valeurs "illimité" sont représentées par -1
 */

import Foundation

// MARK: - RulesetDTO
struct RulesetDTO: Codable {
    let contentVersion: Int
    let sessions: SessionsRulesDTO
    let quotas: QuotasRulesDTO
    let tokens: TokensRulesDTO
    let streak: StreakRulesDTO
    let boosters: BoostersRulesDTO
    let monthlyAccess: MonthlyAccessRulesDTO
    let finalizeRules: FinalizeRulesDTO
}

// MARK: - SessionsRulesDTO
struct SessionsRulesDTO: Codable {
    let defaultMinutes: Int
    let allowedMinutes: [Int]
    let pixelsPerCompletedSession: Int
    let over30: Over30RulesDTO
}

// MARK: - Over30RulesDTO
struct Over30RulesDTO: Codable {
    let enabled: Bool
    let dailyBonus: DailyBonusRulesDTO
}

struct DailyBonusRulesDTO: Codable {
    let extraMinutesStep: Int
    let grantPerStep: DailyBonusGrantDTO
    let dailyCap: DailyBonusCapDTO
    let expires: String
}

struct DailyBonusGrantDTO: Codable {
    let type: String
    let pixels: Int
}

struct DailyBonusCapDTO: Codable {
    let type: String
    let maxPixels: Int
}

// MARK: - QuotasRulesDTO
struct QuotasRulesDTO: Codable {
    let free: QuotaProfileDTO
    let premium: QuotaProfileDTO
}

struct QuotaProfileDTO: Codable {
    let dailyMaxByMinutes: [String: Int]
}

// MARK: - TokensRulesDTO
struct TokensRulesDTO: Codable {
    let protection: ProtectionTokenRulesDTO
}

struct ProtectionTokenRulesDTO: Codable {
    let grantOnCompletedMinutes: Int
    let grantAmount: Int
    let dailyCap: Int
    let useMode: String
}

// MARK: - StreakRulesDTO
struct StreakRulesDTO: Codable {
    let enabled: Bool
    let dailyCompletionRule: DailyCompletionRuleDTO
    let boosterRewards: [StreakBoosterRewardDTO]
}

struct DailyCompletionRuleDTO: Codable {
    let type: String
}

/// Tous les `everyConsecutiveDays` jours de série -> +`boosters`
struct StreakBoosterRewardDTO: Codable {
    let everyConsecutiveDays: Int
    let boosters: Int
}

// MARK: - BoostersRulesDTO
struct BoostersRulesDTO: Codable {
    /// Pixels révélés par booster
    let pixelsPerBooster: Int
    /// Stock maximum de boosters gagnés (les achetés ne sont pas plafonnés)
    let earnedCap: Int
    /// Boosters gagnés utilisables par jour (les achetés ne sont pas limités)
    let dailyEarnedUseLimit: BoosterUseLimitDTO
    /// Boosters offerts aux Premium au début de chaque mois
    let premiumMonthlyGrant: Int
}

struct BoosterUseLimitDTO: Codable {
    let free: Int
    let premium: Int
}

// MARK: - MonthlyAccessRulesDTO
struct MonthlyAccessRulesDTO: Codable {
    /// 1er lancement avant ce jour -> image du mois en cours offerte, sinon celle du mois suivant
    let welcomeCutoffDay: Int
    /// Sessions terminées dans le mois pour réussir le défi (gratuit)
    let challengeSessions: Int
    /// Premium: image du mois précédent jouable jusqu'à ce jour inclus
    let premiumPreviousMonthGraceDay: Int
    /// Progression au-delà de laquelle le prix réduit s'applique
    let reducedPriceProgressThreshold: Double
    /// Prix réduit jusqu'à ce jour inclus du mois suivant
    let reducedPriceUntilDayOfNextMonth: Int
}

// MARK: - FinalizeRulesDTO
struct FinalizeRulesDTO: Codable {
    let daily: DailyFinalizeRulesDTO
    let monthly: MonthlyFinalizeRulesDTO
}

struct DailyFinalizeRulesDTO: Codable {
    let moveToFinalizeIfNotCompleted: Bool
    /// Daily non terminées purgées ce jour de janvier de l'année suivante
    let purgeFinalizeOnJanuaryDayOfNextYear: Int
}

struct MonthlyFinalizeRulesDTO: Codable {
    let moveToFinalizeIfNotCompleted: Bool
    let purgePolicy: String
}
