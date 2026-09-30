/*
 * ThemeComponents.swift
 * PixelFocus
 *
 * Composants UI réutilisables, stylés par le thème courant (Environment \.theme).
 *
 * - themedCard / themedScreenBackground
 * - ScreenHeader (logo + grand titre)
 * - PillPicker (filtre segmenté arrondi)
 * - StatTile, DotsProgress, ThemedProgressBar
 * - PixelArtView (rendu Canvas d'une œuvre, performant pour les vignettes)
 */

import SwiftUI

// MARK: - Card & Background

struct ThemedCard: ViewModifier {
    @Environment(\.theme) private var theme
    var padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: ThemeTokens.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ThemeTokens.Radius.card, style: .continuous)
                    .stroke(theme.border, lineWidth: 1)
            )
    }
}

struct ThemedScreenBackground: ViewModifier {
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(theme.background.ignoresSafeArea())
    }
}

extension View {
    func themedCard(padding: CGFloat = 16) -> some View {
        modifier(ThemedCard(padding: padding))
    }

    func themedScreenBackground() -> some View {
        modifier(ThemedScreenBackground())
    }
}

// MARK: - ScreenHeader
struct ScreenHeader: View {
    let title: String
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "square.grid.3x3.fill")
                    .foregroundStyle(theme.primary)
                HStack(spacing: 0) {
                    Text("Pixel")
                        .foregroundStyle(theme.textPrimary)
                    Text("Focus")
                        .foregroundStyle(theme.primary)
                }
                .font(.headline)
            }

            Text(title)
                .font(.system(size: 34, weight: .bold)) // typography.screenTitle
                .foregroundStyle(theme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }
}

// MARK: - SectionTitle
struct SectionTitle: View {
    let title: String
    @Environment(\.theme) private var theme

    var body: some View {
        Text(title)
            .font(.title3.weight(.semibold))
            .foregroundStyle(theme.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - PillPicker
struct PillPicker<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button {
                    withAnimation(.snappy) { selection = option }
                } label: {
                    Text(title(option))
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(isSelected ? theme.onPrimary : theme.textSecondary)
                        .background(
                            Capsule().fill(isSelected ? theme.primary : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(theme.surface, in: Capsule())
        .overlay(Capsule().stroke(theme.border, lineWidth: 1))
    }
}

// MARK: - StatTile
struct StatTile<Footer: View>: View {
    let icon: String
    let color: Color
    let value: String
    let caption: String
    @ViewBuilder let footer: () -> Footer

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Text(value)
                    .font(.title2.bold())
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            footer()
            Text(caption)
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard(padding: 14)
    }
}

// MARK: - DotsProgress
struct DotsProgress: View {
    let filled: Int
    let total: Int
    let color: Color
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<max(total, 0), id: \.self) { index in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(index < filled ? color : theme.surfaceHighlight)
                    .frame(width: 14, height: 10)
            }
        }
    }
}

// MARK: - ThemedProgressBar
struct ThemedProgressBar: View {
    let value: Double
    var color: Color? = nil
    var height: CGFloat = ThemeTokens.Size.progressBarHeight
    @Environment(\.theme) private var theme

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(theme.surfaceHighlight)
                Capsule()
                    .fill(color ?? theme.primary)
                    .frame(width: geometry.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: height)
    }
}

// MARK: - PixelArtView
/// Rendu Canvas d'une grille pixel art: seuls les pixels révélés sont colorés.
struct PixelArtView: View {
    let gridWidth: Int
    let gridHeight: Int
    let palette: [Color]
    let pixels: [Int]
    let revealed: Set<Int>
    let emptyColor: Color
    var spacing: CGFloat = 1
    var cornerRadius: CGFloat = 1

    var body: some View {
        Canvas { context, size in
            guard gridWidth > 0, gridHeight > 0 else { return }
            let cell = min(size.width / CGFloat(gridWidth), size.height / CGFloat(gridHeight))
            let originX = (size.width - cell * CGFloat(gridWidth)) / 2
            let originY = (size.height - cell * CGFloat(gridHeight)) / 2
            let side = max(cell - spacing, 0.5)

            for row in 0..<gridHeight {
                for column in 0..<gridWidth {
                    let index = row * gridWidth + column
                    let rect = CGRect(
                        x: originX + CGFloat(column) * cell,
                        y: originY + CGFloat(row) * cell,
                        width: side,
                        height: side
                    )
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: min(cornerRadius, side / 3)),
                        with: .color(color(at: index))
                    )
                }
            }
        }
        .aspectRatio(CGFloat(max(gridWidth, 1)) / CGFloat(max(gridHeight, 1)), contentMode: .fit)
    }

    private func color(at index: Int) -> Color {
        guard revealed.contains(index), index < pixels.count else { return emptyColor }
        let paletteIndex = pixels[index]
        guard paletteIndex >= 0, paletteIndex < palette.count else { return emptyColor }
        return palette[paletteIndex]
    }
}

extension PixelArtView {
    /// Construit la vue depuis une œuvre SwiftData et le nombre de pixels révélés.
    init(
        artwork: SDArtwork,
        revealedCount: Int,
        emptyColor: Color,
        spacing: CGFloat = 1,
        cornerRadius: CGFloat = 1
    ) {
        let total = artwork.totalPixels
        let count = min(max(revealedCount, 0), total)
        let sequence = artwork.decodeRevealSequence()
        let revealedSet: Set<Int> = sequence.isEmpty ? Set(0..<count) : Set(sequence.prefix(count))

        self.init(
            gridWidth: artwork.gridWidth,
            gridHeight: artwork.gridHeight,
            palette: artwork.decodePalette().map { Color(hex: $0) ?? .gray },
            pixels: artwork.decodePixels(),
            revealed: revealedSet,
            emptyColor: emptyColor,
            spacing: spacing,
            cornerRadius: cornerRadius
        )
    }
}

// MARK: - PrimaryButtonStyle
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(theme.onPrimary)
            .frame(maxWidth: .infinity, minHeight: ThemeTokens.Size.buttonHeight)
            .background(
                RoundedRectangle(cornerRadius: ThemeTokens.Radius.button, style: .continuous)
                    .fill(theme.primary.opacity(isEnabled ? 1 : 0.4))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy, value: configuration.isPressed)
    }
}

// MARK: - SecondaryButtonStyle
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(theme.textPrimary.opacity(isEnabled ? 1 : 0.4))
            .frame(maxWidth: .infinity, minHeight: ThemeTokens.Size.secondaryButtonHeight)
            .background(
                RoundedRectangle(cornerRadius: ThemeTokens.Radius.control, style: .continuous)
                    .fill(theme.surfaceHighlight)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy, value: configuration.isPressed)
    }
}
