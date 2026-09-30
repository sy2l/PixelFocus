#!/usr/bin/env python3
"""
Génère le code Swift des thèmes à partir de design/design-tokens.json (source unique).

Usage:
    python3 tools/generate_theme.py

Sortie:
    PixelFocus/UI/Theme/ThemeTokens.generated.swift  (ne pas modifier à la main)

Le même fichier JSON servira à générer l'équivalent Kotlin pour Android.
"""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOKENS = ROOT / "design" / "design-tokens.json"
OUTPUT = ROOT / "PixelFocus" / "UI" / "Theme" / "ThemeTokens.generated.swift"

COLOR_KEYS = [
    "background", "surface", "surfaceHighlight", "border", "primary", "onPrimary", "secondary",
    "textPrimary", "textSecondary", "streak", "record", "booster", "token", "success", "danger", "emptyPixel",
]


def swift_color(value: str) -> str:
    hex_value = value.lstrip("#").upper()
    if len(hex_value) == 6:
        return f"Color(rgb: 0x{hex_value})"
    if len(hex_value) == 8:
        opacity = int(hex_value[6:], 16) / 255
        return f"Color(rgb: 0x{hex_value[:6]}, opacity: {opacity:.3f})"
    raise ValueError(f"Couleur invalide: {value}")


def main():
    tokens = json.loads(TOKENS.read_text(encoding="utf-8"))
    lines = [
        "// FICHIER GÉNÉRÉ par tools/generate_theme.py depuis design/design-tokens.json.",
        "// Ne pas modifier à la main: modifier le JSON puis relancer le script.",
        "",
        "import SwiftUI",
        "",
        "enum ThemeTokens {",
        "",
        "    // MARK: - Palettes",
        "",
        "    static func palette(for theme: AppTheme) -> ThemePalette {",
        "        switch theme {",
    ]

    for key, theme in tokens["themes"].items():
        colors = theme["colors"]
        missing = [k for k in COLOR_KEYS if k not in colors]
        if missing:
            raise ValueError(f"Thème {key}: couleurs manquantes {missing}")
        lines.append(f"        case .{key}:")
        lines.append("            return ThemePalette(")
        for color_key in COLOR_KEYS:
            lines.append(f"                {color_key}: {swift_color(colors[color_key])},")
        lines.append(f"                colorScheme: .{theme['scheme']}")
        lines.append("            )")

    lines += ["        }", "    }", ""]

    lines += ["    // MARK: - Métadonnées", "", "    static func name(for theme: AppTheme) -> String {", "        switch theme {"]
    for key, theme in tokens["themes"].items():
        lines.append(f"        case .{key}: return \"{theme['name']}\"")
    lines += ["        }", "    }", ""]

    lines += ["    static func subtitle(for theme: AppTheme) -> String {", "        switch theme {"]
    for key, theme in tokens["themes"].items():
        lines.append(f"        case .{key}: return \"{theme['subtitle']}\"")
    lines += ["        }", "    }", ""]

    lines += ["    static func requiresPremium(_ theme: AppTheme) -> Bool {", "        switch theme {"]
    for key, theme in tokens["themes"].items():
        lines.append(f"        case .{key}: return {'true' if theme['premium'] else 'false'}")
    lines += ["        }", "    }", ""]

    for group, type_name in (("radius", "Radius"), ("spacing", "Spacing"), ("sizes", "Size")):
        lines.append(f"    // MARK: - {type_name}")
        lines.append("")
        lines.append(f"    enum {type_name} {{")
        for name, value in tokens[group].items():
            lines.append(f"        static let {name}: CGFloat = {value}")
        lines.append("    }")
        lines.append("")

    lines.append("}")
    OUTPUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Écrit: {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
