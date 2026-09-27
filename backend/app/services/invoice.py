import io
from datetime import datetime, timezone
from decimal import Decimal

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.platypus import HRFlowable, Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle

from app.models.payment_order import PaymentOrder
from app.models.user import User


def _format_inr(val) -> str:
    if val is None:
        return "0.00"
    try:
        d = Decimal(str(val))
        return f"{d:,.2f}"
    except Exception:
        return "0.00"


def _user_display_name(user: User) -> str:
    first = getattr(user, "first_name", "") or ""
    last = getattr(user, "last_name", "") or ""
    full = f"{first} {last}".strip()
    if full:
        return full
    name = getattr(user, "name", "") or ""
    return name if name else "Customer"


def generate_invoice_pdf(order: PaymentOrder, user: User) -> bytes:
    """Generate an A4 PDF Tax Invoice styled to match the AGS Gold & Silver letterhead."""
    buffer = io.BytesIO()

    PAGE_W, PAGE_H = A4  # 595.27 x 841.89 pt

    # ── Brand colours ────────────────────────────────────────────────────
    MAROON      = colors.HexColor("#7A1E2A")   # dark wine-red band
    GOLD_BAND   = colors.HexColor("#C8A000")   # gold stripe
    GOLD_ACCENT = colors.HexColor("#B8860B")   # totals / highlights
    DARK        = colors.HexColor("#1A1D24")   # body text
    MUTED       = colors.HexColor("#6C757D")   # sub-labels
    LIGHT_BG    = colors.HexColor("#FDF8F0")   # table row bg
    BORDER      = colors.HexColor("#E5D8C0")   # table borders

    # ── Band heights ─────────────────────────────────────────────────────
    TOP_BAND_H   = 58
    TOP_STRIPE_H = 12
    BOT_BAND_H   = 52
    BOT_STRIPE_H = 12

    # ── Per-page letterhead ───────────────────────────────────────────────
    def draw_letterhead(c, doc):
        c.saveState()

        # Top maroon band
        c.setFillColor(MAROON)
        c.rect(0, PAGE_H - TOP_BAND_H, PAGE_W, TOP_BAND_H, fill=1, stroke=0)

        # Top gold stripe
        c.setFillColor(GOLD_BAND)
        c.rect(0, PAGE_H - TOP_BAND_H - TOP_STRIPE_H, PAGE_W, TOP_STRIPE_H, fill=1, stroke=0)

        # Company name — top-left inside band
        c.setFillColor(colors.white)
        c.setFont("Helvetica-Bold", 16)
        c.drawString(36, PAGE_H - 38, "AGS")
        c.setFont("Helvetica", 9)
        c.drawString(36, PAGE_H - 52, "AURUM GOLD & SILVER")

        # "TAX INVOICE" label — top-right inside band
        c.setFont("Helvetica-Bold", 10)
        c.drawRightString(PAGE_W - 36, PAGE_H - 36, "TAX INVOICE")
        c.setFont("Helvetica", 8)
        c.drawRightString(PAGE_W - 36, PAGE_H - 50, "Official Purchase Receipt")

        # Watermark: light AGS centred on page
        c.setFillColor(colors.Color(0.48, 0.12, 0.16, alpha=0.06))
        c.setFont("Helvetica-Bold", 110)
        c.drawCentredString(PAGE_W / 2, PAGE_H / 2 - 55, "AGS")

        # Bottom gold stripe
        c.setFillColor(GOLD_BAND)
        c.rect(0, BOT_BAND_H, PAGE_W, BOT_STRIPE_H, fill=1, stroke=0)

        # Bottom maroon band
        c.setFillColor(MAROON)
        c.rect(0, 0, PAGE_W, BOT_BAND_H, fill=1, stroke=0)

        # Contact details inside bottom band — right-aligned
        c.setFillColor(colors.white)
        c.setFont("Helvetica", 7.5)
        c.drawRightString(PAGE_W - 36, BOT_BAND_H - 16, "Tel: 99437 95005")
        c.drawRightString(PAGE_W - 36, BOT_BAND_H - 28, "Email: aurumgoldsilver@gmail.com")
        c.drawRightString(PAGE_W - 36, BOT_BAND_H - 40, "82B, South Masi Street, Madurai - 625 001")

        # Computer-generated note — bottom-left
        c.setFont("Helvetica", 7)
        c.drawString(36, BOT_BAND_H - 22, "This is a computer-generated invoice.")
        c.drawString(36, BOT_BAND_H - 34, "No signature required.")

        c.restoreState()

    # ── Document ──────────────────────────────────────────────────────────
    doc = SimpleDocTemplate(
        buffer,
        pagesize=A4,
        leftMargin=40,
        rightMargin=40,
        topMargin=TOP_BAND_H + TOP_STRIPE_H + 18,
        bottomMargin=BOT_BAND_H + BOT_STRIPE_H + 14,
    )

    styles = getSampleStyleSheet()

    def _s(name, **kw):
        return ParagraphStyle(name, parent=styles["Normal"], **kw)

    body_style    = _s("Body",    fontName="Helvetica",      fontSize=8.5, leading=11, textColor=DARK)
    label_style   = _s("Label",   fontName="Helvetica-Bold", fontSize=8.5, leading=11, textColor=DARK)
    th_style      = _s("TH",      fontName="Helvetica-Bold", fontSize=8.5, leading=11, textColor=colors.white)
    td_style      = _s("TD",      fontName="Helvetica",      fontSize=8.5, leading=11, textColor=DARK)
    td_bold       = _s("TDBold",  fontName="Helvetica-Bold", fontSize=8.5, leading=11, textColor=DARK)
    total_style   = _s("Total",   fontName="Helvetica-Bold", fontSize=11,  leading=14, textColor=GOLD_ACCENT)

    # ── Data ─────────────────────────────────────────────────────────────
    inv_id         = str(order.id).replace("-", "")[:8].upper()
    invoice_number = f"INV-AGS-{inv_id}"
    paid_dt        = order.paid_at or order.created_at or datetime.now(timezone.utc)
    date_str       = paid_dt.strftime("%d %b %Y, %I:%M %p")

    buyer_name     = _user_display_name(user)
    buyer_mobile   = getattr(user, "mobile_number", "") or "N/A"
    buyer_email    = getattr(user, "email", "") or "N/A"
    payment_id     = getattr(order, "razorpay_payment_id", "") or "Completed"
    bank_rrn       = getattr(order, "bank_rrn", "") or "N/A"
    payment_method = getattr(order, "payment_method", "") or "UPI / Online"

    is_gold    = (order.metal or "gold").lower() == "gold"
    metal_name = "24K Pure Digital Gold (99.9% / 999 Fineness)" if is_gold else "Pure Digital Silver (99.9% / 999 Fineness)"
    hsn_code   = "7108" if is_gold else "7106"

    grams        = Decimal(str(order.grams))
    rate         = Decimal(str(order.rate_per_gram))
    total_amount = Decimal(str(order.amount_paise)) / Decimal("100")

    metal_value = order.metal_value_inr
    if metal_value is None:
        metal_value = (total_amount / Decimal("1.03")).quantize(Decimal("0.01"))
    else:
        metal_value = Decimal(str(metal_value))

    gst_amount = order.gst_amount_inr
    if gst_amount is None:
        gst_amount = total_amount - metal_value
    else:
        gst_amount = Decimal(str(gst_amount))

    cgst = (gst_amount / Decimal("2")).quantize(Decimal("0.01"))
    sgst = gst_amount - cgst

    # ── Story ─────────────────────────────────────────────────────────────
    story = []

    # 1. Invoice reference strip
    hdr_data = [[
        Paragraph(
            f"<b>Invoice No:</b> {invoice_number}<br/>"
            f"<b>Date:</b> {date_str}<br/>"
            f"<b>Order Ref:</b> {order.razorpay_order_id}",
            body_style,
        ),
        Paragraph(
            "<font color='#28A745'><b>PAYMENT SUCCESSFUL</b></font>",
            _s("PS", fontName="Helvetica-Bold", fontSize=11, leading=14,
               textColor=colors.HexColor("#28A745"), alignment=2),
        ),
    ]]
    hdr_table = Table(hdr_data, colWidths=[300, 215])
    hdr_table.setStyle(TableStyle([
        ("VALIGN",     (0, 0), (-1, -1), "MIDDLE"),
        ("ALIGN",      (1, 0), (1, 0),  "RIGHT"),
        ("BACKGROUND", (0, 0), (-1, -1), LIGHT_BG),
        ("BOX",        (0, 0), (-1, -1), 0.5, BORDER),
        ("PADDING",    (0, 0), (-1, -1), 10),
    ]))
    story.append(hdr_table)
    story.append(Spacer(1, 14))

    # Maroon section divider
    story.append(HRFlowable(width="100%", thickness=2, color=MAROON, spaceAfter=14))

    # 2. Billed To / Payment Details
    info_data = [
        [
            Paragraph("<b>BILLED TO (CUSTOMER)</b>",
                      _s("SH", fontName="Helvetica-Bold", fontSize=9, leading=12, textColor=colors.white)),
            Paragraph("<b>PAYMENT TRANSACTION</b>",
                      _s("SH2", fontName="Helvetica-Bold", fontSize=9, leading=12, textColor=colors.white)),
        ],
        [
            Paragraph(
                f"<b>Name:</b> {buyer_name}<br/>"
                f"<b>Mobile:</b> +91 {buyer_mobile}<br/>"
                f"<b>Email:</b> {buyer_email}",
                body_style,
            ),
            Paragraph(
                f"<b>Gateway:</b> Razorpay<br/>"
                f"<b>Payment ID:</b> {payment_id}<br/>"
                f"<b>Mode:</b> {payment_method}<br/>"
                f"<b>Bank Ref (UTR):</b> {bank_rrn}<br/>"
                f"<b>Status:</b> <font color='#28A745'>PAID</font>",
                body_style,
            ),
        ],
    ]
    info_table = Table(info_data, colWidths=[257, 258])
    info_table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), MAROON),
        ("BACKGROUND", (0, 1), (-1, 1), LIGHT_BG),
        ("PADDING",    (0, 0), (-1, -1), 8),
        ("VALIGN",     (0, 0), (-1, -1), "TOP"),
        ("BOX",        (0, 0), (-1, -1), 0.5, BORDER),
        ("LINEAFTER",  (0, 0), (0, -1), 0.5, BORDER),
    ]))
    story.append(info_table)
    story.append(Spacer(1, 16))

    # 3. Line Items
    items_data = [
        [
            Paragraph("Item Description", th_style),
            Paragraph("HSN",              th_style),
            Paragraph("Weight",           th_style),
            Paragraph("Rate / Gram",      th_style),
            Paragraph("Metal Value",      th_style),
            Paragraph("GST (3%)",         th_style),
            Paragraph("Total (INR)",      th_style),
        ],
        [
            Paragraph(
                f"<b>{metal_name}</b><br/>"
                f"<font size='7' color='#6C757D'>Stored in Insured Custody Vault</font>",
                td_style,
            ),
            Paragraph(hsn_code,                        td_style),
            Paragraph(f"{grams:.4f} g",                td_style),
            Paragraph(f"INR {_format_inr(rate)}",      td_style),
            Paragraph(f"INR {_format_inr(metal_value)}",td_style),
            Paragraph(f"INR {_format_inr(gst_amount)}", td_style),
            Paragraph(f"<b>INR {_format_inr(total_amount)}</b>", td_bold),
        ],
    ]
    items_table = Table(items_data, colWidths=[155, 42, 55, 65, 65, 60, 73])
    items_table.setStyle(TableStyle([
        ("BACKGROUND",     (0, 0), (-1, 0), MAROON),
        ("ALIGN",          (1, 0), (-1, -1), "CENTER"),
        ("VALIGN",         (0, 0), (-1, -1), "MIDDLE"),
        ("PADDING",        (0, 0), (-1, -1), 6),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, LIGHT_BG]),
        ("GRID",           (0, 0), (-1, -1), 0.5, BORDER),
    ]))
    story.append(items_table)
    story.append(Spacer(1, 14))

    # 4. Tax Summary (right-aligned block)
    summary_data = [
        [Paragraph("Taxable Metal Amount:", body_style),   Paragraph(f"INR {_format_inr(metal_value)}", td_bold)],
        [Paragraph("CGST @ 1.5%:",          body_style),   Paragraph(f"INR {_format_inr(cgst)}",        td_style)],
        [Paragraph("SGST @ 1.5%:",          body_style),   Paragraph(f"INR {_format_inr(sgst)}",        td_style)],
        [Paragraph("Total GST (3.0%):",     body_style),   Paragraph(f"INR {_format_inr(gst_amount)}",  td_style)],
        [Paragraph("<b>TOTAL AMOUNT PAID:</b>", label_style), Paragraph(f"<b>INR {_format_inr(total_amount)}</b>", total_style)],
    ]
    summary_table = Table(summary_data, colWidths=[155, 110])
    summary_table.setStyle(TableStyle([
        ("ALIGN",      (1, 0), (1, -1), "RIGHT"),
        ("PADDING",    (0, 0), (-1, -1), 5),
        ("LINEABOVE",  (0, 4), (-1, 4), 1.5, GOLD_ACCENT),
        ("BACKGROUND", (0, 4), (-1, 4), colors.HexColor("#FDF3DC")),
        ("BOX",        (0, 0), (-1, -1), 0.5, BORDER),
    ]))
    outer_summary = Table([[Paragraph("", body_style), summary_table]], colWidths=[255, 265])
    outer_summary.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "TOP")]))
    story.append(outer_summary)
    story.append(Spacer(1, 18))

    # 5. Vault notice
    terms_text = (
        "<b>Vault &amp; Custody Certificate:</b><br/>"
        "&#8226; Your purchased metal is 100% physically backed, allocated, and stored in secure, insured bullion vaults.<br/>"
        "&#8226; Purity is certified 24 Karat 99.9% (999 fineness) for Gold, conforming to national bullion standards.<br/>"
        "&#8226; You can sell back or withdraw your accumulated gold anytime through the AGS Gold mobile application.<br/>"
        "&#8226; This is a computer-generated tax invoice and requires no physical signature."
    )
    terms_box = Table(
        [[Paragraph(terms_text, _s("Terms", fontSize=7.5, leading=10, textColor=MUTED))]],
        colWidths=[515],
    )
    terms_box.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#FDF8F0")),
        ("BOX",        (0, 0), (-1, -1), 0.5, GOLD_BAND),
        ("PADDING",    (0, 0), (-1, -1), 9),
    ]))
    story.append(terms_box)

    doc.build(story, onFirstPage=draw_letterhead, onLaterPages=draw_letterhead)
    return buffer.getvalue()


