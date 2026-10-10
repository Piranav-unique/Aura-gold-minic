from __future__ import annotations

import io
from datetime import datetime, timezone
from decimal import Decimal
from pathlib import Path
from typing import TYPE_CHECKING, Any

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.utils import ImageReader
from reportlab.platypus import HRFlowable, Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle

if TYPE_CHECKING:
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
    """Generate a formal, professional corporate Tax Invoice & Bill Receipt HTML email."""
    user_name = _user_display_name(user)
    buyer_mobile = getattr(user, "mobile_number", None) or getattr(order, "customer_contact", None) or "—"
    if buyer_mobile != "—" and not str(buyer_mobile).startswith("+"):
        buyer_mobile = f"+91 {buyer_mobile}"
    buyer_email = getattr(user, "email", None) or "—"

    inv_id = str(order.id).replace("-", "")[:8].upper()
    invoice_number = f"INV-AGS-{inv_id}"
    paid_dt = order.paid_at or order.created_at or datetime.now(timezone.utc)
    date_str = paid_dt.strftime("%d %b %Y, %I:%M %p")

    is_gold = (order.metal or "gold").lower() == "gold"
    metal_name = "24K Pure Bullion Gold (99.9% / 999.0 Fineness)" if is_gold else "Pure Bullion Silver (99.9% / 999.0 Fineness)"
    hsn_code = "7108" if is_gold else "7106"

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

    cgst = (gst_amount / Decimal("2")).quantize(Decimal("0.01"))
    sgst = gst_amount - cgst

    order_ref = getattr(order, "razorpay_order_id", "") or "N/A"
    payment_id = getattr(order, "razorpay_payment_id", "") or "—"
    payment_method = (getattr(order, "payment_method", "") or "Online / UPI").upper()
    bank_rrn_raw = getattr(order, "bank_rrn", "") or ""
    bank_rrn_display = bank_rrn_raw if bank_rrn_raw and bank_rrn_raw.upper() != "N/A" else "—"

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="color-scheme" content="light only">
  <meta name="supported-color-schemes" content="light only">
  <title>Tax Invoice #{invoice_number} - Aurum Gold &amp; Silvers</title>
