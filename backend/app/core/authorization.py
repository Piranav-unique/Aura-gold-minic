from functools import wraps
import re
from typing import Any, Callable
from fastapi import Depends

from app.core.exceptions import AuthenticationException, ForbiddenException
from app.models.user import User
from app.api.dependencies import get_current_user

SPLIT_REGEX = re.compile(r"[:.]")


class PermissionChecker:
    """FastAPI dependency to verify a user has a specific permission."""

    def __init__(self, permission_name: str):
        self.permission_name = permission_name

    def __call__(self, current_user: User = Depends(get_current_user)) -> User:
        if current_user.is_superuser:
            return current_user

        req_parts = SPLIT_REGEX.split(self.permission_name)

        # User's roles -> permissions check
        for role in current_user.roles:
            for perm in role.permissions:
                if perm.name == self.permission_name:
                    return current_user

                # Wildcard check (e.g. "user:*" matches "user:create")
                perm_parts = SPLIT_REGEX.split(perm.name)
                if (
                    len(perm_parts) == 2
                    and perm_parts[1] == "*"
                    and len(req_parts) > 0
                    and perm_parts[0] == req_parts[0]
                ):
                    return current_user

        raise ForbiddenException(
            message=f"Permission '{self.permission_name}' is required"
        )


def require_permission(permission_name: str) -> Callable:
    """Route decorator verifying that the current authenticated user has a specific permission.

    Note: The decorated endpoint MUST include 'current_user: User = Depends(get_current_user)'
    in its arguments list so the decorator can extract the user object.
    """

    def decorator(func: Callable) -> Callable:
        @wraps(func)
        async def wrapper(*args: Any, **kwargs: Any) -> Any:
            # Look for current_user in keyword arguments
            current_user = kwargs.get("current_user")

            # Fallback scan of kwargs values in case it is injected under a different variable name
            if not current_user:
                for val in kwargs.values():
                    if isinstance(val, User):
                        current_user = val
                        break

            if not current_user:
                # Developer mismatch warning
                import inspect
                sig = inspect.signature(func)
                if "current_user" not in sig.parameters:
                    raise RuntimeError(
                        f"Developer Error: Endpoint '{func.__name__}' decorated with "
                        f"@require_permission must declare a 'current_user: User' parameter."
                    )
                raise AuthenticationException(
                    message="Authentication required for this operation"
                )

            # Eager check for superuser bypass
            if current_user.is_superuser:
                return await func(*args, **kwargs)

            # Check permissions with wildcard support
            has_permission = False
            req_parts = SPLIT_REGEX.split(permission_name)
            for role in current_user.roles:
                for perm in role.permissions:
                    if perm.name == permission_name:
                        has_permission = True
                        break

                    perm_parts = SPLIT_REGEX.split(perm.name)
                    if (
                        len(perm_parts) == 2
                        and perm_parts[1] == "*"
                        and len(req_parts) > 0
                        and perm_parts[0] == req_parts[0]
                    ):
                        has_permission = True
                        break
                if has_permission:
                    break

            if not has_permission:
                raise ForbiddenException(
                    message=f"Permission '{permission_name}' is required"
                )

            return await func(*args, **kwargs)

        return wrapper

    return decorator
