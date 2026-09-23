from fastapi import APIRouter, Depends, Query, status

from app.api.dependencies import get_current_user, get_gold_payment_service
from app.core.authorization import PermissionChecker
from app.models.user import User
from app.schemas.payment import (
  AdminPaymentListResponse,
  CreatePaymentOrderRequest,
  CreatePaymentOrderResponse,
  PaymentSettlementListResponse,
  RazorpaySyncAllResponse,
  SyncPaymentRequest,
  SyncPaymentResponse,
  VerifyPaymentRequest,
  VerifyPaymentResponse,
)
from app.services.gold_payment import GoldPaymentService

router = APIRouter()


@router.post(
  "/razorpay/order",
  response_model=CreatePaymentOrderResponse,
  status_code=status.HTTP_200_OK,
  summary="Create Razorpay order for gold/silver purchase",
)
async def create_razorpay_order(
  body: CreatePaymentOrderRequest,
  current_user: User = Depends(get_current_user),
  payment_service: GoldPaymentService = Depends(get_gold_payment_service),
) -> CreatePaymentOrderResponse:
  return await payment_service.create_buy_order(
    current_user,
    metal=body.metal,
    grams=body.grams,
    amount_inr=body.amount_inr,
  )


@router.post(
  "/razorpay/sync",
  response_model=SyncPaymentResponse,
  status_code=status.HTTP_200_OK,
  summary="Sync Razorpay payment after UPI redirect when the SDK callback is missed",
)
async def sync_razorpay_payment(
  body: SyncPaymentRequest,
  current_user: User = Depends(get_current_user),
  payment_service: GoldPaymentService = Depends(get_gold_payment_service),
) -> SyncPaymentResponse:
  return await payment_service.sync_payment(
    current_user,
    razorpay_order_id=body.razorpay_order_id,
  )


@router.post(
  "/razorpay/verify",
  response_model=VerifyPaymentResponse,
  status_code=status.HTTP_200_OK,
  summary="Verify Razorpay payment and credit metal balance",
)
async def verify_razorpay_payment(
  body: VerifyPaymentRequest,
  current_user: User = Depends(get_current_user),
  payment_service: GoldPaymentService = Depends(get_gold_payment_service),
) -> VerifyPaymentResponse:
  return await payment_service.verify_payment(
    current_user,
    razorpay_order_id=body.razorpay_order_id,
    razorpay_payment_id=body.razorpay_payment_id,
    razorpay_signature=body.razorpay_signature,
  )


@router.get(
  "/settlements",
  response_model=PaymentSettlementListResponse,
  summary="Paid purchase settlements with GST and Razorpay fee breakdown (admin)",
)
async def list_payment_settlements(
  skip: int = Query(0, ge=0),
  limit: int = Query(50, ge=1, le=100),
  current_user: User = Depends(PermissionChecker("transaction.view")),
  payment_service: GoldPaymentService = Depends(get_gold_payment_service),
) -> PaymentSettlementListResponse:
  return await payment_service.list_settlements(skip=skip, limit=limit)


@router.post(
  "/razorpay/sync-all",
  response_model=RazorpaySyncAllResponse,
  status_code=status.HTTP_200_OK,
  summary="Synchronously reconcile all recent Razorpay payments into our DB (admin)",
)
async def sync_all_razorpay_payments(
  current_user: User = Depends(PermissionChecker("dashboard.view")),
  payment_service: GoldPaymentService = Depends(get_gold_payment_service),
) -> RazorpaySyncAllResponse:
  return await payment_service.sync_all_from_razorpay(current_user)


@router.get(
  "/admin/orders",
  response_model=AdminPaymentListResponse,
  summary="List detailed payment orders for executive dashboard (admin)",
)
async def list_admin_payment_orders(
  skip: int = Query(0, ge=0),
  limit: int = Query(50, ge=1, le=100),
  status: str | None = Query(None),
  search: str | None = Query(None),
  current_user: User = Depends(PermissionChecker("dashboard.view")),
  payment_service: GoldPaymentService = Depends(get_gold_payment_service),
) -> AdminPaymentListResponse:
  return await payment_service.list_admin_orders(
    skip=skip, limit=limit, status=status, search=search
  )

