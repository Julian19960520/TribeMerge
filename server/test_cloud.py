"""云存档服务器自测：在临时目录起一个独立实例，跑注册/上传/冲突/校验/热卖。不碰 rank.db。"""

import base64
import gzip
import hashlib
import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

PORT = 18766
BASE = "http://127.0.0.1:%d" % PORT


def call(path, body=None, token=""):
    data = None if body is None else json.dumps(body).encode("utf-8")
    req = urllib.request.Request(BASE + path, data=data, headers={"Content-Type": "application/json", "X-Token": token})
    try:
        with urllib.request.urlopen(req, timeout=3) as r:
            return r.status, json.loads(r.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read().decode("utf-8"))


def pack(snap):
    raw = json.dumps(snap).encode("utf-8")
    return base64.b64encode(gzip.compress(raw)).decode("ascii"), hashlib.md5(raw).hexdigest()


def snap(pid, **kw):
    d = {"player_id": pid, "board": [{"id": "fruit_1", "lock": 0}], "stash": [], "level": 3, "amber": 100,
         "energy": 50, "energy_buys": 0, "deals_day": "", "builds": {"fire": 1},
         "orders": [{"items": ["fruit_6"]}, {"items": ["tool_5"]}]}
    d.update(kw)
    return d


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    tmp = tempfile.mkdtemp()
    proc = subprocess.Popen([sys.executable, os.path.join(here, "rank_server.py"), "--port", str(PORT),
                             "--db", os.path.join(tmp, "t.db")], stdout=subprocess.DEVNULL)
    try:
        for _ in range(50):
            try:
                if call("/api/health")[1].get("ok"):
                    break
            except OSError:
                time.sleep(0.1)
        code, r = call("/api/time")
        day = r["day"]
        assert code == 200 and len(day) == 10
        code, r = call("/api/register", {"id": "P1"})
        assert code == 200, r
        tok = r["token"]
        assert call("/api/register", {"id": "P1"})[0] == 409, "重复注册应拒绝"
        assert call("/api/save?id=P1", token="wrong")[0] == 403, "错 token 应拒绝"
        code, r = call("/api/save?id=P1", token=tok)
        assert code == 200 and r["version"] == 0 and r["data"] == ""
        assert call("/api/hot?id=P1", token=tok)[0] == 404, "没快照时没有热卖"

        data, h = pack(snap("P1", deals_day=day))
        code, r = call("/api/save", {"id": "P1", "base": 0, "hash": h, "data": data}, tok)
        assert code == 200 and r["version"] == 1, r
        code, r = call("/api/save", {"id": "P1", "base": 1, "hash": h, "data": data}, tok)
        assert code == 200 and r.get("same") and r["version"] == 1, "内容没变不加版本"
        code, r = call("/api/save", {"id": "P1", "base": 0, "hash": h, "data": data}, tok)
        assert code == 409 and r["version"] == 1, "落后的版本应拒绝"

        # 琥珀凭空 +5000 → 拒绝
        data, h = pack(snap("P1", deals_day=day, amber=5100))
        code, r = call("/api/save", {"id": "P1", "base": 1, "hash": h, "data": data}, tok)
        assert code == 422 and "琥珀" in r["reason"], r
        # 充值 5000 到账后放行
        assert call("/api/purchase", {"id": "P1", "amber": 5000}, tok)[0] == 200
        code, r = call("/api/save", {"id": "P1", "base": 1, "hash": h, "data": data}, tok)
        assert code == 200 and r["version"] == 2, r
        # 体力暴涨 → 拒绝；买 3 次火种 → 放行
        data, h = pack(snap("P1", deals_day=day, amber=5100, energy=500))
        code, r = call("/api/save", {"id": "P1", "base": 2, "hash": h, "data": data}, tok)
        assert code == 422 and "体力" in r["reason"], r
        data, h = pack(snap("P1", deals_day=day, amber=5100, energy=500, energy_buys=3))
        code, r = call("/api/save", {"id": "P1", "base": 2, "hash": h, "data": data}, tok)
        assert code == 200, r
        # 未来日期 → 拒绝
        data, h = pack(snap("P1", deals_day="2999-01-01", amber=5100, energy=500, energy_buys=3))
        assert call("/api/save", {"id": "P1", "base": 3, "hash": h, "data": data}, tok)[0] == 422
        # 备份只留 3 份
        for k in range(3):
            data, h = pack(snap("P1", deals_day=day, amber=5100 - k - 1, energy=500, energy_buys=3))
            assert call("/api/save", {"id": "P1", "base": 3 + k, "hash": h, "data": data}, tok)[0] == 200
        code, r = call("/api/save?id=P1", token=tok)
        assert r["version"] == 6
        got = json.loads(gzip.decompress(base64.b64decode(r["data"])))
        assert got["amber"] == 5097

        # 热卖：一天只抽一次
        code, a = call("/api/hot?id=P1", token=tok)
        assert code == 200 and a["rolled"] and a["day"] == day, a
        code, b = call("/api/hot?id=P1", token=tok)
        assert code == 200 and not b["rolled"] and b["picks"] == a["picks"]
        for p in a["picks"]:
            assert p["id"] in ("fruit_4", "fruit_5", "tool_3", "tool_4"), p
        print("热卖 picks:", a["picks"])
    finally:
        proc.terminate()
        proc.wait()
    import sqlite3
    db = sqlite3.connect(os.path.join(tmp, "t.db"))
    n = db.execute("SELECT COUNT(*) FROM save_backups WHERE id = 'P1'").fetchone()[0]
    logs = db.execute("SELECT COUNT(*) FROM cheat_log").fetchone()[0]
    db.close()
    assert n == 3, n
    assert logs == 3, logs
    print("cloud server OK")


if __name__ == "__main__":
    main()
