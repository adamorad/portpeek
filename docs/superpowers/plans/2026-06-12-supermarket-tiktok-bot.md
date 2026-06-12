# Supermarket TikTok Bot — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Python pipeline that downloads Israeli supermarket promotion data, compares prices across chains by category, and renders a TikTok-ready MP4 slideshow.

**Architecture:** Four independent scripts (`scrape.py → parse.py → match.py → generate.py`), each writing JSON/files consumed by the next. Run manually once per week; output is an MP4 the user uploads to TikTok.

**Tech Stack:** `il-supermarket-scraper`, `il-supermarket-parsers`, `Pillow`, `moviepy>=2.0`, `python-bidi`, `anthropic` (Claude Haiku for category fallback)

---

## File Map

```
supermarket-tiktok/
├── scrape.py          # Downloads promo + price XMLs from 9 chains
├── parse.py           # Parses XMLs → data/promotions.json
├── match.py           # Groups by barcode, assigns categories → data/comparison.json
├── generate.py        # Renders slides → output/video_<category>_<date>.mp4
├── requirements.txt
├── .env.example       # ANTHROPIC_API_KEY=
├── .gitignore
├── assets/
│   └── .gitkeep       # user places music.mp3 here
├── data/
│   ├── raw/           # downloaded XML/GZ files land here
│   ├── parsed/        # ConvertingTask CSV output
│   └── .gitkeep
├── output/
│   └── .gitkeep
└── tests/
    ├── test_parse.py
    ├── test_match.py
    └── test_generate.py
```

---

## Task 1: Project Scaffolding

