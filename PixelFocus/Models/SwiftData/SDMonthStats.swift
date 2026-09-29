/*
 * SDMonthStats.swift
 * PixelFocus
 *
 * Statistiques par mois.
 *
 * Objectifs:
 * - Compter les sessions terminées dans le mois (défi du mois, voir GAME_DESIGN.md §2.1 bis).
 */

import Foundation
import SwiftData

// MARK: - SDMonthStats
@Model
final class SDMonthStats {
    @Attribute(.unique) var monthISO: String   // "YYYY-MM"
    var completedSessions: Int = 0

    init(monthISO: String, completedSessions: Int = 0) {
        self.monthISO = monthISO
        self.completedSessions = completedSessions
    }
}
