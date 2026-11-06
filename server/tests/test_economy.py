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
    from test_merge_event import mutate
    mutate(player, lambda st: st.update(shells=600))
    keys = {o["key"]: o for o in player.get("/v1/shop").json()["offers"]}
    assert keys["deal_energybox"]["id"] == "energybox_1" and keys["deal_energybox"]["cur"] == "shell"
    r = player.post("/v1/daily/claim", {"key": "deal_energybox"})
    assert r.status_code == 200 and r.json()["state"]["shells"] == 300 and r.json()["give"]["items"] == ["energybox_1"]
    assert player.post("/v1/daily/claim", {"key": "deal_energybox"}).json()["error"] == "sold_out"
    assert player.post("/v1/chest/open").json()["error"] == "no_chest"
    r = player.post("/v1/energy-chest/open")
    assert r.status_code == 200 and r.json()["give"]["items"] == ["fire_4"] * 3
    assert player.post("/v1/energy-chest/open").json()["error"] == "no_chest"


def test_collect_currency_needs_budget(client, player):
    from test_merge_event import mutate
    mutate(player, lambda st: st["credits"].update(chest=1))
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


def buy_pass(p, tier):
    """通行证人民币下单 → mock 支付回调开通。"""
    r = p.post("/v1/pass/order", json={"tier": tier})
    assert r.status_code == 200, r.json()
    return r, p.post("/v1/payments/mock/%s/pay" % r.json()["order_id"])


def test_pass_buy_and_claim(client, player):
    player.put(player.snapshot(), events=[ev("order", order={"who": 2, "items": ["fruit_3"], "rw": {"shell": 12}, "story": False}) for _ in range(8)])
    assert player.post("/v1/pass/claim", json={"track": "prem", "level": 1}).json()["error"] == "need_vip"
    # 琥珀买不了，只能人民币下单
    assert player.post("/v1/pass/buy", json={"tier": "vip"}).json()["error"] == "pay_with_cash"
    amber0 = player.post("/v1/pass/claim", json={"track": "free", "level": 1}).json()["state"]["amber"]
    order, paid = buy_pass(player, "vip")
    assert order.json()["price"] == "¥30" and order.json()["status"] == "created" and order.json()["kind"] == "pass"
    assert paid.status_code == 200 and paid.json()["status"] == "paid" and paid.json()["give"]["energy"] == 150
    assert paid.json()["state"]["pass_tier"] == 1 and paid.json()["state"]["amber"] == amber0
    # 重复回调不重复开通；已拥有不能再下单
    again = player.post("/v1/payments/mock/%s/pay" % order.json()["order_id"])
    assert again.json()["state"]["pass_tier"] == 1
    assert player.post("/v1/pass/order", json={"tier": "vip"}).json()["error"] == "already_owned"
    assert player.post("/v1/pass/claim", json={"track": "prem", "level": 1}).status_code == 200
    assert player.post("/v1/pass/claim", json={"track": "free", "level": 1}).json()["error"] == "already_claimed"
    assert player.post("/v1/pass/claim", json={"track": "free", "level": 2}).json()["error"] == "not_reached"
    # 第三列：贵宾领不了，升级超级贵宾（¥68）后才能领
    assert player.post("/v1/pass/claim", json={"track": "super", "level": 1}).json()["error"] == "need_super"
    order, paid = buy_pass(player, "super")
    assert order.json()["price"] == "¥38"  # 已经是贵宾：补差价
    st = paid.json()["state"]
    assert st["pass_tier"] == 2 and st["pass_super_bonus"] and "energy" not in paid.json()["give"]
    r = player.post("/v1/pass/claim", json={"track": "super", "level": 1})
    assert r.status_code == 200 and r.json()["state"]["pass_super"] == [1]
    assert player.post("/v1/pass/claim", json={"track": "super", "level": 1}).json()["error"] == "already_claimed"
    assert player.post("/v1/pass/claim", json={"track": "prem", "level": 1}).json()["error"] == "already_claimed"
    assert player.post("/v1/pass/order", json={"tier": "super"}).json()["error"] == "already_owned"


