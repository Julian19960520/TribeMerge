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
static var PASS_LEVELS: Array = []
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
	var passf = _take(ConfigFiles.PASS, {"levels": []})
	PASS_LEVELS = passf.get("levels", [])
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
## 表里没写的等级（超过 40 级）按公式生成，同样保证声望够用。
static func story_orders(level: int) -> Array:
	if STORY.has(level):
		return STORY[level]
	var r := RandomNumberGenerator.new()
	r.seed = level * 7919
	var out := []
	var top: int = 2 + level / 2
	var chains := order_chains(level)
	var need := xp_need(level)
	for i in 3:
		var items := []
		var n := 1 + r.randi() % 3
		var shell := 0
		for k in n:
			var ch: String = chains[r.randi() % chains.size()]
			var l := r.randi_range(3, mini(top, max_lv(ch) - 2))
			items.append("%s_%d" % [ch, l])
			shell += 4 * int(pow(2, l - 1))
		var xp_i := need / 3 + (1 if i >= 3 - need % 3 else 0)
		var o := {"who": r.randi() % PEOPLE.size(), "items": items, "xp": xp_i, "shell": shell}
		if i == 1 and level >= CARD_LEVEL:
			o["rewards"] = ["pack_1"]
		if i == 2:
			o["token"] = 2 + level / 2
		out.append(o)
	return out

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
		return (LEVEL_REWARDS[level] as Array).duplicate(true)
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
			if not CHAINS.has(chain(str(m))):
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

static func producers_of(ch: String) -> Array:
	var l := line(str(CHAINS[ch].get("line", "")))
	if l.is_empty() or l["gen"] == ch:
		return []
	var pid := first_prod_id(l)
	if pid == "":
		return []
	return [pid]

static func describe(id: String) -> String:
	if DISHES.has(id):
		var d: Dictionary = DISHES[id]
		var bits: PackedStringArray = []
		for m in d["mats"]:
			bits.append(name_of(str(m)))
		var secs := int(d["secs"])
		var clock := "%d秒" % secs if secs < 60 else "%d分%02d秒" % [secs / 60, secs % 60]
		return "把%s拌成一份。制作需要%s。" % ["、".join(bits), clock]
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
			return "点击收取 %d 份沙漏。每份能让正在制作的食物快 10 秒。%s" % [value_of(id), tail]
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

