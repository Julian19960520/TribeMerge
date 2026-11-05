"""石器部落 · 合成 —— 云存档 + 热卖货单（挂在 rank_server.py 上，共用一个 SQLite）。

只用标准库。规则说明见 DESIGN.md「十二、云存档」，配置在 cloud_config.json。

接口（需要鉴权的都带请求头 X-Token）：
  POST /api/register  {"id"}                          → {"ok", "token"}；id 已被注册 → 409
  GET  /api/save?id=                                  → {"ok", "version", "hash", "data"(base64 gzip JSON，空串=还没传过)}
  POST /api/save      {"id", "base", "hash", "data"}  → {"ok", "version"}；base 落后 → 409 stale；校验不过 → 422 rejected
  POST /api/purchase  {"id", "amber"}                 → {"ok", "credit"}（充值到账，下一份快照放行这么多琥珀）
  GET  /api/hot?id=                                   → {"ok", "day", "picks": [{"slot", "id"}]}；还没有快照 → 404
  GET  /api/time                                      → {"ok", "now", "day"}
所有成功的返回里都带 "now"（服务器 Unix 时间）和 "day"（按 day_utc_offset_hours 算的日期）。
"""

import base64
import hmac
import json
import os
import random
import re
import secrets
import sqlite3
import threading
import time
import zlib

ID_RE = re.compile(r"^[A-Za-z0-9_\-]{1,32}$")
HASH_RE = re.compile(r"^[0-9a-f]{8,64}$")


class ApiError(Exception):
    def __init__(self, code: int, error: str, **extra):
        super().__init__(error)
        self.code = code
        self.body = {"ok": False, "error": error}
        self.body.update(extra)


def _load_json(path: str, default):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return default


