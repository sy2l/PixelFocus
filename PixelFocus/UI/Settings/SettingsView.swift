/*
 * SettingsView.swift
 * PixelFocus
 *
 * Réglages (maquette v2).
 *
 * Objectifs:
 * - Premium: statut, boutique, restauration (et Premium simulé en développement)
 * - Compte et synchronisation: état, Se connecter avec Apple, suppression du compte
 * - Apparence: choix du thème (Minuit gratuit; Soleil et Braise Premium)
 * - Statistiques, règles du jeu, à propos
 */

import SwiftUI
import SwiftData
import AuthenticationServices

// MARK: - SettingsView
struct SettingsView: View {
    @EnvironmentObject private var appCoordinator: AppCoordinator
    @EnvironmentObject private var entitlements: EntitlementStore
    @EnvironmentObject private var syncService: SyncService
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.theme) private var theme

    @AppStorage(AppTheme.storageKey) private var storedTheme: String = AppTheme.minuit.rawValue

    @Query private var wallets: [SDWallet]
    @Query private var streaks: [SDStreak]
    @Query private var progresses: [SDProgress]
    @Query private var badges: [SDBadge]

    @State private var infoMessage: String?
    @State private var isStorePresented = false
    @State private var isDeleteConfirmationPresented = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ScreenHeader(title: "Réglages")

                    if let infoMessage {
                        MessageBanner(text: infoMessage, color: theme.primary)
                    }

                    accountSection
                    syncSection
                    appearanceSection
                    statsSection
                    rulesSection
                    aboutSection

                    Spacer(minLength: 20)
                }
                .padding(.horizontal)
            }
            .themedScreenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isStorePresented) {
                StoreView()
                    .environment(\.theme, theme)
            }
            .confirmationDialog(
                "Supprimer ton compte et toutes tes données ?",
                isPresented: $isDeleteConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button("Supprimer définitivement", role: .destructive) {
                    Task { await deleteAccount() }
                }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("Progression, boosters, badges et historique seront effacés, sur cet appareil et sur le serveur. Les abonnements App Store se résilient depuis les réglages de ton compte Apple.")
            }
        }
    }

    // MARK: - Account

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Premium")

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "crown.fill")
                        .font(.title2)
                        .foregroundStyle(theme.record)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entitlements.isPremium ? "Premium actif" : "Version gratuite")
                            .font(.headline)
                            .foregroundStyle(theme.textPrimary)
                        Text(premiumSubtitle)
                            .font(.caption)
                            .foregroundStyle(theme.textSecondary)
                    }
                    Spacer()
                }

                if entitlements.isPremium {
                    PremiumPerkRow(text: "15 & 20 min illimités")
                    PremiumPerkRow(text: "Toutes les images du mois")
                    PremiumPerkRow(text: "2 boosters offerts chaque mois")
                    PremiumPerkRow(text: "3 boosters gagnés utilisables par jour")
                    PremiumPerkRow(text: "Thèmes Soleil et Braise")
                }

                Button {
                    isStorePresented = true
                } label: {
                    Label(entitlements.isPremium ? "Boutique et boosters" : "Découvrir Premium", systemImage: "sparkles")
                }
                .buttonStyle(PrimaryButtonStyle())

                Button {
                    Task { await restorePurchases() }
                } label: {
                    Label("Restaurer les achats", systemImage: "arrow.clockwise")
                }
                .buttonStyle(SecondaryButtonStyle())

                #if DEBUG
                // Tests sans achat: n'existe pas dans la version publiée sur l'App Store
                Toggle(isOn: Binding(
                    get: { entitlements.debugPremium },
                    set: { appCoordinator.setDebugPremium($0) }
                )) {
                    Text("Premium simulé (développement)")
                        .font(.footnote)
                        .foregroundStyle(theme.textSecondary)
                }
                .tint(theme.primary)
                #endif
            }
            .themedCard()
        }
    }

    private var premiumSubtitle: String {
        if entitlements.isLifetime { return "À vie" }
        if entitlements.isPremium { return "Abonnement en cours" }
        return "Passe Premium pour tout débloquer"
    }

    // MARK: - Sync

    private var syncSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Compte et synchronisation")

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: syncIcon)
                        .font(.title3)
                        .foregroundStyle(syncColor)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(syncTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.textPrimary)
                        Text(syncSubtitle)
                            .font(.caption)
                            .foregroundStyle(theme.textSecondary)
                    }
                    Spacer()
                    if syncService.status == .syncing {
                        ProgressView()
                    }
                }

                if syncService.status != .notConfigured {
                    Button {
                        Task { await syncService.syncNow() }
                    } label: {
                        Label("Synchroniser maintenant", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(syncService.status == .syncing)

                    if syncService.isAppleLinked {
                        Label("Compte Apple rattaché : ta progression te suit sur tous tes appareils.", systemImage: "checkmark.seal.fill")
                            .font(.footnote)
                            .foregroundStyle(theme.success)
                    } else {
                        Text("Connecte-toi avec Apple pour retrouver ta progression sur un autre appareil, y compris Android.")
                            .font(.footnote)
                            .foregroundStyle(theme.textSecondary)
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = []
                        } onCompletion: { result in
                            Task { await handleAppleSignIn(result) }
                        }
                        .signInWithAppleButtonStyle(theme.colorScheme == .dark ? .white : .black)
                        .frame(height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.Radius.control, style: .continuous))
                    }
                }

                Button(role: .destructive) {
                    isDeleteConfirmationPresented = true
                } label: {
                    Label("Supprimer mon compte et mes données", systemImage: "trash")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(theme.danger)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .themedCard()
        }
    }

    private var syncIcon: String {
        switch syncService.status {
        case .notConfigured: return "icloud.slash"
        case .idle: return "checkmark.icloud"
        case .syncing: return "arrow.triangle.2.circlepath.icloud"
        case .failed: return "exclamationmark.icloud"
        }
    }

    private var syncColor: Color {
        switch syncService.status {
        case .idle: return theme.success
        case .failed: return theme.danger
        default: return theme.textSecondary
        }
    }

    private var syncTitle: String {
        switch syncService.status {
        case .notConfigured: return "Hors ligne"
        case .idle: return "Synchronisé"
        case .syncing: return "Synchronisation…"
        case .failed: return "Synchronisation en attente"
        }
    }

    private var syncSubtitle: String {
        switch syncService.status {
        case .notConfigured:
            return "Ta progression est enregistrée sur cet appareil."
        case .failed(let message):
            return message
        default:
            guard let lastSyncAt = syncService.lastSyncAt else { return "Jamais synchronisé" }
            return "Dernière synchronisation : " + lastSyncAt.formatted(date: .abbreviated, time: .shortened)
        }
    }

    // MARK: - Actions

    private func restorePurchases() async {
        do {
            try await purchaseManager.restore()
            infoMessage = "Achats restaurés."
        } catch {
            infoMessage = "Restauration impossible : \(error.localizedDescription)"
        }
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let identityToken = String(data: tokenData, encoding: .utf8) else {
                infoMessage = "Connexion Apple impossible."
                return
            }
            do {
                try await syncService.linkApple(identityToken: identityToken)
                infoMessage = "Compte Apple rattaché."
            } catch {
                infoMessage = "Connexion Apple impossible : \(error.localizedDescription)"
            }
        case .failure(let error):
            // Annulation par l'utilisateur: rien à signaler
            if (error as? ASAuthorizationError)?.code != .canceled {
                infoMessage = "Connexion Apple indisponible : vérifie la capacité « Sign in with Apple » du projet."
            }
        }
    }

    private func deleteAccount() async {
        do {
            try await syncService.deleteAccountAndLocalData()
            appCoordinator.applyDatePolicies()
            infoMessage = "Compte et données supprimés."
        } catch {
            infoMessage = "Suppression impossible : \(error.localizedDescription)"
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        let current = AppTheme.effective(storedRawValue: storedTheme, isPremium: entitlements.isPremium)
        return VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Apparence")

            HStack(spacing: 12) {
                ForEach(AppTheme.allCases) { appTheme in
                    let isLocked = appTheme.requiresPremium && !entitlements.isPremium
                    Button {
                        if isLocked {
                            infoMessage = "Le thème \(appTheme.displayName) est inclus avec Premium."
                        } else {
                            infoMessage = nil
                            storedTheme = appTheme.rawValue
                        }
                    } label: {
                        ThemeSwatch(theme: appTheme, isSelected: appTheme == current, isLocked: isLocked)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        let wallet = wallets.first
        let streak = streaks.first
        let completedCount = progresses.filter { $0.state == .completed }.count
        let totalPixelsRevealed = progresses.reduce(0) { $0 + $1.revealedCount }

        return VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Statistiques")
            VStack(spacing: 12) {
                StatRow(icon: "flame.fill", color: theme.streak, title: "Série actuelle", value: "\(streak?.current ?? 0) jour(s)")
                StatRow(icon: "trophy.fill", color: theme.record, title: "Record", value: "\(streak?.longestStreak ?? 0) jour(s)")
                StatRow(icon: "rosette", color: theme.record, title: "Badges", value: "\(badges.count)/\(BadgePolicy.all.count)")
                StatRow(icon: "bolt.fill", color: theme.booster, title: "Boosters gagnés", value: "\(wallet?.earnedBoosters ?? 0)/12")
                StatRow(icon: "bolt.circle.fill", color: theme.booster, title: "Boosters achetés", value: "\(wallet?.purchasedBoosters ?? 0)")
                StatRow(icon: "shield.fill", color: theme.token, title: "Tokens de protection", value: "\(wallet?.protectionTokensAvailable ?? 0)")
                StatRow(icon: "checkmark.seal.fill", color: theme.success, title: "Œuvres terminées", value: "\(completedCount)")
                StatRow(icon: "sparkles", color: theme.primary, title: "Pixels révélés", value: "\(totalPixelsRevealed)")
            }
            .themedCard()
        }
    }

    // MARK: - Rules

    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Règles du jeu")
            VStack(alignment: .leading, spacing: 12) {
                RuleRow(icon: "timer", text: "1 session terminée = +5 pixels, quelle que soit la durée")
                RuleRow(icon: "hourglass", text: "Gratuit : 15 et 20 min = 1 fois par jour ; 25 et 30 min illimités")
                RuleRow(icon: "shield.fill", text: "30 min = +1 token : reprendre au temps restant si interruption")
                RuleRow(icon: "flame.fill", text: "Série : la daily du jour terminée le jour même → 1 booster tous les 3 jours, +1 tous les 18 jours")
                RuleRow(icon: "bolt.fill", text: "Booster : révèle 5 pixels. Gagnés : 1/jour (3 en Premium). Achetés : sans limite")
                RuleRow(icon: "calendar", text: "Daily non terminées : jouables jusqu'au 31 décembre")
                RuleRow(icon: "gift.fill", text: "Image du mois : la première est offerte, puis Premium, défi de 20 sessions ou achat")
            }
            .themedCard()
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "À propos")
            VStack(spacing: 12) {
                StatRow(icon: "info.circle", color: theme.textSecondary, title: "Version", value: "1.1.0")

                Link(destination: URL(string: "https://example.com/privacy")!) {
                    HStack {
                        Text("Politique de confidentialité")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                    }
                    .foregroundStyle(theme.textPrimary)
                }

                Link(destination: URL(string: "https://example.com/terms")!) {
                    HStack {
                        Text("Conditions d'utilisation")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                    }
                    .foregroundStyle(theme.textPrimary)
                }
            }
            .themedCard()
        }
    }
}

