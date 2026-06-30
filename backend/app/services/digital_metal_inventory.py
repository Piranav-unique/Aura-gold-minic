from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from typing import Optional

from app.core.config import settings
from app.core import audit_actions
from app.core.exceptions import NotFoundException, ValidationException
from app.core.logging import logger
from app.models.digital_metal_inventory import DigitalMetalInventory
from app.repositories.digital_metal_inventory import (
    DigitalMetalInventoryMovementRepository,
    DigitalMetalInventoryRepository,
)
from app.schemas.digital_metal_inventory import (
    DigitalMetalInventoryAlertResponse,
    DigitalMetalInventoryAlertsResponse,
    DigitalMetalInventoryListResponse,
    DigitalMetalInventoryMovementListResponse,
    DigitalMetalInventoryMovementResponse,
    DigitalMetalInventoryResponse,
    DigitalMetalInventoryUpdate,
    compute_stock_status,
)
from app.services.audit import AuditService
from app.services.notification import NotificationService


INSUFFICIENT_STOCK_MESSAGE = (
    "Gold is currently out of stock / insufficient stock. Please try again later."
)
INSUFFICIENT_SILVER_STOCK_MESSAGE = (
    "Silver is currently out of stock / insufficient stock. Please try again later."
)


class DigitalMetalInventoryService:
    """Platform digital metal stock that limits end-user purchases."""

    def __init__(
        self,
        inventory_repo: DigitalMetalInventoryRepository,
        movement_repo: DigitalMetalInventoryMovementRepository,
        audit_service: Optional[AuditService] = None,
        notification_service: Optional[NotificationService] = None,
    ):
        self.inventory_repo = inventory_repo
        self.movement_repo = movement_repo
        self.audit_service = audit_service
        self.notification_service = notification_service

    @staticmethod
    def _normalize_metal(metal: str) -> str:
        normalized = metal.lower().strip()
        if normalized not in {"gold", "silver"}:
            raise ValidationException("metal_type must be gold or silver")
        return normalized

    @staticmethod
    def _stock_error_message(metal: str) -> str:
        return (
            INSUFFICIENT_SILVER_STOCK_MESSAGE
            if metal == "silver"
            else INSUFFICIENT_STOCK_MESSAGE
        )

    async def list_metals(self) -> DigitalMetalInventoryListResponse:
        rows = await self.inventory_repo.list_all()
        return DigitalMetalInventoryListResponse(
            items=[DigitalMetalInventoryResponse.from_model(r) for r in rows]
        )

    async def get_metal(self, metal_type: str) -> DigitalMetalInventoryResponse:
        metal = self._normalize_metal(metal_type)
        row = await self.inventory_repo.get_by_metal(metal)
        if not row:
            raise NotFoundException(f"{metal.upper()} inventory not configured")
        return DigitalMetalInventoryResponse.from_model(row)

    async def update_metal(
        self,
        metal_type: str,
        payload: DigitalMetalInventoryUpdate,
        *,
        admin_user_id: uuid.UUID,
    ) -> DigitalMetalInventoryResponse:
        metal = self._normalize_metal(metal_type)
        row = await self.inventory_repo.get_by_metal_for_update(metal)
        if not row:
            raise NotFoundException(f"{metal.upper()} inventory not configured")

        new_total = Decimal(str(payload.total_weight_grams))
        new_threshold = Decimal(str(payload.low_stock_threshold_grams))
        used = Decimal(str(row.used_weight_grams or 0))

        if new_total < used:
            raise ValidationException(
                f"Total stock cannot be less than used stock ({used} g)."
            )

        total_before = Decimal(str(row.total_weight_grams))
        used_before = used
        row.total_weight_grams = new_total
        row.low_stock_threshold_grams = new_threshold
        row.updated_by = admin_user_id

        await self.movement_repo.create(
            {
                "id": uuid.uuid4(),
                "metal_type": metal,
                "movement_type": "admin_update",
                "grams_delta": new_total - total_before,
                "total_weight_before": total_before,
                "used_weight_before": used_before,
                "total_weight_after": new_total,
                "used_weight_after": used_before,
                "performed_by": admin_user_id,
                "notes": "Admin updated total stock and threshold",
            },
            commit=False,
        )

        if self.audit_service:
            await self.audit_service.log_action(
                user_id=admin_user_id,
                action=audit_actions.METAL_INVENTORY_UPDATE,
                entity_type="DigitalMetalInventory",
                entity_id=str(row.id),
                metadata={
                    "metal_type": metal,
                    "total_weight_grams": str(new_total),
                    "used_weight_grams": str(used_before),
                    "available_weight_grams": str(new_total - used_before),
                    "low_stock_threshold_grams": str(new_threshold),
                },
            )

        await self.inventory_repo.db.commit()
        await self.inventory_repo.db.refresh(row)
        await self._notify_stock_status(row)
        return DigitalMetalInventoryResponse.from_model(row)

    async def ensure_available(self, metal: str, grams: Decimal) -> None:
        """Pre-check before creating a Razorpay order."""
        metal = self._normalize_metal(metal)
        grams = Decimal(str(grams))
        row = await self.inventory_repo.get_by_metal(metal)
        if not row:
            raise ValidationException(self._stock_error_message(metal))
        if row.available_weight_grams < grams:
            raise ValidationException(self._stock_error_message(metal))

    async def consume_for_paid_order(
        self,
        *,
        metal: str,
        grams: Decimal,
        payment_order_id: uuid.UUID,
        user_id: uuid.UUID,
        commit: bool = True,
    ) -> None:
        """Debit platform stock after successful payment verification."""
        metal = self._normalize_metal(metal)
        grams = Decimal(str(grams))

        if await self.movement_repo.has_purchase_debit_for_order(payment_order_id):
            return

        row = await self.inventory_repo.get_by_metal_for_update(metal)
        if not row:
            raise ValidationException(self._stock_error_message(metal))

        available = row.available_weight_grams
        if available < grams:
            raise ValidationException(self._stock_error_message(metal))

        total_before = Decimal(str(row.total_weight_grams))
        used_before = Decimal(str(row.used_weight_grams))
        used_after = used_before + grams
        row.used_weight_grams = used_after

        await self.movement_repo.create(
            {
                "id": uuid.uuid4(),
                "metal_type": metal,
                "movement_type": "purchase_debit",
                "grams_delta": grams,
                "total_weight_before": total_before,
                "used_weight_before": used_before,
                "total_weight_after": total_before,
                "used_weight_after": used_after,
                "payment_order_id": payment_order_id,
                "user_id": user_id,
                "performed_by": user_id,
                "notes": "User purchase verified",
            },
            commit=False,
        )

        if self.audit_service:
            await self.audit_service.log_action(
                user_id=user_id,
                action=audit_actions.METAL_INVENTORY_PURCHASE_DEBIT,
                entity_type="DigitalMetalInventory",
                entity_id=str(row.id),
                metadata={
                    "metal_type": metal,
                    "grams": str(grams),
                    "payment_order_id": str(payment_order_id),
                    "available_after": str(total_before - used_after),
                },
            )

        if commit:
            await self.inventory_repo.db.commit()
            await self.inventory_repo.db.refresh(row)
            await self._notify_stock_status(row)

    async def notify_metal_status(self, metal_type: str) -> None:
        """Refresh row and send low/out-of-stock notifications after an outer commit."""
        metal = self._normalize_metal(metal_type)
        row = await self.inventory_repo.get_by_metal(metal)
        if row:
            await self._notify_stock_status(row)

    async def list_movements(
        self,
        metal_type: str,
        *,
        skip: int = 0,
        limit: int = 50,
    ) -> DigitalMetalInventoryMovementListResponse:
        metal = self._normalize_metal(metal_type)
        if not await self.inventory_repo.get_by_metal(metal):
            raise NotFoundException(f"{metal.upper()} inventory not configured")
        rows, total = await self.movement_repo.list_for_metal(
            metal, skip=skip, limit=limit
        )
        return DigitalMetalInventoryMovementListResponse(
            items=[DigitalMetalInventoryMovementResponse.from_model(r) for r in rows],
            total=total,
            skip=skip,
            limit=limit,
        )

    async def get_alerts(self) -> DigitalMetalInventoryAlertsResponse:
        rows = await self.inventory_repo.list_all()
        alerts: list[DigitalMetalInventoryAlertResponse] = []
        for row in rows:
            available = row.available_weight_grams
            status = compute_stock_status(available, row.low_stock_threshold_grams)
            if status == "available":
                continue
            label = row.metal_type.upper()
            if status == "out_of_stock":
                title = f"{label} inventory is out of stock"
                message = (
                    f"{label} inventory is out of stock. "
                    f"Available: {available} g."
                )
            else:
                title = f"{label} inventory is low"
                message = (
                    f"{label} inventory is low. "
                    f"Available: {available} g (threshold: {row.low_stock_threshold_grams} g)."
                )
            alerts.append(
                DigitalMetalInventoryAlertResponse(
                    metal_type=row.metal_type,
                    metal_label=label,
                    stock_status=status,
                    available_weight_grams=available,
                    low_stock_threshold_grams=row.low_stock_threshold_grams,
                    title=title,
                    message=message,
                )
            )
        return DigitalMetalInventoryAlertsResponse(items=alerts)

    async def _notify_stock_status(self, row: DigitalMetalInventory) -> None:
        if not self.notification_service:
            return
        available = row.available_weight_grams
        status = compute_stock_status(available, row.low_stock_threshold_grams)
        if status == "available":
            return

        label = row.metal_type.upper()
        since = datetime.now(timezone.utc) - timedelta(
            minutes=settings.NOTIFICATION_LOW_STOCK_COOLDOWN_MINUTES
        )
        if status == "out_of_stock":
            title = f"{label} inventory is out of stock"
            message = f"{label} inventory is out of stock. Available: {available} g."
        else:
            title = f"{label} inventory is low"
            message = (
                f"{label} inventory is low. Available: {available} g "
                f"(threshold: {row.low_stock_threshold_grams} g)."
            )

        from app.repositories.user import UserRepository

        user_repo = UserRepository(self.inventory_repo.db)
        user_ids = await user_repo.get_user_ids_with_permission("inventory.view")
        for uid in user_ids:
            if await self.notification_service.notification_repo.has_recent_notification(
                user_id=uid,
                category=NotificationService.CATEGORY_SYSTEM,
                title=title,
                since=since,
            ):
                continue
            await self.notification_service.create_notification(
                user_id=uid,
                title=title,
                message=message,
                category=NotificationService.CATEGORY_SYSTEM,
                metadata={
                    "metal_type": row.metal_type,
                    "stock_status": status,
                    "available_weight_grams": str(available),
                },
            )
