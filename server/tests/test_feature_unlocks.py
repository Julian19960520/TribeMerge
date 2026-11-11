"""GM feature access uses the same trusted command gate as all gameplay."""
import copy
import json
import os

import pytest

from app.config import REPO_DIR, get_settings
from conftest import unpack
from test_reducer_domains import confirm, rejects
from test_replay import begin, body, op

pytestmark = pytest.mark.skipif(not os.environ.get('TRIBE_REPLAY_GODOT'), reason='Godot 4.6.3 required')


@pytest.fixture()
def level_one(player, monkeypatch):
    _, state = begin(player, monkeypatch)
    state.update(tutorial_on=False, seen_tutorial=True, orders=[], shells=1000000, stash=['pack_1'])
    state['board'] = [{'id':'','lock':0} for _ in range(63)]
    state['builds'] = {'fire':1}
    assert state['level'] == 1 and state['replay_meta']['allow_gm']
    return state


def last_build():
    return json.loads((REPO_DIR / 'data/builds.json').read_text(encoding='utf-8'))[-1]['id']


@pytest.mark.parametrize('name,arguments', [('pack',{}), ('offer',{'kind':'energy'}), ('build',None),
                                         ('gm',{'action':'card','album':0}), ('album_claim',{'album':0})])
def test_level_one_accounts_cannot_use_locked_features_without_gm(level_one, name, arguments):
    assert not level_one['gm_activities']
    rejects(level_one, name, {'id':last_build()} if arguments is None else arguments)


def test_authorized_gm_opens_card_build_and_offer_through_compressed_sync(player, level_one):
    identity, level, xp = level_one['player_id'], level_one['level'], level_one['xp']
    build = last_build()
    state = confirm(player, copy.deepcopy(level_one), [('gm',{}), ('pack',{}), ('build',{'id':build}),
                                                      ('offer',{'kind':'energy'})])
    assert state['gm_activities'] and state['boost_gm']
    assert sum(state['cards'].values()) == 2
    assert 'pack_1' not in state['stash']
    assert state['builds'][build] == 1
    assert state['offers']['energy']['end'] > state['offers']['energy']['start']
    assert (state['player_id'], state['level'], state['xp']) == (identity, level, xp)


def test_gm_access_command_preserves_identity_progress_and_assets(player, level_one):
    state = confirm(player, copy.deepcopy(level_one), [('gm',{})])
    for field in ['player_id','level','xp','energy','shells','amber','rush','cards','builds','board','inv','stash']:
        assert state[field] == level_one[field], field
    assert state['gm_activities'] and state['seen_tutorial'] and not state['tutorial_on']


@pytest.mark.parametrize('arguments', [{}, {'action':'card','album':0}])
def test_http_session_disallowing_gm_rejects_unlock_without_changing_account(player, monkeypatch, arguments):
    # The server, not a client argument, controls whether a new session can use GM.
    monkeypatch.setattr(get_settings(), 'env', 'prod')
    initial, state = begin(player, monkeypatch)
    assert not state['replay_meta']['allow_gm'] and not state['gm_activities']
    operation = op(1, state['replay_meta']['at'], 'gm')
    operation['args'] = arguments
    request = body(initial, {'hash':'0'*64}, [operation])
    response = player.post('/v2/sync', request)
    assert response.status_code == 200
    rejected = response.json()
    assert rejected['reset'] and rejected['seq'] == 0 and rejected['hash'] == initial['hash']
    assert rejected['version'] == initial['version']
    restored = unpack(rejected['data'])
    assert restored['player_id'] == state['player_id'] == player.id
    assert restored['level'] == state['level'] == 1
    assert not restored['replay_meta']['allow_gm'] and not restored['gm_activities']
    assert player.post('/v2/sync', request).json() == rejected
    assert player.post('/v2/session').json()['hash'] == initial['hash']


def test_random_album_cards_use_compressed_sync_and_persist(player, level_one):
    operations = [('gm', {})] + [('gm', {'action':'card','album':0}) for _ in range(10)]
    state = confirm(player, copy.deepcopy(level_one), operations)
    assert set(state['cards']) == {f'0_{index}' for index in range(9)}
    assert sum(state['cards'].values()) == 10
    assert not state['replay_meta'].get('album:0')
    assert state['amber'] == level_one['amber']
    assert state['stash'].count('chest_1') == level_one['stash'].count('chest_1')
    assert state['replay_rng']['streams'].get('cards') == level_one['replay_rng']['streams'].get('cards')
    assert state['stash'].count('pack_1') == level_one['stash'].count('pack_1')
    assert state['level'] == 1 and state['xp'] == level_one['xp']
    claimed = confirm(player, state, [('album_claim', {'album':0})])
    assert claimed['replay_meta']['album:0']
    assert claimed['amber'] == state['amber'] + 30
    assert claimed['stash'].count('chest_1') == state['stash'].count('chest_1') + 2
    rejects(claimed, 'album_claim', {'album':0})


@pytest.mark.parametrize('album', [-2, 10000])
def test_random_card_rejects_invalid_album(level_one, album):
    state = copy.deepcopy(level_one)
    state['gm_activities'] = True
    rejects(state, 'gm', {'action':'card','album':album})
    rejects(state, 'album_claim', {'album':album})


def test_unfinished_album_cannot_claim_even_after_gm_unlock(level_one):
    state = copy.deepcopy(level_one)
    state['gm_activities'] = True
    state['cards'] = {f'0_{index}':1 for index in range(8)}
    rejects(state, 'album_claim', {'album':0})
