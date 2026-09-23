from fastapi import APIRouter
from fastapi.responses import HTMLResponse

router = APIRouter()

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
  <title>Join AGS Gold - Pure 24K Gold Savings</title>
  <style>
    :root {
      --gold-primary: #D4AF37;
      --gold-dark: #AA820A;
      --bg: #0F1115;
      --card-bg: #1A1D24;
      --text-white: #FFFFFF;
      --text-muted: #9BA3AF;
      --border: #2A2F3D;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      background: var(--bg);
      color: var(--text-white);
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 24px 16px;
    }
    .card {
      width: 100%;
      max-width: 440px;
      background: var(--card-bg);
      border-radius: 20px;
      border: 1px solid var(--border);
      padding: 32px 24px;
      box-shadow: 0 12px 40px rgba(0,0,0,0.5);
      text-align: center;
    }
    .logo-badge {
      width: 68px;
      height: 68px;
      margin: 0 auto 16px;
      background: linear-gradient(135deg, #D4AF37 0%, #AA820A 100%);
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 32px;
      box-shadow: 0 6px 20px rgba(212, 175, 55, 0.35);
    }
    h1 {
      font-size: 24px;
      font-weight: 800;
      margin-bottom: 8px;
      letter-spacing: -0.5px;
    }
    .subtitle {
      font-size: 14px;
      color: var(--text-muted);
      line-height: 1.5;
      margin-bottom: 20px;
    }
    .scheme-pill {
      display: inline-block;
      background: rgba(212, 175, 55, 0.15);
      color: var(--gold-primary);
      border: 1px solid rgba(212, 175, 55, 0.35);
      font-weight: 700;
      font-size: 14px;
      padding: 6px 16px;
      border-radius: 30px;
      margin-bottom: 20px;
    }
    .code-box {
      background: #0B0D11;
      border: 1px dashed var(--gold-primary);
      border-radius: 12px;
      padding: 14px;
      margin-bottom: 24px;
      display: flex;
      align-items: center;
      justify-content: space-between;
    }
    .code-info {
      text-align: left;
    }
    .code-label {
      font-size: 11px;
      text-transform: uppercase;
      color: var(--text-muted);
      letter-spacing: 0.5px;
      font-weight: 600;
    }
    .code-value {
      font-size: 20px;
      font-weight: 800;
      letter-spacing: 2px;
      color: var(--gold-primary);
    }
    .copy-btn {
      background: var(--gold-primary);
      color: #000000;
      border: none;
      border-radius: 8px;
      padding: 8px 14px;
      font-weight: 700;
      font-size: 13px;
      cursor: pointer;
      transition: all 0.2s ease;
    }
    .copy-btn:hover {
      background: #E5C358;
    }
    .btn-main {
      display: block;
      width: 100%;
      background: linear-gradient(135deg, #D4AF37 0%, #AA820A 100%);
      color: #000000;
      text-decoration: none;
      font-weight: 800;
      font-size: 16px;
      padding: 16px;
      border-radius: 12px;
      margin-bottom: 12px;
      box-shadow: 0 4px 16px rgba(212, 175, 55, 0.3);
      cursor: pointer;
    }
    .btn-secondary {
      display: block;
      width: 100%;
      background: transparent;
      color: var(--text-white);
      text-decoration: none;
      border: 1px solid var(--border);
      font-weight: 600;
      font-size: 14px;
      padding: 14px;
      border-radius: 12px;
    }
    .features {
      margin-top: 24px;
      padding-top: 20px;
      border-top: 1px solid var(--border);
      display: flex;
      justify-content: space-around;
      font-size: 12px;
      color: var(--text-muted);
    }
    .feature-item {
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 4px;
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="logo-badge">🏆</div>
    <h1>You're Invited to AGS Gold</h1>
    <p class="subtitle">Join India's trusted 24K pure digital gold savings platform.</p>

    <div class="scheme-pill">✨ {{SCHEME_NAME}}</div>

    <div class="code-box">
      <div class="code-info">
        <div class="code-label">Referral Code</div>
        <div class="code-value" id="refCode">{{REFERRAL_CODE}}</div>
      </div>
      <button class="copy-btn" onclick="copyCode()">Copy</button>
    </div>

    <a href="{{DEEP_LINK}}" class="btn-main" id="openAppBtn">🚀 Open in AGS Gold App</a>
    <a href="https://play.google.com/store/apps/details?id=com.agsgold.ags_gold" class="btn-secondary" target="_blank">📥 Download on Google Play</a>

    <div class="features">
      <div class="feature-item">
        <span>🪙</span>
        <span>24K 99.9% Pure</span>
      </div>
      <div class="feature-item">
        <span>🔒</span>
        <span>Insured Vault</span>
      </div>
      <div class="feature-item">
        <span>🎁</span>
        <span>Gold Rewards</span>
      </div>
    </div>
  </div>

  <script>
    function copyCode() {
      const code = document.getElementById('refCode').innerText;
      navigator.clipboard.writeText(code).then(() => {
        const btn = document.querySelector('.copy-btn');
        btn.innerText = 'Copied!';
        btn.style.background = '#4CAF50';
        btn.style.color = '#FFFFFF';
        setTimeout(() => {
          btn.innerText = 'Copy';
          btn.style.background = 'var(--gold-primary)';
          btn.style.color = '#000000';
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
    if scheme_str == "1":
        scheme_name = "1 Gram 24K Gold Savings Scheme"
    elif scheme_str == "5":
        scheme_name = "5 Grams 24K Gold Savings Scheme"
    elif scheme_str == "10":
        scheme_name = "10 Grams 24K Gold Savings Scheme"
    else:
        scheme_name = "24K Pure Digital Gold Savings Scheme"

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
