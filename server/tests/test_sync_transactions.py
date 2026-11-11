"""Rule execution never holds a DB transaction; commits recheck identity and version."""
import copy
import hashlib
import json
import threading
import uuid
from concurrent.futures import ThreadPoolExecutor

import pytest
from sqlalchemy import select
from sqlalchemy.orm import Session

from app import clock, replay_engine
from app.db import engine, get_db
from app.models import AuthSession, Save, SaveBackup
from conftest import unpack

RULES = 'ab' * 32


def result(snapshot):
    snapshot = copy.deepcopy(snapshot)
    return {'ok':True, 'engine':'4.6.3-stable (official)', 'rules':RULES, 'seq':snapshot['replay_meta']['seq'],
            'data':snapshot,'hash':hashlib.sha256(json.dumps(snapshot,sort_keys=True).encode()).hexdigest()}


def simulate(payload):
    if payload['mode'] == 'new':
        return result({'amber':80,'shells':0,'level':1,'xp':0,'builds':{},'cards':{},'board':[],
                       'replay_meta':{'seq':0,'at':payload['at']}})
    snapshot = copy.deepcopy(payload['data'])
    for operation in payload['ops']:
        snapshot['xp'] += 1
        snapshot['replay_meta'] = {'seq':operation['seq'],'at':operation['at']}
    return result(snapshot)


@pytest.fixture()
def fake_engine(monkeypatch):
    monkeypatch.setattr(replay_engine,'current_rules',lambda: RULES)
    monkeypatch.setattr(replay_engine,'run_worker',simulate)


def request_for(session):
    snapshot = unpack(session['data'])
    operations = [{'seq':snapshot['replay_meta']['seq']+1,'at':snapshot['replay_meta']['at'],
                   'name':'tap','args':{'cell':0}}]
    expected = simulate({'mode':'replay','data':snapshot,'ops':operations})
    return {'base':session['version'],'rules':RULES,'hash':expected['hash'],'batch':uuid.uuid4().hex,'ops':operations}


def test_rule_work_and_queue_wait_do_not_hold_transactions(client, player, fake_engine, monkeypatch):
    sessions=[]
    def tracked_db():
        with Session(engine()) as db:
            sessions.append(db)
            yield db
    client.app.dependency_overrides[get_db] = tracked_db
    def checked(payload):
        assert sessions and all(not db.in_transaction() for db in sessions)
        return simulate(payload)
    monkeypatch.setattr(replay_engine,'run_worker',checked)
    initial = player.post('/v2/session').json()
    assert player.post('/v2/sync',request_for(initial)).json()['seq'] == 1


def test_session_revoked_during_replay_cannot_commit(player, fake_engine, monkeypatch):
    initial = player.post('/v2/session').json()
    def revoke(payload):
        with Session(engine()) as db:
            for session in db.scalars(select(AuthSession).where(AuthSession.account_id==player.id)):
                session.revoked_at=clock.utcnow(); session.revoke_reason='replaced'
            db.commit()
        return simulate(payload)
    monkeypatch.setattr(replay_engine,'run_worker',revoke)
    response = player.post('/v2/sync',request_for(initial))
    assert response.status_code == 401 and response.json()['error']=='session_replaced'
    with Session(engine()) as db: assert db.get(Save,player.id).version == initial['version']


@pytest.mark.parametrize('same_batch',[False,True])
def test_concurrent_batches_advance_a_confirmation_point_once(player, fake_engine, monkeypatch, same_batch):
    initial = player.post('/v2/session').json()
    first, second = request_for(initial), request_for(initial)
    if same_batch: second = copy.deepcopy(first)
    barrier = threading.Barrier(2)
    def concurrent(payload):
        barrier.wait(timeout=3)
        return simulate(payload)
    monkeypatch.setattr(replay_engine,'run_worker',concurrent)
    with ThreadPoolExecutor(max_workers=2) as executor:
        replies=list(executor.map(lambda request: player.post('/v2/sync',request), [first,second]))
    assert [reply.status_code for reply in replies] == [200,200], [reply.text for reply in replies]
    responses=[reply.json() for reply in replies]
    assert all(response['version']==initial['version']+1 for response in responses)
    assert sum(not response['reset'] for response in responses) == (2 if same_batch else 1)
    with Session(engine()) as db: assert db.get(Save,player.id).version == initial['version']+1


def test_batch_id_reuse_with_different_inputs_is_rejected(player, fake_engine):
    initial=player.post('/v2/session').json(); request=request_for(initial)
    assert player.post('/v2/sync',request).status_code == 200
    request['ops'][0]['args']['cell']=1
    response=player.post('/v2/sync',request)
    assert response.status_code==409 and response.json()['error']=='idempotency_key_reused'


def test_rules_mismatch_is_explicit_and_preserves_confirmed_save(player, fake_engine):
    initial=player.post('/v2/session').json(); request=request_for(initial)
    request['rules']='cd'*32
    response=player.post('/v2/sync',request)
    assert response.status_code==409 and response.json()['error']=='rules_update_required'
    with Session(engine()) as db: assert db.get(Save,player.id).version==initial['version']


def test_confirmed_backup_retention(player, fake_engine):
    from app.config import get_settings
    get_settings().backups_recent=2
    initial=player.post('/v2/session').json()
    for _ in range(5):
        assert player.post('/v2/sync',request_for(initial)).status_code==200
        initial=player.post('/v2/session').json()
    with Session(engine()) as db:
        backups=db.scalars(select(SaveBackup).where(SaveBackup.account_id==player.id)).all()
        assert len([entry for entry in backups if entry.kind=='recent'])==2
        assert len([entry for entry in backups if entry.kind=='daily'])==1


def test_concurrent_initial_sessions_create_one_confirmed_save(player, fake_engine, monkeypatch):
    barrier=threading.Barrier(2)
    def prepare(payload):
        barrier.wait(timeout=3)
        return simulate(payload)
    monkeypatch.setattr(replay_engine,'run_worker',prepare)
    with ThreadPoolExecutor(max_workers=2) as executor:
        replies=list(executor.map(lambda _: player.post('/v2/session'),range(2)))
    assert [reply.status_code for reply in replies]==[200,200], [reply.text for reply in replies]
    responses=[reply.json() for reply in replies]
    assert responses[0]['hash']==responses[1]['hash']
    assert responses[0]['version']==responses[1]['version']==1
    with Session(engine()) as db: assert db.get(Save,player.id).version==1


def test_expired_session_during_replay_cannot_commit(player, fake_engine, monkeypatch):
    initial=player.post('/v2/session').json()
    def expire(payload):
        output=simulate(payload)
        clock.offset=31*86400
        return output
    monkeypatch.setattr(replay_engine,'run_worker',expire)
    response=player.post('/v2/sync',request_for(initial))
    assert response.status_code==401 and response.json()['error']=='token_expired'
    with Session(engine()) as db: assert db.get(Save,player.id).version==initial['version']
