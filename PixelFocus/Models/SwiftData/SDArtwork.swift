/*
 * SDArtwork.swift
 * PixelFocus
 *
 * Version: 1.0
 * Date: 15 janvier 2026
 *
 * Modèle SwiftData pour une œuvre.
 *
 * Objectifs:
 * - Stocker une œuvre (pixels, palette, reveal order) en local.
 * - Permettre une mise à jour via contentVersion si besoin.
 *
 * Note:
 * - On stocke palette/pixels/indexSequence en Data (JSON encodé) pour simplicité MVP.
 */

import Foundation
import SwiftData

// MARK: - SDArtwork
@Model
final class SDArtwork {
    @Attribute(.unique) var artworkId: String

    var title: String
    var mode: String

    var gridWidth: Int
    var gridHeight: Int

    /// JSON-encoded arrays for long-term stability and simple migrations.
    var paletteJSON: Data
    var pixelsJSON: Data
    var revealSequenceJSON: Data

    var createdAt: Date

    init(
        artworkId: String,
        title: String,
        mode: String,
        gridWidth: Int,
        gridHeight: Int,
        paletteJSON: Data,
        pixelsJSON: Data,
        revealSequenceJSON: Data,
        createdAt: Date = Date()
    ) {
        self.artworkId = artworkId
        self.title = title
        self.mode = mode
        self.gridWidth = gridWidth
        self.gridHeight = gridHeight
        self.paletteJSON = paletteJSON
        self.pixelsJSON = pixelsJSON
        self.revealSequenceJSON = revealSequenceJSON
        self.createdAt = createdAt
    }
    
    // MARK: - Computed Properties
    
    /// Nombre total de pixels de l'œuvre
    var totalPixels: Int {
        return gridWidth * gridHeight
    }
    
    /// Décode la palette de couleurs depuis le JSON
    func decodePalette() -> [String] {
        guard let palette = try? JSONDecoder().decode([String].self, from: paletteJSON) else {
            return []
        }
        return palette
    }
    
    /// Décode les données de pixels depuis le JSON
    func decodePixels() -> [Int] {
        guard let pixels = try? JSONDecoder().decode([Int].self, from: pixelsJSON) else {
            return []
        }
        return pixels
    }
    
    /// Décode la séquence de révélation depuis le JSON
    func decodeRevealSequence() -> [Int] {
        guard let sequence = try? JSONDecoder().decode([Int].self, from: revealSequenceJSON) else {
            return []
        }
        return sequence
    }
}
