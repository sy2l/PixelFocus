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
 * - Toggle Premium (simulé) via AppCoordinator / EntitlementStore
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
    @EnvironmentObject private var appCoordinator: AppCoordinator
    @EnvironmentObject private var entitlements: EntitlementStore

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
            // Passe par AppCoordinator: mémorise la fin d'abonnement et l'octroi mensuel de boosters
            Toggle(isOn: Binding(
                get: { entitlements.isPremium },
                set: { appCoordinator.setPremium($0) }
            )) {
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
            
            if entitlements.isPremium {
                PremiumPerkRow(text: "15 & 20 min illimités")
                PremiumPerkRow(text: "Toutes les images du mois")
                PremiumPerkRow(text: "2 boosters offerts chaque mois")
                PremiumPerkRow(text: "3 boosters gagnés utilisables par jour")
            }
        } header: {
            Text("Compte")
        } footer: {
            Text("L'abonnement sera géré via l'App Store (StoreKit) dans une prochaine version.")
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
            StatRow(icon: "bolt.fill", color: .purple, title: "Boosters gagnés", value: "\(wallet?.earnedBoosters ?? 0)/12")
            StatRow(icon: "bolt.circle.fill", color: .purple, title: "Boosters achetés", value: "\(wallet?.purchasedBoosters ?? 0)")
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
            RuleRow(icon: "flame.fill", text: "Série : daily du jour terminée chaque jour → 1 booster tous les 3 jours, +1 tous les 18 jours")
            RuleRow(icon: "bolt.fill", text: "Booster : révèle 5 pixels. Gagnés : 1/jour (3 en Premium). Achetés : sans limite")
            RuleRow(icon: "clock.badge.exclamationmark", text: "Daily non finie : purgée le 4 du mois suivant")
            RuleRow(icon: "gift.fill", text: "Image du mois : la première est offerte, puis Premium, défi (20 sessions) ou achat")
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

// MARK: - PremiumPerkRow
private struct PremiumPerkRow: View {
    let text: String

    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(text)
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
}

// MARK: - Preview
#Preview {
    SettingsView()
        .environmentObject(AppCoordinator())
        .environmentObject(EntitlementStore())
        .modelContainer(for: [SDWallet.self, SDStreak.self, SDProgress.self], inMemory: true)
}
