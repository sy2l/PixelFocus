/*
 * ArtworkDetailView.swift
 * PixelFocus
 *
 * Détail d'une œuvre (maquette v2).
 *
 * Objectifs:
 * - Afficher l'œuvre (pixel art) + progression
 * - Sélecteur de durée de session (15/20/25/30) et démarrage
 * - Utiliser un booster (voir GAME_DESIGN.md §3)
 * - Image du mois verrouillée: défi du mois, Premium, achat à l'unité (étape 3)
 *
 * Technique:
 * - AppCoordinator / EntitlementStore via EnvironmentObject
 * - SwiftData pour artwork/progress/wallet
 * - Preview-safe: si AppCoordinator n'est pas prêt (preview), on évite l'import JSON.
 */

import SwiftUI
import SwiftData

// MARK: - ArtworkDetailView
struct ArtworkDetailView: View {

    // MARK: - Dependencies
    @EnvironmentObject private var appCoordinator: AppCoordinator
    @EnvironmentObject private var entitlements: EntitlementStore
    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme

    // MARK: - Input
    let artworkId: String

    // MARK: - SwiftData Queries
    @Query private var wallets: [SDWallet]

    // MARK: - Local State
    @State private var artwork: SDArtwork?
    @State private var progress: SDProgress?

    @State private var selectedMinutes: Int = 25
    @State private var errorMessage: String?

    @State private var isFocusSessionPresented: Bool = false
    @State private var isBoosterSheetPresented: Bool = false

    private var isPremiumUser: Bool { entitlements.isPremium }

    // MARK: - Body
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let errorMessage {
                    MessageBanner(text: errorMessage, color: theme.danger)
                }

                if let artwork {
                    artworkSection(for: artwork)

                    if progress?.state == .completed {
                        completedSection
                    } else if appCoordinator.canPlay(artworkId: artworkId) {
                        sessionSection
                    } else if appCoordinator.monthlyMonthISO(forArtworkId: artworkId) != nil {
                        lockedMonthlySection(for: artwork)
                    } else {
                        notYetAvailableSection
                    }
                } else {
                    ProgressView("Chargement…")
                        .tint(theme.primary)
                        .foregroundStyle(theme.textSecondary)
                        .padding()
                }

