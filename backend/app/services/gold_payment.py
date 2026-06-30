from datetime import datetime, timezone
from decimal import Decimal, ROUND_HALF_UP
import uuid

from app.core.config import settings
from app.core.exceptions import ValidationException
from app.models.payment_order import PaymentOrder
from app.models.user import User
from app.repositories.payment_order import PaymentOrderRepository
from app.repositories.user import UserRepository
from app.schemas.payment import CreatePaymentOrderResponse, VerifyPaymentResponse
from app.services.metal_prices import MetalPriceService
from app.services.gold_scheme import GoldSchemeService
from app.services.payment_settlement import (
    compute_purchase_settlement,
    grams_from_payment_amount,
    payment_amount_from_grams,
)
from app.services.dashboard_cache import clear_personal_dashboard_cache
from app.services.razorpay_client import RazorpayClient
from app.services.digital_metal_inventory import DigitalMetalInventoryService

_MIN_GRAMS = Decimal("0.0001")


class GoldPaymentService:
    def __init__(
        self,
        user_repo: UserRepository,
        payment_repo: PaymentOrderRepository,
        metal_prices: MetalPriceService,
        razorpay: RazorpayClient,
        digital_inventory_service: DigitalMetalInventoryService | None = None,
    ):
        self.user_repo = user_repo
        self.payment_repo = payment_repo
        self.metal_prices = metal_prices
        self.razorpay = razorpay
        self.digital_inventory_service = digital_inventory_service

    async def create_buy_order(
        self,
        user: User,
        *,
        metal: str,
        grams: Decimal | None = None,
        amount_inr: Decimal | None = None,
    ) -> CreatePaymentOrderResponse:
        if user.kyc_status != "verified":
            raise ValidationException("Complete KYC verification before buying gold.")
        if metal == "gold" and (user.gold_scheme_status or "not_selected") == "not_selected":
            raise ValidationException(
                "Choose a gold savings scheme (1 g, 5 g, or 10 g) before buying gold."
            )
        if metal not in {"gold", "silver"}:
            raise ValidationException("Only gold and silver purchases are supported.")

        prices = await self.metal_prices.get_prices()
        quote = prices.gold if metal == "gold" else prices.silver
        rate = Decimal(str(quote.retail_price))

        if grams is None and amount_inr is None:
            raise ValidationException("Enter gold weight or amount in rupees.")
        if grams is not None and grams < _MIN_GRAMS:
            raise ValidationException("Enter a valid gold weight.")
        if amount_inr is not None and amount_inr < Decimal("1"):
            raise ValidationException("Minimum purchase amount is ₹1.")

        if grams is not None:
            amount = payment_amount_from_grams(grams, rate, metal=metal)
            grams = grams_from_payment_amount(amount, rate, metal=metal)
        else:
            amount = amount_inr.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
            grams = grams_from_payment_amount(amount, rate, metal=metal)

        if self.digital_inventory_service:
            await self.digital_inventory_service.ensure_available(metal, grams)

        amount_paise = int((amount * 100).to_integral_value(rounding=ROUND_HALF_UP))
        settlement = compute_purchase_settlement(amount, metal=metal)

        receipt = f"{metal}_{user.id}_{int(datetime.now(timezone.utc).timestamp())}"[:40]
        if self.razorpay.use_dev_mock:
            rz_order = {"id": f"order_dev_{uuid.uuid4().hex[:24]}"}
            key_id = RazorpayClient.DEV_MOCK_KEY_ID
        else:
            rz_order = await self.razorpay.create_order(
                amount_paise=amount_paise,
                receipt=receipt,
                notes={
                    "user_id": str(user.id),
                    "metal": metal,
                    "grams": str(grams),
                },
            )
            key_id = self.razorpay.key_id

        await self.payment_repo.create(
            {
                "id": uuid.uuid4(),
                "user_id": user.id,
                "razorpay_order_id": rz_order["id"],
                "metal": metal,
                "amount_paise": amount_paise,
                "grams": grams,
                "rate_per_gram": rate,
                "gst_percent": settlement.gst_percent,
                "metal_value_inr": settlement.metal_value_inr,
                "gst_amount_inr": settlement.gst_amount_inr,
                "razorpay_fee_inr": settlement.razorpay_fee_inr,
                "merchant_settlement_inr": settlement.merchant_settlement_inr,
                "status": "created",
            },
            commit=False,
        )
        await self.user_repo.db.commit()

        return CreatePaymentOrderResponse(
            order_id=rz_order["id"],
            key_id=key_id,
            amount_paise=amount_paise,
            amount_inr=amount,
            grams=grams,
            rate_per_gram=rate,
            metal=metal,
            currency="INR",
            user_email=user.email,
            user_name=self._display_name(user),
        )

    async def verify_payment(
        self,
        user: User,
        *,
        razorpay_order_id: str,
        razorpay_payment_id: str,
        razorpay_signature: str,
    ) -> VerifyPaymentResponse:
        order = await self.payment_repo.get_by_razorpay_order_id(razorpay_order_id)
        if not order or order.user_id != user.id:
            raise ValidationException("Payment order not found.")
        if order.status == "paid":
            fresh_user = await self.user_repo.get(user.id)
            if fresh_user:
                user = fresh_user
            clear_personal_dashboard_cache(str(user.id))
            return self._build_verify_response(user, order)

        is_dev_mock = RazorpayClient.is_dev_mock_order(razorpay_order_id)
        if is_dev_mock:
            if (
                settings.ENVIRONMENT != "development"
                or not settings.PAYMENT_DEV_MOCK
                or razorpay_signature != "dev_mock"
            ):
                order.status = "failed"
                await self.user_repo.db.commit()
                raise ValidationException("Payment verification failed.")
        elif not self.razorpay.verify_payment_signature(
            razorpay_order_id=razorpay_order_id,
            razorpay_payment_id=razorpay_payment_id,
            razorpay_signature=razorpay_signature,
        ):
            order.status = "failed"
            await self.user_repo.db.commit()
            raise ValidationException("Payment verification failed.")

        if self.digital_inventory_service:
            await self.digital_inventory_service.consume_for_paid_order(
                metal=order.metal,
                grams=Decimal(str(order.grams)),
                payment_order_id=order.id,
                user_id=user.id,
                commit=False,
            )

        order.status = "paid"
        order.razorpay_payment_id = razorpay_payment_id
        order.paid_at = datetime.now(timezone.utc)

        gross_inr = Decimal(str(order.amount_paise)) / Decimal("100")
        if order.metal == "gold":
            user.gold_savings_grams = Decimal(str(user.gold_savings_grams or 0)) + Decimal(
                str(order.grams)
            )
            user.gold_invested_inr = Decimal(str(user.gold_invested_inr or 0)) + gross_inr
            GoldSchemeService.sync_after_gold_purchase(user)
        else:
            user.silver_savings_grams = Decimal(
                str(user.silver_savings_grams or 0)
            ) + Decimal(str(order.grams))
            user.silver_invested_inr = Decimal(str(user.silver_invested_inr or 0)) + gross_inr

        await self.user_repo.db.commit()
        await self.user_repo.db.refresh(user)
        if self.digital_inventory_service:
            await self.digital_inventory_service.notify_metal_status(order.metal)
        clear_personal_dashboard_cache(str(user.id))
        return self._build_verify_response(user, order)

    def _build_verify_response(
        self, user: User, order: PaymentOrder
    ) -> VerifyPaymentResponse:
        return VerifyPaymentResponse(
            status="paid",
            metal=order.metal,
            grams_purchased=Decimal(str(order.grams)),
            amount_inr=Decimal(str(order.amount_paise)) / Decimal("100"),
            gold_savings_grams=Decimal(str(user.gold_savings_grams or 0)),
            silver_savings_grams=Decimal(str(user.silver_savings_grams or 0)),
            gold_invested_inr=Decimal(str(user.gold_invested_inr or 0)),
            silver_invested_inr=Decimal(str(user.silver_invested_inr or 0)),
            message="Payment successful. Your metal balance has been updated.",
        )

    @staticmethod
    def _display_name(user: User) -> str:
        parts = [p for p in (user.first_name, user.last_name) if p]
        return " ".join(parts) if parts else user.email

    async def list_settlements(
        self,
        skip: int = 0,
        limit: int = 50,
    ):
        from app.schemas.payment import PaymentSettlementItem, PaymentSettlementListResponse

        items = await self.payment_repo.list_paid_orders(skip=skip, limit=limit)
        total = await self.payment_repo.count_paid_orders()
        return PaymentSettlementListResponse(
            items=[
                PaymentSettlementItem(
                    id=order.id,
                    user_email=order.user.email if order.user else "",
                    metal=order.metal,
                    gross_amount_inr=Decimal(str(order.amount_paise)) / Decimal("100"),
                    gst_percent=Decimal(str(order.gst_percent or 0)),
                    metal_value_inr=Decimal(str(order.metal_value_inr or 0)),
                    gst_amount_inr=Decimal(str(order.gst_amount_inr or 0)),
                    razorpay_fee_inr=Decimal(str(order.razorpay_fee_inr or 0)),
                    merchant_settlement_inr=Decimal(
                        str(order.merchant_settlement_inr or 0)
                    ),
                    grams=Decimal(str(order.grams)),
                    paid_at=order.paid_at or order.created_at,
                )
                for order in items
            ],
            total=total,
            skip=skip,
            limit=limit,
        )
