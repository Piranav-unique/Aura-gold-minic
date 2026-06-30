from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import Literal, Optional
from uuid import UUID

from pydantic import BaseModel, Field

WalletTransactionType = Literal["BUY", "SELL", "REFERRAL", "SAVINGS", "ADJUSTMENT"]
WalletMetalType = Literal["GOLD", "SILVER"]
WalletTransactionStatus = Literal[
    "created", "paid", "failed", "pending", "responded", "closed", "completed", "active"
]


class WalletUserSearchItem(BaseModel):
    id: UUID
    full_name: str
    email: str
    mobile_number: Optional[str] = None
    kyc_status: str
    kyc_aadhaar_last4: Optional[str] = None
    kyc_pan_last4: Optional[str] = None
    is_active: bool
    gold_balance_grams: Decimal
    silver_balance_grams: Decimal
    wallet_balance_inr: Decimal
    created_at: datetime


class WalletUserSearchResponse(BaseModel):
    items: list[WalletUserSearchItem]
    total: int
    skip: int
    limit: int


class WalletSummary(BaseModel):
    gold_balance_grams: Decimal
    silver_balance_grams: Decimal
    total_inr_invested: Decimal
    total_bought_grams: Decimal
    total_sold_grams: Decimal = Decimal("0")
    pending_sell_inquiries: int = 0
    referral_reward_inr: Decimal = Decimal("0")
    referral_reward_grams: Decimal = Decimal("0")
    savings_scheme_target_grams: Optional[Decimal] = None
    savings_scheme_status: str = "not_selected"
    wallet_balance_inr: Decimal = Decimal("0")


class WalletUserDetailResponse(BaseModel):
    id: UUID
    full_name: str
    email: str
    mobile_number: Optional[str] = None
    kyc_status: str
    kyc_aadhaar_last4: Optional[str] = None
    kyc_pan_last4: Optional[str] = None
    created_at: datetime
    is_active: bool
    is_deleted: bool = False
    wallet: WalletSummary


class WalletTransactionItem(BaseModel):
    id: str
    user_id: UUID
    user_name: Optional[str] = None
    user_mobile: Optional[str] = None
    occurred_at: datetime
    transaction_type: WalletTransactionType
    metal: Optional[WalletMetalType] = None
    quantity_grams: Optional[Decimal] = None
    amount_inr: Optional[Decimal] = None
    status: str
    reference_id: Optional[str] = None


class WalletTransactionListResponse(BaseModel):
    items: list[WalletTransactionItem]
    total: int
    skip: int
    limit: int


class WalletStatusHistoryItem(BaseModel):
    status: str
    occurred_at: datetime
    note: Optional[str] = None


class WalletPaymentDetails(BaseModel):
    razorpay_order_id: Optional[str] = None
    razorpay_payment_id: Optional[str] = None
    rate_per_gram: Optional[Decimal] = None
    gst_percent: Optional[Decimal] = None
    gst_amount_inr: Optional[Decimal] = None
    metal_value_inr: Optional[Decimal] = None
    razorpay_fee_inr: Optional[Decimal] = None
    merchant_settlement_inr: Optional[Decimal] = None


class WalletSellDetails(BaseModel):
    inquiry_id: UUID
    message: Optional[str] = None
    admin_response: Optional[str] = None
    responded_at: Optional[datetime] = None


class WalletReferralDetails(BaseModel):
    referee_id: UUID
    scheme_grams: Decimal
    reward_inr: Decimal


class WalletSavingsDetails(BaseModel):
    target_grams: Decimal
    scheme_status: str
    started_at: Optional[datetime] = None


class WalletTransactionDetailResponse(BaseModel):
    id: str
    user_id: UUID
    user_name: str
    user_email: str
    user_mobile: Optional[str] = None
    occurred_at: datetime
    transaction_type: WalletTransactionType
    metal: Optional[WalletMetalType] = None
    quantity_grams: Optional[Decimal] = None
    amount_inr: Optional[Decimal] = None
    rate_per_gram: Optional[Decimal] = None
    gst_amount_inr: Optional[Decimal] = None
    platform_fee_inr: Optional[Decimal] = None
    total_amount_inr: Optional[Decimal] = None
    status: str
    reference_id: Optional[str] = None
    payment_details: Optional[WalletPaymentDetails] = None
    sell_details: Optional[WalletSellDetails] = None
    referral_details: Optional[WalletReferralDetails] = None
    savings_details: Optional[WalletSavingsDetails] = None
    status_history: list[WalletStatusHistoryItem] = Field(default_factory=list)
    admin_notes: Optional[str] = None
