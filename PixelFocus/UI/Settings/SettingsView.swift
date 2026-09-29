/*
 * SettingsView.swift
 * PixelFocus
 *
 * Version: 1.0
 * Date: 15 janvier 2026
 *
 * Réglages (V1).
 *
 * Objectifs:
 * - Toggle Premium (MVP) via AppStorage
 * - Infos sur quotas et règles
 * - Stats utilisateur
 *
 * Note:
 * - V1.1: remplacement par StoreKit (abonnement).
 */

import SwiftUI
import SwiftData

// MARK: - SettingsView
struct SettingsView: View {
    @AppStorage("isPremiumUser") private var isPremiumUser: Bool = false
    
    @Query private var wallets: [SDWallet]
    @Query private var streaks: [SDStreak]
    @Query private var progresses: [SDProgress]

    var body: some View {
        NavigationStack {
            Form {
                // Section Compte
                accountSection
                
                // Section Stats
                statsSection
                
                // Section Règles
                rulesSection
                
                // Section À propos
                aboutSection
            }
            .navigationTitle("Réglages")
        }
    }
    
    // MARK: - Account Section
    
    private var accountSection: some View {
        Section {
            Toggle(isOn: $isPremiumUser) {
                HStack {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(.yellow)
                    VStack(alignment: .leading) {
                        Text("Premium")
                            .font(.headline)
                        Text("Simulé pour le MVP")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            if isPremiumUser {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("15 & 20 min illimités")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Accès aux œuvres mensuelles")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        } header: {
            Text("Compte")
        } footer: {
            Text("En V1.1, l'abonnement sera géré via StoreKit.")
        }
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        Section("Statistiques") {
            let wallet = wallets.first
            let streak = streaks.first
            let completedCount = progresses.filter { $0.state == .completed }.count
            let totalPixelsRevealed = progresses.reduce(0) { $0 + $1.revealedCount }
            
            StatRow(icon: "flame.fill", color: .orange, title: "Streak actuel", value: "\(streak?.current ?? 0) jour(s)")
            StatRow(icon: "trophy.fill", color: .yellow, title: "Record streak", value: "\(streak?.longestStreak ?? 0) jour(s)")
            StatRow(icon: "square.grid.3x3.fill", color: .purple, title: "Pixels stockés", value: "\(wallet?.bankedPixels ?? 0)/5")
            StatRow(icon: "shield.fill", color: .blue, title: "Tokens protection", value: "\(wallet?.protectionTokensAvailable ?? 0)")
            StatRow(icon: "checkmark.circle.fill", color: .green, title: "Œuvres terminées", value: "\(completedCount)")
            StatRow(icon: "sparkles", color: .pink, title: "Pixels révélés", value: "\(totalPixelsRevealed)")
        }
    }
    
    // MARK: - Rules Section
    
    private var rulesSection: some View {
        Section("Règles du jeu") {
            RuleRow(icon: "timer", text: "1 session terminée = +5 pixels (peu importe la durée)")
            RuleRow(icon: "15.circle", text: "Gratuit : 15 min = 1/jour")
            RuleRow(icon: "20.circle", text: "Gratuit : 20 min = 1/jour")
            RuleRow(icon: "25.circle.fill", text: "25 min : illimité (recommandé)")
            RuleRow(icon: "30.circle.fill", text: "30 min : illimité + 1 token protection")
            RuleRow(icon: "shield.fill", text: "Token : reprendre au temps restant si interruption")
            RuleRow(icon: "flame.fill", text: "Streak : tous les 5 jours → +5 pixels stockables")
            RuleRow(icon: "clock.badge.exclamationmark", text: "Daily non finie : purgée le 4 du mois suivant")
            RuleRow(icon: "star.fill", text: "Monthly : jamais purgée, achetable jusqu'à février N+1")
        }
    }
    
    // MARK: - About Section
    
    private var aboutSection: some View {
        Section("À propos") {
            HStack {
                Text("Version")
                Spacer()
                Text("1.0.0")
                    .foregroundStyle(.secondary)
            }
            
            HStack {
                Text("Build")
                Spacer()
                Text("MVP")
                    .foregroundStyle(.secondary)
            }
            
            Link(destination: URL(string: "https://example.com/privacy")!) {
                HStack {
                    Text("Politique de confidentialité")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(.secondary)
                }
            }
            
            Link(destination: URL(string: "https://example.com/terms")!) {
                HStack {
                    Text("Conditions d'utilisation")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(.secondary)
                }
            }
            
            Button {
                // Restore purchases - à implémenter avec StoreKit
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Restaurer les achats")
                }
            }
        }
    }
}

// MARK: - StatRow
struct StatRow: View {
    let icon: String
    let color: Color
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - RuleRow
struct RuleRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - Preview
#Preview {
    SettingsView()
        .modelContainer(for: [SDWallet.self, SDStreak.self, SDProgress.self], inMemory: true)
}
