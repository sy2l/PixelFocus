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
    @Environment(\.theme) private var theme
    
    /// Tâche choisie avant la session ("Sur quoi vas-tu te concentrer ?")
    var intention: String = ""
    let onClose: () -> Void
    /// Résultat de la session + réponse au bilan ("Tâche terminée ?"), nil si non répondu
    let onSessionCompleted: (FocusSessionResult, Bool?) -> Void

    @State private var taskDone: Bool?

    var body: some View {
        ZStack {
            // Background gradient
            backgroundGradient
            
            VStack(spacing: 32) {
                intentionHeader

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
                onSessionCompleted(result, taskDone)
            }
        }
    }

    // MARK: - Intention

    @ViewBuilder
    private var intentionHeader: some View {
        if !intention.isEmpty {
            VStack(spacing: 4) {
                Text("Objectif de la session")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                Text(intention)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(.top, 24)
        }
    }

    // MARK: - Background
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [stateColor.opacity(0.45), theme.background],
            startPoint: .top,
            endPoint: .bottom
        )
        .background(theme.background)
        .ignoresSafeArea()
        .animation(.easeInOut, value: sessionManager.state)
    }

    /// Couleur d'ambiance selon l'état de la session (issue du thème)
    private var stateColor: Color {
        switch sessionManager.state {
        case .running: return theme.primary
        case .pausedRemainingTime: return theme.record
        case .finishedWaitingUserConfirmation: return theme.success
        case .failed: return theme.danger
        default: return theme.surfaceHighlight
        }
    }

    // MARK: - Timer Display
    
    private var timerDisplay: some View {
        VStack(spacing: 8) {
            switch sessionManager.state {
            case .running, .pausedRemainingTime:
                // Affiche le temps restant
                Text(SessionTiming.formatTime(seconds: sessionManager.remainingSeconds))
                    .font(.system(size: 80, weight: .bold, design: .monospaced))
                    .foregroundStyle(theme.textPrimary)
                
                Text("restant")
                    .font(.title3)
                    .foregroundStyle(theme.textSecondary)
                
            case .finishedWaitingUserConfirmation:
                // Affiche l'overtime
                if sessionManager.overtimeSeconds > 0 {
                    Text("+\(SessionTiming.formatTime(seconds: sessionManager.overtimeSeconds))")
                        .font(.system(size: 60, weight: .bold, design: .monospaced))
                        .foregroundStyle(theme.textPrimary)
                    
                    Text("overtime bonus")
                        .font(.title3)
                        .foregroundStyle(theme.textSecondary)
                } else {
                    Text("00:00")
                        .font(.system(size: 80, weight: .bold, design: .monospaced))
                        .foregroundStyle(theme.textPrimary)
                    
                    Text("terminé!")
                        .font(.title3)
                        .foregroundStyle(theme.textSecondary)
                }
                
            case .failed(let reason):
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(theme.textPrimary)
                
                Text(reason)
                    .font(.title3)
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                
            default:
                Text("--:--")
                    .font(.system(size: 80, weight: .bold, design: .monospaced))
                    .foregroundStyle(theme.textPrimary)
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
                    Text("Reste sur ta tâche, le reste peut attendre.")
                }
                .font(.headline)
                .foregroundStyle(theme.textPrimary)
                .multilineTextAlignment(.center)

                Text("Astuce : active le mode Concentration (Ne pas déranger) et pose ton téléphone face contre la table.")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                
            case .pausedRemainingTime:
                HStack {
                    Image(systemName: "pause.circle.fill")
                    Text("Session en pause")
                }
                .font(.headline)
                .foregroundStyle(theme.textPrimary)
                
                Text("Token de protection utilisé")
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
                
            case .finishedWaitingUserConfirmation:
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Bravo!")
                }
                .font(.headline)
                .foregroundStyle(theme.textPrimary)
                
                if sessionManager.minutesSelected >= 30 {
                    Text("Continue pour le bonus >30 min")
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                }
                
            case .failed:
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("Session échouée")
                }
                .font(.headline)
                .foregroundStyle(theme.textPrimary)
                
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
        .tint(theme.primary)
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
            .tint(theme.primary)
            .foregroundStyle(theme.onPrimary)
            
            Button {
                sessionManager.cancel()
                onClose()
            } label: {
                Text("Abandonner")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(theme.primary)
        }
    }
    
    private var finishedButtons: some View {
        VStack(spacing: 12) {
            Text(intention.isEmpty ? "As-tu avancé sur ta tâche ?" : "As-tu terminé « \(intention) » ?")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.textPrimary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button {
                    taskDone = true
                    sessionManager.confirmCompletion()
                } label: {
                    Label("Terminée", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(PrimaryButtonStyle())

                Button {
                    taskDone = false
                    sessionManager.confirmCompletion()
                } label: {
                    Text("Pas encore")
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            Text("Dans les deux cas, ta session compte : +5 pixels révélés.")
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
            
            Button {
                sessionManager.cancel()
                onClose()
            } label: {
                Text("Quitter sans valider")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(theme.primary)
            
            if sessionManager.minutesSelected >= 30 {
                Text("Astuce: reste après 30 min pour le bonus du jour (cap 10 pixels)")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
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
        .tint(theme.primary)
        .foregroundStyle(theme.onPrimary)
    }
}

// MARK: - Preview
#Preview {
    FocusSessionView(
        sessionManager: SessionManager(),
        intention: "Réviser le chapitre 3",
        onClose: {},
        onSessionCompleted: { _, _ in }
    )
}
