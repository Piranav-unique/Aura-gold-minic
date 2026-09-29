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


def _format_grams(val) -> str:
    if val is None:
        return "0.0000"
    try:
        d = Decimal(str(val))
        s = f"{d:.6f}".rstrip("0")
        if s.endswith("."):
            s += "0000"
        parts = s.split(".")
        if len(parts) == 2 and len(parts[1]) < 4:
            s = f"{parts[0]}.{parts[1].ljust(4, '0')}"
        return s
    except Exception:
        return "0.0000"


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
    cw = [W * 0.36, W * 0.12, W * 0.13, W * 0.13, W * 0.12, W * 0.14]
    items_data = [
        [Paragraph(h, th_style) for h in
         ["Item Description", "Weight", "Rate / Gram", "Metal Value", "GST (3%)", "Total (INR)"]],
        [
            Paragraph(
                f"<b>{metal_name}</b><br/>"
                f"<font size='7' color='#6C757D'>Insured Custody Vault</font>",
                td_style,
            ),
            Paragraph(f"{_format_grams(grams)} g", td_style),
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
    metal_purity = "99.9% Purity (24 Karat) &bull; HSN: 7108" if is_gold else "99.9% Purity &bull; HSN: 7106"
    metal_short = "24K digital gold" if is_gold else "digital silver"
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
    bank_rrn_raw = getattr(order, "bank_rrn", "") or ""
    bank_rrn_display = bank_rrn_raw if bank_rrn_raw and bank_rrn_raw.upper() != "N/A" else "—"

    return f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Payment Receipt &amp; Tax Invoice - Aurum Gold &amp; Silvers</title>
  <style>
    body {{
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      margin: 0; padding: 0;
      background-color: #0B0D13; color: #E2E8F0;
    }}
    .wrapper {{
      width: 100%; max-width: 600px; margin: 0 auto;
      background-color: #151821; border-radius: 16px;
      overflow: hidden; border: 1px solid #252A36;
    }}
    .header {{
      background: linear-gradient(135deg, #261F12 0%, #12141A 100%);
      padding: 30px 24px 24px; text-align: center;
      border-bottom: 1px solid #332B1A;
    }}
    .logo-badge {{
      display: inline-block; width: 50px; height: 50px; line-height: 50px;
      border-radius: 50%;
      background: linear-gradient(135deg, #D4AF37 0%, #AA820A 100%);
      font-size: 24px; margin-bottom: 10px;
    }}
    .brand-title {{ color: #D4AF37; font-size: 21px; font-weight: 800; letter-spacing: 1px; margin: 0 0 4px; }}
    .badge-success {{
      display: inline-block;
      background: rgba(40,167,69,0.15); color: #4ADE80;
      border: 1px solid rgba(74,222,128,0.3);
      font-size: 12px; font-weight: 700; padding: 4px 14px;
      border-radius: 20px; margin-top: 10px;
      text-transform: uppercase; letter-spacing: 0.5px;
    }}
    .content {{ padding: 26px 24px; }}
    .footer {{
      background-color: #0E1015; padding: 22px 24px; text-align: center;
      font-size: 12px; color: #64748B; border-top: 1px solid #20242F; line-height: 1.6;
    }}
    .footer a {{ color: #D4AF37; text-decoration: none; }}
  </style>
</head>
<body>
  <div style="padding: 24px 12px; background-color: #0B0D13;">
    <div class="wrapper">
      <div class="header">
        <div class="logo-badge">{metal_icon}</div>
        <div class="brand-title">AURUM GOLD &amp; SILVERS</div>
        <div style="color: #94A3B8; font-size: 13px; margin-top: 2px;">Official Payment Receipt &amp; Tax Invoice</div>
        <div class="badge-success">&#x2713; Payment Successful</div>
      </div>

      <div class="content">
        <p style="margin: 0 0 16px 0; font-size: 15px; color: #FFFFFF; line-height: 1.6;">
          Dear <strong>{user_name}</strong>,
        </p>
        <p style="margin: 0 0 14px 0; font-size: 14px; color: #CBD5E1; line-height: 1.6;">
          Thank you for choosing <strong>Aurum Gold &amp; Silvers</strong>. We are pleased to confirm that your payment of <strong style="color: #FFFFFF;">&#x20B9;{_format_inr(total_amount)}</strong> has been received successfully.
        </p>
        <p style="margin: 0 0 22px 0; font-size: 14px; color: #CBD5E1; line-height: 1.6;">
          A total of <strong style="color: #D4AF37;">{grams:.4f} grams</strong> of {metal_short} has been credited to your secure digital locker.
        </p>

        <!-- Payment & Order Metadata Table (Email-safe tables to prevent text overlap) -->
        <div style="background-color: #0E1117; border: 1px solid #222734; border-radius: 12px; padding: 16px 18px; margin-bottom: 22px;">
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="width: 100%; border-collapse: collapse;">
            <tr>
              <td style="padding: 7px 0; color: #8E9BAE; font-size: 13px; text-align: left; border-bottom: 1px solid #1C202C;">Invoice Number</td>
              <td style="padding: 7px 0; color: #FFFFFF; font-size: 13px; font-weight: 600; text-align: right; border-bottom: 1px solid #1C202C; font-family: monospace;">{invoice_number}</td>
            </tr>
            <tr>
              <td style="padding: 7px 0; color: #8E9BAE; font-size: 13px; text-align: left; border-bottom: 1px solid #1C202C;">Order Reference</td>
              <td style="padding: 7px 0; color: #CBD5E1; font-size: 13px; text-align: right; border-bottom: 1px solid #1C202C; font-family: monospace;">{order_ref}</td>
            </tr>
            <tr>
              <td style="padding: 7px 0; color: #8E9BAE; font-size: 13px; text-align: left; border-bottom: 1px solid #1C202C;">Transaction Date</td>
              <td style="padding: 7px 0; color: #CBD5E1; font-size: 13px; text-align: right; border-bottom: 1px solid #1C202C;">{date_str}</td>
            </tr>
            <tr>
              <td style="padding: 7px 0; color: #8E9BAE; font-size: 13px; text-align: left; border-bottom: 1px solid #1C202C;">Payment ID</td>
              <td style="padding: 7px 0; color: #CBD5E1; font-size: 13px; text-align: right; border-bottom: 1px solid #1C202C; font-family: monospace;">{payment_id}</td>
            </tr>
            <tr>
              <td style="padding: 7px 0; color: #8E9BAE; font-size: 13px; text-align: left; border-bottom: 1px solid #1C202C;">Bank Reference (UTR)</td>
              <td style="padding: 7px 0; color: #CBD5E1; font-size: 13px; text-align: right; border-bottom: 1px solid #1C202C; font-family: monospace;">{bank_rrn_display}</td>
            </tr>
            <tr>
              <td style="padding: 10px 0 2px 0; color: #FFFFFF; font-size: 14px; font-weight: 600; text-align: left;">Total Paid (Incl. GST)</td>
              <td style="padding: 10px 0 2px 0; color: #D4AF37; font-size: 16px; font-weight: 700; text-align: right;">&#x20B9;{_format_inr(total_amount)}</td>
            </tr>
          </table>
        </div>

        <!-- Purchased Item Table -->
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="width: 100%; border-collapse: collapse; margin-bottom: 20px; border: 1px solid #282C37; border-radius: 8px; overflow: hidden;">
          <thead>
            <tr style="background-color: #6B1B25;">
              <th style="padding: 10px 14px; color: #FFFFFF; font-size: 12px; font-weight: 700; text-transform: uppercase; text-align: left; letter-spacing: 0.5px;">Metal Item</th>
              <th style="padding: 10px 14px; color: #FFFFFF; font-size: 12px; font-weight: 700; text-transform: uppercase; text-align: center; letter-spacing: 0.5px;">Weight</th>
              <th style="padding: 10px 14px; color: #FFFFFF; font-size: 12px; font-weight: 700; text-transform: uppercase; text-align: right; letter-spacing: 0.5px;">Rate / g</th>
              <th style="padding: 10px 14px; color: #FFFFFF; font-size: 12px; font-weight: 700; text-transform: uppercase; text-align: right; letter-spacing: 0.5px;">Total</th>
            </tr>
          </thead>
          <tbody>
            <tr style="background-color: #12151B;">
              <td style="padding: 14px; border-top: 1px solid #282C37; font-size: 13px; color: #FFFFFF; text-align: left;">
                <strong style="color: #FFFFFF; font-size: 14px;">{metal_name}</strong><br/>
                <span style="font-size: 11px; color: #94A3B8;">{metal_purity}</span>
              </td>
              <td style="padding: 14px; border-top: 1px solid #282C37; font-size: 13px; color: #FFFFFF; text-align: center; font-weight: 600;">{grams:.4f} g</td>
              <td style="padding: 14px; border-top: 1px solid #282C37; font-size: 13px; color: #E2E8F0; text-align: right;">&#x20B9;{_format_inr(rate)}</td>
              <td style="padding: 14px; border-top: 1px solid #282C37; font-size: 14px; color: #D4AF37; text-align: right; font-weight: 700;">&#x20B9;{_format_inr(total_amount)}</td>
            </tr>
          </tbody>
        </table>

        <!-- Tax Breakdown (Explicit high-contrast colors to eliminate invisible text) -->
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="width: 100%; border-collapse: collapse; margin-bottom: 22px; background-color: #12151B; border: 1px solid #242936; border-radius: 8px;">
          <tr>
            <td style="padding: 10px 16px 4px 16px; color: #94A3B8; font-size: 13px; text-align: left;">Taxable Metal Value</td>
            <td style="padding: 10px 16px 4px 16px; color: #F8FAFC; font-size: 13px; font-weight: 600; text-align: right;">&#x20B9;{_format_inr(metal_value)}</td>
          </tr>
          <tr>
            <td style="padding: 4px 16px 10px 16px; color: #94A3B8; font-size: 13px; text-align: left;">GST (3% &bull; 1.5% CGST + 1.5% SGST)</td>
            <td style="padding: 4px 16px 10px 16px; color: #F8FAFC; font-size: 13px; font-weight: 600; text-align: right;">&#x20B9;{_format_inr(gst_amount)}</td>
          </tr>
          <tr>
            <td colspan="2" style="padding: 0 16px;"><div style="border-top: 1px solid #242936;"></div></td>
          </tr>
          <tr>
            <td style="padding: 10px 16px; color: #D4AF37; font-size: 14px; font-weight: 700; text-align: left;">Total INR</td>
            <td style="padding: 10px 16px; color: #D4AF37; font-size: 16px; font-weight: 800; text-align: right;">&#x20B9;{_format_inr(total_amount)}</td>
          </tr>
        </table>

        <!-- Security & Human Support Reassurance -->
        <div style="background-color: #161A22; border-left: 3px solid #D4AF37; border-radius: 4px; padding: 14px 16px; margin-bottom: 20px;">
          <div style="font-size: 13px; font-weight: 700; color: #D4AF37; margin-bottom: 4px;">Insured Bullion Vault Custody</div>
          <div style="font-size: 13px; color: #CBD5E1; line-height: 1.5;">
            Your physical gold is 100% physically backed, 24 Karat certified (999 fineness), and safeguarded in institutional-grade vaults. You can monitor your portfolio, sell back at live rates, or request doorstep physical delivery anytime through your Aurum Gold mobile app.
          </div>
        </div>

        <div style="font-size: 13px; color: #94A3B8; line-height: 1.6; margin-bottom: 22px;">
          <p style="margin: 0 0 10px 0;">
            Your official GST Tax Invoice (PDF) is attached to this email for your accounting and taxation records.
          </p>
          <p style="margin: 0;">
            If you have any questions or need help with your account, feel free to reply directly to this email or speak with our team at <strong style="color: #E2E8F0;">+91 99437 95005</strong>.
          </p>
        </div>

        <div style="border-top: 1px solid #242936; padding-top: 16px; margin-bottom: 6px;">
          <div style="font-size: 13px; color: #94A3B8;">Warm regards,</div>
          <div style="font-size: 14px; font-weight: 700; color: #FFFFFF; margin-top: 3px;">Team Aurum Gold &amp; Silvers</div>
          <div style="font-size: 12px; color: #64748B; margin-top: 2px;">Madurai, Tamil Nadu</div>
        </div>
      </div>

      <div class="footer">
        &copy; 2026 Aurum Gold &amp; Silvers. All rights reserved.<br/>
        82B, South Masi Street, Madurai - 625 001 &bull;
        <a href="mailto:aurumgoldsilver@gmail.com">aurumgoldsilver@gmail.com</a><br/>
        Customer Support: +91 99437 95005
      </div>
    </div>
  </div>
</body>
</html>
"""

