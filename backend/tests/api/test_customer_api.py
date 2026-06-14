import uuid
from datetime import datetime, timezone
from decimal import Decimal
from unittest.mock import AsyncMock

import pytest
from httpx import AsyncClient

from app.core.security import create_access_token
from app.models.customer import Customer
from app.models.permission import Permission
from app.models.role import Role
from app.models.user import User


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
def customer_permissions():
    now = datetime.now(timezone.utc)
    return {
        "view": Permission(
            id=uuid.uuid4(), name="customer.view", created_at=now, updated_at=now
        ),
        "create": Permission(
            id=uuid.uuid4(), name="customer.create", created_at=now, updated_at=now
        ),
        "update": Permission(
            id=uuid.uuid4(), name="customer.update", created_at=now, updated_at=now
        ),
        "delete": Permission(
            id=uuid.uuid4(), name="customer.delete", created_at=now, updated_at=now
        ),
    }


@pytest.fixture
def authorized_user(customer_permissions):
    now = datetime.now(timezone.utc)
    role = Role(
        id=uuid.uuid4(),
        name="CustomerAdmin",
        permissions=list(customer_permissions.values()),
        created_at=now,
        updated_at=now,
    )
    return User(
        id=uuid.uuid4(),
        email="admin@example.com",
        first_name="Admin",
        last_name="User",
        is_active=True,
        is_deleted=False,
        is_superuser=False,
        roles=[role],
        created_at=now,
        updated_at=now,
    )


@pytest.fixture
def unauthorized_user():
    now = datetime.now(timezone.utc)
    return User(
        id=uuid.uuid4(),
        email="guest@example.com",
        first_name="Guest",
        last_name="User",
        is_active=True,
        is_deleted=False,
        is_superuser=False,
        roles=[],
        created_at=now,
        updated_at=now,
    )


def _sample_customer(**overrides) -> Customer:
    now = datetime.now(timezone.utc)
    data = {
        "id": uuid.uuid4(),
        "customer_type": "individual",
        "full_name": "John Doe",
        "mobile_number": "+919876543210",
        "email": "john@example.com",
        "address": "123 Main Street",
        "gst_number": None,
        "status": "active",
        "total_purchases": 0,
        "total_revenue": Decimal("0"),
        "last_transaction_date": None,
        "is_deleted": False,
        "created_at": now,
        "updated_at": now,
    }
    data.update(overrides)
    return Customer(**data)


@pytest.mark.asyncio
async def test_create_customer_api_success(
    client: AsyncClient, db_session, authorized_user
):
    access_token = create_access_token(subject=authorized_user.id)
    created = _sample_customer()

    call_count = 0

    async def mock_execute(*args, **kwargs):
        nonlocal call_count
        call_count += 1
        if call_count == 1:
            return make_mock_result(authorized_user)
        if call_count in (2, 3):
            return make_mock_result(None)
        return make_mock_result(created)

    db_session.execute = mock_execute

    async def mock_refresh(obj, *args, **kwargs):
        if hasattr(obj, "id") and obj.id is None:
            obj.id = uuid.uuid4()
        if hasattr(obj, "created_at") and obj.created_at is None:
            obj.created_at = datetime.now(timezone.utc)
        if hasattr(obj, "updated_at") and obj.updated_at is None:
            obj.updated_at = datetime.now(timezone.utc)
        if hasattr(obj, "total_purchases") and obj.total_purchases is None:
            obj.total_purchases = 0
        if hasattr(obj, "total_revenue") and obj.total_revenue is None:
            obj.total_revenue = Decimal("0")

    db_session.refresh = mock_refresh

    response = await client.post(
        "/api/v1/customers/",
        json={
            "customer_type": "individual",
            "full_name": "John Doe",
            "mobile_number": "+919876543210",
            "email": "john@example.com",
            "address": "123 Main Street",
        },
        headers={"Authorization": f"Bearer {access_token}"},
    )

    assert response.status_code == 201
    data = response.json()
    assert data["full_name"] == "John Doe"
    assert data["email"] == "john@example.com"


