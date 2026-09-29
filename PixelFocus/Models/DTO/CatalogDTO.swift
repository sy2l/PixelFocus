/*
 * CatalogDTO.swift
 * PixelFocus
 *
 * Version: 1.0
 * Date: 15 janvier 2026
 *
 * Modèle DTO pour décoder catalog.json.
 *
 * Objectifs:
 * - Donner le contenu actif: daily par date, weekly par semaine, monthly par mois.
 */

import Foundation

// MARK: - CatalogDTO
struct CatalogDTO: Codable {
    let contentVersion: Int
    let month: String
    let daily: [DailyEntryDTO]
    let weekly: [WeeklyEntryDTO]
    let monthly: [MonthlyEntryDTO]
}

// MARK: - DailyEntryDTO
struct DailyEntryDTO: Codable {
    let date: String
    let artworkId: String
}

// MARK: - WeeklyEntryDTO
struct WeeklyEntryDTO: Codable {
    let weekId: String
    let artworkId: String
    let startDate: String
    let endDate: String
}

// MARK: - MonthlyEntryDTO
struct MonthlyEntryDTO: Codable {
    let month: String
    let artworkId: String
    let isPremium: Bool
}
