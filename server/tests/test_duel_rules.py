"""Pure authoritative-rule regression; also runnable without pytest."""
import copy
import random
from pathlib import Path
from types import SimpleNamespace
from app.gamedata import GameData
from app.economy import Economy, Reject
from app import duel_race as duel


def test_duel_rules():
    now = [1793577600.0]
    gd = GameData(str(Path(__file__).resolve().parents[2] / 'data'))
    e = Economy(gd, {}, lambda: '2026-11-02', rng=random.Random(41), now_fn=lambda: now[0])
    st = e.new_state()
    def act(action, milestone=0):
        return duel.action(e, st, SimpleNamespace(action=action, milestone=milestone))
    def rejects(action, milestone=0):
        try: act(action, milestone)
        except Reject: return
        raise AssertionError('action should reject: ' + action)
    rejects('join')
    st['level'] = int(gd.duel_race['unlock_level'])
    rejects('milestone', 2)
    for n in range(12):
        act('join')
        rejects('join')
        rejects('claim')
        for _ in range(8): duel.on_order(e, st, {'items':['fruit_8']})
        assert duel.state(st)['wins'] == n + 1
        duel.on_order(e, st, {'items':['fruit_8']})
        assert duel.state(st)['wins'] == n + 1
        before = st['shells']
        act('claim')
        assert st['shells'] == before + 240
        rejects('claim')
    for wins in (2, 5, 8, 12):
        act('milestone', wins)
        rejects('milestone', wins)
    act('join')
    now[0] += 4000
    duel.on_order(e, st, {'items':['fruit_8']})
    assert duel.state(st)['match']['status'] == 'lost'
    assert duel.state(st)['wins'] == 12
    before = st['shells']
    act('claim')
    assert st['shells'] == before + 60
    # Initial cloud adoption must never trust uploaded win/claim state.
    fresh = e.new_state()
    e.adopt(fresh, {'duel_race': copy.deepcopy(duel.state(st)), 'board':[]})
    assert not fresh.get('duel_race')
    assert duel.order_points(e, {'items':['fruit_8']}) == 4
    print('PASS authoritative duel win/loss, milestones, duplicates, adoption')

if __name__ == '__main__': test_duel_rules()
