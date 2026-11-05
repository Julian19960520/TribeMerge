"""每个测试一个全新的 SQLite 库（用 alembic upgrade head 建表，顺便验证迁移），一个 TestClient。"""

import base64
import gzip
import hashlib
import json
import os
import sys
import uuid

import pytest

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, HERE)


@pytest.fixture()
def client(tmp_path, monkeypatch):
    db = tmp_path / "t.db"
    monkeypatch.setenv("TRIBE_DATABASE_URL", "sqlite:///" + db.as_posix())
    monkeypatch.setenv("TRIBE_ENV", "test")
    monkeypatch.setenv("TRIBE_LOG_JSON", "false")
    monkeypatch.setenv("TRIBE_LOG_LEVEL", "WARNING")
    from app import clock, config, services
    config.get_settings.cache_clear()
    services.gamedata.cache_clear()
    services.economy_cfg.cache_clear()
    clock.offset = 0.0
    from alembic import command
    from alembic.config import Config
    command.upgrade(Config(os.path.join(HERE, "alembic.ini")), "head")
    from app.ratelimit import limiter
    limiter.reset()
    from fastapi.testclient import TestClient
    from app.main import create_app
    with TestClient(create_app()) as c:
        yield c
    clock.offset = 0.0


class Player:
    """测试里的一台设备 + 一个账号。"""

    def __init__(self, client, player_id=None, device="dev-A"):
        self.c = client
        r = client.post("/v1/auth/guest", json={"device_id": device, **({"player_id": player_id} if player_id else {})})
        assert r.status_code == 200, r.text
        self.id = r.json()["account_id"]
        self.token = r.json()["token"]
        self.version = 0

    def h(self, idem=True):
        out = {"Authorization": "Bearer " + self.token}
        if idem:
            out["Idempotency-Key"] = uuid.uuid4().hex
        return out

    def get(self, path, **kw):
        return self.c.get(path, headers=self.h(False), **kw)

    def post(self, path, json=None, key=None):
        h = self.h()
        if key:
            h["Idempotency-Key"] = key
        return self.c.post(path, json=json, headers=h)

    def snapshot(self, **kw):
        from app import clock
        d = {"player_id": self.id, "board": [{"id": "", "lock": 0} for _ in range(63)], "stash": [], "inv": [],
             "orders": [], "energy": 100, "rush": 0, "energy_stamp": clock.now(), "level": 1, "amber": 80}
        d.update(kw)
        return d

    def put(self, snap, events=(), base=None):
        raw = json.dumps(snap).encode("utf-8")
        body = {"base": self.version if base is None else base, "hash": hashlib.md5(raw).hexdigest(),
                "data": base64.b64encode(gzip.compress(raw)).decode(), "events": list(events)}
        r = self.c.put("/v1/save", json=body, headers=self.h(False))
        if r.status_code == 200:
            self.version = r.json()["version"]
        return r


@pytest.fixture()
def player(client):
    return Player(client)


def ev(type_, **kw):
    return {"id": uuid.uuid4().hex, "type": type_, **kw}
