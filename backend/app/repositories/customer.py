from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import asc, desc, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.customer import Customer
from app.repositories.base import BaseRepository

SORT_COLUMNS = {
    "full_name": Customer.full_name,
    "created_at": Customer.created_at,
    "total_revenue": Customer.total_revenue,
    "total_purchases": Customer.total_purchases,
    "last_transaction_date": Customer.last_transaction_date,
    "status": Customer.status,
    "customer_type": Customer.customer_type,
}


class CustomerRepository(BaseRepository[Customer]):
    """Repository class handling query logic for Customer model."""

    def __init__(self, db_session: AsyncSession):
        super().__init__(Customer, db_session)

    def _apply_filters(
        self,
        query,
        search: Optional[str] = None,
        customer_type: Optional[str] = None,
        status: Optional[str] = None,
    ):
        query = query.where(Customer.is_deleted.is_(False))

        if search:
            pattern = f"%{search}%"
            query = query.where(
                or_(
                    Customer.full_name.ilike(pattern),
                    Customer.email.ilike(pattern),
                    Customer.mobile_number.ilike(pattern),
                    Customer.gst_number.ilike(pattern),
                )
            )

        if customer_type is not None:
            query = query.where(Customer.customer_type == customer_type)

        if status is not None:
            query = query.where(Customer.status == status)

        return query

    def _apply_sort(self, query, sort_by: str, sort_order: str):
        column = SORT_COLUMNS.get(sort_by, Customer.created_at)
        direction = asc if sort_order == "asc" else desc
        return query.order_by(direction(column))

    async def get_active(self, customer_id) -> Optional[Customer]:
        """Fetch an active customer by ID."""
        query = select(Customer).where(
            Customer.id == customer_id,
            Customer.is_deleted.is_(False),
        )
        result = await self.db.execute(query)
        return result.scalars().first()

    async def get_by_email(self, email: str) -> Optional[Customer]:
        """Fetch an active customer by email."""
        query = select(Customer).where(
            Customer.email == email,
            Customer.is_deleted.is_(False),
        )
        result = await self.db.execute(query)
        return result.scalars().first()

    async def get_by_mobile(self, mobile_number: str) -> Optional[Customer]:
        """Fetch an active customer by mobile number."""
        query = select(Customer).where(
            Customer.mobile_number == mobile_number,
            Customer.is_deleted.is_(False),
        )
        result = await self.db.execute(query)
        return result.scalars().first()

    async def list_customers(
        self,
        skip: int = 0,
        limit: int = 100,
        search: Optional[str] = None,
        customer_type: Optional[str] = None,
        status: Optional[str] = None,
        sort_by: str = "created_at",
        sort_order: str = "desc",
    ) -> list[Customer]:
        """Fetch customers matching filters with pagination and sorting."""
        limit = min(limit, 100)

        query = select(Customer)
        query = self._apply_filters(query, search, customer_type, status)
        query = self._apply_sort(query, sort_by, sort_order)
        query = query.offset(skip).limit(limit)

        result = await self.db.execute(query)
        return list(result.scalars().all())

    async def count_customers(
        self,
        search: Optional[str] = None,
        customer_type: Optional[str] = None,
        status: Optional[str] = None,
    ) -> int:
        """Count customers matching filters."""
        query = select(func.count(Customer.id)).select_from(Customer)
        query = self._apply_filters(query, search, customer_type, status)
        result = await self.db.execute(query)
        return result.scalar() or 0

    async def dashboard_metrics(self) -> dict[str, int]:
        """Aggregate customer counts for executive dashboard."""
        total = await self.count_customers()
        active = await self.count_customers(status="active")
        month_start = datetime.now(timezone.utc).replace(
            day=1, hour=0, minute=0, second=0, microsecond=0
        )
        new_query = (
            select(func.count(Customer.id))
            .select_from(Customer)
            .where(
                Customer.is_deleted.is_(False),
                Customer.created_at >= month_start,
            )
        )
        new_result = await self.db.execute(new_query)
        return {
            "total_customers": int(total),
            "active_customers": int(active),
            "new_this_month": int(new_result.scalar() or 0),
        }