def generate_invoice_html(order: PaymentOrder, user: User) -> str:
    """Generate high-end luxury gold & obsidian HTML email for customer inbox."""
    user_name = _user_display_name(user)
    inv_id = str(order.id).replace("-", "")[:8].upper()
    invoice_number = f"INV-AGS-{inv_id}"
    paid_dt = order.paid_at or order.created_at or datetime.now(timezone.utc)
    date_str = paid_dt.strftime("%d %b %Y, %I:%M %p")

    is_gold = (order.metal or "gold").lower() == "gold"
    metal_name = "24K Pure Digital Gold" if is_gold else "Pure Digital Silver"
    metal_icon = "\U0001fa99" if is_gold else "\U0001f948"
    grams = Decimal(str(order.grams))
    rate = Decimal(str(order.rate_per_gram))
    total_amount = Decimal(str(order.amount_paise)) / Decimal("100")

    metal_value = order.metal_value_inr
    if metal_value is None:
        metal_value = (total_amount / Decimal("1.03")).quantize(Decimal("0.01"))
    else:
        metal_value = Decimal(str(metal_value))

    gst_amount = order.gst_amount_inr
    if gst_amount is None:
        gst_amount = total_amount - metal_value
    else:
        gst_amount = Decimal(str(gst_amount))

    order_ref = getattr(order, "razorpay_order_id", "") or "N/A"
    payment_id = getattr(order, "razorpay_payment_id", "") or "Completed"
    bank_rrn = getattr(order, "bank_rrn", "") or "N/A"

    return f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Payment Receipt &amp; Tax Invoice - AGS Gold</title>
  <style>
    body {{
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      margin: 0;
      padding: 0;
      background-color: #0F1115;
      color: #E2E8F0;
    }}
    .wrapper {{
      width: 100%;
      max-width: 600px;
      margin: 0 auto;
      background-color: #171A21;
      border-radius: 16px;
      overflow: hidden;
      border: 1px solid #282C37;
    }}
    .header {{
      background: linear-gradient(135deg, #2A2415 0%, #15181F 100%);
      padding: 32px 24px;
      text-align: center;
      border-bottom: 1px solid #3A321E;
    }}
    .logo-badge {{
      display: inline-block;
      width: 52px;
      height: 52px;
      line-height: 52px;
      border-radius: 50%;
      background: linear-gradient(135deg, #D4AF37 0%, #AA820A 100%);
      font-size: 26px;
      margin-bottom: 12px;
    }}
    .brand-title {{
      color: #D4AF37;
      font-size: 22px;
      font-weight: 800;
      letter-spacing: 1px;
      margin: 0 0 4px;
    }}
    .badge-success {{
      display: inline-block;
      background: rgba(40, 167, 69, 0.15);
      color: #4ADE80;
      border: 1px solid rgba(74, 222, 128, 0.3);
      font-size: 12px;
      font-weight: 700;
      padding: 4px 14px;
      border-radius: 20px;
      margin-top: 10px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }}
    .content {{
      padding: 28px 24px;
    }}
    .greeting {{
      font-size: 16px;
      color: #FFFFFF;
      margin-bottom: 16px;
    }}
    .summary-card {{
      background-color: #0B0D11;
      border: 1px solid #2A2F3D;
      border-radius: 12px;
      padding: 20px;
      margin-bottom: 24px;
    }}
    .summary-row {{
      display: flex;
      justify-content: space-between;
      margin-bottom: 10px;
      font-size: 14px;
    }}
    .summary-row:last-child {{
      margin-bottom: 0;
      padding-top: 12px;
      border-top: 1px solid #242936;
      font-weight: 700;
      font-size: 16px;
      color: #D4AF37;
    }}
    .label {{ color: #94A3B8; }}
    .val {{ color: #F8FAFC; font-weight: 600; }}
    .table-container {{
      width: 100%;
      border-collapse: collapse;
      margin-bottom: 24px;
    }}
    .table-container th {{
      background-color: #212631;
      color: #CBD5E1;
      font-size: 12px;
      text-transform: uppercase;
      padding: 10px 12px;
      text-align: left;
    }}
    .table-container td {{
      padding: 12px;
      border-bottom: 1px solid #232734;
      font-size: 13px;
      color: #E2E8F0;
    }}
    .vault-box {{
      background: rgba(212, 175, 55, 0.08);
      border: 1px solid rgba(212, 175, 55, 0.25);
      border-radius: 10px;
      padding: 14px;
      margin-bottom: 24px;
      font-size: 12px;
      color: #D4AF37;
      line-height: 1.5;
    }}
    .footer {{
      background-color: #101217;
      padding: 20px 24px;
      text-align: center;
      font-size: 12px;
      color: #64748B;
      border-top: 1px solid #232734;
    }}
    .footer a {{ color: #D4AF37; text-decoration: none; }}
  </style>
</head>
<body>
  <div style="padding: 20px 10px;">
    <div class="wrapper">
      <div class="header">
        <div class="logo-badge">{metal_icon}</div>
        <div class="brand-title">AURUM GOLD &amp; SILVERS</div>
        <div style="color: #94A3B8; font-size: 13px;">Official Payment Receipt &amp; Tax Invoice</div>
        <div class="badge-success">&#x2713; Payment Successful</div>
      </div>

      <div class="content">
        <div class="greeting">
          Dear <strong>{user_name}</strong>,<br/>
          Thank you for investing with AGS Gold. Your payment has been received, and <strong>{grams:.4f} grams</strong> of pure {metal_name} have been deposited into your secure digital vault.
        </div>

        <div class="summary-card">
          <div class="summary-row">
            <span class="label">Invoice Number</span>
            <span class="val">{invoice_number}</span>
          </div>
          <div class="summary-row">
            <span class="label">Order Reference</span>
            <span class="val">{order_ref}</span>
          </div>
          <div class="summary-row">
            <span class="label">Transaction Date</span>
            <span class="val">{date_str}</span>
          </div>
          <div class="summary-row">
            <span class="label">Payment ID</span>
            <span class="val">{payment_id}</span>
          </div>
          <div class="summary-row">
            <span class="label">Bank Reference (UTR)</span>
            <span class="val">{bank_rrn}</span>
          </div>
          <div class="summary-row">
            <span class="label">Total Paid (Incl. GST)</span>
            <span class="val">&#x20B9;{_format_inr(total_amount)}</span>
          </div>
        </div>

        <table class="table-container">
          <thead>
            <tr>
              <th>Metal Item</th>
              <th>Weight</th>
              <th>Rate / g</th>
              <th>Total</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>
                <strong>{metal_name}</strong><br/>
                <small style="color: #94A3B8;">99.9% Purity &bull; HSN: 7108</small>
              </td>
              <td>{grams:.4f} g</td>
              <td>&#x20B9;{_format_inr(rate)}</td>
              <td><strong>&#x20B9;{_format_inr(total_amount)}</strong></td>
            </tr>
          </tbody>
        </table>

        <div style="margin-bottom: 24px; padding: 12px; background: #1C202A; border-radius: 8px; font-size: 13px;">
          <div style="display: flex; justify-content: space-between; margin-bottom: 6px;">
            <span style="color: #94A3B8;">Taxable Metal Value:</span>
            <span>&#x20B9;{_format_inr(metal_value)}</span>
          </div>
          <div style="display: flex; justify-content: space-between; margin-bottom: 6px;">
            <span style="color: #94A3B8;">GST (3% - 1.5% CGST + 1.5% SGST):</span>
            <span>&#x20B9;{_format_inr(gst_amount)}</span>
          </div>
          <div style="display: flex; justify-content: space-between; font-weight: 700; color: #D4AF37; font-size: 15px; border-top: 1px solid #2D3342; padding-top: 8px;">
            <span>Total INR:</span>
            <span>&#x20B9;{_format_inr(total_amount)}</span>
          </div>
        </div>

        <div class="vault-box">
          &#x1F512; <strong>Insured Bullion Vault Custody:</strong> Your physical gold is safeguarded in institutional-grade vaults insured by national carriers. You can sell back or order physical delivery anytime via the AGS Gold App.
        </div>

        <p style="font-size: 13px; color: #94A3B8; text-align: center;">
          &#x1F4CE; <strong>Note:</strong> Your official printable PDF tax invoice is attached to this email.
        </p>
      </div>

      <div class="footer">
        &copy; 2026 Aurum Gold &amp; Silvers (AGS Gold). All rights reserved.<br/>
        82B, South Masi Street, Madurai - 625 001 &bull; <a href="mailto:aurumgoldsilver@gmail.com">aurumgoldsilver@gmail.com</a><br/>
        Tel: 99437 95005
      </div>
    </div>
  </div>
</body>
</html>
"""
