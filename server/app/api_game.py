"""存档同步、经济操作（全部带幂等键）、集市、充值、排行榜、健康检查。"""

import logging
import secrets
from collections.abc import Callable

from fastapi import APIRouter, Depends, Query, Request
from fastapi.responses import JSONResponse
from sqlalchemy import delete, func, or_, select, text
from sqlalchemy.orm import Session

from . import clock, race
from .config import get_settings
from .db import get_db
from .economy import Economy, Reject
from .errors import ApiError, body
from .logs import log
from .models import Account, HotDeal, PayOrder, Save, SaveBackup
from .schemas import (ActionResp, BookReq, BuildReq, EventsReq, LevelReq, NameReq, PassBuyReq, PassClaimReq, PassOrderReq,
                      PayOrderReq, PayOrderResp, Resp, SaveReq, SaveResp, ShopBuyReq, MergeBubbleReq, BubbleBuyReq, MergeEventReq, ChoiceChestReq)
from .security import Auth, current, hash_token, lock_account
from .services import (audit, b64, economy, gamedata, idem_get, idem_key, idem_put, load_state, pack, stamp,
                       store_state, today, unpack, unpack_blob)

router = APIRouter(prefix="/v1", tags=["游戏"])
logger = logging.getLogger("tribe.game")


# ---------------------------------------------------------------- 杂项

@router.get("/health", tags=["运维"])
def health(db: Session = Depends(get_db)):
    try:
        db.execute(text("SELECT 1"))
        ok = True
    except Exception:  # noqa: BLE001 —— 健康检查只关心能不能连
        ok = False
    out = stamp({"ok": ok, "db": ok, "env": get_settings().env})
    return JSONResponse(out, status_code=200 if ok else 503)


@router.get("/time", response_model=Resp)
def server_time():
    return stamp({"ok": True, "secs_to_midnight": clock.secs_to_midnight(get_settings().day_utc_offset_hours)})


# ---------------------------------------------------------------- 事件

def _events(db: Session, econ: Economy, acc: Account, st: dict, events) -> list:
    econ.ensure_day(st)
    seen = list(st.get("evt_seen") or [])
    results = []
    for ev in events:
        if ev.id in seen:
            results.append({"id": ev.id, "ok": True, "dup": True})
            continue
        try:
            give = econ.apply_event(st, ev.model_dump(exclude_none=True))
            if ev.type == "order":  # 篝火竞速：按服务器收到的交付事件加分
                race.on_order(db, acc, st, ev.order or {}, clock.now())
            results.append({"id": ev.id, "ok": True, "give": give})
        except Reject as r:
            audit(db, acc.id, "event_rejected", "%s %s: %s" % (ev.type, ev.model_dump_json(exclude_none=True)[:300], r.message))
            results.append({"id": ev.id, "ok": False, "error": r.error, "message": r.message})
        seen.append(ev.id)
    st["evt_seen"] = seen[-500:]
    return results


# ---------------------------------------------------------------- 存档

@router.get("/save", response_model=SaveResp)
def get_save(auth: Auth = Depends(current), db: Session = Depends(get_db)):
    sv = db.get(Save, auth.id)
    econ = economy()
    acc = lock_account(db, auth.id)
    st = load_state(acc)
    econ.ensure_day(st)
    store_state(acc, st)
    db.commit()
    return stamp({"ok": True, "version": sv.version if sv else 0, "hash": sv.hash if sv else "",
                  "data": b64(sv.data) if sv else "", "state": econ.client_state(st)})


@router.post("/events", response_model=SaveResp)
def post_events(req: EventsReq, auth: Auth = Depends(current), db: Session = Depends(get_db)):
    """只上报事件、不带快照（有事件要结算、快照又没变时用）。"""
    acc = lock_account(db, auth.id)
    econ = economy()
    st = load_state(acc)
    res = _events(db, econ, acc, st, req.events)
    store_state(acc, st)
    db.commit()
    sv = db.get(Save, acc.id)
    return stamp({"ok": True, "version": sv.version if sv else 0, "state": econ.client_state(st), "events": res})


