/*
 * CollectionView.swift
 * PixelFocus
 *
 * Version: 1.0
 * Date: 15 janvier 2026
 *
 * Collection (V1).
 *
 * Objectifs:
 * - Afficher Terminées / À finaliser (Daily + Monthly)
 * - Navigation vers ArtworkDetailView
 *
 * Note:
 * - Monthly à finaliser n'est pas purgé (règle long terme).
 */

import SwiftUI
import SwiftData

// MARK: - CollectionView
struct CollectionView: View {
    @Query private var progresses: [SDProgress]
    @Query private var artworks: [SDArtwork]

    @State private var selectedFilter: CollectionFilter = .all

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter picker
                Picker("Filtre", selection: $selectedFilter) {
                    ForEach(CollectionFilter.allCases, id: \.self) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                List {
                    switch selectedFilter {
                    case .all:
                        allSections
                    case .completed:
                        completedSection
                    case .toFinalize:
                        toFinalizeSection
                    }
                }
            }
            .navigationTitle("Collection")
        }
    }
    
    // MARK: - All Sections
    
    private var allSections: some View {
        Group {
            completedSection
            toFinalizeSection
        }
    }
    
    // MARK: - Completed Section
    
    private var completedSection: some View {
        Section("Terminées (\(completedProgresses.count))") {
            if completedProgresses.isEmpty {
                EmptyStateRow(
                    icon: "checkmark.circle",
                    message: "Aucune œuvre terminée.",
                    color: .gray
                )
            } else {
                ForEach(completedProgresses, id: \.artworkId) { progress in
                    NavigationLink {
                        ArtworkDetailView(artworkId: progress.artworkId)
                    } label: {
                        CollectionRow(progress: progress, artworks: artworks, isCompleted: true)
                    }
                }
            }
        }
    }
    
    // MARK: - To Finalize Section
    
    private var toFinalizeSection: some View {
        Group {
            // Daily à finaliser
            Section("À finaliser - Daily (\(dailyToFinalize.count))") {
                if dailyToFinalize.isEmpty {
                    EmptyStateRow(
                        icon: "sun.max",
                        message: "Aucune daily à finaliser.",
                        color: .orange
                    )
                } else {
                    ForEach(dailyToFinalize, id: \.artworkId) { progress in
                        NavigationLink {
                            ArtworkDetailView(artworkId: progress.artworkId)
                        } label: {
                            CollectionRow(progress: progress, artworks: artworks, isCompleted: false)
                        }
                    }
                }
            }

            // Monthly à finaliser
            Section("À finaliser - Monthly (\(monthlyToFinalize.count))") {
                if monthlyToFinalize.isEmpty {
                    EmptyStateRow(
                        icon: "star",
                        message: "Aucune mensuelle à finaliser.",
                        color: .purple
                    )
                } else {
                    ForEach(monthlyToFinalize, id: \.artworkId) { progress in
                        NavigationLink {
                            ArtworkDetailView(artworkId: progress.artworkId)
                        } label: {
                            CollectionRow(progress: progress, artworks: artworks, isCompleted: false)
                        }
                    }
                }
                
                // Note sur la non-purge des monthly
                if !monthlyToFinalize.isEmpty {
                    Text("Les œuvres mensuelles ne sont jamais purgées et restent disponibles.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var completedProgresses: [SDProgress] {
        progresses.filter { $0.state == .completed }
            .sorted { ($0.updatedAt) > ($1.updatedAt) }
    }
    
    private var dailyToFinalize: [SDProgress] {
        progresses.filter { $0.state == .toFinalize }
            .filter { progress in
                artworks.first(where: { $0.artworkId == progress.artworkId })?.mode == "daily"
            }
            .sorted { ($0.artworkDateISO ?? "") > ($1.artworkDateISO ?? "") }
    }
    
    private var monthlyToFinalize: [SDProgress] {
        progresses.filter { $0.state == .toFinalize }
            .filter { progress in
                artworks.first(where: { $0.artworkId == progress.artworkId })?.mode == "monthly"
            }
            .sorted { ($0.artworkMonthISO ?? "") > ($1.artworkMonthISO ?? "") }
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
}

// MARK: - CollectionRow
struct CollectionRow: View {
    let progress: SDProgress
    let artworks: [SDArtwork]
    let isCompleted: Bool
    
    var body: some View {
        let artwork = artworks.first(where: { $0.artworkId == progress.artworkId })
        let mode = artwork?.mode ?? "?"
        let totalPixels = artwork?.totalPixels ?? 25
        let percent = totalPixels > 0 ? Double(progress.revealedCount) / Double(totalPixels) : 0
        
        HStack {
            // Mode icon
            modeIcon(mode: mode)
                .frame(width: 44, height: 44)
                .background(modeColor(mode: mode).opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(artwork?.title ?? progress.artworkId)
                    .font(.headline)
                
                HStack {
                    Text(mode.uppercased())
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(modeColor(mode: mode))
                        .clipShape(Capsule())
                    
                    Text("\(progress.revealedCount)/\(totalPixels) pixels")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Status indicator
            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Text("\(Int(percent * 100))%")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }
    
    private func modeIcon(mode: String) -> some View {
        Group {
            switch mode {
            case "daily":
                Image(systemName: "sun.max.fill")
                    .foregroundStyle(.orange)
            case "weekly":
                Image(systemName: "calendar")
                    .foregroundStyle(.blue)
            case "monthly":
                Image(systemName: "star.fill")
                    .foregroundStyle(.purple)
            default:
                Image(systemName: "square.grid.2x2")
                    .foregroundStyle(.gray)
            }
        }
        .font(.title2)
    }
    
    private func modeColor(mode: String) -> Color {
        switch mode {
        case "daily": return .orange
        case "weekly": return .blue
        case "monthly": return .purple
        default: return .gray
        }
    }
}

// MARK: - EmptyStateRow
struct EmptyStateRow: View {
    let icon: String
    let message: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(message)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview
#Preview {
    CollectionView()
        .modelContainer(for: [SDProgress.self, SDArtwork.self], inMemory: true)
}
