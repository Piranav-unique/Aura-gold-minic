import uuid
from datetime import datetime, timezone
from unittest.mock import AsyncMock

import pytest

from app.core.exceptions import ForbiddenException, ValidationException
from app.models.user import User
from app.models.workflow import WorkflowRequest
from app.schemas.workflow import (
    WorkflowCommentCreate,
    WorkflowDecisionRequest,
    WorkflowRequestCreate,
    WorkflowSubmitRequest,
)
from app.services.workflow import WorkflowService


def _make_request(
    *,
    state: str = "draft",
    requester_id: uuid.UUID | None = None,
    assignee_id: uuid.UUID | None = None,
) -> WorkflowRequest:
    now = datetime.now(timezone.utc)
    return WorkflowRequest(
        id=uuid.uuid4(),
        request_number="WR-20260608-0001",
        title="Test request",
        description="Details",
        request_type="general",
        state=state,
        requester_id=requester_id or uuid.uuid4(),
        assignee_id=assignee_id,
        entity_type=None,
        entity_id=None,
        payload=None,
        escalation_level=0,
        pending_since=None,
        submitted_at=None,
        resolved_at=None,
        created_at=now,
        updated_at=now,
    )


@pytest.mark.asyncio
async def test_submit_requires_draft_state():
    repo = AsyncMock()
    user_repo = AsyncMock()
    service = WorkflowService(repo, user_repo)

    request = _make_request(state="pending")
    repo.get_for_update.return_value = request

    with pytest.raises(ValidationException, match="draft"):
        await service.submit_request(
            request.id,
            WorkflowSubmitRequest(),
            performing_user_id=request.requester_id,
        )


@pytest.mark.asyncio
async def test_approve_requires_assignee():
    repo = AsyncMock()
    user_repo = AsyncMock()
    service = WorkflowService(repo, user_repo)

    assignee = uuid.uuid4()
    other = uuid.uuid4()
    request = _make_request(state="pending", assignee_id=assignee)
    repo.get_for_update.return_value = request

    with pytest.raises(ForbiddenException):
        await service.approve_request(
            request.id,
            WorkflowDecisionRequest(comment="ok"),
            performing_user_id=other,
        )


@pytest.mark.asyncio
async def test_create_request_records_history():
    repo = AsyncMock()
    user_repo = AsyncMock()
    audit = AsyncMock()
    service = WorkflowService(repo, user_repo, audit_service=audit)

    requester = uuid.uuid4()
    created = _make_request(state="draft", requester_id=requester)
    repo.next_request_number.return_value = "WR-20260608-0001"
    repo.create.return_value = created
    repo.get_with_details.return_value = created

    result = await service.create_request(
        WorkflowRequestCreate(title="New", request_type="general"),
        performing_user_id=requester,
    )

    assert result.title == "Test request"
    repo.add_history.assert_called_once()
    audit.log_action.assert_called_once()


def _make_user(user_id: uuid.UUID | None = None) -> User:
    now = datetime.now(timezone.utc)
    uid = user_id or uuid.uuid4()
    return User(
        id=uid,
        email="test@example.com",
        is_active=True,
        is_deleted=False,
        is_superuser=False,
        roles=[],
        created_at=now,
        updated_at=now,
    )


@pytest.mark.asyncio
async def test_comment_blocked_on_terminal_state():
    repo = AsyncMock()
    user_repo = AsyncMock()
    service = WorkflowService(repo, user_repo)

    request = _make_request(state="approved")
    repo.get.return_value = request

    with pytest.raises(ValidationException, match="resolved"):
        await service.add_comment(
            request.id,
            WorkflowCommentCreate(body="late comment"),
            performing_user_id=request.requester_id,
            current_user=_make_user(request.requester_id),
        )
