"""体力生产器（火种罐 emberpot_1）：每次点击上报 egen 事件，服务器按账号限次，并把产物记进火种额度。"""

from conftest import ev


def _cfg(player):
    from app.services import gamedata
    return gamedata().egen_stats("emberpot_1")


def test_egen_charges_cooldown_and_budget(client, player):
    from app import clock
    es = _cfg(player)
    assert es and es["charges"] > 0 and "fire_1" in es["drops"]
    n = es["charges"]
    # 掉落表外的产物、不是体力生产器的都不认
    bad = player.put(player.snapshot(), events=[ev("egen", gen="emberpot_1", item="fire_6"), ev("egen", gen="basket_4", item="fire_1")])
    assert bad.status_code == 200, bad.text
    assert [x["ok"] for x in bad.json()["events"]] == [False, False]
    # 一批 n 次都认，第 n+1 次在休息
    evs = [ev("egen", gen="emberpot_1", item="fire_2") for _ in range(n + 1)]
    res = player.put(player.snapshot(), events=evs).json()["events"]
    assert all(x["ok"] for x in res[:n]) and not res[n]["ok"] and res[n]["error"] == "egen_resting"
    # 产出的 n 个 fire_2 = 2n 个 1 级额度：收 n/2 个 fire_3（各 4 个 1 级）正好用完，再收就没额度
    k = (2 * n) // 4
    col = player.put(player.snapshot(), events=[ev("collect", item="fire_3") for _ in range(k + 1)]).json()["events"]
    assert all(x["ok"] for x in col[:k]) and col[k]["error"] == "no_budget"
    # 冷却结束后整批回满
    clock.offset = es["refill"] * 60 + 5
    try:
        res = player.put(player.snapshot(), events=[ev("egen", gen="emberpot_1", item="fire_1") for _ in range(n)]).json()["events"]
        assert all(x["ok"] for x in res)
    finally:
        clock.offset = 0
