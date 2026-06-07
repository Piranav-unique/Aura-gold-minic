from typing import Any, Optional
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.audit_log import AuditLog
from app.repositories.base import BaseRepository


class AuditLogRepository(BaseRepository[AuditLog]):
    """Repository class handling query logic for AuditLog model."""

    def __init__(self, db_session: AsyncSession):
        super().__init__(AuditLog, db_session)

    async def list_audit_logs(
        self,
        skip: int = 0,
        limit: int = 100,
        user_id: Optional[Any] = None,
        action: Optional[str] = None,
        entity_type: Optional[str] = None,
    ) -> list[AuditLog]:
        """Fetch audit logs matching filters ordered by timestamp descending (newest first)."""
        limit = min(limit, 100)  # Safeguard maximum query limit

        # Order by timestamp DESC (since RANGE partitioning is on timestamp, DESC is efficient)
        query = select(AuditLog).order_by(AuditLog.timestamp.desc())

        if user_id is not None:
            query = query.where(AuditLog.user_id == user_id)

        if action:
            query = query.where(AuditLog.action == action)

        if entity_type:
            query = query.where(AuditLog.entity_type == entity_type)

        query = query.offset(skip).limit(limit)
        result = await self.db.execute(query)
        return list(result.scalars().all())
