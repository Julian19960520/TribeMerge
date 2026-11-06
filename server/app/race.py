"""异步联机活动第一期：篝火竞速 + 影子对手（设计见 DESIGN.md「十三、异步联机活动」）。

- 不限时：unlock_level（12）级以上随时点「匹配」开一局；一局结束、领完奖就可以再匹配下一局。
- 假匹配：每局只有自己一个真人，group_size-1 个影子按等级段（tier_levels 级一档）挑；客户端播几秒匹配动画。
  fill_sec（默认 0）后封组开赛（start），最长比 duration_sec。开赛前交的单不算。
- 影子：优先回放同等级段真人最近 history_days 天的分数曲线（按开赛后的时间回放，按场次时长缩放）；没有就按等级生成一条。
- 分数：服务器收到并接受的交付订单事件的理论火苗（gamedata.flames 之和，副产物已按掉率折算），按服务器收到的时间记。
  每人有分数上限：burst + flames_per_energy ×（报名以来回复的体力 + 报名以来买体力次数 × energy_per_buy），超出不计、记审计。
- 结束：先到 target 的赢；前 podium 名都到线（或时间到）就结束。名次按「到线时间 → 分数 → 最后得分时间」排。
- 领奖：POST /v1/race/claim，幂等键 + 每个名次只领一次；第 1 名拿限时称号（state.race_title）。
- 客户端只在活动界面打开时每 30 秒 GET /v1/race 一次，两次之间自己插值。
"""

import hashlib
import json
import logging
import random
import secrets
from collections.abc import Callable
from functools import lru_cache

from fastapi import APIRouter, Depends, Request
from fastapi.responses import JSONResponse
from pydantic import Field
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from . import clock
from .config import get_settings
from .db import get_db
from .economy import Economy, Reject, num
from .errors import ApiError, body
from .logs import log
from .models import Account, RaceEntry, RaceGroup
from .schemas import Req
from .security import Auth, current, lock_account
from .services import audit, economy, gamedata, idem_get, idem_key, idem_put, load_state, stamp, store_state

router = APIRouter(prefix="/v1", tags=["活动"])
logger = logging.getLogger("tribe.race")

KIND = "race"


# ---------------------------------------------------------------- 配置 / 场次

@lru_cache
def _file_cfg(path: str) -> dict:
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def cfg() -> dict:
    s = get_settings()
    c = dict(_file_cfg(s.race_config))
    c.update(s.race_overrides or {})
    return c


def tier_of(level: int, c: dict) -> int:
    return max(0, level - 1) // max(1, num(c.get("tier_levels"), 5))


def _avatar(aid: str, c: dict) -> int:
    return int(hashlib.md5(aid.encode()).hexdigest(), 16) % max(1, num(c.get("avatars"), 8))


# ---------------------------------------------------------------- 影子曲线

def gen_curve(rng: random.Random, level: int, dur: int, target: int, sh: dict) -> list:
    """按等级生成一条合理的分数曲线 [[距开赛秒数, 累计分], ...]：按 nominal_sec（2 小时）的节奏生成，再缩放到本场时长。"""
    nominal = float(num(sh.get("nominal_sec"), 7200) or 7200)
    pace = (float(sh.get("pace_base", 110)) + float(sh.get("pace_per_level", 10)) * level) \
        * rng.uniform(float(sh.get("pace_min", 0.55)), float(sh.get("pace_max", 1.3)))
    total = pace * nominal / 3600.0
    avg = float(sh.get("order_base", 6)) + float(sh.get("order_per_level", 0.8)) * level
    mean_gap = nominal / max(3.0, total / avg)
    t = rng.uniform(0.0, 0.06) * nominal
    s = 0.0
    pts: list = []
    while True:
        gap = rng.expovariate(1.0 / mean_gap)
        if rng.random() < 0.07:  # 歇一会儿
            gap *= 4.0
        t += gap
        if t >= nominal:
            break
        s += max(1.0, round(avg * rng.uniform(0.4, 1.7)))
        pts.append([int(t * dur / nominal), float(min(s, target))])
        if s >= target:
            break
    return pts


