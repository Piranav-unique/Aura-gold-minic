import uuid
from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock

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


def _workflow_service(
    *,
    audit=None,
    notification=None,
) -> tuple[WorkflowService, AsyncMock, AsyncMock]:
    repo = AsyncMock()
    repo.db = MagicMock()
    repo.db.flush = AsyncMock()
    repo.db.commit = AsyncMock()
    repo.db.refresh = AsyncMock()
    user_repo = AsyncMock()
    user_repo.get = AsyncMock(
        return_value=User(
            id=uuid.uuid4(),
            email="active@test.com",
            is_active=True,
            is_deleted=False,
            is_superuser=False,
            roles=[],
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc),
        )
    )
    user_repo.get_user_ids_with_permission = AsyncMock(return_value=[uuid.uuid4()])
    service = WorkflowService(repo, user_repo, audit, notification)
    return service, repo, user_repo


@pytest.mark.asyncio
async def test_submit_request_success():
    service, repo, user_repo = _workflow_service(
        audit=AsyncMock(), notification=AsyncMock()
    )
    requester = uuid.uuid4()
    assignee = uuid.uuid4()
    request = _make_request(state="draft", requester_id=requester, assignee_id=assignee)
    repo.get_for_update.return_value = request
    repo.get_with_details.return_value = request
    user_repo.get.return_value = _make_user(assignee)

    await service.submit_request(
        request.id,
        WorkflowSubmitRequest(comment="Please review"),
        performing_user_id=requester,
    )

    repo.update.assert_called()
    repo.db.commit.assert_called()


@pytest.mark.asyncio
async def test_approve_request_success():
    service, repo, _ = _workflow_service(audit=AsyncMock(), notification=AsyncMock())
    assignee = uuid.uuid4()
    request = _make_request(state="pending", assignee_id=assignee)
    repo.get_for_update.return_value = request
    repo.get_with_details.return_value = request

    await service.approve_request(
        request.id,
        WorkflowDecisionRequest(comment="Approved"),
        performing_user_id=assignee,
    )

    repo.update.assert_called()
    repo.db.commit.assert_called()


@pytest.mark.asyncio
async def test_reject_request_success():
    service, repo, _ = _workflow_service(audit=AsyncMock(), notification=AsyncMock())
    assignee = uuid.uuid4()
    request = _make_request(state="pending", assignee_id=assignee)
    repo.get_for_update.return_value = request
    repo.get_with_details.return_value = request

    await service.reject_request(
        request.id,
        WorkflowDecisionRequest(comment="Rejected"),
        performing_user_id=assignee,
    )

    repo.update.assert_called()


@pytest.mark.asyncio
async def test_update_request_success():
    service, repo, _ = _workflow_service(audit=AsyncMock())
    requester = uuid.uuid4()
    request = _make_request(state="draft", requester_id=requester)
    repo.get_for_update.return_value = request
    repo.get_with_details.return_value = request

    from app.schemas.workflow import WorkflowRequestUpdate

    await service.update_request(
        request.id,
        WorkflowRequestUpdate(title="Updated title"),
        performing_user_id=requester,
    )

    repo.update.assert_called()


@pytest.mark.asyncio
async def test_get_request_enforces_access():
    service, repo, _ = _workflow_service()
    owner = uuid.uuid4()
    intruder = uuid.uuid4()
    request = _make_request(state="pending", requester_id=owner, assignee_id=None)
    repo.get_with_details.return_value = request

    with pytest.raises(ForbiddenException):
        await service.get_request(request.id, _make_user(intruder))


@pytest.mark.asyncio
async def test_list_requests_scopes_to_current_user():
    service, repo, _ = _workflow_service()
    user = _make_user()
    request = _make_request(requester_id=user.id)
    repo.list_filtered.return_value = [request]
    repo.count_filtered.return_value = 1

    items, total = await service.list_requests(current_user=user)

    assert total == 1
    assert len(items) == 1
    assert repo.list_filtered.await_args.kwargs["mine_only"] is True


@pytest.mark.asyncio
async def test_add_comment_success():
    service, repo, _ = _workflow_service(audit=AsyncMock(), notification=AsyncMock())
    user_id = uuid.uuid4()
    request = _make_request(
        state="pending", requester_id=user_id, assignee_id=uuid.uuid4()
    )
    repo.get.return_value = request
    repo.get_with_details.return_value = request

    await service.add_comment(
        request.id,
        WorkflowCommentCreate(body="Looks good"),
        performing_user_id=user_id,
        current_user=_make_user(user_id),
    )

    repo.add_comment.assert_called_once()
    repo.db.commit.assert_called()
