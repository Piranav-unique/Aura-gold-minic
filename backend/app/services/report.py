import time
import uuid
from datetime import datetime, timedelta, timezone
from typing import Optional

from app.core import audit_actions
from app.core.config import settings
from app.core.exceptions import ForbiddenException, ValidationException
from app.core.permissions import user_has_permission
from app.models.user import User
from app.repositories.report import ReportRepository
from app.schemas.report import (
    AnalyticsOverviewResponse,
    AuditBreakdownRow,
    AuditReportResponse,
    CustomerReportResponse,
    CustomerTypeRow,
    ExportFormat,
    InventoryCategoryRow,
    InventoryReportResponse,
    InventoryTrendPoint,
    KpiCard,
    ActivityTrendPoint,
    ReportType,
    RevenueReportResponse,
    RevenueTrendPoint,
    TransactionBreakdownRow,
    TransactionReportResponse,
)
from app.services.audit import AuditService
from app.utils.report_export import (
    MEDIA_TYPES,
    export_filename,
    rows_to_csv,
    rows_to_pdf,
    rows_to_xlsx,
)

_cache: dict[str, tuple[float, AnalyticsOverviewResponse]] = {}


class ReportService:
    """Reports and analytics aggregation with export support."""

    def __init__(
        self,
        report_repo: ReportRepository,
        audit_service: Optional[AuditService] = None,
    ):
        self.report_repo = report_repo
        self.audit_service = audit_service

    def _require(self, user: User, permission: str) -> None:
        if not user_has_permission(user, permission):
            raise ForbiddenException(f"You do not have permission: {permission}")

    def _default_period(
        self, start: Optional[datetime], end: Optional[datetime], days: int = 30
    ) -> tuple[datetime, datetime]:
        end_dt = end or datetime.now(timezone.utc)
        start_dt = start or (end_dt - timedelta(days=days))
        return start_dt, end_dt

    async def get_analytics_overview(self, user: User) -> AnalyticsOverviewResponse:
        cache_key = str(user.id)
        now = time.monotonic()
        cached = _cache.get(cache_key)
        if cached and (now - cached[0]) < settings.REPORT_ANALYTICS_CACHE_TTL_SECONDS:
            return cached[1]

        kpis: list[KpiCard] = []
        revenue_trend: list[RevenueTrendPoint] = []
        inventory_trend: list[InventoryTrendPoint] = []
        revenue_growth = None

        if user_has_permission(user, "transaction.view"):
            now_dt = datetime.now(timezone.utc)
            day_start = now_dt.replace(hour=0, minute=0, second=0, microsecond=0)
            day_end = day_start.replace(
                hour=23, minute=59, second=59, microsecond=999999
            )
            month_start = day_start.replace(day=1)

            daily = await self.report_repo.revenue_period_summary(day_start, day_end)
            monthly = await self.report_repo.revenue_period_summary(
                month_start, day_end
            )
            revenue_growth = await self.report_repo.revenue_growth_percent()
            trend_rows = await self.report_repo.revenue_trend(days=30)
            revenue_trend = [
                RevenueTrendPoint(
                    label=r["label"],
                    revenue=r["revenue"],
                    transaction_count=r["transaction_count"],
                )
                for r in trend_rows
            ]
            kpis.extend(
                [
                    KpiCard(
                        key="daily_revenue",
                        label="Daily Revenue",
                        value=f"₹{daily['total_revenue']:,.0f}",
                        trend_label="Today",
                        trend_positive=True,
                    ),
                    KpiCard(
                        key="monthly_revenue",
                        label="Monthly Revenue",
                        value=f"₹{monthly['total_revenue']:,.0f}",
                        trend_label="This month",
                        trend_positive=True,
                    ),
                ]
            )
            if revenue_growth is not None:
                kpis.append(
                    KpiCard(
                        key="revenue_growth",
                        label="Revenue Growth",
                        value=f"{revenue_growth:+.1f}%",
                        trend_label="vs last month",
                        trend_positive=revenue_growth >= 0,
                    )
                )

        if user_has_permission(user, "inventory.view"):
            inv = await self.report_repo.inventory_summary()
            inv_trend = await self.report_repo.inventory_movement_trend(days=30)
            inventory_trend = [InventoryTrendPoint(**row) for row in inv_trend]
            kpis.extend(
                [
                    KpiCard(
                        key="inventory_value",
                        label="Inventory Value",
                        value=f"₹{inv['inventory_value']:,.0f}",
                        trend_label=f"{inv['total_stock']} units",
                        trend_positive=True,
                    ),
                    KpiCard(
                        key="low_stock",
                        label="Low Stock Items",
                        value=str(inv["low_stock_count"]),
                        trend_label="Alert",
                        trend_positive=inv["low_stock_count"] == 0,
                    ),
                ]
            )

        if user_has_permission(user, "customer.view"):
            cust = await self.report_repo.customer_summary()
            kpis.append(
                KpiCard(
                    key="active_customers",
                    label="Active Customers",
                    value=str(cust["active_customers"]),
                    trend_label=f"{cust['total_customers']} total",
                    trend_positive=True,
                )
            )

        activity_trend: list[ActivityTrendPoint] = []
        if user_has_permission(user, "audit.view") and self.audit_service:
            raw_trend = await self.audit_service.get_activity_trend(days=7)
            activity_trend = [
                ActivityTrendPoint(label=row["label"], count=int(row["count"]))
                for row in raw_trend
            ]

        overview = AnalyticsOverviewResponse(
            kpis=kpis,
            revenue_trend=revenue_trend,
            inventory_trend=inventory_trend,
            revenue_growth_percent=revenue_growth,
            activity_trend=activity_trend,
        )
        _cache[cache_key] = (now, overview)
        return overview

    async def get_revenue_report(
        self,
        user: User,
        start: Optional[datetime] = None,
        end: Optional[datetime] = None,
    ) -> RevenueReportResponse:
        self._require(user, "report.view")
        self._require(user, "transaction.view")
        start_dt, end_dt = self._default_period(start, end, days=30)
        summary = await self.report_repo.revenue_period_summary(start_dt, end_dt)
        trend = await self.report_repo.revenue_trend(days=30)
        top = await self.report_repo.top_customers_report(limit=10)
        growth = await self.report_repo.revenue_growth_percent()
        return RevenueReportResponse(
            period_start=start_dt,
            period_end=end_dt,
            total_revenue=summary["total_revenue"],
            transaction_count=summary["transaction_count"],
            revenue_growth_percent=growth,
            daily_trend=[
                RevenueTrendPoint(
                    label=r["label"],
                    revenue=r["revenue"],
                    transaction_count=r["transaction_count"],
                )
                for r in trend
            ],
            top_customers=top,
        )

    async def get_inventory_report(self, user: User) -> InventoryReportResponse:
        self._require(user, "report.view")
        self._require(user, "inventory.view")
        summary = await self.report_repo.inventory_summary()
        by_cat = await self.report_repo.inventory_by_category()
        trend = await self.report_repo.inventory_movement_trend(days=30)
        return InventoryReportResponse(
            total_stock=summary["total_stock"],
            inventory_value=summary["inventory_value"],
            low_stock_count=summary["low_stock_count"],
            item_count=summary["item_count"],
            by_category=[InventoryCategoryRow(**row) for row in by_cat],
            movement_trend=[InventoryTrendPoint(**row) for row in trend],
        )

    async def get_customer_report(self, user: User) -> CustomerReportResponse:
        self._require(user, "report.view")
        self._require(user, "customer.view")
        summary = await self.report_repo.customer_summary()
        top = await self.report_repo.top_customers_report(limit=10)
        by_type = await self.report_repo.customer_type_breakdown()
        return CustomerReportResponse(
            total_customers=summary["total_customers"],
            active_customers=summary["active_customers"],
            total_revenue=summary["total_revenue"],
            total_purchases=summary["total_purchases"],
            top_customers=top,
            by_type=[CustomerTypeRow(**row) for row in by_type],
        )

    async def get_transaction_report(
        self,
        user: User,
        start: Optional[datetime] = None,
        end: Optional[datetime] = None,
    ) -> TransactionReportResponse:
        self._require(user, "report.view")
        self._require(user, "transaction.view")
        start_dt, end_dt = self._default_period(start, end, days=30)
        breakdown = await self.report_repo.transaction_breakdown(start_dt, end_dt)
        total = sum(row["count"] for row in breakdown)
        return TransactionReportResponse(
            period_start=start_dt,
            period_end=end_dt,
            total_count=total,
            breakdown=[TransactionBreakdownRow(**row) for row in breakdown],
        )

    async def get_audit_report(
        self,
        user: User,
        start: Optional[datetime] = None,
        end: Optional[datetime] = None,
    ) -> AuditReportResponse:
        self._require(user, "report.view")
        self._require(user, "audit.view")
        start_dt, end_dt = self._default_period(start, end, days=30)
        breakdown = await self.report_repo.audit_action_breakdown(start_dt, end_dt)
        total = await self.report_repo.count_audit_logs(start_dt, end_dt)
        return AuditReportResponse(
            period_start=start_dt,
            period_end=end_dt,
            total_events=total,
            breakdown=[AuditBreakdownRow(**row) for row in breakdown],
        )

    async def _build_export_rows(
        self,
        report_type: ReportType,
        user: User,
        start: Optional[datetime],
        end: Optional[datetime],
    ) -> tuple[list[str], list[list], int, bool]:
        limit = settings.REPORT_EXPORT_MAX_ROWS
        headers: list[str] = []
        rows: list[list] = []
        truncated = False

        if report_type == "revenue":
            report = await self.get_revenue_report(user, start, end)
            headers = ["Date", "Revenue", "Transactions"]
            rows = [
                [p.label, p.revenue, p.transaction_count] for p in report.daily_trend
            ]
            for tc in report.top_customers:
                rows.append(
                    [
                        f"TOP: {tc['full_name']}",
                        tc["revenue"],
                        tc["transaction_count"],
                    ]
                )
            return headers, rows, len(rows), False

        if report_type == "inventory":
            report = await self.get_inventory_report(user)
            headers = ["Category", "Items", "Stock", "Value"]
            rows = [
                [c["category"], c["item_count"], c["total_stock"], c["category_value"]]
                for c in report.by_category
            ]
            rows.insert(
                0,
                [
                    "SUMMARY",
                    report.item_count,
                    report.total_stock,
                    report.inventory_value,
                ],
            )
            return headers, rows, len(rows), False

        if report_type == "customer":
            report = await self.get_customer_report(user)
            headers = ["Customer", "Revenue", "Transactions"]
            rows = [
                [c["full_name"], c["revenue"], c["transaction_count"]]
                for c in report.top_customers
            ]
            for bt in report.by_type:
                rows.append([f"TYPE:{bt['customer_type']}", bt["revenue"], bt["count"]])
            return headers, rows, len(rows), False

        if report_type == "transaction":
            self._require(user, "transaction.view")
            start_dt, end_dt = self._default_period(start, end, days=30)
            items = await self.report_repo.list_transactions_for_report(
                start_dt, end_dt, limit=limit + 1
            )
            truncated = len(items) > limit
            items = items[:limit]
            headers = [
                "Number",
                "Type",
                "Payment",
                "Status",
                "Total",
                "Created",
            ]
            rows = [
                [
                    t.transaction_number,
                    t.transaction_type,
                    t.payment_status,
                    t.status,
                    t.total_amount,
                    t.created_at,
                ]
                for t in items
            ]
            return headers, rows, len(items), truncated

        if report_type == "audit":
            self._require(user, "audit.view")
            if not self.audit_service:
                return [], [], 0, False
            start_dt, end_dt = self._default_period(start, end, days=30)
            total = await self.report_repo.count_audit_logs(start_dt, end_dt)
            truncated = total > limit
            logs, _ = await self.audit_service.list_audit_logs(
                skip=0,
                limit=limit,
                start_date=start_dt,
                end_date=end_dt,
            )
            headers = [
                "Timestamp",
                "Action",
                "Entity",
                "Entity ID",
                "User ID",
                "IP",
            ]
            rows = [
                [
                    log.timestamp,
                    log.action,
                    log.entity_type,
                    log.entity_id,
                    log.user_id,
                    log.ip_address,
                ]
                for log in logs
            ]
            return headers, rows, len(rows), truncated

        raise ValidationException(f"Unknown report type: {report_type}")

    async def export_report(
        self,
        report_type: ReportType,
        fmt: ExportFormat,
        user: User,
        *,
        start: Optional[datetime] = None,
        end: Optional[datetime] = None,
        performing_user_id: Optional[uuid.UUID] = None,
    ) -> tuple[bytes | str, str, str, int, bool]:
        self._require(user, "report.export")

        headers, rows, row_count, truncated = await self._build_export_rows(
            report_type, user, start, end
        )
        filename = export_filename(report_type, fmt)
        title = f"AGS Gold — {report_type.title()} Report"
        subtitle = f"Rows: {row_count}" + (" (truncated)" if truncated else "")

        if fmt == "csv":
            content: bytes | str = rows_to_csv(headers, rows)
        elif fmt == "xlsx":
            content = rows_to_xlsx(report_type.title(), headers, rows)
        elif fmt == "pdf":
            content = rows_to_pdf(title, headers, rows, subtitle=subtitle)
        else:
            raise ValidationException(f"Unsupported export format: {fmt}")

        if self.audit_service:
            await self.audit_service.log_action(
                user_id=performing_user_id,
                action=audit_actions.REPORT_EXPORT,
                entity_type="Report",
                metadata={
                    "report_type": report_type,
                    "format": fmt,
                    "row_count": row_count,
                    "truncated": truncated,
                },
            )

        return content, filename, MEDIA_TYPES[fmt], row_count, truncated
