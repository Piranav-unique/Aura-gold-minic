from datetime import datetime, timedelta, timezone
from typing import Any, Union
from jose import jwt, JWTError
import bcrypt

from app.core.config import settings
from app.core.exceptions import AuthenticationException


import hashlib

def _pre_hash(password: str) -> bytes:
    """Pre-hash password using SHA-256 to handle bcrypt 72-byte limit."""
    return hashlib.sha256(password.encode("utf-8")).hexdigest().encode("utf-8")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a plain text password against a bcrypt hash."""
    try:
        return bcrypt.checkpw(
            _pre_hash(plain_password),
            hashed_password.encode("utf-8")
        )
    except Exception:
        return False


def get_password_hash(password: str) -> str:
    """Generate a bcrypt hash of the provided password."""
    salt = bcrypt.gensalt()
    return bcrypt.hashpw(_pre_hash(password), salt).decode("utf-8")


def create_access_token(subject: Any, expires_delta: Union[timedelta, None] = None) -> str:
    """Generate a JWT access token for a subject (user ID)."""
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(
            minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES
        )
    to_encode = {
        "exp": expire,
        "sub": str(subject),
        "type": "access"
    }
    return jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def create_refresh_token(
    subject: Any, jti: str, expires_delta: Union[timedelta, None] = None
) -> str:
    """Generate a JWT refresh token for a subject (user ID) with a unique JTI."""
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(
            minutes=settings.REFRESH_TOKEN_EXPIRE_MINUTES
        )
    to_encode = {
        "exp": expire,
        "sub": str(subject),
        "jti": jti,
        "type": "refresh"
    }
    return jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def decode_token(token: str) -> dict[str, Any]:
    """Decode a JWT and return its claims. Raises AuthenticationException if invalid."""
    try:
        payload = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM]
        )
        # Verify sub and type are present in payload
        if "sub" not in payload or "type" not in payload:
            raise AuthenticationException("Invalid token payload structure")
        return payload
    except jwt.ExpiredSignatureError:
        raise AuthenticationException("Token has expired")
    except JWTError:
        raise AuthenticationException("Could not validate credentials")
