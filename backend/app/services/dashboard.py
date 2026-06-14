import asyncio
import time
import uuid
from typing import Any, Optional

from app.core import audit_actions
from app.core.config import settings
from app.core.permissions import user_has_permission
from app.models.user import User
from app.schemas.dashboard import (
    InventoryDashboardMetrics,
    TransactionDashboardMetrics,
)
from app.services.audit import AuditService
from app.services.notification import NotificationService
from app.services.inventory import InventoryService
from app.services.transaction import TransactionService

_cache: dict[str, tuple[float, dict[str, Any]]] = {}


class DashboardService:
    """Service aggregating dashboard widget data."""

    def __init__(
        self,
        audit_service: AuditService,
        notification_service: NotificationService,
        inventory_service: Optional[InventoryService] = None,
        transaction_service: Optional[TransactionService] = None,
    ):
        self.audit_service = audit_service
        self.notification_service = notification_service
        self.inventory_service = inventory_service
        self.transaction_service = transaction_service

    def _cache_key(self, user_id: uuid.UUID, can_view_all: bool) -> str:
        return f"{user_id}:{can_view_all}"

    async def get_stats(self, current_user: User) -> dict:
        can_view_all = user_has_permission(current_user, "audit.view")
        cache_key = self._cache_key(current_user.id, can_view_all)
        now = time.monotonic()
        cached = _cache.get(cache_key)
        if cached and (now - cached[0]) < settings.DASHBOARD_CACHE_TTL_SECONDS:
            return cached[1]

        activity_user_id = None if can_view_all else current_user.id
        system_wide_logins = can_view_all

        recent_activity_coro = self.audit_service.list_audit_logs(
            skip=0, limit=10, user_id=activity_user_id
        )
        security_alerts_coro = self.audit_service.list_audit_logs(
            skip=0,
            limit=5,
            action=audit_actions.LOGIN_FAILURE,
            user_id=None if can_view_all else current_user.id,
        )
        unread_coro = self.notification_service.get_unread_count(current_user.id)
        notifications_coro = self.notification_service.list_notifications(
            user_id=current_user.id,
            skip=0,
            limit=5,
            is_read=False,
        )
        login_stats_coro = self.audit_service.get_login_statistics(
            user_id=current_user.id,
            system_wide=system_wide_logins,
        )
        activity_trend_coro = self.audit_service.get_activity_trend(
            days=7,
            user_id=activity_user_id,
        )

        inventory_metrics_coro = None
        if self.inventory_service and user_has_permission(
            current_user, "inventory.view"
        ):
            inventory_metrics_coro = self.inventory_service.get_metrics(
                low_stock_limit=5
            )

        transaction_metrics_coro = None
        if self.transaction_service and user_has_permission(
            current_user, "transaction.view"
        ):
            transaction_metrics_coro = self.transaction_service.get_metrics()

        coroutines = [
            recent_activity_coro,
            security_alerts_coro,
            unread_coro,
            notifications_coro,
            login_stats_coro,
            activity_trend_coro,
        ]
        if inventory_metrics_coro is not None:
            coroutines.append(inventory_metrics_coro)
        if transaction_metrics_coro is not None:
            coroutines.append(transaction_metrics_coro)

        results = await asyncio.gather(*coroutines)

        recent_activity_result = results[0]
        security_alerts_result = results[1]
        unread = results[2]
        notifications_result = results[3]
        login_stats = results[4]
        activity_trend = results[5]
        next_idx = 6
        inventory_metrics = None
        transaction_metrics = None
        if inventory_metrics_coro is not None:
            inventory_metrics = results[next_idx]
            next_idx += 1
        if transaction_metrics_coro is not None:
            transaction_metrics = results[next_idx]

        recent_activity, _ = recent_activity_result
        security_alerts, _ = security_alerts_result
        notifications, _, _ = notifications_result

        stats = {
            "recent_activity": recent_activity,
            "unread_notifications": unread,
            "security_alerts": security_alerts,
            "recent_notifications": notifications,
            "login_statistics": login_stats,
            "activity_trend": activity_trend,
        }
        if inventory_metrics is not None:
            stats["inventory_metrics"] = InventoryDashboardMetrics.model_validate(
                inventory_metrics.model_dump()
            )
        if transaction_metrics is not None:
            stats["transaction_metrics"] = TransactionDashboardMetrics.model_validate(
                transaction_metrics.model_dump()
            )
        _cache[cache_key] = (now, stats)
        return stats
