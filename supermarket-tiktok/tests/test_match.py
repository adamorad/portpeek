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
