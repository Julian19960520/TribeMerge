"""礼包链（法币直购活动），设计见 DESIGN.md「礼包链（直购活动）」。

- 队列配置：data/gift_chain.json（客户端读同一份）。每步 price（0 = 免费，否则人民币价格档，元）+ rewards。
- 进度：state["gift_chain"] = {"cycle": 期号, "step": 队首下标}，只在服务器上。客户端只显示服务器返回的结果。
- 周期：cycle_days 天一期（默认 7 天，北京时间周一 00:00 换期），换期后队列从第 1 步重来。按服务器时间算。
- 免费步：POST /v1/gift-chain/claim {step}，必须是队首、必须免费，幂等键。
- 付费步：POST /v1/gift-chain/order {step} 下单（PayOrder kind="gift"）→ 支付渠道回调（现在是 mock）验单成功后
  在 api_game._fulfil 里调 fulfil() 发奖、队列前移。客户端没有任何接口能直接领付费步。
"""

import json
import logging
import secrets
from functools import lru_cache
from pathlib import Path

from fastapi import APIRouter, Depends, Request
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session

from . import clock
from .config import get_settings
from .db import get_db
from .economy import Economy, Reject, num
from .errors import ApiError, body
from .logs import log
from .models import PayOrder
from .schemas import Req
from .security import Auth, current, lock_account
from .services import audit, economy, idem_get, idem_key, idem_put, load_state, stamp, store_state

router = APIRouter(prefix="/v1", tags=["活动"])
logger = logging.getLogger("tribe.gift")

KEY = "gift_chain"


# ---------------------------------------------------------------- 配置 / 周期

@lru_cache
def _file_cfg(path: str, mtime: float) -> dict:
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def cfg() -> dict:
    p = Path(get_settings().data_dir) / "gift_chain.json"
    try:
        return _file_cfg(str(p), p.stat().st_mtime)
    except FileNotFoundError:
        return {"steps": []}


def steps(c: dict | None = None) -> list:
    return list((c or cfg()).get("steps") or [])


def price_str(price) -> str:
    p = float(price or 0)
    return ("¥%d" % p) if p == int(p) else ("¥%.2f" % p)


