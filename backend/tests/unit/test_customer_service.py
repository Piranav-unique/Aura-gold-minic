import uuid
from datetime import datetime, timezone
from decimal import Decimal
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.core.exceptions import NotFoundException, ValidationException
from app.models.customer import Customer
from app.repositories.customer import CustomerRepository
from app.schemas.customer import CustomerCreate, CustomerUpdate
from app.services.audit import AuditService
from app.services.customer import CustomerService


@pytest.fixture
def mock_customer_repository():
    return MagicMock(spec=CustomerRepository)


@pytest.fixture
def mock_audit_service():
    return MagicMock(spec=AuditService)


@pytest.fixture
def customer_service(mock_customer_repository, mock_audit_service):
    return CustomerService(
        customer_repo=mock_customer_repository,
        audit_service=mock_audit_service,
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
async def test_create_customer_success(
    customer_service, mock_customer_repository, mock_audit_service
):
    customer_in = CustomerCreate(
        customer_type="individual",
        full_name="John Doe",
        mobile_number="+919876543210",
        email="john@example.com",
        address="123 Main Street",
    )

    created = _sample_customer()
    mock_customer_repository.get_by_email = AsyncMock(return_value=None)
    mock_customer_repository.get_by_mobile = AsyncMock(return_value=None)
    mock_customer_repository.create = AsyncMock(return_value=created)
    mock_audit_service.log_action = AsyncMock()

    result = await customer_service.create_customer(
        customer_in, performing_user_id=uuid.uuid4()
    )

    assert result.full_name == "John Doe"
    mock_customer_repository.create.assert_called_once()
    mock_audit_service.log_action.assert_called_once()


@pytest.mark.asyncio
async def test_create_customer_duplicate_email(
    customer_service, mock_customer_repository
):
    customer_in = CustomerCreate(
        customer_type="individual",
        full_name="John Doe",
        mobile_number="+919876543210",
        email="john@example.com",
        address="123 Main Street",
    )

    mock_customer_repository.get_by_email = AsyncMock(return_value=_sample_customer())

    with pytest.raises(ValidationException, match="already registered"):
        await customer_service.create_customer(customer_in)


@pytest.mark.asyncio
async def test_create_customer_duplicate_mobile(
    customer_service, mock_customer_repository
):
    customer_in = CustomerCreate(
        customer_type="individual",
        full_name="John Doe",
        mobile_number="+919876543210",
        email="john@example.com",
        address="123 Main Street",
    )

    mock_customer_repository.get_by_email = AsyncMock(return_value=None)
    mock_customer_repository.get_by_mobile = AsyncMock(return_value=_sample_customer())

    with pytest.raises(ValidationException, match="already registered"):
        await customer_service.create_customer(customer_in)


@pytest.mark.asyncio
async def test_get_customer_by_id_not_found(customer_service, mock_customer_repository):
    mock_customer_repository.get_active = AsyncMock(return_value=None)

    with pytest.raises(NotFoundException, match="Customer not found"):
        await customer_service.get_customer_by_id(uuid.uuid4())


@pytest.mark.asyncio
async def test_list_customers_returns_items_and_total(
    customer_service, mock_customer_repository
):
    customers = [_sample_customer(), _sample_customer(email="jane@example.com")]
    mock_customer_repository.list_customers = AsyncMock(return_value=customers)
    mock_customer_repository.count_customers = AsyncMock(return_value=2)

    items, total = await customer_service.list_customers(
        skip=0, limit=10, search="john"
    )

    assert len(items) == 2
    assert total == 2


@pytest.mark.asyncio
async def test_update_customer_success(
    customer_service, mock_customer_repository, mock_audit_service
):
    customer = _sample_customer()
    customer_in = CustomerUpdate(full_name="Jane Doe")

    mock_customer_repository.get_active = AsyncMock(return_value=customer)
    mock_customer_repository.db = MagicMock()
    mock_customer_repository.db.commit = AsyncMock()
    mock_customer_repository.db.refresh = AsyncMock()
    mock_audit_service.log_action = AsyncMock()

    result = await customer_service.update_customer(
        customer.id, customer_in, performing_user_id=uuid.uuid4()
    )

    assert result.full_name == "Jane Doe"
    mock_audit_service.log_action.assert_called_once()


@pytest.mark.asyncio
async def test_update_customer_duplicate_email(
    customer_service, mock_customer_repository
):
    customer = _sample_customer()
    other = _sample_customer(id=uuid.uuid4(), email="other@example.com")
    customer_in = CustomerUpdate(email="other@example.com")

    mock_customer_repository.get_active = AsyncMock(return_value=customer)
    mock_customer_repository.get_by_email = AsyncMock(return_value=other)

    with pytest.raises(ValidationException, match="already registered"):
        await customer_service.update_customer(customer.id, customer_in)


@pytest.mark.asyncio
async def test_delete_customer_soft_delete(
    customer_service, mock_customer_repository, mock_audit_service
):
    customer = _sample_customer()
    mock_customer_repository.get_active = AsyncMock(return_value=customer)
    mock_customer_repository.db = MagicMock()
    mock_customer_repository.db.commit = AsyncMock()
    mock_audit_service.log_action = AsyncMock()

    result = await customer_service.delete_customer(
        customer.id, performing_user_id=uuid.uuid4()
    )

    assert result is True
    assert customer.is_deleted is True
    assert customer.deleted_at is not None
    mock_audit_service.log_action.assert_called_once()


@pytest.mark.asyncio
async def test_create_customer_handles_integrity_error(
    customer_service, mock_customer_repository, mock_audit_service
):
    from sqlalchemy.exc import IntegrityError

    customer_in = CustomerCreate(
        customer_type="individual",
        full_name="John Doe",
        mobile_number="+919876543210",
        email="john@example.com",
        address="123 Main Street",
    )

    mock_customer_repository.get_by_email = AsyncMock(return_value=None)
    mock_customer_repository.get_by_mobile = AsyncMock(return_value=None)
    mock_customer_repository.create = AsyncMock(
        side_effect=IntegrityError("", {}, Exception())
    )
    mock_customer_repository.db = MagicMock()
    mock_customer_repository.db.rollback = AsyncMock()

    with pytest.raises(ValidationException, match="already registered"):
        await customer_service.create_customer(customer_in)


@pytest.mark.asyncio
async def test_record_transaction_metrics(customer_service, mock_customer_repository):
    customer = _sample_customer()
    mock_customer_repository.get_active = AsyncMock(return_value=customer)
    mock_customer_repository.db = MagicMock()
    mock_customer_repository.db.commit = AsyncMock()
    mock_customer_repository.db.refresh = AsyncMock()

    updated = await customer_service.record_transaction_metrics(
        customer.id,
        revenue_delta=Decimal("1500.50"),
    )

    assert updated.total_purchases == 1
    assert updated.total_revenue == Decimal("1500.50")
    assert updated.last_transaction_date is not None