                Spacer(minLength: 20)
            }
            .padding()
        }
        .themedScreenBackground()
        .navigationTitle(artwork?.title ?? "Œuvre")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(theme.background, for: .navigationBar)
        .task {
            await loadArtworkAndProgress()
        }
        .fullScreenCover(isPresented: $isFocusSessionPresented) {
            FocusSessionHostView(
                artworkId: artworkId,
                minutesSelected: selectedMinutes,
                isPremiumUser: isPremiumUser,
                onClose: {
                    isFocusSessionPresented = false
                    Task { await loadArtworkAndProgress() }
                }
            )
            .environment(\.theme, theme)
        }
        .sheet(isPresented: $isBoosterSheetPresented) {
            UseBoosterSheet(
                earnedBoosters: wallets.first?.earnedBoosters ?? 0,
                purchasedBoosters: wallets.first?.purchasedBoosters ?? 0,
                usableNow: usableBoosters,
                pixelsPerBooster: appCoordinator.ruleset?.boosters.pixelsPerBooster ?? 5,
                dailyEarnedLimit: dailyEarnedLimit,
                onUse: {
                    useBooster()
                }
            )
            .environment(\.theme, theme)
            .presentationDetents([.large])
        }
    }

    // MARK: - Booster Helpers

    private var dailyEarnedLimit: Int {
        guard let rules = appCoordinator.ruleset?.boosters else { return 0 }
        return BoosterPolicy.dailyEarnedLimit(isPremium: isPremiumUser, rules: rules)
    }

    private var usableBoosters: Int {
        let todayISO = DatePolicy.isoDayString(for: Date())
        return (try? appCoordinator.getEngine()?.usableBoosters(isPremium: isPremiumUser, todayISO: todayISO)) ?? 0
    }

    // MARK: - Artwork

    private func artworkSection(for artwork: SDArtwork) -> some View {
        let total = artwork.totalPixels
        let revealed = min(progress?.revealedCount ?? 0, total)
        let ratio = total > 0 ? Double(revealed) / Double(total) : 0
        let totalBoosters = wallets.first?.totalBoosters ?? 0
        let canUseBooster = progress?.state != .completed && appCoordinator.canPlay(artworkId: artworkId)

        return VStack(alignment: .leading, spacing: 14) {
            PixelArtView(artwork: artwork, revealedCount: revealed, emptyColor: theme.emptyPixel, spacing: 2, cornerRadius: 3)
                .frame(maxWidth: .infinity)
                .frame(height: 300)

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(artwork.title)
                        .font(.title3.bold())
                        .foregroundStyle(theme.textPrimary)
                    Text("\(modeLabel(artwork.mode)) • \(artwork.gridWidth)×\(artwork.gridHeight)")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer()
                Text("\(Int(ratio * 100))%")
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(ratio >= 1 ? theme.success : theme.textPrimary)
            }

            ThemedProgressBar(value: ratio, color: ratio >= 1 ? theme.success : theme.primary)

            Text("\(revealed)/\(total) pixels")
                .font(.caption)
                .foregroundStyle(theme.textSecondary)

            if canUseBooster && totalBoosters > 0 {
                Button {
                    isBoosterSheetPresented = true
                } label: {
                    Label("Utiliser un booster (\(usableBoosters) dispo.)", systemImage: "bolt.fill")
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .themedCard()
    }

    private func modeLabel(_ mode: String) -> String {
        switch mode {
        case "daily": return "Image du jour"
        case "weekly": return "Image de la semaine"
        case "monthly": return "Image du mois"
        default: return mode.capitalized
        }
    }

    // MARK: - Session

    private var sessionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Durée de session")
                .font(.headline)
                .foregroundStyle(theme.textPrimary)

            PillPicker(options: [15, 20, 25, 30], selection: $selectedMinutes) { "\($0) min" }

            quotaHintText

            Button {
                startSession()
            } label: {
                Label("Démarrer la session", systemImage: "play.fill")
            }
            .buttonStyle(PrimaryButtonStyle())

            Text("Récompense : +\(appCoordinator.ruleset?.sessions.pixelsPerCompletedSession ?? 5) pixels par session réussie")
                .font(.footnote)
                .foregroundStyle(theme.textSecondary)
        }
        .themedCard()
    }

    @ViewBuilder
    private var quotaHintText: some View {
        if isPremiumUser {
            Text("Premium : 15 & 20 min illimités.")
                .font(.footnote)
                .foregroundStyle(theme.success)

        } else if selectedMinutes == 15 || selectedMinutes == 20 {
            let remainingSessions = appCoordinator.remainingQuota(for: selectedMinutes, isPremium: false) ?? 0
            Text("Gratuit : \(selectedMinutes) min limité à 1/jour. Restant : \(remainingSessions)")
                .font(.footnote)
                .foregroundStyle(remainingSessions > 0 ? theme.textSecondary : theme.danger)

        } else if selectedMinutes == 30 {
            Text("30 min : illimité + 1 token de protection (3 max/jour).")
                .font(.footnote)
                .foregroundStyle(theme.token)

        } else {
            Text("25 min : illimité (recommandé).")
                .font(.footnote)
                .foregroundStyle(theme.success)
        }
    }

    // MARK: - Completed / Locked / Not yet

    private var completedSection: some View {
        Label("Œuvre terminée — elle est dans ta collection.", systemImage: "checkmark.seal.fill")
            .font(.subheadline)
            .foregroundStyle(theme.success)
            .frame(maxWidth: .infinity, alignment: .leading)
            .themedCard()
    }

    private var notYetAvailableSection: some View {
        Label("Cette œuvre n'est pas encore disponible.", systemImage: "clock")
            .font(.subheadline)
            .foregroundStyle(theme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .themedCard()
    }

    private func lockedMonthlySection(for artwork: SDArtwork) -> some View {
        let rules = appCoordinator.ruleset?.monthlyAccess
        let monthISO = appCoordinator.monthlyMonthISO(forArtworkId: artworkId) ?? ""
        let isCurrentMonth = monthISO == DatePolicy.isoMonthString(for: Date())
        let challengeTarget = rules?.challengeSessions ?? 20
        let challengeDone = min(appCoordinator.completedSessions(monthISO: monthISO), challengeTarget)

        let total = artwork.totalPixels
        let ratio = total > 0 ? Double(progress?.revealedCount ?? 0) / Double(total) : 0
        let priceTier: MonthlyPriceTier = rules.map {
            MonthlyAccessPolicy.unitPriceTier(monthISO: monthISO, now: Date(), revealedRatio: ratio, rules: $0)
        } ?? .full
        let priceText = priceTier == .reduced ? "0,99 €" : "1,99 €"

        return VStack(alignment: .leading, spacing: 14) {
            Label("Image du mois verrouillée", systemImage: "lock.fill")
                .font(.headline)
                .foregroundStyle(theme.textPrimary)

            if isCurrentMonth {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Défi du mois : termine \(challengeTarget) sessions ce mois-ci pour la débloquer gratuitement.")
                        .font(.subheadline)
                        .foregroundStyle(theme.textPrimary)
                    ThemedProgressBar(value: Double(challengeDone) / Double(max(challengeTarget, 1)))
                    Text("\(challengeDone)/\(challengeTarget) sessions")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                }
            }

            Text("Incluse avec Premium.")
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)

            Button {
                // Achat à l'unité: branché à l'étape 3 (StoreKit)
            } label: {
                Text("Acheter cette image — \(priceText) (bientôt)")
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(true)
        }
        .themedCard()
    }

    // MARK: - Data Loading

    private func loadArtworkAndProgress() async {
        // Preview-safe: si le coordinator n'est pas prêt/configuré, on charge uniquement depuis SwiftData.
        do {
            if appCoordinator.isReady {
                try appCoordinator.ensureArtworkImported(artworkId: artworkId)
            }

            self.artwork = try fetchArtwork(artworkId: artworkId)
            self.progress = try fetchProgress(artworkId: artworkId)
        } catch {
            self.errorMessage = "Erreur chargement: \(error.localizedDescription)"
        }
    }

    private func fetchArtwork(artworkId: String) throws -> SDArtwork? {
        let descriptor = FetchDescriptor<SDArtwork>(predicate: #Predicate { $0.artworkId == artworkId })
        return try modelContext.fetch(descriptor).first
    }

    private func fetchProgress(artworkId: String) throws -> SDProgress? {
        let descriptor = FetchDescriptor<SDProgress>(predicate: #Predicate { $0.artworkId == artworkId })
        return try modelContext.fetch(descriptor).first
    }

    // MARK: - Actions

    private func startSession() {
        do {
            try appCoordinator.startSession(artworkId: artworkId, minutes: selectedMinutes)
            errorMessage = nil
            isFocusSessionPresented = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func useBooster() {
        guard let engine = appCoordinator.getEngine() else {
            errorMessage = "Moteur non disponible."
            return
        }
        guard appCoordinator.canPlay(artworkId: artworkId) else {
            errorMessage = "Cette œuvre est verrouillée."
            return
        }

        do {
            try engine.useBooster(
                artworkId: artworkId,
                isPremium: isPremiumUser,
                todayISO: DatePolicy.isoDayString(for: Date()),
                dailyDateISO: appCoordinator.dailyDateISO(forArtworkId: artworkId)
            )
            self.progress = try fetchProgress(artworkId: artworkId)
            self.errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        ArtworkDetailView(artworkId: "daily_2026_01_15")
    }
    .environmentObject(AppCoordinator())
    .environmentObject(EntitlementStore())
    .modelContainer(
        for: [
            SDArtwork.self,
            SDProgress.self,
            SDWallet.self,
            SDStreak.self,
            SDDailyQuota.self,
            SDMonthStats.self
        ],
        inMemory: true
    )
}
