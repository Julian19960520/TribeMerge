"""Payments API: orders, receipts, the dev mock provider and grant delivery."""

from typing import Any

from fastapi import APIRouter, Depends, Header, Path
from pydantic import Field
from sqlalchemy.orm import Session

from . import payments
from .db import get_db
from .schemas import Req
from .security import Auth, current

router = APIRouter(prefix="/v1/payments", tags=["支付"])
ORDER_ID = Field(pattern=r"^po_[0-9a-f]{24}$")


class OrderReq(Req):
    product: str = Field(pattern=r"^[a-z]+(:[a-z0-9_]{1,24}){0,2}$")
    detail: dict[str, Any] = Field(default_factory=dict)


class ConfirmReq(Req):
    provider: str = Field(pattern=r"^[a-z0-9_]{1,16}$")
    receipt: str = Field(min_length=1, max_length=8192)


class MockPayReq(Req):
    order_id: str = ORDER_ID


class AckReq(Req):
    ids: list[str] = Field(min_length=1, max_length=100)


@router.post("/orders")
def create_order(request: OrderReq, idempotency_key: str = Header(default="", max_length=80),
                 auth: Auth = Depends(current), db: Session = Depends(get_db)):
    return payments.create_order(db, auth, request.product, request.detail, idempotency_key)


@router.post("/orders/{order_id}/confirm")
def confirm(request: ConfirmReq, order_id: str = Path(pattern=r"^po_[0-9a-f]{24}$"), auth: Auth = Depends(current), db: Session = Depends(get_db)):
    return payments.confirm(db, auth, order_id, request.provider, request.receipt)


@router.post("/mock/pay")
def mock_pay(request: MockPayReq, auth: Auth = Depends(current), db: Session = Depends(get_db)):
    return payments.mock_pay(db, auth, request.order_id)


@router.get("/grants")
def grants(auth: Auth = Depends(current), db: Session = Depends(get_db)):
    return payments.pending(db, auth)


@router.post("/grants/ack")
def ack(request: AckReq, auth: Auth = Depends(current), db: Session = Depends(get_db)):
    return payments.ack(db, auth, request.ids)
