// FICHIER GÉNÉRÉ par tools/generate_theme.py depuis design/design-tokens.json.
// Ne pas modifier à la main: modifier le JSON puis relancer le script.

import SwiftUI

enum ThemeTokens {

    // MARK: - Palettes

    static func palette(for theme: AppTheme) -> ThemePalette {
        switch theme {
        case .minuit:
            return ThemePalette(
                background: Color(rgb: 0x0B0B0F),
                surface: Color(rgb: 0x1C1C22),
                surfaceHighlight: Color(rgb: 0x2A2A33),
                border: Color(rgb: 0xFFFFFF, opacity: 0.059),
                primary: Color(rgb: 0x7C3AED),
                onPrimary: Color(rgb: 0xFFFFFF),
                secondary: Color(rgb: 0xC4B5FD),
                textPrimary: Color(rgb: 0xFFFFFF),
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
                border: Color(rgb: 0x632B30, opacity: 0.102),
                primary: Color(rgb: 0x2274A5),
                onPrimary: Color(rgb: 0xFFFFFF),
                secondary: Color(rgb: 0xE6AF2E),
                textPrimary: Color(rgb: 0x632B30),
                textSecondary: Color(rgb: 0x632B30, opacity: 0.651),
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
                border: Color(rgb: 0xFFFFFF, opacity: 0.059),
                primary: Color(rgb: 0xBF0603),
                onPrimary: Color(rgb: 0xFFFFFF),
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

    // MARK: - Métadonnées

    static func name(for theme: AppTheme) -> String {
        switch theme {
        case .minuit: return "Minuit"
        case .soleil: return "Soleil"
        case .braise: return "Braise"
        }
    }

    static func subtitle(for theme: AppTheme) -> String {
        switch theme {
        case .minuit: return "Sombre"
        case .soleil: return "Clair"
        case .braise: return "Bleu nuit"
        }
    }

    static func requiresPremium(_ theme: AppTheme) -> Bool {
        switch theme {
        case .minuit: return false
        case .soleil: return true
        case .braise: return true
        }
    }

    // MARK: - Radius

    enum Radius {
        static let card: CGFloat = 22
        static let button: CGFloat = 18
        static let control: CGFloat = 14
        static let thumbnail: CGFloat = 12
        static let dayCell: CGFloat = 8
    }

    // MARK: - Spacing

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let s: CGFloat = 12
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
    }

    // MARK: - Size

    enum Size {
        static let buttonHeight: CGFloat = 52
        static let secondaryButtonHeight: CGFloat = 44
        static let minTouchTarget: CGFloat = 44
        static let progressBarHeight: CGFloat = 8
    }

}
