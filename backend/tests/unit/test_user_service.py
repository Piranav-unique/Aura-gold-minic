import pytest
import uuid
from unittest.mock import AsyncMock, MagicMock

from app.core.exceptions import NotFoundException, ValidationException
from app.core.security import verify_password
from app.models.user import User
from app.models.role import Role
from app.repositories.user import UserRepository
from app.repositories.role import RoleRepository
from app.services.user import UserService
from app.schemas.user import UserCreate, UserUpdate


@pytest.fixture
def mock_user_repository():
    return MagicMock(spec=UserRepository)


@pytest.fixture
def mock_role_repository():
    return MagicMock(spec=RoleRepository)


@pytest.fixture
def user_service(mock_user_repository, mock_role_repository):
    return UserService(user_repo=mock_user_repository, role_repo=mock_role_repository)


@pytest.mark.asyncio
async def test_create_user_success(user_service, mock_user_repository, mock_role_repository):
    """Verify that a user is successfully created with hashed password and associated roles."""
    role_id = uuid.uuid4()
    user_in = UserCreate(
        email="test@example.com",
        password="secret_password",
        first_name="John",
        last_name="Doe",
        roles=[role_id],
    )

    mock_user_repository.get_by_email = AsyncMock(return_value=None)
    mock_role = Role(id=role_id, name="User")
    mock_role_repository.get_by_ids = AsyncMock(return_value=[mock_role])

    created_user_instance = None

    def mock_create(user_data, commit=False):
        nonlocal created_user_instance
        created_user_instance = User(**user_data, roles=[])
        return created_user_instance

    mock_user_repository.create = AsyncMock(side_effect=mock_create)

    async def mock_get_with_roles(uid):
        if created_user_instance:
            created_user_instance.roles = [mock_role]
            return created_user_instance
        return None

    mock_user_repository.get_with_roles_and_permissions = AsyncMock(
        side_effect=mock_get_with_roles
    )
    mock_user_repository.db = MagicMock()
    mock_user_repository.db.commit = AsyncMock()

    created_user = await user_service.create_user(user_in)

    assert created_user.email == "test@example.com"
    assert verify_password("secret_password", created_user.hashed_password) is True
    assert created_user.first_name == "John"
    assert created_user.last_name == "Doe"
    assert mock_role in created_user.roles

    mock_user_repository.get_by_email.assert_called_once_with("test@example.com")
    mock_role_repository.get_by_ids.assert_called_once_with([role_id])
    mock_user_repository.create.assert_called_once()
    mock_user_repository.db.commit.assert_called_once()
    mock_user_repository.get_with_roles_and_permissions.assert_called_once_with(
        created_user.id
    )


@pytest.mark.asyncio
async def test_create_user_duplicate_email_raises_exception(user_service, mock_user_repository):
    """Verify that creating a user with a duplicate email raises ValidationException."""
    user_in = UserCreate(
        email="existing@example.com",
        password="secret_password",
        first_name="Existing",
    )

    mock_user_repository.get_by_email = AsyncMock(
        return_value=User(id=uuid.uuid4(), email="existing@example.com")
    )

    with pytest.raises(ValidationException) as exc_info:
        await user_service.create_user(user_in)

    assert "already registered" in str(exc_info.value).lower()
    mock_user_repository.get_by_email.assert_called_once_with("existing@example.com")


@pytest.mark.asyncio
async def test_create_user_invalid_role_raises_exception(
    user_service, mock_user_repository, mock_role_repository
):
    """Verify that creating a user with a non-existent role raises NotFoundException."""
    invalid_role_id = uuid.uuid4()
    user_in = UserCreate(
        email="test@example.com",
        password="secret_password",
        roles=[invalid_role_id],
    )

    mock_user_repository.get_by_email = AsyncMock(return_value=None)
    mock_role_repository.get_by_ids = AsyncMock(return_value=[])
    mock_user_repository.create = AsyncMock(return_value=User(email="test@example.com", roles=[]))

    with pytest.raises(NotFoundException) as exc_info:
        await user_service.create_user(user_in)

    assert f"role '{invalid_role_id}' not found" in str(exc_info.value).lower()
    mock_role_repository.get_by_ids.assert_called_once_with([invalid_role_id])


@pytest.mark.asyncio
async def test_get_user_by_id_success(user_service, mock_user_repository):
    """Verify that an existing user is returned by ID."""
    user_id = uuid.uuid4()
    mock_user = User(id=user_id, email="test@example.com")
    mock_user_repository.get_with_roles_and_permissions = AsyncMock(return_value=mock_user)

    result = await user_service.get_user_by_id(user_id)

    assert result == mock_user
    mock_user_repository.get_with_roles_and_permissions.assert_called_once_with(user_id)


