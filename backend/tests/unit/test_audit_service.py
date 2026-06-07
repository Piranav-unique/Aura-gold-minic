import pytest
import uuid
from unittest.mock import AsyncMock, MagicMock

from app.models.audit_log import AuditLog
from app.repositories.audit_log import AuditLogRepository
from app.services.audit import AuditService
from app.middleware.audit_middleware import client_ip_ctx, user_agent_ctx


@pytest.fixture
def mock_audit_repository():
    return MagicMock(spec=AuditLogRepository)


@pytest.fixture
def audit_service(mock_audit_repository):
    return AuditService(audit_repo=mock_audit_repository)


@pytest.mark.asyncio
async def test_log_action_resolves_context_meta(audit_service, mock_audit_repository):
    """Verify log_action pulls client IP and User Agent from request context vars."""
    user_id = uuid.uuid4()

    # Set context variables
    token_ip = client_ip_ctx.set("192.168.1.50")
    token_ua = user_agent_ctx.set("Safari")

    try:
        mock_audit_repository.create = AsyncMock(
            return_value=AuditLog(action="test_action")
        )

        result = await audit_service.log_action(
            user_id=user_id,
            action="test_action",
            entity_type="Test",
            entity_id="999",
            metadata={"detail": "some_info"},
        )

        assert result.action == "test_action"
        mock_audit_repository.create.assert_called_once()

        # Check that it called create with resolved context values
        created_data = mock_audit_repository.create.call_args[0][0]
        assert created_data["user_id"] == user_id
        assert created_data["action"] == "test_action"
        assert created_data["entity_type"] == "Test"
        assert created_data["entity_id"] == "999"
        assert created_data["meta_data"] == {"detail": "some_info"}
        assert created_data["ip_address"] == "192.168.1.50"
        assert created_data["user_agent"] == "Safari"
        assert "timestamp" in created_data
    finally:
        client_ip_ctx.reset(token_ip)
        user_agent_ctx.reset(token_ua)


@pytest.mark.asyncio
async def test_list_audit_logs(audit_service, mock_audit_repository):
    """Verify list_audit_logs calls repository list_audit_logs with filters."""
    mock_logs = [AuditLog(action="a"), AuditLog(action="b")]
    mock_audit_repository.list_audit_logs = AsyncMock(return_value=mock_logs)

    filter_user_id = uuid.uuid4()
    result = await audit_service.list_audit_logs(
        skip=5,
        limit=50,
        user_id=filter_user_id,
        action="some_action",
        entity_type="SomeEntity",
    )

    assert result == mock_logs
    mock_audit_repository.list_audit_logs.assert_called_once_with(
        skip=5,
        limit=50,
        user_id=filter_user_id,
        action="some_action",
        entity_type="SomeEntity",
    )
