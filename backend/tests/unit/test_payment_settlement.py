from decimal import Decimal

from app.services.payment_settlement import (
    compute_purchase_settlement,
    grams_from_payment_amount,
    payment_amount_from_grams,
)


def test_settlement_for_1000_inr_gold():
    breakdown = compute_purchase_settlement(Decimal("1000"), metal="gold")
    assert breakdown.gross_amount_inr == Decimal("1000.00")
    assert breakdown.gst_percent == Decimal("3")
    assert breakdown.metal_value_inr == Decimal("970.87")
    assert breakdown.gst_amount_inr == Decimal("29.13")
    assert breakdown.razorpay_fee_inr == Decimal("23.60")
    assert breakdown.merchant_settlement_inr == Decimal("976.40")


def test_grams_from_10000_payment_at_14280_rate():
    grams = grams_from_payment_amount(
        Decimal("10000"),
        Decimal("14280"),
        metal="gold",
    )
    assert grams == Decimal("0.679884")
    amount = payment_amount_from_grams(grams, Decimal("14280"), metal="gold")
    # With 6 decimal places (microgram precision), metal_value + GST reverses exactly to 10000.00
    assert amount == Decimal("10000.00")


def test_settlement_modes_breakdown():
    from app.services.payment_settlement import compute_grams_purchase_settlement

    # Test ₹1.00
    s1 = compute_purchase_settlement(Decimal("1.00"), metal="gold")
    assert s1.gross_amount_inr == Decimal("1.00")
    assert s1.metal_value_inr == Decimal("0.97")
    assert s1.gst_amount_inr == Decimal("0.03")
    assert s1.metal_value_inr + s1.gst_amount_inr == Decimal("1.00")

    # Test ₹5.00
    s5 = compute_purchase_settlement(Decimal("5.00"), metal="gold")
    assert s5.gross_amount_inr == Decimal("5.00")
    assert s5.metal_value_inr == Decimal("4.85")
    assert s5.gst_amount_inr == Decimal("0.15")
    assert s5.metal_value_inr + s5.gst_amount_inr == Decimal("5.00")

    # Test ₹10.00
    s10 = compute_purchase_settlement(Decimal("10.00"), metal="gold")
    assert s10.gross_amount_inr == Decimal("10.00")
    assert s10.metal_value_inr == Decimal("9.71")
    assert s10.gst_amount_inr == Decimal("0.29")
    assert s10.metal_value_inr + s10.gst_amount_inr == Decimal("10.00")

    # Test ₹100.00
    s100 = compute_purchase_settlement(Decimal("100.00"), metal="gold")
    assert s100.gross_amount_inr == Decimal("100.00")
    assert s100.metal_value_inr == Decimal("97.09")
    assert s100.gst_amount_inr == Decimal("2.91")
    assert s100.metal_value_inr + s100.gst_amount_inr == Decimal("100.00")

    # Test ₹500.00
    s500 = compute_purchase_settlement(Decimal("500.00"), metal="gold")
    assert s500.gross_amount_inr == Decimal("500.00")
    assert s500.metal_value_inr == Decimal("485.44")
    assert s500.gst_amount_inr == Decimal("14.56")
    assert s500.metal_value_inr + s500.gst_amount_inr == Decimal("500.00")

    # Gram mode: 0.001 g at 15728 rate
    sg = compute_grams_purchase_settlement(Decimal("0.001"), Decimal("15728"), metal="gold")
    assert sg.metal_value_inr == Decimal("15.73")
    assert sg.gst_amount_inr == Decimal("0.47")
    assert sg.gross_amount_inr == Decimal("16.20")

