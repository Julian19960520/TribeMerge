class_name Data
extends RefCounted
## 玩法数值在 data/*.json。游戏主页左下「配置」可以改，每一页的保存只写回自己的文件。
## 代码里仍用 Data.LINES、Data.CHAINS 这些名字。保存后会立刻重新读入。

const ConfigFiles := preload("res://scripts/config/config_files.gd")
const Layout := preload("res://scripts/config/board_layout.gd")

static var LINES: Array = []
static var CHAINS: Dictionary = {}
## 纯数值奖励只保留图标与说明，不属于棋盘物品链。
static var REWARD_RESOURCES: Dictionary = {}
static var PEOPLE: Array = []
static var STORY: Dictionary = {}
static var ALBUMS: Array = []
static var AMBER_PACKS: Array = []
static var BUILDS: Array = []
static var LEVEL_REWARDS := {}
static var STORE_HOT: Array = []
## 集市「不那那小摊」（data/store_shell.json）：每项 {"id", "price", "stock"}，每 STORE_SHELL_HOURS 小时刷新
static var STORE_SHELL: Array = []
static var STORE_SHELL_HOURS := 8
static var STORE_SHELL_REFRESH := 5
static var PASS_LEVELS: Array = []
## 通行证赛季：{"days": 35, "start": "2026-11-02"}（北京时间零点起算）
static var PASS_SEASON: Dictionary = {}
static var PASS_PURCHASE: Dictionary = {}
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
## 活动和入口按等级一个个开放：竞品开局什么活动都没有，玩熟了合成再陆续出现。
## 带自己配置文件的活动（剑齿虎、化石、双人竞速、篝火竞速、月石遗迹）用各自的 unlock_level。
const FEATURE_LEVELS := {"seven": 3, "gift": 4, "pass": 5, "rank": 6, "ufo": 7}
static var FEATURE_NAMES := {"seven": TextCatalog.source("notice.data.f205a3d7f611"), "gift": TextCatalog.source("notice.data.70541fc12efb"), "pass": TextCatalog.source("developer.host.2f0a2b5a01ff"), "rank": TextCatalog.source("notice.data.1ee95aa94712"), "ufo": TextCatalog.source("notice.data.c086e8b44aa2")}
static func feature_level(id: String) -> int:
	return int(FEATURE_LEVELS.get(id, 1))

## 各活动开放等级（升级面板「新内容」和入口显示共用）
static func activity_levels() -> Dictionary:
	var out := {}
	for id in FEATURE_LEVELS: out[FEATURE_NAMES[id]] = int(FEATURE_LEVELS[id])
	for f in ["tiger_escape", "fossil_dig", "duel_race", "race"]:
		var c: Dictionary = ConfigFiles.shared("res://data/%s.json" % f)
		var title := str(c.get("title", {"duel_race": TextCatalog.source("notice.data.33c9c97e48ba"), "race": TextCatalog.source("notice.data.bb33bbf8c01b")}.get(f, f)))
		out[title] = int(c.get("unlock_level", 1))
	for s in ConfigFiles.shared("res://data/merge_events.json").get("seasons", []):
		if bool(s.get("enabled", true)): out[str(s.get("entry_title", s.get("title", "")))] = int(s.get("unlock_level", 1))
	return out

## 双倍火种（生产器加速）：这一级解锁。开启后生产器每次耗 2 火种，产物高 1 级。
const BOOST_LEVEL := 18
## 储物洞每排格数：界面布局与扩容计价共用。
const STORAGE_COLS := 5

static var valid := false
static var revision := 0
static var _line_index: Dictionary = {}
static var _build_index: Dictionary = {}
static var _gen_cache: Dictionary = {}

static func _static_init() -> void:
	refresh()

## Commit a validated registry generation; on failure retain the prior complete generation.
static func refresh() -> bool:
	ConfigFiles.runtime_overrides = PriceBook.catalog.get("documents", {})
	if not ConfigFiles.refresh():
		for error in ConfigFiles.last_errors: push_error(error)
		return false
	_load()
	revision = ConfigFiles.revision
	valid = true
	return true

