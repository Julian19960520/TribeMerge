class_name Data
extends RefCounted
## 玩法数值在 data/*.json。游戏主页左下「配置」可以改，每一页的保存只写回自己的文件。
## 代码里仍用 Data.LINES、Data.CHAINS 这些名字。保存后会立刻重新读入。

const ConfigFiles := preload("res://scripts/config/config_files.gd")
const Layout := preload("res://scripts/config/board_layout.gd")

static var LINES: Array = []
static var CHAINS: Dictionary = {}
static var PEOPLE: Array = []
static var STORY: Dictionary = {}
static var ALBUMS: Array = []
static var AMBER_PACKS: Array = []
static var BUILDS: Array = []
static var LEVEL_REWARDS := {}
static var STORE_HOT: Array = []
## 集市「贝币小摊」（data/store_shell.json）：每项 {"id", "price", "stock"}，每 STORE_SHELL_HOURS 小时刷新
static var STORE_SHELL: Array = []
static var STORE_SHELL_HOURS := 8
static var STORE_SHELL_REFRESH := 5
static var PASS_LEVELS: Array = []
## 通行证赛季：{"days": 35, "start": "2026-11-02"}（北京时间零点起算）
static var PASS_SEASON: Dictionary = {}
static var RULES: Dictionary = {}
static var BOARD: Array = []
static var LOCKS: Array = []
static var REWARDS: Dictionary = {}
static var DISHES: Dictionary = {}
static var RANDOM_CURVES: Array = []
## 常驻随机订单每张在「下限～上限」之间的位置，0 是下限（简单单），1 是上限（难单）。
static var RANDOM_SLOTS: Array = [0.0, 0.3, 0.55, 1.0]
## 链 id -> 每一级是否可进订单。下标 0 是主角 1 级。
static var UNLOCK_ROWS: Dictionary = {}
## 典藏卡册是后期活动。这一级之前不发卡包，主页也不露出卡册。
const CARD_LEVEL := 8
## 双倍火种（生产器加速）：这一级解锁。开启后生产器每次耗 2 火种，产物高 1 级。
const BOOST_LEVEL := 18

static func _static_init() -> void:
	_load()

static func reload() -> void:
	_load()

