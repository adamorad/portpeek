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


SAMPLE_PROMO_XML_VARIANT_B = """<?xml version="1.0" encoding="utf-8"?>
<Root>
  <Promotions>
    <Promotion>
      <PromotionId>2002</PromotionId>
      <PromotionDescription>מחיר שבועי</PromotionDescription>
      <PromotionStartDate>2026-06-10</PromotionStartDate>
      <PromotionEndDate>2026-06-16</PromotionEndDate>
      <Groups>
        <Group>
          <DiscountType>1</DiscountType>
          <DiscountedPrice>3.90</DiscountedPrice>
          <PromotionItems>
            <PromotionItem>
              <ItemCode>7290108879671</ItemCode>
            </PromotionItem>
          </PromotionItems>
        </Group>
      </Groups>
    </Promotion>
  </Promotions>
</Root>"""

def test_parse_promo_xml_handles_variant_b_group_structure():
    promos = parse_promo_xml(SAMPLE_PROMO_XML_VARIANT_B)
    assert len(promos) == 1
    assert promos[0]["barcode"] == "7290108879671"
    assert promos[0]["sale_price"] == 3.90
    assert promos[0]["promo_description"] == "מחיר שבועי"
