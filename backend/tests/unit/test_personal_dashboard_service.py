import uuid
from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock

import pytest

import app.services.dashboard_cache as dashboard_cache_module
from app.models.audit_log import AuditLog
from app.models.role import Role
from app.models.user import User
from app.services.personal_dashboard import PersonalDashboardService


def _now():
    return datetime.now(timezone.utc)


def _user() -> User:
    now = _now()
    role = Role(
        id=uuid.uuid4(),
        name="employee",
        permissions=[],
        created_at=now,
        updated_at=now,
    )
    return User(
        id=uuid.uuid4(),
        email="user@agsgold.com",
        mobile_number="9876543210",
        first_name="Gold",
        last_name="User",
        is_active=True,
        is_deleted=False,
        is_superuser=False,
        roles=[role],
        created_at=now,
        updated_at=now,
    )


@pytest.fixture(autouse=True)
def clear_personal_cache():
    dashboard_cache_module.get_personal_dashboard_cache().clear()
    yield
    dashboard_cache_module.get_personal_dashboard_cache().clear()


@pytest.fixture
def personal_service():
    audit_service = MagicMock()
    audit_service.get_activity_trend = AsyncMock(
        return_value=[{"label": "Mon", "count": 3}]
    )
    audit_service.get_login_statistics = AsyncMock(
        return_value={"today": 1, "week": 5, "month": 15}
    )
    audit_service.list_audit_logs = AsyncMock(
        return_value=(
            [
                AuditLog(
                    id=uuid.uuid4(),
                    action="login_success",
                    entity_type="User",
                    entity_id="u1",
                    timestamp=_now(),
                )
            ],
            1,
        )
    )

    notification_service = MagicMock()
    notification_service.get_unread_count = AsyncMock(return_value=2)
    notification = MagicMock()
    notification.id = uuid.uuid4()
    notification.user_id = uuid.uuid4()
    notification.title = "Task assigned"
    notification.message = "You have a new workflow"
    notification.category = "workflow"
    notification.is_read = False
    notification.created_at = _now()
    notification.metadata = None
    notification_service.list_notifications = AsyncMock(
        return_value=([notification], 1, 2)
    )

    workflow_repo = MagicMock()
    pending_item = MagicMock()
    pending_item.id = uuid.uuid4()
    pending_item.request_number = "WF-001"
    pending_item.title = "Approve purchase"
    pending_item.state = "pending"
    pending_item.request_type = "purchase"
    pending_item.submitted_at = _now()

    draft_item = MagicMock()
    draft_item.id = uuid.uuid4()
    draft_item.request_number = "WF-002"
    draft_item.title = "Draft request"
    draft_item.state = "draft"
    draft_item.request_type = "general"
    draft_item.submitted_at = None

    workflow_repo.list_filtered = AsyncMock(
        side_effect=[[pending_item], [draft_item]]
    )

    return PersonalDashboardService(
        audit_service,
        notification_service,
        workflow_repo,
    )


@pytest.mark.asyncio
async def test_personal_dashboard_aggregates_user_data(personal_service):
    user = _user()
    result = await personal_service.get_dashboard(user)

    assert result.display_name == "Gold User"
    assert result.mobile_number == "9876543210"
    assert result.roles == ["employee"]
    assert result.unread_notifications == 2
    assert result.login_statistics.week == 5
    assert result.pending_task_count == 1
    assert result.draft_task_count == 1
    assert len(result.assigned_tasks) == 2
    assert len(result.recent_notifications) == 1
    assert len(result.daily_activities) == 1
    assert result.activity_trend[0].count == 3


@pytest.mark.asyncio
async def test_personal_dashboard_uses_cache(personal_service):
    user = _user()
    await personal_service.get_dashboard(user)
    await personal_service.get_dashboard(user)

    personal_service.workflow_repo.list_filtered.assert_called_once()
