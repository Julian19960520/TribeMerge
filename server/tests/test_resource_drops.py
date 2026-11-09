from pathlib import Path
from app.gamedata import GameData


def test_configured_resource_intervals():
    gd = GameData(str(Path(__file__).parents[2] / 'data'))
    assert gd.resource_drop('main', .01, 8, 'fruit_8') == 'shell_1'
    assert gd.resource_drop('main', .05, 8, 'fruit_8') == 'sand_1'
    assert gd.resource_drop('main', .0705, 8, 'fruit_8') == 'amber_1'
    assert gd.resource_drop('main', .08, 8, 'fruit_8') == ''
    assert gd.resource_drop('event', .1, 1) == 'amber_1'
    assert gd.resource_drop('event', .3, 1) == 'fire_1'
    assert gd.resource_drop('event', .5, 1) == ''
    gd.rules['merge_resource_drops']['event'] = [{'item': 'sand_4', 'chance': 1}]
    assert gd.resource_drop('event', .9, 1) == 'sand_1'
    gd.rules['merge_resource_drops']['event'] = []
    assert gd.resource_drop('event', 0, 1) == ''


def test_main_merge_uses_new_rules_and_deduplicates(player):
    import hashlib
    nonce = next(str(i) for i in range(100000) if .04 <= int(hashlib.sha256(str(i).encode()).hexdigest()[:8], 16) / 4294967296 < .041)
    assert player.put(player.snapshot()).status_code == 200
    event = {'id': nonce, 'type': 'merge', 'item': 'fruit_8', 'cell': 0}
    response = player.post('/v1/events', {'events': [event]}).json()['events'][0]
    assert response['give']['items'] == ['amber_1']
    repeated = player.post('/v1/events', {'events': [event]}).json()['events'][0]
    assert repeated['dup']
