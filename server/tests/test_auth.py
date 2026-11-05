from conftest import Player


def test_guest_and_account(client, player):
    r = player.get("/v1/account")
    assert r.status_code == 200
    j = r.json()
    assert j["account_id"] == player.id and j["bindings"] == [] and not j["has_transfer_code"]


def test_guest_keeps_existing_player_id(client):
    a = Player(client, player_id="TRB12345678")
    assert a.id == "TRB12345678"
    b = Player(client, player_id="TRB12345678")  # 被占用了就换一个
    assert b.id != "TRB12345678"


def test_missing_or_bad_token(client):
    assert client.get("/v1/account").json()["error"] == "unauthorized"
    r = client.get("/v1/account", headers={"Authorization": "Bearer nope"})
    assert r.status_code == 401 and r.json()["error"] == "unauthorized"


def test_error_format(client, player):
    r = player.post("/v1/build", json={"area": "fire", "extra": 1})
    assert r.status_code == 422
    j = r.json()
    assert j["ok"] is False and j["error"] == "invalid_request" and "message" in j


def test_refresh_revokes_old_token(client, player):
    old = player.token
    r = client.post("/v1/auth/refresh", headers={"Authorization": "Bearer " + old})
    assert r.status_code == 200
    player.token = r.json()["token"]
    assert player.get("/v1/account").status_code == 200
    r = client.get("/v1/account", headers={"Authorization": "Bearer " + old})
    assert r.status_code == 401 and r.json()["error"] == "session_revoked"


def test_token_expiry(client, player):
    from app import clock
    clock.offset = 31 * 86400
    r = player.get("/v1/account")
    assert r.status_code == 401 and r.json()["error"] == "token_expired"


def test_transfer_code_moves_account_and_kicks_old_device(client, player):
    code = player.post("/v1/account/transfer-code").json()["code"]
    assert player.get("/v1/account").json()["has_transfer_code"]
    r = client.post("/v1/auth/transfer", json={"account_id": player.id, "code": code.lower(), "device_id": "dev-B"})
    assert r.status_code == 200, r.text
    assert r.json()["account_id"] == player.id and r.json()["cloud"]["level"] == 1
    tok_b = r.json()["token"]
    assert client.get("/v1/account", headers={"Authorization": "Bearer " + tok_b}).status_code == 200
    r = player.get("/v1/account")
    assert r.status_code == 401 and r.json()["error"] == "session_replaced"


def test_transfer_code_regenerate_invalidates_old(client, player):
    old = player.post("/v1/account/transfer-code").json()["code"]
    player.post("/v1/account/transfer-code")
    r = client.post("/v1/auth/transfer", json={"account_id": player.id, "code": old})
    assert r.status_code == 401


def test_transfer_code_lockout(client, player):
    code = player.post("/v1/account/transfer-code").json()["code"]
    for _ in range(5):
        assert client.post("/v1/auth/transfer", json={"account_id": player.id, "code": "WRONG-CODE1"}).status_code == 401
    r = client.post("/v1/auth/transfer", json={"account_id": player.id, "code": code})
    assert r.status_code == 429 and r.json()["error"] in ("transfer_locked", "rate_limited")


def test_mock_provider_bind_and_login(client, player):
    assert client.post("/v1/auth/provider", json={"provider": "mock", "credential": "mock:alice"}).status_code == 404
    r = client.post("/v1/account/bind", json={"provider": "mock", "credential": "mock:alice"},
                    headers={"Authorization": "Bearer " + player.token})
    assert r.status_code == 200
    assert player.get("/v1/account").json()["bindings"] == ["mock"]
    other = Player(client, device="dev-B")
    r = client.post("/v1/account/bind", json={"provider": "mock", "credential": "mock:alice"},
                    headers={"Authorization": "Bearer " + other.token})
    assert r.status_code == 409 and r.json()["error"] == "bound_elsewhere"
    r = client.post("/v1/auth/provider", json={"provider": "mock", "credential": "mock:alice", "device_id": "dev-C"})
    assert r.status_code == 200 and r.json()["account_id"] == player.id
    assert player.get("/v1/account").json()["error"] == "session_replaced"
    r = client.post("/v1/auth/provider", json={"provider": "apple", "credential": "x"})
    assert r.status_code == 501


def test_player_rate_limit(client, player):
    from app.config import get_settings
    get_settings().rate_player_per_min = 3
    codes = [player.get("/v1/account").status_code for _ in range(5)]
    assert codes[:3] == [200, 200, 200] and codes[3] == 429


def test_body_size_limit(client, player):
    r = client.put("/v1/save", content=b"x" * (200 * 1024), headers={"Authorization": "Bearer " + player.token,
                                                                       "Content-Type": "application/json"})
    assert r.status_code == 413 and r.json()["error"] == "too_big"


def test_health(client):
    r = client.get("/v1/health")
    assert r.status_code == 200 and r.json()["db"] is True and len(r.json()["day"]) == 10
