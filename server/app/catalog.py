"""Paid products, priced and filled from the same data/*.json files the client reads.

The client only names a product; the server decides the price and what the
grant contains. Product ids:

  amber:<k>            data/amber_packs.json row k
  pass:vip, pass:super data/pass.json "purchase" (super is the difference when already VIP this season)
  offer:<kind>:<tier>  data/offers.json limited-time bundles
  ufo                  data/ufo_offer.json; detail = {"offer_id", "items"} (the missing order items shown in the popup)
  gift:<step>          a paid step of data/gift_chain.json in the current weekly cycle
"""

import json
import re
from datetime import datetime, timedelta, timezone
from functools import lru_cache
from pathlib import Path

from sqlalchemy import func, select

from . import clock
from .config import get_settings
from .errors import ApiError
from .models import Grant, PaymentOrder

DAY = 86400
BEIJING = 8 * 3600
ITEM_ID = re.compile(r"^([a-z]+)_(\d{1,2})$")


@lru_cache
def _load(data_dir: str, name: str):
    return json.loads((Path(data_dir) / name).read_text(encoding="utf-8"))


def data(name: str):
    return _load(get_settings().data_dir, name)


def _chains() -> dict:
    return {row["id"]: row for row in data("chains.json")}


def item_type(item_id: str) -> str:
    match = ITEM_ID.match(item_id)
    chain = _chains().get(match.group(1)) if match else None
    if chain is None or not 1 <= int(match.group(2)) <= len(chain["items"]):
        return ""
    return str(chain.get("type", ""))


def paid_amber(rewards: list) -> int:
    """Amber a reward list puts in the wallet: [amber_x, points] or physical amber items by their value."""
    total = 0
    for reward in rewards:
        item_id, amount = str(reward[0]), int(reward[1])
        if item_type(item_id) != "amber":
            continue
        if len(reward) > 2 and reward[2] in ("item", "physical"):
            values = _chains()["amber"]["value"]
            total += amount * int(values[int(item_id.rsplit("_", 1)[1]) - 1])
        else:
            total += amount
    return total


def _price_fen(value) -> int:
    if isinstance(value, str):
        digits = re.sub(r"[^0-9.]", "", value)
        value = float(digits) if digits else 0
    fen = int(round(float(value) * 100))
    if fen <= 0:
        raise ApiError(422, "not_for_sale", "该商品不出售")
    return fen