def _replay(e: RaceEntry, g: RaceGroup, t: float) -> tuple[float, int | None, int]:
    """t 时刻的 (分数, 到线时间, 最后得分时间)。真人用服务器记的值；影子按开赛后的时间回放曲线。"""
    if not e.shadow:
        return float(e.score), e.finished_at, int(e.last_at)
    rel = t - g.start
    s, fin, last = 0.0, None, int(g.start)
    for p in e.points or []:
        if p[0] > rel:
            break
        s = min(float(p[1]), float(g.target))
        last = int(g.start + p[0])
        if fin is None and s >= g.target:
            fin = last
    return s, fin, last


# ---------------------------------------------------------------- 组：封组、结束、排名

def _members(db: Session, g: RaceGroup) -> list[RaceEntry]:
    return list(db.execute(select(RaceEntry).where(RaceEntry.group_id == g.id).order_by(RaceEntry.slot)).scalars().all())


def _fill_shadows(db: Session, g: RaceGroup, ms: list[RaceEntry], now: float, c: dict) -> None:
    size = num(c.get("group_size"), 5)
    used = {m.slot for m in ms}
    free = [i for i in range(size) if i not in used]
    if not free:
        return
    rng = random.Random(g.id)
    sh = c.get("shadow") or {}
    since = int(now) - num(sh.get("history_days"), 14) * 86400
    rows = db.execute(
        select(RaceEntry, RaceGroup).join(RaceGroup, RaceEntry.group_id == RaceGroup.id).where(
            RaceGroup.kind == g.kind, RaceGroup.tier == g.tier, RaceGroup.settled.is_(True), RaceGroup.start >= since,
            RaceGroup.id != g.id, RaceEntry.shadow.is_(False), RaceEntry.score > 0)
        .order_by(RaceEntry.id.desc()).limit(300)).all()
    rows = list(rows)
    rng.shuffle(rows)
    seen = {m.account_id for m in ms if m.account_id}
    picked = []
    for e, sg in rows:
        if len(picked) >= len(free):
            break
        if e.account_id in seen or not e.points:
            continue
        seen.add(e.account_id)
        picked.append((e, sg))
    names = [str(n) for n in c.get("names") or []]
    rng.shuffle(names)
    taken = {m.name for m in ms}
    levels = [m.level for m in ms if not m.shadow] or [tier_of(1, c) * num(c.get("tier_levels"), 5) + 3]
    avg_lv = round(sum(levels) / len(levels))
    for i, slot in enumerate(free):
        name = next((n for n in names if n not in taken), "原始人%02d" % rng.randrange(100))
        taken.add(name)
        if i < len(picked):
            src, sg = picked[i]
            k = (g.end - g.start) / max(1, sg.end - sg.start)
            pts = [[int(round(float(p[0]) * k)), float(p[1])] for p in src.points]
            lv, source = src.level, "entry:%d" % src.id
        else:
            lv = max(1, avg_lv + rng.randint(-1, 1))
            pts = gen_curve(rng, lv, g.end - g.start, g.target, sh)
            source = "gen"
        db.add(RaceEntry(group_id=g.id, slot=slot, session=g.session, account_id=None, shadow=True, source=source, name=name,
                         avatar=rng.randrange(max(1, num(c.get("avatars"), 8))), level=lv, joined_at=g.start, score=0.0,
                         points=pts, last_at=g.start, buys0=0, buys_day="", capped=0.0, claimed=True))


def _seal(db: Session, g: RaceGroup, now: float, c: dict) -> None:
    if g.sealed:
        return
    ms = _members(db, g)
    reals = sum(1 for m in ms if not m.shadow)
    deadline = g.created_at + num(c.get("fill_sec"), 20)
    if reals < num(c.get("group_size"), 5) and now < deadline:
        return
    try:
        with db.begin_nested():
            g.start = int(min(now, deadline))
            g.end = g.start + num(c.get("duration_sec"), 7200)
            _fill_shadows(db, g, ms, now, c)
            g.sealed = True
    except IntegrityError:  # 另一个请求刚封了这组
        db.refresh(g)


