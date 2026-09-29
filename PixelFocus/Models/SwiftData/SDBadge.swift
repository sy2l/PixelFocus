/*
 * SDBadge.swift
 * PixelFocus
 *
 * Badge débloqué (voir BadgePolicy pour le catalogue).
 */

import Foundation
import SwiftData

// MARK: - SDBadge
@Model
final class SDBadge {
    @Attribute(.unique) var badgeId: String
    var unlockedAt: Date = Date()

    init(badgeId: String, unlockedAt: Date = Date()) {
        self.badgeId = badgeId
        self.unlockedAt = unlockedAt
    }
}
