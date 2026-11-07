"""Pure progression regression, runnable without pytest or the HTTP server."""
from collections import Counter
from pathlib import Path
from types import SimpleNamespace
from app.gamedata import GameData
from app.economy import Economy
from app import merge_event as moon


def test_progression():
    gd = GameData(str(Path(__file__).resolve().parents[2] / 'data'))
    e = Economy(gd, {}, lambda: '2026-11-02', now_fn=lambda: 1793577600.0)
    c = moon.current(gd.merge_events, e.now())
    s = moon.fresh(c)
    for cell in s['cells']:
        cell.update(lock=0, id='')
    s['discovered']['moon_3'] = True
    moon.advance(c, s)
    assert s['view'] == 9
    for tier, view in [(4, 6), (5, 3), (6, 0)]:
        s['discovered'][f'moon_{tier}'] = True
        moon.advance(c, s)
        assert s['view'] == view
        moon.advance(c, s)
        assert s['view'] == view
    # Highest discovered tier includes earlier thresholds even for legacy saves.
    s['view'] = s['min_view'] = 9
    s['discovered'] = {'moon_6': True}
    s['rules_version'] = 2
    moon.state({'merge_events': {c['key']: s}}, c)
    assert s['view'] == 0 and s['rules_version'] == 3
    s['discovered'] = {}
    s['rules_version'] = 2
    moon.state({'merge_events': {c['key']: s}}, c)
    assert s['view'] == 0  # never move an existing save backwards
    # Advance without clearing the top row, retaining all outgoing items.
    s = moon.fresh(c)
    for cell in s['cells'][72:]: cell.update(lock=0, id='')
    s['cells'][95]['id'] = 'moon_4'
    s['cells'][80]['id'] = 'moon_3'
    s['discovered'] = {'moon_4': True}
    before = Counter(x['id'] for x in s['cells'] if x['id'])
    moon.advance(c, s)
    assert s['view'] == 6 and s['cells'][54]['lock'] == 2
    assert before == Counter(x['id'] for x in s['cells'] if x['id'])
    assert all(not x['id'] and not x['lock'] for x in s['cells'][78:])
    # A full board defers earned advancement; recycling retries it safely.
    s = moon.fresh(c)
    s['discovered'] = {'moon_4': True}
    for cell in s['cells'][72:]: cell.update(lock=0, id='moon_8')
    moon.advance(c, s)
    assert s['view'] == 9
    st = {'level':10, 'merge_events':{c['key']:s}}
    for i in range(72, 80):
        moon.action(e, st, SimpleNamespace(season=c['key'], action='recycle', view=s['view'], cell=i))
    assert s['view'] == 8
    assert sum(x['id'] == 'moon_8' for x in s['cells']) == 16
    assert all(not x['lock'] and not x['id'] for x in s['cells'][90:])
    print('PASS moon tier thresholds, one-time advance, migration, item conservation, pending retry')


def test_full_play():
    gd = GameData(str(Path(__file__).resolve().parents[2] / 'data'))
    e = Economy(gd, {}, lambda: '2026-11-02', now_fn=lambda: 1793577600.0)
    c = moon.current(gd.merge_events, e.now())
    st = {'level':10}
    s = moon.state(st, c)
    # Test-only point budget; every spawn still pays its configured cost.
    s['points'] = s['earned'] = 1000
    chain = [row['id'] for row in c['chain']]
    for step in range(6000):
        if moon.complete(c,s): break
        cells=s['cells']; lo=s['view']*6; hi=lo+42
        candidates=[]
        for a in range(lo,hi):
            if cells[a]['lock'] or not cells[a]['id'] or cells[a]['id']==chain[-1]: continue
            for b in range(lo,hi):
                if a==b or cells[b]['lock']==2 or cells[b]['id']!=cells[a]['id']: continue
                reveal=sum(cells[n]['lock']==2 for n in moon.neighbors(b,6,len(cells)))
                candidates.append((int(cells[b]['lock']==1)*100+reveal*10-b*.001,a,b))
        req=dict(season=c['key'],view=s['view'])
        if candidates:
            _,a,b=max(candidates); req.update(action='drop',from_cell=a,to=b)
        elif any(not cells[i]['id'] and not cells[i]['lock'] for i in range(lo,hi)):
            req.update(action='spawn')
        else:
            recycle=next((i for i in range(lo,hi) if not cells[i]['lock'] and cells[i]['id']==chain[-1]),None)
            assert recycle is not None, ('stuck',s['view'],moon.progress(c,s))
            req.update(action='recycle',cell=recycle)
        moon.action(e,st,SimpleNamespace(**req))
        assert s['points']+s['spent']==s['earned']
        assert all(not x['id'] and not x['lock'] for x in cells[(s['view']+7)*6:])
    assert moon.complete(c,s) and s['view']==0
    print(f'PASS moon full 90-cell play: {step} actions, {s["spent"]} points')

if __name__ == '__main__':
    test_progression()
    test_full_play()