@router.put("/save", response_model=SaveResp)
def put_save(req: SaveReq, auth: Auth = Depends(current), db: Session = Depends(get_db)):
    """上传快照（可以顺带一批事件）。base 必须等于服务器当前版本，否则 409；校验不过 422（事件照样结算）。"""
    s = get_settings()
    raw, snap = unpack(req.data)
    if str(snap.get("player_id", "")) != auth.id:
        raise ApiError(400, "id_mismatch", "快照里的玩家 id 和账号不一致")
    acc = lock_account(db, auth.id)
    sv = db.get(Save, acc.id)
    if sv is None:
        sv = Save(account_id=acc.id, version=0, hash="", data=None, saved_at=0, energy=0, rush=0)
        db.add(sv)
    if req.base != sv.version:
        raise ApiError(409, "stale", "云端有更新的版本", version=sv.version)
    econ = economy()
    st = load_state(acc)
    econ.ensure_day(st)
    results = _events(db, econ, acc, st, req.events)
    now = clock.now()
    if st.pop("adopt_pending", False) and sv.data is None:
        econ.adopt(st, snap)
        audit(db, acc.id, "adopt", "第一份快照：沿用客户端的货币和进度")
    prev = {"energy": sv.energy, "rush": sv.rush} if sv.data is not None else None
    reason = econ.check_snapshot(st, prev, snap, now, now - float(sv.saved_at or 0))
    if reason:
        audit(db, acc.id, "snapshot_rejected", "v%d：%s" % (sv.version, reason))
        store_state(acc, st)
        db.commit()
        raise ApiError(422, "rejected", reason, version=sv.version, state=econ.client_state(st), events=results)
    if req.hash == sv.hash and sv.data is not None and not req.events:
        store_state(acc, st)
        db.commit()
        return stamp({"ok": True, "version": sv.version, "state": econ.client_state(st), "same": True})
    merged = econ.merge(st, snap)
    blob = pack(merged)
    _backup(db, acc.id, sv, st, s.backups_recent, s.backups_daily_days)
    sv.version += 1
    sv.hash = req.hash
    sv.data = blob
    sv.saved_at = int(now)
    sv.energy = int(float(snap.get("energy", 0) or 0))
    sv.rush = int(float(snap.get("rush", 0) or 0))
    acc.last_sync_at = clock.utcnow()
    store_state(acc, st)
    db.commit()
    return stamp({"ok": True, "version": sv.version, "state": econ.client_state(st), "events": results})


def _backup(db: Session, aid: str, sv: Save, st: dict, recent: int, daily_days: int) -> None:
    if sv.data is None:
        return
    now = clock.utcnow()
    db.add(SaveBackup(account_id=aid, kind="recent", day=today(), version=sv.version, data=sv.data, state=st, saved_at=now))
    db.flush()
    keep = select(SaveBackup.id).where(SaveBackup.account_id == aid, SaveBackup.kind == "recent") \
        .order_by(SaveBackup.version.desc()).limit(recent)
    db.execute(delete(SaveBackup).where(SaveBackup.account_id == aid, SaveBackup.kind == "recent",
                                        SaveBackup.id.not_in(keep.scalar_subquery())))
    has_today = db.execute(select(func.count()).select_from(SaveBackup).where(
        SaveBackup.account_id == aid, SaveBackup.kind == "daily", SaveBackup.day == today())).scalar()
    if not has_today:
        db.add(SaveBackup(account_id=aid, kind="daily", day=today(), version=sv.version, data=sv.data, state=st, saved_at=now))
        cutoff = clock.day(clock.now() - daily_days * 86400, get_settings().day_utc_offset_hours)
        db.execute(delete(SaveBackup).where(SaveBackup.account_id == aid, SaveBackup.kind == "daily", SaveBackup.day < cutoff))


