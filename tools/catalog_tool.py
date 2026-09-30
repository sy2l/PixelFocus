#!/usr/bin/env python3
"""
Vérifie le catalogue et les œuvres, et génère un aperçu HTML pour les relire avant publication.

Usage:
    python3 tools/catalog_tool.py check                 # vérifications (code de sortie 1 si erreur)
    python3 tools/catalog_tool.py preview [--month 2026-10] [--out build/catalog-preview.html]

Vérifications:
- chaque œuvre du catalogue existe et est valide (taille, palette, ordre de révélation complet)
- identifiants uniques, dates cohérentes (1 daily par jour, semaines lundi -> dimanche)
- couleurs au format #RRGGBB
"""

import argparse
import datetime as dt
import html
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RESOURCES = ROOT / "PixelFocus" / "Resources"
ARTWORKS = RESOURCES / "artworks"
HEX = re.compile(r"^#[0-9A-Fa-f]{6}$")


def load_catalog():
    return json.loads((RESOURCES / "catalog.json").read_text(encoding="utf-8"))


def load_artwork(artwork_id):
    path = ARTWORKS / f"{artwork_id}.json"
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def validate_artwork(artwork_id, data):
    errors = []
    if data.get("artworkId") != artwork_id:
        errors.append("artworkId différent du nom de fichier")
    width, height = data["grid"]["width"], data["grid"]["height"]
    size = width * height
    pixels = data["pixels"]["data"]
    palette = data["palette"]
    sequence = data["reveal"]["indexSequence"]
    if len(pixels) != size:
        errors.append(f"{len(pixels)} pixels pour une grille de {size}")
    if sorted(sequence) != list(range(size)):
        errors.append("ordre de révélation incomplet ou en double")
    if any(not HEX.match(color) for color in palette):
        errors.append("couleur invalide dans la palette")
    if pixels and (max(pixels) >= len(palette) or min(pixels) < 0):
        errors.append("index de couleur hors palette")
    return errors


def check():
    catalog = load_catalog()
    problems = 0
    seen = set()

    entries = [(e["artworkId"], "daily") for e in catalog["daily"]]
    entries += [(e["artworkId"], "weekly") for e in catalog["weekly"]]
    entries += [(e["artworkId"], "monthly") for e in catalog["monthly"]]

    for artwork_id, mode in entries:
        if artwork_id in seen:
            print(f"✗ {artwork_id}: présent plusieurs fois dans le catalogue")
            problems += 1
        seen.add(artwork_id)
        data = load_artwork(artwork_id)
        if data is None:
            print(f"✗ {artwork_id}: fichier manquant")
            problems += 1
            continue
        for error in validate_artwork(artwork_id, data):
            is_warning = error.startswith("avertissement")
            print(f"{'!' if is_warning else '✗'} {artwork_id}: {error}")
            problems += 0 if is_warning else 1
        if data.get("mode") != mode:
            print(f"✗ {artwork_id}: mode {data.get('mode')} au lieu de {mode}")
            problems += 1

    dates = [e["date"] for e in catalog["daily"]]
    if len(dates) != len(set(dates)):
        print("✗ plusieurs daily le même jour")
        problems += 1
    for week in catalog["weekly"]:
        start = dt.date.fromisoformat(week["startDate"])
        end = dt.date.fromisoformat(week["endDate"])
        if start.weekday() != 0 or (end - start).days != 6:
            print(f"✗ {week['artworkId']}: une semaine doit aller du lundi au dimanche")
            problems += 1

    orphans = sorted(p.stem for p in ARTWORKS.glob("*.json") if p.stem not in seen)
    print(f"\n{len(entries)} œuvres au catalogue, {len(orphans)} fichier(s) hors catalogue (packs, brouillons…)")
    print("✓ Catalogue valide" if problems == 0 else f"✗ {problems} problème(s)")
    return problems == 0


def artwork_svg(data, cell=10):
    width, height = data["grid"]["width"], data["grid"]["height"]
    palette, pixels = data["palette"], data["pixels"]["data"]
    rects = []
    for index, color_index in enumerate(pixels):
        x, y = index % width, index // width
        rects.append(f'<rect x="{x * cell}" y="{y * cell}" width="{cell - 1}" height="{cell - 1}" fill="{palette[color_index]}"/>')
    return f'<svg viewBox="0 0 {width * cell} {height * cell}" xmlns="http://www.w3.org/2000/svg">{"".join(rects)}</svg>'


def preview(month, out):
    catalog = load_catalog()
    sections = []
    groups = [
        ("Images du mois", [e["artworkId"] for e in catalog["monthly"] if not month or e["month"] == month]),
        ("Images de la semaine", [e["artworkId"] for e in catalog["weekly"] if not month or e["startDate"][:7] == month or e["endDate"][:7] == month]),
        ("Images du jour", [e["artworkId"] for e in catalog["daily"] if not month or e["date"][:7] == month]),
    ]
    for title, ids in groups:
        cards = []
        for artwork_id in ids:
            data = load_artwork(artwork_id)
            if data is None:
                cards.append(f'<figure class="missing"><figcaption>{artwork_id}<br>manquant</figcaption></figure>')
                continue
            errors = [e for e in validate_artwork(artwork_id, data) if not e.startswith("avertissement")]
            cards.append(
                f'<figure class="{"error" if errors else ""}">{artwork_svg(data)}'
                f'<figcaption><strong>{html.escape(data["title"])}</strong><br>{artwork_id}'
                f'{"<br>" + html.escape("; ".join(errors)) if errors else ""}</figcaption></figure>'
            )
        sections.append(f"<h2>{title} ({len(ids)})</h2><div class=grid>{''.join(cards)}</div>")

    page = f"""<!doctype html><html lang="fr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Aperçu du catalogue PixelFocus</title>
<style>
:root {{ --bg:#0B0B0F; --card:#1C1C22; --text:#fff; --muted:#9CA3AF; --danger:#F87171; }}
body {{ margin:0; padding:16px; background:var(--bg); color:var(--text); font-family:-apple-system,system-ui,sans-serif; }}
h1 {{ font-size:28px; }} h2 {{ font-size:18px; margin-top:32px; }}
.grid {{ display:grid; grid-template-columns:repeat(auto-fill,minmax(120px,1fr)); gap:12px; }}
figure {{ margin:0; background:var(--card); border-radius:16px; padding:10px; }}
figure svg {{ width:100%; height:auto; display:block; border-radius:6px; image-rendering:pixelated; }}
figcaption {{ font-size:11px; color:var(--muted); margin-top:6px; word-break:break-all; }}
figcaption strong {{ color:var(--text); font-size:12px; }}
.error, .missing {{ outline:2px solid var(--danger); }}
</style></head><body>
<h1>Aperçu du catalogue{" — " + html.escape(month) if month else ""}</h1>
<p style="color:var(--muted)">À relire avant publication : lisibilité, neutralité (pas de drapeau, pas d'édifice religieux, pas de politique).</p>
{''.join(sections)}
</body></html>"""
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(page, encoding="utf-8")
    print(f"Aperçu écrit: {out}")


def main():
    parser = argparse.ArgumentParser(description="Outils du catalogue PixelFocus")
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("check")
    preview_parser = sub.add_parser("preview")
    preview_parser.add_argument("--month", help="Limiter à un mois AAAA-MM")
    preview_parser.add_argument("--out", type=Path, default=ROOT / "build" / "catalog-preview.html")
    args = parser.parse_args()

    if args.command == "check":
        sys.exit(0 if check() else 1)
    preview(args.month, args.out)


if __name__ == "__main__":
    main()
