"""Shared reducer determinism: commands, random streams and illegal input."""
from godot_rules import GODOT, new_game, op, requires_godot, run_worker, worker

pytestmark = requires_godot


def test_fossil_refresh_commits_and_invalid_dig_is_rejected():
    d = new_game()
    at = d['replay_meta']['at']
    refreshed = worker(dict(mode='replay', data=d, ops=[op(1, at, 'fossil', action='refresh')]))
    snapshot = refreshed['data']
    assert snapshot['fossil_dig']['board']['n'] == 3 and snapshot['fossil_dig']['shovels'] == 0
    assert not run_worker(dict(mode='replay', data=snapshot, ops=[op(2, at, 'fossil', action='dig', value=0)]))['ok']


def test_illegal_commands_are_rejected():
    d = new_game()
    at = d['replay_meta']['at']
    for name, args in [('tap', {'cell': 99999}), ('pack', {}), ('order', {'cell': 0}), ('daily', {'key': 'deal_ad'})]:
        assert not run_worker(dict(mode='replay', data=d, ops=[op(1, at, name, **args)]))['ok'], name


def test_sequence_gaps_and_backwards_time_are_rejected():
    d = new_game()
    at = d['replay_meta']['at']
    for seq, t in [(2, at), (1, at - 1)]:
        assert not run_worker(dict(mode='replay', data=d, ops=[op(seq, t, 'drop', **{'from': 28, 'to': 29})]))['ok']


def test_stream_isolation_consumption_and_reload():
    d=new_game()
    d.update(level=10,tutorial_on=False,orders=[],amber=500)
    d['board']=[{'id':'','lock':0} for _ in range(63)]
    d['board'][0]={'id':'emberpot_1','lock':0}
    d['board'][1]={'id':'basket_5','lock':0}
    d['stash']=['pack_1','pack_1','chest_1']
    at=d['replay_meta']['at']
    cards=worker(dict(mode='replay',data=d,ops=[op(1,at,'pack')]))
    ops=[op(1,at,'tap',cell=0),op(2,at,'tap',cell=1),op(3,at,'stash',index=2)]
    placed=worker(dict(mode='replay',data=d,ops=ops))
    chest_cell=next(i for i,c in enumerate(placed['data']['board']) if c['id']=='chest_1' and c['lock']==0)
    ops += [op(4,at,'tap',cell=chest_cell),op(5,at,'pack')]
    mixed=worker(dict(mode='replay',data=d,ops=ops))
    assert cards['data']['cards']==mixed['data']['cards']
    streams=mixed['data']['replay_rng']['streams']
    assert streams['cards']==cards['data']['replay_rng']['streams']['cards']
    assert {'energy_produce','produce:basket_5','chests'}<=streams.keys()
    assert mixed['data']['stash'].count('pack_1')==1
    last=op(6,at,'pack')
    split=worker(dict(mode='replay',data=mixed['data'],ops=[last]))
    whole=worker(dict(mode='replay',data=d,ops=ops+[last]))
    assert split['hash']==whole['hash']
    assert split['data']['stash'].count('pack_1')==0

def test_spends_and_duplicate_claims():
    d=new_game()
    d.update(level=10,tutorial_on=False,orders=[],amber=80,shells=1000)
    at=d['replay_meta']['at']
    r=worker(dict(mode='replay',data=d,ops=[op(1,at,'energy'),op(2,at,'level',level=2)]))
    assert r['data']['amber']==65 and r['data']['energy']>=200
    assert not run_worker(dict(mode='replay',data=r['data'],ops=[op(3,at,'level',level=2)]))['ok']


def test_real_interface_operations_replay_to_the_same_state(tmp_path):
    import json
    import subprocess
    from app.config import REPO_DIR
    d = new_game()
    d.update(level=10, tutorial_on=False, seen_tutorial=True, orders=[])
    d['board'] = [{'id': '', 'lock': 0} for _ in range(63)]
    for i, iid in [(0, 'emberpot_1'), (1, 'basket_5'), (10, 'fire_2'), (11, 'chest_1'), (12, 'pack_1')]:
        d['board'][i]['id'] = iid
    src, dst = tmp_path / 'ui-input.json', tmp_path / 'ui-output.json'
    src.write_text(json.dumps(d), encoding='utf-8')
    p = subprocess.run([GODOT, '--headless', '--path', str(REPO_DIR), '--script', 'res://tools/check_replay_ui.gd', '--',
                        '--replay-test', '--cloud-off', f'--save={tmp_path / "save.json"}', f'--input={src}', f'--output={dst}'],
                       timeout=30, capture_output=True, text=True)
    assert p.returncode == 0 and 'SCRIPT ERROR' not in p.stdout + p.stderr, p.stdout + p.stderr
    local = json.loads(dst.read_text(encoding='utf-8'))
    assert [x['name'] for x in local['ops']] == ['tap', 'tap', 'tap', 'tap', 'pack', 'discard', 'discard_finish']
    replayed = worker(dict(mode='replay', data=d, ops=local['ops']))
    assert local['hash'] == replayed['hash']


def test_completed_album_bonus_waits_for_a_manual_claim_and_is_paid_once():
    d = new_game()
    d.update(level=10, tutorial_on=False, orders=[], cards={}, stash=['pack_1', 'pack_1'])
    at = d['replay_meta']['at']
    sample = worker(dict(mode='replay', data=d, ops=[op(1, at, 'pack')]))
    album, missing = next(iter(sample['data']['cards'])).split('_')
    d['cards'] = {f'{album}_{i}': 1 for i in range(9) if str(i) != missing}
    first = worker(dict(mode='replay', data=d, ops=[op(1, at, 'pack')]))
    assert first['data']['amber'] == d['amber']
    assert first['data']['stash'].count('chest_1') == 0
    assert not first['data']['replay_meta'].get(f'album:{album}')
    second = worker(dict(mode='replay', data=first['data'], ops=[op(2, at, 'pack')]))
    assert second['data']['amber'] == first['data']['amber']
    assert second['data']['stash'].count('chest_1') == 0
    claimed = worker(dict(mode='replay', data=second['data'], ops=[op(3, at, 'album_claim', album=int(album))]))
    assert claimed['data']['amber'] == d['amber'] + 30
    assert claimed['data']['stash'].count('chest_1') == 2
    assert not run_worker(dict(mode='replay', data=claimed['data'], ops=[op(4, at, 'album_claim', album=int(album))]))['ok']
