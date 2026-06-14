import uuid
from datetime import datetime
from decimal import Decimal
from typing import Literal, Optional

from pydantic import BaseModel, Field

InventoryCategory = Literal["gold_bar", "gold_coin", "gold_ornament", "raw_gold"]
InventoryStatus = Literal["active", "inactive", "discontinued"]
InventorySortField = Literal[
    "item_name",
    "item_category",
    "stock_quantity",
    "current_value",
    "purchase_price",
    "status",
    "created_at",
]
MovementType = Literal["stock_in", "stock_out", "adjustment"]
SortOrder = Literal["asc", "desc"]


class InventoryItemCreate(BaseModel):
    item_name: str = Field(..., min_length=1, max_length=200)
    item_category: InventoryCategory
    weight: Decimal = Field(..., gt=0)
    purity: Decimal = Field(..., gt=0, le=100)
    purchase_price: Decimal = Field(..., ge=0)
    current_value: Decimal = Field(..., ge=0)
    stock_quantity: int = Field(default=0, ge=0)
    reorder_level: int = Field(default=5, ge=0)
    supplier_id: Optional[uuid.UUID] = None
    status: InventoryStatus = "active"
    notes: Optional[str] = None


class InventoryItemUpdate(BaseModel):
    item_name: Optional[str] = Field(None, min_length=1, max_length=200)
    item_category: Optional[InventoryCategory] = None
    weight: Optional[Decimal] = Field(None, gt=0)
    purity: Optional[Decimal] = Field(None, gt=0, le=100)
    purchase_price: Optional[Decimal] = Field(None, ge=0)
    current_value: Optional[Decimal] = Field(None, ge=0)
    reorder_level: Optional[int] = Field(None, ge=0)
    supplier_id: Optional[uuid.UUID] = None
    status: Optional[InventoryStatus] = None
    notes: Optional[str] = None


class InventoryItemResponse(BaseModel):
    id: uuid.UUID
    item_name: str
    item_category: str
    weight: Decimal
    purity: Decimal
    purchase_price: Decimal
    current_value: Decimal
    stock_quantity: int
    reorder_level: int
    supplier_id: Optional[uuid.UUID] = None
    supplier_name: Optional[str] = None
    status: str
    notes: Optional[str] = None
    is_low_stock: bool = False
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}

    @classmethod
    def from_model(cls, item) -> "InventoryItemResponse":
        return cls(
            id=item.id,
            item_name=item.item_name,
            item_category=item.item_category,
            weight=item.weight,
            purity=item.purity,
            purchase_price=item.purchase_price,
            current_value=item.current_value,
            stock_quantity=item.stock_quantity,
            reorder_level=item.reorder_level,
            supplier_id=item.supplier_id,
            supplier_name=item.supplier.name if item.supplier else None,
            status=item.status,
            notes=item.notes,
            is_low_stock=item.stock_quantity <= item.reorder_level,
            created_at=item.created_at,
            updated_at=item.updated_at,
        )


class StockInRequest(BaseModel):
    quantity: int = Field(..., gt=0)
    reference: Optional[str] = Field(None, max_length=100)
    notes: Optional[str] = None
    supplier_id: Optional[uuid.UUID] = None


class StockOutRequest(BaseModel):
    quantity: int = Field(..., gt=0)
    reference: Optional[str] = Field(None, max_length=100)
    notes: Optional[str] = None


class StockAdjustRequest(BaseModel):
    new_quantity: int = Field(..., ge=0)
    reason: Optional[str] = Field(None, max_length=200)
    notes: Optional[str] = None


class StockMovementResponse(BaseModel):
    id: uuid.UUID
    inventory_item_id: uuid.UUID
    item_name: Optional[str] = None
    movement_type: str
    quantity_change: int
    quantity_before: int
    quantity_after: int
    reference: Optional[str] = None
    notes: Optional[str] = None
    supplier_id: Optional[uuid.UUID] = None
    performed_by: Optional[uuid.UUID] = None
    created_at: datetime

    model_config = {"from_attributes": True}

    @classmethod
    def from_model(
        cls, movement, *, item_name: Optional[str] = None
    ) -> "StockMovementResponse":
        resolved_name = item_name
        if resolved_name is None:
            item = movement.__dict__.get("inventory_item")
            if item is not None:
                resolved_name = item.item_name
        return cls(
            id=movement.id,
            inventory_item_id=movement.inventory_item_id,
            item_name=resolved_name,
            movement_type=movement.movement_type,
            quantity_change=movement.quantity_change,
            quantity_before=movement.quantity_before,
            quantity_after=movement.quantity_after,
            reference=movement.reference,
            notes=movement.notes,
            supplier_id=movement.supplier_id,
            performed_by=movement.performed_by,
            created_at=movement.created_at,
        )


class InventoryMetricsResponse(BaseModel):
    total_stock: int
    inventory_value: Decimal
    low_stock_count: int
    low_stock_items: list[InventoryItemResponse] = Field(default_factory=list)