static func _load() -> void:
	LINES = _take(ConfigFiles.LINES, [])
	CHAINS = {}
	for raw in _take(ConfigFiles.CHAINS, []):
		if raw is not Dictionary:
			continue
		var c: Dictionary = raw.duplicate(true)
		var id := str(c.get("id", ""))
		c.erase("id")
		if str(c.get("line", "")) == "":
			c.erase("line")
		c.erase("kind")
		if not (c.get("value", []) is Array) or c.get("value", []).is_empty():
			c.erase("value")
		if id != "":
			CHAINS[id] = c
	PEOPLE = _take(ConfigFiles.PEOPLE, [])
	STORY = {}
	var story = _take(ConfigFiles.STORY, {"levels": []})
	for lv in story.get("levels", []):
		var orders := []
		for o in lv.get("orders", []):
			var d := {
				"who": int(o["who"]),
				"items": o["items"],
				"xp": int(o["xp"]),
				"shell": int(o["shell"]),
			}
			var rewards: Array = []
			if o.get("rewards") is Array:
				for id in o["rewards"]:
					if str(id) != "":
						rewards.append(str(id))
			else:
				for _i in int(o.get("pack", 0)):
					rewards.append("pack_1")
			if not rewards.is_empty():
				d["rewards"] = rewards
			if int(o.get("token", 0)) > 0:
				d["token"] = int(o["token"])
			if str(o.get("say", "")) != "":
				d["say"] = str(o["say"])
			orders.append(d)
		STORY[int(lv["level"])] = orders
	ALBUMS = _take(ConfigFiles.ALBUMS, [])
	AMBER_PACKS = _take(ConfigFiles.AMBER, [])
	BUILDS = _take(ConfigFiles.BUILDS, [])
	LEVEL_REWARDS = {}
	var lvfile = _take(ConfigFiles.LEVELS, {"levels": []})
	if lvfile is Dictionary:
		for row in lvfile.get("levels", []):
			if row is not Dictionary:
				continue
			var packed := []
			for rw in row.get("rewards", []):
				if rw is Array and rw.size() >= 2 and str(rw[0]) != "":
					packed.append([str(rw[0]), maxi(1, int(rw[1]))])
			LEVEL_REWARDS[int(row.get("level", 0))] = packed
	STORE_HOT = _take(ConfigFiles.STORE, [])
	var shellf = _take(ConfigFiles.STORE_SHELL, {})
	STORE_SHELL = []
	if shellf is Dictionary:
		for d in shellf.get("items", []):
			if d is Dictionary:
				STORE_SHELL.append({"id": str(d.get("id", "")), "price": int(d.get("price", 0)), "stock": int(d.get("stock", 0))})
		STORE_SHELL_REFRESH = maxi(1, int(shellf.get("refresh_amber", 5)))
		STORE_SHELL_HOURS = maxi(1, int(shellf.get("refresh_hours", 8)))
	var passf = _take(ConfigFiles.PASS, {"levels": []})
	PASS_LEVELS = passf.get("levels", [])
	PASS_SEASON = passf.get("season", {}) if passf.get("season") is Dictionary else {}
	RULES = _take(ConfigFiles.RULES, {})
	var board = _take(ConfigFiles.BOARD, {"cells": []})
	BOARD = board.get("cells", [])
	var locks = board.get("locks", [])
	LOCKS = locks if locks is Array else []
	REWARDS = Layout.rewards_map(board.get("rewards", {}))
	DISHES = {}
	for raw in _take(ConfigFiles.DISHES, []):
		if raw is not Dictionary:
			continue
		var id := str(raw.get("id", ""))
		if id == "":
			continue
		var d: Dictionary = raw.duplicate(true)
		d["id"] = id
		var mats: Array = []
		for m in d.get("mats", []):
			if str(m) != "":
				mats.append(str(m))
		d["mats"] = mats
		d["secs"] = maxi(int(d.get("secs", 12)), 1)
		d["unlock"] = maxi(int(d.get("unlock", 1)), 1)
		d["name"] = str(d.get("name", id))
		DISHES[id] = d
	RANDOM_CURVES = []
	var rc = _take(ConfigFiles.RANDOM_ORDERS, {"curves": []})
	var rows: Array = []
	RANDOM_SLOTS = [0.0, 0.3, 0.55, 1.0]
	if rc is Dictionary and rc.get("slots") is Array and not (rc["slots"] as Array).is_empty():
		RANDOM_SLOTS = []
		for v in rc["slots"]:
			RANDOM_SLOTS.append(clampf(float(v), 0.0, 1.0))
	if rc is Dictionary:
		for raw in rc.get("curves", []):
			if raw is not Dictionary:
				continue
			var diff: Array = []
			var src = raw.get("diff", [])
			if src is Array:
				for v in src:
					diff.append(maxi(1, int(v)))
			if not diff.is_empty():
				rows.append(diff)
	if not rows.is_empty():
		var n := 0
		for row in rows:
			n = maxi(n, row.size())
		var low: Array = []
		var high: Array = []
		for i in n:
			var mn := 999999
			var mx := 1
			for row in rows:
				if i >= row.size():
					continue
				mn = mini(mn, int(row[i]))
				mx = maxi(mx, int(row[i]))
			low.append(maxi(1, mn))
			high.append(maxi(int(low[i]), mx))
		RANDOM_CURVES = [
			{"name": "下限", "diff": low},
			{"name": "上限", "diff": high},
		]
	UNLOCK_ROWS = {}
	var book = _take(ConfigFiles.UNLOCKS, {"rows": []})
	if book is Dictionary:
		for raw in book.get("rows", []):
			if raw is not Dictionary:
				continue
			var cid := str(raw.get("id", ""))
			var open = raw.get("open", [])
			if cid == "" or not (open is Array) or open.is_empty():
				continue
			var flags: Array = []
			for v in open:
				flags.append(1 if int(v) != 0 else 0)
			UNLOCK_ROWS[cid] = flags

static func _take(path: String, fallback: Variant) -> Variant:
	var v = ConfigFiles.read(path)
	if v == null:
		push_error("配置读取失败 " + path)
		return fallback
	return v


## 第 index 档要的积分。下标从 0 起。超出最后一档时用最后一档的积分。
static func pass_need(index: int) -> int:
	if PASS_LEVELS.is_empty():
		return 8
	var i := clampi(index, 0, PASS_LEVELS.size() - 1)
	return maxi(1, int(PASS_LEVELS[i].get("need", 8)))

