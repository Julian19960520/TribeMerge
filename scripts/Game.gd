extends Node
## Current state and command gateway. Queries live on the injected rules context.

signal boil_tick
signal changed
signal board_changed
signal orders_changed
## A committed order delivery, consumed by race and presentation listeners.
signal order_delivered(items: Array)

const Layout := preload("res://scripts/config/board_layout.gd")
const Roll := preload("res://scripts/OrderRoll.gd")
const RuleContext := preload("res://scripts/domain/RuleContext.gd")
var rules: RuleContext
const StateCodec := preload("res://scripts/domain/StateCodec.gd")

var COLS := 7
var ROWS := 9
var MAX_ENERGY := 100
var REGEN_SEC := 120
const SAVE_PATH := "user://tribe_save.json"
## 实际读写的存档路径。测试可以用 `-- --save=user://xxx.json` 换掉，不碰真实存档
var save_path := SAVE_PATH
## Headless balance simulation only. Negative keeps the normal clock/save path.
var simulation_time := -1.0
## 启动时读到了本地存档（false = 没存档、新开了一局，云存档会试着从服务器恢复）
var loaded_save := false
var RANDOM_ORDERS := 4
var TOKEN_STEP := 10

var main: Node = null
var ufo_offer: Dictionary = {}
## 付费限时礼包（赶大集 / 火种大礼包）每期状态，见 scripts/events/Offers.gd
var offers: Dictionary = {}
var local_race: Dictionary = {}
var duel_race: Dictionary = {}
var tiger_escape: Dictionary = {}
var fossil_dig: Dictionary = {}
var tiger_escape_seen: Dictionary = {}
var gm_activities := false
var seven_day: Dictionary = {}
signal seven_day_changed
var merge_events: Dictionary = {}
signal merge_event_changed
signal presentation_event(kind: String, payload: Dictionary)
var _presentation_events: Array = []
var font_title: Font
var font_body: Font

var level := 1
var xp := 0
var energy := 100
var shells := 320
var amber := 140
var rush := 0
var energy_stamp := 0.0
## 双倍体力模式开关（Data.BOOST_LEVEL 级解锁）
var boost := false
## GM 按钮提前解锁了双倍体力（不看等级）
var boost_gm := false
var board: Array = []
## 最近一次合成解开的巨石格子，给崩坏动画用
var opened: Array = []
var inv: Array = []
var inv_chests: Dictionary = {}
var inv_cap := 5
var discovered := {}
## 图鉴里已经领过奖的物品。新发现的还没领，格子上是礼物。
var book_claimed := {}
var orders: Array = []
var order_serial := 0
var story_done: Dictionary = {}
var pending_orders: Array = []
## 刚做完的格子，棋盘下一帧播合成爆开
var cooked_pop: Array = []
var builds := {}
var cards := {}
var card_stars := 0
var stash: Array = []
var tokens := 0
var token_claimed := 0
var pass_pts := 0
var pass_tier := 0
var pass_free: Array = []
var pass_prem: Array = []
## 超级贵宾那一列已领的级别（贵宾列是 pass_prem）
var pass_super: Array = []
var pass_endless := 0
var pass_super_bonus := false
var pass_season := ""
var scroll_drag := false
## 有列表正在拖动或惯性滑动。这时推迟线条沸腾，避免整屏重绘把滚动卡住。
var scroll_moving := false
var _boil_hold := false
## boil：沸腾线（线条每 0.125 秒换一帧抖动）。关掉后线条定格，不再按节拍重绘。
var settings := {"music": true, "sound": true, "vibrate": true, "hint": true, "boil": true}
var hot_bought := {}
var hot_revision := 0
var _hot_refresh_busy := false
var _bubble_busy := {}
var _chest_busy := {}
var _pack_busy := false
var _storage_busy := false
var _shell_refresh_busy := false
## 通行证价格（元），来自 data/pass.json 的 purchase；服务器按同一份开单。
var PASS_CNY: Dictionary:
	get: return {"vip": int(Data.PASS_PURCHASE.get("vip", {}).get("price_cny", 0)), "super": int(Data.PASS_PURCHASE.get("super_vip", {}).get("price_cny", 0))}
## 今天用琥珀买了几次火种。价格逐次上涨，零点清零。
var energy_buys := 0
var deals_bought := {}
var deals_day := ""
var shell_bought := {}
var shell_period := ""
var player_id := ""
var seen_tutorial := false
var tutorial_on := false

