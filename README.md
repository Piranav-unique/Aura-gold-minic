# AGS Gold (Aurum Gold & Silvers)

**AGS Gold** is a digital gold and silver savings and trading platform. It consists of a **FastAPI backend** (Python), a **PostgreSQL database**, and a **Flutter mobile app** (Android & iOS).

The platform allows everyday customers to buy 24K 999 digital gold and silver starting from ₹50, track real-time spot prices with Tamil Nadu retail markups, accumulate gold toward goals (1g, 5g, 10g schemes), earn cash rewards via plan-specific referral codes, link bank accounts, complete Aadhaar/PAN KYC, and submit sell requests that are reviewed and settled by the admin.

---

## 📱 What Is in the Mobile App (Customer Side)

### 1. Smart Sign Up & Plan-Specific Referral Codes
- **Mobile OTP Authentication**: Customers sign up or log in using their mobile number with instant 6-digit OTP delivered via SMS (MSG91 DLT header `AURUS`).
- **Plan-Specific Referral Codes**: 
  - Instead of generic codes, referrers share codes tied directly to target schemes: `<CODE>-1G`, `<CODE>-5G`, or `<CODE>-10G`.
  - When a new user enters a plan code during signup, the app **automatically locks in the selected scheme** (1g, 5g, or 10g) with no manual choice required.
  - When the new customer makes their first gold purchase of at least ₹100, the referrer automatically receives a **₹150 cash reward** credited directly to their in-app wallet balance.

### 2. Customer Dashboard & Real-Time Portfolio
- **Total Portfolio Value**: Live value of customer gold and silver holdings in rupees, along with total return/gain percentage and net profit.
- **Privacy Toggle**: Eye icon to quickly hide or reveal portfolio values on screen.
- **24K Live Gold Spot Price**: Real-time rate per gram, 24-hour change percentage, and live sparkline graph.
- **Full Price Charts (`/live-price`)**: Interactive historical charts across **1 Month**, **3 Months**, **6 Months**, **1 Year**, and **3 Years**.

### 3. Buying Digital Gold (`/buy-gold`)
- **Flexible Amounts**: Buy by entering rupees (₹) or grams (g), or tap instant quick-buy chips (**₹50, ₹100, ₹250, ₹500, ₹1,000, ₹2,000**).
- **Transparent Price Breakdown**: Real-time display of pure gold price, 3% GST, 2% platform fee, and exact grams credited.
- **Instant Payment Gateway**: Integrated with **Razorpay** supporting UPI (Google Pay, PhonePe, Paytm), Netbanking, Debit/Credit Cards.
- **Instant Vault Credit**: Purchased gold is credited immediately to the customer's digital vault with an automated tax invoice.

### 4. Selling Gold & Customer Sell Requests (`/sell-gold-inquiry`)
- **Sell From Vault**: Customers can sell their accumulated gold at the live market buyback rate.
- **Amount by Grams or Rupees**: Enter the weight to sell or desired rupee payout.
- **Destination Bank Account**: Select a linked verified bank account to receive funds.
- **Instant Submission**: Generates a sell request with a unique inquiry ID for administrative review and settlement.

### 5. Goal-Based Gold Savings Schemes (`/my-savings`)
- **Target Accumulation**: Track progress toward physical gold savings goals (**1 gram, 5 grams, 10 grams**).
- **Visual Progress Ring**: Live progress bars showing grams accumulated, target remaining, and invested amounts.

### 6. Refer & Earn (`/referral`)
- **Dedicated Scheme Cards**: Separate cards for **1g**, **5g**, and **10g** plans.
- **One-Tap Sharing**: Dedicated **Copy code** and **Copy link** buttons for each plan code.
- **Wallet Overview**: Shows total referrals count, total cash earned, available wallet balance, and full reward transaction history.

### 7. Bank Account Linking (`/bank-accounts`)
- **Add Bank Account**: Add beneficiary bank accounts with Account Number and IFSC code.
- **Auto IFSC Lookup**: Automatically resolves and displays bank name and branch name upon entering the IFSC.
- **OTP Verification**: Secure verification via SMS OTP before linking the account.

### 8. Regulatory KYC Verification (`/kyc-verification`)
- **Instant Aadhaar Verification**: Live Aadhaar OTP verification powered by Sandbox.co.in API.
- **PAN Verification**: PAN card input with automated name-match verification.
- **KYC Status Badges**: Real-time status indicators (**Verified**, **Pending**, or **Action Required**).

### 9. Account Settings & Security (`/settings`, `/profile`)
- **Biometric Lock**: Enable Fingerprint or Face ID unlock for app launch.
- **Screenshot Protection**: Option to toggle screenshot and screen recording security (`FLAG_SECURE`).
- **Data Privacy**: GDPR/DPDP-compliant account deletion request submission.

---

## 🛠️ What Is in the Admin & Back-Office (`/admin/*`)

### 1. Sell Requests Queue (`/admin/sell-inquiries`)
- Review all customer sell requests with customer name, phone number, grams to sell, locked price, and bank details.
- Approve or reject requests with payout settlement via **RazorpayX** or manual bank transfer.

### 2. User Wallets & Customer Accounts (`/admin/user-wallets`)
- Search any user by mobile number or name.
- View gold savings grams, silver savings grams, cash wallet balance, and full transaction ledgers.
- Perform admin adjustments or corrections with full audit notes.

### 3. Payment Settlements (`/admin/payment-settlements`)
- Reconcile online Razorpay payments, payment IDs, bank RRNs, customer contacts, and payment methods (UPI, card, netbanking).

