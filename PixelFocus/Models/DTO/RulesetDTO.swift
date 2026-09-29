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
 * - Décoder les règles globales (sessions, quotas, tokens, streak, purge).
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
    let banks: BanksRulesDTO
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
    let rewardEveryConsecutiveDays: Int
    let reward: BankedPixelsRewardDTO
    let bankCap: Int
}

struct DailyCompletionRuleDTO: Codable {
    let type: String
}

struct BankedPixelsRewardDTO: Codable {
    let type: String
    let pixels: Int
}

// MARK: - BanksRulesDTO
struct BanksRulesDTO: Codable {
    let bankedPixels: BankedPixelsBankDTO
}

struct BankedPixelsBankDTO: Codable {
    let enabled: Bool
    let cap: Int
    let spendEffect: SpendEffectDTO
    let canSpendOnModes: [String]
}

struct SpendEffectDTO: Codable {
    let type: String
    let pixels: Int
}

// MARK: - FinalizeRulesDTO
struct FinalizeRulesDTO: Codable {
    let daily: DailyFinalizeRulesDTO
    let monthly: MonthlyFinalizeRulesDTO
}

struct DailyFinalizeRulesDTO: Codable {
    let moveToFinalizeIfNotCompleted: Bool
    let purgeFinalizeOnDayOfNextMonth: Int
}

struct MonthlyFinalizeRulesDTO: Codable {
    let moveToFinalizeIfNotCompleted: Bool
    let purgePolicy: String
    let purchaseAvailableUntilMonth: Int
}
