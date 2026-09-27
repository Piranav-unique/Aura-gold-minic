import io
from datetime import datetime, timezone
from decimal import Decimal
from typing import Any

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.platypus import HRFlowable, Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle

from app.models.payment_order import PaymentOrder
from app.models.user import User


def _format_inr(val: Decimal | float | int | None) -> str:
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
    if name:
        return name
    return "Customer"


def generate_invoice_pdf(order: PaymentOrder, user: User) -> bytes:
    """Generate a clean, official A4 PDF Tax Invoice / Payment Receipt for a metal purchase."""
    buffer = io.BytesIO()
    doc = SimpleDocTemplate(
        buffer,
        pagesize=A4,
        leftMargin=36,
        rightMargin=36,
        topMargin=36,
        bottomMargin=36,
    )

    styles = getSampleStyleSheet()

    # Custom styles
    gold_color = colors.HexColor("#B8860B")
    dark_color = colors.HexColor("#1A1D24")
    gray_bg = colors.HexColor("#F8F9FA")
    text_muted = colors.HexColor("#6C757D")

    title_style = ParagraphStyle(
        "InvoiceTitle",
        parent=styles["Heading1"],
        fontName="Helvetica-Bold",
        fontSize=18,
        leading=22,
        textColor=gold_color,
    )
    subtitle_style = ParagraphStyle(
        "InvoiceSubtitle",
        parent=styles["Normal"],
        fontName="Helvetica",
        fontSize=9,
        leading=12,
        textColor=text_muted,
    )
    section_title = ParagraphStyle(
        "SectionTitle",
        parent=styles["Normal"],
        fontName="Helvetica-Bold",
        fontSize=10,
        leading=13,
        textColor=dark_color,
    )
    body_style = ParagraphStyle(
        "InvoiceBody",
        parent=styles["Normal"],
        fontName="Helvetica",
        fontSize=9,
        leading=12,
        textColor=dark_color,
    )
    table_header = ParagraphStyle(
        "TableHeader",
        parent=styles["Normal"],
        fontName="Helvetica-Bold",
        fontSize=9,
        leading=11,
        textColor=colors.white,
    )
    table_cell = ParagraphStyle(
        "TableCell",
        parent=styles["Normal"],
        fontName="Helvetica",
        fontSize=8.5,
        leading=11,
        textColor=dark_color,
    )
    table_cell_bold = ParagraphStyle(
        "TableCellBold",
        parent=styles["Normal"],
        fontName="Helvetica-Bold",
        fontSize=8.5,
        leading=11,
        textColor=dark_color,
    )

    story = []

    # 1. Header: Brand & Document Info
    inv_id = str(order.id).replace("-", "")[:8].upper()
    invoice_number = f"INV-AGS-{inv_id}"
    paid_dt = order.paid_at or order.created_at or datetime.now(timezone.utc)
    date_str = paid_dt.strftime("%d %b %Y, %I:%M %p UTC")

    header_table_data = [
        [
            Paragraph("<b>AURUM GOLD & SILVERS</b><br/><font size='8' color='#6C757D'>AGS Gold • Pure 24K Savings<br/>Coimbatore, Tamil Nadu, India<br/>Support: info@aurumgold.co.in | +91 99437 95005</font>", body_style),
            Paragraph(f"<font color='#B8860B'><b>TAX INVOICE / RECEIPT</b></font><br/><font size='8'><b>Invoice No:</b> {invoice_number}<br/><b>Date:</b> {date_str}<br/><b>Order Ref:</b> {order.razorpay_order_id}</font>", body_style),
        ]
    ]
    header_table = Table(header_table_data, colWidths=[310, 210])
    header_table.setStyle(TableStyle([
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("ALIGN", (1, 0), (1, 0), "RIGHT"),
    ]))
    story.append(header_table)
    story.append(Spacer(1, 14))

    story.append(HRFlowable(width="100%", thickness=1, color=gold_color, spaceAfter=14))

    # 2. Buyer & Payment Details Table
    buyer_name = _user_display_name(user)
    buyer_mobile = getattr(user, "mobile_number", "") or "N/A"
    buyer_email = getattr(user, "email", "") or "N/A"
    payment_id = getattr(order, "razorpay_payment_id", "") or "Completed"
    bank_rrn = getattr(order, "bank_rrn", "") or "N/A"
    payment_method = getattr(order, "payment_method", "") or "UPI / Online"

    info_table_data = [
        [
            Paragraph("<b>BILLED TO (CUSTOMER):</b>", section_title),
            Paragraph("<b>PAYMENT TRANSACTION DETAILS:</b>", section_title),
        ],
        [
            Paragraph(f"<b>Name:</b> {buyer_name}<br/><b>Mobile:</b> +91 {buyer_mobile}<br/><b>Email:</b> {buyer_email}", body_style),
            Paragraph(f"<b>Payment Gateway:</b> Razorpay<br/><b>Payment ID:</b> {payment_id}<br/><b>Payment Mode:</b> {payment_method}<br/><b>Bank Reference (UTR):</b> {bank_rrn}<br/><b>Payment Status:</b> <font color='#28A745'><b>PAID (SUCCESSFUL)</b></font>", body_style),
        ],
    ]
    info_table = Table(info_table_data, colWidths=[260, 260])
    info_table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), gray_bg),
        ("PADDING", (0, 0), (-1, -1), 8),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("BOX", (0, 0), (-1, -1), 0.5, colors.HexColor("#E5E7EB")),
    ]))
    story.append(info_table)
    story.append(Spacer(1, 16))

    # 3. Metal Purchase Line Item
    is_gold = (order.metal or "gold").lower() == "gold"
    metal_name = "24K Pure Digital Gold (99.9% / 999 Fineness)" if is_gold else "Pure Digital Silver (99.9% / 999 Fineness)"
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

    items_data = [
        [
            Paragraph("Item Description", table_header),
            Paragraph("HSN", table_header),
            Paragraph("Weight", table_header),
            Paragraph("Rate / Gram", table_header),
            Paragraph("Metal Value", table_header),
            Paragraph("GST (3%)", table_header),
            Paragraph("Total (INR)", table_header),
        ],
        [
            Paragraph(f"<b>{metal_name}</b><br/><font size='7.5' color='#6C757D'>Stored in Insured Custody Vault</font>", table_cell),
            Paragraph(hsn_code, table_cell),
            Paragraph(f"{grams:.4f} g", table_cell),
            Paragraph(f"INR {_format_inr(rate)}", table_cell),
            Paragraph(f"INR {_format_inr(metal_value)}", table_cell),
            Paragraph(f"INR {_format_inr(gst_amount)}", table_cell),
            Paragraph(f"<b>INR {_format_inr(total_amount)}</b>", table_cell_bold),
        ],
    ]

    items_table = Table(items_data, colWidths=[160, 45, 55, 65, 65, 60, 70])
    items_table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), dark_color),
        ("ALIGN", (1, 0), (-1, -1), "CENTER"),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("PADDING", (0, 0), (-1, -1), 6),
        ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#E5E7EB")),
    ]))
    story.append(items_table)
    story.append(Spacer(1, 14))

    # 4. Tax & Totals Breakdown Table
    summary_data = [
        [Paragraph("Taxable Metal Amount:", body_style), Paragraph(f"INR {_format_inr(metal_value)}", table_cell_bold)],
        [Paragraph("CGST @ 1.5%:", body_style), Paragraph(f"INR {_format_inr(cgst)}", table_cell)],
        [Paragraph("SGST @ 1.5%:", body_style), Paragraph(f"INR {_format_inr(sgst)}", table_cell)],
        [Paragraph("Total GST (3.0%):", body_style), Paragraph(f"INR {_format_inr(gst_amount)}", table_cell)],
        [Paragraph("<b>TOTAL AMOUNT PAID:</b>", section_title), Paragraph(f"<font color='#B8860B'><b>INR {_format_inr(total_amount)}</b></font>", section_title)],
    ]
    summary_table = Table(summary_data, colWidths=[150, 110])
    summary_table.setStyle(TableStyle([
        ("ALIGN", (1, 0), (1, -1), "RIGHT"),
        ("PADDING", (0, 0), (-1, -1), 4),
        ("LINEBELOW", (0, 3), (-1, 3), 0.5, gold_color),
    ]))

    # Wrap summary to right side
    outer_summary = Table([[Paragraph("", body_style), summary_table]], colWidths=[260, 260])
    outer_summary.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "TOP")]))
    story.append(outer_summary)
    story.append(Spacer(1, 20))

    # 5. Security & Vault Certification Notice
    terms_text = (
        "<b>Vault & Custody Certificate:</b><br/>"
        "• Your purchased precious metal is 100% physically backed, allocated, and stored in secure, insured bullion vaults.<br/>"
        "• Purity is certified 24 Karat 99.9% (999 fineness) for Gold, conforming to national bullion standards.<br/>"
        "• You can sell back or withdraw your accumulated gold anytime directly through the AGS Gold mobile application.<br/>"
        "• This is a computer-generated tax invoice and requires no physical signature."
    )
    terms_p = Paragraph(terms_text, ParagraphStyle("Terms", parent=styles["Normal"], fontSize=7.5, leading=10, textColor=text_muted))
    terms_box = Table([[terms_p]], colWidths=[520])
    terms_box.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#FDF9F0")),
        ("PADDING", (0, 0), (-1, -1), 8),
        ("BOX", (0, 0), (-1, -1), 0.5, colors.HexColor("#EEDBB2")),
    ]))
    story.append(terms_box)

    doc.build(story)
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
    metal_icon = "🪙" if is_gold else "🥈"
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
  <title>Payment Receipt & Tax Invoice - AGS Gold</title>
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
    .label {{
      color: #94A3B8;
    }}
    .val {{
      color: #F8FAFC;
      font-weight: 600;
    }}
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
    .footer a {{
      color: #D4AF37;
      text-decoration: none;
    }}
  </style>