## 剧情订单在 data/story.json。只有它们给声望。每一级的剧情声望加起来正好等于升到下一级要的声望。
## 配置以外不补造经验订单，空位由随机订单填充。
static func story_orders(level: int) -> Array:
	return STORY.get(level, [])

## 升到下一级要的声望 = xp_base + (等级 - 1) / xp_div，在 data/rules.json 里调。
static func xp_need(level: int) -> int:
	var base := int(RULES.get("xp_base", 3))
	var div := maxi(1, int(RULES.get("xp_div", 2)))
	return maxi(1, base + (maxi(level, 1) - 1) / div)

static func random_curve_count() -> int:
	return RANDOM_CURVES.size()

## 这个主角等级上随机订单难度的下限和上限。等级从 1 计。
static func random_bounds(level: int) -> Vector2i:
	var lo := random_diff(level, 0)
	var hi := random_diff(level, 1) if random_curve_count() > 1 else lo
	if hi < lo:
		return Vector2i(hi, lo)
	return Vector2i(lo, hi)

## 常驻随机订单第 slot 张的目标火苗：在下限和上限之间按 RANDOM_SLOTS 插值。
static func random_slot_target(level: int, slot: int) -> int:
	var b := random_bounds(level)
	if RANDOM_SLOTS.is_empty():
		return b.x
	var t: float = RANDOM_SLOTS[posmod(slot, RANDOM_SLOTS.size())]
	return maxi(1, int(round(lerpf(float(b.x), float(b.y), t))))

## 第 curve 条线在这个主角等级上的火苗。0 是下限，1 是上限。等级从 1 计。
static func random_diff(level: int, curve: int) -> int:
	if RANDOM_CURVES.is_empty():
		return 0
	var c: Dictionary = RANDOM_CURVES[posmod(curve, RANDOM_CURVES.size())]
	var diff: Array = c.get("diff", [])
	if diff.is_empty():
		return 1
	return maxi(1, int(diff[clampi(level - 1, 0, diff.size() - 1)]))

## 升到 level 时获得的奖励。配置里写了就用配置，没写的等级仍按原来的公式。
static func level_rewards(level: int) -> Array:
	if LEVEL_REWARDS.has(level):
		var rewards := (LEVEL_REWARDS[level] as Array).duplicate(true)
		if level < CARD_LEVEL:
			rewards = rewards.filter(func(rw): return type_of(str(rw[0])) != "pack")
		return rewards
	return default_level_rewards(level)

static func default_level_rewards(level: int) -> Array:
	var out := [["fire_2", 30 + level * 10], ["chest_1", 1]]
	if level >= CARD_LEVEL:
		out.append(["pack_1", 1])
	var fresh := {}
	for l in LINES:
		if int(l["unlock"]) == level:
			fresh = l
	if not fresh.is_empty():
		var pid := first_prod_id(fresh)
		if pid != "":
			out.append([pid, 1])
	elif level % 3 == 0:
		var open := unlocked_lines(level)
		if not open.is_empty():
			out.append(["%s_1" % open[(level / 3) % open.size()]["gen"], 1])
	else:
		out.append(["amber_3", 5])
	return out

## 订单栏逐级变多：数组里第 k 个数是「第 k+1 张从几级开始」。可在 rules.json 里改。
## order_cap_at：每个元素代表一个新订单位开放的等级；经验订单优先填满这些位置。
static func _cap_at(key: String, fallback: Array, level: int, limit: int) -> int:
	var at = RULES.get(key, fallback)
	if not (at is Array):
		at = fallback
	var n := 0
	for v in at:
		if level >= int(v):
			n += 1
	return mini(n, limit)

## One total capacity shared by experience, random and crafting orders.
static func order_total(level: int) -> int:
	return maxi(1, _cap_at("order_cap_at", [1, 1, 4, 10, 20], level, 99))

static func story_cap(level: int) -> int:
	return order_total(level)

static func random_cap(level: int) -> int:
	return order_total(level)

