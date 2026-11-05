from conftest import Player


def test_hot_deals_rolled_once_per_day(client, player):
    from app import clock
    # 没快照：用底子
    assert player.get("/v1/shop").json()["picks"] == []
    orders = [{"who": 0, "items": ["fruit_7"], "rw": {"shell": 10}, "story": False},
              {"who": 1, "items": ["tool_6"], "rw": {"shell": 10}, "story": False}]
    player.put(player.snapshot(orders=orders))
    days = set()
    for _ in range(4):
        a = player.get("/v1/shop").json()
        b = player.get("/v1/shop").json()
        assert a["picks"] == b["picks"] and a["offers"] == b["offers"]  # 同一天不重抽
        for p in a["picks"]:
            assert p["id"] in ("fruit_5", "fruit_6", "tool_4", "tool_5")
        days.add(a["day"])
        clock.offset += 86400
    assert len(days) == 4


def test_hot_buy_respects_stock(client):
    p = Player(client)
    p.put(p.snapshot(orders=[]))
    offers = p.get("/v1/shop").json()["offers"]
    hot0 = next(o for o in offers if o["key"] == "hot_0")
    bought = 0
    for _ in range(hot0["stock"] + 1):
        r = p.post("/v1/shop/buy", json={"key": "hot_0", "item": hot0["id"]})
        if r.status_code == 200:
            bought += 1
        else:
            assert r.json()["error"] in ("sold_out", "not_enough_amber")
    assert bought <= hot0["stock"]
    assert p.post("/v1/shop/buy", json={"key": "hot_0", "item": "gem_9"}).json()["error"] == "no_offer"