def update(db: Session, g: RaceGroup, now: float, c: dict | None = None) -> None:
    """按当前时间推进这组：到点封组补影子；前 podium 名都到线或时间到就结束并排名次。"""
    c = c or cfg()
    _seal(db, g, now, c)
    if g.ended_at is None and g.sealed:
        ms = _members(db, g)
        t = min(now, g.end)
        fins = sorted(f for f in (_replay(m, g, t)[1] for m in ms) if f is not None)
        podium = max(1, min(num(c.get("podium"), 3), len(ms)))
        if len(fins) >= podium:
            g.ended_at = int(fins[podium - 1])
        elif now >= g.end:
            g.ended_at = int(g.end)
    if g.ended_at is not None and not g.settled and now >= g.ended_at:
        _settle(g, _members(db, g), c)


def _settle(g: RaceGroup, ms: list[RaceEntry], c: dict) -> None:
    t = float(g.ended_at)
    rows = []
    for m in ms:
        s, fin, last = _replay(m, g, t)
        rows.append((m, s, fin, last))
    rows.sort(key=lambda r: (r[2] is None, r[2] or 0, -r[1], r[3], r[0].slot))
    rewards = c.get("rewards") or []
    for i, (m, s, fin, last) in enumerate(rows):
        m.place = i + 1
        if m.shadow:  # 冻结影子的最终成绩
            m.score, m.finished_at, m.last_at = s, fin, last
        else:
            m.reward = rewards[i] if i < min(3, num(c.get("podium"), 3), len(rewards)) else []
    g.settled = True


def view(db: Session, g: RaceGroup, me: str, now: float, c: dict) -> dict:
    """给客户端看的一组：不暴露谁是影子，也不给影子未来的曲线。"""
    t = min(now, g.end, g.ended_at if g.ended_at is not None else now)
    out = []
    for m in _members(db, g):
        s, fin, last = _replay(m, g, t)
        out.append({"slot": m.slot, "name": m.name, "avatar": m.avatar, "level": m.level, "score": round(s, 1),
                    "finished_at": fin, "last_at": last, "place": m.place, "me": (not m.shadow) and m.account_id == me})
    state = "ended" if g.ended_at is not None and now >= g.ended_at else ("running" if g.sealed else "matching")
    return {"id": g.id, "session": g.session, "start": g.start, "end": g.end, "ended_at": g.ended_at, "target": g.target,
            "size": num(c.get("group_size"), 5), "state": state, "members": out}


def _me(e: RaceEntry) -> dict:
    return {"place": e.place, "reward": (e.reward or []) if 1 <= int(e.place or 0) <= 3 else [], "claimed": e.claimed, "score": round(e.score, 1), "capped": round(e.capped, 1),
            "joined_at": e.joined_at}


# ---------------------------------------------------------------- 计分（交付订单事件）

def score_cap(e: RaceEntry, g: RaceGroup, st: dict, now: float, c: dict) -> float:
    cc = c.get("cap") or {}
    regen = max(1, num(gamedata().rules.get("regen_sec", 120), 120))
    elapsed = max(0.0, now - max(g.start, e.joined_at))
    buys = num(st.get("energy_buys"))
    if str(st.get("deals_day", "")) == e.buys_day:
        buys -= e.buys0
    buys = max(0, buys)
    return float(cc.get("burst", 200)) + float(cc.get("flames_per_energy", 2.0)) * (
        elapsed / regen + buys * float(cc.get("energy_per_buy", 100)))


