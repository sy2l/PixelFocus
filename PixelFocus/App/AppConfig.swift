/*
 * AppConfig.swift
 * PixelFocus
 *
 * Configuration globale de l'app.
 *
 * À faire avant la mise en production:
 * - Remplacer apiBaseURLString par l'adresse de l'API (ex: https://api.tondomaine.fr).
 *   Tant que l'adresse contient "CHANGE-ME", la synchronisation est désactivée et l'app fonctionne hors ligne.
 */

import Foundation

enum AppConfig {

    /// Adresse de l'API PixelFocus (dossier server/ du dépôt, hébergé chez o2switch)
    static let apiBaseURLString = "https://api.CHANGE-ME.fr"

    /// Identifiant du bundle (doit correspondre à apple.bundle_id côté serveur)
    static let bundleId = "com.sy2l.PixelFocus"

    static var apiBaseURL: URL? {
        guard isSyncConfigured else { return nil }
        return URL(string: apiBaseURLString)
    }

    /// Faux tant que l'adresse de l'API n'a pas été renseignée
    static var isSyncConfigured: Bool {
        !apiBaseURLString.contains("CHANGE-ME")
    }
}
