"""Server-priced virtual purchases, using the existing idempotent grant delivery."""
import gzip
import json
import secrets
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Header
from pydantic import Field
from sqlalchemy import select
from sqlalchemy.orm import Session

from . import clock, economy, payments
from .db import get_db
from .errors import ApiError
from .models import Grant, PaymentOrder, Save
from .schemas import Req
from .security import Auth, current
from .services import idem_get, idem_put, request_fingerprint, stamp
from .texts import source as text_source

router = APIRouter(prefix="/v1/economy", tags=["经济"])


class PurchaseReq(Req):
    product: str = Field(min_length=1, max_length=80)
    version: str = Field(min_length=1, max_length=80)
    expected_price: int = Field(ge=0)
    detail: dict = Field(default_factory=dict)


@router.post("/purchases")
def purchase(request: PurchaseReq, idempotency_key: str = Header(default="", max_length=80),
             auth: Auth = Depends(current), db: Session = Depends(get_db)):
    if not idempotency_key:
        raise ApiError(400, "idempotency_key_required", text_source("server_notice.api_economy.c45907409f58"))
    account, _ = payments._begin(db, auth)
    fingerprint = request_fingerprint(request.model_dump())
    previous = idem_get(db, account.id, idempotency_key, "economy.purchase", fingerprint)
    if previous is not None:
        result = dict(previous.response)
        db.rollback()
        return stamp(result)
    book = economy.current()
    if request.version != book["version"]:
        raise ApiError(409, "catalog_changed", text_source("server_notice.api_economy.16099a1f008a"))
    save = db.get(Save, account.id, populate_existing=True)
    snapshot = json.loads(gzip.decompress(save.data)) if save and save.data else {}
    if not snapshot:
        raise ApiError(409, "save_required", text_source("server_notice.api_economy.139b469a53b7"))
    applied = payments.applied_ids(snapshot)
    outstanding = list(db.scalars(select(Grant).where(Grant.account_id == account.id)))
    available = int(snapshot.get("amber", 0)) - sum(int(g.content.get("cost_amber", 0)) for g in outstanding if g.id not in applied)
    now = clock.now()
    offset = int(book["energy"]["reset_utc_offset_hours"]) * 3600
    day = int((now + offset) // 86400)
    start = datetime.fromtimestamp(day * 86400 - offset, timezone.utc)
    today = list(db.scalars(select(PaymentOrder).where(PaymentOrder.account_id == account.id, PaymentOrder.provider == "virtual", PaymentOrder.status == "paid", PaymentOrder.paid_at >= start)))
    product = request.product
    content = {"product": product, "_pricing": {"currency": "AMBER", "market": book["market"], "version": book["version"]}}
    if product == "energy":
        bought = sum(o.product == "energy" for o in today)
        day_string = datetime.fromtimestamp(now + offset, timezone.utc).date().isoformat()
        if snapshot.get("deals_day") == day_string:
            bought = max(bought, int(snapshot.get("energy_buys", 0)))
        prices = book["energy"]["prices"]
        price = prices[min(bought, len(prices) - 1)]
        content.update(rewards=[["fire_2", book["energy"]["amount"]]], energy_purchase={"day": day_string, "count": bought + 1})
    elif product == "shell":
        price = book["shell"]["price"]
        content["rewards"] = [["shell_2", book["shell"]["amount"]]]
    elif product.startswith("sand:") and product[5:].isdigit() and int(product[5:]) < len(book["sand"]["packs"]):
        seconds, price = book["sand"]["packs"][int(product[5:])]
        content["rewards"] = [["sand_2", seconds // book["sand"]["seconds_per_unit"]]]
    elif product.startswith("shop:"):
        item_id = product[5:]
        item = book["items"].get(item_id, {})
        key = str(request.detail.get("key", ""))
        hot = snapshot.get("replay_meta", {}).get("hot", {}).get("list", [])
        if not key.startswith("hot_") or not key[4:].isdigit() or int(key[4:]) >= len(hot):
            raise ApiError(422, "invalid_product", text_source("server_notice.api_economy.938bcdf06f85"))
        index = int(key[4:])
        row = hot[index]
        shelves = book["documents"]["store"]
        if index >= len(shelves):
            raise ApiError(422, "invalid_product", text_source("server_notice.api_economy.938bcdf06f85"))
        shelf = shelves[index]
        if row.get("id") != item_id or not item.get("amber"):
            raise ApiError(422, "invalid_product", text_source("server_notice.api_economy.938bcdf06f85"))
        revision = int(snapshot.get("hot_revision", 0))
        used = sum(o.content.get("shop", {}).get("key") == key and o.content.get("shop", {}).get("revision") == revision for o in today)
        if used >= int(shelf["stock"]):
            raise ApiError(409, "limit_reached", text_source("server_notice.api_economy.1288785a6aa2"))
        price = item["amber"]
        content.update(rewards=[[item_id, 1, "physical"]], shop={"key": key, "revision": revision})
    else:
        raise ApiError(404, "unknown_product", text_source("server_notice.catalog.1ae6d9f15326"))
    if price != request.expected_price:
        raise ApiError(409, "price_changed", text_source("server_notice.api_economy.3b4fcba4afb8"))
    if available < price:
        raise ApiError(409, "not_enough_amber", text_source("server_notice.api_economy.65486c9390eb"))
    content["cost_amber"] = price
    order_id, grant_id = "po_" + secrets.token_hex(12), "gr_" + secrets.token_hex(12)
    order = PaymentOrder(id=order_id, account_id=account.id, product=product, price_fen=0, once_key="", content=content, status="paid", provider="virtual", created_at=clock.utcnow(), paid_at=clock.utcnow(), grant_id=grant_id)
    grant = Grant(id=grant_id, account_id=account.id, order_id=order_id, content=content, amber=0, created_at=clock.utcnow())
    db.add_all([order, grant])
    result = {"ok": True, "grant": payments._grant_view(grant), "price": price}
    idem_put(db, account.id, idempotency_key, "economy.purchase", fingerprint, result)
    db.commit()
    return stamp(result)
