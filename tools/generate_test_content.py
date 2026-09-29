#!/usr/bin/env python3
"""
Génère du contenu de TEST pour PixelFocus (catalogue + œuvres pixel art).

- 1 daily (5x5) par jour, 1 weekly (7x7) par semaine ISO, 1 monthly (10x10) par mois
- Période: START..END (inclus)
- Déterministe (seed fixe): relancer le script produit les mêmes fichiers
- Les fichiers d'œuvres déjà présents ne sont PAS écrasés (œuvres faites à la main)

Usage:
    python3 tools/generate_test_content.py

Ce contenu est provisoire: il sera remplacé par le vrai contenu (étape 4, contenu téléchargé).
"""

import datetime as dt
import json
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RESOURCES = ROOT / "PixelFocus" / "Resources"
ARTWORKS = RESOURCES / "artworks"

START = dt.date(2026, 1, 1)
END = dt.date(2027, 3, 31)
SEED = 2026

# ---------------------------------------------------------------------------
# Motifs: '.' = fond (index 0), 'a'..'d' = couleurs 1..4 de la palette
# ---------------------------------------------------------------------------

DAILY_MOTIFS = [
    ("Cœur", [".a.a.", "abaaa", "aaaaa", ".aaa.", "..a.."]),
    ("Étoile", ["..a..", ".aba.", "abcba", ".aba.", "..a.."]),
    ("Soleil", ["a.a.a", ".bbb.", "abcba", ".bbb.", "a.a.a"]),
    ("Sapin", ["..a..", ".aaa.", "aaaaa", "..b..", "..b.."]),
    ("Maison", ["..a..", ".aaa.", "aaaaa", ".bcb.", ".bcb."]),
    ("Fleur", [".a.a.", "aabaa", ".a.a.", "..c..", ".cc.."]),
    ("Lune", [".aa..", "aa...", "aa...", "aa...", ".aa.."]),
    ("Nuage", [".....", ".aa..", "aaaa.", "bbbbb", "....."]),
    ("Goutte", ["..a..", ".aaa.", "aabaa", "aaaaa", ".aaa."]),
    ("Champignon", [".aaa.", "abaab", "aaaaa", ".cc..", ".cc.."]),
    ("Poisson", [".....", "a.aa.", "aaaba", "a.aa.", "....."]),
    ("Montagne", [".....", "..a..", ".aba.", "abbba", "ccccc"]),
    ("Cerises", ["...c.", "..c.c", ".c..c", "aa.aa", "aa.aa"]),
    ("Feuille", ["...aa", "..aba", ".aba.", "aba..", "c...."]),
    ("Éclair", ["..aa.", ".aa..", "aaaa.", "..aa.", ".a..."]),
]

WEEKLY_MOTIFS = [
    ("Voilier", ["...a...", "..aa...", ".aaa...", "...c...", "bbbbbbb", ".bbbbb.", "ddddddd"]),
    ("Fusée", ["...a...", "..aba..", "..aaa..", "..aba..", ".aaaaa.", ".c.a.c.", "..d.d.."]),
    ("Papillon", ["a.....a", "aa...aa", "abacaba", ".aacaa.", "abacaba", "aa...aa", "a.....a"]),
    ("Cactus", ["...a...", ".a.a...", ".aaa.a.", "...aaa.", "...a...", "..bbb..", "..bbb.."]),
    ("Phare", ["...c...", "..aaa..", "..bbb..", "..aaa..", "..bbb..", ".aaaaa.", "ddddddd"]),
    ("Tasse", [".......", ".c.c...", ".......", "aaaaa..", "abbbaa.", "abbba.a", ".aaa..."]),
]

PALETTES = [
    ["#1A1A2E", "#E94560", "#F5A3B5", "#FFD166", "#06D6A0"],
    ["#0F172A", "#38BDF8", "#0EA5E9", "#FDE68A", "#F97316"],
    ["#1B1B1B", "#A78BFA", "#7C3AED", "#F0ABFC", "#FACC15"],
    ["#FFF8E7", "#2274A5", "#E6AF2E", "#632B30", "#FADF63"],
    ["#001427", "#BF0603", "#F4D58D", "#708D81", "#8D0801"],
    ["#F1F5F9", "#16A34A", "#86EFAC", "#78350F", "#FDE047"],
    ["#1E293B", "#F472B6", "#FB7185", "#34D399", "#FBBF24"],
    ["#FEF3C7", "#EA580C", "#B91C1C", "#65A30D", "#1D4ED8"],
]

MONTH_NAMES = [
    "janvier", "février", "mars", "avril", "mai", "juin",
    "juillet", "août", "septembre", "octobre", "novembre", "décembre",
]

# Palettes de paysage mensuelles: ciel haut, ciel bas, soleil, collines, eau
LANDSCAPE_PALETTES = [
    ["#1E3A5F", "#A7C7E7", "#F8FAFC", "#E2E8F0", "#64748B"],  # janvier
    ["#312E81", "#C4B5FD", "#FDE68A", "#CBD5E1", "#475569"],  # février
    ["#0EA5E9", "#BAE6FD", "#FDE047", "#4ADE80", "#0369A1"],  # mars
    ["#38BDF8", "#FBCFE8", "#FEF08A", "#22C55E", "#0284C7"],  # avril
    ["#0284C7", "#E0F2FE", "#FACC15", "#16A34A", "#0369A1"],  # mai
    ["#0369A1", "#FEF3C7", "#F59E0B", "#65A30D", "#075985"],  # juin
    ["#1D4ED8", "#FDE68A", "#F97316", "#EAB308", "#1E40AF"],  # juillet
    ["#7C3AED", "#FDBA74", "#FB923C", "#A16207", "#4C1D95"],  # août
    ["#4338CA", "#FCA5A5", "#F97316", "#B45309", "#312E81"],  # septembre
    ["#1E1B4B", "#F9A8D4", "#FDBA74", "#9A3412", "#3730A3"],  # octobre
    ["#1F2937", "#94A3B8", "#FDE68A", "#57534E", "#334155"],  # novembre
    ["#0F172A", "#475569", "#F1F5F9", "#E2E8F0", "#1E293B"],  # décembre
]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def motif_to_pixels(rows):
    mapping = {".": 0, "a": 1, "b": 2, "c": 3, "d": 4}
    return [mapping[ch] for row in rows for ch in row]