</head>
<body>
  <div style="padding: 20px 10px;">
    <div class="wrapper">
      <div class="header">
        <div class="logo-badge">{metal_icon}</div>
        <div class="brand-title">AURUM GOLD & SILVERS</div>
        <div style="color: #94A3B8; font-size: 13px;">Official Payment Receipt & Tax Invoice</div>
        <div class="badge-success">✓ Payment Successful</div>
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
            <span class="val">₹{_format_inr(total_amount)}</span>
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
                <small style="color: #94A3B8;">99.9% Purity • HSN: 7108</small>
              </td>
              <td>{grams:.4f} g</td>
              <td>₹{_format_inr(rate)}</td>
              <td><strong>₹{_format_inr(total_amount)}</strong></td>
            </tr>
          </tbody>
        </table>

        <div style="margin-bottom: 24px; padding: 12px; background: #1C202A; border-radius: 8px; font-size: 13px;">
          <div style="display: flex; justify-content: space-between; margin-bottom: 6px;">
            <span style="color: #94A3B8;">Taxable Metal Value:</span>
            <span>₹{_format_inr(metal_value)}</span>
          </div>
          <div style="display: flex; justify-content: space-between; margin-bottom: 6px;">
            <span style="color: #94A3B8;">GST (3% - 1.5% CGST + 1.5% SGST):</span>
            <span>₹{_format_inr(gst_amount)}</span>
          </div>
          <div style="display: flex; justify-content: space-between; font-weight: 700; color: #D4AF37; font-size: 15px; border-top: 1px solid #2D3342; padding-top: 8px;">
            <span>Total INR:</span>
            <span>₹{_format_inr(total_amount)}</span>
          </div>
        </div>

        <div class="vault-box">
          🔒 <strong>Insured Bullion Vault Custody:</strong> Your physical gold is safeguarded in institutional-grade vaults insured by national carriers. You can sell back or order physical delivery anytime via the AGS Gold App.
        </div>

        <p style="font-size: 13px; color: #94A3B8; text-align: center;">
          📎 <strong>Note:</strong> Your official printable PDF tax invoice is attached to this email.
        </p>
      </div>

      <div class="footer">
        © 2026 Aurum Gold Works (AGS Gold). All rights reserved.<br/>
        Coimbatore, Tamil Nadu, India • <a href="mailto:info@aurumgold.co.in">info@aurumgold.co.in</a><br/>
        Visit: <a href="https://aurumgold.co.in" target="_blank">aurumgold.co.in</a>
      </div>
    </div>
  </div>
</body>
</html>
"""
