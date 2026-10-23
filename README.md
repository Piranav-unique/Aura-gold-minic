# Aurum Gold Enterprise Platform (AGS Gold)

[![Backend CI](https://github.com/aurum-gold/ags-gold/actions/workflows/backend.yml/badge.svg)](https://github.com/aurum-gold/ags-gold/actions/workflows/backend.yml)
[![Flutter CI](https://github.com/aurum-gold/ags-gold/actions/workflows/flutter.yml/badge.svg)](https://github.com/aurum-gold/ags-gold/actions/workflows/flutter.yml)
[![Python 3.12+](https://img.shields.io/badge/python-3.12+-blue.svg)](https://www.python.org/downloads/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.110+-009688.svg)](https://fastapi.tiangolo.com/)
[![PostgreSQL 15](https://img.shields.io/badge/PostgreSQL-15-336791.svg)](https://www.postgresql.org/)
[![Flutter 3.x](https://img.shields.io/badge/Flutter-3.x%20%7C%20Dart%203.x-02569B.svg)](https://flutter.dev/)
[![Code style: ruff](https://img.shields.io/badge/code%20style-ruff-000000.svg)](https://github.com/astral-sh/ruff)

AGS Gold (Aurum Gold & Silvers) is an enterprise-grade digital bullion fintech ecosystem comprising an asynchronous FastAPI backend, a high-throughput PostgreSQL database with partitioned audit logging, and a reactive cross-platform Flutter client. The platform enables retail and enterprise customers to track real-time bullion spot prices, buy/sell 24K physical gold and 999 fine silver, participate in goal-based gold accumulation schemes, link bank accounts, complete automated KYC, and earn rewards via a tiered multi-scheme referral engine.

---

## Key Features & Business Modules

### 🪙 Digital Bullion Trading & Pricing Engine
- **Live Spot Price Feed**: Real-time 24K Gold and 999 Fine Silver spot prices aggregating multiple market data providers (GoldAPI.io, Commodities-API, MetalPriceAPI) with automatic fallback and configurable cache TTLs.
- **Tamil Nadu Bullion Formula Engine**: Dynamic retail pricing incorporating international spot conversion, import duty (6% Gold / 10% Silver), GST (3%), and regional jeweler bullion markups.
- **Interactive Historical Charts**: Interactive Sparklines and multi-range price trend history (1 Month, 3 Months, 6 Months, 1 Year, 3 Years).
- **Instant Buy Orders**: Real-time gram-to-INR conversions, transparent GST and platform fee calculations, Razorpay checkout, and automated credit to user digital vaults.
- **Cryptographic Webhook Reconciliation**: Asynchronous Razorpay webhook ingestion (`razorpay_webhooks.py`) with HMAC-SHA256 signature verification for resilient payment completion.

### 💰 Customer Sell Inquiries & Admin Settlement Pipeline
- **Locked-In Sell Quotes**: Real-time sell price locking for customer holdings with choice of gram weight or rupee value.
- **Bank Account Integration**: Verified payout destination routing with automated IFSC resolution (bank, branch, MICR).
- **Admin Settlement Queue**: Granular admin back-office dashboard to inspect, approve, or reject sell inquiries with support for RazorpayX automated payouts or manual settlement reconciliation.
- **Digital Metal Inventory Tracking**: Automatic ledger debits from user savings balances and reconciliation against digital vault stock.

### 🎯 Goal-Based Gold Savings Schemes
- **Flexible Accumulation Tiers**: Targeted gold accumulation milestones (1g, 5g, 10g schemes) designed to help users build wealth incrementally.
- **Visual Progress Tracking**: Real-time progress bars, completion estimates, and milestone celebration dialogs.

### 🤝 Tiered Multi-Scheme Referral Engine ("Refer & Earn")
- **Plan-Specific Referral Codes**: Unique referral codes for each individual scheme tier (`<CODE>-1G`, `<CODE>-5G`, `<CODE>-10G`) with one-touch copy and shareable link generators.
- **Automatic Plan Lock**: When new customers sign up using a tiered referral code, the target scheme tier is automatically resolved and locked in without requiring manual dropdown choices.
- **Automated Qualifying Payouts**: Instant validation of minimum qualifying purchases (`₹100`) and immediate crediting of referral cash rewards (e.g., `₹150` for 1g scheme) directly into the referrer's wallet.
- **Wallet Ledger & History**: Transparent ledger of referral earnings, transaction timestamps, and referee milestone statuses.

### 🔐 Identity, Bank & Regulatory Compliance
- **Sandbox.co.in KYC Engine**: Live Aadhaar OTP authentication and PAN-Aadhaar linking with automated verification statuses (`pending`, `verified`, `rejected`).
- **Bank Account Verification**: Bank addition secured with MSG91 DLT OTP verification and instant IFSC resolution.
- **Mobile OTP Authentication**: Passwordless signup and login via MSG91 v5 OTP with Jio DLT Principal Entity headers (`AURUS`).
- **Brevo SMTP Integration**: Transactional emails for order confirmations, statements, and security notices.
- **Enterprise 2FA & TOTP**: Time-based one-time password (TOTP) two-factor authentication for administrative personnel.
- **Data Privacy & Account Deletion**: Self-service GDPR/DPDP-compliant account deletion workflows with administrative review.

### 📱 Flutter Mobile Experience
- **Architecture**: Material 3 design system, Riverpod 3 declarative state management, and GoRouter 17 route guards.
- **Security & Privacy**: Biometric authentication (`local_auth`), encrypted credential storage (`flutter_secure_storage`), and privacy/screenshot protections (`FLAG_SECURE`).
- **In-App OTA Updates**: Built-in Over-The-Air release checker and APK installer for seamless client upgrades.

---

## Architecture Diagram

```mermaid
graph TD
    %% Client Layer
    subgraph Client ["Client Layer (Flutter Mobile App)"]
        FlutterApp["Flutter Mobile App (Android/iOS)"]
        Riverpod["flutter_riverpod (State & DI)"]
        GoRouter["GoRouter (Guards & Deep Links)"]
        DioClient["ApiClient (Dio Interceptors)"]
        SecureStorage["SecureStorage (Encrypted Tokens)"]
        LocalAuth["Biometrics & Screenshot Security"]

        FlutterApp --> Riverpod
        FlutterApp --> GoRouter
        FlutterApp --> LocalAuth
        Riverpod --> DioClient
        DioClient --> SecureStorage
    end

    %% Network & API Gateway Layer
    subgraph Gateway ["Gateway & API Layer (FastAPI)"]
        FastAPI["FastAPI Application"]
        RateLimit["RateLimitMiddleware"]
        AuditMD["AuditMiddleware"]
        LoggingMD["RequestLoggingMiddleware"]
        SecurityHeaders["SecurityHeadersMiddleware"]
        JWTDep["JWT & TokenBlacklist Dependency"]
        RBACDep["RBAC Authorization Engine"]

        DioClient -- HTTPS / JSON --> RateLimit
        RateLimit --> AuditMD
        AuditMD --> LoggingMD
        LoggingMD --> SecurityHeaders
        SecurityHeaders --> JWTDep
        JWTDep --> RBACDep
    end

    %% Service Layer
    subgraph Services ["Core Business Services"]
        GoldPaySvc["GoldPaymentService"]
        SellSvc["GoldSellInquiryService"]
        SchemeSvc["GoldSchemeService"]
        ReferralSvc["ReferralService"]
        MetalPriceSvc["MetalPriceService"]
        KYCSvc["SandboxKYCService"]
        BankSvc["BankAccountService"]
        AuthSvc["AuthService"]
        UserSvc["UserService"]
        AuditSvc["AuditService"]

        RBACDep --> GoldPaySvc
        RBACDep --> SellSvc
        RBACDep --> SchemeSvc
        RBACDep --> ReferralSvc
        RBACDep --> MetalPriceSvc
        RBACDep --> KYCSvc
        RBACDep --> BankSvc
        RBACDep --> AuthSvc
        RBACDep --> UserSvc
        RBACDep --> AuditSvc
    end

    %% External Integrations
    subgraph Integrations ["Third-Party & FinTech Integrations"]
        Razorpay["Razorpay Gateway & RazorpayX"]
        GoldAPIs["Bullion Spot Feeds (GoldAPI / MetalPrice)"]
        SandboxKYC["Sandbox.co.in (Aadhaar / PAN KYC)"]
        MSG91["MSG91 SMS Gateway (DLT 'AURUS')"]
        BrevoSMTP["Brevo SMTP (Transactional Mail)"]

        GoldPaySvc --> Razorpay
        SellSvc --> Razorpay
        MetalPriceSvc --> GoldAPIs
        KYCSvc --> SandboxKYC
        BankSvc --> MSG91
        AuthSvc --> MSG91
        AuthSvc --> BrevoSMTP
    end

    %% Persistence Layer
    subgraph Database ["Persistence Layer (PostgreSQL 15)"]
        SQLAlchemy["SQLAlchemy 2.0 (Async ORM / asyncpg)"]
        Postgres["PostgreSQL Database Container"]
        AuditLogs["audit_logs (RANGE Partitioned)"]
        Users["users (Partial Unique Indexes)"]
        PaymentOrders["payment_orders"]
        SellInquiries["gold_sell_inquiries"]
        BankAccounts["bank_accounts"]
        ReferralRewards["referral_rewards"]
        DigitalInventory["digital_metal_inventory"]
        TokenBL["token_blacklist"]

        Services --> SQLAlchemy
        SQLAlchemy --> Postgres
        Postgres --> AuditLogs
        Postgres --> Users
        Postgres --> PaymentOrders
        Postgres --> SellInquiries
        Postgres --> BankAccounts
        Postgres --> ReferralRewards
        Postgres --> DigitalInventory
        Postgres --> TokenBL
    end
