import uuid
from datetime import datetime, timezone
from decimal import Decimal
from unittest.mock import AsyncMock, MagicMock

import pytest

import app.services.report as report_module
from app.core.exceptions import ForbiddenException, ValidationException
from app.models.audit_log import AuditLog
from app.models.permission import Permission
from app.models.role import Role
from app.models.transaction import Transaction
from app.models.user import User
from app.services.report import ReportService


def _now():
    return datetime.now(timezone.utc)


def _user(*permissions: str) -> User:
    now = _now()
    perms = [
        Permission(id=uuid.uuid4(), name=name, created_at=now, updated_at=now)
        for name in permissions
    ]
    role = Role(
        id=uuid.uuid4(),
        name="report_role",
        permissions=perms,
        created_at=now,
        updated_at=now,
    )
    return User(
        id=uuid.uuid4(),
        email="reports@test.com",
        is_active=True,
        is_deleted=False,
        is_superuser=False,
        roles=[role],
        created_at=now,
        updated_at=now,
    )


@pytest.fixture(autouse=True)
def clear_report_cache():
    report_module._cache.clear()
    yield
    report_module._cache.clear()


@pytest.fixture
def mock_report_repo():
    repo = MagicMock()
    repo.revenue_period_summary = AsyncMock(
        return_value={"total_revenue": Decimal("1000"), "transaction_count": 3}
    )
    repo.revenue_growth_percent = AsyncMock(return_value=Decimal("12.5"))
    repo.revenue_trend = AsyncMock(
        return_value=[
            {
                "label": "2026-06-01",
                "revenue": Decimal("500"),
                "transaction_count": 1,
            }
        ]
    )
    repo.inventory_summary = AsyncMock(
        return_value={
            "total_stock": 50,
            "inventory_value": Decimal("250000"),
            "low_stock_count": 2,
            "item_count": 10,
        }
    )
    repo.inventory_movement_trend = AsyncMock(
        return_value=[{"label": "2026-06-01", "net_change": 2, "movement_count": 3}]
    )
    repo.customer_summary = AsyncMock(
        return_value={
            "total_customers": 20,
            "active_customers": 18,
            "total_revenue": Decimal("90000"),
            "total_purchases": 40,
        }
    )
    repo.top_customers_report = AsyncMock(
        return_value=[
            {
                "customer_id": uuid.uuid4(),
                "full_name": "Acme",
                "revenue": Decimal("5000"),
                "transaction_count": 2,
            }
        ]
    )
    repo.customer_type_breakdown = AsyncMock(
        return_value=[
            {
                "customer_type": "business",
                "count": 5,
                "revenue": Decimal("10000"),
            }
        ]
    )
    repo.inventory_by_category = AsyncMock(
        return_value=[
            {
                "category": "gold_bar",
                "item_count": 4,
                "total_stock": 20,
                "category_value": Decimal("100000"),
            }
        ]
    )
    repo.transaction_breakdown = AsyncMock(
        return_value=[
            {
                "transaction_type": "sale",
                "payment_status": "paid",
                "count": 2,
                "total_amount": Decimal("5000"),
            }
        ]
    )
    repo.list_transactions_for_report = AsyncMock(
        return_value=[
            Transaction(
                transaction_number="TXN-1",
                transaction_type="sale",
                status="active",
                payment_status="paid",
                subtotal=Decimal("1000"),
                tax_amount=Decimal("0"),
                total_amount=Decimal("1000"),
                stock_applied=False,
            )
        ]
    )
    repo.audit_action_breakdown = AsyncMock(
        return_value=[{"action": "login_success", "count": 5}]
    )
    repo.count_audit_logs = AsyncMock(return_value=5)
    return repo


@pytest.fixture
def mock_audit_service():
    audit = MagicMock()
    audit.get_activity_trend = AsyncMock(return_value=[{"label": "Mon", "count": 4}])
    audit.list_audit_logs = AsyncMock(
        return_value=(
            [
                AuditLog(
                    id=uuid.uuid4(),
                    action="login_success",
                    entity_type="User",
                    entity_id="u1",
                    user_id=uuid.uuid4(),
                    ip_address="127.0.0.1",
                    timestamp=_now(),
                )
            ],
            1,
        )
    )
    audit.log_action = AsyncMock()
    return audit


@pytest.fixture
def report_service(mock_report_repo, mock_audit_service):
    return ReportService(mock_report_repo, mock_audit_service)


@pytest.mark.asyncio
async def test_get_analytics_overview(report_service):
    user = _user(
        "report.view",
        "transaction.view",
        "inventory.view",
        "customer.view",
        "audit.view",
    )

    overview = await report_service.get_analytics_overview(user)

    assert overview.kpis
    assert overview.revenue_trend
    assert overview.inventory_trend
    assert overview.activity_trend
    assert overview.revenue_growth_percent == Decimal("12.5")


@pytest.mark.asyncio
async def test_get_analytics_overview_uses_cache(report_service):
    user = _user("transaction.view")

    await report_service.get_analytics_overview(user)
    await report_service.get_analytics_overview(user)

    assert report_service.report_repo.revenue_growth_percent.await_count == 1


@pytest.mark.asyncio
async def test_get_revenue_report(report_service):
    user = _user("report.view", "transaction.view")
    report = await report_service.get_revenue_report(user)
    assert report.total_revenue == Decimal("1000")
    assert report.daily_trend


