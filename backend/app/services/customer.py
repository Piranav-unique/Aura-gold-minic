import uuid
from datetime import datetime, timezone
from decimal import Decimal
from typing import Optional, Tuple

from sqlalchemy.exc import IntegrityError

from app.core import audit_actions
from app.core.exceptions import NotFoundException, ValidationException
from app.models.customer import Customer
from app.repositories.customer import CustomerRepository
from app.schemas.customer import CustomerCreate, CustomerUpdate
from app.services.audit import AuditService


def normalize_mobile(value: str) -> str:
    """Normalize mobile numbers to a consistent storage format."""
    return value.replace(" ", "").replace("-", "")


class CustomerService:
    """Service class encapsulating Customer management business logic."""

    def __init__(
        self,
        customer_repo: CustomerRepository,
        audit_service: Optional[AuditService] = None,
    ):
        self.customer_repo = customer_repo
        self.audit_service = audit_service

    async def _ensure_unique_contact(
        self,
        email: Optional[str] = None,
        mobile_number: Optional[str] = None,
        exclude_id: Optional[uuid.UUID] = None,
    ) -> None:
        if email:
            existing = await self.customer_repo.get_by_email(email)
            if existing and (exclude_id is None or existing.id != exclude_id):
                raise ValidationException(
                    f"Email '{email}' is already registered to a customer"
                )
        if mobile_number:
            existing = await self.customer_repo.get_by_mobile(mobile_number)
            if existing and (exclude_id is None or existing.id != exclude_id):
                raise ValidationException(
                    f"Mobile number '{mobile_number}' is already registered"
                )

    async def create_customer(
        self,
        customer_in: CustomerCreate,
        performing_user_id: Optional[uuid.UUID] = None,
    ) -> Customer:
        """Create a new customer with validation and audit logging."""
        mobile = normalize_mobile(customer_in.mobile_number)
        await self._ensure_unique_contact(
            email=customer_in.email,
            mobile_number=mobile,
        )

        customer_data = customer_in.model_dump()
        customer_data["mobile_number"] = mobile
        customer_data.setdefault("total_purchases", 0)
        customer_data.setdefault("total_revenue", Decimal("0"))

        try:
            customer = await self.customer_repo.create(customer_data, commit=True)
        except IntegrityError as exc:
            await self.customer_repo.db.rollback()
            raise ValidationException(
                "Email or mobile number already registered to a customer"
            ) from exc

        if self.audit_service:
            await self.audit_service.log_action(
                user_id=performing_user_id,
                action=audit_actions.CUSTOMER_CREATE,
                entity_type="Customer",
                entity_id=str(customer.id),
                metadata={
                    "full_name": customer.full_name,
                    "email": customer.email,
                    "customer_type": customer.customer_type,
                },
            )

        return customer

    async def get_customer_by_id(self, customer_id: uuid.UUID) -> Customer:
        """Fetch active customer by ID."""
        customer = await self.customer_repo.get_active(customer_id)
        if not customer:
            raise NotFoundException("Customer not found")
        return customer

    async def list_customers(
        self,
        skip: int = 0,
        limit: int = 100,
        search: Optional[str] = None,
        customer_type: Optional[str] = None,
        status: Optional[str] = None,
        sort_by: str = "created_at",
        sort_order: str = "desc",
    ) -> Tuple[list[Customer], int]:
        """Fetch customers matching filters with total count."""
        items = await self.customer_repo.list_customers(
            skip=skip,
            limit=limit,
            search=search,
            customer_type=customer_type,
            status=status,
            sort_by=sort_by,
            sort_order=sort_order,
        )
        total = await self.customer_repo.count_customers(
            search=search,
            customer_type=customer_type,
            status=status,
        )
        return items, total

    async def update_customer(
        self,
        customer_id: uuid.UUID,
        customer_in: CustomerUpdate,
        performing_user_id: Optional[uuid.UUID] = None,
    ) -> Customer:
        """Update an existing customer and log the update event."""
        customer = await self.customer_repo.get_active(customer_id)
        if not customer:
            raise NotFoundException("Customer not found")

        update_data = customer_in.model_dump(exclude_unset=True)
        # Enforce name immutability: customer name cannot be modified by admin
        update_data.pop("full_name", None)

        if "mobile_number" in update_data:
            update_data["mobile_number"] = normalize_mobile(
                update_data["mobile_number"]
            )

        email = update_data.get("email")
        mobile = update_data.get("mobile_number")
        if email or mobile:
            await self._ensure_unique_contact(
                email=email if email and email != customer.email else None,
                mobile_number=(
                    mobile if mobile and mobile != customer.mobile_number else None
                ),
                exclude_id=customer.id,
            )

        for field, value in update_data.items():
            setattr(customer, field, value)

        try:
            await self.customer_repo.db.commit()
            await self.customer_repo.db.refresh(customer)
        except IntegrityError as exc:
            await self.customer_repo.db.rollback()
            raise ValidationException(
                "Email or mobile number already registered to a customer"
            ) from exc

        if self.audit_service:
            await self.audit_service.log_action(
                user_id=performing_user_id,
                action=audit_actions.CUSTOMER_UPDATE,
                entity_type="Customer",
                entity_id=str(customer.id),
                metadata={"updated_fields": list(update_data.keys())},
            )

        return customer

    async def delete_customer(
        self,
        customer_id: uuid.UUID,
        performing_user_id: Optional[uuid.UUID] = None,
    ) -> bool:
        """Soft-delete a customer and log the deletion event."""
        customer = await self.customer_repo.get_active(customer_id)
        if not customer:
            raise NotFoundException("Customer not found")

        customer.is_deleted = True
        customer.deleted_at = datetime.now(timezone.utc)
        await self.customer_repo.db.commit()

        if self.audit_service:
            await self.audit_service.log_action(
                user_id=performing_user_id,
                action=audit_actions.CUSTOMER_DELETE,
                entity_type="Customer",
                entity_id=str(customer_id),
                metadata={"full_name": customer.full_name},
            )

        return True

    async def record_transaction_metrics(
        self,
        customer_id: uuid.UUID,
        *,
        purchase_delta: int = 1,
        revenue_delta: Decimal,
        transaction_at: Optional[datetime] = None,
        commit: bool = True,
    ) -> Customer:
        """Update business metrics after a paid customer-facing transaction."""
        customer = await self.get_customer_by_id(customer_id)
        customer.total_purchases += purchase_delta
        customer.total_revenue += revenue_delta
        customer.last_transaction_date = transaction_at or datetime.now(timezone.utc)
        if commit:
            await self.customer_repo.db.commit()
            await self.customer_repo.db.refresh(customer)
        return customer
