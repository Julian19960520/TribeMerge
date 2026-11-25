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
## 制作产物目录（data/crafts.json）：分类 → 产物和配方。现在只在图鉴里展示，还没接进订单和制作。
static var CRAFTS: Array = []
## 所有制作产物：id → 配方那一行（name / mats / secs）
static var CRAFT_IDS: Dictionary = {}
## 制作产物的大类，每个大类含几个小类（CRAFTS 里的分类），图鉴里一个大类一个页签
static var CRAFT_GROUPS: Array = []
static var RANDOM_CURVES: Array = []
## 常驻随机订单每张在「下限～上限」之间的位置，0 是下限（简单单），1 是上限（难单）。
static var RANDOM_SLOTS: Array = [0.0, 0.3, 0.55, 1.0]
## 随机单档位：{"easy": {"curve", "xp", "spread"}, "hard": {...}}。为空时退回按 RANDOM_SLOTS 插值的旧出单。
static var ORDER_TIERS: Dictionary = {}
## [[等级, 难单占比], ...]，等级之间线性插值。
static var HARD_SHARE: Array = []
## 订单给的不那那（random_orders.json coins）；空表示沿用按难度算的旧规则
static var ORDER_COINS: Dictionary = {}
## 订单给的通行证积分（random_orders.json pass_points）；空表示每单固定 1 分
static var ORDER_PASS_POINTS: Dictionary = {}
## 常驻随机单里至少保留几张简单单。
static var MIN_EASY: int = 1
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
## 4倍火种（生产器加速）：这一级解锁。开启后生产器每次耗 4 火种，产物高 2 级。
const BOOST_4_LEVEL := 42
## 好运爆发：这一级解锁。手头订单全都差得远时，点生产器有小概率直接出高 LUCKY_STEPS_MIN~LUCKY_STEPS_MAX 级（随机）的物品。
const LUCKY_LEVEL := 25
const LUCKY_CHANCE := 0.05
const LUCKY_STEPS_MIN := 2
const LUCKY_STEPS_MAX := 4
## 订单要的东西比手头同链最高的（不超过要的那级）还高这么多级，才算「难」。
const LUCKY_HARD_GAP := 3
## 储物洞每排格数：界面布局与扩容计价共用。
const STORAGE_COLS := 5

static var valid := false
static var revision := 0
static var _line_index: Dictionary = {}
static var _build_index: Dictionary = {}
static var _gen_cache: Dictionary = {}
static var _primary_cache: Dictionary = {}

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
	CRAFTS = ConfigFiles.shared(ConfigFiles.CRAFTS)["categories"]
	CRAFT_GROUPS = ConfigFiles.shared(ConfigFiles.CRAFTS).get("groups", [])
	CRAFT_IDS.clear()
	for cat in CRAFTS:
		for row in cat["items"]:
			CRAFT_IDS[str(row["id"])] = row
	var random: Dictionary = ConfigFiles.shared(ConfigFiles.RANDOM_ORDERS)
	RANDOM_SLOTS = random["slots"]
	ORDER_TIERS = {}
	for key in ["easy", "hard"]:
		if random.get("tiers", {}).get(key) is Dictionary: ORDER_TIERS[key] = random["tiers"][key]
	if ORDER_TIERS.size() < 2: ORDER_TIERS = {}
	HARD_SHARE = random.get("hard_share", {}).get("points", []) if random.get("hard_share") is Dictionary else []
	ORDER_COINS = random.get("coins", {}) if random.get("coins") is Dictionary else {}
	ORDER_PASS_POINTS = random.get("pass_points", {}) if random.get("pass_points") is Dictionary else {}
	MIN_EASY = int(random.get("min_easy", 1))
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
	_primary_cache = {}

## 第 index 档要的积分。下标从 0 起。超出最后一档时用最后一档的积分。
static func pass_need(index: int) -> int:
	if PASS_LEVELS.is_empty():
		return 8
	var i := clampi(index, 0, PASS_LEVELS.size() - 1)
	return maxi(1, int(PASS_LEVELS[i].get("need", 8)))

