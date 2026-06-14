import uuid
from datetime import datetime, timezone
from decimal import Decimal
from unittest.mock import AsyncMock

import pytest
from httpx import AsyncClient

from app.core.security import create_access_token
from app.models.permission import Permission
from app.models.role import Role
from app.models.user import User
from app.schemas.transaction import (
    TransactionDetailResponse,
    TransactionMetricsResponse,
)


def make_mock_result(val, is_list=False):
    class MockScalars:
        def first(self):
            return None if is_list else val

        def all(self):
            return val if is_list else [val]

        def unique(self):
            return self

    class MockResult:
        def scalars(self):
            return MockScalars()

        def all(self):
            return val if is_list else [val]

    return MockResult()


@pytest.fixture
def transaction_permissions():
    now = datetime.now(timezone.utc)
    return {
        "view": Permission(
            id=uuid.uuid4(), name="transaction.view", created_at=now, updated_at=now
        ),
        "create": Permission(
            id=uuid.uuid4(), name="transaction.create", created_at=now, updated_at=now
        ),
        "update": Permission(
            id=uuid.uuid4(), name="transaction.update", created_at=now, updated_at=now
        ),
    }


@pytest.fixture
def authorized_user(transaction_permissions):
    now = datetime.now(timezone.utc)
    role = Role(
        id=uuid.uuid4(),
        name="TransactionAdmin",
        permissions=list(transaction_permissions.values()),
        created_at=now,
        updated_at=now,
    )
    return User(
        id=uuid.uuid4(),
        email="txnadmin@example.com",
        first_name="Txn",
        last_name="Admin",
        is_active=True,
        is_deleted=False,
        is_superuser=False,
        roles=[role],
        created_at=now,
        updated_at=now,
    )


@pytest.mark.asyncio
async def test_list_transactions_requires_auth(client: AsyncClient):
    response = await client.get("/api/v1/transactions/")
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_list_transactions_success(
    client: AsyncClient, db_session, authorized_user
):
    access_token = create_access_token(subject=str(authorized_user.id))

    async def mock_execute(*args, **kwargs):
        return make_mock_result(authorized_user)

    db_session.execute = mock_execute

    mock_service = AsyncMock()
    mock_service.list_transactions = AsyncMock(return_value=([], 0))

    from app.api import dependencies
    from app.main import app

    app.dependency_overrides[dependencies.get_transaction_service] = lambda: (
        mock_service
    )

    try:
        response = await client.get(
            "/api/v1/transactions/",
            headers={"Authorization": f"Bearer {access_token}"},
        )
        assert response.status_code == 200
        assert response.json()["total"] == 0
    finally:
        app.dependency_overrides.pop(dependencies.get_transaction_service, None)


@pytest.mark.asyncio
async def test_get_metrics_response_model():
    metrics = TransactionMetricsResponse(
        daily_revenue=Decimal("1000.00"),
        monthly_revenue=Decimal("5000.00"),
        top_customers=[],
    )
    assert metrics.daily_revenue == Decimal("1000.00")


@pytest.mark.asyncio
async def test_transaction_detail_response_from_attributes():
    now = datetime.now(timezone.utc)
    txn = TransactionDetailResponse(
        id=uuid.uuid4(),
        transaction_number="TXN-20260608-0001",
        transaction_type="sale",
        customer_id=uuid.uuid4(),
        status="active",
        payment_status="paid",
        subtotal=Decimal("100.00"),
        tax_amount=Decimal("0"),
        total_amount=Decimal("100.00"),
        stock_applied=True,
        created_at=now,
        updated_at=now,
    )
    assert txn.transaction_type == "sale"
