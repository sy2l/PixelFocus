/*
 * TodayView.swift
 * PixelFocus
 *
 * Écran "Aujourd'hui" (maquette v2).
 *
 * Objectifs:
 * - Grande carte: la daily du jour (pixel art + progression)
 * - Barre de session: durée + lancement direct
 * - Tuiles: série, record, boosters, tokens
 * - Cartes weekly / monthly (verrou + défi du mois)
 *
 * Technique:
 * - AppCoordinator / EntitlementStore via EnvironmentObject
 * - SwiftData via @Query (wallet, streak, quotas, progressions, œuvres, stats, badges)
 */

import SwiftUI
import SwiftData

// MARK: - TodayView
struct TodayView: View {
    @EnvironmentObject private var appCoordinator: AppCoordinator
    @EnvironmentObject private var entitlements: EntitlementStore
    @Environment(\.theme) private var theme

    @Query private var wallets: [SDWallet]
    @Query private var streaks: [SDStreak]
    @Query private var dailyQuotas: [SDDailyQuota]
    @Query private var progresses: [SDProgress]
    @Query private var artworks: [SDArtwork]
    @Query private var monthStats: [SDMonthStats]
    @Query(sort: \SDBadge.unlockedAt, order: .reverse) private var badges: [SDBadge]

    @State private var selectedMinutes: Int = 25
    @State private var errorMessage: String?
    @State private var sessionArtworkId: String?

