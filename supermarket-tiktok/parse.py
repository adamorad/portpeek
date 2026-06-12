"""
parse.py — Convert downloaded XML files from data/raw/ into data/promotions.json.

Joins promo files (discounted price) with price files (product name + regular price)
by barcode. Handles two promo XML variants found across Israeli supermarket chains:

Variant A (HaziHinam, Yohananof, YaynotBitanAndCarrefour):
  DiscountType + DiscountedPrice at <Promotion> level, items as <PromotionItems><Item>

Variant B (Shufersal, RamiLevy, Osherad, TivTaam):
  DiscountedPrice at <Group><PromotionItems><PromotionItem> level (per-item price)
"""

import gzip
import json
import logging
from datetime import date
from pathlib import Path

import defusedxml.ElementTree as ET

logger = logging.getLogger(__name__)

CHAIN_DISPLAY_NAMES = {
    "shufersal": "שופרסל",
    "ramilevy": "רמי לוי",
    "yohananof": "יוחננוף",
    "osherad": "אושר עד",
    "hazihinam": "חצי חינם",
    "tivtaam": "טיב טעם",
    "mahsanishuk": "מחסני השוק",
    "mahsaniashuk": "מחסני השוק",
    "victory": "ויקטורי",
    "yaynotbitanandcarrefour": "קרפור",
    "yaynotbitan": "יינות ביתן",
}


def _read_file(path: str) -> str:
    if path.endswith(".gz"):
        with gzip.open(path, "rt", encoding="utf-8", errors="replace") as f:
            return f.read()
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        return f.read()


def _find_text(element, *tags) -> str:
    """Return text of the first found tag among candidates, stripped."""
    for tag in tags:
        el = element.find(tag)
        if el is not None and el.text:
            return el.text.strip()
    return ""


def parse_promo_xml(xml_content: str) -> list[dict]:
    """Parse a promo XML string into a list of promotion dicts.

    Handles two formats:
    - Promotion-level DiscountedPrice with <Item> children (HaziHinam/Yohananof style)
    - Per-item DiscountedPrice in <PromotionItem> under <Group> (Shufersal/RamiLevy style)
    """
    try:
        root = ET.fromstring(xml_content)
    except Exception as exc:
        logger.warning("Failed to parse XML: %s", exc)
        return []

    promotions = []
    for promo in root.iter("Promotion"):
        desc = _find_text(promo, "PromotionDescription")
        start = _find_text(promo, "PromotionStartDate", "PromotionStartDateTime")
        end = _find_text(promo, "PromotionEndDate", "PromotionEndDateTime")
        promo_price_str = _find_text(promo, "DiscountedPrice")

        start_date = start[:10] if start else ""
        end_date = end[:10] if end else ""

        # --- Variant B: PromotionItem elements carry their own DiscountedPrice ---
        # Price may live on the item itself or on its parent <Group> element.
        for group in promo.iter("Group"):
            group_price_str = _find_text(group, "DiscountedPrice")
            for item in group.iter("PromotionItem"):
                barcode = _find_text(item, "ItemCode")
                if not barcode:
                    continue
                item_price_str = _find_text(item, "DiscountedPrice")
                price_str = item_price_str or group_price_str or promo_price_str
                if not price_str:
                    continue
                try:
                    sale_price = float(price_str)
                except ValueError:
                    continue
                if sale_price <= 0:
                    continue
                promotions.append({
                    "barcode": barcode,
                    "sale_price": sale_price,
                    "promo_description": desc,
                    "start_date": start_date,
                    "end_date": end_date,
                })

        # Handle PromotionItem elements outside any Group (flat Variant B)
        if promo.find("Group") is None:
            for item in promo.iter("PromotionItem"):
                barcode = _find_text(item, "ItemCode")
                if not barcode:
                    continue
                item_price_str = _find_text(item, "DiscountedPrice")
                price_str = item_price_str or promo_price_str
                if not price_str:
                    continue
                try:
                    sale_price = float(price_str)
                except ValueError:
                    continue
                if sale_price <= 0:
                    continue
                promotions.append({
                    "barcode": barcode,
                    "sale_price": sale_price,
                    "promo_description": desc,
                    "start_date": start_date,
                    "end_date": end_date,
                })

        # --- Variant A: Item elements at PromotionItems level, price from Promotion ---
        # Only run this if no PromotionItem children found (avoid double-counting)
        has_promotion_items = promo.find(".//PromotionItem") is not None
        if not has_promotion_items:
            if not promo_price_str:
                continue
            try:
                sale_price = float(promo_price_str)
            except ValueError:
                continue
            if sale_price <= 0:
                continue
            for item in promo.iter("Item"):
                barcode = _find_text(item, "ItemCode")
                if barcode:
                    promotions.append({
                        "barcode": barcode,
                        "sale_price": sale_price,
                        "promo_description": desc,
                        "start_date": start_date,
                        "end_date": end_date,
                    })

    return promotions


