from __future__ import annotations

import uuid
from datetime import datetime, timezone
from decimal import Decimal
from typing import Optional

from sqlalchemy import select

from app.core import audit_actions
from app.core.exceptions import NotFoundException, ValidationException
from app.models.gold_sell_inquiry import GoldSellInquiry
from app.models.user import User
from app.repositories.bank_account import UserBankAccountRepository
from app.repositories.gold_sell_inquiry import GoldSellInquiryRepository
from app.repositories.organization_profile import OrganizationProfileRepository
from app.repositories.user import UserRepository
from app.schemas.gold_sell_inquiry import (
    GoldSellInquiryApprove,
    GoldSellInquiryCreate,
    GoldSellInquiryDetailResponse,
    GoldSellInquiryListResponse,
    GoldSellInquiryReject,
    GoldSellInquiryRespond,
    GoldSellInquiryResponse,
    SellPayoutBreakdown,
)
from app.services.audit import AuditService
from app.services.gold_scheme import GoldSchemeService
from app.services.notification import NotificationService
from app.services.sell_payout import SellPayoutService
from app.services.sell_razorpayx_payout import SellRazorpayXPayoutService


class GoldSellInquiryService:
    def __init__(
        self,
        inquiry_repo: GoldSellInquiryRepository,
        user_repo: UserRepository,
        bank_repo: UserBankAccountRepository,
        org_repo: OrganizationProfileRepository,
        notification_service: NotificationService,
        payout_service: SellPayoutService,
        razorpayx_payout_service: SellRazorpayXPayoutService,
        audit_service: Optional[AuditService] = None,
    ):
        self.inquiry_repo = inquiry_repo
        self.user_repo = user_repo
        self.bank_repo = bank_repo
        self.org_repo = org_repo
        self.notification_service = notification_service
        self.payout_service = payout_service
        self.razorpayx_payout_service = razorpayx_payout_service
        self.audit_service = audit_service

    def _to_response(self, inquiry: GoldSellInquiry) -> GoldSellInquiryResponse:
        user = inquiry.user
        user_email = user.email if user else None
        gold_balance = None
        scheme_status = None
        kyc_status = None
        if user:
            gold_balance = Decimal(str(user.gold_savings_grams or 0))
            scheme_status = user.gold_scheme_status
            kyc_status = user.kyc_status
        return GoldSellInquiryResponse(
            id=inquiry.id,
            user_id=inquiry.user_id,
            name=inquiry.name,
            mobile_number=inquiry.mobile_number,
            quantity_grams=inquiry.quantity_grams,
            message=inquiry.message,
            status=inquiry.status,
            admin_response=inquiry.admin_response,
            responded_by_user_id=inquiry.responded_by_user_id,
            responded_at=inquiry.responded_at,
            sell_rate_per_gram=inquiry.sell_rate_per_gram,
            gross_amount_inr=inquiry.gross_amount_inr,
            platform_charge_inr=inquiry.platform_charge_inr,
            tax_amount_inr=inquiry.tax_amount_inr,
            net_payable_inr=inquiry.net_payable_inr,
            payment_method=inquiry.payment_method,
            payment_destination=inquiry.payment_destination,
            reference_number=inquiry.reference_number,
            rejection_reason=inquiry.rejection_reason,
            approved_by_user_id=inquiry.approved_by_user_id,
            approved_at=inquiry.approved_at,
            razorpay_payout_id=inquiry.razorpay_payout_id,
            payout_status=inquiry.payout_status,
            payout_failure_reason=inquiry.payout_failure_reason,
            created_at=inquiry.created_at,
            updated_at=inquiry.updated_at,
            user_email=user_email,
            gold_balance_grams=gold_balance,
            gold_scheme_status=scheme_status,
            kyc_status=kyc_status,
        )

    async def _notify_admins(self, inquiry: GoldSellInquiry) -> None:
        admin_ids = set(
            await self.user_repo.get_user_ids_with_permission("transaction.view")
        )
        superuser_query = select(User.id).where(
            User.is_superuser.is_(True),
            User.is_deleted.is_(False),
            User.is_active.is_(True),
        )
        result = await self.user_repo.db.execute(superuser_query)
        admin_ids.update(result.scalars().all())

        qty = inquiry.quantity_grams or Decimal("0")
        title = "New Gold Sell Request"
        message = (
            f"Customer: {inquiry.name}\n"
            f"Quantity: {qty} grams\n"
            f"Status: Pending"
        )
        for admin_id in admin_ids:
            if admin_id == inquiry.user_id:
                continue
            await self.notification_service.create_notification(
                user_id=admin_id,
                title=title,
                message=message,
                category=NotificationService.CATEGORY_SYSTEM,
                metadata={
                    "inquiry_id": str(inquiry.id),
                    "type": "gold_sell_inquiry",
                    "quantity_grams": str(qty),
                },
            )

    async def _notify_user_submitted(self, inquiry: GoldSellInquiry) -> None:
        org = await self.org_repo.get_singleton()
        contact = org.support_contact_number if org else ""
        await self.notification_service.create_notification(
            user_id=inquiry.user_id,
            title="Sell request submitted",
            message=(
                "Your sell request has been forwarded to our administrator.\n"
                "Status: Pending Review\n"
                "Expected response: Within 24 Hours\n"
                f"Contact: {contact}"
            ),
            category=NotificationService.CATEGORY_SYSTEM,
            metadata={"inquiry_id": str(inquiry.id), "type": "gold_sell_inquiry"},
        )

    async def create_inquiry(
        self,
        user: User,
        body: GoldSellInquiryCreate,
    ) -> GoldSellInquiryResponse:
        reason = GoldSchemeService.sell_inquiry_blocked_reason(user)
        if reason:
            raise ValidationException(reason)

        holdings = Decimal(str(user.gold_savings_grams or 0))
        if body.quantity_grams > holdings:
            raise ValidationException(
                f"You can sell up to {holdings} g based on your current gold balance."
            )

        bank = await self.bank_repo.get_for_user(user.id, body.bank_account_id)
        if not bank:
            raise ValidationException(
                "Link a verified bank account before selling gold. "
                "Payout is sent to the bank you select."
            )

        payout = await self.payout_service.calculate(body.quantity_grams)

        inquiry = await self.inquiry_repo.create(
            {
                "user_id": user.id,
                "name": body.name,
                "mobile_number": body.mobile_number,
                "quantity_grams": body.quantity_grams,
                "message": body.message,
                "status": "pending",
                "bank_account_id": bank.id,
                "sell_rate_per_gram": payout["sell_rate_per_gram"],
                "gross_amount_inr": payout["gross_amount_inr"],
                "platform_charge_inr": payout["platform_charge_inr"],
                "tax_amount_inr": payout["tax_amount_inr"],
                "net_payable_inr": payout["net_payable_inr"],
            }
        )
        inquiry.user = user
        await self._notify_admins(inquiry)
        await self._notify_user_submitted(inquiry)
        if self.audit_service:
            await self.audit_service.log_action(
                user_id=user.id,
                action=audit_actions.SELL_REQUEST_CREATED,
                entity_type="GoldSellInquiry",
                entity_id=str(inquiry.id),
                metadata={
                    "quantity_grams": str(body.quantity_grams),
                    "net_payable_inr": str(payout["net_payable_inr"]),
                },
            )
        return self._to_response(inquiry)

    async def list_my_inquiries(
        self,
        user: User,
        skip: int = 0,
        limit: int = 50,
    ) -> GoldSellInquiryListResponse:
        items = await self.inquiry_repo.list_for_user(user.id, skip=skip, limit=limit)
        total = await self.inquiry_repo.count_for_user(user.id)
        return GoldSellInquiryListResponse(
            items=[self._to_response(item) for item in items],
            total=total,
            skip=skip,
            limit=limit,
        )

    async def list_inquiries(
        self,
        skip: int = 0,
        limit: int = 50,
        status: Optional[str] = None,
    ) -> GoldSellInquiryListResponse:
        items = await self.inquiry_repo.list_all(skip=skip, limit=limit, status=status)
        total = await self.inquiry_repo.count_all(status=status)
        return GoldSellInquiryListResponse(
            items=[self._to_response(item) for item in items],
            total=total,
            skip=skip,
            limit=limit,
        )

    async def _user_payment_info(
        self, user_id: uuid.UUID, bank_account_id: uuid.UUID | None = None
    ) -> tuple[Optional[str], Optional[str]]:
        bank = None
        if bank_account_id:
            bank = await self.bank_repo.get_for_user(user_id, bank_account_id)
        if not bank:
            accounts = await self.bank_repo.list_for_user(user_id)
            if not accounts:
                return None, None
            bank = accounts[0]
        return (
            "bank_account",
            f"{bank.bank_name} • XXXX{bank.account_number_last4} • {bank.ifsc}",
        )

    async def get_inquiry_detail(
        self, inquiry_id: uuid.UUID, admin_user: User
    ) -> GoldSellInquiryDetailResponse:
        inquiry = await self.inquiry_repo.get_with_user(inquiry_id)
        if not inquiry:
            raise NotFoundException(message="Sell inquiry not found")

        user = inquiry.user
        if self.audit_service:
            await self.audit_service.log_action(
                user_id=admin_user.id,
                action=audit_actions.SELL_REQUEST_VIEWED,
                entity_type="GoldSellInquiry",
                entity_id=str(inquiry.id),
            )

        scheme_status = user.gold_scheme_status or "not_selected"
        scheme_completed = scheme_status in {"completed", "not_selected"} or (
            scheme_status == "active"
            and Decimal(str(user.gold_savings_grams or 0))
            >= Decimal(str(user.gold_scheme_target_grams or 0))
        )
        scheme_warning = None
        if scheme_status == "active" and not scheme_completed:
            scheme_warning = (
                "Gold savings scheme is not completed. Review carefully before approving payout."
            )

        payout = None
        if inquiry.quantity_grams:
            calc = await self.payout_service.calculate(inquiry.quantity_grams)
            payout = SellPayoutBreakdown(**calc)

        pay_method, pay_dest = await self._user_payment_info(
            inquiry.user_id, inquiry.bank_account_id
        )
        base = self._to_response(inquiry)
        return GoldSellInquiryDetailResponse(
            **base.model_dump(),
            kyc_aadhaar_last4=user.kyc_aadhaar_last4,
            kyc_pan_last4=user.kyc_pan_last4,
            silver_balance_grams=Decimal(str(user.silver_savings_grams or 0)),
            gold_invested_inr=Decimal(str(user.gold_invested_inr or 0)),
            gold_scheme_target_grams=(
                Decimal(str(user.gold_scheme_target_grams))
                if user.gold_scheme_target_grams is not None
                else None
            ),
            gold_scheme_started_at=user.gold_scheme_started_at,
            scheme_completed=scheme_completed,
            scheme_warning=scheme_warning,
            payout=payout,
            user_payment_method=pay_method,
            user_payment_destination=pay_dest,
        )

    async def respond_to_inquiry(
        self,
        inquiry_id: uuid.UUID,
        admin_user: User,
        body: GoldSellInquiryRespond,
    ) -> GoldSellInquiryResponse:
        inquiry = await self.inquiry_repo.get_with_user(inquiry_id)
        if not inquiry:
            raise NotFoundException(message="Sell inquiry not found")
        if inquiry.status in {"approved", "rejected"}:
            raise ValidationException("This inquiry is already finalized.")

        inquiry = await self.inquiry_repo.update(
            inquiry,
            {
                "admin_response": body.admin_response,
                "status": body.status,
                "responded_by_user_id": admin_user.id,
                "responded_at": datetime.now(timezone.utc),
            },
        )
        await self.notification_service.create_notification(
            user_id=inquiry.user_id,
            title="More information needed for your sell request",
            message=body.admin_response,
            category=NotificationService.CATEGORY_SYSTEM,
            metadata={"inquiry_id": str(inquiry.id), "type": "gold_sell_inquiry"},
        )
        return self._to_response(inquiry)

    async def reject_inquiry(
        self,
        inquiry_id: uuid.UUID,
        admin_user: User,
        body: GoldSellInquiryReject,
    ) -> GoldSellInquiryResponse:
        inquiry = await self.inquiry_repo.get_with_user(inquiry_id)
        if not inquiry:
            raise NotFoundException(message="Sell inquiry not found")
        if inquiry.status in {"approved", "rejected"}:
            raise ValidationException("This inquiry is already finalized.")

        inquiry = await self.inquiry_repo.update(
            inquiry,
            {
                "status": "rejected",
                "rejection_reason": body.rejection_reason,
                "responded_by_user_id": admin_user.id,
                "responded_at": datetime.now(timezone.utc),
            },
        )
        if self.audit_service:
            await self.audit_service.log_action(
                user_id=admin_user.id,
                action=audit_actions.SELL_REJECTED,
                entity_type="GoldSellInquiry",
                entity_id=str(inquiry.id),
            )
        await self.notification_service.create_notification(
            user_id=inquiry.user_id,
            title="Your sell request has been rejected",
            message=f"Reason: {body.rejection_reason}",
            category=NotificationService.CATEGORY_SYSTEM,
            metadata={"inquiry_id": str(inquiry.id), "type": "gold_sell_inquiry"},
        )
        return self._to_response(inquiry)

    async def approve_inquiry(
        self,
        inquiry_id: uuid.UUID,
        admin_user: User,
        body: GoldSellInquiryApprove,
    ) -> GoldSellInquiryResponse:
        if not body.confirm:
            raise ValidationException("Confirmation required to approve payout.")

        inquiry = await self.inquiry_repo.get_with_user(inquiry_id)
        if not inquiry:
            raise NotFoundException(message="Sell inquiry not found")
        if inquiry.status in {"approved", "rejected"}:
            raise ValidationException("This inquiry is already finalized.")

        user = inquiry.user

        quantity = Decimal(str(inquiry.quantity_grams or 0))
        holdings = Decimal(str(user.gold_savings_grams or 0))
        if quantity <= 0 or quantity > holdings:
            raise ValidationException("Invalid sell quantity for user's current balance.")

        payout = await self.payout_service.calculate(quantity)
        now = datetime.now(timezone.utc)

        user.gold_savings_grams = holdings - quantity

        payout_result = await self.razorpayx_payout_service.initiate_payout(
            inquiry, user, Decimal(str(payout["net_payable_inr"]))
        )

        inquiry = await self.inquiry_repo.update(
            inquiry,
            {
                "status": "approved",
                "sell_rate_per_gram": payout["sell_rate_per_gram"],
                "gross_amount_inr": payout["gross_amount_inr"],
                "platform_charge_inr": payout["platform_charge_inr"],
                "tax_amount_inr": payout["tax_amount_inr"],
                "net_payable_inr": payout["net_payable_inr"],
                "payment_method": payout_result["payment_method"],
                "payment_destination": payout_result["payment_destination"],
                "reference_number": payout_result["reference_number"],
                "razorpay_payout_id": payout_result["razorpay_payout_id"],
                "razorpay_fund_account_id": payout_result["razorpay_fund_account_id"],
                "payout_status": payout_result["payout_status"],
                "approved_by_user_id": admin_user.id,
                "approved_at": now,
            },
        )
        await self.user_repo.db.commit()
        await self.user_repo.db.refresh(user)

        ref = payout_result["reference_number"]
        pay_method = payout_result["payment_method"]

        if self.audit_service:
            await self.audit_service.log_action(
                user_id=admin_user.id,
                action=audit_actions.SELL_APPROVED,
                entity_type="GoldSellInquiry",
                entity_id=str(inquiry.id),
                metadata={
                    "reference_number": ref,
                    "razorpay_payout_id": payout_result["razorpay_payout_id"],
                    "net_payable_inr": str(payout["net_payable_inr"]),
                },
            )
            await self.audit_service.log_action(
                user_id=admin_user.id,
                action=audit_actions.SELL_PAYMENT_PROCESSED,
                entity_type="GoldSellInquiry",
                entity_id=str(inquiry.id),
                metadata={
                    "reference_number": ref,
                    "razorpay_payout_id": payout_result["razorpay_payout_id"],
                    "payment_method": pay_method,
                },
            )

        payout_label = (
            "sent to your bank account"
            if payout_result["payout_status"] == "processed"
            else "initiated via RazorpayX"
        )
        await self.notification_service.create_notification(
            user_id=inquiry.user_id,
            title="Your sell request has been approved",
            message=(
                f"Amount: ₹{payout['net_payable_inr']}\n"
                f"Payment: RazorpayX bank transfer ({payout_label})\n"
                f"Payout ID: {ref}"
            ),
            category=NotificationService.CATEGORY_SYSTEM,
            metadata={
                "inquiry_id": str(inquiry.id),
                "type": "gold_sell_inquiry",
                "razorpay_payout_id": payout_result["razorpay_payout_id"],
            },
        )
        return self._to_response(inquiry)

    async def handle_payout_webhook(
        self,
        payout_id: str,
        status: str,
        failure_reason: str | None = None,
    ) -> GoldSellInquiryResponse | None:
        inquiry = await self.razorpayx_payout_service.handle_payout_webhook(
            payout_id, status, failure_reason
        )
        if not inquiry:
            return None

        if inquiry.payout_status == "processed":
            await self.notification_service.create_notification(
                user_id=inquiry.user_id,
                title="Sell payout completed",
                message=(
                    f"₹{inquiry.net_payable_inr} has been transferred to your bank account.\n"
                    f"Payout ID: {inquiry.razorpay_payout_id}"
                ),
                category=NotificationService.CATEGORY_SYSTEM,
                metadata={
                    "inquiry_id": str(inquiry.id),
                    "type": "gold_sell_payout",
                    "razorpay_payout_id": inquiry.razorpay_payout_id,
                },
            )
        elif inquiry.status == "payout_failed":
            if self.audit_service:
                await self.audit_service.log_action(
                    user_id=inquiry.user_id,
                    action=audit_actions.SELL_PAYOUT_FAILED,
                    entity_type="GoldSellInquiry",
                    entity_id=str(inquiry.id),
                    metadata={
                        "razorpay_payout_id": payout_id,
                        "reason": failure_reason or "",
                    },
                )
            await self.notification_service.create_notification(
                user_id=inquiry.user_id,
                title="Sell payout failed",
                message=(
                    "Your bank payout could not be completed. "
                    "Your gold balance has been restored. Our team will contact you.\n"
                    f"Reason: {failure_reason or 'Bank transfer failed'}"
                ),
                category=NotificationService.CATEGORY_SYSTEM,
                metadata={"inquiry_id": str(inquiry.id), "type": "gold_sell_payout"},
            )

        return self._to_response(inquiry)