## 升到这一级时新开放的东西，给升级弹窗用。每条一句。
static func level_unlocks(level: int) -> Array:
	var out: Array = []
	for l in LINES:
		if int(l.get("unlock", 0)) == level and level > 1:
			out.append("新产线：%s" % str(l.get("name", "")))
		var sub := str(l.get("sub", ""))
		if sub != "" and level > 1 and product_open(level, sub) and not product_open(level - 1, sub):
			out.append("订单开始要%s" % str(CHAINS.get(str(l["sub"]), {}).get("name", "")))
	if level == int(RULES.get("craft_level", 3)):
		out.append("新玩法：制作订单")
	for id in DISHES:
		var d: Dictionary = DISHES[id]
		if int(d["unlock"]) == level and level > int(RULES.get("craft_level", 3)):
			out.append("新菜谱：%s" % str(d["name"]))
	if level > 1 and order_total(level) > order_total(level - 1):
		out.append("订单栏 +%d，现在 %d 张" % [order_total(level) - order_total(level - 1), order_total(level)])
	if level == CARD_LEVEL:
		out.append("丰收祭卡册开放")
	if level == BOOST_LEVEL:
		out.append("新玩法：双倍火种（生产器产物升 1 级）")
	return out

static func is_dish(id: String) -> bool:
	return DISHES.has(id)

## 当前等级能接到的制作菜。材料都得是已有物品。
static func dishes_for(level: int) -> Array:
	var out := []
	for id in DISHES:
		var d: Dictionary = DISHES[id]
		if int(d["unlock"]) > level:
			continue
		var ok := true
		for m in d["mats"]:
			if not CHAINS.has(chain(str(m))) or not product_open(level, chain(str(m))):
				ok = false
				break
		if ok and not (d["mats"] as Array).is_empty():
			out.append(d)
	return out

static func chain(id: String) -> String:
	return id.get_slice("_", 0)

static func lv(id: String) -> int:
	if DISHES.has(id):
		return 1
	return int(id.get_slice("_", 1))

static func max_lv(ch: String) -> int:
	return CHAINS[ch]["items"].size()

static func type_of(id: String) -> String:
	if DISHES.has(id):
		return "dish"
	return CHAINS[chain(id)]["type"]

static func name_of(id: String) -> String:
	if DISHES.has(id):
		return str(DISHES[id]["name"])
	return CHAINS[chain(id)]["items"][lv(id) - 1]

static func next_id(id: String) -> String:
	if DISHES.has(id):
		return ""
	var ch := chain(id)
	var l := lv(id)
	if l >= max_lv(ch):
		return ""
	return "%s_%d" % [ch, l + 1]

static func value_of(id: String) -> int:
	if DISHES.has(id):
		return 0
	var c: Dictionary = CHAINS[chain(id)]
	if c.has("value"):
		return c["value"][lv(id) - 1]
	return 0

# ---------------------------------------------------------------- 产线

static func line(id: String) -> Dictionary:
	for l in LINES:
		if l["id"] == id:
			return l
	return {}

## 物品所属产线；不属于任何产线时返回空字典
static func line_of(id: String) -> Dictionary:
	return line(str(CHAINS[chain(id)].get("line", "")))

## 现场绘制用的角色。产线的 gen / main / sub 对应 G / M / S
static func draw_role(ch: String) -> String:
	var def: Dictionary = CHAINS.get(ch, {})
	var l := line(str(def.get("line", "")))
	if l.is_empty():
		return ""
	if str(l.get("gen", "")) == ch:
		return "G"
	if str(l.get("main", "")) == ch:
		return "M"
	if str(l.get("sub", "")) == ch:
		return "S"
	return ""

static func unlocked_lines(level: int) -> Array:
	var out := []
	for l in LINES:
		if int(l["unlock"]) <= level:
			out.append(l)
	return out

## 已开放产线里，速查表允许进订单的主产物链
static func order_chains(level: int) -> Array:
	var out := []
	for l in unlocked_lines(level):
		var ch := str(l.get("main", ""))
		if ch != "" and product_open(level, ch):
			out.append(ch)
	return out

## 这条产物链在该主角等级能不能进订单。表里没有时，主产物跟产线一起开，副产物开在个位为 3 或 8 的等级。
static func product_open(level: int, chain_id: String) -> bool:
	if level < 1 or chain_id == "":
		return false
	if UNLOCK_ROWS.has(chain_id):
		var open: Array = UNLOCK_ROWS[chain_id]
		if open.is_empty():
			return false
		return int(open[mini(level - 1, open.size() - 1)]) != 0
	for l in LINES:
		if str(l.get("main", "")) == chain_id:
			return int(l.get("unlock", 1)) <= level
		if str(l.get("sub", "")) == chain_id:
			return sub_unlock_level(int(l.get("unlock", 1))) <= level
	return true

