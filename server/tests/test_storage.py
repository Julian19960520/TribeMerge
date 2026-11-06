from test_merge_event import mutate


def test_unlimited_storage_price_and_idempotence(player):
    mutate(player,lambda st:st.update(amber=10000))
    total=0
    for n in range(12):
        price=50+n*10
        key=f'expand-{n}'
        r=player.post('/v1/storage/expand',key=key)
        total+=price
        assert r.status_code==200
        assert r.json()['state']['inv_cap']==6+n
        assert r.json()['state']['amber']==10000-total
        assert player.post('/v1/storage/expand',key=key).json()==r.json()
    mutate(player,lambda st:st.update(amber=0))
    assert player.post('/v1/storage/expand').json()['error']=='not_enough_amber'
    assert player.get('/v1/save').json()['state']['inv_cap']==17
    mutate(player,lambda st:st.update(inv_cap=125,amber=5000))
    r=player.post('/v1/storage/expand').json()
    assert r['state']['inv_cap']==126 and r['state']['amber']==3750


def test_each_page_has_matching_login_goal(client):
    from app.services import gamedata
    for day in gamedata().seven_day['days']:
        login=[t for t in day['tasks'] if t['metric']=='login_days']
        assert len(day['tasks'])==5 and len(login)==1
        assert login[0]['target']==day['day']
