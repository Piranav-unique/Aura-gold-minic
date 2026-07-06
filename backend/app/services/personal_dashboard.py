import asyncio
import time
from datetime import datetime, timezone
from decimal import Decimal

from app.core.config import settings
from app.core.kyc_profile import loads_profile, profile_for_api, profile_to_schema
from app.models.user import User
from app.repositories.workflow import WorkflowRepository
from app.schemas.dashboard import (
    AssignedTaskSummary,
    DailyActivityItem,
    PersonalDashboardResponse,
)
from app.services.audit import AuditService
from app.services.dashboard_cache import get_personal_dashboard_cache
from app.services.gold_scheme import GoldSchemeService
from app.services.notification import NotificationService

_personal_cache = get_personal_dashboard_cache()


def _display_name(user: User) -> str:
    parts = [p for p in (user.first_name, user.last_name) if p]
    if parts:
        return " ".join(parts)
    return user.mobile_number or user.email


class PersonalDashboardService:
    """Aggregates personal home dashboard data for any authenticated user."""

    def __init__(
        self,
        audit_service: AuditService,
        notification_service: NotificationService,
        workflow_repo: WorkflowRepository,
    ):
        self.audit_service = audit_service
        self.notification_service = notification_service
        self.workflow_repo = workflow_repo

    async def get_dashboard(self, user: User) -> PersonalDashboardResponse:
        cache_key = str(user.id)
        now_mono = time.monotonic()
        cached = _personal_cache.get(cache_key)
        if cached and (now_mono - cached[0]) < settings.DASHBOARD_CACHE_TTL_SECONDS:
            return cached[1]

        refreshed_at = datetime.now(timezone.utc)

        assigned_coro = self.workflow_repo.list_filtered(
            skip=0,
            limit=8,
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
            skip=0, limit=10, user_id=user.id
        )
        trend_coro = self.audit_service.get_activity_trend(days=7, user_id=user.id)
        unread_coro = self.notification_service.get_unread_count(user.id)
        notifications_coro = self.notification_service.list_notifications(
            user_id=user.id,
            skip=0,
            limit=5,
            is_read=False,
        )
        login_stats_coro = self.audit_service.get_login_statistics(
            user_id=user.id,
            system_wide=False,
        )

        (
            assigned_items,
            my_requests,
            activity_result,
            activity_trend,
            unread,
            notifications_result,
            login_stats,
        ) = await asyncio.gather(
            assigned_coro,
            my_requests_coro,
            activity_coro,
            trend_coro,
            unread_coro,
            notifications_coro,
            login_stats_coro,
        )

        activity_logs, _ = activity_result
        notifications, _, _ = notifications_result

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

        draft_count = 0
        for draft in my_requests:
            if draft.state == "draft":
                draft_count += 1
                if len(assigned_tasks) < 8:
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

        pending_count = sum(1 for t in assigned_tasks if t.state == "pending")

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

        payload = PersonalDashboardResponse(
            display_name=_display_name(user),
            email=user.email,
            mobile_number=user.mobile_number,
            roles=[role.name for role in user.roles],
            unread_notifications=unread,
            refreshed_at=refreshed_at,
            login_statistics=login_stats,
            activity_trend=activity_trend,
            recent_notifications=notifications,
            assigned_tasks=assigned_tasks,
            daily_activities=daily_activities,
            pending_task_count=pending_count,
            draft_task_count=draft_count,
            kyc_status=user.kyc_status or "not_started",
            kyc_profile=profile_to_schema(
                profile_for_api(user.kyc_status or "not_started", loads_profile(user.kyc_profile))
            ),
            gold_savings_grams=Decimal(str(user.gold_savings_grams or 0)),
            silver_savings_grams=Decimal(str(user.silver_savings_grams or 0)),
            gold_invested_inr=Decimal(str(user.gold_invested_inr or 0)),
            silver_invested_inr=Decimal(str(user.silver_invested_inr or 0)),
            wallet_balance_inr=Decimal(str(user.wallet_balance_inr or 0)),
            gold_scheme=GoldSchemeService.build_response(user),
        )

        _personal_cache[cache_key] = (now_mono, payload)
        return payload

    @staticmethod
    def _activity_description(action: str, entity_type: str | None) -> str:
        readable = action.replace("_", " ").title()
        if entity_type:
            return f"{readable} on {entity_type}"
        return readable
