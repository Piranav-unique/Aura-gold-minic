import hashlib
import json
import re
from datetime import datetime, timezone
from typing import Any, Optional

from app.schemas.profile import KycGovernmentProfile

_STRING_PROFILE_FIELDS = frozenset(
    {
        "full_name",
        "date_of_birth",
        "gender",
        "care_of",
        "full_address",
        "state",
        "district",
        "pincode",
        "aadhaar_last4",
        "aadhaar_linked_mobile_masked",
        "pan_number_masked",
        "pan_category",
        "pan_status",
        "aadhaar_seeding_status",
        "verified_at",
    }
)


def _optional_str(value: Any) -> Optional[str]:
    if value is None:
        return None
    text = str(value).strip()
    return text or None


def parse_aadhaar_profile(data: dict[str, Any], aadhaar_last4: str) -> dict[str, Any]:
    address = data.get("address") if isinstance(data.get("address"), dict) else {}
    gender_raw = str(data.get("gender", "")).strip().upper()
    gender = {"M": "Male", "F": "Female", "T": "Transgender"}.get(gender_raw, gender_raw)

    dob_raw = (
        data.get("date_of_birth")
        or data.get("dob")
        or data.get("dateOfBirth")
    )
    if not dob_raw and (data.get("year_of_birth") or data.get("yob")):
        dob_raw = f"01-01-{data.get('year_of_birth') or data.get('yob')}"

    return {
        "full_name": _optional_str(data.get("name") or data.get("full_name") or data.get("fullName")),
        "date_of_birth": _optional_str(dob_raw),
        "gender": _optional_str(gender),
        "care_of": _optional_str(data.get("care_of") or data.get("careOf")),
        "full_address": _optional_str(data.get("full_address") or data.get("fullAddress")),
        "state": _optional_str(address.get("state") or data.get("state")),
        "district": _optional_str(address.get("district") or data.get("district")),
        "pincode": _optional_str(address.get("pincode") or address.get("pin") or data.get("pincode")),
        "aadhaar_last4": _optional_str(aadhaar_last4),
        "source": "uidai",
    }


def parse_pan_profile(data: dict[str, Any], pan_number: str) -> dict[str, Any]:
    return {
        "pan_number_masked": f"XXXXXX{pan_number[-4:]}",
        "pan_category": _optional_str(data.get("category")),
        "pan_status": _optional_str(data.get("status")),
        "name_as_per_pan_match": data.get("name_as_per_pan_match"),
        "date_of_birth_match": data.get("date_of_birth_match"),
        "aadhaar_seeding_status": _optional_str(data.get("aadhaar_seeding_status")),
        "source": "income_tax",
    }


def merge_kyc_profile(
    existing: Optional[dict[str, Any]],
    updates: dict[str, Any],
) -> dict[str, Any]:
    merged = dict(existing or {})
    merged.update({k: v for k, v in updates.items() if v is not None})
    merged["verified_at"] = datetime.now(timezone.utc).isoformat()
    return merged


def mask_mobile(mobile: Optional[str]) -> Optional[str]:
    if not mobile:
        return None
    digits = re.sub(r"\D", "", str(mobile))
    if digits.startswith("91") and len(digits) == 12:
        digits = digits[2:]
    if len(digits) != 10:
        return None
    return f"XXXXXX{digits[-4:]}"


def compute_aadhaar_mobile_hash(
    mobile: str, share_code: str, aadhaar_number: str
) -> str:
    """UIDAI offline e-KYC mobile hash (Sha256 chain keyed by last Aadhaar digit)."""
    digits = re.sub(r"\D", "", aadhaar_number)
    last_digit = int(digits[-1]) if digits else 0
    current = hashlib.sha256(f"{mobile}{share_code}".encode()).hexdigest()
    if last_digit <= 1:
        return current
    for _ in range(2, last_digit + 1):
        current = hashlib.sha256(current.encode()).hexdigest()
    return current


def profile_for_api(
    kyc_status: str, raw: Optional[dict[str, Any]]
) -> Optional[dict[str, Any]]:
    """Return only fields safe to expose for the current KYC stage."""
    if not raw:
        return None
    if kyc_status == "aadhaar_verified":
        limited: dict[str, Any] = {}
        if raw.get("aadhaar_last4"):
            limited["aadhaar_last4"] = raw["aadhaar_last4"]
        if raw.get("aadhaar_linked_mobile_masked"):
            limited["aadhaar_linked_mobile_masked"] = raw["aadhaar_linked_mobile_masked"]
        return limited or None
    return raw


def profile_to_schema(raw: Optional[dict[str, Any]]) -> Optional[KycGovernmentProfile]:
    if not raw:
        return None
    payload: dict[str, Any] = {}
    for key in KycGovernmentProfile.model_fields:
        value = raw.get(key)
        if key in _STRING_PROFILE_FIELDS:
            value = _optional_str(value)
        payload[key] = value
    return KycGovernmentProfile(**payload)


def dumps_profile(profile: dict[str, Any]) -> str:
    normalized: dict[str, Any] = {}
    for key, value in profile.items():
        if key in _STRING_PROFILE_FIELDS:
            value = _optional_str(value)
        normalized[key] = value
    return json.dumps(normalized)


def loads_profile(value: Optional[str]) -> Optional[dict[str, Any]]:
    if not value:
        return None
    try:
        data = json.loads(value)
        return data if isinstance(data, dict) else None
    except json.JSONDecodeError:
        return None


def aadhaar_dob_for_pan(dob: Optional[str]) -> Optional[str]:
    if not dob:
        return None
    normalized = dob.strip().replace("-", "/").replace(".", "/")
    parts = [p.strip() for p in normalized.split("/") if p.strip()]
    if len(parts) == 3:
        if len(parts[0]) == 4:
            # YYYY/MM/DD -> DD/MM/YYYY
            return f"{parts[2].zfill(2)}/{parts[1].zfill(2)}/{parts[0]}"
        if len(parts[2]) == 4:
            # DD/MM/YYYY -> DD/MM/YYYY
            return f"{parts[0].zfill(2)}/{parts[1].zfill(2)}/{parts[2]}"
    if len(normalized) == 4 and normalized.isdigit():
        return f"01/01/{normalized}"
    return normalized
