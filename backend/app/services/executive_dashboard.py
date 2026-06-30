import asyncio
import time
from datetime import datetime, timezone
from decimal import Decimal
from typing import Optional

from app.core.config import settings
from app.core.permissions import user_has_permission
from app.models.user import User
from app.repositories.app_metrics import AppMetricsRepository
from app.repositories.customer import CustomerRepository
from app.repositories.digital_metal_inventory import DigitalMetalInventoryRepository
from app.repositories.report import ReportRepository
from app.repositories.user import UserRepository
from app.repositories.workflow import WorkflowRepository
from app.schemas.dashboard import (
    AppDashboardMetrics,
    AssignedTaskSummary,
    CustomerDashboardMetrics,
    DailyActivityItem,
    ExecutiveDashboardResponse,
    ExecutiveRole,
    InventoryDashboardMetrics,
    RevenueTrendPoint,
    TeamDashboardMetrics,
    TransactionDashboardMetrics,
    WorkflowApprovalSummary,
)
from app.schemas.digital_metal_inventory import compute_stock_status
from app.schemas.inventory import InventoryItemResponse
from app.services.audit import AuditService
from app.services.inventory import InventoryService
from app.services.metal_prices import MetalPriceService
from app.services.notification import NotificationService
from app.services.transaction import TransactionService

_executive_cache: dict[str, tuple[float, ExecutiveDashboardResponse]] = {}


def resolve_executive_role(user: User) -> ExecutiveRole:
    """Map authenticated user to executive dashboard persona."""
    if user.is_superuser:
        return "admin"

    role_names = {role.name for role in user.roles}
    if role_names & {"super_admin", "admin"}:
        return "admin"
    if "manager" in role_names:
        return "manager"
    if "employee" in role_names:
        return "employee"

    if user_has_permission(user, "audit.view") and user_has_permission(
        user, "transaction.view"
    ):
        return "admin"
    if user_has_permission(user, "workflow.approve"):
        return "manager"
    return "employee"


def _display_name(user: User) -> str:
    parts = [p for p in (user.first_name, user.last_name) if p]
    return " ".join(parts) if parts else user.email


