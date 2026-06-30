from fastapi import APIRouter, Depends

from app.api.dependencies import get_organization_profile_service
from app.schemas.organization_profile import OrganizationProfilePublicResponse
from app.services.organization_profile import OrganizationProfileService

router = APIRouter()


@router.get(
    "",
    response_model=OrganizationProfilePublicResponse,
    summary="Public organization contact details",
)
async def get_public_organization_profile(
    service: OrganizationProfileService = Depends(get_organization_profile_service),
) -> OrganizationProfilePublicResponse:
    return await service.get_public()
