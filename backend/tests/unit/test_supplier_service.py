import uuid
from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock

import pytest
from sqlalchemy.exc import IntegrityError

from app.core.exceptions import NotFoundException, ValidationException
from app.models.supplier import Supplier
from app.repositories.supplier import SupplierRepository
from app.schemas.supplier import SupplierCreate
from app.services.audit import AuditService
from app.services.supplier import SupplierService


@pytest.fixture
def mock_supplier_repo():
    repo = MagicMock(spec=SupplierRepository)
    repo.db = MagicMock()
    repo.db.commit = AsyncMock()
    repo.db.rollback = AsyncMock()
    repo.db.refresh = AsyncMock()
    return repo


@pytest.fixture
def mock_audit_service():
    return MagicMock(spec=AuditService)


@pytest.fixture
def supplier_service(mock_supplier_repo, mock_audit_service):
    return SupplierService(mock_supplier_repo, mock_audit_service)


def _sample_supplier(**overrides) -> Supplier:
    now = datetime.now(timezone.utc)
    data = {
        "id": uuid.uuid4(),
        "name": "Gold Suppliers Ltd",
        "contact_person": "Raj",
        "mobile_number": "+919876543210",
        "email": "raj@gold.com",
        "address": "Mumbai",
        "is_active": True,
        "is_deleted": False,
        "created_at": now,
        "updated_at": now,
    }
    data.update(overrides)
    return Supplier(**data)


@pytest.mark.asyncio
async def test_create_supplier_success(
    supplier_service, mock_supplier_repo, mock_audit_service
):
    supplier_in = SupplierCreate(name="Gold Suppliers Ltd")
    created = _sample_supplier()
    mock_supplier_repo.get_by_name = AsyncMock(return_value=None)
    mock_supplier_repo.create = AsyncMock(return_value=created)
    mock_audit_service.log_action = AsyncMock()

    result = await supplier_service.create_supplier(
        supplier_in, performing_user_id=uuid.uuid4()
    )

    assert result.name == "Gold Suppliers Ltd"
    mock_audit_service.log_action.assert_called_once()


@pytest.mark.asyncio
async def test_create_supplier_duplicate_name(supplier_service, mock_supplier_repo):
    existing = _sample_supplier()
    mock_supplier_repo.get_by_name = AsyncMock(return_value=existing)

    with pytest.raises(ValidationException, match="already registered"):
        await supplier_service.create_supplier(
            SupplierCreate(name="Gold Suppliers Ltd")
        )


@pytest.mark.asyncio
async def test_get_supplier_not_found(supplier_service, mock_supplier_repo):
    mock_supplier_repo.get_active = AsyncMock(return_value=None)

    with pytest.raises(NotFoundException):
        await supplier_service.get_supplier_by_id(uuid.uuid4())


@pytest.mark.asyncio
async def test_list_suppliers(supplier_service, mock_supplier_repo):
    supplier = _sample_supplier()
    mock_supplier_repo.list_suppliers = AsyncMock(return_value=[supplier])
    mock_supplier_repo.count_suppliers = AsyncMock(return_value=1)

    items, total = await supplier_service.list_suppliers(search="Gold")

    assert total == 1
    assert items[0].name == supplier.name


@pytest.mark.asyncio
async def test_update_supplier_success(
    supplier_service, mock_supplier_repo, mock_audit_service
):
    supplier = _sample_supplier()
    mock_supplier_repo.get_active = AsyncMock(return_value=supplier)
    mock_supplier_repo.get_by_name = AsyncMock(return_value=None)
    mock_audit_service.log_action = AsyncMock()

    from app.schemas.supplier import SupplierUpdate

    updated = await supplier_service.update_supplier(
        supplier.id,
        SupplierUpdate(contact_person="Amit"),
        performing_user_id=uuid.uuid4(),
    )

    assert updated.contact_person == "Amit"
    mock_audit_service.log_action.assert_called_once()


@pytest.mark.asyncio
async def test_delete_supplier_success(
    supplier_service, mock_supplier_repo, mock_audit_service
):
    supplier = _sample_supplier()
    mock_supplier_repo.get_active = AsyncMock(return_value=supplier)
    mock_supplier_repo.count_linked_inventory_items = AsyncMock(return_value=0)
    mock_audit_service.log_action = AsyncMock()

    assert await supplier_service.delete_supplier(supplier.id, uuid.uuid4()) is True


@pytest.mark.asyncio
async def test_delete_supplier_with_linked_inventory(
    supplier_service, mock_supplier_repo
):
    supplier = _sample_supplier()
    mock_supplier_repo.get_active = AsyncMock(return_value=supplier)
    mock_supplier_repo.count_linked_inventory_items = AsyncMock(return_value=2)

    with pytest.raises(ValidationException, match="linked"):
        await supplier_service.delete_supplier(supplier.id)


@pytest.mark.asyncio
async def test_create_supplier_integrity_error(supplier_service, mock_supplier_repo):
    mock_supplier_repo.get_by_name = AsyncMock(return_value=None)
    mock_supplier_repo.create = AsyncMock(
        side_effect=IntegrityError("", {}, Exception())
    )

    with pytest.raises(ValidationException, match="already registered"):
        await supplier_service.create_supplier(SupplierCreate(name="Duplicate Co"))
