from fastapi import APIRouter, Depends

from app.api.dependencies import get_current_user, get_organization_profile_service
from app.core.authorization import PermissionChecker
from app.core.exceptions import ForbiddenException
from app.models.user import User
from app.schemas.organization_profile import (
    OrganizationProfileResponse,
    OrganizationProfileUpdate,
)
from app.services.organization_profile import OrganizationProfileService

router = APIRouter()


def _require_superuser(user: User) -> User:
    if not user.is_superuser:
        raise ForbiddenException("Only super admin can update organization profile.")
    return user


@router.get(
    "",
    response_model=OrganizationProfileResponse,
    summary="Organization profile (admin view)",
)
async def get_organization_profile(
    current_user: User = Depends(PermissionChecker("organization.view")),
    service: OrganizationProfileService = Depends(get_organization_profile_service),
) -> OrganizationProfileResponse:
    return await service.get_full()


@router.put(
    "",
    response_model=OrganizationProfileResponse,
    summary="Update organization profile (super admin only)",
)
async def update_organization_profile(
    body: OrganizationProfileUpdate,
    current_user: User = Depends(get_current_user),
    service: OrganizationProfileService = Depends(get_organization_profile_service),
) -> OrganizationProfileResponse:
    _require_superuser(current_user)
    return await service.update(body, current_user)
