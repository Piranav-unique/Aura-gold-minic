from starlette.requests import Request

from app.core import client_ip as client_ip_module
from app.core.client_ip import resolve_client_ip


def _request(
    headers: dict | None = None, client_host: str | None = "127.0.0.1"
) -> Request:
    scope = {
        "type": "http",
        "method": "GET",
        "path": "/",
        "headers": [
            (k.lower().encode(), v.encode()) for k, v in (headers or {}).items()
        ],
        "client": (client_host, 1234) if client_host else None,
        "server": ("testserver", 80),
        "scheme": "http",
        "http_version": "1.1",
    }
    return Request(scope)


def test_resolve_client_ip_from_client_host():
    assert resolve_client_ip(_request(client_host="192.168.1.10")) == "192.168.1.10"


def test_resolve_client_ip_unknown_when_missing():
    assert resolve_client_ip(_request(client_host=None)) is None


def test_resolve_client_ip_honors_forwarded_header_when_trusted(monkeypatch):
    monkeypatch.setattr(client_ip_module.settings, "TRUSTED_PROXY", True)
    request = _request(
        headers={"X-Forwarded-For": "203.0.113.1, 10.0.0.1"},
        client_host="10.0.0.1",
    )
    assert resolve_client_ip(request) == "203.0.113.1"


def test_resolve_client_ip_honors_real_ip_when_trusted(monkeypatch):
    monkeypatch.setattr(client_ip_module.settings, "TRUSTED_PROXY", True)
    request = _request(headers={"X-Real-IP": "198.51.100.20"}, client_host="10.0.0.1")
    assert resolve_client_ip(request) == "198.51.100.20"
