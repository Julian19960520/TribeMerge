"""Cross-runtime wire tests, measured request sizes and bounded decompression."""
import base64
import gzip
import hashlib
import json
import os
import random
import subprocess
import typing
from pathlib import Path

import pytest
from app import replay_wire as wire
from app.replay_models import COMMANDS, SyncReq
from app.config import REPO_DIR

GODOT = os.environ.get('TRIBE_REPLAY_GODOT')


def sample(ops):
    return {'base': 12, 'rules': hashlib.sha256(b'rules').hexdigest(),
            'hash': hashlib.sha256(b'state').hexdigest(), 'batch': hashlib.md5(b'batch').hexdigest(), 'ops': ops}


def encoded(bodies, tmp_path):
    if not GODOT:
        pytest.skip('set TRIBE_REPLAY_GODOT to Godot 4.6.3')
    src, dst = tmp_path / 'wire-input.json', tmp_path / 'wire-output.json'
    src.write_text(json.dumps(bodies))
    p = subprocess.run([GODOT, '--headless', '--path', str(REPO_DIR), '--script', 'res://tools/check_replay_wire.gd', '--',
                        '--cloud-off', f'--save={tmp_path / "unused.json"}', f'--input={src}', f'--output={dst}'],
                       timeout=20, capture_output=True, text=True)
    assert p.returncode == 0 and 'SCRIPT ERROR' not in p.stdout + p.stderr, p.stdout + p.stderr
    return json.loads(dst.read_text())


