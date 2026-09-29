/*
 * ArtworkDTO.swift
 * PixelFocus
 *
 * Version: 1.0
 * Date: 15 janvier 2026
 *
 * Modèles DTO pour décoder artworks/*.json.
 *
 * Objectifs:
 * - Décrire une œuvre en pixel-art (grille, palette, données pixels, reveal order).
 * - Les données sont ensuite persistées en SwiftData via SDArtwork.
*/
*/
import Foundation

// MARK: - ArtworkDTO
struct ArtworkDTO: Codable {
    let artworkId: String
    let title: String
    let mode: String
    let grid: GridDTO
    let reveal: RevealDTO
    let palette: [String]
    let pixels: PixelsDTO
}

// MARK: - GridDTO
struct GridDTO: Codable {
    let width: Int
    let height: Int
}

// MARK: - RevealDTO
struct RevealDTO: Codable {
    let order: String
    let indexSequence: [Int]
}

// MARK: - PixelsDTO
struct PixelsDTO: Codable {
    let encoding: String
    let data: [Int]
}
