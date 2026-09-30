/*
 * SDEvent.swift
 * PixelFocus
 *
 * Historique local des événements de jeu (source de vérité partagée avec le serveur).
 *
 * - Chaque action (session terminée, booster utilisé/gagné, badge, jour actif…) crée un événement
 *   avec un UUID généré ici: le serveur ignore les doublons.
 * - isSynced: faux tant que le serveur ne l'a pas reçu.
 * - Les événements venus d'un autre appareil sont enregistrés avec isSynced = vrai.
 */

import Foundation
import SwiftData

// MARK: - EventType
enum EventType: String, CaseIterable {
    case sessionCompleted = "session_completed"
    case boosterUsed = "booster_used"
    case boosterEarned = "booster_earned"
    case protectionTokenEarned = "protection_token_earned"
    case protectionTokenUsed = "protection_token_used"
    case badgeUnlocked = "badge_unlocked"
    case monthlyUnlocked = "monthly_unlocked"
    case dayActive = "day_active"
}

// MARK: - SDEvent
@Model
final class SDEvent {
    @Attribute(.unique) var id: String
    var type: String
    var artworkId: String?
    /// Contenu JSON (JSONValue encodé)
    var payloadJSON: Data?
    var occurredAt: Date
    var isSynced: Bool = false

    init(
        id: String = UUID().uuidString.lowercased(),
        type: EventType,
        artworkId: String? = nil,
        payload: [String: JSONValue]? = nil,
        occurredAt: Date = Date(),
        isSynced: Bool = false
    ) {
        self.id = id
        self.type = type.rawValue
        self.artworkId = artworkId
        self.payloadJSON = payload.flatMap { try? JSONEncoder().encode(JSONValue.object($0)) }
        self.occurredAt = occurredAt
        self.isSynced = isSynced
    }

    var payload: JSONValue? {
        payloadJSON.flatMap { try? JSONDecoder().decode(JSONValue.self, from: $0) }
    }

    /// Représentation envoyée à l'API
    var apiEvent: APIEvent {
        APIEvent(
            id: id,
            type: type,
            artworkId: artworkId,
            payload: payload,
            occurredAt: ISO8601DateFormatter.api.string(from: occurredAt)
        )
    }
}
