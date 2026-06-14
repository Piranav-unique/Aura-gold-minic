import uuid
from datetime import datetime, timezone
from decimal import Decimal
from typing import Optional

from sqlalchemy import asc, case, desc, func, or_, select, text
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.customer import Customer
from app.models.transaction import Transaction, TransactionLine
from app.repositories.base import BaseRepository

SORT_COLUMNS = {
    "transaction_number": Transaction.transaction_number,
    "transaction_type": Transaction.transaction_type,
    "total_amount": Transaction.total_amount,
    "payment_status": Transaction.payment_status,
    "status": Transaction.status,
    "created_at": Transaction.created_at,
}


class TransactionRepository(BaseRepository[Transaction]):
    """Repository for transaction queries and revenue metrics."""

    def __init__(self, db_session: AsyncSession):
        super().__init__(Transaction, db_session)

    def _apply_filters(
        self,
        query,
        search: Optional[str] = None,
        transaction_type: Optional[str] = None,
        payment_status: Optional[str] = None,
        status: Optional[str] = None,
        customer_id: Optional[uuid.UUID] = None,
    ):
        if search:
            pattern = f"%{search}%"
            query = query.where(
                or_(
                    Transaction.transaction_number.ilike(pattern),
                    Transaction.invoice_number.ilike(pattern),
                    Transaction.receipt_number.ilike(pattern),
                )
            )
        if transaction_type is not None:
            query = query.where(Transaction.transaction_type == transaction_type)
        if payment_status is not None:
            query = query.where(Transaction.payment_status == payment_status)
        if status is not None:
            query = query.where(Transaction.status == status)
        if customer_id is not None:
            query = query.where(Transaction.customer_id == customer_id)
        return query

    def _apply_sort(self, query, sort_by: str, sort_order: str):
        column = SORT_COLUMNS.get(sort_by, Transaction.created_at)
        direction = asc if sort_order == "asc" else desc
        return query.order_by(direction(column))

    async def get_with_details(
        self, transaction_id: uuid.UUID
    ) -> Optional[Transaction]:
        query = (
            select(Transaction)
            .options(
                selectinload(Transaction.lines).selectinload(
                    TransactionLine.inventory_item
                ),
                selectinload(Transaction.customer),
            )
            .where(Transaction.id == transaction_id)
        )
        result = await self.db.execute(query)
        return result.scalars().first()

    async def get_for_update(self, transaction_id: uuid.UUID) -> Optional[Transaction]:
        query = (
            select(Transaction)
            .options(
                selectinload(Transaction.lines),
                selectinload(Transaction.customer),
            )
            .where(Transaction.id == transaction_id)
            .with_for_update()
        )
        result = await self.db.execute(query)
        return result.scalars().first()

    async def list_transactions_with_total(
        self,
        skip: int = 0,
        limit: int = 100,
        search: Optional[str] = None,
        transaction_type: Optional[str] = None,
        payment_status: Optional[str] = None,
        status: Optional[str] = None,
        customer_id: Optional[uuid.UUID] = None,
        sort_by: str = "created_at",
        sort_order: str = "desc",
    ) -> tuple[list[Transaction], int]:
        limit = min(limit, 100)
        total_col = func.count().over().label("total_count")
        query = select(Transaction, total_col).options(
            selectinload(Transaction.customer),
            selectinload(Transaction.lines),
        )
        query = self._apply_filters(
            query, search, transaction_type, payment_status, status, customer_id
        )
        query = self._apply_sort(query, sort_by, sort_order)
        query = query.offset(skip).limit(limit)
        result = await self.db.execute(query)
        rows = result.all()
        if not rows:
            return [], 0
        return [row[0] for row in rows], int(rows[0].total_count or 0)

    async def count_for_day(self, day: datetime) -> int:
        start = day.replace(hour=0, minute=0, second=0, microsecond=0)
        end = start.replace(hour=23, minute=59, second=59, microsecond=999999)
        query = select(func.count(Transaction.id)).where(
            Transaction.created_at >= start,
            Transaction.created_at <= end,
        )
        result = await self.db.execute(query)
        return result.scalar() or 0

    @staticmethod
    def _signed_revenue_amount():
        """Net revenue: sales/exchanges add, returns subtract."""
        return case(
            (Transaction.transaction_type == "return", -Transaction.total_amount),
            (
                Transaction.transaction_type.in_(["sale", "exchange"]),
                Transaction.total_amount,
            ),
            else_=0,
        )

    async def revenue_sum(
        self,
        *,
        start: datetime,
        end: datetime,
        payment_status: str = "paid",
    ) -> Decimal:
        signed_amount = self._signed_revenue_amount()
        query = select(func.coalesce(func.sum(signed_amount), 0)).where(
            Transaction.status == "active",
            Transaction.payment_status == payment_status,
            Transaction.transaction_type.in_(["sale", "return", "exchange"]),
            Transaction.created_at >= start,
            Transaction.created_at <= end,
        )
        result = await self.db.execute(query)
        return Decimal(str(result.scalar() or 0))

    async def top_customers(
        self, limit: int = 5, payment_status: str = "paid"
    ) -> list[dict]:
        signed_amount = self._signed_revenue_amount()
        query = (
            select(
                Customer.id,
                Customer.full_name,
                func.coalesce(func.sum(signed_amount), 0).label("revenue"),
                func.count(Transaction.id).label("transaction_count"),
            )
            .join(Transaction, Transaction.customer_id == Customer.id)
            .where(
                Transaction.status == "active",
                Transaction.payment_status == payment_status,
                Transaction.transaction_type.in_(["sale", "return", "exchange"]),
                Customer.is_deleted.is_(False),
            )
            .group_by(Customer.id, Customer.full_name)
            .order_by(desc("revenue"))
            .limit(min(limit, 20))
        )
        result = await self.db.execute(query)
        rows = result.all()
        return [
            {
                "customer_id": row.id,
                "full_name": row.full_name,
                "revenue": Decimal(str(row.revenue or 0)),
                "transaction_count": int(row.transaction_count or 0),
            }
            for row in rows
        ]

    def _document_column(self, prefix: str):
        if prefix == "TXN":
            return Transaction.transaction_number
        if prefix == "INV":
            return Transaction.invoice_number
        return Transaction.receipt_number

    async def next_document_number(self, prefix: str) -> str:
        """Generate next document number with transactional advisory lock."""
        today = datetime.now(timezone.utc).strftime("%Y%m%d")
        base = f"{prefix}-{today}-"
        await self.db.execute(
            text("SELECT pg_advisory_xact_lock(hashtext(:lock_key))"),
            {"lock_key": base},
        )
        column = self._document_column(prefix)
        result = await self.db.execute(
            select(func.max(column)).where(column.like(f"{base}%"))
        )
        last_number = result.scalar()
        if last_number:
            seq = int(str(last_number).rsplit("-", 1)[-1]) + 1
        else:
            seq = 1
        return f"{base}{seq:04d}"
