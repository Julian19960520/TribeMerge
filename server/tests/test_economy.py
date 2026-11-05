import uuid

from conftest import Player, ev

STORY0 = {"who": 0, "items": ["fruit_5"], "rw": {"xp": 1, "shell": 64}, "story": True, "si": 0}
STORY1 = {"who": 1, "items": ["fruit_6", "fruit_2"], "rw": {"xp": 1, "shell": 136}, "story": True, "si": 1}


def give_amber(p, n):
    r = p.post("/v1/payments/orders", json={"pack": 0})
    oid = r.json()["order_id"]
    for _ in range((n + 79) // 80):
        r = p.post("/v1/payments/orders", json={"pack": 0})
        p.post("/v1/payments/mock/%s/pay" % r.json()["order_id"])
    p.post("/v1/payments/mock/%s/pay" % oid)


def test_buy_energy_price_and_idempotency(client, player):
    k = uuid.uuid4().hex
    r1 = player.post("/v1/energy/buy", key=k)
    r2 = player.post("/v1/energy/buy", key=k)
    assert r1.status_code == 200 and r1.json() == r2.json()  # 同一个幂等键只扣一次
    assert r1.json()["state"]["amber"] == 60 and r1.json()["give"]["energy"] == 100
    r3 = player.post("/v1/energy/buy")
    assert r3.json()["state"]["amber"] == 30 and r3.json()["state"]["energy_buys"] == 2
    r4 = player.post("/v1/energy/buy")
    assert r4.status_code == 409 and r4.json()["error"] == "not_enough_amber"


def test_idempotency_key_required(client, player):
    r = client.post("/v1/energy/buy", headers={"Authorization": "Bearer " + player.token})
    assert r.status_code == 400 and r.json()["error"] == "idempotency_key_required"


def test_daily_reset_uses_server_date(client, player):
    from app import clock
    player.post("/v1/energy/buy")
    clock.offset = 86400
    r = player.post("/v1/energy/buy")
    assert r.json()["state"]["energy_buys"] == 1


def test_story_order_once_and_level_up(client, player):
    r = player.put(player.snapshot(), events=[ev("order", order=STORY0), ev("order", order=STORY0)])
    res = r.json()["events"]
    assert res[0]["ok"] and not res[1]["ok"] and res[1]["error"] == "already_done"
    r = player.put(player.snapshot(energy=99), events=[ev("order", order=STORY1)])
    st = r.json()["state"]
    assert st["shells"] == 200 and st["level"] == 1 and st["xp"] == 2
    # 等级奖励：没到不能领
    assert player.post("/v1/level/claim", json={"level": 2}).status_code == 409


def test_fake_story_rejected(client, player):
    fake = dict(STORY0, rw={"xp": 5, "shell": 9999})
    r = player.put(player.snapshot(), events=[ev("order", order=fake)])
    assert not r.json()["events"][0]["ok"] and r.json()["state"]["shells"] == 0


def test_random_order_bounds(client, player):
    ok = {"who": 2, "items": ["fruit_3"], "rw": {"shell": 12}, "story": False}
    bad = {"who": 2, "items": ["fruit_3"], "rw": {"shell": 5000}, "story": False}
    r = player.put(player.snapshot(), events=[ev("order", order=ok), ev("order", order=bad)])
    res = r.json()["events"]
    assert res[0]["ok"] and not res[1]["ok"] and r.json()["state"]["shells"] == 12


def test_listed_order_used_once(client, player):
    o = {"who": 2, "items": ["fruit_3"], "rw": {"shell": 12, "token": 2}, "story": False}
    player.put(player.snapshot(orders=[o]))
    r = player.put(player.snapshot(energy=99), events=[ev("order", order=o)])
    assert r.json()["events"][0]["ok"] and r.json()["state"]["tokens"] == 2 and r.json()["state"]["pass_pts"] == 1


def test_tutorial_and_seed_orders(client, player):
    t1 = {"who": 0, "items": ["fruit_2"], "rw": {"shell": 25}, "story": True, "tutorial": 1}
    seed = {"who": 1, "items": ["seed_1"], "rw": {"xp": 1, "shell": 50}, "story": True}
    r = player.put(player.snapshot(), events=[ev("order", order=t1), ev("order", order=t1), ev("order", order=seed)])
    res = r.json()["events"]
    assert [x["ok"] for x in res] == [True, False, True]
    assert r.json()["state"]["shells"] == 75 and r.json()["state"]["xp"] == 1


def test_build_spends_shells_and_ranks(client, player):
    assert player.post("/v1/build", json={"area": "fire"}).json()["error"] == "not_enough_shell"
    player.put(player.snapshot(), events=[ev("order", order=STORY0), ev("order", order=STORY1),
                                          ev("order", order={"who": 0, "items": ["fruit_2"], "rw": {"shell": 25}, "story": True, "tutorial": 1}),
                                          ev("order", order={"who": 1, "items": ["fruit_8"], "rw": {"shell": 315}, "story": True, "tutorial": 2})])
    r = player.post("/v1/build", json={"area": "fire"})
    assert r.status_code == 200, r.text
    j = r.json()
    assert j["state"]["builds"]["fire"] == 2 and j["state"]["shells"] == 540 - 340 and j["give"]["idx"] == 1
    # 部件奖励 [["basket_3",1],["fire_2",15],["amber_2",1]]：货币类按点数发（同客户端），其他是实物
    assert j["give"]["items"] == ["basket_3"] and j["give"]["energy"] == 15 and j["state"]["amber"] == 81
    top = client.get("/v1/rank/top", headers={"Authorization": "Bearer " + player.token}).json()
    assert top["me"]["progress"] == 2 and top["top"][0]["id"] == player.id


def test_shop_deal_chest_then_open(client, player):
    shop = player.get("/v1/shop").json()
    keys = {o["key"]: o for o in shop["offers"]}
    assert keys["deal_0"]["id"] == "chest_1" and "deal_1" not in keys  # 卡包 8 级才卖
    r = player.post("/v1/shop/buy", json={"key": "deal_0", "item": "chest_1"})
    assert r.status_code == 200 and r.json()["state"]["amber"] == 70 and r.json()["give"]["items"] == ["chest_1"]
    assert player.post("/v1/shop/buy", json={"key": "deal_0"}).json()["error"] == "sold_out"
    r = player.post("/v1/chest/open")
    assert r.status_code == 200 and len(r.json()["give"]["items"]) == 3
    assert player.post("/v1/chest/open").json()["error"] == "no_chest"


def test_collect_currency_needs_budget(client, player):
    assert player.post("/v1/shop/buy", json={"key": "deal_0"}).status_code == 200
    items = player.post("/v1/chest/open").json()["give"]["items"]
    cur = [i for i in items if i.split("_")[0] in ("amber", "shell", "fire", "sand")]
    evs = [ev("collect", item=i) for i in cur] + [ev("collect", item="amber_6")]
    r = player.put(player.snapshot(), events=evs)
    res = r.json()["events"]
    assert all(x["ok"] for x in res[:-1]) and not res[-1]["ok"] and res[-1]["error"] == "no_budget"


def test_bubble_reward_once(client, player):
    r = player.put(player.snapshot(), events=[ev("bubble", cell=4), ev("bubble", cell=4), ev("bubble", cell=1)])
    res = r.json()["events"]
    assert res[0]["ok"] and not res[1]["ok"] and not res[2]["ok"]
    assert r.json()["state"]["shells"] == 30


def test_pass_buy_and_claim(client, player):
    give_amber(player, 100)
    player.put(player.snapshot(), events=[ev("order", order={"who": 2, "items": ["fruit_3"], "rw": {"shell": 12}, "story": False}) for _ in range(8)])
    assert player.post("/v1/pass/claim", json={"track": "prem", "level": 1}).json()["error"] == "need_vip"
    r = player.post("/v1/pass/buy", json={"tier": "vip"})
    assert r.status_code == 200 and r.json()["give"]["energy"] == 150
    assert player.post("/v1/pass/buy", json={"tier": "vip"}).json()["error"] == "already_owned"
    assert player.post("/v1/pass/claim", json={"track": "free", "level": 1}).status_code == 200
    assert player.post("/v1/pass/claim", json={"track": "prem", "level": 1}).status_code == 200
    assert player.post("/v1/pass/claim", json={"track": "free", "level": 1}).json()["error"] == "already_claimed"
    assert player.post("/v1/pass/claim", json={"track": "free", "level": 2}).json()["error"] == "not_reached"


def test_book_claim_needs_seen_item(client, player):
    assert player.post("/v1/book/claim", json={"item": "fruit_6"}).json()["error"] == "not_discovered"
    player.put(player.snapshot(stash=["fruit_6"]))
    r = player.post("/v1/book/claim", json={"item": "fruit_6"})
    assert r.status_code == 200 and r.json()["give"]["energy"] == 6
    assert player.post("/v1/book/claim", json={"item": "fruit_5"}).status_code == 200  # 低等级也算见过
    assert player.post("/v1/book/claim", json={"item": "fruit_6"}).json()["error"] == "already_claimed"


def test_storage_expand(client, player):
    r = player.post("/v1/storage/expand")
    assert r.status_code == 200 and r.json()["state"]["inv_cap"] == 6 and r.json()["state"]["amber"] == 30


def test_payment_credits_once(client, player):
    r = player.post("/v1/payments/orders", json={"pack": 1})
    oid = r.json()["order_id"]
    assert r.json()["status"] == "created" and r.json()["amber"] == 500
    r = player.post("/v1/payments/mock/%s/pay" % oid)
    assert r.json()["status"] == "paid" and r.json()["state"]["amber"] == 580
    r = player.post("/v1/payments/mock/%s/pay" % oid)
    assert r.json()["state"]["amber"] == 580
    other = Player(client, device="x")
    assert other.post("/v1/payments/mock/%s/pay" % oid).status_code == 404


def test_pack_open_and_cards(client, player):
    player.put(player.snapshot(), events=[ev("order", order={"who": 2, "items": ["fruit_3"], "rw": {"shell": 12, "token": 3}, "story": False}) for _ in range(4)])
    r = player.post("/v1/pack/open")
    assert r.status_code == 200 and len(r.json()["give"]["cards"]) == 2
    assert sum(r.json()["state"]["cards"].values()) == 2
    assert player.post("/v1/pack/open").json()["error"] == "no_pack"
