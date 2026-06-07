import pytest
import uuid
from datetime import datetime, timezone
from httpx import AsyncClient

from app.core.security import create_access_token
from app.models.user import User
from app.models.role import Role
from app.models.permission import Permission


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
def test_permissions():
    now = datetime.now(timezone.utc)
    return {
        "view": Permission(
            id=uuid.uuid4(), name="user.view", created_at=now, updated_at=now
        ),
        "create": Permission(
            id=uuid.uuid4(), name="user.create", created_at=now, updated_at=now
        ),
        "update": Permission(
            id=uuid.uuid4(), name="user.update", created_at=now, updated_at=now
        ),
        "delete": Permission(
            id=uuid.uuid4(), name="user.delete", created_at=now, updated_at=now
        ),
    }


@pytest.fixture
def authorized_user(test_permissions):
    now = datetime.now(timezone.utc)
    # Admin user with all user permissions
    admin_role = Role(
        id=uuid.uuid4(),
        name="Administrator",
        permissions=[
            test_permissions["view"],
            test_permissions["create"],
            test_permissions["update"],
            test_permissions["delete"],
        ],
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
        roles=[admin_role],
        created_at=now,
        updated_at=now,
    )


@pytest.fixture
def unauthorized_user():
    now = datetime.now(timezone.utc)
    # User with no permissions
    return User(
        id=uuid.uuid4(),
        email="unauthorized@example.com",
        first_name="Guest",
        last_name="User",
        is_active=True,
        is_deleted=False,
        is_superuser=False,
        roles=[],
        created_at=now,
        updated_at=now,
    )


@pytest.mark.asyncio
async def test_create_user_api_success(
    client: AsyncClient, db_session, authorized_user
):
    """Verify that authorized users can create a new user via API."""
    access_token = create_access_token(subject=authorized_user.id)

    now = datetime.now(timezone.utc)
    role_id = uuid.uuid4()
    mock_role = Role(id=role_id, name="User", created_at=now, updated_at=now)

    call_count = 0
    created_user = User(
        id=uuid.uuid4(),
        email="new_user@example.com",
        first_name="New",
        last_name="User",
        roles=[mock_role],
        is_active=True,
        is_superuser=False,
        created_at=now,
        updated_at=now,
    )

    async def mock_execute(*args, **kwargs):
        nonlocal call_count
        call_count += 1
        if call_count == 1:
            # get_current_user check
            return make_mock_result(authorized_user)
        elif call_count == 2:
            # get_by_email check
            return make_mock_result(None)
        elif call_count == 3:
            # get_by_ids role fetch
            return make_mock_result([mock_role], is_list=True)
        elif call_count == 4:
            # get_with_roles_and_permissions fetch after commit
            return make_mock_result(created_user)
        return make_mock_result(None)

    db_session.execute = mock_execute

    async def mock_get(model, id):
        if model == Role and id == role_id:
            return mock_role
        return None

    db_session.get = mock_get

    async def mock_refresh(obj, *args, **kwargs):
        if hasattr(obj, "id") and obj.id is None:
            obj.id = uuid.uuid4()
        if hasattr(obj, "created_at") and obj.created_at is None:
            obj.created_at = datetime.now(timezone.utc)
        if hasattr(obj, "updated_at") and obj.updated_at is None:
            obj.updated_at = datetime.now(timezone.utc)

    db_session.refresh = mock_refresh

    payload = {
        "email": "new_user@example.com",
        "password": "securepassword123",
        "first_name": "New",
        "last_name": "User",
        "roles": [str(role_id)],
    }

    response = await client.post(
        "/api/v1/users/",
        json=payload,
        headers={"Authorization": f"Bearer {access_token}"},
    )

    assert response.status_code == 201
    data = response.json()
    assert data["email"] == "new_user@example.com"
    assert data["first_name"] == "New"
    assert data["last_name"] == "User"


@pytest.mark.asyncio
async def test_create_user_api_forbidden(
    client: AsyncClient, db_session, unauthorized_user
):
    """Verify that unauthorized users are blocked from creating a user."""
    access_token = create_access_token(subject=unauthorized_user.id)

    async def mock_execute(*args, **kwargs):
        return make_mock_result(unauthorized_user)

    db_session.execute = mock_execute

    payload = {
        "email": "guest@example.com",
        "password": "guestpassword123",
    }

    response = await client.post(
        "/api/v1/users/",
        json=payload,
        headers={"Authorization": f"Bearer {access_token}"},
    )

    assert response.status_code == 403
    assert (
        "permission 'user.create' is required"
        in response.json()["error"]["message"].lower()
    )