    private var todayISO: String { DatePolicy.isoDayString(for: Date()) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ScreenHeader(title: "Aujourd'hui")

                    if let loadingError = appCoordinator.loadingErrorMessage {
                        MessageBanner(text: loadingError, color: theme.danger)
                    }
                    if let errorMessage {
                        MessageBanner(text: errorMessage, color: theme.danger)
                    }
                    if let badge = badgeUnlockedToday {
                        MessageBanner(text: "Nouveau badge : \(badge.title) 🎉", color: theme.record)
                    }

                    heroSection
                    sessionBar
                    statsGrid
                    otherArtworksSection

                    Spacer(minLength: 20)
                }
                .padding(.horizontal)
            }
            .themedScreenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .task(id: appCoordinator.isReady) {
                importCurrentArtworks()
            }
            .refreshable {
                appCoordinator.loadInitialContentIfNeeded()
                appCoordinator.applyDatePolicies()
                importCurrentArtworks()
            }
            .fullScreenCover(item: Binding(
                get: { sessionArtworkId.map(SessionTarget.init) },
                set: { sessionArtworkId = $0?.id }
            )) { target in
                FocusSessionHostView(
                    artworkId: target.id,
                    minutesSelected: selectedMinutes,
                    isPremiumUser: entitlements.isPremium,
                    onClose: { sessionArtworkId = nil }
                )
                .environment(\.theme, theme)
            }
        }
    }

    // MARK: - Hero (daily du jour)

    @ViewBuilder
    private var heroSection: some View {
        if let dailyId = appCoordinator.todayDailyArtworkId(), let dailyArtwork = artwork(dailyId) {
            let revealed = progress(dailyId)?.revealedCount ?? 0
            NavigationLink {
                ArtworkDetailView(artworkId: dailyId)
            } label: {
                VStack(alignment: .leading, spacing: 12) {
                    PixelArtView(artwork: dailyArtwork, revealedCount: revealed, emptyColor: theme.emptyPixel, spacing: 3, cornerRadius: 4)
                        .frame(maxWidth: .infinity)
                        .frame(height: 280)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(dailyArtwork.title)
                                .font(.headline)
                                .foregroundStyle(theme.textPrimary)
                            Text("Image du jour")
                                .font(.caption)
                                .foregroundStyle(theme.textSecondary)
                        }
                        Spacer()
                        Text("\(min(revealed, dailyArtwork.totalPixels))/\(dailyArtwork.totalPixels)")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(theme.textSecondary)
                    }
                    ThemedProgressBar(value: ratio(revealed, dailyArtwork.totalPixels))
                }
                .themedCard()
            }
            .buttonStyle(.plain)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "sun.max")
                    .font(.largeTitle)
                    .foregroundStyle(theme.textSecondary)
                Text("Aucune image du jour disponible.")
                    .foregroundStyle(theme.textSecondary)
            }
            .frame(maxWidth: .infinity, minHeight: 200)
            .themedCard()
        }
    }

    // MARK: - Session Bar

    @ViewBuilder
    private var sessionBar: some View {
        let target = sessionTargetId
        HStack(spacing: 12) {
            Menu {
                ForEach([15, 20, 25, 30], id: \.self) { minutes in
                    Button {
                        selectedMinutes = minutes
                    } label: {
                        Text(durationLabel(minutes))
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                    Text("\(selectedMinutes) min")
                        .monospacedDigit()
                }
                .font(.headline)
                .foregroundStyle(theme.textPrimary)
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(theme.surfaceHighlight, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            Button {
                startSession(artworkId: target)
            } label: {
                Image(systemName: "play.fill")
                    .font(.title2)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(target == nil)
        }
        .themedCard(padding: 10)

        if let target, target != appCoordinator.todayDailyArtworkId() {
            Text("Daily du jour terminée : la session ira sur l'image de la semaine.")
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Œuvre ciblée par le bouton lecture: la daily du jour, sinon la weekly en cours
    private var sessionTargetId: String? {
        if let dailyId = appCoordinator.todayDailyArtworkId(), progress(dailyId)?.state != .completed {
            return dailyId
        }
        if let weeklyId = appCoordinator.currentWeeklyArtworkId(), progress(weeklyId)?.state != .completed {
            return weeklyId
        }
        return nil
    }

    private func durationLabel(_ minutes: Int) -> String {
        if entitlements.isPremium { return "\(minutes) min" }
        switch minutes {
        case 15, 20:
            let remaining = appCoordinator.remainingQuota(for: minutes, isPremium: false) ?? 0
            return "\(minutes) min — \(remaining) restant(s) aujourd'hui"
        case 30:
            return "30 min — +1 token de protection"
        default:
            return "\(minutes) min — illimité"
        }
    }

    // MARK: - Stats

    private var statsGrid: some View {
        let streak = streaks.first
        let current = streak?.current ?? 0
        let isStreakAlive = streak?.lastCompletedDayISO == todayISO || streak?.lastCompletedDayISO == yesterdayISO
        let displayedStreak = isStreakAlive ? current : 0
        let wallet = wallets.first
        let usable = (try? appCoordinator.getEngine()?.usableBoosters(isPremium: entitlements.isPremium, todayISO: todayISO)) ?? 0

        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            StatTile(icon: "flame.fill", color: theme.streak, value: "\(displayedStreak)", caption: "Série (jours)") {
                DotsProgress(filled: displayedStreak % 3 == 0 && displayedStreak > 0 ? 3 : displayedStreak % 3, total: 3, color: theme.streak)
            }
            StatTile(icon: "trophy.fill", color: theme.record, value: "\(streak?.longestStreak ?? 0)", caption: "Record • \(badges.count)/\(BadgePolicy.all.count) badges") {
                DotsProgress(filled: badges.count, total: BadgePolicy.all.count, color: theme.record)
            }
            StatTile(icon: "bolt.fill", color: theme.booster, value: "\(wallet?.totalBoosters ?? 0)", caption: "Boosters • \(usable) utilisable(s)") {
                ThemedProgressBar(value: Double(wallet?.earnedBoosters ?? 0) / 12.0, color: theme.booster)
            }
            StatTile(icon: "shield.fill", color: theme.token, value: "\(wallet?.protectionTokensAvailable ?? 0)", caption: "Tokens de protection") {
                DotsProgress(filled: min(wallet?.protectionTokensAvailable ?? 0, 5), total: 5, color: theme.token)
            }
        }
    }

    private var yesterdayISO: String {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return DatePolicy.isoDayString(for: yesterday)
    }

    // MARK: - Weekly / Monthly

    private var otherArtworksSection: some View {
        VStack(spacing: 12) {
            SectionTitle(title: "À jouer aussi")

            if let weeklyId = appCoordinator.currentWeeklyArtworkId() {
                NavigationLink {
                    ArtworkDetailView(artworkId: weeklyId)
                } label: {
                    ArtworkRowCard(
                        artwork: artwork(weeklyId),
                        revealedCount: progress(weeklyId)?.revealedCount ?? 0,
                        title: "Image de la semaine",
                        subtitle: artwork(weeklyId)?.title ?? "Weekly",
                        isLocked: false
                    )
                }
                .buttonStyle(.plain)
            }

            if let monthlyId = appCoordinator.currentMonthlyArtworkId() {
                let isUnlocked = appCoordinator.canPlay(artworkId: monthlyId)
                NavigationLink {
                    ArtworkDetailView(artworkId: monthlyId)
                } label: {
                    ArtworkRowCard(
                        artwork: artwork(monthlyId),
                        revealedCount: progress(monthlyId)?.revealedCount ?? 0,
                        title: "Image du mois",
                        subtitle: isUnlocked ? (artwork(monthlyId)?.title ?? "Monthly") : monthlyLockedSubtitle,
                        isLocked: !isUnlocked
                    )
                }
                .buttonStyle(.plain)
            }

            if !entitlements.isPremium {
                quotasRow
            }
        }
    }

    private var quotasRow: some View {
        let quota = dailyQuotas.first(where: { $0.dayISO == todayISO })
        return HStack(spacing: 16) {
            Image(systemName: "hourglass")
                .foregroundStyle(theme.textSecondary)
            Text("Gratuit : 15 min \(max(0, 1 - (quota?.used15 ?? 0)))/1 • 20 min \(max(0, 1 - (quota?.used20 ?? 0)))/1 • 25 & 30 min illimités")
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
            Spacer()
        }
        .themedCard(padding: 12)
    }

    /// Sous-titre de l'image du mois verrouillée: progression du défi
    private var monthlyLockedSubtitle: String {
        let monthISO = DatePolicy.isoMonthString(for: Date())
        let target = appCoordinator.ruleset?.monthlyAccess.challengeSessions ?? 20
        let completed = monthStats.first(where: { $0.monthISO == monthISO })?.completedSessions ?? 0
        return "Verrouillée • Défi \(min(completed, target))/\(target) sessions"
    }

    // MARK: - Badges

    private var badgeUnlockedToday: BadgeDefinition? {
        guard let latest = badges.first, Calendar.current.isDateInToday(latest.unlockedAt) else { return nil }
        return BadgePolicy.all.first(where: { $0.id == latest.badgeId })
    }

    // MARK: - Helpers

    private func artwork(_ artworkId: String) -> SDArtwork? {
        artworks.first(where: { $0.artworkId == artworkId })
    }

    private func progress(_ artworkId: String) -> SDProgress? {
        progresses.first(where: { $0.artworkId == artworkId })
    }

    private func ratio(_ revealed: Int, _ total: Int) -> Double {
        total > 0 ? Double(min(revealed, total)) / Double(total) : 0
    }

    private func importCurrentArtworks() {
        guard appCoordinator.isReady else { return }
        let ids = [
            appCoordinator.todayDailyArtworkId(),
            appCoordinator.currentWeeklyArtworkId(),
            appCoordinator.currentMonthlyArtworkId()
        ].compactMap { $0 }
        for id in ids {
            try? appCoordinator.ensureArtworkImported(artworkId: id)
        }
    }

    private func startSession(artworkId: String?) {
        guard let artworkId else { return }
        do {
            try appCoordinator.startSession(artworkId: artworkId, minutes: selectedMinutes)
            errorMessage = nil
            sessionArtworkId = artworkId
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - SessionTarget
/// Identifiable pour fullScreenCover(item:)
private struct SessionTarget: Identifiable {
    let id: String
}

// MARK: - ArtworkRowCard
struct ArtworkRowCard: View {
    let artwork: SDArtwork?
    let revealedCount: Int
    let title: String
    let subtitle: String
    let isLocked: Bool

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(theme.surfaceHighlight)
                if let artwork {
                    PixelArtView(artwork: artwork, revealedCount: revealedCount, emptyColor: theme.emptyPixel)
                        .padding(6)
                        .opacity(isLocked ? 0.35 : 1)
                }
                if isLocked {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(theme.textPrimary)
                }
            }
            .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
                if let artwork, !isLocked {
                    ThemedProgressBar(
                        value: artwork.totalPixels > 0 ? Double(min(revealedCount, artwork.totalPixels)) / Double(artwork.totalPixels) : 0,
                        height: 6
                    )
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(theme.textSecondary)
        }
        .themedCard(padding: 12)
    }
}

// MARK: - MessageBanner
struct MessageBanner: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.85), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Preview
#Preview {
    TodayView()
        .environmentObject(AppCoordinator())
        .environmentObject(EntitlementStore())
        .modelContainer(for: [
            SDWallet.self, SDStreak.self, SDDailyQuota.self, SDProgress.self,
            SDArtwork.self, SDMonthStats.self, SDBadge.self
        ], inMemory: true)
}
