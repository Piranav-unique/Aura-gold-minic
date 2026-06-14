import uuid

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories.customer import CustomerRepository

pytestmark = pytest.mark.integration


@pytest.mark.asyncio
async def test_customer_repository_unique_active_email(test_db: AsyncSession):
    repo = CustomerRepository(test_db)
    email = f"unique_{uuid.uuid4().hex[:8]}@example.com"

    await repo.create(
        {
            "customer_type": "individual",
            "full_name": "First Customer",
            "mobile_number": f"+9198{uuid.uuid4().int % 100000000:08d}",
            "email": email,
            "address": "Address 1",
            "status": "active",
        },
        commit=True,
    )

    duplicate = await repo.get_by_email(email)
    assert duplicate is not None
    assert duplicate.full_name == "First Customer"


@pytest.mark.asyncio
async def test_customer_repository_soft_deleted_email_reusable(test_db: AsyncSession):
    repo = CustomerRepository(test_db)
    email = f"reuse_{uuid.uuid4().hex[:8]}@example.com"
    mobile1 = f"+9198{uuid.uuid4().int % 100000000:08d}"
    mobile2 = f"+9197{uuid.uuid4().int % 100000000:08d}"

    first = await repo.create(
        {
            "customer_type": "individual",
            "full_name": "To Delete",
            "mobile_number": mobile1,
            "email": email,
            "address": "Old address",
            "status": "active",
        },
        commit=True,
    )
    first.is_deleted = True
    await test_db.commit()

    second = await repo.create(
        {
            "customer_type": "business",
            "full_name": "Replacement",
            "mobile_number": mobile2,
            "email": email,
            "address": "New address",
            "status": "active",
        },
        commit=True,
    )

    active = await repo.get_by_email(email)
    assert active is not None
    assert active.id == second.id
    assert active.full_name == "Replacement"


@pytest.mark.asyncio
async def test_customer_repository_list_excludes_soft_deleted(test_db: AsyncSession):
    repo = CustomerRepository(test_db)

    active = await repo.create(
        {
            "customer_type": "individual",
            "full_name": "Active Customer",
            "mobile_number": f"+9196{uuid.uuid4().int % 100000000:08d}",
            "email": f"active_{uuid.uuid4().hex[:8]}@example.com",
            "address": "Active",
            "status": "active",
        },
        commit=True,
    )
    deleted = await repo.create(
        {
            "customer_type": "individual",
            "full_name": "Deleted Customer",
            "mobile_number": f"+9195{uuid.uuid4().int % 100000000:08d}",
            "email": f"deleted_{uuid.uuid4().hex[:8]}@example.com",
            "address": "Deleted",
            "status": "inactive",
        },
        commit=True,
    )
    deleted.is_deleted = True
    await test_db.commit()

    items = await repo.list_customers(search="Customer")
    ids = {item.id for item in items}
    assert active.id in ids
    assert deleted.id not in ids