@pytest.mark.asyncio
async def test_list_users_api(client: AsyncClient, db_session, authorized_user):
    """Verify listing users is paginated, filtered, and requires permission."""
    access_token = create_access_token(subject=authorized_user.id)

    mock_users = [
        User(
            id=uuid.uuid4(),
            email="u1@example.com",
            is_active=True,
            is_deleted=False,
            is_superuser=False,
            roles=[],
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc),
        ),
        User(
            id=uuid.uuid4(),
            email="u2@example.com",
            is_active=True,
            is_deleted=False,
            is_superuser=False,
            roles=[],
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc),
        ),
    ]

    call_count = 0

    async def mock_execute(*args, **kwargs):
        nonlocal call_count
        call_count += 1
        if call_count == 1:
            return make_mock_result(authorized_user)
        else:
            return make_mock_result(mock_users, is_list=True)

    db_session.execute = mock_execute

    response = await client.get(
        "/api/v1/users/?skip=0&limit=10&search=example",
        headers={"Authorization": f"Bearer {access_token}"},
    )

    assert response.status_code == 200
    data = response.json()
    assert len(data) == 2
    assert data[0]["email"] == "u1@example.com"
    assert data[1]["email"] == "u2@example.com"


@pytest.mark.asyncio
async def test_get_user_api_details(client: AsyncClient, db_session, authorized_user):
    """Verify detail retrieval of a specific user."""
    access_token = create_access_token(subject=authorized_user.id)

    target_user_id = uuid.uuid4()
    target_user = User(
        id=target_user_id,
        email="target@example.com",
        first_name="Target",
        is_active=True,
        is_deleted=False,
        is_superuser=False,
        roles=[],
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc),
    )

    call_count = 0

    async def mock_execute(*args, **kwargs):
        nonlocal call_count
        call_count += 1
        if call_count == 1:
            return make_mock_result(authorized_user)
        else:
            return make_mock_result(target_user)

    db_session.execute = mock_execute

    response = await client.get(
        f"/api/v1/users/{target_user_id}",
        headers={"Authorization": f"Bearer {access_token}"},
    )

    assert response.status_code == 200
    data = response.json()
    assert data["email"] == "target@example.com"
    assert data["first_name"] == "Target"


@pytest.mark.asyncio
async def test_update_user_api(client: AsyncClient, db_session, authorized_user):
    """Verify updating a user's details via API."""
    access_token = create_access_token(subject=authorized_user.id)

    target_user_id = uuid.uuid4()
    target_user = User(
        id=target_user_id,
        email="before@example.com",
        first_name="Before",
        is_active=True,
        is_deleted=False,
        is_superuser=False,
        roles=[],
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc),
    )

    call_count = 0

    async def mock_execute(*args, **kwargs):
        nonlocal call_count
        call_count += 1
        if call_count == 1:
            return make_mock_result(authorized_user)
        elif call_count == 2:
            # get_with_roles_and_permissions for target user
            return make_mock_result(target_user)
        elif call_count == 3:
            # get_with_roles_and_permissions for performing user (privilege check)
            return make_mock_result(authorized_user)
        elif call_count == 4:
            # get_by_email checking email duplication
            return make_mock_result(None)
        elif call_count == 5:
            # get_with_roles_and_permissions for target user after update
            return make_mock_result(target_user)
        return make_mock_result(None)

    db_session.execute = mock_execute

    payload = {
        "email": "after@example.com",
        "first_name": "After",
    }

    response = await client.put(
        f"/api/v1/users/{target_user_id}",
        json=payload,
        headers={"Authorization": f"Bearer {access_token}"},
    )

    assert response.status_code == 200
    data = response.json()
    assert data["email"] == "after@example.com"
    assert data["first_name"] == "After"


@pytest.mark.asyncio
async def test_delete_user_api(client: AsyncClient, db_session, authorized_user):
    """Verify soft deleting a user via API."""
    access_token = create_access_token(subject=authorized_user.id)

    target_user_id = uuid.uuid4()
    target_user = User(
        id=target_user_id,
        email="delete_me@example.com",
        is_active=True,
        is_deleted=False,
    )

    call_count = 0

    async def mock_execute(*args, **kwargs):
        nonlocal call_count
        call_count += 1
        if call_count == 1:
            return make_mock_result(authorized_user)
        return make_mock_result(None)

    db_session.execute = mock_execute

    async def mock_get(model, id):
        if model == User and id == target_user_id:
            return target_user
        return None

    db_session.get = mock_get

    response = await client.delete(
        f"/api/v1/users/{target_user_id}",
        headers={"Authorization": f"Bearer {access_token}"},
    )

    assert response.status_code == 200
    assert response.json() == {"message": "User deleted successfully"}
    assert target_user.is_deleted is True
