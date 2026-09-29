/*
 * DatePolicy.swift
 * PixelFocus
 *
 * Version: 1.0
 * Date: 15 janvier 2026
 *
 * Règles de dates:
 * - Purge daily "à finaliser" le 4 du mois suivant.
 * - Monthly achetable jusqu'à février de l'année suivante.
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

    // MARK: - Purge Daily Finalize
    
    /// Vérifie si une daily d'un mois donné doit être purgée à la date actuelle
    /// (purge le 4 du mois suivant)
    static func shouldPurgeDailyFinalize(
        dailyMonth: DateComponents,
        currentDate: Date,
        purgeDay: Int,
        calendar: Calendar = .current
    ) -> Bool {
        let now = calendar.dateComponents([.year, .month, .day], from: currentDate)
        guard let nowYear = now.year, let nowMonth = now.month, let nowDay = now.day else { return false }
        guard nowDay >= purgeDay else { return false }

        guard let dailyYear = dailyMonth.year, let dailyMonthValue = dailyMonth.month else { return false }

        // Calcul du mois de purge (mois suivant le mois de la daily)
        var nextMonthComponents = DateComponents(year: dailyYear, month: dailyMonthValue, day: 1)
        guard let dailyMonthDate = calendar.date(from: nextMonthComponents) else { return false }

        guard let purgeMonthDate = calendar.date(byAdding: .month, value: 1, to: dailyMonthDate) else { return false }
        let purgeMonth = calendar.component(.month, from: purgeMonthDate)
        let purgeYear = calendar.component(.year, from: purgeMonthDate)

        return (nowYear == purgeYear && nowMonth == purgeMonth && nowDay >= purgeDay)
    }
    
    /// Vérifie si une daily (par sa date ISO) doit être purgée
    static func shouldPurgeDailyFinalize(
        dailyDateISO: String,
        currentDate: Date,
        purgeDay: Int,
        calendar: Calendar = .current
    ) -> Bool {
        guard let dailyDate = DateParsing.dateFromISODay(dailyDateISO, calendar: calendar) else {
            return false
        }
        
        let dailyMonth = calendar.dateComponents([.year, .month], from: dailyDate)
        return shouldPurgeDailyFinalize(
            dailyMonth: dailyMonth,
            currentDate: currentDate,
            purgeDay: purgeDay,
            calendar: calendar
        )
    }

    // MARK: - Monthly Purchase Window
    
    /// Vérifie si une œuvre mensuelle est encore achetable
    /// (Monthly de l'année Y est achetable jusqu'à fin février Y+1)
    static func isMonthlyPurchasable(monthISO: String, on date: Date, calendar: Calendar = .current) -> Bool {
        let parts = monthISO.split(separator: "-")
        guard parts.count == 2,
              let year = Int(parts[0]),
              let _ = Int(parts[1]) else { return false }

        // Fin février de l'année suivante = 1er mars de l'année suivante
        let cutoffComponents = DateComponents(year: year + 1, month: 3, day: 1)
        guard let cutoff = calendar.date(from: cutoffComponents) else { return false }

        // Achetable strictement avant le 1er mars de l'année suivante
        return date < cutoff
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
