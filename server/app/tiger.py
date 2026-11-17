"""逃离剑齿虎：100人10阶段异步联机匹配与淘汰结算。"""

import hashlib
import json
import uuid
from pathlib import Path

from sqlalchemy import select
from sqlalchemy.orm import Session

from . import clock
from .models import Account, TigerCohort, TigerEntry

DEFAULT_QUOTAS = [90, 80, 70, 60, 50, 40, 30, 20, 10, 10]
DEFAULT_INTERVAL = 10800.0
DEFAULT_BOT_NAMES = [
    "阿木", "石牙", "风铃", "大壮", "小岩",
    "火苗", "青叶", "黑石", "飞羽", "长矛",
    "月影", "山鹰", "草编", "泥碗", "星火",
]


def _load_config() -> dict:
    for p in [
        Path(__file__).resolve().parents[2] / "data" / "tiger_escape.json",
        Path(__file__).resolve().parents[1] / "config" / "tiger_escape.json",
    ]:
        if p.exists():
            try:
                return json.loads(p.read_text(encoding="utf-8"))
            except Exception:
                pass
    return {}


def _fraction(seed_str: str) -> float:
    digest = hashlib.sha256(seed_str.encode("utf-8")).hexdigest()
    return int(digest[:8], 16) / 4294967296.0


def _gen_bot_stage_times(cohort_id: str, slot: int, num_stages: int, interval: float, pace_min: float, pace_max: float) -> list[float]:
    pace = pace_min + (pace_max - pace_min) * _fraction(f"{cohort_id}:{slot}:pace")
    elapsed = 0.0
    times = []
    for leg in range(num_stages):
        elapsed += interval * pace * (0.8 + 0.4 * _fraction(f"{cohort_id}:{slot}:{leg}"))
        times.append(round(elapsed, 2))
    return times


def evaluate_cohort(cohort: TigerCohort, entries: list[TigerEntry], now: float) -> dict:
    """按100人、10阶段、每阶段名额淘汰10人的规则评估当前房间状态。"""
    elapsed = max(0.0, now - float(cohort.start_at))
    quotas = list(cohort.quotas or DEFAULT_QUOTAS)
    num_stages = len(quotas)

    # 先初始化每个人在当前 elapsed 下的理论进度与状态
    alive = set(range(len(entries)))
    statuses = ["running"] * len(entries)
    vis_stages = [0] * len(entries)
    destroyed = -1
    finished_at: float | None = None

    for i, e in enumerate(entries):
        times = list(e.stage_times or [])
        s = 0
        for t in times:
            if float(t) <= elapsed:
                s += 1
            else:
                break
        vis_stages[i] = min(s, num_stages)

    # 逐阶段按名额结算淘汰
    for s_idx in range(num_stages):
        q = int(quotas[s_idx])
        completed = []
        for i in alive:
            times = list(entries[i].stage_times or [])
            if len(times) > s_idx:
                completed.append((float(times[s_idx]), entries[i].slot, i))
        completed.sort(key=lambda x: (x[0], x[1]))

        if len(completed) >= q:
            cutoff_t = completed[q - 1][0]
            if elapsed >= cutoff_t:
                # 本阶段名额已满且当前时间已过截断时刻：第 q 名之后全部在 s_idx 节点被淘汰
                survivors_set = {item[2] for item in completed[:q]}
                for i in list(alive):
                    if i not in survivors_set:
                        statuses[i] = "lost"
                        vis_stages[i] = min(vis_stages[i], s_idx)
                        alive.remove(i)
                        if entries[i].slot == 0:
                            finished_at = float(cohort.start_at) + cutoff_t
                destroyed = max(destroyed, s_idx)
                continue
        # 尚未满额或尚未到达截断时刻：后续阶段也不会提前关闭
        break

    # 活着且跑完所有阶段的算胜利
    player_idx = 0
    for i, e in enumerate(entries):
        if e.slot == 0:
            player_idx = i
        if statuses[i] == "running" and vis_stages[i] >= num_stages:
            statuses[i] = "won"
            if e.slot == 0 and finished_at is None:
                times = list(e.stage_times or [])
                if len(times) >= num_stages:
                    finished_at = float(cohort.start_at) + float(times[num_stages - 1])

    player_entry = entries[player_idx]
    player_stage = vis_stages[player_idx]
    player_status = statuses[player_idx]

    # 计算玩家当前目标阶段的剩余名额
    target_idx = min(player_stage, num_stages - 1)
    stage_quota = int(quotas[target_idx])
    passed_target = sum(1 for i in alive if vis_stages[i] > target_idx)
    if player_status == "won":
        stage_remaining = 0
    else:
        stage_remaining = max(0, stage_quota - passed_target)

    total_survivors = sum(1 for st in statuses if st != "lost")
    bots_view = []
    for i, e in enumerate(entries):
        if e.slot == 0:
            continue
        bots_view.append({
            "slot": e.slot,
            "name": e.name,
            "avatar": e.avatar,
            "stage": vis_stages[i],
            "status": statuses[i],
            "is_bot": e.is_bot,
        })

    return {
        "cohort_id": cohort.id,
        "start": float(cohort.start_at),
        "player_count": cohort.player_count,
        "quotas": quotas,
        "stage": player_stage,
        "points": int(player_entry.points),
        "status": player_status,
        "destroyed": destroyed,
        "finished_at": finished_at,
        "survivors": total_survivors,
        "stage_quota": stage_quota,
        "stage_remaining": stage_remaining,
        "bots": bots_view,
    }