# ---------------------------------------------------------------- 经济操作（统一走 _action：加锁、幂等、结算、返回新余额）

def _action(request: Request, auth: Auth, db: Session, endpoint: str, fn: Callable[[Economy, dict], dict]):
    key = idem_key(request)
    hit = idem_get(db, auth.id, key, endpoint)
    if hit is not None:
        return JSONResponse(hit.response, status_code=hit.status)
    acc = lock_account(db, auth.id)
    econ = economy()
    st = load_state(acc)
    econ.ensure_day(st)
    try:
        give = fn(econ, st)
    except Reject as r:
        resp = stamp(body(r.error, r.message, state=econ.client_state(st)))
        idem_put(db, auth.id, key, endpoint, r.status, resp)
        db.commit()
        return JSONResponse(resp, status_code=r.status)
    store_state(acc, st)
    resp = stamp({"ok": True, "state": econ.client_state(st), "give": give})
    idem_put(db, auth.id, key, endpoint, 200, resp)
    db.commit()
    log(logger, logging.INFO, "action", endpoint=endpoint, give=give)
    return resp


@router.post("/energy/buy", response_model=ActionResp)
def buy_energy(request: Request, auth: Auth = Depends(current), db: Session = Depends(get_db)):
    return _action(request, auth, db, "energy.buy", lambda e, st: e.buy_energy(st))


@router.post("/pass/buy", response_model=ActionResp)
def buy_pass(req: PassBuyReq, request: Request, auth: Auth = Depends(current), db: Session = Depends(get_db)):
    return _action(request, auth, db, "pass.buy", lambda e, st: e.buy_pass(st, req.tier))


@router.post("/pass/order", response_model=PayOrderResp)
def pass_order(req: PassOrderReq, request: Request, auth: Auth = Depends(current), db: Session = Depends(get_db)):
    """通行证下单（人民币）：贵宾 ¥30、超级贵宾 ¥68（server/config/economy.json 的 pass.vip_cny / super_cny）。
    付款成功回调里才开通，和琥珀礼包同一套订单。"""
    key = idem_key(request)
    hit = idem_get(db, auth.id, key, "pass.order")
    if hit is not None:
        return JSONResponse(hit.response, status_code=hit.status)
    if req.provider != "mock" or not get_settings().enable_mock_payment:
        raise ApiError(501, "payment_not_configured", "这个支付渠道还没有接入")
    econ = economy()
    st = load_state(lock_account(db, auth.id))
    try:
        econ.check_pass_tier(st, req.tier)
    except Reject as r:
        resp = stamp(body(r.error, r.message))
        idem_put(db, auth.id, key, "pass.order", r.status, resp)
        db.commit()
        return JSONResponse(resp, status_code=r.status)
    o = PayOrder(id="po_" + secrets.token_hex(12), account_id=auth.id, pack=0, amber=0,
                 price=econ.pass_price(st, req.tier), provider=req.provider, status="created", created_at=clock.utcnow(),
                 kind="pass", ref=req.tier)
    db.add(o)
    resp = _order_out(o)
    idem_put(db, auth.id, key, "pass.order", 200, resp)
    db.commit()
    return resp


@router.post("/pass/claim", response_model=ActionResp)
def claim_pass(req: PassClaimReq, request: Request, auth: Auth = Depends(current), db: Session = Depends(get_db)):
    return _action(request, auth, db, "pass.claim", lambda e, st: e.claim_pass(st, req.track, req.level))


@router.post("/storage/expand", response_model=ActionResp)
def expand(request: Request, auth: Auth = Depends(current), db: Session = Depends(get_db)):
    return _action(request, auth, db, "storage.expand", lambda e, st: e.expand_storage(st))


@router.post("/build", response_model=ActionResp)
def build(req: BuildReq, request: Request, auth: Auth = Depends(current), db: Session = Depends(get_db)):
    return _action(request, auth, db, "build", lambda e, st: e.build(st, req.area))


