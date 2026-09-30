/*
 * PixelFocusApp.swift
 * PixelFocus
 *
 * Entrée principale de l'application.
 *
 * Objectifs:
 * - Créer la base SwiftData et le coordinateur (moteur, synchronisation, achats)
 * - Injecter les objets partagés dans toute l'interface
 */

import SwiftUI
import SwiftData

@main
struct PixelFocusApp: App {

    private let modelContainer: ModelContainer
    @StateObject private var appCoordinator: AppCoordinator

    init() {
        let container = AppSchema.makeContainer()
        modelContainer = container
        _appCoordinator = StateObject(wrappedValue: AppCoordinator(modelContext: container.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .withAppEnvironment(appCoordinator)
        }
        .modelContainer(modelContainer)
    }
}

// MARK: - Environnement partagé
extension View {
    /// Injecte le coordinateur et ses services (utilisé par l'app et les aperçus Xcode)
    func withAppEnvironment(_ coordinator: AppCoordinator) -> some View {
        self
            .environmentObject(coordinator)
            .environmentObject(coordinator.entitlements)
            .environmentObject(coordinator.syncService)
            .environmentObject(coordinator.purchaseManager)
            .modelContext(coordinator.modelContext)
    }
}
