"""Real shared reducer and HTTP replay trust-boundary regression tests."""
import os
import uuid
import pytest
GODOT = os.environ.get('TRIBE_REPLAY_GODOT')
pytestmark = pytest.mark.skipif(not GODOT, reason='set TRIBE_REPLAY_GODOT to Godot 4.6.3')

def worker(payload):
    from app.api_replay import run_worker
    r = run_worker(payload)
    assert r['ok'], r
    return r

def begin(player, monkeypatch):
    from app.config import get_settings
    from app.services import unpack
    monkeypatch.setattr(get_settings(), 'replay_godot', GODOT)
    r = player.post('/v2/session').json()
    assert r['ok'], r
    return r, unpack(r['data'])[1]

def body(s, expected, ops):
    return dict(base=s['version'], rules=s['rules'], hash=expected['hash'], ops=ops, batch=uuid.uuid4().hex)

def op(seq, at, name, **args): return dict(seq=seq, at=at, name=name, args=args)

def test_commit_retry_login_and_legacy_bypass(player, monkeypatch):
    s, d = begin(player, monkeypatch)
    ops = [op(1,d['replay_meta']['at'],'drop',**{'from':28,'to':29})]
    expected = worker(dict(mode='replay', data=d, ops=ops))
    req = body(s,expected,ops)
    r = player.post('/v2/sync',req).json()
    assert not r['reset'] and r['hash']==expected['hash'] and r['seq']==1
    assert player.post('/v2/sync',req).json()==r
    again=player.post('/v2/session').json()
    assert again['version']==r['version'] and again['hash']==r['hash']
    from app.services import unpack
    assert unpack(again['data'])[1]['replay_rng']['seed']==d['replay_rng']['seed']
    assert player.post('/v1/energy/buy').json()['error']=='replay_only'
    assert player.put(player.snapshot(amber=999999)).json()['error']=='replay_only'

def test_hash_mismatch_illegal_ops_and_forged_snapshot(player, monkeypatch):
    s,d=begin(player,monkeypatch)
    at=d['replay_meta']['at']
    for name,args in [('drop',{'from':28,'to':29}),('tap',{'cell':99999}),('pack',{}),('order',{'cell':0}),('daily',{'key':'deal_ad'})]:
        req=body(s,{'hash':'0'*64},[op(1,at,name,**args)])
        r=player.post('/v2/sync',req).json()
        assert r['reset'] and r['hash']==s['hash'] and r['version']==s['version'],r
    assert player.post('/v2/sync',{**req,'data':'client snapshot'}).status_code==422

def test_sequence_future_and_backwards_time(player,monkeypatch):
    s,d=begin(player,monkeypatch)
    at=d['replay_meta']['at']
    for seq,t in [(2,at),(1,at+3600),(1,at-1)]:
        req=body(s,{'hash':'0'*64},[op(seq,t,'drop',**{'from':28,'to':29})])
        assert player.post('/v2/sync',req).json()['reset']

def test_stream_isolation_consumption_and_reload(player,monkeypatch):
    _,d=begin(player,monkeypatch)
    d.update(level=10,tutorial_on=False,orders=[],amber=500)
    d['board']=[{'id':'','lock':0} for _ in range(63)]
    d['board'][0]={'id':'emberpot_1','lock':0}
    d['board'][1]={'id':'basket_5','lock':0}
    d['stash']=['pack_1','pack_1','chest_1']
    at=d['replay_meta']['at']
    cards=worker(dict(mode='replay',data=d,ops=[op(1,at,'pack')]))
    ops=[op(1,at,'tap',cell=0),op(2,at,'tap',cell=1),op(3,at,'stash',index=2),op(4,at,'pack')]
    mixed=worker(dict(mode='replay',data=d,ops=ops))
    assert cards['data']['cards']==mixed['data']['cards']
    streams=mixed['data']['replay_rng']['streams']
    assert streams['cards']==cards['data']['replay_rng']['streams']['cards']
    assert {'energy_produce','produce:basket_5','chests'}<=streams.keys()
    assert mixed['data']['stash'].count('pack_1')==1
    last=op(5,at,'pack')
    split=worker(dict(mode='replay',data=mixed['data'],ops=[last]))
    whole=worker(dict(mode='replay',data=d,ops=ops+[last]))
    assert split['hash']==whole['hash']
    assert split['data']['stash'].count('pack_1')==0

def test_spends_and_duplicate_claims(player,monkeypatch):
    _,d=begin(player,monkeypatch)
    d.update(level=10,tutorial_on=False,orders=[],amber=80,shells=1000)
    at=d['replay_meta']['at']
    r=worker(dict(mode='replay',data=d,ops=[op(1,at,'energy'),op(2,at,'level',level=2)]))
    assert r['data']['amber']==65 and r['data']['energy']>=200
    from app.api_replay import run_worker
    assert not run_worker(dict(mode='replay',data=r['data'],ops=[op(3,at,'level',level=2)]))['ok']


def test_real_interface_operations_match_server_replay(player, monkeypatch, tmp_path):
    import json
    import subprocess
    from app.config import REPO_DIR
    _, d = begin(player, monkeypatch)
    d.update(level=10, tutorial_on=False, seen_tutorial=True, orders=[])
    d['board'] = [{'id': '', 'lock': 0} for _ in range(63)]
    for i, iid in [(0, 'emberpot_1'), (1, 'basket_5'), (10, 'fire_2'), (11, 'chest_1'), (12, 'pack_1')]:
        d['board'][i]['id'] = iid
    src, dst = tmp_path / 'ui-input.json', tmp_path / 'ui-output.json'
    src.write_text(json.dumps(d))
    p = subprocess.run([GODOT, '--headless', '--path', str(REPO_DIR), '--script', 'res://tools/check_replay_ui.gd', '--',
                        '--replay-test', '--cloud-off', f'--save={tmp_path / "save.json"}', f'--input={src}', f'--output={dst}'],
                       timeout=30, capture_output=True, text=True)
    assert p.returncode == 0 and 'SCRIPT ERROR' not in p.stdout + p.stderr, p.stdout + p.stderr
    local = json.loads(dst.read_text())
    assert [x['name'] for x in local['ops']] == ['tap', 'tap', 'tap', 'tap', 'pack', 'discard', 'discard_finish']
    replayed = worker(dict(mode='replay', data=d, ops=local['ops']))
    assert local['hash'] == replayed['hash']


def test_completed_album_bonus_is_paid_once(player, monkeypatch):
    _, d = begin(player, monkeypatch)
    d.update(level=10, tutorial_on=False, orders=[], cards={}, stash=['pack_1', 'pack_1'])
    at = d['replay_meta']['at']
    sample = worker(dict(mode='replay', data=d, ops=[op(1, at, 'pack')]))
    album, missing = next(iter(sample['data']['cards'])).split('_')
    d['cards'] = {f'{album}_{i}': 1 for i in range(9) if str(i) != missing}
    first = worker(dict(mode='replay', data=d, ops=[op(1, at, 'pack')]))
    assert first['data']['amber'] == d['amber'] + 30
    assert first['data']['stash'].count('chest_1') == 2
    second = worker(dict(mode='replay', data=first['data'], ops=[op(2, at, 'pack')]))
    assert second['data']['amber'] == first['data']['amber']
    assert second['data']['stash'].count('chest_1') == 2
