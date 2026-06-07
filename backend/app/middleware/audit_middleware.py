import contextvars
from typing import Optional
from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware

# Context variables to hold request client metadata within async execution chains
client_ip_ctx: contextvars.ContextVar[Optional[str]] = contextvars.ContextVar(
    "client_ip", default=None
)
user_agent_ctx: contextvars.ContextVar[Optional[str]] = contextvars.ContextVar(
    "user_agent", default=None
)


class AuditRequestContextMiddleware(BaseHTTPMiddleware):
    """Middleware capturing request host metadata (IP, user agent) into context variables."""

    async def dispatch(self, request: Request, call_next):
        # Try to resolve client IP considering forward proxy headers
        x_forwarded_for = request.headers.get("x-forwarded-for")
        if x_forwarded_for:
            ip = x_forwarded_for.split(",")[0].strip()
        else:
            ip = request.client.host if request.client else None

        ua = request.headers.get("user-agent")

        # Set context variables for the current async task execution scope
        token_ip = client_ip_ctx.set(ip)
        token_ua = user_agent_ctx.set(ua)

        try:
            return await call_next(request)
        finally:
            # Reset context variables to clean context state
            client_ip_ctx.reset(token_ip)
            user_agent_ctx.reset(token_ua)
