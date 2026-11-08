"""付费限时礼包（data/offers.json）：赶大集 spree / 火种大礼包 energy。规则和客户端 scripts/events/Offers.gd 一样。

每种礼包一期一期开：start → end（duration_sec）之间可买，每档 limit 次；end 之后再过 cooldown_sec（next_at）才能开下一期。
状态 st["offers"][kind] = {"start", "end", "next_at", "bought": {"档位": 次数}}。
购买走充值表：POST /v1/offer/order 下单（PayOrder kind = offer，ref = "kind:start:tier"，give 冻结下单时的奖励），
到账只在支付回调 api_game._fulfil → fulfil()：按 give 发奖；还是同一期就记一次已购（跨期才付：奖励照发，不记数）。
"""
from . import clock
from .economy import Reject, num

KINDS = ("spree", "energy")
# 估值（琥珀当量 AE），和 Offers.gd value() 同一张表
AE = {"amber": 1.0, "energy": 0.4, "shell": 0.1, "sand": 5.0, "chest": 15.0, "pack": 20.0}


def cfg(e, kind):
    c = (e.gd.offers or {}).get(kind)
    if kind not in KINDS or not isinstance(c, dict):
        raise Reject("bad_offer", "没有这个礼包", 400)
    return c


def value(e, rewards):
    total = 0.0
    for iid, n in rewards:
        t = e.gd.type_of(iid)
        if t in AE:
            total += AE[t] * n
        elif t == "gen":
            total += 10.0 * 2 ** (e.gd.lv(iid) - 1) * n
    return total


def _s(st, kind):
    return st.setdefault("offers", {}).setdefault(kind, {})


def active(st, kind, now=None):
    s = (st.get("offers") or {}).get(kind) or {}
    t = clock.now() if now is None else now
    return bool(s) and num(s.get("start")) <= t < float(s.get("end", 0))


def open_window(e, st, kind):
    """开一期（已经在进行就原样返回）。"""
    c = cfg(e, kind)
    if active(st, kind):
        return {}
    if num(st.get("level"), 1) < num(c.get("min_level"), 999):
        raise Reject("offer_locked", "%d 级开放" % num(c.get("min_level")))
    s = _s(st, kind)
    now = clock.now()
    if now < float(s.get("next_at", 0)):
        raise Reject("offer_cooldown", "礼包还没刷新，稍后再来")
    end = now + num(c.get("duration_sec"), 600)
    s.clear()
    s.update(start=now, end=end, next_at=end + num(c.get("cooldown_sec")), bought={})
    return {}


def reviewed(e, st, kind, tier):
    """下单前校验：这一期在进行、这一档还有次数。返回 (ref, 价格, 奖励)。"""
    c = cfg(e, kind)
    tiers = c.get("tiers") or []
    if not (0 <= tier < len(tiers)):
        raise Reject("bad_tier", "没有这一档", 400)
    if not active(st, kind):
        raise Reject("offer_expired", "礼包已结束，下次再来")
    s = _s(st, kind)
    t = tiers[tier]
    if num((s.get("bought") or {}).get(str(tier))) >= num(t.get("limit")):
        raise Reject("offer_sold_out", "这一档已经买完了")
    rewards = [[str(r[0]), num(r[1], 1)] for r in t.get("rewards") or []]
    return "%s:%s:%d" % (kind, repr(float(s["start"])), tier), "¥%d" % num(t.get("price_cny")), rewards


def fulfil(e, st, order):
    """支付成功：发下单时冻结的奖励；还是同一期就记一次已购。"""
    rewards = list((order.give or {}).get("rewards", []))
    give = e.grant(st, rewards, {"rewards": rewards})
    try:
        kind, start, tier = order.ref.split(":")
        s = (st.get("offers") or {}).get(kind) or {}
        if s and repr(float(s.get("start", -1))) == start:
            b = s.setdefault("bought", {})
            b[tier] = num(b.get(tier)) + 1
    except ValueError:
        pass
    return give
