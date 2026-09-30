/*
 * OnboardingView.swift
 * PixelFocus
 *
 * Présentation au premier lancement: le but de l'app est la concentration,
 * le pixel art est la récompense.
 *
 * 1. Choisis une tâche  2. Pose ton téléphone  3. Révèle ton œuvre
 */

import SwiftUI

// MARK: - OnboardingView
struct OnboardingView: View {
    static let storageKey = "hasSeenOnboarding"

    let onFinish: () -> Void

    @Environment(\.theme) private var theme
    @State private var page = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "scope",
            title: "Choisis une tâche",
            text: "Une seule chose à la fois : réviser un chapitre, écrire un rapport, ranger ton bureau. Tu la notes avant de lancer la session."
        ),
        OnboardingPage(
            icon: "iphone.slash",
            title: "Pose ton téléphone",
            text: "15 à 30 minutes de concentration, sans notifications. Si tu quittes l'app, la session s'arrête — sauf si tu as un token de protection."
        ),
        OnboardingPage(
            icon: "square.grid.3x3.fill",
            title: "Révèle ton œuvre",
            text: "Chaque session terminée révèle 5 pixels d'une œuvre. Chaque jour, chaque semaine et chaque mois, une nouvelle image à compléter."
        )
    ]

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Spacer()
                Button("Passer") { onFinish() }
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
            }

            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    pageView(pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            DotsProgress(filled: page + 1, total: pages.count, color: theme.primary)

            Button {
                if page < pages.count - 1 {
                    withAnimation(.snappy) { page += 1 }
                } else {
                    onFinish()
                }
            } label: {
                Text(page < pages.count - 1 ? "Suivant" : "Commencer")
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(24)
        .themedScreenBackground()
    }

    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: page.icon)
                .font(.system(size: 72))
                .foregroundStyle(theme.primary)
                .frame(width: 140, height: 140)
                .background(theme.surface, in: Circle())
            Text(page.title)
                .font(.title.bold())
                .foregroundStyle(theme.textPrimary)
                .multilineTextAlignment(.center)
            Text(page.text)
                .font(.body)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
            Spacer()
        }
    }
}

// MARK: - OnboardingPage
private struct OnboardingPage {
    let icon: String
    let title: String
    let text: String
}

// MARK: - Preview
#Preview {
    OnboardingView(onFinish: {})
}