class Cloud:
    def __init__(self, db: sqlite3.Connection, lock: threading.Lock, data_dir: str, cfg_path: str, log=print):
        self.db = db
        self.lock = lock
        self.data_dir = data_dir
        self.log = log
        self.cfg = _load_json(cfg_path, {})
        self._data_stamp = None
        self._reload_data()
        db.executescript(
            """
            CREATE TABLE IF NOT EXISTS saves (
                id TEXT PRIMARY KEY,
                token TEXT NOT NULL,
                version INTEGER NOT NULL DEFAULT 0,
                hash TEXT NOT NULL DEFAULT '',
                data BLOB,
                amber INTEGER NOT NULL DEFAULT 0,
                energy INTEGER NOT NULL DEFAULT 0,
                energy_buys INTEGER NOT NULL DEFAULT 0,
                level INTEGER NOT NULL DEFAULT 0,
                parts INTEGER NOT NULL DEFAULT 0,
                deals_day TEXT NOT NULL DEFAULT '',
                credit INTEGER NOT NULL DEFAULT 0,
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL
            );
            CREATE TABLE IF NOT EXISTS save_backups (
                id TEXT NOT NULL,
                version INTEGER NOT NULL,
                data BLOB NOT NULL,
                saved_at REAL NOT NULL,
                PRIMARY KEY (id, version)
            );
            CREATE TABLE IF NOT EXISTS hot_deals (
                id TEXT NOT NULL,
                day TEXT NOT NULL,
                picks TEXT NOT NULL,
                rolled_at REAL NOT NULL,
                PRIMARY KEY (id, day)
            );
            CREATE TABLE IF NOT EXISTS cheat_log (
                id TEXT NOT NULL,
                at REAL NOT NULL,
                base INTEGER NOT NULL,
                reason TEXT NOT NULL
            );
            """
        )
        db.commit()

    # ------------------------------------------------------------ 时间

    def now(self) -> float:
        return time.time()

    def day(self, t: float = None) -> str:
        if t is None:
            t = self.now()
        off = float(self.cfg.get("day_utc_offset_hours", 8)) * 3600.0
        return time.strftime("%Y-%m-%d", time.gmtime(t + off))

    def stamp(self, out: dict) -> dict:
        t = self.now()
        out["now"] = t
        out["day"] = self.day(t)
        return out

    # ------------------------------------------------------------ 游戏配置（热卖、校验要用）

    def _reload_data(self) -> None:
        files = ["chains.json", "dishes.json", "lines.json", "store.json", "rules.json"]
        stamp = []
        for f in files:
            try:
                stamp.append(os.path.getmtime(os.path.join(self.data_dir, f)))
            except OSError:
                stamp.append(0)
        if stamp == self._data_stamp:
            return
        self._data_stamp = stamp
        get = lambda f, d: _load_json(os.path.join(self.data_dir, f), d)
        self.chains = {c["id"]: c for c in get("chains.json", []) if isinstance(c, dict) and "id" in c}
        self.dishes = {d["id"] for d in get("dishes.json", []) if isinstance(d, dict) and "id" in d}
        self.lines = {l["id"]: l for l in get("lines.json", []) if isinstance(l, dict) and "id" in l}
        self.store = [d for d in get("store.json", []) if isinstance(d, dict)]
        self.rules = get("rules.json", {})

    # ------------------------------------------------------------ 鉴权

    def _row(self, pid: str):
        return self.db.execute(
            "SELECT token, version, hash, data, amber, energy, energy_buys, level, parts, deals_day, credit, updated_at "
            "FROM saves WHERE id = ?",
            (pid,),
        ).fetchone()

    def _auth(self, pid: str, token: str):
        if not ID_RE.match(pid or ""):
            raise ApiError(400, "bad id")
        row = self._row(pid)
        if row is None:
            raise ApiError(404, "unknown id")
        if not token or not hmac.compare_digest(row[0], token):
            raise ApiError(403, "bad token")
        return row

    def register(self, body: dict) -> dict:
        pid = str(body.get("id", ""))
        if not ID_RE.match(pid):
            raise ApiError(400, "bad id")
        token = secrets.token_hex(16)
        t = self.now()
        with self.lock:
            if self._row(pid) is not None:
                raise ApiError(409, "taken")
            self.db.execute("INSERT INTO saves (id, token, created_at, updated_at) VALUES (?, ?, ?, ?)", (pid, token, t, t))
            self.db.commit()
        return self.stamp({"ok": True, "token": token})

    # ------------------------------------------------------------ 存档

    def get_save(self, pid: str, token: str) -> dict:
        with self.lock:
            row = self._auth(pid, token)
        data = row[3]
        return self.stamp({
            "ok": True, "version": row[1], "hash": row[2],
            "data": base64.b64encode(data).decode("ascii") if data else "",
        })

    def _unpack(self, b64: str):
        try:
            raw = base64.b64decode(b64, validate=True)
        except (ValueError, TypeError):
            raise ApiError(400, "bad data")
        if len(raw) > int(self.cfg.get("snapshot_max_bytes", 65536)):
            raise ApiError(413, "too big")
        try:
            # wbits=47：自动识别 gzip / zlib 头
            d = zlib.decompressobj(47)
            txt = d.decompress(raw, int(self.cfg.get("snapshot_max_unpacked", 262144)))
            if d.unconsumed_tail:
                raise ApiError(413, "too big")
            snap = json.loads(txt.decode("utf-8"))
        except (zlib.error, ValueError, UnicodeDecodeError):
            raise ApiError(400, "bad data")
        if not isinstance(snap, dict) or not isinstance(snap.get("board"), list):
            raise ApiError(400, "bad data")
        return raw, snap

    def _parts(self, snap: dict) -> int:
        b = snap.get("builds")
        if not isinstance(b, dict):
            return 0
        n = 0
        for v in b.values():
            try:
                n += max(0, int(v))
            except (TypeError, ValueError):
                pass
        return n

    @staticmethod
    def _int(snap: dict, key: str) -> int:
        try:
            return int(snap.get(key, 0))
        except (TypeError, ValueError):
            return 0

    def _check(self, row, snap: dict, t: float) -> str:
        """合理性检查。返回空串表示通过，否则是拒绝原因。只看琥珀、体力、日期这几样，合成和移动不管。"""
        today = self.day(t)
        dday = str(snap.get("deals_day", ""))
        if dday > today:
            return "日期超前：存档 %s，服务器 %s" % (dday, today)
        if row[3] is None:
            return ""  # 第一份快照只登记，不比较
        c = self.cfg.get("check", {})
        hours = max(0.0, t - float(row[11])) / 3600.0
        dlv = max(0, self._int(snap, "level") - int(row[7]))
        dparts = max(0, self._parts(snap) - int(row[8]))
        # 琥珀：凭空增加
        amber = self._int(snap, "amber")
        allow = (int(row[10]) + c.get("amber_base", 60) + c.get("amber_per_hour", 40) * hours
                 + c.get("amber_per_level", 40) * dlv + c.get("amber_per_build", 30) * dparts)
        if amber - int(row[4]) > allow:
            return "琥珀 %d → %d，最多允许 +%d" % (row[4], amber, int(allow))
        # 体力：回复 + 购买 + 奖励余量
        buys = self._int(snap, "energy_buys")
        if dday == row[9]:
            if buys < int(row[6]):
                return "同一天里火种购买次数变少了：%d → %d" % (row[6], buys)
            dbuys = buys - int(row[6])
        else:
            dbuys = buys
        max_e = int(self.rules.get("max_energy", 100))
        regen = max(1, int(self.rules.get("regen_sec", 120)))
        regen_gain = min(max_e, int(hours * 3600 / regen))
        energy = self._int(snap, "energy")
        allow_e = (regen_gain + dbuys * c.get("energy_per_buy", 100) + c.get("energy_slack", 150)
                   + c.get("energy_per_level", 60) * dlv + c.get("energy_per_build", 30) * dparts)
        if energy - int(row[5]) > allow_e:
            return "体力 %d → %d，最多允许 +%d（回复 %d，购买 %d 次）" % (row[5], energy, int(allow_e), regen_gain, dbuys)
        return ""

    def put_save(self, body: dict, token: str) -> dict:
        pid = str(body.get("id", ""))
        h = str(body.get("hash", ""))
        if not HASH_RE.match(h):
            raise ApiError(400, "bad hash")
        try:
            base = int(body.get("base", -1))
        except (TypeError, ValueError):
            raise ApiError(400, "bad base")
        raw, snap = self._unpack(str(body.get("data", "")))
        if str(snap.get("player_id", "")) != pid:
            raise ApiError(400, "id mismatch")
        t = self.now()
        with self.lock:
            row = self._auth(pid, token)
            version = int(row[1])
            if base != version:
                raise ApiError(409, "stale", version=version)
            if h == row[2] and row[3] is not None:
                return self.stamp({"ok": True, "version": version, "same": True})
            reason = self._check(row, snap, t)
            if reason:
                self.db.execute("INSERT INTO cheat_log VALUES (?, ?, ?, ?)", (pid, t, base, reason))
                self.db.commit()
                self.log("[cloud] 拒绝 %s v%d：%s" % (pid, base, reason))
                raise ApiError(422, "rejected", reason=reason, version=version)
            if row[3] is not None:
                self.db.execute("INSERT OR REPLACE INTO save_backups VALUES (?, ?, ?, ?)", (pid, version, row[3], row[11]))
                keep = max(0, int(self.cfg.get("backups", 3)))
                self.db.execute(
                    "DELETE FROM save_backups WHERE id = ? AND version NOT IN "
                    "(SELECT version FROM save_backups WHERE id = ? ORDER BY version DESC LIMIT ?)",
                    (pid, pid, keep),
                )
            version += 1
            self.db.execute(
                "UPDATE saves SET version = ?, hash = ?, data = ?, amber = ?, energy = ?, energy_buys = ?, level = ?, "
                "parts = ?, deals_day = ?, credit = 0, updated_at = ? WHERE id = ?",
                (version, h, raw, self._int(snap, "amber"), self._int(snap, "energy"), self._int(snap, "energy_buys"),
                 self._int(snap, "level"), self._parts(snap), str(snap.get("deals_day", "")), t, pid),
            )
            self.db.commit()
        return self.stamp({"ok": True, "version": version})

    def purchase(self, body: dict, token: str) -> dict:
        pid = str(body.get("id", ""))
        try:
            n = int(body.get("amber", 0))
        except (TypeError, ValueError):
            raise ApiError(400, "bad amber")
        if n <= 0 or n > int(self.cfg.get("amber_credit_max", 20000)):
            raise ApiError(400, "bad amber")
        with self.lock:
            row = self._auth(pid, token)
            credit = int(row[10]) + n
            self.db.execute("UPDATE saves SET credit = ? WHERE id = ?", (credit, pid))
            self.db.commit()
        return self.stamp({"ok": True, "credit": credit})

    # ------------------------------------------------------------ 热卖

    def _is_goods(self, iid: str) -> bool:
        if not iid or iid in self.dishes:
            return False
        c = self.chains.get(iid.split("_")[0])
        return c is not None and c.get("type") == "item"

    @staticmethod
    def _lv(iid: str) -> int:
        try:
            return int(iid.split("_")[1])
        except (IndexError, ValueError):
            return 0

    def _line(self, iid: str) -> str:
        return str(self.chains.get(iid.split("_")[0], {}).get("line", ""))

    def wanted(self, snap: dict) -> list:
        """订单里要、但棋盘和储物洞里都还没有的普通物品（同 HotDeals._wanted）"""
        have = {}
        for c in snap.get("board", []):
            if isinstance(c, dict) and int(c.get("lock", 0) or 0) == 0 and c.get("id"):
                have[str(c["id"])] = have.get(str(c["id"]), 0) + 1
        for s in snap.get("stash", []) or []:
            sid = str(s.get("id", "")) if isinstance(s, dict) else str(s)
            have[sid] = have.get(sid, 0) + 1
        out = []
        for o in snap.get("orders", []) or []:
            if not isinstance(o, dict):
                continue
            for it in o.get("items", []) or []:
                iid = str(it)
                if have.get(iid, 0) > 0:
                    have[iid] -= 1
                    continue
                if self._is_goods(iid) and iid not in out:
                    out.append(iid)
        return out

    def roll(self, wanted: list, rng: random.Random) -> list:
        """同 HotDeals.roll：返回换掉的格子 [{"slot", "id"}]。价格、库存由客户端按原格算。"""
        hc = self.cfg.get("hot", {})
        odds = [max(0, int(x)) for x in hc.get("odds", [20, 55, 25])] or [1]
        n = rng.choices(range(len(odds)), weights=odds)[0] if sum(odds) > 0 else 0
        ids = [str(d.get("id", "")) for d in self.store]
        slots = [k for k, i in enumerate(ids) if self._is_goods(i)]
        pool = list(wanted)
        rng.shuffle(pool)
        used = set()
        picks = []
        min_lv = int(hc.get("min_lv", 2))
        while n > 0 and pool and slots:
            need = pool.pop()
            ch = need.split("_")[0]
            if ch in used:
                continue
            drops = [1, 2] if rng.randrange(100) < int(hc.get("drop1_chance", 60)) else [2, 1]
            iid = ""
            for dl in drops:
                lv = self._lv(need) - dl
                cand = "%s_%d" % (ch, lv)
                if lv >= min_lv and cand not in wanted:
                    iid = cand
                    break
            if not iid or iid in ids:
                continue
            at = next((k for k in slots if ids[k].split("_")[0] == ch), -1)
            if at < 0:
                at = next((k for k in slots if self._line(ids[k]) == self._line(iid)), -1)
            if at < 0:
                at = rng.choice(slots)
            slots.remove(at)
            used.add(ch)
            ids[at] = iid
            picks.append({"slot": at, "id": iid})
            n -= 1
        return picks

    def hot(self, pid: str, token: str) -> dict:
        t = self.now()
        today = self.day(t)
        with self.lock:
            row = self._auth(pid, token)
            got = self.db.execute("SELECT picks FROM hot_deals WHERE id = ? AND day = ?", (pid, today)).fetchone()
            if got is not None:
                return self.stamp({"ok": True, "picks": json.loads(got[0]), "rolled": False})
            if row[3] is None:
                raise ApiError(404, "no snapshot")
            snap = json.loads(zlib.decompress(row[3], 47).decode("utf-8"))
            self._reload_data()
            picks = self.roll(self.wanted(snap), random.SystemRandom())
            self.db.execute("INSERT INTO hot_deals VALUES (?, ?, ?, ?)", (pid, today, json.dumps(picks), t))
            # 只留最近几天的
            self.db.execute("DELETE FROM hot_deals WHERE id = ? AND day < ?", (pid, self.day(t - 7 * 86400)))
            self.db.commit()
        return self.stamp({"ok": True, "picks": picks, "rolled": True})
