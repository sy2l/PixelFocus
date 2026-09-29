/*
 * SDProgress.swift
 * PixelFocus
 *
 * Version: 1.0
 * Date: 15 janvier 2026
 *
 * Progression SwiftData par œuvre.
 *
 * Objectifs:
 * - Suivre le nombre de pixels révélés.
 * - Gérer l'état: active / completed / toFinalize.
 */

import Foundation
import SwiftData

// MARK: - ProgressState
enum ProgressState: String, Codable {
    case active
    case completed
    case toFinalize
}

// MARK: - SDProgress
@Model
final class SDProgress {
    @Attribute(.unique) var artworkId: String
    var revealedCount: Int
    var stateRaw: String
    var updatedAt: Date
    
    /// Date ISO de l'œuvre (pour les daily)
    var artworkDateISO: String?
    
    /// Mois ISO de l'œuvre (pour les monthly)
    var artworkMonthISO: String?

    init(
        artworkId: String,
        revealedCount: Int = 0,
        state: ProgressState = .active,
        updatedAt: Date = Date(),
        artworkDateISO: String? = nil,
        artworkMonthISO: String? = nil
    ) {
        self.artworkId = artworkId
        self.revealedCount = revealedCount
        self.stateRaw = state.rawValue
        self.updatedAt = updatedAt
        self.artworkDateISO = artworkDateISO
        self.artworkMonthISO = artworkMonthISO
    }

    // MARK: - Computed
    var state: ProgressState {
        get { ProgressState(rawValue: stateRaw) ?? .active }
        set { stateRaw = newValue.rawValue }
    }
}