@pytest.mark.asyncio
async def test_get_user_by_id_not_found(user_service, mock_user_repository):
    """Verify that get_user_by_id raises NotFoundException if user doesn't exist."""
    user_id = uuid.uuid4()
    mock_user_repository.get_with_roles_and_permissions = AsyncMock(return_value=None)

    with pytest.raises(NotFoundException) as exc_info:
        await user_service.get_user_by_id(user_id)

    assert "user not found" in str(exc_info.value).lower()


@pytest.mark.asyncio
async def test_list_users(user_service, mock_user_repository):
    """Verify list_users forwards search/filter parameters to repository."""
    mock_users = [User(email="a@test.com"), User(email="b@test.com")]
    mock_user_repository.list_users = AsyncMock(return_value=mock_users)

    role_filter_id = uuid.uuid4()
    result = await user_service.list_users(
        skip=10,
        limit=20,
        search="test",
        is_active=True,
        is_superuser=False,
        role_id=role_filter_id,
    )

    assert result == mock_users
    mock_user_repository.list_users.assert_called_once_with(
        skip=10,
        limit=20,
        search="test",
        is_active=True,
        is_superuser=False,
        role_id=role_filter_id,
    )


@pytest.mark.asyncio
async def test_update_user_success(user_service, mock_user_repository, mock_role_repository):
    """Verify that updating a user successfully applies updates, including roles and password hashing."""
    user_id = uuid.uuid4()
    old_role = Role(id=uuid.uuid4(), name="User")
    new_role = Role(id=uuid.uuid4(), name="Admin")
    user = User(
        id=user_id,
        email="old@example.com",
        first_name="OldName",
        hashed_password="old_hashed_password",
        roles=[old_role],
    )

    user_update_in = UserUpdate(
        email="new@example.com",
        password="new_password",
        first_name="NewName",
        roles=[new_role.id],
    )

    mock_user_repository.get_with_roles_and_permissions = AsyncMock(return_value=user)
    mock_user_repository.get_by_email = AsyncMock(return_value=None)
    mock_role_repository.get_by_ids = AsyncMock(return_value=[new_role])

    mock_user_repository.db = MagicMock()
    mock_user_repository.db.commit = AsyncMock()
    mock_user_repository.db.refresh = AsyncMock()

    updated = await user_service.update_user(user_id, user_update_in)

    assert updated.email == "new@example.com"
    assert verify_password("new_password", updated.hashed_password) is True
    assert updated.first_name == "NewName"
    assert new_role in updated.roles
    assert old_role not in updated.roles

    assert mock_user_repository.get_with_roles_and_permissions.call_count == 2
    mock_user_repository.get_by_email.assert_called_once_with("new@example.com")
    mock_role_repository.get_by_ids.assert_called_once_with([new_role.id])
    mock_user_repository.db.commit.assert_called_once()


@pytest.mark.asyncio
async def test_update_user_duplicate_email_raises_exception(user_service, mock_user_repository):
    """Verify that updating user to another user's registered email raises ValidationException."""
    user_id = uuid.uuid4()
    user = User(id=user_id, email="user@example.com")
    user_update_in = UserUpdate(email="duplicate@example.com")

    mock_user_repository.get_with_roles_and_permissions = AsyncMock(return_value=user)
    mock_user_repository.get_by_email = AsyncMock(
        return_value=User(id=uuid.uuid4(), email="duplicate@example.com")
    )

    with pytest.raises(ValidationException) as exc_info:
        await user_service.update_user(user_id, user_update_in)

    assert "already registered" in str(exc_info.value).lower()


@pytest.mark.asyncio
async def test_delete_user_success(user_service, mock_user_repository):
    """Verify that deleting a user sets the is_deleted flag and timestamp (soft-delete)."""
    user_id = uuid.uuid4()
    user = User(id=user_id, email="test@example.com", is_deleted=False, deleted_at=None)

    mock_user_repository.get = AsyncMock(return_value=user)
    mock_user_repository.db = MagicMock()
    mock_user_repository.db.commit = AsyncMock()

    result = await user_service.delete_user(user_id)

    assert result is True
    assert user.is_deleted is True
    assert user.deleted_at is not None
    mock_user_repository.get.assert_called_once_with(user_id)
    mock_user_repository.db.commit.assert_called_once()


@pytest.mark.asyncio
async def test_delete_user_not_found(user_service, mock_user_repository):
    """Verify deleting a non-existent user raises NotFoundException."""
    user_id = uuid.uuid4()
    mock_user_repository.get = AsyncMock(return_value=None)

    with pytest.raises(NotFoundException) as exc_info:
        await user_service.delete_user(user_id)

    assert "user not found" in str(exc_info.value).lower()
