/*
 * ArtworkDetailView.swift
 * PixelFocus
 *
 * Version: 1.0
 * Date: 15 janvier 2026
 *
 * Détail d'une œuvre (V1).
 *
 * Objectifs:
 * - Afficher l'œuvre + progression
 * - Afficher une preview de la grille (pixel-art)
 * - Sélecteur de durée de session (15/20/25/30)
 * - Démarrer une session focus
 * - Utiliser un booster (voir GAME_DESIGN.md §3)
 * - Image du mois verrouillée: défi du mois, Premium, achat à l'unité (étape 3)
 *
 * Technique:
 * - AppCoordinator via EnvironmentObject
 * - SwiftData pour artwork/progress/wallet
 * - @Query pour les wallets (SwiftData)
 *
 * Notes:
 * - Preview-safe: si AppCoordinator n'est pas prêt (preview), on évite l'import JSON.
 * - PixelGridView (V1) est adapté aux grilles modestes (ex 5x5 à 50x50).
 *   Pour des grilles plus grosses, prévoir un rendu tuilé / Canvas.
 */

import SwiftUI
import SwiftData

// MARK: - ArtworkDetailView
struct ArtworkDetailView: View {

    // MARK: - Dependencies
    @EnvironmentObject private var appCoordinator: AppCoordinator
    @EnvironmentObject private var entitlements: EntitlementStore
    @Environment(\.modelContext) private var modelContext

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
                errorBanner

                if let artwork {
                    headerSection(for: artwork)
                    pixelGridPreview(for: artwork)
                    progressSection(for: artwork)

                    if progress?.state == .completed {
                        completedSection
                    } else if appCoordinator.canPlay(artworkId: artworkId) {
                        sessionPickerSection
                        actionsSection
                    } else {
                        lockedMonthlySection(for: artwork)
                    }
                } else {
                    ProgressView("Chargement…")
                        .padding()
                }

