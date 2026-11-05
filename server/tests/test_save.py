import base64
import gzip
import json

from conftest import Player, ev


def test_put_get_roundtrip_and_server_fields_win(client, player):
    r = player.put(player.snapshot(amber=999999, shells=999999, level=30))
    assert r.status_code == 200 and r.json()["version"] == 1
    st = r.json()["state"]
    assert st["amber"] == 80 and st["shells"] == 0 and st["level"] == 1  # 服务器字段用服务器的
    g = player.get("/v1/save").json()
    snap = json.loads(gzip.decompress(base64.b64decode(g["data"])))
    assert g["version"] == 1 and snap["amber"] == 80 and snap["level"] == 1


def test_stale_version_conflict(client, player):
    assert player.put(player.snapshot(energy=90)).status_code == 200
    r = player.put(player.snapshot(energy=80), base=0)
    assert r.status_code == 409 and r.json()["error"] == "stale" and r.json()["version"] == 1


def test_same_hash_not_stored_again(client, player):
    s = player.snapshot()
    assert player.put(s).json()["version"] == 1
    r = player.put(s)
    assert r.json().get("same") and r.json()["version"] == 1


def test_backups_recent_and_daily(client, player):
    for e in range(10, 70, 10):
        assert player.put(player.snapshot(energy=e)).status_code == 200
    from sqlalchemy import select
    from app.db import engine
    from app.models import SaveBackup
    with engine().connect() as c:
        rows = c.execute(select(SaveBackup.kind, SaveBackup.version)).all()
    recent = sorted(v for k, v in rows if k == "recent")
    daily = [v for k, v in rows if k == "daily"]
    assert recent == [3, 4, 5] and len(daily) == 1


def test_energy_spike_rejected(client, player):
    assert player.put(player.snapshot(energy=50)).status_code == 200
    r = player.put(player.snapshot(energy=500))
    assert r.status_code == 422 and "体力" in r.json()["message"]


def test_energy_purchase_allows_increase(client, player):
    assert player.put(player.snapshot(energy=50)).status_code == 200
    assert player.post("/v1/energy/buy").status_code == 200
    assert player.put(player.snapshot(energy=150)).status_code == 200


def test_regen_by_server_time(client, player):
    from app import clock
    assert player.put(player.snapshot(energy=0)).status_code == 200
    clock.offset = 120 * 30
    assert player.put(player.snapshot(energy=50)).status_code == 200  # 30 点回复 + 20 余量


def test_future_timestamps_rejected(client, player):
    from app import clock
    board = [{"id": "", "lock": 0} for _ in range(63)]
    board[3] = {"id": "basket_5", "lock": 0, "gm": {"g": "basket_5", "u": 1, "t": clock.now() + 86400}}
    r = player.put(player.snapshot(board=board))
    assert r.status_code == 422 and "时间戳" in r.json()["message"]


def test_invalid_item_rejected(client, player):
    r = player.put(player.snapshot(stash=["fruit_99"]))
    assert r.status_code == 422


def test_id_mismatch(client, player):
    r = player.put(player.snapshot(player_id="SOMEONE"))
    assert r.status_code == 400 and r.json()["error"] == "id_mismatch"


def test_adopt_old_save_once(client):
    p = Player(client, player_id="TRB00001111")
    snap = p.snapshot(amber=500, shells=1234, level=7, builds={"fire": 3}, stash=["chest_1", "amber_3"])
    r = p.put(snap)
    assert r.status_code == 200 and r.json()["state"]["amber"] == 500 and r.json()["state"]["level"] == 7
    r = p.put(p.snapshot(amber=99999, shells=1234, level=7, builds={"fire": 3}))
    assert r.json()["state"]["amber"] == 500  # 只信第一份
    assert p.post("/v1/chest/open").status_code == 200  # 快照里的宝箱算进额度


def test_events_settle_even_when_snapshot_rejected(client, player):
    assert player.put(player.snapshot(energy=50)).status_code == 200
    order = {"who": 0, "items": ["fruit_5"], "rw": {"xp": 1, "shell": 64}, "story": True, "si": 0}
    r = player.put(player.snapshot(energy=999), events=[ev("order", order=order)])
    assert r.status_code == 422 and r.json()["state"]["shells"] == 64
