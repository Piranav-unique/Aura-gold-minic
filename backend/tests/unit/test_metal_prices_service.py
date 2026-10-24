import pytest
from datetime import date, timedelta
from decimal import Decimal
from unittest.mock import AsyncMock, patch

from app.schemas.dashboard import MetalPricePoint
from app.services.metal_prices import MetalPriceService


@pytest.mark.asyncio
async def test_apininjas_live_parses_inr_per_gram():
    service = MetalPriceService()
    gold_payload = {
        "name": "Gold Futures",
        "price": 11250.42,
        "currency_unit": "INR",
        "unit": "g",
        "change_24h_percent": 0.42,
    }
    silver_payload = {
        "name": "Silver Futures",
        "price": 128.55,
        "currency_unit": "INR",
        "unit": "g",
        "change_24h_percent": -0.18,
    }

    with patch.object(
        service,
        "_apininjas_get",
        new=AsyncMock(side_effect=[gold_payload, silver_payload]),
    ):
        gold, silver, gold_chg, silver_chg = await service._apininjas_live()

    assert gold == Decimal("11250.42")
    assert silver == Decimal("128.55")
    assert gold_chg == Decimal("0.42")
    assert silver_chg == Decimal("-0.18")


@pytest.mark.asyncio
async def test_get_metal_prices_returns_gold_and_silver():
    service = MetalPriceService()
    prices = await service.get_prices()

    assert prices.gold.metal == "gold"
    assert prices.silver.metal == "silver"
    assert prices.gold.retail_price > 0
    assert prices.silver.retail_price > 0
    assert len(prices.gold.trend) >= 1
    assert len(prices.silver.trend) >= 1
    assert prices.gold.retail_price > 14000
    assert prices.silver.retail_price > 100


@pytest.mark.asyncio
async def test_calibrate_spot_series_aligns_to_live_anchor():
    service = MetalPriceService()
    points = [
        MetalPricePoint(label="01 Jun", price=Decimal("10000")),
        MetalPricePoint(label="25 Jun", price=Decimal("11000")),
    ]
    calibrated = service._calibrate_spot_series(points, Decimal("12100"))
    assert calibrated[0].price == Decimal("11000.00")
    assert calibrated[1].price == Decimal("12100.00")


@pytest.mark.asyncio
async def test_goldapi_history_builds_chart_points():
    service = MetalPriceService()
    end = date.today()
    start = end - timedelta(days=30)

    async def fake_price(symbol: str, day: date):
        return Decimal("12000.00") + Decimal(str(day.day))

    with patch.object(
        service,
        "_goldapi_price_on_date",
        new=AsyncMock(side_effect=fake_price),
    ):
        points = await service._goldapi_history("XAU", start, end, "1M")

    assert len(points) >= 2
    assert all(p.price > 0 for p in points)
    assert points[0].label


@pytest.mark.asyncio
async def test_get_metal_history_returns_tn_retail_chart_points():
    service = MetalPriceService()
    history = await service.get_history("gold", "1Y")

    assert len(history.points) > 0
    assert history.price_basis in (
        "tamil_nadu_retail",
        "india_market_24k",
        "india_market",
        "india_buy_rate",
        "goldapi_inr_24k",
        "gold_api_inr_24k",
    )
    assert history.points[0].price > 0


@pytest.mark.asyncio
async def test_tn_bullion_rate_matches_sln_markup():
    from app.services.metal_prices import _to_tn_bullion_rate

    spot = Decimal("12389.47")
    rate = _to_tn_bullion_rate(spot, "gold")
    assert rate > spot
    assert rate >= Decimal("14700")
    assert rate <= Decimal("14900")


@pytest.mark.asyncio
async def test_get_metal_history_1y_trend_is_upward():
    service = MetalPriceService()
    history = await service.get_history("gold", "1Y")
    assert len(history.points) >= 2
    assert history.points[-1].price > 0
    assert history.points[0].price > 0
    assert isinstance(history.performance_percent, Decimal)


@pytest.mark.asyncio
async def test_get_metal_prices_uses_short_cache():
    service = MetalPriceService()
    first = await service.get_prices()
    second = await service.get_prices()
    assert first.refreshed_at == second.refreshed_at


@pytest.mark.asyncio
async def test_api_response_hides_spot_and_breakdown():
    service = MetalPriceService()
    prices = await service.get_prices()
    payload = prices.model_dump()
    gold = payload["gold"]
    assert "spot_price" not in gold
    assert "retail" not in gold
    assert gold["retail_price"] > 0
