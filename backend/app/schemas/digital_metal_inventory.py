from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal
from typing import Literal, Optional

from pydantic import BaseModel, Field

MetalType = Literal["gold", "silver"]
StockStatus = Literal["available", "low_stock", "out_of_stock"]


def compute_stock_status(
    available: Decimal, threshold: Decimal
) -> StockStatus:
    if available <= Decimal("0"):
        return "out_of_stock"
    if available <= threshold:
        return "low_stock"
    return "available"


class DigitalMetalInventoryResponse(BaseModel):
    id: uuid.UUID
    metal_type: str
    metal_label: str
    total_weight_grams: Decimal
    used_weight_grams: Decimal
    available_weight_grams: Decimal
    low_stock_threshold_grams: Decimal
    stock_status: StockStatus
    updated_by: Optional[uuid.UUID] = None
    updated_at: datetime

    @classmethod
    def from_model(cls, row) -> "DigitalMetalInventoryResponse":
        available = row.available_weight_grams
        return cls(
            id=row.id,
            metal_type=row.metal_type,
            metal_label=row.metal_type.upper(),
            total_weight_grams=row.total_weight_grams,
            used_weight_grams=row.used_weight_grams,
            available_weight_grams=available,
            low_stock_threshold_grams=row.low_stock_threshold_grams,
            stock_status=compute_stock_status(available, row.low_stock_threshold_grams),
            updated_by=row.updated_by,
            updated_at=row.updated_at,
        )


class DigitalMetalInventoryListResponse(BaseModel):
    items: list[DigitalMetalInventoryResponse]


class DigitalMetalInventoryUpdate(BaseModel):
    total_weight_grams: Decimal = Field(..., ge=0)
    low_stock_threshold_grams: Decimal = Field(..., ge=0)


class DigitalMetalInventoryMovementResponse(BaseModel):
    id: uuid.UUID
    metal_type: str
    metal_label: str
    movement_type: str
    grams_delta: Decimal
    total_weight_before: Decimal
    used_weight_before: Decimal
    total_weight_after: Decimal
    used_weight_after: Decimal
    available_weight_after: Decimal
    payment_order_id: Optional[uuid.UUID] = None
    user_id: Optional[uuid.UUID] = None
    performed_by: Optional[uuid.UUID] = None
    notes: Optional[str] = None
    created_at: datetime

    @classmethod
    def from_model(cls, row) -> "DigitalMetalInventoryMovementResponse":
        available_after = Decimal(str(row.total_weight_after)) - Decimal(
            str(row.used_weight_after)
        )
        return cls(
            id=row.id,
            metal_type=row.metal_type,
            metal_label=row.metal_type.upper(),
            movement_type=row.movement_type,
            grams_delta=row.grams_delta,
            total_weight_before=row.total_weight_before,
            used_weight_before=row.used_weight_before,
            total_weight_after=row.total_weight_after,
            used_weight_after=row.used_weight_after,
            available_weight_after=available_after,
            payment_order_id=row.payment_order_id,
            user_id=row.user_id,
            performed_by=row.performed_by,
            notes=row.notes,
            created_at=row.created_at,
        )


class DigitalMetalInventoryMovementListResponse(BaseModel):
    items: list[DigitalMetalInventoryMovementResponse]
    total: int
    skip: int
    limit: int


class DigitalMetalInventoryAlertResponse(BaseModel):
    metal_type: str
    metal_label: str
    stock_status: StockStatus
    available_weight_grams: Decimal
    low_stock_threshold_grams: Decimal
    title: str
    message: str


class DigitalMetalInventoryAlertsResponse(BaseModel):
    items: list[DigitalMetalInventoryAlertResponse]