@pytest.mark.asyncio
async def test_get_inventory_report(report_service):
    user = _user("report.view", "inventory.view")
    report = await report_service.get_inventory_report(user)
    assert report.total_stock == 50
    assert report.by_category


@pytest.mark.asyncio
async def test_get_customer_report(report_service):
    user = _user("report.view", "customer.view")
    report = await report_service.get_customer_report(user)
    assert report.total_customers == 20
    assert report.by_type


@pytest.mark.asyncio
async def test_get_transaction_report(report_service):
    user = _user("report.view", "transaction.view")
    report = await report_service.get_transaction_report(user)
    assert report.total_count == 2
    assert report.breakdown


@pytest.mark.asyncio
async def test_get_audit_report(report_service):
    user = _user("report.view", "audit.view")
    report = await report_service.get_audit_report(user)
    assert report.total_events == 5
    assert report.breakdown


@pytest.mark.asyncio
async def test_export_report_csv_revenue(report_service):
    user = _user("report.export", "report.view", "transaction.view")
    (
        content,
        filename,
        media_type,
        row_count,
        truncated,
    ) = await report_service.export_report(
        "revenue", "csv", user, performing_user_id=user.id
    )
    assert isinstance(content, str)
    assert filename.endswith(".csv")
    assert media_type.startswith("text/")
    assert row_count >= 1
    assert truncated is False


@pytest.mark.asyncio
async def test_export_report_xlsx_inventory(report_service):
    user = _user("report.export", "report.view", "inventory.view")
    content, filename, _, _, _ = await report_service.export_report(
        "inventory", "xlsx", user
    )
    assert isinstance(content, bytes)
    assert filename.endswith(".xlsx")


@pytest.mark.asyncio
async def test_export_report_pdf_customer(report_service):
    user = _user("report.export", "report.view", "customer.view")
    content, filename, _, _, _ = await report_service.export_report(
        "customer", "pdf", user
    )
    assert isinstance(content, bytes)
    assert content[:4] == b"%PDF"
    assert filename.endswith(".pdf")


@pytest.mark.asyncio
async def test_export_report_transaction_and_audit(report_service):
    user = _user(
        "report.export",
        "report.view",
        "transaction.view",
        "audit.view",
    )

    txn_content, _, _, _, _ = await report_service.export_report(
        "transaction", "csv", user
    )
    assert "TXN-1" in txn_content

    audit_content, _, _, _, _ = await report_service.export_report("audit", "csv", user)
    assert "login_success" in audit_content


@pytest.mark.asyncio
async def test_export_requires_permission(report_service):
    user = _user("report.view", "transaction.view")
    with pytest.raises(ForbiddenException):
        await report_service.export_report("revenue", "csv", user)


@pytest.mark.asyncio
async def test_unknown_report_type(report_service):
    user = _user("report.export", "report.view", "transaction.view")
    with pytest.raises(ValidationException):
        await report_service._build_export_rows("unknown", user, None, None)


@pytest.mark.asyncio
async def test_audit_export_without_audit_service(mock_report_repo):
    service = ReportService(mock_report_repo, audit_service=None)
    user = _user("report.export", "report.view", "audit.view")
    content, _, _, row_count, truncated = await service.export_report(
        "audit", "csv", user
    )
    assert row_count == 0
    assert truncated is False
    assert isinstance(content, str)


@pytest.mark.asyncio
async def test_export_report_transaction_truncated(
    report_service, mock_report_repo, monkeypatch
):
    from app.core.config import settings

    monkeypatch.setattr(settings, "REPORT_EXPORT_MAX_ROWS", 2)
    user = _user("report.export", "report.view", "transaction.view")
    mock_report_repo.list_transactions_for_report = AsyncMock(
        return_value=[
            Transaction(
                transaction_number=f"TXN-{i}",
                transaction_type="sale",
                status="active",
                payment_status="paid",
                subtotal=Decimal("100"),
                tax_amount=Decimal("0"),
                total_amount=Decimal("100"),
                stock_applied=False,
            )
            for i in range(3)
        ]
    )

    _, _, _, row_count, truncated = await report_service.export_report(
        "transaction", "csv", user
    )
    assert row_count == 2
    assert truncated is True


@pytest.mark.asyncio
async def test_get_revenue_report_custom_period(report_service):
    user = _user("report.view", "transaction.view")
    start = datetime(2026, 1, 1, tzinfo=timezone.utc)
    end = datetime(2026, 1, 31, tzinfo=timezone.utc)
    report = await report_service.get_revenue_report(user, start=start, end=end)
    assert report.period_start == start
    assert report.period_end == end


@pytest.mark.asyncio
async def test_get_analytics_overview_inventory_only(report_service):
    user = _user("inventory.view")
    overview = await report_service.get_analytics_overview(user)
    assert overview.revenue_trend == []
    assert overview.inventory_trend


@pytest.mark.asyncio
async def test_revenue_report_requires_transaction_view(report_service):
    user = _user("report.view")
    with pytest.raises(ForbiddenException):
        await report_service.get_revenue_report(user)


@pytest.mark.asyncio
async def test_unsupported_export_format(report_service):
    user = _user("report.export", "report.view", "transaction.view")
    with pytest.raises(ValidationException):
        await report_service.export_report("revenue", "docx", user)  # type: ignore[arg-type]
