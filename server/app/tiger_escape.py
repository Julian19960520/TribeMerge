"""Timed elimination: only accepted main-board merge events advance the runner."""
import copy

from .economy import Reject


def state(st):
    return st.setdefault('tiger_escape', {'rounds': 0, 'round': {}})


def tick(e, st):
    m = state(st)['round']
    if not m or m['status'] != 'running':
        return
    destroyed = min(len(m['stages']) - 1, int(max(0, e.now() - m['start']) // m['interval']) - 1)
    m['destroyed'] = max(m['destroyed'], min(destroyed, m['stage']))
    if destroyed >= m['stage']:
        m.update(status='lost', finished_at=m['start'] + (m['stage'] + 1) * m['interval'])


def on_merge(e, st):
    tick(e, st)  # Expiry wins ties, including delayed/offline merge events.
    m = state(st)['round']
    if not m or m['status'] != 'running':
        return
    m['points'] += m['points_per_merge']
    while m['stage'] < len(m['stages']) and m['points'] >= m['stages'][m['stage']]['points']:
        m['points'] -= m['stages'][m['stage']]['points']
        m['stage'] += 1
    if m['stage'] == len(m['stages']):
        m.update(status='won', points=0, finished_at=e.now())


def pending_rewards(m):
    return [list(r) for n, row in enumerate(m.get('stages', [])[:m.get('stage', 0)], 1)
            if n not in m['claimed'] for r in row['rewards']]


def action(e, st, req):
    cfg = e.gd.tiger_escape
    if not st.get('gm_activities') and st.get('level', 1) < cfg['unlock_level']:
        raise Reject('locked', f"{cfg['unlock_level']}级解锁逃离剑齿虎")
    tick(e, st)
    s = state(st)
    m = s['round']
    if req.action == 'refresh':
        return {}
    if req.action in ('join', 'restart'):
        if m and m['status'] == 'running':
            raise Reject('round_running', '这局逃生还没结束')
        if req.action == 'join' and m:
            raise Reject('round_pending', '请结算后再出发')
        if req.action == 'restart' and not m:
            raise Reject('no_round', '请先开始逃生')
        rewards = pending_rewards(m) if m else []
        stages = copy.deepcopy(cfg['stages'])
        if not stages or any(row['points'] <= 0 for row in stages) or cfg['attack_interval_sec'] <= 0:
            raise Reject('bad_config', '活动配置有误')
        s['rounds'] += 1
        s['round'] = dict(id=s['rounds'], start=e.now(), stage=0, points=0, destroyed=-1,
                          status='running', claimed=[], stages=stages,
                          interval=cfg['attack_interval_sec'], points_per_merge=max(1, int(cfg['points_per_merge'])))
        return e.grant(st, rewards, {'rewards': rewards})
    if req.action == 'claim':
        n = req.node
        if not m or n < 1 or n > m['stage'] or n in m['claimed']:
            raise Reject('not_ready', '礼包尚未到达或已领取')
        m['claimed'].append(n)
        rewards = m['stages'][n - 1]['rewards']
        return e.grant(st, rewards, {'rewards': rewards})
    raise Reject('invalid_action', '未知操作', 400)
