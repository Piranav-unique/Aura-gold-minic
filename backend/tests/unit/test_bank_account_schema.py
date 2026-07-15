import pytest
from pydantic import ValidationError

from app.schemas.bank_account import BankLinkInitiateRequest


def _base_payload(**overrides):
    data = {
        "account_holder_name": "Ramesh Kumar",
        "account_number": "1234567890",
        "ifsc": "HDFC0001234",
        "bank_name": "HDFC Bank",
        "branch_name": "Chennai Main",
        "account_type": "savings",
        "bank_registered_mobile": "9876543210",
    }
    data.update(overrides)
    return data


def test_bank_link_request_normalizes_mobile():
    body = BankLinkInitiateRequest(**_base_payload(bank_registered_mobile="+91 98765 43210"))
    assert body.bank_registered_mobile == "9876543210"


def test_bank_link_request_rejects_invalid_mobile():
    with pytest.raises(ValidationError):
        BankLinkInitiateRequest(**_base_payload(bank_registered_mobile="12345"))