@router.post("/chest/open", response_model=ActionResp)
def open_chest(request: Request, auth: Auth = Depends(current), db: Session = Depends(get_db)):
    return _action(request, auth, db, "chest.open", lambda e, st: e.open_chest(st))


@router.post("/pack/open", response_model=ActionResp)
def open_pack(request: Request, auth: Auth = Depends(current), db: Session = Depends(get_db)):
    return _action(request, auth, db, "pack.open", lambda e, st: e.open_pack(st))


@router.post("/book/claim", response_model=ActionResp)
def claim_book(req: BookReq, request: Request, auth: Auth = Depends(current), db: Session = Depends(get_db)):
    return _action(request, auth, db, "book.claim", lambda e, st: e.claim_book(st, req.item))


@router.post("/level/claim", response_model=ActionResp)
def claim_level(req: LevelReq, request: Request, auth: Auth = Depends(current), db: Session = Depends(get_db)):
    return _action(request, auth, db, "level.claim", lambda e, st: e.claim_level(st, req.level))


# ---------------------------------------------------------------- 集市

def _picks(db: Session, econ: Economy, aid: str, refresh: bool = False) -> list:
    """今天的热卖换货：每人每天按服务器存的最新快照抽一次，存库。还没快照时不换（用底子）。"""
    d = today()
    row = db.get(HotDeal, (aid, d))
    if row is not None and not refresh:
        return row.picks
    sv = db.get(Save, aid)
    snap = unpack_blob(sv.data) if sv and sv.data else None
    if snap is None and not refresh:
        return []
    picks = econ.reroll_hot_all(econ.hot_list(row.picks if row else [])) if refresh else econ.roll_hot(econ.wanted(snap))
    if row is None:
        db.add(HotDeal(account_id=aid, day=d, picks=picks, rolled_at=clock.utcnow()))
    else:
        row.picks = picks
        row.rolled_at = clock.utcnow()
    db.execute(delete(HotDeal).where(HotDeal.account_id == aid, HotDeal.day < clock.day(clock.now() - 7 * 86400)))
    db.flush()
    return picks


@router.get("/shop")
def shop(auth: Auth = Depends(current), db: Session = Depends(get_db)):
    econ = economy()
    acc = lock_account(db, auth.id)
    st = load_state(acc)
    econ.ensure_day(st)
    store_state(acc, st)
    db.commit()
    picks = _picks(db, econ, auth.id)
    db.commit()
    return stamp({"ok": True, "picks": picks, "offers": econ.offers(st, picks), "hot_revision": st.get("hot_revision", 0),
                  "secs_to_midnight": clock.secs_to_midnight(get_settings().day_utc_offset_hours),
                  "shell_period": econ.shell_period(), "shell_secs_left": econ.shell_secs_left()})


@router.post("/shop/buy", response_model=ActionResp)
def shop_buy(req: ShopBuyReq, request: Request, auth: Auth = Depends(current), db: Session = Depends(get_db)):
    def fn(e: Economy, st: dict) -> dict:
        return e.shop_buy(st, _picks(db, e, auth.id), req.key, req.item)
    return _action(request, auth, db, "shop.buy", fn)


@router.post("/shop/refresh", response_model=ActionResp)
def refresh_shop(request: Request, auth: Auth = Depends(current), db: Session = Depends(get_db)):
    def fn(e: Economy, st: dict) -> dict:
        e.refresh_hot(st)
        return {"picks": _picks(db, e, auth.id, refresh=True)}
    return _action(request, auth, db, "shop.refresh", fn)


@router.post("/merge/bubble", response_model=ActionResp)
def merge_bubble(req: MergeBubbleReq, request: Request, auth: Auth = Depends(current), db: Session = Depends(get_db)):
    def fn(e: Economy, st: dict) -> dict:
        saved = db.get(Save, auth.id)
        snap = unpack_blob(saved.data) if saved and saved.data else {}
        if snap and snap.get("tutorial_on", False):
            return {}
        return e.merge_bubble(st, req.item)
    return _action(request, auth, db, "merge.bubble", fn)


