import os
from pathlib import Path

import httpx
import pytest_asyncio
from httpx import ASGITransport, AsyncClient


def _load_env_file() -> None:
    """Load backend/.env so local smoke settings are available."""
    env_file = Path(__file__).resolve().parents[1] / ".env"
    if not env_file.exists():
        return
    with open(env_file) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, value = line.split("=", 1)
                key = key.strip()
                value = value.strip().strip("\"'")
                if key not in os.environ:
                    os.environ[key] = value


_load_env_file()

SMOKE_BASE_URL = os.getenv("SMOKE_BASE_URL", "http://localhost:8000").rstrip("/")


def _live_server_available() -> bool:
    """Return True when a deployed API responds on SMOKE_BASE_URL."""
    try:
        with httpx.Client(base_url=SMOKE_BASE_URL, timeout=2.0) as probe:
            response = probe.get("/health")
            return response.status_code == 200
    except httpx.HTTPError:
        return False


@pytest_asyncio.fixture
async def smoke_client():
    """Async HTTP client for smoke tests.

    Uses the live API when reachable (CI post-deploy). Otherwise exercises the
    FastAPI app in-process against the seeded test database.
    """
    if _live_server_available():
        async with AsyncClient(base_url=SMOKE_BASE_URL, timeout=15.0) as client:
            yield client
        return

    from app.database.session import get_db_session
    from app.main import app
    from tests.conftest import test_session_maker

    async def override_get_db():
        async with test_session_maker() as session:
            yield session

    app.dependency_overrides[get_db_session] = override_get_db
    try:
        async with AsyncClient(
            transport=ASGITransport(app=app),
            base_url="http://testserver",
        ) as client:
            yield client
    finally:
        app.dependency_overrides.clear()
