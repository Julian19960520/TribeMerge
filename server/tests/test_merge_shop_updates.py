import random

from conftest import Player


def test_free_daily_and_paid_refresh(player):
    r = player.post('/v1/daily/claim', {'key': 'deal_2'}, key='free-once')
    assert r.status_code == 200
    assert r.json()['give']['energy'] == 15
    assert r.json()['state']['amber'] == 80
    assert player.post('/v1/daily/claim', {'key': 'deal_2'}).status_code == 409
    assert player.post('/v1/daily/claim', {'key': 'deal_2'}, key='free-once').json() == r.json()
    player.post('/v1/shop/buy', {'key': 'hot_0', 'item': 'fruit_3'})
    r = player.post('/v1/shop/refresh', key='refresh-once')
    assert r.status_code == 200
    assert r.json()['state']['amber'] == 68
    assert r.json()['state']['hot_bought'] == {}
    assert r.json()['state']['hot_revision'] == 1
    assert r.json()['state']['deals_bought']['deal_2'] == 1
    assert player.post('/v1/shop/refresh', key='refresh-once').json() == r.json()
    assert player.get('/v1/shop').json()['hot_revision'] == 1
    for _ in range(6):
        assert player.post('/v1/shop/refresh').status_code == 200
    r = player.post('/v1/shop/refresh')
    assert r.status_code == 409 and r.json()['state']['amber'] == 8
    from app import clock
    clock.offset += 86400
    assert player.post('/v1/daily/claim', {'key': 'deal_2'}).status_code == 200


def test_level_eight_card_gate(client):
    player = Player(client, player_id="TRBlevelseven")
    assert player.put(player.snapshot(level=7, stash=['pack_1'])).status_code == 200
    assert not any(o['key'] == 'deal_1' for o in player.get('/v1/shop').json()['offers'])
    assert player.post('/v1/pack/open').status_code == 409
    eight = Player(client, player_id="TRBleveleight", device="eight")
    assert eight.put(eight.snapshot(level=8, stash=["pack_1"])).status_code == 200
    assert len([o for o in eight.get("/v1/shop").json()["offers"] if o["key"].startswith("deal_")]) == 5
    assert eight.post("/v1/pack/open").status_code == 200


def test_bubble_quote_purchase_and_expiry(player, monkeypatch):
    monkeypatch.setattr(random.SystemRandom, 'random', lambda _: 0.0)
    snap = player.snapshot(board=[{'id': 'fruit_5', 'lock': 0}] + [{'id': '', 'lock': 0} for _ in range(62)])
    assert player.put(snap).status_code == 200
    r = player.post('/v1/merge/bubble', {'item': 'fruit_5'}, key='merged-once')
    assert r.status_code == 200
    offer = r.json()['give']['offer']
    assert offer['item'] == 'fruit_5' and offer['price'] == 10
    assert player.post('/v1/merge/bubble', {'item': 'fruit_5'}, key='merged-once').json()['give']['offer'] == offer
    bought = player.post('/v1/merge/bubble/buy', {'uid': offer['uid']}, key='buy-once')
    assert bought.status_code == 200 and bought.json()['state']['amber'] == 70
    assert bought.json()['give']['items'] == ['fruit_5']
    assert player.post('/v1/merge/bubble/buy', {'uid': offer['uid']}, key='buy-once').json() == bought.json()
    assert player.post('/v1/merge/bubble/buy', {'uid': offer['uid']}).status_code == 409
    offer = player.post('/v1/merge/bubble', {'item': 'fruit_5'}).json()['give']['offer']
    from app import clock
    clock.offset += 61
    expired = player.post('/v1/merge/bubble/buy', {'uid': offer['uid']})
    assert expired.status_code == 409 and expired.json()['state']['amber'] == 70


def test_unpaid_bubbles_do_not_grant_currency_budget(player):
    from app.services import economy
    e = economy()
    snap = player.snapshot(board=[{'id': 'amber_5', 'lock': 3, 'bubble': {'expires': 1}}])
    assert e.snapshot_items(snap) == []
    assert e.bubble_price('seed_3') > e.bubble_price('fruit_3')
    assert e.bubble_price('basket_3') > e.bubble_price('fruit_3')


def test_refresh_changes_every_hot_slot_without_snapshot(player):
    previous = {o['key']: o['id'] for o in player.get('/v1/shop').json()['offers'] if o['key'].startswith('hot_')}
    for _ in range(3):
        assert player.post('/v1/shop/refresh').status_code == 200
        current = {o['key']: o['id'] for o in player.get('/v1/shop').json()['offers'] if o['key'].startswith('hot_')}
        assert len(current) == 6
        assert all(current[k] != previous[k] for k in previous)
        assert current == {o['key']: o['id'] for o in player.get('/v1/shop').json()['offers'] if o['key'].startswith('hot_')}
        previous = current


def test_crafted_item_codex_reward_once(player):
    from conftest import ev
    assert player.post('/v1/book/claim', {'item': 'salad'}).status_code == 409
    r = player.post('/v1/events', {'events': [ev('found', item='salad')]})
    assert r.status_code == 200 and r.json()['events'][0]['ok']
    r = player.post('/v1/book/claim', {'item': 'salad'})
    assert r.status_code == 200 and r.json()['give']['energy'] == 1
    assert player.post('/v1/book/claim', {'item': 'salad'}).json()['error'] == 'already_claimed'


def test_no_bubbles_for_low_items_or_tutorial(player, monkeypatch):
    monkeypatch.setattr(random.SystemRandom, 'random', lambda _: 0.0)
    assert player.post('/v1/merge/bubble', {'item': 'fruit_3'}).json()['give'] == {}
    snap = player.snapshot(tutorial_on=True, board=[{'id': 'fruit_5', 'lock': 0}])
    assert player.put(snap).status_code == 200
    assert player.post('/v1/merge/bubble', {'item': 'fruit_5'}).json()['give'] == {}


def test_shop_resource_direct_credit_cannot_redeem_twice(player):
    from conftest import ev
    purchase = player.post('/v1/daily/claim', {'key': 'deal_2'}, key='free-energy')
    assert purchase.status_code == 200 and purchase.json()['give']['energy'] == 15
    assert player.post('/v1/daily/claim', {'key': 'deal_2'}, key='free-energy').json() == purchase.json()
    assert player.post('/v1/daily/claim', {'key': 'deal_2'}).status_code == 409
    repeat = player.post('/v1/events', {'events': [ev('collect', item='fire_4')]}).json()['events'][0]
    assert not repeat['ok'] and repeat['error'] == 'no_budget'
