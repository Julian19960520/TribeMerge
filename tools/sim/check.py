"""Check simulation conservation boundaries, claim uniqueness, and reproducibility."""
import json
import sys
from pathlib import Path


def clean(value):
    if isinstance(value, dict): return {k: clean(v) for k, v in value.items() if k != 'uid'}
    if isinstance(value, list): return [clean(v) for v in value]
    return value


def check(path):
    d = json.loads(Path(path).read_text(encoding='utf-8'))
    assert d['runs'] and d['events']
    lines = d.get('production_lines', [])
    metrics = [line['metric'] for line in lines]
    metrics += [line['max_metric'] for line in lines if 'max_metric' in line]
    if d.get('resource_counting'):
        metrics += ['sand', 'amber_earned', 'sand_earned']
    assert len(metrics) == len(set(metrics))
    for run in d['runs']:
        rows = [e for e in d['events'] if e['run'] == run['run']]
        assert rows[0]['category'] == 'start' and rows[0]['state']['level'] == 1
        assert rows[-1]['category'] == 'end'
        assert rows[-1]['state'] == run['state']
        assert run['duration'] <= float(d['config']['cycle_days']) * 86400
        last_time = -1
        level_claims = set()
        win_claims = set()
        previous = None
        for e in rows:
            for metric in metrics:
                value = e['state'][metric]
                assert value >= 0 and int(value) == value
                if previous is not None:
                    assert e['delta'].get(metric, 0) == value - previous['state'][metric]
            if d.get('resource_counting'):
                for earned in ('amber_earned', 'sand_earned'):
                    assert e['state'][earned] >= (previous['state'][earned] if previous else 0)
                if previous is None:
                    assert e['state']['amber_earned'] == e['state']['sand_earned'] == 0
            if e['category'] == 'unlock':
                detail = e['detail']
                assert detail['board'] in ('main', 'moon')
                assert detail['lock_before'] == 1 and detail['lock_after'] == 0
                assert previous and previous['seq'] == detail['merge_seq']
                assert previous['time'] == e['time'] and previous['category'] in ('merge', 'event')
                assert e['state'] == previous['state'] and not e['delta']
            previous = e
            assert e['time'] >= last_time
            last_time = e['time']
            assert all(e['state'][k] >= 0 for k in ('energy','coins','gems','empty','storage'))
            assert e['state']['storage'] <= d['config'].get('max_storage',20)
            if e['category'] == 'wait':
                assert abs(e['time'] - e['detail']['from'] - e['detail']['seconds']) < .02
            if e['title'].startswith('领取 ') and e['title'].endswith(' 级奖励'):
                assert e['title'] not in level_claims
                level_claims.add(e['title'])
            if e['title'] == '双人竞速累计胜利奖励':
                at = e['detail']['wins']
                assert at in (2,5,8,12) and at not in win_claims
                assert e['state']['duel_wins'] >= at
                win_claims.add(at)
            if e['category'] == 'delete':
                item = e['detail']['item']
                assert int(item.rsplit('_',1)[-1]) <= d['config']['delete_max_level']
            if e['title'] in ('打开典藏卡包', '领取暂存卡包'):
                assert e['state']['level'] >= 8
        assert run['finish_reason'] != 'invariant_failed'
        save_path = Path(path).with_name(Path(path).stem + '-run%d-save.json' % run['run'])
        if lines and save_path.exists():
            state = json.loads(save_path.read_text(encoding='utf-8'))
            owned = [cell['id'] for cell in state['board'] if cell['lock'] == 0]
            owned += state.get('inv', []) + state.get('stash', [])
            for line in lines:
                levels = [int(i.rsplit('_', 1)[1]) for i in owned if i and i.rsplit('_', 1)[0] == line['generator']]
                expected = sum(2 ** (level - 1) for level in levels) if d.get('production_counting') == 'level1_equivalent' else sum(levels)
                assert run['state'][line['metric']] == expected, (line['id'], expected)
                if 'max_metric' in line:
                    assert run['state'][line['max_metric']] == max(levels, default=0)
            if d.get('resource_counting'):
                assert run['state']['gems'] == state['amber']
                assert run['state']['sand'] == state['rush']
                assert run['state']['gems'] <= run['resource_initial']['amber'] + run['state']['amber_earned']
                assert run['state']['sand'] <= run['resource_initial']['sand'] + run['state']['sand_earned']

    print(f"PASS {path}: {len(d['runs'])} runs, {len(d['events'])} events")
    return d


if __name__ == '__main__':
    reports = [check(p) for p in sys.argv[1:]]
    if len(reports) == 2:
        assert reports[0]['config'] == reports[1]['config']
        assert clean(reports[0]['events']) == clean(reports[1]['events'])
        print('PASS same-seed deterministic event stream')
