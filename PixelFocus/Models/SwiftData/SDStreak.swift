/*
 * SDStreak.swift
 * PixelFocus
 *
 * Version: 1.0
 * Date: 15 janvier 2026
 *
 * Modèle SwiftData pour le streak.
 *
 * Objectifs:
 * - Compter les jours consécutifs de completion Daily.
 * - Déclencher la récompense (tous les 5 jours) côté engine.
 */

import Foundation
import SwiftData

// MARK: - SDStreak
@Model
final class SDStreak {
    var current: Int
    var lastCompletedDayISO: String?   // "YYYY-MM-DD"
    var longestStreak: Int             // Record personnel

    init(
        current: Int = 0,
        lastCompletedDayISO: String? = nil,
        longestStreak: Int = 0
    ) {
        self.current = current
        self.lastCompletedDayISO = lastCompletedDayISO
        self.longestStreak = longestStreak
    }
    
    // MARK: - Methods
    
    /// Met à jour le record si le streak actuel est plus long
    func updateLongestIfNeeded() {
        if current > longestStreak {
            longestStreak = current
        }
    }
}
