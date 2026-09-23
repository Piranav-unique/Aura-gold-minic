from datetime import datetime, timezone
from decimal import Decimal, ROUND_HALF_UP
from typing import Optional
import uuid

from app.core.config import settings
from app.core.exceptions import ValidationException
from app.models.payment_order import PaymentOrder
from app.models.user import User
from app.repositories.payment_order import PaymentOrderRepository
from app.repositories.user import UserRepository
from app.schemas.payment import CreatePaymentOrderResponse, SyncPaymentResponse, VerifyPaymentResponse
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
from app.services.referral import ReferralService

_MIN_GRAMS = Decimal("0.0001")


class GoldPaymentService:
    def __init__(
        self,
        user_repo: UserRepository,
        payment_repo: PaymentOrderRepository,
        metal_prices: MetalPriceService,
        razorpay: RazorpayClient,
        digital_inventory_service: DigitalMetalInventoryService | None = None,
        referral_service: ReferralService | None = None,
    ):
        self.user_repo = user_repo
        self.payment_repo = payment_repo
        self.metal_prices = metal_prices
        self.razorpay = razorpay
        self.digital_inventory_service = digital_inventory_service
        self.referral_service = referral_service

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

        return await self._mark_order_paid(user, order, razorpay_payment_id)

    async def sync_payment(
        self,
        user: User,
        *,
        razorpay_order_id: str,
    ) -> SyncPaymentResponse:
        """Recover payments when the mobile SDK callback is lost after UPI redirect."""
        order = await self.payment_repo.get_by_razorpay_order_id(razorpay_order_id)
        if not order or order.user_id != user.id:
            raise ValidationException("Payment order not found.")
        if order.status == "paid":
            fresh_user = await self.user_repo.get(user.id)
            if fresh_user:
                user = fresh_user
            clear_personal_dashboard_cache(str(user.id))
            return self._build_sync_response(user, order, status="paid")

        if order.status == "failed":
            return SyncPaymentResponse(
                status="failed",
                message="Payment failed. Please start a new purchase.",
            )

        if RazorpayClient.is_dev_mock_order(razorpay_order_id):
            return SyncPaymentResponse(
                status="pending",
                message="Payment not completed yet.",
            )

        payments = await self.razorpay.fetch_order_payments(razorpay_order_id)
        captured = next(
            (
                payment
                for payment in payments
                if str(payment.get("status", "")).lower() == "captured"
            ),
            None,
        )
        if not captured:
            return SyncPaymentResponse(
                status="pending",
                message="Payment not completed yet.",
            )

        payment_id = str(captured.get("id") or "").strip()
        if not payment_id:
            return SyncPaymentResponse(
                status="pending",
                message="Payment not completed yet.",
            )

        verify_response = await self._mark_order_paid(user, order, payment_id)
        return self._build_sync_response(
            user,
            order,
            status="paid",
            message=verify_response.message,
        )

    async def _mark_order_paid(
        self,
        user: User,
        order: PaymentOrder,
        razorpay_payment_id: str,
        *,
        bank_rrn: str | None = None,
        payment_method: str | None = None,
        customer_contact: str | None = None,
    ) -> VerifyPaymentResponse:
        if order.status == "paid":
            fresh_user = await self.user_repo.get(user.id)
            if fresh_user:
                user = fresh_user
            return self._build_verify_response(user, order)

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
        if bank_rrn:
            order.bank_rrn = str(bank_rrn)
        if payment_method:
            order.payment_method = str(payment_method)
        if customer_contact:
            order.customer_contact = str(customer_contact)
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
        if order.metal == "gold" and self.referral_service:
            try:
                await self.referral_service.maybe_credit_referrer_on_purchase(
                    referee=user,
                    live_gold_rate=Decimal(str(order.rate_per_gram)),
                )
            except Exception as e:
                from app.core.logging import logger
                logger.error(f"Failed to credit referral reward for referee {user.id}: {e}", exc_info=True)
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

    def _build_sync_response(
        self,
        user: User,
        order: PaymentOrder,
        *,
        status: str,
        message: str | None = None,
    ) -> SyncPaymentResponse:
        return SyncPaymentResponse(
            status=status,
            message=message or "Payment successful. Your metal balance has been updated.",
            metal=order.metal,
            grams_purchased=Decimal(str(order.grams)),
            amount_inr=Decimal(str(order.amount_paise)) / Decimal("100"),
            gold_savings_grams=Decimal(str(user.gold_savings_grams or 0)),
            silver_savings_grams=Decimal(str(user.silver_savings_grams or 0)),
            gold_invested_inr=Decimal(str(user.gold_invested_inr or 0)),
            silver_invested_inr=Decimal(str(user.silver_invested_inr or 0)),
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

    async def sync_all_from_razorpay(
        self,
        admin_user: User,
    ):
        """Synchronously reconcile and pull latest Razorpay payments into our DB."""
        from app.schemas.payment import AdminPaymentSummary, RazorpaySyncAllResponse
        from app.services.executive_dashboard import clear_executive_dashboard_cache
        from app.utils.mobile import normalize_mobile

        items = await self.razorpay.list_payments(count=100)
        updated_orders = 0
        created_orders = 0

        prices = await self.metal_prices.get_prices()
        gold_rate = Decimal(str(prices.gold.retail_price))
        silver_rate = Decimal(str(prices.silver.retail_price))

        for item in items:
            payment_id = str(item.get("id") or "").strip()
            if not payment_id:
                continue

            order_id = str(item.get("order_id") or "").strip()
            raw_status = str(item.get("status") or "").strip().lower()
            method = str(item.get("method") or "upi").lower()
            contact = str(item.get("contact") or "").strip()
            email = str(item.get("email") or "").strip()
            acquirer = item.get("acquirer_data") or {}
            rrn = (
                acquirer.get("rrn")
                or acquirer.get("upi_transaction_id")
                or acquirer.get("bank_transaction_id")
            )
            error_reason = (
                item.get("error_description")
                or item.get("error_reason")
                or item.get("error_code")
            )
            amount_paise = int(item.get("amount") or 0)
            created_at_ts = item.get("created_at")
            payment_created_at = (
                datetime.fromtimestamp(created_at_ts, tz=timezone.utc)
                if created_at_ts
                else datetime.now(timezone.utc)
            )

            # 1. Match existing order
            order = await self.payment_repo.get_by_razorpay_payment_id(payment_id)
            if not order and order_id:
                order = await self.payment_repo.get_by_razorpay_order_id(order_id)

            if order:
                user = order.user or await self.user_repo.get(order.user_id)
                if raw_status == "captured":
                    if order.status != "paid" and user:
                        await self._mark_order_paid(
                            user,
                            order,
                            payment_id,
                            bank_rrn=str(rrn) if rrn else None,
                            payment_method=method,
                            customer_contact=contact or (user.mobile_number if user else None),
                        )
                        updated_orders += 1
                    else:
                        changed = False
                        if not order.bank_rrn and rrn:
                            order.bank_rrn = str(rrn)
                            changed = True
                        if not order.payment_method and method:
                            order.payment_method = method
                            changed = True
                        if not order.customer_contact and contact:
                            order.customer_contact = contact
                            changed = True
                        if not order.razorpay_payment_id and payment_id:
                            order.razorpay_payment_id = payment_id
                            changed = True
                        if changed:
                            await self.user_repo.db.commit()
                            updated_orders += 1
                elif raw_status == "failed" and order.status != "paid":
                    order.status = "failed"
                    order.failure_reason = error_reason or "Payment failed"
                    if rrn:
                        order.bank_rrn = str(rrn)
                    if method:
                        order.payment_method = method
                    if contact:
                        order.customer_contact = contact
                    if payment_id:
                        order.razorpay_payment_id = payment_id
                    await self.user_repo.db.commit()
                    updated_orders += 1
                continue

            # 2. If order not in DB, attempt matching user to create aligned record
            matched_user: User | None = None
            notes = item.get("notes") or {}
            if notes.get("user_id"):
                try:
                    matched_user = await self.user_repo.get(uuid.UUID(notes["user_id"]))
                except Exception:
                    pass

            if not matched_user and contact:
                try:
                    clean_mobile = normalize_mobile(contact)
                    matched_user = await self.user_repo.get_by_mobile(clean_mobile)
                except Exception:
                    pass

            if not matched_user and email:
                matched_user = await self.user_repo.get_by_email(email)

            if matched_user:
                metal = str(notes.get("metal", "gold")).lower()
                rate = gold_rate if metal == "gold" else silver_rate
                amount_inr = Decimal(str(amount_paise)) / Decimal("100")
                grams = grams_from_payment_amount(amount_inr, rate, metal=metal)
                settlement = compute_purchase_settlement(amount_inr, metal=metal)

                assigned_order_id = order_id or f"synced_{payment_id}"
                new_order = await self.payment_repo.create(
                    {
                        "id": uuid.uuid4(),
                        "user_id": matched_user.id,
                        "razorpay_order_id": assigned_order_id,
                        "razorpay_payment_id": payment_id,
                        "metal": metal,
                        "amount_paise": amount_paise,
                        "grams": grams,
                        "rate_per_gram": rate,
                        "gst_percent": settlement.gst_percent,
                        "metal_value_inr": settlement.metal_value_inr,
                        "gst_amount_inr": settlement.gst_amount_inr,
                        "razorpay_fee_inr": settlement.razorpay_fee_inr,
                        "merchant_settlement_inr": settlement.merchant_settlement_inr,
                        "payment_method": method,
                        "bank_rrn": str(rrn) if rrn else None,
                        "customer_contact": contact or matched_user.mobile_number,
                        "failure_reason": error_reason if raw_status == "failed" else None,
                        "status": "created",
                        "created_at": payment_created_at,
                    },
                    commit=False,
                )
                await self.user_repo.db.commit()

                if raw_status == "captured":
                    await self._mark_order_paid(
                        matched_user,
                        new_order,
                        payment_id,
                        bank_rrn=str(rrn) if rrn else None,
                        payment_method=method,
                        customer_contact=contact or matched_user.mobile_number,
                    )
                elif raw_status == "failed":
                    new_order.status = "failed"
                    new_order.failure_reason = error_reason or "Payment failed"
                    await self.user_repo.db.commit()

                created_orders += 1

        clear_executive_dashboard_cache()
        summary_dict = await self.payment_repo.get_orders_summary()
        summary_dict["last_synced_at"] = datetime.now(timezone.utc)

        return RazorpaySyncAllResponse(
            synced=True,
            total_inspected=len(items),
            updated_orders=updated_orders,
            created_orders=created_orders,
            synced_at=datetime.now(timezone.utc),
            summary=AdminPaymentSummary(**summary_dict),
        )

    async def list_admin_orders(
        self,
        *,
        skip: int = 0,
        limit: int = 50,
        status: Optional[str] = None,
        search: Optional[str] = None,
    ):
        """List comprehensive payment orders for executive dashboard."""
        from app.schemas.payment import AdminPaymentItem, AdminPaymentListResponse, AdminPaymentSummary

        items = await self.payment_repo.list_orders(
            skip=skip, limit=limit, status=status, search=search
        )
        total = await self.payment_repo.count_paid_orders() if status == "paid" else len(items)
        summary_dict = await self.payment_repo.get_orders_summary()

        return AdminPaymentListResponse(
            items=[
                AdminPaymentItem(
                    id=order.id,
                    razorpay_order_id=order.razorpay_order_id,
                    razorpay_payment_id=order.razorpay_payment_id,
                    bank_rrn=order.bank_rrn,
                    payment_method=order.payment_method,
                    customer_name=self._display_name(order.user) if order.user else None,
                    customer_mobile=order.customer_contact or (order.user.mobile_number if order.user else None),
                    customer_email=order.user.email if order.user else None,
                    metal=order.metal,
                    grams=Decimal(str(order.grams)),
                    amount_inr=Decimal(str(order.amount_paise)) / Decimal("100"),
                    status="captured" if order.status == "paid" else order.status,
                    failure_reason=order.failure_reason,
                    created_at=order.created_at,
                    paid_at=order.paid_at,
                    gst_percent=order.gst_percent,
                    metal_value_inr=order.metal_value_inr,
                    gst_amount_inr=order.gst_amount_inr,
                    razorpay_fee_inr=order.razorpay_fee_inr,
                    merchant_settlement_inr=order.merchant_settlement_inr,
                )
                for order in items
            ],
            summary=AdminPaymentSummary(**summary_dict),
            total=total,
            skip=skip,
            limit=limit,
        )

