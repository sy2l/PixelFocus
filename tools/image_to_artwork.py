#!/usr/bin/env python3
"""
Convertit une image (PNG, JPG…) en œuvre PixelFocus (JSON).

- Réduit l'image à la grille voulue (5x5 daily, 7x7 weekly, 10x10 monthly, ou taille libre)
- Limite le nombre de couleurs (palette optimisée)
- Choisit un ordre de révélation (centre -> bords par défaut)
- Affiche un aperçu dans le terminal et vérifie la lisibilité

Prérequis: pip install pillow

Exemples:
    python3 tools/image_to_artwork.py tour.png --id pack_capitales_2026_paris --title "Paris" --mode pack --size 12x12 --colors 8
    python3 tools/image_to_artwork.py coeur.png --id daily_2027_02_14 --title "Cœur" --mode daily
    python3 tools/image_to_artwork.py paysage.jpg --id monthly_2027_04_main --title "Printemps" --mode monthly --reveal spiral

Conseil: partir d'une image simple, cadrée serrée, avec des aplats de couleur (logo, illustration, pixel art existant).
"""

import argparse
import json
import math
import random
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    sys.exit("Pillow est requis: pip install pillow")

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_OUT = ROOT / "PixelFocus" / "Resources" / "artworks"

DEFAULT_SIZES = {"daily": (5, 5), "weekly": (7, 7), "monthly": (10, 10), "pack": (10, 10)}
DEFAULT_COLORS = {"daily": 4, "weekly": 5, "monthly": 8, "pack": 8}


# ---------------------------------------------------------------------------
# Ordres de révélation
# ---------------------------------------------------------------------------

def reveal_order(width, height, mode, seed):
    cells = list(range(width * height))
    rng = random.Random(seed)
    cx, cy = (width - 1) / 2, (height - 1) / 2

    if mode == "random":
        rng.shuffle(cells)
        return cells
    if mode == "rows":
        return cells
    if mode == "center":
        # Du centre vers les bords, avec un léger désordre pour un effet vivant
        return sorted(cells, key=lambda i: math.hypot(i % width - cx, i // width - cy) + rng.random() * 0.8)
    if mode == "spiral":
        order, seen = [], set()
        x, y, dx, dy = 0, 0, 1, 0
        for _ in range(width * height):
            order.append(y * width + x)
            seen.add((x, y))
            nx, ny = x + dx, y + dy
            if not (0 <= nx < width and 0 <= ny < height) or (nx, ny) in seen:
                dx, dy = -dy, dx
                nx, ny = x + dx, y + dy
            x, y = nx, ny
        return order
    raise ValueError(f"Ordre inconnu: {mode}")


# ---------------------------------------------------------------------------
# Conversion
# ---------------------------------------------------------------------------

def convert(path, width, height, colors, background):
    image = Image.open(path).convert("RGBA")

    # Transparence -> couleur de fond
    base = Image.new("RGBA", image.size, background + (255,))
    base.alpha_composite(image)
    image = base.convert("RGB")

    # Réduction: BOX moyenne les pixels (net pour les petites grilles)
    small = image.resize((width, height), Image.Resampling.BOX)
    quantized = small.quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)

    raw_palette = quantized.getpalette()[: colors * 3]
    flatten = getattr(quantized, "get_flattened_data", None) or quantized.getdata
    indices = list(flatten())

    # Palette triée par fréquence, couleurs inutilisées retirées
    counts = {}
    for index in indices:
        counts[index] = counts.get(index, 0) + 1
    ordered = sorted(counts, key=lambda i: -counts[i])
    remap = {old: new for new, old in enumerate(ordered)}
    palette = ["#%02X%02X%02X" % tuple(raw_palette[i * 3:i * 3 + 3]) for i in ordered]
    pixels = [remap[i] for i in indices]
    return palette, pixels, counts


def terminal_preview(palette, pixels, width):
    lines = []
    for row in range(len(pixels) // width):
        line = ""
        for column in range(width):
            hex_color = palette[pixels[row * width + column]].lstrip("#")
            r, g, b = (int(hex_color[i:i + 2], 16) for i in (0, 2, 4))
            line += f"\x1b[48;2;{r};{g};{b}m  \x1b[0m"
        lines.append(line)
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Image -> œuvre PixelFocus")
    parser.add_argument("image", type=Path)
    parser.add_argument("--id", required=True, help="Identifiant (ex: daily_2027_02_14, pack_capitales_2026_paris)")
    parser.add_argument("--title", required=True)
    parser.add_argument("--mode", choices=["daily", "weekly", "monthly", "pack"], required=True)
    parser.add_argument("--size", help="Grille LxH (défaut: 5x5 daily, 7x7 weekly, 10x10 monthly/pack)")
    parser.add_argument("--colors", type=int, help="Nombre de couleurs (défaut selon le mode)")
    parser.add_argument("--reveal", choices=["center", "random", "spiral", "rows"], default="center")
    parser.add_argument("--background", default="#FFFFFF", help="Couleur de fond pour les zones transparentes")
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--force", action="store_true", help="Écraser une œuvre existante")
    args = parser.parse_args()

    if not args.id.replace("_", "").isalnum() or args.id.lower() != args.id:
        sys.exit("L'identifiant doit être en minuscules, chiffres et _ uniquement.")

    width, height = DEFAULT_SIZES[args.mode]
    if args.size:
        width, height = (int(v) for v in args.size.lower().split("x"))
    if not (3 <= width <= 32 and 3 <= height <= 32):
        sys.exit("Taille de grille entre 3 et 32.")
    colors = args.colors or DEFAULT_COLORS[args.mode]
    if not 2 <= colors <= 16:
        sys.exit("Entre 2 et 16 couleurs.")
    background = tuple(int(args.background.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4))

    palette, pixels, counts = convert(args.image, width, height, colors, background)

    artwork = {
        "artworkId": args.id,
        "title": args.title,
        "mode": "monthly" if args.mode == "monthly" else args.mode,
        "grid": {"width": width, "height": height},
        "reveal": {"order": args.reveal, "indexSequence": reveal_order(width, height, args.reveal, args.id)},
        "palette": palette,
        "pixels": {"encoding": "index", "data": pixels},
    }

    print(terminal_preview(palette, pixels, width))
    print(f"\n{args.title} — {width}x{height}, {len(palette)} couleur(s), révélation « {args.reveal} »")

    # Avertissements de lisibilité
    dominant = max(counts.values()) / len(pixels)
    if len(palette) < 2:
        print("⚠️  Une seule couleur: l'image ne sera pas lisible.")
    if dominant > 0.8:
        print(f"⚠️  Une couleur occupe {dominant:.0%} de l'image: recadrer plus serré ?")

    out_path = args.out / f"{args.id}.json"
    if out_path.exists() and not args.force:
        sys.exit(f"{out_path} existe déjà (utiliser --force pour écraser).")
    args.out.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(artwork, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Écrit: {out_path}")
    print("Pense à l'ajouter au catalogue, puis: python3 tools/catalog_tool.py check")


if __name__ == "__main__":
    main()
