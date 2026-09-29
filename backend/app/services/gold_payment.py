import asyncio
from datetime import datetime, timezone
from decimal import Decimal, ROUND_HALF_UP
from typing import Optional
import uuid

from app.core.config import settings
from app.core import audit_actions
from app.core.email_utils import is_placeholder_email
from app.core.exceptions import NotFoundException, ValidationException
from app.core.logging import logger

from app.models.payment_order import PaymentOrder
from app.models.user import User
from app.repositories.payment_order import PaymentOrderRepository
from app.repositories.user import UserRepository
from app.schemas.payment import CreatePaymentOrderResponse, SyncPaymentResponse, VerifyPaymentResponse
from app.services.metal_prices import MetalPriceService
from app.services.gold_scheme import GoldSchemeService
from app.services.payment_settlement import (
    compute_grams_purchase_settlement,
    compute_purchase_settlement,
    grams_from_payment_amount,
    payment_amount_from_grams,
)
from app.services.dashboard_cache import clear_personal_dashboard_cache
from app.services.razorpay_client import RazorpayClient
from app.services.digital_metal_inventory import DigitalMetalInventoryService
from app.services.referral import ReferralService
from app.services.invoice import generate_invoice_pdf
from app.services.email_service import send_invoice_email_async

# Avoid circular import — AuditService is only needed for type hints at runtime
from typing import TYPE_CHECKING
if TYPE_CHECKING:
    from app.services.audit import AuditService

_MIN_GRAMS = Decimal("0.0001")
# Tolerance for Razorpay amount cross-check (1 paisa allowed for rounding)
_AMOUNT_TOLERANCE_PAISE = 1


