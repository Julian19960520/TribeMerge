"""Gameplay coverage runs the actual shared reducer, never a Python rule copy."""
import copy
import json
import os

import pytest
from sqlalchemy.orm import Session

from app.config import REPO_DIR
from app.db import engine
from app.models import Account, Save
from app.replay_engine import run_worker
from app.replay_service import commit_result
from conftest import unpack
from test_replay import begin, body, op, worker

pytestmark = pytest.mark.skipif(not os.environ.get('TRIBE_REPLAY_GODOT'), reason='Godot 4.6.3 required')


@pytest.fixture()
def game(player, monkeypatch):
    _, state = begin(player, monkeypatch)
    state.update(level=30, tutorial_on=False, seen_tutorial=True, orders=[], energy=1000,
                 shells=100000, amber=10000, rush=1000, stash=[], inv=[])
    state['board'] = [{'id':'','lock':0} for _ in range(63)]
    state['builds'] = {row['id']:len(row['parts']) for row in json.loads((REPO_DIR/'data/builds.json').read_text())}
    return state


def reduce(state, commands, at=None):
    sequence = state['replay_meta']['seq']
    at = state['replay_meta']['at'] if at is None else at
    operations = [op(sequence+index+1,at,name,**arguments) for index,(name,arguments) in enumerate(commands)]
    return worker(dict(mode='replay',data=state,ops=operations)), operations


def rejects(state, name, arguments):
    operation=op(state['replay_meta']['seq']+1,state['replay_meta']['at'],name,**arguments)
    assert not run_worker(dict(mode='replay',data=state,ops=[operation]))['ok']


def confirm(player, state, commands):
    # Authoritative fixtures are inserted only inside the test database. There is
    # deliberately no endpoint for a client to seed or upload this state.
    loaded=worker(dict(mode='load',data=state))
    with Session(engine()) as db:
        commit_result(db.get(Account,player.id), db.get(Save,player.id),loaded)
        db.commit()
    initial=player.post('/v2/session').json()
    expected,operations=reduce(state,commands)
    request=body(initial,expected,operations)
    acknowledgement=player.post('/v2/sync',request).json()
    assert acknowledgement['ok'] and not acknowledgement['reset'], acknowledgement
    assert acknowledgement['hash']==expected['hash'] and acknowledgement['seq']==expected['seq']
    assert player.post('/v2/sync',request).json()==acknowledgement
    restored=unpack(player.post('/v2/session').json()['data'])
    assert restored==expected['data']
    return restored


def order(state,item='fruit_1'):
    state['board'][0]['id']=item
    state['orders']=[{'who':0,'items':[item],'rw':{'shell':10,'xp':1},'story':False}]


def test_merge_inventory_and_undo_share_one_command_path(player,game):
    game['board'][0]['id']=game['board'][1]['id']='fruit_1'
    state=confirm(player,game,[('drop',{'from':0,'to':1}),('store',{'cell':1}),
                              ('inventory',{'index':0}),('discard',{'cell':0}),('undo',{})])
    assert state['board'][0]['id']=='fruit_2' and state['inv']==[]
    assert state['seven_day']['stats']['merges']==1
    rejects(state,'undo',{})


def test_producers_and_chest_preserve_random_streams(player,game):
    for index,item in enumerate(['basket_5','emberpot_1','chest_1']): game['board'][index]['id']=item
    state=confirm(player,game,[('tap',{'cell':0}),('tap',{'cell':1}),('tap',{'cell':2})])
    assert state['energy']==game['energy']-1
    assert state['board'][2]['id']=='chest_1' and state['board'][2]['chest']
    assert {'produce:basket_5','energy_produce','chests'} <= state['replay_rng']['streams'].keys()


def test_shop_stock_daily_currency_and_refresh(player,game):
    state=confirm(player,game,[('daily',{'key':'deal_2'}),('daily',{'key':'deal_energybox'}),
                              ('shop',{'key':'shell_0','id':'fruit_2'}),('shell_refresh',{}),('hot_refresh',{})])
    assert state['energy']==game['energy']+15
    assert state['shells']==game['shells']-300-8
    assert 'energybox_1' in state['stash'] and 'fruit_2' in state['stash']
    assert state['shell_bought']=={} and state['hot_revision']==1
    rejects(state,'daily',{'key':'deal_2'})
    rejects(state,'daily',{'key':'deal_ad'})


def test_building_and_level_codex_pass_rewards_are_single_claims(player,game):
    game['builds']={'fire':1}
    game['discovered']['fruit_3']=True
    game['pass_pts']=6
    state=confirm(player,game,[('build',{'id':'fire'}),('book',{'id':'fruit_3'}),
                              ('level',{'level':2}),('pass',{'track':'free','level':1})])
    assert state['builds']['fire']==2 and state['shells'] < game['shells']
    assert state['book_claimed']['fruit_3'] and 1 in state['pass_free']
    rejects(state,'book',{'id':'fruit_3'})
    rejects(state,'level',{'level':2})
    rejects(state,'pass',{'track':'free','level':1})


