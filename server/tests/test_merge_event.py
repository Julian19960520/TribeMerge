import copy
from conftest import ev


def mutate(player, fn):
    from app import db
    from app.models import Account
    from app.services import economy
    with db._SessionLocal() as session:
        account = session.get(Account, player.id)
        st = copy.deepcopy(account.state or economy().new_state())
        result = fn(st)
        account.state = st
        session.commit()
        return result


def config():
    from app import merge_event, clock
    from app.services import gamedata
    return merge_event.current(gamedata().merge_events, clock.now())


def test_order_points_gate_and_idempotence(player):
    c = config()
    mutate(player, lambda st: st.update(level=9))
    order = ev('order', order={'who':2,'items':['fruit_6'],'rw':{'shell':1},'story':False})
    r = player.post('/v1/events', {'events':[order]}).json()
    assert r['events'][0]['ok'] and not r['state']['merge_events']
    mutate(player, lambda st: st.update(level=10))
    order = ev('order', order={'who':2,'items':['fruit_6'],'rw':{'shell':1},'story':False})
    r = player.post('/v1/events', {'events':[order]}).json()
    assert r['events'][0]['ok'] and r['state']['merge_events'][c['key']]['points'] == 2
    r = player.post('/v1/events', {'events':[order]}).json()
    assert r['state']['merge_events'][c['key']]['points'] == 2


def test_board_actions_and_claim(player):
    from app import merge_event
    c = config()
    mutate(player, lambda st: st.update(level=10))
    path = '/v1/merge-event/action'
    base = {'season':c['key'], 'view':9}
    assert player.post(path, dict(base, action='spawn')).json()['error'] == 'not_enough_points'
    mutate(player, lambda st: merge_event.state(st,c).update(points=3,earned=3))
    r = player.post(path, dict(base, action='spawn'), key='spawn-once')
    assert r.status_code == 200
    from_cell = r.json()['give']['to']
    assert r.json()['state']['merge_events'][c['key']]['points'] == 2
    assert player.post(path, dict(base, action='spawn'), key='spawn-once').json() == r.json()
    assert player.post(path, dict(base, action='drop', **{'from':from_cell,'to':0})).status_code == 409
    assert player.post(path, dict(base, action='drop', **{'from':from_cell,'to':84})).json()['error'] == 'covered'
    assert player.post(path, dict(base, action='drop', **{'from':from_cell,'to':90})).status_code == 200
    second = player.post(path, dict(base, action='spawn')).json()['give']['to']
    r = player.post(path, dict(base, action='drop', **{'from':second,'to':90}))
    cells = r.json()['state']['merge_events'][c['key']]['cells']
    assert cells[84]['lock'] == 1 and cells[78]['lock'] == 2
    assert r.json()['give']['revealed'] == [84]
    assert player.post(path, dict(base, action='drop', **{'from':90,'to':84})).json()['error'] == 'not_matching'
    third = player.post(path, dict(base, action='spawn')).json()['give']['to']
    r = player.post(path, dict(base, action='drop', **{'from':third,'to':84}))
    assert r.status_code == 200 and r.json()['give']['kind'] == 'merge'
    cells = r.json()['state']['merge_events'][c['key']]['cells']
    assert cells[84] == {'id':'moon_2','lock':0} and cells[78]['lock'] == 1
    assert player.post(path, dict(base, action='claim')).status_code == 409
    def finish(st):
        for cell in merge_event.state(st,c)['cells']: cell['lock'] = 0
    mutate(player,finish)
    r = player.post(path, dict(base, action='claim'), key='reward-once')
    assert r.status_code == 200 and r.json()['give']['items'] == ['choice_1']
    assert r.json()['state']['amber'] == 110
    assert player.post(path, dict(base, action='claim'), key='reward-once').json() == r.json()
    assert player.post(path, dict(base, action='claim')).status_code == 409
    assert player.post(path, dict(base, action='spawn')).status_code == 409


def test_period_isolation_and_frontier(player):
    from app import merge_event
    c = config()
    s = merge_event.fresh(c)
    assert len(s['cells']) == 96 and sum(x['lock'] == 2 for x in s['cells']) == 90
    future = merge_event.current({'seasons':[c]}, c['ends_at']+1)
    assert future['key'] != c['key']
    mutate(player, lambda st: st.update(level=10, merge_events={c['key']:s}))
    assert player.post('/v1/merge-event/action', {'season':future['key'],'action':'spawn','view':9}).json()['error'] == 'event_ended'
    # Unrevealed rows cannot be accessed via a forged viewport.
    assert player.post('/v1/merge-event/action', {'season':c['key'],'action':'drop','view':0,'from':90,'to':0}).status_code == 409


