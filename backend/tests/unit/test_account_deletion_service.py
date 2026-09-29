import uuid
from decimal import Decimal
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.core.exceptions import NotFoundException, ValidationException
from app.models.account_deletion_request import AccountDeletionRequest
from app.models.role import Role
from app.models.user import User
from app.schemas.account_deletion import (
    AccountDeletionDecisionRequest,
    CreateAccountDeletionRequest,
)
from app.services.account_deletion import AccountDeletionService


def _make_consumer_user(**kwargs) -> User:
    defaults = {
        "id": uuid.uuid4(),
        "email": "consumer@example.com",
        "first_name": "Test",
        "last_name": "Consumer",
        "mobile_number": "9876543210",
        "is_active": True,
        "is_deleted": False,
        "is_superuser": False,
        "roles": [],
        "gold_savings_grams": Decimal("0"),
        "silver_savings_grams": Decimal("0"),
    }
    defaults.update(kwargs)
    return User(**defaults)


def _make_admin_user() -> User:
    admin_role = Role(id=uuid.uuid4(), name="admin")
    return User(
        id=uuid.uuid4(),
        email="admin@agsgold.com",
        first_name="Admin",
        last_name="User",
        mobile_number="9943795005",
        is_active=True,
        is_deleted=False,
        is_superuser=True,
        roles=[admin_role],
    )


def _setup_service():
    deletion_repo = MagicMock()
    deletion_repo.db = MagicMock()
    deletion_repo.db.commit = AsyncMock()
    deletion_repo.db.refresh = AsyncMock()
    deletion_repo.db.flush = AsyncMock()
    deletion_repo.create = AsyncMock()
    deletion_repo.get = AsyncMock()
    deletion_repo.get_active_for_user = AsyncMock(return_value=None)
    deletion_repo.get_latest_for_user = AsyncMock(return_value=None)
    deletion_repo.list_all = AsyncMock(return_value=[])
    deletion_repo.count_all = AsyncMock(return_value=0)

    user_repo = MagicMock()
    user_repo.db = deletion_repo.db
    user_repo.get = AsyncMock()

    audit_service = MagicMock()
    audit_service.log = AsyncMock()

    service = AccountDeletionService(
        deletion_repo=deletion_repo,
        user_repo=user_repo,
        audit_service=audit_service,
    )
    return service, deletion_repo, user_repo


# ==============================================================================
# 1. Wallet Balance Blocking Tests
# ==============================================================================

@pytest.mark.asyncio
async def test_deletion_blocked_when_gold_balance_positive():
    service, deletion_repo, _ = _setup_service()
    user = _make_consumer_user(gold_savings_grams=Decimal("0.500000"))

    with pytest.raises(ValidationException) as exc_info:
        await service.create_deletion_request(
            user, CreateAccountDeletionRequest(reason="Moving abroad")
        )

    error_msg = str(exc_info.value)
    assert "Your wallet is not empty" in error_msg
    assert "0.5 g Gold" in error_msg
    assert "claim or sell your gold" in error_msg
    deletion_repo.create.assert_not_called()


@pytest.mark.asyncio
async def test_deletion_blocked_when_silver_balance_positive():
    service, deletion_repo, _ = _setup_service()
    user = _make_consumer_user(
        gold_savings_grams=Decimal("0"), silver_savings_grams=Decimal("10.000000")
    )

    with pytest.raises(ValidationException) as exc_info:
        await service.create_deletion_request(
            user, CreateAccountDeletionRequest()
        )

    error_msg = str(exc_info.value)
    assert "Your wallet is not empty" in error_msg
    assert "10 g Silver" in error_msg
    deletion_repo.create.assert_not_called()


@pytest.mark.asyncio
async def test_deletion_blocked_for_staff_user():
    service, deletion_repo, _ = _setup_service()
    admin = _make_admin_user()

    with pytest.raises(ValidationException, match="Staff and administrator accounts"):
        await service.create_deletion_request(
            admin, CreateAccountDeletionRequest()
        )


# ==============================================================================
# 2. Successful Deletion Request Creation (Empty Wallet)
# ==============================================================================

@pytest.mark.asyncio
async def test_deletion_request_created_when_wallet_empty():
    service, deletion_repo, _ = _setup_service()
    user = _make_consumer_user(
        gold_savings_grams=Decimal("0"),
        silver_savings_grams=Decimal("0"),
    )

    req_id = uuid.uuid4()
    mock_record = AccountDeletionRequest(
        id=req_id,
        user_id=user.id,
        user_email=user.email,
        user_mobile=user.mobile_number,
        user_name="Test Consumer",
        status="pending",
        reason="No longer using the app",
        gold_balance_grams=Decimal("0"),
        silver_balance_grams=Decimal("0"),
    )
    deletion_repo.create.return_value = mock_record

    result = await service.create_deletion_request(
        user, CreateAccountDeletionRequest(reason="No longer using the app")
    )

    assert result.status == "pending"
    assert result.user_email == "consumer@example.com"
    assert result.reason == "No longer using the app"
    deletion_repo.create.assert_called_once()
    create_args = deletion_repo.create.call_args[0][0]
    assert create_args["status"] == "pending"
    assert create_args["gold_balance_grams"] == Decimal("0")