## 副产物解锁等级：从产线开放等级往后，第一个个位是 3 或 8 的等级。
static func sub_unlock_level(line_unlock: int) -> int:
	var lv := maxi(1, line_unlock)
	while lv % 10 != 3 and lv % 10 != 8:
		lv += 1
	return lv

## 生产器第一个配了产物的等级；都没配时返回空字符串
static func first_prod_id(l: Dictionary) -> String:
	var ch := str(l.get("gen", ""))
	var n := first_prod_lv(ch)
	if n <= 0:
		return ""
	return "%s_%d" % [ch, n]

## 这条生产器链上第一个能生产的等级，从 1 计；没有则返回 0
static func first_prod_lv(ch: String) -> int:
	var prod = CHAINS.get(ch, {}).get("prod", [])
	if not (prod is Array):
		return 0
	for i in prod.size():
		if _prod_ready(prod[i]):
			return i + 1
	return 0

static func _prod_ready(slot) -> bool:
	if slot == null or not (slot is Dictionary):
		return false
	var drops = slot.get("drops", [])
	if not (drops is Array):
		return false
	for d in drops:
		if d is Dictionary and str(d.get("id", "")) != "" and int(d.get("p", 0)) > 0:
			return true
	return false

## 生产器的产出参数；这一级没配产物时返回空字典
static func gen_stats(id: String) -> Dictionary:
	if type_of(id) == "egen":
		return egen_stats(id)
	if type_of(id) != "gen":
		return {}
	var ch := chain(id)
	var def: Dictionary = CHAINS.get(ch, {})
	var prod = def.get("prod", [])
	var g := lv(id)
	if not (prod is Array) or g < 1 or g > prod.size() or not _prod_ready(prod[g - 1]):
		return {}
	var slot: Dictionary = prod[g - 1]
	var usable: Array = []
	for d in slot.get("drops", []):
		if d is Dictionary and str(d.get("id", "")) != "" and int(d.get("p", 0)) > 0:
			usable.append({"id": str(d["id"]), "p": int(d["p"])})
	var st := {"drops": usable}
	if line(str(def.get("line", ""))).get("cooldown", false):
		st["charges"] = int(slot.get("charges", 8))
		st["refill"] = int(slot.get("refill_min", 12))
	return st

## 体力生产器（type "egen"，如火种罐）：点击不耗体力，一批 charges 次，点空后休息 refill_min 分钟再整批回满。
## 配置在 chains.json 这条链的 prod[0]。返回格式同 gen_stats，多一个 "free"。
static func egen_stats(id: String) -> Dictionary:
	var prod = CHAINS[chain(id)].get("prod", [])
	if not (prod is Array) or prod.is_empty() or not (prod[0] is Dictionary):
		return {}
	var slot: Dictionary = prod[0]
	var usable: Array = []
	for d in slot.get("drops", []):
		if d is Dictionary and str(d.get("id", "")) != "" and int(d.get("p", 0)) > 0:
			usable.append({"id": str(d["id"]), "p": int(d["p"])})
	if usable.is_empty():
		return {}
	return {"drops": usable, "charges": int(slot.get("charges", 24)), "refill": int(slot.get("refill_min", 720)), "free": true}

static func producers_of(ch: String) -> Array:
	var l := line(str(CHAINS[ch].get("line", "")))
	if l.is_empty() or l["gen"] == ch:
		return []
	var pid := first_prod_id(l)
	if pid == "":
		return []
	return [pid]

