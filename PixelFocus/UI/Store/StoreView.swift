/*
 * StoreView.swift
 * PixelFocus
 *
 * Boutique: Premium (mensuel, annuel, à vie), boosters, restauration des achats.
 *
 * - Prix affichés depuis l'App Store (Product.displayPrice), jamais écrits en dur
 * - Offre "à vie" au tarif abonné proposée uniquement pendant un abonnement actif
 * - Après un achat à vie pendant un abonnement: invitation à résilier l'abonnement
 */

import SwiftUI
import StoreKit

// MARK: - StoreView
struct StoreView: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @EnvironmentObject private var entitlements: EntitlementStore
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var message: String?
    @State private var purchasingId: String?
    @State private var isManageSubscriptionsPresented = false
    @State private var isCancelSubscriptionHintPresented = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header

                    if let message {
                        MessageBanner(text: message, color: theme.primary)
                    }

                    premiumSection
                    boostersSection
                    footer
                }
                .padding()
            }
            .themedScreenBackground()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }
            .manageSubscriptionsSheet(isPresented: $isManageSubscriptionsPresented)
            .alert("Pense à résilier ton abonnement", isPresented: $isCancelSubscriptionHintPresented) {
                Button("Gérer mon abonnement") { isManageSubscriptionsPresented = true }
                Button("Plus tard", role: .cancel) {}
            } message: {
                Text("Tu as maintenant Premium à vie. Ton abonnement ne s'arrête pas tout seul : résilie-le pour ne plus être prélevé.")
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "crown.fill")
                .font(.system(size: 40))
                .foregroundStyle(theme.record)
            Text("PixelFocus Premium")
                .font(.title.bold())
                .foregroundStyle(theme.textPrimary)
            Text("Plus de concentration, plus d'œuvres.")
                .foregroundStyle(theme.textSecondary)

            VStack(alignment: .leading, spacing: 8) {
                PerkRow(icon: "timer", text: "Sessions de 15 et 20 min illimitées")
                PerkRow(icon: "star.fill", text: "Toutes les images du mois")
                PerkRow(icon: "shippingbox.fill", text: "Les packs thématiques de l'année")
                PerkRow(icon: "bolt.fill", text: "2 boosters offerts chaque mois, 3 utilisables par jour")
                PerkRow(icon: "paintpalette.fill", text: "Thèmes Soleil et Braise")
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }

    // MARK: - Premium

    @ViewBuilder
    private var premiumSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Premium")

            if entitlements.isLifetime {
                Label("Tu as Premium à vie. Merci !", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(theme.success)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .themedCard()
            } else {
                offerRow(id: StoreProducts.premiumYearly, title: "Annuel", subtitle: "Essai gratuit de 7 jours • le meilleur prix", highlighted: true)
                offerRow(id: StoreProducts.premiumMonthly, title: "Mensuel", subtitle: "Sans engagement", highlighted: false)
                if purchaseManager.hasActiveSubscription {
                    offerRow(id: StoreProducts.lifetimeMember, title: "À vie — tarif abonné", subtitle: "Un seul paiement, pour toujours", highlighted: false)
                } else {
                    offerRow(id: StoreProducts.lifetime, title: "À vie", subtitle: "Un seul paiement, pour toujours", highlighted: false)
                }
            }
        }
    }

    // MARK: - Boosters

    private var boostersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Boosters")
            Text("1 booster = 5 pixels révélés. Les boosters achetés s'utilisent sans limite par jour.")
                .font(.footnote)
                .foregroundStyle(theme.textSecondary)

            HStack(spacing: 12) {
                ForEach(StoreProducts.boosterIdsSorted, id: \.self) { id in
                    boosterTile(id: id, amount: StoreProducts.boosters[id] ?? 0)
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 12) {
            Button {
                Task { await restore() }
            } label: {
                Label("Restaurer les achats", systemImage: "arrow.clockwise")
            }
            .buttonStyle(SecondaryButtonStyle())

            Text("Les abonnements se renouvellent automatiquement sauf résiliation au moins 24 h avant la fin de la période, depuis les réglages de ton compte Apple.")
                .font(.caption2)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Link("Conditions d'utilisation", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                Link("Confidentialité", destination: URL(string: "https://example.com/privacy")!)
            }
            .font(.caption)
            .foregroundStyle(theme.primary)
        }
        .padding(.top, 8)
    }

    // MARK: - Rows

    private func offerRow(id: String, title: String, subtitle: String, highlighted: Bool) -> some View {
        let product = purchaseManager.product(id)
        return Button {
            Task { await buy(id) }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(theme.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer()
                if purchasingId == id {
                    ProgressView()
                } else {
                    Text(product?.displayPrice ?? "—")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(highlighted ? theme.onPrimary : theme.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(highlighted ? theme.primary : theme.surfaceHighlight, in: Capsule())
                }
            }
            .themedCard(padding: 14)
            .overlay(
                RoundedRectangle(cornerRadius: ThemeTokens.Radius.card, style: .continuous)
                    .stroke(highlighted ? theme.primary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .disabled(product == nil || purchasingId != nil)
    }

    private func boosterTile(id: String, amount: Int) -> some View {
        let product = purchaseManager.product(id)
        return Button {
            Task { await buy(id) }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.title2)
                    .foregroundStyle(theme.booster)
                Text("× \(amount)")
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)
                Text(product?.displayPrice ?? "—")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .themedCard(padding: 12)
        }
        .buttonStyle(.plain)
        .disabled(product == nil || purchasingId != nil)
    }

    // MARK: - Actions

    private func buy(_ id: String) async {
        guard let product = purchaseManager.product(id) else {
            message = "Produit indisponible pour le moment."
            return
        }
        let wasSubscribed = purchaseManager.hasActiveSubscription
        purchasingId = id
        defer { purchasingId = nil }

        do {
            switch try await purchaseManager.purchase(product) {
            case .purchased:
                message = "Merci ! Ton achat est actif."
                if StoreProducts.lifetimes.contains(id) && wasSubscribed {
                    isCancelSubscriptionHintPresented = true
                }
            case .pending:
                message = "Achat en attente de validation (contrôle parental ou paiement)."
            case .cancelled:
                break
            }
        } catch {
            message = "L'achat n'a pas abouti : \(error.localizedDescription)"
        }
    }

    private func restore() async {
        do {
            try await purchaseManager.restore()
            message = "Achats restaurés."
        } catch {
            message = "Restauration impossible : \(error.localizedDescription)"
        }
    }
}

// MARK: - PerkRow
private struct PerkRow: View {
    let icon: String
    let text: String
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(theme.primary)
                .frame(width: 22)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(theme.textPrimary)
        }
    }
}
