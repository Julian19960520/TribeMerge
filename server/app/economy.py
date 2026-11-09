"""服务器说了算的那部分存档（state）和所有改它的规则。纯函数，不碰数据库，方便测试。

state 里：
- 和客户端存档同名的字段（SERVER_FIELDS）：琥珀、贝币、等级、声望、建造、通行证、卡册、图鉴领奖、每日购买记录……
  客户端上传快照时这些字段一律用服务器的值覆盖。
- 额度（客户端存档里没有）：
  - budget：棋盘上 / 暂存里的货币物品，折成 1 级个数。只能由服务器发出来（宝箱、奖励、新局棋盘），收取时扣。
  - credits：服务器发出去还没打开的宝箱 / 卡包个数。
  - energy_credit / rush_credit：上一份快照之后服务器发的体力 / 沙漏（校验快照增量用）。
  - max_lv：快照里出现过、交过、或服务器发过的每条链最高等级（有凭据的进度）。
  - found：客户端 found 事件报上来的每条链最高等级。只用来放行图鉴领奖、丢弃退款，不抬高 max_lv，
    这样每次 found 最多只能比有凭据的进度高 1 级，改过的客户端没法一串 found 把整条链刷满。
  - done：一次性的东西（剧情单、新手单、气泡、等级奖励）。
"""

import json
import math
import random
import secrets
import datetime
import time

from .gamedata import CURRENCY, GameData

SERVER_FIELDS = [
    "duel_race",
    "ufo_offer", "offers", "gm_activities", "seven_day", "merge_events", "amber", "shells", "level", "xp", "energy_buys", "deals_day", "hot_bought", "deals_bought", "inv_cap",
    "pass_pts", "pass_tier", "pass_free", "pass_prem", "pass_super", "pass_endless", "pass_super_bonus", "pass_season",
    "tokens", "token_claimed", "builds", "cards", "book_claimed", "shell_bought", "shell_period", "hot_revision",
]


class Reject(Exception):
    """操作不允许。error 是机器可读的代码。"""

    def __init__(self, error: str, message: str, status: int = 409):
        super().__init__(error)
        self.error = error
        self.message = message
        self.status = status


def num(v, default=0) -> int:
    try:
        return int(float(v))
    except (TypeError, ValueError):
        return default