static func describe(id: String) -> String:
	if id == "energybox_1": return "打开获得3个熊熊大火，每个可领取40点体力，也可继续合成。"
	if DISHES.has(id):
		var d: Dictionary = DISHES[id]
		var bits: PackedStringArray = []
		for m in d["mats"]:
			bits.append(name_of(str(m)))
		var secs := int(d["secs"])
		var clock := "%d 秒" % secs
		if secs >= 3600:
			clock = "%d 小时" % (secs / 3600) if secs % 3600 == 0 else "%d 小时 %d 分钟" % [secs / 3600, secs % 3600 / 60]
		elif secs >= 60:
			clock = "%d 分钟" % (secs / 60) if secs % 60 == 0 else "%d 分 %d 秒" % [secs / 60, secs % 60]
		return "用%s做成。制作需要 %s，可以用沙漏加速。%d 级解锁。" % ["、".join(bits), clock, int(d["unlock"])]
	var t := type_of(id)
	var nx := next_id(id)
	var tail := "合成可得：%s。" % name_of(nx) if nx != "" else "已经是最高级！"
	match t:
		"gen":
			var st := gen_stats(id)
			if st.is_empty():
				var n := first_prod_lv(chain(id))
				if n <= 0:
					return "还不能生产。%s" % tail
				return "还不能生产，合成到 %d 级才能点击。%s" % [n, tail]
			var bits: PackedStringArray = []
			for d in st["drops"]:
				bits.append("%s %d" % [name_of(str(d["id"])), int(d["p"])])
			return "点击产出%s。%s" % ["、".join(bits), tail]
		"egen":
			var st := gen_stats(id)
			if st.is_empty():
				return "还不能生产。"
			var rest := int(st["refill"])
			var rest_text := "%d 小时" % (rest / 60) if rest % 60 == 0 else "%d 分钟" % rest
			return "点击免费产出火种，一批 %d 次，点完休息 %s。攒着合成大火种再收！" % [int(st["charges"]), rest_text]
		"item":
			var l := line_of(id)
			var sell := value_of(id)
			var back := "丢弃退回 %d 贝币。" % sell if sell > 0 else ""
			if not l.is_empty():
				return "%s产出。%s%s" % [CHAINS[l["gen"]]["name"], back, tail]
			if back != "":
				return back + tail
		"energy", "shell", "amber", "sand" when value_of(id) <= 0:
			return "合成到 2 级才能收取。%s" % tail
		"energy":
			return "点击收取 %d 点体力。%s" % [value_of(id), tail]
		"shell":
			return "点击收取 %d 贝币。%s" % [value_of(id), tail]
		"amber":
			return "点击收取 %d 琥珀。%s" % [value_of(id), tail]
		"sand":
			return "点击收取 %d 份沙漏。每份能让正在制作的成品快 %s。%s" % [value_of(id), rush_text(), tail]
		"choice":
			return "点击打开，三选一。选择后宝箱变为所选物品。"
		"chest":
			return "点击打开，获得随机物品。"
		"pack":
			return "点击打开，获得丰收祭卡牌。"
		"token":
			return "丰收祭的活动积分，每攒 %d 个换一个兽皮卡包。" % int(RULES.get("token_step", 10))
		"xp":
			return "主角的经验，只有带星标的剧情订单才会给，攒满即可升级。"
	return tail

static func build_def(id: String) -> Dictionary:
	for b in BUILDS:
		if b is Dictionary and str(b.get("id", "")) == id:
			return b
	return {}

## 一个区域的部件列表 [{id, name, cost, rewards}]。旧格式（stages + rewards）自动折成无名部件。
static func build_parts(b: Dictionary) -> Array:
	if b.get("parts") is Array:
		return b["parts"]
	var out: Array = []
	var rw = b.get("rewards", [])
	for k in int(b.get("stages", 0)):
		out.append({"id": "%s_%d" % [str(b.get("id", "")), k], "name": "第 %d 段" % (k + 1), "cost": 60 + k * 45,
			"rewards": rw[k] if rw is Array and k < rw.size() else []})
	return out

static func build_stages(b: Dictionary) -> int:
	return build_parts(b).size()

## 区域开放的部落等级：写了 unlock 用 unlock，否则跟随所属产线开放。
static func build_unlock(b: Dictionary) -> int:
	if b.has("unlock"):
		return maxi(1, int(b["unlock"]))
	var line := str(b.get("line", ""))
	for l in LINES:
		if str(l.get("id", "")) == line:
			return maxi(1, int(l.get("unlock", 1)))
	return 1


## 每日特惠的 key 固定，低等级隐藏卡包也不会挤占免费物品的领取记录。
static func daily_deals(_level: int) -> Array:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/daily_deals.json"))

## 合成泡泡（规则在 rules.json merge_bubble，服务器 Economy 同一套算法）：
## 只有普通物品链、理论火苗（稀有度）≥ min_flames 的高级物品才可能出泡泡。
static func bubble_rule() -> Dictionary:
	var r = RULES.get("merge_bubble", {})
	return r if r is Dictionary else {}