def cycle_of(t: float, c: dict | None = None) -> dict:
    """第几期、开始 / 结束的 Unix 时间。北京时间零点换日；anchor_weekday 0 = 周一。"""
    c = c or cfg()
    days = max(1, num(c.get("cycle_days"), 7))
    off = get_settings().day_utc_offset_hours * 3600
    d = int((t + off) // 86400)
    # Unix 第 0 天（1970-01-01）是周四：周一是第 4 天
    anchor = 4 + num(c.get("anchor_weekday"), 0)
    k = (d - anchor) // days
    start_day = anchor + k * days
    return {"cycle": k, "start": start_day * 86400 - off, "end": (start_day + days) * 86400 - off}


def ensure(st: dict, now: float, c: dict | None = None) -> dict:
    """拿到本期进度；换期了就从第 1 步重来。"""
    cy = cycle_of(now, c)
    g = st.get(KEY)
    if not isinstance(g, dict) or num(g.get("cycle"), -1) != cy["cycle"]:
        g = {"cycle": cy["cycle"], "step": 0}
        st[KEY] = g
    return g


def view(st: dict, now: float) -> dict:
    c = cfg()
    g = ensure(st, now, c)
    cy = cycle_of(now, c)
    ss = steps(c)
    head = num(g.get("step"))
    out = []
    for i, s in enumerate(ss):
        p = float(s.get("price", 0) or 0)
        out.append({"i": i, "price": p, "price_str": price_str(p) if p > 0 else "", "rewards": s.get("rewards") or [],
                    "tag": s.get("tag", "")})
    return {"cycle": cy["cycle"], "ends_at": cy["end"], "step": head, "total": len(ss), "visible": num(c.get("visible"), 3),
            "done": head >= len(ss), "free_ready": head < len(ss) and float(ss[head].get("price", 0) or 0) <= 0,
            "steps": out}


def _head(st: dict, step: int, now: float) -> dict:
    """校验 step 是本期队首，返回这一步的配置。"""
    g = ensure(st, now)
    ss = steps()
    head = num(g.get("step"))
    if head >= len(ss):
        raise Reject("chain_done", "本期礼包已经全部领完")
    if step < head:
        raise Reject("already_claimed", "这一步已经领过了")
    if step != head:
        raise Reject("not_head", "要先领完前面的礼包")
    return ss[head]


# ---------------------------------------------------------------- 免费步 / 付费步发货

def claim_free(econ: Economy, st: dict, step: int, now: float) -> dict:
    s = _head(st, step, now)
    if float(s.get("price", 0) or 0) > 0:
        raise Reject("need_payment", "这一步需要购买")
    rw = s.get("rewards") or []
    out = econ.grant(st, rw, {"rewards": rw})
    st[KEY]["step"] = step + 1
    return out


def fulfil(db: Session, econ: Economy, acc_id: str, st: dict, o: PayOrder, now: float) -> dict:
    """付费步验单成功（支付回调）：发这一步的奖励；还是队首就前移一格。
    已付钱但队列已经变了（换期 / 重复下单都付了）：奖励照发（玩家付过钱），不前移，记审计。"""
    try:
        cyc, step = (int(x) for x in o.ref.split(":"))
    except ValueError:
        cyc, step = -1, o.pack
    ss = steps()
    rw = (ss[step].get("rewards") or []) if 0 <= step < len(ss) else []
    give = econ.grant(st, rw, {"rewards": rw})
    g = ensure(st, now)
    if num(g.get("cycle")) == cyc and num(g.get("step")) == step:
        g["step"] = step + 1
    else:
        audit(db, acc_id, "gift_paid_stale", "订单 %s 第 %d 步（第 %d 期）付款时队首已是第 %d 步（第 %d 期），只发奖不前移"
              % (o.id, step, cyc, num(g.get("step")), num(g.get("cycle"))))
    log(logger, logging.INFO, "gift fulfilled", order_id=o.id, step=step)
    return give


# ---------------------------------------------------------------- 接口

class GiftStepReq(Req):
    step: int


class GiftOrderReq(Req):
    step: int
    provider: str = "mock"


@router.get("/gift-chain")
def gift_info(auth: Auth = Depends(current), db: Session = Depends(get_db)):
    acc = lock_account(db, auth.id)
    st = load_state(acc)
    before = json.dumps(st.get(KEY), sort_keys=True)
    out = view(st, clock.now())
    if json.dumps(st.get(KEY), sort_keys=True) != before:
        store_state(acc, st)
    db.commit()
    return stamp({"ok": True, "chain": out})


@router.post("/gift-chain/claim")
def gift_claim(req: GiftStepReq, request: Request, auth: Auth = Depends(current), db: Session = Depends(get_db)):
    key = idem_key(request)
    hit = idem_get(db, auth.id, key, "gift.claim")
    if hit is not None:
        return JSONResponse(hit.response, status_code=hit.status)
    acc = lock_account(db, auth.id)
    econ = economy()
    st = load_state(acc)
    econ.ensure_day(st)
    now = clock.now()
    try:
        give = claim_free(econ, st, req.step, now)
    except Reject as r:
        resp = stamp(body(r.error, r.message, state=econ.client_state(st), chain=view(st, now)))
        idem_put(db, auth.id, key, "gift.claim", r.status, resp)
        db.commit()
        return JSONResponse(resp, status_code=r.status)
    store_state(acc, st)
    resp = stamp({"ok": True, "state": econ.client_state(st), "give": give, "chain": view(st, now)})
    idem_put(db, auth.id, key, "gift.claim", 200, resp)
    db.commit()
    log(logger, logging.INFO, "gift claim", step=req.step)
    return resp


@router.post("/gift-chain/order")
def gift_order(req: GiftOrderReq, request: Request, auth: Auth = Depends(current), db: Session = Depends(get_db)):
    """付费步下单。正式接入时这里调应用商店 / 支付渠道，把商品 id（按价格档）和拉起参数给客户端。"""
    from .api_game import _order_out  # 和琥珀礼包同一套订单输出
    key = idem_key(request)
    hit = idem_get(db, auth.id, key, "gift.order")
    if hit is not None:
        return JSONResponse(hit.response, status_code=hit.status)
    if req.provider != "mock" or not get_settings().enable_mock_payment:
        raise ApiError(501, "payment_not_configured", "这个支付渠道还没有接入")
    acc = lock_account(db, auth.id)
    st = load_state(acc)
    now = clock.now()
    try:
        s = _head(st, req.step, now)
        if float(s.get("price", 0) or 0) <= 0:
            raise Reject("free_step", "这一步是免费的，直接领取")
    except Reject as r:
        resp = stamp(body(r.error, r.message, chain=view(st, now)))
        idem_put(db, auth.id, key, "gift.order", r.status, resp)
        db.commit()
        return JSONResponse(resp, status_code=r.status)
    store_state(acc, st)  # 可能刚换期
    o = PayOrder(id="po_" + secrets.token_hex(12), account_id=auth.id, pack=req.step, amber=0,
                 price=price_str(s.get("price")), provider=req.provider, status="created", created_at=clock.utcnow(),
                 kind="gift", ref="%d:%d" % (num(st[KEY]["cycle"]), req.step))
    db.add(o)
    resp = _order_out(o)
    idem_put(db, auth.id, key, "gift.order", 200, resp)
    db.commit()
    return resp