def test_pass_super_direct(client, player):
    """没买过贵宾直接买超级贵宾：一次开通，也送火种。"""
    order, paid = buy_pass(player, "super")
    assert order.json()["price"] == "¥68"
    assert paid.json()["state"]["pass_tier"] == 2 and paid.json()["give"]["energy"] == 150
    assert paid.json()["state"]["pass_pts"] == 10


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
    player = Player(client, player_id="TRBcardtest", device="cards")
    assert player.put(player.snapshot(level=8)).status_code == 200
    player.put(player.snapshot(), events=[ev("order", order={"who": 2, "items": ["fruit_3"], "rw": {"shell": 12, "token": 3}, "story": False}) for _ in range(4)])
    r = player.post("/v1/pack/open")
    assert r.status_code == 200 and len(r.json()["give"]["cards"]) == 2
    assert sum(r.json()["state"]["cards"].values()) == 2
    assert player.post("/v1/pack/open").json()["error"] == "no_pack"


def test_book_claim_counts_delivered_items(client, player):
    # 合成出来马上交掉、从没出现在快照里的物品，也算图鉴里见过
    t1 = {"who": 0, "items": ["fruit_2"], "rw": {"shell": 25}, "story": True, "tutorial": 1}
    t2 = {"who": 1, "items": ["fruit_8"], "rw": {"shell": 315}, "story": True, "tutorial": 2}
    player.put(player.snapshot(), events=[ev("order", order=t1), ev("order", order=t2)])
    r = player.post("/v1/book/claim", json={"item": "fruit_8"})
    assert r.status_code == 200 and r.json()["give"]["energy"] == 8


def test_book_claim_backfills_old_accounts(client, player):
    # 修复前交掉的新手单：服务器只记了 done，没记见过；领奖时按 done 补回来
    from app.economy import Economy
    t2 = {"who": 1, "items": ["fruit_8"], "rw": {"shell": 315}, "story": True, "tutorial": 2}
    orig = Economy._seen_item
    try:
        def no_seen(self, st, iid, credit, budget, seen=True):
            if iid == "fruit_8":
                return
            return orig(self, st, iid, credit, budget, seen)
        Economy._seen_item = no_seen
        player.put(player.snapshot(), events=[ev("order", order=t2)])
    finally:
        Economy._seen_item = orig
    r = player.post("/v1/book/claim", json={"item": "fruit_8"})
    assert r.status_code == 200


def test_found_event_lets_book_claim_right_away(client, player):
    # 刚合出来、还没等到下一次存档同步就去领图鉴：found 事件先到，领奖接口能过
    player.put(player.snapshot(stash=["seed_2"]))
    assert player.post("/v1/book/claim", json={"item": "seed_3"}).json()["error"] == "not_discovered"
    r = player.post("/v1/events", json={"events": [ev("found", item="seed_3")]})
    assert r.status_code == 200
    assert player.post("/v1/book/claim", json={"item": "seed_3"}).status_code == 200


def test_found_event_rejects_level_jumps(client, player):
    r = player.post("/v1/events", json={"events": [ev("found", item="pot_9")]})
    assert not r.json()["events"][0]["ok"]
    assert player.post("/v1/book/claim", json={"item": "pot_9"}).json()["error"] == "not_discovered"
    r = player.post("/v1/events", json={"events": [ev("found", item="pot_4")]})
    assert r.json()["events"][0]["ok"]


def test_found_chain_cannot_skip_levels(client, player):
    # 改过的客户端一批连发 found pot_4 ~ pot_12：found 不抬高凭据，只有第一件（4 级以内）能过
    batch = [ev("found", item="pot_%d" % lv) for lv in range(4, 13)]
    res = player.post("/v1/events", json={"events": batch}).json()["events"]
    assert res[0]["ok"] and not any(r["ok"] for r in res[1:])
    assert player.post("/v1/book/claim", json={"item": "pot_5"}).json()["error"] == "not_discovered"
    assert player.post("/v1/book/claim", json={"item": "pot_4"}).status_code == 200
    # 快照里真的出现 pot_4 之后，凭据跟上，再往上一级才放行
    player.put(player.snapshot(stash=["pot_4"]))
    assert player.post("/v1/events", json={"events": [ev("found", item="pot_5")]}).json()["events"][0]["ok"]
    assert not player.post("/v1/events", json={"events": [ev("found", item="pot_6")]}).json()["events"][0]["ok"]