@router.post("/merge/bubble/buy", response_model=ActionResp)
def buy_merge_bubble(req: BubbleBuyReq, request: Request, auth: Auth = Depends(current), db: Session = Depends(get_db)):
    return _action(request, auth, db, "merge.bubble.buy", lambda e, st: e.buy_merge_bubble(st, req.uid))


# ---------------------------------------------------------------- 充值（下单 → 支付渠道回调到账）

def _order_out(o: PayOrder, st: dict | None = None) -> dict:
    out = {"ok": True, "order_id": o.id, "status": o.status, "amber": o.amber, "price": o.price, "provider": o.provider,
           "pay_params": {"mock_pay_url": "/v1/payments/mock/%s/pay" % o.id} if o.provider == "mock" and o.status == "created" else {}}
    if o.kind == "gift":  # 礼包链付费步：带上步数和到账时发的东西
        out.update({"kind": "gift", "step": o.pack, "give": o.give or {}})
    elif o.kind == "ufo":
        out.update({"kind": "ufo", "give": o.give or {}})
    elif o.kind == "offer":  # 付费限时礼包：ref = "kind:期开始时间:档位"
        out.update({"kind": "offer", "ref": o.ref, "give": o.give or {}})
    elif o.kind == "pass":  # 通行证：带上档位和到账时发的东西
        out.update({"kind": "pass", "tier": o.ref, "give": o.give or {}})
    if st is not None:
        out["state"] = economy().client_state(st)
        if o.kind == "gift":
            from . import gift_chain
            out["chain"] = gift_chain.view(st, clock.now())
    return stamp(out)


@router.post("/payments/orders", response_model=PayOrderResp)
def create_order(req: PayOrderReq, request: Request, auth: Auth = Depends(current), db: Session = Depends(get_db)):
    """下单。正式接入时这里调支付渠道统一下单，把 pay_params（签名后的拉起参数）交给客户端。"""
    key = idem_key(request)
    hit = idem_get(db, auth.id, key, "pay.order")
    if hit is not None:
        return JSONResponse(hit.response, status_code=hit.status)
    packs = gamedata().amber_packs
    if not (0 <= req.pack < len(packs)):
        raise ApiError(400, "bad_pack", "没有这个礼包")
    if req.provider != "mock" or not get_settings().enable_mock_payment:
        raise ApiError(501, "payment_not_configured", "这个支付渠道还没有接入")
    p = packs[req.pack]
    o = PayOrder(id="po_" + secrets.token_hex(12), account_id=auth.id, pack=req.pack, amber=int(p.get("n", 0)),
                 price=str(p.get("price", "")), provider=req.provider, status="created", created_at=clock.utcnow())
    db.add(o)
    resp = _order_out(o)
    idem_put(db, auth.id, key, "pay.order", 200, resp)
    db.commit()
    return resp


@router.post("/payments/mock/{order_id}/pay", response_model=PayOrderResp)
def mock_pay(order_id: str, auth: Auth = Depends(current), db: Session = Depends(get_db)):
    """mock 支付渠道的「支付成功回调」。正式渠道是 /v1/payments/notify/<渠道>，验签后走同一个 _fulfil。"""
    if not get_settings().enable_mock_payment:
        raise ApiError(403, "payment_disabled", "mock 支付只在开发环境可用")
    o = db.execute(select(PayOrder).where(PayOrder.id == order_id).with_for_update()).scalar_one_or_none()
    if o is None or o.account_id != auth.id:
        raise ApiError(404, "unknown_order", "订单不存在")
    st = _fulfil(db, o, "mock_" + secrets.token_hex(6))
    db.commit()
    return _order_out(o, st)