@pytest.mark.asyncio
async def test_create_customer_api_forbidden(
    client: AsyncClient, db_session, unauthorized_user
):
    access_token = create_access_token(subject=unauthorized_user.id)

    async def mock_execute(*args, **kwargs):
        return make_mock_result(unauthorized_user)

    db_session.execute = mock_execute

    response = await client.post(
        "/api/v1/customers/",
        json={
            "customer_type": "individual",
            "full_name": "John Doe",
            "mobile_number": "+919876543210",
            "email": "john@example.com",
            "address": "123 Main Street",
        },
        headers={"Authorization": f"Bearer {access_token}"},
    )

    assert response.status_code == 403
    assert "customer.create" in response.json()["error"]["message"].lower()


@pytest.mark.asyncio
async def test_list_customers_api_paginated(
    client: AsyncClient, db_session, authorized_user
):
    access_token = create_access_token(subject=authorized_user.id)
    customers = [
        _sample_customer(),
        _sample_customer(email="jane@example.com", mobile_number="+919876543211"),
    ]

    call_count = 0

    async def mock_execute(*args, **kwargs):
        nonlocal call_count
        call_count += 1
        if call_count == 1:
            return make_mock_result(authorized_user)
        if call_count == 2:
            return make_mock_result(customers, is_list=True)
        if call_count == 3:

            class CountResult:
                def scalar(self):
                    return 2

            return CountResult()
        return make_mock_result(None)

    db_session.execute = mock_execute

    response = await client.get(
        "/api/v1/customers/?skip=0&limit=10&search=john",
        headers={"Authorization": f"Bearer {access_token}"},
    )

    assert response.status_code == 200
    data = response.json()
    assert data["total"] == 2
    assert len(data["items"]) == 2


@pytest.mark.asyncio
async def test_get_customer_api_details(
    client: AsyncClient, db_session, authorized_user
):
    access_token = create_access_token(subject=authorized_user.id)
    target = _sample_customer()

    call_count = 0

    async def mock_execute(*args, **kwargs):
        nonlocal call_count
        call_count += 1
        if call_count == 1:
            return make_mock_result(authorized_user)
        return make_mock_result(target)

    db_session.execute = mock_execute

    response = await client.get(
        f"/api/v1/customers/{target.id}",
        headers={"Authorization": f"Bearer {access_token}"},
    )

    assert response.status_code == 200
    assert response.json()["id"] == str(target.id)


@pytest.mark.asyncio
async def test_update_customer_api(client: AsyncClient, db_session, authorized_user):
    access_token = create_access_token(subject=authorized_user.id)
    target = _sample_customer()

    call_count = 0

    async def mock_execute(*args, **kwargs):
        nonlocal call_count
        call_count += 1
        if call_count == 1:
            return make_mock_result(authorized_user)
        return make_mock_result(target)

    db_session.execute = mock_execute
    db_session.commit = AsyncMock()
    db_session.refresh = AsyncMock()

    response = await client.put(
        f"/api/v1/customers/{target.id}",
        json={"full_name": "Updated Name"},
        headers={"Authorization": f"Bearer {access_token}"},
    )

    assert response.status_code == 200
    assert response.json()["full_name"] == "Updated Name"


@pytest.mark.asyncio
async def test_delete_customer_api(client: AsyncClient, db_session, authorized_user):
    access_token = create_access_token(subject=authorized_user.id)
    target = _sample_customer()

    call_count = 0

    async def mock_execute(*args, **kwargs):
        nonlocal call_count
        call_count += 1
        if call_count == 1:
            return make_mock_result(authorized_user)
        return make_mock_result(target)

    db_session.execute = mock_execute
    db_session.commit = AsyncMock()

    response = await client.delete(
        f"/api/v1/customers/{target.id}",
        headers={"Authorization": f"Bearer {access_token}"},
    )

    assert response.status_code == 200
    assert response.json()["message"] == "Customer deleted successfully"
