/*
 * SessionTiming.swift
 * PixelFocus
 *
 * Version: 1.0
 * Date: 15 janvier 2026
 *
 * Logique pure (sans UI) pour calculer:
 * - elapsed actif
 * - remaining avant complétion
 * - overtime (temps au-delà de la durée cible)
 * - extraMinutesOver30 (temps au-delà de 30 minutes, en minutes entières)
 *
 * Objectifs:
 * - Rendre le moteur testable facilement (XCTest)
 * - Éviter les calculs dispersés dans UI/Timer
 */

import Foundation

// MARK: - SessionTiming
enum SessionTiming {

    // MARK: - Active Elapsed
    
    /// Retourne le temps actif écoulé en secondes entre `startDate` et `now`,
    /// en excluant les durées de pause.
    static func activeElapsedSeconds(
        startDate: Date,
        now: Date,
        totalPausedSeconds: TimeInterval
    ) -> Int {
        let rawElapsed = now.timeIntervalSince(startDate)
        let activeElapsed = max(0, rawElapsed - totalPausedSeconds)
        return Int(activeElapsed.rounded(.down))
    }

    // MARK: - Remaining
    
    /// Retourne le temps restant en secondes avant d'atteindre la durée cible.
    /// Si déjà dépassé, retourne 0.
    static func remainingSeconds(
        targetSeconds: Int,
        activeElapsedSeconds: Int
    ) -> Int {
        max(0, targetSeconds - activeElapsedSeconds)
    }

    // MARK: - Overtime
    
    /// Retourne les secondes de dépassement au-delà de la durée cible.
    static func overtimeSeconds(
        targetSeconds: Int,
        activeElapsedSeconds: Int
    ) -> Int {
        max(0, activeElapsedSeconds - targetSeconds)
    }

    // MARK: - Over 30 Bonus Minutes
    
    /// Retourne les minutes complètes au-delà de 30 minutes de temps actif.
    /// Exemple: 31:59 => 1 minute, 39:00 => 9 minutes.
    static func extraMinutesOver30(activeElapsedSeconds: Int) -> Int {
        let threshold = 30 * 60
        guard activeElapsedSeconds > threshold else { return 0 }
        let extraSeconds = activeElapsedSeconds - threshold
        return Int((Double(extraSeconds) / 60.0).rounded(.down))
    }
    
    // MARK: - Formatting
    
    /// Formate les secondes en chaîne "MM:SS"
    static func formatTime(seconds: Int) -> String {
        let positive = max(0, seconds)
        let minutes = positive / 60
        let secs = positive % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
    
    /// Formate les secondes en chaîne "HH:MM:SS" si nécessaire
    static func formatTimeLong(seconds: Int) -> String {
        let positive = max(0, seconds)
        let hours = positive / 3600
        let minutes = (positive % 3600) / 60
        let secs = positive % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
}