def _fulfil(db: Session, o: PayOrder, provider_ref: str) -> dict:
    """支付成功：只在 created → paid 时到账一次（重复回调不会重复加）。"""
    acc = lock_account(db, o.account_id)
    st = load_state(acc)
    if o.status == "created":
        o.status = "paid"
        o.paid_at = clock.utcnow()
        o.provider_ref = provider_ref
        if o.kind == "gift":  # 礼包链付费步：验单成功才发奖、队列前移
            from . import gift_chain
            o.give = gift_chain.fulfil(db, economy(), acc.id, st, o, clock.now())
        elif o.kind == "ufo":
            from . import ufo_offer
            ufo_offer.fulfil(economy(), st, o)
        elif o.kind == "offer":  # 付费限时礼包：按下单时冻结的奖励发，同一期记一次已购
            from . import offers
            o.give = {**(o.give or {}), **offers.fulfil(economy(), st, o)}
        elif o.kind == "pass":  # 通行证：付款成功才开通档位
            try:
                o.give = economy().activate_pass(st, o.ref or "")
            except Reject as r:  # 两张单都付了（比如先下贵宾单又买了超级）：不重复开通，记下来等人工退款
                o.give = {}
                log(logger, logging.WARNING, "pass order not applied", order_id=o.id, reason=r.error)
        else:
            st["amber"] = int(st.get("amber", 0)) + o.amber
        from . import seven_day
        if o.kind not in ("gift", "pass", "ufo", "offer"):
            seven_day.record(economy(), st, "amber", o.amber)
        if o.provider != "mock":
            from decimal import Decimal
            seven_day.record(economy(), st, "paid_cents", int(Decimal(o.price.replace("¥", "").replace("￥", "").replace("元", "").strip()) * 100))
        store_state(acc, st)
        log(logger, logging.INFO, "payment fulfilled", order_id=o.id, amber=o.amber)
    return st


@router.get("/payments/orders/{order_id}", response_model=PayOrderResp)
def get_order(order_id: str, auth: Auth = Depends(current), db: Session = Depends(get_db)):
    o = db.get(PayOrder, order_id)
    if o is None or o.account_id != auth.id:
        raise ApiError(404, "unknown_order", "订单不存在")
    return _order_out(o, load_state(auth.account))


# ---------------------------------------------------------------- 排行榜（进度由服务器从 builds 算）

def _rank_of(db: Session, acc: Account) -> dict:
    ahead = db.execute(select(func.count()).select_from(Account).where(or_(
        Account.rank_progress > acc.rank_progress,
        (Account.rank_progress == acc.rank_progress) & (Account.rank_reached_at < acc.rank_reached_at),
        (Account.rank_progress == acc.rank_progress) & (Account.rank_reached_at == acc.rank_reached_at) & (Account.id < acc.id),
    ))).scalar()
    return {"rank": ahead + 1, "id": acc.id, "name": acc.nick or ("原始人" + acc.id[-4:]), "progress": acc.rank_progress,
            "reached_at": acc.rank_reached_at}


@router.get("/rank/top")
def rank_top(request: Request, n: int = Query(50, ge=1, le=200), db: Session = Depends(get_db)):
    rows = db.execute(select(Account).where(Account.rank_progress > 0)
                      .order_by(Account.rank_progress.desc(), Account.rank_reached_at.asc(), Account.id.asc()).limit(n)).scalars().all()
    total = db.execute(select(func.count()).select_from(Account).where(Account.rank_progress > 0)).scalar()
    me = None
    h = request.headers.get("authorization", "")
    if h.lower().startswith("bearer "):
        from .models import AuthSession
        sess = db.get(AuthSession, hash_token(h[7:].strip()))
        if sess is not None and sess.revoked_at is None:
            acc = db.get(Account, sess.account_id)
            if acc is not None and acc.rank_progress > 0:
                me = _rank_of(db, acc)
    top = [{"rank": i + 1, "id": a.id, "name": a.nick or ("原始人" + a.id[-4:]), "progress": a.rank_progress,
            "reached_at": a.rank_reached_at} for i, a in enumerate(rows)]
    return stamp({"ok": True, "total": total, "top": top, "me": me})