static func _load() -> void:
	LINES = ConfigFiles.shared(ConfigFiles.LINES)
	CHAINS = {}
	REWARD_RESOURCES = ConfigFiles.shared(ConfigFiles.REWARD_RESOURCES)
	for raw in ConfigFiles.shared(ConfigFiles.CHAINS):
		var definition: Dictionary = raw.duplicate(true)
		definition.erase("id")
		CHAINS[raw["id"]] = definition
	PEOPLE = ConfigFiles.shared(ConfigFiles.PEOPLE)
	STORY = {}
	for level in ConfigFiles.shared(ConfigFiles.STORY)["levels"]:
		var orders := []
		for raw in level["orders"]:
			var order := {"who": raw["who"], "items": raw["items"], "xp": raw["xp"], "shell": raw["shell"], "rewards": raw["rewards"]}
			if raw.has("token"): order["token"] = raw["token"]
			if raw.has("say"): order["say"] = raw["say"]
			orders.append(order)
		STORY[level["level"]] = orders
	ALBUMS = ConfigFiles.shared(ConfigFiles.ALBUMS)
	AMBER_PACKS = ConfigFiles.shared(ConfigFiles.AMBER)
	BUILDS = ConfigFiles.shared(ConfigFiles.BUILDS)
	LEVEL_REWARDS = {}
	for row in ConfigFiles.shared(ConfigFiles.LEVELS)["levels"]: LEVEL_REWARDS[row["level"]] = row["rewards"]
	STORE_HOT = ConfigFiles.shared(ConfigFiles.STORE)
	var shell: Dictionary = ConfigFiles.shared(ConfigFiles.STORE_SHELL)
	STORE_SHELL = shell["items"]
	STORE_SHELL_REFRESH = shell["refresh_amber"]
	STORE_SHELL_HOURS = shell["refresh_hours"]
	var pass_data: Dictionary = ConfigFiles.shared(ConfigFiles.PASS)
	PASS_LEVELS = pass_data["levels"]
	PASS_SEASON = pass_data["season"]
	PASS_PURCHASE = pass_data.get("purchase", {})
	RULES = ConfigFiles.shared(ConfigFiles.RULES)
	var board: Dictionary = ConfigFiles.shared(ConfigFiles.BOARD)
	BOARD = board["cells"]
	LOCKS = board["locks"]
	REWARDS = board["rewards"]
	DISHES = {}
	for row in ConfigFiles.shared(ConfigFiles.DISHES): DISHES[row["id"]] = row
	var random: Dictionary = ConfigFiles.shared(ConfigFiles.RANDOM_ORDERS)
	RANDOM_SLOTS = random["slots"]
	var low := []
	var high := []
	var count := 0
	for curve in random["curves"]: count = maxi(count, curve["diff"].size())
	for i in count:
		var minimum := 2147483647
		var maximum := 1
		for curve in random["curves"]:
			if i < curve["diff"].size():
				minimum = mini(minimum, int(curve["diff"][i]))
				maximum = maxi(maximum, int(curve["diff"][i]))
		low.append(minimum)
		high.append(maximum)
	RANDOM_CURVES = [{"name": TextCatalog.source("notice.data.2c3f8d6ce49a"), "diff": low}, {"name": TextCatalog.source("notice.data.8e7ddbeee310"), "diff": high}]
	UNLOCK_ROWS = {}
	for row in ConfigFiles.shared(ConfigFiles.UNLOCKS)["rows"]: UNLOCK_ROWS[row["id"]] = row["open"]
	_line_index = {}
	for row in LINES: _line_index[row["id"]] = row
	_build_index = {}
	for row in BUILDS: _build_index[row["id"]] = row
	_gen_cache = {}

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
	var early: Array = RULES.get("xp_by_level", [])
	if level >= 1 and level <= early.size(): return maxi(1, int(early[level - 1]))
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
			out.append(TextCatalog.source("notice.data.3c0db30d775a") % str(l.get("name", "")))
		var sub := str(l.get("sub", ""))
		if sub != "" and level > 1 and product_open(level, sub) and not product_open(level - 1, sub):
			out.append(TextCatalog.source("notice.data.1f0a007ab89d") % str(CHAINS.get(str(l["sub"]), {}).get("name", "")))
	if level == int(RULES.get("craft_level", 3)):
		out.append(TextCatalog.source("notice.data.60f991a1a015"))
	for id in DISHES:
		var d: Dictionary = DISHES[id]
		if int(d["unlock"]) == level and level > int(RULES.get("craft_level", 3)):
			out.append(TextCatalog.source("notice.data.1b4046c64e71") % str(d["name"]))
	if level > 1 and order_total(level) > order_total(level - 1):
		out.append(TextCatalog.source("notice.data.cceb0cae7767") % [order_total(level) - order_total(level - 1), order_total(level)])
	if level == CARD_LEVEL:
		out.append(TextCatalog.source("notice.data.f0ffe31b59db"))
	var acts := activity_levels()
	for name in acts:
		if int(acts[name]) == level and level > 1: out.append(TextCatalog.source("notice.data.a3fe574ac2c6") % name)
	if level == BOOST_LEVEL:
		out.append(TextCatalog.source("notice.data.651ad0fee6e4"))
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
	return CHAINS.get(ch, {}).get("items", []).size()

