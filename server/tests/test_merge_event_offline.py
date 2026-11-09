"""Offline activity input is replayed in order, with the same rewards as local play."""
import copy
import hashlib

from conftest import ev
from test_merge_event import config, mutate


def board_event(c, action, at, **args):
    return ev("merge_board", at=at, board_action={
        "season": c["key"], "action": action, "view": 9, **args,
    })


def trace(c, at):
    return [
        ev("order", at=at, order={"items": ["fruit_6"], "rw": {"shell": 1}}),
        board_event(c, "spawn", at),
        board_event(c, "drop", at, **{"from": 93, "to": 90}),
        board_event(c, "spawn", at),
        board_event(c, "drop", at, **{"from": 93, "to": 90}),
    ]


def test_offline_order_spawn_merge_and_drop_collection_are_ordered(player):
    from app import clock
    from app.services import economy
    c = config()
    mutate(player, lambda st: st.update(level=10))
    batch = trace(c, clock.now())
    # Fixed event ID gives a reproducible resource drop on both platforms.
    gd = economy().gd
    for i in range(100):
        uid = f"offline-drop-{i}"
        roll = int(hashlib.sha256(uid.encode()).hexdigest()[:8], 16) / 4294967296
        drop = gd.resource_drop("event", roll, 10)
        if drop:
            batch[-1]["id"] = uid
            break
    assert drop
    r = player.post("/v1/events", {"events": batch}).json()
    assert all(e["ok"] for e in r["events"])
    s = r["state"]["merge_events"][c["key"]]
    assert s["points"] == 0 and s["spent"] == 2 and s["earned"] == 2
    assert s["cells"][90] == {"id": "moon_2", "lock": 0}
    assert s["cells"][84]["lock"] == 1 and s["cells"][78]["lock"] == 2
    assert r["events"][-1]["give"]["drops"] == [drop]
    # Background acknowledgements don't award a second copy; collection spends
    # exactly the one resource allowance granted by the merge event.
    collected = player.post("/v1/events", {"events": [ev("collect", item=drop)]}).json()
    assert collected["events"][0]["ok"]
    retry = player.post("/v1/events", {"events": batch}).json()
    assert all(e.get("dup") for e in retry["events"])
    assert retry["state"] == collected["state"]
    assert not player.post("/v1/events", {"events": [ev("collect", item=drop)]}).json()["events"][0]["ok"]


def test_more_than_400_moves_across_batches_and_snapshot_restore(player):
    from app import clock
    from app.services import unpack
    c = config()
    mutate(player, lambda st: st.update(level=10))
    batch = trace(c, clock.now())
    at_cell = 90
    for _ in range(450):
        dest = 91 if at_cell == 90 else 90
        batch.append(board_event(c, "drop", clock.now(), **{"from": at_cell, "to": dest}))
        at_cell = dest
    for start in range(0, len(batch), 200):
        r = player.post("/v1/events", {"events": batch[start:start + 200]}).json()
        assert all(e["ok"] for e in r["events"])
    expected = copy.deepcopy(r["state"]["merge_events"])
    # Client snapshot isn't allowed to forge the replayed activity state.
    assert player.put(player.snapshot(merge_events={"forged:0": {"points": 999}})).status_code == 200
    saved = player.get("/v1/save").json()
    assert saved["state"]["merge_events"] == expected
    assert unpack(saved["data"])[1]["merge_events"] == expected
    assert expected[c["key"]]["cells"][90]["id"] == "moon_2"


def test_reconnect_after_period_end_replays_old_board_not_new_one(player, monkeypatch):
    from app import clock, merge_event
    from app.services import gamedata
    c = config()
    mutate(player, lambda st: st.update(level=10))
    batch = trace(c, c["ends_at"] - 5)
    monkeypatch.setattr(clock, "now", lambda: c["ends_at"] + 5)
    r = player.post("/v1/events", {"events": batch}).json()
    assert all(e["ok"] for e in r["events"])
    new = merge_event.current(gamedata().merge_events, clock.now())
    assert new["key"] not in r["state"]["merge_events"]
    assert r["state"]["merge_events"][c["key"]]["cells"][90]["id"] == "moon_2"
    expired = board_event(c, "spawn", clock.now())
    r = player.post("/v1/events", {"events": [expired]}).json()
    assert r["events"][0]["error"] == "event_ended"


def test_replay_cannot_claim_inflate_points_or_use_future_time(player):
    from app import clock
    c = config()
    mutate(player, lambda st: st.update(level=10))
    batch = [board_event(c, "spawn", clock.now()),
             board_event(c, "claim", clock.now()),
             board_event(c, "spawn", clock.now() + 1000)]
    r = player.post("/v1/events", {"events": batch}).json()
    assert [e["error"] for e in r["events"]] == ["not_enough_points", "bad_event", "future_event"]
    assert r["state"]["amber"] == 80
    assert r["state"]["merge_events"][c["key"]]["points"] == 0
