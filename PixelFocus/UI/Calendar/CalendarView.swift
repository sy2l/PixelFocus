/*
 * CalendarView.swift
 * PixelFocus
 *
 * Calendrier (maquette v2).
 *
 * Objectifs:
 * - Naviguer mois par mois dans l'année calendaire en cours
 * - Grille lundi -> dimanche: vignette pixel art de chaque daily (progression visible)
 * - Jours futurs grisés; aujourd'hui entouré; daily terminées marquées
 * - Daily non terminées: jouables jusqu'à la fin de l'année
 * - Aperçu de l'image du mois affiché
 *
 * Technique:
 * - Import SwiftData des daily du mois affiché à la demande (.task(id:))
 */

import SwiftUI
import SwiftData

// MARK: - CalendarView
struct CalendarView: View {
    @EnvironmentObject private var appCoordinator: AppCoordinator
    @Environment(\.theme) private var theme

    @Query private var progresses: [SDProgress]
    @Query private var artworks: [SDArtwork]

    @State private var displayedMonth: Int = Calendar.current.component(.month, from: Date())

    private let currentYear = Calendar.current.component(.year, from: Date())
    private let weekdaySymbols = ["LUN", "MAR", "MER", "JEU", "VEN", "SAM", "DIM"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ScreenHeader(title: "Calendrier")
                    monthNavigator
                    monthGrid
                    monthSummary
                    monthlyPreview
                    ruleCard
                    Spacer(minLength: 20)
                }
                .padding(.horizontal)
            }
            .themedScreenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .task(id: "\(displayedMonth)-\(appCoordinator.isReady)") {
                importDisplayedMonth()
            }
        }
    }

    // MARK: - Month Navigator

    private var monthNavigator: some View {
        HStack {
            Button {
                withAnimation(.snappy) { displayedMonth -= 1 }
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 44, height: 44)
            }
            .disabled(displayedMonth <= 1)

            Spacer()

            Text(monthTitle)
                .font(.headline)
                .foregroundStyle(theme.textPrimary)

            Spacer()

            Button {
                withAnimation(.snappy) { displayedMonth += 1 }
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 44, height: 44)
            }
            .disabled(displayedMonth >= 12)
        }
        .foregroundStyle(theme.textPrimary)
        .themedCard(padding: 4)
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: firstDayOfDisplayedMonth).capitalized
    }

    // MARK: - Month Grid

    private var monthGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
        return VStack(spacing: 8) {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(theme.textSecondary)
                }
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(0..<leadingBlankDays, id: \.self) { _ in
                    Color.clear.frame(height: 52)
                }
                ForEach(daysInDisplayedMonth, id: \.self) { day in
                    dayCell(day: day)
                }
            }
        }
        .themedCard(padding: 12)
    }

    @ViewBuilder
    private func dayCell(day: Int) -> some View {
        let dayISO = String(format: "%04d-%02d-%02d", currentYear, displayedMonth, day)
        let entry = appCoordinator.catalog?.daily.first(where: { $0.date == dayISO })
        let isToday = dayISO == DatePolicy.isoDayString(for: Date())
        let isFuture = dayISO > DatePolicy.isoDayString(for: Date())

        if let entry, !isFuture {
            NavigationLink {
                ArtworkDetailView(artworkId: entry.artworkId)
            } label: {
                DayCellContent(
                    day: day,
                    artwork: artwork(entry.artworkId),
                    progress: progress(entry.artworkId),
                    isToday: isToday,
                    isFuture: false
                )
            }
            .buttonStyle(.plain)
        } else {
            DayCellContent(day: day, artwork: nil, progress: nil, isToday: isToday, isFuture: true)
        }
    }

    // MARK: - Summary

    private var monthSummary: some View {
        let entries = dailyEntriesOfDisplayedMonth
        let completed = entries.filter { progress($0.artworkId)?.state == .completed }.count
        let started = entries.filter { progress($0.artworkId)?.state == .toFinalize }.count

        return HStack(spacing: 12) {
            SummaryPill(icon: "checkmark.seal.fill", color: theme.success, value: "\(completed)", label: "terminées")
            SummaryPill(icon: "hourglass", color: theme.streak, value: "\(started)", label: "à finaliser")
            SummaryPill(icon: "calendar", color: theme.primary, value: "\(entries.count)", label: "ce mois")
        }
    }

    // MARK: - Monthly Preview

    @ViewBuilder
    private var monthlyPreview: some View {
        let monthISO = String(format: "%04d-%02d", currentYear, displayedMonth)
        if let entry = appCoordinator.catalog?.monthly.first(where: { $0.month == monthISO }),
           monthISO <= DatePolicy.isoMonthString(for: Date()) {
            let isUnlocked = appCoordinator.canPlay(artworkId: entry.artworkId)
            NavigationLink {
                ArtworkDetailView(artworkId: entry.artworkId)
            } label: {
                ArtworkRowCard(
                    artwork: artwork(entry.artworkId),
                    revealedCount: progress(entry.artworkId)?.revealedCount ?? 0,
                    title: "Image du mois",
                    subtitle: isUnlocked ? (artwork(entry.artworkId)?.title ?? "Monthly") : "Verrouillée",
                    isLocked: !isUnlocked
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Rule

    private var ruleCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(theme.primary)
            Text("Les daily non terminées restent jouables jusqu'au 31 décembre. Seule la daily terminée le jour même compte pour la série et les badges.")
                .font(.footnote)
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard(padding: 14)
    }

    // MARK: - Date Helpers

    private var firstDayOfDisplayedMonth: Date {
        Calendar.current.date(from: DateComponents(year: currentYear, month: displayedMonth, day: 1)) ?? Date()
    }

    private var daysInDisplayedMonth: [Int] {
        let count = Calendar.current.range(of: .day, in: .month, for: firstDayOfDisplayedMonth)?.count ?? 30
        return Array(1...count)
    }

    /// Nombre de cases vides avant le 1er (semaine commençant le lundi)
    private var leadingBlankDays: Int {
        let weekday = Calendar.current.component(.weekday, from: firstDayOfDisplayedMonth) // 1 = dimanche
        return (weekday + 5) % 7
    }

    private var dailyEntriesOfDisplayedMonth: [DailyEntryDTO] {
        let prefix = String(format: "%04d-%02d-", currentYear, displayedMonth)
        let todayISO = DatePolicy.isoDayString(for: Date())
        return appCoordinator.catalog?.daily.filter { $0.date.hasPrefix(prefix) && $0.date <= todayISO } ?? []
    }

    private func artwork(_ artworkId: String) -> SDArtwork? {
        artworks.first(where: { $0.artworkId == artworkId })
    }

    private func progress(_ artworkId: String) -> SDProgress? {
        progresses.first(where: { $0.artworkId == artworkId })
    }

    private func importDisplayedMonth() {
        guard appCoordinator.isReady else { return }
        for entry in dailyEntriesOfDisplayedMonth {
            try? appCoordinator.ensureArtworkImported(artworkId: entry.artworkId)
        }
        let monthISO = String(format: "%04d-%02d", currentYear, displayedMonth)
        if let monthly = appCoordinator.catalog?.monthly.first(where: { $0.month == monthISO }) {
            try? appCoordinator.ensureArtworkImported(artworkId: monthly.artworkId)
        }
    }
}

// MARK: - DayCellContent
private struct DayCellContent: View {
    let day: Int
    let artwork: SDArtwork?
    let progress: SDProgress?
    let isToday: Bool
    let isFuture: Bool

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 3) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(theme.surfaceHighlight.opacity(isFuture ? 0.4 : 1))

                if let artwork {
                    PixelArtView(
                        artwork: artwork,
                        revealedCount: progress?.revealedCount ?? 0,
                        emptyColor: theme.emptyPixel.opacity(0.6),
                        spacing: 0.5,
                        cornerRadius: 0.5
                    )
                    .padding(4)
                }

                if progress?.state == .completed {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.success)
                        .offset(x: 3, y: -3)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isToday ? theme.primary : Color.clear, lineWidth: 2)
            )

            Text("\(day)")
                .font(.caption2.weight(isToday ? .bold : .regular))
                .foregroundStyle(isFuture ? theme.textSecondary.opacity(0.5) : theme.textPrimary)
        }
    }
}

// MARK: - SummaryPill
private struct SummaryPill: View {
    let icon: String
    let color: Color
    let value: String
    let label: String

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(value)
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .themedCard(padding: 10)
    }
}

// MARK: - Preview
#Preview {
    CalendarView()
        .environmentObject(AppCoordinator())
        .modelContainer(for: [SDProgress.self, SDArtwork.self], inMemory: true)
}