static func is_numeric_resource(id: String) -> bool:
	return REWARD_RESOURCES.has(id)

static func is_board_item(id: String) -> bool:
	if DISHES.has(id): return true
	return CHAINS.has(chain(id)) and lv(id) >= 1 and lv(id) <= max_lv(chain(id))

static func is_known(id: String) -> bool:
	return is_numeric_resource(id) or is_board_item(id)

static func type_of(id: String) -> String:
	if is_numeric_resource(id): return str(REWARD_RESOURCES[id]["type"])
	if DISHES.has(id):
		return "dish"
	return str(CHAINS.get(chain(id), {}).get("type", ""))

static func name_of(id: String) -> String:
	if is_numeric_resource(id): return str(REWARD_RESOURCES[id]["name"])
	if DISHES.has(id):
		return str(DISHES[id]["name"])
	return CHAINS[chain(id)]["items"][lv(id) - 1]

static func next_id(id: String) -> String:
	if is_numeric_resource(id): return ""
	if DISHES.has(id):
		return ""
	var ch := chain(id)
	var l := lv(id)
	if l >= max_lv(ch):
		return ""
	return "%s_%d" % [ch, l + 1]

static func value_of(id: String) -> int:
	if is_numeric_resource(id): return 1
	if DISHES.has(id):
		return 0
	var c: Dictionary = CHAINS[chain(id)]
	if c.has("value"):
		return c["value"][lv(id) - 1]
	return 0

# ---------------------------------------------------------------- 产线

static func line(id: String) -> Dictionary:
	return _line_index.get(id, {})

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
		if d is Dictionary and is_board_item(str(d.get("id", ""))) and int(d.get("p", 0)) > 0:
			return true
	return false

## 生产器的产出参数；这一级没配产物时返回空字典
static func gen_stats(id: String) -> Dictionary:
	if not _gen_cache.has(id): _gen_cache[id] = _make_gen_stats(id)
	return _gen_cache[id]

static func _make_gen_stats(id: String) -> Dictionary:
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
		if d is Dictionary and is_board_item(str(d.get("id", ""))) and int(d.get("p", 0)) > 0:
			usable.append({"id": str(d["id"]), "p": int(d["p"])})
	if usable.is_empty(): return {}
	var st := {"drops": usable}
	if line(str(def.get("line", ""))).get("cooldown", false):
		st["charges"] = int(slot.get("charges", 8))
		st["refill"] = int(slot.get("refill_min", 12))
	return st

