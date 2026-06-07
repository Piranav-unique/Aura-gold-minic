import pytest
from httpx import AsyncClient
from fastapi import status


@pytest.mark.asyncio
async def test_not_found_error_handler(client: AsyncClient):
    """Verify that requesting an unregistered path yields standard 404 response shape."""
    response = await client.get("/api/v1/invalid-route-nonexistent")
    assert response.status_code == status.HTTP_404_NOT_FOUND
    data = response.json()
    assert "detail" in data
