/*
 * SDActiveDay.swift
 * PixelFocus
 *
 * Jour "actif": la daily de ce jour a été terminée le jour même.
 *
 * Objectifs:
 * - Historique pour les badges de régularité (semaine / mois parfaits, régularité sur 3 mois).
 */

import Foundation
import SwiftData

// MARK: - SDActiveDay
@Model
final class SDActiveDay {
    @Attribute(.unique) var dayISO: String   // "YYYY-MM-DD"

    init(dayISO: String) {
        self.dayISO = dayISO
    }
}
