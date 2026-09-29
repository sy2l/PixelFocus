/*
 * DateParsing.swift
 * PixelFocus
 *
 * Version: 1.0
 * Date: 15 janvier 2026
 *
 * Helpers de parsing de dates ISO (YYYY-MM-DD) et mois (YYYY-MM).
 *
 * Objectifs:
 * - Aider les vues à retrouver weekly/monthly actifs.
 * - Éviter du parsing répété partout.
 */

import Foundation

// MARK: - DateParsing
enum DateParsing {

    // MARK: - ISO Day Parsing
    
    /// Convertit une chaîne ISO "YYYY-MM-DD" en Date
    static func dateFromISODay(_ iso: String, calendar: Calendar = .current) -> Date? {
        let parts = iso.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else { return nil }

        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    /// Vérifie si une date est dans une plage ISO (inclusive)
    static func isDate(
        _ date: Date,
        withinISOStart startISO: String,
        isoEnd endISO: String,
        calendar: Calendar = .current
    ) -> Bool {
        guard let start = dateFromISODay(startISO, calendar: calendar),
              let end = dateFromISODay(endISO, calendar: calendar) else { return false }

        // Plage inclusive
        return date >= start && date <= end
    }

    // MARK: - Month ISO
    
    /// Retourne le mois courant au format "YYYY-MM"
    static func currentMonthISO(date: Date, calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.year, .month], from: date)
        let year = comps.year ?? 1970
        let month = comps.month ?? 1
        return String(format: "%04d-%02d", year, month)
    }
    
    /// Extrait le mois d'une date ISO "YYYY-MM-DD" -> "YYYY-MM"
    static func monthFromISODay(_ iso: String) -> String? {
        let parts = iso.split(separator: "-")
        guard parts.count >= 2 else { return nil }
        return "\(parts[0])-\(parts[1])"
    }
    
    // MARK: - Week Helpers
    
    /// Retourne l'identifiant de semaine ISO (ex: "2026-W01")
    static func weekIdFromDate(_ date: Date, calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let year = comps.yearForWeekOfYear ?? 1970
        let week = comps.weekOfYear ?? 1
        return String(format: "%04d-W%02d", year, week)
    }
}
