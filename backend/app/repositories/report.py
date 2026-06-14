from datetime import datetime, timedelta, timezone
from decimal import Decimal
from typing import Optional

from sqlalchemy import case, cast, Date, desc, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.audit_log import AuditLog
from app.models.customer import Customer
from app.models.inventory_item import InventoryItem
from app.models.stock_movement import StockMovement
from app.models.transaction import Transaction
from app.repositories.transaction import TransactionRepository


class ReportRepository:
    """Analytics and report aggregation queries."""

    def __init__(self, db_session: AsyncSession):
        self.db = db_session

    @staticmethod
    def _signed_revenue():
        return case(
            (Transaction.transaction_type == "return", -Transaction.total_amount),
            (
                Transaction.transaction_type.in_(["sale", "exchange"]),
                Transaction.total_amount,
            ),
            else_=0,
        )

    async def revenue_trend(
        self, days: int = 30, payment_status: str = "paid"
    ) -> list[dict]:
        signed = self._signed_revenue()
        start = datetime.now(timezone.utc) - timedelta(days=days - 1)
        start = start.replace(hour=0, minute=0, second=0, microsecond=0)
        day_col = cast(Transaction.created_at, Date).label("day")
        query = (
            select(
                day_col,
                func.coalesce(func.sum(signed), 0).label("revenue"),
                func.count(Transaction.id).label("transaction_count"),
            )
            .where(
                Transaction.status == "active",
                Transaction.payment_status == payment_status,
                Transaction.transaction_type.in_(["sale", "return", "exchange"]),
                Transaction.created_at >= start,
            )
            .group_by(day_col)
            .order_by(day_col)
        )
        result = await self.db.execute(query)
        return [
            {
                "label": row.day.isoformat(),
                "revenue": Decimal(str(row.revenue or 0)),
                "transaction_count": int(row.transaction_count or 0),
            }
            for row in result.all()
        ]

    async def revenue_period_summary(
        self, start: datetime, end: datetime, payment_status: str = "paid"
    ) -> dict:
        repo = TransactionRepository(self.db)
        total = await repo.revenue_sum(
            start=start, end=end, payment_status=payment_status
        )
        count_query = select(func.count(Transaction.id)).where(
            Transaction.status == "active",
            Transaction.payment_status == payment_status,
            Transaction.transaction_type.in_(["sale", "return", "exchange"]),
            Transaction.created_at >= start,
            Transaction.created_at <= end,
        )
        count_result = await self.db.execute(count_query)
        return {
            "total_revenue": total,
            "transaction_count": int(count_result.scalar() or 0),
        }

    async def revenue_growth_percent(self) -> Optional[Decimal]:
        now = datetime.now(timezone.utc)
        this_month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        last_month_end = this_month_start - timedelta(microseconds=1)
        last_month_start = last_month_end.replace(
            day=1, hour=0, minute=0, second=0, microsecond=0
        )

        this_month = await self.revenue_period_summary(this_month_start, now)
        last_month = await self.revenue_period_summary(last_month_start, last_month_end)
        last_rev = last_month["total_revenue"]
        this_rev = this_month["total_revenue"]
        if last_rev == 0:
            return None if this_rev == 0 else Decimal("100")
        return ((this_rev - last_rev) / last_rev * 100).quantize(Decimal("0.01"))

    async def inventory_summary(self) -> dict:
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
            func.count(InventoryItem.id).label("item_count"),
        ).where(InventoryItem.is_deleted.is_(False))
        result = await self.db.execute(query)
        row = result.one()
        return {
            "total_stock": int(row.total_stock or 0),
            "inventory_value": Decimal(str(row.inventory_value or 0)),
            "low_stock_count": int(row.low_stock_count or 0),
            "item_count": int(row.item_count or 0),
        }

    async def inventory_by_category(self) -> list[dict]:
        query = (
            select(
                InventoryItem.item_category,
                func.count(InventoryItem.id).label("item_count"),
                func.coalesce(func.sum(InventoryItem.stock_quantity), 0).label(
                    "total_stock"
                ),
                func.coalesce(
                    func.sum(
                        InventoryItem.current_value * InventoryItem.stock_quantity
                    ),
                    0,
                ).label("category_value"),
            )
            .where(InventoryItem.is_deleted.is_(False))
            .group_by(InventoryItem.item_category)
            .order_by(desc("category_value"))
        )
        result = await self.db.execute(query)
        return [
            {
                "category": row.item_category,
                "item_count": int(row.item_count or 0),
                "total_stock": int(row.total_stock or 0),
                "category_value": Decimal(str(row.category_value or 0)),
            }
            for row in result.all()
        ]

    async def inventory_movement_trend(self, days: int = 30) -> list[dict]:
        start = datetime.now(timezone.utc) - timedelta(days=days - 1)
        start = start.replace(hour=0, minute=0, second=0, microsecond=0)
        day_col = cast(StockMovement.created_at, Date).label("day")
        query = (
            select(
                day_col,
                func.coalesce(func.sum(StockMovement.quantity_change), 0).label(
                    "net_change"
                ),
                func.count(StockMovement.id).label("movement_count"),
            )
            .where(StockMovement.created_at >= start)
            .group_by(day_col)
            .order_by(day_col)
        )
        result = await self.db.execute(query)
        return [
            {
                "label": row.day.isoformat(),
                "net_change": int(row.net_change or 0),
                "movement_count": int(row.movement_count or 0),
            }
            for row in result.all()
        ]

    async def customer_summary(self) -> dict:
        query = select(
            func.count(Customer.id).label("total_customers"),
            func.count().filter(Customer.status == "active").label("active_customers"),
            func.coalesce(func.sum(Customer.total_revenue), 0).label("total_revenue"),
            func.coalesce(func.sum(Customer.total_purchases), 0).label(
                "total_purchases"
            ),
        ).where(Customer.is_deleted.is_(False))
        result = await self.db.execute(query)
        row = result.one()
        return {
            "total_customers": int(row.total_customers or 0),
            "active_customers": int(row.active_customers or 0),
            "total_revenue": Decimal(str(row.total_revenue or 0)),
            "total_purchases": int(row.total_purchases or 0),
        }

    async def top_customers_report(self, limit: int = 10) -> list[dict]:
        repo = TransactionRepository(self.db)
        return await repo.top_customers(limit=limit)

    async def customer_type_breakdown(self) -> list[dict]:
        query = (
            select(
                Customer.customer_type,
                func.count(Customer.id).label("count"),
                func.coalesce(func.sum(Customer.total_revenue), 0).label("revenue"),
            )
            .where(Customer.is_deleted.is_(False))
            .group_by(Customer.customer_type)
            .order_by(desc("revenue"))
        )
        result = await self.db.execute(query)
        return [
            {
                "customer_type": row.customer_type,
                "count": int(row.count or 0),
                "revenue": Decimal(str(row.revenue or 0)),
            }
            for row in result.all()
        ]

    async def transaction_breakdown(
        self,
        start: Optional[datetime] = None,
        end: Optional[datetime] = None,
    ) -> list[dict]:
        query = select(
            Transaction.transaction_type,
            Transaction.payment_status,
            func.count(Transaction.id).label("count"),
            func.coalesce(func.sum(Transaction.total_amount), 0).label("total_amount"),
        ).where(Transaction.status == "active")
        if start:
            query = query.where(Transaction.created_at >= start)
        if end:
            query = query.where(Transaction.created_at <= end)
        query = query.group_by(
            Transaction.transaction_type, Transaction.payment_status
        ).order_by(Transaction.transaction_type)
        result = await self.db.execute(query)
        return [
            {
                "transaction_type": row.transaction_type,
                "payment_status": row.payment_status,
                "count": int(row.count or 0),
                "total_amount": Decimal(str(row.total_amount or 0)),
            }
            for row in result.all()
        ]

    async def list_transactions_for_report(
        self,
        start: Optional[datetime] = None,
        end: Optional[datetime] = None,
        limit: int = 5000,
    ) -> list[Transaction]:
        query = select(Transaction).order_by(desc(Transaction.created_at))
        if start:
            query = query.where(Transaction.created_at >= start)
        if end:
            query = query.where(Transaction.created_at <= end)
        query = query.limit(limit)
        result = await self.db.execute(query)
        return list(result.scalars().all())

    async def audit_action_breakdown(
        self,
        start: Optional[datetime] = None,
        end: Optional[datetime] = None,
    ) -> list[dict]:
        query = select(
            AuditLog.action,
            func.count(AuditLog.id).label("count"),
        )
        if start:
            query = query.where(AuditLog.timestamp >= start)
        if end:
            query = query.where(AuditLog.timestamp <= end)
        query = query.group_by(AuditLog.action).order_by(desc("count"))
        result = await self.db.execute(query)
        return [
            {"action": row.action, "count": int(row.count or 0)} for row in result.all()
        ]

    async def count_audit_logs(
        self,
        start: Optional[datetime] = None,
        end: Optional[datetime] = None,
    ) -> int:
        query = select(func.count(AuditLog.id))
        if start:
            query = query.where(AuditLog.timestamp >= start)
        if end:
            query = query.where(AuditLog.timestamp <= end)
        result = await self.db.execute(query)
        return int(result.scalar() or 0)