</head>
<body style="margin: 0; padding: 0; background-color: #F3F4F6; font-family: Arial, Helvetica, sans-serif; color: #111827; -webkit-font-smoothing: antialiased;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color: #F3F4F6; padding: 24px 12px;">
    <tr>
      <td align="center">
        <!-- Main Invoice Sheet -->
        <table role="presentation" width="640" cellpadding="0" cellspacing="0" border="0" style="width: 100%; max-width: 640px; background-color: #FFFFFF; border: 1px solid #D1D5DB; border-collapse: collapse;">

          <!-- Top Corporate Accent Bar -->
          <tr>
            <td style="background-color: #7A1E2A; height: 6px; font-size: 1px; line-height: 1px;">&nbsp;</td>
          </tr>

          <!-- Company Letterhead & Document Title -->
          <tr>
            <td style="padding: 24px 28px 18px 28px; border-bottom: 2px solid #111827;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td valign="top" style="text-align: left;">
                    <div style="font-size: 19px; font-weight: 700; color: #7A1E2A; letter-spacing: 0.4px; text-transform: uppercase;">
                      AURUM GOLD &amp; SILVERS
                    </div>
                    <div style="font-size: 11.5px; color: #4B5563; margin-top: 4px; line-height: 1.5;">
                      82B, South Masi Street, Madurai &ndash; 625 001, Tamil Nadu<br/>
                      Phone: +91 99437 95005 &nbsp;|&nbsp; Email: aurumgoldsilver@gmail.com
                    </div>
                  </td>
                  <td valign="top" style="text-align: right;">
                    <div style="font-size: 16px; font-weight: 700; color: #111827; letter-spacing: 0.5px; text-transform: uppercase;">
                      TAX INVOICE
                    </div>
                    <div style="font-size: 11px; color: #6B7280; margin-top: 2px;">
                      Original for Recipient
                    </div>
                    <div style="margin-top: 8px; display: inline-block; padding: 3px 10px; background-color: #ECFDF5; border: 1px solid #A7F3D0; color: #065F46; font-size: 11px; font-weight: 700; letter-spacing: 0.4px;">
                      STATUS: PAID
                    </div>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Greeting / Intro Line -->
          <tr>
            <td style="padding: 18px 28px 10px 28px; font-size: 13px; color: #374151; line-height: 1.5;">
              Dear <strong style="color: #111827;">{user_name}</strong>,<br/>
              Please find below the official Tax Invoice and payment settlement statement for your bullion purchase. A printable A4 copy is also attached as a PDF document.
            </td>
          </tr>

          <!-- Two-Column Billed To & Invoice Details -->
          <tr>
            <td style="padding: 8px 28px 18px 28px;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="border: 1px solid #D1D5DB; border-collapse: collapse;">
                <tr style="background-color: #F9FAFB;">
                  <td width="48%" style="padding: 8px 12px; font-size: 11px; font-weight: 700; color: #374151; text-transform: uppercase; border-bottom: 1px solid #D1D5DB; border-right: 1px solid #D1D5DB; letter-spacing: 0.3px;">
                    Billed To (Customer)
                  </td>
                  <td width="52%" style="padding: 8px 12px; font-size: 11px; font-weight: 700; color: #374151; text-transform: uppercase; border-bottom: 1px solid #D1D5DB; letter-spacing: 0.3px;">
                    Invoice &amp; Settlement Details
                  </td>
                </tr>
                <tr>
                  <td valign="top" style="padding: 12px; font-size: 12.5px; color: #1F2937; line-height: 1.65; border-right: 1px solid #D1D5DB;">
                    <strong>Name:</strong> {user_name}<br/>
                    <strong>Mobile:</strong> {buyer_mobile}<br/>
                    <strong>Email:</strong> {buyer_email}<br/>
                    <strong>Place of Supply:</strong> Tamil Nadu (33)
                  </td>
                  <td valign="top" style="padding: 12px; font-size: 12px; color: #1F2937; line-height: 1.65;">
                    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                      <tr>
                        <td style="color: #6B7280; padding-bottom: 2px;">Invoice No.:</td>
                        <td style="text-align: right; font-weight: 700; color: #111827; font-family: 'Courier New', Courier, monospace; padding-bottom: 2px;">{invoice_number}</td>
                      </tr>
                      <tr>
                        <td style="color: #6B7280; padding-bottom: 2px;">Invoice Date:</td>
                        <td style="text-align: right; color: #111827; padding-bottom: 2px;">{date_str}</td>
                      </tr>
                      <tr>
                        <td style="color: #6B7280; padding-bottom: 2px;">Order Ref.:</td>
                        <td style="text-align: right; color: #111827; font-family: 'Courier New', Courier, monospace; padding-bottom: 2px;">{order_ref}</td>
                      </tr>
                      <tr>
                        <td style="color: #6B7280; padding-bottom: 2px;">Payment ID:</td>
                        <td style="text-align: right; color: #111827; font-family: 'Courier New', Courier, monospace; padding-bottom: 2px;">{payment_id}</td>
                      </tr>
                      <tr>
                        <td style="color: #6B7280; padding-bottom: 2px;">Payment Mode:</td>
                        <td style="text-align: right; color: #111827; padding-bottom: 2px;">{payment_method}</td>
                      </tr>
                      <tr>
                        <td style="color: #6B7280;">Bank UTR / RRN:</td>
                        <td style="text-align: right; color: #111827; font-family: 'Courier New', Courier, monospace;">{bank_rrn_display}</td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Itemized Bill & Tax Table -->
          <tr>
            <td style="padding: 0 28px 20px 28px;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="border: 1px solid #D1D5DB; border-collapse: collapse;">
                <thead>
                  <tr style="background-color: #1F2937; color: #FFFFFF;">
                    <th style="padding: 9px 10px; font-size: 11px; font-weight: 700; text-transform: uppercase; text-align: center; border-right: 1px solid #374151; width: 6%;">#</th>
                    <th style="padding: 9px 10px; font-size: 11px; font-weight: 700; text-transform: uppercase; text-align: left; border-right: 1px solid #374151; width: 40%;">Description of Goods</th>
                    <th style="padding: 9px 10px; font-size: 11px; font-weight: 700; text-transform: uppercase; text-align: center; border-right: 1px solid #374151; width: 10%;">HSN</th>
                    <th style="padding: 9px 10px; font-size: 11px; font-weight: 700; text-transform: uppercase; text-align: right; border-right: 1px solid #374151; width: 14%;">Qty (g)</th>
                    <th style="padding: 9px 10px; font-size: 11px; font-weight: 700; text-transform: uppercase; text-align: right; border-right: 1px solid #374151; width: 15%;">Rate / g (&#x20B9;)</th>
                    <th style="padding: 9px 10px; font-size: 11px; font-weight: 700; text-transform: uppercase; text-align: right; width: 15%;">Amount (&#x20B9;)</th>
                  </tr>
                </thead>
                <tbody>
                  <tr>
                    <td valign="top" style="padding: 12px 10px; font-size: 12.5px; color: #374151; text-align: center; border-bottom: 1px solid #D1D5DB; border-right: 1px solid #D1D5DB;">1</td>
                    <td valign="top" style="padding: 12px 10px; font-size: 12.5px; color: #111827; text-align: left; border-bottom: 1px solid #D1D5DB; border-right: 1px solid #D1D5DB;">
                      <strong>{metal_name}</strong><br/>
                      <span style="font-size: 11px; color: #6B7280;">Allocated Vault Bullion &bull; Immediate Custody Credit</span>
                    </td>
                    <td valign="top" style="padding: 12px 10px; font-size: 12.5px; color: #374151; text-align: center; border-bottom: 1px solid #D1D5DB; border-right: 1px solid #D1D5DB;">{hsn_code}</td>
                    <td valign="top" style="padding: 12px 10px; font-size: 12.5px; color: #111827; font-weight: 600; text-align: right; border-bottom: 1px solid #D1D5DB; border-right: 1px solid #D1D5DB;">{_format_grams(grams)}</td>
                    <td valign="top" style="padding: 12px 10px; font-size: 12.5px; color: #374151; text-align: right; border-bottom: 1px solid #D1D5DB; border-right: 1px solid #D1D5DB;">{_format_inr(rate)}</td>
                    <td valign="top" style="padding: 12px 10px; font-size: 12.5px; color: #111827; font-weight: 600; text-align: right; border-bottom: 1px solid #D1D5DB;">{_format_inr(metal_value)}</td>
                  </tr>

                  <!-- Tax Breakdown Rows -->
                  <tr>
                    <td colspan="4" rowspan="4" valign="top" style="padding: 12px; font-size: 11.5px; color: #4B5563; line-height: 1.5; border-right: 1px solid #D1D5DB; border-bottom: 1px solid #D1D5DB; background-color: #F9FAFB;">
                      <strong>Custody &amp; Allocation Note:</strong><br/>
                      <strong>{_format_grams(grams)} grams</strong> of certified bullion has been credited to your account locker. Physical bullion is 100% backed and stored in insured vault custody.
                    </td>
                    <td style="padding: 7px 10px; font-size: 12px; color: #4B5563; text-align: right; border-bottom: 1px solid #E5E7EB; border-right: 1px solid #D1D5DB;">Taxable Value</td>
                    <td style="padding: 7px 10px; font-size: 12px; color: #111827; text-align: right; border-bottom: 1px solid #E5E7EB;">&#x20B9;{_format_inr(metal_value)}</td>
                  </tr>
                  <tr>
                    <td style="padding: 7px 10px; font-size: 12px; color: #4B5563; text-align: right; border-bottom: 1px solid #E5E7EB; border-right: 1px solid #D1D5DB;">CGST (1.5%)</td>
                    <td style="padding: 7px 10px; font-size: 12px; color: #111827; text-align: right; border-bottom: 1px solid #E5E7EB;">&#x20B9;{_format_inr(cgst)}</td>
                  </tr>
                  <tr>
                    <td style="padding: 7px 10px; font-size: 12px; color: #4B5563; text-align: right; border-bottom: 1px solid #E5E7EB; border-right: 1px solid #D1D5DB;">SGST (1.5%)</td>
                    <td style="padding: 7px 10px; font-size: 12px; color: #111827; text-align: right; border-bottom: 1px solid #E5E7EB;">&#x20B9;{_format_inr(sgst)}</td>
                  </tr>
                  <tr>
                    <td style="padding: 7px 10px; font-size: 12px; color: #4B5563; text-align: right; border-bottom: 1px solid #D1D5DB; border-right: 1px solid #D1D5DB;">Total GST (3.0%)</td>
                    <td style="padding: 7px 10px; font-size: 12px; color: #111827; text-align: right; border-bottom: 1px solid #D1D5DB;">&#x20B9;{_format_inr(gst_amount)}</td>
                  </tr>

                  <!-- Grand Total Row -->
                  <tr style="background-color: #FEFCE8;">
                    <td colspan="4" style="padding: 10px 12px; font-size: 12px; font-weight: 700; color: #111827; text-align: right; border-right: 1px solid #D1D5DB; text-transform: uppercase;">
                      Total Invoice Amount (Inclusive of GST)
                    </td>
                    <td colspan="2" style="padding: 10px 12px; font-size: 15px; font-weight: 700; color: #7A1E2A; text-align: right;">
                      &#x20B9;{_format_inr(total_amount)}
                    </td>
                  </tr>
                </tbody>
              </table>
            </td>
          </tr>

          <!-- Declarations & Signatory -->
          <tr>
            <td style="padding: 0 28px 22px 28px;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td width="62%" valign="top" style="font-size: 11px; color: #4B5563; line-height: 1.55; padding-right: 16px;">
                    <strong style="color: #111827;">Terms &amp; Declaration:</strong><br/>
                    1. We declare that this invoice shows the actual price of the goods described and that all particulars are true and correct.<br/>
                    2. All disputes are subject to Madurai, Tamil Nadu jurisdiction only.<br/>
                    3. This is a computer-generated Tax Invoice and requires no physical signature.
                  </td>
                  <td width="38%" valign="bottom" style="text-align: right; font-size: 11.5px; color: #111827;">
                    <div style="font-weight: 700; color: #7A1E2A;">For AURUM GOLD &amp; SILVERS</div>
                    <div style="margin-top: 24px; font-size: 11px; color: #6B7280; border-top: 1px solid #D1D5DB; display: inline-block; padding-top: 4px;">
                      Authorized Signatory
                    </div>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Footer Bar -->
          <tr>
            <td style="background-color: #F9FAFB; border-top: 1px solid #E5E7EB; padding: 14px 28px; text-align: center; font-size: 11px; color: #6B7280; line-height: 1.5;">
              Aurum Gold &amp; Silvers &bull; 82B, South Masi Street, Madurai &ndash; 625 001 &bull; Support: +91 99437 95005 &bull;
              <a href="mailto:aurumgoldsilver@gmail.com" style="color: #7A1E2A; text-decoration: none;">aurumgoldsilver@gmail.com</a>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>
"""


