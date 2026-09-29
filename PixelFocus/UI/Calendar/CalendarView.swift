/*
 * CalendarView.swift
 * PixelFocus
 *
 * Version: 1.0
 * Date: 15 janvier 2026
 *
 * Calendrier (V1).
 *
 * Objectifs:
 * - Afficher les daily du mois en cours
 * - Section "À finaliser" avec timer de purge (jusqu'au 4)
 * - Navigation vers ArtworkDetailView
 *
 * Technique:
 * - AppCoordinator via EnvironmentObject
 * - SwiftData pour les progressions
 */

import SwiftUI
import SwiftData

// MARK: - CalendarView
struct CalendarView: View {
    @EnvironmentObject private var appCoordinator: AppCoordinator

    @State private var selectedMonth: String = DateParsing.currentMonthISO(date: Date())

    var body: some View {
        NavigationStack {
            List {
                // Section du mois en cours
                Section("Daily du mois") {
                    if let catalog = appCoordinator.catalog {
                        let monthDailies = catalog.daily.filter { entry in
                            DateParsing.monthFromISODay(entry.date) == selectedMonth
                        }

                        if monthDailies.isEmpty {
                            Text("Aucune daily pour ce mois.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(monthDailies, id: \.date) { entry in
                                NavigationLink {
                                    ArtworkDetailView(artworkId: entry.artworkId)
                                } label: {
                                    DailyCalendarRow(entry: entry)
                                }
                            }
                        }
                    } else {
                        Text("Chargement…")
                            .foregroundStyle(.secondary)
                    }
                }

                // Section À finaliser
                Section("À finaliser (Daily)") {
                    DailyFinalizeListView()
                }

                // Règle de purge
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Règle de purge", systemImage: "trash.circle")
                            .font(.headline)
                        
                        Text("Les daily non terminées restent en \"À finaliser\" jusqu'au 4 du mois suivant. Le 4, elles sont supprimées définitivement.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        
                        // Compte à rebours jusqu'au prochain 4
                        if let daysUntilPurge = daysUntilNextPurge() {
                            HStack {
                                Image(systemName: "clock.badge.exclamationmark")
                                    .foregroundStyle(.orange)
                                Text("Prochaine purge dans \(daysUntilPurge) jour(s)")
                                    .font(.footnote)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Calendrier")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    MonthPicker(selectedMonth: $selectedMonth)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func daysUntilNextPurge() -> Int? {
        let calendar = Calendar.current
        let now = Date()
        let currentDay = calendar.component(.day, from: now)
        
        if currentDay < 4 {
            // Le 4 est ce mois-ci
            return 4 - currentDay
        } else {
            // Le 4 est le mois prochain
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: now) else { return nil }
            let components = calendar.dateComponents([.year, .month], from: nextMonth)
            guard let purgeDate = calendar.date(from: DateComponents(year: components.year, month: components.month, day: 4)) else { return nil }
            
            let days = calendar.dateComponents([.day], from: now, to: purgeDate).day
            return days
        }
    }
}

// MARK: - DailyCalendarRow
struct DailyCalendarRow: View {
    let entry: DailyEntryDTO
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(formattedDate(entry.date))
                    .font(.headline)
                Text(entry.artworkId)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Indicateur si c'est aujourd'hui
            if entry.date == DatePolicy.isoDayString(for: Date()) {
                Text("Aujourd'hui")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.blue)
                    .clipShape(Capsule())
            }
        }
    }
    
    private func formattedDate(_ isoDate: String) -> String {
        guard let date = DateParsing.dateFromISODay(isoDate) else { return isoDate }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "EEEE d MMMM"
        return formatter.string(from: date).capitalized
    }
}

// MARK: - MonthPicker
struct MonthPicker: View {
    @Binding var selectedMonth: String
    
    var body: some View {
        Menu {
            ForEach(availableMonths(), id: \.self) { month in
                Button {
                    selectedMonth = month
                } label: {
                    Text(formattedMonth(month))
                    if month == selectedMonth {
                        Image(systemName: "checkmark")
                    }
                }
            }
        } label: {
            Label(formattedMonth(selectedMonth), systemImage: "calendar")
        }
    }
    
    private func availableMonths() -> [String] {
        // Retourne les 3 derniers mois et le mois courant
        let calendar = Calendar.current
        let now = Date()
        var months: [String] = []
        
        for offset in -2...1 {
            if let date = calendar.date(byAdding: .month, value: offset, to: now) {
                months.append(DateParsing.currentMonthISO(date: date))
            }
        }
        
        return months.reversed()
    }
    
    private func formattedMonth(_ monthISO: String) -> String {
        let parts = monthISO.split(separator: "-")
        guard parts.count == 2,
              let year = Int(parts[0]),
              let month = Int(parts[1]) else { return monthISO }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "MMMM yyyy"
        
        let components = DateComponents(year: year, month: month, day: 1)
        guard let date = Calendar.current.date(from: components) else { return monthISO }
        
        return formatter.string(from: date).capitalized
    }
}

// MARK: - Preview
#Preview {
    CalendarView()
        .environmentObject(AppCoordinator())
        .modelContainer(for: [SDProgress.self, SDArtwork.self], inMemory: true)
}