## 手配的剧情订单在 data/story.json，只留 1–5 级。现在的出单流程不再发它们：引导期间用 onboarding.json 的教学单，
## 引导结束后全部随机出单，随机单按难度档给声望。这里只给老存档里残留的剧情单查声望用。
static func story_orders(level: int) -> Array:
	return STORY.get(level, [])

## 升到下一级要的声望 = xp_base + (等级 - 1) / xp_div，在 data/rules.json 里调。
static func xp_need(level: int) -> int:
	var early: Array = RULES.get("xp_by_level", [])
	if level >= 1 and level <= early.size(): return maxi(1, int(early[level - 1]))
	# 表外等级沿用表里最后一级的需求；只有没配表时才退回公式。
	if not early.is_empty() and level > early.size(): return maxi(1, int(early[early.size() - 1]))
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

## 这个等级下新随机单抽到难单的概率。
static func hard_share(level: int) -> float:
	if HARD_SHARE.is_empty(): return 0.4
	var prev: Array = HARD_SHARE[0]
	if level <= int(prev[0]): return float(prev[1])
	for point in HARD_SHARE:
		if level <= int(point[0]):
			var span := maxf(1.0, float(int(point[0]) - int(prev[0])))
			return lerpf(float(prev[1]), float(point[1]), float(level - int(prev[0])) / span)
		prev = point
	return float(prev[1])

## 一张订单按理论火苗给多少不那那（random_orders.json coins 的幂律公式 round(base + k * flames^exp)）；未配 k 时返回 -1
static func order_coins_by_flames(flames: float) -> int:
	if ORDER_COINS.is_empty() or not ORDER_COINS.has("k") or flames <= 0.0: return -1
	var base := float(ORDER_COINS.get("base", 0.0))
	var k := float(ORDER_COINS["k"])
	var exp := float(ORDER_COINS.get("exp", 1.0))
	var lo := maxi(1, int(ORDER_COINS.get("min", 1)))
	return maxi(lo, int(round(base + k * pow(flames, exp))))

## 一张订单给多少不那那：kind 是 easy / hard / craft；没配 coins 时返回 -1（调用方沿用旧算法）
static func order_coins(level: int, kind: String, rng: RandomNumberGenerator) -> int:
	if ORDER_COINS.is_empty() or not ORDER_COINS.has(kind): return -1
	var grow := 1.0 + float(ORDER_COINS.get("per_level", 0.0)) * maxf(0.0, float(level - int(ORDER_COINS.get("from_level", 1))))
	return maxi(1, int(round(float(ORDER_COINS[kind]) * grow)) + rng.randi_range(0, int(ORDER_COINS.get("jitter", 0))))

## 一张订单给多少基础通行证积分（超级会员在交单处 ×2）：按订单金币折算 max(min, round(coins / coins_per_point))
static func order_pass_points(order: Dictionary) -> int:
	if ORDER_PASS_POINTS.is_empty(): return 1
	var items = order.get("mats", []) if str(order.get("kind", "")) == "craft" else order.get("items", [])
	var flames := OrderRoll.total(items) if items is Array else 0.0
	var coins := order_coins_by_flames(flames)
	if coins <= 0:
		coins = int(order.get("rw", {}).get("shell", 0))
	var per := maxf(1.0, float(ORDER_PASS_POINTS.get("coins_per_point", 22.0)))
	var lo := maxi(1, int(ORDER_PASS_POINTS.get("min", 1)))
	return maxi(lo, int(round(float(coins) / per)))

static func tier_xp(tier: String) -> int:
	return maxi(1, int(ORDER_TIERS.get(tier, {}).get("xp", 2 if tier == "hard" else 1)))

static func _tier_spread(tier: String) -> Vector2:
	var spread: Array = ORDER_TIERS.get(tier, {}).get("spread", [1.0, 1.0])
	return Vector2(float(spread[0]), float(spread[1]))

static func tier_base(level: int, tier: String) -> float:
	return float(random_diff(level, int(ORDER_TIERS.get(tier, {}).get("curve", 1 if tier == "hard" else 0))))

