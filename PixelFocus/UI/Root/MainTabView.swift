/*
 * MainTabView.swift
 * PixelFocus
 *
 * Root UI: TabView + thème.
 *
 * Objectifs:
 * - Injecter AppCoordinator et EntitlementStore
 * - Configurer SwiftData ModelContext
 * - Charger le contenu JSON au lancement, réappliquer les règles de dates au retour au premier plan
 * - Appliquer le thème choisi (Minuit par défaut; Soleil/Braise réservés au Premium)
 */

import SwiftUI
import SwiftData

// MARK: - MainTabView
struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var appCoordinator: AppCoordinator = AppCoordinator()

    var body: some View {
        ThemedTabView()
            .environmentObject(appCoordinator)
            .environmentObject(appCoordinator.entitlements)
            .task {
                appCoordinator.configure(modelContext: modelContext)
                appCoordinator.loadInitialContentIfNeeded()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    appCoordinator.applyDatePolicies()
                }
            }
    }
}

// MARK: - ThemedTabView
private struct ThemedTabView: View {
    @EnvironmentObject private var entitlements: EntitlementStore
    @AppStorage(AppTheme.storageKey) private var storedTheme: String = AppTheme.minuit.rawValue

    var body: some View {
        let theme = AppTheme.effective(storedRawValue: storedTheme, isPremium: entitlements.isPremium)
        let palette = theme.palette

        TabView {
            TodayView()
                .tabItem { Label("Aujourd'hui", systemImage: "sun.max") }

            CalendarView()
                .tabItem { Label("Calendrier", systemImage: "calendar") }

            CollectionView()
                .tabItem { Label("Collection", systemImage: "square.grid.2x2") }

            SettingsView()
                .tabItem { Label("Réglages", systemImage: "gearshape") }
        }
        .tint(palette.primary)
        .environment(\.theme, palette)
        .preferredColorScheme(palette.colorScheme)
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
            SDDailyQuota.self,
            SDMonthStats.self,
            SDActiveDay.self,
            SDBadge.self
        ], inMemory: true)
}
