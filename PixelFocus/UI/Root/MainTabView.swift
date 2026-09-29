/*
 * MainTabView.swift
 * PixelFocus
 *
 * Version: 1.0
 * Date: 15 janvier 2026
 *
 * Root UI: TabView (V1 complète).
 *
 * Objectifs:
 * - Injecter AppCoordinator (scalable)
 * - Configurer SwiftData ModelContext
 * - Charger le contenu JSON au lancement
 */

import SwiftUI
import SwiftData

// MARK: - MainTabView
struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext

    @StateObject private var appCoordinator: AppCoordinator = AppCoordinator()

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Aujourd'hui", systemImage: "sun.max") }

            CalendarView()
                .tabItem { Label("Calendrier", systemImage: "calendar") }

            CollectionView()
                .tabItem { Label("Collection", systemImage: "square.grid.2x2") }

            SettingsView()
                .tabItem { Label("Réglages", systemImage: "gear") }
        }
        .environmentObject(appCoordinator)
        .task {
            appCoordinator.configure(modelContext: modelContext)
            appCoordinator.loadInitialContentIfNeeded()
        }
    }
}

// MARK: - Preview
#Preview {
    MainTabView()
        .modelContainer(for: [
            SDArtwork.self,
            SDProgress.self,
            SDStreak.self,
            SDWallet.self,
            SDDailyQuota.self
        ], inMemory: true)
}
