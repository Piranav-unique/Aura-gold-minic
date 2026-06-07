# Import all database models so Alembic can discover them
from app.models.base import Base  # noqa: F401
from app.models.associations import user_roles, role_permissions  # noqa: F401
from app.models.user import User  # noqa: F401
from app.models.role import Role  # noqa: F401
from app.models.permission import Permission  # noqa: F401
from app.models.audit_log import AuditLog  # noqa: F401
from app.models.token_blacklist import TokenBlacklist  # noqa: F401
