/*
 * BoosterPolicyTests.swift
 * PixelFocusTests
 *
 * Tests unitaires sur BoosterPolicy (règles des boosters, GAME_DESIGN.md §3).
 */

import XCTest
@testable import PixelFocus

// MARK: - BoosterPolicyTests
final class BoosterPolicyTests: XCTestCase {

    private let rewards = [
        StreakBoosterRewardDTO(everyConsecutiveDays: 3, boosters: 1),
        StreakBoosterRewardDTO(everyConsecutiveDays: 18, boosters: 1)
    ]

    private let rules = BoostersRulesDTO(
        pixelsPerBooster: 5,
        earnedCap: 12,
        dailyEarnedUseLimit: BoosterUseLimitDTO(free: 1, premium: 3),
        premiumMonthlyGrant: 2
    )

    // MARK: - Streak Rewards

    func testStreakReward_everyThreeDays() {
        XCTAssertEqual(BoosterPolicy.streakReward(streakDay: 1, rewards: rewards), 0)
        XCTAssertEqual(BoosterPolicy.streakReward(streakDay: 2, rewards: rewards), 0)
        XCTAssertEqual(BoosterPolicy.streakReward(streakDay: 3, rewards: rewards), 1)
        XCTAssertEqual(BoosterPolicy.streakReward(streakDay: 6, rewards: rewards), 1)
        XCTAssertEqual(BoosterPolicy.streakReward(streakDay: 7, rewards: rewards), 0)
    }

    func testStreakReward_bonusEveryEighteenDays() {
        XCTAssertEqual(BoosterPolicy.streakReward(streakDay: 18, rewards: rewards), 2)
        XCTAssertEqual(BoosterPolicy.streakReward(streakDay: 36, rewards: rewards), 2)
        XCTAssertEqual(BoosterPolicy.streakReward(streakDay: 54, rewards: rewards), 2)
    }

    func testStreakReward_zeroOrNegative() {
        XCTAssertEqual(BoosterPolicy.streakReward(streakDay: 0, rewards: rewards), 0)
        XCTAssertEqual(BoosterPolicy.streakReward(streakDay: -3, rewards: rewards), 0)
    }

    // MARK: - Earned Cap

    func testAddingEarned_respectsCap() {
        XCTAssertEqual(BoosterPolicy.addingEarned(current: 10, amount: 1, cap: 12), 11)
        XCTAssertEqual(BoosterPolicy.addingEarned(current: 11, amount: 2, cap: 12), 12)
        XCTAssertEqual(BoosterPolicy.addingEarned(current: 12, amount: 1, cap: 12), 12)
    }

    func testAddingEarned_neverRemovesExisting() {
        // Déjà au-dessus du cap (ex: cap abaissé): on ne retire rien
        XCTAssertEqual(BoosterPolicy.addingEarned(current: 15, amount: 1, cap: 12), 15)
    }

    // MARK: - Next Source

    func testNextSource_earnedFirstWithinLimit() {
        XCTAssertEqual(
            BoosterPolicy.nextSource(earned: 3, purchased: 5, earnedUsedToday: 0, dailyEarnedLimit: 1),
            .earned
        )
    }

    func testNextSource_purchasedWhenDailyLimitReached() {
        XCTAssertEqual(
            BoosterPolicy.nextSource(earned: 3, purchased: 5, earnedUsedToday: 1, dailyEarnedLimit: 1),
            .purchased
        )
    }

    func testNextSource_nilWhenLimitReachedAndNoPurchased() {
        XCTAssertNil(BoosterPolicy.nextSource(earned: 3, purchased: 0, earnedUsedToday: 1, dailyEarnedLimit: 1))
    }

    func testNextSource_nilWhenEmpty() {
        XCTAssertNil(BoosterPolicy.nextSource(earned: 0, purchased: 0, earnedUsedToday: 0, dailyEarnedLimit: 3))
    }

    func testDailyEarnedLimit_byStatus() {
        XCTAssertEqual(BoosterPolicy.dailyEarnedLimit(isPremium: false, rules: rules), 1)
        XCTAssertEqual(BoosterPolicy.dailyEarnedLimit(isPremium: true, rules: rules), 3)
    }

    // MARK: - Premium Monthly Grant

    func testShouldGrantPremiumMonthly() {
        XCTAssertTrue(BoosterPolicy.shouldGrantPremiumMonthly(lastGrantMonthISO: nil, currentMonthISO: "2026-10"))
        XCTAssertTrue(BoosterPolicy.shouldGrantPremiumMonthly(lastGrantMonthISO: "2026-09", currentMonthISO: "2026-10"))
        XCTAssertFalse(BoosterPolicy.shouldGrantPremiumMonthly(lastGrantMonthISO: "2026-10", currentMonthISO: "2026-10"))
    }
}
