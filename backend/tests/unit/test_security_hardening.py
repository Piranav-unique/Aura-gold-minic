import pytest
from fastapi import FastAPI
from fastapi.responses import JSONResponse
from fastapi.testclient import TestClient

from app.core.config import Settings
from app.middleware.rate_limit_middleware import RateLimitMiddleware, reset_rate_limit_store
from app.middleware.security_headers_middleware import SecurityHeadersMiddleware


def test_production_secret_key_validation():
    # Weak default key should fail in production
    with pytest.raises(ValueError, match="SECRET_KEY must be overridden"):
        Settings(
            ENVIRONMENT="production",
            SECRET_KEY="secret-key-change-me",
            DATABASE_URL="postgresql+asyncpg://u:p@localhost:5432/db",
        )

    # Short key should fail in production
    with pytest.raises(ValueError, match="at least 32 characters"):
        Settings(
            ENVIRONMENT="production",
            SECRET_KEY="short-secret-key-12345",
            DATABASE_URL="postgresql+asyncpg://u:p@localhost:5432/db",
        )

    # Valid 64-character secret key should succeed in production
    strong_key = "a" * 64
    s = Settings(
        ENVIRONMENT="production",
        SECRET_KEY=strong_key,
        DATABASE_URL="postgresql+asyncpg://u:p@localhost:5432/db",
    )
    assert s.SECRET_KEY == strong_key


def test_security_headers_middleware():
    app = FastAPI()
    app.add_middleware(SecurityHeadersMiddleware)

    @app.get("/api/v1/auth/test")
    def auth_endpoint():
        return {"status": "ok"}

    @app.get("/api/v1/public/test")
    def public_endpoint():
        return {"status": "public"}

    client = TestClient(app)

    # Test sensitive endpoint gets cache-control and security headers
    res_auth = client.get("/api/v1/auth/test")
    assert res_auth.status_code == 200
    assert res_auth.headers["X-Content-Type-Options"] == "nosniff"
    assert res_auth.headers["X-Frame-Options"] == "SAMEORIGIN"
    assert res_auth.headers["X-XSS-Protection"] == "1; mode=block"
    assert res_auth.headers["Referrer-Policy"] == "strict-origin-when-cross-origin"
    assert "camera=()" in res_auth.headers["Permissions-Policy"]
    assert "no-store" in res_auth.headers["Cache-Control"]

    # Test public endpoint gets basic security headers
    res_pub = client.get("/api/v1/public/test")
    assert res_pub.status_code == 200
    assert res_pub.headers["X-Content-Type-Options"] == "nosniff"


def test_rate_limit_otp_send_endpoints():
    reset_rate_limit_store()
    app = FastAPI()
    app.add_middleware(RateLimitMiddleware)

    @app.post("/api/v1/auth/signup/otp/send")
    def send_otp():
        return {"message": "sent"}

    client = TestClient(app)

    # Send 5 OTP requests (max allowed)
    for _ in range(5):
        res = client.post("/api/v1/auth/signup/otp/send")
        assert res.status_code == 200

    # 6th request must trigger rate limit 429
    res_blocked = client.post("/api/v1/auth/signup/otp/send")
    assert res_blocked.status_code == 429
    assert res_blocked.headers.get("Retry-After") is not None
    body = res_blocked.json()
    assert body["error"]["type"] == "RateLimitException"
    assert body["error"]["status_code"] == 429

    reset_rate_limit_store()


def test_rate_limit_auth_attempt_endpoints():
    reset_rate_limit_store()
    app = FastAPI()
    app.add_middleware(RateLimitMiddleware)

    @app.post("/api/v1/auth/login/mobile")
    def login_mobile():
        return {"token": "xyz"}

    client = TestClient(app)

    # 10 attempts allowed
    for _ in range(10):
        res = client.post("/api/v1/auth/login/mobile")
        assert res.status_code == 200

    # 11th request must be blocked
    res_blocked = client.post("/api/v1/auth/login/mobile")
    assert res_blocked.status_code == 429
    assert res_blocked.json()["error"]["status_code"] == 429

    reset_rate_limit_store()
