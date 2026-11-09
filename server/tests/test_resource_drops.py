from pathlib import Path
from app.gamedata import GameData


def test_configured_resource_intervals():
    gd = GameData(str(Path(__file__).parents[2] / 'data'))
    assert gd.resource_drop('main', .005, 8, 'fruit_8') == 'shell_1'
    assert gd.resource_drop('main', .012, 8, 'fruit_8') == 'sand_1'
    assert gd.resource_drop('main', .0155, 8, 'fruit_8') == 'amber_1'
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
    nonce = next(str(i) for i in range(100000) if .01 <= int(hashlib.sha256(str(i).encode()).hexdigest()[:8], 16) / 4294967296 < .011)
    assert player.put(player.snapshot()).status_code == 200
    event = {'id': nonce, 'type': 'merge', 'item': 'fruit_8', 'cell': 0}
    response = player.post('/v1/events', {'events': [event]}).json()['events'][0]
    assert response['give']['items'] == ['amber_1']
    repeated = player.post('/v1/events', {'events': [event]}).json()['events'][0]
    assert repeated['dup']


def test_only_enabled_production_lines_can_generate_resources():
    gd = GameData(str(Path(__file__).parents[2] / 'data'))
    for merged in ('shell_2', 'sand_2', 'amber_2', 'fire_2', 'basket_3', 'chest_1', 'pack_1', 'choice_1', 'energybox_1', 'salad', '', 'fruit_1'):
        assert gd.resource_drop('main', 0, 40, merged) == '', merged
    for line in gd.lines:
        for chain in (line['main'], line['sub']):
            assert gd.resource_drop('main', 0, 40, chain + '_2') == 'shell_1'
    gd.rules['merge_resource_lines'] = ['food']
    assert gd.resource_drop('main', 0, 8, 'fruit_2') == 'shell_1'
    assert gd.resource_drop('main', 0, 8, 'tool_2') == ''
    gd.rules['merge_resource_lines'] = []
    assert gd.resource_drop('main', 0, 8, 'fruit_2') == ''
    assert gd.resource_drop('event', 0, 8) == 'amber_1'


def test_resource_merges_never_generate_more_resources(player):
    from conftest import ev
    events = [ev('merge', item=i, cell=0) for i in ('shell_2', 'sand_2', 'amber_2', 'fire_2', 'basket_3')]
    result = player.post('/v1/events', {'events': events}).json()['events']
    assert all(r['ok'] and r['give'] == {} for r in result)
