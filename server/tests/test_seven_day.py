from conftest import ev
from test_merge_event import mutate


def test_login_and_forged_snapshot(player, monkeypatch):
    from app import clock
    st=player.get('/v1/save').json()['state']
    assert st['seven_day']['stats']['login_days']==1
    player.put(player.snapshot(seven_day={'stats':{'orders':9999},'claimed':{'d1_2':True}}))
    st=player.get('/v1/save').json()['state']
    assert st['seven_day']['stats'].get('orders',0)==0 and not st['seven_day']['claimed']
    assert st['seven_day']['stats']['login_days']==1
    clock.offset += 86400
    assert player.get('/v1/save').json()['state']['seven_day']['stats']['login_days']==2


def test_claim_early_individual_and_milestones(player):
    from app import seven_day
    from app.services import economy
    player.get('/v1/save')
    mutate(player,lambda st:seven_day.record(economy(),st,'orders',180))
    r=player.post('/v1/seven-day/claim',{'entry':'d7_2'},key='claim-seven')
    assert r.status_code==200 and r.json()['state']['seven_day']['claimed']['d7_2']
    assert player.post('/v1/seven-day/claim',{'entry':'d7_2'},key='claim-seven').json()==r.json()
    assert player.post('/v1/seven-day/claim',{'entry':'d7_2'}).json()['error']=='already_claimed'
    assert player.post('/v1/seven-day/claim',{'entry':'p50','stage':True}).json()['error']=='not_completed'
    # d7_2 alone is 30 points; two early order tasks (10 + 15) push past the first 50-point stage
    for key in ['d1_2','d2_2']:
        assert player.post('/v1/seven-day/claim',{'entry':key}).status_code==200
    p50=next(s for s in economy().gd.seven_day['milestones'] if s['id']=='p50')
    want=sum(int(n) for i,n in p50['rewards'] if str(i).startswith('fire_'))
    assert player.post('/v1/seven-day/claim',{'entry':'p50','stage':True}).json()['give']['energy']==want
    assert player.post('/v1/seven-day/claim',{'entry':'p50','stage':True}).json()['error']=='already_claimed'


def test_order_merge_and_refill_counters(player):
    order=ev('order',order={'who':2,'items':['fruit_2'],'rw':{'shell':4},'story':False})
    merge=ev('merge',item='fruit_2',cell=-1)
    seed=ev('order',order={'who':2,'items':['seed_1'],'rw':{'shell':50,'xp':1},'story':True})
    r=player.post('/v1/events',{'events':[order,merge,seed]}).json()
    assert all(e['ok'] for e in r['events'])
    stats=r['state']['seven_day']['stats']
    assert stats['orders']==2 and stats['merges']==1 and stats['shell']==54 and stats['xp']==1
    assert player.post('/v1/events',{'events':[order,merge]}).json()['state']['seven_day']['stats']==stats
    mutate(player,lambda st:st.update(shell_bought={'shell_0':3,'shell_5':2}))
    r=player.post('/v1/shop/shell/refresh',key='refresh-five')
    assert r.status_code==200 and r.json()['state']['amber']==75 and not r.json()['state']['shell_bought']
    assert r.json()['state']['seven_day']['stats']['amber_spent']==5
    assert player.post('/v1/shop/shell/refresh',key='refresh-five').json()==r.json()
    mutate(player,lambda st:st.update(amber=0,shell_bought={'shell_0':3}))
    assert player.post('/v1/shop/shell/refresh').json()['error']=='not_enough_amber'
    assert player.get('/v1/save').json()['state']['shell_bought']=={'shell_0':3}


def test_merge_drop_budget_and_retry(player):
    import hashlib
    from app.services import gamedata
    chance=float(gamedata().rules["merge_resource_drops"]["main"][0]["chance"])
    nonce=next(str(i) for i in range(10000) if int(hashlib.sha256(str(i).encode()).hexdigest()[:8],16)/4294967296 < chance)
    event={'id':nonce,'type':'merge','item':'fruit_2','cell':0}
    r=player.post('/v1/events',{'events':[event]}).json()
    assert r['events'][0]['give']['items']==['shell_1']
    from app.services import economy
    before=mutate(player,lambda st:st['budget'].get('shell',0))
    r=player.post('/v1/events',{'events':[event]}).json()
    assert r['events'][0]['dup']
    assert mutate(player,lambda st:st['budget'].get('shell',0))==before
    bad=player.post('/v1/events',{'events':[ev('merge',item='fruit_1',cell=0)]}).json()
    assert not bad['events'][0]['ok']


def test_mock_payment_not_real_cash(player):
    order=player.post('/v1/payments/orders',{'pack':0,'provider':'mock'}).json()
    paid=player.post('/v1/payments/mock/'+order['order_id']+'/pay').json()
    assert paid['status']=='paid'
    assert paid['state']['seven_day']['stats'].get('paid_cents',0)==0
    assert player.post('/v1/seven-day/claim',{'entry':'d3_5'}).json()['error']=='not_completed'


def test_configuration_has_35_tasks_and_free_path(client):
    from app.services import gamedata
    cfg=gamedata().seven_day
    assert len(cfg['days'])==7 and all(len(day['tasks'])==5 for day in cfg['days'])
    tasks=[t for d in cfg['days'] for t in d['tasks']]
    assert len({t['id'] for t in tasks})==35
    assert sum(t['points'] for t in tasks if t['metric']!='paid_cents') >= max(m['points'] for m in cfg['milestones'])
    # every page opens with "login N days", and each metric's target grows page by page
    assert [d['tasks'][0]['metric'] for d in cfg['days']]==['login_days']*7
    assert [d['tasks'][0]['target'] for d in cfg['days']]==list(range(1,8))
    last={}
    for d in cfg['days']:
        for t in d['tasks']:
            assert t['target']>last.get(t['metric'],0)
            last[t['metric']]=t['target']
    assert set(last)=={'login_days','orders','merges','xp','cards','shell','amber','amber_spent','paid_cents'}
    gd=gamedata()
    for t in tasks+cfg['milestones']:
        for rid,n in t['rewards']:
            assert gd.valid_item(rid) and n>0


def test_card_counts_and_verified_payment_callback_once(player):
    from app.services import economy
    def packs(st):
        st['level']=8
        for _ in range(3): economy().give_item(st,'pack_1',{})
    mutate(player,packs)
    assert player.post('/v1/pack/open').json()['state']['seven_day']['stats']['cards']==2
    assert player.post('/v1/pack/open').json()['state']['seven_day']['stats']['cards']==4
    assert player.post('/v1/seven-day/claim',{'entry':'d4_4'}).json()['error']=='not_completed'
    assert player.post('/v1/pack/open').json()['state']['seven_day']['stats']['cards']==6
    assert player.post('/v1/seven-day/claim',{'entry':'d4_4'}).status_code==200
    order=player.post('/v1/payments/orders',{'pack':0,'provider':'mock'}).json()
    # Exercise the verified callback boundary without performing any real payment.
    from app import db
    from app.models import PayOrder
    from app.api_game import _fulfil
    with db._SessionLocal() as session:
        row=session.get(PayOrder,order['order_id'])
        row.provider='verified_test'
        st=_fulfil(session,row,'verified-receipt')
        assert st['seven_day']['stats']['paid_cents']==600
        session.commit()
        st=_fulfil(session,row,'verified-receipt')
        assert st['seven_day']['stats']['paid_cents']==600
        session.commit()
    assert player.post('/v1/seven-day/claim',{'entry':'d3_5'}).status_code==200