## 这一档在这个等级上允许的难度范围；简单单上限不超过难单下限。
static func tier_range(level: int, tier: String) -> Vector2:
	var easy := tier_base(level, "easy") * _tier_spread("easy")
	var hard := tier_base(level, "hard") * _tier_spread("hard")
	if easy.y > hard.x: easy.y = hard.x
	if easy.x > easy.y: easy.x = easy.y
	return hard if tier == "hard" else easy

## 在档位范围里抽一个目标难度：三角分布，靠近基准的多，两头少。
static func tier_target(level: int, tier: String, rng: RandomNumberGenerator) -> int:
	var r := tier_range(level, tier)
	var base := clampf(tier_base(level, tier), r.x, r.y)
	var u := rng.randf()
	var span_lo := base - r.x
	var span_hi := r.y - base
	var total := maxf(0.0001, span_lo + span_hi)
	var cut := span_lo / total
	var v := base
	if u < cut: v = r.x + sqrt(u * total * span_lo)
	else: v = r.y - sqrt((1.0 - u) * total * span_hi)
	return maxi(1, int(round(v)))

## 已有难度值属于哪一档（制作单、旧存档订单用）：落在难单范围就算难单。
static func tier_of_value(level: int, value: float) -> String:
	if ORDER_TIERS.is_empty():
		var b := random_bounds(level)
		return "hard" if value >= (b.x + b.y) * 0.5 else "easy"
	return "hard" if value >= tier_range(level, "hard").x else "easy"

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
			out.append(TextCatalog.fill(TextCatalog.source("notice.data.3c0db30d775a"), str(l.get("name", ""))))
		for sub in secondaries(l):
			if level > 1 and product_open(level, sub) and not product_open(level - 1, sub):
				out.append(TextCatalog.fill(TextCatalog.source("notice.data.1f0a007ab89d"), str(CHAINS.get(sub, {}).get("name", ""))))
	if level == int(RULES.get("craft_level", 3)):
		out.append(TextCatalog.source("notice.data.60f991a1a015"))
	for id in DISHES:
		var d: Dictionary = DISHES[id]
		if int(d["unlock"]) == level and level > int(RULES.get("craft_level", 3)):
			out.append(TextCatalog.fill(TextCatalog.source("notice.data.1b4046c64e71"), str(d["name"])))
	if level > 1 and order_total(level) > order_total(level - 1):
		out.append(TextCatalog.fill(TextCatalog.source("notice.data.cceb0cae7767"), [order_total(level) - order_total(level - 1), order_total(level)]))
	if level == CARD_LEVEL:
		out.append(TextCatalog.source("notice.data.f0ffe31b59db"))
	var acts := activity_levels()
	for name in acts:
		if int(acts[name]) == level and level > 1: out.append(TextCatalog.fill(TextCatalog.source("notice.data.a3fe574ac2c6"), name))
	if level == BOOST_LEVEL:
		out.append(TextCatalog.source("notice.data.651ad0fee6e4"))
	if level == BOOST_4_LEVEL:
		out.append(TextCatalog.source("notice.data.e3408ef57afa"))
	if level == LUCKY_LEVEL:
		out.append(TextCatalog.source("notice.data.5b622fa09c65"))
	return out

static func is_dish(id: String) -> bool:
	return DISHES.has(id)

static func is_craft(id: String) -> bool:
	return CRAFT_IDS.has(id)

## 配方第一次做出来后，图鉴里领的体力：按最高级的材料算，和同级物品的图鉴体力一样
static func craft_book_energy(id: String) -> int:
	var top := 1
	for m in CRAFT_IDS.get(id, {}).get("mats", []):
		top = maxi(top, lv(str(m)))
	return 1 if top <= 4 else top - 3

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

