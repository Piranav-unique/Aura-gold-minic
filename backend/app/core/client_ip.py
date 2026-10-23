"""Shared client IP resolution with trusted-proxy support."""

from starlette.requests import Request

from app.core.config import settings


def resolve_client_ip(request: Request) -> str | None:
    """Resolve the client IP, honoring proxy headers only when configured."""
    if settings.TRUSTED_PROXY:
        # Set by Cloudflare (the VPS sits behind a Cloudflare Tunnel) to the
        # visitor's address; X-Forwarded-For may carry extra hops.
        cf_ip = request.headers.get("cf-connecting-ip")
        if cf_ip:
            return cf_ip.strip()
        forwarded = request.headers.get("x-forwarded-for")
        if forwarded:
            return forwarded.split(",")[0].strip()
        real_ip = request.headers.get("x-real-ip")
        if real_ip:
            return real_ip.strip()

    if request.client:
        return request.client.host
    return None
