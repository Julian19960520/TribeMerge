"""Server-owned paid content: orders, receipt verification, grants and the paid-amber ledger.

Flow: create order (server prices it) → the payment provider is paid → the server
verifies the receipt, marks the order paid and issues exactly one grant → the client
applies the grant with the `grant` command (its id is recorded in replay_meta.grants,
so it applies once) → the uploaded snapshot containing that id marks it delivered.
"""

import gzip
import hashlib
import hmac
import json
import secrets

from sqlalchemy import select

from . import catalog, clock
from .config import get_settings
from .errors import ApiError
from .models import Grant, PaymentOrder, Save
from .save_service import _account, _write_start
from .services import audit, idem_get, idem_put, request_fingerprint, stamp

ORDER_ENDPOINT = "payments.order"


def _order_view(order: PaymentOrder) -> dict:
    return {"id": order.id, "product": order.product, "price_fen": order.price_fen, "status": order.status,
            "grant_id": order.grant_id or ""}


def _grant_view(grant: Grant) -> dict:
    return {"id": grant.id, "order_id": grant.order_id, "content": grant.content, "created_at": grant.created_at.timestamp()}


def _begin(db, auth):
    db.rollback()
    _write_start(db)
    return _account(db, auth.id, auth.session.token_hash)


def _order(db, account_id: str, order_id: str) -> PaymentOrder:
    order = db.get(PaymentOrder, order_id, populate_existing=True)
    if order is None or order.account_id != account_id:
        raise ApiError(404, "unknown_order", "订单不存在")
    return order


# ---------------------------------------------------------------- 下单

def create_order(db, auth, product: str, detail: dict, key: str) -> dict:
    if not key:
        raise ApiError(400, "idempotency_key_required", "下单需要 Idempotency-Key")
    fingerprint = request_fingerprint({"product": product, "detail": detail})
    account, _session = _begin(db, auth)
    replay = idem_get(db, account.id, key, ORDER_ENDPOINT, fingerprint)
    if replay is not None:
        out = dict(replay.response)
        db.rollback()
        return stamp(out)
    quote = catalog.quote(db, account.id, product, detail)
    order = PaymentOrder(id="po_" + secrets.token_hex(12), account_id=account.id, product=product,
                         price_fen=quote["price_fen"], once_key=quote["once_key"], content=quote["content"],
                         status="created", created_at=clock.utcnow())
    db.add(order)
    out = {"ok": True, "order": _order_view(order)}
    idem_put(db, account.id, key, ORDER_ENDPOINT, fingerprint, out)
    db.commit()
    return stamp(out)


# ---------------------------------------------------------------- 支付凭证

def _mock_signature(order: PaymentOrder, txn: str) -> str:
    secret = ("mock-pay:" + get_settings().token_pepper).encode("utf-8")
    return hmac.new(secret, f"{order.id}|{txn}|{order.price_fen}".encode("utf-8"), hashlib.sha256).hexdigest()


def mock_receipt(order: PaymentOrder) -> str:
    txn = "mock-" + secrets.token_hex(10)
    return f"{order.id}.{txn}.{_mock_signature(order, txn)}"


def verify_receipt(provider: str, order: PaymentOrder, receipt: str) -> str:
    """Return the provider's transaction id when the receipt proves this order was paid in full."""
    if provider == "mock":
        if not get_settings().enable_mock_payments:
            raise ApiError(400, "provider_unavailable", "该支付渠道不可用")
        parts = receipt.split(".")
        if len(parts) != 3 or parts[0] != order.id or not hmac.compare_digest(parts[2], _mock_signature(order, parts[1])):
            raise ApiError(422, "invalid_receipt", "支付凭证无效")
        return parts[1]
    # App Store / Google Play / WeChat verifiers plug in here.
    raise ApiError(400, "provider_unavailable", "该支付渠道不可用")


