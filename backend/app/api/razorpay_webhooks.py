from fastapi import APIRouter, Depends, Header, Request, status
from fastapi.responses import JSONResponse

from app.api.dependencies import get_gold_sell_inquiry_service
from app.core.config import settings
from app.core.logging import logger
from app.services.gold_sell_inquiry import GoldSellInquiryService
from app.services.razorpayx_client import RazorpayXClient

router = APIRouter()


@router.post(
    "/razorpay",
    status_code=status.HTTP_200_OK,
    summary="Razorpay / RazorpayX webhook (payout status)",
    include_in_schema=False,
)
async def razorpay_webhook(
    request: Request,
    x_razorpay_signature: str | None = Header(default=None),
    service: GoldSellInquiryService = Depends(get_gold_sell_inquiry_service),
):
    body = await request.body()

    if settings.RAZORPAY_WEBHOOK_SECRET and x_razorpay_signature:
        client = RazorpayXClient()
        if not client.verify_webhook_signature(body, x_razorpay_signature):
            logger.warning("razorpay_webhook_invalid_signature")
            return JSONResponse(
                status_code=status.HTTP_400_BAD_REQUEST,
                content={"detail": "Invalid signature"},
            )

    payload = await request.json()
    event = payload.get("event", "")
    entity = payload.get("payload", {}).get("payout", {}).get("entity", {})

    if not entity and "payout" in payload.get("payload", {}):
        entity = payload["payload"]["payout"].get("entity", entity)

    payout_id = entity.get("id")
    payout_status = entity.get("status", "")
    failure_reason = None
    if entity.get("status_details"):
        failure_reason = entity["status_details"].get("description")

    if not payout_id:
        return {"status": "ignored"}

    if event.startswith("payout.") or payout_status:
        inquiry = await service.handle_payout_webhook(
            payout_id=payout_id,
            status=payout_status,
            failure_reason=failure_reason,
        )
        if inquiry:
            return {"status": "ok", "inquiry_id": str(inquiry.id)}
        return {"status": "not_found"}

    return {"status": "ignored"}
