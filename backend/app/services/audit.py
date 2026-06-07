import uuid
from datetime import datetime, timezone
from typing import Any, Optional

from app.models.audit_log import AuditLog
from app.repositories.audit_log import AuditLogRepository
from app.middleware.audit_middleware import client_ip_ctx, user_agent_ctx


class AuditService:
    """Service class encapsulating Audit Logging business logic."""

    def __init__(self, audit_repo: AuditLogRepository):
        self.audit_repo = audit_repo

    async def log_action(
        self,
        user_id: Optional[uuid.UUID],
        action: str,
        entity_type: Optional[str] = None,
        entity_id: Optional[str] = None,
        metadata: Optional[dict] = None,
    ) -> AuditLog:
        """Log a new audit event, automatically resolving client context (IP, User Agent)."""
        ip_address = client_ip_ctx.get()
        user_agent = user_agent_ctx.get()

        log_data = {
            "user_id": user_id,
            "action": action,
            "entity_type": entity_type,
            "entity_id": entity_id,
            "meta_data": metadata,
            "ip_address": ip_address,
            "user_agent": user_agent,
            "timestamp": datetime.now(timezone.utc),
        }

        # Create record in DB
        return await self.audit_repo.create(log_data)

    async def list_audit_logs(
        self,
        skip: int = 0,
        limit: int = 100,
        user_id: Optional[uuid.UUID] = None,
        action: Optional[str] = None,
        entity_type: Optional[str] = None,
    ) -> list[AuditLog]:
        """Fetch audit logs matching filters ordered by descending timestamp."""
        return await self.audit_repo.list_audit_logs(
            skip=skip,
            limit=limit,
            user_id=user_id,
            action=action,
            entity_type=entity_type,
        )
