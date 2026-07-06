import re

from app.core.exceptions import AuthenticationException, ValidationException
from app.models.user import User
from app.repositories.user import UserRepository

_DEVICE_ID_RE = re.compile(
    r"^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
    re.IGNORECASE,
)


def normalize_device_id(raw: str) -> str:
    cleaned = (raw or "").strip().lower()
    if not _DEVICE_ID_RE.match(cleaned):
        raise ValueError("Invalid device identifier")
    return cleaned


def validate_device_id(raw: str) -> str:
    try:
        return normalize_device_id(raw)
    except ValueError as exc:
        raise ValueError("Invalid device identifier") from exc


async def ensure_device_available_for_registration(
    user_repo: UserRepository,
    device_id: str,
) -> None:
    """Reject signup when this device is already linked to another account."""
    existing = await user_repo.get_by_registered_device_id(device_id)
    if existing:
        raise ValidationException(
            "This device is already linked to another account. "
            "Please sign in with your registered mobile number."
        )


async def bind_device_for_mobile_login(
    user_repo: UserRepository,
    user: User,
    device_id: str,
) -> None:
    """Ensure mobile login uses the same device that registered the account."""
    if user.registered_device_id:
        if user.registered_device_id != device_id:
            raise AuthenticationException(
                "This account is registered on another device. "
                "Please sign in using the device you registered with."
            )
        return

    existing = await user_repo.get_by_registered_device_id(device_id)
    if existing and existing.id != user.id:
        raise AuthenticationException(
            "This device is already linked to another account."
        )

    user.registered_device_id = device_id
    await user_repo.db.commit()
