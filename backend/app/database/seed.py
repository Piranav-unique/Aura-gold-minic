import asyncio

from sqlalchemy import inspect, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database.session import async_session_maker
from app.models.user import User
from app.models.role import Role
from app.models.permission import Permission
from app.models.workflow import WorkflowEscalationRule
from app.core.logging import logger, setup_logging


from app.core.security import get_password_hash


def hash_password(password: str) -> str:
    """Hash password using the application's central security utility."""
    return get_password_hash(password)


async def seed_data(session: AsyncSession) -> None:
    logger.info("database_seeding", message="Starting database seeding...")

    # 1. Define Permissions
    permissions_list = [
        {"name": "user:read", "description": "View user details"},
        {"name": "user:write", "description": "Create, update, or delete users"},
        {"name": "role:read", "description": "View roles"},
        {"name": "role:write", "description": "Manage roles and role mappings"},
        {"name": "audit_log:read", "description": "View system audit logs"},
        {"name": "user.view", "description": "View user details"},
        {"name": "user.create", "description": "Create new users"},
        {"name": "user.update", "description": "Update user details"},
        {"name": "user.delete", "description": "Delete users"},
        {"name": "audit.view", "description": "View system audit logs"},
        {"name": "customer.view", "description": "View customers"},
        {"name": "customer.create", "description": "Create customers"},
        {"name": "customer.update", "description": "Update customers"},
        {"name": "customer.delete", "description": "Delete customers"},
        {"name": "inventory.view", "description": "View inventory and suppliers"},
        {
            "name": "inventory.create",
            "description": "Create inventory items and suppliers",
        },
        {
            "name": "inventory.update",
            "description": "Update inventory and record stock movements",
        },
        {
            "name": "inventory.delete",
            "description": "Delete inventory items and suppliers",
        },
        {
            "name": "transaction.view",
            "description": "View transactions and revenue metrics",
        },
        {"name": "transaction.create", "description": "Create transactions"},
        {"name": "transaction.update", "description": "Update or cancel transactions"},
        {"name": "report.view", "description": "View reports and analytics"},
        {
            "name": "report.export",
            "description": "Export reports as CSV, Excel, or PDF",
        },
        {"name": "dashboard.view", "description": "View executive dashboard and stats"},
        {"name": "workflow.view", "description": "View workflow and approval requests"},
        {
            "name": "workflow.create",
            "description": "Create and submit workflow requests",
        },
        {
            "name": "workflow.approve",
            "description": "Approve, reject, and assign workflow requests",
        },
        {"name": "workflow.manage", "description": "Manage workflow escalation rules"},
    ]

    db_permissions = {}
    for perm_data in permissions_list:
        query = select(Permission).where(Permission.name == perm_data["name"])
        result = await session.execute(query)
        perm = result.scalars().first()
        if not perm:
            perm = Permission(**perm_data)
            session.add(perm)
            logger.info("permission_created", name=perm_data["name"])
        db_permissions[perm_data["name"]] = perm

    await session.flush()

    # 2. Define Roles
    roles_list = [
        {
            "name": "super_admin",
            "description": "Full system access permissions",
            "permissions": [],
        },
        {
            "name": "admin",
            "description": "Administrative access permissions",
            "permissions": [],
        },
        {
            "name": "user",
            "description": "Standard user access permissions",
            "permissions": [],
        },
        {
            "name": "manager",
            "description": "Team oversight and approval workflows",
            "permissions": [],
        },
        {
            "name": "employee",
            "description": "Day-to-day operational access",
            "permissions": [],
        },
    ]

    db_roles = {}
    for role_data in roles_list:
        query = (
            select(Role)
            .where(Role.name == role_data["name"])
            .options(selectinload(Role.permissions))
        )
        result = await session.execute(query)
        role = result.scalars().first()
        if not role:
            role = Role(**role_data)
            session.add(role)
            logger.info("role_created", name=role_data["name"])
        db_roles[role_data["name"]] = role

    await session.flush()

    # 3. Associate Permissions to Roles
    super_admin_role = db_roles["super_admin"]
    for perm in db_permissions.values():
        if perm not in super_admin_role.permissions:
            super_admin_role.permissions.append(perm)

    admin_role = db_roles["admin"]
    for perm_name in [
        "user.view",
        "role:read",
        "audit.view",
        "user:read",
        "role:read",
        "audit_log:read",
        "customer.view",
        "customer.create",
        "customer.update",
        "customer.delete",
        "inventory.view",
        "inventory.create",
        "inventory.update",
        "inventory.delete",
        "transaction.view",
        "transaction.create",
        "transaction.update",
        "report.view",
        "report.export",
        "dashboard.view",
        "workflow.view",
        "workflow.create",
        "workflow.approve",
        "workflow.manage",
    ]:
        perm = db_permissions[perm_name]
        if perm not in admin_role.permissions:
            admin_role.permissions.append(perm)

    user_role = db_roles["user"]
    for perm_name in ["user.view", "user:read", "dashboard.view"]:
        perm = db_permissions[perm_name]
        if perm not in user_role.permissions:
            user_role.permissions.append(perm)

    manager_role = db_roles["manager"]
    for perm_name in [
        "user.view",
        "audit.view",
        "customer.view",
        "inventory.view",
        "transaction.view",
        "workflow.view",
        "workflow.approve",
        "report.view",
        "dashboard.view",
    ]:
        perm = db_permissions[perm_name]
        if perm not in manager_role.permissions:
            manager_role.permissions.append(perm)

    employee_role = db_roles["employee"]
    for perm_name in [
        "user.view",
        "workflow.view",
        "workflow.create",
        "inventory.view",
        "customer.view",
        "dashboard.view",
    ]:
        perm = db_permissions[perm_name]
        if perm not in employee_role.permissions:
            employee_role.permissions.append(perm)

    # 4. Create Default Super Admin User
    import os

    admin_email = "superadmin@agsgold.com"
    admin_password = os.getenv("SUPERADMIN_PASSWORD", "adminpassword")
    hashed_pw = hash_password(admin_password)

    query = (
        select(User).where(User.email == admin_email).options(selectinload(User.roles))
    )
    result = await session.execute(query)
    admin_user = result.scalars().first()

    if not admin_user:
        admin_user = User(
            email=admin_email,
            hashed_password=hashed_pw,
            is_active=True,
            is_superuser=True,
            first_name="Super",
            last_name="Admin",
            roles=[],
        )
        admin_user.roles.append(super_admin_role)
        session.add(admin_user)
        logger.info("super_admin_user_created", email=admin_email)
    else:
        admin_user.hashed_password = hashed_pw
        admin_user.is_active = True
        admin_user.is_superuser = True
        if super_admin_role not in admin_user.roles:
            admin_user.roles.append(super_admin_role)
        logger.info("super_admin_user_updated", email=admin_email)

    conn = await session.connection()

    def _has_workflow_tables(sync_conn) -> bool:
        inspector = inspect(sync_conn)
        return inspector.has_table("workflow_escalation_rules")

    if await conn.run_sync(_has_workflow_tables):
        default_rule = await session.execute(
            select(WorkflowEscalationRule).where(
                WorkflowEscalationRule.name == "Default 24h escalation"
            )
        )
        if not default_rule.scalars().first():
            session.add(
                WorkflowEscalationRule(
                    name="Default 24h escalation",
                    request_type="*",
                    hours_until_escalation=24,
                    target_permission="workflow.manage",
                    escalation_level=0,
                    is_active=True,
                )
            )
            logger.info(
                "workflow_escalation_rule_created", name="Default 24h escalation"
            )
    else:
        logger.warning(
            "workflow_escalation_rule_skipped",
            message=(
                "workflow_escalation_rules table not found. "
                "Run `python -m alembic upgrade head` then re-run seed."
            ),
        )

    await session.commit()
    logger.info(
        "database_seeding_complete", message="Database seeding completed successfully."
    )


async def main():
    setup_logging()
    async with async_session_maker() as session:
        await seed_data(session)


if __name__ == "__main__":
    asyncio.run(main())
