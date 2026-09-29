/*
 * CollectionView.swift
 * PixelFocus
 *
 * Collection (maquette v2).
 *
 * Objectifs:
 * - Filtre Tout / Terminées / À finaliser
 * - Grille 2 colonnes des œuvres commencées (vignette + progression)
 * - Rangée "Mensuel" (images du mois commencées)
 * - Badges débloqués / à débloquer
 * - Emplacement des packs thématiques (étape 4)
 */

import SwiftUI
import SwiftData

// MARK: - CollectionView
struct CollectionView: View {
    @Environment(\.theme) private var theme

    @Query(sort: \SDProgress.updatedAt, order: .reverse) private var progresses: [SDProgress]
    @Query private var artworks: [SDArtwork]
    @Query private var badges: [SDBadge]

    @State private var selectedFilter: CollectionFilter = .all

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ScreenHeader(title: "Collection")

                    PillPicker(options: CollectionFilter.allCases, selection: $selectedFilter) { $0.title }

                    artworksGrid

                    if selectedFilter == .all {
                        monthlyRow
                        badgesSection
                        packsPlaceholder
                    }

                    Spacer(minLength: 20)
                }
                .padding(.horizontal)
            }
            .themedScreenBackground()
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Grid

    @ViewBuilder
    private var artworksGrid: some View {
        let items = filteredProgresses
        if items.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: selectedFilter.emptyIcon)
                    .font(.largeTitle)
                    .foregroundStyle(theme.textSecondary)
                Text(selectedFilter.emptyMessage)
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 160)
            .themedCard()
        } else {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(items, id: \.artworkId) { progress in
                    if let tileArtwork = artwork(progress.artworkId) {
                        NavigationLink {
                            ArtworkDetailView(artworkId: progress.artworkId)
                        } label: {
                            ArtworkTile(artwork: tileArtwork, progress: progress)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var filteredProgresses: [SDProgress] {
        let started = progresses.filter { $0.revealedCount > 0 || $0.state != .active }
        switch selectedFilter {
        case .all:
            return started
        case .completed:
            return started.filter { $0.state == .completed }
        case .toFinalize:
            return started.filter { $0.state == .toFinalize }
        }
    }

    // MARK: - Monthly Row

    @ViewBuilder
    private var monthlyRow: some View {
        let monthly = progresses.filter { artwork($0.artworkId)?.mode == "monthly" }
        if !monthly.isEmpty {
            SectionTitle(title: "Mensuel")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(monthly, id: \.artworkId) { progress in
                        if let tileArtwork = artwork(progress.artworkId) {
                            NavigationLink {
                                ArtworkDetailView(artworkId: progress.artworkId)
                            } label: {
                                ArtworkTile(artwork: tileArtwork, progress: progress)
                                    .frame(width: 150)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Badges

    private var badgesSection: some View {
        let unlocked = Set(badges.map(\.badgeId))
        return VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Badges \(unlocked.count)/\(BadgePolicy.all.count)")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(BadgePolicy.all) { badge in
                    BadgeCell(badge: badge, isUnlocked: unlocked.contains(badge.id))
                }
            }
        }
    }

    // MARK: - Packs

    private var packsPlaceholder: some View {
        HStack(spacing: 12) {
            Image(systemName: "shippingbox.fill")
                .font(.title2)
                .foregroundStyle(theme.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Packs thématiques")
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)
                Text("Continents, capitales, saisons… bientôt disponibles.")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer()
        }
        .themedCard(padding: 14)
    }

    // MARK: - Helpers

    private func artwork(_ artworkId: String) -> SDArtwork? {
        artworks.first(where: { $0.artworkId == artworkId })
    }
}

// MARK: - CollectionFilter
enum CollectionFilter: CaseIterable {
    case all
    case completed
    case toFinalize

    var title: String {
        switch self {
        case .all: return "Tout"
        case .completed: return "Terminées"
        case .toFinalize: return "À finaliser"
        }
    }

    var emptyIcon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .completed: return "checkmark.seal"
        case .toFinalize: return "hourglass"
        }
    }

    var emptyMessage: String {
        switch self {
        case .all: return "Lance une session pour commencer ta collection."
        case .completed: return "Aucune œuvre terminée pour l'instant."
        case .toFinalize: return "Rien à finaliser. Bravo !"
        }
    }
}

// MARK: - ArtworkTile
struct ArtworkTile: View {
    let artwork: SDArtwork
    let progress: SDProgress

    @Environment(\.theme) private var theme

    var body: some View {
        let total = artwork.totalPixels
        let ratio = total > 0 ? Double(min(progress.revealedCount, total)) / Double(total) : 0
        let isCompleted = progress.state == .completed

        VStack(alignment: .leading, spacing: 10) {
            PixelArtView(artwork: artwork, revealedCount: progress.revealedCount, emptyColor: theme.emptyPixel, spacing: 1.5, cornerRadius: 2)
                .frame(maxWidth: .infinity)
                .frame(height: 120)

            Text(artwork.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)

            HStack(spacing: 8) {
                if isCompleted {
                    Text("100%")
                        .font(.caption.bold())
                        .foregroundStyle(theme.textPrimary)
                    Image(systemName: "trophy.fill")
                        .font(.caption)
                        .foregroundStyle(theme.record)
                } else {
                    ThemedProgressBar(value: ratio, height: 6)
                    Text("\(Int(ratio * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(theme.textSecondary)
                }
            }
        }
        .themedCard(padding: 10)
    }
}

// MARK: - BadgeCell
private struct BadgeCell: View {
    let badge: BadgeDefinition
    let isUnlocked: Bool

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: isUnlocked ? badge.icon : "lock.fill")
                .font(.title2)
                .foregroundStyle(isUnlocked ? theme.record : theme.textSecondary.opacity(0.5))
                .frame(width: 52, height: 52)
                .background(
                    Circle().fill(isUnlocked ? theme.record.opacity(0.15) : theme.surfaceHighlight)
                )
            Text(badge.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isUnlocked ? theme.textPrimary : theme.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(badge.title), \(badge.detail), \(isUnlocked ? "débloqué" : "à débloquer")")
    }
}

// MARK: - Preview
#Preview {
    CollectionView()
        .modelContainer(for: [SDProgress.self, SDArtwork.self, SDBadge.self], inMemory: true)
}
