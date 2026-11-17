"""Pricing, regional quotes, daily tiers and once-only virtual purchases."""
import uuid

import pytest

from app import clock, config, economy
from conftest import snapshot


def buy(player, product="energy", price=20, key=None, **extra):
    body = {"product": product, "version": economy.current()["version"], "expected_price": price, **extra}
    return player.c.post("/v1/economy/purchases", json=body, headers={**player.h(), "Idempotency-Key": key or uuid.uuid4().hex})


def test_catalog_values_and_regional_prices(client):
    cn, us = economy.build("CN"), economy.build("US")
    assert [cn["items"][f"fruit_{i}"]["amber"] for i in (5, 7, 8)] == [16, 50, 97]
    assert cn["items"]["seed_3"]["amber"] == 22
    assert cn["items"]["basket_1"]["amber"] == 120
    assert cn["items"]["fruit_8"]["value"] == 128
    assert all(v["value"] > 0 for v in cn["items"].values())
    assert [r["n"] for r in cn["documents"]["amber_packs"]] == [60,330,800,1600,4300,9000]
    assert [r["n"] for r in us["documents"]["amber_packs"]] == [110,290,640,1380,3700,8200]
    assert us["products"]["pass:vip"]["price_str"] == "$4.99"
    assert us["products"]["pass:upgrade"]["price_minor"] == 500
    assert client.get("/v1/economy/catalog").json()["version"] == cn["version"]
    assert cn["items"] == us["items"]
    assert cn["rules_version"] == us["rules_version"]
    assert all(a["after"] <= a["budget"] for a in cn["reward_audit"].values())


def test_energy_price_tiers_and_daily_reset(player):
    assert player.upload(snapshot(amber=1000), 0).status_code == 200
    for price in (20,30,40,50,60,60):
        response = buy(player, price=price)
        assert response.status_code == 200, response.text
        assert response.json()["price"] == price
        assert response.json()["grant"]["content"]["rewards"] == [["fire_2",100]]
    clock.offset += 86400
    assert buy(player, price=20).status_code == 200


def test_virtual_idempotency_and_reserved_balance(player):
    player.upload(snapshot(amber=25), 0)
    key = uuid.uuid4().hex
    first = buy(player, key=key)
    again = buy(player, key=key)
    assert first.status_code == again.status_code == 200
    assert first.json()["grant"]["id"] == again.json()["grant"]["id"]
    # Undelivered grants reserve their cost; a second call cannot overspend.
    refused = buy(player, price=30)
    assert refused.status_code == 409 and refused.json()["error"] == "not_enough_amber"
    changed = buy(player, product="shell", price=20, key=key)
    assert changed.status_code == 409 and changed.json()["error"] == "idempotency_key_reused"


def test_wrong_price_version_and_unknown_product_do_not_consume_tier(player):
    player.upload(snapshot(amber=100), 0)
    assert buy(player, price=1).json()["error"] == "price_changed"
    assert buy(player, version="old").json()["error"] == "catalog_changed"
    assert buy(player, product="sand:999", price=1).status_code == 404
    assert buy(player, price=20).status_code == 200


def test_hourglass_uses_actual_six_second_units(player):
    player.upload(snapshot(amber=100), 0)
    response = buy(player, product="sand:3", price=6)
    assert response.status_code == 200, response.text
    assert response.json()["grant"]["content"]["rewards"] == [["sand_2",600]]
    assert buy(player, product="shell", price=20).json()["grant"]["content"]["rewards"] == [["shell_2",100]]


def test_paid_quotes_use_server_market_and_ignore_client_prices(player, monkeypatch):
    monkeypatch.setenv("TRIBE_PRICING_MARKET", "US")
    config.get_settings.cache_clear()
    response = player.c.post("/v1/payments/orders", json={"product":"amber:0", "detail":{"price":1,"market":"CN","amber":999999}}, headers={**player.h(),"Idempotency-Key":uuid.uuid4().hex})
    assert response.status_code == 200, response.text
    order = response.json()["order"]
    assert order["price_fen"] == 199 and order["currency"] == "USD"
    paid = player.post("/v1/payments/mock/pay", {"order_id":order["id"]})
    assert paid.status_code == 200
    assert paid.json()["grant"]["content"]["amber"] == 110


def test_shop_uses_server_stock_and_price(player):
    book = economy.current()
    hot = [dict(r) for r in book["documents"]["store"]]
    hot[0].update(id="fruit_3", price=0, stock=99999)
    player.upload(snapshot(amber=1000, hot_revision=0, replay_meta={"hot":{"list":hot}}),0)
    for _ in range(book["documents"]["store"][0]["stock"]):
        response = buy(player, product="shop:fruit_3", price=4, detail={"key":"hot_0","price":0,"stock":99999})
        assert response.status_code == 200, response.text
        assert response.json()["grant"]["content"]["cost_amber"] == 4
    assert buy(player, product="shop:fruit_3", price=4, detail={"key":"hot_0"}).json()["error"] == "limit_reached"
