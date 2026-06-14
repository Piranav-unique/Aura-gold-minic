import uuid
from datetime import datetime, timezone
from decimal import Decimal
from unittest.mock import AsyncMock, MagicMock

import pytest

import app.services.executive_dashboard as executive_module
from app.models.audit_log import AuditLog
from app.models.permission import Permission
from app.models.role import Role
from app.models.user import User
from app.schemas.inventory import InventoryMetricsResponse
from app.schemas.transaction import TopCustomerMetric, TransactionMetricsResponse
from app.services.executive_dashboard import (
    ExecutiveDashboardService,
    resolve_executive_role,
)


def _now():
    return datetime.now(timezone.utc)


def _user(
    *,
    role_names: list[str] | None = None,
    permissions: list[str] | None = None,
    superuser: bool = False,
    user_id: uuid.UUID | None = None,
) -> User:
    now = _now()
    perms = [
        Permission(id=uuid.uuid4(), name=name, created_at=now, updated_at=now)
        for name in (permissions or [])
    ]
    roles = []
    if role_names:
        for name in role_names:
            roles.append(
                Role(
                    id=uuid.uuid4(),
                    name=name,
                    permissions=[],
                    created_at=now,
                    updated_at=now,
                )
            )
    elif permissions:
        roles.append(
            Role(
                id=uuid.uuid4(),
                name="custom",
                permissions=perms,
                created_at=now,
                updated_at=now,
            )
        )
    return User(
        id=user_id or uuid.uuid4(),
        email="exec@test.com",
        first_name="Exec",
        last_name="User",
        is_active=True,
        is_deleted=False,
        is_superuser=superuser,
        roles=roles,
        created_at=now,
        updated_at=now,
    )


@pytest.fixture(autouse=True)
def clear_executive_cache():
    executive_module._executive_cache.clear()
    yield
    executive_module._executive_cache.clear()