static func bubble_ok(id: String) -> bool:
	if id == "" or DISHES.has(id) or not CHAINS.has(chain(id)) or type_of(id) != "item":
		return false
	return OrderRoll.flames(id) >= float(bubble_rule().get("min_flames", 32))

## 价格 = k × 理论火苗^exp，按 step 取整：稀有度越高越贵，但越高级折扣越大。
static func bubble_price(id: String) -> int:
	var r := bubble_rule()
	var raw := float(r.get("price_k", 0.6)) * pow(maxf(OrderRoll.flames(id), 1.0), float(r.get("price_exp", 0.8)))
	var step := maxf(1.0, float(r.get("price_step", 5)))
	var p := int(round(raw / step) * step)
	return clampi(p, int(r.get("price_min", 5)), int(r.get("price_max", 300)))

## 合成掉贝币：合成结果越高级，掉的贝币物品越大（rules.json merge_coin.tiers = [[最低等级, 物品], ...]）。
static func merge_coin_item(merged: String) -> String:
	var r = RULES.get("merge_coin", {})
	var out := ""
	if r is Dictionary:
		for t in r.get("tiers", []):
			if t is Array and t.size() >= 2 and lv(merged) >= int(t[0]):
				out = str(t[1])
	return out

static func merge_coin_chance() -> float:
	var r = RULES.get("merge_coin", {})
	return clampf(float(r.get("chance", 0.0)), 0.0, 1.0) if r is Dictionary else 0.0

## 合成掉沙漏：普通物品合成后，在掉贝币之外再有 merge_sand.chance 的机会掉一个沙漏（rules.json merge_sand）。
## 和贝币共用同一个掷点：[贝币概率, 贝币概率 + 沙漏概率) 这一段掉沙漏。服务器 Economy.merge_sand_item 同一套算法。
static func merge_sand_item(merged: String, level: int) -> String:
	var r = RULES.get("merge_sand", {})
	if not (r is Dictionary) or level < int(r.get("min_level", 1)) or DISHES.has(merged):
		return ""
	if not CHAINS.has(chain(merged)) or str(CHAINS[chain(merged)]["type"]) != "item":
		return ""
	var out := ""
	for t in r.get("tiers", []):
		if t is Array and t.size() >= 2 and lv(merged) >= int(t[0]):
			out = str(t[1])
	return out

static func merge_sand_chance() -> float:
	var r = RULES.get("merge_sand", {})
	return clampf(float(r.get("chance", 0.0)), 0.0, 1.0) if r is Dictionary else 0.0

static func rush_text() -> String:
	var s := rush_sec()
	return "%d 分钟" % (s / 60) if s % 60 == 0 else "%d 秒" % s

## 一份沙漏让制作快多少秒（rules.json rush_sec）。
static func rush_sec() -> int:
	return maxi(1, int(RULES.get("rush_sec", 60)))

## 同时最多几张制作订单：craft_cap_at 每个元素是多开一张的等级。
static func craft_cap(level: int) -> int:
	return _cap_at("craft_cap_at", [int(RULES.get("craft_level", 3))], level, 9)

## 制作订单附送的沙漏：按菜的制作秒数取 craft_sand 里最后一个够得着的档 [[最少秒数, 物品], ...]。
static func craft_sand(dish_id: String) -> String:
	if not DISHES.has(dish_id):
		return ""
	var secs := int(DISHES[dish_id].get("secs", 0))
	var out := ""
	for t in RULES.get("craft_sand", []):
		if t is Array and t.size() >= 2 and secs >= int(t[0]):
			out = str(t[1])
	return out

## 每次合成最多掉一件资源；按顺序占用概率区间，剩余概率不掉落。
static func resource_drop(scope: String, roll: float, level: int, merged: String = "") -> String:
	var total := 0.0
	for entry in RULES.get("merge_resource_drops", {}).get(scope, []):
		if level < int(entry.get("min_level", 1)): continue
		if bool(entry.get("items_only", false)) and type_of(merged) != "item": continue
		var id := str(entry.get("item", ""))
		if not CHAINS.has(chain(id)) or not type_of(id) in ["shell", "amber", "energy", "sand"]: continue
		total += clampf(float(entry.get("chance", 0)), 0.0, 1.0)
		if roll < total: return "%s_1" % chain(id)
	return ""
