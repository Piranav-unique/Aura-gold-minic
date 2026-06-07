import pytest
import uuid
from unittest.mock import AsyncMock, MagicMock

from app.core.exceptions import NotFoundException, ValidationException
from app.models.role import Role
from app.models.permission import Permission
from app.models.user import User
from app.repositories.role import RoleRepository
from app.repositories.permission import PermissionRepository
from app.repositories.user import UserRepository
from app.services.rbac import RbacService
from app.schemas.rbac import RoleCreate, PermissionCreate


@pytest.fixture
def mock_role_repository():
    return MagicMock(spec=RoleRepository)


@pytest.fixture
def mock_permission_repository():
    return MagicMock(spec=PermissionRepository)


@pytest.fixture
def mock_user_repository():
    return MagicMock(spec=UserRepository)


@pytest.fixture
def rbac_service(
    mock_role_repository, mock_permission_repository, mock_user_repository
):
    return RbacService(
        role_repo=mock_role_repository,
        permission_repo=mock_permission_repository,
        user_repo=mock_user_repository,
    )


@pytest.mark.asyncio
async def test_create_role_success(rbac_service, mock_role_repository):
    """Verify that a role can be created successfully when name is unique."""
    role_in = RoleCreate(name="admin", description="Admin role")
    mock_role_repository.get_by_name = AsyncMock(return_value=None)
    mock_role_repository.create = AsyncMock(return_value=Role(name="admin"))

    result = await rbac_service.create_role(role_in)

    assert result.name == "admin"
    mock_role_repository.get_by_name.assert_called_once_with("admin")
    mock_role_repository.create.assert_called_once()


@pytest.mark.asyncio
async def test_create_role_duplicate_raises_exception(
    rbac_service, mock_role_repository
):
    """Verify that creating a role with a duplicate name raises ValidationException."""
    role_in = RoleCreate(name="admin", description="Admin role")
    mock_role_repository.get_by_name = AsyncMock(return_value=Role(name="admin"))

    with pytest.raises(ValidationException) as exc_info:
        await rbac_service.create_role(role_in)

    assert "already exists" in str(exc_info.value).lower()


@pytest.mark.asyncio
async def test_assign_role_to_user(
    rbac_service, mock_user_repository, mock_role_repository
):
    """Verify role assignment appends the role to user.roles list."""
    user_id = uuid.uuid4()
    role_id = uuid.uuid4()

    mock_user = User(id=user_id, email="test@example.com", roles=[])
    mock_role = Role(id=role_id, name="admin")

    mock_user_repository.get_with_roles_and_permissions = AsyncMock(
        return_value=mock_user
    )
    mock_role_repository.get = AsyncMock(return_value=mock_role)
    mock_user_repository.db = MagicMock()
    mock_user_repository.db.commit = AsyncMock()
    mock_user_repository.db.refresh = AsyncMock()

    updated_user = await rbac_service.assign_role_to_user(user_id, role_id)

    assert mock_role in updated_user.roles
    mock_user_repository.get_with_roles_and_permissions.assert_called_once_with(user_id)
    mock_role_repository.get.assert_called_once_with(role_id)


@pytest.mark.asyncio
async def test_assign_permission_to_role(
    rbac_service, mock_role_repository, mock_permission_repository
):
    """Verify permission assignment appends the permission to role.permissions list."""
    role_id = uuid.uuid4()
    permission_id = uuid.uuid4()

    mock_role = Role(id=role_id, name="admin", permissions=[])
    mock_permission = Permission(id=permission_id, name="user:create")

    mock_role_repository.get_with_permissions = AsyncMock(return_value=mock_role)
    mock_permission_repository.get = AsyncMock(return_value=mock_permission)
    mock_role_repository.db = MagicMock()
    mock_role_repository.db.commit = AsyncMock()
    mock_role_repository.db.refresh = AsyncMock()

    updated_role = await rbac_service.assign_permission_to_role(role_id, permission_id)

    assert mock_permission in updated_role.permissions
    mock_role_repository.get_with_permissions.assert_called_once_with(role_id)
    mock_permission_repository.get.assert_called_once_with(permission_id)


@pytest.mark.asyncio
async def test_get_role_by_id_success(rbac_service, mock_role_repository):
    """Verify that a role can be retrieved by ID."""
    role_id = uuid.uuid4()
    mock_role = Role(id=role_id, name="User")
    mock_role_repository.get_with_permissions = AsyncMock(return_value=mock_role)

    result = await rbac_service.get_role_by_id(role_id)
    assert result == mock_role
    mock_role_repository.get_with_permissions.assert_called_once_with(role_id)


@pytest.mark.asyncio
async def test_get_role_by_id_not_found(rbac_service, mock_role_repository):
    """Verify that get_role_by_id raises NotFoundException if role doesn't exist."""
    role_id = uuid.uuid4()
    mock_role_repository.get_with_permissions = AsyncMock(return_value=None)

    with pytest.raises(NotFoundException):
        await rbac_service.get_role_by_id(role_id)


@pytest.mark.asyncio
async def test_list_roles(rbac_service, mock_role_repository):
    """Verify listing roles calls the repository with correct pagination parameters."""
    mock_roles = [Role(name="Admin"), Role(name="User")]
    mock_role_repository.list = AsyncMock(return_value=mock_roles)

    result = await rbac_service.list_roles(skip=0, limit=10)
    assert result == mock_roles
    mock_role_repository.list.assert_called_once_with(skip=0, limit=10)


@pytest.mark.asyncio
async def test_create_permission_success(rbac_service, mock_permission_repository):
    """Verify that a permission can be created successfully when name is unique."""
    perm_in = PermissionCreate(name="user:write", description="Write user data")
    mock_permission_repository.get_by_name = AsyncMock(return_value=None)
    mock_permission_repository.create = AsyncMock(
        return_value=Permission(name="user:write")
    )

    result = await rbac_service.create_permission(perm_in)
    assert result.name == "user:write"
    mock_permission_repository.get_by_name.assert_called_once_with("user:write")
    mock_permission_repository.create.assert_called_once()


@pytest.mark.asyncio
async def test_create_permission_duplicate_raises_exception(
    rbac_service, mock_permission_repository
):
    """Verify that creating a permission with a duplicate name raises ValidationException."""
    perm_in = PermissionCreate(name="user:write", description="Write user data")
    mock_permission_repository.get_by_name = AsyncMock(
        return_value=Permission(name="user:write")
    )

    with pytest.raises(ValidationException):
        await rbac_service.create_permission(perm_in)


@pytest.mark.asyncio
async def test_list_permissions(rbac_service, mock_permission_repository):
    """Verify listing permissions calls the repository with correct pagination parameters."""
    mock_perms = [Permission(name="user:read"), Permission(name="user:write")]
    mock_permission_repository.list = AsyncMock(return_value=mock_perms)

    result = await rbac_service.list_permissions(skip=5, limit=15)
    assert result == mock_perms
    mock_permission_repository.list.assert_called_once_with(skip=5, limit=15)
