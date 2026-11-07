"""Authoritative practice duel. Client cannot submit scores, wins, or claimed milestones."""
from .economy import Reject


def state(st):
    return st.setdefault('duel_race', {'wins': 0, 'rounds': 0, 'claimed': [], 'match': {}})


def finish(st, won, at):
    s = state(st)
    m = s['match']
    if not m or m['status'] != 'running': return
    m.update(status='won' if won else 'lost', finished_at=at)
    if won: s['wins'] += 1


def tick(e, st):
    m = state(st)['match']
    if not m or m['status'] != 'running': return
    elapsed = e.now() - m['start']
    for at, score in m['opponent_curve']:
        if elapsed < at: break
        m['opponent'] = score
        if score >= m['target']:
            finish(st, False, m['start'] + at)
            break


def order_points(e, order):
    config = e.gd.duel_race
    score = max([e.gd.lv(str(i)) for i in order.get('items', [])] or [1]) + max(0, len(order.get('items', [])) - 1)
    tier = sum(score >= t for t in config['order_thresholds'])
    return config['order_points'][min(tier, len(config['order_points']) - 1)]


def on_order(e, st, order):
    tick(e, st)
    m = state(st)['match']
    if not m or m['status'] != 'running': return
    m['me'] = min(m['target'], m['me'] + order_points(e, order))
    if m['me'] >= m['target']: finish(st, True, e.now())


def action(e, st, req):
    cfg = e.gd.duel_race
    if not st.get('gm_activities') and st.get('level', 1) < cfg['unlock_level']:
        raise Reject('locked', f"{cfg['unlock_level']}级解锁双人竞速")
    tick(e, st)
    s = state(st)
    m = s['match']
    if req.action == 'refresh': return {}
    if req.action == 'join':
        if m and (m['status'] == 'running' or not m.get('claimed')):
            raise Reject('match_pending', '请先完成比赛并领取奖励')
        target = cfg['target']
        duration = e.rng.uniform(*cfg['opponent_seconds'])
        curve = [[duration * (score - e.rng.uniform(0, .4)) / target, score] for score in range(1, target + 1)]
        s['rounds'] += 1
        s['match'] = dict(id=s['rounds'], start=e.now(), target=target, me=0, opponent=0, status='running', claimed=False, opponent_curve=curve)
        return {}
    if req.action == 'claim':
        if not m or m['status'] == 'running' or m.get('claimed'):
            raise Reject('already_claimed', '没有可领取的比赛奖励')
        m['claimed'] = True
        rw = cfg['win_rewards'] if m['status'] == 'won' else cfg['lose_rewards']
    else:
        entry = next((x for x in cfg['milestones'] if x['wins'] == req.milestone), None)
        if not entry or s['wins'] < req.milestone or str(req.milestone) in s['claimed']:
            raise Reject('not_ready', '尚未达成或已领取')
        s['claimed'].append(str(req.milestone))
        rw = entry['rewards']
    return e.grant(st, rw, {'rewards': rw})