def on_order(db: Session, acc: Account, st: dict, order: dict, now: float) -> float:
    """服务器接受了一张交付订单：给正在进行的竞速加分。返回计入的分数。"""
    c = cfg()
    e = latest(db, acc.id)
    if e is None or e.finished_at is not None:
        return 0.0
    g = db.get(RaceGroup, e.group_id)
    update(db, g, now, c)
    if not g.sealed or g.ended_at is not None or now >= g.end or now < g.start:
        return 0.0
    gd = gamedata()
    pts = round(sum(gd.flames(str(x)) for x in order.get("items") or []), 2)
    if pts <= 0:
        return 0.0
    room = max(0.0, score_cap(e, g, st, now, c) - e.score)
    got = min(pts, room)
    if got < pts:
        e.capped = round(e.capped + pts - got, 2)
        audit(db, acc.id, "race_capped", "%s 交单 %.1f 分，上限只剩 %.1f" % (g.id, pts, room))
    if got <= 0:
        return 0.0
    e.score = min(float(g.target), round(e.score + got, 2))
    e.last_at = int(now)
    e.points = list(e.points or []) + [[int(now) - g.start, e.score]]
    if e.score >= g.target:
        e.finished_at = int(now)
    update(db, g, now, c)
    return got


# ---------------------------------------------------------------- 报名 / 领奖

def latest(db: Session, aid: str) -> RaceEntry | None:
    """这个玩家最近一局的位置。"""
    return db.execute(select(RaceEntry).where(RaceEntry.account_id == aid, RaceEntry.shadow.is_(False))
                      .order_by(RaceEntry.id.desc()).limit(1)).scalar_one_or_none()


def join(db: Session, acc: Account, st: dict, now: float, c: dict) -> RaceEntry:
    level = num(st.get("level"), 1)
    if not st.get("gm_activities") and level < num(c.get("unlock_level"), 12):
        raise Reject("race_locked", "%d 级解锁篝火竞速" % num(c.get("unlock_level"), 12))
    e = latest(db, acc.id)
    if e is not None:
        g0 = db.get(RaceGroup, e.group_id)
        update(db, g0, now, c)
        if g0.ended_at is None or now < g0.ended_at:
            return e  # 这一局还没比完：还是这一局
    tier = tier_of(level, c)
    size = num(c.get("group_size"), 5)
    g = None  # 假匹配：每局只有自己一个真人，其余位置全补影子
    if g is None:
        gid = "g" + secrets.token_hex(8)
        g = RaceGroup(id=gid, kind=KIND, session=gid, tier=tier, start=int(now),
                      end=int(now) + num(c.get("fill_sec"), 20) + num(c.get("duration_sec"), 7200), target=num(c.get("target"), 300), created_at=int(now), sealed=False, settled=False, meta={})
        db.add(g)
        db.flush()
    slot = len(_members(db, g))
    e = RaceEntry(group_id=g.id, slot=slot, session=g.id, account_id=acc.id, shadow=False, source="",
                  name=acc.nick or ("原始人" + acc.id[-4:]), avatar=_avatar(acc.id, c), level=level, joined_at=int(now), score=0.0,
                  points=[], last_at=int(now), buys0=num(st.get("energy_buys")), buys_day=str(st.get("deals_day", "")),
                  capped=0.0, claimed=False)
    db.add(e)
    db.flush()
    update(db, g, now, c)
    return e


def claim(db: Session, econ: Economy, acc: Account, st: dict, gid: str, now: float, c: dict) -> dict:
    e = db.execute(select(RaceEntry).where(RaceEntry.group_id == gid, RaceEntry.account_id == acc.id,
                                           RaceEntry.shadow.is_(False))).scalar_one_or_none()
    if e is None:
        raise Reject("unknown_race", "没有参加这一场", 404)
    g = db.get(RaceGroup, gid)
    update(db, g, now, c)
    if not g.settled:
        raise Reject("race_running", "比赛还没结束")
    if e.claimed:
        raise Reject("already_claimed", "这场的奖励已经领过了")
    out: dict = {}
    rw = (e.reward or []) if 1 <= int(e.place or 0) <= min(3, num(c.get("podium"), 3)) else []
    econ.grant(st, rw, out)
    title = None
    tc = c.get("title") or {}
    if e.place == 1 and tc:
        title = {"id": str(tc.get("id", "race_champ")), "name": str(tc.get("name", "篝火王")),
                 "until": int(now) + int(float(tc.get("hours", 24)) * 3600)}
        st["race_title"] = title
    e.claimed = True
    return {"give": out, "rewards": rw, "place": e.place, "title": title, "group": view(db, g, acc.id, now, c)}


