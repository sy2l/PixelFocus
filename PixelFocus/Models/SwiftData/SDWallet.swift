/*
 * SDWallet.swift
 * PixelFocus
 *
 * Portefeuille de bonus: boosters + tokens.
 *
 * Objectifs:
 * - Stocker les boosters gagnés (cap, limite d'usage/jour) et achetés (sans limite).
 * - Stocker les protection tokens (cap journalier appliqué côté engine).
 * - Gérer les bonus journaliers (>30 min).
 *
 * Note:
 * - Remplace l'ancien système de "pixels stockés" (bankedPixels), supprimé (voir GAME_DESIGN.md §3).
 * - Les nouvelles propriétés ont une valeur par défaut pour la migration SwiftData automatique.
 */

import Foundation
import SwiftData

// MARK: - SDWallet
@Model
final class SDWallet {
    /// Boosters gagnés en jouant (série, octroi Premium) — plafonnés, limite d'usage par jour
    var earnedBoosters: Int = 0

    /// Boosters achetés — ni plafond, ni limite d'usage, ni expiration
    var purchasedBoosters: Int = 0

    /// Jour ISO du compteur d'usage des boosters gagnés
    var earnedBoostersUsedDayISO: String?

    /// Boosters gagnés utilisés ce jour-là
    var earnedBoostersUsedToday: Int = 0

    /// Dernier mois ISO où l'octroi mensuel Premium a été fait
    var premiumGrantMonthISO: String?

    /// Tokens de protection disponibles
    var protectionTokensAvailable: Int = 0

    /// Jour ISO où les tokens ont été gagnés (pour le cap journalier)
    var protectionTokensEarnedDayISO: String?

    /// Nombre de tokens gagnés aujourd'hui (cap 3/jour)
    var protectionTokensEarnedToday: Int = 0

    /// Pixels bonus journaliers (gagnés via sessions >30 min)
    var dailyBonusPixelsAvailable: Int = 0

    /// Jour ISO des bonus (expire fin de journée)
    var dailyBonusPixelsDayISO: String?

    init() {}

    // MARK: - Computed

    var totalBoosters: Int {
        earnedBoosters + purchasedBoosters
    }

    // MARK: - Methods

    /// Réinitialise les compteurs journaliers si le jour a changé
    func resetDailyIfNeeded(todayISO: String) {
        // Reset protection tokens earned today
        if protectionTokensEarnedDayISO != todayISO {
            protectionTokensEarnedDayISO = todayISO
            protectionTokensEarnedToday = 0
        }

        // Reset daily bonus pixels (ils expirent fin de journée)
        if dailyBonusPixelsDayISO != todayISO {
            dailyBonusPixelsDayISO = todayISO
            dailyBonusPixelsAvailable = 0
        }

        // Reset usage quotidien des boosters gagnés
        if earnedBoostersUsedDayISO != todayISO {
            earnedBoostersUsedDayISO = todayISO
            earnedBoostersUsedToday = 0
        }
    }
}
