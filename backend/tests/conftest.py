import asyncio
import os
import uuid
from pathlib import Path
from typing import AsyncGenerator, Generator
from urllib.parse import urlparse, urlunparse
import pytest
import pytest_asyncio
from httpx import AsyncClient, ASGITransport
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.pool import NullPool

# Load environment variables from .env file
def _load_env_file():
    """Load variables from .env file into os.environ if .env exists."""
    env_file = Path(__file__).parent.parent / ".env"
    if env_file.exists():
        with open(env_file) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    key, value = line.split("=", 1)
                    key = key.strip()
                    value = value.strip().strip('"\'')
                    if key not in os.environ:
                        os.environ[key] = value

_load_env_file()

# 1. Import settings and override DATABASE_URL to test database BEFORE importing app modules
from app.core.config import settings

db_url = settings.DATABASE_URL
parsed = urlparse(db_url)
admin_db_url = urlunparse(parsed._replace(path="/postgres"))
test_db_url = urlunparse(parsed._replace(path="/ags_gold_test_db"))
settings.DATABASE_URL = test_db_url

# 2. Now import app modules
from app.main import app
from app.database.session import get_db_session
from app.database.base import Base
from app.database.seed import seed_data
from app.models.user import User
from app.models.role import Role
from app.models.permission import Permission
from app.core.security import create_access_token, get_password_hash

# Create the test engine with NullPool to avoid event loop mismatch on Windows
test_engine = create_async_engine(
    test_db_url,
    echo=False,
    poolclass=NullPool,
)

test_session_maker = async_sessionmaker(
    bind=test_engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False,
)


# --- Mock Session for Legacy Unit Tests ---
class MockAsyncSession:
    async def execute(self, *args, **kwargs):
        class MockResult:
            def scalars(self):
                class MockScalars:
                    def all(self):
                        return []

                    def first(self):
                        return None

                return MockScalars()

            def all(self):
                return []

        return MockResult()

    async def commit(self):
        pass

    async def rollback(self):
        pass

    async def close(self):
        pass

    async def get(self, *args, **kwargs):
        return None

    def add(self, *args, **kwargs):
        pass

    async def delete(self, *args, **kwargs):
        pass

    async def refresh(self, *args, **kwargs):
        pass


@pytest.fixture(scope="session")
def event_loop() -> Generator[asyncio.AbstractEventLoop, None, None]:
    """Create an instance of the default event loop for each test case."""
    try:
        loop = asyncio.get_running_loop()
    except RuntimeError:
        loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    yield loop
    loop.close()


@pytest_asyncio.fixture(scope="session", autouse=True)
async def setup_test_db() -> AsyncGenerator[None, None]:
    """Session-scoped fixture to automatically create and seed the test database."""
    # Connect to default postgres DB to check/create test DB
    admin_engine = create_async_engine(admin_db_url, isolation_level="AUTOCOMMIT")
    async with admin_engine.connect() as conn:
        result = await conn.execute(
            text("SELECT 1 FROM pg_database WHERE datname = 'ags_gold_test_db'")
        )
        exists = result.scalar() is not None
        if not exists:
            await conn.execute(text("CREATE DATABASE ags_gold_test_db"))
    await admin_engine.dispose()

    # Drop and recreate schema inside test DB
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)
        await conn.execute(
            text(
                "CREATE TABLE IF NOT EXISTS audit_logs_default PARTITION OF audit_logs DEFAULT"
            )
        )

    # Seed data
    async with test_session_maker() as session:
        await seed_data(session)

    yield

    # Clean up and dispose connections
    await test_engine.dispose()


# --- Real Database Session and Client for Integration/Security Tests ---
@pytest_asyncio.fixture
async def test_db() -> AsyncGenerator[AsyncSession, None]:
    """Fixture yielding a real async database session wrapped in a transaction that rolls back."""
    async with test_engine.connect() as connection:
        # Start outer transaction
        transaction = await connection.begin()

        # Create session bound to connection with savepoint support
        async with AsyncSession(
            bind=connection,
            expire_on_commit=False,
            join_transaction_mode="create_savepoint",
        ) as session:
            yield session
            # Rollback session changes
            await session.rollback()

        # Rollback outer transaction
        await transaction.rollback()


@pytest_asyncio.fixture
async def db_client(test_db: AsyncSession) -> AsyncGenerator[AsyncClient, None]:
    """Fixture yielding an AsyncClient configured to request against FastAPI using real test_db."""
    # Override database dependency injection to use the real transactional test database session
    app.dependency_overrides[get_db_session] = lambda: test_db

    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://testserver"
    ) as ac:
        yield ac

    app.dependency_overrides.clear()


# --- Legacy Mock Session and Client for backward compatibility ---
@pytest_asyncio.fixture
async def db_session() -> AsyncGenerator[AsyncSession, None]:
    """Fixture yielding a mock database session."""
    yield MockAsyncSession()  # type: ignore


@pytest_asyncio.fixture
async def client(db_session: AsyncSession) -> AsyncGenerator[AsyncClient, None]:
    """Fixture yielding an AsyncClient configured to request against FastAPI using mock db."""
    # Override database dependency injection to use the mock session
    app.dependency_overrides[get_db_session] = lambda: db_session

    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://testserver"
    ) as ac:
        yield ac

    app.dependency_overrides.clear()


# --- Authentication and Token Fixtures ---
@pytest.fixture
def jwt_token() -> Generator[callable, None, None]:
    """Fixture to generate valid JWT tokens."""

    def _generate(subject: str) -> str:
        return create_access_token(subject=subject)

    yield _generate


@pytest_asyncio.fixture
async def authenticated_user(
    test_db: AsyncSession,
) -> AsyncGenerator[tuple[User, dict[str, str]], None]:
    """Fixture that seeds a standard user and returns the user object and Authorization headers."""
    # Find or create standard user role
    role_result = await test_db.execute(select(Role).where(Role.name == "user"))
    role = role_result.scalars().first()
    if not role:
        role = Role(name="user", description="Standard user")
        test_db.add(role)
        await test_db.flush()

    user = User(
        email=f"user_{uuid.uuid4().hex[:6]}@example.com",
        hashed_password=get_password_hash("password123"),
        is_active=True,
        is_superuser=False,
        roles=[role],
    )
    test_db.add(user)
    await test_db.flush()

    token = create_access_token(subject=str(user.id))
    headers = {"Authorization": f"Bearer {token}"}

    yield user, headers


@pytest_asyncio.fixture
async def admin_user(
    test_db: AsyncSession,
) -> AsyncGenerator[tuple[User, dict[str, str]], None]:
    """Fixture that seeds a super admin user and returns the user object and Authorization headers."""
    # Find or create super admin role
    role_result = await test_db.execute(select(Role).where(Role.name == "super_admin"))
    role = role_result.scalars().first()
    if not role:
        role = Role(name="super_admin", description="Super Admin")
        test_db.add(role)
        await test_db.flush()

    user = User(
        email=f"admin_{uuid.uuid4().hex[:6]}@example.com",
        hashed_password=get_password_hash("password123"),
        is_active=True,
        is_superuser=True,
        roles=[role],
    )
    test_db.add(user)
    await test_db.flush()

    token = create_access_token(subject=str(user.id))
    headers = {"Authorization": f"Bearer {token}"}

    yield user, headers


ZOOM_TEST_ENV = True