def reveal_sequence(size, rng):
    order = list(range(size))
    rng.shuffle(order)
    return order


def artwork(artwork_id, title, mode, width, height, palette, pixels, rng):
    assert len(pixels) == width * height, artwork_id
    return {
        "artworkId": artwork_id,
        "title": title,
        "mode": mode,
        "grid": {"width": width, "height": height},
        "reveal": {"order": "custom", "indexSequence": reveal_sequence(width * height, rng)},
        "palette": palette,
        "pixels": {"encoding": "index", "data": pixels},
    }


def landscape_pixels(rng):
    """Paysage 10x10: ciel en dégradé, soleil, collines, eau."""
    w = h = 10
    sun_x = rng.randint(2, 7)
    sun_y = rng.randint(1, 3)
    hill_base = rng.randint(5, 6)
    phase = rng.random() * 6.28
    pixels = []
    import math
    for y in range(h):
        for x in range(w):
            hill_top = hill_base + round(math.sin(x * 0.8 + phase))
            if y >= 8:
                color = 5  # eau
            elif y >= hill_top:
                color = 4  # collines
            elif (x - sun_x) ** 2 + (y - sun_y) ** 2 <= 1:
                color = 3  # soleil
            elif y <= 2:
                color = 1  # ciel haut
            else:
                color = 2  # ciel bas
            pixels.append(color)
    return pixels


def write_artwork(data):
    path = ARTWORKS / f"{data['artworkId']}.json"
    if path.exists():
        return False  # ne jamais écraser une œuvre existante
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return True


# ---------------------------------------------------------------------------
# Génération
# ---------------------------------------------------------------------------

def main():
    rng = random.Random(SEED)
    ARTWORKS.mkdir(parents=True, exist_ok=True)

    daily_entries, weekly_entries, monthly_entries = [], [], []
    created = 0

    # Daily
    day = START
    index = 0
    while day <= END:
        artwork_id = f"daily_{day.year:04d}_{day.month:02d}_{day.day:02d}"
        name, rows = DAILY_MOTIFS[index % len(DAILY_MOTIFS)]
        palette = PALETTES[(index // len(DAILY_MOTIFS) + index) % len(PALETTES)]
        title = f"{name} du {day.day} {MONTH_NAMES[day.month - 1]}"
        created += write_artwork(artwork(artwork_id, title, "daily", 5, 5, palette, motif_to_pixels(rows), rng))
        daily_entries.append({"date": day.isoformat(), "artworkId": artwork_id})
        day += dt.timedelta(days=1)
        index += 1

    # Weekly (semaines ISO dont le lundi tombe dans la période, + la semaine contenant START)
    monday = START - dt.timedelta(days=START.weekday())
    index = 0
    while monday <= END:
        iso_year, iso_week, _ = monday.isocalendar()
        artwork_id = f"weekly_{iso_year:04d}_w{iso_week:02d}"
        name, rows = WEEKLY_MOTIFS[index % len(WEEKLY_MOTIFS)]
        palette = PALETTES[(index * 3) % len(PALETTES)]
        title = f"{name} — semaine {iso_week}"
        created += write_artwork(artwork(artwork_id, title, "weekly", 7, 7, palette, motif_to_pixels(rows), rng))
        weekly_entries.append({
            "weekId": f"{iso_year:04d}-W{iso_week:02d}",
            "artworkId": artwork_id,
            "startDate": monday.isoformat(),
            "endDate": (monday + dt.timedelta(days=6)).isoformat(),
        })
        monday += dt.timedelta(days=7)
        index += 1

    # Monthly
    year, month = START.year, START.month
    while (year, month) <= (END.year, END.month):
        artwork_id = f"monthly_{year:04d}_{month:02d}_main"
        palette = ["#000000"] + LANDSCAPE_PALETTES[month - 1]
        title = f"Paysage de {MONTH_NAMES[month - 1]} {year}"
        created += write_artwork(artwork(artwork_id, title, "monthly", 10, 10, palette, landscape_pixels(rng), rng))
        monthly_entries.append({"month": f"{year:04d}-{month:02d}", "artworkId": artwork_id, "isPremium": True})
        month += 1
        if month > 12:
            year, month = year + 1, 1

    catalog = {
        "contentVersion": 2,
        "month": f"{START.isoformat()}..{END.isoformat()}",
        "daily": daily_entries,
        "weekly": weekly_entries,
        "monthly": monthly_entries,
    }
    (RESOURCES / "catalog.json").write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(f"catalog: {len(daily_entries)} daily, {len(weekly_entries)} weekly, {len(monthly_entries)} monthly")
    print(f"artworks créés: {created} (existants conservés)")


if __name__ == "__main__":
    main()