def pass_season(now: float) -> str:
    season = data("pass.json")["season"]
    start = datetime.fromisoformat(str(season.get("start", "2026-11-02"))).replace(tzinfo=timezone.utc).timestamp()
    span = max(1, int(season.get("days", 35))) * DAY
    return str(int((now + BEIJING - start) // span))


def gift_cycle(now: float) -> int:
    chain = data("gift_chain.json")
    days = max(1, int(chain.get("cycle_days", 7)))
    day = int((now + BEIJING) // DAY)
    return (day - 4 - int(chain.get("anchor_weekday", 0))) // days


def owned_pass_tier(db, account_id: str, season: str) -> int:
    tier = 0
    rows = db.execute(select(Grant.content).join(PaymentOrder, PaymentOrder.id == Grant.order_id)
                      .where(Grant.account_id == account_id, PaymentOrder.product.like("pass:%"))).scalars()
    for content in rows:
        info = content.get("pass") or {}
        if str(info.get("season")) == season:
            tier = max(tier, int(info.get("tier", 0)))
    return tier


def _reward_list(rows, physical: bool = False) -> list:
    out = []
    for row in rows:
        out.append([str(row[0]), int(row[1])] + (["physical"] if physical else []))
    return out


def quote(db, account_id: str, product: str, detail: dict) -> dict:
    """Price and grant content for one purchase; raises ApiError when it cannot be sold now."""
    now = clock.now()
    parts = product.split(":")
    kind = parts[0]
    content: dict = {"product": product}
    once_key = ""
    if kind == "amber" and len(parts) == 2 and parts[1].isdigit():
        packs = data("amber_packs.json")
        index = int(parts[1])
        if index >= len(packs):
            raise ApiError(404, "unknown_product", "商品不存在")
        price = _price_fen(packs[index]["price"])
        content["amber"] = int(packs[index]["n"])
    elif kind == "pass" and len(parts) == 2 and parts[1] in ("vip", "super"):
        purchase = data("pass.json")["purchase"]
        season = pass_season(now)
        tier = 1 if parts[1] == "vip" else 2
        owned = owned_pass_tier(db, account_id, season)
        if owned >= tier:
            raise ApiError(409, "already_owned", "本赛季已拥有")
        row = purchase["vip" if tier == 1 else "super_vip"]
        rewards = _reward_list(row["rewards"])
        price = _price_fen(row["price_cny"])
        if tier == 2 and owned == 1:
            # Upgrade: pay the difference, receive only what super adds over VIP.
            price -= _price_fen(purchase["vip"]["price_cny"])
            vip = {row[0]: row[1] for row in _reward_list(purchase["vip"]["rewards"])}
            rewards = [[rid, n - vip.get(rid, 0)] for rid, n in rewards if n - vip.get(rid, 0) > 0]
        content["pass"] = {"tier": tier, "season": season}
        content["rewards"] = rewards
        once_key = f"pass:{season}:{tier}"
    elif kind == "offer" and len(parts) == 3 and parts[2].isdigit():
        offer = data("offers.json").get(parts[1])
        tiers = offer.get("tiers", []) if isinstance(offer, dict) else []
        index = int(parts[2])
        if index >= len(tiers):
            raise ApiError(404, "unknown_product", "商品不存在")
        tier = tiers[index]
        # A window lasts duration_sec and windows are separated by a cooldown, so no
        # duration-long interval can legitimately hold more than `limit` purchases.
        since = clock.utcnow() - timedelta(seconds=int(offer["duration_sec"]))
        bought = db.execute(select(func.count()).select_from(PaymentOrder).where(
            PaymentOrder.account_id == account_id, PaymentOrder.product == product,
            PaymentOrder.status == "paid", PaymentOrder.paid_at >= since)).scalar_one()
        if bought >= int(tier.get("limit", 1)):
            raise ApiError(409, "limit_reached", "本期已买完")
        price = _price_fen(tier["price_cny"])
        content["rewards"] = _reward_list(tier["rewards"])
        content["offer"] = {"kind": parts[1], "tier": index}
    elif kind == "ufo" and len(parts) == 1:
        config = data("ufo_offer.json")
        offer_id = str(detail.get("offer_id", ""))
        items = detail.get("items")
        if not config.get("enabled", False):
            raise ApiError(409, "not_for_sale", "活动未开放")
        if not re.fullmatch(r"[0-9]{1,20}", offer_id) or not isinstance(items, list) \
                or not int(config.get("min_items", 1)) <= len(items) <= int(config["max_items"]):
            raise ApiError(422, "invalid_product", "礼包内容不合法")
        for item in items:
            if not isinstance(item, str) or item_type(item) != "item":
                raise ApiError(422, "invalid_product", "礼包内容不合法")
        price = _price_fen(config["price_cny"])
        content["rewards"] = [[item, 1, "physical"] for item in [*items, *config.get("bonus_items", [])]]
        content["ufo"] = offer_id
        once_key = "ufo:" + offer_id
    elif kind == "gift" and len(parts) == 2 and parts[1].isdigit():
        steps = data("gift_chain.json")["steps"]
        step = int(parts[1])
        if step >= len(steps) or float(steps[step].get("price", 0)) <= 0:
            raise ApiError(404, "unknown_product", "商品不存在")
        cycle = gift_cycle(now)
        price = _price_fen(steps[step]["price"])
        content["rewards"] = _reward_list(steps[step]["rewards"])
        content["gift"] = {"cycle": cycle, "step": step}
        once_key = f"gift:{cycle}:{step}"
    else:
        raise ApiError(404, "unknown_product", "商品不存在")
    if once_key and db.execute(select(PaymentOrder.id).where(
            PaymentOrder.account_id == account_id, PaymentOrder.once_key == once_key,
            PaymentOrder.status == "paid")).first() is not None:
        raise ApiError(409, "already_owned", "已经买过了")
    return {"price_fen": price, "content": content, "once_key": once_key}


def amber_in(content: dict) -> int:
    return int(content.get("amber", 0)) + paid_amber(content.get("rewards", []))
