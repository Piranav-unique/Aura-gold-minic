import re
from typing import Optional

EMAIL_REGEX = re.compile(r"^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$")


def is_placeholder_email(email: Optional[str]) -> bool:
    """Return True if email is None, empty, malformed, or an auto-generated placeholder.

    Placeholders include:
    - @mobile.agsgold.com (system auto-generated on mobile signup)
    - Any domain containing 'agsgold' (e.g. phoneno.agsgold@gmail.com, user@agsgold.com)
    - Local part that consists purely of 10 or more digits (mobile number used as local part)
    """
    if not email:
        return True
    cleaned = email.strip().lower()
    if not cleaned or "@" not in cleaned:
        return True
    if not EMAIL_REGEX.match(cleaned):
        return True

    # Reject system generated placeholder domain
    if cleaned.endswith("@mobile.agsgold.com") or cleaned.endswith("@agsgold.com"):
        return True

    # Reject placeholder addresses containing 'agsgold' in username or domain
    if "agsgold" in cleaned:
        return True

    # Reject if local part is a mobile number (10+ digits)
    local_part = cleaned.split("@")[0]
    digits_only = re.sub(r"\D", "", local_part)
    if len(digits_only) >= 10 and (len(digits_only) == len(local_part) or local_part.startswith(digits_only)):
        return True

    return False
