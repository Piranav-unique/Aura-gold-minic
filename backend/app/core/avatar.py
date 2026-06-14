"""Avatar upload validation helpers."""

import base64
import binascii
import re

from app.core.config import settings
from app.core.exceptions import ValidationException

_DATA_URL_PATTERN = re.compile(
    r"^data:image/(jpeg|png|gif|webp);base64,(.+)$", re.IGNORECASE
)

_MAGIC_BYTES: dict[str, list[bytes]] = {
    "image/jpeg": [b"\xff\xd8\xff"],
    "image/png": [b"\x89PNG\r\n\x1a\n"],
    "image/gif": [b"GIF87a", b"GIF89a"],
    "image/webp": [b"RIFF"],
}


def _decode_avatar_payload(raw: str) -> tuple[bytes, str]:
    """Decode base64 avatar payload, stripping optional data-URL prefix."""
    content_type = "image/png"
    payload = raw.strip()

    match = _DATA_URL_PATTERN.match(payload)
    if match:
        content_type = f"image/{match.group(1).lower()}"
        payload = match.group(2)

    try:
        image_bytes = base64.b64decode(payload, validate=True)
    except (binascii.Error, ValueError) as exc:
        raise ValidationException("Invalid base64 avatar data") from exc

    return image_bytes, content_type


def _validate_magic_bytes(image_bytes: bytes, content_type: str) -> None:
    signatures = _MAGIC_BYTES.get(content_type)
    if not signatures:
        raise ValidationException(f"Unsupported image type: {content_type}")

    if content_type == "image/webp":
        if (
            len(image_bytes) < 12
            or image_bytes[:4] != b"RIFF"
            or image_bytes[8:12] != b"WEBP"
        ):
            raise ValidationException(
                "Avatar content does not match declared image type"
            )
        return

    if not any(image_bytes.startswith(sig) for sig in signatures):
        raise ValidationException("Avatar content does not match declared image type")


def validate_and_encode_avatar(
    raw_base64: str, declared_content_type: str
) -> tuple[str, str]:
    """Validate avatar bytes and return normalized base64 + content type."""
    image_bytes, detected_type = _decode_avatar_payload(raw_base64)

    if len(image_bytes) > settings.AVATAR_MAX_BYTES:
        raise ValidationException(
            f"Avatar image exceeds maximum size of {settings.AVATAR_MAX_BYTES} bytes"
        )

    if len(image_bytes) == 0:
        raise ValidationException("Avatar image is empty")

    content_type = declared_content_type.lower()
    if content_type not in _MAGIC_BYTES:
        raise ValidationException("Avatar must be JPEG, PNG, GIF, or WebP")

    _validate_magic_bytes(image_bytes, content_type)

    normalized = base64.b64encode(image_bytes).decode("ascii")
    return normalized, content_type
