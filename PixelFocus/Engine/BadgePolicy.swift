/*
 * BadgePolicy.swift
 * PixelFocus
 *
 * Badges de régularité (voir GAME_DESIGN.md §3 bis).
 *
 * Un "jour actif" = un jour où la daily de ce jour a été terminée le jour même
 * (même règle que la série). Les badges se débloquent une seule fois.
 *
 * Semaines: lundi -> dimanche (calendrier ISO 8601).
 * Aucune dépendance SwiftData: testable unitairement.
 */

import Foundation

// MARK: - BadgeCriterion
enum BadgeCriterion: Equatable {
    /// N jours actifs consécutifs
    case streak(days: Int)
    /// N semaines consécutives dont les 7 jours sont actifs
    case perfectWeeks(consecutive: Int)
    /// Un mois calendaire dont tous les jours sont actifs
    case perfectMonth
    /// N semaines consécutives avec au moins `minActiveDays` jours actifs chacune
    case weeklyRegularity(weeks: Int, minActiveDays: Int)
}

// MARK: - BadgeDefinition
struct BadgeDefinition: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let icon: String
    let criterion: BadgeCriterion
}

// MARK: - BadgePolicy
enum BadgePolicy {

    /// Catalogue des badges (ordre d'affichage)
    static let all: [BadgeDefinition] = [
        BadgeDefinition(id: "streak_3", title: "Premiers pas", detail: "3 jours d'affilée", icon: "flame", criterion: .streak(days: 3)),
        BadgeDefinition(id: "streak_5", title: "Sur la lancée", detail: "5 jours d'affilée", icon: "flame.fill", criterion: .streak(days: 5)),
        BadgeDefinition(id: "week_perfect", title: "Semaine parfaite", detail: "Les 7 daily d'une semaine (lundi → dimanche)", icon: "calendar.badge.checkmark", criterion: .perfectWeeks(consecutive: 1)),
        BadgeDefinition(id: "weeks_perfect_2", title: "Quinzaine parfaite", detail: "2 semaines parfaites d'affilée", icon: "calendar.circle.fill", criterion: .perfectWeeks(consecutive: 2)),
        BadgeDefinition(id: "streak_18", title: "Inarrêtable", detail: "18 jours d'affilée", icon: "bolt.heart.fill", criterion: .streak(days: 18)),
        BadgeDefinition(id: "month_perfect", title: "Mois parfait", detail: "Toutes les daily d'un mois", icon: "crown.fill", criterion: .perfectMonth),
        BadgeDefinition(id: "regular_3m", title: "Régulier", detail: "13 semaines d'affilée avec au moins 1 daily par semaine", icon: "leaf.fill", criterion: .weeklyRegularity(weeks: 13, minActiveDays: 1)),
        BadgeDefinition(id: "assiduous_3m", title: "Assidu", detail: "13 semaines d'affilée avec au moins 3 daily par semaine", icon: "star.circle.fill", criterion: .weeklyRegularity(weeks: 13, minActiveDays: 3)),
    ]

    /// Calendrier ISO 8601 (semaines du lundi au dimanche) dans le fuseau courant
    static var isoCalendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        return calendar
    }

    /// Identifiants des badges dont le critère est rempli par l'historique `activeDays` ("YYYY-MM-DD").
    static func earnedBadgeIds(
        activeDays: Set<String>,
        badges: [BadgeDefinition] = all,
        calendar: Calendar = isoCalendar
    ) -> Set<String> {
        let dates = activeDays
            .compactMap { DateParsing.dateFromISODay($0, calendar: calendar) }
            .sorted()
        guard !dates.isEmpty else { return [] }

        let longest = longestStreak(dates: dates, calendar: calendar)
        let weekCounts = activeDaysPerWeek(dates: dates, calendar: calendar)

        var earned = Set<String>()
        for badge in badges {
            let isEarned: Bool
            switch badge.criterion {
            case .streak(let days):
                isEarned = longest >= days
            case .perfectWeeks(let consecutive):
                isEarned = longestWeekRun(weekCounts: weekCounts, minActiveDays: 7, calendar: calendar) >= consecutive
            case .perfectMonth:
                isEarned = hasPerfectMonth(dates: dates, calendar: calendar)
            case .weeklyRegularity(let weeks, let minActiveDays):
                isEarned = longestWeekRun(weekCounts: weekCounts, minActiveDays: minActiveDays, calendar: calendar) >= weeks
            }
            if isEarned {
                earned.insert(badge.id)
            }
        }
        return earned
    }

    // MARK: - Helpers

    /// Plus longue suite de jours consécutifs (dates triées, sans doublon de jour)
    static func longestStreak(dates: [Date], calendar: Calendar) -> Int {
        var longest = 0
        var current = 0
        var previous: Date?
        for date in dates {
            if let previous, calendar.dateComponents([.day], from: previous, to: date).day == 1 {
                current += 1
            } else if let previous, calendar.isDate(previous, inSameDayAs: date) {
                continue
            } else {
                current = 1
            }
            longest = max(longest, current)
            previous = date
        }
        return longest
    }

    /// Nombre de jours actifs par semaine (clé = lundi de la semaine)
    static func activeDaysPerWeek(dates: [Date], calendar: Calendar) -> [Date: Int] {
        var counts: [Date: Int] = [:]
        for date in dates {
            guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: date)?.start else { continue }
            counts[weekStart, default: 0] += 1
        }
        return counts
    }

    /// Plus longue suite de semaines consécutives ayant au moins `minActiveDays` jours actifs
    static func longestWeekRun(weekCounts: [Date: Int], minActiveDays: Int, calendar: Calendar) -> Int {
        let qualifying = weekCounts
            .filter { $0.value >= minActiveDays }
            .map(\.key)
            .sorted()

        var longest = 0
        var current = 0
        var previous: Date?
        for weekStart in qualifying {
            if let previous, calendar.dateComponents([.day], from: previous, to: weekStart).day == 7 {
                current += 1
            } else {
                current = 1
            }
            longest = max(longest, current)
            previous = weekStart
        }
        return longest
    }

    /// Vrai si au moins un mois calendaire a tous ses jours actifs
    static func hasPerfectMonth(dates: [Date], calendar: Calendar) -> Bool {
        var counts: [String: (count: Int, sample: Date)] = [:]
        for date in dates {
            let key = DatePolicy.isoMonthString(for: date, calendar: calendar)
            let entry = counts[key]
            counts[key] = ((entry?.count ?? 0) + 1, entry?.sample ?? date)
        }
        return counts.values.contains { entry in
            guard let daysInMonth = calendar.range(of: .day, in: .month, for: entry.sample)?.count else { return false }
            return entry.count >= daysInMonth
        }
    }
}