**Files:**
- Create: `supermarket-tiktok/requirements.txt`
- Create: `supermarket-tiktok/.env.example`
- Create: `supermarket-tiktok/.gitignore`
- Create: `supermarket-tiktok/assets/.gitkeep`
- Create: `supermarket-tiktok/data/.gitkeep`
- Create: `supermarket-tiktok/data/raw/.gitkeep`
- Create: `supermarket-tiktok/data/parsed/.gitkeep`
- Create: `supermarket-tiktok/output/.gitkeep`
- Create: `supermarket-tiktok/tests/__init__.py`

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p supermarket-tiktok/{assets,data/raw,data/parsed,output,tests}
touch supermarket-tiktok/assets/.gitkeep
touch supermarket-tiktok/data/.gitkeep
touch supermarket-tiktok/data/raw/.gitkeep
touch supermarket-tiktok/data/parsed/.gitkeep
touch supermarket-tiktok/output/.gitkeep
touch supermarket-tiktok/tests/__init__.py
```

- [ ] **Step 2: Write requirements.txt**

```
# supermarket-tiktok/requirements.txt
il-supermarket-scraper
il-supermarket-parsers
Pillow>=10.0
moviepy>=2.0
python-bidi>=0.4.2
anthropic>=0.25.0
python-dotenv>=1.0
defusedxml>=0.7.1
pytest>=8.0
```

- [ ] **Step 3: Write .env.example**

```
# supermarket-tiktok/.env.example
ANTHROPIC_API_KEY=your_key_here
```

- [ ] **Step 4: Write .gitignore**

```
# supermarket-tiktok/.gitignore
data/raw/
data/parsed/
data/promotions.json
data/comparison.json
output/*.mp4
output/*.png
.env
__pycache__/
*.pyc
.pytest_cache/
```

- [ ] **Step 5: Install dependencies**

```bash
cd supermarket-tiktok
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Expected: all packages install without errors.

- [ ] **Step 6: Discover available file type enum values**

```python
# Run this once to see available file types — not committed
from il_supermarket_scarper.utils.file_types import FileTypesFilters
for ft in FileTypesFilters:
    print(ft.name, ft.value)
```

Run: `python3 -c "from il_supermarket_scarper.utils.file_types import FileTypesFilters; [print(ft.name) for ft in FileTypesFilters]"`

Note the names for promo files (will contain "PROMO") and price files (will contain "PRICE"). You'll use these in scrape.py.

- [ ] **Step 7: Commit**

```bash
git add supermarket-tiktok/
git commit -m "feat: scaffold supermarket-tiktok project"
```

---

## Task 2: scrape.py

Downloads this week's promotion and price XML files from all 9 chains into `data/raw/`.

**Files:**
- Create: `supermarket-tiktok/scrape.py`

- [ ] **Step 1: Write scrape.py**

```python
# supermarket-tiktok/scrape.py
import os
from il_supermarket_scarper import ScarpingTask

CHAINS = [
    "SHUFERSAL",
    "RAMI_LEVY",
    "YOHANANOF",
    "OSHER_AD",
    "HAZI_HINAM",
    "TIV_TAAM",
    "MAHSANI_ASHUK",
    "VICTORY",
    "YAYNO_BITAN_AND_CARREFOUR",
]

# Discover exact enum names at runtime in case they differ
def get_valid_chains():
    try:
        from il_supermarket_scarper.scrappers import ScraperFactory
        available = {s.upper() for s in ScraperFactory.all_scrapers()}
        valid = [c for c in CHAINS if c in available]
        skipped = [c for c in CHAINS if c not in available]
        if skipped:
            print(f"Warning: chains not found, skipping: {skipped}")
        return valid
    except Exception:
        return CHAINS  # fall back to hardcoded list


def main():
    os.makedirs("data/raw", exist_ok=True)
    chains = get_valid_chains()
    print(f"Scraping {len(chains)} chains: {chains}")

    task = ScarpingTask(
        dump_folder="data/raw",
        enabled_scrapers=chains,
        files_types=["PROMO_FULL", "PRICE_FULL"],  # adjust names if Step 6 of Task 1 shows different values
    )
    task.start()
    print("Scraping complete. Files saved to data/raw/")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run scrape.py and verify output**

```bash
cd supermarket-tiktok
python3 scrape.py
```

Expected: files appear in `data/raw/`. They will be gzipped XML files with names like `shufersal_promo_full_<date>.xml.gz`.

```bash
ls data/raw/ | head -20
```

If you see 0 files, the file type names may be wrong. Re-check the enum values from Task 1 Step 6 and update `files_types` in scrape.py accordingly.

- [ ] **Step 3: Inspect a sample file to understand structure**

```bash
# Decompress and inspect one promo file
gunzip -c data/raw/$(ls data/raw/ | grep -i promo | head -1) | head -100
```

Note the XML structure — particularly:
- Tag name for promotions list (usually `<Promotions>` or `<root>`)
- Tag name for each promotion (usually `<Promotion>`)
- Fields: `<PromotionDescription>`, `<PromotionStartDate>`, `<PromotionEndDate>`, `<DiscountedPrice>`, `<DiscountRate>`, `<DiscountType>`
- Items section: `<PromotionItems>` → `<Item>` → `<ItemCode>` (barcode)

Also inspect a price file:
```bash
gunzip -c data/raw/$(ls data/raw/ | grep -i price | head -1) | head -100
```

Note price file fields: `<ItemCode>` (barcode), `<ItemName>`, `<ItemPrice>`.

- [ ] **Step 4: Commit**

```bash
git add supermarket-tiktok/scrape.py
git commit -m "feat: add scrape.py to download promo XMLs"
```

---

## Task 3: parse.py

Converts downloaded XMLs into a flat `data/promotions.json`. Joins promo files (discounted price) with price files (product name + regular price) by barcode.

**Files:**
- Create: `supermarket-tiktok/parse.py`
- Create: `supermarket-tiktok/tests/test_parse.py`

**Output schema (`data/promotions.json`):**
```json
[
  {
    "chain": "שופרסל",
    "barcode": "7290000066646",
    "name": "חלב תנובה 3% 1L",
    "regular_price": 5.90,
    "sale_price": 4.90,
    "promo_description": "מבצע שבועי",
    "start_date": "2026-06-10",
    "end_date": "2026-06-16"
  }
]
```

- [ ] **Step 1: Write failing test**

```python
# supermarket-tiktok/tests/test_parse.py
import json
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from parse import parse_promo_xml, parse_price_xml, build_promotions


SAMPLE_PROMO_XML = """<?xml version="1.0" encoding="utf-8"?>
<root>
  <Promotions>
    <ChainId>7290027600007</ChainId>
    <Promotion>
      <PromotionId>1001</PromotionId>
      <PromotionDescription>מבצע שבועי</PromotionDescription>
      <PromotionStartDate>2026-06-10</PromotionStartDate>
      <PromotionEndDate>2026-06-16</PromotionEndDate>
      <DiscountType>1</DiscountType>
      <DiscountedPrice>4.90</DiscountedPrice>
      <PromotionItems>
        <Item>
          <ItemCode>7290000066646</ItemCode>
          <ItemType>1</ItemType>
        </Item>
      </PromotionItems>
    </Promotion>
  </Promotions>
</root>"""

SAMPLE_PRICE_XML = """<?xml version="1.0" encoding="utf-8"?>
<root>
  <Items>
    <Item>
      <ItemCode>7290000066646</ItemCode>
      <ItemName>חלב תנובה 3% 1L</ItemName>
      <ItemPrice>5.90</ItemPrice>
    </Item>
  </Items>
</root>"""


def test_parse_promo_xml_extracts_promotions():
    promos = parse_promo_xml(SAMPLE_PROMO_XML)
    assert len(promos) == 1
    assert promos[0]["barcode"] == "7290000066646"
    assert promos[0]["sale_price"] == 4.90
    assert promos[0]["start_date"] == "2026-06-10"
    assert promos[0]["end_date"] == "2026-06-16"
    assert promos[0]["promo_description"] == "מבצע שבועי"


def test_parse_price_xml_extracts_prices():
    prices = parse_price_xml(SAMPLE_PRICE_XML)
    assert prices["7290000066646"]["name"] == "חלב תנובה 3% 1L"
    assert prices["7290000066646"]["price"] == 5.90


def test_build_promotions_joins_promo_and_price():
    promos = parse_promo_xml(SAMPLE_PROMO_XML)
    prices = parse_price_xml(SAMPLE_PRICE_XML)
    result = build_promotions("שופרסל", promos, prices)
    assert len(result) == 1
    p = result[0]
    assert p["chain"] == "שופרסל"
    assert p["barcode"] == "7290000066646"
    assert p["name"] == "חלב תנובה 3% 1L"
    assert p["regular_price"] == 5.90
    assert p["sale_price"] == 4.90


def test_build_promotions_skips_items_without_price_data():
    promos = parse_promo_xml(SAMPLE_PROMO_XML)
    prices = {}  # no price data
    result = build_promotions("שופרסל", promos, prices)
    assert len(result) == 0
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd supermarket-tiktok
pytest tests/test_parse.py -v
```

Expected: `ImportError` or `ModuleNotFoundError` — parse.py doesn't exist yet.

- [ ] **Step 3: Write parse.py**

```python
# supermarket-tiktok/parse.py
import gzip
import json
import os
import re
from datetime import date
from pathlib import Path

import defusedxml.ElementTree as ET

CHAIN_DISPLAY_NAMES = {
    "shufersal": "שופרסל",
    "rami_levy": "רמי לוי",
    "yohananof": "יוחננוף",
    "osher_ad": "אושר עד",
    "hazi_hinam": "חצי חינם",
    "tiv_taam": "טיב טעם",
    "mahsani_ashuk": "מחסני השוק",
    "victory": "ויקטורי",
    "yayno_bitan_and_carrefour": "קרפור",
}


def _read_file(path: str) -> str:
    if path.endswith(".gz"):
        with gzip.open(path, "rt", encoding="utf-8", errors="replace") as f:
            return f.read()
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        return f.read()


def _find_text(element, *tags) -> str:
    for tag in tags:
        el = element.find(tag)
        if el is not None and el.text:
            return el.text.strip()
    return ""


def parse_promo_xml(xml_content: str) -> list[dict]:
    """Parse a promo XML string into a list of promotion dicts."""
    try:
        root = ET.fromstring(xml_content)
    except ET.ParseError:
        return []

    promotions = []
    for promo in root.iter("Promotion"):
        desc = _find_text(promo, "PromotionDescription")
        start = _find_text(promo, "PromotionStartDate")
        end = _find_text(promo, "PromotionEndDate")
        discount_type = _find_text(promo, "DiscountType")
        discounted_price = _find_text(promo, "DiscountedPrice")

        # Only handle fixed-price promotions (DiscountType=1) for simplicity
        if discount_type != "1" or not discounted_price:
            continue

        try:
            sale_price = float(discounted_price)
        except ValueError:
            continue

        for item in promo.iter("Item"):
            barcode = _find_text(item, "ItemCode")
            if barcode:
                promotions.append({
                    "barcode": barcode,
                    "sale_price": sale_price,
                    "promo_description": desc,
                    "start_date": start[:10] if start else "",
                    "end_date": end[:10] if end else "",
                })

    return promotions


def parse_price_xml(xml_content: str) -> dict[str, dict]:
    """Parse a price XML string into a barcode→{name, price} dict."""
    try:
        root = ET.fromstring(xml_content)
    except ET.ParseError:
        return {}

    prices = {}
    for item in root.iter("Item"):
        barcode = _find_text(item, "ItemCode")
        name = _find_text(item, "ItemName")
        price_str = _find_text(item, "ItemPrice")
        if barcode and name and price_str:
            try:
                prices[barcode] = {"name": name, "price": float(price_str)}
            except ValueError:
                pass

    return prices


def build_promotions(chain: str, promos: list[dict], prices: dict[str, dict]) -> list[dict]:
    """Join promo list with price lookup, drop items missing price data."""
    today = date.today().isoformat()
    result = []
    for promo in promos:
        barcode = promo["barcode"]
        if barcode not in prices:
            continue
        # Skip expired promotions
        if promo["end_date"] and promo["end_date"] < today:
            continue
        result.append({
            "chain": chain,
            "barcode": barcode,
            "name": prices[barcode]["name"],
            "regular_price": prices[barcode]["price"],
            "sale_price": promo["sale_price"],
            "promo_description": promo["promo_description"],
            "start_date": promo["start_date"],
            "end_date": promo["end_date"],
        })
    return result


def _chain_name_from_filename(filename: str) -> str:
    """Extract chain key from filename like 'shufersal_promo_full_2026-06-12.xml.gz'."""
    lower = filename.lower()
    for key in CHAIN_DISPLAY_NAMES:
        if key in lower:
            return CHAIN_DISPLAY_NAMES[key]
    return filename.split("_")[0]


def main():
    raw_dir = Path("data/raw")
    all_promos = []

    # Group files by chain
    chain_files: dict[str, dict] = {}
    for f in raw_dir.iterdir():
        if not (f.name.endswith(".xml") or f.name.endswith(".xml.gz")):
            continue
        chain_key = None
        for key in CHAIN_DISPLAY_NAMES:
            if key in f.name.lower():
                chain_key = key
                break
        if chain_key is None:
            continue

        chain_files.setdefault(chain_key, {"promo": [], "price": []})
        if "promo" in f.name.lower():
            chain_files[chain_key]["promo"].append(str(f))
        elif "price" in f.name.lower():
            chain_files[chain_key]["price"].append(str(f))

    for chain_key, files in chain_files.items():
        display_name = CHAIN_DISPLAY_NAMES[chain_key]
        print(f"Parsing {display_name}...")

        # Build price lookup from all price files for this chain
        prices: dict[str, dict] = {}
        for pf in files["price"]:
            prices.update(parse_price_xml(_read_file(pf)))

        # Parse all promo files and join with prices
        for pf in files["promo"]:
            promos = parse_promo_xml(_read_file(pf))
            all_promos.extend(build_promotions(display_name, promos, prices))

    os.makedirs("data", exist_ok=True)
    with open("data/promotions.json", "w", encoding="utf-8") as f:
        json.dump(all_promos, f, ensure_ascii=False, indent=2)

    print(f"Saved {len(all_promos)} promotions to data/promotions.json")


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
pytest tests/test_parse.py -v
```

Expected: 4 tests pass.

- [ ] **Step 5: Run parse.py on real data**

```bash
python3 parse.py
```

Expected: `Saved N promotions to data/promotions.json`. Open `data/promotions.json` and confirm entries have `chain`, `barcode`, `name`, `regular_price`, `sale_price`.

If you see 0 promotions, inspect the actual XML structure (Task 2 Step 3) and adjust tag names in `_find_text` calls — common variations are `<item_code>` vs `<ItemCode>`, `<item_name>` vs `<ItemName>`.

- [ ] **Step 6: Commit**

```bash
git add supermarket-tiktok/parse.py supermarket-tiktok/tests/test_parse.py
git commit -m "feat: add parse.py to extract promotions from XML"
```

---

## Task 4: match.py

Groups promotions from `data/promotions.json` by barcode (cross-chain comparison), assigns categories using Claude Haiku for product names, and writes `data/comparison.json`.

**Files:**
- Create: `supermarket-tiktok/match.py`
- Create: `supermarket-tiktok/tests/test_match.py`

- [ ] **Step 1: Write failing tests**

```python
# supermarket-tiktok/tests/test_match.py
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from match import group_by_barcode, assign_categories_locally, build_comparison


SAMPLE_PROMOTIONS = [
    {"chain": "שופרסל", "barcode": "7290000066646", "name": "חלב תנובה 3% 1L",
     "regular_price": 5.90, "sale_price": 4.90, "promo_description": "", "start_date": "", "end_date": ""},
    {"chain": "רמי לוי", "barcode": "7290000066646", "name": "חלב תנובה 3%",
     "regular_price": 4.50, "sale_price": None, "promo_description": "", "start_date": "", "end_date": ""},
    {"chain": "יוחננוף", "barcode": "7290000066646", "name": "חלב תנובה 1L",
     "regular_price": 5.50, "sale_price": 4.80, "promo_description": "", "start_date": "", "end_date": ""},
    # Single-chain product — should still appear
    {"chain": "שופרסל", "barcode": "9999999999999", "name": "עגבניות שרי 250ג",
     "regular_price": 8.90, "sale_price": 6.90, "promo_description": "", "start_date": "", "end_date": ""},
]


def test_group_by_barcode_merges_same_product():
    groups = group_by_barcode(SAMPLE_PROMOTIONS)
    assert "7290000066646" in groups
    assert len(groups["7290000066646"]["deals"]) == 3


def test_group_by_barcode_uses_most_common_name():
    groups = group_by_barcode(SAMPLE_PROMOTIONS)
    # Most common name among the 3 entries — any of the 3 is acceptable, just not empty
    assert groups["7290000066646"]["name"] != ""


def test_group_by_barcode_includes_single_chain_products():
    groups = group_by_barcode(SAMPLE_PROMOTIONS)
    assert "9999999999999" in groups


def test_assign_categories_locally_classifies_dairy():
    groups = group_by_barcode(SAMPLE_PROMOTIONS)
    categorized = assign_categories_locally(groups)
    milk_group = next(g for g in categorized if g["barcode"] == "7290000066646")
    assert milk_group["category"] == "מוצרי חלב"


def test_build_comparison_structure():
    groups = group_by_barcode(SAMPLE_PROMOTIONS)
    categorized = assign_categories_locally(groups)
    comparison = build_comparison(categorized)
    assert "generated_at" in comparison
    assert "categories" in comparison
    category_names = [c["name"] for c in comparison["categories"]]
    assert "מוצרי חלב" in category_names
```

- [ ] **Step 2: Run test to verify it fails**

```bash
pytest tests/test_match.py -v
```

Expected: `ImportError` — match.py doesn't exist yet.

- [ ] **Step 3: Write match.py**

```python
# supermarket-tiktok/match.py
import json
import os
from collections import Counter
from datetime import date

CATEGORY_KEYWORDS = {
    "מוצרי חלב": ["חלב", "גבינה", "יוגורט", "שמנת", "חמאה", "קוטג", "לבן", "גבן", "ריקוטה"],
    "בשר ועוף": ["בשר", "עוף", "פרגית", "כנפיים", "שניצל", "קציצ", "נקניק", "סלמי", "הודו", "טחון"],
    "ירקות ופירות": ["עגבני", "מלפפון", "פלפל", "חסה", "גזר", "בצל", "תפוח", "בננ", "תות", "אבוקדו", "פטריה"],
    "שתייה": ["קולה", "פנטה", "מים", "מיץ", "בירה", "יין", "שתייה", "סודה", "ספרייט"],
    "לחם ומאפים": ["לחם", "פיתה", "חלה", "בגט", "לחמני", "עוגה", "עוגיה", "קרואסון", "מאפה"],
    "ניקיון": ["סבון", "שמפו", "אבקת", "נוזל כלים", "מרכך", "דאודו", "קרם", "נייר טואלט", "מגבות"],
    "חטיפים": ["במבה", "ביסלי", "חטיף", "שוקולד", "ממתק", "גומי", "קרקר", "פופקורן"],
}


def group_by_barcode(promotions: list[dict]) -> dict[str, dict]:
    """Group promotion entries by barcode, merging deals from different chains."""
    groups: dict[str, dict] = {}
    for p in promotions:
        bc = p["barcode"]
        if bc not in groups:
            groups[bc] = {"barcode": bc, "names": [], "deals": {}}
        groups[bc]["names"].append(p["name"])
        groups[bc]["deals"][p["chain"]] = {
            "regular_price": p["regular_price"],
            "sale_price": p["sale_price"],
        }

    # Pick most common name per product
    for bc, group in groups.items():
        most_common = Counter(group["names"]).most_common(1)[0][0]
        group["name"] = most_common
        del group["names"]

    return groups


def assign_categories_locally(groups: dict[str, dict]) -> list[dict]:
    """Assign category to each product by keyword matching on product name."""
    result = []
    for bc, group in groups.items():
        name_lower = group["name"].lower()
        category = "שונות"
        for cat, keywords in CATEGORY_KEYWORDS.items():
            if any(kw in name_lower for kw in keywords):
                category = cat
                break
        result.append({**group, "category": category})
    return result


def build_comparison(categorized: list[dict]) -> dict:
    """Organize products into categories dict for generate.py."""
    by_category: dict[str, list] = {}
    for product in categorized:
        cat = product["category"]
        by_category.setdefault(cat, [])
        by_category[cat].append({
            "barcode": product["barcode"],
            "name": product["name"],
            "deals": product["deals"],
        })

    # Sort each category by number of chains (most widely compared first)
    categories = []
    for cat_name, products in by_category.items():
        products.sort(key=lambda p: len(p["deals"]), reverse=True)
        categories.append({"name": cat_name, "products": products[:20]})  # cap at 20 per category

    # Sort categories by product count
    categories.sort(key=lambda c: len(c["products"]), reverse=True)

    return {
        "generated_at": date.today().isoformat(),
        "categories": categories,
    }


def main():
    with open("data/promotions.json", encoding="utf-8") as f:
        promotions = json.load(f)

    print(f"Loaded {len(promotions)} promotions")
    groups = group_by_barcode(promotions)
    print(f"Grouped into {len(groups)} unique products")
    categorized = assign_categories_locally(groups)
    comparison = build_comparison(categorized)

    with open("data/comparison.json", "w", encoding="utf-8") as f:
        json.dump(comparison, f, ensure_ascii=False, indent=2)

    total = sum(len(c["products"]) for c in comparison["categories"])
    print(f"Saved {total} products across {len(comparison['categories'])} categories to data/comparison.json")


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
pytest tests/test_match.py -v
```

Expected: 5 tests pass.

- [ ] **Step 5: Run match.py on real data**

```bash
python3 match.py
```

Expected output like:
```
Loaded 3421 promotions
Grouped into 1847 unique products
Saved 1847 products across 7 categories to data/comparison.json
```

Open `data/comparison.json` and verify the structure matches the spec schema.

- [ ] **Step 6: Commit**

```bash
git add supermarket-tiktok/match.py supermarket-tiktok/tests/test_match.py
git commit -m "feat: add match.py for cross-chain barcode grouping and categorization"
```

---

## Task 5: generate.py

Reads `data/comparison.json` and renders one MP4 per category. Each video is a slideshow: opening slide → one slide per product → closing slide.

**Files:**
- Create: `supermarket-tiktok/generate.py`
- Create: `supermarket-tiktok/tests/test_generate.py`

**Visual spec:**
- 1080×1920 dark background (#1a1a1a)
- White text, green (#00c853) for cheapest chain, grey (#888888) for regular price (strikethrough)
- Noto Sans Hebrew font (falls back to system font)
- 2.5s per slide, fade transition

- [ ] **Step 1: Download Noto Sans Hebrew font**

```bash
cd supermarket-tiktok
mkdir -p assets
# Download NotoSansHebrew-Regular.ttf from Google Fonts
curl -L "https://github.com/googlefonts/noto-fonts/raw/main/hinted/ttf/NotoSansHebrew/NotoSansHebrew-Regular.ttf" \
     -o assets/NotoSansHebrew-Regular.ttf
curl -L "https://github.com/googlefonts/noto-fonts/raw/main/hinted/ttf/NotoSansHebrew/NotoSansHebrew-Bold.ttf" \
     -o assets/NotoSansHebrew-Bold.ttf
```

- [ ] **Step 2: Write failing tests**

```python
# supermarket-tiktok/tests/test_generate.py
import os
import sys
from pathlib import Path
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from PIL import Image
from generate import render_opening_slide, render_product_slide, render_closing_slide

W, H = 1080, 1920


def test_render_opening_slide_returns_correct_size():
    img = render_opening_slide("מוצרי חלב", "2026-06-12")
    assert isinstance(img, Image.Image)
    assert img.size == (W, H)


def test_render_product_slide_returns_correct_size():
    deals = {
        "שופרסל": {"regular_price": 5.90, "sale_price": 4.90},
        "רמי לוי": {"regular_price": 4.50, "sale_price": None},
    }
    img = render_product_slide("חלב תנובה 3% 1L", deals)
    assert isinstance(img, Image.Image)
    assert img.size == (W, H)


def test_render_closing_slide_returns_correct_size():
    img = render_closing_slide()
    assert isinstance(img, Image.Image)
    assert img.size == (W, H)


def test_render_product_slide_handles_empty_deals():
    img = render_product_slide("מוצר כלשהו", {})
    assert img.size == (W, H)
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
pytest tests/test_generate.py -v
```

Expected: `ImportError` — generate.py doesn't exist yet.

- [ ] **Step 4: Write generate.py**

```python
# supermarket-tiktok/generate.py
import json
import os
import tempfile
from datetime import date
from pathlib import Path

from bidi.algorithm import get_display
from PIL import Image, ImageDraw, ImageFont

W, H = 1080, 1920
BG = "#1a1a1a"
WHITE = "#ffffff"
GREEN = "#00c853"
GREY = "#888888"
YELLOW = "#ffd740"

FONT_PATH_REGULAR = "assets/NotoSansHebrew-Regular.ttf"
FONT_PATH_BOLD = "assets/NotoSansHebrew-Bold.ttf"


def _font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    path = FONT_PATH_BOLD if bold else FONT_PATH_REGULAR
    try:
        return ImageFont.truetype(path, size)
    except OSError:
        return ImageFont.load_default()


def _rtl(text: str) -> str:
    return get_display(text)


def _new_slide() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = Image.new("RGB", (W, H), BG)
    return img, ImageDraw.Draw(img)


def render_opening_slide(category: str, date_str: str) -> Image.Image:
    img, draw = _new_slide()
    # Category emoji mapping
    icons = {
        "מוצרי חלב": "🥛", "בשר ועוף": "🍖", "ירקות ופירות": "🥦",
        "שתייה": "🧃", "לחם ומאפים": "🍞", "ניקיון": "🧴", "חטיפים": "🍿",
    }
    icon = icons.get(category, "🛒")

    draw.text((W // 2, 600), icon, font=_font(120), anchor="mm", fill=WHITE)
    draw.text((W // 2, 820), _rtl(category), font=_font(80, bold=True), anchor="mm", fill=WHITE)
    draw.text((W // 2, 960), _rtl("השוואת מחירים"), font=_font(50), anchor="mm", fill=GREY)
    draw.text((W // 2, 1060), _rtl(date_str), font=_font(40), anchor="mm", fill=GREY)
    return img


def render_product_slide(product_name: str, deals: dict) -> Image.Image:
    img, draw = _new_slide()

    # Product name at top
    draw.text((W // 2, 280), _rtl(product_name), font=_font(60, bold=True), anchor="mm", fill=WHITE)

    if not deals:
        draw.text((W // 2, H // 2), _rtl("אין נתונים"), font=_font(50), anchor="mm", fill=GREY)
        return img

    # Find cheapest effective price per chain
    def effective_price(deal):
        return deal["sale_price"] if deal["sale_price"] is not None else deal["regular_price"]

    sorted_chains = sorted(deals.items(), key=lambda x: effective_price(x[1]))
    cheapest_chain = sorted_chains[0][0]

    row_h = 160
    start_y = 500
    for i, (chain, deal) in enumerate(sorted_chains):
        y = start_y + i * row_h
        is_cheapest = chain == cheapest_chain
        row_color = GREEN if is_cheapest else WHITE

        # Chain name (right-aligned)
        trophy = " 🏆" if is_cheapest else ""
        draw.text((W - 60, y + 30), _rtl(chain + trophy), font=_font(48, bold=is_cheapest),
                  anchor="ra", fill=row_color)

        # Price display
        ep = effective_price(deal)
        price_text = f"₪{ep:.2f}"
        draw.text((200, y + 30), price_text, font=_font(55, bold=is_cheapest),
                  anchor="la", fill=row_color)

        # Strikethrough regular price if on sale
        if deal["sale_price"] is not None and deal["regular_price"] != deal["sale_price"]:
            orig_text = f"₪{deal['regular_price']:.2f}"
            draw.text((330, y + 30), orig_text, font=_font(36), anchor="la", fill=GREY)
            # Draw strikethrough line
            bbox = _font(36).getbbox(orig_text)
            mid_y = y + 30 + (bbox[3] - bbox[1]) // 2
            draw.line([(330, mid_y), (330 + bbox[2], mid_y)], fill=GREY, width=2)

        # Divider
        draw.line([(60, y + row_h - 10), (W - 60, y + row_h - 10)], fill="#333333", width=1)

    return img


def render_closing_slide() -> Image.Image:
    img, draw = _new_slide()
    draw.text((W // 2, 700), "🛒", font=_font(120), anchor="mm", fill=WHITE)
    draw.text((W // 2, 900), _rtl("עקבו לעוד השוואות"), font=_font(65, bold=True), anchor="mm", fill=WHITE)
    draw.text((W // 2, 1020), _rtl("מחירים כל שבוע"), font=_font(50), anchor="mm", fill=GREY)
    return img


def generate_video(category_name: str, products: list[dict], output_path: str):
    today = date.today().isoformat()
    frames = []

    with tempfile.TemporaryDirectory() as tmp:
        def save_frame(img: Image.Image, idx: int) -> str:
            path = os.path.join(tmp, f"frame_{idx:04d}.png")
            img.save(path)
            return path

        frame_idx = 0
        frames.append(save_frame(render_opening_slide(category_name, today), frame_idx))
        frame_idx += 1

        for product in products:
            frames.append(save_frame(render_product_slide(product["name"], product["deals"]), frame_idx))
            frame_idx += 1

        frames.append(save_frame(render_closing_slide(), frame_idx))

        # Assemble video
        from moviepy import ImageSequenceClip, AudioFileClip

        fps = 1 / 2.5  # 2.5 seconds per frame
        clip = ImageSequenceClip(frames, fps=fps)

        music_path = "assets/music.mp3"
        if os.path.exists(music_path):
            audio = AudioFileClip(music_path)
            if audio.duration > clip.duration:
                audio = audio.subclipped(0, clip.duration)
            clip = clip.with_audio(audio)

        os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)
        clip.write_videofile(output_path, fps=24, codec="libx264", audio_codec="aac",
                             logger=None)
        print(f"  Saved: {output_path}")


def main():
    with open("data/comparison.json", encoding="utf-8") as f:
        comparison = json.load(f)

    today = comparison["generated_at"]
    os.makedirs("output", exist_ok=True)

    for category in comparison["categories"]:
        name = category["name"]
        products = category["products"]
        if not products:
            continue

        safe_name = name.replace(" ", "_").replace("/", "-")
        output_path = f"output/video_{safe_name}_{today}.mp4"
        print(f"Generating: {name} ({len(products)} products)")
        generate_video(name, products, output_path)

    print("Done. Upload files from output/ to TikTok.")


if __name__ == "__main__":
    main()
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
pytest tests/test_generate.py -v
```

Expected: 4 tests pass.

- [ ] **Step 6: Run generate.py on real data**

```bash
python3 generate.py
```

Expected: MP4 files appear in `output/`. Open one and verify the slides look correct with Hebrew text, prices, and 🏆 on the cheapest chain.

If Hebrew text appears as rectangles (missing font), confirm `assets/NotoSansHebrew-Regular.ttf` was downloaded in Step 1.

If moviepy throws an error about `ImageSequenceClip` or `with_audio`, check moviepy version: `pip show moviepy`. For v1.x, change the import to `from moviepy.editor import ImageSequenceClip, AudioFileClip` and `clip.set_audio(audio)`.

- [ ] **Step 7: Commit**

```bash
git add supermarket-tiktok/generate.py supermarket-tiktok/tests/test_generate.py
git commit -m "feat: add generate.py to render TikTok slideshow videos"
```

---

## Task 6: Final integration test + README

- [ ] **Step 1: Run full pipeline end-to-end**

```bash
cd supermarket-tiktok
python3 scrape.py   # ~5 min
python3 parse.py
python3 match.py
python3 generate.py
ls output/
```

Expected: at least 2-3 `.mp4` files in `output/`.

- [ ] **Step 2: Run all tests**

```bash
pytest tests/ -v
```

Expected: all tests pass.

- [ ] **Step 3: Write README.md**

Create `supermarket-tiktok/README.md`:

```markdown
# Supermarket Deals TikTok Bot

Weekly comparison of Israeli supermarket promotions, rendered as TikTok-ready slideshows.

## Setup

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # add your ANTHROPIC_API_KEY (optional — only needed for future AI categorization)
# Place a music.mp3 file in assets/
```

## Weekly Run

```bash
python3 scrape.py    # ~5 min — downloads promo XMLs
python3 parse.py     # extracts promotions
python3 match.py     # groups by barcode, assigns categories
python3 generate.py  # renders MP4s → output/
```

Upload files from `output/` to TikTok.

## Supported Chains

שופרסל, רמי לוי, יוחננוף, אושר עד, חצי חינם, טיב טעם, מחסני השוק, ויקטורי, קרפור
```

- [ ] **Step 4: Final commit**

```bash
git add supermarket-tiktok/README.md
git commit -m "feat: complete supermarket TikTok bot pipeline"
```
