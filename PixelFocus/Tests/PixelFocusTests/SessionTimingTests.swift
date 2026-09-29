/*
 * SessionTimingTests.swift
 * PixelFocusTests
 *
 * Version: 1.0
 * Date: 15 janvier 2026
 *
 * Tests unitaires sur SessionTiming (logique pure).
 *
 * Objectifs:
 * - Vérifier remaining/overtime
 * - Vérifier extraMinutesOver30
 * - Vérifier le formatage du temps
 

import XCTest
@testable import PixelFocus

// MARK: - SessionTimingTests
final class SessionTimingTests: XCTestCase {

    // MARK: - Remaining & Overtime Tests
    
    func testRemainingSeconds_beforeEnd() {
        let start = Date(timeIntervalSince1970: 0)
        let now = Date(timeIntervalSince1970: 10)
        let elapsed = SessionTiming.activeElapsedSeconds(startDate: start, now: now, totalPausedSeconds: 0)

        XCTAssertEqual(elapsed, 10)
        XCTAssertEqual(SessionTiming.remainingSeconds(targetSeconds: 60, activeElapsedSeconds: elapsed), 50)
        XCTAssertEqual(SessionTiming.overtimeSeconds(targetSeconds: 60, activeElapsedSeconds: elapsed), 0)
    }

    func testOvertimeSeconds_afterEnd() {
        let start = Date(timeIntervalSince1970: 0)
        let now = Date(timeIntervalSince1970: 75)
        let elapsed = SessionTiming.activeElapsedSeconds(startDate: start, now: now, totalPausedSeconds: 0)

        XCTAssertEqual(elapsed, 75)
        XCTAssertEqual(SessionTiming.remainingSeconds(targetSeconds: 60, activeElapsedSeconds: elapsed), 0)
        XCTAssertEqual(SessionTiming.overtimeSeconds(targetSeconds: 60, activeElapsedSeconds: elapsed), 15)
    }

    // MARK: - Pause Exclusion Tests
    
    func testActiveElapsed_excludesPause() {
        let start = Date(timeIntervalSince1970: 0)
        let now = Date(timeIntervalSince1970: 120)

        // paused 30 seconds
        let elapsed = SessionTiming.activeElapsedSeconds(startDate: start, now: now, totalPausedSeconds: 30)

        XCTAssertEqual(elapsed, 90)
    }
    
    func testActiveElapsed_multiplePauses() {
        let start = Date(timeIntervalSince1970: 0)
        let now = Date(timeIntervalSince1970: 300) // 5 minutes total

        // Total paused: 60 seconds (multiple pauses)
        let elapsed = SessionTiming.activeElapsedSeconds(startDate: start, now: now, totalPausedSeconds: 60)

        XCTAssertEqual(elapsed, 240) // 4 minutes active
    }

    // MARK: - Over30 Bonus Tests
    
    func testExtraMinutesOver30_none() {
        // 29:59 => 0
        let elapsed = (29 * 60) + 59
        XCTAssertEqual(SessionTiming.extraMinutesOver30(activeElapsedSeconds: elapsed), 0)
    }
    
    func testExtraMinutesOver30_exactly30() {
        // 30:00 => 0
        let elapsed = 30 * 60
        XCTAssertEqual(SessionTiming.extraMinutesOver30(activeElapsedSeconds: elapsed), 0)
    }

    func testExtraMinutesOver30_oneMinute() {
        // 31:00 => 1
        let elapsed = (31 * 60)
        XCTAssertEqual(SessionTiming.extraMinutesOver30(activeElapsedSeconds: elapsed), 1)
    }
    
    func testExtraMinutesOver30_oneMinutePartial() {
        // 31:30 => 1 (only full minutes count)
        let elapsed = (31 * 60) + 30
        XCTAssertEqual(SessionTiming.extraMinutesOver30(activeElapsedSeconds: elapsed), 1)
    }

    func testExtraMinutesOver30_multipleMinutes() {
        // 39:59 => 9
        let elapsed = (39 * 60) + 59
        XCTAssertEqual(SessionTiming.extraMinutesOver30(activeElapsedSeconds: elapsed), 9)
    }
    
    func testExtraMinutesOver30_tenMinutes() {
        // 40:00 => 10
        let elapsed = 40 * 60
        XCTAssertEqual(SessionTiming.extraMinutesOver30(activeElapsedSeconds: elapsed), 10)
    }
    
    // MARK: - Format Time Tests
    
    func testFormatTime_zeroSeconds() {
        XCTAssertEqual(SessionTiming.formatTime(seconds: 0), "00:00")
    }
    
    func testFormatTime_underOneMinute() {
        XCTAssertEqual(SessionTiming.formatTime(seconds: 45), "00:45")
    }
    
    func testFormatTime_exactMinutes() {
        XCTAssertEqual(SessionTiming.formatTime(seconds: 300), "05:00")
    }
    
    func testFormatTime_mixedTime() {
        XCTAssertEqual(SessionTiming.formatTime(seconds: 754), "12:34")
    }
    
    func testFormatTime_negativeSeconds() {
        // Should return 00:00 for negative values
        XCTAssertEqual(SessionTiming.formatTime(seconds: -10), "00:00")
    }
    
    func testFormatTimeLong_withHours() {
        XCTAssertEqual(SessionTiming.formatTimeLong(seconds: 3661), "01:01:01")
    }
    
    func testFormatTimeLong_withoutHours() {
        XCTAssertEqual(SessionTiming.formatTimeLong(seconds: 754), "12:34")
    }
}
*/
