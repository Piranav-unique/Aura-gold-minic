import pytest
import uuid
from datetime import datetime, timezone
from fastapi import APIRouter, Depends
from httpx import AsyncClient

from app.main import app
from app.api.dependencies import get_current_user
from app.core.authorization import require_permission, PermissionChecker
from app.core.security import create_access_token
from app.models.user import User
from app.models.role import Role
from app.models.permission import Permission


# Setup dynamic test routes to test decorators and dependencies
rbac_test_router = APIRouter(prefix="/api/v1/test-auth")


@rbac_test_router.get("/decorator")
@require_permission("user:view")
async def decorator_route(current_user: User = Depends(get_current_user)):
    return {"message": "success"}


@rbac_test_router.get("/dependency")
async def dependency_route(
    current_user: User = Depends(PermissionChecker("user:create")),
):
    return {"message": "success"}


# Register test router on FastAPI app
app.include_router(rbac_test_router)


@pytest.mark.asyncio
async def test_require_permission_decorator_allowed(client: AsyncClient, db_session):
    """Verify decorator grants access if user has the required permission."""
    user_id = uuid.uuid4()
    access_token = create_access_token(subject=user_id)

    # User has a role which has 'user:view' permission
    perm = Permission(name="user:view")
    role = Role(name="viewer", permissions=[perm])
    mock_user = User(
        id=user_id,
        email="viewer@example.com",
        is_active=True,
        is_deleted=False,
        is_superuser=False,
        roles=[role],
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc),
    )

    async def mock_get(model, id):
        if model == User:
            return mock_user
        return None

    db_session.get = mock_get

    # Also mock query for get_with_roles_and_permissions in UserRepository
    async def mock_execute(*args, **kwargs):
        class MockResult:
            def scalars(self):
                class MockScalars:
                    def first(self):
                        return mock_user

                return MockScalars()

        return MockResult()

    db_session.execute = mock_execute

    response = await client.get(
        "/api/v1/test-auth/decorator",
        headers={"Authorization": f"Bearer {access_token}"},
    )

    assert response.status_code == 200
    assert response.json() == {"message": "success"}


@pytest.mark.asyncio
async def test_require_permission_decorator_forbidden(client: AsyncClient, db_session):
    """Verify decorator raises 403 Forbidden if user lacks required permission."""
    user_id = uuid.uuid4()
    access_token = create_access_token(subject=user_id)

    # User has no roles / permissions
    mock_user = User(
        id=user_id,
        email="poor@example.com",
        is_active=True,
        is_deleted=False,
        is_superuser=False,
        roles=[],
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc),
    )

    async def mock_get(model, id):
        if model == User:
            return mock_user
        return None

    db_session.get = mock_get

    async def mock_execute(*args, **kwargs):
        class MockResult:
            def scalars(self):
                class MockScalars:
                    def first(self):
                        return mock_user

                return MockScalars()

        return MockResult()

    db_session.execute = mock_execute

    response = await client.get(
        "/api/v1/test-auth/decorator",
        headers={"Authorization": f"Bearer {access_token}"},
    )

    assert response.status_code == 403
    data = response.json()
    assert "error" in data
    assert "permission 'user:view' is required" in data["error"]["message"].lower()


@pytest.mark.asyncio
async def test_permission_checker_dependency_allowed(client: AsyncClient, db_session):
    """Verify PermissionChecker dependency allows access for authorized user."""
    user_id = uuid.uuid4()
    access_token = create_access_token(subject=user_id)

    # User has 'user:create' permission
    perm = Permission(name="user:create")
    role = Role(name="admin", permissions=[perm])
    mock_user = User(
        id=user_id,
        email="admin@example.com",
        is_active=True,
        is_deleted=False,
        is_superuser=False,
        roles=[role],
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc),
    )

    async def mock_get(model, id):
        if model == User:
            return mock_user
        return None

    db_session.get = mock_get

    async def mock_execute(*args, **kwargs):
        class MockResult:
            def scalars(self):
                class MockScalars:
                    def first(self):
                        return mock_user

                return MockScalars()

        return MockResult()

    db_session.execute = mock_execute

    response = await client.get(
        "/api/v1/test-auth/dependency",
        headers={"Authorization": f"Bearer {access_token}"},
    )

    assert response.status_code == 200
    assert response.json() == {"message": "success"}


