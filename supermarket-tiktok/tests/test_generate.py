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
