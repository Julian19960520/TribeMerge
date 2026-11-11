"""Whole-snapshot cloud saves: upload, adopt, device conflicts, integrity and plausibility flags."""
import base64
import gzip

from sqlalchemy import select
from sqlalchemy.orm import Session

from app import clock
from app.db import engine
from app.models import Account, AuditLog, SaveBackup
from conftest import Player, save_body, snapshot, unpack


def transfer(client, player, device):
    code = player.post('/v1/account/transfer-code').json()['code']
    response = client.post('/v1/auth/transfer', json={'account_id': player.id, 'code': code, 'device_id': device})
    assert response.status_code == 200, response.text
    other = Player.__new__(Player)
    other.c, other.id, other.token = client, player.id, response.json()['token']
    return other


def test_new_account_has_no_cloud_save(player):
    session = player.post('/v2/session').json()
    assert session['ok'] and session['version'] == 0 and session['data'] == '' and not session['mine']


def test_upload_then_session_returns_the_same_bytes(player):
    state = snapshot(level=2, builds={'fire': 1})
    ack = player.upload(state, 0).json()
    assert ack['ok'] and not ack['conflict'] and ack['version'] == 1
    session = player.post('/v2/session').json()
    assert session['version'] == 1 and session['hash'] == ack['hash'] and session['mine']
    assert unpack(session['data']) == state
    again = player.upload(state, 1).json()
    assert again['version'] == 1 and not again['conflict']


def test_same_device_overwrites_even_with_a_stale_base(player):
    player.upload(snapshot(level=2), 0)
    # Response for version 1 was lost; the device retries from base 0 with newer progress.
    ack = player.upload(snapshot(level=3), 0).json()
    assert not ack['conflict'] and ack['version'] == 2
    assert unpack(player.post('/v2/session').json()['data'])['level'] == 3


def test_other_device_save_wins_over_a_stale_upload(client, player):
    player.upload(snapshot(level=2), 0)
    other = transfer(client, player, 'device-B')
    session = other.post('/v2/session').json()
    assert session['version'] == 1 and not session['mine']
    assert not other.upload(snapshot(level=4), 1).json()['conflict']
    # Device B now owns version 2; an upload from a fresh device-C session based on v1 must adopt the cloud.
    third = transfer(client, other, 'device-C')
    conflict = third.upload(snapshot(level=1), 1).json()
    assert conflict['conflict'] and conflict['version'] == 2 and unpack(conflict['data'])['level'] == 4
    assert unpack(third.post('/v2/session').json()['data'])['level'] == 4


def test_old_device_cannot_upload_after_transfer(client, player):
    player.upload(snapshot(level=2), 0)
    transfer(client, player, 'device-B')
    response = player.upload(snapshot(level=9), 1)
    assert response.status_code == 401 and response.json()['error'] == 'session_replaced'


def test_integrity_and_format_errors(player):
    body = save_body(snapshot(), 0)
    assert player.post('/v2/save', {**body, 'hash': '0' * 64}).json()['error'] == 'save_hash_mismatch'
    assert player.post('/v2/save', {**body, 'data': 'not base64!'}).json()['error'] == 'invalid_save'
    raw_gzip = base64.b64encode(b'plain bytes').decode()
    assert player.post('/v2/save', {**body, 'data': raw_gzip}).json()['error'] == 'invalid_save'
    wrong_schema = save_body({**snapshot(), 'schema': 2}, 0)
    assert player.post('/v2/save', wrong_schema).json()['error'] == 'invalid_save'
    bomb = base64.b64encode(gzip.compress(b' ' * (2 * 1024 * 1024))).decode()
    assert player.post('/v2/save', {**body, 'data': bomb}).json()['error'] == 'save_too_big'
    assert player.post('/v2/session').json()['version'] == 0


def test_backups_keep_previous_versions(player):
    for version in range(5):
        player.upload(snapshot(level=1 + version), version)
    with Session(engine()) as db:
        recent = db.scalars(select(SaveBackup).where(SaveBackup.kind == 'recent')).all()
        assert sorted(backup.version for backup in recent) == [2, 3, 4]
        assert db.scalar(select(SaveBackup).where(SaveBackup.kind == 'daily')) is not None


def test_ranking_uses_uploaded_builds(player):
    player.upload(snapshot(level=3, builds={'fire': 2}), 0)
    top = player.get('/v1/rank/top').json()
    assert top['top'][0]['id'] == player.id and top['top'][0]['progress'] == 2


def test_implausible_jump_flags_account_and_leaves_ranking(player):
    player.upload(snapshot(level=2, amber=10, builds={'fire': 1}), 0)
    clock.offset = 600
    ack = player.upload(snapshot(level=2, amber=99999, builds={'fire': 2}), 1).json()
    assert ack['ok'] and ack['version'] == 2  # flagged, never rejected
    with Session(engine()) as db:
        account = db.get(Account, player.id)
        assert account.flagged and 'amber' in account.flag_reason
        assert db.scalar(select(AuditLog).where(AuditLog.kind == 'save_flagged')) is not None
    top = player.get('/v1/rank/top').json()
    assert top['total'] == 0 and top['me'] is None


def test_steady_progress_is_not_flagged(player):
    player.upload(snapshot(level=2, amber=10), 0)
    clock.offset = 2 * 3600
    player.upload(snapshot(level=8, amber=900, shells=30000), 1)
    with Session(engine()) as db:
        assert not db.get(Account, player.id).flagged
