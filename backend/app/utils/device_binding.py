import re

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
    """No-op: multiple accounts may use the same device."""
    del user_repo, device_id


async def bind_device_for_mobile_login(
    user_repo: UserRepository,
    user: User,
    device_id: str,
) -> None:
    """Record the latest device used for login without blocking other devices."""
    user.registered_device_id = device_id
    await user_repo.db.commit()
