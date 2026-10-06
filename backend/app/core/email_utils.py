import re
from typing import Optional

EMAIL_REGEX = re.compile(r"^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$")


def is_valid_customer_email(email: Optional[str]) -> bool:
    """Return True if email is a valid customer Gmail address ending in @gmail.com."""
    if not email:
        return False
    cleaned = email.strip().lower()
    if not cleaned or "@" not in cleaned:
        return False
    if not EMAIL_REGEX.match(cleaned):
        return False

    # Strictly require @gmail.com for retail customers
    if not cleaned.endswith("@gmail.com"):
        return False

    # Reject placeholder addresses containing 'agsgold' in username or domain
    if "agsgold" in cleaned:
        return False

    # Reject if local part is a mobile number (10+ digits)
    local_part = cleaned.split("@")[0]
    digits_only = re.sub(r"\D", "", local_part)
    if len(digits_only) >= 10 and (len(digits_only) == len(local_part) or local_part.startswith(digits_only)):
        return False

    # Local part must be at least 3 characters
    if len(local_part) < 3:
        return False

    return True


def is_placeholder_email(email: Optional[str]) -> bool:
    """Return True if email is None, empty, malformed, or an auto-generated placeholder or non-gmail address."""
    return not is_valid_customer_email(email)