@pytest.fixture()
def wire_samples(tmp_path):
    all_ops = []
    for i, (name, fields) in enumerate(wire.REGISTRY):
        args = {}
        for field in fields:
            if field in wire.STRING_FIELDS:
                args[field] = {'season': 'moon_relic:0', 'action': 'drop', 'track': 'free', 'id': 'fruit_2',
                               'key': 'deal_2', 'kind': 'energy'}[field]
            elif field in wire.BOOL_FIELDS:
                args[field] = field == 'stage'
            else:
                args[field] = -1 if field == 'from' else 31
        all_ops.append({'seq': i + 100, 'at': 1794216000 + i // 3, 'name': name, 'args': args})
    repeated = [{'seq': i + 1, 'at': 1794216000 + i // 5, 'name': 'drop',
                 'args': {'from': i % 63, 'to': (i + 1) % 63}} for i in range(256)]
    bodies = [sample(all_ops), sample(repeated), sample([{'seq': 1, 'at': 1794216000, 'name': 'activity',
                                                       'args': {'season': '月石:0', 'action': 'spawn'}}])]
    mixed = []
    for i in range(256):
        choices = [('tap', {'cell': 31}), ('drop', {'from': i % 63, 'to': (i + 1) % 63}),
                   ('order', {'cell': i % 5}), ('stash', {'index': 0}),
                   ('activity', {'season': 'moon_relic:0', 'action': 'drop', 'view': 9,
                                 'from': 90 + i % 6, 'to': 90 + (i + 1) % 6}),
                   ('pack', {}), ('book', {'id': 'fruit_' + str(i % 8 + 1)}), ('tap', {'cell': 0})]
        name, args = choices[i % len(choices)]
        mixed.append({'seq': i + 1, 'at': 1794216000 + i // 5, 'name': name, 'args': args})
    bodies.append(sample(mixed))
    return bodies, encoded(bodies, tmp_path)


def test_registry_covers_every_replay_command():
    names = [row[0] for row in wire.REGISTRY]
    assert len(names) == len(set(names)) and set(names) == set(typing.get_args(COMMANDS))


def test_godot_binary_gzip_python_round_trip_and_size(wire_samples):
    bodies, results = wire_samples
    for body, result in zip(bodies, results):
        assert result['ok']
        raw = wire.inflate(base64.b64decode(result['gzip']))
        assert raw == base64.b64decode(result['raw'])
        assert wire.decode(raw) == body
        assert SyncReq.model_validate(wire.decode(raw)).model_dump() == body
    repeated = results[1]
    assert repeated['gzip_bytes'] < repeated['json_bytes'] * 0.1
    print('256 repeated operation bytes:', {k: repeated[k] for k in ('json_bytes', 'compact_bytes', 'gzip_bytes')})
    print('256 mixed operation bytes:', {k: results[-1][k] for k in ('json_bytes', 'compact_bytes', 'gzip_bytes')})


def test_encoder_preserves_order_and_rejects_unknown_fields(tmp_path):
    good = sample([{'seq': 1, 'at': 1794216000, 'name': 'tap', 'args': {'cell': 31}}])
    bad = []
    for change in [dict(seq=2), dict(at=1794215999), dict(args={'cell': 1.5}), dict(args={'cell': 31, 'reward': 999}), dict(name='cheat')]:
        b = json.loads(json.dumps(good))
        if 'seq' in change or 'at' in change:
            b['ops'].append({**b['ops'][0], 'seq': 2, **change})
            if 'seq' in change: b['ops'][-1]['seq'] = 3
        else:
            b['ops'][0].update(change)
        bad.append(b)
    assert all(not r['ok'] for r in encoded(bad, tmp_path))


def test_bounded_gzip_and_malformed_wire(wire_samples):
    _, results = wire_samples
    raw, compressed = base64.b64decode(results[0]['raw']), base64.b64decode(results[0]['gzip'])
    for invalid in [compressed[:-1], compressed + b'trailing', compressed + compressed, b'not gzip',
                    gzip.compress(b'A' * (wire.MAX_RAW + 1)), b'A' * (wire.MAX_COMPRESSED + 1)]:
        with pytest.raises(wire.WireError): wire.inflate(invalid)
    for invalid in [b'', b'TRP2' + raw[4:], raw[:-1], raw + b'trailing']:
        with pytest.raises(wire.WireError): wire.decode(invalid)
    # Mutated input must either decode or fail as a controlled protocol error.
    rng = random.Random(12)
    for _ in range(200):
        mutant = bytearray(raw)
        for _ in range(rng.randrange(1, 4)):
            mutant[rng.randrange(len(mutant))] = rng.randrange(256)
        try:
            wire.decode(mutant)
        except wire.WireError:
            pass


def test_binary_http_commit_retry_and_reject_json(player, monkeypatch, tmp_path):
    from test_replay import begin, worker, body, op
    s, d = begin(player, monkeypatch)
    ops = [op(1, d['replay_meta']['at'], 'drop', **{'from': 28, 'to': 29})]
    expected = worker(dict(mode='replay', data=d, ops=ops))
    req = body(s, expected, ops)
    compressed = base64.b64decode(encoded([req], tmp_path)[0]['gzip'])
    headers = {**player.h(), 'Content-Type': wire.MIME, 'Content-Encoding': 'gzip'}
    r = player.c.post('/v2/sync', content=compressed, headers=headers)
    assert r.status_code == 200, r.text
    ack = r.json()
    assert not ack['reset'] and ack['hash'] == expected['hash'] and 'data' not in ack
    assert player.c.post('/v2/sync', content=compressed, headers=headers).json() == ack
    assert player.c.post('/v2/sync', json=req, headers=player.h()).status_code == 415
    # Recovery still returns the confirmed snapshot.
    req['base'] = ack['version']; req['batch'] = 'ab' * 16; req['hash'] = '0' * 64
    req['ops'] = [op(2, d['replay_meta']['at'], 'drop', **{'from': 29, 'to': 28})]
    compressed = base64.b64decode(encoded([req], tmp_path)[0]['gzip'])
    reset = player.c.post('/v2/sync', content=compressed, headers=headers).json()
    assert reset['reset'] and reset['data']


def test_corrupt_http_payloads_are_bounded_before_replay(player):
    headers = {**player.h(), 'Content-Type': wire.MIME, 'Content-Encoding': 'gzip'}
    for data in [b'bad gzip', gzip.compress(b'broken'), gzip.compress(b'A' * (wire.MAX_RAW + 1))]:
        r = player.c.post('/v2/sync', content=data, headers=headers)
        assert r.status_code == 400 and r.json()['error'] == 'invalid_replay_wire'
    headers.pop('Content-Encoding')
    assert player.c.post('/v2/sync', content=b'TRP1', headers=headers).status_code == 415


def test_trp1_known_vector(tmp_path):
    # This fixed vector detects accidental changes to current opcode numbers
    # or field order even when the sender and receiver share a changed registry.
    body = {'base': 0, 'rules': '00' * 32, 'hash': '11' * 32, 'batch': '22' * 16, 'ops': [
        {'seq': 1, 'at': 1000, 'name': 'drop', 'args': {'from': 1, 'to': 2}},
        {'seq': 2, 'at': 1005, 'name': 'pack', 'args': {}},
    ]}
    golden = (b'TRP1\x00' + bytes.fromhex('00' * 32 + '11' * 32 + '22' * 16)
              + bytes.fromhex('01 e8 07 02 00 00 01 03 02 04 05 12 00'))
    actual = base64.b64decode(encoded([body], tmp_path)[0]['raw'])
    assert actual == golden and wire.decode(golden) == body
