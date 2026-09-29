/*
 * UseBoosterSheet.swift
 * PixelFocus
 *
 * Sheet pour utiliser un booster sur une œuvre (voir GAME_DESIGN.md §3).
 *
 * Objectifs:
 * - Afficher les stocks (gagnés / achetés) et ce qui est utilisable aujourd'hui
 * - Utiliser 1 booster (= N pixels) via le callback onUse
 */

import SwiftUI

// MARK: - UseBoosterSheet
struct UseBoosterSheet: View {
    let earnedBoosters: Int
    let purchasedBoosters: Int
    let usableNow: Int
    let pixelsPerBooster: Int
    let dailyEarnedLimit: Int
    let onUse: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.purple)

                    Text("Utiliser un booster")
                        .font(.title2)
                        .bold()

                    Text("1 booster = \(pixelsPerBooster) pixels révélés")
                        .foregroundStyle(.secondary)
                }
                .padding(.top)

                // Stocks
                VStack(spacing: 12) {
                    BoosterStockRow(title: "Gagnés", value: earnedBoosters, caption: "\(dailyEarnedLimit) utilisable(s) par jour")
                    BoosterStockRow(title: "Achetés", value: purchasedBoosters, caption: "sans limite")
                    Divider()
                    BoosterStockRow(title: "Utilisables maintenant", value: usableNow, caption: nil)
                }
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                Text("Les boosters gagnés sont utilisés en premier, dans la limite du jour.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Spacer()

                // Actions
                VStack(spacing: 12) {
                    Button {
                        onUse()
                        dismiss()
                    } label: {
                        Text("Utiliser 1 booster (+\(pixelsPerBooster) pixels)")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(usableNow <= 0)

                    Button("Annuler") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - BoosterStockRow
private struct BoosterStockRow: View {
    let title: String
    let value: Int
    let caption: String?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let caption {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("\(value)")
                .font(.title3)
                .bold()
        }
    }
}

// MARK: - Preview
#Preview {
    UseBoosterSheet(
        earnedBoosters: 4,
        purchasedBoosters: 2,
        usableNow: 3,
        pixelsPerBooster: 5,
        dailyEarnedLimit: 1,
        onUse: {}
    )
}
