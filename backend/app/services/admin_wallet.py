from __future__ import annotations

import uuid
from datetime import date
from decimal import Decimal
from typing import Optional

from app.core import audit_actions
from app.core.exceptions import NotFoundException
from app.models.user import User
from app.repositories.admin_wallet import AdminWalletRepository, _user_display_name
from app.schemas.admin_wallet import (
    WalletPaymentDetails,
    WalletReferralDetails,
    WalletSavingsDetails,
    WalletSellDetails,
    WalletStatusHistoryItem,
    WalletSummary,
    WalletTransactionDetailResponse,
    WalletTransactionItem,
    WalletTransactionListResponse,
    WalletUserDetailResponse,
    WalletUserSearchItem,
    WalletUserSearchResponse,
)
from app.services.audit import AuditService


class AdminWalletService:
    """Admin wallet search, detail, and unified transaction views."""

    def __init__(
        self,
        wallet_repo: AdminWalletRepository,
        audit_service: Optional[AuditService] = None,
    ):
        self.wallet_repo = wallet_repo
        self.audit_service = audit_service

    async def _log_wallet_view(
        self,
        admin_user_id: uuid.UUID,
        target_user_id: uuid.UUID,
        *,
        action: str,
        metadata: Optional[dict] = None,
    ) -> None:
        if not self.audit_service:
            return
        await self.audit_service.log_action(
            user_id=admin_user_id,
            action=action,
            entity_type="UserWallet",
            entity_id=str(target_user_id),
            metadata=metadata or {},
        )

    def _to_search_item(self, user: User) -> WalletUserSearchItem:
        return WalletUserSearchItem(
            id=user.id,
            full_name=_user_display_name(user),
            email=user.email,
            mobile_number=user.mobile_number,
            kyc_status=user.kyc_status,
            kyc_aadhaar_last4=user.kyc_aadhaar_last4,
            kyc_pan_last4=user.kyc_pan_last4,
            is_active=user.is_active,
            gold_balance_grams=user.gold_savings_grams or Decimal("0"),
            silver_balance_grams=user.silver_savings_grams or Decimal("0"),
            wallet_balance_inr=user.wallet_balance_inr or Decimal("0"),
            created_at=user.created_at,
        )

    async def _build_wallet_summary(self, user: User) -> WalletSummary:
        total_bought = await self.wallet_repo.sum_paid_grams(user.id)
        pending_sell = await self.wallet_repo.count_pending_sell_inquiries(user.id)
        referral_inr, referral_grams = await self.wallet_repo.sum_referral_rewards(
            user.id
        )
        gold_invested = user.gold_invested_inr or Decimal("0")
        silver_invested = user.silver_invested_inr or Decimal("0")
        return WalletSummary(
            gold_balance_grams=user.gold_savings_grams or Decimal("0"),
            silver_balance_grams=user.silver_savings_grams or Decimal("0"),
            total_inr_invested=gold_invested + silver_invested,
            total_bought_grams=total_bought,
            total_sold_grams=Decimal("0"),
            pending_sell_inquiries=pending_sell,
            referral_reward_inr=referral_inr,
            referral_reward_grams=referral_grams,
            savings_scheme_target_grams=user.gold_scheme_target_grams,
            savings_scheme_status=user.gold_scheme_status or "not_selected",
            wallet_balance_inr=user.wallet_balance_inr or Decimal("0"),
        )

    async def search_users(
        self,
        *,
        search: Optional[str] = None,
        skip: int = 0,
        limit: int = 20,
    ) -> WalletUserSearchResponse:
        users, total = await self.wallet_repo.search_wallet_users(
            search=search, skip=skip, limit=limit
        )
        return WalletUserSearchResponse(
            items=[self._to_search_item(u) for u in users],
            total=total,
            skip=skip,
            limit=limit,
        )

    async def get_user_wallet(
        self,
        user_id: uuid.UUID,
        *,
        admin_user_id: uuid.UUID,
    ) -> WalletUserDetailResponse:
        user = await self.wallet_repo.get_wallet_user(user_id)
        if not user:
            raise NotFoundException("User not found")

        await self._log_wallet_view(
            admin_user_id,
            user_id,
            action=audit_actions.WALLET_USER_VIEW,
            metadata={
                "kyc_status": user.kyc_status,
                "viewed_masked_kyc": True,
            },
        )

        wallet = await self._build_wallet_summary(user)
        return WalletUserDetailResponse(
            id=user.id,
            full_name=_user_display_name(user),
            email=user.email,
            mobile_number=user.mobile_number,
            kyc_status=user.kyc_status,
            kyc_aadhaar_last4=user.kyc_aadhaar_last4,
            kyc_pan_last4=user.kyc_pan_last4,
            created_at=user.created_at,
            is_active=user.is_active,
            is_deleted=user.is_deleted,
            wallet=wallet,
        )

    def _row_to_item(self, row) -> WalletTransactionItem:
        return WalletTransactionItem(
            id=row.id,
            user_id=row.user_id,
            user_name=row.user_name,
            user_mobile=row.user_mobile,
            occurred_at=row.occurred_at,
            transaction_type=row.transaction_type,
            metal=row.metal,
            quantity_grams=row.quantity_grams,
            amount_inr=row.amount_inr,
            status=row.status,
            reference_id=row.reference_id,
        )

    async def list_user_transactions(
        self,
        user_id: uuid.UUID,
        *,
        skip: int = 0,
        limit: int = 20,
        transaction_type: Optional[str] = None,
        metal: Optional[str] = None,
        status: Optional[str] = None,
    ) -> WalletTransactionListResponse:
        user = await self.wallet_repo.get_wallet_user(user_id)
        if not user:
            raise NotFoundException("User not found")

        rows, total = await self.wallet_repo.list_transactions(
            user_id=user_id,
            skip=skip,
            limit=limit,
            transaction_type=transaction_type,
            metal=metal,
            status=status,
        )
        return WalletTransactionListResponse(
            items=[self._row_to_item(r) for r in rows],
            total=total,
            skip=skip,
            limit=limit,
        )

    async def list_recent_transactions(
        self,
        *,
        skip: int = 0,
        limit: int = 20,
        transaction_type: Optional[str] = None,
        metal: Optional[str] = None,
        status: Optional[str] = None,
        search: Optional[str] = None,
        from_date: Optional[date] = None,
        to_date: Optional[date] = None,
    ) -> WalletTransactionListResponse:
        rows, total = await self.wallet_repo.list_transactions(
            user_id=None,
            skip=skip,
            limit=limit,
            transaction_type=transaction_type,
            metal=metal,
            status=status,
            search=search,
            from_date=from_date,
            to_date=to_date,
        )
        return WalletTransactionListResponse(
            items=[self._row_to_item(r) for r in rows],
            total=total,
            skip=skip,
            limit=limit,
        )

    async def get_transaction_detail(
        self,
        transaction_id: str,
        *,
        admin_user_id: uuid.UUID,
    ) -> WalletTransactionDetailResponse:
        if ":" not in transaction_id:
            raise NotFoundException("Transaction not found")

        kind, raw_id = transaction_id.split(":", 1)
        try:
            source_id = uuid.UUID(raw_id)
        except ValueError:
            raise NotFoundException("Transaction not found")

        if kind == "buy":
            return await self._detail_from_buy(source_id, transaction_id, admin_user_id)
        if kind == "sell":
            return await self._detail_from_sell(source_id, transaction_id, admin_user_id)
        if kind == "referral":
            return await self._detail_from_referral(
                source_id, transaction_id, admin_user_id
            )
        if kind == "savings":
            return await self._detail_from_savings(
                source_id, transaction_id, admin_user_id
            )
        raise NotFoundException("Transaction not found")

    async def _detail_from_buy(
        self, order_id: uuid.UUID, txn_id: str, admin_user_id: uuid.UUID
    ) -> WalletTransactionDetailResponse:
        order = await self.wallet_repo.get_payment_order(order_id)
        if not order:
            raise NotFoundException("Transaction not found")
        user = await self.wallet_repo.get_wallet_user(order.user_id)
        if not user:
            raise NotFoundException("User not found")

        await self._log_wallet_view(
            admin_user_id,
            user.id,
            action=audit_actions.WALLET_TRANSACTION_VIEW,
            metadata={"transaction_id": txn_id, "type": "BUY"},
        )

        amount = Decimal(order.amount_paise) / Decimal("100")
        history = [
            WalletStatusHistoryItem(
                status="created", occurred_at=order.created_at, note="Order created"
            )
        ]
        if order.paid_at:
            history.append(
                WalletStatusHistoryItem(
                    status="paid", occurred_at=order.paid_at, note="Payment verified"
                )
            )
        if order.status == "failed":
            history.append(
                WalletStatusHistoryItem(
                    status="failed",
                    occurred_at=order.created_at,
                    note="Payment failed or abandoned",
                )
            )

        platform_fee = order.razorpay_fee_inr
        return WalletTransactionDetailResponse(
            id=txn_id,
            user_id=user.id,
            user_name=_user_display_name(user),
            user_email=user.email,
            user_mobile=user.mobile_number,
            occurred_at=order.paid_at or order.created_at,
            transaction_type="BUY",
            metal=order.metal.upper(),
            quantity_grams=order.grams,
            amount_inr=amount,
            rate_per_gram=order.rate_per_gram,
            gst_amount_inr=order.gst_amount_inr,
            platform_fee_inr=platform_fee,
            total_amount_inr=amount,
            status=order.status,
            reference_id=order.razorpay_order_id,
            payment_details=WalletPaymentDetails(
                razorpay_order_id=order.razorpay_order_id,
                razorpay_payment_id=order.razorpay_payment_id,
                rate_per_gram=order.rate_per_gram,
                gst_percent=order.gst_percent,
                gst_amount_inr=order.gst_amount_inr,
                metal_value_inr=order.metal_value_inr,
                razorpay_fee_inr=order.razorpay_fee_inr,
                merchant_settlement_inr=order.merchant_settlement_inr,
            ),
            status_history=history,
        )

    async def _detail_from_sell(
        self, inquiry_id: uuid.UUID, txn_id: str, admin_user_id: uuid.UUID
    ) -> WalletTransactionDetailResponse:
        inquiry = await self.wallet_repo.get_sell_inquiry(inquiry_id)
        if not inquiry:
            raise NotFoundException("Transaction not found")
        user = await self.wallet_repo.get_wallet_user(inquiry.user_id)
        if not user:
            raise NotFoundException("User not found")

        await self._log_wallet_view(
            admin_user_id,
            user.id,
            action=audit_actions.WALLET_TRANSACTION_VIEW,
            metadata={"transaction_id": txn_id, "type": "SELL"},
        )

        history = [
            WalletStatusHistoryItem(
                status="pending",
                occurred_at=inquiry.created_at,
                note="Sell inquiry submitted",
            )
        ]
        if inquiry.responded_at:
            history.append(
                WalletStatusHistoryItem(
                    status=inquiry.status,
                    occurred_at=inquiry.responded_at,
                    note=inquiry.admin_response,
                )
            )

        return WalletTransactionDetailResponse(
            id=txn_id,
            user_id=user.id,
            user_name=_user_display_name(user),
            user_email=user.email,
            user_mobile=inquiry.mobile_number,
            occurred_at=inquiry.created_at,
            transaction_type="SELL",
            metal="GOLD",
            quantity_grams=None,
            amount_inr=None,
            status=inquiry.status,
            reference_id=str(inquiry.id),
            sell_details=WalletSellDetails(
                inquiry_id=inquiry.id,
                message=inquiry.message,
                admin_response=inquiry.admin_response,
                responded_at=inquiry.responded_at,
            ),
            status_history=history,
            admin_notes=inquiry.admin_response,
        )

    async def _detail_from_referral(
        self, reward_id: uuid.UUID, txn_id: str, admin_user_id: uuid.UUID
    ) -> WalletTransactionDetailResponse:
        reward = await self.wallet_repo.get_referral_reward(reward_id)
        if not reward:
            raise NotFoundException("Transaction not found")
        user = await self.wallet_repo.get_wallet_user(reward.referrer_id)
        if not user:
            raise NotFoundException("User not found")

        await self._log_wallet_view(
            admin_user_id,
            user.id,
            action=audit_actions.WALLET_TRANSACTION_VIEW,
            metadata={"transaction_id": txn_id, "type": "REFERRAL"},
        )

        return WalletTransactionDetailResponse(
            id=txn_id,
            user_id=user.id,
            user_name=_user_display_name(user),
            user_email=user.email,
            user_mobile=user.mobile_number,
            occurred_at=reward.created_at,
            transaction_type="REFERRAL",
            metal="GOLD",
            quantity_grams=reward.scheme_grams,
            amount_inr=reward.reward_inr,
            total_amount_inr=reward.reward_inr,
            status="completed",
            reference_id=str(reward.id),
            referral_details=WalletReferralDetails(
                referee_id=reward.referee_id,
                scheme_grams=reward.scheme_grams,
                reward_inr=reward.reward_inr,
            ),
            status_history=[
                WalletStatusHistoryItem(
                    status="completed",
                    occurred_at=reward.created_at,
                    note="Referral reward credited to INR wallet",
                )
            ],
        )

    async def _detail_from_savings(
        self, user_id: uuid.UUID, txn_id: str, admin_user_id: uuid.UUID
    ) -> WalletTransactionDetailResponse:
        user = await self.wallet_repo.get_wallet_user(user_id)
        if not user or not user.gold_scheme_started_at:
            raise NotFoundException("Transaction not found")

        await self._log_wallet_view(
            admin_user_id,
            user.id,
            action=audit_actions.WALLET_TRANSACTION_VIEW,
            metadata={"transaction_id": txn_id, "type": "SAVINGS"},
        )

        return WalletTransactionDetailResponse(
            id=txn_id,
            user_id=user.id,
            user_name=_user_display_name(user),
            user_email=user.email,
            user_mobile=user.mobile_number,
            occurred_at=user.gold_scheme_started_at,
            transaction_type="SAVINGS",
            metal="GOLD",
            quantity_grams=user.gold_scheme_target_grams,
            status=user.gold_scheme_status,
            reference_id=f"scheme-{user.gold_scheme_target_grams}g",
            savings_details=WalletSavingsDetails(
                target_grams=user.gold_scheme_target_grams or Decimal("0"),
                scheme_status=user.gold_scheme_status,
                started_at=user.gold_scheme_started_at,
            ),
            status_history=[
                WalletStatusHistoryItem(
                    status=user.gold_scheme_status,
                    occurred_at=user.gold_scheme_started_at,
                    note="Gold savings scheme selected",
                )
            ],
        )
