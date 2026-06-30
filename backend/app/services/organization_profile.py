from __future__ import annotations

from typing import Optional

from app.core import audit_actions
from app.core.exceptions import NotFoundException
from app.models.user import User
from app.repositories.organization_profile import OrganizationProfileRepository
from app.schemas.organization_profile import (
    OrganizationProfilePublicResponse,
    OrganizationProfileResponse,
    OrganizationProfileUpdate,
)
from app.services.audit import AuditService


class OrganizationProfileService:
    def __init__(
        self,
        repo: OrganizationProfileRepository,
        audit_service: Optional[AuditService] = None,
    ):
        self.repo = repo
        self.audit_service = audit_service

    async def get_public(self) -> OrganizationProfilePublicResponse:
        row = await self.repo.get_singleton()
        if not row:
            return OrganizationProfilePublicResponse(
                organization_name="AGS Gold",
                admin_name="AGS Gold Support",
                support_contact_number="+91 98765 43210",
            )
        return OrganizationProfilePublicResponse(
            organization_name=row.organization_name,
            admin_name=row.admin_name,
            support_contact_number=row.support_contact_number,
            support_email=row.support_email,
            office_address=row.office_address,
            business_hours=row.business_hours,
            emergency_contact=row.emergency_contact,
        )

    async def get_full(self) -> OrganizationProfileResponse:
        row = await self.repo.get_singleton()
        if not row:
            raise NotFoundException("Organization profile not configured")
        return OrganizationProfileResponse.model_validate(row)

    async def update(
        self, payload: OrganizationProfileUpdate, admin_user: User
    ) -> OrganizationProfileResponse:
        row = await self.repo.get_singleton()
        if not row:
            raise NotFoundException("Organization profile not configured")
        data = payload.model_dump()
        data["updated_by"] = admin_user.id
        row = await self.repo.update(row, data)
        if self.audit_service:
            await self.audit_service.log_action(
                user_id=admin_user.id,
                action=audit_actions.ADMIN_PROFILE_UPDATED,
                entity_type="OrganizationProfile",
                entity_id=str(row.id),
                metadata={"organization_name": row.organization_name},
            )
        return OrganizationProfileResponse.model_validate(row)
