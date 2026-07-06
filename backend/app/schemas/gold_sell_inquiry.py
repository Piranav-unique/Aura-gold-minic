from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal
from typing import List, Optional

from pydantic import BaseModel, Field, field_validator

from app.schemas.auth import _normalize_mobile_input


class GoldSellInquiryCreate(BaseModel):
    name: str = Field(..., min_length=2, max_length=200)
    mobile_number: str = Field(..., min_length=10, max_length=15)
    quantity_grams: Decimal = Field(..., gt=0)
    message: str = Field(..., min_length=10, max_length=2000)
    bank_account_id: uuid.UUID

    @field_validator("name")
    @classmethod
    def strip_name(cls, value: str) -> str:
        return " ".join(value.strip().split())

    @field_validator("mobile_number")
    @classmethod
    def validate_mobile(cls, value: str) -> str:
        digits = _normalize_mobile_input(value)
        if len(digits) < 10:
            raise ValueError("Invalid mobile number")
        return digits

    @field_validator("message")
    @classmethod
    def strip_message(cls, value: str) -> str:
        return value.strip()


class GoldSellInquiryRespond(BaseModel):
    admin_response: str = Field(..., min_length=5, max_length=2000)
    status: str = Field(default="needs_info", pattern=r"^(needs_info|responded|closed)$")

    @field_validator("admin_response")
    @classmethod
    def strip_response(cls, value: str) -> str:
        return value.strip()


class GoldSellInquiryReject(BaseModel):
    rejection_reason: str = Field(..., min_length=5, max_length=2000)

    @field_validator("rejection_reason")
    @classmethod
    def strip_reason(cls, value: str) -> str:
        return value.strip()


class GoldSellInquiryApprove(BaseModel):
    confirm: bool = Field(default=True)


class SellPayoutBreakdown(BaseModel):
    sell_rate_per_gram: Decimal
    quantity_grams: Decimal
    gross_amount_inr: Decimal
    platform_charge_inr: Decimal
    tax_amount_inr: Decimal
    net_payable_inr: Decimal


class GoldSellInquiryResponse(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID
    name: str
    mobile_number: str
    quantity_grams: Optional[Decimal] = None
    message: str
    status: str
    admin_response: Optional[str] = None
    responded_by_user_id: Optional[uuid.UUID] = None
    responded_at: Optional[datetime] = None
    sell_rate_per_gram: Optional[Decimal] = None
    gross_amount_inr: Optional[Decimal] = None
    platform_charge_inr: Optional[Decimal] = None
    tax_amount_inr: Optional[Decimal] = None
    net_payable_inr: Optional[Decimal] = None
    payment_method: Optional[str] = None
    payment_destination: Optional[str] = None
    reference_number: Optional[str] = None
    rejection_reason: Optional[str] = None
    approved_by_user_id: Optional[uuid.UUID] = None
    approved_at: Optional[datetime] = None
    razorpay_payout_id: Optional[str] = None
    payout_status: Optional[str] = None
    payout_failure_reason: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    user_email: Optional[str] = None
    gold_balance_grams: Optional[Decimal] = None
    gold_scheme_status: Optional[str] = None
    kyc_status: Optional[str] = None

    model_config = {"from_attributes": True}


class GoldSellInquiryListResponse(BaseModel):
    items: List[GoldSellInquiryResponse]
    total: int
    skip: int
    limit: int


class GoldSellInquiryDetailResponse(GoldSellInquiryResponse):
    user_email: Optional[str] = None
    kyc_status: Optional[str] = None
    kyc_aadhaar_last4: Optional[str] = None
    kyc_pan_last4: Optional[str] = None
    gold_balance_grams: Decimal = Decimal("0")
    silver_balance_grams: Decimal = Decimal("0")
    gold_invested_inr: Decimal = Decimal("0")
    gold_scheme_status: Optional[str] = None
    gold_scheme_target_grams: Optional[Decimal] = None
    gold_scheme_started_at: Optional[datetime] = None
    scheme_completed: bool = False
    scheme_warning: Optional[str] = None
    payout: Optional[SellPayoutBreakdown] = None
    user_payment_method: Optional[str] = None
    user_payment_destination: Optional[str] = None