def _fulfil(db, account, order: PaymentOrder, provider: str, ref: str) -> dict:
    if order.status == "paid":
        if order.provider == provider and order.provider_ref == ref:
            return _paid_view(db, order)
        raise ApiError(409, "order_already_paid", "订单已支付")
    if order.status != "created":
        raise ApiError(409, "order_closed", "订单已关闭")
    other = db.execute(select(PaymentOrder.id).where(PaymentOrder.provider == provider, PaymentOrder.provider_ref == ref)).first()
    if other is not None:
        raise ApiError(409, "receipt_reused", "支付凭证已使用")
    now = clock.utcnow()
    order.provider, order.provider_ref, order.paid_at = provider, ref, now
    if order.once_key and db.execute(select(PaymentOrder.id).where(
            PaymentOrder.account_id == account.id, PaymentOrder.once_key == order.once_key,
            PaymentOrder.status == "paid")).first() is not None:
        # Paid twice for something sold once (two orders raced): keep the money trail, deliver nothing.
        order.status = "refund"
        audit(db, account.id, "payment_refund", f"{order.id} {order.product} {provider}:{ref} duplicates {order.once_key}")
        db.commit()
        raise ApiError(409, "already_owned", "已经买过了，这笔付款会退回")
    grant = Grant(id="gr_" + secrets.token_hex(12), account_id=account.id, order_id=order.id,
                  content=order.content, amber=catalog.amber_in(order.content), created_at=now)
    db.add(grant)
    order.status = "paid"
    order.grant_id = grant.id
    account.paid_amber = int(account.paid_amber or 0) + grant.amber
    db.flush()
    return _paid_view(db, order)


def _paid_view(db, order: PaymentOrder) -> dict:
    grant = db.get(Grant, order.grant_id)
    return {"ok": True, "order": _order_view(order), "grant": _grant_view(grant)}


def confirm(db, auth, order_id: str, provider: str, receipt: str) -> dict:
    account, _session = _begin(db, auth)
    order = _order(db, account.id, order_id)
    out = _fulfil(db, account, order, provider, verify_receipt(provider, order, receipt))
    db.commit()
    return stamp(out)


def mock_pay(db, auth, order_id: str) -> dict:
    """Development stand-in for a store purchase: pays the order and confirms its receipt."""
    if not get_settings().enable_mock_payments:
        raise ApiError(404, "not_found", "Not Found")
    account, _session = _begin(db, auth)
    order = _order(db, account.id, order_id)
    if order.status == "paid":
        out = _paid_view(db, order)
        db.rollback()
        return stamp(out)
    receipt = mock_receipt(order)
    out = _fulfil(db, account, order, "mock", verify_receipt("mock", order, receipt))
    db.commit()
    return stamp({**out, "receipt": receipt})


# ---------------------------------------------------------------- 发放

def applied_ids(snapshot: dict) -> set[str]:
    meta = snapshot.get("replay_meta") if isinstance(snapshot, dict) else None
    applied = meta.get("grants") if isinstance(meta, dict) else None
    return set(applied) if isinstance(applied, dict) else set()


def pending(db, auth) -> dict:
    rows = db.execute(select(Grant).where(Grant.account_id == auth.id, Grant.delivered_at.is_(None))
                      .order_by(Grant.created_at, Grant.id)).scalars()
    return stamp({"ok": True, "grants": [_grant_view(row) for row in rows]})


def sync_delivery(db, account_id: str, snapshot: dict, version: int) -> None:
    """The newest uploaded snapshot decides delivery: listed grants are delivered,
    delivered grants it lacks (progress lost or replaced) are issued again."""
    applied = applied_ids(snapshot)
    now = clock.utcnow()
    for grant in db.execute(select(Grant).where(Grant.account_id == account_id)).scalars():
        if grant.id in applied and grant.delivered_at is None:
            grant.delivered_at, grant.delivered_version = now, version
        elif grant.id not in applied and grant.delivered_at is not None:
            grant.delivered_at, grant.delivered_version = None, None
            audit(db, account_id, "grant_redeliver", f"{grant.id} missing from save v{version}")


def ack(db, auth, ids: list[str]) -> dict:
    """Client says these grants are applied and uploaded; trust only the stored snapshot."""
    account, _session = _begin(db, auth)
    save = db.get(Save, account.id, populate_existing=True)
    snapshot = json.loads(gzip.decompress(save.data)) if save and save.data else {}
    applied = applied_ids(snapshot)
    delivered, waiting = [], []
    for grant_id in ids:
        grant = db.get(Grant, grant_id)
        if grant is None or grant.account_id != account.id:
            continue
        if grant_id in applied:
            if grant.delivered_at is None:
                grant.delivered_at, grant.delivered_version = clock.utcnow(), save.version
            delivered.append(grant_id)
        else:
            waiting.append(grant_id)
    db.commit()
    return stamp({"ok": True, "delivered": delivered, "pending": waiting})
