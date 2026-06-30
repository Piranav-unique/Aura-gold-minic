from __future__ import annotations

from decimal import Decimal, ROUND_HALF_UP

from app.core.config import settings
from app.services.metal_prices import MetalPriceService


def _quantize_inr(value: Decimal) -> Decimal:
    return value.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def _quantize_rate(value: Decimal) -> Decimal:
    return value.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


class SellPayoutService:
    """Automatic sell payout calculation from live rates."""

    def __init__(self, metal_prices: MetalPriceService):
        self.metal_prices = metal_prices

    async def calculate(self, quantity_grams: Decimal, *, metal: str = "gold") -> dict:
        quantity_grams = Decimal(str(quantity_grams))
        prices = await self.metal_prices.get_prices()
        quote = prices.gold if metal == "gold" else prices.silver
        spot = Decimal(str(quote.spot_price))

        if metal == "gold":
            markup = Decimal(str(settings.METAL_GOLD_TN_BULLION_MARKUP_PERCENT))
            sell_spread = Decimal(str(settings.METAL_GOLD_SELL_SPREAD_PERCENT))
            platform_pct = Decimal(str(settings.SELL_PLATFORM_CHARGE_PERCENT))
            tax_pct = Decimal(str(settings.SELL_TAX_PERCENT))
        else:
            markup = Decimal(str(settings.METAL_SILVER_TN_BULLION_MARKUP_PERCENT))
            sell_spread = Decimal(str(settings.METAL_SILVER_SELL_SPREAD_PERCENT))
            platform_pct = Decimal(str(settings.SELL_PLATFORM_CHARGE_PERCENT))
            tax_pct = Decimal(str(settings.SELL_TAX_PERCENT))

        bullion_rate = spot * (Decimal("1") + markup / Decimal("100"))
        sell_rate = _quantize_rate(
            bullion_rate * (Decimal("1") - sell_spread / Decimal("100"))
        )
        gross = _quantize_inr(quantity_grams * sell_rate)
        platform_charge = _quantize_inr(gross * platform_pct / Decimal("100"))
        tax = _quantize_inr(platform_charge * tax_pct / Decimal("100"))
        net = _quantize_inr(gross - platform_charge - tax)

        return {
            "sell_rate_per_gram": sell_rate,
            "quantity_grams": quantity_grams,
            "gross_amount_inr": gross,
            "platform_charge_inr": platform_charge,
            "tax_amount_inr": tax,
            "net_payable_inr": net,
        }
