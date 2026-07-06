from __future__ import annotations

import uuid
from decimal import Decimal, ROUND_HALF_UP

from app.core.config import settings
from app.core.exceptions import ValidationException
from app.core.kyc_crypto import decrypt_aadhaar
from app.models.bank_account import UserBankAccount
from app.models.gold_sell_inquiry import GoldSellInquiry
from app.models.user import User
from app.repositories.bank_account import UserBankAccountRepository
from app.repositories.gold_sell_inquiry import GoldSellInquiryRepository
from app.repositories.user import UserRepository
from app.services.razorpayx_client import RazorpayXClient
from app.utils.mobile import normalize_mobile


class SellRazorpayXPayoutService:
    """Initiate RazorpayX bank payouts when admin approves a sell inquiry."""

    def __init__(
        self,
        razorpayx: RazorpayXClient,
        bank_repo: UserBankAccountRepository,
        user_repo: UserRepository,
        inquiry_repo: GoldSellInquiryRepository,
    ):
        self.razorpayx = razorpayx
        self.bank_repo = bank_repo
        self.user_repo = user_repo
        self.inquiry_repo = inquiry_repo

    async def _resolve_payout_bank(
        self, user_id: uuid.UUID, bank_account_id: uuid.UUID | None
    ) -> UserBankAccount:
        if bank_account_id:
            bank = await self.bank_repo.get_for_user(user_id, bank_account_id)
            if bank:
                return bank
        accounts = await self.bank_repo.list_for_user(user_id)
        if not accounts:
            raise ValidationException(
                "User has no linked bank account. Ask them to link one before payout."
            )
        return accounts[0]

    def _display_name(self, user: User) -> str:
        parts = [p for p in (user.first_name, user.last_name) if p]
        return " ".join(parts) if parts else user.email

    def _phone(self, user: User) -> str:
        mobile = normalize_mobile(user.mobile_number or "")
        if not mobile:
            raise ValidationException(
                "User mobile number is required for RazorpayX payout."
            )
        return mobile

    def _decrypt_account_number(self, bank: UserBankAccount) -> str:
        try:
            return decrypt_aadhaar(bank.account_number_encrypted)
        except Exception as exc:
            raise ValidationException(
                "Unable to read linked bank account for payout."
            ) from exc

    async def _ensure_contact(self, user: User) -> str:
        if user.razorpay_contact_id:
            return user.razorpay_contact_id

        if self.razorpayx.use_dev_mock:
            contact_id = f"cont_dev_{uuid.uuid4().hex[:14]}"
            user.razorpay_contact_id = contact_id
            return contact_id

        data = await self.razorpayx.create_contact(
            name=self._display_name(user),
            email=user.email,
            phone=self._phone(user),
            reference_id=str(user.id),
        )
        contact_id = data["id"]
        user.razorpay_contact_id = contact_id
        return contact_id

    async def _ensure_fund_account(
        self, user: User, bank: UserBankAccount, contact_id: str
    ) -> str:
        if bank.razorpay_fund_account_id:
            return bank.razorpay_fund_account_id

        if self.razorpayx.use_dev_mock:
            fund_id = f"fa_dev_{uuid.uuid4().hex[:14]}"
            bank.razorpay_fund_account_id = fund_id
            return fund_id

        account_number = self._decrypt_account_number(bank)
        data = await self.razorpayx.create_fund_account(
            contact_id=contact_id,
            account_holder_name=bank.account_holder_name,
            ifsc=bank.ifsc,
            account_number=account_number,
        )
        fund_id = data["id"]
        bank.razorpay_fund_account_id = fund_id
        return fund_id

    async def initiate_payout(
        self,
        inquiry: GoldSellInquiry,
        user: User,
        net_payable_inr: Decimal,
    ) -> dict:
        bank = await self._resolve_payout_bank(user.id, inquiry.bank_account_id)
        contact_id = await self._ensure_contact(user)
        fund_account_id = await self._ensure_fund_account(user, bank, contact_id)

        amount_paise = int(
            (net_payable_inr * 100).to_integral_value(rounding=ROUND_HALF_UP)
        )
        idempotency_key = f"sell-{inquiry.id}"

        if self.razorpayx.use_dev_mock:
            payout = self.razorpayx.create_dev_mock_payout(
                amount_paise=amount_paise,
                reference_id=str(inquiry.id),
            )
            payout_status = "processed"
        else:
            payout = await self.razorpayx.create_payout(
                fund_account_id=fund_account_id,
                amount_paise=amount_paise,
                reference_id=str(inquiry.id),
                narration="AGS Gold sell",
                idempotency_key=idempotency_key,
            )
            payout_status = self._map_payout_status(payout.get("status", "processing"))

        pay_dest = (
            f"{bank.bank_name} • XXXX{bank.account_number_last4} • {bank.ifsc}"
        )
        return {
            "razorpay_payout_id": payout["id"],
            "payout_status": payout_status,
            "payment_method": "bank_account",
            "payment_destination": pay_dest,
            "reference_number": payout["id"],
            "razorpay_fund_account_id": fund_account_id,
        }

    @staticmethod
    def _map_payout_status(razorpay_status: str) -> str:
        status = (razorpay_status or "").lower()
        if status in {"processed", "queued"}:
            return "processed" if status == "processed" else "processing"
        if status in {"processing", "pending"}:
            return "processing"
        if status in {"failed", "reversed", "cancelled"}:
            return "failed"
        return "processing"

    async def handle_payout_webhook(
        self, payout_id: str, status: str, failure_reason: str | None = None
    ) -> GoldSellInquiry | None:
        inquiry = await self.inquiry_repo.get_by_razorpay_payout_id(payout_id)
        if not inquiry:
            return None

        mapped = self._map_payout_status(status)
        if mapped == "failed":
            mapped = "failed"

        updates: dict = {"payout_status": mapped}
        if failure_reason:
            updates["payout_failure_reason"] = failure_reason

        inquiry = await self.inquiry_repo.update(inquiry, updates)

        if mapped == "failed" and inquiry.status == "approved":
            user = inquiry.user
            if user:
                qty = Decimal(str(inquiry.quantity_grams or 0))
                user.gold_savings_grams = Decimal(
                    str(user.gold_savings_grams or 0)
                ) + qty
            inquiry = await self.inquiry_repo.update(
                inquiry, {"status": "payout_failed"}
            )

        await self.user_repo.db.commit()
        return inquiry
