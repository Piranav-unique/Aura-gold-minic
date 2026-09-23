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


class AdminPaymentItem(BaseModel):
  id: UUID
  razorpay_order_id: str
  razorpay_payment_id: Optional[str] = None
  bank_rrn: Optional[str] = None
  payment_method: Optional[str] = None
  customer_name: Optional[str] = None
  customer_mobile: Optional[str] = None
  customer_email: Optional[str] = None
  metal: str
  grams: Decimal
  amount_inr: Decimal
  status: str
  failure_reason: Optional[str] = None
  created_at: datetime
  paid_at: Optional[datetime] = None
  gst_percent: Optional[Decimal] = None
  metal_value_inr: Optional[Decimal] = None
  gst_amount_inr: Optional[Decimal] = None
  razorpay_fee_inr: Optional[Decimal] = None
  merchant_settlement_inr: Optional[Decimal] = None


class AdminPaymentSummary(BaseModel):
  total_captured_revenue: Decimal
  total_captured_count: int
  total_pending_count: int
  total_failed_count: int
  today_captured_revenue: Decimal
  today_captured_count: int
  last_synced_at: Optional[datetime] = None


class AdminPaymentListResponse(BaseModel):
  items: List[AdminPaymentItem]
  summary: AdminPaymentSummary
  total: int
  skip: int
  limit: int


class RazorpaySyncAllResponse(BaseModel):
  synced: bool
  total_inspected: int
  updated_orders: int
  created_orders: int
  synced_at: datetime
  summary: AdminPaymentSummary


class CustomerPaymentSummary(BaseModel):
  mobile: str
  name: Optional[str] = None
  email: Optional[str] = None
  total_paid_inr: Decimal
  success_count: int
  total_grams: Decimal = Decimal("0")
