/*
 * AppTheme.swift
 * PixelFocus
 *
 * Thèmes de couleur de l'app (voir GAME_DESIGN.md §7).
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
        switch self {
        case .minuit: return "Minuit"
        case .soleil: return "Soleil"
        case .braise: return "Braise"
        }
    }

    var subtitle: String {
        switch self {
        case .minuit: return "Sombre"
        case .soleil: return "Clair"
        case .braise: return "Bleu nuit"
        }
    }

    var requiresPremium: Bool {
        self != .minuit
    }

    /// Thème réellement appliqué: un thème Premium retombe sur Minuit sans Premium
    static func effective(storedRawValue: String, isPremium: Bool) -> AppTheme {
        let stored = AppTheme(rawValue: storedRawValue) ?? .minuit
        return (stored.requiresPremium && !isPremium) ? .minuit : stored
    }

    var palette: ThemePalette {
        switch self {
        case .minuit:
            return ThemePalette(
                background: Color(rgb: 0x0B0B0F),
                surface: Color(rgb: 0x1C1C22),
                surfaceHighlight: Color(rgb: 0x2A2A33),
                border: Color.white.opacity(0.06),
                primary: Color(rgb: 0x8B5CF6),
                onPrimary: .white,
                secondary: Color(rgb: 0xC4B5FD),
                textPrimary: .white,
                textSecondary: Color(rgb: 0x9CA3AF),
                streak: Color(rgb: 0xFB923C),
                record: Color(rgb: 0xFACC15),
                booster: Color(rgb: 0xA78BFA),
                token: Color(rgb: 0x2DD4BF),
                success: Color(rgb: 0x4ADE80),
                danger: Color(rgb: 0xF87171),
                emptyPixel: Color(rgb: 0x2A2A33),
                colorScheme: .dark
            )
        case .soleil:
            return ThemePalette(
                background: Color(rgb: 0xF7F8E3),
                surface: Color(rgb: 0xFFFDF2),
                surfaceHighlight: Color(rgb: 0xE7EB90),
                border: Color(rgb: 0x632B30, opacity: 0.10),
                primary: Color(rgb: 0x2274A5),
                onPrimary: .white,
                secondary: Color(rgb: 0xE6AF2E),
                textPrimary: Color(rgb: 0x632B30),
                textSecondary: Color(rgb: 0x632B30, opacity: 0.65),
                streak: Color(rgb: 0xE6AF2E),
                record: Color(rgb: 0xC9971C),
                booster: Color(rgb: 0x2274A5),
                token: Color(rgb: 0x3A8FBF),
                success: Color(rgb: 0x4C8A2A),
                danger: Color(rgb: 0x9B2C2C),
                emptyPixel: Color(rgb: 0xE7EB90),
                colorScheme: .light
            )
        case .braise:
            return ThemePalette(
                background: Color(rgb: 0x001427),
                surface: Color(rgb: 0x0A2238),
                surfaceHighlight: Color(rgb: 0x12304C),
                border: Color.white.opacity(0.06),
                primary: Color(rgb: 0xBF0603),
                onPrimary: .white,
                secondary: Color(rgb: 0x708D81),
                textPrimary: Color(rgb: 0xFFF6E0),
                textSecondary: Color(rgb: 0x9FB5AB),
                streak: Color(rgb: 0xE8553F),
                record: Color(rgb: 0xF4D58D),
                booster: Color(rgb: 0xF4D58D),
                token: Color(rgb: 0x8FB0A2),
                success: Color(rgb: 0x8FB0A2),
                danger: Color(rgb: 0xE8553F),
                emptyPixel: Color(rgb: 0x12304C),
                colorScheme: .dark
            )
        }
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
