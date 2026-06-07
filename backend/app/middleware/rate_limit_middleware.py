import time
from collections import defaultdict
from typing import Callable

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse, Response

from app.core.config import settings

_rate_limit_store: dict[str, list[float]] = defaultdict(list)


class RateLimitMiddleware(BaseHTTPMiddleware):
    """In-memory sliding-window rate limiter for login brute-force protection."""

    def __init__(self, app, login_path: str | None = None):
        super().__init__(app)
        self.login_path = login_path or f"{settings.API_V1_STR}/auth/login"

    def _client_ip(self, request: Request) -> str:
        forwarded = request.headers.get("X-Forwarded-For")
        if forwarded:
            return forwarded.split(",")[0].strip()
        if request.client:
            return request.client.host
        return "unknown"

    def _is_rate_limited(self, client_ip: str) -> bool:
        now = time.monotonic()
        window = settings.RATE_LIMIT_LOGIN_WINDOW_SECONDS
        max_requests = settings.RATE_LIMIT_LOGIN_MAX

        timestamps = _rate_limit_store[client_ip]
        cutoff = now - window
        _rate_limit_store[client_ip] = [ts for ts in timestamps if ts > cutoff]

        if len(_rate_limit_store[client_ip]) >= max_requests:
            return True

        _rate_limit_store[client_ip].append(now)
        return False

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        if request.method == "POST" and request.url.path == self.login_path:
            client_ip = self._client_ip(request)
            if self._is_rate_limited(client_ip):
                return JSONResponse(
                    status_code=429,
                    content={
                        "error": {
                            "message": "Too many requests. Please try again later.",
                            "type": "RateLimitException",
                            "status_code": 429,
                        }
                    },
                )

        return await call_next(request)


def reset_rate_limit_store() -> None:
    """Clear in-memory rate limit counters (for tests)."""
    _rate_limit_store.clear()