def join_cohort(db: Session, account: Account, now: float) -> dict:
    cfg = _load_config()
    player_count = int(cfg.get("player_count", 100))
    stages = cfg.get("stages", [])
    num_stages = len(stages) if stages else 10
    quotas = list(cfg.get("stage_quotas", DEFAULT_QUOTAS))
    if len(quotas) != num_stages:
        quotas = [max(1, player_count - (i + 1) * 10) for i in range(num_stages - 1)] + [10]
    interval = float(cfg.get("attack_interval_sec", DEFAULT_INTERVAL))
    bot_cfg = cfg.get("bots", {})
    pace_min = float(bot_cfg.get("pace_min", 0.45))
    pace_max = float(bot_cfg.get("pace_max", 1.4))

    cohort_id = "tc_" + uuid.uuid4().hex[:20]
    cohort = TigerCohort(
        id=cohort_id,
        account_id=account.id,
        start_at=now,
        player_count=player_count,
        quotas=quotas,
        status="running",
        created_at=clock.utcnow(),
    )
    db.add(cohort)

    nick = account.nick or ("原始人" + account.id[-4:])
    entries: list[TigerEntry] = []
    me = TigerEntry(
        cohort_id=cohort_id,
        slot=0,
        account_id=account.id,
        source_entry_id=None,
        is_bot=False,
        name=nick,
        avatar=0,
        stage=0,
        points=0,
        stage_times=[],
        status="running",
        eliminated_stage=-1,
        updated_at=clock.utcnow(),
    )
    entries.append(me)

    # 优先匹配其他真实玩家的历史异步进度曲线
    need_opponents = player_count - 1
    real_rows = list(
        db.scalars(
            select(TigerEntry)
            .where(
                TigerEntry.account_id.is_not(None),
                TigerEntry.account_id != account.id,
                TigerEntry.source_entry_id.is_(None),
                TigerEntry.stage > 0,
            )
            .order_by(TigerEntry.updated_at.desc())
            .limit(need_opponents * 2)
        )
    )
    seen_accounts = set()
    real_pool: list[TigerEntry] = []
    for row in real_rows:
        if row.account_id and row.account_id not in seen_accounts and row.stage_times:
            seen_accounts.add(row.account_id)
            real_pool.append(row)
            if len(real_pool) >= need_opponents:
                break

    for slot in range(1, player_count):
        if slot - 1 < len(real_pool):
            src = real_pool[slot - 1]
            entry = TigerEntry(
                cohort_id=cohort_id,
                slot=slot,
                account_id=None,
                source_entry_id=src.id,
                is_bot=False,
                name=src.name or ("原始人" + str(slot)),
                avatar=src.avatar,
                stage=0,
                points=0,
                stage_times=list(src.stage_times),
                status="running",
                eliminated_stage=-1,
                updated_at=clock.utcnow(),
            )
        else:
            bname = DEFAULT_BOT_NAMES[(slot - 1) % len(DEFAULT_BOT_NAMES)]
            if slot > len(DEFAULT_BOT_NAMES):
                bname = f"{bname}{slot}"
            entry = TigerEntry(
                cohort_id=cohort_id,
                slot=slot,
                account_id=None,
                source_entry_id=None,
                is_bot=True,
                name=bname,
                avatar=slot % 8,
                stage=0,
                points=0,
                stage_times=_gen_bot_stage_times(cohort_id, slot, num_stages, interval, pace_min, pace_max),
                status="running",
                eliminated_stage=-1,
                updated_at=clock.utcnow(),
            )
        entries.append(entry)

    db.add_all(entries)
    db.commit()
    return evaluate_cohort(cohort, entries, now)


def sync_progress(db: Session, account: Account, cohort_id: str, stage: int, points: int, stage_times: list[float], now: float) -> dict | None:
    cohort = db.get(TigerCohort, cohort_id)
    if cohort is None or cohort.account_id != account.id:
        return None
    entries = list(
        db.scalars(
            select(TigerEntry).where(TigerEntry.cohort_id == cohort_id).order_by(TigerEntry.slot.asc())
        )
    )
    if not entries:
        return None
    me = entries[0]
    # 只接受单调递增的阶段记录
    clean_times = [round(max(0.0, float(t)), 2) for t in stage_times[:len(cohort.quotas or DEFAULT_QUOTAS)]]
    if len(clean_times) >= len(me.stage_times or []):
        me.stage_times = clean_times
    me.stage = max(int(me.stage), min(int(stage), len(cohort.quotas or DEFAULT_QUOTAS)))
    me.points = max(0, int(points))
    me.updated_at = clock.utcnow()

    result = evaluate_cohort(cohort, entries, now)
    me.status = result["status"]
    cohort.status = result["status"]
    db.commit()
    return result


def get_state(db: Session, account: Account, cohort_id: str, now: float) -> dict | None:
    cohort = db.get(TigerCohort, cohort_id)
    if cohort is None or cohort.account_id != account.id:
        return None
    entries = list(
        db.scalars(
            select(TigerEntry).where(TigerEntry.cohort_id == cohort_id).order_by(TigerEntry.slot.asc())
        )
    )
    if not entries:
        return None
    return evaluate_cohort(cohort, entries, now)
