"""读取游戏配置 data/*.json（和客户端同一份），提供和 Data.gd / OrderRoll.gd 一致的计算。

文件改了会按修改时间自动重读。
"""

import json
import os
import threading
from pathlib import Path

CURRENCY = {"energy", "shell", "amber", "sand"}


def _load(path: Path, default):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return default


class GameData:
    FILES = ["chains", "lines", "dishes", "store", "rules", "story", "levels", "pass", "builds", "albums",
             "board", "amber_packs", "people", "store_shell", "merge_events", "choice_chests", "seven_day", "daily_deals", "ufo_offer"]

    def __init__(self, data_dir: str):
        self.dir = Path(data_dir)
        self._stamp: list = []
        self._lock = threading.Lock()
        self.reload()

    def reload(self, force: bool = False) -> None:
        stamp = []
        for f in self.FILES:
            try:
                stamp.append(os.path.getmtime(self.dir / f"{f}.json"))
            except OSError:
                stamp.append(0)
        if stamp == self._stamp and not force:
            return
        with self._lock:
            g = lambda n, d: _load(self.dir / f"{n}.json", d)
            self.chains = {c["id"]: c for c in g("chains", []) if isinstance(c, dict) and c.get("id")}
            self.lines = [l for l in g("lines", []) if isinstance(l, dict)]
            self.dishes = {d["id"]: d for d in g("dishes", []) if isinstance(d, dict) and d.get("id")}
            self.store = [d for d in g("store", []) if isinstance(d, dict)]
            ss = g("store_shell", {})
            ss = ss if isinstance(ss, dict) else {}
            self.store_shell = [d for d in ss.get("items", []) if isinstance(d, dict)]
            self.shell_refresh_amber = max(1, int(ss.get("refresh_amber", 5)))
            self.shell_refresh_hours = max(1, int(ss.get("refresh_hours", 8) or 8))
            self.rules = g("rules", {})
            self.story = {}
            for lv in g("story", {"levels": []}).get("levels", []):
                rows = []
                for o in lv.get("orders", []):
                    rw = [str(x) for x in o.get("rewards", []) if str(x)] if isinstance(o.get("rewards"), list) \
                        else ["pack_1"] * int(o.get("pack", 0))
                    rows.append({"items": [str(x) for x in o.get("items", [])], "xp": int(o.get("xp", 0)),
                                 "shell": int(o.get("shell", 0)), "token": int(o.get("token", 0)), "rewards": rw})
                self.story[int(lv["level"])] = rows
            self.level_rewards = {}
            for row in g("levels", {"levels": []}).get("levels", []):
                self.level_rewards[int(row.get("level", 0))] = [
                    [str(r[0]), max(1, int(r[1]))] for r in row.get("rewards", []) if isinstance(r, list) and len(r) >= 2 and str(r[0])
                ]
            self.pass_levels = g("pass", {"levels": []}).get("levels", [])
            self.builds = [b for b in g("builds", []) if isinstance(b, dict)]
            self.albums = g("albums", [])
            self.board = g("board", {})
            self.amber_packs = g("amber_packs", [])
            self.people = g("people", [])
            self.merge_events = g("merge_events", {"seasons": []})
            self.seven_day = g("seven_day", {})
            self.daily_deals = g("daily_deals", [])
            self.ufo_offer = g("ufo_offer", {})
            self.choice_chests = g("choice_chests", {})
            self._stamp = stamp

    # ------------------------------------------------------------ 物品

    @staticmethod
    def chain(iid: str) -> str:
        return iid.split("_")[0]

    def lv(self, iid: str) -> int:
        if iid in self.dishes:
            return 1
        try:
            return int(iid.split("_")[1])
        except (IndexError, ValueError):
            return 0

    def type_of(self, iid: str) -> str:
        if iid in self.dishes:
            return "dish"
        return str(self.chains.get(self.chain(iid), {}).get("type", ""))

    def max_lv(self, ch: str) -> int:
        return len(self.chains.get(ch, {}).get("items", []))

    def valid_item(self, iid: str) -> bool:
        if iid in self.dishes:
            return True
        ch = self.chain(iid)
        return ch in self.chains and 1 <= self.lv(iid) <= self.max_lv(ch)

    def value_of(self, iid: str) -> int:
        c = self.chains.get(self.chain(iid), {})
        v = c.get("value")
        lv = self.lv(iid)
        if isinstance(v, list) and 1 <= lv <= len(v):
            return int(v[lv - 1])
        return 0

    @staticmethod
    def units(lv: int) -> int:
        """货币物品折成 1 级的个数：合成两个 n 级得一个 n+1 级，所以 n 级 = 2^(n-1) 个 1 级，合成前后不变。"""
        return 1 << max(0, lv - 1)

    def is_goods(self, iid: str) -> bool:
        return bool(iid) and iid not in self.dishes and self.chains.get(self.chain(iid), {}).get("type") == "item"

    def line_of(self, iid: str) -> str:
        return str(self.chains.get(self.chain(iid), {}).get("line", ""))

    # ------------------------------------------------------------ 等级 / 产线

    def xp_need(self, level: int) -> int:
        base = int(self.rules.get("xp_base", 3))
        div = max(1, int(self.rules.get("xp_div", 2)))
        return max(1, base + (max(level, 1) - 1) // div)

    def unlocked_lines(self, level: int) -> list:
        return [l for l in self.lines if int(l.get("unlock", 1)) <= level]

    def card_level(self) -> int:
        return 8

    def first_prod_id(self, line: dict) -> str:
        ch = str(line.get("gen", ""))
        prod = self.chains.get(ch, {}).get("prod", [])
        for i, slot in enumerate(prod or []):
            if isinstance(slot, dict) and any(isinstance(d, dict) and d.get("id") and int(d.get("p", 0)) > 0 for d in slot.get("drops", [])):
                return "%s_%d" % (ch, i + 1)
        return ""

    def rewards_for_level(self, level: int) -> list:
        if level in self.level_rewards:
            return [list(r) for r in self.level_rewards[level]]
        out = [["fire_2", 30 + level * 10], ["chest_1", 1]]
        if level >= self.card_level():
            out.append(["pack_1", 1])
        fresh = next((l for l in self.lines if int(l.get("unlock", 0)) == level), None)
        if fresh:
            pid = self.first_prod_id(fresh)
            if pid:
                out.append([pid, 1])
        elif level % 3 == 0:
            op = self.unlocked_lines(level)
            if op:
                out.append(["%s_1" % op[(level // 3) % len(op)]["gen"], 1])
        else:
            out.append(["amber_3", 5])
        return out

    # ------------------------------------------------------------ 理论火苗（OrderRoll.flames）

    def is_sub(self, ch: str) -> bool:
        return any(str(l.get("sub", "")) == ch for l in self.lines)

    def sub_percent(self, ch: str) -> float:
        needle = "%s_1" % ch
        for l in self.lines:
            if str(l.get("sub", "")) != ch:
                continue
            s, n = 0.0, 0
            for slot in self.chains.get(str(l.get("gen", "")), {}).get("prod", []) or []:
                if not isinstance(slot, dict):
                    continue
                for d in slot.get("drops", []) or []:
                    if isinstance(d, dict) and str(d.get("id", "")) == needle and int(d.get("p", 0)) > 0:
                        s += float(d["p"])
                        n += 1
            if n > 0:
                return s / n
        return 5.0

    def flames(self, iid: str) -> float:
        ch = self.chain(iid)
        if not iid or ch not in self.chains:
            return 0.0
        base = float(1 << max(0, self.lv(iid) - 1))
        if self.is_sub(ch):
            p = self.sub_percent(ch)
            return base * 100.0 / (p if p > 0 else 5.0)
        return base

    # ------------------------------------------------------------ 建造 / 通行证

    def build_def(self, bid: str) -> dict:
        return next((b for b in self.builds if str(b.get("id", "")) == bid), {})

    def build_parts(self, b: dict) -> list:
        if isinstance(b.get("parts"), list):
            return b["parts"]
        rw = b.get("rewards", [])
        return [{"cost": 60 + k * 45, "rewards": rw[k] if isinstance(rw, list) and k < len(rw) else []}
                for k in range(int(b.get("stages", 0)))]

    def build_unlock(self, b: dict) -> int:
        if "unlock" in b:
            return max(1, int(b["unlock"]))
        line = str(b.get("line", ""))
        for l in self.lines:
            if str(l.get("id", "")) == line:
                return max(1, int(l.get("unlock", 1)))
        return 1

    def rank_progress(self, builds: dict) -> int:
        n = 0
        for b in self.builds:
            n += max(0, min(int(builds.get(str(b.get("id", "")), 0) or 0), len(self.build_parts(b))))
        return n

    def pass_need(self, i: int) -> int:
        if not self.pass_levels:
            return 8
        i = max(0, min(i, len(self.pass_levels) - 1))
        return max(1, int(self.pass_levels[i].get("need", 8)))

    def pass_cursor(self, pts: int) -> dict:
        left = pts
        n = len(self.pass_levels)
        for i in range(n):
            need = self.pass_need(i)
            if left < need:
                return {"reached": i, "need": need, "extra": 0}
            left -= need
        if n == 0:
            return {"reached": 0, "need": 8, "extra": 0}
        tail = self.pass_need(n - 1)
        return {"reached": n, "need": tail, "extra": left}

    # ------------------------------------------------------------ 新局棋盘

    def initial_board_units(self) -> dict:
        """新局棋盘上已有的货币物品和气泡奖励里的货币物品，折成 1 级个数（这些是初始额度）。"""
        out: dict = {}
        for iid in self.board.get("cells", []) or []:
            iid = str(iid)
            if iid and self.type_of(iid) in CURRENCY:
                t = self.type_of(iid)
                out[t] = out.get(t, 0) + self.units(self.lv(iid))
        return out

    def bubble_reward(self, cell: int):
        """新局棋盘第 cell 格（按 data/board.json 的下标）的气泡奖励 [id, n]，没有返回 None。"""
        raw = self.board.get("rewards", {})
        r = None
        if isinstance(raw, dict):
            r = raw.get(str(cell))
        elif isinstance(raw, list) and 0 <= cell < len(raw):
            r = raw[cell]
        if isinstance(r, list) and len(r) >= 2 and str(r[0]) and int(r[1]) >= 1:
            return [str(r[0]), int(r[1])]
        return None
