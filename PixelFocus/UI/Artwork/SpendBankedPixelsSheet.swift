/*
 * SpendBankedPixelsSheet.swift
 * PixelFocus
 *
 * Version: 1.0
 * Date: 15 janvier 2026
 *
 * Sheet pour dépenser des pixels stockés.
 *
 * Objectifs:
 * - Choisir un montant 1..maxAvailable
 * - Appeler callback onSpend
 */

import SwiftUI

// MARK: - SpendBankedPixelsSheet
struct SpendBankedPixelsSheet: View {
    let maxAvailable: Int
    let onSpend: (_ amount: Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var amountToSpend: Int = 1

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 48))
                        .foregroundStyle(.purple)
                    
                    Text("Utiliser pixels stockés")
                        .font(.title2)
                        .bold()

                    Text("Disponible: \(maxAvailable) pixel(s)")
                        .foregroundStyle(.secondary)
                }
                .padding(.top)
                
                // Stepper
                VStack(spacing: 12) {
                    Text("\(amountToSpend)")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(.purple)
                    
                    Text("pixel(s) à utiliser")
                        .foregroundStyle(.secondary)
                    
                    Stepper("", value: $amountToSpend, in: 1...max(1, maxAvailable))
                        .labelsHidden()
                        .disabled(maxAvailable <= 0)
                }
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                // Info
                Text("Chaque pixel stocké révèle 1 pixel de l'œuvre.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Spacer()

                // Actions
                VStack(spacing: 12) {
                    Button {
                        onSpend(amountToSpend)
                        dismiss()
                    } label: {
                        Text("Utiliser \(amountToSpend) pixel(s)")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(maxAvailable <= 0)

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
        .onAppear {
            amountToSpend = min(1, maxAvailable)
        }
    }
}

// MARK: - Preview
#Preview {
    SpendBankedPixelsSheet(maxAvailable: 5) { amount in
        print("Spending \(amount) pixels")
    }
}
