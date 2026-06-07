import pytest
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.models.role import Role
from app.models.permission import Permission


@pytest.mark.asyncio
async def test_create_and_retrieve_user_with_roles(test_db: AsyncSession):
    """Verify that a User can be created and saved, linked to a Role and Permission, and retrieved successfully."""
    # 1. Create a Permission
    perm = Permission(name="document:approve", description="Approve documents")
    test_db.add(perm)
    await test_db.flush()

    # 2. Create a Role and associate the Permission
    role = Role(name="approver", description="Can approve things")
    role.permissions.append(perm)
    test_db.add(role)
    await test_db.flush()

    # 3. Create a User and associate the Role
    user = User(
        email="test_integration@example.com",
        hashed_password="somehashedpw",
        first_name="Integration",
        last_name="Tester",
        roles=[role],
    )
    test_db.add(user)
    await test_db.commit()  # commit within nested transactional test session

    # 4. Fetch the user with roles and permissions loaded
    query = (
        select(User)
        .where(User.email == "test_integration@example.com")
        .options(selectinload(User.roles).selectinload(Role.permissions))
    )
    result = await test_db.execute(query)
    fetched_user = result.scalars().first()

    assert fetched_user is not None
    assert fetched_user.email == "test_integration@example.com"
    assert len(fetched_user.roles) == 1
    assert fetched_user.roles[0].name == "approver"
    assert len(fetched_user.roles[0].permissions) == 1
    assert fetched_user.roles[0].permissions[0].name == "document:approve"


@pytest.mark.asyncio
async def test_duplicate_email_constraint_active(test_db: AsyncSession):
    """Verify that creating two active users with the same email raises an IntegrityError."""
    user1 = User(
        email="duplicate@example.com",
        hashed_password="pw1",
        is_deleted=False,
    )
    test_db.add(user1)
    await test_db.flush()

    user2 = User(
        email="duplicate@example.com",
        hashed_password="pw2",
        is_deleted=False,
    )
    test_db.add(user2)

    with pytest.raises(IntegrityError):
        await test_db.flush()


@pytest.mark.asyncio
async def test_duplicate_email_allowed_if_soft_deleted(test_db: AsyncSession):
    """Verify that a duplicate email is allowed if the existing user is soft-deleted."""
    # Create and soft-delete user1
    user1 = User(
        email="softdelete@example.com",
        hashed_password="pw1",
        is_deleted=True,
    )
    test_db.add(user1)
    await test_db.flush()

    # Create active user2 with the same email (should succeed because user1 is soft-deleted)
    user2 = User(
        email="softdelete@example.com",
        hashed_password="pw2",
        is_deleted=False,
    )
    test_db.add(user2)
    await test_db.flush()

    # Fetch both users to verify they coexist
    query = select(User).where(User.email == "softdelete@example.com")
    result = await test_db.execute(query)
    users = result.scalars().all()

    assert len(users) == 2
    assert any(u.is_deleted is True for u in users)
    assert any(u.is_deleted is False for u in users)