### 4. Metal Inventory & Vault Oversight (`/admin/metal-inventory`, `/inventory`)
- Track digital bullion reserves and physical vault stock.
- Monitor inward and outward stock movements to ensure 100% backing of user digital gold.

### 5. Customer Directory (`/customers`)
- Complete directory of registered customers, registration dates, KYC verification statuses, and lifetime savings.

### 6. Role-Based Access Control & Audit Trails (`/admin/roles`, `/audit-logs`)
- Granular permissions engine for admin roles (Superadmin, Store Manager, Operations, Auditor).
- Range-partitioned PostgreSQL audit logs recording every database change with timestamps and IP addresses.

---

## 🔌 Core Integrations That Power AGS Gold

| Service | Provider | Purpose |
| :--- | :--- | :--- |
| **Payment Gateway** | **Razorpay** | UPI, Cards, Netbanking checkout for buying gold |
| **Payout Settlements** | **RazorpayX** | Automated bank payouts for customer gold sell requests |
| **Live Spot Prices** | **GoldAPI / Commodities-API / MetalPriceAPI** | International spot bullion prices with failover |
| **Retail Pricing Engine**| **Tamil Nadu Bullion Formula** | Calculates live retail prices with 6% duty, 3% GST, and TN jeweler markup |
| **SMS OTP** | **MSG91 (Jio DLT header `AURUS`)** | Signup OTP and Bank addition verification |
| **Government KYC** | **Sandbox.co.in API** | Live Aadhaar OTP authentication and PAN-Aadhaar linking |
| **Bank IFSC Directory** | **Razorpay IFSC** | Automated bank name and branch resolution |
| **Transactional Email**| **Brevo SMTP** | Purchase invoices, statement delivery, and security alerts |

---

## 📁 Repository Structure

```text
Aura-gold-minic/
├── backend/                        # FastAPI Python Backend
│   ├── alembic/versions/           # 40+ database migration files
│   ├── app/
│   │   ├── api/                    # API Endpoints
│   │   │   ├── auth.py             # Mobile OTP signup & login
│   │   │   ├── payments.py         # Gold/silver buy orders & Razorpay
│   │   │   ├── razorpay_webhooks.py# Webhook payment confirmation
│   │   │   ├── sell_inquiries.py   # Customer sell requests
│   │   │   ├── referrals.py        # Tiered referral codes & wallet
│   │   │   ├── bank_accounts.py    # Bank account linking & OTP
│   │   │   ├── gold_scheme.py      # Goal savings targets (1g, 5g, 10g)
│   │   │   ├── dashboard.py        # Live bullion prices & charts
│   │   │   ├── admin_wallet.py     # Admin user wallet management
│   │   │   └── admin_2fa.py        # Admin TOTP two-factor security
│   │   ├── models/                 # SQLAlchemy 2.0 Database Models
│   │   ├── services/               # Core Business Logic
│   │   │   ├── gold_payment.py     # Buy order processing & GST calculations
│   │   │   ├── gold_sell_inquiry.py# Sell quoting & payout approvals
│   │   │   ├── referral.py         # Tiered codes (-1G, -5G, -10G) & rewards
│   │   │   ├── metal_prices.py     # Spot price aggregation & TN retail markup
│   │   │   └── sandbox_kyc.py      # Aadhaar OTP & PAN verification client
│   │   └── main.py                 # FastAPI application startup
│   ├── Dockerfile                  # Production container
│   ├── docker-compose.yml          # PostgreSQL 15 & API containers
│   └── requirements.txt            # Python dependencies
│
├── frontend/                       # Flutter Cross-Platform Mobile App
│   ├── lib/
│   │   ├── features/
│   │   │   ├── auth/               # Mobile OTP login & smart referral signup
│   │   │   ├── user_dashboard/     # Live prices, buy gold, sell gold
│   │   │   ├── referral/           # Refer & Earn plan cards (1g, 5g, 10g)
│   │   │   ├── profile/            # Profile, KYC verification, bank linking
│   │   │   ├── admin/              # Sell inquiry review, settlements, wallets
│   │   │   └── settings/           # Biometric lock & screenshot settings
│   │   ├── routes/                 # GoRouter declarations & route guards
│   │   └── main.dart               # Flutter app entry point
│   └── pubspec.yaml                # Flutter dependencies
│
└── AGS-Gold-Release.apk            # Compiled release Android APK
```

---

## 🚀 How to Run the Project Locally

### 1. Start the Backend API

```powershell
# 1. Start PostgreSQL container
cd backend
docker compose up -d db

# 2. Activate virtual environment
.\.venv\Scripts\Activate.ps1

# 3. Install dependencies
pip install -r requirements.txt

# 4. Run migrations & seed data
$env:PYTHONPATH="."
python -m alembic upgrade head
python app/database/seed.py

# 5. Start development server
uvicorn app.main:app --reload --port 8000
```
- API Docs: `http://localhost:8000/docs`
- Health Check: `http://localhost:8000/api/v1/health`

### 2. Run the Mobile App

```bash
cd frontend
flutter pub get
flutter run
```

### 3. Generate Android Release APK

```bash
cd frontend
flutter build apk --release
# Output: frontend/build/app/outputs/flutter-apk/app-release.apk
```

---

## 👥 User Roles & Access

| Role | Access Scope |
| :--- | :--- |
| **Customer** | View live prices, buy gold/silver, track savings goals, refer friends, link bank accounts, complete KYC, request sell payouts. |
| **Superadmin** | Full platform access, admin 2FA, approve sell requests, adjust wallets, oversee inventory, manage roles and permissions. |
| **Store Manager** | Manage bullion inventory, review customers, and view settlement ledgers. |
| **Auditor** | Read-only access to partitioned audit logs, transaction histories, and regulatory reports. |