class GoldPaymentService:
    def __init__(
        self,
        user_repo: UserRepository,
        payment_repo: PaymentOrderRepository,
        metal_prices: MetalPriceService,
        razorpay: RazorpayClient,
        digital_inventory_service: DigitalMetalInventoryService | None = None,
        referral_service: ReferralService | None = None,
        audit_service: Optional["AuditService"] = None,
    ):
        self.user_repo = user_repo
        self.payment_repo = payment_repo
        self.metal_prices = metal_prices
        self.razorpay = razorpay
        self.digital_inventory_service = digital_inventory_service
        self.referral_service = referral_service
        self.audit_service = audit_service

    async def create_buy_order(
        self,
        user: User,
        *,
        metal: str,
        purchase_mode: str | None = None,
        grams: Decimal | None = None,
        amount_inr: Decimal | None = None,
    ) -> CreatePaymentOrderResponse:
        if user.kyc_status != "verified":
            raise ValidationException("Complete KYC verification before buying gold.")
        if is_placeholder_email(user.email):
            raise ValidationException(
                "Please add your personal email address (e.g. name@gmail.com) in your profile to receive tax invoices before purchasing."
            )
        if metal == "gold" and (user.gold_scheme_status or "not_selected") == "not_selected":
            raise ValidationException(
                "Choose a gold savings scheme (1 g, 5 g, or 10 g) before buying gold."
            )
        if metal not in {"gold", "silver"}:
            raise ValidationException("Only gold and silver purchases are supported.")

        prices = await self.metal_prices.get_prices()
        quote = prices.gold if metal == "gold" else prices.silver
        rate = Decimal(str(quote.retail_price))

        # Determine explicit purchase mode
        mode = (purchase_mode or "").lower().strip()
        if not mode:
            if amount_inr is not None and amount_inr > 0 and (grams is None or grams <= 0):
                mode = "amount"
            elif grams is not None and grams > 0 and (amount_inr is None or amount_inr <= 0):
                mode = "grams"
            elif amount_inr is not None and amount_inr > 0:
                mode = "amount"
            else:
                mode = "grams"

        if mode == "amount":
            if amount_inr is None or amount_inr <= Decimal("0"):
                raise ValidationException("Enter an amount in rupees.")
            if amount_inr < Decimal("1"):
                raise ValidationException("Minimum purchase amount is ₹1.")

            # MODE A: Exact INR amount is strictly authoritative.
            final_amount = amount_inr.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
            settlement = compute_purchase_settlement(final_amount, metal=metal)
            final_grams = grams_from_payment_amount(final_amount, rate, metal=metal)

        elif mode == "grams":
            if grams is None or grams <= Decimal("0"):
                raise ValidationException("Enter gold weight.")
            if grams < _MIN_GRAMS:
                raise ValidationException(f"Minimum purchase weight is {_MIN_GRAMS} g.")

            # MODE B: Exact grams quantity is strictly authoritative.
            final_grams = grams.quantize(Decimal("0.000001"), rounding=ROUND_HALF_UP)
            settlement = compute_grams_purchase_settlement(final_grams, rate, metal=metal)
            final_amount = settlement.gross_amount_inr

        else:
            raise ValidationException("Invalid purchase mode.")

        if self.digital_inventory_service:
            await self.digital_inventory_service.ensure_available(metal, final_grams)

        amount_paise = int((final_amount * 100).to_integral_value(rounding=ROUND_HALF_UP))

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
                    "purchase_mode": mode,
                    "grams": str(final_grams),
                    "amount_inr": str(final_amount),
                },
            )
            key_id = self.razorpay.key_id

        await self.payment_repo.create(
            {
                "id": uuid.uuid4(),
                "user_id": user.id,
                "razorpay_order_id": rz_order["id"],
                "metal": metal,
                "purchase_mode": mode,
                "amount_paise": amount_paise,
                "grams": final_grams,
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
            amount_inr=final_amount,
            grams=final_grams,
            rate_per_gram=rate,
            metal=metal,
            purchase_mode=mode,
            currency="INR",
            user_email=user.email or "",
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

        return await self._mark_order_paid(
            user, order, razorpay_payment_id, _verify_amount=True
        )

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

        customer_email = str(captured.get("email") or "").strip()
        verify_response = await self._mark_order_paid(
            user,
            order,
            payment_id,
            customer_email=customer_email or None,
        )
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
        customer_email: str | None = None,
        # When called from verify_payment (SDK callback), we have the payment ID
        # so we can cross-check the actual charged amount with Razorpay's server.
        _verify_amount: bool = False,
    ) -> VerifyPaymentResponse:
        if order.status == "paid":
            fresh_user = await self.user_repo.get(user.id)
            if fresh_user:
                user = fresh_user
            return self._build_verify_response(user, order)

        # ------------------------------------------------------------------ #
        # SECURITY: Cross-check amount with Razorpay server (prevents         #
        # tampering where someone submits a valid signature for a different    #
        # order amount or alters the payment before capture).                  #
        # Only runs for real Razorpay payments (not dev-mock), and only when   #
        # we have a payment ID to look up.                                     #
        # ------------------------------------------------------------------ #
        is_dev_mock_payment = RazorpayClient.is_dev_mock_order(
            order.razorpay_order_id or ""
        )
        if (
            _verify_amount
            and not is_dev_mock_payment
            and razorpay_payment_id
            and not razorpay_payment_id.startswith("dev_")
        ):
            try:
                rz_payment = await self.razorpay.fetch_payment(razorpay_payment_id)
                rz_amount_paise = int(rz_payment.get("amount") or 0)
                rz_status = str(rz_payment.get("status") or "").lower()
                # Payment must be captured and amount must match within tolerance
                amount_diff = abs(rz_amount_paise - int(order.amount_paise))
                if rz_status != "captured":
                    logger.warning(
                        "payment_not_captured",
                        payment_id=razorpay_payment_id,
                        order_id=str(order.id),
                        rz_status=rz_status,
                    )
                    order.status = "failed"
                    order.failure_reason = f"Payment status is '{rz_status}', not captured"
                    await self.user_repo.db.commit()
                    if self.audit_service:
                        await self.audit_service.log_action(
                            user_id=user.id,
                            action=audit_actions.PAYMENT_FAILED,
                            entity_type="PaymentOrder",
                            entity_id=str(order.id),
                            metadata={
                                "razorpay_payment_id": razorpay_payment_id,
                                "rz_status": rz_status,
                                "metal": order.metal,
                                "amount_paise": int(order.amount_paise),
                            },
                        )
                    raise ValidationException(
                        "Payment has not been captured by Razorpay. Please contact support."
                    )
                if amount_diff > _AMOUNT_TOLERANCE_PAISE:
                    logger.error(
                        "payment_amount_mismatch",
                        payment_id=razorpay_payment_id,
                        order_id=str(order.id),
                        stored_paise=int(order.amount_paise),
                        rz_paise=rz_amount_paise,
                        diff_paise=amount_diff,
                    )
                    order.status = "failed"
                    order.failure_reason = (
                        f"Amount mismatch: stored={order.amount_paise} paise, "
                        f"Razorpay={rz_amount_paise} paise"
                    )
                    await self.user_repo.db.commit()
                    if self.audit_service:
                        await self.audit_service.log_action(
                            user_id=user.id,
                            action=audit_actions.PAYMENT_AMOUNT_MISMATCH,
                            entity_type="PaymentOrder",
                            entity_id=str(order.id),
                            metadata={
                                "razorpay_payment_id": razorpay_payment_id,
                                "stored_paise": int(order.amount_paise),
                                "rz_paise": rz_amount_paise,
                                "diff_paise": amount_diff,
                                "metal": order.metal,
                            },
                        )
                    raise ValidationException(
                        "Payment amount mismatch detected. Please contact support."
                    )
                # Enrich from Razorpay response if not already supplied
                if not bank_rrn:
                    acquirer = rz_payment.get("acquirer_data") or {}
                    bank_rrn = (
                        acquirer.get("rrn")
                        or acquirer.get("upi_transaction_id")
                        or acquirer.get("bank_transaction_id")
                    )
                if not payment_method:
                    payment_method = str(rz_payment.get("method") or "").lower() or None
                if not customer_contact:
                    customer_contact = str(rz_payment.get("contact") or "").strip() or None
                if not customer_email:
                    customer_email = str(rz_payment.get("email") or "").strip() or None
            except ValidationException:
                raise
            except Exception as exc:
                # Network/API failure — log and proceed without blocking gold credit.
                # Amount was already verified by Razorpay signature; this is a defence-
                # in-depth layer, not the primary verification.
                logger.error(
                    "razorpay_amount_verify_failed",
                    payment_id=razorpay_payment_id,
                    order_id=str(order.id),
                    error=str(exc),
                )

        if (
            customer_email
            and "@" in str(customer_email)
            and not str(customer_email).lower().endswith("void@razorpay.com")
            and not is_placeholder_email(str(customer_email))
            and is_placeholder_email(user.email)
        ):
            user.email = str(customer_email).strip().lower()

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

        # ------------------------------------------------------------------ #
        # AUDIT: Log successful payment capture with full financial details.   #
        # ------------------------------------------------------------------ #
        if self.audit_service:
            try:
                await self.audit_service.log_action(
                    user_id=user.id,
                    action=audit_actions.PAYMENT_CAPTURED,
                    entity_type="PaymentOrder",
                    entity_id=str(order.id),
                    metadata={
                        "razorpay_order_id": order.razorpay_order_id,
                        "razorpay_payment_id": razorpay_payment_id,
                        "metal": order.metal,
                        "grams": str(order.grams),
                        "amount_inr": str(gross_inr),
                        "rate_per_gram": str(order.rate_per_gram),
                        "bank_rrn": bank_rrn,
                        "payment_method": payment_method,
                    },
                )
            except Exception as exc:
                logger.error(f"Failed to write payment audit log for order {order.id}: {exc}")

        if self.digital_inventory_service:
            await self.digital_inventory_service.notify_metal_status(order.metal)
        if order.metal == "gold" and self.referral_service:
            try:
                await self.referral_service.maybe_credit_referrer_on_purchase(
                    referee=user,
                    live_gold_rate=Decimal(str(order.rate_per_gram)),
                    purchase_amount_inr=gross_inr,
                )
            except Exception as e:
                logger.error(f"Failed to credit referral reward for referee {user.id}: {e}", exc_info=True)
        clear_personal_dashboard_cache(str(user.id))

        # Dispatch tax invoice email asynchronously in the background
        try:
            asyncio.create_task(send_invoice_email_async(user, order))
        except Exception as e:
            logger.error(f"Failed to dispatch invoice email for order {order.id}: {e}", exc_info=True)

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
        if parts:
            return " ".join(parts).strip()
        if getattr(user, "kyc_profile", None):
            try:
                import json
                kd = json.loads(user.kyc_profile)
                if isinstance(kd, dict) and (kd.get("full_name") or kd.get("name")):
                    return str(kd.get("full_name") or kd.get("name")).strip()
            except Exception:
                pass
        if getattr(user, "email", None) and "@" in str(user.email):
            import re
            cleaned = re.sub(r"[\d_.]+", " ", str(user.email).split("@")[0]).strip()
            if len(cleaned) >= 3 and not cleaned.isdigit():
                return cleaned.title()
            return str(user.email)
        if getattr(user, "mobile_number", None):
            return str(user.mobile_number)
        return "Customer"

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

    async def get_order_invoice_pdf(
        self, current_user: User, order_id: uuid.UUID
    ) -> tuple[bytes, str]:
        order = await self.payment_repo.get(order_id)
        if not order:
            raise NotFoundException("Payment order not found.")

        if not current_user.is_superuser and order.user_id != current_user.id:
            raise NotFoundException("Payment order not found.")

        if order.status != "paid":
            raise ValidationException("Tax invoice is only available for completed and paid orders.")

        user = getattr(order, "user", None) or await self.user_repo.get(order.user_id) or current_user
        pdf_bytes = generate_invoice_pdf(order, user)
        inv_id = str(order.id).replace("-", "")[:8].upper()
        filename = f"Invoice_INV-AGS-{inv_id}.pdf"
        return pdf_bytes, filename

    async def resend_order_invoice_email(
        self, current_user: User, order_id: uuid.UUID
    ) -> dict[str, str]:
        order = await self.payment_repo.get(order_id)
        if not order:
            raise NotFoundException("Payment order not found.")

        if not current_user.is_superuser and order.user_id != current_user.id:
            raise NotFoundException("Payment order not found.")

        if order.status != "paid":
            raise ValidationException("Tax invoice is only available for completed and paid orders.")

        user = getattr(order, "user", None) or await self.user_repo.get(order.user_id) or current_user
        recipient_email = (getattr(user, "email", "") or "").strip()
        if not recipient_email or "@" not in recipient_email:
            raise ValidationException("User does not have a valid email address configured.")

        success = await send_invoice_email_async(user, order)
        if not success:
            raise ValidationException("Unable to send invoice email at this time. Please verify SMTP settings.")

        return {
            "status": "success",
            "message": f"Tax invoice has been emailed to {recipient_email}",
            "recipient": recipient_email,
        }

    async def handle_payment_webhook(
        self,
        *,
        event: str,
        payload: dict,
    ) -> bool:
        """Handle Razorpay payment webhooks (e.g. payment.captured, order.paid)."""
        payment_entity = payload.get("payment", {}).get("entity", {})
        order_entity = payload.get("order", {}).get("entity", {})

        order_id = payment_entity.get("order_id") or order_entity.get("id")
        payment_id = payment_entity.get("id")
        raw_status = str(payment_entity.get("status") or order_entity.get("status") or "").lower()

        if not order_id and not payment_id:
            return False

        order = None
        if order_id:
            order = await self.payment_repo.get_by_razorpay_order_id(order_id)
        if not order and payment_id:
            order = await self.payment_repo.get_by_razorpay_payment_id(payment_id)

        if not order:
            from app.core.logging import logger
            logger.warning(
                "payment_webhook_order_not_found",
                order_id=order_id,
                payment_id=payment_id,
                event=event,
            )
            return False

        if order.status == "paid":
            return True

        user = getattr(order, "user", None) or await self.user_repo.get(order.user_id)
        if not user:
            from app.core.logging import logger
            logger.error("payment_webhook_user_not_found", user_id=str(order.user_id))
            return False

        if event in {"payment.captured", "order.paid"} or raw_status in {"captured", "paid"}:
            acquirer = payment_entity.get("acquirer_data") or {}
            rrn = (
                acquirer.get("rrn")
                or acquirer.get("upi_transaction_id")
                or acquirer.get("bank_transaction_id")
            )
            method = payment_entity.get("method")
            contact = payment_entity.get("contact")
            customer_email = payment_entity.get("email")

            await self._mark_order_paid(
                user,
                order,
                payment_id or f"webhook_{order_id}",
                bank_rrn=str(rrn) if rrn else None,
                payment_method=str(method) if method else None,
                customer_contact=str(contact) if contact else None,
                customer_email=str(customer_email) if customer_email else None,
            )
            from app.core.logging import logger
            logger.info(
                "payment_webhook_order_marked_paid",
                order_id=str(order.id),
                razorpay_order_id=order_id,
                payment_id=payment_id,
            )
            return True

        if event == "payment.failed" or raw_status == "failed":
            error_reason = (
                payment_entity.get("error_description")
                or payment_entity.get("error_reason")
                or payment_entity.get("error_code")
                or "Payment failed"
            )
            order.status = "failed"
            order.failure_reason = str(error_reason)
            await self.user_repo.db.commit()
            return True

        return False



