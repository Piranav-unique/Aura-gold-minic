import uuid
from datetime import datetime, timezone
from unittest.mock import AsyncMock

import pytest
from httpx import AsyncClient

from app.core.security import create_access_token
from app.models.permission import Permission
from app.models.role import Role
from app.models.user import User
from app.schemas.report import AnalyticsOverviewResponse, KpiCard


@pytest.fixture
def report_user():
    now = datetime.now(timezone.utc)
    perms = [
        Permission(id=uuid.uuid4(), name=p, created_at=now, updated_at=now)
        for p in [
            "report.view",
            "report.export",
            "transaction.view",
            "inventory.view",
            "customer.view",
            "audit.view",
        ]
    ]
    role = Role(
        id=uuid.uuid4(),
        name="ReportAdmin",
        permissions=perms,
        created_at=now,
        updated_at=now,
    )
    return User(
        id=uuid.uuid4(),
        email="reports@example.com",
        is_active=True,
        is_deleted=False,
        is_superuser=False,
        roles=[role],
        created_at=now,
        updated_at=now,
    )


@pytest.mark.asyncio
async def test_analytics_requires_auth(client: AsyncClient):
    response = await client.get("/api/v1/reports/analytics")
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_analytics_success(client: AsyncClient, db_session, report_user):
    access_token = create_access_token(subject=str(report_user.id))

    async def mock_execute(*args, **kwargs):
        class R:
            def scalars(self):
                class S:
                    def first(self):
                        return report_user

                return S()

        return R()

    db_session.execute = mock_execute

    mock_service = AsyncMock()
    mock_service.get_analytics_overview = AsyncMock(
        return_value=AnalyticsOverviewResponse(
            kpis=[
                KpiCard(
                    key="daily_revenue",
                    label="Daily Revenue",
                    value="₹1,000",
                )
            ]
        )
    )

    from app.api import dependencies
    from app.main import app

    app.dependency_overrides[dependencies.get_report_service] = lambda: mock_service
    try:
        response = await client.get(
            "/api/v1/reports/analytics",
            headers={"Authorization": f"Bearer {access_token}"},
        )
        assert response.status_code == 200
        assert response.json()["kpis"][0]["key"] == "daily_revenue"
    finally:
        app.dependency_overrides.pop(dependencies.get_report_service, None)
