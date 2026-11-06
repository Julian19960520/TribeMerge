"""Configured daily rewards. Ad completion is mock-only until an SDK is connected."""
from . import clock
from .economy import Reject
from .config import get_settings


def offer(e, key):
    row = next((d for d in e.gd.daily_deals if d['key'] == key), None)
    if not row:
        raise Reject('no_offer', '这件已经下架了')
    return row


def check(e, st, d):
    e.ensure_day(st)
    if int(st.get('pass_tier', 0)) < d.get('min_tier', 0):
        raise Reject('member_required', '需要会员才能领取')
    if st['deals_bought'].get(d['key'], 0) >= d['stock']:
        raise Reject('sold_out', '今日已经领取')


def ad_start(e, st):
    if not get_settings().enable_mock_payment:
        raise Reject('ad_not_configured', '广告渠道尚未接入')
    check(e, st, offer(e, 'deal_ad'))
    st['daily_ad'] = {'day': e.day(), 'ready_at': clock.now() + 5}
    return {}


def claim(e, st, key):
    d = offer(e, key)
    check(e, st, d)
    if d.get('mode') == 'ad':
        a = st.get('daily_ad', {})
        if not get_settings().enable_mock_payment or a.get('day') != e.day() or clock.now() < a.get('ready_at', float('inf')):
            raise Reject('ad_incomplete', '请完整观看广告')
    e._spend(st, d.get('currency', 'amber'), d['price'])
    st['deals_bought'][key] = st['deals_bought'].get(key, 0) + 1
    st.pop('daily_ad', None) if d.get('mode') == 'ad' else None
    return e.grant(st, d['rewards'], {})


def energy_chest(e, st):
    credits = st.setdefault('credits', {})
    if credits.get('energybox', 0) <= 0:
        raise Reject('no_chest', '没有可以打开的体力宝箱')
    credits['energybox'] -= 1
    out = {}
    for _ in range(3):
        e.give_item(st, 'fire_4', out)
    return out
