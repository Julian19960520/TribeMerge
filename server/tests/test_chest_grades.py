"""Every new chest grade uses shared Godot rules and the compressed /v2 API."""
import copy
import json
import os

import pytest

from app.config import REPO_DIR
from test_reducer_domains import confirm, game, rejects

pytestmark = pytest.mark.skipif(not os.environ.get('TRIBE_REPLAY_GODOT'), reason='Godot 4.6.3 required')


def configuration(name):
    return json.loads((REPO_DIR / 'data' / (name + '.json')).read_text(encoding='utf-8'))


def known_item(item):
    chain, separator, raw_grade = item.rpartition('_')
    if not separator or not raw_grade.isdigit(): return False
    return any(row['id'] == chain and 1 <= int(raw_grade) <= len(row['items'])
               for row in configuration('chains'))


@pytest.mark.parametrize('chain', ['chest', 'energybox', 'premiumbox', 'choice'])
@pytest.mark.parametrize('grade', range(1, 6))
def test_every_grade_settles_once_and_keeps_rewards_physical(player, game, chain, grade):
    item = f'{chain}_{grade}'
    fixture = copy.deepcopy(game)
    fixture['board'][0]['id'] = item
    balances = {field:fixture[field] for field in ['energy', 'shells', 'amber', 'rush']}
    if chain == 'choice':
        choices = configuration('choice_chests')[item]['choices']
        for option, expected in enumerate(choices):
            state = confirm(player, copy.deepcopy(fixture), [('choice', {'cell':0, 'option':option})])
            outputs = [cell['id'] for cell in state['board'] if cell['id']]
            assert outputs == [expected] and known_item(expected)
            assert {field:state[field] for field in balances} == balances
            rejects(state, 'choice', {'cell':0, 'option':option})
        return

    definition = configuration('special_chests')[chain]['levels'][grade - 1]
    count = len(definition['items']) if chain == 'energybox' else definition['count']
    state = confirm(player, fixture, [('tap', {'cell':0}) for _ in range(count)])
    outputs = [cell['id'] for cell in state['board'] if cell['id']]
    assert len(outputs) == count and all(known_item(output) for output in outputs)
    assert item not in outputs and not any('chest' in cell for cell in state['board'])
    assert state['stash'] == []
    assert {field:state[field] for field in balances} == balances
    # confirm() retries the same compressed batch and checks a newly downloaded
    # snapshot against the shared reducer, so a retry cannot dispense twice.
    if chain == 'energybox':
        assert sorted(outputs) == sorted(definition['items'])
    elif chain == 'premiumbox':
        assert {output.rsplit('_', 1)[0] for output in outputs} == {'fire', 'amber'}
        allowed_grades = {index + 1 for index, weight in enumerate(definition['tier_weights']) if weight > 0}
        assert all(int(output.rsplit('_', 1)[1]) in allowed_grades for output in outputs)


def test_energy_and_premium_merges_increase_total_reward_value():
    definitions = configuration('special_chests')
    fire_values = next(row['value'] for row in configuration('chains') if row['id'] == 'fire')
    previous_energy = previous_premium = 0
    for grade in range(5):
        energy = sum(fire_values[int(item.rsplit('_', 1)[1]) - 1]
                     for item in definitions['energybox']['levels'][grade]['items'])
        premium_definition = definitions['premiumbox']['levels'][grade]
        weights = premium_definition['tier_weights']
        premium = sum(value * weight for value, weight in zip(fire_values, weights)) / sum(weights) * premium_definition['count']
        assert energy > previous_energy * 2
        assert premium > previous_premium * 2
        previous_energy, previous_premium = energy, premium