## 产线配置的产物链，一条线可以配一个、两个或更多。旧格式（存档回放时会用到）的 main / sub 也认。
static func products(l: Dictionary) -> Array:
	var out: Array = []
	if l.get("products") is Array:
		for ch in l["products"]:
			if str(ch) != "":
				out.append(str(ch))
		return out
	for key in ["main", "sub"]:
		var ch := str(l.get(key, ""))
		if ch != "":
			out.append(ch)
	return out

## 产线的主力产物：生产器各级掉率加起来最多的那条产物链，按原来主产物的规则走（订单常要、难度按合成次数算）。
## 不用单独配置，生产器怎么配掉落，它就是谁；掉率一样时取产物列表里靠前的。
static func primary(l: Dictionary) -> String:
	var key := str(l.get("id", ""))
	if _primary_cache.has(key):
		return _primary_cache[key]
	var list := products(l)
	var weight := {}
	for ch in list:
		weight[ch] = 0
	var prod = CHAINS.get(str(l.get("gen", "")), {}).get("prod", [])
	if prod is Array:
		for slot in prod:
			if not (slot is Dictionary) or not (slot.get("drops") is Array):
				continue
			for d in slot["drops"]:
				if d is Dictionary and weight.has(chain(str(d.get("id", "")))):
					weight[chain(str(d["id"]))] += int(d.get("p", 0))
	var best := ""
	for ch in list:
		if best == "" or int(weight[ch]) > int(weight[best]):
			best = ch
	_primary_cache[key] = best
	return best

## 产线上主力产物以外的产物：生产器掉得少，按原来副产物的规则走（晚一点进订单、难度按掉率折算）。
static func secondaries(l: Dictionary) -> Array:
	var main := primary(l)
	var out: Array = []
	for ch in products(l):
		if ch != main:
			out.append(ch)
	return out

## 这条产物链挂在哪条产线上；没挂在任何产线上时返回空字典
static func line_of_product(ch: String) -> Dictionary:
	for l in LINES:
		if products(l).has(ch):
			return l
	return {}

## 现场绘制和商店摆货用的角色：生产器 G，主力产物 M，其余产物 S
static func draw_role(ch: String) -> String:
	var def: Dictionary = CHAINS.get(ch, {})
	var l := line(str(def.get("line", "")))
	if l.is_empty():
		return ""
	if str(l.get("gen", "")) == ch:
		return "G"
	if not products(l).has(ch):
		return ""
	return "M" if primary(l) == ch else "S"

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
		var ch := primary(l)
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
	var l := line_of_product(chain_id)
	if not l.is_empty():
		if primary(l) == chain_id:
			return int(l.get("unlock", 1)) <= level
		return sub_unlock_level(int(l.get("unlock", 1))) <= level
	return true

## 通行证奖励里的棋盘物品：这条链当前等级还没开，就换成已开放产线里同等级的物品。资源、宝箱、卡包保持原样。
static func for_pass(level: int, rewards: Array) -> Array:
	var out: Array = []
	for rw in rewards:
		if not rw is Array or rw.size() < 2:
			continue
		var id := opened_reward(level, str(rw[0]))
		if id == "":
			continue
		var copy: Array = rw.duplicate()
		copy[0] = id
		out.append(copy)
	return out

static func opened_reward(level: int, id: String) -> String:
	if is_numeric_resource(id) or not is_board_item(id):
		return id
	var kind := type_of(id)
	if kind == "item":
		if product_open(level, chain(id)):
			return id
		return _stand_in_item(level, id)
	if kind == "gen":
		if _gen_open(level, chain(id)):
			return id
		return _stand_in_gen(level, id)
	if kind == "dish":
		return id if int(DISHES[id].get("unlock", 1)) <= level else ""
	return id

static func _gen_open(level: int, chain_id: String) -> bool:
	for l in LINES:
		if str(l.get("gen", "")) == chain_id:
			return int(l.get("unlock", 1)) <= level
	return true

static func _stand_in_item(level: int, id: String) -> String:
	var pools := _open_chains(level, "S" if draw_role(chain(id)) == "S" else "M")
	if pools.is_empty():
		pools = _open_chains(level, "M")
	if pools.is_empty():
		return ""
	var ch := str(pools[0])
	return "%s_%d" % [ch, clampi(lv(id), 1, max_lv(ch))]