var _boil_t := 0.0
var _save_t := -1.0
var _regen_t := 0.0
var rng := RandomNumberGenerator.new()
var random_seed := ""
var random_streams: Dictionary = {}
var replay_meta: Dictionary = {}
var replay_local: Dictionary = {}


func random_for(key: String) -> RandomNumberGenerator:
	if random_seed == "": return rng
	if not random_streams.has(key):
		var generator := RandomNumberGenerator.new()
		generator.seed = (random_seed + ":" + key).sha256_text().substr(0, 15).hex_to_int()
		random_streams[key] = generator
	return random_streams[key]

func random_save() -> Dictionary:
	var streams := {}
	for key in random_streams:
		streams[key] = str(random_streams[key].state)
	return {"seed": random_seed, "streams": streams}

func random_load(d: Dictionary) -> void:
	random_seed = str(d.get("seed", ""))
	random_streams = {}
	for key in d.get("streams", {}): random_for(key).state = int(d["streams"][key])

func replay_input() -> bool:
	return is_instance_valid(get_node_or_null("/root/Replay")) and Replay.active and not Replay.executing

func _init() -> void:
	rules = RuleContext.new(self, now, random_for, _clock_is_ready, {
		"record": SevenDay.record, "login": SevenDay.login,
		"order": ActivityRules.on_order, "settle": Rewards.settle, "meta": _rule_meta})

func _clock_is_ready() -> bool:
	if simulation_time >= 0: return true
	var replay = get_node_or_null("/root/Replay")
	if replay != null and replay.executing: return true
	var cloud = get_node_or_null("/root/Cloud")
	return cloud != null and cloud.clock_ready

func _ready() -> void:
	_apply_rules()
	rng.randomize()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--save="):
			save_path = a.trim_prefix("--save=")
	if not ("--replay-worker" in OS.get_cmdline_user_args() or "--replay-service" in OS.get_cmdline_user_args()):
		font_title = _sysfont(["STHupo", "Microsoft YaHei UI", "Microsoft YaHei"], 400)
		font_body = _sysfont(["Microsoft YaHei UI", "Microsoft YaHei", "SimHei"], 700)
	loaded_save = load_game()
	if not loaded_save:
		new_game()
	if replay_meta.is_empty(): rules.clock._check_day()

func _apply_rules() -> void:
	var r: Dictionary = Data.RULES
	if r.is_empty():
		return
	COLS = int(r["cols"])
	ROWS = int(r["rows"])
	MAX_ENERGY = int(r["max_energy"])
	REGEN_SEC = int(r["regen_sec"])
	RANDOM_ORDERS = int(r["random_orders"])
	TOKEN_STEP = int(r["token_step"])

func clear_scroll_drag() -> void:
	scroll_drag = false

func _sysfont(names: Array, weight: int) -> Font:
	if OS.has_feature("web"):
		return load("res://assets/fonts/NotoSansCJKsc-Regular.otf")
	var f := SystemFont.new()
	f.font_names = PackedStringArray(names)
	f.font_weight = weight
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return f

func set_boil(on: bool) -> void:
	settings["boil"] = on
	_boil_hold = false
	if not on and Art.boil != 0:
		Art.boil = 0
		boil_tick.emit()

func _process(delta: float) -> void:
	var moving := scroll_moving
	scroll_moving = false
	_boil_t += delta
	if not settings.get("boil", true):
		_boil_t = 0.0
	elif _boil_t >= Items.frame_sec:
		_boil_t = fmod(_boil_t, Items.frame_sec)
		Art.boil = (Art.boil + 1) % 4
		if moving:
			_boil_hold = true
		else:
			_boil_hold = false
			boil_tick.emit()
	elif _boil_hold and not moving:
		_boil_hold = false
		boil_tick.emit()
	_regen_t += delta
	if _regen_t >= 1.0:
		_regen_t = 0.0
		if not Replay.active:
			rules.clock._check_day()
			rules.board._tick_bubbles()
			TigerEscape.tick()
			rules.clock._regen()
	if _save_t >= 0.0:
		_save_t -= delta
		if _save_t < 0.0:
			save_game()
	if not Replay.active: rules.orders._tick_cooks()

func now() -> float:
	if is_instance_valid(get_node_or_null("/root/Replay")) and Replay.active and Replay.executing: return float(Replay.clock)
	if simulation_time >= 0: return simulation_time
	var c = get_node_or_null("/root/Cloud")
	return c.server_now() if c != null else Time.get_unix_time_from_system()

