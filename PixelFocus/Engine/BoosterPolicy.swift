/*
 * BoosterPolicy.swift
 * PixelFocus
 *
 * Règles pures des boosters (voir GAME_DESIGN.md §3).
 *
 * - 1 booster = N pixels révélés sur une œuvre accessible.
 * - Série: +1 booster tous les 3 jours, +1 supplémentaire tous les 18 jours.
 * - Deux stocks: gagnés (cap, limite d'usage par jour) et achetés (sans limite).
 * - Premium: +2 boosters gagnés au début de chaque mois.
 *
 * Aucune dépendance SwiftData: testable unitairement.
 */

import Foundation

// MARK: - BoosterSource
enum BoosterSource: Equatable {
    case earned
    case purchased
}

// MARK: - BoosterPolicy
enum BoosterPolicy {

    /// Boosters gagnés le jour où la série atteint `streakDay` jours consécutifs.
    /// Ex: règles [3 -> 1, 18 -> 1] : jour 3 = 1, jour 6 = 1, jour 18 = 2, jour 36 = 2.
    static func streakReward(streakDay: Int, rewards: [StreakBoosterRewardDTO]) -> Int {
        guard streakDay > 0 else { return 0 }
        return rewards
            .filter { $0.everyConsecutiveDays > 0 && streakDay % $0.everyConsecutiveDays == 0 }
            .reduce(0) { $0 + $1.boosters }
    }

    /// Ajoute des boosters gagnés en respectant le cap (sans jamais retirer ce qui est déjà détenu).
    static func addingEarned(current: Int, amount: Int, cap: Int) -> Int {
        guard amount > 0 else { return current }
        return max(current, min(cap, current + amount))
    }

    /// Stock à utiliser pour le prochain booster, ou nil si aucun n'est utilisable.
    /// Les gagnés d'abord (dans la limite du jour), puis les achetés (sans limite).
    static func nextSource(
        earned: Int,
        purchased: Int,
        earnedUsedToday: Int,
        dailyEarnedLimit: Int
    ) -> BoosterSource? {
        if earned > 0 && earnedUsedToday < dailyEarnedLimit {
            return .earned
        }
        if purchased > 0 {
            return .purchased
        }
        return nil
    }

    /// Limite quotidienne d'usage des boosters gagnés selon le statut.
    static func dailyEarnedLimit(isPremium: Bool, rules: BoostersRulesDTO) -> Int {
        isPremium ? rules.dailyEarnedUseLimit.premium : rules.dailyEarnedUseLimit.free
    }

    /// Vrai si l'octroi mensuel Premium n'a pas encore été fait pour ce mois.
    static func shouldGrantPremiumMonthly(lastGrantMonthISO: String?, currentMonthISO: String) -> Bool {
        lastGrantMonthISO != currentMonthISO
    }
}
