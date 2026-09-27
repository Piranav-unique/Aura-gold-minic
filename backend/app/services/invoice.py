import io
from datetime import datetime, timezone
from decimal import Decimal
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.utils import ImageReader
from reportlab.platypus import HRFlowable, Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle

from app.models.payment_order import PaymentOrder
from app.models.user import User

_ASSETS_DIR = Path(__file__).resolve().parent.parent / "assets"
_LETTERHEAD_PATH = _ASSETS_DIR / "letterhead.png"
_LOGO_PATH = _ASSETS_DIR / "ags_logo.png"


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
    """Generate an A4 PDF invoice using the exact AGS letterhead as background."""
    buffer = io.BytesIO()
    PAGE_W, PAGE_H = A4  # 595.27 x 841.89 pt

    # ── Content area (measured from letterhead layout) ──────────────────
    # The letterhead has:
    #   Top bands (maroon+gold): ~42pt
    #   Logo + Company name area: ~150pt  → content starts at ~200pt from top
    #   Bottom contact section:  ~130pt from bottom
    # We add a little padding so text doesn't touch the decorative elements.
    TOP_MARGIN    = 205   # start of invoice content (below logo+name)
    BOTTOM_MARGIN = 135   # space reserved at bottom for contact/bands
    SIDE_MARGIN   = 50

    # ── Draw letterhead as full-page background ───────────────────────
    def draw_background(c, doc):
        c.saveState()
        if _LETTERHEAD_PATH.exists():
            lh = ImageReader(str(_LETTERHEAD_PATH))
            c.drawImage(lh, 0, 0, width=PAGE_W, height=PAGE_H, preserveAspectRatio=False)
        else:
            # Fallback: plain white
            c.setFillColor(colors.white)
            c.rect(0, 0, PAGE_W, PAGE_H, fill=1, stroke=0)
        c.restoreState()

    # ── Colour palette (maroon/gold to match letterhead) ─────────────
    MAROON      = colors.HexColor("#7A1E2A")
    GOLD_ACCENT = colors.HexColor("#B8860B")
    GOLD_LINE   = colors.HexColor("#C8A000")
    DARK        = colors.HexColor("#1A1D24")
    MUTED       = colors.HexColor("#6C757D")
    LIGHT_BG    = colors.HexColor("#FDF8F0")
    BORDER      = colors.HexColor("#E5D8C0")

    # ── Document with margins matching the letterhead content area ───
    doc = SimpleDocTemplate(
        buffer,
        pagesize=A4,
        leftMargin=SIDE_MARGIN,
        rightMargin=SIDE_MARGIN,
        topMargin=TOP_MARGIN,
        bottomMargin=BOTTOM_MARGIN,
    )

    styles = getSampleStyleSheet()

    def _s(name, **kw):
        return ParagraphStyle(name, parent=styles["Normal"], **kw)

    body_style  = _s("Body",   fontName="Helvetica",      fontSize=8.5, leading=12, textColor=DARK)
    label_style = _s("Label",  fontName="Helvetica-Bold", fontSize=8.5, leading=12, textColor=DARK)
    th_style    = _s("TH",     fontName="Helvetica-Bold", fontSize=8.5, leading=11, textColor=colors.white)
    td_style    = _s("TD",     fontName="Helvetica",      fontSize=8.5, leading=11, textColor=DARK)
    td_bold     = _s("TDBold", fontName="Helvetica-Bold", fontSize=8.5, leading=11, textColor=DARK)
    total_style = _s("Total",  fontName="Helvetica-Bold", fontSize=11,  leading=14, textColor=GOLD_ACCENT)

    # ── Invoice data ──────────────────────────────────────────────────
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

    # Usable content width
    W = PAGE_W - SIDE_MARGIN * 2  # 495 pt

    # ── Story ─────────────────────────────────────────────────────────
    story = []

    # Title: "TAX INVOICE" centred
    story.append(Paragraph(
        "<b>TAX INVOICE / PAYMENT RECEIPT</b>",
        _s("InvTitle", fontName="Helvetica-Bold", fontSize=13, leading=16,
           textColor=MAROON, alignment=1),
    ))
    story.append(Spacer(1, 4))
    story.append(HRFlowable(width="100%", thickness=1.5, color=GOLD_LINE, spaceAfter=10))

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
    hdr_table = Table(hdr_data, colWidths=[W * 0.58, W * 0.42])
    hdr_table.setStyle(TableStyle([
        ("VALIGN",     (0, 0), (-1, -1), "MIDDLE"),
        ("ALIGN",      (1, 0), (1, 0),  "RIGHT"),
        ("BACKGROUND", (0, 0), (-1, -1), LIGHT_BG),
        ("BOX",        (0, 0), (-1, -1), 0.5, BORDER),
        ("PADDING",    (0, 0), (-1, -1), 8),
    ]))
    story.append(hdr_table)
    story.append(Spacer(1, 12))

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
    info_table = Table(info_data, colWidths=[W * 0.5, W * 0.5])
    info_table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), MAROON),
        ("BACKGROUND", (0, 1), (-1, 1), LIGHT_BG),
        ("PADDING",    (0, 0), (-1, -1), 8),
        ("VALIGN",     (0, 0), (-1, -1), "TOP"),
        ("BOX",        (0, 0), (-1, -1), 0.5, BORDER),
        ("LINEAFTER",  (0, 0), (0, -1), 0.5, BORDER),
    ]))
    story.append(info_table)
    story.append(Spacer(1, 12))

    # 3. Line Items
    cw = [W * 0.30, W * 0.08, W * 0.10, W * 0.13, W * 0.13, W * 0.12, W * 0.14]
    items_data = [
        [Paragraph(h, th_style) for h in
         ["Item Description", "HSN", "Weight", "Rate / Gram", "Metal Value", "GST (3%)", "Total (INR)"]],
        [
            Paragraph(
                f"<b>{metal_name}</b><br/>"
                f"<font size='7' color='#6C757D'>Insured Custody Vault</font>",
                td_style,
            ),
            Paragraph(hsn_code, td_style),
            Paragraph(f"{grams:.4f} g", td_style),
            Paragraph(f"INR {_format_inr(rate)}", td_style),
            Paragraph(f"INR {_format_inr(metal_value)}", td_style),
            Paragraph(f"INR {_format_inr(gst_amount)}", td_style),
            Paragraph(f"<b>INR {_format_inr(total_amount)}</b>", td_bold),
        ],
    ]
    items_table = Table(items_data, colWidths=cw)
    items_table.setStyle(TableStyle([
        ("BACKGROUND",     (0, 0), (-1, 0), MAROON),
        ("ALIGN",          (1, 0), (-1, -1), "CENTER"),
        ("VALIGN",         (0, 0), (-1, -1), "MIDDLE"),
        ("PADDING",        (0, 0), (-1, -1), 6),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, LIGHT_BG]),
        ("GRID",           (0, 0), (-1, -1), 0.5, BORDER),
    ]))
    story.append(items_table)
    story.append(Spacer(1, 12))

    # 4. Tax Summary (right-aligned)
    sw = W * 0.32
    summary_data = [
        [Paragraph("Taxable Metal Amount:", body_style),   Paragraph(f"INR {_format_inr(metal_value)}", td_bold)],
        [Paragraph("CGST @ 1.5%:",          body_style),   Paragraph(f"INR {_format_inr(cgst)}",        td_style)],
        [Paragraph("SGST @ 1.5%:",          body_style),   Paragraph(f"INR {_format_inr(sgst)}",        td_style)],
        [Paragraph("Total GST (3.0%):",     body_style),   Paragraph(f"INR {_format_inr(gst_amount)}",  td_style)],
        [Paragraph("<b>TOTAL AMOUNT PAID:</b>", label_style),
         Paragraph(f"<b>INR {_format_inr(total_amount)}</b>", total_style)],
    ]
    summary_table = Table(summary_data, colWidths=[sw * 1.2, sw * 0.9])
    summary_table.setStyle(TableStyle([
        ("ALIGN",      (1, 0), (1, -1), "RIGHT"),
        ("PADDING",    (0, 0), (-1, -1), 5),
        ("LINEABOVE",  (0, 4), (-1, 4), 1.5, GOLD_ACCENT),
        ("BACKGROUND", (0, 4), (-1, 4), colors.HexColor("#FDF3DC")),
        ("BOX",        (0, 0), (-1, -1), 0.5, BORDER),
    ]))
    outer_summary = Table([[Paragraph("", body_style), summary_table]],
                          colWidths=[W - sw * 2.1, sw * 2.1])
    outer_summary.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "TOP")]))
    story.append(outer_summary)
    story.append(Spacer(1, 14))

    # 5. Vault notice
    terms_text = (
        "<b>Vault &amp; Custody Certificate:</b><br/>"
        "&#8226; Your purchased metal is 100% physically backed, allocated, and stored in secure, insured bullion vaults.<br/>"
        "&#8226; Purity is certified 24 Karat 99.9% (999 fineness) for Gold, conforming to national bullion standards.<br/>"
        "&#8226; You can sell back or withdraw anytime through the AGS Gold mobile application.<br/>"
        "&#8226; This is a computer-generated tax invoice and requires no physical signature."
    )
    terms_box = Table(
        [[Paragraph(terms_text, _s("Terms", fontSize=7.5, leading=10, textColor=MUTED))]],
        colWidths=[W],
    )
    terms_box.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#FDF8F0")),
        ("BOX",        (0, 0), (-1, -1), 0.5, GOLD_LINE),
        ("PADDING",    (0, 0), (-1, -1), 8),
    ]))
    story.append(terms_box)

    doc.build(story, onFirstPage=draw_background, onLaterPages=draw_background)
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
      margin: 0; padding: 0;
      background-color: #0F1115; color: #E2E8F0;
    }}
    .wrapper {{
      width: 100%; max-width: 600px; margin: 0 auto;
      background-color: #171A21; border-radius: 16px;
      overflow: hidden; border: 1px solid #282C37;
    }}
    .header {{
      background: linear-gradient(135deg, #2A2415 0%, #15181F 100%);
      padding: 32px 24px; text-align: center;
      border-bottom: 1px solid #3A321E;
    }}
    .logo-badge {{
      display: inline-block; width: 52px; height: 52px; line-height: 52px;
      border-radius: 50%;
      background: linear-gradient(135deg, #D4AF37 0%, #AA820A 100%);
      font-size: 26px; margin-bottom: 12px;
    }}
    .brand-title {{ color: #D4AF37; font-size: 22px; font-weight: 800; letter-spacing: 1px; margin: 0 0 4px; }}
    .badge-success {{
      display: inline-block;
      background: rgba(40,167,69,0.15); color: #4ADE80;
      border: 1px solid rgba(74,222,128,0.3);
      font-size: 12px; font-weight: 700; padding: 4px 14px;
      border-radius: 20px; margin-top: 10px;
      text-transform: uppercase; letter-spacing: 0.5px;
    }}
    .content {{ padding: 28px 24px; }}
    .greeting {{ font-size: 16px; color: #FFFFFF; margin-bottom: 16px; }}
    .summary-card {{
      background-color: #0B0D11; border: 1px solid #2A2F3D;
      border-radius: 12px; padding: 20px; margin-bottom: 24px;
    }}
    .summary-row {{
      display: flex; justify-content: space-between; margin-bottom: 10px; font-size: 14px;
    }}
    .summary-row:last-child {{
      margin-bottom: 0; padding-top: 12px; border-top: 1px solid #242936;
      font-weight: 700; font-size: 16px; color: #D4AF37;
    }}
    .label {{ color: #94A3B8; }}
    .val {{ color: #F8FAFC; font-weight: 600; }}
    .table-container {{ width: 100%; border-collapse: collapse; margin-bottom: 24px; }}
    .table-container th {{
      background-color: #7A1E2A; color: #ffffff;
      font-size: 12px; text-transform: uppercase; padding: 10px 12px; text-align: left;
    }}
    .table-container td {{ padding: 12px; border-bottom: 1px solid #232734; font-size: 13px; color: #E2E8F0; }}
    .vault-box {{
      background: rgba(212,175,55,0.08); border: 1px solid rgba(212,175,55,0.25);
      border-radius: 10px; padding: 14px; margin-bottom: 24px;
      font-size: 12px; color: #D4AF37; line-height: 1.5;
    }}
    .footer {{
      background-color: #101217; padding: 20px 24px; text-align: center;
      font-size: 12px; color: #64748B; border-top: 1px solid #232734;
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
          Thank you for investing with AGS Gold. Your payment has been received, and
          <strong>{grams:.4f} grams</strong> of pure {metal_name} have been deposited into your secure digital vault.
        </div>

        <div class="summary-card">
          <div class="summary-row"><span class="label">Invoice Number</span><span class="val">{invoice_number}</span></div>
          <div class="summary-row"><span class="label">Order Reference</span><span class="val">{order_ref}</span></div>
          <div class="summary-row"><span class="label">Transaction Date</span><span class="val">{date_str}</span></div>
          <div class="summary-row"><span class="label">Payment ID</span><span class="val">{payment_id}</span></div>
          <div class="summary-row"><span class="label">Bank Reference (UTR)</span><span class="val">{bank_rrn}</span></div>
          <div class="summary-row">
            <span class="label">Total Paid (Incl. GST)</span>
            <span class="val">&#x20B9;{_format_inr(total_amount)}</span>
          </div>
        </div>

        <table class="table-container">
          <thead>
            <tr><th>Metal Item</th><th>Weight</th><th>Rate / g</th><th>Total</th></tr>
          </thead>
          <tbody>
            <tr>
              <td><strong>{metal_name}</strong><br/><small style="color:#94A3B8;">99.9% Purity &bull; HSN: 7108</small></td>
              <td>{grams:.4f} g</td>
              <td>&#x20B9;{_format_inr(rate)}</td>
              <td><strong>&#x20B9;{_format_inr(total_amount)}</strong></td>
            </tr>
          </tbody>
        </table>

        <div style="margin-bottom:24px;padding:12px;background:#1C202A;border-radius:8px;font-size:13px;">
          <div style="display:flex;justify-content:space-between;margin-bottom:6px;">
            <span style="color:#94A3B8;">Taxable Metal Value:</span><span>&#x20B9;{_format_inr(metal_value)}</span>
          </div>
          <div style="display:flex;justify-content:space-between;margin-bottom:6px;">
            <span style="color:#94A3B8;">GST (3% - 1.5% CGST + 1.5% SGST):</span><span>&#x20B9;{_format_inr(gst_amount)}</span>
          </div>
          <div style="display:flex;justify-content:space-between;font-weight:700;color:#D4AF37;font-size:15px;border-top:1px solid #2D3342;padding-top:8px;">
            <span>Total INR:</span><span>&#x20B9;{_format_inr(total_amount)}</span>
          </div>
        </div>

        <div class="vault-box">
          &#x1F512; <strong>Insured Bullion Vault Custody:</strong>
          Your physical gold is safeguarded in institutional-grade vaults.
          Sell back or order physical delivery anytime via the AGS Gold App.
        </div>

        <p style="font-size:13px;color:#94A3B8;text-align:center;">
          &#x1F4CE; <strong>Note:</strong> Your official printable PDF tax invoice is attached to this email.
        </p>
      </div>

      <div class="footer">
        &copy; 2026 Aurum Gold &amp; Silvers. All rights reserved.<br/>
        82B, South Masi Street, Madurai - 625 001 &bull;
        <a href="mailto:aurumgoldsilver@gmail.com">aurumgoldsilver@gmail.com</a><br/>
        Tel: 99437 95005
      </div>
    </div>
  </div>
</body>
</html>
"""
