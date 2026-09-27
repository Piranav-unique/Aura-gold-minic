import time
from collections import defaultdict
from typing import Callable

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse, Response

from app.core.client_ip import resolve_client_ip
from app.core.config import settings

_rate_limit_store: dict[str, list[float]] = defaultdict(list)


class RateLimitMiddleware(BaseHTTPMiddleware):
    """In-memory sliding-window rate limiter for sensitive endpoints."""

    PROFILE_PATHS = frozenset(
        {
            f"{settings.API_V1_STR}/profile/change-password",
            f"{settings.API_V1_STR}/profile/avatar",
        }
    )

    OTP_SEND_PATHS = frozenset(
        {
            f"{settings.API_V1_STR}/auth/signup/otp/send",
            f"{settings.API_V1_STR}/auth/login/otp/send",
            f"{settings.API_V1_STR}/bank-accounts/link/initiate",
        }
    )

    AUTH_ATTEMPT_PATHS = frozenset(
        {
            f"{settings.API_V1_STR}/auth/login/mobile",
            f"{settings.API_V1_STR}/auth/signup/otp/verify",
            f"{settings.API_V1_STR}/bank-accounts/link/verify",
        }
    )

    def __init__(self, app, login_path: str | None = None):
        super().__init__(app)
        self.login_path = login_path or f"{settings.API_V1_STR}/auth/login"

    def _client_ip(self, request: Request) -> str:
        return resolve_client_ip(request) or "unknown"

    def _is_rate_limited(
        self, client_ip: str, max_requests: int, window_seconds: int, scope: str
    ) -> bool:
        now = time.monotonic()
        key = f"{scope}:{client_ip}"
        timestamps = _rate_limit_store[key]
        cutoff = now - window_seconds
        _rate_limit_store[key] = [ts for ts in timestamps if ts > cutoff]

        if len(_rate_limit_store[key]) >= max_requests:
            return True

        _rate_limit_store[key].append(now)
        return False

    def _rate_limit_response(self, retry_after: int = 60) -> JSONResponse:
        return JSONResponse(
            status_code=429,
            headers={"Retry-After": str(retry_after)},
            content={
                "error": {
                    "message": "Too many requests. Please try again later.",
                    "type": "RateLimitException",
                    "status_code": 429,
                }
            },
        )

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        if request.method != "POST":
            return await call_next(request)

        client_ip = self._client_ip(request)
        path = request.url.path

        if path == self.login_path:
            if self._is_rate_limited(
                client_ip,
                settings.RATE_LIMIT_LOGIN_MAX,
                settings.RATE_LIMIT_LOGIN_WINDOW_SECONDS,
                "login",
            ):
                return self._rate_limit_response(settings.RATE_LIMIT_LOGIN_WINDOW_SECONDS)

        elif path in self.OTP_SEND_PATHS:
            if self._is_rate_limited(
                client_ip,
                settings.RATE_LIMIT_OTP_SEND_MAX,
                settings.RATE_LIMIT_OTP_SEND_WINDOW_SECONDS,
                "otp_send",
            ):
                return self._rate_limit_response(settings.RATE_LIMIT_OTP_SEND_WINDOW_SECONDS)

        elif path in self.AUTH_ATTEMPT_PATHS:
            if self._is_rate_limited(
                client_ip,
                settings.RATE_LIMIT_AUTH_ATTEMPT_MAX,
                settings.RATE_LIMIT_AUTH_ATTEMPT_WINDOW_SECONDS,
                "auth_attempt",
            ):
                return self._rate_limit_response(settings.RATE_LIMIT_AUTH_ATTEMPT_WINDOW_SECONDS)

        elif path in self.PROFILE_PATHS:
            if self._is_rate_limited(
                client_ip,
                settings.RATE_LIMIT_PROFILE_MAX,
                settings.RATE_LIMIT_PROFILE_WINDOW_SECONDS,
                "profile",
            ):
                return self._rate_limit_response(settings.RATE_LIMIT_PROFILE_WINDOW_SECONDS)

        return await call_next(request)


def reset_rate_limit_store() -> None:
    """Clear in-memory rate limit counters (for tests)."""
    _rate_limit_store.clear()