func dirty() -> void:
	var replay = get_node_or_null("/root/Replay")
	if replay != null and replay.active and replay.executing: return
	_save_t = 0.6

func new_game() -> void:
	clear_transient()
	if simulation_time >= 0:
		random_seed = "simulation:" + str(rng.seed)
	elif random_seed == "":
		random_seed = Crypto.new().generate_random_bytes(32).hex_encode()
	random_streams = {}
	level = 1
	xp = 0
	energy = 100
	shells = 0
	amber = 80
	rush = 0
	energy_stamp = now()
	boost = false
	boost_gm = false
	inv = []
	inv_chests = {}
	inv_cap = int(Data.RULES.get("storage_initial", 5))
	discovered = {}
	book_claimed = {}
	builds = {"fire": 1}
	cards = {}
	card_stars = 0
	stash = []
	ufo_offer = {}
	offers = {}
	local_race = {}
	duel_race = {}
	tiger_escape = {}
	fossil_dig = {}
	tiger_escape_seen = {}
	gm_activities = false
	seven_day = {}
	merge_events = {}
	tokens = 0
	token_claimed = 0
	pass_pts = 0
	pass_tier = 0
	pass_free = []
	pass_prem = []
	pass_super = []
	pass_endless = 0
	pass_super_bonus = false
	pass_season = rules.clock.pass_season_now()
	player_id = "TRB" + str(rng.randi_range(10000000, 99999999))
	seen_tutorial = false
	tutorial_on = true
	story_done = {}
	pending_orders = []
	order_serial = 0
	deals_bought.clear()
	hot_bought.clear()
	hot_revision = 0
	_bubble_busy.clear()
	_chest_busy.clear()
	shell_bought = {}
	shell_period = ""
	energy_buys = 0
	deals_day = rules.clock.today()
	rules.board._init_board()
	var cost := rules.progression.build_cost("fire")
	var first := 25
	orders = [
		{"who": 0, "items": ["fruit_2"], "rw": {"shell": first}, "story": true, "tutorial": 1},
		{"who": 1, "items": ["fruit_8"], "rw": {"shell": maxi(cost - first, 1)}, "story": true, "tutorial": 2},
	]
	for order in orders: order_identity(order)
	dirty()

func save_game() -> void:
	if simulation_time >= 0: return
	var replay = get_node_or_null("/root/Replay")
	if replay != null and replay.active:
		if not replay.worker and not replay.executing: replay.checkpoint()
		return
	StateCodec.write(save_path, save_dict())

func save_dict(include_local: bool = true) -> Dictionary:
	return StateCodec.capture(self, include_local)

func load_game() -> bool:
	var data := StateCodec.read(save_path)
	if data.is_empty() or not load_snapshot(data): return false
	if data.get("settings") is Dictionary:
		settings = data["settings"].duplicate(true)
	if data.get("replay_local") is Dictionary:
		replay_local = data["replay_local"].duplicate(true)
	if data.get("tiger_escape_seen") is Dictionary:
		tiger_escape_seen = data["tiger_escape_seen"].duplicate(true)
	set_boil(bool(settings["boil"]))
	return true

func load_snapshot(data: Dictionary) -> bool:
	if not StateCodec.restore(self, data): return false
	clear_transient()
	return true

func reset_game() -> void:
	if replay_input(): Replay.perform("reset"); return
	new_game()
	save_game()
	board_changed.emit()
	orders_changed.emit()
	changed.emit()

func buy_energy() -> bool:
	if replay_input(): return bool((Replay.perform("energy")).get("ok", false))
	return rules.progression.buy_energy()

func expand_storage() -> bool:
	if replay_input(): return bool((Replay.perform("expand")).get("ok", false))
	return rules.progression.expand_storage()

func claim_level(lv: int) -> Array:
	if replay_input(): return Replay.perform("level", {"level": lv}).get("rewards", [])
	return rules.progression.claim_level(lv)

func shop_buy(key: String, id: String) -> Dictionary:
	if replay_input(): return Replay.perform("shop", {"key": key, "id": id})
	return rules.progression.shop_buy(key, id)

func refresh_hot() -> Dictionary:
	if replay_input(): return Replay.perform("hot_refresh")
	return rules.progression.refresh_hot()

func buy_bubble(i: int) -> Dictionary:
	if replay_input(): return Replay.perform("bubble_buy", {"cell": i})
	return rules.board.buy_bubble(i)

