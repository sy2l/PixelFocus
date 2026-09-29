/*
 * SessionManager.swift
 * PixelFocus
 *
 * Version: 1.0
 * Date: 15 janvier 2026
 *
 * Moteur de session focus (robuste, scalable).
 *
 * Fonctionnalités:
 * - Timer basé sur timestamps (pas de drift de Timer classique)
 * - Pause / reprise (reprendre au temps restant)
 * - Gestion interruption (background) via "protection token" (consommé via callback)
 * - Overtime: permettre de continuer après la fin (pour bonus >30)
 * - Fournit:
 *   - remainingSeconds (avant complétion)
 *   - overtimeSeconds (après complétion)
 *   - extraMinutesOver30 (minutes au-delà de 30 minutes d'actif)
 *
 * Intégration:
 * - Le host (FocusSessionHostView) fournit:
 *   - canConsumeProtectionToken() -> Bool
 *   - consumeProtectionToken() -> Void
 */

import Foundation
import SwiftUI

// MARK: - FocusSessionState
enum FocusSessionState: Equatable {
    case idle
    case running
    case pausedRemainingTime
    case finishedWaitingUserConfirmation   // session atteinte (0), utilisateur peut "Valider"
    case failed(reason: String)
    case completed(result: FocusSessionResult)
}

// MARK: - FocusSessionResult
struct FocusSessionResult: Equatable {
    let minutesSelected: Int
    let activeElapsedSeconds: Int
    let extraMinutesOver30: Int
}

// MARK: - SessionManager
@MainActor
final class SessionManager: ObservableObject {

    // MARK: - Published Properties
    @Published private(set) var state: FocusSessionState = .idle
    @Published private(set) var minutesSelected: Int = 25

    /// Avant complétion: remainingSeconds > 0.
    /// Après complétion: remainingSeconds == 0, overtimeSeconds augmente.
    @Published private(set) var remainingSeconds: Int = 0
    @Published private(set) var overtimeSeconds: Int = 0

    // MARK: - Timing Properties
    private var startDate: Date?
    private var pausedAt: Date?
    private var totalPausedSeconds: TimeInterval = 0

    private var tickTimer: Timer?

    // MARK: - Computed Properties
    private var targetSeconds: Int { minutesSelected * 60 }

    // Token callbacks (injectés par host)
    private var canConsumeProtectionToken: (() -> Bool)?
    private var consumeProtectionToken: (() -> Void)?

    // MARK: - Public Configuration
    
    /// Configure la session avec les paramètres et callbacks
    func configure(
        minutes: Int,
        canConsumeProtectionToken: @escaping () -> Bool,
        consumeProtectionToken: @escaping () -> Void
    ) {
        self.minutesSelected = minutes
        self.canConsumeProtectionToken = canConsumeProtectionToken
        self.consumeProtectionToken = consumeProtectionToken
    }

    // MARK: - Start / Stop
    
    /// Démarre une nouvelle session
    func start() {
        resetInternalState()

        startDate = Date()
        remainingSeconds = targetSeconds
        overtimeSeconds = 0
        state = .running

        startTicking()
    }

    /// Annule la session en cours
    func cancel() {
        stopTicking()
        resetInternalState()
        state = .idle
    }

    // MARK: - Interruption Handling
    
    /// Appelé quand l'app passe en background ou qu'une interruption survient.
    /// Si un token est disponible, la session est mise en pause et peut être reprise.
    func handleInterruption() {
        guard case .running = state else { return }

        // Pause immédiate
        pauseInternal()

        let tokenAvailable = canConsumeProtectionToken?() ?? false
        if tokenAvailable {
            consumeProtectionToken?()
            state = .pausedRemainingTime
        } else {
            state = .failed(reason: "Interruption sans protection.")
            stopTicking()
        }
    }

    // MARK: - Resume
    
    /// Reprend une session en pause
    func resume() {
        guard case .pausedRemainingTime = state else { return }
        resumeInternal()
        state = .running
        startTicking()
    }

    // MARK: - Finish Flow
    
    /// Appelé quand l'utilisateur valide la session après avoir atteint 0.
    /// C'est ici qu'on finalise le résultat (incluant overtime & bonus >30).
    func confirmCompletion() {
        guard case .finishedWaitingUserConfirmation = state else { return }
        stopTicking()

        let now = Date()
        guard let startDate else {
            state = .failed(reason: "Erreur interne (startDate manquant).")
            return
        }

        let activeElapsed = SessionTiming.activeElapsedSeconds(
            startDate: startDate,
            now: now,
            totalPausedSeconds: totalPausedSeconds
        )

        let result = FocusSessionResult(
            minutesSelected: minutesSelected,
            activeElapsedSeconds: activeElapsed,
            extraMinutesOver30: SessionTiming.extraMinutesOver30(activeElapsedSeconds: activeElapsed)
        )

        state = .completed(result: result)
    }

    // MARK: - Private Ticking
    
    private func startTicking() {
        stopTicking()

        // Tick rapide mais stable (0.25s) pour UI fluide, calcul basé sur timestamps
        tickTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.refreshTime()
            }
        }
    }

    private func stopTicking() {
        tickTimer?.invalidate()
        tickTimer = nil
    }

    private func refreshTime() {
        guard let startDate else { return }

        // Si on est en pause, ne pas avancer
        if case .pausedRemainingTime = state { return }
        if case .failed = state { return }
        if case .completed = state { return }
        if case .idle = state { return }

        let now = Date()
        let activeElapsed = SessionTiming.activeElapsedSeconds(
            startDate: startDate,
            now: now,
            totalPausedSeconds: totalPausedSeconds
        )

        let remaining = SessionTiming.remainingSeconds(
            targetSeconds: targetSeconds,
            activeElapsedSeconds: activeElapsed
        )

        let overtime = SessionTiming.overtimeSeconds(
            targetSeconds: targetSeconds,
            activeElapsedSeconds: activeElapsed
        )

        remainingSeconds = remaining
        overtimeSeconds = overtime

        // Atteint 0 -> on passe en état "attente validation" (l'utilisateur peut continuer en overtime)
        if remaining == 0 {
            if case .running = state {
                state = .finishedWaitingUserConfirmation
            }
        }
    }

    // MARK: - Pause Internal
    
    private func pauseInternal() {
        guard pausedAt == nil else { return }
        pausedAt = Date()
        stopTicking()
    }

    private func resumeInternal() {
        guard let pausedAt else { return }
        let pausedDuration = Date().timeIntervalSince(pausedAt)
        totalPausedSeconds += pausedDuration
        self.pausedAt = nil
    }

    // MARK: - Reset
    
    private func resetInternalState() {
        startDate = nil
        pausedAt = nil
        totalPausedSeconds = 0

        remainingSeconds = 0
        overtimeSeconds = 0

        canConsumeProtectionToken = nil
        consumeProtectionToken = nil
    }
}
