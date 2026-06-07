import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_health_check(client: AsyncClient):
    """Test that the /health endpoint is live and returns the expected status format."""
    response = await client.get("/health")
    assert response.status_code == 200

    data = response.json()
    assert data == {"status": "healthy", "service": "ags-gold-api"}
