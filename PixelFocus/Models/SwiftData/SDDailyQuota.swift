/*
 * SDDailyQuota.swift
 * PixelFocus
 *
 * Version: 1.0
 * Date: 15 janvier 2026
 *
 * Quotas d'utilisation journalière (gratuit).
 *
 * Objectifs:
 * - Appliquer: 15min = 1/jour, 20min = 1/jour.
 * - Reset automatique chaque jour.
 */

import Foundation
import SwiftData

// MARK: - SDDailyQuota
@Model
final class SDDailyQuota {
    var dayISO: String          // "YYYY-MM-DD"
    var used15: Int             // Nombre de sessions 15 min utilisées
    var used20: Int             // Nombre de sessions 20 min utilisées

    init(
        dayISO: String,
        used15: Int = 0,
        used20: Int = 0
    ) {
        self.dayISO = dayISO
        self.used15 = used15
        self.used20 = used20
    }
    
    // MARK: - Methods
    
    /// Vérifie si le quota pour une durée donnée est atteint
    func isQuotaReached(for minutes: Int, maxAllowed: Int) -> Bool {
        guard maxAllowed >= 0 else { return false } // -1 = illimité
        
        switch minutes {
        case 15:
            return used15 >= maxAllowed
        case 20:
            return used20 >= maxAllowed
        default:
            return false // 25 et 30 sont illimités
        }
    }
    
    /// Incrémente le compteur pour une durée donnée
    func incrementUsage(for minutes: Int) {
        switch minutes {
        case 15:
            used15 += 1
        case 20:
            used20 += 1
        default:
            break // 25 et 30 ne sont pas limités
        }
    }
}
