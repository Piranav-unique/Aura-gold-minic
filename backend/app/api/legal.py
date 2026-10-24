from pathlib import Path
from fastapi import APIRouter
from fastapi.responses import FileResponse, HTMLResponse

router = APIRouter()

LOGO_PATH = Path(__file__).resolve().parent.parent / "static" / "ags_logo.png"


@router.get("/ags-logo.png", include_in_schema=False)
async def get_shop_logo():
    return FileResponse(LOGO_PATH, media_type="image/png")

HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Privacy Policy - Aurum Gold Works (AGS Gold)</title>
  <style>
    :root {
      --primary: #B8860B;
      --primary-dark: #8B6508;
      --bg: #FAFAF7;
      --card-bg: #FFFFFF;
      --text: #222222;
      --text-muted: #555555;
      --border: #E8E5DD;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      line-height: 1.6;
      background-color: var(--bg);
      color: var(--text);
      padding: 24px 16px;
    }
    .container {
      max-width: 800px;
      margin: 0 auto;
      background: var(--card-bg);
      padding: 40px;
      border-radius: 12px;
      border: 1px solid var(--border);
      box-shadow: 0 4px 16px rgba(0,0,0,0.04);
    }
    header {
      border-bottom: 2px solid var(--border);
      padding-bottom: 20px;
      margin-bottom: 28px;
    }
    .badge {
      display: inline-block;
      background: #FDF6E2;
      color: var(--primary-dark);
      font-weight: 600;
      font-size: 13px;
      padding: 4px 12px;
      border-radius: 20px;
      margin-bottom: 12px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    h1 {
      font-size: 28px;
      color: #1a1a1a;
      margin-bottom: 8px;
    }
    .date {
      font-size: 14px;
      color: var(--text-muted);
    }
    h2 {
      font-size: 20px;
      color: var(--primary-dark);
      margin: 24px 0 12px;
      border-left: 4px solid var(--primary);
      padding-left: 10px;
    }
    p {
      margin-bottom: 14px;
      color: var(--text);
    }
    ul {
      margin: 10px 0 16px 24px;
    }
    li {
      margin-bottom: 6px;
      color: var(--text-muted);
    }
    .contact-box {
      background: #FDF9F0;
      border: 1px solid #EEDBB2;
      border-radius: 8px;
      padding: 20px;
      margin-top: 24px;
    }
    .contact-box p {
      margin-bottom: 8px;
    }
    footer {
      text-align: center;
      margin-top: 32px;
      font-size: 13px;
      color: var(--text-muted);
    }
  </style>
</head>
<body>
  <div class="container">
    <header>
      <span class="badge">Legal Document</span>
      <h1>Privacy Policy</h1>
      <div class="date">Application: <strong>AGS Gold</strong> | Organization: <strong>Aurum Gold Works</strong></div>
      <div class="date">Last Updated: September 2026</div>
    </header>

    <section>
      <p>Welcome to <strong>Aurum Gold Works</strong> ("AGS Gold", "we", "our", or "us"). We value your privacy and are committed to protecting your personal information. This Privacy Policy explains how we collect, use, store, and protect the information you provide when using our mobile application, website, and related digital gold services (accessible at aurumgold.co.in).</p>
      <p>By using the AGS Gold mobile application or our services, you agree to the collection and use of information in accordance with this Privacy Policy.</p>
    </section>

    <section>
      <h2>1. Information We Collect</h2>
      <p>We may collect and process the following categories of information to provide you with secure digital gold services:</p>
      <ul>
        <li><strong>Personal Identification:</strong> Full Name, Mobile Phone Number, and Email Address.</li>
        <li><strong>Address & Delivery Information:</strong> Postal Address, City, State, and PIN code.</li>
        <li><strong>Identity & KYC Details:</strong> Government-issued identity numbers (PAN card, Aadhaar details via licensed verification partners) as legally mandated for precious metal transactions in India.</li>
        <li><strong>Transaction & Order Details:</strong> Buy/sell gold orders, payment transaction IDs, and linked bank account details for sale proceeds.</li>
        <li><strong>Customer Inquiries:</strong> Any feedback, communications, or support tickets submitted through the application.</li>
      </ul>
    </section>

    <section>
      <h2>2. How We Use Your Information</h2>
      <p>The information collected is used strictly for legitimate business and regulatory purposes, including:</p>
      <ul>
        <li>Authenticating your account securely using One-Time Passwords (SMS OTP).</li>
        <li>Fulfilling buy and sell orders for digital gold and silver.</li>
        <li>Complying with Anti-Money Laundering (AML) and Know Your Customer (KYC) regulations mandated by Indian laws.</li>
        <li>Processing refunds, sales payouts, and transaction settlements.</li>
        <li>Providing prompt customer care and technical support.</li>
        <li>Sending important order confirmations, transaction receipts, and security alerts.</li>
      </ul>
    </section>

    <section>
      <h2>3. Information Security</h2>
      <p>We implement industry-standard administrative, technical, and physical safeguards to protect your personal information against unauthorized access, disclosure, alteration, or destruction. Sensitive communications are encrypted in transit using Transport Layer Security (TLS/HTTPS), and passwords/tokens are cryptographically protected.</p>
    </section>

    <section>
      <h2>4. Sharing of Information</h2>
      <p>We do not sell, rent, or trade your personal information to third parties for marketing purposes. Information may be shared solely under the following circumstances:</p>
      <ul>
        <li><strong>Authorized Service Providers:</strong> Trusted third-party partners providing infrastructure, such as payment gateways (Razorpay), SMS gateways (MSG91), and compliant KYC verification engines (Sandbox.co.in).</li>
        <li><strong>Legal Compliance:</strong> When required by law, subpoena, court order, or official governmental request.</li>
        <li><strong>Protection of Rights:</strong> When necessary to protect the rights, property, safety, or security of Aurum Gold Works, our users, or the public.</li>
      </ul>
    </section>

    <section>
      <h2>5. Data Retention & Deletion</h2>
      <p>We retain personal information only for as long as necessary to fulfill the purposes outlined in this Privacy Policy, or to satisfy legal, accounting, tax, or regulatory reporting requirements under Indian law.</p>
      <p><strong>Your Right to Account Deletion:</strong> You have the right to request deletion of your account and associated personal data at any time directly through the app settings (Profile ➔ Delete Account) or by contacting our support team. Upon receiving your verified request, we will delete or anonymize your data, subject to statutory record-retention requirements.</p>
    </section>

    <section>
      <h2>6. Your Rights</h2>
      <p>Subject to applicable law, you have the following rights regarding your personal information:</p>
      <ul>
        <li>Access the personal data we hold about you.</li>
        <li>Request corrections to any inaccurate or incomplete information.</li>
        <li>Request deletion of your personal account.</li>
        <li>Opt out of non-essential communications.</li>
      </ul>
    </section>

    <section>
      <h2>7. Children's Privacy</h2>
      <p>Our application and services are not intended for individuals under 18 years of age. We do not knowingly collect personal information from minors.</p>
    </section>

    <section>
      <h2>8. Changes to This Privacy Policy</h2>
      <p>We may update this Privacy Policy periodically to reflect changes in our practices or applicable legal requirements. Any modifications will be posted on this page with an updated revision date.</p>
    </section>

    <section>
      <h2>9. Contact Us & Grievance Officer</h2>
      <p>If you have any questions, concerns, or requests regarding this Privacy Policy or our data handling practices, please contact us at:</p>
      <div class="contact-box">
        <p><strong>Aurum Gold Works (AGS Gold)</strong></p>
        <p>Coimbatore, Tamil Nadu, India</p>
        <p><strong>Phone:</strong> +91 99437 95005</p>
        <p><strong>Email:</strong> <a href="mailto:info@aurumgold.co.in">info@aurumgold.co.in</a></p>
        <p><strong>Website:</strong> <a href="https://aurumgold.co.in" target="_blank">https://aurumgold.co.in</a></p>
      </div>
    </section>

    <footer>
      &copy; 2026 Aurum Gold Works. All rights reserved.
    </footer>
  </div>
</body>
</html>
"""


@router.get("/privacy-policy", response_class=HTMLResponse, include_in_schema=False)
@router.get("/privacy", response_class=HTMLResponse, include_in_schema=False)
async def get_privacy_policy():
    return HTMLResponse(content=HTML_TEMPLATE, status_code=200)


SIGNUP_LANDING_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>AGS - Aurum Gold &amp; Silvers | Referral Invitation</title>
  <link rel="icon" type="image/png" href="/ags-logo.png">
  <meta property="og:title" content="AGS - Aurum Gold &amp; Silvers">
  <meta property="og:description" content="Join AGS Gold ({{SCHEME_NAME}}) using referral code {{REFERRAL_CODE}}.">
  <meta property="og:image" content="https://api.aurumgold.co.in/ags-logo.png">
  <style>
    :root {
      --bg: #F7F3EA;
      --surface: #FFFFFF;
      --surface-muted: #FAF8F3;
      --border: #E6E0D2;
      --ink: #1A1712;
      --ink-secondary: #5C564B;
      --ink-muted: #8A8377;
      --gold: #B8860B;
      --gold-light: #FDF7E7;
      --gold-border: #E5CFA0;
      --cta-bg: #1A1712;
      --cta-text: #FFFFFF;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      background-color: var(--bg);
      color: var(--ink);
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 20px 16px;
      -webkit-font-smoothing: antialiased;
    }
    .wrapper {
      width: 100%;
      max-width: 420px;
    }
    .card {
      background: var(--surface);
      border-radius: 16px;
      border: 1px solid var(--border);
      padding: 28px 22px;
      box-shadow: 0 2px 10px rgba(26, 23, 18, 0.04);
    }
    .logo-wrap {
      text-align: center;
      margin-bottom: 18px;
      padding-bottom: 16px;
      border-bottom: 1px solid var(--border);
    }
    .shop-logo {
      max-width: 190px;
      width: 100%;
      height: auto;
      display: inline-block;
    }
    .section-tag {
      display: inline-block;
      font-size: 11px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.6px;
      color: var(--gold);
      background: var(--gold-light);
      border: 1px solid var(--gold-border);
      padding: 4px 10px;
      border-radius: 6px;
      margin-bottom: 10px;
    }
    h1 {
      font-size: 21px;
      font-weight: 700;
      color: var(--ink);
      margin-bottom: 6px;
      line-height: 1.3;
    }
    .subtitle {
      font-size: 14px;
      color: var(--ink-secondary);
      line-height: 1.5;
      margin-bottom: 18px;
    }
    .scheme-row {
      background: var(--surface-muted);
      border: 1px solid var(--border);
      border-radius: 10px;
      padding: 12px 14px;
      margin-bottom: 14px;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .scheme-label {
      font-size: 12px;
      color: var(--ink-muted);
      font-weight: 600;
    }
    .scheme-value {
      font-size: 13px;
      color: var(--ink);
      font-weight: 700;
    }
    .code-box {
      background: var(--surface-muted);
      border: 1px solid var(--border);
      border-radius: 10px;
      padding: 14px 16px;
      margin-bottom: 20px;
      display: flex;
      align-items: center;
      justify-content: space-between;
    }
    .code-label {
      font-size: 11px;
      text-transform: uppercase;
      color: var(--ink-muted);
      letter-spacing: 0.5px;
      font-weight: 600;
      margin-bottom: 3px;
    }
    .code-value {
      font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
      font-size: 19px;
      font-weight: 700;
      letter-spacing: 1.5px;
      color: var(--ink);
    }
    .copy-btn {
      background: var(--surface);
      color: var(--ink);
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 8px 14px;
      font-weight: 600;
      font-size: 13px;
      cursor: pointer;
      transition: background 0.15s ease;
    }
    .copy-btn:active {
      background: var(--bg);
    }
    .btn-primary {
      display: block;
      width: 100%;
      background: var(--cta-bg);
      color: var(--cta-text);
      text-decoration: none;
      text-align: center;
      font-weight: 600;
      font-size: 15px;
      padding: 14px 16px;
      border-radius: 10px;
      margin-bottom: 10px;
    }
    .btn-secondary {
      display: block;
      width: 100%;
      background: var(--surface);
      color: var(--ink);
      text-decoration: none;
      text-align: center;
      border: 1px solid var(--border);
      font-weight: 600;
      font-size: 14px;
      padding: 13px 16px;
      border-radius: 10px;
    }
    .steps {
      margin-top: 18px;
      padding-top: 16px;
      border-top: 1px solid var(--border);
      font-size: 12.5px;
      color: var(--ink-secondary);
      line-height: 1.6;
    }
    .steps strong {
      color: var(--ink);
    }
    .footer {
      text-align: center;
      margin-top: 16px;
      font-size: 12px;
      color: var(--ink-muted);
    }
  </style>
</head>
<body>
  <div class="wrapper">
    <div class="card">
      <div class="logo-wrap">
        <img src="/ags-logo.png" alt="AGS - Aurum Gold &amp; Silvers" class="shop-logo">
      </div>

      <span class="section-tag">Referral Invitation</span>
      <h1>Create your AGS Gold account</h1>
      <p class="subtitle">You have been invited to join AGS (Aurum Gold &amp; Silvers). Use the referral code below during registration.</p>

      <div class="scheme-row">
        <span class="scheme-label">Selected Plan</span>
        <span class="scheme-value">{{SCHEME_NAME}}</span>
      </div>

      <div class="code-box">
        <div>
          <div class="code-label">Referral Code</div>
          <div class="code-value" id="refCode">{{REFERRAL_CODE}}</div>
        </div>
        <button class="copy-btn" type="button" onclick="copyCode()">Copy Code</button>
      </div>

      <a href="{{DEEP_LINK}}" class="btn-primary" id="openAppBtn">Continue in AGS Gold App</a>
      <a href="https://play.google.com/store/apps/details?id=com.agsgold.ags_gold" class="btn-secondary" target="_blank" rel="noopener">Get the App on Google Play</a>

      <div class="steps">
        <strong>How to apply:</strong> Open the AGS Gold app, tap <strong>Sign Up</strong>, and enter the referral code <strong>{{REFERRAL_CODE}}</strong> before completing verification.
      </div>
    </div>

    <div class="footer">
      &copy; 2026 Aurum Gold &amp; Silvers, Coimbatore
    </div>
  </div>

  <script>
    function copyCode() {
      const code = document.getElementById('refCode').innerText;
      navigator.clipboard.writeText(code).then(() => {
        const btn = document.querySelector('.copy-btn');
        btn.innerText = 'Copied';
        btn.style.borderColor = '#B8860B';
        btn.style.color = '#B8860B';
        setTimeout(() => {
          btn.innerText = 'Copy Code';
          btn.style.borderColor = 'var(--border)';
          btn.style.color = 'var(--ink)';
        }, 2000);
      });
    }

    window.onload = function() {
      const deepLink = "{{DEEP_LINK}}";
      if (deepLink && deepLink.startsWith("agsgold://")) {
        const iframe = document.createElement("iframe");
        iframe.style.display = "none";
        iframe.src = deepLink;
        document.body.appendChild(iframe);
      }
    };
  </script>
</body>
</html>
"""


@router.get("/signup", response_class=HTMLResponse, include_in_schema=False)
async def signup_landing_page(
    ref: str | None = None,
    scheme: str | None = None,
):
    code = (ref or "").strip().upper() or "WELCOME"
    scheme_str = (scheme or "").strip()
    if not scheme_str:
        if code.endswith("-1G"):
            scheme_str = "1"
        elif code.endswith("-5G"):
            scheme_str = "5"
        elif code.endswith("-10G"):
            scheme_str = "10"

    if scheme_str == "1":
        scheme_name = "1-Gram Gold Scheme (Min. ₹100)"
    elif scheme_str == "5":
        scheme_name = "5-Gram Gold Scheme (Min. ₹1,000)"
    elif scheme_str == "10":
        scheme_name = "10-Gram Gold Scheme (Min. ₹2,000)"
    else:
        scheme_name = "24K Digital Gold Savings"

    deep_link = f"agsgold://signup?ref={code}"
    if scheme_str:
        deep_link += f"&scheme={scheme_str}"

    html = (
        SIGNUP_LANDING_TEMPLATE
        .replace("{{SCHEME_NAME}}", scheme_name)
        .replace("{{REFERRAL_CODE}}", code)
        .replace("{{DEEP_LINK}}", deep_link)
    )
    return HTMLResponse(content=html, status_code=200)


ACCOUNT_DELETION_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>Account &amp; Data Deletion - Aurum Gold &amp; Silvers (AGS Gold)</title>
  <link rel="icon" type="image/png" href="/ags-logo.png">
  <style>
    :root {
      --primary: #B8860B;
      --primary-dark: #8B6508;
      --bg: #FAFAF7;
      --card-bg: #FFFFFF;
      --text: #222222;
      --text-muted: #555555;
      --border: #E8E5DD;
      --danger: #DC2626;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      line-height: 1.6;
      background-color: var(--bg);
      color: var(--text);
      padding: 24px 16px;
    }
    .container {
      max-width: 760px;
      margin: 0 auto;
      background: var(--card-bg);
      padding: 36px 32px;
      border-radius: 12px;
      border: 1px solid var(--border);
      box-shadow: 0 4px 16px rgba(0,0,0,0.04);
    }
    header {
      border-bottom: 2px solid var(--border);
      padding-bottom: 20px;
      margin-bottom: 24px;
    }
    .badge {
      display: inline-block;
      background: #FDF6E2;
      color: var(--primary-dark);
      font-weight: 600;
      font-size: 13px;
      padding: 4px 12px;
      border-radius: 20px;
      margin-bottom: 12px;
    }
    h1 { font-size: 24px; font-weight: 700; color: #111; margin-bottom: 8px; }
    h2 { font-size: 18px; font-weight: 700; color: var(--primary-dark); margin: 24px 0 12px; }
    p, li { font-size: 14.5px; color: var(--text); margin-bottom: 10px; }
    ul { padding-left: 20px; margin-bottom: 16px; }
    .card-box {
      background: #F9F9F6;
      border: 1px solid var(--border);
      padding: 16px;
      border-radius: 8px;
      margin: 16px 0;
    }
    .contact-box {
      background: #FEF3C7;
      border: 1px solid #F59E0B;
      padding: 16px;
      border-radius: 8px;
      margin-top: 24px;
    }
    .contact-box a { color: #92400E; font-weight: 700; text-decoration: none; }
    footer {
      margin-top: 32px;
      border-top: 1px solid var(--border);
      padding-top: 16px;
      font-size: 13px;
      color: var(--text-muted);
      text-align: center;
    }
  </style>
</head>
<body>
  <div class="container">
    <header>
      <div class="badge">Google Play Data Safety &amp; User Privacy</div>
      <h1>Request Account &amp; Data Deletion</h1>
      <p style="color: var(--text-muted); font-size: 13px;">Aurum Gold &amp; Silvers (AGS Gold)</p>
    </header>

    <p>At Aurum Gold &amp; Silvers, we respect your right to privacy and control over your personal information. If you wish to delete your AGS Gold account and all associated personal data, you can request account deletion at any time.</p>

    <h2>1. How to Delete Your Account</h2>
    <p>You can request account deletion through either of the following methods:</p>
    <ul>
      <li><strong>In-App Deletion:</strong> Open the AGS Gold app ➔ go to <strong>Profile / Settings</strong> ➔ tap <strong>Delete Account</strong> ➔ confirm your request.</li>
      <li><strong>Web / Email Request:</strong> Send an email from your registered email address to <a href="mailto:aurumgoldsilvers@gmail.com">aurumgoldsilvers@gmail.com</a> with the subject <code>Account Deletion Request - [Your Mobile Number]</code>.</li>
    </ul>

    <h2>2. What Data is Deleted</h2>
    <div class="card-box">
      <ul>
        <li><strong>Profile Information:</strong> Name, mobile phone number, email address, and profile photo.</li>
        <li><strong>Device Identifiers:</strong> Registered device IDs, login session tokens, and push notification tokens.</li>
        <li><strong>KYC Documents:</strong> PAN card records, Aadhaar verification logs, and identity hashes.</li>
        <li><strong>Linked Bank Accounts:</strong> Saved bank account numbers, IFSC codes, and beneficiary data.</li>
      </ul>
    </div>

    <h2>3. Data Retention for Legal &amp; Financial Compliance</h2>
    <p>Under Indian regulations (including the Prevention of Money Laundering Act - PMLA, GST Act, and statutory financial accounting standards):</p>
    <ul>
      <li>Records of executed financial transactions (gold/silver purchases, sell payouts, and GST tax invoices) are legally required to be retained in archived audit ledgers for a period of 5 years.</li>
      <li>These archived records are isolated, securely encrypted, and never used for marketing or commercial profiling.</li>
    </ul>

    <h2>4. Processing Timeline</h2>
    <p>Account deletion requests are reviewed and fulfilled within <strong>48 to 72 business hours</strong>. Once deleted, your account cannot be recovered, and any unused promotional credits or vouchers will be forfeited.</p>

    <div class="contact-box">
      <p style="margin: 0; font-size: 14px;"><strong>Need help or have questions?</strong> Contact our Data Privacy Officer at <a href="mailto:aurumgoldsilvers@gmail.com">aurumgoldsilvers@gmail.com</a>.</p>
    </div>

    <footer>
      &copy; 2026 Aurum Gold &amp; Silvers. All rights reserved. &bull; <a href="/privacy-policy" style="color: var(--primary);">Privacy Policy</a>
    </footer>
  </div>
</body>
</html>
"""


@router.get("/delete-account", response_class=HTMLResponse, include_in_schema=False)
@router.get("/account-deletion", response_class=HTMLResponse, include_in_schema=False)
async def get_account_deletion_page():
    return HTMLResponse(content=ACCOUNT_DELETION_TEMPLATE, status_code=200)
