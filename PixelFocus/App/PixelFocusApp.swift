/*
 * PixelFocusApp.swift
 * PixelFocus
 *
 * Version: 1.0
 * Date: 15 janvier 2026
 *
 * Entrée principale de l'application.
 *
 * Objectifs:
 * - Configurer SwiftData container.
 * - Charger ruleset + catalog au lancement.
 * - Mettre en place le MainTabView.
 */

import SwiftUI
import SwiftData

@main
struct PixelFocusApp: App {

    // MARK: - SwiftData Container
    private var modelContainer: ModelContainer = {
        let schema = Schema([
            SDArtwork.self,
            SDProgress.self,
            SDStreak.self,
            SDWallet.self,
            SDDailyQuota.self,
            SDMonthStats.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Impossible de créer le ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(modelContainer)
    }
}