static func _stand_in_gen(level: int, id: String) -> String:
	var lines := unlocked_lines(level)
	if lines.is_empty():
		return ""
	var ch := str(lines[0].get("gen", ""))
	if ch == "" or max_lv(ch) < 1:
		return ""
	return "%s_%d" % [ch, clampi(lv(id), 1, max_lv(ch))]

## role 为 M 时取各条已开放产线的主力产物，为 S 时取其余产物
static func _open_chains(level: int, role: String) -> Array:
	var out: Array = []
	for l in unlocked_lines(level):
		for ch in ([primary(l)] if role == "M" else secondaries(l)):
			if ch != "" and product_open(level, ch):
				out.append(ch)
	return out

## 制作产物要等它所有材料都能进订单的那一级才开放；有材料永远不开放时返回 0
static func craft_unlock(mats: Array) -> int:
	var need := 1
	for m in mats:
		var ch := chain(str(m))
		var at := 0
		for lv in range(1, 100):
			if product_open(lv, ch):
				at = lv
				break
		if at == 0:
			return 0
		need = maxi(need, at)
	return need

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
	if Data.chain(id) == "orderbox": return TextCatalog.fill(TextCatalog.source("notice.data.c14a2bd6dafb"), [name_of(id), int(SpecialChests.order_definition(id)["count"])])
	if Data.chain(id) == "premiumbox": return TextCatalog.fill(TextCatalog.source("notice.data.7c86baa46882"), [name_of(id), SpecialChests.count(id)])
	if Data.chain(id) in ["energybox", "amberbox"]:
		var total := 0
		for item in SpecialChests.definition(id)["items"]: total += value_of(str(item))
		var line := "notice.data.57a9680ca8c6" if Data.chain(id) == "energybox" else "notice.data.8718219c205f"
		return TextCatalog.fill(TextCatalog.source(line), [name_of(id), SpecialChests.count(id), total])
	if Data.chain(id) == "chest": return TextCatalog.fill(TextCatalog.source("notice.data.f531c7922f96"), [name_of(id), SpecialChests.count(id)])
	if DISHES.has(id):
		var d: Dictionary = DISHES[id]
		var bits: PackedStringArray = []
		for m in d["mats"]:
			bits.append(name_of(str(m)))
		var secs := int(d["secs"])
		var clock := TextCatalog.fill(TextCatalog.source("notice.data.517926f2a953"), secs)
		if secs >= 3600:
			clock = TextCatalog.fill(TextCatalog.source("notice.data.f24d0c399e61"), (secs / 3600)) if secs % 3600 == 0 else TextCatalog.fill(TextCatalog.source("notice.data.f6dc3c925a2d"), [secs / 3600, secs % 3600 / 60])
		elif secs >= 60:
			clock = TextCatalog.fill(TextCatalog.source("notice.data.441275a944fb"), (secs / 60)) if secs % 60 == 0 else TextCatalog.fill(TextCatalog.source("notice.data.14bf9175170a"), [secs / 60, secs % 60])
		return TextCatalog.fill(TextCatalog.source("notice.data.fabf3c04d980"), ["、".join(bits), clock, int(d["unlock"])])
	var t := type_of(id)
	var nx := next_id(id)
	var tail := TextCatalog.fill(TextCatalog.source("notice.data.f706e677fd73"), name_of(nx)) if nx != "" else TextCatalog.source("notice.data.994bd700ac50")
	match t:
		"gen":
			var st := gen_stats(id)
			if st.is_empty():
				var n := first_prod_lv(chain(id))
				if n <= 0:
					return TextCatalog.fill(TextCatalog.source("notice.data.4901cf0da721"), tail)
				return TextCatalog.fill(TextCatalog.source("notice.data.0c5c3fdb9314"), [n, tail])
			var bits: PackedStringArray = []
			for d in st["drops"]:
				bits.append("%s %d" % [name_of(str(d["id"])), int(d["p"])])
			return TextCatalog.fill(TextCatalog.source("notice.data.5cb11c71f59f"), ["、".join(bits), tail])
		"egen":
			var st := gen_stats(id)
			if st.is_empty():
				return TextCatalog.source("notice.data.da558152175b")
			var rest := int(st["refill"])
			var rest_text := TextCatalog.fill(TextCatalog.source("notice.data.f24d0c399e61"), (rest / 60)) if rest % 60 == 0 else TextCatalog.fill(TextCatalog.source("notice.data.441275a944fb"), rest)
			var starter: Dictionary = RULES.get("starter_generator", {})
			if id == str(starter.get("item", "")):
				return TextCatalog.fill(TextCatalog.source("notice.data.2e905efaff17"), [int(starter["reward_level"]), int(starter["lifetime_sec"]) / 86400, rest_text, int(st["charges"])])
			return TextCatalog.fill(TextCatalog.source("notice.data.08c4e6ad065d"), [int(st["charges"]), rest_text])
		"item":
			var l := line_of(id)
			var sell := value_of(id)
			var back := TextCatalog.fill(TextCatalog.source("notice.data.b797c33cee7e"), sell) if sell > 0 else ""
			if not l.is_empty():
				return TextCatalog.fill(TextCatalog.source("notice.data.3d317673a560"), [CHAINS[l["gen"]]["name"], back, tail])
			if back != "":
				return back + tail
		"energy", "shell", "amber", "sand" when value_of(id) <= 0:
			return TextCatalog.fill(TextCatalog.source("notice.data.d63394fd4de9"), tail)
		"energy":
			return TextCatalog.fill(TextCatalog.source("notice.data.bfcc2a59e43c"), [value_of(id), tail])
		"shell":
			return TextCatalog.fill(TextCatalog.source("notice.data.4e95c9c43291"), [value_of(id), tail])
		"amber":
			return TextCatalog.fill(TextCatalog.source("notice.data.ce2d2f368aea"), [value_of(id), tail])
		"sand":
			return TextCatalog.fill(TextCatalog.source("notice.data.e6c372cc495b"), [value_of(id), rush_text(), tail])
		"choice":
			return TextCatalog.fill(TextCatalog.source("notice.data.10ea43411057"), name_of(id))
		"chest":
			return TextCatalog.source("notice.data.83a2fa3dc002")
		"pack":
			return TextCatalog.fill(TextCatalog.source("notice.data.15eca9cf6383"), [lv(id), int(CardPacks.config()["cards_per_pack"]), CardPacks.probability_text(id)])
		"token":
			return TextCatalog.fill(TextCatalog.source("notice.data.14617eddea71"), int(RULES.get("token_step", 10)))
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