class Economy:
    def __init__(self, gd: GameData, cfg: dict, day_fn, rng: random.Random | None = None, now_fn=None, utc_offset: int = 8):
        self.gd = gd
        self.cfg = cfg
        self.day = day_fn
        self.rng = rng or random.SystemRandom()
        self.now = now_fn or time.time
        self.utc_offset = utc_offset

    # ------------------------------------------------------------ 状态

    def new_state(self) -> dict:
        np = self.cfg.get("new_player", {})
        st = {
            "amber": num(np.get("amber", 80)), "shells": num(np.get("shells", 0)), "level": num(np.get("level", 1)),
            "xp": num(np.get("xp", 0)), "energy_buys": 0, "deals_day": self.day(), "hot_bought": {}, "deals_bought": {},
            "inv_cap": num(self.gd.rules.get("storage_initial", np.get("inv_cap", 5))), "pass_pts": 0, "pass_tier": 0, "pass_free": [], "pass_prem": [], "pass_super": [],
            "pass_endless": 0, "pass_super_bonus": False, "pass_season": self.pass_season(), "tokens": 0, "token_claimed": 0,
            "builds": dict(np.get("builds", {"fire": 1})), "cards": {}, "book_claimed": {},
            "shell_bought": {}, "shell_period": self.shell_period(), "hot_revision": 0, "merge_events": {}, "ufo_offer": {}, "offers": {}, "gm_activities": False,
        }
        st.update({"budget": self.gd.initial_board_units(), "credits": {"chest": 0, "pack": 0},
                   "energy_credit": 0, "rush_credit": 0, "max_lv": {}, "done": {}, "adopted": False,
                   "orders_fp": [], "orders_used": [], "evt_seen": [], "unlisted": 0, "refunds": 0})
        locks = self.gd.board.get("locks", []) or []
        for n, iid in enumerate(self.gd.board.get("cells", []) or []):
            iid = str(iid)
            # 宝箱 / 卡包不管在不在石头下面都算额度；「见过」只算露在外面的格子
            self._seen_item(st, iid, credit=True, budget=False, seen=n < len(locks) and int(locks[n]) == 0)
        return st

    def adopt(self, st: dict, snap: dict) -> None:
        """账号的第一份快照（老存档第一次连上服务器）：服务器字段信一次客户端，额度按快照里的物品算。之后就以服务器为准。"""
        for k in SERVER_FIELDS:
            if k in snap and k not in ("duel_race", "merge_events", "seven_day", "ufo_offer", "offers", "gm_activities"):
                st[k] = snap[k]
        st["amber"] = max(0, num(st.get("amber")))
        st["shells"] = max(0, num(st.get("shells")))
        st["level"] = max(1, num(st.get("level"), 1))
        st["builds"] = {str(k): max(0, num(v)) for k, v in (st.get("builds") or {}).items()}
        st["budget"] = {}
        st["credits"] = {"chest": 0, "pack": 0}
        for iid in self.snapshot_items(snap):
            self._seen_item(st, iid, credit=True, budget=True, seen=False)
        for iid in self.snapshot_items(snap, open_only=True):
            self._seen_item(st, iid, credit=False, budget=False)
        # 还没裂开的石头气泡：这些将来会通过 bubble 事件领取，现在标记成「还没领」即可，已经没有气泡的格子当作领过
        cells = snap.get("board") or []
        for n in range(len(cells)):
            c = cells[n] if isinstance(cells[n], dict) else {}
            if not c.get("rw") and self.gd.bubble_reward(n):
                st["done"]["bubble:%d" % n] = True
        st["adopted"] = True

    def client_state(self, st: dict) -> dict:
        return {k: st.get(k) for k in SERVER_FIELDS}

    def ensure_day(self, st: dict) -> None:
        from . import seven_day
        seven_day.login(self, st)
        d = self.day()
        st.setdefault("hot_revision", 0)
        if st.get("deals_day") != d:
            st["deals_day"] = d
            st["energy_buys"] = 0
            st["hot_bought"] = {}
            st["hot_revision"] = 0
            st["deals_bought"] = {}
        self.ensure_shell(st)
        self.ensure_pass_season(st)

    # 贝币小摊每 refresh_hours 小时（按服务器时间、东八区零点对齐）换一轮，换轮时已购清零
    def shell_period(self) -> str:
        span = self.gd.shell_refresh_hours * 3600
        return str(int((self.now() + self.utc_offset * 3600) // span))

    def shell_secs_left(self) -> int:
        span = self.gd.shell_refresh_hours * 3600
        return span - int(self.now() + self.utc_offset * 3600) % span

    # 通行证赛季：从 season.start（东八区零点）起每 season.days 天一季，和客户端 Game.pass_season_now 一致
    def _pass_season_span(self) -> int:
        return max(1, int(self.gd.pass_season.get("days", 35))) * 86400

    def _pass_season_offset(self) -> int:
        start = datetime.datetime.strptime(str(self.gd.pass_season.get("start", "2026-11-02")), "%Y-%m-%d").replace(tzinfo=datetime.timezone.utc)
        return int(self.now()) + self.utc_offset * 3600 - int(start.timestamp())

    def pass_season(self) -> str:
        return str(self._pass_season_offset() // self._pass_season_span())

    def pass_secs_left(self) -> int:
        return self._pass_season_span() - self._pass_season_offset() % self._pass_season_span()

    def ensure_pass_season(self, st: dict) -> None:
        """换季：积分、已领档位、贵宾档位全部清零，上季没领的奖励作废。"""
        s = self.pass_season()
        if st.get("pass_season") == s:
            return
        st.update({"pass_season": s, "pass_pts": 0, "pass_tier": 0, "pass_free": [], "pass_prem": [], "pass_super": [],
                   "pass_endless": 0, "pass_super_bonus": False})

    def ensure_shell(self, st: dict) -> None:
        p = self.shell_period()
        if st.get("shell_period") != p:
            st["shell_period"] = p
            st["shell_bought"] = {}

    # ------------------------------------------------------------ 物品与奖励

    def snapshot_items(self, snap: dict, open_only: bool = False) -> list:
        out = []
        for c in snap.get("board") or []:
            if isinstance(c, dict) and num(c.get("lock")) != 3 and c.get("id") and not (open_only and num(c.get("lock")) != 0):
                out.append(str(c["id"]))
        for s in (snap.get("stash") or []) + (snap.get("inv") or []):
            iid = str(s.get("id", "")) if isinstance(s, dict) else str(s)
            if iid:
                out.append(iid)
        return out

    def _seen_item(self, st: dict, iid: str, credit: bool, budget: bool, seen: bool = True) -> None:
        if not self.gd.valid_item(iid):
            return
        ch = self.gd.chain(iid)
        lv = self.gd.lv(iid)
        ml = st.setdefault("max_lv", {})
        if seen and lv > num(ml.get(ch, 0)):
            ml[ch] = lv
        t = self.gd.type_of(iid)
        if budget and t in CURRENCY:
            b = st.setdefault("budget", {})
            b[t] = num(b.get(t, 0)) + self.gd.units(lv)
        if credit and t == "choice":
            key = "choice:" + iid
            credits = st.setdefault("credits", {})
            credits[key] = num(credits.get(key)) + 1
        if credit and t in ("chest", "pack"):
            c = st.setdefault("credits", {})
            key = "energybox" if iid == "energybox_1" else t
            c[key] = num(c.get(key, 0)) + 1

    def give_item(self, st: dict, iid: str, out: dict) -> None:
        """发一件实物（放进暂存区 / 棋盘）。"""
        self._seen_item(st, iid, credit=True, budget=True)
        out.setdefault("items", []).append(iid)

    def grant(self, st: dict, rewards: list, out: dict) -> dict:
        """发一组 [id, n] 奖励（和客户端 Popups 的发奖规则一样：货币类是 n 点货币，其他是 n 件实物）。
        out 收集客户端要做的事：energy / rush（客户端自己加）、items（放暂存）、levels（升了哪几级）。"""
        from . import seven_day
        for r in rewards or []:
            if not isinstance(r, (list, tuple)) or len(r) < 2:
                continue
            iid, n = str(r[0]), max(1, num(r[1], 1))
            t = self.gd.type_of(iid)
            if t in ("amber", "shell"): seven_day.record(self, st, t, n)
            if t == "amber":
                st["amber"] = num(st.get("amber")) + n
            elif t == "shell":
                st["shells"] = num(st.get("shells")) + n
            elif t == "energy":
                st["energy_credit"] = num(st.get("energy_credit")) + n
                out["energy"] = out.get("energy", 0) + n
            elif t == "sand":
                st["rush_credit"] = num(st.get("rush_credit")) + n
                out["rush"] = out.get("rush", 0) + n
            elif t == "xp":
                self.add_xp(st, n, out)
            elif t == "token":
                self.add_tokens(st, n, out)
            else:
                for _ in range(n):
                    self.give_item(st, iid, out)
        return out

    def add_xp(self, st: dict, n: int, out: dict) -> None:
        from . import seven_day
        seven_day.record(self, st, "xp", n)
        st["xp"] = num(st.get("xp")) + n
        while st["xp"] >= self.gd.xp_need(num(st.get("level"), 1)):
            st["xp"] -= self.gd.xp_need(num(st.get("level"), 1))
            st["level"] = num(st.get("level"), 1) + 1
            out.setdefault("levels", []).append(st["level"])

    def add_tokens(self, st: dict, n: int, out: dict) -> None:
        step = max(1, num(self.gd.rules.get("token_step", 10), 10))
        st["tokens"] = num(st.get("tokens")) + n
        while st["tokens"] - num(st.get("token_claimed")) >= step:
            st["token_claimed"] = num(st.get("token_claimed")) + step
            # 祭典鼓攒满：客户端自己往暂存放卡包（BoardScreen），服务器记一个卡包额度
            st["credits"]["pack"] = num(st["credits"].get("pack")) + 1
            out["packs"] = out.get("packs", 0) + 1

    def _spend(self, st: dict, kind: str, n: int) -> None:
        key = "amber" if kind == "amber" else "shells"
        if num(st.get(key)) < n:
            raise Reject("not_enough_" + kind, "琥珀不够" if kind == "amber" else "贝币不够")
        st[key] = num(st.get(key)) - n
        if kind == "amber":
            from . import seven_day
            seven_day.record(self, st, "amber_spent", n)

    # ------------------------------------------------------------ 购买（花琥珀）

    def energy_price(self, st: dict) -> int:
        r = self.gd.rules
        base, step, top = num(r.get("energy_price", 20)), num(r.get("energy_price_step", 10)), num(r.get("energy_price_max", 60))
        return min(base + step * num(st.get("energy_buys")), max(top, base))

    def buy_energy(self, st: dict) -> dict:
        self.ensure_day(st)
        self._spend(st, "amber", self.energy_price(st))
        st["energy_buys"] = num(st.get("energy_buys")) + 1
        return self.grant(st, [["fire_1", num(self.cfg.get("energy_buy", {}).get("grant", 100))]], {})

    def buy_pass(self, st: dict, tier: str) -> dict:
        """通行证只能用人民币买：走 /v1/pass/order 下单，支付回调里 activate_pass。"""
        raise Reject("pay_with_cash", "通行证需要用人民币购买")

    def pass_cny(self, st: dict, tier: str) -> int:
        """人民币价格：贵宾 30；超级贵宾 68，已经是贵宾的升级只补差价（68 - 30 = 38）。"""
        pc = self.cfg.get("pass", {})
        vip, sup = num(pc.get("vip_cny", 30)), num(pc.get("super_cny", 68))
        if tier == "vip":
            return vip
        return max(0, sup - vip) if num(st.get("pass_tier")) == 1 else sup

    def pass_price(self, st: dict, tier: str) -> str:
        """写进订单的标价，比如 ¥38。"""
        return "¥%d" % self.pass_cny(st, tier)

    def check_pass_tier(self, st: dict, tier: str) -> None:
        self.ensure_pass_season(st)
        if tier not in ("vip", "super"):
            raise Reject("bad_tier", "没有这个档位", 400)
        if num(st.get("pass_tier")) >= (1 if tier == "vip" else 2):
            raise Reject("already_owned", "已经拥有")

    def activate_pass(self, st: dict, tier: str) -> dict:
        """付款成功后开通。贵宾送火种；超级贵宾一次性加积分，从没买过直接买超级也送火种。"""
        pc = self.cfg.get("pass", {})
        out: dict = {}
        self.check_pass_tier(st, tier)  # 先换季：上季下的单在新一季付款，开通的是新一季
        cur = num(st.get("pass_tier"))
        if tier == "vip":
            st["pass_tier"] = 1
            self.grant(st, [["fire_1", num(pc.get("vip_energy", 150))]], out)
        else:
            st["pass_tier"] = 2
            if not st.get("pass_super_bonus"):
                st["pass_super_bonus"] = True
                st["pass_pts"] = num(st.get("pass_pts")) + num(pc.get("super_bonus_pts", 10))
            if cur == 0:
                self.grant(st, [["fire_1", num(pc.get("vip_energy", 150))]], out)
        return out

    def claim_pass(self, st: dict, track: str, lv: int) -> dict:
        cur = self.gd.pass_cursor(num(st.get("pass_pts")))
        n = len(self.gd.pass_levels)
        out: dict = {}
        if track in ("free", "prem", "super"):
            if lv < 1 or lv > n:
                raise Reject("bad_level", "没有这一档", 400)
            if cur["reached"] < lv:
                raise Reject("not_reached", "还没到这一档")
            key = {"free": "pass_free", "prem": "pass_prem", "super": "pass_super"}[track]
            if track == "prem" and num(st.get("pass_tier")) < 1:
                raise Reject("need_vip", "激活通行证后可领取")
            if track == "super" and num(st.get("pass_tier")) < 2:
                raise Reject("need_super", "超级贵宾可领取")
            got = [num(x) for x in st.get(key) or []]
            if lv in got:
                raise Reject("already_claimed", "已经领过了")
            st[key] = got + [lv]
            self.grant(st, self.gd.pass_levels[lv - 1].get(track, []), out)
        elif track == "endless":
            if num(st.get("pass_tier")) != 2:
                raise Reject("need_super", "超级贵宾可领取循环奖励")
            ready = 0
            if cur["reached"] >= n and cur["need"] >= 1:
                ready = max(0, cur["extra"] // cur["need"] - num(st.get("pass_endless")))
            if ready <= 0:
                raise Reject("not_reached", "还没攒够")
            st["pass_endless"] = num(st.get("pass_endless")) + 1
            self.grant(st, self.cfg.get("pass", {}).get("endless_reward", [["chest_1", 1]]), out)
        else:
            raise Reject("bad_track", "没有这一栏", 400)
        return out

    def storage_price(self, st: dict) -> int:
        rules = self.gd.rules
        return num(rules.get("storage_expand_price", 50)) + max(0, num(st.get("inv_cap"), 5) - num(rules.get("storage_initial", 5))) * num(rules.get("storage_expand_step", 10))

    def expand_storage(self, st: dict) -> dict:
        cap = num(st.get("inv_cap"), 5)
        self._spend(st, "amber", self.storage_price(st))
        st["inv_cap"] = cap + 1
        return {}

    # ------------------------------------------------------------ 集市

    def _price_like(self, iid: str, old: dict) -> int:
        oid = str(old.get("id", ""))
        of = self.gd.flames(oid)
        if self.gd.chain(oid) == self.gd.chain(iid) and of > 0 and num(old.get("price")) > 0:
            return max(2, int(math.floor(float(old["price"]) * self.gd.flames(iid) / of + 0.5)))
        sc = self.cfg.get("shop", {})
        per = float(sc.get("price_sub", 0.33)) if self.gd.is_sub(self.gd.chain(iid)) else float(sc.get("price_main", 0.6))
        return max(2, int(round(self.gd.flames(iid) * per)))

    def hot_list(self, picks: list) -> list:
        out = [dict(d) for d in self.gd.store]
        for p in picks or []:
            k, iid = num(p.get("slot"), -1), str(p.get("id", ""))
            if not (0 <= k < len(out)):
                continue
            old_id = str(out[k].get("id", ""))
            if self.gd.chain(old_id) != self.gd.chain(iid) and not (self.gd.is_goods(old_id) and self.gd.is_goods(iid)):
                continue
            if not self.gd.valid_item(iid):
                continue
            old = out[k]
            lv = self.gd.lv(iid)
            out[k] = {"id": iid, "price": self._price_like(iid, old),
                      "stock": max(1, min(num(old.get("stock"), 3), 3 if lv >= 5 else 5))}
        return out

    def offers(self, st: dict, picks: list) -> list:
        """今天集市里卖的全部：每日特惠 + 热卖（琥珀）+ 贝币小摊（贝币）。每项 {key, id, price, stock, left, cur}。"""
        self.ensure_day(st)
        rows = []
        for d in self.gd.daily_deals:
            if num(st.get("level"), 1) >= num(d.get("min_level", 0)):
                rows.append({"key": d["key"], "id": d["id"], "price": num(d["price"]), "stock": num(d["stock"]), "deal": True})
        for k, d in enumerate(self.hot_list(picks)):
            rows.append({"key": "hot_%d" % k, "id": str(d.get("id", "")), "price": num(d.get("price")),
                         "stock": num(d.get("stock")), "deal": False})
        for r in rows:
            r["cur"] = next((d.get("currency", "amber") for d in self.gd.daily_deals if d["key"] == r["key"]), "amber")
            r["book"] = "deals_bought" if r["deal"] else "hot_bought"
        for k, d in enumerate(self.gd.store_shell):
            iid = str(d.get("id", ""))
            if self.gd.valid_item(iid) and num(d.get("price")) > 0:
                rows.append({"key": "shell_%d" % k, "id": iid, "price": num(d.get("price")), "stock": num(d.get("stock")),
                             "deal": False, "cur": "shell", "book": "shell_bought"})
        for r in rows:
            book = st.get(r["book"]) or {}
            r["left"] = max(0, r["stock"] - num(book.get(r["key"], 0)))
        return rows

    def shop_buy(self, st: dict, picks: list, key: str, iid: str) -> dict:
        if key.startswith("deal_"):
            raise Reject("daily_endpoint", "请从每日商品入口领取")
        offer = next((r for r in self.offers(st, picks) if r["key"] == key), None)
        if offer is None or (iid and offer["id"] != iid):
            raise Reject("no_offer", "这件已经下架了")
        if offer["left"] <= 0:
            raise Reject("sold_out", "卖完了")
        self._spend(st, offer["cur"], offer["price"])
        book_key = offer["book"]
        book = dict(st.get(book_key) or {})
        book[key] = num(book.get(key, 0)) + 1
        st[book_key] = book
        out: dict = {}
        self.give_item(st, offer["id"], out)
        return out

    def refresh_hot(self, st: dict) -> None:
        self.ensure_day(st)
        self._spend(st, "amber", 10)
        st["hot_bought"] = {}
        st["hot_revision"] = num(st.get("hot_revision")) + 1

    # 合成泡泡 / 合成掉贝币：规则在 data/rules.json（merge_bubble / merge_coin），客户端 Data.gd 同一套算法
    def bubble_rule(self) -> dict:
        r = self.gd.rules.get("merge_bubble", {})
        return r if isinstance(r, dict) else {}

    def bubble_ok(self, iid: str) -> bool:
        if not self.gd.valid_item(iid) or self.gd.type_of(iid) != "item":
            return False
        return self.gd.flames(iid) >= float(self.bubble_rule().get("min_flames", 32))

    def bubble_price(self, iid: str) -> int:
        """k × 理论火苗^exp，按 step 取整，夹在 [price_min, price_max]。"""
        r = self.bubble_rule()
        raw = float(r.get("price_k", .6)) * max(self.gd.flames(iid), 1.0) ** float(r.get("price_exp", .8))
        step = max(1.0, float(r.get("price_step", 5)))
        p = int(math.floor(raw / step + 0.5) * step)
        return min(int(r.get("price_max", 300)), max(int(r.get("price_min", 5)), p))

    def merge_coin_item(self, merged: str) -> str:
        r = self.gd.rules.get("merge_coin", {})
        out = ""
        for t in (r.get("tiers", []) if isinstance(r, dict) else []):
            if isinstance(t, (list, tuple)) and len(t) >= 2 and self.gd.lv(merged) >= int(t[0]):
                out = str(t[1])
        return out

    def merge_coin_chance(self) -> float:
        r = self.gd.rules.get("merge_coin", {})
        return min(1.0, max(0.0, float(r.get("chance", 0)))) if isinstance(r, dict) else 0.0

    def merge_bubble(self, st: dict, iid: str) -> dict:
        if not self.gd.valid_item(iid) or self.gd.lv(iid) < 2 or self.gd.type_of(iid) == "dish":
            raise Reject("bad_item", "物品不能合成", 400)
        if st.get("tutorial_on") or not self.bubble_ok(iid):
            return {}
        self._backfill_seen(st)
        if not self._has_seen(st, iid):
            raise Reject("not_seen", "还没有合成这件物品")
        now = self.now()
        offers = {k: v for k, v in st.get("merge_bubbles", {}).items() if float(v.get("expires", 0)) > now}
        st["merge_bubbles"] = offers
        rule = self.bubble_rule()
        if len(offers) >= 63 or self.rng.random() >= float(rule.get("chance", .1)):
            return {}
        uid = secrets.token_hex(16)
        offer = {"uid": uid, "item": iid, "expires": now + float(rule.get("seconds", 60)), "price": self.bubble_price(iid)}
        offers[uid] = offer
        return {"offer": offer}

    def buy_merge_bubble(self, st: dict, uid: str) -> dict:
        offer = (st.get("merge_bubbles") or {}).get(uid)
        if not offer or float(offer.get("expires", 0)) <= self.now():
            raise Reject("expired", "泡泡已经消失了")
        if offer.get("paid"):
            raise Reject("already_bought", "已经购买过了")
        self._spend(st, "amber", num(offer["price"]))
        offer["paid"] = True
        out: dict = {}
        self.give_item(st, str(offer["item"]), out)
        return out

    # ------------------------------------------------------------ 建造 / 宝箱 / 卡包 / 图鉴 / 等级奖励

    def build(self, st: dict, bid: str) -> dict:
        b = self.gd.build_def(bid)
        if not b:
            raise Reject("unknown_build", "没有这个区域", 400)
        if num(st.get("level"), 1) < self.gd.build_unlock(b):
            raise Reject("locked", "还没开放")
        parts = self.gd.build_parts(b)
        builds = dict(st.get("builds") or {})
        stage = num(builds.get(bid, 0))
        if stage >= len(parts):
            raise Reject("done", "已经建完了")
        part = parts[stage] if isinstance(parts[stage], dict) else {}
        cost = max(0, num(part["cost"])) if "cost" in part else 60 + stage * 45
        self._spend(st, "shell", cost)
        builds[bid] = stage + 1
        st["builds"] = builds
        out = {"idx": stage}
        rw = [[str(r[0]), max(1, num(r[1], 1))] for r in part.get("rewards", []) or [] if isinstance(r, list) and len(r) >= 2 and str(r[0])]
        out["rewards"] = rw
        self.grant(st, rw, out)
        return out

    def open_chest(self, st: dict) -> dict:
        cr = st.setdefault("credits", {})
        if num(cr.get("chest")) <= 0:
            raise Reject("no_chest", "没有可以打开的宝箱")
        cr["chest"] = num(cr.get("chest")) - 1
        cc = self.cfg.get("chest", {})
        pool = list(cc.get("base_pool", ["fire_4", "shell_4", "amber_2", "sand_2"]))
        opened = self.gd.unlocked_lines(num(st.get("level"), 1))
        for l in opened:
            pool += ["%s_2" % l["main"], "%s_3" % l["main"], "%s_1" % l["sub"]]
        out: dict = {"items": []}
        for _ in range(num(cc.get("count", 3), 3)):
            if opened and self.rng.random() < float(cc.get("gen_chance", 0.1)):
                iid = "%s_1" % self.rng.choice(opened)["gen"]
            else:
                iid = self.rng.choice(pool)
            self.give_item(st, iid, out)
        return out

    def choose_chest(self, st: dict, box: str, option: int) -> dict:
        choices = self.gd.choice_chests.get(box, {}).get("choices", [])
        key = "choice:" + box
        credits = st.setdefault("credits", {})
        if num(credits.get(key)) <= 0:
            raise Reject("no_chest", "没有可以打开的自选宝箱")
        if len(choices) != 3 or not 0 <= option < 3 or not self.gd.valid_item(str(choices[option])):
            raise Reject("bad_choice", "选项无效", 400)
        credits[key] -= 1
        out = {}
        self.give_item(st, str(choices[option]), out)
        return out

    def open_pack(self, st: dict) -> dict:
        if num(st.get("level"), 1) < self.gd.card_level():
            raise Reject("locked", "典藏卡在 8 级解锁")
        cr = st.setdefault("credits", {})
        if num(cr.get("pack")) <= 0:
            raise Reject("no_pack", "没有可以打开的卡包")
        cr["pack"] = num(cr.get("pack")) - 1
        albums = self.gd.albums or []
        cards = dict(st.get("cards") or {})
        out: dict = {"cards": []}
        before = {a for a in range(len(albums)) if self._album_full(cards, a)}
        for _ in range(2):
            a = self.rng.randrange(len(albums)) if albums else 0
            c = self.rng.randrange(9)
            key = "%d_%d" % (a, c)
            cards[key] = num(cards.get(key, 0)) + 1
            out["cards"].append([a, c])
        st["cards"] = cards
        from . import seven_day
        seven_day.record(self, st, "cards", len(out["cards"]))
        for a in range(len(albums)):
            if a not in before and self._album_full(cards, a) and not st["done"].get("album:%d" % a):
                st["done"]["album:%d" % a] = True
                out.setdefault("albums_done", []).append(a)
                self.grant(st, self.cfg.get("album_reward", []), out)
        return out

    @staticmethod
    def _album_full(cards: dict, a: int) -> bool:
        return all(num(cards.get("%d_%d" % (a, c), 0)) > 0 for c in range(9))

    def claim_book(self, st: dict, iid: str) -> dict:
        if not self.gd.valid_item(iid):
            raise Reject("bad_item", "没有这件物品", 400)
        self._backfill_seen(st)
        if not self._has_seen(st, iid):
            raise Reject("not_discovered", "还没发现这件物品")
        claimed = dict(st.get("book_claimed") or {})
        if claimed.get(iid):
            raise Reject("already_claimed", "已经领过了")
        claimed[iid] = True
        st["book_claimed"] = claimed
        return self.grant(st, [["fire_1", max(1, self.gd.lv(iid))]], {})

    def _backfill_seen(self, st: dict) -> None:
        """老账号补一次「见过」：以前交单不记见过，合成出来马上交掉的物品（比如新手单的石榴）服务器不知道。
        按已经交过的新手单、剧情单补回来，只补一次。"""
        if st.get("seen_backfill"):
            return
        st["seen_backfill"] = 1
        tut = self.cfg.get("tutorial", {})
        for key in list((st.get("done") or {}).keys()):
            items: list = []
            parts = str(key).split(":")
            if parts[0] == "tut" and len(parts) == 2:
                items = tut.get("orders", {}).get(parts[1], [])
            elif parts[0] == "seed":
                items = tut.get("seed_order", {}).get("items", [])
            elif parts[0] == "story" and len(parts) == 3:
                rows = self.gd.story.get(num(parts[1], -1)) or []
                si = num(parts[2], -1)
                if 0 <= si < len(rows):
                    items = rows[si]["items"]
            for iid in items:
                self._seen_item(st, str(iid), credit=False, budget=False)

    def claim_level(self, st: dict, level: int) -> dict:
        if level < 2 or level > num(st.get("level"), 1):
            raise Reject("not_reached", "还没到这一级")
        key = "level:%d" % level
        if st["done"].get(key):
            raise Reject("already_claimed", "已经领过了")
        st["done"][key] = True
        rw = self.gd.rewards_for_level(level)
        out = {"rewards": rw}
        return self.grant(st, rw, out)

    # ------------------------------------------------------------ 客户端上报的事件（交单、气泡、收取、退款）

    @staticmethod
    def _norm(v):
        if isinstance(v, float) and v.is_integer():
            return int(v)
        if isinstance(v, dict):
            return {str(k): Economy._norm(x) for k, x in v.items()}
        if isinstance(v, list):
            return [Economy._norm(x) for x in v]
        return v

    @classmethod
    def order_fp(cls, o: dict) -> str:
        keep = {k: o.get(k) for k in ("who", "items", "rw", "story", "si", "kind", "dish", "tutorial") if k in o}
        return json.dumps(cls._norm(keep), sort_keys=True, ensure_ascii=False)

    def remember_orders(self, st: dict, snap: dict) -> None:
        st["orders_fp"] = [self.order_fp(o) for o in snap.get("orders") or [] if isinstance(o, dict)]
        st["orders_used"] = []
        st["unlisted"] = 0
        st["refunds"] = 0

    def apply_event(self, st: dict, ev: dict) -> dict:
        t = str(ev.get("type", ""))
        if t == "merge":
            import hashlib
            from . import seven_day
            iid = str(ev.get("item", ""))
            if not self.gd.valid_item(iid) or self.gd.lv(iid) < 2:
                raise Reject("invalid_merge", "无效合并", 400)
            # Main board moves are client simulated. Never discard rapid legitimate
            # merges just because their next snapshot has not arrived yet.
            seven_day.record(self, st, "merges", 1)
            roll = int(hashlib.sha256(str(ev["id"]).encode()).hexdigest()[:8], 16) / 4294967296
            if 0 <= num(ev.get("cell"), -1) < int(self.gd.rules.get("cols", 7)) * int(self.gd.rules.get("rows", 9)):
                resource = self.gd.resource_drop("main", roll, num(st.get("level"), 1), iid)
                if resource:
                    out = {}
                    self.give_item(st, resource, out)
                    return out
            return {}
        if t == "order":
            return self._ev_order(st, ev.get("order") if isinstance(ev.get("order"), dict) else {})
        if t == "bubble":
            return self._ev_bubble(st, num(ev.get("cell"), -1))
        if t == "collect":
            return self._ev_collect(st, str(ev.get("item", "")))
        if t == "refund":
            return self._ev_refund(st, str(ev.get("item", "")))
        if t == "found":
            return self._ev_found(st, str(ev.get("item", "")))
        if t == "egen":
            return self._ev_egen(st, str(ev.get("gen", "")), str(ev.get("item", "")))
        raise Reject("bad_event", "未知事件", 400)

    def _ev_egen(self, st: dict, gid: str, iid: str) -> dict:
        """点一下体力生产器（不耗体力）。按账号记一批用了几次：用满 charges 次后 refill 分钟内不再认；
        产物必须在掉落表里，认了就把它记进货币额度，之后才能收取。"""
        es = self.gd.egen_stats(gid)
        if not es:
            raise Reject("bad_item", "这不是体力生产器", 400)
        if iid not in es["drops"]:
            raise Reject("bad_item", "体力生产器不会掉这件", 400)
        now = self.now()
        rec = st.get("egen") if isinstance(st.get("egen"), dict) else {}
        used = num(rec.get("u"))
        slack = num(self.cfg.get("check", {}).get("future_slack_sec", 120))
        if used >= es["charges"]:
            if now - float(rec.get("t", 0) or 0) < es["refill"] * 60 - slack:
                raise Reject("egen_resting", "体力生产器还在休息")
            used = 0
        st["egen"] = {"u": used + 1, "t": now}
        self._seen_item(st, iid, credit=False, budget=True)
        return {}

    def _ev_found(self, st: dict, iid: str) -> dict:
        """客户端刚发现一件新物品（合成出来 / 生产出来），还没等到下一次快照。
        只认：比这条链「有凭据的」最高等级（max_lv，含初始棋盘）最多高 1 级，或者 4 级以内（生产器能直接掉的）。
        记在 found 里，不抬高 max_lv：连发 found 也只能领先凭据 1 级，下一次快照同步后凭据才跟上。"""
        if not self.gd.valid_item(iid):
            raise Reject("bad_item", "没有这件物品", 400)
        if iid in self.gd.dishes and num(st.get("level"), 1) < num(self.gd.dishes[iid].get("unlock", 1)):
            raise Reject("locked", "还没有解锁这件订单成品")
        ch = self.gd.chain(iid)
        lv = self.gd.lv(iid)
        if lv > max(self._proven_lv(st, ch) + 1, int(self.cfg.get("found_free_lv", 4))):
            raise Reject("found_too_high", "这件物品等级跳得太快")
        fd = st.setdefault("found", {})
        if lv > num(fd.get(ch, 0)):
            fd[ch] = lv
        return {}

    def _proven_lv(self, st: dict, ch: str) -> int:
        """这条链有凭据的最高等级：快照 / 交单 / 服务器发奖记下的 max_lv，以及初始棋盘上（含石头下面）的物品。"""
        top = num(st.get("max_lv", {}).get(ch, 0))
        for cid in self.gd.board.get("cells", []) or []:
            if self.gd.valid_item(str(cid)) and self.gd.chain(str(cid)) == ch:
                top = max(top, self.gd.lv(str(cid)))
        return top

    def _has_seen(self, st: dict, iid: str) -> bool:
        """图鉴领奖、丢弃退款用：有凭据见过，或者 found 报过（已经限制过不能跳级）。"""
        ch = self.gd.chain(iid)
        lv = self.gd.lv(iid)
        return num(st.get("max_lv", {}).get(ch, 0)) >= lv or num(st.get("found", {}).get(ch, 0)) >= lv

    def _check_order(self, st: dict, o: dict) -> str:
        """返回一次性 key（剧情 / 新手单），普通单返回空串；不合规抛 Reject。"""
        rw = self._norm(o.get("rw") or {})
        items = [str(x) for x in o.get("items") or []]
        if not items or not all(self.gd.valid_item(x) for x in items):
            raise Reject("bad_order", "订单物品不对")
        fp = self.order_fp(o)
        listed = fp in (st.get("orders_fp") or []) and st.get("orders_fp").count(fp) > (st.get("orders_used") or []).count(fp)
        level = num(st.get("level"), 1)
        if o.get("story"):
            if "tutorial" in o:
                key = "tut:%d" % num(o["tutorial"])
                fire = self.gd.build_def("fire")
                parts = self.gd.build_parts(fire)
                cap = num(parts[1].get("cost", 340)) if len(parts) > 1 and isinstance(parts[1], dict) else 340
                if num(rw.get("shell")) > cap or num(rw.get("xp")) > 0 or num(o["tutorial"]) not in (1, 2):
                    raise Reject("bad_order", "新手单奖励不对")
                return key
            seed = self.cfg.get("tutorial", {}).get("seed_order", {})
            if items == seed.get("items") and "si" not in o:
                if num(rw.get("xp")) > num(seed.get("xp", 1)) or num(rw.get("shell")) > num(seed.get("shell", 50)):
                    raise Reject("bad_order", "新手单奖励不对")
                return "seed"
            si = num(o.get("si"), -1)
            rows = self.gd.story.get(level)
            if rows is not None:
                if not (0 <= si < len(rows)):
                    raise Reject("bad_order", "剧情单不属于当前等级")
                r = rows[si]
                ok = (sorted(items) == sorted(r["items"]) and num(rw.get("xp")) == r["xp"] and num(rw.get("shell")) == r["shell"]
                      and num(rw.get("token")) == r["token"] and [str(x) for x in rw.get("rewards", [])] == r["rewards"])
                if not ok:
                    raise Reject("bad_order", "剧情单和配置对不上")
            else:
                cap = sum(4 * self.gd.units(self.gd.lv(x)) for x in items)
                if si < 0 or num(rw.get("xp")) > self.gd.xp_need(level) or num(rw.get("shell")) > cap or rw.get("rewards"):
                    raise Reject("bad_order", "剧情单奖励超出范围")
            return "story:%d:%d" % (level, si)
        craft = str(o.get("kind", "")) == "craft"
        if num(rw.get("xp")) > 0:
            raise Reject("bad_order", "普通单不发声望和实物")
        if rw.get("rewards"):
            # 制作单只能附送一件沙漏，档位由菜的制作时长决定
            sand = self.gd.craft_sand(str(o.get("dish", ""))) if craft else ""
            if not sand or [str(x) for x in rw.get("rewards") or []] != [sand]:
                raise Reject("bad_order", "普通单不发声望和实物")
        oc = self.cfg.get("orders", {})
        if num(rw.get("token")) > num(oc.get("token_max_per_item", 3)) * len(items):
            raise Reject("bad_order", "祭典鼓超出范围")
        if num(rw.get("pack")) > (1 if level >= self.gd.card_level() else 0):
            raise Reject("bad_order", "卡包超出范围")
        if not listed:
            if craft:
                cap = 4 + sum(4 * self.gd.units(self.gd.lv(x)) for x in items)
            else:
                cap = math.ceil(float(oc.get("pay_per_flame", 3.0)) * sum(self.gd.flames(x) for x in items)) + 4 * len(items) + 2
            if num(rw.get("shell")) > cap:
                raise Reject("bad_order", "贝币超出范围（%d > %d）" % (num(rw.get("shell")), cap))
            if num(st.get("unlisted")) >= num(oc.get("unlisted_max_per_sync", 40)):
                raise Reject("too_many_orders", "两次同步之间交单太多")
            st["unlisted"] = num(st.get("unlisted")) + 1
        else:
            st.setdefault("orders_used", []).append(fp)
        return ""

    def _ev_order(self, st: dict, o: dict) -> dict:
        key = self._check_order(st, o)
        if key:
            if st["done"].get(key):
                raise Reject("already_done", "这张单已经交过了")
            st["done"][key] = True
        # 交得出去的东西一定在棋盘上出现过：合成出来、没等到下一次同步就交掉的物品也算见过（图鉴领奖、退款要用）
        for iid in o.get("items") or []:
            self._seen_item(st, str(iid), credit=False, budget=False)
        from . import merge_event
        merge_event.on_order(self, st, o)
        from . import duel_race
        duel_race.on_order(self, st, o)
        from . import seven_day
        seven_day.record(self, st, "orders", 1)
        rw = self._norm(o.get("rw") or {})
        out: dict = {}
        seven_day.record(self, st, "shell", max(0, num(rw.get("shell"))))
        st["shells"] = num(st.get("shells")) + max(0, num(rw.get("shell")))
        if num(rw.get("xp")) > 0:
            self.add_xp(st, num(rw["xp"]), out)
        if num(rw.get("token")) > 0:
            self.add_tokens(st, num(rw["token"]), out)
        for _ in range(max(0, num(rw.get("pack")))):
            self.give_item(st, "pack_1", out)
        for iid in rw.get("rewards") or []:
            if self.gd.valid_item(str(iid)):
                self.give_item(st, str(iid), out)
        st["pass_pts"] = num(st.get("pass_pts")) + (2 if num(st.get("pass_tier")) >= 2 else 1)
        return out

    def _ev_bubble(self, st: dict, cell: int) -> dict:
        rw = self.gd.bubble_reward(cell)
        if rw is None:
            raise Reject("no_bubble", "这一格没有气泡奖励")
        key = "bubble:%d" % cell
        if st["done"].get(key):
            raise Reject("already_done", "已经领过了")
        st["done"][key] = True
        return self.grant(st, [rw], {})

    def _ev_collect(self, st: dict, iid: str) -> dict:
        t = self.gd.type_of(iid)
        if t not in CURRENCY or not self.gd.valid_item(iid):
            raise Reject("bad_item", "这不是货币物品", 400)
        need = self.gd.units(self.gd.lv(iid))
        b = st.setdefault("budget", {})
        if num(b.get(t)) < need:
            raise Reject("no_budget", "没有这么多%s物品" % t)
        b[t] = num(b.get(t)) - need
        v = self.gd.value_of(iid)
        if v <= 0:
            return {}
        return self.grant(st, [[{"amber": "amber_1", "shell": "shell_1", "energy": "fire_1", "sand": "sand_1"}[t], v]], {})

    def _ev_refund(self, st: dict, iid: str) -> dict:
        if not self.gd.valid_item(iid) or self.gd.type_of(iid) != "item":
            raise Reject("bad_item", "这件不能退款", 400)
        self._backfill_seen(st)
        if not self._has_seen(st, iid):
            raise Reject("not_seen", "没见过这件物品")
        if num(st.get("refunds")) >= num(self.cfg.get("orders", {}).get("refund_max_per_sync", 60)):
            raise Reject("too_many_refunds", "两次同步之间退款太多")
        st["refunds"] = num(st.get("refunds")) + 1
        from . import seven_day
        seven_day.record(self, st, "shell", max(0, self.gd.value_of(iid)))
        st["shells"] = num(st.get("shells")) + max(0, self.gd.value_of(iid))
        return {}

    # ------------------------------------------------------------ 快照校验与合并

    def check_snapshot(self, st: dict, prev: dict | None, snap: dict, now: float, elapsed: float) -> str:
        """返回空串表示通过，否则是拒收原因。服务器字段不看（会被覆盖），只看客户端自己管的那部分。"""
        cc = self.cfg.get("check", {})
        for iid in self.snapshot_items(snap):
            if not self.gd.valid_item(iid):
                return "存档里有不存在的物品 %s" % iid
        fut = now + num(cc.get("future_slack_sec", 120))
        if float(snap.get("energy_stamp", 0) or 0) > fut:
            return "体力时间戳晚于服务器时间"
        for c in snap.get("board") or []:
            if isinstance(c, dict):
                for sub in (c.get("gm"), c.get("ck")):
                    if isinstance(sub, dict):
                        for k in ("t", "t0"):
                            if float(sub.get(k, 0) or 0) > fut:
                                return "生产器 / 制作的时间戳晚于服务器时间"
        for o in snap.get("orders") or []:
            if isinstance(o, dict) and float(o.get("t0", 0) or 0) > fut:
                return "制作订单的时间戳晚于服务器时间"
        if prev is None:
            return ""
        max_e = num(self.gd.rules.get("max_energy", 100), 100)
        regen = max(1, num(self.gd.rules.get("regen_sec", 120), 120))
        regen_gain = min(max_e, int(max(0.0, elapsed) / regen))
        energy = num(snap.get("energy"))
        allow = num(prev.get("energy")) + regen_gain + num(st.get("energy_credit")) + num(cc.get("energy_slack", 20))
        if energy > allow:
            return "体力 %d → %d，最多允许 %d（回复 %d，服务器发 %d）" % (num(prev.get("energy")), energy, allow, regen_gain, num(st.get("energy_credit")))
        rush = num(snap.get("rush"))
        allow_r = num(prev.get("rush")) + num(st.get("rush_credit")) + num(cc.get("rush_slack", 2))
        if rush > allow_r:
            return "沙漏 %d → %d，最多允许 %d" % (num(prev.get("rush")), rush, allow_r)
        return ""

    def merge(self, st: dict, snap: dict) -> dict:
        """服务器字段覆盖进快照，并记下快照里的物品（最高等级）和订单（交单校验用）。"""
        for k in SERVER_FIELDS:
            snap[k] = st.get(k)
        for iid in self.snapshot_items(snap, open_only=True):
            self._seen_item(st, iid, credit=False, budget=False)
        self.remember_orders(st, snap)
        st["energy_credit"] = 0
        st["rush_credit"] = 0
        return snap

    # ------------------------------------------------------------ 热卖抽货（同 HotDeals.roll）

    def wanted(self, snap: dict) -> list:
        have: dict = {}
        for iid in self.snapshot_items({"board": [c for c in snap.get("board") or [] if isinstance(c, dict) and num(c.get("lock")) == 0],
                                         "stash": snap.get("stash") or []}):
            have[iid] = have.get(iid, 0) + 1
        out = []
        for o in snap.get("orders") or []:
            if not isinstance(o, dict):
                continue
            for it in o.get("items") or []:
                iid = str(it)
                if have.get(iid, 0) > 0:
                    have[iid] -= 1
                    continue
                if self.gd.is_goods(iid) and iid not in out:
                    out.append(iid)
        return out

    def roll_hot(self, wanted: list) -> list:
        hc = self.cfg.get("hot", {})
        odds = [max(0, num(x)) for x in hc.get("odds", [20, 55, 25])] or [1]
        n = self.rng.choices(range(len(odds)), weights=odds)[0] if sum(odds) > 0 else 0
        ids = [str(d.get("id", "")) for d in self.gd.store]
        slots = [k for k, i in enumerate(ids) if self.gd.is_goods(i)]
        pool = list(wanted)
        self.rng.shuffle(pool)
        used: set = set()
        picks = []
        min_lv = num(hc.get("min_lv", 2), 2)
        while n > 0 and pool and slots:
            need = pool.pop()
            ch = self.gd.chain(need)
            if ch in used:
                continue
            drops = [1, 2] if self.rng.randrange(100) < num(hc.get("drop1_chance", 60)) else [2, 1]
            iid = ""
            for dl in drops:
                lv = self.gd.lv(need) - dl
                cand = "%s_%d" % (ch, lv)
                if lv >= min_lv and cand not in wanted:
                    iid = cand
                    break
            if not iid or iid in ids:
                continue
            at = next((k for k in slots if self.gd.chain(ids[k]) == ch), -1)
            if at < 0:
                at = next((k for k in slots if self.gd.line_of(ids[k]) == self.gd.line_of(iid)), -1)
            if at < 0:
                at = self.rng.choice(slots)
            slots.remove(at)
            used.add(ch)
            ids[at] = iid
            picks.append({"slot": at, "id": iid})
            n -= 1
        return picks

    def reroll_hot_all(self, previous: list) -> list:
        picks = []
        for k, base in enumerate(self.gd.store):
            iid = str(base["id"])
            ch = self.gd.chain(iid)
            old = str(previous[k]["id"]) if k < len(previous) else iid
            pool = [f"{ch}_{lv}" for lv in range(max(1, self.gd.lv(iid) - 1),
                    min(self.gd.max_lv(ch), self.gd.lv(iid) + 1) + 1) if f"{ch}_{lv}" != old]
            picks.append({"slot": k, "id": self.rng.choice(pool) if pool else iid})
        return picks
