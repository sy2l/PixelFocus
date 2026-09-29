/*
 * DatePolicyTests.swift
 * PixelFocusTests
 *
 * Version: 1.0
 * Date: 15 janvier 2026
 *
 * Tests unitaires sur DatePolicy (logique de dates).
 *
 * Objectifs:
 * - Vérifier la logique de purge des daily
 * - Vérifier la fenêtre d'achat des monthly
 * - Vérifier les helpers de date
 
 
 import XCTest
 @testable import PixelFocus
 
 // MARK: - DatePolicyTests
 final class DatePolicyTests: XCTestCase {
 
 // MARK: - ISO Day String Tests
 
 func testIsoDayString_formatsCorrectly() {
 let calendar = Calendar.current
 let components = DateComponents(year: 2026, month: 1, day: 15)
 guard let date = calendar.date(from: components) else {
 XCTFail("Could not create date")
 return
 }
 
 let result = DatePolicy.isoDayString(for: date, calendar: calendar)
 XCTAssertEqual(result, "2026-01-15")
 }
 
 func testIsoDayString_singleDigitMonthAndDay() {
 let calendar = Calendar.current
 let components = DateComponents(year: 2026, month: 3, day: 5)
 guard let date = calendar.date(from: components) else {
 XCTFail("Could not create date")
 return
 }
 
 let result = DatePolicy.isoDayString(for: date, calendar: calendar)
 XCTAssertEqual(result, "2026-03-05")
 }
 
 // MARK: - Monthly Purchase Window Tests
 
 func testIsMonthlyPurchasable_withinWindow() {
 let calendar = Calendar.current
 // January 2026 monthly, checked on December 2026
 let components = DateComponents(year: 2026, month: 12, day: 15)
 guard let date = calendar.date(from: components) else {
 XCTFail("Could not create date")
 return
 }
 
 let result = DatePolicy.isMonthlyPurchasable(monthISO: "2026-01", on: date, calendar: calendar)
 XCTAssertTrue(result)
 }
 
 func testIsMonthlyPurchasable_onLastDay() {
 let calendar = Calendar.current
 // January 2026 monthly, checked on February 28, 2027 (last valid day)
 let components = DateComponents(year: 2027, month: 2, day: 28)
 guard let date = calendar.date(from: components) else {
 XCTFail("Could not create date")
 return
 }
 
 let result = DatePolicy.isMonthlyPurchasable(monthISO: "2026-01", on: date, calendar: calendar)
 XCTAssertTrue(result)
 }
 
 func testIsMonthlyPurchasable_afterWindow() {
 let calendar = Calendar.current
 // January 2026 monthly, checked on March 1, 2027 (expired)
 let components = DateComponents(year: 2027, month: 3, day: 1)
 guard let date = calendar.date(from: components) else {
 XCTFail("Could not create date")
 return
 }
 
 let result = DatePolicy.isMonthlyPurchasable(monthISO: "2026-01", on: date, calendar: calendar)
 XCTAssertFalse(result)
 }
 
 // MARK: - Same Day Tests
 
 func testIsSameDay_true() {
 let calendar = Calendar.current
 let components1 = DateComponents(year: 2026, month: 1, day: 15, hour: 10)
 let components2 = DateComponents(year: 2026, month: 1, day: 15, hour: 22)
 
 guard let date1 = calendar.date(from: components1),
 let date2 = calendar.date(from: components2) else {
 XCTFail("Could not create dates")
 return
 }
 
 XCTAssertTrue(DatePolicy.isSameDay(date1, date2, calendar: calendar))
 }
 
 func testIsSameDay_false() {
 let calendar = Calendar.current
 let components1 = DateComponents(year: 2026, month: 1, day: 15)
 let components2 = DateComponents(year: 2026, month: 1, day: 16)
 
 guard let date1 = calendar.date(from: components1),
 let date2 = calendar.date(from: components2) else {
 XCTFail("Could not create dates")
 return
 }
 
 XCTAssertFalse(DatePolicy.isSameDay(date1, date2, calendar: calendar))
 }
 
 // MARK: - Yesterday Tests
 
 func testIsYesterday_true() {
 let calendar = Calendar.current
 let components1 = DateComponents(year: 2026, month: 1, day: 14)
 let components2 = DateComponents(year: 2026, month: 1, day: 15)
 
 guard let yesterday = calendar.date(from: components1),
 let today = calendar.date(from: components2) else {
 XCTFail("Could not create dates")
 return
 }
 
 XCTAssertTrue(DatePolicy.isYesterday(yesterday, relativeTo: today, calendar: calendar))
 }
 
 func testIsYesterday_false_sameDay() {
 let calendar = Calendar.current
 let components = DateComponents(year: 2026, month: 1, day: 15)
 
 guard let date = calendar.date(from: components) else {
 XCTFail("Could not create date")
 return
 }
 
 XCTAssertFalse(DatePolicy.isYesterday(date, relativeTo: date, calendar: calendar))
 }
 
 func testIsYesterday_false_twoDaysAgo() {
 let calendar = Calendar.current
 let components1 = DateComponents(year: 2026, month: 1, day: 13)
 let components2 = DateComponents(year: 2026, month: 1, day: 15)
 
 guard let twoDaysAgo = calendar.date(from: components1),
 let today = calendar.date(from: components2) else {
 XCTFail("Could not create dates")
 return
 }
 
 XCTAssertFalse(DatePolicy.isYesterday(twoDaysAgo, relativeTo: today, calendar: calendar))
 }
 }
 */