func claim_book(id: String) -> int:
	if replay_input(): return int((Replay.perform("book", {"id": id})).get("energy", 0))
	return rules.board.claim_book(id)

func try_drop(a: int, b: int) -> String:
	if replay_input(): return str(Replay.perform("drop", {"from": a, "to": b}).get("kind", ""))
	return rules.board.try_drop(a, b)

func set_boost(on: bool) -> void:
	if replay_input(): Replay.perform("boost", {"on": on}); return
	rules.board.set_boost(on)

func dispense_chest(i: int) -> Dictionary:
	if replay_input(): return Replay.perform("tap", {"cell": i})
	return rules.board.dispense_chest(i)

func next_order_uid() -> String:
	order_serial += 1
	return "order:%d" % order_serial

func order_identity(order: Dictionary) -> Dictionary:
	if not order.has("uid"): order["uid"] = next_order_uid()
	return order

func rush_cook(i: int) -> int:
	if replay_input(): return int(Replay.perform("rush", {"cell": i}).get("used", 0))
	return rules.orders.rush_cook(i)

func begin_craft(oi: int) -> Array:
	if replay_input(): return Replay.perform("craft", {"cell": oi}).get("flights", [])
	return rules.orders.begin_craft(oi)

func complete_order(oi: int) -> Array:
	if replay_input(): return Replay.perform("order", {"cell": oi}).get("cells", [])
	return rules.orders.complete_order(oi)

func claim_pass_free(lv: int) -> Array:
	if replay_input(): return (Replay.perform("pass", {"track": "free", "level": lv})).get("rewards", [])
	return rules.progression.claim_pass_free(lv)

func claim_pass_prem(lv: int) -> Array:
	if replay_input(): return (Replay.perform("pass", {"track": "prem", "level": lv})).get("rewards", [])
	return rules.progression.claim_pass_prem(lv)

func claim_pass_super(lv: int) -> Array:
	if replay_input(): return (Replay.perform("pass", {"track": "super", "level": lv})).get("rewards", [])
	return rules.progression.claim_pass_super(lv)

func claim_pass_endless() -> Array:
	if replay_input(): return (Replay.perform("pass", {"track": "endless"})).get("rewards", [])
	return rules.progression.claim_pass_endless()

func do_build(id: String) -> Dictionary:
	if replay_input(): return Replay.perform("build", {"id": id})
	return rules.progression.do_build(id)

func open_pack(pack_id: String = "", cell: int = -1, stash_index: int = -1) -> Array:
	return open_pack_result(pack_id, cell, stash_index).get("cards", [])

func open_pack_result(pack_id: String = "", cell: int = -1, stash_index: int = -1) -> Dictionary:
	if replay_input(): return Replay.perform("pack", {"id": pack_id, "cell": cell, "stash": stash_index})
	return rules.progression.open_pack_result(pack_id, cell, stash_index)

func refresh_shell() -> Dictionary:
	if replay_input(): return Replay.perform("shell_refresh")
	return rules.progression.refresh_shell()

func business_snapshot() -> Dictionary:
	return StateCodec.capture(self, false)


static func fmt_time(sec: int) -> String:
	if sec >= 86400:
		return "%d天%d时" % [sec / 86400, (sec % 86400) / 3600]
	if sec >= 3600:
		return "%d时%d分" % [sec / 3600, (sec % 3600) / 60]
	return "%d分%02d秒" % [sec / 60, sec % 60]


func present(kind: String, payload: Dictionary) -> void:
	if is_blocking_signals():
		_presentation_events.append({"kind": kind, "payload": payload})
	else:
		presentation_event.emit(kind, payload)

func clear_transient() -> void:
	opened = []
	cooked_pop = []
	_bubble_busy.clear()
	_chest_busy.clear()
	_hot_refresh_busy = false
	_storage_busy = false
	_shell_refresh_busy = false
	_pack_busy = false
	clear_presentations()

func clear_presentations() -> void:
	_presentation_events.clear()

func flush_presentations() -> void:
	var events := _presentation_events
	_presentation_events = []
	for event in events:
		presentation_event.emit(str(event["kind"]), event["payload"])

func _rule_meta() -> Dictionary:
	var replay = get_node_or_null("/root/Replay")
	return replay.meta if replay != null else replay_meta

func shop_view() -> Array:
	var cached: Dictionary = rules.shop.cached()
	if not cached.is_empty(): return cached["list"]
	if replay_input(): return Replay.perform("shop_view").get("list", [])
	return rules.shop.today()
