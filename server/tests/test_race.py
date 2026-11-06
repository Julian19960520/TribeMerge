"""篝火竞速 + 影子对手：分组、影子补位（历史曲线 / 生成曲线）、到 300 分结束、分数上限、结算领奖幂等。"""

import json
import random
import time

import pytest

from conftest import Player, ev

BASE = {"duration_sec": 7200, "fill_sec": 60, "unlock_level": 5}


def set_race(monkeypatch, **kw):
    from app import config
    monkeypatch.setenv("TRIBE_RACE_OVERRIDES", json.dumps(dict(BASE, **kw)))
    config.get_settings.cache_clear()


def goto(t):
    """把服务器时钟拨到 Unix 时间 t。"""
    from app import clock
    clock.offset = t - time.time()


def db():
    from app import db as dbm
    return dbm._SessionLocal()


def set_level(p, level):
    from app.models import Account
    s = db()
    acc = s.get(Account, p.id)
    st = dict(acc.state or {})
    if not st:
        from app.services import economy
        st = economy().new_state()
    st["level"] = level
    acc.state = st
    s.commit()
    s.close()


def entries(gid):
    from sqlalchemy import select
    from app.models import RaceEntry
    s = db()
    rows = s.execute(select(RaceEntry).where(RaceEntry.group_id == gid).order_by(RaceEntry.slot)).scalars().all()
    s.close()
    return rows


def order(item="fruit_6"):
    return ev("order", order={"who": 2, "items": [item], "rw": {"shell": 1}, "story": False})


def deliver(p, n=1, item="fruit_6"):
    r = p.post("/v1/events", json={"events": [order(item) for _ in range(n)]})
    assert r.status_code == 200, r.text
    assert all(x["ok"] for x in r.json()["events"]), r.text
    return r


def P(client, device="d", level=5):
    p = Player(client, device=device)
    set_level(p, level)
    return p


def race(p):
    r = p.get("/v1/race")
    assert r.status_code == 200, r.text
    return r.json()


