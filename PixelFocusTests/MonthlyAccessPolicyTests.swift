/*
 * MonthlyAccessPolicyTests.swift
 * PixelFocusTests
 *
 * Tests unitaires sur MonthlyAccessPolicy (accès et prix de l'image du mois, GAME_DESIGN.md §2).
 */

import XCTest
@testable import PixelFocus

// MARK: - MonthlyAccessPolicyTests
final class MonthlyAccessPolicyTests: XCTestCase {

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendar
    }()

    private let rules = MonthlyAccessRulesDTO(
        welcomeCutoffDay: 25,
        challengeSessions: 20,
        premiumPreviousMonthGraceDay: 7,
        reducedPriceProgressThreshold: 0.5,
        reducedPriceUntilDayOfNextMonth: 7
    )

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func access(
        _ monthISO: String,
        now: Date,
        firstLaunch: Date,
        premium: PremiumStatus = .none,
        isPurchased: Bool = false,
        sessions: Int = 0
    ) -> MonthlyAccess {
        MonthlyAccessPolicy.access(
            monthISO: monthISO,
            now: now,
            firstLaunch: firstLaunch,
            premium: premium,
            isPurchased: isPurchased,
            completedSessionsInMonth: sessions,
            rules: rules,
            calendar: calendar
        )
    }

    // MARK: - Welcome Gift

    func testWelcomeMonth_beforeCutoff() {
        XCTAssertEqual(MonthlyAccessPolicy.welcomeMonthISO(firstLaunch: date(2026, 3, 10), rules: rules, calendar: calendar), "2026-03")
        XCTAssertEqual(MonthlyAccessPolicy.welcomeMonthISO(firstLaunch: date(2026, 3, 24), rules: rules, calendar: calendar), "2026-03")
    }

    func testWelcomeMonth_onOrAfterCutoff() {
        XCTAssertEqual(MonthlyAccessPolicy.welcomeMonthISO(firstLaunch: date(2026, 3, 25), rules: rules, calendar: calendar), "2026-04")
        XCTAssertEqual(MonthlyAccessPolicy.welcomeMonthISO(firstLaunch: date(2026, 12, 28), rules: rules, calendar: calendar), "2027-01")
    }

    func testFree_welcomeGiftThenLocked() {
        let firstLaunch = date(2026, 3, 10)
        XCTAssertEqual(access("2026-03", now: date(2026, 3, 15), firstLaunch: firstLaunch), .granted(.welcomeGift))
        XCTAssertEqual(access("2026-04", now: date(2026, 4, 2), firstLaunch: firstLaunch), .locked)
    }

    // MARK: - Challenge & Purchase

    func testFree_challengeUnlocks() {
        let firstLaunch = date(2026, 1, 10)
        XCTAssertEqual(access("2026-04", now: date(2026, 4, 20), firstLaunch: firstLaunch, sessions: 19), .locked)
        XCTAssertEqual(access("2026-04", now: date(2026, 4, 20), firstLaunch: firstLaunch, sessions: 20), .granted(.challenge))
    }

    func testPurchased_alwaysGranted() {
        let firstLaunch = date(2026, 1, 10)
        XCTAssertEqual(access("2025-06", now: date(2026, 4, 20), firstLaunch: firstLaunch, isPurchased: true), .granted(.purchased))
    }

    // MARK: - Premium

    func testPremium_currentMonth() {
        let premium = PremiumStatus(isActive: true, lapsedAt: nil)
        XCTAssertEqual(access("2026-05", now: date(2026, 5, 2), firstLaunch: date(2026, 1, 10), premium: premium), .granted(.premium))
    }

    func testPremium_previousMonthUntilSeventh() {
        let premium = PremiumStatus(isActive: true, lapsedAt: nil)
        let firstLaunch = date(2026, 1, 10)
        XCTAssertEqual(access("2026-04", now: date(2026, 5, 7), firstLaunch: firstLaunch, premium: premium), .granted(.premiumPreviousMonthGrace))
        XCTAssertEqual(access("2026-04", now: date(2026, 5, 8), firstLaunch: firstLaunch, premium: premium), .locked)
    }

    func testPremium_olderMonthsLocked() {
        let premium = PremiumStatus(isActive: true, lapsedAt: nil)
        XCTAssertEqual(access("2026-03", now: date(2026, 5, 2), firstLaunch: date(2026, 1, 10), premium: premium), .locked)
    }

    // MARK: - Premium Lapse

    func testPremiumLapse_giftUntilEndOfMonth() {
        let premium = PremiumStatus(isActive: false, lapsedAt: date(2026, 5, 12))
        let firstLaunch = date(2026, 1, 10)
        XCTAssertEqual(access("2026-05", now: date(2026, 5, 31, hour: 23), firstLaunch: firstLaunch, premium: premium), .granted(.premiumLapseGift))
        XCTAssertEqual(access("2026-05", now: date(2026, 6, 1), firstLaunch: firstLaunch, premium: premium), .locked)
    }

    // MARK: - Unit Price

    func testUnitPrice_reducedAboveHalfUntilSeventhOfNextMonth() {
        XCTAssertEqual(MonthlyAccessPolicy.unitPriceTier(monthISO: "2026-05", now: date(2026, 5, 20), revealedRatio: 0.6, rules: rules, calendar: calendar), .reduced)
        XCTAssertEqual(MonthlyAccessPolicy.unitPriceTier(monthISO: "2026-05", now: date(2026, 6, 7, hour: 23), revealedRatio: 0.6, rules: rules, calendar: calendar), .reduced)
        XCTAssertEqual(MonthlyAccessPolicy.unitPriceTier(monthISO: "2026-05", now: date(2026, 6, 8, hour: 0), revealedRatio: 0.6, rules: rules, calendar: calendar), .full)
    }

    func testUnitPrice_fullAtOrBelowHalf() {
        XCTAssertEqual(MonthlyAccessPolicy.unitPriceTier(monthISO: "2026-05", now: date(2026, 5, 20), revealedRatio: 0.5, rules: rules, calendar: calendar), .full)
        XCTAssertEqual(MonthlyAccessPolicy.unitPriceTier(monthISO: "2026-05", now: date(2026, 5, 20), revealedRatio: 0.0, rules: rules, calendar: calendar), .full)
    }
}
