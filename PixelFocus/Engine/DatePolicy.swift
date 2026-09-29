/*
 * DatePolicy.swift
 * PixelFocus
 *
 * Version: 1.0
 * Date: 15 janvier 2026
 *
 * Règles de dates:
 * - Daily jouables toute l'année; purge des daily "à finaliser" en janvier de l'année suivante.
 * - Fin de période (daily/weekly/monthly) pour le passage en "à finaliser".
 * - Les règles d'achat des monthly sont décrites dans GAME_DESIGN.md.
 *
 * Objectifs:
 * - Encapsuler la logique temporelle (scalable, testable).
 */

import Foundation

// MARK: - DatePolicy
enum DatePolicy {

    // MARK: - ISO Helpers
    
    /// Retourne la date au format ISO "YYYY-MM-DD"
    static func isoDayString(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 1970
        let month = components.month ?? 1
        let day = components.day ?? 1
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
    
    /// Retourne le mois au format ISO "YYYY-MM"
    static func isoMonthString(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month], from: date)
        let year = components.year ?? 1970
        let month = components.month ?? 1
        return String(format: "%04d-%02d", year, month)
    }

    /// Premier jour (00:00) d'un mois ISO "YYYY-MM"
    static func firstDayOfMonth(_ monthISO: String, calendar: Calendar = .current) -> Date? {
        let parts = monthISO.split(separator: "-")
        guard parts.count == 2, let year = Int(parts[0]), let month = Int(parts[1]) else { return nil }
        return calendar.date(from: DateComponents(year: year, month: month, day: 1))
    }

    /// Mois ISO décalé de `offset` mois (ex: "2026-01" + 1 -> "2026-02")
    static func monthISO(_ monthISO: String, offsetBy offset: Int, calendar: Calendar = .current) -> String? {
        guard let first = firstDayOfMonth(monthISO, calendar: calendar),
              let shifted = calendar.date(byAdding: .month, value: offset, to: first) else { return nil }
        return isoMonthString(for: shifted, calendar: calendar)
    }

    // MARK: - Purge Daily Finalize

    /// Date de purge des daily d'une année: le `januaryDay` janvier de l'année suivante (00:00).
    /// Les daily restent jouables toute l'année calendaire (voir GAME_DESIGN.md).
    static func dailyPurgeDate(
        dailyYear: Int,
        januaryDay: Int,
        calendar: Calendar = .current
    ) -> Date? {
        calendar.date(from: DateComponents(year: dailyYear + 1, month: 1, day: januaryDay))
    }

    /// Vérifie si une daily (par sa date ISO) doit être purgée à la date actuelle.
    static func shouldPurgeDailyFinalize(
        dailyDateISO: String,
        currentDate: Date,
        januaryDay: Int,
        calendar: Calendar = .current
    ) -> Bool {
        guard let dailyDate = DateParsing.dateFromISODay(dailyDateISO, calendar: calendar),
              let purgeDate = dailyPurgeDate(
                dailyYear: calendar.component(.year, from: dailyDate),
                januaryDay: januaryDay,
                calendar: calendar
              ) else {
            return false
        }
        return currentDate >= purgeDate
    }

    // MARK: - Period End

    /// Vrai si le jour ISO "YYYY-MM-DD" est strictement avant le jour de `date`.
    /// (Comparaison lexicographique valide pour le format ISO.)
    static func isDayISO(_ dayISO: String, before date: Date, calendar: Calendar = .current) -> Bool {
        return dayISO < isoDayString(for: date, calendar: calendar)
    }

    /// Vrai si le mois ISO "YYYY-MM" est strictement avant le mois de `date`.
    static func isMonthISO(_ monthISO: String, before date: Date, calendar: Calendar = .current) -> Bool {
        return monthISO < isoMonthString(for: date, calendar: calendar)
    }

    // MARK: - Day Comparison
    
    /// Vérifie si deux dates sont le même jour
    static func isSameDay(_ date1: Date, _ date2: Date, calendar: Calendar = .current) -> Bool {
        return calendar.isDate(date1, inSameDayAs: date2)
    }
    
    /// Vérifie si une date est hier par rapport à une autre
    static func isYesterday(_ date: Date, relativeTo referenceDate: Date, calendar: Calendar = .current) -> Bool {
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: referenceDate) else {
            return false
        }
        return calendar.isDate(date, inSameDayAs: yesterday)
    }
}
