import uuid
from datetime import datetime, timezone
import pytest
from httpx import AsyncClient

from app.core.security import create_access_token
from app.models.permission import Permission
from app.models.role import Role
from app.models.user import User


@pytest.fixture
def workflow_permissions():
    now = datetime.now(timezone.utc)
    return {
        "view": Permission(
            id=uuid.uuid4(), name="workflow.view", created_at=now, updated_at=now
        ),
        "create": Permission(
            id=uuid.uuid4(), name="workflow.create", created_at=now, updated_at=now
        ),
        "approve": Permission(
            id=uuid.uuid4(), name="workflow.approve", created_at=now, updated_at=now
        ),
    }


@pytest.fixture
def workflow_user(workflow_permissions):
    now = datetime.now(timezone.utc)
    role = Role(
        id=uuid.uuid4(),
        name="WorkflowUser",
        permissions=list(workflow_permissions.values()),
        created_at=now,
        updated_at=now,
    )
    return User(
        id=uuid.uuid4(),
        email="workflow@example.com",
        first_name="Flow",
        last_name="User",
        is_active=True,
        is_deleted=False,
        is_superuser=False,
        roles=[role],
        created_at=now,
        updated_at=now,
    )


@pytest.mark.asyncio
async def test_list_workflows_requires_auth(client: AsyncClient):
    response = await client.get("/api/v1/workflows/")
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_list_workflows_forbidden_without_permission(client: AsyncClient):
    now = datetime.now(timezone.utc)
    role = Role(
        id=uuid.uuid4(),
        name="NoWorkflow",
        permissions=[],
        created_at=now,
        updated_at=now,
    )
    user_id = uuid.uuid4()
    user = User(
        id=user_id,
        email="nowf@example.com",
        is_active=True,
        is_deleted=False,
        is_superuser=False,
        roles=[role],
        created_at=now,
        updated_at=now,
    )
    token = create_access_token({"sub": str(user_id), "type": "access", "tv": 0})

    from app.api.dependencies import get_current_user

    async def override_user():
        return user

    from app.main import app

    app.dependency_overrides[get_current_user] = override_user
    try:
        response = await client.get(
            "/api/v1/workflows/",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert response.status_code == 403
    finally:
        app.dependency_overrides.pop(get_current_user, None)
