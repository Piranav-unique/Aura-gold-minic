import asyncio
from types import SimpleNamespace
from typing import Any
import smtplib
from email.mime.application import MIMEApplication
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.utils import formataddr

import structlog

from app.core.config import settings
from app.core.email_utils import is_placeholder_email
from app.services.invoice import generate_invoice_html, generate_invoice_pdf


logger = structlog.get_logger()


def _snapshot_data(user: Any, order: Any) -> tuple[SimpleNamespace, SimpleNamespace]:
    """Create lightweight detached thread-safe snapshots of user and order."""
    user_snap = SimpleNamespace(
        id=str(getattr(user, "id", "")),
        first_name=getattr(user, "first_name", None),
        last_name=getattr(user, "last_name", None),
        name=getattr(user, "name", None),
        email=getattr(user, "email", None),
        mobile_number=getattr(user, "mobile_number", None),
    )
    order_snap = SimpleNamespace(
        id=getattr(order, "id", None),
        user_id=getattr(order, "user_id", None),
        razorpay_order_id=getattr(order, "razorpay_order_id", ""),
        razorpay_payment_id=getattr(order, "razorpay_payment_id", None),
        bank_rrn=getattr(order, "bank_rrn", None),
        payment_method=getattr(order, "payment_method", None),
        customer_contact=getattr(order, "customer_contact", None),
        metal=getattr(order, "metal", "gold"),
        amount_paise=getattr(order, "amount_paise", 0),
        grams=getattr(order, "grams", 0),
        rate_per_gram=getattr(order, "rate_per_gram", 0),
        gst_percent=getattr(order, "gst_percent", None),
        metal_value_inr=getattr(order, "metal_value_inr", None),
        gst_amount_inr=getattr(order, "gst_amount_inr", None),
        created_at=getattr(order, "created_at", None),
        paid_at=getattr(order, "paid_at", None),
        status=getattr(order, "status", "paid"),
    )
    return user_snap, order_snap


def _send_invoice_smtp_sync(user: Any, order: Any) -> bool:
    """Synchronous SMTP helper to dispatch email with PDF invoice attachment."""
    if not settings.SMTP_ENABLED:
        logger.info("smtp_disabled_skipping_invoice_email", order_id=str(getattr(order, "id", "")))
        return False

    recipient_email = getattr(user, "email", "") or ""
    recipient_email = recipient_email.strip()
    if not recipient_email or "@" not in recipient_email:
        logger.warning(
            "user_has_no_email_skipping_invoice",
            user_id=str(getattr(user, "id", "")),
            order_id=str(getattr(order, "id", "")),
        )
        return False

    if is_placeholder_email(recipient_email):
        logger.warning(
            "user_has_placeholder_or_invalid_email_skipping_invoice",
            user_id=str(getattr(user, "id", "")),
            order_id=str(getattr(order, "id", "")),
            placeholder_email=recipient_email,
            hint="Set a real personal email address (e.g. Gmail) on the user profile to receive invoices.",
        )
        return False


    if not settings.SMTP_USER or not settings.SMTP_PASSWORD:
        logger.warning("smtp_credentials_not_configured_skipping_email")
        return False

    try:
        inv_id = str(order.id).replace("-", "")[:8].upper()
        invoice_number = f"INV-AGS-{inv_id}"

        # 1. Generate PDF and HTML
        pdf_bytes = generate_invoice_pdf(order, user)
        html_body = generate_invoice_html(order, user)

        # 2. Build multipart message
        msg = MIMEMultipart("mixed")
        msg["From"] = formataddr((settings.SMTP_FROM_NAME, settings.SMTP_FROM_EMAIL))
        msg["To"] = recipient_email
        msg["Subject"] = f"Payment Receipt & Tax Invoice #{invoice_number} – Aurum Gold & Silvers"

        # Alternative part for HTML
        alt_part = MIMEMultipart("alternative")
        html_part = MIMEText(html_body, "html", "utf-8")
        alt_part.attach(html_part)
        msg.attach(alt_part)

        # Attachment part for PDF
        pdf_part = MIMEApplication(pdf_bytes, _subtype="pdf")
        pdf_filename = f"Invoice_{invoice_number}.pdf"
        pdf_part.add_header(
            "Content-Disposition",
            "attachment",
            filename=pdf_filename,
        )
        msg.attach(pdf_part)

        # 3. Connect and send via SMTP
        with smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT, timeout=15) as server:
            if settings.SMTP_TLS:
                server.starttls()
            server.login(settings.SMTP_USER, settings.SMTP_PASSWORD)
            server.send_message(msg)

        logger.info(
            "invoice_email_sent_successfully",
            order_id=str(order.id),
            recipient=recipient_email,
            invoice_no=invoice_number,
        )
        return True
    except Exception as e:
        logger.error(
            "failed_to_send_invoice_email",
            order_id=str(getattr(order, "id", "")),
            recipient=recipient_email,
            error=str(e),
            exc_info=True,
        )
        return False


async def send_invoice_email_async(user: Any, order: Any) -> bool:
    """Asynchronously send invoice email in a background thread without blocking."""
    user_snap, order_snap = _snapshot_data(user, order)
    return await asyncio.to_thread(_send_invoice_smtp_sync, user_snap, order_snap)
