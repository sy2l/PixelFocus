/*
 * DailyFinalizeListView.swift
 * PixelFocus
 *
 * Version: 1.0
 * Date: 15 janvier 2026
 *
 * Liste SwiftData des daily en état "toFinalize".
 *
 * Objectifs:
 * - Afficher les daily à finaliser
 * - Navigation vers ArtworkDetailView
 */

import SwiftUI
import SwiftData

// MARK: - DailyFinalizeListView
struct DailyFinalizeListView: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var progresses: [SDProgress]
    @Query private var artworks: [SDArtwork]

    var body: some View {
        let dailyToFinalize = progresses.filter { $0.state == .toFinalize }
            .filter { progress in
                (artworks.first(where: { $0.artworkId == progress.artworkId })?.mode == "daily")
            }
            .sorted { ($0.artworkDateISO ?? "") > ($1.artworkDateISO ?? "") }

        if dailyToFinalize.isEmpty {
            HStack {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(.green)
                Text("Aucune daily à finaliser.")
                    .foregroundStyle(.secondary)
            }
        } else {
            ForEach(dailyToFinalize, id: \.artworkId) { progress in
                NavigationLink {
                    ArtworkDetailView(artworkId: progress.artworkId)
                } label: {
                    FinalizeRow(progress: progress, artworks: artworks)
                }
            }
        }
    }
}

// MARK: - FinalizeRow
struct FinalizeRow: View {
    let progress: SDProgress
    let artworks: [SDArtwork]
    
    var body: some View {
        let artwork = artworks.first(where: { $0.artworkId == progress.artworkId })
        let totalPixels = artwork?.totalPixels ?? 25
        let percent = totalPixels > 0 ? Double(progress.revealedCount) / Double(totalPixels) : 0
        
        HStack {
            // Progress indicator
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: percent)
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                Text("\(Int(percent * 100))%")
                    .font(.caption2)
                    .bold()
            }
            .frame(width: 44, height: 44)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(artwork?.title ?? progress.artworkId)
                    .font(.headline)
                
                HStack {
                    Text("\(progress.revealedCount)/\(totalPixels) pixels")
                    
                    if let dateISO = progress.artworkDateISO {
                        Text("•")
                        Text(formattedDate(dateISO))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
    }
    
    private func formattedDate(_ isoDate: String) -> String {
        guard let date = DateParsing.dateFromISODay(isoDate) else { return isoDate }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }
}

// MARK: - Preview
#Preview {
    List {
        DailyFinalizeListView()
    }
    .modelContainer(for: [SDProgress.self, SDArtwork.self], inMemory: true)
}
