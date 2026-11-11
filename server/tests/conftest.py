"""Fresh current-schema SQLite database and an authenticated test client."""
import base64
import gzip
import json
import os
import sys
import uuid

import pytest

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, HERE)


@pytest.fixture()
def client(tmp_path, monkeypatch):
    monkeypatch.setenv('TRIBE_DATABASE_URL', 'sqlite:///' + (tmp_path / 'test.db').as_posix())
    monkeypatch.setenv('TRIBE_ENV', 'test')
    monkeypatch.setenv('TRIBE_LOG_JSON', 'false')
    monkeypatch.setenv('TRIBE_LOG_LEVEL', 'WARNING')
    from app import clock, config, services
    config.get_settings.cache_clear()
    services.build_limits.cache_clear()
    clock.offset = 0.0
    from alembic import command
    from alembic.config import Config
    command.upgrade(Config(os.path.join(HERE, 'alembic.ini')), 'head')
    from app.ratelimit import limiter
    limiter.reset()
    from fastapi.testclient import TestClient
    from app.main import create_app
    with TestClient(create_app()) as instance:
        yield instance
    clock.offset = 0.0


def unpack(data):
    return json.loads(gzip.decompress(base64.b64decode(data)))


def snapshot(**fields):
    state = {'schema': 1, 'level': 1, 'xp': 0, 'amber': 0, 'shells': 0, 'builds': {}, 'cards': {}, 'board': []}
    state.update(fields)
    return state


def save_body(state, base):
    import hashlib
    raw = json.dumps(state, separators=(',', ':')).encode('utf-8')
    return {'base': base, 'hash': hashlib.sha256(raw).hexdigest(),
            'data': base64.b64encode(gzip.compress(raw)).decode('ascii')}


class Player:
    def __init__(self, client, device='device-A'):
        self.c = client
        response = client.post('/v1/auth/guest', json={'device_id': device})
        assert response.status_code == 200, response.text
        self.id, self.token = response.json()['account_id'], response.json()['token']

    def h(self):
        return {'Authorization': 'Bearer ' + self.token}

    def get(self, path, **kwargs):
        return self.c.get(path, headers=self.h(), **kwargs)

    def post(self, path, json=None, **kwargs):
        return self.c.post(path, json=json, headers=self.h(), **kwargs)

    def upload(self, snapshot, base, **kwargs):
        return self.post('/v2/save', save_body(snapshot, base), **kwargs)


@pytest.fixture()
def player(client):
    return Player(client)
