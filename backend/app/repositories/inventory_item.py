from decimal import Decimal
from typing import Optional
import uuid

from sqlalchemy import asc, desc, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.inventory_item import InventoryItem
from app.repositories.base import BaseRepository

SORT_COLUMNS = {
    "item_name": InventoryItem.item_name,
    "item_category": InventoryItem.item_category,
    "stock_quantity": InventoryItem.stock_quantity,
    "current_value": InventoryItem.current_value,
    "purchase_price": InventoryItem.purchase_price,
    "status": InventoryItem.status,
    "created_at": InventoryItem.created_at,
}


class InventoryItemRepository(BaseRepository[InventoryItem]):
    """Repository for inventory item queries and metrics."""

    def __init__(self, db_session: AsyncSession):
        super().__init__(InventoryItem, db_session)

    def _apply_filters(
        self,
        query,
        search: Optional[str] = None,
        item_category: Optional[str] = None,
        status: Optional[str] = None,
        supplier_id: Optional[str] = None,
        low_stock_only: bool = False,
    ):
        query = query.where(InventoryItem.is_deleted.is_(False))
        if search:
            pattern = f"%{search}%"
            query = query.where(
                or_(
                    InventoryItem.item_name.ilike(pattern),
                    InventoryItem.notes.ilike(pattern),
                )
            )
        if item_category is not None:
            query = query.where(InventoryItem.item_category == item_category)
        if status is not None:
            query = query.where(InventoryItem.status == status)
        if supplier_id is not None:
            query = query.where(InventoryItem.supplier_id == supplier_id)
        if low_stock_only:
            query = query.where(
                InventoryItem.stock_quantity <= InventoryItem.reorder_level
            )
        return query

    def _apply_sort(self, query, sort_by: str, sort_order: str):
        column = SORT_COLUMNS.get(sort_by, InventoryItem.created_at)
        direction = asc if sort_order == "asc" else desc
        return query.order_by(direction(column))

    async def get_active(self, item_id) -> Optional[InventoryItem]:
        query = (
            select(InventoryItem)
            .options(selectinload(InventoryItem.supplier))
            .where(
                InventoryItem.id == item_id,
                InventoryItem.is_deleted.is_(False),
            )
        )
        result = await self.db.execute(query)
        return result.scalars().first()

    async def get_active_by_ids(self, item_ids: list) -> dict:
        if not item_ids:
            return {}
        unique_ids = list(dict.fromkeys(item_ids))
        query = (
            select(InventoryItem)
            .options(selectinload(InventoryItem.supplier))
            .where(
                InventoryItem.id.in_(unique_ids),
                InventoryItem.is_deleted.is_(False),
            )
        )
        result = await self.db.execute(query)
        items = result.scalars().all()
        return {item.id: item for item in items}

    async def get_active_for_update(self, item_id) -> Optional[InventoryItem]:
        """Fetch active item with row lock for stock mutations."""
        query = (
            select(InventoryItem)
            .options(selectinload(InventoryItem.supplier))
            .where(
                InventoryItem.id == item_id,
                InventoryItem.is_deleted.is_(False),
            )
            .with_for_update()
        )
        result = await self.db.execute(query)
        return result.scalars().first()

    async def count_by_supplier(self, supplier_id: uuid.UUID) -> int:
        query = (
            select(func.count(InventoryItem.id))
            .select_from(InventoryItem)
            .where(
                InventoryItem.supplier_id == supplier_id,
                InventoryItem.is_deleted.is_(False),
            )
        )
        result = await self.db.execute(query)
        return result.scalar() or 0

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
    ) -> list[InventoryItem]:
        items, _ = await self.list_items_with_total(
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
        return items

    async def list_items_with_total(
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
    ) -> tuple[list[InventoryItem], int]:
        """List items and total count in a single query."""
        limit = min(limit, 100)
        total_col = func.count().over().label("total_count")
        query = select(InventoryItem, total_col).options(
            selectinload(InventoryItem.supplier)
        )
        query = self._apply_filters(
            query, search, item_category, status, supplier_id, low_stock_only
        )
        query = self._apply_sort(query, sort_by, sort_order)
        query = query.offset(skip).limit(limit)
        result = await self.db.execute(query)
        rows = result.all()
        if not rows:
            return [], 0
        total = int(rows[0].total_count or 0)
        return [row[0] for row in rows], total

    async def count_items(
        self,
        search: Optional[str] = None,
        item_category: Optional[str] = None,
        status: Optional[str] = None,
        supplier_id: Optional[str] = None,
        low_stock_only: bool = False,
    ) -> int:
        query = select(func.count(InventoryItem.id)).select_from(InventoryItem)
        query = self._apply_filters(
            query, search, item_category, status, supplier_id, low_stock_only
        )
        result = await self.db.execute(query)
        return result.scalar() or 0

    async def get_metrics(self) -> dict:
        query = select(
            func.coalesce(func.sum(InventoryItem.stock_quantity), 0).label(
                "total_stock"
            ),
            func.coalesce(
                func.sum(InventoryItem.current_value * InventoryItem.stock_quantity),
                0,
            ).label("inventory_value"),
            func.count()
            .filter(InventoryItem.stock_quantity <= InventoryItem.reorder_level)
            .label("low_stock_count"),
        ).where(InventoryItem.is_deleted.is_(False))
        result = await self.db.execute(query)
        row = result.one()
        return {
            "total_stock": int(row.total_stock or 0),
            "inventory_value": Decimal(str(row.inventory_value or 0)),
            "low_stock_count": int(row.low_stock_count or 0),
        }

    async def list_low_stock(self, limit: int = 10) -> list[InventoryItem]:
        query = (
            select(InventoryItem)
            .options(selectinload(InventoryItem.supplier))
            .where(
                InventoryItem.is_deleted.is_(False),
                InventoryItem.stock_quantity <= InventoryItem.reorder_level,
            )
            .order_by(InventoryItem.stock_quantity.asc())
            .limit(min(limit, 50))
        )
        result = await self.db.execute(query)
        return list(result.scalars().all())