class ExecutiveDashboardService:
    """Role-aware executive dashboard aggregation."""

    def __init__(
        self,
        audit_service: AuditService,
        notification_service: NotificationService,
        customer_repo: CustomerRepository,
        user_repo: UserRepository,
        workflow_repo: WorkflowRepository,
        report_repo: ReportRepository,
        app_metrics_repo: AppMetricsRepository,
        digital_inventory_repo: DigitalMetalInventoryRepository,
        metal_price_service: MetalPriceService,
        inventory_service: Optional[InventoryService] = None,
        transaction_service: Optional[TransactionService] = None,
    ):
        self.audit_service = audit_service
        self.notification_service = notification_service
        self.customer_repo = customer_repo
        self.user_repo = user_repo
        self.workflow_repo = workflow_repo
        self.report_repo = report_repo
        self.app_metrics_repo = app_metrics_repo
        self.digital_inventory_repo = digital_inventory_repo
        self.metal_price_service = metal_price_service
        self.inventory_service = inventory_service
        self.transaction_service = transaction_service

    async def get_dashboard(self, user: User) -> ExecutiveDashboardResponse:
        role = resolve_executive_role(user)
        cache_key = f"{user.id}:{role}"
        now_mono = time.monotonic()
        cached = _executive_cache.get(cache_key)
        if cached and (now_mono - cached[0]) < settings.DASHBOARD_CACHE_TTL_SECONDS:
            return cached[1]

        unread = await self.notification_service.get_unread_count(user.id)
        refreshed_at = datetime.now(timezone.utc)

        if role == "admin":
            payload = await self._build_admin_dashboard(user, unread, refreshed_at)
        elif role == "manager":
            payload = await self._build_manager_dashboard(user, unread, refreshed_at)
        else:
            payload = await self._build_employee_dashboard(user, unread, refreshed_at)

        _executive_cache[cache_key] = (now_mono, payload)
        return payload

    async def _build_admin_dashboard(
        self, user: User, unread: int, refreshed_at: datetime
    ) -> ExecutiveDashboardResponse:
        activity_trend: list = []
        if user_has_permission(user, "audit.view"):
            activity_trend = await self.audit_service.get_activity_trend(
                days=7, user_id=None
            )

        revenue_trend: list[RevenueTrendPoint] = []
        revenue_growth = None
        transaction_metrics = None
        customer_metrics = None
        inventory_metrics = None
        app_metrics = None

        can_view_wallet = user_has_permission(user, "wallet.view")
        can_view_transactions = user_has_permission(user, "transaction.view")

        if can_view_wallet or can_view_transactions:
            now = datetime.now(timezone.utc)
            day_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
            day_end = day_start.replace(hour=23, minute=59, second=59, microsecond=999999)
            month_start = day_start.replace(day=1)

            (
                total_revenue,
                monthly_revenue,
                daily_revenue,
                total_transactions,
                monthly_transactions,
                member_count,
                members_new,
                trend_rows,
                growth,
            ) = await asyncio.gather(
                self.app_metrics_repo.paid_revenue_sum(),
                self.app_metrics_repo.paid_revenue_sum(start=month_start, end=day_end),
                self.app_metrics_repo.paid_revenue_sum(start=day_start, end=day_end),
                self.app_metrics_repo.count_wallet_transactions(),
                self.app_metrics_repo.count_wallet_transactions(
                    start=month_start, end=day_end
                ),
                self.app_metrics_repo.count_app_members(),
                self.app_metrics_repo.count_new_members_this_month(),
                self.app_metrics_repo.payment_revenue_trend(days=30),
                self.app_metrics_repo.payment_revenue_growth_percent(),
            )

            metal_inventory_value = Decimal("0")
            gold_available = Decimal("0")
            silver_available = Decimal("0")
            low_stock_metal_count = 0

            if user_has_permission(user, "inventory.view"):
                metals = await self.digital_inventory_repo.list_all()
                prices = await self.metal_price_service.get_prices()
                price_by_metal = {
                    "gold": prices.gold.retail_price,
                    "silver": prices.silver.retail_price,
                }
                for row in metals:
                    available = row.available_weight_grams
                    rate = price_by_metal.get(row.metal_type, Decimal("0"))
                    metal_inventory_value += available * rate
                    if row.metal_type == "gold":
                        gold_available = available
                    elif row.metal_type == "silver":
                        silver_available = available
                    status = compute_stock_status(
                        available, row.low_stock_threshold_grams
                    )
                    if status in {"low_stock", "out_of_stock"}:
                        low_stock_metal_count += 1

            app_metrics = AppDashboardMetrics(
                total_revenue=total_revenue,
                monthly_revenue=monthly_revenue,
                daily_revenue=daily_revenue,
                total_transactions=total_transactions,
                monthly_transactions=monthly_transactions,
                member_count=member_count,
                members_new_this_month=members_new,
                metal_inventory_value=metal_inventory_value,
                gold_available_grams=gold_available,
                silver_available_grams=silver_available,
                low_stock_metal_count=low_stock_metal_count,
            )
            revenue_trend = [
                RevenueTrendPoint(
                    label=row["label"],
                    revenue=row["revenue"],
                    transaction_count=row.get("transaction_count", 0),
                )
                for row in trend_rows
            ]
            revenue_growth = growth

        if user_has_permission(user, "customer.view"):
            customer_metrics = CustomerDashboardMetrics(
                **(await self.customer_repo.dashboard_metrics())
            )

        if self.inventory_service and user_has_permission(user, "inventory.view"):
            inv = await self.inventory_service.get_metrics(low_stock_limit=5)
            inventory_metrics = InventoryDashboardMetrics(
                total_stock=inv.total_stock,
                inventory_value=inv.inventory_value,
                low_stock_count=inv.low_stock_count,
                low_stock_items=inv.low_stock_items,
            )

        return ExecutiveDashboardResponse(
            role="admin",
            display_name=_display_name(user),
            unread_notifications=unread,
            refreshed_at=refreshed_at,
            revenue_trend=revenue_trend,
            revenue_growth_percent=revenue_growth,
            customer_metrics=customer_metrics,
            app_metrics=app_metrics,
            inventory_metrics=inventory_metrics,
            transaction_metrics=transaction_metrics,
            activity_trend=activity_trend,
        )

    async def _build_manager_dashboard(
        self, user: User, unread: int, refreshed_at: datetime
    ) -> ExecutiveDashboardResponse:
        today_start = datetime.now(timezone.utc).replace(
            hour=0, minute=0, second=0, microsecond=0
        )
        can_view_audit = user_has_permission(user, "audit.view")
        can_view_users = user_has_permission(user, "user.view")
        can_approve = user_has_permission(user, "workflow.approve")

        login_stats = {"today": 0, "week": 0, "month": 0}
        activity_total = 0
        active_users = 0
        pending_count = 0
        pending_items: list = []

        if can_view_audit:
            login_stats = await self.audit_service.get_login_statistics(
                user_id=user.id, system_wide=True
            )
            _, activity_total = await self.audit_service.list_audit_logs(
                skip=0,
                limit=1,
                user_id=None,
                start_date=today_start,
            )

        if can_view_users:
            active_users = await self.user_repo.count_active_users()

        if can_approve:
            pending_count = await self.workflow_repo.count_pending()
            pending_items = await self.workflow_repo.list_filtered(
                skip=0,
                limit=8,
                state="pending",
                sort_by="pending_since",
                sort_order="asc",
            )

        inventory_alerts: list[InventoryItemResponse] = []
        if self.inventory_service and user_has_permission(user, "inventory.view"):
            inv = await self.inventory_service.get_metrics(low_stock_limit=10)
            inventory_alerts = inv.low_stock_items

        pending_approvals = [
            WorkflowApprovalSummary(
                id=item.id,
                request_number=item.request_number,
                title=item.title,
                state=item.state,
                requester_name=(
                    f"{item.requester.first_name or ''} {item.requester.last_name or ''}".strip()
                    if item.requester
                    else None
                )
                or (item.requester.email if item.requester else None),
                assignee_name=(
                    f"{item.assignee.first_name or ''} {item.assignee.last_name or ''}".strip()
                    if item.assignee
                    else None
                )
                or (item.assignee.email if item.assignee else None),
                pending_since=item.pending_since,
                escalation_level=item.escalation_level,
            )
            for item in pending_items
        ]

        team_metrics = TeamDashboardMetrics(
            active_users=active_users,
            pending_approvals=pending_count,
            logins_today=login_stats["today"],
            team_activity_today=activity_total,
        )

        return ExecutiveDashboardResponse(
            role="manager",
            display_name=_display_name(user),
            unread_notifications=unread,
            refreshed_at=refreshed_at,
            team_metrics=team_metrics,
            pending_approvals=pending_approvals,
            inventory_alerts=inventory_alerts,
        )

    async def _build_employee_dashboard(
        self, user: User, unread: int, refreshed_at: datetime
    ) -> ExecutiveDashboardResponse:
        assigned_coro = self.workflow_repo.list_filtered(
            skip=0,
            limit=10,
            assignee_id=user.id,
            state="pending",
            sort_by="pending_since",
            sort_order="asc",
        )
        my_requests_coro = self.workflow_repo.list_filtered(
            skip=0,
            limit=5,
            requester_id=user.id,
            sort_by="created_at",
            sort_order="desc",
        )
        activity_coro = self.audit_service.list_audit_logs(
            skip=0, limit=12, user_id=user.id
        )
        trend_coro = self.audit_service.get_activity_trend(days=7, user_id=user.id)

        (
            assigned_items,
            my_requests,
            activity_result,
            activity_trend,
        ) = await asyncio.gather(
            assigned_coro,
            my_requests_coro,
            activity_coro,
            trend_coro,
        )
        activity_logs, _ = activity_result

        assigned_tasks = [
            AssignedTaskSummary(
                id=item.id,
                request_number=item.request_number,
                title=item.title,
                state=item.state,
                request_type=item.request_type,
                submitted_at=item.submitted_at,
            )
            for item in assigned_items
        ]

        for draft in my_requests:
            if draft.state == "draft" and len(assigned_tasks) < 10:
                assigned_tasks.append(
                    AssignedTaskSummary(
                        id=draft.id,
                        request_number=draft.request_number,
                        title=draft.title,
                        state=draft.state,
                        request_type=draft.request_type,
                        submitted_at=draft.submitted_at,
                    )
                )

        daily_activities = [
            DailyActivityItem(
                id=log.id,
                action=log.action,
                entity_type=log.entity_type,
                entity_id=log.entity_id,
                timestamp=log.timestamp,
                description=self._activity_description(log.action, log.entity_type),
            )
            for log in activity_logs
        ]

        return ExecutiveDashboardResponse(
            role="employee",
            display_name=_display_name(user),
            unread_notifications=unread,
            refreshed_at=refreshed_at,
            assigned_tasks=assigned_tasks,
            daily_activities=daily_activities,
            activity_trend=activity_trend,
        )

    @staticmethod
    def _activity_description(action: str, entity_type: Optional[str]) -> str:
        readable = action.replace("_", " ").title()
        if entity_type:
            return f"{readable} on {entity_type}"
        return readable