@router.post("/rank/name")
def rank_name(req: NameReq, auth: Auth = Depends(current), db: Session = Depends(get_db)):
    acc = db.get(Account, auth.id)
    acc.nick = req.name.strip().replace("\n", " ")[:16]
    db.commit()
    return stamp({"ok": True, "me": _rank_of(db, acc) if acc.rank_progress > 0 else None})


@router.post("/merge-event/action", response_model=ActionResp)
def merge_event_action(req: MergeEventReq, request: Request, auth: Auth = Depends(current), db: Session = Depends(get_db)):
    from . import merge_event
    return _action(request, auth, db, "merge_event." + req.action, lambda e, st: merge_event.action(e, st, req))


@router.post("/chest/choose", response_model=ActionResp)
def choice_chest(req: ChoiceChestReq, request: Request, auth: Auth = Depends(current), db: Session = Depends(get_db)):
    return _action(request, auth, db, "chest.choose", lambda e, st: e.choose_chest(st, req.box, req.option))


from .schemas import SevenDayClaimReq

@router.post("/seven-day/claim", response_model=ActionResp)
def seven_day_claim(req: SevenDayClaimReq, request: Request, auth: Auth = Depends(current), db: Session = Depends(get_db)):
    from . import seven_day
    return _action(request, auth, db, "seven_day.claim", lambda e, st: seven_day.claim(e, st, req.entry, req.stage))

@router.post("/shop/shell/refresh", response_model=ActionResp)
def shell_refresh(request: Request, auth: Auth = Depends(current), db: Session = Depends(get_db)):
    def refresh(e, st):
        e.ensure_shell(st)
        e._spend(st, "amber", e.gd.shell_refresh_amber)
        st["shell_bought"] = {}
        return {}
    return _action(request, auth, db, "shop.shell.refresh", refresh)


@router.post("/gm/activities", response_model=ActionResp)
def gm_activities(request: Request, auth: Auth = Depends(current), db: Session = Depends(get_db)):
    if get_settings().env not in ("dev", "test"):
        raise ApiError(403, "gm_disabled", "当前环境未开放 GM")
    def unlock(e, st):
        st["gm_activities"] = True
        return {}
    return _action(request, auth, db, "gm.activities", unlock)


@router.post("/daily/ad/start", response_model=ActionResp)
def daily_ad_start(request: Request, auth: Auth = Depends(current), db: Session = Depends(get_db)):
    from . import daily_shop
    return _action(request, auth, db, "daily.ad.start", daily_shop.ad_start)


@router.post("/daily/claim", response_model=ActionResp)
def daily_claim(payload: dict, request: Request, auth: Auth = Depends(current), db: Session = Depends(get_db)):
    from . import daily_shop
    return _action(request, auth, db, "daily.claim", lambda e, st: daily_shop.claim(e, st, str(payload.get("key", ""))))


@router.post("/energy-chest/open", response_model=ActionResp)
def energy_chest_open(request: Request, auth: Auth = Depends(current), db: Session = Depends(get_db)):
    from . import daily_shop
    return _action(request, auth, db, "energy_chest.open", daily_shop.energy_chest)


def _latest_snapshot(db, aid):
    sv = db.get(Save, aid)
    return unpack_blob(sv.data) if sv and sv.data else {}


@router.post("/ufo/visit", response_model=ActionResp)
def ufo_visit(payload: dict, request: Request, auth: Auth = Depends(current), db: Session = Depends(get_db)):
    from . import ufo_offer
    return _action(request, auth, db, "ufo.visit", lambda e, st: ufo_offer.visit(e, st, _latest_snapshot(db, auth.id), payload.get("received", [])[:256], bool(payload.get("refresh"))))


