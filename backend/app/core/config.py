import json
from typing import Any, List, Union
from pydantic import field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env", env_ignore_empty=True, extra="ignore"
    )

    ENVIRONMENT: str = "development"
    PROJECT_NAME: str = "AGS Gold API"
    API_V1_STR: str = "/api/v1"

    SECRET_KEY: str = "secret-key-change-me"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    REFRESH_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 days

    RATE_LIMIT_LOGIN_MAX: int = 5
    RATE_LIMIT_LOGIN_WINDOW_SECONDS: int = 60
    RATE_LIMIT_PROFILE_MAX: int = 10
    RATE_LIMIT_PROFILE_WINDOW_SECONDS: int = 300

    TRUSTED_PROXY: bool = False
    AVATAR_MAX_BYTES: int = 262_144  # 256 KB
    DASHBOARD_CACHE_TTL_SECONDS: int = 30
    INVENTORY_METRICS_CACHE_TTL_SECONDS: int = 30
    NOTIFICATION_LOGIN_COOLDOWN_MINUTES: int = 60
    NOTIFICATION_LOW_STOCK_COOLDOWN_MINUTES: int = 240
    AUDIT_EXPORT_MAX_ROWS: int = 5000
    REPORT_EXPORT_MAX_ROWS: int = 5000
    REPORT_ANALYTICS_CACHE_TTL_SECONDS: int = 30

    # CORS Origins
    BACKEND_CORS_ORIGINS: Union[List[str], str] = []

    @field_validator("BACKEND_CORS_ORIGINS", mode="before")
    @classmethod
    def assemble_cors_origins(cls, v: Any) -> Union[List[str], str]:
        if isinstance(v, str) and not v.startswith("["):
            return [i.strip() for i in v.split(",")]
        elif isinstance(v, (list, str)):
            if isinstance(v, str):
                try:
                    return json.loads(v)
                except Exception:
                    return [v]
            return v
        return []

    # Database Settings
    POSTGRES_SERVER: str = "localhost"
    POSTGRES_USER: str = "postgres"
    POSTGRES_PASSWORD: str = "password123"
    POSTGRES_DB: str = "ags_gold_db"
    POSTGRES_PORT: int = 5432

    DATABASE_URL: str = ""

    @model_validator(mode="after")
    def assemble_db_url(self) -> "Settings":
        if not self.DATABASE_URL:
            self.DATABASE_URL = f"postgresql+asyncpg://{self.POSTGRES_USER}:{self.POSTGRES_PASSWORD}@{self.POSTGRES_SERVER}:{self.POSTGRES_PORT}/{self.POSTGRES_DB}"

        # Enforce production security constraints
        if self.ENVIRONMENT == "production":
            if self.SECRET_KEY == "secret-key-change-me":
                raise ValueError("SECRET_KEY must be overridden in production mode!")
            if self.POSTGRES_PASSWORD == "password123":
                raise ValueError(
                    "POSTGRES_PASSWORD must be overridden in production mode!"
                )

        return self


settings = Settings()
