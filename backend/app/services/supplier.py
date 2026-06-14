import uuid
from datetime import datetime, timezone
from typing import Optional, Tuple

from sqlalchemy.exc import IntegrityError

from app.core import audit_actions
from app.core.exceptions import NotFoundException, ValidationException
from app.models.supplier import Supplier
from app.repositories.supplier import SupplierRepository
from app.schemas.supplier import SupplierCreate, SupplierUpdate
from app.services.audit import AuditService


class SupplierService:
    """Business logic for supplier management."""

    def __init__(
        self,
        supplier_repo: SupplierRepository,
        audit_service: Optional[AuditService] = None,
    ):
        self.supplier_repo = supplier_repo
        self.audit_service = audit_service

    async def _ensure_unique_name(
        self, name: str, exclude_id: Optional[uuid.UUID] = None
    ) -> None:
        existing = await self.supplier_repo.get_by_name(name)
        if existing and (exclude_id is None or existing.id != exclude_id):
            raise ValidationException(f"Supplier name '{name}' is already registered")

    async def create_supplier(
        self,
        supplier_in: SupplierCreate,
        performing_user_id: Optional[uuid.UUID] = None,
    ) -> Supplier:
        await self._ensure_unique_name(supplier_in.name)
        try:
            supplier = await self.supplier_repo.create(
                supplier_in.model_dump(), commit=True
            )
        except IntegrityError as exc:
            await self.supplier_repo.db.rollback()
            raise ValidationException("Supplier name already registered") from exc

        if self.audit_service:
            await self.audit_service.log_action(
                user_id=performing_user_id,
                action=audit_actions.SUPPLIER_CREATE,
                entity_type="Supplier",
                entity_id=str(supplier.id),
                metadata={"name": supplier.name},
            )
        return supplier

    async def get_supplier_by_id(self, supplier_id: uuid.UUID) -> Supplier:
        supplier = await self.supplier_repo.get_active(supplier_id)
        if not supplier:
            raise NotFoundException("Supplier not found")
        return supplier

    async def list_suppliers(
        self,
        skip: int = 0,
        limit: int = 100,
        search: Optional[str] = None,
        is_active: Optional[bool] = None,
        sort_by: str = "created_at",
        sort_order: str = "desc",
    ) -> Tuple[list[Supplier], int]:
        items = await self.supplier_repo.list_suppliers(
            skip=skip,
            limit=limit,
            search=search,
            is_active=is_active,
            sort_by=sort_by,
            sort_order=sort_order,
        )
        total = await self.supplier_repo.count_suppliers(
            search=search, is_active=is_active
        )
        return items, total

    async def update_supplier(
        self,
        supplier_id: uuid.UUID,
        supplier_in: SupplierUpdate,
        performing_user_id: Optional[uuid.UUID] = None,
    ) -> Supplier:
        supplier = await self.supplier_repo.get_active(supplier_id)
        if not supplier:
            raise NotFoundException("Supplier not found")

        update_data = supplier_in.model_dump(exclude_unset=True)
        if "name" in update_data and update_data["name"] != supplier.name:
            await self._ensure_unique_name(update_data["name"], exclude_id=supplier.id)

        for field, value in update_data.items():
            setattr(supplier, field, value)

        try:
            await self.supplier_repo.db.commit()
            await self.supplier_repo.db.refresh(supplier)
        except IntegrityError as exc:
            await self.supplier_repo.db.rollback()
            raise ValidationException("Supplier name already registered") from exc

        if self.audit_service:
            await self.audit_service.log_action(
                user_id=performing_user_id,
                action=audit_actions.SUPPLIER_UPDATE,
                entity_type="Supplier",
                entity_id=str(supplier.id),
                metadata={"updated_fields": list(update_data.keys())},
            )
        return supplier

    async def delete_supplier(
        self,
        supplier_id: uuid.UUID,
        performing_user_id: Optional[uuid.UUID] = None,
    ) -> bool:
        supplier = await self.supplier_repo.get_active(supplier_id)
        if not supplier:
            raise NotFoundException("Supplier not found")

        linked = await self.supplier_repo.count_linked_inventory_items(supplier_id)
        if linked > 0:
            raise ValidationException(
                f"Cannot delete supplier linked to {linked} inventory item(s). "
                "Reassign or remove items first."
            )

        supplier.is_deleted = True
        supplier.deleted_at = datetime.now(timezone.utc)
        await self.supplier_repo.db.commit()

        if self.audit_service:
            await self.audit_service.log_action(
                user_id=performing_user_id,
                action=audit_actions.SUPPLIER_DELETE,
                entity_type="Supplier",
                entity_id=str(supplier_id),
                metadata={"name": supplier.name},
            )
        return True
