# Supermarket Deals TikTok Bot — Spec

**Date:** 2026-06-12  
**Status:** Approved

## Overview

An automated pipeline that fetches weekly promotion data from Israeli supermarket chains, compares prices by category across chains, and generates a TikTok-ready slideshow video. The user manually uploads the final MP4 to TikTok.

## Supported Chains

יוחננוף, אושר עד, חצי חינם, רמי לוי, שופרסל, טיב טעם, מחסני השוק, ויקטורי, קרפור

All chains publish government-mandated XML price and promotion files. Accessed via the `il-supermarket-scraper` Python library.

## Architecture

Four independent scripts, each producing output consumed by the next:

```
scrape.py → parse.py → match.py → generate.py → output/video_YYYY-MM-DD.mp4
```

### 1. `scrape.py` — Data Collection

- Uses `il-supermarket-scraper` (`pip install il-supermarket-scraper`) to download promotion XML files from all supported chains
- Downloads only promotion files (not full price catalog) to keep volume manageable
- Output: `data/raw/<chain>_promo_<date>.xml`
- Runtime: ~5 minutes

### 2. `parse.py` — Extraction

- Parses XML promotion files using `il-supermarket-parsers`
- Extracts: barcode, product name, regular price, sale price, sale start/end dates
- Filters to active promotions only (current week)
- Output: `data/promotions.json` — flat list of all active deals across all chains

### 3. `match.py` — Cross-Chain Comparison

**Primary matching: barcode**
- Products sharing the same barcode across chains are the same product
- Covers ~95% of cases

**Fallback: AI categorization (Claude Haiku)**
- For products with no barcode match, uses the product name to assign a category
- Categories: מוצרי חלב, בשר ועוף, ירקות ופירות, שתייה, לחם ומאפים, ניקיון, שונות

Output: `data/comparison.json`

```json
{
  "generated_at": "2026-06-12",
  "categories": [
    {
      "name": "מוצרי חלב",
      "products": [
        {
          "barcode": "7290000066646",
          "name": "חלב תנובה 3% 1L",
          "deals": {
            "שופרסל": { "regular_price": 5.90, "sale_price": 4.90 },
            "רמי לוי": { "regular_price": 4.50, "sale_price": null },
            "יוחננוף": { "regular_price": 5.50, "sale_price": 4.80 }
          }
        }
      ]
    }
  ]
}
```

### 4. `generate.py` — Video Generation

- Reads `data/comparison.json`
- Generates one MP4 per category (or one combined video — configurable)
- Output: `output/video_<category>_<date>.mp4`

**Video specs:**
- Resolution: 1080×1920 (TikTok vertical)
- Frame duration: 2.5 seconds per slide
- Transition: fade
- Libraries: `Pillow` (frame rendering) + `moviepy` (assembly + audio)
- Font: Noto Sans Hebrew
- Background music: local MP3 file at `assets/music.mp3`

**Slide structure:**
1. Opening slide: category name + date
2. One slide per product: product name, price per chain, cheapest chain highlighted with 🏆
3. Closing slide: call to follow

**Visual style:**
- Dark background (#1a1a1a)
- White text
- Green accent (#00c853) for cheapest chain
- Red strikethrough on original price when on sale

## File Structure

```
supermarket-tiktok/
├── scrape.py
├── parse.py
├── match.py
├── generate.py
├── requirements.txt
├── assets/
│   └── music.mp3          # user-provided
├── data/
│   ├── raw/               # downloaded XML files
│   ├── promotions.json    # parsed deals
│   └── comparison.json    # cross-chain comparison
└── output/                # generated MP4 files
```

## Weekly Workflow

```bash
python scrape.py     # download this week's XMLs (~5 min)
python parse.py      # extract active promotions (~30 sec)
python match.py      # build comparison (~30 sec)
python generate.py   # render video(s) (~10 sec)
# → upload output/*.mp4 to TikTok manually
```

## Dependencies

```
il-supermarket-scraper
il-supermarket-parsers
Pillow
moviepy
anthropic              # for AI categorization fallback (Claude Haiku)
```

## Out of Scope

- Automatic TikTok upload
- Price history tracking / trend analysis
- Web dashboard
- Push notifications
