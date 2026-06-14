from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, Query, status
from fastapi.responses import Response, StreamingResponse

from app.api.dependencies import get_current_user, get_report_service
from app.core.authorization import require_permission
from app.models.user import User
from app.schemas.report import (
    AnalyticsOverviewResponse,
    AuditReportResponse,
    CustomerReportResponse,
    ExportFormat,
    InventoryReportResponse,
    ReportType,
    RevenueReportResponse,
    TransactionReportResponse,
)
from app.services.report import ReportService

router = APIRouter()


@router.get(
    "/analytics",
    response_model=AnalyticsOverviewResponse,
    status_code=status.HTTP_200_OK,
    summary="Analytics overview for dashboard KPIs and trends",
)
@require_permission("report.view")
async def get_analytics_overview(
    report_service: ReportService = Depends(get_report_service),
    current_user: User = Depends(get_current_user),
) -> AnalyticsOverviewResponse:
    return await report_service.get_analytics_overview(current_user)


@router.get(
    "/revenue",
    response_model=RevenueReportResponse,
    status_code=status.HTTP_200_OK,
    summary="Revenue report",
)
@require_permission("report.view")
async def get_revenue_report(
    start_date: Optional[datetime] = Query(None),
    end_date: Optional[datetime] = Query(None),
    report_service: ReportService = Depends(get_report_service),
    current_user: User = Depends(get_current_user),
) -> RevenueReportResponse:
    return await report_service.get_revenue_report(
        current_user, start=start_date, end=end_date
    )


@router.get(
    "/inventory",
    response_model=InventoryReportResponse,
    status_code=status.HTTP_200_OK,
    summary="Inventory report",
)
@require_permission("report.view")
async def get_inventory_report(
    report_service: ReportService = Depends(get_report_service),
    current_user: User = Depends(get_current_user),
) -> InventoryReportResponse:
    return await report_service.get_inventory_report(current_user)


@router.get(
    "/customers",
    response_model=CustomerReportResponse,
    status_code=status.HTTP_200_OK,
    summary="Customer report",
)
@require_permission("report.view")
async def get_customer_report(
    report_service: ReportService = Depends(get_report_service),
    current_user: User = Depends(get_current_user),
) -> CustomerReportResponse:
    return await report_service.get_customer_report(current_user)


@router.get(
    "/transactions",
    response_model=TransactionReportResponse,
    status_code=status.HTTP_200_OK,
    summary="Transaction report",
)
@require_permission("report.view")
async def get_transaction_report(
    start_date: Optional[datetime] = Query(None),
    end_date: Optional[datetime] = Query(None),
    report_service: ReportService = Depends(get_report_service),
    current_user: User = Depends(get_current_user),
) -> TransactionReportResponse:
    return await report_service.get_transaction_report(
        current_user, start=start_date, end=end_date
    )


@router.get(
    "/audit",
    response_model=AuditReportResponse,
    status_code=status.HTTP_200_OK,
    summary="Audit report",
)
@require_permission("report.view")
async def get_audit_report(
    start_date: Optional[datetime] = Query(None),
    end_date: Optional[datetime] = Query(None),
    report_service: ReportService = Depends(get_report_service),
    current_user: User = Depends(get_current_user),
) -> AuditReportResponse:
    return await report_service.get_audit_report(
        current_user, start=start_date, end=end_date
    )


@router.get(
    "/{report_type}/export",
    status_code=status.HTTP_200_OK,
    summary="Export report as CSV, Excel, or PDF",
)
@require_permission("report.export")
async def export_report(
    report_type: ReportType,
    format: ExportFormat = Query("csv", alias="format"),
    start_date: Optional[datetime] = Query(None),
    end_date: Optional[datetime] = Query(None),
    report_service: ReportService = Depends(get_report_service),
    current_user: User = Depends(get_current_user),
) -> Response:
    (
        content,
        filename,
        media_type,
        row_count,
        truncated,
    ) = await report_service.export_report(
        report_type,
        format,
        current_user,
        start=start_date,
        end=end_date,
        performing_user_id=current_user.id,
    )

    headers = {
        "Content-Disposition": f'attachment; filename="{filename}"',
        "X-Export-Total": str(row_count),
        "X-Export-Truncated": "true" if truncated else "false",
    }

    if isinstance(content, str):
        return StreamingResponse(
            iter([content]),
            media_type=media_type,
            headers=headers,
        )

    return Response(content=content, media_type=media_type, headers=headers)
