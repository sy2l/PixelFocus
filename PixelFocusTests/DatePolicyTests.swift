/*
 * DatePolicyTests.swift
 * PixelFocusTests
 *
 * Tests unitaires sur DatePolicy (logique de dates).
 *
 * Objectifs:
 * - Vérifier la logique de purge des daily (fin d'année calendaire)
 * - Vérifier les fins de période (jour / mois échus)
 * - Vérifier les helpers de date
 */

import XCTest
@testable import PixelFocus

// MARK: - DatePolicyTests
final class DatePolicyTests: XCTestCase {

    /// Calendrier fixe pour des tests indépendants du fuseau de la machine.
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    // MARK: - ISO Day String Tests

    func testIsoDayString_formatsCorrectly() {
        XCTAssertEqual(DatePolicy.isoDayString(for: date(2026, 1, 15), calendar: calendar), "2026-01-15")
    }

    func testIsoDayString_singleDigitMonthAndDay() {
        XCTAssertEqual(DatePolicy.isoDayString(for: date(2026, 3, 5), calendar: calendar), "2026-03-05")
    }

    // MARK: - Daily Purge Tests (daily jouables toute l'année, purge le 1er janvier suivant)

    func testShouldPurge_sameYear() {
        // Daily du 15 janvier, encore là en décembre de la même année
        XCTAssertFalse(DatePolicy.shouldPurgeDailyFinalize(
            dailyDateISO: "2026-01-15", currentDate: date(2026, 12, 31, hour: 23), januaryDay: 1, calendar: calendar))
    }

    func testShouldPurge_onJanuaryFirst() {
        XCTAssertTrue(DatePolicy.shouldPurgeDailyFinalize(
            dailyDateISO: "2026-01-15", currentDate: date(2027, 1, 1, hour: 0), januaryDay: 1, calendar: calendar))
    }

    func testShouldPurge_decemberDaily() {
        // Daily du 20 décembre: purgée dès le 1er janvier
        XCTAssertFalse(DatePolicy.shouldPurgeDailyFinalize(
            dailyDateISO: "2026-12-20", currentDate: date(2026, 12, 31), januaryDay: 1, calendar: calendar))
        XCTAssertTrue(DatePolicy.shouldPurgeDailyFinalize(
            dailyDateISO: "2026-12-20", currentDate: date(2027, 1, 1), januaryDay: 1, calendar: calendar))
    }

    func testShouldPurge_customJanuaryDay() {
        XCTAssertFalse(DatePolicy.shouldPurgeDailyFinalize(
            dailyDateISO: "2026-06-10", currentDate: date(2027, 1, 3), januaryDay: 4, calendar: calendar))
        XCTAssertTrue(DatePolicy.shouldPurgeDailyFinalize(
            dailyDateISO: "2026-06-10", currentDate: date(2027, 1, 4), januaryDay: 4, calendar: calendar))
    }

    func testShouldPurge_yearsLater() {
        XCTAssertTrue(DatePolicy.shouldPurgeDailyFinalize(
            dailyDateISO: "2026-01-15", currentDate: date(2028, 6, 1), januaryDay: 1, calendar: calendar))
    }

    func testShouldPurge_invalidISO() {
        XCTAssertFalse(DatePolicy.shouldPurgeDailyFinalize(
            dailyDateISO: "invalid", currentDate: date(2026, 4, 2), januaryDay: 1, calendar: calendar))
    }

    // MARK: - Period End Tests

    func testIsDayISOBefore() {
        let today = date(2026, 1, 15)
        XCTAssertTrue(DatePolicy.isDayISO("2026-01-14", before: today, calendar: calendar))
        XCTAssertFalse(DatePolicy.isDayISO("2026-01-15", before: today, calendar: calendar))
        XCTAssertFalse(DatePolicy.isDayISO("2026-01-16", before: today, calendar: calendar))
        XCTAssertTrue(DatePolicy.isDayISO("2025-12-31", before: today, calendar: calendar))
    }

    func testIsMonthISOBefore() {
        let today = date(2026, 2, 1)
        XCTAssertTrue(DatePolicy.isMonthISO("2026-01", before: today, calendar: calendar))
        XCTAssertFalse(DatePolicy.isMonthISO("2026-02", before: today, calendar: calendar))
        XCTAssertTrue(DatePolicy.isMonthISO("2025-12", before: today, calendar: calendar))
    }

    // MARK: - Same Day Tests

    func testIsSameDay_true() {
        XCTAssertTrue(DatePolicy.isSameDay(date(2026, 1, 15, hour: 10), date(2026, 1, 15, hour: 22), calendar: calendar))
    }

    func testIsSameDay_false() {
        XCTAssertFalse(DatePolicy.isSameDay(date(2026, 1, 15), date(2026, 1, 16), calendar: calendar))
    }

    // MARK: - Yesterday Tests

    func testIsYesterday_true() {
        XCTAssertTrue(DatePolicy.isYesterday(date(2026, 1, 14), relativeTo: date(2026, 1, 15), calendar: calendar))
    }

    func testIsYesterday_false_sameDay() {
        XCTAssertFalse(DatePolicy.isYesterday(date(2026, 1, 15), relativeTo: date(2026, 1, 15), calendar: calendar))
    }

    func testIsYesterday_false_twoDaysAgo() {
        XCTAssertFalse(DatePolicy.isYesterday(date(2026, 1, 13), relativeTo: date(2026, 1, 15), calendar: calendar))
    }
}
