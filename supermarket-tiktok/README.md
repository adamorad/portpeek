# Supermarket Deals TikTok Bot

Automated pipeline that compares weekly promotions across Israeli supermarket chains and renders TikTok-ready slideshow videos.

## Supported Chains

שופרסל, רמי לוי, יוחננוף, אושר עד, חצי חינם, טיב טעם, מחסני השוק, ויקטורי, קרפור

## How it works

1. **Scrape** — Downloads government-mandated XML promotion files from all chains
2. **Parse** — Extracts products on sale, joins with regular price data by barcode
3. **Match** — Groups same products across chains, assigns categories (dairy, meat, etc.)
4. **Generate** — Renders one MP4 per category as a 1080×1920 TikTok slideshow

## Setup

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
# Optional: place music.mp3 in assets/ for background audio
```

## Weekly Run

```bash
python3 scrape.py    # ~5–10 min — downloads this week's XML files
python3 parse.py     # ~1 min — extracts promotions
python3 match.py     # ~30 sec — groups by barcode, assigns categories
python3 generate.py  # ~2 min — renders MP4s

# Upload files from output/ to TikTok
```

## Import note

The PyPI package `il-supermarket-scraper` installs as `il_supermarket_scarper` (typo in upstream package). Always import from `il_supermarket_scarper`.

## Categories

- 🥛 מוצרי חלב
- 🍖 בשר ועוף
- 🥦 ירקות ופירות
- 🧃 שתייה
- 🍞 לחם ומאפים
- 🧴 ניקיון
- 🍿 חטיפים
- שונות (uncategorized)
