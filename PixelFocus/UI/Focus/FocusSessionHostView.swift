/*
 * FocusSessionHostView.swift
 * PixelFocus
 *
 * Version: 1.0
 * Date: 15 janvier 2026
 *
 * Host de session focus (plein écran) qui:
 * - pilote SessionManager
 * - applique le résultat dans GameEngine (+5 pixels, token 30, bonus >30)
 * - gère l'interruption via token (pause/reprise au temps restant)
 *
 * Technique:
 * - Configure SessionManager avec les callbacks token
 * - Observe les états du SessionManager
 * - Applique les récompenses via GameEngine à la complétion
 */

import SwiftUI
import SwiftData

// MARK: - FocusSessionHostView
struct FocusSessionHostView: View {
    @EnvironmentObject private var appCoordinator: AppCoordinator
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    let artworkId: String
    let minutesSelected: Int
    let isPremiumUser: Bool
    let onClose: () -> Void

    @State private var errorMessage: String?
    @State private var hasStarted: Bool = false

    var body: some View {
        ZStack {
            if let sessionManager = appCoordinator.getSessionManager() {
                FocusSessionView(
                    sessionManager: sessionManager,
                    onClose: onClose,
                    onSessionCompleted: { result in
                        applyCompletion(result: result)
                        onClose()
                    }
                )
            } else {
                VStack {
                    Text("Erreur: SessionManager non disponible")
                        .foregroundStyle(.red)
                    Button("Fermer") {
                        onClose()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                appCoordinator.getSessionManager()?.handleInterruption()
            }
        }
        .task {
            startSession()
        }
    }

    // MARK: - Start Session
    
    private func startSession() {
        guard !hasStarted else { return }
        hasStarted = true
        
        guard let sessionManager = appCoordinator.getSessionManager() else { return }

        sessionManager.configure(
            minutes: minutesSelected,
            canConsumeProtectionToken: {
                canUseProtectionTokenFromWallet()
            },
            consumeProtectionToken: {
                consumeProtectionTokenInWallet()
            }
        )

        sessionManager.start()
    }

    // MARK: - Completion
    
    private func applyCompletion(result: FocusSessionResult) {
        guard let engine = appCoordinator.getEngine() else { return }
        let todayISO = DatePolicy.isoDayString(for: Date())

        do {
            try engine.applyCompletedSession(
                artworkId: artworkId,
                minutes: result.minutesSelected,
                todayISO: todayISO,
                dailyDateISO: appCoordinator.dailyDateISO(forArtworkId: artworkId),
                didExceed30By: result.extraMinutesOver30
            )
        } catch {
            errorMessage = "Erreur completion: \(error.localizedDescription)"
        }
    }

    // MARK: - Token Helpers
    
    private func canUseProtectionTokenFromWallet() -> Bool {
        let todayISO = DatePolicy.isoDayString(for: Date())
        do {
            let descriptor = FetchDescriptor<SDWallet>()
            if let wallet = try modelContext.fetch(descriptor).first {
                wallet.resetDailyIfNeeded(todayISO: todayISO)
                return wallet.protectionTokensAvailable > 0
            }
            return false
        } catch {
            return false
        }
    }

    private func consumeProtectionTokenInWallet() {
        let todayISO = DatePolicy.isoDayString(for: Date())
        do {
            let descriptor = FetchDescriptor<SDWallet>()
            if let wallet = try modelContext.fetch(descriptor).first {
                wallet.resetDailyIfNeeded(todayISO: todayISO)
                if wallet.protectionTokensAvailable > 0 {
                    wallet.protectionTokensAvailable -= 1
                    try modelContext.save()
                }
            }
        } catch {
            // Ignorer l'erreur pour le MVP
        }
    }
}

// MARK: - Preview
#Preview {
    FocusSessionHostView(
        artworkId: "daily_2026_01_15",
        minutesSelected: 25,
        isPremiumUser: false,
        onClose: {}
    )
    .environmentObject(AppCoordinator())
    .modelContainer(for: [SDWallet.self], inMemory: true)
}
