import uuid
from datetime import datetime, timezone
from decimal import Decimal
from typing import Optional

from app.core import audit_actions
from app.core.exceptions import NotFoundException, ValidationException
from app.models.account_deletion_request import AccountDeletionRequest
from app.models.user import User
from app.repositories.account_deletion import AccountDeletionRepository
from app.repositories.user import UserRepository
from app.schemas.account_deletion import (
    AccountDeletionListResponse,
    AccountDeletionRequestResponse,
    CreateAccountDeletionRequest,
)
from app.services.audit import AuditService
from app.services.consumer_account_deletion import delete_consumer_account, is_staff_user


class AccountDeletionService:
    def __init__(
        self,
        deletion_repo: AccountDeletionRepository,
        user_repo: UserRepository,
        audit_service: Optional[AuditService] = None,
    ):
        self.deletion_repo = deletion_repo
        self.user_repo = user_repo
        self.audit_service = audit_service

    async def get_current_user_request(
        self, user_id: uuid.UUID
    ) -> Optional[AccountDeletionRequestResponse]:
        req = await self.deletion_repo.get_latest_for_user(user_id)
        if not req:
            return None
        return AccountDeletionRequestResponse.model_validate(req)

    async def create_deletion_request(
        self,
        user: User,
        data: CreateAccountDeletionRequest,
        client_ip: Optional[str] = None,
    ) -> AccountDeletionRequestResponse:
        if is_staff_user(user):
            raise ValidationException(
                "Staff and administrator accounts cannot request deletion from the app."
            )

        # Enforce that user's wallet is completely empty (0g Gold, 0g Silver)
        gold_balance = Decimal(str(user.gold_savings_grams or 0))
        silver_balance = Decimal(str(user.silver_savings_grams or 0))

        if gold_balance > Decimal("0") or silver_balance > Decimal("0"):
            parts = []
            if gold_balance > Decimal("0"):
                parts.append(f"{gold_balance:f}".rstrip("0").rstrip(".") + " g Gold")
            if silver_balance > Decimal("0"):
                parts.append(f"{silver_balance:f}".rstrip("0").rstrip(".") + " g Silver")
            holdings = " and ".join(parts)
            raise ValidationException(
                f"Your wallet is not empty ({holdings}). Please claim or sell your gold and silver "
                "according to the current live rate before deleting your account."
            )

        # Check if already has a pending request
        active = await self.deletion_repo.get_active_for_user(user.id)
        if active:
            raise ValidationException(
                "You already have an account deletion request pending review by the administrator."
            )

        user_name = f"{user.first_name or ''} {user.last_name or ''}".strip() or None

        request_record = await self.deletion_repo.create(
            {
                "user_id": user.id,
                "user_email": user.email,
                "user_mobile": user.mobile_number,
                "user_name": user_name,
                "status": "pending",
                "reason": data.reason,
                "gold_balance_grams": gold_balance,
                "silver_balance_grams": silver_balance,
            },
            commit=True,
        )

        if self.audit_service:
            await self.audit_service.log(
                action=audit_actions.ACCOUNT_DELETION_REQUESTED,
                actor_id=user.id,
                entity_type="account_deletion_request",
                entity_id=request_record.id,
                ip_address=client_ip,
                metadata={"reason": data.reason, "user_email": user.email},
            )

        return AccountDeletionRequestResponse.model_validate(request_record)

    async def cancel_deletion_request(
        self,
        user: User,
        client_ip: Optional[str] = None,
    ) -> AccountDeletionRequestResponse:
        active = await self.deletion_repo.get_active_for_user(user.id)
        if not active:
            raise NotFoundException("No pending account deletion request found.")

        active.status = "cancelled"
        await self.deletion_repo.db.commit()
        await self.deletion_repo.db.refresh(active)

        if self.audit_service:
            await self.audit_service.log(
                action=audit_actions.ACCOUNT_DELETION_CANCELLED,
                actor_id=user.id,
                entity_type="account_deletion_request",
                entity_id=active.id,
                ip_address=client_ip,
            )

        return AccountDeletionRequestResponse.model_validate(active)

    async def list_requests(
        self,
        status: Optional[str] = None,
        skip: int = 0,
        limit: int = 50,
    ) -> AccountDeletionListResponse:
        items = await self.deletion_repo.list_all(skip=skip, limit=limit, status=status)
        total = await self.deletion_repo.count_all(status=status)
        return AccountDeletionListResponse(
            items=[AccountDeletionRequestResponse.model_validate(item) for item in items],
            total=total,
            skip=skip,
            limit=limit,
        )

    async def approve_request(
        self,
        request_id: uuid.UUID,
        admin_user: User,
        comment: Optional[str] = None,
        client_ip: Optional[str] = None,
    ) -> AccountDeletionRequestResponse:
        req = await self.deletion_repo.get(request_id)
        if not req:
            raise NotFoundException("Account deletion request not found.")
        if req.status != "pending":
            raise ValidationException(f"Cannot approve request with status '{req.status}'.")

        # Find target user
        user = None
        if req.user_id:
            user = await self.user_repo.get(req.user_id)

        if user:
            # Re-verify that user wallet has not acquired positive balance
            gold_balance = Decimal(str(user.gold_savings_grams or 0))
            silver_balance = Decimal(str(user.silver_savings_grams or 0))
            if gold_balance > Decimal("0") or silver_balance > Decimal("0"):
                raise ValidationException(
                    "Cannot approve deletion: User has acquired a non-empty gold or silver balance."
                )

            # Detach user_id so cascading doesn't delete the audit record of the request
            req.user_id = None
            req.status = "approved"
            req.reviewed_by_id = admin_user.id
            req.admin_comment = comment
            req.reviewed_at = datetime.now(timezone.utc)
            await self.deletion_repo.db.flush()

            # Destroy consumer data and user account
            await delete_consumer_account(self.deletion_repo.db, user)
        else:
            req.status = "approved"
            req.reviewed_by_id = admin_user.id
            req.admin_comment = comment
            req.reviewed_at = datetime.now(timezone.utc)

        await self.deletion_repo.db.commit()
        await self.deletion_repo.db.refresh(req)

        if self.audit_service:
            await self.audit_service.log(
                action=audit_actions.ACCOUNT_DELETION_APPROVED,
                actor_id=admin_user.id,
                entity_type="account_deletion_request",
                entity_id=req.id,
                ip_address=client_ip,
                metadata={"user_email": req.user_email, "admin_comment": comment},
            )

        return AccountDeletionRequestResponse.model_validate(req)

    async def reject_request(
        self,
        request_id: uuid.UUID,
        admin_user: User,
        comment: Optional[str] = None,
        client_ip: Optional[str] = None,
    ) -> AccountDeletionRequestResponse:
        req = await self.deletion_repo.get(request_id)
        if not req:
            raise NotFoundException("Account deletion request not found.")
        if req.status != "pending":
            raise ValidationException(f"Cannot reject request with status '{req.status}'.")

        req.status = "rejected"
        req.reviewed_by_id = admin_user.id
        req.admin_comment = comment
        req.reviewed_at = datetime.now(timezone.utc)

        await self.deletion_repo.db.commit()
        await self.deletion_repo.db.refresh(req)

        if self.audit_service:
            await self.audit_service.log(
                action=audit_actions.ACCOUNT_DELETION_REJECTED,
                actor_id=admin_user.id,
                entity_type="account_deletion_request",
                entity_id=req.id,
                ip_address=client_ip,
                metadata={"user_email": req.user_email, "admin_comment": comment},
            )

        return AccountDeletionRequestResponse.model_validate(req)
