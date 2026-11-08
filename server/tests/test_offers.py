"""付费限时礼包（data/offers.json）：配置性价比、等级 / 冷却、下单 → mock 支付到账、每期限购、重复回调不重复发。"""
import json
import pathlib

from app import clock
from test_merge_event import mutate

CFG = json.loads((pathlib.Path(__file__).resolve().parents[2] / 'data' / 'offers.json').read_text(encoding='utf8'))


def test_config_value_matches_label():
    from app.services import economy
    from app import offers
    e = economy()
    for kind in offers.KINDS:
        for t in CFG[kind]['tiers']:
            pct = offers.value(e, t['rewards']) / (t['price_cny'] * 15) * 100
            assert abs(pct - t['value_pct']) <= 5, (kind, t['price_cny'], pct)


def test_locked_below_level(player):
    r = player.post('/v1/offer/open', {'offer': 'spree'})
    assert r.status_code == 409 and r.json()['error'] == 'offer_locked'
    assert player.post('/v1/offer/order', {'offer': 'spree', 'tier': 0}).json()['error'] == 'offer_expired'


def test_spree_buy_limit_and_cooldown(player):
    mutate(player, lambda st: st.update(level=13))
    s = player.post('/v1/offer/open', {'offer': 'spree'}).json()['state']['offers']['spree']
    assert s['end'] - s['start'] == CFG['spree']['duration_sec']
    amber0 = player.post('/v1/offer/open', {'offer': 'spree'}).json()['state']['amber']
    t = CFG['spree']['tiers'][0]
    for n in range(t['limit']):
        o = player.post('/v1/offer/order', {'offer': 'spree', 'tier': 0}).json()
        assert o['price'] == '¥%d' % t['price_cny']
        paid = player.post('/v1/payments/mock/%s/pay' % o['order_id']).json()
        assert paid['status'] == 'paid' and paid['state']['offers']['spree']['bought'] == {'0': n + 1}
        # 重复回调不重复发
        assert player.post('/v1/payments/mock/%s/pay' % o['order_id']).json()['state'] == paid['state']
    amber = dict(t['rewards'])['amber_4']
    assert paid['state']['amber'] == amber0 + amber * t['limit']
    assert player.post('/v1/offer/order', {'offer': 'spree', 'tier': 0}).json()['error'] == 'offer_sold_out'
    # 期满：不能买；冷却中不能开新一期；冷却完能开
    clock.offset += CFG['spree']['duration_sec'] + 1
    assert player.post('/v1/offer/order', {'offer': 'spree', 'tier': 0}).json()['error'] == 'offer_expired'
    assert player.post('/v1/offer/open', {'offer': 'spree'}).json()['error'] == 'offer_cooldown'
    clock.offset += CFG['spree']['cooldown_sec']
    s = player.post('/v1/offer/open', {'offer': 'spree'}).json()['state']['offers']['spree']
    assert s['bought'] == {}


def test_energy_tiers_and_stale_payment(player):
    mutate(player, lambda st: st.update(level=13))
    player.post('/v1/offer/open', {'offer': 'energy'})
    o = player.post('/v1/offer/order', {'offer': 'energy', 'tier': 2}).json()
    paid = player.post('/v1/payments/mock/%s/pay' % o['order_id']).json()
    rw = dict(CFG['energy']['tiers'][2]['rewards'])
    assert paid['give']['energy'] == rw['fire_2'] and paid['give']['items'] == ['chest_1']
    assert player.post('/v1/offer/order', {'offer': 'energy', 'tier': 2}).json()['error'] == 'offer_sold_out'
    assert player.post('/v1/offer/order', {'offer': 'energy', 'tier': 9}).json()['error'] == 'bad_tier'
    # 下了单没付，期满后才付：照发奖励，不算进新一期
    o = player.post('/v1/offer/order', {'offer': 'energy', 'tier': 0}).json()
    clock.offset += CFG['energy']['duration_sec'] + CFG['energy']['cooldown_sec'] + 1
    player.post('/v1/offer/open', {'offer': 'energy'})
    paid = player.post('/v1/payments/mock/%s/pay' % o['order_id']).json()
    assert paid['status'] == 'paid' and paid['state']['offers']['energy']['bought'] == {}


def test_offers_cannot_be_uploaded(player):
    assert player.put(player.snapshot(offers={'spree': {'start': 0, 'end': 9e12, 'bought': {}}})).json()['state']['offers'] == {}
