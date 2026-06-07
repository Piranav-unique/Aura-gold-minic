from fastapi import Request, status
from fastapi.responses import JSONResponse
from app.core.logging import logger


class AppException(Exception):
    """Base exception class for AGS Gold application."""

    def __init__(
        self, message: str, status_code: int = status.HTTP_500_INTERNAL_SERVER_ERROR
    ):
        super().__init__(message)
        self.message = message
        self.status_code = status_code


class DatabaseException(AppException):
    """Exception raised for database-related errors."""

    def __init__(self, message: str = "A database error occurred"):
        super().__init__(message, status_code=status.HTTP_500_INTERNAL_SERVER_ERROR)


class NotFoundException(AppException):
    """Exception raised when a resource is not found."""

    def __init__(self, message: str = "Resource not found"):
        super().__init__(message, status_code=status.HTTP_404_NOT_FOUND)


class AuthenticationException(AppException):
    """Exception raised when authentication fails."""

    def __init__(self, message: str = "Authentication failed"):
        super().__init__(message, status_code=status.HTTP_401_UNAUTHORIZED)


class ForbiddenException(AppException):
    """Exception raised when a user is not authorized to perform an action."""

    def __init__(self, message: str = "Permission denied"):
        super().__init__(message, status_code=status.HTTP_403_FORBIDDEN)


class ValidationException(AppException):
    """Exception raised when validation fails."""

    def __init__(self, message: str = "Validation failed"):
        super().__init__(message, status_code=status.HTTP_422_UNPROCESSABLE_CONTENT)


class RateLimitException(AppException):
    """Exception raised when a client exceeds rate limits."""

    def __init__(
        self, message: str = "Too many requests. Please try again later."
    ):
        super().__init__(message, status_code=status.HTTP_429_TOO_MANY_REQUESTS)


async def app_exception_handler(request: Request, exc: AppException) -> JSONResponse:
    logger.error(
        "application_error",
        path=request.url.path,
        error=str(exc),
        status_code=exc.status_code,
    )
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error": {
                "message": exc.message,
                "type": exc.__class__.__name__,
                "status_code": exc.status_code,
            }
        },
    )


async def general_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    logger.exception("unhandled_error", path=request.url.path, error=str(exc))
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "error": {
                "message": "An unexpected error occurred. Please try again later.",
                "type": "InternalServerError",
                "status_code": 500,
            }
        },
    )
