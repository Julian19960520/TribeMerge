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


def locked_tier(b, depth, col):
    """Locked item tier at a depth (0 = row above the open bottom row). Same hash as MergeEvent.gd."""
    seed = b.get('seed', 0)
    if 'layers' not in b:
        old = b['locked_tiers']
        return 1 if depth < 2 else old[(depth // 2 + col + seed) % len(old)]
    tiers, acc = b['layers'][-1]['tiers'], 0
    for layer in b['layers']:
        acc += layer['rows']
        if depth < acc:
            tiers = layer['tiers']
            break
    return tiers[((depth * 131 + col * 71 + seed * 17) % 97) % len(tiers)]


def fresh(c):
    b = c['board']
    cols, rows = b['cols'], b['total_rows']
    cells = []
    for row in range(rows):
        for col in range(cols):
            if row == rows - 1:
                cells.append({'id': '', 'lock': 0})
                continue
            tier = locked_tier(b, rows - 2 - row, col)
            cells.append({'id': c['chain'][min(max(0, tier - 1), len(c['chain']) - 2)]['id'], 'lock': 2})
    return dict(rules_version=3, cells=cells, points=0, earned=0, spent=0, discovered={}, min_view=rows-b['visible_rows'], view=rows-b['visible_rows'], claimed=False, got=[], orders=0)


def state(st, c):
    s = st.setdefault('merge_events', {}).setdefault(c['key'], fresh(c))
    version = s.get('rules_version', 1)
    if version < 2:
        for k, tile in enumerate(s['cells']):
            if tile['lock'] == 1 and not any(s['cells'][n]['lock'] == 0 for n in neighbors(k, c['board']['cols'], len(s['cells']))):
                tile['lock'] = 2
    if version < 3:
        s['rules_version'] = 3
        advance(c, s)
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


def goal_total(c):
    if c['board'].get('goal') == 'discover_all':
        return len(c['chain'])
    return c['board']['cols'] * (c['board']['total_rows'] - 1)


def progress(c, s):
    if c['board'].get('goal') == 'discover_all':
        return sum(i['id'] in s['discovered'] for i in c['chain'])
    return goal_total(c) - sum(1 for x in s['cells'] if x['lock'])


def complete(c, s):
    return progress(c, s) >= goal_total(c)


def milestones(c):
    """Progress milestones; the last one is the completion reward. Old configs with a bare `rewards` list get one."""
    return c.get('milestones') or [{'at': goal_total(c), 'rewards': c.get('rewards', [])}]


def got(c, s):
    if 'got' in s:
        return s['got']
    return list(range(len(milestones(c)))) if s.get('claimed') else []


def claimable(c, s):
    have, p = got(c, s), progress(c, s)
    return [k for k, m in enumerate(milestones(c)) if p >= min(m['at'], goal_total(c)) and k not in have]


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


def unlocked_tier(c, s):
    return max([k + 1 for k, row in enumerate(c['chain']) if row['id'] in s['discovered']] or [0])


def advance_target(c, s):
    tier = unlocked_tier(c, s)
    rows = sum(max(0, stage['rows']) for stage in c['board'].get('advance_by_tier', []) if tier >= stage['tier'])
    return max(0, c['board']['total_rows'] - c['board']['visible_rows'] - rows)


def advance(c, s):
    cols, rows = c['board']['cols'], c['board']['visible_rows']
    cells = s['cells']
    target = advance_target(c, s)
    while s['view'] > target:
        view = s['view']
        shifted = False
        for step in range(min(view-target, c['board']['reveal_rows']), 0, -1):
            next_view = view-step
            next_end = (next_view+rows)*cols
            retiring = list(range(next_end, (view+rows)*cols))
            if any(cells[k]['lock'] for k in retiring):
                continue
            outgoing = [k for k in retiring if cells[k]['id']]
            slots = [k for k in range(next_view*cols, next_end) if not cells[k]['lock'] and not cells[k]['id']][::-1]
            # Keep room to place and merge a fresh pair after advancing.
            if len(outgoing) + 2 > len(slots):
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
        advance(c, s)
        return {'kind':'spawn', 'to':to, 'id':iid, 'advance_rows':view-s['view']}
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
        out = dict(kind=kind, **{'from':a}, to=b, id=iid, under=under, unlocked=locked, revealed=revealed, advance_rows=view-s['view'])
        if kind == 'merge':
            import random
            drop = econ.gd.resource_drop('event', random.SystemRandom().random(), int(st.get('level', 1)))
            if drop:
                econ.give_item(st, drop, out)
                out['drops'] = [drop]
        return out
    if req.action == 'recycle':
        i = req.cell
        if not lo <= i < hi or cells[i]['lock'] or not cells[i]['id']:
            raise Reject('invalid_cell', '请选择未锁定物品')
        cells[i]['id'] = ''
        advance(c, s)
        return {'kind':'recycle', 'advance_rows':view-s['view']}
    if req.action == 'claim':
        ready = claimable(c, s)
        if not ready:
            raise Reject('already_claimed' if s['claimed'] else 'not_completed', '继续解锁遗迹，到达下一个宝箱即可领取')
        s['got'] = got(c, s) + ready
        if len(milestones(c)) - 1 in s['got']:
            s['claimed'] = True
        rewards = [list(r) for k in ready for r in milestones(c)[k]['rewards']]
        out = {'kind': 'claim', 'milestones': ready, 'rewards': rewards}
        econ.grant(st, rewards, out)
        return out
    raise Reject('invalid_action','未知操作',400)
