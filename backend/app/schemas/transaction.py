import uuid
from datetime import datetime
from decimal import Decimal
from typing import Literal, Optional

from pydantic import BaseModel, Field, field_validator, model_validator

TransactionType = Literal["purchase", "sale", "return", "exchange"]
TransactionStatus = Literal["active", "cancelled"]
PaymentStatus = Literal["pending", "paid", "failed", "refunded"]
StockDirection = Literal["in", "out"]
TransactionSortField = Literal[
    "transaction_number",
    "transaction_type",
    "total_amount",
    "payment_status",
    "status",
    "created_at",
]
SortOrder = Literal["asc", "desc"]


class TransactionLineCreate(BaseModel):
    inventory_item_id: uuid.UUID
    quantity: int = Field(..., gt=0)
    unit_price: Decimal = Field(..., ge=0)
    stock_direction: Optional[StockDirection] = None

    @field_validator("unit_price")
    @classmethod
    def round_unit_price(cls, value: Decimal) -> Decimal:
        return value.quantize(Decimal("0.01"))


class TransactionLineResponse(BaseModel):
    id: uuid.UUID
    inventory_item_id: uuid.UUID
    item_name: str
    quantity: int
    unit_price: Decimal
    line_total: Decimal
    stock_direction: str

    model_config = {"from_attributes": True}


class TransactionCreate(BaseModel):
    transaction_type: TransactionType
    customer_id: Optional[uuid.UUID] = None
    payment_status: PaymentStatus = "pending"
    tax_amount: Decimal = Field(default=Decimal("0"), ge=0)
    notes: Optional[str] = None
    lines: list[TransactionLineCreate] = Field(..., min_length=1)

    @field_validator("tax_amount")
    @classmethod
    def round_tax(cls, value: Decimal) -> Decimal:
        return value.quantize(Decimal("0.01"))

    @model_validator(mode="after")
    def validate_customer_and_lines(self) -> "TransactionCreate":
        if self.payment_status != "pending":
            raise ValueError(
                "payment_status must be pending when creating a transaction; "
                "mark as paid via update after review"
            )
        if (
            self.transaction_type in ("sale", "return", "exchange")
            and not self.customer_id
        ):
            raise ValueError(
                "customer_id is required for sale, return, and exchange transactions"
            )
        if self.transaction_type == "exchange":
            for line in self.lines:
                if line.stock_direction is None:
                    raise ValueError(
                        "stock_direction is required on each line for exchange transactions"
                    )
        return self


class TransactionUpdate(BaseModel):
    customer_id: Optional[uuid.UUID] = None
    payment_status: Optional[PaymentStatus] = None
    tax_amount: Optional[Decimal] = Field(None, ge=0)
    notes: Optional[str] = None
    lines: Optional[list[TransactionLineCreate]] = None

    @field_validator("tax_amount")
    @classmethod
    def round_tax(cls, value: Optional[Decimal]) -> Optional[Decimal]:
        if value is None:
            return None
        return value.quantize(Decimal("0.01"))


class TransactionCancelRequest(BaseModel):
    reason: str = Field(..., min_length=1, max_length=255)


class TransactionCustomerSummary(BaseModel):
    id: uuid.UUID
    full_name: str
    mobile_number: str
    email: Optional[str] = None

    model_config = {"from_attributes": True}


class TransactionDetailResponse(BaseModel):
    id: uuid.UUID
    transaction_number: str
    transaction_type: str
    customer_id: Optional[uuid.UUID] = None
    customer: Optional[TransactionCustomerSummary] = None
    status: str
    payment_status: str
    subtotal: Decimal
    tax_amount: Decimal
    total_amount: Decimal
    invoice_number: Optional[str] = None
    receipt_number: Optional[str] = None
    stock_applied: bool
    notes: Optional[str] = None
    performed_by: Optional[uuid.UUID] = None
    cancelled_at: Optional[datetime] = None
    cancellation_reason: Optional[str] = None
    lines: list[TransactionLineResponse] = []
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}

    @classmethod
    def from_model(cls, txn) -> "TransactionDetailResponse":
        customer_summary = None
        if txn.customer:
            customer_summary = TransactionCustomerSummary(
                id=txn.customer.id,
                full_name=txn.customer.full_name,
                mobile_number=txn.customer.mobile_number,
                email=txn.customer.email,
            )
        return cls(
            id=txn.id,
            transaction_number=txn.transaction_number,
            transaction_type=txn.transaction_type,
            customer_id=txn.customer_id,
            customer=customer_summary,
            status=txn.status,
            payment_status=txn.payment_status,
            subtotal=txn.subtotal,
            tax_amount=txn.tax_amount,
            total_amount=txn.total_amount,
            invoice_number=txn.invoice_number,
            receipt_number=txn.receipt_number,
            stock_applied=txn.stock_applied,
            notes=txn.notes,
            performed_by=txn.performed_by,
            cancelled_at=txn.cancelled_at,
            cancellation_reason=txn.cancellation_reason,
            lines=[TransactionLineResponse.model_validate(line) for line in txn.lines],
            created_at=txn.created_at,
            updated_at=txn.updated_at,
        )


class TransactionDocumentLine(BaseModel):
    item_name: str
    quantity: int
    unit_price: Decimal
    line_total: Decimal
    stock_direction: str


class TransactionDocumentResponse(BaseModel):
    document_type: Literal["invoice", "receipt"]
    document_number: str
    transaction_id: uuid.UUID
    transaction_number: str
    transaction_type: str
    customer_name: Optional[str] = None
    customer_mobile: Optional[str] = None
    payment_status: str
    subtotal: Decimal
    tax_amount: Decimal
    total_amount: Decimal
    issued_at: datetime
    lines: list[TransactionDocumentLine]


class TopCustomerMetric(BaseModel):
    customer_id: uuid.UUID
    full_name: str
    revenue: Decimal
    transaction_count: int


class TransactionMetricsResponse(BaseModel):
    daily_revenue: Decimal
    monthly_revenue: Decimal
    top_customers: list[TopCustomerMetric]
