from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

from app.core.config import settings


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    """Middleware that injects industry-standard HTTP security headers into every response."""

    SENSITIVE_PREFIXES = (
        f"{settings.API_V1_STR}/auth",
        f"{settings.API_V1_STR}/profile",
        f"{settings.API_V1_STR}/bank-accounts",
        f"{settings.API_V1_STR}/admin",
    )

    async def dispatch(self, request: Request, call_next) -> Response:
        response: Response = await call_next(request)

        # Basic security headers
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "SAMEORIGIN"
        response.headers["X-XSS-Protection"] = "1; mode=block"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        response.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"

        # Enforce HSTS for HTTPS or non-development environments
        is_https = request.url.scheme == "https" or request.headers.get("x-forwarded-proto") == "https"
        if is_https or settings.ENVIRONMENT != "development":
            response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"

        # Prevent browser / proxy caching of sensitive auth, banking, and profile data
        path = request.url.path
        if any(path.startswith(prefix) for prefix in self.SENSITIVE_PREFIXES):
            response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate, private"
            response.headers["Pragma"] = "no-cache"

        # Mask server identification to prevent banner grabbing
        if "server" in response.headers:
            response.headers["Server"] = "AGS-Gold"

        return response