@pytest.mark.asyncio
async def test_duplicate_pending_request_blocked():
    service, deletion_repo, _ = _setup_service()
    user = _make_consumer_user()

    # Existing active request
    deletion_repo.get_active_for_user.return_value = AccountDeletionRequest(
        id=uuid.uuid4(),
        user_id=user.id,
        user_email=user.email,
        status="pending",
    )

    with pytest.raises(ValidationException, match="already have an account deletion request pending"):
        await service.create_deletion_request(user, CreateAccountDeletionRequest())


# ==============================================================================
# 3. User Cancel Deletion Request
# ==============================================================================

@pytest.mark.asyncio
async def test_user_can_cancel_pending_request():
    service, deletion_repo, _ = _setup_service()
    user = _make_consumer_user()

    pending_req = AccountDeletionRequest(
        id=uuid.uuid4(),
        user_id=user.id,
        user_email=user.email,
        status="pending",
        gold_balance_grams=Decimal("0"),
        silver_balance_grams=Decimal("0"),
    )
    deletion_repo.get_active_for_user.return_value = pending_req

    result = await service.cancel_deletion_request(user)
    assert result.status == "cancelled"
    assert pending_req.status == "cancelled"
    deletion_repo.db.commit.assert_called_once()


# ==============================================================================
# 4. Admin Review & Decision Flow
# ==============================================================================

@pytest.mark.asyncio
async def test_admin_can_reject_deletion_request():
    service, deletion_repo, _ = _setup_service()
    admin = _make_admin_user()
    req_id = uuid.uuid4()

    pending_req = AccountDeletionRequest(
        id=req_id,
        user_id=uuid.uuid4(),
        user_email="consumer@example.com",
        status="pending",
        gold_balance_grams=Decimal("0"),
        silver_balance_grams=Decimal("0"),
    )
    deletion_repo.get.return_value = pending_req

    result = await service.reject_request(
        req_id, admin, comment="Account has pending grievance resolution."
    )

    assert result.status == "rejected"
    assert pending_req.status == "rejected"
    assert pending_req.reviewed_by_id == admin.id
    assert pending_req.admin_comment == "Account has pending grievance resolution."


@pytest.mark.asyncio
async def test_admin_can_approve_deletion_request_and_purges_data():
    service, deletion_repo, user_repo = _setup_service()
    admin = _make_admin_user()
    consumer = _make_consumer_user(
        gold_savings_grams=Decimal("0"),
        silver_savings_grams=Decimal("0"),
    )
    req_id = uuid.uuid4()

    pending_req = AccountDeletionRequest(
        id=req_id,
        user_id=consumer.id,
        user_email=consumer.email,
        status="pending",
        gold_balance_grams=Decimal("0"),
        silver_balance_grams=Decimal("0"),
    )
    deletion_repo.get.return_value = pending_req
    user_repo.get.return_value = consumer

    with patch("app.services.account_deletion.delete_consumer_account", new=AsyncMock()) as mock_purge:
        result = await service.approve_request(
            req_id, admin, comment="Approved by customer request"
        )

        assert result.status == "approved"
        assert pending_req.status == "approved"
        assert pending_req.reviewed_by_id == admin.id
        # delete_consumer_account was called with session and consumer user
        mock_purge.assert_called_once_with(deletion_repo.db, consumer)


@pytest.mark.asyncio
async def test_admin_cannot_approve_if_user_acquired_gold():
    service, deletion_repo, user_repo = _setup_service()
    admin = _make_admin_user()
    # User had 0g at request, but subsequently received 1.0g gold
    consumer = _make_consumer_user(
        gold_savings_grams=Decimal("1.000000"),
        silver_savings_grams=Decimal("0"),
    )
    req_id = uuid.uuid4()

    pending_req = AccountDeletionRequest(
        id=req_id,
        user_id=consumer.id,
        user_email=consumer.email,
        status="pending",
        gold_balance_grams=Decimal("0"),
        silver_balance_grams=Decimal("0"),
    )
    deletion_repo.get.return_value = pending_req
    user_repo.get.return_value = consumer

    with pytest.raises(ValidationException, match="User has acquired a non-empty gold or silver balance"):
        await service.approve_request(req_id, admin)