## 一件部件要建几次才落成（没写就是 1 次）
static func part_steps(part) -> int:
	return maxi(1, int(part.get("steps", 1))) if part is Dictionary else 1

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
	return TextCatalog.fill(TextCatalog.source("notice.data.441275a944fb"), (s / 60)) if s % 60 == 0 else TextCatalog.fill(TextCatalog.source("notice.data.517926f2a953"), s)

## 一份沙漏让制作快多少秒（rules.json rush_sec）。
static func rush_sec() -> int:
	return maxi(1, int(RULES.get("rush_sec", 60)))

## 同时最多几张制作订单：craft_cap_at 每个元素是多开一张的等级。
static func craft_cap(level: int) -> int:
	return _cap_at("craft_cap_at", [int(RULES.get("craft_level", 3))], level, 9)

## 制作订单附送的沙漏：按这张单实际的制作秒数取 craft_sand 里最后一个够得着的档 [[最少秒数, 物品], ...]。
static func craft_sand(dish_id: String, secs: int = -1) -> String:
	if not DISHES.has(dish_id):
		return ""
	if secs < 0: secs = int(DISHES[dish_id].get("secs", 0))
	var out := ""
	for t in RULES.get("craft_sand", []):
		if t is Array and t.size() >= 2 and secs >= int(t[0]):
			out = str(t[1])
	return out

