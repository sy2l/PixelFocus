/*
 * SDWallet.swift
 * PixelFocus
 *
 * Version: 1.0
 * Date: 15 janvier 2026
 *
 * Portefeuille de bonus: bankedPixels + tokens.
 *
 * Objectifs:
 * - Stocker les pixels bankés (cap 5).
 * - Stocker les protection tokens (cap journalier appliqué côté engine).
 * - Gérer les bonus journaliers (>30 min).
 */

import Foundation
import SwiftData

// MARK: - SDWallet
@Model
final class SDWallet {
    /// Pixels stockables (gagnés via streak, utilisables sur n'importe quelle œuvre)
    var bankedPixels: Int

    /// Tokens de protection disponibles
    var protectionTokensAvailable: Int
    
    /// Jour ISO où les tokens ont été gagnés (pour le cap journalier)
    var protectionTokensEarnedDayISO: String?
    
    /// Nombre de tokens gagnés aujourd'hui (cap 3/jour)
    var protectionTokensEarnedToday: Int

    /// Pixels bonus journaliers (gagnés via sessions >30 min)
    var dailyBonusPixelsAvailable: Int
    
    /// Jour ISO des bonus (expire fin de journée)
    var dailyBonusPixelsDayISO: String?

    init(
        bankedPixels: Int = 0,
        protectionTokensAvailable: Int = 0,
        protectionTokensEarnedDayISO: String? = nil,
        protectionTokensEarnedToday: Int = 0,
        dailyBonusPixelsAvailable: Int = 0,
        dailyBonusPixelsDayISO: String? = nil
    ) {
        self.bankedPixels = bankedPixels
        self.protectionTokensAvailable = protectionTokensAvailable
        self.protectionTokensEarnedDayISO = protectionTokensEarnedDayISO
        self.protectionTokensEarnedToday = protectionTokensEarnedToday
        self.dailyBonusPixelsAvailable = dailyBonusPixelsAvailable
        self.dailyBonusPixelsDayISO = dailyBonusPixelsDayISO
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
    }
}