// MARK: - ThemeSwatch
private struct ThemeSwatch: View {
    let theme: AppTheme
    let isSelected: Bool
    let isLocked: Bool

    @Environment(\.theme) private var currentPalette

    var body: some View {
        let palette = theme.palette
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(palette.background)
                    .frame(height: 84)
                    .overlay(
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(palette.surface)
                                .frame(height: 22)
                            HStack(spacing: 6) {
                                Circle().fill(palette.primary).frame(width: 16, height: 16)
                                Circle().fill(palette.secondary).frame(width: 16, height: 16)
                                Circle().fill(palette.record).frame(width: 16, height: 16)
                            }
                        }
                        .padding(10)
                    )

                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(palette.textPrimary)
                        .padding(6)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? currentPalette.primary : currentPalette.border, lineWidth: isSelected ? 3 : 1)
            )

            VStack(spacing: 0) {
                Text(theme.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(currentPalette.textPrimary)
                Text(theme.requiresPremium ? "\(theme.subtitle) • Premium" : theme.subtitle)
                    .font(.caption2)
                    .foregroundStyle(currentPalette.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - StatRow
struct StatRow: View {
    let icon: String
    let color: Color
    let title: String
    let value: String

    @Environment(\.theme) private var theme

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(title)
                .foregroundStyle(theme.textPrimary)
            Spacer()
            Text(value)
                .foregroundStyle(theme.textSecondary)
        }
        .font(.subheadline)
    }
}

// MARK: - RuleRow
struct RuleRow: View {
    let icon: String
    let text: String

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(theme.primary)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - PremiumPerkRow
private struct PremiumPerkRow: View {
    let text: String
    @Environment(\.theme) private var theme

    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(theme.success)
            Text(text)
                .foregroundStyle(theme.textSecondary)
        }
        .font(.subheadline)
    }
}

// MARK: - Preview
#Preview {
    SettingsView()
        .withAppEnvironment(AppCoordinator())
}