def parse_price_xml(xml_content: str) -> dict[str, dict]:
    """Parse a price XML string into a barcode -> {name, price} dict."""
    try:
        root = ET.fromstring(xml_content)
    except Exception as exc:
        logger.warning("Failed to parse XML: %s", exc)
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


def build_promotions(
    chain: str,
    promos: list[dict],
    prices: dict[str, dict],
    seen: set[str] | None = None,
) -> list[dict]:
    """Join promo list with price lookup; drop items missing price data or expired.

    Pass a shared ``seen`` set across multiple calls for the same chain to
    deduplicate barcodes globally (not just within a single file).
    """
    today = date.today().isoformat()
    if seen is None:
        seen = set()
    result = []
    for promo in promos:
        barcode = promo["barcode"]
        if barcode not in prices:
            continue
        # Skip expired promotions
        if promo["end_date"] and promo["end_date"] < today:
            continue
        # Deduplicate same barcode within same chain
        key = f"{barcode}:{chain}"
        if key in seen:
            continue
        seen.add(key)
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


def _chain_display_name(dirname: str) -> str:
    """Map a raw directory name to a Hebrew display name."""
    lower = dirname.lower().replace("-", "").replace("_", "")
    for key, display in CHAIN_DISPLAY_NAMES.items():
        if key in lower:
            return display
    return dirname


def main():
    raw_dir = Path(__file__).parent / "data" / "raw"
    all_promotions: list[dict] = []

    for chain_dir in sorted(raw_dir.iterdir()):
        if not chain_dir.is_dir():
            continue
        chain_name = _chain_display_name(chain_dir.name)

        promo_files = [str(f) for f in chain_dir.rglob("*.xml*") if "promo" in f.name.lower()]
        price_files = [str(f) for f in chain_dir.rglob("*.xml*") if "price" in f.name.lower()]

        if not promo_files and not price_files:
            continue

        print(f"{chain_dir.name} ({chain_name}): {len(promo_files)} promo, {len(price_files)} price files")

        # Build price lookup from all price files for this chain
        prices: dict[str, dict] = {}
        for pf in price_files:
            prices.update(parse_price_xml(_read_file(pf)))

        # Parse promos and join with prices; share seen set across files to
        # deduplicate the same barcode appearing in multiple store files.
        chain_seen: set[str] = set()
        chain_promotions: list[dict] = []
        for pf in promo_files:
            promos = parse_promo_xml(_read_file(pf))
            chain_promotions.extend(build_promotions(chain_name, promos, prices, chain_seen))

        print(f"  -> {len(chain_promotions)} promotions after join")
        all_promotions.extend(chain_promotions)

    out_path = Path(__file__).parent / "data" / "promotions.json"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(all_promotions, f, ensure_ascii=False, indent=2)

    print(f"\nTotal: {len(all_promotions)} promotions saved to {out_path}")


if __name__ == "__main__":
    main()
