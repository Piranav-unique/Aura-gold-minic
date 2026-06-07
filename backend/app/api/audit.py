import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status

from app.api.dependencies import get_current_user, get_audit_service
from app.core.authorization import require_permission
from app.models.user import User
from app.schemas.audit_log import AuditLogResponse
from app.services.audit import AuditService

router = APIRouter()


@router.get(
    "/",
    response_model=List[AuditLogResponse],
    status_code=status.HTTP_200_OK,
    summary="Retrieve audit logs with pagination and filtering",
)
@require_permission("audit.view")
async def list_audit_logs(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=100),
    user_id: Optional[uuid.UUID] = Query(None, description="Filter logs by acting user ID"),
    action: Optional[str] = Query(None, description="Filter logs by action type"),
    entity_type: Optional[str] = Query(None, description="Filter logs by target entity type"),
    audit_service: AuditService = Depends(get_audit_service),
    current_user: User = Depends(get_current_user),
) -> List[AuditLogResponse]:
    """Retrieve audit logs matching search parameters. Requires 'audit.view' permission."""
    return await audit_service.list_audit_logs(
        skip=skip,
        limit=limit,
        user_id=user_id,
        action=action,
        entity_type=entity_type,
    )
