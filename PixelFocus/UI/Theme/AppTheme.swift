/*
 * AppTheme.swift
 * PixelFocus
 *
 * Thèmes de couleur de l'app (voir DESIGN_SYSTEM.md et GAME_DESIGN.md §7).
 * Les valeurs viennent de design/design-tokens.json via tools/generate_theme.py (ThemeTokens.generated.swift).
 *
 * - Minuit: sombre, noir/gris, accent violet (gratuit, par défaut)
 * - Soleil: clair, palette Cerulean / Lime Cream / Gold / Wine Plum (Premium)
 * - Braise: sombre bleu nuit, palette Prussian / Teal / Jasmine / Ember (Premium)
 *
 * Les œuvres pixel art gardent toujours leurs propres couleurs.
 */

import SwiftUI

// MARK: - ThemePalette
struct ThemePalette {
    let background: Color
    let surface: Color
    let surfaceHighlight: Color
    let border: Color
    let primary: Color
    let onPrimary: Color
    let secondary: Color
    let textPrimary: Color
    let textSecondary: Color
    let streak: Color
    let record: Color
    let booster: Color
    let token: Color
    let success: Color
    let danger: Color
    /// Couleur d'un pixel pas encore révélé
    let emptyPixel: Color
    let colorScheme: ColorScheme
}

// MARK: - AppTheme
enum AppTheme: String, CaseIterable, Identifiable {
    case minuit
    case soleil
    case braise

    static let storageKey = "appTheme"

    var id: String { rawValue }

    var displayName: String {
        ThemeTokens.name(for: self)
    }

    var subtitle: String {
        ThemeTokens.subtitle(for: self)
    }

    var requiresPremium: Bool {
        ThemeTokens.requiresPremium(self)
    }

    /// Thème réellement appliqué: un thème Premium retombe sur Minuit sans Premium
    static func effective(storedRawValue: String, isPremium: Bool) -> AppTheme {
        let stored = AppTheme(rawValue: storedRawValue) ?? .minuit
        return (stored.requiresPremium && !isPremium) ? .minuit : stored
    }

    /// Couleurs du thème (générées depuis design/design-tokens.json)
    var palette: ThemePalette {
        ThemeTokens.palette(for: self)
    }
}

// MARK: - Environment
private struct ThemePaletteKey: EnvironmentKey {
    static let defaultValue: ThemePalette = AppTheme.minuit.palette
}

extension EnvironmentValues {
    /// Palette du thème courant (injectée par la racine de l'app)
    var theme: ThemePalette {
        get { self[ThemePaletteKey.self] }
        set { self[ThemePaletteKey.self] = newValue }
    }
}

// MARK: - Color Helpers
extension Color {
    /// Couleur depuis un entier 0xRRGGBB
    init(rgb: UInt32, opacity: Double = 1) {
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255.0,
            green: Double((rgb >> 8) & 0xFF) / 255.0,
            blue: Double(rgb & 0xFF) / 255.0,
            opacity: opacity
        )
    }

    /// Couleur depuis une chaîne "#RRGGBB" (palettes des œuvres)
    init?(hex: String) {
        var sanitizedHexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitizedHexString = sanitizedHexString.replacingOccurrences(of: "#", with: "")

        var rgbValue: UInt64 = 0
        guard Scanner(string: sanitizedHexString).scanHexInt64(&rgbValue) else { return nil }

        self.init(rgb: UInt32(truncatingIfNeeded: rgbValue))
    }
}
