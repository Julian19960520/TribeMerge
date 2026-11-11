"""GM feature access uses the same trusted command gate as all gameplay."""
import copy
import json

import pytest

from app.config import REPO_DIR
from godot_rules import new_game, requires_godot
from test_reducer_domains import confirm, rejects

pytestmark = requires_godot


@pytest.fixture()
def level_one():
    state = new_game(allow_gm=True)
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


def test_authorized_gm_opens_card_build_and_offer(level_one):
    identity, level, xp = level_one['player_id'], level_one['level'], level_one['xp']
    build = last_build()
    state = confirm(copy.deepcopy(level_one), [('gm',{}), ('pack',{}), ('build',{'id':build}),
                                                      ('offer',{'kind':'energy'})])
    assert state['gm_activities'] and state['boost_gm']
    assert sum(state['cards'].values()) == 2
    assert 'pack_1' not in state['stash']
    assert state['builds'][build] == 1
    assert state['offers']['energy']['end'] > state['offers']['energy']['start']
    assert (state['player_id'], state['level'], state['xp']) == (identity, level, xp)


def test_gm_access_command_preserves_identity_progress_and_assets(level_one):
    state = confirm(copy.deepcopy(level_one), [('gm',{})])
    for field in ['player_id','level','xp','energy','shells','amber','rush','cards','builds','board','inv','stash']:
        assert state[field] == level_one[field], field
    assert state['gm_activities'] and state['seen_tutorial'] and not state['tutorial_on']


@pytest.mark.parametrize('arguments', [{}, {'action':'card','album':0}])
def test_games_created_without_gm_reject_unlock(arguments):
    # Release builds create new games with allow_gm=false; the flag lives in the save, not in arguments.
    state = new_game(allow_gm=False)
    assert not state['replay_meta']['allow_gm'] and not state['gm_activities']
    rejects(state, 'gm', arguments)


def test_random_album_cards_persist(level_one):
    operations = [('gm', {})] + [('gm', {'action':'card','album':0}) for _ in range(10)]
    state = confirm(copy.deepcopy(level_one), operations)
    assert set(state['cards']) == {f'0_{index}' for index in range(9)}
    assert sum(state['cards'].values()) == 10
    assert not state['replay_meta'].get('album:0')
    assert state['amber'] == level_one['amber']
    assert state['stash'].count('chest_1') == level_one['stash'].count('chest_1')
    assert state['replay_rng']['streams'].get('cards') == level_one['replay_rng']['streams'].get('cards')
    assert state['stash'].count('pack_1') == level_one['stash'].count('pack_1')
    assert state['level'] == 1 and state['xp'] == level_one['xp']
    claimed = confirm(state, [('album_claim', {'album':0})])
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
