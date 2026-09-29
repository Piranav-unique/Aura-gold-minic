from dataclasses import dataclass
from decimal import Decimal, ROUND_HALF_UP

from app.core.config import settings


@dataclass(frozen=True)
class PurchaseSettlementBreakdown:
    """GST-inclusive customer payment split for ledger and merchant settlement."""

    gross_amount_inr: Decimal
    gst_percent: Decimal
    metal_value_inr: Decimal
    gst_amount_inr: Decimal
    razorpay_fee_inr: Decimal
    merchant_settlement_inr: Decimal


def _quantize_inr(value: Decimal) -> Decimal:
    return value.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def gst_percent_for_metal(metal: str) -> Decimal:
    if metal == "silver":
        return Decimal(str(settings.METAL_SILVER_GST_PERCENT))
    return Decimal(str(settings.METAL_GOLD_GST_PERCENT))


def compute_purchase_settlement(
    gross_amount_inr: Decimal,
    *,
    metal: str,
) -> PurchaseSettlementBreakdown:
    """
    Customer pays a GST-inclusive total. GST is extracted internally (not shown in app UI).
    Merchant settlement = gross minus Razorpay platform fee and GST on that fee.
    """
    gross = _quantize_inr(gross_amount_inr)
    gst_percent = gst_percent_for_metal(metal)
    divisor = Decimal("1") + gst_percent / Decimal("100")
    metal_value = _quantize_inr(gross / divisor)
    gst_amount = _quantize_inr(gross - metal_value)

    fee_percent = Decimal(str(settings.RAZORPAY_PLATFORM_FEE_PERCENT))
    fee_gst_percent = Decimal(str(settings.RAZORPAY_PLATFORM_FEE_GST_PERCENT))
    platform_fee = _quantize_inr(gross * fee_percent / Decimal("100"))
    fee_gst = _quantize_inr(platform_fee * fee_gst_percent / Decimal("100"))
    razorpay_fee = _quantize_inr(platform_fee + fee_gst)
    merchant_settlement = _quantize_inr(gross - razorpay_fee)

    return PurchaseSettlementBreakdown(
        gross_amount_inr=gross,
        gst_percent=gst_percent,
        metal_value_inr=metal_value,
        gst_amount_inr=gst_amount,
        razorpay_fee_inr=razorpay_fee,
        merchant_settlement_inr=merchant_settlement,
    )


def compute_grams_purchase_settlement(
    grams: Decimal,
    rate_per_gram: Decimal,
    *,
    metal: str,
) -> PurchaseSettlementBreakdown:
    """
    Customer enters weight in grams (MODE B).
    Metal value is calculated directly from grams * rate, then GST (3%) is added.
    Total payable = metal_value + gst_amount.
    """
    if rate_per_gram <= 0:
        raise ValueError("rate_per_gram must be positive")
    metal_value = _quantize_inr(grams * rate_per_gram)
    gst_percent = gst_percent_for_metal(metal)
    gst_amount = _quantize_inr(metal_value * gst_percent / Decimal("100"))
    gross = metal_value + gst_amount

    fee_percent = Decimal(str(settings.RAZORPAY_PLATFORM_FEE_PERCENT))
    fee_gst_percent = Decimal(str(settings.RAZORPAY_PLATFORM_FEE_GST_PERCENT))
    platform_fee = _quantize_inr(gross * fee_percent / Decimal("100"))
    fee_gst = _quantize_inr(platform_fee * fee_gst_percent / Decimal("100"))
    razorpay_fee = _quantize_inr(platform_fee + fee_gst)
    merchant_settlement = _quantize_inr(gross - razorpay_fee)

    return PurchaseSettlementBreakdown(
        gross_amount_inr=gross,
        gst_percent=gst_percent,
        metal_value_inr=metal_value,
        gst_amount_inr=gst_amount,
        razorpay_fee_inr=razorpay_fee,
        merchant_settlement_inr=merchant_settlement,
    )


def grams_from_payment_amount(
    gross_amount_inr: Decimal,
    rate_per_gram: Decimal,
    *,
    metal: str,
) -> Decimal:
    """Gold grams credited from GST-inclusive payment and live buy rate per gram.
    Uses 6 decimal places (1 microgram precision) so small purchases (e.g. ₹1)
    accurately reflect fractional metal without destructive display rounding."""
    if rate_per_gram <= 0:
        raise ValueError("rate_per_gram must be positive")
    settlement = compute_purchase_settlement(gross_amount_inr, metal=metal)
    return (settlement.metal_value_inr / rate_per_gram).quantize(
        Decimal("0.000001"), rounding=ROUND_HALF_UP
    )


def payment_amount_from_grams(
    grams: Decimal,
    rate_per_gram: Decimal,
    *,
    metal: str,
) -> Decimal:
    """GST-inclusive Razorpay amount for a target metal weight at the live buy rate."""
    if rate_per_gram <= 0:
        raise ValueError("rate_per_gram must be positive")
    metal_value = _quantize_inr(grams * rate_per_gram)
    gst_percent = gst_percent_for_metal(metal)
    gst_amount = _quantize_inr(metal_value * gst_percent / Decimal("100"))
    return metal_value + gst_amount
