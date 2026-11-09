import copy
import random
from pathlib import Path
from types import SimpleNamespace

import pytest

from app import tiger_escape as tiger
from app.economy import Economy, Reject
from app.gamedata import GameData
from conftest import ev
from test_merge_event import mutate


def rules():
    clock = [1000.0]
    gd = GameData(str(Path(__file__).resolve().parents[2] / 'data'))
    gd.tiger_escape = dict(unlock_level=6, attack_interval_sec=10, points_per_order=1,
                           stages=[{'points': 2, 'rewards': [['fire_2', 5]]},
                                   {'points': 3, 'rewards': [['amber_2', 7]]}])
    econ = Economy(gd, {}, lambda: '2026-11-09', rng=random.Random(5), now_fn=lambda: clock[0])
    st = econ.new_state()
    st['level'] = 6
    return econ, st, clock


def act(e, st, action, node=0):
    return tiger.action(e, st, SimpleNamespace(action=action, node=node))


def test_advances_only_after_target_and_claims_once():
    e, st, clock = rules()
    act(e, st, 'join')
    with pytest.raises(Reject): act(e, st, 'join')
    with pytest.raises(Reject): act(e, st, 'claim', 1)
    tiger.on_order(e, st, {})
    m = tiger.state(st)['round']
    assert (m['stage'], m['points']) == (0, 1)
    tiger.on_order(e, st, {})
    assert (m['stage'], m['points']) == (1, 0)
    assert act(e, st, 'claim', 1)['rewards'] == [['fire_2', 5]]
    with pytest.raises(Reject): act(e, st, 'claim', 1)
    with pytest.raises(Reject): act(e, st, 'restart')
    clock[0] += 10
    tiger.tick(e, st)
    assert m['destroyed'] == 0 and m['status'] == 'running'
    for _ in range(3): tiger.on_order(e, st, {})
    assert m['status'] == 'won' and m['stage'] == 2
    clock[0] += 100
    tiger.tick(e, st)
    assert m['status'] == 'won'
    balance = st['amber']
    assert act(e, st, 'restart')['rewards'] == [['amber_2', 7]]
    assert st['amber'] == balance + 7 and tiger.state(st)['round']['stage'] == 0
    assert tiger.state(st)['rounds'] == 2


def test_expiry_wins_ties_and_offline_catches_up():
    e, st, clock = rules()
    act(e, st, 'join')
    tiger.on_order(e, st, {})
    clock[0] += 10
    tiger.on_order(e, st, {})
    m = tiger.state(st)['round']
    assert m['status'] == 'lost' and m['stage'] == 0 and m['points'] == 1
    act(e, st, 'restart')
    tiger.on_order(e, st, {})
    tiger.on_order(e, st, {})
    clock[0] += 1000
    tiger.tick(e, st)
    m = tiger.state(st)['round']
    assert m['status'] == 'lost' and m['destroyed'] == 1 and m['finished_at'] == 1030
    assert act(e, st, 'claim', 1)['rewards'] == [['fire_2', 5]]
    assert act(e, st, 'restart')['rewards'] == []
    assert tiger.state(st)['round']['start'] == clock[0]


def test_rules_snapshot_overflow_and_no_uploaded_progress():
    e, st, clock = rules()
    st['level'] = 5
    with pytest.raises(Reject): act(e, st, 'join')
    st['level'] = 6
    e.gd.tiger_escape['points_per_order'] = 6
    act(e, st, 'join')
    e.gd.tiger_escape['stages'][0]['points'] = 99
    tiger.on_order(e, st, {})
    assert tiger.state(st)['round']['status'] == 'won'
    fresh = e.new_state()
    e.adopt(fresh, {'board': [], 'tiger_escape': copy.deepcopy(tiger.state(st))})
    assert not fresh.get('tiger_escape', {}).get('round')


def test_api_order_events_idempotency_persistence_and_restart(player):
    path = '/v1/tiger/action'
    assert player.post(path, {'action': 'join'}).json()['error'] == 'locked'
    mutate(player, lambda st: st.update(level=6))
    joined = player.post(path, {'action': 'join'}, key='tiger-start')
    assert joined.status_code == 200
    assert player.post(path, {'action': 'join'}, key='tiger-start').json() == joined.json()
    assert player.post(path, {'action': 'claim', 'node': 10}).status_code == 409
    assert player.post(path, {'action': 'score', 'points': 99999}).status_code == 422
    merge = player.post('/v1/events', {'events': [ev('merge', item='fruit_2', cell=-1)]}).json()
    assert merge['state']['tiger_escape']['round']['points'] == 0
    order = {'who': 2, 'items': ['fruit_2'], 'rw': {'shell': 1}, 'story': False}
    events = [ev('order', order=order) for _ in range(3)]
    response = player.post('/v1/events', {'events': events}).json()
    assert response['state']['tiger_escape']['round']['stage'] == 1
    duplicate = player.post('/v1/events', {'events': events}).json()
    assert duplicate['state']['tiger_escape']['round']['stage'] == 1
    assert player.get('/v1/save').json()['state']['tiger_escape']['round']['stage'] == 1
    from app import clock
    clock.offset += 10800 * 2
    expired = player.post(path, {'action': 'refresh'}).json()['state']['tiger_escape']['round']
    assert expired['status'] == 'lost' and expired['stage'] == 1
    result = player.post(path, {'action': 'restart'}, key='tiger-restart')
    assert result.json()['give']['rewards'] == [['fire_2', 15]]
    assert player.post(path, {'action': 'restart'}, key='tiger-restart').json() == result.json()
    assert player.get('/v1/save').json()['state']['tiger_escape']['rounds'] == 2


def test_bots_advance_and_lose_on_deadlines_even_after_long_absence():
    e, st, clock = rules()
    act(e, st, 'join')
    m = tiger.state(st)['round']
    assert len(m['bots']) == 15
    same = tiger.create_bots(e.gd.tiger_escape, m)
    assert same == m['bots']
    # Two runners who will finish, fail at the first node, and fail at the second.
    m['bots'] = [dict(name='fast', avatar=0, arrivals=[5, 15], stage=0, status='running'),
                 dict(name='slow', avatar=1, arrivals=[10, 15], stage=0, status='running'),
                 dict(name='late', avatar=2, arrivals=[5, 21], stage=0, status='running')]
    m['stage'] = 2
    m['status'] = 'won'
    m['finished_at'] = 1030
    clock[0] = 1100
    tiger.tick(e, st)
    assert [(b['stage'], b['status']) for b in m['bots']] == [(2, 'won'), (0, 'lost'), (1, 'lost')]
    again = copy.deepcopy(m['bots'])
    tiger.tick(e, st)
    assert m['bots'] == again


def test_legacy_running_round_keeps_earned_nodes_and_gets_hourly_order_rules():
    e, st, clock = rules()
    e.gd.tiger_escape['attack_interval_sec'] = 10800
    act(e, st, 'join')
    m = tiger.state(st)['round']
    m.pop('rule_version')
    m.update(stage=1, points=9, interval=180, claimed=[1], destroyed=0)
    tiger.tick(e, st)
    assert m['stage'] == 1 and m['claimed'] == [1] and m['points'] == 0
    assert m['interval'] == 10800 and m['status'] == 'running' and m['destroyed'] == -1
    assert len(m['bots']) == 15
