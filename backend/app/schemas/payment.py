from decimal import Decimal
from typing import List, Optional
from uuid import UUID
from datetime import datetime

from pydantic import BaseModel, Field, field_validator


class CreatePaymentOrderRequest(BaseModel):
  metal: str = Field(default="gold", pattern=r"^(gold|silver)$")
  grams: Optional[Decimal] = Field(default=None, gt=0)
  amount_inr: Optional[Decimal] = Field(default=None, gt=0)

  @field_validator("metal")
  @classmethod
  def normalize_metal(cls, value: str) -> str:
    return value.lower()


class CreatePaymentOrderResponse(BaseModel):
  order_id: str
  key_id: str
  amount_paise: int
  amount_inr: Decimal
  grams: Decimal
  rate_per_gram: Decimal
  metal: str
  currency: str = "INR"
  user_email: str
  user_name: str


class SyncPaymentRequest(BaseModel):
  razorpay_order_id: str


class SyncPaymentResponse(BaseModel):
  status: str
  message: str
  metal: Optional[str] = None
  grams_purchased: Optional[Decimal] = None
  amount_inr: Optional[Decimal] = None
  gold_savings_grams: Optional[Decimal] = None
  silver_savings_grams: Optional[Decimal] = None
  gold_invested_inr: Optional[Decimal] = None
  silver_invested_inr: Optional[Decimal] = None


class VerifyPaymentRequest(BaseModel):
  razorpay_order_id: str
  razorpay_payment_id: str
  razorpay_signature: str


class VerifyPaymentResponse(BaseModel):
  status: str
  metal: str
  grams_purchased: Decimal
  amount_inr: Decimal
  gold_savings_grams: Decimal
  silver_savings_grams: Decimal
  gold_invested_inr: Decimal = Decimal("0")
  silver_invested_inr: Decimal = Decimal("0")
  message: str


class PaymentSettlementItem(BaseModel):
  id: UUID
  user_email: str
  metal: str
  gross_amount_inr: Decimal
  gst_percent: Decimal
  metal_value_inr: Decimal
  gst_amount_inr: Decimal
  razorpay_fee_inr: Decimal
  merchant_settlement_inr: Decimal
  grams: Decimal
  paid_at: datetime


class PaymentSettlementListResponse(BaseModel):
  items: List[PaymentSettlementItem]
  total: int
  skip: int
  limit: int