## 制作单返还多少份沙漏（每份 rush_sec 秒）：制作秒数 × craft_sand_cover 在该等级的覆盖率。没配时返回 -1，沿用 craft_sand 物品档。
static func craft_sand_units(level: int, secs: int) -> int:
	var cfg: Variant = RULES.get("craft_sand_cover", {})
	if not cfg is Dictionary or (cfg.get("points", []) as Array).is_empty(): return -1
	var points: Array = cfg["points"]
	var cover := float(points[points.size() - 1][1])
	if level <= int(points[0][0]): cover = float(points[0][1])
	else:
		for i in range(1, points.size()):
			if level <= int(points[i][0]):
				var a: Array = points[i - 1]
				var b: Array = points[i]
				cover = lerpf(float(a[1]), float(b[1]), float(level - int(a[0])) / maxf(1.0, float(int(b[0]) - int(a[0]))))
				break
	return maxi(1, int(ceil(float(secs) * cover / float(rush_sec()))))

## 这个主角等级下做这道菜要多少秒：rules.craft_time.by_level 给出该等级的基准秒数（等级之间线性插值），
## 再按这道菜在当前可做菜里的难度（配置秒数的对数排位）乘 spread 区间的系数。没配 craft_time 时用菜自己的秒数。
static func craft_secs(level: int, dish_id: String) -> int:
	if not DISHES.has(dish_id): return 1
	var own := maxi(1, int(DISHES[dish_id].get("secs", 1)))
	var cfg: Variant = RULES.get("craft_time", {})
	if not cfg is Dictionary or (cfg.get("by_level", []) as Array).is_empty(): return own
	var points: Array = cfg["by_level"]
	var base := float(points[0][1])
	if level > int(points[0][0]):
		base = float(points[points.size() - 1][1])
		for i in range(1, points.size()):
			if level <= int(points[i][0]):
				var a: Array = points[i - 1]
				var b: Array = points[i]
				base = lerpf(float(a[1]), float(b[1]), float(level - int(a[0])) / maxf(1.0, float(int(b[0]) - int(a[0]))))
				break
	var lo := own
	var hi := own
	for d in dishes_for(maxi(level, int(DISHES[dish_id].get("unlock", 1)))):
		lo = mini(lo, maxi(1, int(d["secs"])))
		hi = maxi(hi, maxi(1, int(d["secs"])))
	var t := 0.5
	if hi > lo: t = clampf(log(float(own) / float(lo)) / log(float(hi) / float(lo)), 0.0, 1.0)
	var spread: Array = cfg.get("spread", [1.0, 1.0])
	return maxi(1, int(round(base * lerpf(float(spread[0]), float(spread[1]), t))))

## 制作时长的文字：x秒 / x分 / x分x秒 / x小时 / x小时x分。
static func secs_text(secs: int) -> String:
	if secs >= 3600:
		return TextCatalog.fill(TextCatalog.source("notice.data.f24d0c399e61"), (secs / 3600)) if secs % 3600 == 0 else TextCatalog.fill(TextCatalog.source("notice.data.f6dc3c925a2d"), [secs / 3600, secs % 3600 / 60])
	if secs >= 60:
		return TextCatalog.fill(TextCatalog.source("notice.data.441275a944fb"), (secs / 60)) if secs % 60 == 0 else TextCatalog.fill(TextCatalog.source("notice.data.14bf9175170a"), [secs / 60, secs % 60])
	return TextCatalog.fill(TextCatalog.source("notice.data.517926f2a953"), secs)

## 每次合成最多掉一件资源；按顺序占用概率区间，剩余概率不掉落。
static func resource_drop(scope: String, roll: float, level: int, merged: String = "") -> String:
	if scope == "main":
		if type_of(merged) != "item" or lv(merged) < 2 or lv(merged) > max_lv(chain(merged)): return ""
		var allowed := false
		for line in LINES:
			if str(line["id"]) in RULES.get("merge_resource_lines", []) and level >= int(line["unlock"]) and products(line).has(chain(merged)):
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