@pytest.fixture()
def t0(client, monkeypatch):
    set_race(monkeypatch)
    s = (int(time.time()) // 1000 + 10) * 1000
    goto(s + 10)
    return s


# ---------------------------------------------------------------- 匹配

def test_unlock_and_rematch(client, monkeypatch, t0):
    set_race(monkeypatch, podium=1, cap={"burst": 10000})
    p = P(client, level=4)
    r = p.post("/v1/race/join")
    assert r.status_code == 409 and r.json()["error"] == "race_locked"
    set_level(p, 5)
    r = p.post("/v1/race/join")
    assert r.status_code == 200 and r.json()["current"]["group"]["state"] == "matching"
    gid = r.json()["current"]["group"]["id"]
    # 重复匹配还是同一局
    assert p.post("/v1/race/join").json()["current"]["group"]["id"] == gid
    # 匹配中交的单不算
    deliver(p, 1)
    goto(t0 + 10 + 60)
    g = race(p)["current"]["group"]
    assert g["state"] == "running" and g["start"] == t0 + 70
    assert [m for m in g["members"] if m["me"]][0]["score"] == 0
    deliver(p, 10)
    # 比完没领奖：current 还是这局（结算面板）
    info = race(p)
    assert info["current"]["group"]["state"] == "ended" and info["results"][0]["group"]["id"] == gid
    # 比完了随时可以开下一局
    g2 = p.post("/v1/race/join").json()["current"]["group"]
    assert g2["id"] != gid and g2["state"] == "matching"
    assert race(p)["results"][0]["group"]["id"] == gid  # 上一局的奖还能领
    assert p.post("/v1/race/claim", json={"group": gid}).status_code == 200
    assert race(p)["current"]["group"]["id"] == g2["id"]


# ---------------------------------------------------------------- 分组 / 影子

def test_fake_matching_all_shadows(client, t0):
    a, b = P(client, device="a"), P(client, device="b")
    ga = a.post("/v1/race/join").json()["current"]["group"]
    gb = b.post("/v1/race/join").json()["current"]["group"]
    assert ga["id"] != gb["id"]  # 每局只有自己一个真人
    goto(t0 + 10 + 61)
    g = race(a)["current"]["group"]
    assert g["state"] == "running" and len(g["members"]) == 5 and g["start"] == t0 + 70
    assert all("shadow" not in m for m in g["members"])
    rows = entries(ga["id"])
    assert [r.shadow for r in rows] == [False, True, True, True, True]
    assert all(r.source == "gen" and r.points for r in rows if r.shadow)


def test_shadow_replays_history_curve(client, monkeypatch, t0):
    # 第一局：a 打出一条曲线（t0+70 开赛）
    a = P(client, device="a")
    a.post("/v1/race/join")
    goto(t0 + 670)
    deliver(a, 2)           # 64 分
    goto(t0 + 1270)
    deliver(a, 1, "fruit_5")  # +16
    goto(t0 + 7400)          # 时间到，结束
    res = race(a)["results"]
    assert len(res) == 1 and res[0]["me"]["score"] == 80
    # 下一局（时长缩短一半）：b 一个人匹配，影子里有一个回放 a 的曲线
    set_race(monkeypatch, duration_sec=3600)
    t1 = t0 + 10000
    goto(t1)
    b = P(client, device="b")
    gid = b.post("/v1/race/join").json()["current"]["group"]["id"]
    goto(t1 + 60)
    race(b)
    rows = entries(gid)
    hist = [r for r in rows if r.shadow and r.source.startswith("entry:")]
    assert len(hist) == 1
    assert hist[0].points == [[300, 32.0], [300, 64.0], [600, 80.0]]  # 时间按时长缩放
    name = hist[0].name
    sc = lambda: [m for m in race(b)["current"]["group"]["members"] if m["name"] == name][0]["score"]
    assert sc() == 0
    goto(t1 + 360)
    assert sc() == 64
    goto(t1 + 760)
    assert sc() == 80


def test_generated_curve_is_reasonable():
    from app import race
    sh = {"nominal_sec": 7200, "pace_base": 110, "pace_per_level": 10, "pace_min": 0.55, "pace_max": 1.3,
          "order_base": 6, "order_per_level": 0.8}
    finals = []
    for seed in range(200):
        pts = race.gen_curve(random.Random(seed), 5, 7200, 300, sh)
        assert pts and all(0 <= p[0] < 7200 for p in pts)
        assert all(pts[i][0] <= pts[i + 1][0] and pts[i][1] <= pts[i + 1][1] for i in range(len(pts) - 1))
        finals.append(pts[-1][1])
    reach = sum(1 for f in finals if f >= 300) / len(finals)
    assert 0.15 < reach < 0.9  # 有的能到线，有的到不了
    # 缩短场次：同样的曲线按时长缩放
    short = race.gen_curve(random.Random(1), 5, 600, 300, sh)
    assert all(p[0] < 600 for p in short)


# ---------------------------------------------------------------- 计分 / 结束

def test_first_to_target_wins_and_race_ends(client, monkeypatch, t0):
    set_race(monkeypatch, podium=1, cap={"burst": 10000})
    a = P(client, device="a")
    gid = a.post("/v1/race/join").json()["current"]["group"]["id"]
    goto(t0 + 200)
    deliver(a, 10)  # 320 → 封顶 300，到线
    g = race(a)["current"]["group"]
    me = [m for m in g["members"] if m["me"]][0]
    assert me["score"] == 300 and me["finished_at"] == t0 + 200
    assert g["state"] == "ended" and g["ended_at"] == t0 + 200
    goto(t0 + 300)
    deliver(a, 5)  # 结束后不再算分
    assert race(a)["results"][0]["me"]["score"] == 300
    res = race(a)["results"][0]
    assert res["me"]["place"] == 1 and res["me"]["reward"][0] == ["amber_3", 30]
    assert sorted(r.place for r in entries(gid)) == [1, 2, 3, 4, 5]


def test_podium_finish_ends_race(client, monkeypatch, t0):
    set_race(monkeypatch, cap={"burst": 10000}, shadow={"nominal_sec": 7200, "pace_base": 100000, "pace_per_level": 0,
                                                       "pace_min": 1, "pace_max": 1, "order_base": 50, "order_per_level": 0})
    p = P(client)
    p.post("/v1/race/join")
    goto(t0 + 7000)  # 影子都飞快到线：前 3 名定了就结束
    g = race(p)["current"]["group"]
    assert g["state"] == "ended" and g["ended_at"] < t0 + 7000
    assert [m for m in g["members"] if m["me"]][0]["place"] in (4, 5)


def test_score_cap(client, t0):
    from sqlalchemy import select
    from app.models import AuditLog
    p = P(client)
    p.post("/v1/race/join")
    goto(t0 + 70)  # 开赛
    deliver(p, 10)  # 320 分，上限 200（burst）
    me = race(p)["current"]["me"]
    assert me["score"] == 200 and me["capped"] == 120
    s = db()
    assert s.execute(select(AuditLog).where(AuditLog.kind == "race_capped")).scalars().first() is not None
    s.close()
    # 20 分钟回复 10 点体力 → 上限 +20
    goto(t0 + 70 + 1200)
    deliver(p, 1)
    assert race(p)["current"]["me"]["score"] == 220
    # 买一次体力（100 点）→ 上限 +200
    assert p.post("/v1/energy/buy").status_code == 200
    deliver(p, 2)
    assert race(p)["current"]["me"]["score"] == 284


def test_orders_outside_race_dont_count(client, t0):
    p = P(client)
    deliver(p, 1)  # 没报名
    p.post("/v1/race/join")
    goto(t0 + 70)
    assert race(p)["current"]["me"]["score"] == 0
    deliver(p, 1, "seed_1")  # 副产物按掉率折算
    assert race(p)["current"]["me"]["score"] == pytest.approx(12.9, abs=0.05)


# ---------------------------------------------------------------- 领奖

def test_claim_idempotent_and_title(client, monkeypatch, t0):
    set_race(monkeypatch, podium=1, cap={"burst": 10000})
    p = P(client)
    gid = p.post("/v1/race/join").json()["current"]["group"]["id"]
    r = p.post("/v1/race/claim", json={"group": gid})
    assert r.status_code == 409 and r.json()["error"] == "race_running"
    goto(t0 + 100)  # 凑组时间过了才封组开赛
    deliver(p, 10)
    amber0 = p.get("/v1/save").json()["state"]["amber"]
    r1 = p.post("/v1/race/claim", json={"group": gid}, key="k-claim-1")
    assert r1.status_code == 200, r1.text
    assert r1.json()["place"] == 1 and r1.json()["state"]["amber"] == amber0 + 30
    assert r1.json()["give"]["energy"] == 100 and r1.json()["give"]["items"] == ["pack_1"]
    assert r1.json()["title"]["name"] == "篝火王"
    # 同一个幂等键重试：同样的结果，不重复发
    r2 = p.post("/v1/race/claim", json={"group": gid}, key="k-claim-1")
    assert r2.json() == r1.json()
    # 换一个键：已经领过
    r3 = p.post("/v1/race/claim", json={"group": gid})
    assert r3.status_code == 409 and r3.json()["error"] == "already_claimed"
    assert p.get("/v1/save").json()["state"]["amber"] == amber0 + 30
    info = race(p)
    assert info["results"] == [] and info["title"]["id"] == "race_champ"
    # 称号限时
    goto(t0 + 25 * 3600)
    assert race(p)["title"] is None


def test_claim_other_group_and_no_reward_place(client, monkeypatch, t0):
    p, q = P(client, device="p"), P(client, device="q")
    gid = p.post("/v1/race/join").json()["current"]["group"]["id"]
    assert q.post("/v1/race/claim", json={"group": gid}).status_code == 404
    goto(t0 + 7400)  # 一分没得，时间到：第 4/5 名之类，没有奖励
    res = race(p)["results"][0]
    r = p.post("/v1/race/claim", json={"group": gid})
    assert r.status_code == 200 and r.json()["rewards"] == (res["me"]["reward"] or [])
