from decimal import Decimal
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.services.sell_payout import SellPayoutService


class _Quote:
    def __init__(self, spot: str):
        self.spot_price = spot


class _Prices:
    def __init__(self, gold_spot: str = "6000"):
        self.gold = _Quote(gold_spot)
        self.silver = _Quote("80")


@pytest.mark.asyncio
async def test_sell_payout_calculates_net_amount():
    metal_prices = MagicMock()
    metal_prices.get_prices = AsyncMock(return_value=_Prices("6000"))
    service = SellPayoutService(metal_prices)

    result = await service.calculate(Decimal("2.5"))

    assert result["quantity_grams"] == Decimal("2.5")
    assert result["sell_rate_per_gram"] > 0
    assert result["gross_amount_inr"] > 0
    assert result["net_payable_inr"] <= result["gross_amount_inr"]
    assert result["platform_charge_inr"] >= 0
    assert result["tax_amount_inr"] >= 0


@pytest.mark.asyncio
async def test_sell_payout_zero_quantity_edge():
    metal_prices = MagicMock()
    metal_prices.get_prices = AsyncMock(return_value=_Prices())
    service = SellPayoutService(metal_prices)

    result = await service.calculate(Decimal("0.001"))

    assert result["gross_amount_inr"] > 0
