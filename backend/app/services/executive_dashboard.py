import asyncio
import time
from datetime import datetime, timezone
from typing import Optional

from app.core.config import settings
from app.core.permissions import user_has_permission
from app.models.user import User
from app.repositories.customer import CustomerRepository
from app.repositories.report import ReportRepository
from app.repositories.user import UserRepository
from app.repositories.workflow import WorkflowRepository
from app.schemas.dashboard import (
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
from app.schemas.inventory import InventoryItemResponse
from app.services.audit import AuditService
from app.services.inventory import InventoryService
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
        inventory_service: Optional[InventoryService] = None,
        transaction_service: Optional[TransactionService] = None,
    ):
        self.audit_service = audit_service
        self.notification_service = notification_service
        self.customer_repo = customer_repo
        self.user_repo = user_repo
        self.workflow_repo = workflow_repo
        self.report_repo = report_repo
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

        if user_has_permission(user, "transaction.view"):
            if self.transaction_service:
                trend_rows, growth, txn = await asyncio.gather(
                    self.report_repo.revenue_trend(days=30),
                    self.report_repo.revenue_growth_percent(),
                    self.transaction_service.get_metrics(),
                )
                transaction_metrics = TransactionDashboardMetrics.model_validate(
                    txn.model_dump()
                )
            else:
                trend_rows, growth = await asyncio.gather(
                    self.report_repo.revenue_trend(days=30),
                    self.report_repo.revenue_growth_percent(),
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