def test_choice_chest_one_choice_only(player):
    from app.services import economy
    assert player.put(player.snapshot(board=[{'id':'choice_1','lock':0}])).status_code == 200
    assert player.post('/v1/chest/choose', {'box':'choice_1','option':1}).json()['error'] == 'no_chest'
    mutate(player, lambda st: economy().give_item(st, 'choice_1', {}))
    r = player.post('/v1/chest/choose', {'box':'choice_1','option':1}, key='choose-once')
    assert r.status_code == 200 and r.json()['give']['items'] == ['shell_4']
    assert player.post('/v1/chest/choose', {'box':'choice_1','option':1}, key='choose-once').json() == r.json()
    assert player.post('/v1/chest/choose', {'box':'choice_1','option':0}).json()['error'] == 'no_chest'
    assert player.post('/v1/chest/choose', {'box':'choice_1','option':3}).status_code == 422


def test_default_banana_level_and_reward_order(player):
    from app import race
    c = race.cfg()
    assert c['unlock_level'] == 12 and c['podium'] == 3 and len(c['rewards']) == 3
    amounts = [dict(rewards) for rewards in c['rewards']]
    assert amounts[0]['amber_3'] > amounts[1]['amber_3'] > amounts[2]['amber_3']
    assert amounts[0]['fire_1'] > amounts[1]['fire_1'] > amounts[2]['fire_1']
    mutate(player, lambda st: st.update(level=11))
    assert player.post('/v1/race/join').json()['error'] == 'race_locked'
    mutate(player, lambda st: st.update(level=12))
    assert player.post('/v1/race/join').status_code == 200


def test_full_board_and_snapshot_cannot_create_points(player):
    from app import merge_event
    c = config()
    mutate(player, lambda st: st.update(level=10))
    forged = merge_event.fresh(c)
    forged['points'] = 999
    player.put(player.snapshot(merge_events={c['key']:forged}))
    r = player.post('/v1/merge-event/action', {'season':c['key'],'action':'spawn','view':9})
    assert r.json()['error'] == 'not_enough_points'
    def fill(st):
        s = merge_event.state(st,c)
        s['points'] = 2
        for tile in s['cells']:
            if not tile['lock']: tile['id'] = 'moon_1'
    mutate(player,fill)
    assert player.post('/v1/merge-event/action', {'season':c['key'],'action':'spawn','view':9}).json()['error'] == 'board_full'
    assert player.get('/v1/save').json()['state']['merge_events'][c['key']]['points'] == 2


def test_expired_period_can_claim_completed_reward_only(player, monkeypatch):
    from app import merge_event, clock
    c = config()
    def finish(st):
        st['level'] = 10
        s = merge_event.state(st,c)
        s['points'] = 5
        for tile in s['cells']: tile['lock'] = 0
    mutate(player,finish)
    monkeypatch.setattr(clock, 'now', lambda: c['ends_at'] + 1)
    base = {'season':c['key'], 'view':9}
    assert player.post('/v1/merge-event/action', dict(base,action='spawn')).json()['error'] == 'event_ended'
    assert player.post('/v1/merge-event/action', dict(base,action='claim')).status_code == 200
    assert player.post('/v1/merge-event/action', dict(base,action='claim')).status_code == 409


def test_auto_scroll_preserves_items_and_unfinished_cells(player):
    from app import merge_event
    from collections import Counter
    c = config()
    s = merge_event.fresh(c)
    for k in range(54,96):
        s['cells'][k] = {'id':'', 'lock':0}
    s['cells'][95]['id'] = 'moon_4'
    s['cells'][80]['id'] = 'moon_3'
    before = Counter(x['id'] for x in s['cells'] if x['id'])
    merge_event.advance(c,s)
    assert s['view'] == s['min_view'] == 6
    assert before == Counter(x['id'] for x in s['cells'] if x['id'])
    assert all(not x['id'] for x in s['cells'][78:])
    assert {'moon_3','moon_4'} <= {x['id'] for x in s['cells'][36:78]}
    # A covered outgoing cell must remain reachable; only shift the safe bottom row.
    s = merge_event.fresh(c)
    for k in range(54,60): s['cells'][k] = {'id':'','lock':0}
    merge_event.advance(c,s)
    assert s['view'] == 8 and s['cells'][84]['lock'] == 2


def test_three_state_migration_and_no_repeated_reveal(player):
    from app import merge_event
    c = config()
    s = merge_event.fresh(c)
    s.pop('rules_version')
    s['points'] = 17
    for tile in s['cells']:
        if tile['lock']: tile['lock'] = 1
    st = {'merge_events':{c['key']:s}}
    s = merge_event.state(st,c)
    assert s['points'] == 17 and s['cells'][84]['lock'] == 1 and s['cells'][78]['lock'] == 2
    assert merge_event.reveal_neighbors(s['cells'],90,6) == []
    assert s['cells'][84]['lock'] == 1
    assert merge_event.reveal_neighbors(s['cells'],84,6) == [78]
    assert s['cells'][78]['lock'] == 1 and s['cells'][72]['lock'] == 2