## 体力生产器：不耗体力，具体有效期与恢复时钟由新人生产器规则管理。
## 配置在 chains.json 这条链的 prod[0]。返回格式同 gen_stats，多一个 "free"。
static func egen_stats(id: String) -> Dictionary:
	var prod = CHAINS[chain(id)].get("prod", [])
	if not (prod is Array) or prod.is_empty() or not (prod[0] is Dictionary):
		return {}
	var slot: Dictionary = prod[0]
	var usable: Array = []
	for d in slot.get("drops", []):
		if d is Dictionary and is_board_item(str(d.get("id", ""))) and int(d.get("p", 0)) > 0:
			usable.append({"id": str(d["id"]), "p": int(d["p"])})
	if usable.is_empty():
		return {}
	return {"drops": usable, "charges": int(slot.get("charges", 8)), "refill": int(slot.get("refill_min", 720)), "free": true}

static func producers_of(ch: String) -> Array:
	var l := line(str(CHAINS[ch].get("line", "")))
	if l.is_empty() or l["gen"] == ch:
		return []
	var pid := first_prod_id(l)
	if pid == "":
		return []
	return [pid]

static func describe(id: String) -> String:
	if is_numeric_resource(id): return str(REWARD_RESOURCES[id]["description"])
	if type_of(id) == "upgrade": return TextCatalog.source("notice.data.83eb30deb5bb")
	if type_of(id) == "scissors": return TextCatalog.source("notice.data.befb6f57c800")
	if Data.chain(id) == "orderbox": return TextCatalog.source("notice.data.c14a2bd6dafb") % int(SpecialChests.order_definition(id)["count"])
	if Data.chain(id) == "premiumbox": return TextCatalog.source("notice.data.7c86baa46882") % [lv(id), SpecialChests.count(id)]
	if Data.chain(id) == "energybox":
		var total := 0
		for item in SpecialChests.definition(id)["items"]: total += value_of(str(item))
		return TextCatalog.source("notice.data.57a9680ca8c6") % [lv(id), SpecialChests.count(id), total]
	if Data.chain(id) == "chest": return TextCatalog.source("notice.data.f531c7922f96") % [lv(id), SpecialChests.count(id)]
	if DISHES.has(id):
		var d: Dictionary = DISHES[id]
		var bits: PackedStringArray = []
		for m in d["mats"]:
			bits.append(name_of(str(m)))
		var secs := int(d["secs"])
		var clock := TextCatalog.source("notice.data.517926f2a953") % secs
		if secs >= 3600:
			clock = TextCatalog.source("notice.data.f24d0c399e61") % (secs / 3600) if secs % 3600 == 0 else TextCatalog.source("notice.data.f6dc3c925a2d") % [secs / 3600, secs % 3600 / 60]
		elif secs >= 60:
			clock = TextCatalog.source("notice.data.441275a944fb") % (secs / 60) if secs % 60 == 0 else TextCatalog.source("notice.data.14bf9175170a") % [secs / 60, secs % 60]
		return TextCatalog.source("notice.data.fabf3c04d980") % ["、".join(bits), clock, int(d["unlock"])]
	var t := type_of(id)
	var nx := next_id(id)
	var tail := TextCatalog.source("notice.data.f706e677fd73") % name_of(nx) if nx != "" else TextCatalog.source("notice.data.994bd700ac50")
	match t:
		"gen":
			var st := gen_stats(id)
			if st.is_empty():
				var n := first_prod_lv(chain(id))
				if n <= 0:
					return TextCatalog.source("notice.data.4901cf0da721") % tail
				return TextCatalog.source("notice.data.0c5c3fdb9314") % [n, tail]
			var bits: PackedStringArray = []
			for d in st["drops"]:
				bits.append("%s %d" % [name_of(str(d["id"])), int(d["p"])])
			return TextCatalog.source("notice.data.5cb11c71f59f") % ["、".join(bits), tail]
		"egen":
			var st := gen_stats(id)
			if st.is_empty():
				return TextCatalog.source("notice.data.da558152175b")
			var rest := int(st["refill"])
			var rest_text := TextCatalog.source("notice.data.f24d0c399e61") % (rest / 60) if rest % 60 == 0 else TextCatalog.source("notice.data.441275a944fb") % rest
			var starter: Dictionary = RULES.get("starter_generator", {})
			if id == str(starter.get("item", "")):
				return TextCatalog.source("notice.data.2e905efaff17") % [int(starter["reward_level"]), int(starter["lifetime_sec"]) / 86400, rest_text, int(st["charges"])]
			return TextCatalog.source("notice.data.08c4e6ad065d") % [int(st["charges"]), rest_text]
		"item":
			var l := line_of(id)
			var sell := value_of(id)
			var back := TextCatalog.source("notice.data.b797c33cee7e") % sell if sell > 0 else ""
			if not l.is_empty():
				return TextCatalog.source("notice.data.3d317673a560") % [CHAINS[l["gen"]]["name"], back, tail]
			if back != "":
				return back + tail
		"energy", "shell", "amber", "sand" when value_of(id) <= 0:
			return TextCatalog.source("notice.data.d63394fd4de9") % tail
		"energy":
			return TextCatalog.source("notice.data.bfcc2a59e43c") % [value_of(id), tail]
		"shell":
			return TextCatalog.source("notice.data.4e95c9c43291") % [value_of(id), tail]
		"amber":
			return TextCatalog.source("notice.data.ce2d2f368aea") % [value_of(id), tail]
		"sand":
			return TextCatalog.source("notice.data.e6c372cc495b") % [value_of(id), rush_text(), tail]
		"choice":
			return TextCatalog.source("notice.data.10ea43411057") % lv(id)
		"chest":
			return TextCatalog.source("notice.data.83a2fa3dc002")
		"pack":
			return TextCatalog.source("notice.data.15eca9cf6383") % [lv(id), int(CardPacks.config()["cards_per_pack"]), CardPacks.probability_text(id)]
		"token":
			return TextCatalog.source("notice.data.14617eddea71") % int(RULES.get("token_step", 10))
		"xp":
			return TextCatalog.source("notice.data.78a6f00684d0")
	return tail

