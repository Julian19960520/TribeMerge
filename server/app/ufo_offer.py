"""Limited order support: freeze reviewed rewards, deliver once via payment receipts."""
from collections import Counter
import secrets
from . import clock
from .economy import Reject


def candidate(e, snap):
    owned = Counter(str(c.get('id', '')) for c in snap.get('board', []) if int(c.get('lock', 0)) == 0 and not isinstance(c.get('ck'), dict))
    for item in snap.get('inv', []) + snap.get('stash', []):
        owned[str(item.get('id', '')) if isinstance(item, dict) else str(item)] += 1
    ranked = []
    for order in snap.get('orders', []):
        if order.get('kind') == 'craft' and order.get('phase', 'need') != 'need':
            continue
        ids = order.get('mats', []) if order.get('kind') == 'craft' else order.get('items', [])
        available, missing = owned.copy(), []
        for iid in ids:
            if available[iid] > 0:
                available[iid] -= 1
            elif e.gd.valid_item(iid) and e.gd.type_of(iid) == 'item':
                missing.append(iid)
        if not missing:
            continue
        value = (1 - len(missing) / len(ids)) * 1000 - len(missing) * 10
        ranked.append((value, missing))
    ranked.sort(key=lambda row: -row[0])
    maximum = int(e.gd.ufo_offer['max_items'])
    items = [iid for _, missing in ranked for iid in missing][:maximum]
    if not items:
        return []
    filler = '%s_%d' % (e.gd.chain(items[0]), max(1, e.gd.lv(items[0])-1))
    while len(items) < min(maximum, int(e.gd.ufo_offer.get('min_items', 1))):
        items.append(filler)
    return items


def bundle(e, items):
    """Everything the pack delivers: missing order items + fixed bonus_items (same rule as client UfoOffer.bundle)."""
    return [str(i) for i in items] + [str(i) for i in e.gd.ufo_offer.get('bonus_items', [])]


def active(s):
    o = s.get('offer', {})
    return bool(o) and not o.get('paid') and clock.now() < o['expires_at']


def visit(e, st, snap, received=(), refresh=False):
    cfg = e.gd.ufo_offer
    s = st.setdefault('ufo_offer', {})
    for key in received:
        s.get('deliveries', {}).pop(str(key), None)
    if not cfg.get('enabled') or snap.get('tutorial_on', True):
        return {}
    if not s:
        s.update(next_at=clock.now()+cfg['first_delay_sec'], offer={}, deliveries={})
    if active(s) and refresh:
        items = candidate(e, snap)
        if items:
            s['offer']['items'] = items
        else:
            s['offer'] = {}
    elif clock.now() >= s['next_at']:
        items = candidate(e, snap)
        if items:
            s['offer'] = {'id': secrets.token_hex(12), 'items': items, 'expires_at': clock.now()+cfg['duration_sec'], 'paid': False}
            s['next_at'] = clock.now()+cfg['interval_sec']
        else:
            s['offer'] = {}
            s['next_at'] = clock.now()+cfg['retry_sec']
    return {}


def reviewed(e, st, snap, offer_id):
    s = st.get('ufo_offer', {})
    if not e.gd.ufo_offer.get('enabled') or not active(s) or s['offer']['id'] != offer_id:
        raise Reject('ufo_expired', '飞碟已离开，下次再见')
    if candidate(e, snap) != s['offer']['items']:
        raise Reject('ufo_changed', '订单需求已变化，请重新打开礼包')
    return bundle(e, s['offer']['items'])


def fulfil(e, st, order):
    items = list((order.give or {}).get('items', []))
    for iid in items:
        e.give_item(st, iid, {})
    s = st.setdefault('ufo_offer', {})
    s.setdefault('deliveries', {})[order.id] = items
    if s.get('offer', {}).get('id') == order.ref:
        s['offer']['paid'] = True
