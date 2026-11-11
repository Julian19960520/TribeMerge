"""Current schema and public projections have no direct gameplay mutation route."""
from sqlalchemy import inspect
from sqlalchemy.orm import Session

from app import clock
from app.db import engine
from app.models import Account
from app.services import store_state


def test_fresh_migration_matches_only_current_models(client):
    names=set(inspect(engine()).get_table_names())
    assert names=={'alembic_version','accounts','sessions','identities','saves','save_backups','idempotency_keys','audit_log',
                   'payment_orders','grants'}


def test_removed_direct_gameplay_routes_are_absent(client):
    for method,path in [('get','/v1/save'),('put','/v1/save'),('post','/v1/events'),('post','/v1/pack/open'),
                        ('post','/v1/build'),('post','/v1/energy/buy'),('get','/v1/race'),('get','/v1/gift-chain')]:
        assert getattr(client,method)(path).status_code==404


def test_ranking_reads_confirmed_build_projection_and_nickname(player):
    with Session(engine()) as db:
        account=db.get(Account,player.id)
        store_state(account,{'builds':{'fire':2},'level':3,'amber':80})
        db.commit()
    renamed=player.post('/v1/rank/name',{'name':'小酋长'})
    assert renamed.status_code==200
    top=player.get('/v1/rank/top').json()
    assert top['top'][0]['name']=='小酋长' and top['top'][0]['progress']==2
    assert top['me']['id']==player.id and top['me']['rank']==1
    clock.offset=31*86400
    assert player.get('/v1/rank/top').status_code==401