@pytest.fixture
def executive_service():
    audit_service = MagicMock()
    audit_service.get_activity_trend = AsyncMock(return_value=[{"label": "Mon", "count": 2}])
    audit_service.get_login_statistics = AsyncMock(
        return_value={"today": 3, "week": 10, "month": 30}
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
    notification_service.get_unread_count = AsyncMock(return_value=4)

    customer_repo = MagicMock()
    customer_repo.dashboard_metrics = AsyncMock(
        return_value={
            "total_customers": 10,
            "active_customers": 8,
            "new_this_month": 2,
        }
    )

    user_repo = MagicMock()
    user_repo.count_active_users = AsyncMock(return_value=12)

    workflow_repo = MagicMock()
    pending_item = MagicMock()
    pending_item.id = uuid.uuid4()
    pending_item.request_number = "WR-001"
    pending_item.title = "Approve discount"
    pending_item.state = "pending"
    pending_item.requester = _user(role_names=["employee"])
    pending_item.assignee = _user(role_names=["manager"])
    pending_item.pending_since = _now()
    pending_item.escalation_level = 1
    workflow_repo.count_pending = AsyncMock(return_value=1)
    workflow_repo.list_filtered = AsyncMock(return_value=[pending_item])

    report_repo = MagicMock()
    report_repo.revenue_trend = AsyncMock(
        return_value=[
            {
                "label": "2026-06-01",
                "revenue": Decimal("1000"),
                "transaction_count": 2,
            }
        ]
    )
    report_repo.revenue_growth_percent = AsyncMock(return_value=Decimal("5.5"))

    inventory_service = MagicMock()
    inventory_service.get_metrics = AsyncMock(
        return_value=InventoryMetricsResponse(
            total_stock=100,
            inventory_value=Decimal("500000"),
            low_stock_count=1,
            low_stock_items=[],
        )
    )

    transaction_service = MagicMock()
    transaction_service.get_metrics = AsyncMock(
        return_value=TransactionMetricsResponse(
            daily_revenue=Decimal("1000"),
            monthly_revenue=Decimal("10000"),
            top_customers=[
                TopCustomerMetric(
                    customer_id=uuid.uuid4(),
                    full_name="Jane",
                    revenue=Decimal("5000"),
                    transaction_count=2,
                )
            ],
        )
    )

    return ExecutiveDashboardService(
        audit_service=audit_service,
        notification_service=notification_service,
        customer_repo=customer_repo,
        user_repo=user_repo,
        workflow_repo=workflow_repo,
        report_repo=report_repo,
        inventory_service=inventory_service,
        transaction_service=transaction_service,
    )


def test_resolve_executive_role_permission_heuristics():
    admin_user = _user(permissions=["audit.view", "transaction.view"])
    manager_user = _user(permissions=["workflow.approve"])
    employee_user = _user(permissions=["user.view"])

    assert resolve_executive_role(admin_user) == "admin"
    assert resolve_executive_role(manager_user) == "manager"
    assert resolve_executive_role(employee_user) == "employee"


@pytest.mark.asyncio
async def test_get_dashboard_admin(executive_service):
    user = _user(
        role_names=["admin"],
        permissions=[
            "audit.view",
            "transaction.view",
            "customer.view",
            "inventory.view",
        ],
    )
    for role in user.roles:
        role.permissions = [
            Permission(id=uuid.uuid4(), name=p, created_at=_now(), updated_at=_now())
            for p in [
                "audit.view",
                "transaction.view",
                "customer.view",
                "inventory.view",
            ]
        ]

    dashboard = await executive_service.get_dashboard(user)

    assert dashboard.role == "admin"
    assert dashboard.display_name == "Exec User"
    assert dashboard.unread_notifications == 4
    assert dashboard.revenue_trend
    assert dashboard.customer_metrics is not None
    assert dashboard.inventory_metrics is not None
    assert dashboard.transaction_metrics is not None


@pytest.mark.asyncio
async def test_get_dashboard_manager(executive_service):
    user = _user(
        role_names=["manager"],
        permissions=["audit.view", "user.view", "workflow.approve", "inventory.view"],
    )
    for role in user.roles:
        role.permissions = [
            Permission(id=uuid.uuid4(), name=p, created_at=_now(), updated_at=_now())
            for p in [
                "audit.view",
                "user.view",
                "workflow.approve",
                "inventory.view",
            ]
        ]

    dashboard = await executive_service.get_dashboard(user)

    assert dashboard.role == "manager"
    assert dashboard.team_metrics is not None
    assert dashboard.team_metrics.active_users == 12
    assert dashboard.pending_approvals
    assert dashboard.inventory_alerts == []


@pytest.mark.asyncio
async def test_get_dashboard_employee(executive_service):
    user_id = uuid.uuid4()
    user = _user(role_names=["employee"], user_id=user_id)

    draft_item = MagicMock()
    draft_item.id = uuid.uuid4()
    draft_item.request_number = "WR-DRAFT"
    draft_item.title = "Draft request"
    draft_item.state = "draft"
    draft_item.request_type = "general"
    draft_item.submitted_at = None

    executive_service.workflow_repo.list_filtered = AsyncMock(
        side_effect=[
            [],
            [draft_item],
        ]
    )

    dashboard = await executive_service.get_dashboard(user)

    assert dashboard.role == "employee"
    assert dashboard.assigned_tasks
    assert dashboard.daily_activities
    assert dashboard.activity_trend


@pytest.mark.asyncio
async def test_get_dashboard_uses_cache(executive_service):
    user = _user(role_names=["employee"])
    executive_service.workflow_repo.list_filtered = AsyncMock(return_value=[])

    await executive_service.get_dashboard(user)
    await executive_service.get_dashboard(user)

    assert executive_service.notification_service.get_unread_count.await_count == 1


def test_activity_description_without_entity():
    assert ExecutiveDashboardService._activity_description("login_success", None) == (
        "Login Success"
    )


@pytest.mark.asyncio
async def test_get_dashboard_admin_without_transaction_service():
    user = _user(role_names=["admin"])
    for role in user.roles:
        role.permissions = [
            Permission(
                id=uuid.uuid4(),
                name="transaction.view",
                created_at=_now(),
                updated_at=_now(),
            )
        ]

    service = ExecutiveDashboardService(
        audit_service=MagicMock(),
        notification_service=MagicMock(),
        customer_repo=MagicMock(),
        user_repo=MagicMock(),
        workflow_repo=MagicMock(),
        report_repo=MagicMock(),
        inventory_service=None,
        transaction_service=None,
    )
    service.notification_service.get_unread_count = AsyncMock(return_value=0)
    service.report_repo.revenue_trend = AsyncMock(return_value=[])
    service.report_repo.revenue_growth_percent = AsyncMock(return_value=None)

    dashboard = await service.get_dashboard(user)

    assert dashboard.role == "admin"
    assert dashboard.transaction_metrics is None
    assert dashboard.revenue_trend == []
