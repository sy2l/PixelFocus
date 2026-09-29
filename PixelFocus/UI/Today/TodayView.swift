/*
 * TodayView.swift
 * PixelFocus
 *
 * Version: 1.0
 * Date: 15 janvier 2026
 *
 * Écran "Aujourd'hui" (V1).
 *
 * Objectifs:
 * - Afficher Daily / Weekly / Monthly actuels
 * - Montrer quotas + streak + banked pixels
 * - Navigation vers ArtworkDetailView
 *
 * Technique:
 * - AppCoordinator via EnvironmentObject
 * - SwiftData via @Query pour wallet/streak
 */

import SwiftUI
import SwiftData

// MARK: - TodayView
struct TodayView: View {
    @EnvironmentObject private var appCoordinator: AppCoordinator
    @AppStorage("isPremiumUser") private var isPremiumUser: Bool = false

    @Query private var wallets: [SDWallet]
    @Query private var streaks: [SDStreak]
    @Query private var dailyQuotas: [SDDailyQuota]

    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    if let loadingError = appCoordinator.loadingErrorMessage {
                        errorBanner(message: loadingError)
                    }

                    if let errorMessage {
                        errorBanner(message: errorMessage)
                    }

                    streakSection
                    quotasSection
                    contentSection

                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Aujourd'hui")
            .refreshable {
                appCoordinator.loadInitialContentIfNeeded()
            }
        }
    }

    // MARK: - Error Banner
    private func errorBanner(message: String) -> some View {
        Text(message)
            .foregroundStyle(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.red.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Streak Section
    private var streakSection: some View {
        let streakValue = streaks.first?.current ?? 0
        let longestStreak = streaks.first?.longestStreak ?? 0
        let banked = wallets.first?.bankedPixels ?? 0
        let tokens = wallets.first?.protectionTokensAvailable ?? 0

        return VStack(alignment: .leading, spacing: 12) {
            Text("Streak & Bonus")
                .font(.headline)

            HStack(spacing: 16) {
                StatCard(title: "Streak", value: "\(streakValue)", subtitle: "jour(s)", icon: "flame.fill", color: .orange)
                StatCard(title: "Record", value: "\(longestStreak)", subtitle: "jour(s)", icon: "trophy.fill", color: .yellow)
            }
            
            HStack(spacing: 16) {
                StatCard(title: "Pixels stockés", value: "\(banked)/5", subtitle: "", icon: "square.grid.3x3.fill", color: .purple)
                StatCard(title: "Tokens", value: "\(tokens)", subtitle: "protection", icon: "shield.fill", color: .blue)
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Quotas Section
    private var quotasSection: some View {
        let todayISO = DatePolicy.isoDayString(for: Date())
        let todayQuota = dailyQuotas.first(where: { $0.dayISO == todayISO })
        let used15 = todayQuota?.used15 ?? 0
        let used20 = todayQuota?.used20 ?? 0

        return VStack(alignment: .leading, spacing: 8) {
            Text("Quotas du jour")
                .font(.headline)

            if isPremiumUser {
                Text("Premium : toutes les durées sont illimitées ✨")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                HStack {
                    QuotaIndicator(duration: 15, used: used15, max: 1)
                    QuotaIndicator(duration: 20, used: used20, max: 1)
                    QuotaIndicator(duration: 25, used: nil, max: nil, isUnlimited: true)
                    QuotaIndicator(duration: 30, used: nil, max: nil, isUnlimited: true)
                }
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Content Section
    private var contentSection: some View {
        VStack(spacing: 12) {
            // Daily
            if let dailyId = appCoordinator.todayDailyArtworkId() {
                NavigationLink {
                    ArtworkDetailView(artworkId: dailyId)
                } label: {
                    ContentCard(
                        title: "Image du jour",
                        subtitle: "Daily • 5×5 pixels",
                        icon: "sun.max.fill",
                        color: .orange
                    )
                }
            } else {
                ContentCard(
                    title: "Image du jour",
                    subtitle: "Aucune daily disponible",
                    icon: "sun.max",
                    color: .gray
                )
            }

            // Weekly
            if let weeklyId = appCoordinator.currentWeeklyArtworkId() {
                NavigationLink {
                    ArtworkDetailView(artworkId: weeklyId)
                } label: {
                    ContentCard(
                        title: "Image de la semaine",
                        subtitle: "Weekly • Plus grande",
                        icon: "calendar",
                        color: .blue
                    )
                }
            } else {
                ContentCard(
                    title: "Image de la semaine",
                    subtitle: "Aucune weekly disponible",
                    icon: "calendar",
                    color: .gray
                )
            }

            // Monthly
            if let monthlyId = appCoordinator.currentMonthlyArtworkId() {
                let isPremiumContent = appCoordinator.isMonthlyPremium()
                
                NavigationLink {
                    ArtworkDetailView(artworkId: monthlyId)
                } label: {
                    ContentCard(
                        title: "Image du mois",
                        subtitle: isPremiumContent ? "Monthly • Premium ⭐" : "Monthly • Grande œuvre",
                        icon: "star.fill",
                        color: isPremiumContent ? .yellow : .purple
                    )
                }
            } else {
                ContentCard(
                    title: "Image du mois",
                    subtitle: "Aucune monthly disponible",
                    icon: "star",
                    color: .gray
                )
            }
        }
    }
}

// MARK: - StatCard
struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.title2)
                .bold()
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - QuotaIndicator
struct QuotaIndicator: View {
    let duration: Int
    let used: Int?
    let max: Int?
    var isUnlimited: Bool = false
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(duration)")
                .font(.headline)
            Text("min")
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            if isUnlimited {
                Text("∞")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else if let used, let max {
                Text("\(max - used)/\(max)")
                    .font(.caption)
                    .foregroundStyle(used >= max ? .red : .green)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - ContentCard
struct ContentCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Preview
#Preview {
    TodayView()
        .environmentObject(AppCoordinator())
        .modelContainer(for: [SDWallet.self, SDStreak.self, SDDailyQuota.self], inMemory: true)
}
