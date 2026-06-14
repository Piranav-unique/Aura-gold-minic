import time
import uuid
from datetime import datetime, timezone
from typing import Optional, Tuple

from app.core import audit_actions
from app.core.config import settings
from app.core.exceptions import NotFoundException, ValidationException
from app.models.inventory_item import InventoryItem
from app.models.stock_movement import StockMovement
from app.repositories.inventory_item import InventoryItemRepository
from app.repositories.stock_movement import StockMovementRepository
from app.repositories.supplier import SupplierRepository
from app.schemas.inventory import (
    InventoryItemCreate,
    InventoryItemResponse,
    InventoryItemUpdate,
    InventoryMetricsResponse,
    StockAdjustRequest,
    StockInRequest,
    StockOutRequest,
)
from app.services.audit import AuditService

_metrics_cache: tuple[float, InventoryMetricsResponse] | None = None


def _invalidate_metrics_cache() -> None:
    global _metrics_cache
    _metrics_cache = None


class InventoryService:
    """Business logic for inventory CRUD and stock movements."""

    def __init__(
        self,
        inventory_repo: InventoryItemRepository,
        movement_repo: StockMovementRepository,
        supplier_repo: SupplierRepository,
        audit_service: Optional[AuditService] = None,
    ):
        self.inventory_repo = inventory_repo
        self.movement_repo = movement_repo
        self.supplier_repo = supplier_repo
        self.audit_service = audit_service

    async def _validate_supplier(self, supplier_id: Optional[uuid.UUID]) -> None:
        if supplier_id is None:
            return
        supplier = await self.supplier_repo.get_active(supplier_id)
        if not supplier:
            raise ValidationException("Supplier not found")
        if not supplier.is_active:
            raise ValidationException("Supplier is inactive")

    @staticmethod
    def _ensure_active_for_stock(item: InventoryItem) -> None:
        if item.status != "active":
            raise ValidationException(
                f"Stock operations are only allowed on active items "
                f"(current status: {item.status})"
            )

    async def _get_item_for_stock_update(self, item_id: uuid.UUID) -> InventoryItem:
        item = await self.inventory_repo.get_active_for_update(item_id)
        if not item:
            raise NotFoundException("Inventory item not found")
        self._ensure_active_for_stock(item)
        return item

    async def _log_audit(
        self,
        *,
        performing_user_id: Optional[uuid.UUID],
        action: str,
        entity_type: str,
        entity_id: str,
        metadata: dict,
        commit: bool,
    ) -> None:
        if not self.audit_service:
            return
        await self.audit_service.log_action(
            user_id=performing_user_id,
            action=action,
            entity_type=entity_type,
            entity_id=entity_id,
            metadata=metadata,
            commit=commit,
        )

    async def _apply_stock_change(
        self,
        item: InventoryItem,
        *,
        movement_type: str,
        quantity_change: int,
        quantity_before: int,
        quantity_after: int,
        performing_user_id: Optional[uuid.UUID],
        reference: Optional[str] = None,
        notes: Optional[str] = None,
        supplier_id: Optional[uuid.UUID] = None,
        audit_action: str,
        commit: bool = True,
    ) -> StockMovement:
        movement = StockMovement(
            inventory_item_id=item.id,
            movement_type=movement_type,
            quantity_change=quantity_change,
            quantity_before=quantity_before,
            quantity_after=quantity_after,
            reference=reference,
            notes=notes,
            supplier_id=supplier_id,
            performed_by=performing_user_id,
        )
        self.movement_repo.db.add(movement)
        item.stock_quantity = quantity_after

        audit_metadata = {
            "inventory_item_id": str(item.id),
            "item_name": item.item_name,
            "movement_type": movement_type,
            "quantity_change": quantity_change,
            "quantity_before": quantity_before,
            "quantity_after": quantity_after,
            "reference": reference,
            "is_low_stock": quantity_after <= item.reorder_level,
        }
        await self._log_audit(
            performing_user_id=performing_user_id,
            action=audit_action,
            entity_type="StockMovement",
            entity_id=str(movement.id),
            metadata=audit_metadata,
            commit=False,
        )

        if commit:
            await self.movement_repo.db.commit()
            await self.movement_repo.db.refresh(movement)
            _invalidate_metrics_cache()
        return movement

    async def apply_transaction_stock_line(
        self,
        inventory_item_id: uuid.UUID,
        quantity: int,
        stock_direction: str,
        reference: str,
        performing_user_id: Optional[uuid.UUID] = None,
        *,
        commit: bool = False,
        reverse: bool = False,
    ) -> None:
        """Apply or reverse stock for a transaction line without committing by default."""
        direction = stock_direction
        if reverse:
            direction = "in" if stock_direction == "out" else "out"

        item = await self._get_item_for_stock_update(inventory_item_id)
        before = item.stock_quantity

        if direction == "out":
            if quantity > before:
                raise ValidationException(
                    f"Insufficient stock for '{item.item_name}'. "
                    f"Available: {before}, requested: {quantity}"
                )
            after = before - quantity
            quantity_change = -quantity
            movement_type = "stock_out"
            audit_action = audit_actions.STOCK_MOVEMENT_OUT
        else:
            after = before + quantity
            quantity_change = quantity
            movement_type = "stock_in"
            audit_action = audit_actions.STOCK_MOVEMENT_IN

        await self._apply_stock_change(
            item,
            movement_type=movement_type,
            quantity_change=quantity_change,
            quantity_before=before,
            quantity_after=after,
            performing_user_id=performing_user_id,
            reference=reference,
            notes=f"Transaction stock {'reversal' if reverse else 'application'}",
            audit_action=audit_action,
            commit=commit,
        )
        if commit:
            _invalidate_metrics_cache()

    async def create_item(
        self,
        item_in: InventoryItemCreate,
        performing_user_id: Optional[uuid.UUID] = None,
    ) -> InventoryItem:
        await self._validate_supplier(item_in.supplier_id)
        initial_stock = item_in.stock_quantity
        data = item_in.model_dump()
        data["stock_quantity"] = 0

        item = await self.inventory_repo.create(data, commit=False)
        await self.inventory_repo.db.flush()

        movement = None
        if initial_stock > 0:
            movement = StockMovement(
                inventory_item_id=item.id,
                movement_type="stock_in",
                quantity_change=initial_stock,
                quantity_before=0,
                quantity_after=initial_stock,
                reference="Opening balance",
                notes="Initial stock recorded on item creation",
                supplier_id=item_in.supplier_id,
                performed_by=performing_user_id,
            )
            self.movement_repo.db.add(movement)
            item.stock_quantity = initial_stock

        await self._log_audit(
            performing_user_id=performing_user_id,
            action=audit_actions.INVENTORY_CREATE,
            entity_type="InventoryItem",
            entity_id=str(item.id),
            metadata={
                "item_name": item.item_name,
                "item_category": item.item_category,
                "stock_quantity": initial_stock,
            },
            commit=False,
        )

        if initial_stock > 0:
            await self._log_audit(
                performing_user_id=performing_user_id,
                action=audit_actions.STOCK_MOVEMENT_IN,
                entity_type="StockMovement",
                entity_id=str(movement.id),
                metadata={
                    "inventory_item_id": str(item.id),
                    "item_name": item.item_name,
                    "movement_type": "stock_in",
                    "quantity_change": initial_stock,
                    "quantity_before": 0,
                    "quantity_after": initial_stock,
                    "reference": "Opening balance",
                    "is_low_stock": initial_stock <= item.reorder_level,
                },
                commit=False,
            )

        await self.inventory_repo.db.commit()
        _invalidate_metrics_cache()
        return await self.inventory_repo.get_active(item.id)

    async def get_item_by_id(self, item_id: uuid.UUID) -> InventoryItem:
        item = await self.inventory_repo.get_active(item_id)
        if not item:
            raise NotFoundException("Inventory item not found")
        return item

    async def list_items(
        self,
        skip: int = 0,
        limit: int = 100,
        search: Optional[str] = None,
        item_category: Optional[str] = None,
        status: Optional[str] = None,
        supplier_id: Optional[str] = None,
        low_stock_only: bool = False,
        sort_by: str = "created_at",
        sort_order: str = "desc",
    ) -> Tuple[list[InventoryItem], int]:
        return await self.inventory_repo.list_items_with_total(
            skip=skip,
            limit=limit,
            search=search,
            item_category=item_category,
            status=status,
            supplier_id=supplier_id,
            low_stock_only=low_stock_only,
            sort_by=sort_by,
            sort_order=sort_order,
        )

    async def update_item(
        self,
        item_id: uuid.UUID,
        item_in: InventoryItemUpdate,
        performing_user_id: Optional[uuid.UUID] = None,
    ) -> InventoryItem:
        item = await self.inventory_repo.get_active(item_id)
        if not item:
            raise NotFoundException("Inventory item not found")

        update_data = item_in.model_dump(exclude_unset=True)
        if "supplier_id" in update_data:
            await self._validate_supplier(update_data["supplier_id"])

        for field, value in update_data.items():
            setattr(item, field, value)

        await self._log_audit(
            performing_user_id=performing_user_id,
            action=audit_actions.INVENTORY_UPDATE,
            entity_type="InventoryItem",
            entity_id=str(item.id),
            metadata={"updated_fields": list(update_data.keys())},
            commit=False,
        )
        await self.inventory_repo.db.commit()
        _invalidate_metrics_cache()
        return await self.inventory_repo.get_active(item.id)

    async def delete_item(
        self,
        item_id: uuid.UUID,
        performing_user_id: Optional[uuid.UUID] = None,
    ) -> bool:
        item = await self.inventory_repo.get_active(item_id)
        if not item:
            raise NotFoundException("Inventory item not found")

        item.is_deleted = True
        item.deleted_at = datetime.now(timezone.utc)

        await self._log_audit(
            performing_user_id=performing_user_id,
            action=audit_actions.INVENTORY_DELETE,
            entity_type="InventoryItem",
            entity_id=str(item_id),
            metadata={"item_name": item.item_name},
            commit=False,
        )
        await self.inventory_repo.db.commit()
        _invalidate_metrics_cache()
        return True

    async def stock_in(
        self,
        item_id: uuid.UUID,
        request: StockInRequest,
        performing_user_id: Optional[uuid.UUID] = None,
    ) -> InventoryItem:
        item = await self._get_item_for_stock_update(item_id)
        if request.supplier_id:
            await self._validate_supplier(request.supplier_id)

        before = item.stock_quantity
        after = before + request.quantity
        await self._apply_stock_change(
            item,
            movement_type="stock_in",
            quantity_change=request.quantity,
            quantity_before=before,
            quantity_after=after,
            performing_user_id=performing_user_id,
            reference=request.reference,
            notes=request.notes,
            supplier_id=request.supplier_id,
            audit_action=audit_actions.STOCK_MOVEMENT_IN,
        )
        return await self.inventory_repo.get_active(item_id)

    async def stock_out(
        self,
        item_id: uuid.UUID,
        request: StockOutRequest,
        performing_user_id: Optional[uuid.UUID] = None,
    ) -> InventoryItem:
        item = await self._get_item_for_stock_update(item_id)
        if request.quantity > item.stock_quantity:
            raise ValidationException(
                f"Insufficient stock. Available: {item.stock_quantity}, "
                f"requested: {request.quantity}"
            )

        before = item.stock_quantity
        after = before - request.quantity
        await self._apply_stock_change(
            item,
            movement_type="stock_out",
            quantity_change=-request.quantity,
            quantity_before=before,
            quantity_after=after,
            performing_user_id=performing_user_id,
            reference=request.reference,
            notes=request.notes,
            audit_action=audit_actions.STOCK_MOVEMENT_OUT,
        )
        return await self.inventory_repo.get_active(item_id)

    async def stock_adjust(
        self,
        item_id: uuid.UUID,
        request: StockAdjustRequest,
        performing_user_id: Optional[uuid.UUID] = None,
    ) -> InventoryItem:
        item = await self._get_item_for_stock_update(item_id)
        before = item.stock_quantity
        after = request.new_quantity
        change = after - before
        if change == 0:
            raise ValidationException("New quantity matches current stock")

        notes = request.notes
        if request.reason:
            notes = f"{request.reason}" + (f" — {notes}" if notes else "")

        await self._apply_stock_change(
            item,
            movement_type="adjustment",
            quantity_change=change,
            quantity_before=before,
            quantity_after=after,
            performing_user_id=performing_user_id,
            notes=notes,
            audit_action=audit_actions.STOCK_MOVEMENT_ADJUST,
        )
        return await self.inventory_repo.get_active(item_id)

    async def list_movements_for_item(
        self,
        item_id: uuid.UUID,
        skip: int = 0,
        limit: int = 50,
    ) -> Tuple[list[StockMovement], int]:
        await self.get_item_by_id(item_id)
        items = await self.movement_repo.list_for_item(item_id, skip=skip, limit=limit)
        total = await self.movement_repo.count_for_item(item_id)
        return items, total

    async def list_movements(
        self,
        skip: int = 0,
        limit: int = 50,
        inventory_item_id: Optional[uuid.UUID] = None,
        movement_type: Optional[str] = None,
    ) -> Tuple[list[StockMovement], int]:
        items = await self.movement_repo.list_movements(
            skip=skip,
            limit=limit,
            inventory_item_id=inventory_item_id,
            movement_type=movement_type,
        )
        total = await self.movement_repo.count_movements(
            inventory_item_id=inventory_item_id,
            movement_type=movement_type,
        )
        return items, total

    async def get_metrics(self, low_stock_limit: int = 10) -> InventoryMetricsResponse:
        global _metrics_cache
        now = time.monotonic()
        if (
            _metrics_cache is not None
            and (now - _metrics_cache[0]) < settings.INVENTORY_METRICS_CACHE_TTL_SECONDS
        ):
            return _metrics_cache[1]

        metrics = await self.inventory_repo.get_metrics()
        low_stock_items = await self.inventory_repo.list_low_stock(
            limit=low_stock_limit
        )
        result = InventoryMetricsResponse(
            total_stock=metrics["total_stock"],
            inventory_value=metrics["inventory_value"],
            low_stock_count=metrics["low_stock_count"],
            low_stock_items=[
                InventoryItemResponse.from_model(item) for item in low_stock_items
            ],
        )
        _metrics_cache = (now, result)
        return result

    async def list_low_stock(
        self, skip: int = 0, limit: int = 50
    ) -> Tuple[list[InventoryItem], int]:
        return await self.inventory_repo.list_items_with_total(
            skip=skip,
            limit=limit,
            low_stock_only=True,
            sort_by="stock_quantity",
            sort_order="asc",
        )