# ---------------------------------------------------------------- 接口

class RaceClaimReq(Req):
    group: str = Field(pattern=r"^g[0-9a-f]{4,22}$")


def _rules(c: dict) -> dict:
    return {k: c.get(k) for k in ("unlock_level", "duration_sec", "fill_sec", "group_size", "target", "podium",
                                  "tier_levels", "rewards", "title")}


def _title(st: dict, now: float) -> dict | None:
    t = st.get("race_title")
    return t if isinstance(t, dict) and num(t.get("until")) > now else None


@router.get("/race")
def race_info(auth: Auth = Depends(current), db: Session = Depends(get_db)):
    """活动界面打开时每 30 秒拉一次：场次、自己这组的进度快照、待领的结算、称号、规则。"""
    for attempt in range(2):
        try:
            out = _race_info(db, auth.account, attempt)
            db.commit()
            return out
        except IntegrityError:
            db.rollback()
    raise ApiError(503, "busy", "请稍后再试")


def _race_info(db: Session, acc: Account, _attempt: int) -> dict:
    c = cfg()
    now = clock.now()
    cur = None
    e = latest(db, acc.id)
    if e is not None:
        g = db.get(RaceGroup, e.group_id)
        update(db, g, now, c)
        if not (g.settled and e.claimed):  # 正在比，或者比完了还没领奖
            cur = {"group": view(db, g, acc.id, now, c), "me": _me(e)}
    results = []
    for e in db.execute(select(RaceEntry).where(RaceEntry.account_id == acc.id, RaceEntry.shadow.is_(False),
                                                RaceEntry.claimed.is_(False)).order_by(RaceEntry.id.desc()).limit(5)).scalars():
        g = db.get(RaceGroup, e.group_id)
        update(db, g, now, c)
        if g.settled:
            results.append({"group": view(db, g, acc.id, now, c), "me": _me(e)})
    st = acc.state or {}
    return stamp({"ok": True, "current": cur, "results": results, "title": _title(st, now), "rules": _rules(c)})


def _race_action(request: Request, auth: Auth, db: Session, endpoint: str, fn: Callable[[Economy, Account, dict], dict]):
    key = idem_key(request)
    hit = idem_get(db, auth.id, key, endpoint)
    if hit is not None:
        return JSONResponse(hit.response, status_code=hit.status)
    acc = lock_account(db, auth.id)
    econ = economy()
    st = load_state(acc)
    econ.ensure_day(st)
    try:
        out = fn(econ, acc, st)
    except Reject as r:
        db.rollback()
        resp = stamp(body(r.error, r.message))
        idem_put(db, auth.id, key, endpoint, r.status, resp)
        db.commit()
        return JSONResponse(resp, status_code=r.status)
    store_state(acc, st)
    resp = stamp({"ok": True, "state": econ.client_state(st), **out})
    idem_put(db, auth.id, key, endpoint, 200, resp)
    db.commit()
    log(logger, logging.INFO, "race", endpoint=endpoint)
    return resp


@router.post("/race/join")
def race_join(request: Request, auth: Auth = Depends(current), db: Session = Depends(get_db)):
    def fn(econ: Economy, acc: Account, st: dict) -> dict:
        c = cfg()
        now = clock.now()
        e = join(db, acc, st, now, c)
        g = db.get(RaceGroup, e.group_id)
        return {"current": {"group": view(db, g, acc.id, now, c), "me": _me(e)}}
    return _race_action(request, auth, db, "race.join", fn)


@router.post("/race/claim")
def race_claim(req: RaceClaimReq, request: Request, auth: Auth = Depends(current), db: Session = Depends(get_db)):
    return _race_action(request, auth, db, "race.claim",
                        lambda econ, acc, st: claim(db, econ, acc, st, req.group, clock.now(), cfg()))
