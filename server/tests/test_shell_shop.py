"""集市「贝币小摊」：服务器扣贝币、库存限购、每 8 小时按服务器时间刷新、幂等。"""

from conftest import Player


def _player(client, shells, pid="TRB00002222"):
    p = Player(client, player_id=pid)
    r = p.put(p.snapshot(shells=shells))  # 老存档第一份快照：服务器字段信一次
    assert r.status_code == 200 and r.json()["state"]["shells"] == shells
    return p


def _shell_offers(p):
    j = p.get("/v1/shop").json()
    return [o for o in j["offers"] if o["key"].startswith("shell_")], j


def test_shell_offers_listed_and_priced_above_order_pay(client):
    from app.services import gamedata
    p = _player(client, 0)
    rows, j = _shell_offers(p)
    assert len(rows) == 6 and all(o["cur"] == "shell" for o in rows)
    assert 0 < j["shell_secs_left"] <= 8 * 3600
    gd = gamedata()
    pay = 3.0  # 交单每理论火苗给的贝币（OrderRoll.PAY_PER_FLAME / economy.json orders.pay_per_flame）
    for o in rows:
        assert isinstance(o["price"], int)
        assert o["price"] > gd.flames(o["id"]) * pay, o  # 买来交单必亏
        assert gd.is_goods(o["id"])  # 不卖生产器 / 宝箱 / 货币


def test_buy_spends_shells_and_gives_item(client):
    p = _player(client, 100)
    r = p.post("/v1/shop/buy", json={"key": "shell_0", "item": "fruit_2"})
    assert r.status_code == 200, r.text
    j = r.json()
    assert j["state"]["shells"] == 92 and j["state"]["amber"] == 80  # 只扣贝币，不动琥珀
    assert j["give"]["items"] == ["fruit_2"]
    assert j["state"]["shell_bought"] == {"shell_0": 1}


def test_not_enough_shells(client):
    p = _player(client, 51)
    r = p.post("/v1/shop/buy", json={"key": "shell_3", "item": "seed_1"})
    assert r.status_code == 409 and r.json()["error"] == "not_enough_shell"
    assert r.json()["state"]["shells"] == 51 and r.json()["state"]["shell_bought"] == {}


def test_stock_limit_and_wrong_item(client):
    p = _player(client, 1000)
    for _ in range(2):
        assert p.post("/v1/shop/buy", json={"key": "shell_4", "item": "gem_1"}).status_code == 200
    r = p.post("/v1/shop/buy", json={"key": "shell_4", "item": "gem_1"})
    assert r.status_code == 409 and r.json()["error"] == "sold_out" and r.json()["state"]["shells"] == 1000 - 104
    assert p.post("/v1/shop/buy", json={"key": "shell_0", "item": "fruit_9"}).json()["error"] == "no_offer"
    assert p.post("/v1/shop/buy", json={"key": "shell_9", "item": ""}).json()["error"] == "no_offer"
    assert p.post("/v1/shop/buy", json={"key": "shells_0", "item": "fruit_2"}).status_code == 422


def test_refresh_every_8_hours_by_server_clock(client):
    from app import clock
    p = _player(client, 1000)
    for _ in range(3):
        assert p.post("/v1/shop/buy", json={"key": "shell_1", "item": "tool_2"}).status_code == 200
    assert p.post("/v1/shop/buy", json={"key": "shell_1", "item": "tool_2"}).json()["error"] == "sold_out"
    rows, j = _shell_offers(p)
    left = j["shell_secs_left"]
    assert next(o for o in rows if o["key"] == "shell_1")["left"] == 0
    period = j["shell_period"]
    clock.offset += left - 5  # 还没到点
    assert p.post("/v1/shop/buy", json={"key": "shell_1", "item": "tool_2"}).json()["error"] == "sold_out"
    clock.offset += 10  # 过了刷新点
    rows, j = _shell_offers(p)
    assert j["shell_period"] != period and next(o for o in rows if o["key"] == "shell_1")["left"] == 3
    r = p.post("/v1/shop/buy", json={"key": "shell_1", "item": "tool_2"})
    assert r.status_code == 200 and r.json()["state"]["shell_bought"] == {"shell_1": 1}


def test_idempotent_buy(client):
    p = _player(client, 100)
    a = p.post("/v1/shop/buy", json={"key": "shell_2", "item": "cloth_2"}, key="same-key-1")
    b = p.post("/v1/shop/buy", json={"key": "shell_2", "item": "cloth_2"}, key="same-key-1")
    assert a.status_code == b.status_code == 200
    assert a.json()["give"] == b.json()["give"]
    assert b.json()["state"]["shells"] == 92 and b.json()["state"]["shell_bought"] == {"shell_2": 1}
    c = p.post("/v1/shop/buy", json={"key": "shell_2", "item": "cloth_2"})
    assert c.json()["state"]["shells"] == 84


def test_amber_shop_unchanged(client):
    p = _player(client, 100)
    offers = p.get("/v1/shop").json()["offers"]
    hot0 = next(o for o in offers if o["key"] == "hot_0")
    r = p.post("/v1/shop/buy", json={"key": "hot_0", "item": hot0["id"]})
    assert r.status_code == 200 and r.json()["state"]["amber"] == 80 - hot0["price"] and r.json()["state"]["shells"] == 100
