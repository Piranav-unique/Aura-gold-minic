# AGS Gold — Aurum Gold & Silvers

AGS Gold is a digital gold and silver savings platform for **Aurum Gold & Silvers**. The repository contains:

- **`backend/`**: a FastAPI (Python, async SQLAlchemy 2.0) REST API on PostgreSQL, with Alembic migrations.
- **`frontend/`**: a Flutter app (Riverpod + GoRouter). It is one codebase that serves both the customer app and the admin / back-office console.
- **`.github/workflows/`**: CI pipelines for the backend and the Flutter app, plus automated Android APK releases.

The production API is served at `https://api.aurumgold.co.in/api/v1` behind a Cloudflare Tunnel. This is the default `hostedApiBaseUrl` in `frontend/lib/config/env_config.dart`.

---

## Contents

- [Customer app features](#customer-app-features)
- [Admin and back-office features](#admin-and-back-office-features)
- [Tech stack](#tech-stack)
- [External integrations](#external-integrations)
- [Repository structure](#repository-structure)
- [API overview](#api-overview)
- [Getting started](#getting-started)
- [Configuration](#configuration)
- [Testing](#testing)
- [CI/CD](#cicd)
- [Roles and permissions](#roles-and-permissions)

---

## Customer app features

| Area | Route(s) | What it does |
| :--- | :--- | :--- |
| **Sign up / login** | `/login`, `/signup` | Mobile-number OTP signup and login over SMS (MSG91). Each account is bound to the device it registered on (`backend/app/utils/device_binding.py`). Trusted-device login is supported (`/auth/login/mobile/trusted`). |
| **Home dashboard** | `/user-dashboard` | Portfolio value, live gold and silver price cards, quick-buy chips (₹50 / ₹100 / ₹250 / ₹500 / ₹1,000 / ₹2,000), savings-scheme progress, recent transactions, and KYC prompts. |
| **Live prices and charts** | `/live-price` | Live gold and silver rates with a Tamil Nadu retail breakdown and historical charts over selectable ranges. |
| **Buy gold / silver** | `/buy-gold` | Buy by **amount (₹)** or by **grams** (`purchase_mode: amount \| grams`). Checkout runs through Razorpay. A PDF tax invoice is generated and can be emailed. |
| **Sell gold** | `/sell-gold`, `/sell-gold-inquiry` | Customers create a sell inquiry against a linked bank account. An admin approves or rejects it, and approved payouts are sent through RazorpayX. |
| **Savings schemes** | `/my-savings` | Goal-based gold schemes with **1 g, 5 g and 10 g** targets. Customers can select or upgrade a scheme and track progress to completion. |
| **Refer & earn** | `/refer-and-earn` | Plan-specific referral codes. The referrer is rewarded once the referee's first qualifying purchase completes (see the table below). |
| **Portfolio and history** | `/portfolio`, `/user-transactions` | Holdings, invested amount, market-linked value, and a combined buy/sell/wallet activity history. |
| **Bank accounts** | `/bank-accounts`, `/bank-accounts/add` | Add payout accounts with IFSC lookup (Razorpay IFSC) and OTP verification over SMS. |
| **KYC** | `/kyc` | Aadhaar OTP verification and a PAN–Aadhaar link check through Sandbox.co.in. Trading is gated on KYC status (`kyc_trading_gate.dart`). |
| **Profile and settings** | `/profile`, `/settings` | Profile, avatar, nominee details, theme mode, English / **Tamil (தமிழ்)** language, biometric app lock, and account deletion requests. |
| **Notifications** | `/notifications` | In-app notifications with unread counts. |
| **Legal** | `/privacy-policy`, `/terms-and-conditions` | Privacy policy and Digi-Gold terms. The backend also serves the privacy policy and a signup landing page as HTML. |
| **In-app updates** | — | On Android, the app checks `/api/v1/app/android-release` for a newer APK and installs it with `ota_update`. |
| **Device security** | — | Rooted devices are detected through a native method channel (`MainActivity.kt`) and blocked by `security_guard.dart`. |

### Referral rewards

Defined in `backend/app/schemas/referral.py`:

| Scheme | Referrer reward | Referee's minimum first purchase |
| :---: | :---: | :---: |
| 1 g | ₹150 | ₹100 |
| 5 g | ₹350 | ₹1,000 |
| 10 g | ₹550 | ₹2,000 |

### Pricing

`backend/app/services/metal_prices.py` builds customer prices from international spot rates. Every percentage below is a setting in `backend/app/core/config.py` and can be overridden from the environment:

- Import duty and GST: gold 6% + 3%, silver 10% + 3%.
- Tamil Nadu bullion parity markup and jeweller premium.
- A buy spread, plus a sell spread, platform charge and tax that apply to sell payouts.
- Spot prices come from Gold-API / GoldAPI, then Metal Price API, API Ninjas and CommodityPriceAPI as fallbacks. If no provider key is configured, the service uses simulated history.

---

## Admin and back-office features

Admin screens live in `frontend/lib/features/admin/` and the related feature folders. Every screen is guarded by permission checks (`permission_gate.dart`).

| Area | Route(s) | What it does |
| :--- | :--- | :--- |
| **Executive dashboard** | `/dashboard` | Role-based KPI views for admin, manager and employee. |
| **Sell inquiries** | `/admin/sell-inquiries`, `/admin/sell-inquiries/:id` | Review customer sell requests and approve them (with a RazorpayX payout) or reject them. |
| **User wallets** | `/admin/user-wallets`, `/admin/user-wallets/:userId/transactions` | Search customers by name, mobile, email or masked KYC. Shows balances and a unified transaction ledger. |
| **Payment settlements** | `/admin/payment-settlements` | Razorpay order reconciliation and settlement ledger, with a bulk sync from Razorpay. |
| **Digital metal inventory** | `/admin/metal-inventory` | Gold and silver stock pools: restock, reserved quantity, movement history, and low-stock alerts. Customers can subscribe to back-in-stock notifications. |
| **Physical inventory and suppliers** | `/inventory`, `/suppliers` | Inventory items, stock movements, and supplier management. |
| **Customers** | `/customers` | Customer directory with create, read, update and delete. |
| **Transactions** | `/transactions` | Back-office transaction records and wallet transaction detail. |
| **Workflows** | `/workflows` | Approval workflows with escalation rules. |
| **Reports** | `/reports` | Analytics with export to CSV, Excel (`openpyxl`) and PDF (`reportlab`). |
| **Audit logs** | `/audit-logs` | Request-level audit trail stored in a partitioned PostgreSQL table, with CSV export. |
| **Users, roles and permissions** | `/admin/users`, `/admin/roles`, `/admin/permissions` | RBAC management. |
| **Account deletions** | `/admin/account-deletions`, `/admin/deleted-users` | Approve or reject customer deletion requests and view soft-deleted accounts. |
| **Organization profile** | `/admin/profile` | Company details attached to sell inquiries and exposed through the public organization-profile endpoint. |
| **Admin 2FA** | — | TOTP-based two-factor authentication for admins (`pyotp`). |

---

## Tech stack

**Backend** (`backend/requirements.txt`)
- FastAPI and Uvicorn
- SQLAlchemy 2.0 (async) with `asyncpg`, and Alembic for migrations
- Pydantic v2 and `pydantic-settings`
- `python-jose` (JWT), `passlib[bcrypt]`, `pyotp` (TOTP)
- `structlog` for structured logging
- `reportlab` for PDF invoices and `openpyxl` for Excel exports
- pytest, `pytest-asyncio`, `pytest-cov` and `httpx` for tests
- Ruff for linting and formatting (configured in the root `pyproject.toml`)

**Middleware** (`backend/app/middleware/`): security headers, rate limiting (login, OTP, profile and auth attempts), request logging, and audit request context. When `TRUSTED_PROXY` is enabled, client IPs are read from the Cloudflare `CF-Connecting-IP` header (`app/core/client_ip.py`).

**Frontend** (`frontend/pubspec.yaml`, version `0.1.9+25`)
- Flutter (Dart SDK `^3.12.1`)
- `flutter_riverpod` for state, `go_router` for routing, `dio` for HTTP
- `flutter_secure_storage`, `shared_preferences`, `local_auth` (biometrics)
- `razorpay_flutter`, `image_picker`, `package_info_plus`, `ota_update`
- Localization through `flutter_localizations` and ARB files (`lib/l10n/app_en.arb`, `lib/l10n/app_ta.arb`)
- `mocktail` and `http_mock_adapter` for tests

**Platforms:** Android (primary), plus generated iOS, Web, Windows, macOS and Linux runners.

---

## External integrations

| Service | Used for | Code |
| :--- | :--- | :--- |
| Razorpay | Buy checkout, payment verification, webhooks | `services/razorpay_client.py`, `api/razorpay_webhooks.py` |
| RazorpayX | Bank payouts for approved sell inquiries | `services/razorpayx_client.py`, `services/sell_razorpayx_payout.py` |
| Razorpay IFSC | Bank and branch lookup | `services/ifsc.py` |
| MSG91 (DLT sender `AURUS`) | Signup/login OTP and bank-link OTP over SMS | `services/sms.py`, `services/signup_otp.py` |
| Sandbox.co.in | Aadhaar OTP and PAN–Aadhaar link verification | `services/sandbox_kyc.py`, `services/kyc.py` |
| Gold-API / GoldAPI, Metal Price API, API Ninjas, CommodityPriceAPI | Live and historical spot prices | `services/metal_prices.py` |
| SMTP (Brevo by default) | Invoice and transactional email | `services/email_service.py`, `core/email_utils.py` |

---

## Repository structure

```text
Aura-gold-minic/
├── .github/workflows/
│   ├── backend.yml            # Lint → unit/API, integration, security → E2E → coverage → Docker build → smoke
│   ├── flutter.yml            # Analyze → unit, widget → integration/E2E/security → APK + web builds
│   └── release-apk.yml        # Builds the release APK and publishes a GitHub Release (tag v<version>)
├── backend/
│   ├── alembic/versions/      # 40 migration files
│   ├── app/
│   │   ├── api/               # 29 routers (auth, payments, sell_inquiries, referrals, admin_*, …)
│   │   ├── core/              # config, security/JWT, permissions, KYC crypto, client IP, logging
│   │   ├── database/          # session, seed, reset, clear_consumer_users
│   │   ├── middleware/        # security headers, rate limit, logging, audit context
│   │   ├── models/            # SQLAlchemy models (users, payment orders, sell inquiries, inventory, …)
│   │   ├── repositories/      # data-access layer
│   │   ├── schemas/           # Pydantic request/response models
│   │   ├── services/          # business logic and third-party clients
│   │   ├── utils/             # device binding, mobile normalisation, report export
│   │   ├── assets/ static/    # logo and invoice letterhead
│   │   └── main.py            # app factory, middleware, router registration
│   ├── scripts/               # run_local.ps1, KYC debug/fix helpers, metal price check
│   ├── tests/                 # unit, api, integration, security, e2e, smoke
│   ├── Dockerfile             # multi-stage, non-root image (Python 3.11)
│   ├── docker-compose.yml     # Postgres 15 (host port 5435) + API (host port 8001)
│   ├── entrypoint.sh          # alembic upgrade head → uvicorn
│   └── .env.example
├── frontend/
│   ├── lib/
│   │   ├── config/            # EnvConfig (dev / prod, API_BASE_URL, API_HOST)
│   │   ├── core/              # theme, widgets, navigation, auth helpers, logging
│   │   ├── features/          # admin, app_update, audit_logs, auth, customers, dashboard,
│   │   │                      # inventory, legal, notifications, profile, referral, reports,
│   │   │                      # settings, splash, transactions, user_dashboard, workflows
│   │   ├── l10n/              # English + Tamil localizations
│   │   ├── routes/            # GoRouter config and redirects
│   │   ├── services/          # API client, secure storage, biometrics, security, Razorpay
│   │   └── main.dart
│   ├── test/                  # unit, widget, integration, e2e, security
│   ├── android/ ios/ web/ windows/ macos/ linux/
│   ├── run.ps1                # run on a device against a local or cloud API
│   ├── build_apk.ps1          # release APK pointed at the hosted API
│   └── build_aab.ps1          # Play Store bundle
├── docs/                      # CA ownership certificate generator (python-docx)
└── pyproject.toml             # Ruff configuration
```

---

## API overview

All routers are mounted under `/api/v1` (`API_V1_STR`), except `/health` and the legal HTML pages. Interactive docs are served at `/docs`, and the OpenAPI schema at `/api/v1/openapi.json`.

| Prefix | Purpose |
| :--- | :--- |
| `/health` | Liveness check |
| `/api/v1/auth` | Password login, mobile OTP login/signup, refresh, logout, `/me` |
| `/api/v1/profile` | Profile, avatar, settings, KYC (Aadhaar OTP, PAN), account deletion, activity |
| `/api/v1/dashboard` | Personal dashboard, live prices, price history, executive dashboard |
| `/api/v1/payments` | Razorpay order/verify/sync, invoices (PDF and email), settlements, stock subscriptions |
| `/api/v1/sell-inquiries` | Create and list sell inquiries; admin approve/reject |
| `/api/v1/gold-scheme` | Select or upgrade a 1 g / 5 g / 10 g scheme |
| `/api/v1/referrals` | Referral summary and codes |
| `/api/v1/bank-accounts` | Bank accounts, OTP verification, IFSC lookup |
| `/api/v1/notifications` | Notifications and unread count |
| `/api/v1/app` | Android app release info for in-app updates |
| `/api/v1/organization-profile` | Public organization details |
| `/api/v1/webhooks` | Razorpay webhooks |
| `/api/v1/admin/wallets` | Admin wallet search, ledgers, customer removal |
| `/api/v1/admin/inventory` | Digital gold and silver stock pools |
| `/api/v1/admin/organization-profile` | Edit organization details |
| `/api/v1/admin/account-deletion-requests` | Review deletion requests |
| `/api/v1/admin/2fa` | Admin TOTP setup, enable, disable, verify |
| `/api/v1/users`, `/api/v1/rbac` | User and role/permission management |
| `/api/v1/customers`, `/api/v1/inventory`, `/api/v1/suppliers`, `/api/v1/transactions`, `/api/v1/workflows`, `/api/v1/reports`, `/api/v1/audit-logs` | Back-office modules |
| `/privacy-policy`, `/privacy`, `/signup` | Public HTML pages (`/` redirects to `/privacy-policy`) |

---

## Getting started

### Prerequisites

- Python 3.11+ (CI uses 3.12)
- Docker (for PostgreSQL 15)
- Flutter SDK (stable channel, Dart `^3.12.1`) and JDK 17 for Android builds

### 1. Backend

```powershell
cd backend
copy .env.example .env          # then fill in the keys you need

# Option A: helper script (starts Postgres on port 5435, migrates, runs uvicorn on :8000)
.\scripts\run_local.ps1

# Option B: manual
docker compose up -d db
python -m venv .venv; .\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
$env:PYTHONPATH = "."
python -m alembic upgrade head
python -m app.database.seed      # roles, permissions and the super admin (set SUPERADMIN_PASSWORD first)
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

- Swagger UI: http://localhost:8000/docs
- Health check: http://localhost:8000/health

To run the whole stack in Docker, use `docker compose up -d`. The API is then exposed on **http://localhost:8001**. The container runs migrations on startup (`entrypoint.sh`).

### 2. Flutter app

```powershell
cd frontend
flutter pub get

# Against a local backend on a physical Android device (auto-detects the LAN IP)
.\run.ps1

# Against the hosted API
.\run.ps1 -Cloud

# Or call flutter directly
flutter run --dart-define=API_HOST=<your-pc-lan-ip>        # Android → http://<ip>:8000/api/v1
flutter run --dart-define=API_BASE_URL=<full-api-url>      # any platform
```

API URL resolution in `EnvConfig`:

1. `API_BASE_URL`, if it is set.
2. `ENV=dev` on Android: `http://<API_HOST>:8000/api/v1` if `API_HOST` is set, otherwise the hosted API.
3. `ENV=dev` on other platforms: `http://localhost:8000/api/v1`.
4. `ENV=prod`: the hosted API.

### 3. Release builds

```powershell
cd frontend
.\build_apk.ps1     # or: flutter build apk --release --dart-define=ENV=prod
.\build_aab.ps1     # Play Store bundle
```

Release signing reads `frontend/android/key.properties`; see `key.properties.example`. APKs are not committed to git. Pushing frontend changes to `main` publishes the APK to GitHub Releases through `release-apk.yml`.

---

## Configuration

All backend settings live in `backend/app/core/config.py`, and `backend/.env.example` documents them. The main groups are:

| Group | Keys |
| :--- | :--- |
| App and security | `ENVIRONMENT`, `SECRET_KEY` (at least 32 characters, enforced in production), `ACCESS_TOKEN_EXPIRE_MINUTES`, `BACKEND_CORS_ORIGINS`, `TRUSTED_PROXY`, `RATE_LIMIT_*` |
| Database | `DATABASE_URL`, or `POSTGRES_SERVER` / `POSTGRES_PORT` / `POSTGRES_USER` / `POSTGRES_PASSWORD` / `POSTGRES_DB` |
| Metal prices | `GOLDAPI_KEY`, `METALPRICEAPI_KEY`, `API_NINJAS_KEY`, `COMMODITY_PRICE_API_KEY`, `METAL_*_PERCENT`, `METAL_PRICES_CACHE_TTL_SECONDS` |
| SMS OTP | `MSG91_AUTH_KEY`, `MSG91_OTP_TEMPLATE_ID`, `MSG91_DLT_*`, `MSG91_BANK_*`, `SIGNUP_OTP_*`, `BANK_OTP_DEV_MODE` |
| KYC | `SANDBOX_API_KEY`, `SANDBOX_API_SECRET`, `KYC_TEST_MODE` (local development only) |
| Payments | `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`, `RAZORPAY_WEBHOOK_SECRET`, `RAZORPAYX_ACCOUNT_NUMBER`, `PAYMENT_DEV_MOCK` |
| Email | `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASSWORD`, `SMTP_FROM_EMAIL`, `SMTP_ENABLED` |
| Android updates | `APP_ANDROID_VERSION_NAME`, `APP_ANDROID_VERSION_CODE`, `APP_ANDROID_APK_URL`, `APP_ANDROID_FORCE_UPDATE` |

`backend/.env` is git-ignored. Never commit real keys.

---

## Testing

### Backend (`backend/tests`, pytest markers in `pytest.ini`)

| Suite | Files | Command |
| :--- | :---: | :--- |
| Unit | 45 | `pytest tests/unit` |
| API | 16 | `pytest tests/api` |
| Integration (needs Postgres) | 6 | `pytest tests/integration` |
| Security | 7 | `pytest tests/security -m security` |
| End-to-end | 8 | `pytest tests/e2e -m e2e` |
| Smoke (against a running API) | 4 | `RUN_SMOKE_TESTS=true pytest tests/smoke -m smoke` |

Coverage is configured in `.coveragerc` with `fail_under = 85`.

### Frontend (`frontend/test`)

| Suite | Files | Command |
| :--- | :---: | :--- |
| Unit | 26 | `flutter test test/unit` |
| Widget | 20 | `flutter test test/widget` |
| Integration | 3 | `flutter test test/integration` |
| End-to-end | 4 | `flutter test test/e2e` |
| Security | 3 | `flutter test test/security` |

CI requires at least 80% line coverage across `domain/`, `services/`, `config/`, `core/auth/` and `utils/`.

---

## CI/CD

- **Backend CI** (`backend.yml`) runs on pushes and PRs to `main`, `develop` or `dev` that touch `backend/**`. The stages are: Ruff lint and format check → unit + API, integration, and security tests in parallel (Postgres 15 service) → E2E → combined coverage report → Docker image build → smoke tests against the composed stack.
- **Flutter CI** (`flutter.yml`) runs on changes to `frontend/**`. The stages are: `flutter analyze` → unit (with the coverage gate) and widget tests → integration, E2E and security tests → release APK and web builds.
- **APK release** (`release-apk.yml`) runs on pushes to `main` that touch `frontend/**`, and can also be started manually. It builds the release APK and publishes it as GitHub Release `v<version>` using the version from `pubspec.yaml`.

---

## Roles and permissions

`backend/app/database/seed.py` seeds these roles: `super_admin`, `admin`, `manager`, `employee` and `user` (customers). Permissions are granular strings, for example `customer.view`, `inventory.update`, `transaction.create`, `report.export`, `workflow.approve`, `audit.view`, `wallet.view` and `organization.view`. API endpoints enforce them with `require_permission(...)`, and the Flutter UI checks them with permission gates.

Customers sign in with mobile OTP. Admins can sign in with a password and can enable TOTP 2FA.