def test_choice_chest_and_seven_day_claim_cannot_repeat(player,game):
    game['board'][0]['id']='choice_1'
    state=confirm(player,game,[('choice',{'cell':0,'option':2}),('seven',{'id':'d1_1','stage':False})])
    assert state['board'][0]['id']=='chest_1'
    assert state['seven_day']['claimed']['d1_1']
    rejects(state,'choice',{'cell':0,'option':2})
    rejects(state,'seven',{'id':'d1_1','stage':False})


def test_order_credits_progress_and_all_active_events(player,game):
    order(game)
    state=confirm(player,game,[('duel',{'action':'join'}),('tiger',{'action':'join'}),('race_join',{}),('order',{'cell':0})])
    assert state['fossil_dig']['shovels']==3
    assert state['duel_race']['match']['me'] > 0
    assert state['tiger_escape']['round']['points'] > 0
    assert state['seven_day']['stats']['orders']==1
    assert state['pass_pts'] > game['pass_pts']
    assert state['local_race']['current']['group']['members'][0]['score'] > 0
    active=list(state['merge_events'].values())
    assert active and active[0]['points'] > 0


def test_duel_wins_and_milestone_rewards_persist(player,game):
    joined,_=reduce(game,[('duel',{'action':'join'})])
    game=joined['data'];game['duel_race']['wins']=1
    game['duel_race']['match']['me']=game['duel_race']['match']['target']-1
    order(game)
    state=confirm(player,game,[('order',{'cell':0}),('duel',{'action':'claim'}),('duel',{'action':'milestone','milestone':2})])
    assert state['duel_race']['wins']==2 and '2' in state['duel_race']['claimed']
    assert state['duel_race']['match']['claimed']
    rejects(state,'duel',{'action':'claim'})
    rejects(state,'duel',{'action':'milestone','milestone':2})


def test_tiger_deadline_is_reproducible_and_cannot_be_undone(game):
    joined,_=reduce(game,[('tiger',{'action':'join'})]);state=joined['data']
    run=state['tiger_escape']['round']
    expired,_=reduce(state,[('tick',{})],int(run['start']+run['interval']+1))
    assert expired['data']['tiger_escape']['round']['status']=='lost'
    assert any(bot['status']=='lost' for bot in expired['data']['tiger_escape']['round']['bots'])
    rejects(expired['data'],'tiger',{'action':'join'})


def test_all_fossil_stages_keep_recovered_progress_and_single_claims(game):
    state=copy.deepcopy(game)
    state['fossil_dig']['shovels']=10000
    for stage in range(1,11):
        board=state['fossil_dig']['board']; n=board['n']
        cells=sorted({(piece['y']+y)*n+piece['x']+x for piece in board['pieces']
                      for y in range(piece['h']) for x in range(piece['w'])})
        complete,_=reduce(state,[('fossil',{'action':'dig','value':cell}) for cell in cells])
        state=complete['data']
        assert all(piece['found'] for piece in state['fossil_dig']['board']['pieces'])
        if stage < 10:
            advanced,_=reduce(state,[('fossil',{'action':'next'})]);state=advanced['data']
            assert state['fossil_dig']['stage']==stage+1 and state['fossil_dig']['board']['n']==stage+3
    assert state['fossil_dig']['recovered']==65
    awarded,_=reduce(state,[('fossil',{'action':'claim','value':2})])
    assert 2 in awarded['data']['fossil_dig']['claimed']
    rejects(awarded['data'],'fossil',{'action':'claim','value':2})
    rejects(awarded['data'],'fossil',{'action':'next'})


def test_gift_free_step_cannot_skip_payment_and_offer_window_is_timed(player,game):
    game['energy']=0
    state=confirm(player,game,[('gift',{'step':0}),('offer',{'kind':'energy'})])
    assert state['replay_meta']['gift_step']==1
    rejects(state,'gift',{'step':0})
    rejects(state,'gift',{'step':1})
    assert state['offers']


def test_worker_pool_keeps_accounts_and_failed_requests_isolated(game):
    a=worker(dict(mode='new',at=game['replay_meta']['at'],player='A',seed='ab'*32,allow_gm=False))
    b=worker(dict(mode='new',at=game['replay_meta']['at'],player='B',seed='cd'*32,allow_gm=False))
    assert a['data']['replay_rng']['seed'] != b['data']['replay_rng']['seed']
    rejects(b['data'],'tap',{'cell':99999})
    restored=worker(dict(mode='load',data=a['data']))
    assert restored['hash']==a['hash'] and restored['data']['player_id']=='A'
    from app.replay_engine import pool
    assert sum(process.starts for process in pool().processes)==1
