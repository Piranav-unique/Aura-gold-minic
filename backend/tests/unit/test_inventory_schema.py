import pytest
from decimal import Decimal

from app.schemas.inventory import (
    InventoryItemCreate,
    StockAdjustRequest,
    StockInRequest,
    StockOutRequest,
)


def test_inventory_item_create_valid():
    item = InventoryItemCreate(
        item_name="Gold Coin",
        item_category="gold_coin",
        weight=Decimal("5.5"),
        purity=Decimal("91.6"),
        purchase_price=Decimal("25000"),
        current_value=Decimal("27000"),
        stock_quantity=20,
    )
    assert item.item_name == "Gold Coin"
    assert item.stock_quantity == 20


def test_stock_in_request_requires_positive_quantity():
    with pytest.raises(ValueError):
        StockInRequest(quantity=0)


def test_stock_out_request_requires_positive_quantity():
    with pytest.raises(ValueError):
        StockOutRequest(quantity=-1)


def test_stock_adjust_allows_zero():
    req = StockAdjustRequest(new_quantity=0, reason="Physical count")
    assert req.new_quantity == 0
