import json
from collections import Counter
from datetime import date
from pathlib import Path

CATEGORY_KEYWORDS = {
    "מוצרי חלב": ["חלב", "גבינה", "יוגורט", "חמאה", "קוטג", "לבן", "גבן", "ריקוטה"],
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

    categories = []
    for cat_name, products in by_category.items():
        # Sort by number of chains (most widely available first), cap at 20
        products.sort(key=lambda p: len(p["deals"]), reverse=True)
        categories.append({"name": cat_name, "products": products[:20], "total_count": len(products)})

    # Sort categories by uncapped product count (before the 20-cap)
    categories.sort(key=lambda c: c["total_count"], reverse=True)
    # Remove internal-only field from output
    for cat in categories:
        cat.pop("total_count")

    return {
        "generated_at": date.today().isoformat(),
        "categories": categories,
    }


def main():
    data_dir = Path(__file__).parent / "data"
    with open(data_dir / "promotions.json", encoding="utf-8") as f:
        promotions = json.load(f)

    print(f"Loaded {len(promotions)} promotions")
    groups = group_by_barcode(promotions)
    print(f"Grouped into {len(groups)} unique products")
    categorized = assign_categories_locally(groups)
    comparison = build_comparison(categorized)

    out_path = data_dir / "comparison.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(comparison, f, ensure_ascii=False, indent=2)

    total = sum(len(c["products"]) for c in comparison["categories"])
    print(f"Saved {total} products across {len(comparison['categories'])} categories to {out_path}")


if __name__ == "__main__":
    main()
