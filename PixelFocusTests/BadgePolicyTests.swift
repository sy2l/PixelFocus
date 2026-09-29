/*
 * BadgePolicyTests.swift
 * PixelFocusTests
 *
 * Tests unitaires sur BadgePolicy (badges de régularité).
 */

import XCTest
@testable import PixelFocus

// MARK: - BadgePolicyTests
final class BadgePolicyTests: XCTestCase {

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendar
    }()

    /// Jours ISO consécutifs à partir de `start` ("YYYY-MM-DD")
    private func days(from start: String, count: Int, step: Int = 1) -> Set<String> {
        let startDate = DateParsing.dateFromISODay(start, calendar: calendar)!
        return Set((0..<count).map { offset in
            DatePolicy.isoDayString(for: calendar.date(byAdding: .day, value: offset * step, to: startDate)!, calendar: calendar)
        })
    }

    private func earned(_ activeDays: Set<String>) -> Set<String> {
        BadgePolicy.earnedBadgeIds(activeDays: activeDays, calendar: calendar)
    }

    // MARK: - Streak

    func testNoActivity_noBadge() {
        XCTAssertTrue(earned([]).isEmpty)
    }

    func testStreak3And5() {
        XCTAssertFalse(earned(days(from: "2026-03-10", count: 2)).contains("streak_3"))
        XCTAssertTrue(earned(days(from: "2026-03-10", count: 3)).contains("streak_3"))
        XCTAssertFalse(earned(days(from: "2026-03-10", count: 4)).contains("streak_5"))
        XCTAssertTrue(earned(days(from: "2026-03-10", count: 5)).contains("streak_5"))
    }

    func testStreak_brokenDoesNotCount() {
        // 2 jours, trou, 2 jours -> pas de série de 3
        let active: Set<String> = ["2026-03-10", "2026-03-11", "2026-03-13", "2026-03-14"]
        XCTAssertFalse(earned(active).contains("streak_3"))
    }

    // MARK: - Perfect Weeks

    func testPerfectWeek_mondayToSunday() {
        // 2026-03-09 est un lundi
        XCTAssertTrue(earned(days(from: "2026-03-09", count: 7)).contains("week_perfect"))
    }

    func testPerfectWeek_sevenDaysAcrossTwoWeeksIsNotPerfect() {
        // Mercredi -> mardi: 7 jours d'affilée mais aucune semaine complète
        let result = earned(days(from: "2026-03-11", count: 7))
        XCTAssertFalse(result.contains("week_perfect"))
        XCTAssertTrue(result.contains("streak_5"))
    }

    func testTwoConsecutivePerfectWeeks() {
        XCTAssertFalse(earned(days(from: "2026-03-09", count: 13)).contains("weeks_perfect_2"))
        XCTAssertTrue(earned(days(from: "2026-03-09", count: 14)).contains("weeks_perfect_2"))
    }

    // MARK: - Perfect Month

    func testPerfectMonth() {
        XCTAssertFalse(earned(days(from: "2026-02-01", count: 27)).contains("month_perfect"))
        XCTAssertTrue(earned(days(from: "2026-02-01", count: 28)).contains("month_perfect"))
    }

    // MARK: - Weekly Regularity

    func testRegular_oneDayPerWeekFor13Weeks() {
        // Un lundi par semaine pendant 13 semaines
        let active = days(from: "2026-01-05", count: 13, step: 7)
        XCTAssertTrue(earned(active).contains("regular_3m"))
        XCTAssertFalse(earned(active).contains("assiduous_3m"))
    }

    func testRegular_gapBreaksTheRun() {
        var active = days(from: "2026-01-05", count: 13, step: 7)
        active.remove("2026-02-16") // semaine 7 manquée
        XCTAssertFalse(earned(active).contains("regular_3m"))
    }

    func testAssiduous_threeDaysPerWeekFor13Weeks() {
        var active = Set<String>()
        for week in 0..<13 {
            let monday = calendar.date(byAdding: .day, value: week * 7, to: DateParsing.dateFromISODay("2026-01-05", calendar: calendar)!)!
            for offset in [0, 2, 4] { // lundi, mercredi, vendredi
                active.insert(DatePolicy.isoDayString(for: calendar.date(byAdding: .day, value: offset, to: monday)!, calendar: calendar))
            }
        }
        let result = earned(active)
        XCTAssertTrue(result.contains("assiduous_3m"))
        XCTAssertTrue(result.contains("regular_3m"))
        XCTAssertFalse(result.contains("streak_3"))
    }
}
