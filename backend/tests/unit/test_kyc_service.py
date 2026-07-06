import uuid
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.core.exceptions import ValidationException
from app.core.kyc_crypto import decrypt_aadhaar, encrypt_aadhaar
from app.core.kyc_profile import compute_aadhaar_mobile_hash
from app.models.user import User
from app.services.kyc import KycService


def _user(kyc_status: str = "not_started") -> User:
    return User(
        id=uuid.uuid4(),
        email="user@test.com",
        first_name="Test",
        last_name="User",
        mobile_number="9876543210",
        mobile_verified=True,
        kyc_status=kyc_status,
        is_active=True,
        is_deleted=False,
        is_superuser=False,
    )


@pytest.fixture
def user_repo():
    repo = MagicMock()
    repo.db = MagicMock()
    repo.db.commit = AsyncMock()
    return repo


@pytest.fixture
def sandbox():
    client = MagicMock()
    client.generate_aadhaar_otp = AsyncMock(return_value="ref-1234")
    client.verify_aadhaar_otp = AsyncMock(
        return_value={
            "data": {
                "status": "VALID",
                "name": "Ramesh Kumar",
                "date_of_birth": "15-08-1992",
                "gender": "M",
                "full_address": "Chennai, Tamil Nadu",
                "address": {"state": "Tamil Nadu", "pincode": 600002},
                "mobile": "9876543210",
            }
        }
    )
    client.verify_pan_aadhaar_link = AsyncMock(
        return_value={"data": {"link_status": "Y", "aadhaar_seeding_status": "Y"}}
    )
    client.verify_pan_details = AsyncMock(
        return_value={
            "data": {
                "status": "valid",
                "category": "individual",
                "name_as_per_pan_match": True,
                "date_of_birth_match": True,
            }
        }
    )
    return client


@pytest.fixture
def kyc_service(user_repo, sandbox):
    return KycService(user_repo, sandbox, audit_service=None)


@pytest.mark.asyncio
async def test_send_aadhaar_otp_returns_reference(kyc_service, user_repo, sandbox):
    user = _user()
    user_repo.get_with_roles_and_permissions = AsyncMock(return_value=user)

    ref = await kyc_service.send_aadhaar_otp(user.id, "1234 5678 9012")

    assert ref == "ref-1234"
    sandbox.generate_aadhaar_otp.assert_awaited_once_with("123456789012")


@pytest.mark.asyncio
async def test_verify_aadhaar_otp_stores_profile(kyc_service, user_repo, sandbox, monkeypatch):
    cleared: list[str] = []

    monkeypatch.setattr(
        "app.services.kyc.clear_personal_dashboard_cache",
        lambda user_id=None: cleared.append(user_id) if user_id else None,
    )

    user = _user()
    user_repo.get_with_roles_and_permissions = AsyncMock(return_value=user)

    result = await kyc_service.verify_aadhaar_otp(
        user.id, "ref-1234", "123456", "123456789012"
    )

    assert result.kyc_status == "aadhaar_verified"
    assert result.aadhaar_last4 == "9012"
    assert result.profile is not None
    assert result.profile.full_name is None
    assert result.profile.aadhaar_linked_mobile_masked == "XXXXXX3210"
    assert decrypt_aadhaar(user.kyc_aadhaar_encrypted) == "123456789012"
    user_repo.db.commit.assert_awaited()
    assert cleared == [str(user.id)]


@pytest.mark.asyncio
async def test_verify_aadhaar_rejects_mobile_mismatch(kyc_service, user_repo, sandbox):
    user = _user()
    user.mobile_number = "9123456789"
    user_repo.get_with_roles_and_permissions = AsyncMock(return_value=user)

    with pytest.raises(ValidationException, match="does not match"):
        await kyc_service.verify_aadhaar_otp(
            user.id, "ref-1234", "123456", "123456789012"
        )


@pytest.mark.asyncio
async def test_verify_aadhaar_otp_via_mobile_hash(kyc_service, user_repo, sandbox):
    user = _user()
    aadhaar = "123456789012"
    share_code = "2356"
    mobile_hash = compute_aadhaar_mobile_hash("9876543210", share_code, aadhaar)
    user_repo.get_with_roles_and_permissions = AsyncMock(return_value=user)
    sandbox.is_configured = True
    sandbox.verify_aadhaar_otp = AsyncMock(
        return_value={
            "data": {
                "status": "VALID",
                "name": "Ramesh Kumar",
                "date_of_birth": "15-08-1992",
                "gender": "M",
                "full_address": "Chennai, Tamil Nadu",
                "address": {"state": "Tamil Nadu", "pincode": 600002},
                "mobile_hash": mobile_hash,
                "share_code": share_code,
            }
        }
    )

    result = await kyc_service.verify_aadhaar_otp(
        user.id, "ref-1234", "123456", aadhaar
    )

    assert result.kyc_status == "aadhaar_verified"
    assert result.profile.aadhaar_linked_mobile_masked == "XXXXXX3210"