static func build_def(id: String) -> Dictionary:
	return _build_index.get(id, {})

## Every building uses the current explicit part representation.
static func build_parts(building: Dictionary) -> Array:
	return building.get("parts", [])

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
	return ConfigFiles.shared(ConfigFiles.DAILY_DEALS)

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
	return PriceBook.price(id, "bubble")

## 合成掉不那那：合成结果越高级，掉的不那那物品越大（rules.json merge_coin.tiers = [[最低等级, 物品], ...]）。
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

## 合成掉沙漏：普通物品合成后，在掉不那那之外再有 merge_sand.chance 的机会掉一个沙漏（rules.json merge_sand）。
## 和不那那共用同一个掷点：[不那那概率, 不那那概率 + 沙漏概率) 这一段掉沙漏。服务器 Economy.merge_sand_item 同一套算法。
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
	return TextCatalog.source("notice.data.441275a944fb") % (s / 60) if s % 60 == 0 else TextCatalog.source("notice.data.517926f2a953") % s

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
	if scope == "main":
		if type_of(merged) != "item" or lv(merged) < 2 or lv(merged) > max_lv(chain(merged)): return ""
		var allowed := false
		for line in LINES:
			if str(line["id"]) in RULES.get("merge_resource_lines", []) and level >= int(line["unlock"]) and chain(merged) in [str(line["main"]), str(line["sub"])]:
				allowed = true
				break
		if not allowed: return ""
	var total := 0.0
	for entry in RULES.get("merge_resource_drops", {}).get(scope, []):
		if level < int(entry.get("min_level", 1)): continue
		if bool(entry.get("items_only", false)) and type_of(merged) != "item": continue
		var id := str(entry.get("item", ""))
		if not is_board_item(id) or not type_of(id) in ["shell", "amber", "energy", "sand"]: continue
		total += clampf(float(entry.get("chance", 0)), 0.0, 1.0)
		if roll < total: return id
	return ""
