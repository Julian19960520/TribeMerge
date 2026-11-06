"""Authoritative seasonal merge boards. Shares data/merge_events.json with Godot."""
from datetime import datetime, timezone
from .economy import Reject


def current(config, now):
    for raw in config.get('seasons', []):
        if not raw.get('enabled', True):
            continue
        start = datetime.fromisoformat(raw['start_utc']).replace(tzinfo=timezone.utc).timestamp()
        period = raw.get('repeat_days', 0) * 86400
        duration = raw.get('duration_days', 7) * 86400
        if now < start:
            continue
        index = int((now - start) / period) if period else 0
        end = start + index * period + duration
        if now < end:
            return dict(raw, key=f"{raw['id']}:{index}", ends_at=end)
    return {}


def definition(config, key):
    prefix, _, index = key.partition(':')
    if not index.isdigit():
        return {}
    return next((dict(c, key=key) for c in config.get('seasons', []) if c['id'] == prefix), {})


def fresh(c):
    b = c['board']
    cols, rows = b['cols'], b['total_rows']
    cells = []
    for row in range(rows):
        for col in range(cols):
            depth = rows - 2 - row
            tiers = b['locked_tiers']
            tier = tiers[(max(0, depth) // 2 + col + b.get('seed', 0)) % len(tiers)] if depth >= 2 else 1
            cells.append({'id': c['chain'][min(max(0, tier - 1), len(c['chain']) - 2)]['id'] if row < rows - 1 else '', 'lock': 2 if row < rows - 1 else 0})
    return dict(rules_version=2, cells=cells, points=0, earned=0, spent=0, discovered={}, min_view=rows-b['visible_rows'], view=rows-b['visible_rows'], claimed=False, orders=0)


def state(st, c):
    s = st.setdefault('merge_events', {}).setdefault(c['key'], fresh(c))
    if s.get('rules_version', 1) < 2:
        for k, tile in enumerate(s['cells']):
            if tile['lock'] == 1 and not any(s['cells'][n]['lock'] == 0 for n in neighbors(k, c['board']['cols'], len(s['cells']))):
                tile['lock'] = 2
        s['rules_version'] = 2
        s['min_view'] = s['view']
    return s


def order_points(c, order, gd):
    ids = order.get('items', [])
    score = max([1] + [gd.lv(i) for i in ids]) + max(0, len(ids) - 1)
    p = c['points']
    tier = sum(score >= t for t in p['order_thresholds'])
    return min(3, max(1, p['order_rewards'][min(tier, len(p['order_rewards'])-1)]))


def on_order(econ, st, order):
    c = current(econ.gd.merge_events, econ.now())
    if not c or (not st.get('gm_activities') and st.get('level', 1) < c.get('unlock_level', 1)):
        return
    s = state(st, c)
    n = order_points(c, order, econ.gd)
    s['points'] += n
    s['earned'] += n
    s['orders'] += 1


def complete(c, s):
    if c['board'].get('goal') == 'discover_all':
        return all(i['id'] in s['discovered'] for i in c['chain'])
    return all(x['lock'] == 0 for x in s['cells'])


def neighbors(i, cols, count):
    x, y = i % cols, i // cols
    return [ny * cols + nx for nx, ny in [(x-1,y), (x+1,y), (x,y-1), (x,y+1)] if 0 <= nx < cols and ny >= 0 and ny * cols + nx < count]


def reveal_neighbors(cells, at, cols):
    revealed = []
    for k in neighbors(at, cols, len(cells)):
        if cells[k]['lock'] == 2:
            cells[k]['lock'] = 1 if cells[k]['id'] else 0
            revealed.append(k)
    return revealed


def advance(c, s):
    cols, rows = c['board']['cols'], c['board']['visible_rows']
    cells = s['cells']
    while s['view'] > 0:
        view = s['view']
        if any(cells[view*cols+k]['lock'] for k in range(cols)):
            break
        shifted = False
        for step in range(min(view, c['board']['reveal_rows']), 0, -1):
            next_view = view-step
            next_end = (next_view+rows)*cols
            retiring = list(range(next_end, (view+rows)*cols))
            if any(cells[k]['lock'] for k in retiring):
                continue
            outgoing = [k for k in retiring if cells[k]['id']]
            slots = [k for k in range(next_view*cols, next_end) if not cells[k]['lock'] and not cells[k]['id']][::-1]
            if len(outgoing) > len(slots):
                continue
            for source, dest in zip(outgoing, slots):
                cells[dest]['id'], cells[source]['id'] = cells[source]['id'], ''
            s['view'] = s['min_view'] = next_view
            shifted = True
            break
        if not shifted:
            break


def action(econ, st, req):
    c = definition(econ.gd.merge_events, req.season)
    if not c or (not st.get('gm_activities') and st.get('level', 1) < c.get('unlock_level', 1)):
        raise Reject('event_unavailable', '活动尚未开放')
    if req.action != 'claim' and current(econ.gd.merge_events, econ.now()).get('key') != req.season:
        raise Reject('event_ended', '本期活动已结束')
    if req.action == 'claim' and req.season not in (st.get('merge_events') or {}):
        raise Reject('not_completed', '尚未完成活动')
    s = state(st, c)
    cells = s['cells']
    cols = c['board']['cols']
    view = s['view']
    if req.action != 'claim' and req.view != view:
        raise Reject('view_changed', '棋盘已滚动，请重试')
    lo, hi = view*cols, (view+c['board']['visible_rows'])*cols
    if req.action != "claim" and s["claimed"]:
        raise Reject("event_completed", "本期奖励已领取")
    s["view"] = view
    if req.action == 'spawn':
        cost = c['points']['spawn_cost']
        if s['points'] < cost:
            raise Reject('not_enough_points', '完成主棋盘订单可获得活动积分')
        empty = [i for i in range(lo, hi) if not cells[i]['id'] and not cells[i]['lock']]
        if not empty:
            raise Reject('board_full', '当前区域已满，请先合并物品')
        origin = hi-cols+cols//2
        to = min(empty, key=lambda i: (i%cols-origin%cols)**2+(i//cols-origin//cols)**2+i*.0001)
        iid = c['chain'][c['points']['spawn_tier']-1]['id']
        cells[to]['id'] = iid
        s['points'] -= cost
        s['spent'] += cost
        s['discovered'][iid] = True
        return {'kind':'spawn', 'to':to, 'id':iid}
    if req.action == 'drop':
        a,b = req.from_cell, req.to
        if a == b or not lo <= a < hi or not lo <= b < hi or not cells[a]['id'] or cells[a]['lock']:
            raise Reject('invalid_drop', '不能移动这个物品')
        ca,cb = cells[a],cells[b]
        locked = bool(cb['lock'])
        if cb['lock'] == 2:
            raise Reject('covered', '先在旁边合并，揭开覆盖')
        chain = [i['id'] for i in c['chain']]
        iid,under = ca['id'],cb['id']
        index = chain.index(iid)
        if iid == under and index < len(chain)-1:
            kind = 'merge'
            ca['id'],cb['id'],cb['lock'] = '',chain[index+1],0
            s['discovered'][cb['id']] = True
            if locked: s['discovered'][under] = True
        elif locked:
            raise Reject('not_matching', '需要同级物品合并解锁')
        else:
            kind = 'swap' if under else 'move'
            ca['id'],cb['id'] = under,iid
        revealed = reveal_neighbors(cells, b, cols) if kind == 'merge' else []
        advance(c, s)
        return dict(kind=kind, **{'from':a}, to=b, id=iid, under=under, unlocked=locked, revealed=revealed)
    if req.action == 'recycle':
        i = req.cell
        if not lo <= i < hi or cells[i]['lock'] or not cells[i]['id']:
            raise Reject('invalid_cell', '请选择未锁定物品')
        cells[i]['id'] = ''
        return {'kind':'recycle'}
    if req.action == 'claim':
        if s['claimed'] or not complete(c,s):
            raise Reject('already_claimed' if s['claimed'] else 'not_completed', '奖励已领取，或尚未完成活动')
        s['claimed'] = True
        out = {'kind':'claim','rewards':c['rewards']}
        econ.grant(st,c['rewards'],out)
        return out
    raise Reject('invalid_action','未知操作',400)