@pytest.mark.asyncio
async def test_superuser_bypass(client: AsyncClient, db_session):
    """Verify superuser is bypassed from authorization checks."""
    user_id = uuid.uuid4()
    access_token = create_access_token(subject=user_id)

    mock_user = User(
        id=user_id,
        email="super@example.com",
        is_active=True,
        is_deleted=False,
        is_superuser=True,
        roles=[],
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc),
    )

    async def mock_get(model, id):
        if model == User:
            return mock_user
        return None

    db_session.get = mock_get

    async def mock_execute(*args, **kwargs):
        class MockResult:
            def scalars(self):
                class MockScalars:
                    def first(self):
                        return mock_user

                return MockScalars()

        return MockResult()

    db_session.execute = mock_execute

    # Superuser has access to decorator route without matching permission
    response1 = await client.get(
        "/api/v1/test-auth/decorator",
        headers={"Authorization": f"Bearer {access_token}"},
    )
    assert response1.status_code == 200

    # Superuser has access to dependency route without matching permission
    response2 = await client.get(
        "/api/v1/test-auth/dependency",
        headers={"Authorization": f"Bearer {access_token}"},
    )
    assert response2.status_code == 200


@pytest.mark.asyncio
async def test_list_roles_api_allowed(client: AsyncClient, db_session):
    """Verify listing roles endpoint is accessible to user with role:read."""
    user_id = uuid.uuid4()
    access_token = create_access_token(subject=user_id)

    perm = Permission(name="role:read")
    role = Role(name="manager", permissions=[perm])
    mock_user = User(
        id=user_id,
        email="manager@example.com",
        is_active=True,
        is_deleted=False,
        is_superuser=False,
        roles=[role],
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc),
    )

    # Eager mock return for rbac get_list
    mock_roles_list = [
        Role(
            id=uuid.uuid4(),
            name="user",
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc),
        )
    ]

    call_count = 0

    async def mock_execute(*args, **kwargs):
        nonlocal call_count
        call_count += 1

        class MockResult:
            def scalars(self):
                class MockScalars:
                    def first(self):
                        return mock_user

                    def all(self):
                        return mock_roles_list

                return MockScalars()

        return MockResult()

    db_session.execute = mock_execute

    response = await client.get(
        "/api/v1/rbac/roles",
        headers={"Authorization": f"Bearer {access_token}"},
    )

    assert response.status_code == 200
    data = response.json()
    assert len(data) == 1
    assert data[0]["name"] == "user"


@pytest.mark.asyncio
async def test_wildcard_permission_allowed(client: AsyncClient, db_session):
    """Verify that wildcard permission (e.g. 'user:*') grants access to 'user:view'."""
    user_id = uuid.uuid4()
    access_token = create_access_token(subject=user_id)

    # User has wildcard permission 'user:*'
    perm = Permission(name="user:*")
    role = Role(name="manager", permissions=[perm])
    mock_user = User(
        id=user_id,
        email="wildcard@example.com",
        is_active=True,
        is_deleted=False,
        is_superuser=False,
        roles=[role],
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc),
    )

    async def mock_get(model, id):
        if model == User:
            return mock_user
        return None

    db_session.get = mock_get

    async def mock_execute(*args, **kwargs):
        class MockResult:
            def scalars(self):
                class MockScalars:
                    def first(self):
                        return mock_user

                return MockScalars()

        return MockResult()

    db_session.execute = mock_execute

    # Request decorator route (requires 'user:view')
    response1 = await client.get(
        "/api/v1/test-auth/decorator",
        headers={"Authorization": f"Bearer {access_token}"},
    )
    assert response1.status_code == 200

    # Request dependency route (requires 'user:create')
    response2 = await client.get(
        "/api/v1/test-auth/dependency",
        headers={"Authorization": f"Bearer {access_token}"},
    )
    assert response2.status_code == 200


def test_decorator_mismatch_raises_runtime_error():
    """Verify that using @require_permission on a function without current_user raises RuntimeError."""

    # Decorating a function that doesn't accept current_user should raise RuntimeError when called
    @require_permission("user:view")
    async def bad_route():
        return {"message": "failure"}

    import pytest

    with pytest.raises(RuntimeError) as exc_info:
        import asyncio

        asyncio.run(bad_route())

    assert "must declare a 'current_user: User' parameter" in str(exc_info.value)