@router.post("/ufo/order", response_model=PayOrderResp)
def ufo_order(payload: dict, request: Request, auth: Auth = Depends(current), db: Session = Depends(get_db)):
    from . import ufo_offer
    if not get_settings().enable_mock_payment:
        raise ApiError(501, "payment_not_configured", "这个支付渠道还没有接入")
    key = idem_key(request)
    hit = idem_get(db, auth.id, key, "ufo.order")
    if hit is not None:
        return JSONResponse(hit.response, status_code=hit.status)
    st = load_state(lock_account(db, auth.id))
    ref = str(payload.get("offer", ""))
    try:
        items = ufo_offer.reviewed(economy(), st, _latest_snapshot(db, auth.id), ref)
    except Reject as r:
        raise ApiError(r.status, r.error, r.message)
    o = db.execute(select(PayOrder).where(PayOrder.account_id == auth.id, PayOrder.kind == "ufo", PayOrder.ref == ref)).scalar_one_or_none()
    if o is None:
        o = PayOrder(id="po_" + secrets.token_hex(12), account_id=auth.id, pack=-1, amber=0, kind="ufo", ref=ref,
                     price="¥%d" % gamedata().ufo_offer['price_cny'], provider="mock", status="created", created_at=clock.utcnow(), give={"items": items})
        db.add(o)
    elif o.status == "created" and o.give.get("items") != items:
        # One order per visit; the originally reviewed order stays frozen.
        raise ApiError(409, "ufo_changed", "礼包需求已变化，请等待下一次飞碟")
    resp = _order_out(o)
    idem_put(db, auth.id, key, "ufo.order", 200, resp)
    db.commit()
    return resp


from pydantic import Field
from .schemas import Req


class OfferOpenReq(Req):
    offer: str = Field(min_length=1, max_length=16)


class OfferOrderReq(Req):
    offer: str = Field(min_length=1, max_length=16)
    tier: int = 0
    provider: str = "mock"


@router.post("/offer/open", response_model=ActionResp)
def offer_open(req: OfferOpenReq, request: Request, auth: Auth = Depends(current), db: Session = Depends(get_db)):
    """付费限时礼包开一期（赶大集到点自动开 / 火种大礼包体力用完时开）。等级、冷却由服务器判定。"""
    from . import offers
    return _action(request, auth, db, "offer.open", lambda e, st: offers.open_window(e, st, req.offer))


@router.post("/offer/order", response_model=PayOrderResp)
def offer_order(req: OfferOrderReq, request: Request, auth: Auth = Depends(current), db: Session = Depends(get_db)):
    """付费限时礼包下单（PayOrder kind = offer）。到账只在支付回调里（_fulfil → offers.fulfil）。"""
    from . import offers
    if req.provider != "mock" or not get_settings().enable_mock_payment:
        raise ApiError(501, "payment_not_configured", "这个支付渠道还没有接入")
    key = idem_key(request)
    hit = idem_get(db, auth.id, key, "offer.order")
    if hit is not None:
        return JSONResponse(hit.response, status_code=hit.status)
    st = load_state(lock_account(db, auth.id))
    try:
        ref, price, rewards = offers.reviewed(economy(), st, req.offer, req.tier)
    except Reject as r:
        raise ApiError(r.status, r.error, r.message)
    o = PayOrder(id="po_" + secrets.token_hex(12), account_id=auth.id, pack=req.tier, amber=0, kind="offer", ref=ref,
                 price=price, provider=req.provider, status="created", created_at=clock.utcnow(), give={"rewards": rewards})
    db.add(o)
    resp = _order_out(o)
    idem_put(db, auth.id, key, "offer.order", 200, resp)
    db.commit()
    return resp


from .schemas import DuelActionReq

@router.post("/duel/action", response_model=ActionResp)
def duel_action(req: DuelActionReq, request: Request, auth: Auth = Depends(current), db: Session = Depends(get_db)):
    from . import duel_race
    return _action(request, auth, db, "duel." + req.action, lambda e, st: duel_race.action(e, st, req))
