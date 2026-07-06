import json
import os
from pathlib import Path
from typing import Any, List, Union
from pydantic import field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

_BACKEND_ROOT = Path(__file__).resolve().parents[2]
_ON_RAILWAY = bool(os.getenv("RAILWAY_ENVIRONMENT") or os.getenv("RAILWAY_PROJECT_ID"))


def normalize_database_url(url: str) -> str:
    """Railway/Heroku provide postgresql:// — SQLAlchemy async needs postgresql+asyncpg://."""
    if not url:
        return url
    if url.startswith("postgres://"):
        url = "postgresql://" + url[len("postgres://") :]
    if url.startswith("postgresql://") and "+asyncpg" not in url.split("://", 1)[0]:
        url = url.replace("postgresql://", "postgresql+asyncpg://", 1)
    return url


def database_connect_args(url: str) -> dict:
    """Railway public Postgres endpoints require TLS; private *.railway.internal does not."""
    from urllib.parse import urlparse

    host = (urlparse(url).hostname or "").lower()
    if host.endswith(".railway.internal"):
        return {}
    if any(
        marker in host
        for marker in (".rlwy.net", "railway.app", "amazonaws.com", "neon.tech")
    ):
        return {"ssl": True}
    return {}


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        # Load shipped .env for API keys etc.; Railway injects DATABASE_URL via os.environ.
        env_file=_BACKEND_ROOT / ".env" if (_BACKEND_ROOT / ".env").exists() else None,
        env_ignore_empty=True,
        extra="ignore",
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

    # Sandbox KYC (Aadhaar OTP + PAN linking) — set in .env, never commit secrets
    SANDBOX_API_KEY: str = ""
    SANDBOX_API_SECRET: str = ""
    SANDBOX_BASE_URL: str = "https://api.sandbox.co.in"
    SANDBOX_API_VERSION: str = "1.0.0"
    KYC_VERIFICATION_REASON: str = "AURUM gold trading KYC verification"

    # Live metal price providers (set in .env — never commit real keys)
    API_NINJAS_KEY: str = ""
    API_NINJAS_BASE_URL: str = "https://api.api-ninjas.com/v1"
    COMMODITY_PRICE_API_KEY: str = ""
    COMMODITY_PRICE_API_BASE_URL: str = "https://api.commoditypriceapi.com/v2"
    GOLDAPI_KEY: str = ""
    # Gold Price API dashboard keys (hex) use https://api.gold-api.com; legacy keys use goldapi.io
    GOLD_API_BASE_URL: str = "https://api.gold-api.com"
    METALPRICEAPI_KEY: str = ""
    METALPRICEAPI_BASE_URL: str = "https://api.metalpriceapi.com"
    METAL_PRICES_CACHE_TTL_SECONDS: int = 60
    METAL_HISTORY_CACHE_TTL_SECONDS: int = 21600

    # India customer buy-rate (GoldAPI spot + GST + platform spread — like digital gold apps)
    METAL_GOLD_BUY_SPREAD_PERCENT: float = 14.5
    METAL_SILVER_BUY_SPREAD_PERCENT: float = 12.0
    METAL_GOLD_IMPORT_DUTY_PERCENT: float = 6.0
    METAL_GOLD_GST_PERCENT: float = 3.0
    METAL_SILVER_IMPORT_DUTY_PERCENT: float = 10.0
    METAL_SILVER_GST_PERCENT: float = 3.0
    METAL_TN_JEWELLER_PREMIUM_PERCENT: float = 1.25
    # SLN Bullion (slnbullion.in) GOLD CBE 9999 T+1 parity on international INR/gram
    METAL_GOLD_TN_BULLION_MARKUP_PERCENT: float = 19.2
    # SLN Chennai silver T+1 (₹/kg) parity on international INR/gram
    METAL_SILVER_TN_BULLION_MARKUP_PERCENT: float = 28.6

    # Sell payout (bullion rate minus spread; platform fee on gross)
    METAL_GOLD_SELL_SPREAD_PERCENT: float = 2.0
    METAL_SILVER_SELL_SPREAD_PERCENT: float = 2.0
    SELL_PLATFORM_CHARGE_PERCENT: float = 0.5
    SELL_TAX_PERCENT: float = 18.0

    # Signup SMS OTP (MSG91 v5 OTP template — AurumGoldSilvers_OTP_v2)
    MSG91_AUTH_KEY: str = ""
    MSG91_OTP_URL: str = "https://control.msg91.com/api/v5/otp"
    MSG91_OTP_TEMPLATE_ID: str = "6a3a73a1a51ea2ee050db8b6"
    # Flow API uses a different ID than OTP API — copy from MSG91 → Templates (not SendOTP)
    MSG91_FLOW_ID: str = ""
    MSG91_SEND_URL: str = "https://api.msg91.com/api/sendhttp.php"
    # Comma-separated fallback order: otp, flow, sendotp, sendhttp
    MSG91_SMS_CHANNELS: str = "otp"
    MSG91_DLT_TE_ID: str = ""
    MSG91_DLT_TEMPLATE_ID: str = ""
    SMS_SENDER_ID: str = "AURUS"
    SMS_ROUTE: str = "4"
    SIGNUP_OTP_LENGTH: int = 6
    SIGNUP_OTP_EXPIRE_MINUTES: int = 10
    SIGNUP_OTP_MAX_ATTEMPTS: int = 5
    SIGNUP_OTP_MAX_SENDS_PER_HOUR: int = 10
    SIGNUP_OTP_MIN_RESEND_SECONDS: int = 60
    SIGNUP_OTP_SEND_COOLDOWN_HOURS: int = 1
    SIGNUP_OTP_USE_MSG91_VERIFY: bool = True
    SIGNUP_OTP_DEV_CODE: str = "123456"

    # Bank link OTP (MSG91 Flow only — Aurum_Bank_Add_OTP, DLT 1207178235534667442).
    # Do NOT use the v5 /otp API for this template (MSG91 error 400).
    MSG91_BANK_OTP_TEMPLATE_ID: str = "6a4a7eae9fe09e57d9000643"
    MSG91_BANK_DLT_TEMPLATE_ID: str = "1207178235534667442"
    MSG91_BANK_FLOW_ID: str = "6a4a7eae9fe09e57d9000643"
    MSG91_BANK_OTP_LENGTH: int = 6
    MSG91_BANK_OTP_USE_MSG91_VERIFY: bool = False
    MSG91_BANK_SMS_CHANNELS: str = "flow,sendhttp"
    # Local dev: use SIGNUP_OTP_DEV_CODE for bank link (skip MSG91 bank Flow SMS).
    BANK_OTP_DEV_MODE: bool = True

    # Android in-app update (public APK URL + version; bump when publishing a new APK)
    APP_ANDROID_VERSION_NAME: str = ""
    APP_ANDROID_VERSION_CODE: int = 0
    APP_ANDROID_APK_URL: str = ""
    APP_ANDROID_RELEASE_NOTES: str = ""
    APP_ANDROID_FORCE_UPDATE: bool = False

    # Razorpay — set in .env, never commit secrets
    RAZORPAY_KEY_ID: str = ""
    RAZORPAY_KEY_SECRET: str = ""
    RAZORPAY_WEBHOOK_SECRET: str = ""
    RAZORPAY_CURRENCY: str = "INR"
    # Domestic card/UPI fee estimate used for merchant settlement ledger (2% + 18% GST on fee).
    RAZORPAY_PLATFORM_FEE_PERCENT: float = 2.0
    RAZORPAY_PLATFORM_FEE_GST_PERCENT: float = 18.0
    # When true (default in development), simulate checkout if Razorpay keys are unset
    PAYMENT_DEV_MOCK: bool = True
    # RazorpayX — merchant ledger account for sell payouts (from RazorpayX dashboard)
    RAZORPAYX_ACCOUNT_NUMBER: str = ""
    RAZORPAYX_PAYOUT_MODE: str = "IMPS"

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
        env_url = os.getenv("DATABASE_URL", "").strip()
        on_railway = _ON_RAILWAY

        if env_url:
            self.DATABASE_URL = normalize_database_url(env_url)
        elif on_railway:
            raise ValueError(
                "DATABASE_URL is required on Railway. Add PostgreSQL, then in API "
                "service Variables set DATABASE_URL as a reference to Postgres."
            )
        elif self.DATABASE_URL:
            self.DATABASE_URL = normalize_database_url(self.DATABASE_URL)
        else:
            self.DATABASE_URL = (
                f"postgresql+asyncpg://{self.POSTGRES_USER}:{self.POSTGRES_PASSWORD}"
                f"@{self.POSTGRES_SERVER}:{self.POSTGRES_PORT}/{self.POSTGRES_DB}"
            )

        # Enforce production security constraints
        if self.ENVIRONMENT == "production":
            if self.SECRET_KEY == "secret-key-change-me":
                raise ValueError("SECRET_KEY must be overridden in production mode!")
            if (
                not self.DATABASE_URL
                and self.POSTGRES_PASSWORD == "password123"
            ):
                raise ValueError(
                    "POSTGRES_PASSWORD must be overridden in production mode!"
                )
            if self.TRUSTED_PROXY is False:
                self.TRUSTED_PROXY = True

        return self

    def bank_otp_uses_dev_code(self) -> bool:
        return (
            self.BANK_OTP_DEV_MODE
            and self.ENVIRONMENT == "development"
            and bool(self.SIGNUP_OTP_DEV_CODE.strip())
        )


settings = Settings()