@pytest.mark.asyncio
async def test_verify_aadhaar_rejects_mobile_hash_mismatch(kyc_service, user_repo, sandbox):
    user = _user()
    user.mobile_number = "9123456789"
    aadhaar = "123456789012"
    share_code = "2356"
    mobile_hash = compute_aadhaar_mobile_hash("9876543210", share_code, aadhaar)
    user_repo.get_with_roles_and_permissions = AsyncMock(return_value=user)
    sandbox.is_configured = True
    sandbox.verify_aadhaar_otp = AsyncMock(
        return_value={
            "data": {
                "status": "VALID",
                "name": "Ramesh Kumar",
                "mobile_hash": mobile_hash,
                "share_code": share_code,
            }
        }
    )

    with pytest.raises(ValidationException, match="does not match"):
        await kyc_service.verify_aadhaar_otp(
            user.id, "ref-1234", "123456", aadhaar
        )


@pytest.mark.asyncio
async def test_verify_aadhaar_otp_valid_without_mobile_hash(kyc_service, user_repo, sandbox):
    user = _user()
    user_repo.get_with_roles_and_permissions = AsyncMock(return_value=user)
    sandbox.is_configured = True
    sandbox.verify_aadhaar_otp = AsyncMock(
        return_value={
            "data": {
                "status": "VALID",
                "name": "Ramesh Kumar",
                "date_of_birth": "15-08-1992",
                "gender": "M",
                "full_address": "Chennai, Tamil Nadu",
                "address": {"state": "Tamil Nadu", "pincode": 600002},
            }
        }
    )

    result = await kyc_service.verify_aadhaar_otp(
        user.id, "ref-1234", "123456", "123456789012"
    )

    assert result.kyc_status == "aadhaar_verified"
    assert result.profile.aadhaar_linked_mobile_masked == "XXXXXX3210"


@pytest.mark.asyncio
async def test_verify_pan_link_marks_verified(kyc_service, user_repo, sandbox, monkeypatch):
    cleared: list[str] = []

    def _clear(user_id: str | None = None) -> None:
        if user_id is not None:
            cleared.append(user_id)

    monkeypatch.setattr(
        "app.services.kyc.clear_personal_dashboard_cache",
        _clear,
    )

    user = _user("aadhaar_verified")
    user.kyc_aadhaar_encrypted = encrypt_aadhaar("123456789012")
    user.kyc_aadhaar_last4 = "9012"
    user.kyc_profile = (
        '{"full_name": "Ramesh Kumar", "date_of_birth": "15-08-1992", '
        '"aadhaar_last4": "9012"}'
    )
    user_repo.get_with_roles_and_permissions = AsyncMock(return_value=user)

    result = await kyc_service.verify_pan_aadhaar_link(user.id, "ABCDE1234F")

    assert result.kyc_status == "verified"
    assert result.pan_last4 == "234F"
    assert result.profile is not None
    assert result.profile.pan_number_masked == "XXXXXX234F"
    assert user.kyc_aadhaar_encrypted is None
    sandbox.verify_pan_details.assert_awaited_once()
    assert cleared == [str(user.id)]


@pytest.mark.asyncio
async def test_verify_pan_link_rejects_unlinked(kyc_service, user_repo, sandbox):
    user = _user("aadhaar_verified")
    user.kyc_aadhaar_encrypted = encrypt_aadhaar("123456789012")
    user.kyc_aadhaar_last4 = "9012"
    user.kyc_profile = '{"full_name": "Ramesh Kumar", "date_of_birth": "15-08-1992"}'
    user_repo.get_with_roles_and_permissions = AsyncMock(return_value=user)
    sandbox.verify_pan_aadhaar_link = AsyncMock(
        return_value={"data": {"link_status": "N"}}
    )

    with pytest.raises(ValidationException):
        await kyc_service.verify_pan_aadhaar_link(user.id, "ABCDE1234F")

    assert user.kyc_status == "rejected"


@pytest.mark.asyncio
async def test_pan_requires_aadhaar_first(kyc_service, user_repo):
    user = _user("not_started")
    user_repo.get_with_roles_and_permissions = AsyncMock(return_value=user)

    with pytest.raises(ValidationException, match="Aadhaar"):
        await kyc_service.verify_pan_aadhaar_link(user.id, "ABCDE1234F")
