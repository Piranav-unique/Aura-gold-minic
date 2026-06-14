from fastapi import APIRouter, Depends, status

from app.api.dependencies import (
    get_current_user,
    get_dashboard_service,
    get_executive_dashboard_service,
)
from app.core.authorization import require_permission
from app.models.user import User
from app.schemas.dashboard import DashboardStatsResponse, ExecutiveDashboardResponse
from app.services.dashboard import DashboardService
from app.services.executive_dashboard import ExecutiveDashboardService

router = APIRouter()


@router.get(
    "/stats",
    response_model=DashboardStatsResponse,
    status_code=status.HTTP_200_OK,
    summary="Get dashboard statistics and widget data",
)
@require_permission("dashboard.view")
async def get_dashboard_stats(
    current_user: User = Depends(get_current_user),
    dashboard_service: DashboardService = Depends(get_dashboard_service),
) -> DashboardStatsResponse:
    stats = await dashboard_service.get_stats(current_user)
    return DashboardStatsResponse(**stats)


@router.get(
    "/executive",
    response_model=ExecutiveDashboardResponse,
    status_code=status.HTTP_200_OK,
    summary="Get role-based executive dashboard",
)
@require_permission("dashboard.view")
async def get_executive_dashboard(
    current_user: User = Depends(get_current_user),
    executive_service: ExecutiveDashboardService = Depends(
        get_executive_dashboard_service
    ),
) -> ExecutiveDashboardResponse:
    return await executive_service.get_dashboard(current_user)
