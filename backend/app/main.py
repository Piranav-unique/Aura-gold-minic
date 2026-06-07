from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.core.logging import setup_logging, logger
from app.core.exceptions import (
    AppException,
    app_exception_handler,
    general_exception_handler,
)
from app.middleware.logging_middleware import RequestLoggingMiddleware
from app.middleware.audit_middleware import AuditRequestContextMiddleware
from app.middleware.rate_limit_middleware import RateLimitMiddleware
from app.api.health import router as health_router
from app.api.auth import router as auth_router
from app.api.rbac import router as rbac_router
from app.api.user import router as user_router
from app.api.audit import router as audit_router
from app.database.session import verify_db_connection
from app.database import base as db_base  # noqa: F401


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    setup_logging()
    logger.info("app_startup", message="Initializing AGS Gold API services...")

    db_connected = await verify_db_connection()
    if db_connected:
        logger.info(
            "db_connection_success",
            message="Database connection verified successfully.",
        )
    else:
        logger.warning(
            "db_connection_failed",
            message="Could not connect to database on startup. Please verify credentials/server status.",
        )

    yield

    # Shutdown
    logger.info("app_shutdown", message="Shutting down AGS Gold API services...")


app = FastAPI(
    title=settings.PROJECT_NAME,
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    lifespan=lifespan,
)

# CORS configuration
cors_origins = settings.BACKEND_CORS_ORIGINS
allow_origin_regex = None

if settings.ENVIRONMENT == "development":
    # Allow any localhost or 127.0.0.1 port in development mode (e.g. Flutter Web)
    allow_origin_regex = r"https?://(localhost|127\.0\.0\.1)(:\d+)?"
    if not cors_origins:
        cors_origins = ["*"]

if cors_origins or allow_origin_regex:
    origins_list = (
        [str(origin).strip("/") for origin in cors_origins] if cors_origins else []
    )
    # Starlette requires allow_origins to not contain "*" when allow_origin_regex is used with credentials
    if allow_origin_regex and "*" in origins_list:
        origins_list.remove("*")

    app.add_middleware(
        CORSMiddleware,
        allow_origins=origins_list,
        allow_origin_regex=allow_origin_regex,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

# Logging & Request Context Middleware
app.add_middleware(RateLimitMiddleware)
app.add_middleware(RequestLoggingMiddleware)
app.add_middleware(AuditRequestContextMiddleware)

# Exception Handlers
app.add_exception_handler(AppException, app_exception_handler)
app.add_exception_handler(Exception, general_exception_handler)

# Routers
# Mount health check endpoint directly at /health
app.include_router(health_router)
app.include_router(auth_router, prefix=f"{settings.API_V1_STR}/auth", tags=["auth"])
app.include_router(rbac_router, prefix=f"{settings.API_V1_STR}/rbac", tags=["rbac"])
app.include_router(user_router, prefix=f"{settings.API_V1_STR}/users", tags=["users"])
app.include_router(
    audit_router, prefix=f"{settings.API_V1_STR}/audit-logs", tags=["audit-logs"]
)