                Spacer(minLength: 20)
            }
            .padding()
        }
        .navigationTitle(artwork?.title ?? "Œuvre")
        .navigationBarTitleDisplayMode(.inline)
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

    // MARK: - UI Components

    private var errorBanner: some View {
        Group {
            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func headerSection(for artwork: SDArtwork) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(artwork.title)
                .font(.title2)
                .bold()

            Text("Mode: \(artwork.mode.uppercased()) • Grille: \(artwork.gridWidth)×\(artwork.gridHeight)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func pixelGridPreview(for artwork: SDArtwork) -> some View {
        let revealedCount = progress?.revealedCount ?? 0

        let decodedPalette = artwork.decodePalette()
        let decodedPixels = artwork.decodePixels()
        let decodedRevealSequence = artwork.decodeRevealSequence()

        return PixelGridView(
            gridWidth: artwork.gridWidth,
            gridHeight: artwork.gridHeight,
            paletteHexColors: decodedPalette,
            pixelPaletteIndexes: decodedPixels,
            revealSequence: decodedRevealSequence,
            revealedCount: revealedCount
        )
        .frame(height: 220)
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func progressSection(for artwork: SDArtwork) -> some View {
        let totalPixelsCount = artwork.totalPixels
        let revealedCount = progress?.revealedCount ?? 0
        let clampedRevealedCount = min(revealedCount, totalPixelsCount)
        let completionRatio = totalPixelsCount > 0 ? Double(clampedRevealedCount) / Double(totalPixelsCount) : 0

        let totalBoosters = wallets.first?.totalBoosters ?? 0
        let canUseBooster = progress?.state != .completed && appCoordinator.canPlay(artworkId: artworkId)

        return VStack(alignment: .leading, spacing: 10) {
            Text("Progression")
                .font(.headline)

            ProgressView(value: completionRatio)
                .tint(completionRatio >= 1.0 ? .green : .blue)

            HStack {
                Text("\(clampedRevealedCount)/\(totalPixelsCount) pixels")
                Spacer()
                Text("\(Int(completionRatio * 100))%")
                    .bold()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if canUseBooster && totalBoosters > 0 {
                Button {
                    isBoosterSheetPresented = true
                } label: {
                    Label("Utiliser un booster (\(usableBoosters) dispo.)", systemImage: "bolt.fill")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var sessionPickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Durée de session")
                .font(.headline)

            Picker("Durée", selection: $selectedMinutes) {
                Text("15 min").tag(15)
                Text("20 min").tag(20)
                Text("25 min ⭐").tag(25)
                Text("30 min 🛡️").tag(30)
            }
            .pickerStyle(.segmented)

            quotaHintText
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var quotaHintText: some View {
        if isPremiumUser {
            Text("Premium : 15 & 20 illimités.")
                .font(.footnote)
                .foregroundStyle(.green)

        } else if selectedMinutes == 15 || selectedMinutes == 20 {
            let remainingSessions = appCoordinator.remainingQuota(for: selectedMinutes, isPremium: false) ?? 0
            Text("Gratuit : \(selectedMinutes) min limité à 1/jour. Restant: \(remainingSessions)")
                .font(.footnote)
                .foregroundStyle(remainingSessions > 0 ? Color.secondary : Color.red)

        } else if selectedMinutes == 30 {
            Text("30 min : illimité + 1 token protection (cap 3/jour).")
                .font(.footnote)
                .foregroundStyle(.blue)

        } else {
            Text("25 min : illimité (recommandé).")
                .font(.footnote)
                .foregroundStyle(.green)
        }
    }

    private var actionsSection: some View {
        VStack(spacing: 10) {
            Button {
                startSession()
            } label: {
                Label("Démarrer la session", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Text("Récompense : +5 pixels par session réussie")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
        let todayISO = DatePolicy.isoDayString(for: Date())
        guard let engine = appCoordinator.getEngine() else {
            errorMessage = "Moteur non disponible."
            return
        }

        do {
            let canStart = try engine.canStartSession(minutes: selectedMinutes, isPremium: isPremiumUser, todayISO: todayISO)
            guard canStart else {
                errorMessage = "Quota atteint pour \(selectedMinutes) min."
                return
            }

            try engine.registerSessionStart(minutes: selectedMinutes, isPremium: isPremiumUser, todayISO: todayISO)
            isFocusSessionPresented = true

        } catch {
            errorMessage = "Erreur démarrage session: \(error.localizedDescription)"
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

    // MARK: - Completed / Locked Sections

    private var completedSection: some View {
        Label("Œuvre terminée — elle est dans ta collection.", systemImage: "checkmark.seal.fill")
            .font(.subheadline)
            .foregroundStyle(.green)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
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

            if isCurrentMonth {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Défi du mois : termine \(challengeTarget) sessions ce mois-ci pour la débloquer gratuitement.")
                        .font(.subheadline)
                    ProgressView(value: Double(challengeDone), total: Double(challengeTarget))
                    Text("\(challengeDone)/\(challengeTarget) sessions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Incluse avec Premium.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                // Achat à l'unité: branché à l'étape 3 (StoreKit)
            } label: {
                Text("Acheter cette image — \(priceText) (bientôt)")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(true)
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - PixelGridView (V1)
struct PixelGridView: View {

    // MARK: - Inputs
    let gridWidth: Int
    let gridHeight: Int
    let paletteHexColors: [String]
    let pixelPaletteIndexes: [Int]
    let revealSequence: [Int]
    let revealedCount: Int

    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            let cellSize = min(
                geometry.size.width / CGFloat(max(1, gridWidth)),
                geometry.size.height / CGFloat(max(1, gridHeight))
            )

            VStack(spacing: 1) {
                ForEach(0..<gridHeight, id: \.self) { rowIndex in
                    HStack(spacing: 1) {
                        ForEach(0..<gridWidth, id: \.self) { colIndex in
                            let pixelIndex = rowIndex * gridWidth + colIndex
                            let revealed = isPixelRevealed(pixelIndex: pixelIndex)

                            Rectangle()
                                .fill(revealed ? colorForPixel(pixelIndex: pixelIndex) : Color.gray.opacity(0.30))
                                .frame(width: max(1, cellSize - 1), height: max(1, cellSize - 1))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Reveal Logic
    private func isPixelRevealed(pixelIndex: Int) -> Bool {
        guard pixelIndex >= 0 else { return false }

        // Si pas de séquence, révélation dans l'ordre
        guard !revealSequence.isEmpty else {
            return pixelIndex < revealedCount
        }

        // Si séquence, on regarde la position de pixelIndex dans la séquence
        if let positionInSequence = revealSequence.firstIndex(of: pixelIndex) {
            return positionInSequence < revealedCount
        }
        return false
    }

    // MARK: - Color
    private func colorForPixel(pixelIndex: Int) -> Color {
        guard pixelIndex < pixelPaletteIndexes.count else { return .gray }

        let paletteIndex = pixelPaletteIndexes[pixelIndex]
        guard paletteIndex >= 0, paletteIndex < paletteHexColors.count else { return .gray }

        return Color(hex: paletteHexColors[paletteIndex]) ?? .gray
    }
}

// MARK: - Color Hex Utility
extension Color {
    init?(hex: String) {
        var sanitizedHexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitizedHexString = sanitizedHexString.replacingOccurrences(of: "#", with: "")

        var rgbValue: UInt64 = 0
        guard Scanner(string: sanitizedHexString).scanHexInt64(&rgbValue) else { return nil }

        let red = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let green = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let blue = Double(rgbValue & 0x0000FF) / 255.0

        self.init(red: red, green: green, blue: blue)
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
