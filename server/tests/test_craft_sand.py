"""制作单附送沙漏、合成掉沙漏：服务器和客户端（Data.craft_sand / Data.merge_sand_item）同一套规则。"""

import hashlib
import uuid

from conftest import ev


def _craft(dish, mats, rewards, shell=20):
    return {"who": 1, "kind": "craft", "dish": dish, "items": mats, "rw": {"shell": shell, "rewards": rewards}, "story": False}


def test_craft_sand_tier_follows_cook_time(client):
    from app import services
    gd = services.gamedata()
    assert gd.craft_sand("salad") == "sand_2"          # 1 分钟
    assert gd.craft_sand("trailpack") == "sand_3"      # 10 分钟
    assert gd.craft_sand("platter") == "sand_4"        # 45 分钟
    assert gd.craft_sand("chiefgift") == "sand_5"      # 4 小时
    assert gd.craft_sand("nope") == ""


def test_craft_order_sand_reward(client, player):
    ok = _craft("salad", ["fruit_2", "fruit_3", "seed_1"], ["sand_2"])
    greedy = _craft("salad", ["fruit_2", "fruit_3", "seed_1"], ["sand_5"])
    extra = _craft("salad", ["fruit_2", "fruit_3", "seed_1"], ["sand_2", "sand_2"])
    plain = {"who": 2, "items": ["fruit_3"], "rw": {"shell": 12, "rewards": ["sand_2"]}, "story": False}
    r = player.put(player.snapshot(level=3), events=[ev("order", order=ok), ev("order", order=greedy),
                                                      ev("order", order=extra), ev("order", order=plain)])
    res = r.json()["events"]
    assert res[0]["ok"] and res[0]["give"]["items"] == ["sand_2"]
    assert [x["ok"] for x in res[1:]] == [False, False, False]
    # 附送的沙漏记进额度，之后能收取成沙漏份数
    got = player.post("/v1/events", {"events": [ev("collect", item="sand_2")]}).json()["events"][0]
    assert got["ok"] and got["give"]["rush"] == 1


def _roll(eid: str) -> float:
    return int(hashlib.sha256(eid.encode()).hexdigest()[:8], 16) / 4294967296


def _id_in(lo: float, hi: float) -> str:
    while True:
        eid = uuid.uuid4().hex
        if lo <= _roll(eid) < hi:
            return eid


def test_merge_sand_drop(client):
    from conftest import Player
    from app import services
    player = Player(client, player_id="TRBsandmerge", device="sand")
    rules = services.gamedata().rules
    coin = float(rules["merge_resource_drops"]["main"][0]["chance"])
    sand = float(rules["merge_resource_drops"]["main"][1]["chance"])
    assert sand > 0
    r = player.put(player.snapshot(level=3))
    assert r.json()["state"]["level"] == 3, r.json()
    hit = {"id": _id_in(coin, coin + sand), "type": "merge", "item": "fruit_3", "cell": 5}
    miss = {"id": _id_in(sum(float(row["chance"]) for row in rules["merge_resource_drops"]["main"]), 1.0), "type": "merge", "item": "fruit_3", "cell": 5}
    big = {"id": _id_in(coin, coin + sand), "type": "merge", "item": "fruit_8", "cell": 5}
    gen = {"id": _id_in(coin, coin + sand), "type": "merge", "item": "basket_3", "cell": 5}
    res = player.post("/v1/events", {"events": [hit, miss, big, gen]}).json()["events"]
    assert res[0]["give"] == {"items": ["sand_1"]}
    assert res[1]["give"] == {}
    assert res[2]["give"] == {"items": ["sand_1"]}  # Current table drops level-one resources only.
    assert res[3]["give"] == {}  # 生产器合成不掉沙漏


def test_merge_sand_needs_craft_level(client, player):
    from app import services
    rules = services.gamedata().rules
    coin = float(rules["merge_resource_drops"]["main"][0]["chance"])
    sand = float(rules["merge_resource_drops"]["main"][1]["chance"])
    hit = {"id": _id_in(coin, coin + sand), "type": "merge", "item": "fruit_3", "cell": 5}
    res = player.post("/v1/events", {"events": [hit]}).json()["events"]
    assert res[0]["ok"] and not any(i.startswith("sand_") for i in res[0]["give"].get("items", []))
