/*
 * FocusSessionView.swift
 * PixelFocus
 *
 * Version: 1.0
 * Date: 15 janvier 2026
 *
 * UI robuste de session focus.
 *
 * Objectifs:
 * - Afficher le timer (remaining / overtime)
 * - Gérer les états: running, paused, finished, failed
 * - Permettre la reprise après pause (token)
 * - Permettre de continuer en overtime pour bonus >30
 *
 * Technique:
 * - Observe SessionManager via @ObservedObject
 * - Appelle les callbacks du host pour la complétion
 */

import SwiftUI

// MARK: - FocusSessionView
struct FocusSessionView: View {
    @ObservedObject var sessionManager: SessionManager
    
    let onClose: () -> Void
    let onSessionCompleted: (FocusSessionResult) -> Void

    var body: some View {
        ZStack {
            // Background gradient
            backgroundGradient
            
            VStack(spacing: 32) {
                Spacer()
                
                // Timer display
                timerDisplay
                
                // Status message
                statusMessage
                
                Spacer()
                
                // Action buttons
                actionButtons
            }
            .padding()
        }
        .onChange(of: sessionManager.state) { _, newState in
            if case .completed(let result) = newState {
                onSessionCompleted(result)
            }
        }
    }

    // MARK: - Background
    
    private var backgroundGradient: some View {
        Group {
            switch sessionManager.state {
            case .running:
                LinearGradient(
                    colors: [.blue.opacity(0.8), .purple.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .pausedRemainingTime:
                LinearGradient(
                    colors: [.orange.opacity(0.8), .yellow.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .finishedWaitingUserConfirmation:
                LinearGradient(
                    colors: [.green.opacity(0.8), .teal.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .failed:
                LinearGradient(
                    colors: [.red.opacity(0.8), .orange.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            default:
                LinearGradient(
                    colors: [.gray.opacity(0.8), .gray.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Timer Display
    
    private var timerDisplay: some View {
        VStack(spacing: 8) {
            switch sessionManager.state {
            case .running, .pausedRemainingTime:
                // Affiche le temps restant
                Text(SessionTiming.formatTime(seconds: sessionManager.remainingSeconds))
                    .font(.system(size: 80, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                
                Text("restant")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.8))
                
            case .finishedWaitingUserConfirmation:
                // Affiche l'overtime
                if sessionManager.overtimeSeconds > 0 {
                    Text("+\(SessionTiming.formatTime(seconds: sessionManager.overtimeSeconds))")
                        .font(.system(size: 60, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                    
                    Text("overtime bonus")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.8))
                } else {
                    Text("00:00")
                        .font(.system(size: 80, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                    
                    Text("terminé!")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.8))
                }
                
            case .failed(let reason):
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.white)
                
                Text(reason)
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                
            default:
                Text("--:--")
                    .font(.system(size: 80, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Status Message
    
    private var statusMessage: some View {
        VStack(spacing: 8) {
            switch sessionManager.state {
            case .running:
                HStack {
                    Image(systemName: "brain.head.profile")
                    Text("Concentre-toi...")
                }
                .font(.headline)
                .foregroundStyle(.white.opacity(0.9))
                
            case .pausedRemainingTime:
                HStack {
                    Image(systemName: "pause.circle.fill")
                    Text("Session en pause")
                }
                .font(.headline)
                .foregroundStyle(.white.opacity(0.9))
                
                Text("Token de protection utilisé")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                
            case .finishedWaitingUserConfirmation:
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Bravo!")
                }
                .font(.headline)
                .foregroundStyle(.white.opacity(0.9))
                
                if sessionManager.minutesSelected >= 30 {
                    Text("Continue pour le bonus >30 min")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
                
            case .failed:
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("Session échouée")
                }
                .font(.headline)
                .foregroundStyle(.white.opacity(0.9))
                
            default:
                EmptyView()
            }
        }
    }

    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 16) {
            switch sessionManager.state {
            case .running:
                runningButtons
                
            case .pausedRemainingTime:
                pausedButtons
                
            case .finishedWaitingUserConfirmation:
                finishedButtons
                
            case .failed:
                failedButtons
                
            default:
                EmptyView()
            }
        }
    }
    
    private var runningButtons: some View {
        Button {
            sessionManager.cancel()
            onClose()
        } label: {
            Text("Annuler")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(.white)
    }
    
    private var pausedButtons: some View {
        VStack(spacing: 12) {
            Button {
                sessionManager.resume()
            } label: {
                Label("Reprendre", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .foregroundStyle(.orange)
            
            Button {
                sessionManager.cancel()
                onClose()
            } label: {
                Text("Abandonner")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.white)
        }
    }
    
    private var finishedButtons: some View {
        VStack(spacing: 12) {
            Button {
                sessionManager.confirmCompletion()
            } label: {
                Label("Valider (+5 pixels)", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .foregroundStyle(.green)
            
            Button {
                sessionManager.cancel()
                onClose()
            } label: {
                Text("Quitter sans valider")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.white)
            
            if sessionManager.minutesSelected >= 30 {
                Text("Astuce: reste après 30 min pour le bonus du jour (cap 10 pixels)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var failedButtons: some View {
        Button {
            sessionManager.cancel()
            onClose()
        } label: {
            Text("Fermer")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(.white)
        .foregroundStyle(.red)
    }
}

// MARK: - Preview
#Preview {
    FocusSessionView(
        sessionManager: SessionManager(),
        onClose: {},
        onSessionCompleted: { _ in }
    )
}
