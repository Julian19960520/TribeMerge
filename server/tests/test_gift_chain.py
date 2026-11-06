"""礼包链：顺序校验、免费步幂等、付费步必须验单、周期重置。"""

from app import clock, gift_chain


def _chain(p):
    r = p.get("/v1/gift-chain")
    assert r.status_code == 200, r.text
    return r.json()["chain"]


def _pay(p, step):
    r = p.post("/v1/gift-chain/order", {"step": step})
    assert r.status_code == 200, r.text
    o = r.json()
    assert o["status"] == "created" and o["kind"] == "gift" and o["price"].startswith("¥")
    return p.post("/v1/payments/mock/%s/pay" % o["order_id"])


def test_config_shape():
    ss = gift_chain.steps()
    assert 20 <= len(ss) <= 30
    assert float(ss[0]["price"]) == 0 and float(ss[1]["price"]) == 6
    # 每个付费步都比它前后的免费步值钱得多
    val = gift_chain.cfg()["value"]

    def worth(s):
        t = 0.0
        for iid, n in s["rewards"]:
            ch = iid.rsplit("_", 1)[0]
            k = {"amber": "amber", "fire": "energy", "shell": "shell", "sand": "sand"}.get(ch)
            t += n * val[k] if k else n * val[iid]
        return t
    for i, s in enumerate(ss):
        if s["price"] > 0:
            near = [worth(ss[j]) for j in (i - 1, i + 1) if 0 <= j < len(ss) and ss[j]["price"] == 0]
            assert worth(s) > 5 * max(near)
    # 付费步的性价比（价值 ÷ 价格）越往后越高
    ratios = [worth(s) / (s["price"] * gift_chain.cfg()["cny_amber"]) for s in ss if s["price"] > 0]
    assert ratios == sorted(ratios)


def test_order_free_paid_free(player):
    c = _chain(player)
    assert c["step"] == 0 and c["free_ready"] and c["total"] >= 20
    # 不能跳步
    r = player.post("/v1/gift-chain/claim", {"step": 2})
    assert r.status_code == 409 and r.json()["error"] == "not_head"
    # 第 1 步免费
    r = player.post("/v1/gift-chain/claim", {"step": 0})
    assert r.status_code == 200, r.text
    d = r.json()
    assert d["chain"]["step"] == 1 and d["give"]["energy"] == 50
    assert d["state"]["shells"] == 100
    # 第 2 步付费：不能用 claim 领
    r = player.post("/v1/gift-chain/claim", {"step": 1})
    assert r.status_code == 409 and r.json()["error"] == "need_payment"
    assert _chain(player)["step"] == 1
    # 下单但没付钱：队列不动
    r = player.post("/v1/gift-chain/order", {"step": 1})
    assert r.status_code == 200
    assert _chain(player)["step"] == 1
    # 付费步下单也不能跳
    r = player.post("/v1/gift-chain/order", {"step": 3})
    assert r.status_code == 409 and r.json()["error"] == "not_head"
    # 免费步不能下单
    amber0 = player.get("/v1/save").json()["state"]["amber"]
    paid = _pay(player, 1)
    assert paid.status_code == 200, paid.text
    pj = paid.json()
    assert pj["status"] == "paid" and pj["chain"]["step"] == 2
    assert pj["state"]["amber"] == amber0 + 200
    assert pj["give"]["items"].count("chest_1") == 2 and pj["give"]["rush"] == 3
    # 重复回调不重复发
    again = player.post("/v1/payments/mock/%s/pay" % pj["order_id"]).json()
    assert again["state"]["amber"] == amber0 + 200 and again["chain"]["step"] == 2
    # 第 3 步免费
    r = player.post("/v1/gift-chain/claim", {"step": 2})
    assert r.status_code == 200 and r.json()["chain"]["step"] == 3
    r = player.post("/v1/gift-chain/order", {"step": 3})
    assert r.status_code == 409 and r.json()["error"] == "free_step"


def test_free_claim_idempotent(player):
    r1 = player.post("/v1/gift-chain/claim", {"step": 0}, key="same-key")
    r2 = player.post("/v1/gift-chain/claim", {"step": 0}, key="same-key")
    assert r1.status_code == r2.status_code == 200
    assert r1.json()["state"] == r2.json()["state"]
    assert _chain(player)["step"] == 1
    # 换个键再领同一步：已经领过
    r3 = player.post("/v1/gift-chain/claim", {"step": 0})
    assert r3.status_code == 409 and r3.json()["error"] == "already_claimed"
    st = player.get("/v1/save").json()["state"]
    assert st["shells"] == 100


def test_paid_stale_order_still_delivers(player):
    """同一步下了两单都付了：第二单奖励照发（付过钱），队列不再前移。"""
    player.post("/v1/gift-chain/claim", {"step": 0})
    a = player.post("/v1/gift-chain/order", {"step": 1}).json()
    b = player.post("/v1/gift-chain/order", {"step": 1}).json()
    amber0 = player.get("/v1/save").json()["state"]["amber"]
    player.post("/v1/payments/mock/%s/pay" % a["order_id"])
    rb = player.post("/v1/payments/mock/%s/pay" % b["order_id"]).json()
    assert rb["chain"]["step"] == 2
    assert rb["state"]["amber"] == amber0 + 400


def test_cycle_reset(player):
    player.post("/v1/gift-chain/claim", {"step": 0})
    c = _chain(player)
    assert c["step"] == 1
    cy = gift_chain.cycle_of(clock.now())
    assert cy["end"] - cy["start"] == 7 * 86400 and cy["start"] <= clock.now() < cy["end"]
    # 期末前下的付费单，跨期后才付：发奖但不让新一期前移
    o = player.post("/v1/gift-chain/order", {"step": 1}).json()
    clock.offset = cy["end"] - clock.now() + 5
    c2 = _chain(player)
    assert c2["step"] == 0 and c2["cycle"] == c["cycle"] + 1 and c2["free_ready"]
    paid = player.post("/v1/payments/mock/%s/pay" % o["order_id"]).json()
    assert paid["status"] == "paid" and paid["chain"]["step"] == 0
    r = player.post("/v1/gift-chain/claim", {"step": 0})
    assert r.status_code == 200 and r.json()["chain"]["step"] == 1


def test_cycle_starts_monday_beijing():
    import datetime as dt
    cy = gift_chain.cycle_of(clock.now())
    start = dt.datetime.fromtimestamp(cy["start"], dt.timezone(dt.timedelta(hours=8)))
    assert start.weekday() == 0 and start.hour == 0 and start.minute == 0


def test_needs_auth(client):
    assert client.get("/v1/gift-chain").status_code == 401
