/*
 * MainTabView.swift
 * PixelFocus
 *
 * Root UI: TabView + thème.
 *
 * Objectifs:
 * - Les objets partagés sont injectés par PixelFocusApp (withAppEnvironment)
 * - Charger le contenu JSON au lancement, réappliquer les règles de dates au retour au premier plan
 * - Appliquer le thème choisi (Minuit par défaut; Soleil/Braise réservés au Premium)
 */

import SwiftUI
import SwiftData

// MARK: - MainTabView
struct MainTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var appCoordinator: AppCoordinator
    @AppStorage(OnboardingView.storageKey) private var hasSeenOnboarding = false

    var body: some View {
        ThemedTabView(showOnboarding: !hasSeenOnboarding, onFinishOnboarding: { hasSeenOnboarding = true })
            .task {
                appCoordinator.loadInitialContentIfNeeded()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    appCoordinator.applyDatePolicies()
                    appCoordinator.requestSync()
                }
            }
    }
}

// MARK: - ThemedTabView
private struct ThemedTabView: View {
    let showOnboarding: Bool
    let onFinishOnboarding: () -> Void

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
        .fullScreenCover(isPresented: .constant(showOnboarding)) {
            OnboardingView(onFinish: onFinishOnboarding)
                .environment(\.theme, palette)
        }
        .environment(\.theme, palette)
        .preferredColorScheme(palette.colorScheme)
    }
}

// MARK: - Preview
#Preview {
    MainTabView()
        .withAppEnvironment(AppCoordinator())
}
