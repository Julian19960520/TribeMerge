from app import clock
from test_merge_event import mutate
import json, pathlib

UFO = json.loads((pathlib.Path(__file__).resolve().parents[2] / 'data' / 'ufo_offer.json').read_text(encoding='utf8'))
DELAY, STAY, BONUS = UFO['first_delay_sec'], UFO['duration_sec'], UFO['bonus_items']


def test_daily_member_ad_and_day_reset(player):
    keys = [o['key'] for o in player.get('/v1/shop').json()['offers'] if o['key'].startswith('deal_')]
    assert keys == ['deal_ad', 'deal_energybox', 'deal_member_1', 'deal_member_2', 'deal_2']
    assert player.post('/v1/daily/claim', {'key':'deal_member_1'}).json()['error'] == 'member_required'
    assert player.post('/v1/shop/buy', {'key':'deal_member_1', 'item':'amber_3'}).status_code in (409,422)
    mutate(player, lambda st: st.update(pass_tier=1))
    r = player.post('/v1/daily/claim', {'key':'deal_member_1'}, key='m1')
    assert r.json()['state']['amber'] == 180
    assert player.post('/v1/daily/claim', {'key':'deal_member_1'}, key='m1').json() == r.json()
    # 第二份要超级贵宾
    assert player.post('/v1/daily/claim', {'key':'deal_member_2'}).json()['error'] == 'member_required'
    mutate(player, lambda st: st.update(pass_tier=2))
    assert player.post('/v1/daily/claim', {'key':'deal_member_2'}).json()['state']['amber'] == 280
    assert player.post('/v1/daily/claim', {'key':'deal_member_1'}).status_code == 409
    assert player.post('/v1/daily/claim', {'key':'deal_ad'}).json()['error'] == 'ad_incomplete'
    assert player.post('/v1/daily/ad/start').status_code == 200
    assert player.post('/v1/daily/claim', {'key':'deal_ad'}).status_code == 409
    clock.offset += 6
    r = player.post('/v1/daily/claim', {'key':'deal_ad'}, key='ad1')
    assert r.json()['give']['energy'] == 30
    assert player.post('/v1/daily/claim', {'key':'deal_ad'}, key='ad1').json() == r.json()
    assert player.post('/v1/daily/claim', {'key':'deal_ad'}).status_code == 409
    clock.offset += 86400
    assert player.post('/v1/daily/claim', {'key':'deal_member_1'}).json()['state']['amber'] == 380
    assert player.post('/v1/daily/claim', {'key':'deal_ad'}).json()['error'] == 'ad_incomplete'


def test_gm_unlocks_without_level_and_cannot_be_uploaded(player, monkeypatch):
    assert player.put(player.snapshot(gm_activities=True)).json()['state']['gm_activities'] is False
    r = player.post('/v1/gm/activities')
    assert r.json()['state']['gm_activities'] and r.json()['state']['level'] == 1
    from app.config import get_settings
    monkeypatch.setattr(get_settings(), 'env', 'prod')
    assert player.post('/v1/gm/activities').status_code == 403
    monkeypatch.setattr(get_settings(), 'enable_mock_payment', False)
    assert player.post('/v1/daily/ad/start').status_code == 409


def test_ufo_candidate_and_refresh_expiry(player):
    from app.services import economy
    from app.ufo_offer import candidate
    snap = player.snapshot(tutorial_on=False, board=[{'id':'fruit_3','lock':0},{'id':'fruit_4','lock':3}],orders=[{'items':['fruit_3','fruit_3','fruit_4']},{'items':['tool_3','tool_4','tool_5']}])
    assert candidate(economy(), snap) == ['fruit_3','fruit_4','tool_3']
    assert player.put(snap).status_code == 200
    assert not player.post('/v1/ufo/visit', {}).json()['state']['ufo_offer']['offer']
    clock.offset += DELAY + 1
    o = player.post('/v1/ufo/visit', {}).json()['state']['ufo_offer']['offer']
    assert o['items'] == ['fruit_3','fruit_4','tool_3']
    clock.offset += 2
    updated = player.post('/v1/ufo/visit', {'refresh':True}).json()['state']['ufo_offer']['offer']
    assert updated['id'] == o['id'] and updated['expires_at'] == o['expires_at']
    clock.offset += STAY
    assert player.post('/v1/ufo/order', {'offer':o['id']}).json()['error'] == 'ufo_expired'


def test_ufo_pay_receipt_idempotence_and_frozen_order(player):
    snap = player.snapshot(tutorial_on=False, orders=[{'items':['fruit_5']}])
    assert player.put(snap).status_code == 200
    player.post('/v1/ufo/visit', {})
    clock.offset += DELAY + 1
    o = player.post('/v1/ufo/visit', {}).json()['state']['ufo_offer']['offer']
    order = player.post('/v1/ufo/order', {'offer':o['id']}).json()
    assert order['price'] == '¥3' and order['give']['items'] == ['fruit_5','fruit_4','fruit_4'] + BONUS
    assert player.post('/v1/ufo/order', {'offer':o['id']}).json()['order_id'] == order['order_id']
    # Payment can settle after expiry, using rewards frozen when order was created.
    clock.offset += STAY + 1
    paid = player.post('/v1/payments/mock/%s/pay' % order['order_id']).json()
    state = paid['state']['ufo_offer']
    assert state['offer']['paid'] and state['deliveries'][order['order_id']] == ['fruit_5','fruit_4','fruit_4'] + BONUS
    replay = player.post('/v1/payments/mock/%s/pay' % order['order_id']).json()
    assert replay['state'] == paid['state']
    assert player.post('/v1/ufo/order', {'offer':o['id']}).status_code == 409
    ack = player.post('/v1/ufo/visit', {'received':[order['order_id']]}).json()
    assert not ack['state']['ufo_offer']['deliveries']


def test_ufo_stale_order_and_tutorial_block(player):
    snap = player.snapshot(tutorial_on=True,orders=[{'items':['fruit_5']}])
    assert player.put(snap).status_code == 200
    assert player.post('/v1/ufo/visit', {}).json()['state']['ufo_offer'] == {}
    snap['tutorial_on'] = False
    player.put(snap)
    player.post('/v1/ufo/visit', {})
    clock.offset += DELAY + 1
    o = player.post('/v1/ufo/visit', {}).json()['state']['ufo_offer']['offer']
    snap['orders'] = [{'items':['tool_5']}]
    assert player.put(snap).status_code == 200
    assert player.post('/v1/ufo/order', {'offer':o['id']}).json()['error'] == 'ufo_changed'
    updated = player.post('/v1/ufo/visit', {'refresh':True}).json()['state']['ufo_offer']['offer']
    assert updated['items'] == ['tool_5','tool_4','tool_4'] and updated['expires_at'] == o['expires_at']
