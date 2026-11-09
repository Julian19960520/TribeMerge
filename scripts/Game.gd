extends Node
## 全局状态（autoload: G）

signal boil_tick
signal changed
signal board_changed
signal orders_changed
## 交付了一张订单（篝火竞速用它先在本地给自己的头像加分，服务器结算为准）
signal order_delivered(items: Array)

const Layout := preload("res://scripts/config/board_layout.gd")
const Roll := preload("res://scripts/OrderRoll.gd")
const HotDeals := preload("res://scripts/HotDeals.gd")

var COLS := 7
var ROWS := 9
var MAX_ENERGY := 100
var REGEN_SEC := 120
const SAVE_PATH := "user://tribe_save_v17.json"
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
var ufo_receipts: Array = []
## 付费限时礼包（赶大集 / 火种大礼包）每期状态，见 scripts/events/Offers.gd
var offers: Dictionary = {}
var local_race: Dictionary = {}
var duel_race: Dictionary = {}
var tiger_escape: Dictionary = {}
var tiger_escape_seen: Dictionary = {}
var gm_activities := false
var seven_day: Dictionary = {}
signal seven_day_changed
var merge_events: Dictionary = {}
signal merge_event_changed
var font_title: Font
var font_body: Font

var level := 1
var xp := 0
var energy := 100
var shells := 320
var amber := 140
var rush := 0
var energy_stamp := 0.0
## 双倍火种模式开关（Data.BOOST_LEVEL 级解锁）
var boost := false
## GM 按钮提前解锁了双倍火种（不看等级）
var boost_gm := false
var board: Array = []
## 最近一次合成解开的巨石格子，给崩坏动画用
var opened: Array = []
var inv: Array = []
var inv_cap := 5
var discovered := {}
## 图鉴里已经领过奖的物品。新发现的还没领，格子上是礼物。
var book_claimed := {}
var orders: Array = []
var story_done: Dictionary = {}
var pending_orders: Array = []
## 刚做完的格子，棋盘下一帧播合成爆开
var cooked_pop: Array = []
var builds := {}
var cards := {}
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
## 当前通行证赛季号（和服务器 Economy.pass_season 算法一致），换季时清空通行证进度
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
## 今天用琥珀买了几次火种。价格逐次上涨，零点清零。
var energy_buys := 0
var deals_bought := {}
var deals_day := ""
## 贝币小摊本轮已购（key "shell_%d" -> 个数）和轮次号，轮次按服务器时间每 Data.STORE_SHELL_HOURS 小时换一次
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


func _ready() -> void:
	_apply_rules()
	rng.randomize()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--save="):
			save_path = a.trim_prefix("--save=")
	font_title = _sysfont(["STHupo", "Microsoft YaHei UI", "Microsoft YaHei"], 400)
	font_body = _sysfont(["Microsoft YaHei UI", "Microsoft YaHei", "SimHei"], 700)
	loaded_save = load_game()
	if not loaded_save:
		new_game()
	if replay_meta.is_empty(): _check_day()

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

## 开关沸腾线。关掉时定格在第 0 帧并通知所有界面重画一次。
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
			_check_day()
			_tick_bubbles()
			TigerEscape.tick()
			_regen()
	if _save_t >= 0.0:
		_save_t -= delta
		if _save_t < 0.0:
			save_game()
	if not Replay.active: _tick_cooks()

## 服务器时间（Cloud 按服务器给的差值换算）；没有 Cloud 时用本机时间。体力回复、冷却、制作计时都用它。
func now() -> float:
	if is_instance_valid(get_node_or_null("/root/Replay")) and Replay.active and Replay.executing: return float(Replay.clock)
	if simulation_time >= 0: return simulation_time
	var c = get_node_or_null("/root/Cloud")
	return c.server_now() if c != null else Time.get_unix_time_from_system()

func _regen() -> void:
	if energy >= MAX_ENERGY:
		energy_stamp = now()
		changed.emit()
		return
	var n := int((now() - energy_stamp) / REGEN_SEC)
	if n > 0:
		energy = min(MAX_ENERGY, energy + n)
		energy_stamp += n * REGEN_SEC
		dirty()
	changed.emit()

func energy_left() -> int:
	if energy >= MAX_ENERGY:
		return 0
	return int(REGEN_SEC - fmod(now() - energy_stamp, REGEN_SEC))

func energy_full_left() -> int:
	if energy >= MAX_ENERGY:
		return 0
	return energy_left() + (MAX_ENERGY - energy - 1) * REGEN_SEC

static func fmt_time(sec: int) -> String:
	if sec >= 86400:
		return "%d天%d时" % [sec / 86400, (sec % 86400) / 3600]
	if sec >= 3600:
		return "%d时%d分" % [sec / 3600, (sec % 3600) / 60]
	return "%d分%02d秒" % [sec / 60, sec % 60]

## 到北京时间零点还有几秒（按服务器时间，连不上时按本机时间）
func secs_to_midnight() -> int:
	if simulation_time >= 0: return 86400 - int(simulation_time + 28800) % 86400
	var c = get_node_or_null("/root/Cloud")
	if c != null:
		return c.secs_to_midnight()
	var t := Time.get_datetime_dict_from_system()
	return 86400 - (int(t["hour"]) * 3600 + int(t["minute"]) * 60 + int(t["second"]))

## 今天的日期：服务器的北京时间日期（Cloud），连不上时按本机时间
func today() -> String:
	if is_instance_valid(get_node_or_null("/root/Replay")) and Replay.active: return Time.get_date_string_from_unix_time(int(now()) + 28800)
	if simulation_time >= 0: return Time.get_datetime_string_from_unix_time(int(simulation_time + 28800)).split("T")[0]
	var c = get_node_or_null("/root/Cloud")
	return c.today() if c != null else Time.get_date_string_from_system()

## 关键事件：让云存档记一笔待上传（交单、建造、升级、花/得琥珀、开卡包）
func cloud_mark() -> void:
	if is_instance_valid(get_node_or_null("/root/Replay")) and Replay.active: return
	var c = get_node_or_null("/root/Cloud")
	if c != null:
		c.mark()

## 服务器模式：云服务开着（正式玩法），花钱、领奖、开箱、建造都先问服务器。
## 关掉时（--cloud-off、测试脚本）走下面的本地规则。
func server_mode() -> bool:
	if is_instance_valid(get_node_or_null("/root/Replay")) and Replay.active: return false
	var c = get_node_or_null("/root/Cloud")
	return c != null and c.enabled

func _cloud():
	return get_node_or_null("/root/Cloud")

## 本地先生效、服务器随后结算的事件（交单、气泡、收取、退款）
func cloud_event(ev: Dictionary) -> void:
	if server_mode():
		_cloud().event(ev)

## 把服务器状态里的一个字段写回本地（Cloud.apply_state 用）
func set_server_field(k: String, v) -> void:
	match k:
		"ufo_offer":
			ufo_offer = v.duplicate(true) if v is Dictionary else {}
		"offers":
			offers = v.duplicate(true) if v is Dictionary else {}
		"gm_activities":
			gm_activities = bool(v)
		"seven_day":
			seven_day = Data.ConfigFiles.ints(v) if v is Dictionary else {}
		"tiger_escape":
			tiger_escape = Data.ConfigFiles.ints(v) if v is Dictionary else {}
		"duel_race":
			duel_race = v.duplicate(true) if v is Dictionary else {}
		"merge_events":
			merge_events = Data.ConfigFiles.ints(v) if v is Dictionary else {}
		"hot_bought", "deals_bought", "book_claimed", "shell_bought":
			set(k, (v as Dictionary).duplicate() if v is Dictionary else {})
		"builds", "cards":
			var d := {}
			if v is Dictionary:
				for key in v:
					d[str(key)] = int(v[key])
			set(k, d)
		"pass_free", "pass_prem", "pass_super":
			var a := []
			if v is Array:
				for x in v:
					a.append(int(x))
			set(k, a)
		"pass_super_bonus":
			pass_super_bonus = bool(v)
		"deals_day":
			deals_day = str(v)
		"shell_period":
			shell_period = str(v)
		"pass_season":
			pass_season = str(v)
		_:
			set(k, int(v))

## 服务器拒绝 / 连不上时的提示。「琥珀不够」这类调用方自己会提示。
func _srv_fail(r: Dictionary) -> void:
	if main != null and not str(r.get("error", "")).begins_with("not_enough"):
		main.toast(str(r.get("message", "连不上服务器，请稍后再试")))

## 服务器发的、UI 不会另外处理的东西：实物进暂存，体力 / 沙漏直接加
func take_give(give: Dictionary) -> void:
	var rewards := Rewards.items(give.get("items", []))
	if int(give.get("energy", 0)) > 0:
		rewards.append(["fire_2", int(give["energy"])])
	if int(give.get("rush", 0)) > 0:
		rewards.append(["sand_2", int(give["rush"])])
	Rewards.grant(rewards)

## 贝币小摊的轮次号（东八区零点对齐，每 Data.STORE_SHELL_HOURS 小时一轮），和服务器 Economy.shell_period 算法一致
func shell_period_now() -> String:
	return str(int((now() + 8 * 3600) / float(Data.STORE_SHELL_HOURS * 3600)))

func shell_secs_left() -> int:
	var span := Data.STORE_SHELL_HOURS * 3600
	return span - int(now() + 8 * 3600) % span

## 换轮了就把本轮已购清零（服务器那边同样在换轮时清零）
func check_shell_period() -> void:
	var p := shell_period_now()
	if p != shell_period:
		shell_period = p
		shell_bought = {}

## 通行证赛季：从 season.start（北京时间零点）起每 season.days 天一季
func _pass_season_span() -> int:
	return maxi(1, int(Data.PASS_SEASON.get("days", 35))) * 86400

func _pass_season_offset() -> int:
	var start := str(Data.PASS_SEASON.get("start", "2026-11-02"))
	return int(now()) + 8 * 3600 - int(Time.get_unix_time_from_datetime_string(start + "T00:00:00"))

func pass_season_now() -> String:
	return str(floori(float(_pass_season_offset()) / float(_pass_season_span())))

func pass_secs_left() -> int:
	return _pass_season_span() - posmod(_pass_season_offset(), _pass_season_span())

## 换季：积分、已领档位、贵宾档位全部清零，上季没领的奖励作废（服务器同样在换季时清零）
func check_pass_season() -> void:
	var s := pass_season_now()
	if s == pass_season:
		return
	pass_season = s
	pass_pts = 0
	pass_tier = 0
	pass_free = []
	pass_prem = []
	pass_super = []
	pass_endless = 0
	pass_super_bonus = false
	dirty()
	changed.emit()

func event_left() -> int:
	return 35 * 86400 + 15 * 3600 - int(fmod(now(), 86400.0))

func _check_day() -> void:
	check_pass_season()
	SevenDay.login()
	# 等云存档拿到服务器时间（或确认连不上）再判断，免得改了本机时间先把每日次数清掉
	var c = get_node_or_null("/root/Cloud")
	if simulation_time < 0 and (c == null or not c.clock_ready):
		return
	var d: String = today()
	if d != deals_day:
		deals_day = d
		deals_bought = {}
		hot_bought = {}
		hot_revision = 0
		dirty()
		energy_buys = 0

# ---------------------------------------------------------------- 存档

func dirty() -> void:
	_save_t = 0.6

func new_game() -> void:
	if not is_instance_valid(get_node_or_null("/root/Replay")) or not Replay.active:
		random_seed = ""; random_streams = {}
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
	inv_cap = int(Data.RULES.get("storage_initial", 5))
	discovered = {}
	book_claimed = {}
	builds = {"fire": 1}
	cards = {}
	stash = []
	ufo_offer = {}
	ufo_receipts = []
	offers = {}
	local_race = {}
	duel_race = {}
	tiger_escape = {}
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
	pass_season = pass_season_now()
	player_id = "TRB" + str(rng.randi_range(10000000, 99999999))
	seen_tutorial = false
	tutorial_on = true
	story_done = {}
	pending_orders = []
	deals_bought.clear()
	hot_bought.clear()
	hot_revision = 0
	_bubble_busy.clear()
	shell_bought = {}
	shell_period = ""
	energy_buys = 0
	deals_day = today()
	_init_board()
	var cost := build_cost("fire")
	var first := 25
	orders = [
		{"who": 0, "items": ["fruit_2"], "rw": {"shell": first}, "story": true, "tutorial": 1},
		{"who": 1, "items": ["fruit_8"], "rw": {"shell": maxi(cost - first, 1)}, "story": true, "tutorial": 2},
	]
	dirty()

## 新局棋盘来自 data/board.json。locks：0 开放、1 藤蔓、2 巨石。
## 新手从中间偏左的两捆干草束合成。石头底下的物品都还在，只有生产器正上方那一格空着，给第一颗野莓落点。
## 两笔订单的贝币加起来刚好够盖下一段篝火广场。
## rewards：石头上的气泡。裂开时弹出全屏领取面板，点一下后体力、贝币、琥珀飞向顶栏，其他物品进暂存。
func _init_board() -> void:
	board = []
	for i in COLS * ROWS:
		board.append({"id": "", "lock": 0})
	var cells: Array = Data.BOARD
	for row in ROWS:
		for col in COLS:
			var at := idx(col, row)
			var n := row * COLS + col
			var id := str(cells[n]) if n < cells.size() else ""
			if id != "":
				board[at]["id"] = id
			board[at]["lock"] = Layout.lock_of(Data.LOCKS, n, col, row, COLS, ROWS)
			var rw := Layout.reward_of(Data.REWARDS, n)
			if not rw.is_empty():
				board[at]["rw"] = rw
	for k in board:
		if k["id"] != "" and k["lock"] == 0:
			discover(k["id"])

func save_game() -> void:
	if is_instance_valid(get_node_or_null("/root/Replay")) and (Replay.worker or (Replay.active and Replay.executing)): return
	if simulation_time >= 0: return # Simulator owns its reports/checkpoints; never writes a player save.
	DirAccess.make_dir_recursive_absolute(save_path.get_base_dir())
	var f := FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(save_dict()))
		f.close()
		DirAccess.rename_absolute(save_path + ".tmp", save_path)
	else:
		push_error("save_game: cannot write %s (%s)" % [save_path, error_string(FileAccess.get_open_error())])

## 整份存档。本地存档和云存档快照都用它。
func save_dict() -> Dictionary:
	var local := Replay.journal() if is_instance_valid(get_node_or_null("/root/Replay")) and Replay.active else replay_local
	return {"replay_rng": random_save(), "replay_meta": replay_meta, "replay_local": local,
		"ufo_offer": ufo_offer, "ufo_receipts": ufo_receipts, "offers": offers, "local_race": local_race, "duel_race": duel_race, "tiger_escape": tiger_escape, "tiger_escape_seen": tiger_escape_seen, "gm_activities": gm_activities, "seven_day": seven_day, "merge_events": merge_events, "level": level, "xp": xp, "energy": energy, "boost": boost, "boost_gm": boost_gm, "shells": shells, "amber": amber, "rush": rush,
		"energy_stamp": energy_stamp, "board": board, "inv": inv, "inv_cap": inv_cap,
		"discovered": discovered, "book_claimed": book_claimed, "orders": orders, "story_done": story_done, "pending_orders": pending_orders, "builds": builds, "cards": cards,
		"stash": stash, "tokens": tokens, "token_claimed": token_claimed, "settings": settings, "hot_bought": hot_bought, "hot_revision": hot_revision,
		"deals_bought": deals_bought, "deals_day": deals_day, "shell_bought": shell_bought, "shell_period": shell_period, "energy_buys": energy_buys, "player_id": player_id,
		"seen_tutorial": seen_tutorial, "tutorial_on": tutorial_on,
		"pass_pts": pass_pts, "pass_tier": pass_tier, "pass_free": pass_free, "pass_prem": pass_prem, "pass_super": pass_super,
		"pass_endless": pass_endless, "pass_super_bonus": pass_super_bonus, "pass_season": pass_season,
	}

func load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return false
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY or not d.has("board"):
		return false
	return load_snapshot(d, not d.has("replay_meta") or d.get("replay_meta", {}).is_empty())

func load_snapshot(d: Dictionary, reconcile := true) -> bool:
	random_load(d.get("replay_rng", {}))
	replay_meta = Data.ConfigFiles.ints(d.get("replay_meta", {}))
	replay_local = d.get("replay_local", {})
	ufo_offer = d.get("ufo_offer", {}) if d.get("ufo_offer", {}) is Dictionary else {}
	ufo_receipts = d.get("ufo_receipts", []) if d.get("ufo_receipts", []) is Array else []
	offers = d.get("offers", {}) if d.get("offers", {}) is Dictionary else {}
	duel_race = d.get("duel_race", {}) if d.get("duel_race", {}) is Dictionary else {}
	tiger_escape = Data.ConfigFiles.ints(d.get("tiger_escape", {})) if d.get("tiger_escape", {}) is Dictionary else {}
	tiger_escape_seen = Data.ConfigFiles.ints(d.get("tiger_escape_seen", {})) if d.get("tiger_escape_seen", {}) is Dictionary else {}
	local_race = d.get("local_race", {}) if d.get("local_race", {}) is Dictionary else {}
	gm_activities = bool(d.get("gm_activities", false))
	seven_day = Data.ConfigFiles.ints(d.get("seven_day", {})) if d.get("seven_day", {}) is Dictionary else {}
	merge_events = Data.ConfigFiles.ints(d.get("merge_events", {})) if d.get("merge_events", {}) is Dictionary else {}
	level = int(d["level"])
	xp = int(d["xp"])
	energy = int(d["energy"])
	shells = int(d["shells"])
	amber = int(d["amber"])
	rush = int(d.get("rush", 0))
	energy_stamp = float(d["energy_stamp"])
	boost = bool(d.get("boost", false))
	boost_gm = bool(d.get("boost_gm", false))
	board = d["board"]
	for c in board:
		c["lock"] = int(c["lock"])
		var rw := Layout.parse_reward(c.get("rw", null))
		if rw.is_empty():
			c.erase("rw")
		else:
			c["rw"] = rw
	inv = d["inv"]
	inv_cap = int(d["inv_cap"])
	discovered = d["discovered"]
	book_claimed = d.get("book_claimed", {})
	orders = d["orders"]
	story_done = d.get("story_done", {}) if d.get("story_done", {}) is Dictionary else {}
	pending_orders = d.get("pending_orders", []) if d.get("pending_orders", []) is Array else []
	for o in orders:
		o["who"] = int(o["who"])
		for k in o["rw"]:
			var v = o["rw"][k]
			var t := typeof(v)
			if t == TYPE_INT or t == TYPE_FLOAT or t == TYPE_BOOL:
				o["rw"][k] = int(v)
			elif t == TYPE_STRING and str(v).is_valid_int():
				o["rw"][k] = int(v)
	builds = d["builds"]
	for k in builds:
		builds[k] = int(builds[k])
	cards = d["cards"]
	stash = d["stash"]
	tokens = int(d.get("tokens", 0))
	token_claimed = int(d.get("token_claimed", 0))
	settings = d.get("settings", settings)
	if not settings.has("hint"):
		settings["hint"] = true
	if not settings.has("boil"):
		settings["boil"] = true
	set_boil(bool(settings["boil"]))
	hot_bought = d.get("hot_bought", {})
	hot_revision = int(d.get("hot_revision", 0))
	deals_bought = d.get("deals_bought", {})
	deals_day = d.get("deals_day", "")
	shell_bought = d.get("shell_bought", {})
	shell_period = str(d.get("shell_period", ""))
	energy_buys = int(d.get("energy_buys", 0))
	player_id = d.get("player_id", "TRB00000000")
	seen_tutorial = d.get("seen_tutorial", true)
	tutorial_on = bool(d.get("tutorial_on", false))
	pass_pts = int(d.get("pass_pts", 0))
	pass_tier = int(d.get("pass_tier", 0))
	pass_free = []
	pass_prem = []
	var pf = d.get("pass_free", [])
	if typeof(pf) == TYPE_ARRAY:
		for x in pf:
			pass_free.append(int(x))
	var pp = d.get("pass_prem", [])
	if typeof(pp) == TYPE_ARRAY:
		for x in pp:
			pass_prem.append(int(x))
	pass_super = []
	var ps = d.get("pass_super", [])
	if typeof(ps) == TYPE_ARRAY:
		for x in ps:
			pass_super.append(int(x))
	pass_endless = int(d.get("pass_endless", 0))
	pass_super_bonus = bool(d.get("pass_super_bonus", false))
	pass_season = str(d.get("pass_season", ""))
	if not reconcile: return true
	check_pass_season()
	_reconcile_cooks()
	if not tutorial_on:
		# Legacy saves had no completion ledger; infer preceding displayed rows.
		if not d.has("story_done"):
			var first := 999
			for o in orders:
				if o.get("story", false) and o.has("si"): first = mini(first, int(o["si"]))
			if first < 999:
				for si in first: story_done["%d:%d" % [level, si]] = true
		refill_orders()
	return true

func reset_game() -> void:
	if replay_input(): Replay.perform("reset"); return
	new_game()
	save_game()
	board_changed.emit()
	orders_changed.emit()
	changed.emit()

# ---------------------------------------------------------------- 货币

func add_currency(kind: String, n: int) -> void:
	if kind in ["shell", "amber"]: SevenDay.record(kind, n)
	match kind:
		"energy": energy += n
		"shell": shells += n
		"amber": amber += n
		"sand": rush += n
	if kind == "energy" and energy >= MAX_ENERGY:
		energy_stamp = now()
	if kind == "amber":
		cloud_mark()
	dirty()
	changed.emit()

func spend(kind: String, n: int) -> bool:
	match kind:
		"energy":
			if energy < n:
				return false
			if energy >= MAX_ENERGY:
				energy_stamp = now()
			energy -= n
		"shell":
			if shells < n:
				return false
			shells -= n
		"amber":
			if amber < n:
				return false
			amber -= n
			SevenDay.record("amber_spent", n)
			cloud_mark()
		"sand":
			if rush < n:
				return false
			rush -= n
	dirty()
	changed.emit()
	return true

## 用琥珀买 100 火种的价格：每天第一次 energy_price，之后每次加 energy_price_step，最多 energy_price_max。
func energy_price() -> int:
	var r: Dictionary = Data.RULES
	var base := int(r.get("energy_price", 20))
	var step := int(r.get("energy_price_step", 10))
	var top := int(r.get("energy_price_max", 60))
	return mini(base + step * energy_buys, maxi(top, base))

func buy_energy() -> bool:
	if replay_input(): return bool((await Replay.perform("energy")).get("ok", false))
	if server_mode():
		var r: Dictionary = await _cloud().act("/v1/energy/buy")
		if not r.get("ok", false):
			_srv_fail(r)
		return bool(r.get("ok", false))
	_check_day()
	if not spend("amber", energy_price()):
		return false
	energy_buys += 1
	dirty()
	return true

## 按已扩充的格子计算下一格价格；旧存档直接沿用现有容量。
func storage_price() -> int:
	return int(Data.RULES.get("storage_expand_price", 50)) + maxi(0, inv_cap - int(Data.RULES.get("storage_initial", 5))) * int(Data.RULES.get("storage_expand_step", 10))

var _storage_busy := false
func expand_storage() -> bool:
	if replay_input(): return bool((await Replay.perform("expand")).get("ok", false))
	if _storage_busy: return false
	_storage_busy = true
	var success := false
	if server_mode():
		var r: Dictionary = await _cloud().act("/v1/storage/expand")
		success = bool(r.get("ok", false))
		if not success: _srv_fail(r)
	elif spend("amber", storage_price()):
		inv_cap += 1
		success = true
	_storage_busy = false
	if success:
		dirty()
		changed.emit()
	return success

## 领一次升级奖励。成功返回奖励列表；已经领过返回 []；连不上返回 null（奖励留着，稍后再领）。
func claim_level(lv: int):
	if replay_input(): return (await Replay.perform("level", {"level": lv})).get("rewards", [])
	var rw := Data.level_rewards(lv)
	if not server_mode():
		return rw
	var r: Dictionary = await _cloud().act("/v1/level/claim", {"level": lv}, rw)
	if r.get("ok", false):
		return rw
	if str(r.get("error", "")) == "already_claimed":
		return []
	_srv_fail(r)
	return null

## 集市购买。返回 {"ok", "message"}；成功时服务器已扣琥珀（贝币小摊 key "shell_N" 扣贝币）、记了已购数。
func shop_buy(key: String, id: String, _price: int, _deal: bool) -> Dictionary:
	if replay_input(): return await Replay.perform("shop", {"key": key, "id": id})
	if key.begins_with("deal_"): return {"ok":false,"message":"请从每日商品入口领取"}
	if server_mode():
		return await _cloud().act("/v1/shop/buy", {"key": key, "item": id})
	_check_day()
	check_shell_period()
	var offer: Dictionary = {}
	var rows: Array = Data.daily_deals(level)
	for k in HotDeals.today().size():
		var d: Dictionary = HotDeals.today()[k].duplicate()
		d["key"] = "hot_%d" % k
		rows.append(d)
	for k in Data.STORE_SHELL.size():
		var d: Dictionary = Data.STORE_SHELL[k].duplicate()
		d["key"] = "shell_%d" % k
		rows.append(d)
	for d in rows:
		if str(d["key"]) == key and str(d["id"]) == id:
			offer = d
			break
	if offer.is_empty():
		return {"ok": false, "message": "这件已经下架了"}
	var book: Dictionary = shell_bought if key.begins_with("shell_") else (deals_bought if key.begins_with("deal_") else hot_bought)
	if int(book.get(key, 0)) >= int(offer["stock"]):
		return {"ok": false, "message": "已经领完了" if int(offer["price"]) == 0 else "卖完了"}
	var currency := "shell" if key.begins_with("shell_") else "amber"
	if not spend(currency, int(offer["price"])):
		return {"ok": false, "error": "not_enough_" + currency}
	book[key] = int(book.get(key, 0)) + 1
	dirty()
	changed.emit()
	return {"ok": true}

func has_free_daily() -> bool:
	for d in Data.daily_deals(level):
		if str(d.get("mode", "")) == "ad" or int(d["price"]) > 0 or pass_tier < int(d.get("min_tier",0)): continue
		if deals_day != today() or int(deals_bought.get(d["key"],0)) < int(d["stock"]): return true
	return false

func refresh_hot() -> Dictionary:
	if replay_input(): return await Replay.perform("hot_refresh")
	if _hot_refresh_busy:
		return {"ok": false, "message": "正在刷新"}
	_hot_refresh_busy = true
	_check_day()
	var previous: Array = HotDeals.today().duplicate(true)
	var result: Dictionary
	if server_mode():
		result = await _cloud().act("/v1/shop/refresh")
		if result.get("ok", false):
			_cloud().accept_hot(today(), hot_revision, result.get("give", {}).get("picks", []))
	elif not spend("amber", 10):
		result = {"ok": false, "message": "琥珀不够了！"}
	else:
		hot_bought = {}
		hot_revision += 1
		HotDeals.reroll_all(previous)
		result = {"ok": true}
	_hot_refresh_busy = false
	if result.get("ok", false):
		HotDeals.clear_cache()
		dirty()
		changed.emit()
	return result

## lock=3：额外复制的物品尚未购买，不能当作库存、订单材料或合成对象。
func is_merge_bubble(i: int) -> bool:
	return i >= 0 and i < board.size() and int(board[i].get("lock", 0)) == 3 and board[i].get("bubble") is Dictionary

func bubble_left(i: int) -> int:
	return maxi(0, int(ceil(float(board[i]["bubble"].get("expires", 0)) - now()))) if is_merge_bubble(i) else 0

func _maybe_spawn_bubble(id: String, near: int) -> void:
	# 引导固定了每一步用到的格子，完成后才开始出现随机额外物品。只有高级普通物品才有（Data.bubble_ok）。
	if tutorial_on or not Data.bubble_ok(id) or find_empty_near(near) < 0:
		return
	var offer: Dictionary
	if server_mode():
		var r: Dictionary = await _cloud().act("/v1/merge/bubble", {"item": id})
		if not r.get("ok", false):
			return
		offer = r.get("give", {}).get("offer", {})
	else:
		var rule := Data.bubble_rule()
		if random_for("bubbles").randf() >= float(rule.get("chance", 0.1)):
			return
		offer = {"uid": "%s-%s" % [int(now()), random_for("bubbles").randi()], "item": id,
			"expires": now() + float(rule.get("seconds", 60)), "price": Data.bubble_price(id)}
	if tutorial_on or offer.is_empty() or float(offer.get("expires", 0)) <= now():
		return
	var at := find_empty_near(near)
	if at < 0:
		return
	board[at] = {"id": id, "lock": 3, "bubble": offer}
	dirty()
	board_changed.emit()
	if is_instance_valid(main) and main.board_screen != null:
		main.board_screen.board.fly_in(near, at, id)

func _tick_bubbles() -> void:
	var expired := false
	for i in board.size():
		if not is_merge_bubble(i):
			continue
		if bubble_left(i) == 0 and not _bubble_busy.has(str(board[i]["bubble"].get("uid", ""))):
			board[i] = {"id": "", "lock": 0}
			expired = true
	if expired:
		dirty()
		board_changed.emit()

func buy_bubble(i: int) -> Dictionary:
	if replay_input(): return await Replay.perform("bubble_buy", {"cell": i})
	if not is_merge_bubble(i) or bubble_left(i) <= 0:
		_tick_bubbles()
		return {"ok": false, "message": "泡泡已经消失了"}
	var offer: Dictionary = board[i]["bubble"]
	var uid := str(offer.get("uid", ""))
	if _bubble_busy.has(uid):
		return {"ok": false, "message": "正在购买"}
	_bubble_busy[uid] = true
	var result: Dictionary
	if server_mode():
		result = await _cloud().act("/v1/merge/bubble/buy", {"uid": uid})
	else:
		result = {"ok": spend("amber", int(offer.get("price", Data.bubble_price(str(board[i]["id"]))))), "message": "琥珀不够了！"}
	_bubble_busy.erase(uid)
	if result.get("ok", false):
		board[i]["lock"] = 0
		board[i].erase("bubble")
		discover(str(board[i]["id"]))
		dirty()
		board_changed.emit()
		changed.emit()
	else:
		_tick_bubbles()
	return result

## 琥珀礼包：服务器下单 → 支付渠道（现在是 mock）回调到账。返回到账的琥珀数，失败 0。
func buy_amber_pack(k: int) -> int:
	if Replay.active: return 0
	var n := int(Data.AMBER_PACKS[k].get("n", 0)) if k >= 0 and k < Data.AMBER_PACKS.size() else 0
	if not server_mode():
		return n
	var c = _cloud()
	var r: Dictionary = await c.act("/v1/payments/orders", {"pack": k})
	if not r.get("ok", false):
		_srv_fail(r)
		return 0
	var paid: Dictionary = await c.act("/v1/payments/mock/%s/pay" % str(r.get("order_id", "")), {}, [["amber_1", n]])
	if not paid.get("ok", false) or str(paid.get("status", "")) != "paid":
		_srv_fail(paid)
		return 0
	return int(paid.get("amber", n))

func xp_need() -> int:
	return Data.xp_need(level)

func add_xp(n: int) -> bool:
	SevenDay.record("xp", n)
	xp += n
	var up := false
	while xp >= xp_need():
		xp -= xp_need()
		level += 1
		up = true
		cloud_mark()
		if not tutorial_on: refill_orders()
		orders_changed.emit()
	if not up and not tutorial_on and _ensure_story():
		orders_changed.emit()
	dirty()
	changed.emit()
	return up

## 暂存区：奖励、购买、溢出的物品都先放这里
func stash_push(id: String) -> void:
	stash.append(id)
	dirty()
	changed.emit()

## 旧存档或其他奖励里的未解锁卡包保留，但不挡住其余物品。
func stash_claim_index() -> int:
	for i in range(stash.size() - 1, -1, -1):
		if level >= Data.CARD_LEVEL or Data.type_of(str(stash[i])) != "pack":
			return i
	return -1

## 返回这次攒满换到的兽皮卡包数量。卡包另开全屏领奖，不在这里塞进暂存。
func add_tokens(n: int) -> int:
	tokens += n
	var packs := 0
	while tokens - token_claimed >= TOKEN_STEP:
		token_claimed += TOKEN_STEP
		packs += 1
	dirty()
	changed.emit()
	return packs

# ---------------------------------------------------------------- 棋盘

func idx(c: int, r: int) -> int:
	return r * COLS + c

func cell_id(i: int) -> String:
	return board[i]["id"]

func is_free(i: int) -> bool:
	return board[i]["lock"] == 0

func _vacant(i: int) -> bool:
	var c: Dictionary = board[i]
	return c["id"] == "" and int(c["lock"]) == 0 and typeof(c.get("ck")) != TYPE_DICTIONARY

func empty_count() -> int:
	var n := 0
	for i in board.size():
		if _vacant(i):
			n += 1
	return n

func find_empty_near(i: int) -> int:
	return MergeGrid.nearest_empty(board, COLS, i)

func place(i: int, id: String) -> void:
	board[i]["id"] = id
	discover(id)
	dirty()

## 图鉴格子还能领奖：已经发现，但还没点过礼物。
func book_prize(id: String) -> bool:
	return id != "" and discovered.has(id) and not book_claimed.has(id)

func book_prize_count() -> int:
	var n := 0
	for line in Data.LINES:
		for key in ["gen", "main", "sub"]:
			var ch := str(line[key])
			if not Data.CHAINS.has(ch):
				continue
			var items: Array = Data.CHAINS[ch]["items"]
			for i in items.size():
				if book_prize("%s_%d" % [ch, i + 1]):
					n += 1
	for id in Data.DISHES:
		if book_prize(str(id)):
			n += 1
	return n

## 领走这份图鉴奖。返回火苗数量（等于物品等级），已经领过或还没发现则是 0。
func claim_book(id: String) -> int:
	if replay_input(): return int((await Replay.perform("book", {"id": id})).get("energy", 0))
	if not book_prize(id):
		return 0
	if server_mode():
		var r: Dictionary = await _cloud().act("/v1/book/claim", {"item": id})
		if not r.get("ok", false):
			_srv_fail(r)
			return 0
		return int(r.get("give", {}).get("energy", maxi(1, Data.lv(id))))
	book_claimed[id] = true
	dirty()
	changed.emit()
	return maxi(1, Data.lv(id))

func discover(id: String) -> bool:
	if id == "" or discovered.has(id):
		return false
	if Data.is_dish(id):
		discovered[id] = true
		cloud_event({"type": "found", "item": id})
		return true
	var ch := Data.chain(id)
	for l in range(1, Data.lv(id) + 1):
		discovered["%s_%d" % [ch, l]] = true
	# 马上告诉服务器「见过了」：服务器平时只在同步存档时看棋盘，刚合出来就领图鉴、马上丢弃退款的物品它还不知道。
	# 事件按顺序结算，领奖接口会先把排队的事件交掉，所以领奖、退款之前服务器一定已经知道。
	cloud_event({"type": "found", "item": id})
	return true

## 合成后，上下左右的巨石崩开。有物品的格子露出藤蔓，空格直接开放。返回这些格子。
func unlock_around(i: int) -> Array:
	return MergeGrid.reveal_neighbors(board, i, COLS)

func try_drop(a: int, b: int) -> String:
	if replay_input(): return str(Replay.perform("drop", {"from": a, "to": b}).get("kind", ""))
	opened = []
	if a < 0 or b < 0 or a >= board.size() or b >= board.size() or a == b: return ""
	if is_merge_bubble(a) or is_merge_bubble(b): return _drop_bubble(a, b)
	if cooking(a) or cooking(b): return _drop_cook(a, b)
	var result := MergeGrid.drop_kind(board, a, b, Data.next_id)
	if result == "": return ""
	if result != "merge": _swap_gm(a, b)
	MergeGrid.apply_drop(board, a, b, result, Data.next_id)
	if result == "merge":
		SevenDay.record("merges", 1)
		var nx := str(board[b]["id"])
		board[a].erase("gm")
		board[b].erase("gm")
		discover(nx)
		opened = unlock_around(b)
		_maybe_spawn_bubble(nx, b)
		_merge_coin(nx, b)
	dirty()
	board_changed.emit()
	return result

## 制作中的格子可以拖到空位，或和另一个未锁定的物品对调。
func _drop_cook(a: int, b: int) -> String:
	if int(board[a]["lock"]) != 0 or int(board[b]["lock"]) != 0:
		return ""
	if not cooking(a) and str(board[a]["id"]) == "":
		return ""
	var onto_empty := str(board[b]["id"]) == "" and not cooking(b)
	var ida: String = board[a]["id"]
	var idb: String = board[b]["id"]
	var cka = board[a].get("ck")
	var ckb = board[b].get("ck")
	board[a]["id"] = idb
	board[b]["id"] = ida
	if typeof(cka) == TYPE_DICTIONARY:
		board[b]["ck"] = cka
	else:
		board[b].erase("ck")
	if typeof(ckb) == TYPE_DICTIONARY:
		board[a]["ck"] = ckb
	else:
		board[a].erase("ck")
	_swap_gm(a, b)
	_sync_cook_cells()
	dirty()
	board_changed.emit()
	return "move" if onto_empty else "swap"

func _sync_cook_cells() -> void:
	var at := {}
	for i in board.size():
		var ck = board[i].get("ck")
		if typeof(ck) == TYPE_DICTIONARY:
			at[str(ck.get("uid", ""))] = i
	for o in orders:
		if str(o.get("kind", "")) != "craft" or str(o.get("phase", "")) != "cook":
			continue
		var uid := str(o.get("uid", ""))
		if at.has(uid):
			o["cell"] = int(at[uid])

# ---------------------------------------------------------------- 生产器

## 开了冷却的生产器，用量记在格子的 "gm" 里：g 是生产器 id，u 是已用次数，t 是最后一次生产的时间。
## 用光后从 t 起算，过了回满时间一次性恢复。
func _swap_gm(a: int, b: int) -> void:
	var ga = board[a].get("gm")
	var gb = board[b].get("gm")
	board[a].erase("gm")
	board[b].erase("gm")
	if ga != null:
		board[b]["gm"] = ga
	if gb != null:
		board[a]["gm"] = gb

## 剩余次数；没有冷却的生产器返回 -1（不限次数）
func gen_left(i: int) -> int:
	var id: String = board[i]["id"]
	var st := Data.gen_stats(id)
	if not st.has("charges"):
		return -1
	var cap: int = st["charges"]
	var gm = board[i].get("gm")
	if typeof(gm) != TYPE_DICTIONARY or str(gm.get("g", "")) != id:
		return cap
	var used := int(gm["u"])
	if used >= cap and now() - float(gm["t"]) >= float(st["refill"]) * 60.0:
		board[i].erase("gm")
		return cap
	return maxi(cap - used, 0)

## 生产器用光后还要等多少秒；没在休息时为 0
func gen_wait(i: int) -> int:
	if gen_left(i) != 0:
		return 0
	var st := Data.gen_stats(board[i]["id"])
	return maxi(1, int(float(st["refill"]) * 60.0 - (now() - float(board[i]["gm"]["t"]))))

## 双倍火种是否生效（开着且等级够）
func boost_on() -> bool:
	return boost and boost_open()

## 双倍火种开关是否已解锁：到 Data.BOOST_LEVEL 级，或被 GM 按钮解锁
func boost_open() -> bool:
	return boost_gm or level >= Data.BOOST_LEVEL

## 点一次（耗火种的）生产器要花多少火种
func gen_cost() -> int:
	return 2 if boost_on() else 1

func set_boost(on: bool) -> void:
	if replay_input(): Replay.perform("boost", {"on": on}); return
	boost = on and boost_open()
	dirty()
	changed.emit()
	board_changed.emit()

## 双倍火种下产物升 1 级（到链顶为止）
func boost_drop(id: String) -> String:
	if not boost_on() or Data.is_dish(id):
		return id
	var nxt := Data.next_id(id)
	return nxt if nxt != "" else id

func gen_use(i: int) -> void:
	var left := gen_left(i)
	if left < 0:
		return
	var id: String = board[i]["id"]
	board[i]["gm"] = {"g": id, "u": int(Data.gen_stats(id)["charges"]) - left + 1, "t": now()}
	dirty()

func _pick(dist: Array) -> int:
	var r := random_for("orders").randf() * 100.0
	for k in dist.size():
		r -= float(dist[k])
		if r < 0.0:
			return k
	return dist.size() - 1

func roll_produce(gen_id: String) -> String:
	var st := Data.gen_stats(gen_id)
	var drops: Array = st["drops"]
	var total := 0.0
	for d in drops:
		total += float(d["p"])
	var r := random_for("energy_produce" if Data.type_of(gen_id) == "egen" else "produce:" + gen_id).randf() * total
	for d in drops:
		r -= float(d["p"])
		if r < 0.0:
			return str(d["id"])
	return str(drops.back()["id"])

## 打开一个宝箱：服务器抽（连不上返回 []，宝箱留着）；本地模式用 roll_chest
func open_chest(box_id: String = "chest_1") -> Array:
	if not server_mode():
		return DailyShop.energy_chest_items() if box_id == "energybox_1" else roll_chest()
	var r: Dictionary = await _cloud().act("/v1/energy-chest/open" if box_id == "energybox_1" else "/v1/chest/open")
	if not r.get("ok", false):
		_srv_fail(r)
		return []
	var out := []
	for id in r.get("give", {}).get("items", []):
		out.append(str(id))
	return out

func roll_chest() -> Array:
	var out := []
	var pool := ["fire_4", "shell_4", "amber_2", "sand_2"]
	var open := Data.unlocked_lines(level)
	for l in open:
		pool.append_array(["%s_2" % l["main"], "%s_3" % l["main"], "%s_1" % l["sub"]])
	for i in 3:
		if random_for("chests").randf() < 0.1:
			out.append("%s_1" % open[random_for("chests").randi() % open.size()]["gen"])
		else:
			out.append(pool[random_for("chests").randi() % pool.size()])
	return out

# ---------------------------------------------------------------- 订单

## Shared slots: active crafts are protected, experience orders take remaining priority.
func _trim_orders() -> void:
	while orders.size() > Data.order_total(level):
		var remove := -1
		for i in range(orders.size()-1, -1, -1):
			var o: Dictionary = orders[i]
			if not o.get("story",false) and str(o.get("phase","need")) not in ["cook","ready"]:
				remove=i
				break
		if remove<0:
			for i in range(orders.size()-1,-1,-1):
				if orders[i].get("story",false):
					remove=i
					pending_orders.push_front(orders[i])
					break
		if remove<0: break # Only possible for legacy saves with multiple active crafts.
		orders.remove_at(remove)

func refill_orders() -> void:
	if tutorial_on: return
	_trim_orders()
	_add_story_orders()
	_trim_orders()
	_ensure_craft_order(false)
	_add_random_batch()
	dirty()
	orders_changed.emit()

func _is_random_order(o: Dictionary) -> bool:
	return not bool(o.get("story", false)) and str(o.get("kind", "")) != "craft"

func _random_left() -> int:
	var n := 0
	for o in orders:
		if o is Dictionary and _is_random_order(o):
			n += 1
	return n

## 随机订单填补总上限的空位，每张占一个难度位（slot）。
## 交掉一张就在原位补一张同难度位的新单，不用等一整批做完。
func _random_slots_taken() -> Dictionary:
	var taken := {}
	for o in orders:
		if o is Dictionary and _is_random_order(o) and o.has("slot"):
			taken[int(o["slot"])] = true
	return taken

## 随机订单只能占据经验订单和制作订单之外的剩余位置。
func random_cap() -> int:
	return _random_left() + maxi(0, Data.order_total(level) - orders.size())

## 制作订单从这一级开放（rules.json 的 craft_level）。
func craft_level() -> int:
	return maxi(1, int(Data.RULES.get("craft_level", 3)))

## 这一张常驻单的目标火苗。
func _slot_target(slot: int) -> int:
	return Data.random_slot_target(level, slot)

## 把缺的难度位补齐。at 大于等于 0 时，第一张补的单插在这个位置（交单的原位）。
func _add_random_batch(at: int = -1) -> void:
	var n := random_cap()
	if n == 0:
		return
	var taken := _random_slots_taken()
	var have := _random_left()
	var avoid: Array = []
	for o in orders:
		if o is Dictionary and _is_random_order(o) and o.get("items") is Array:
			avoid = o["items"]
	var slot := 0
	while have < n and slot < n:
		if taken.has(slot):
			slot += 1
			continue
		var made: Dictionary
		if Data.random_curve_count() <= 0:
			made = _spice(_make_order_free())
		else:
			made = _make_order(_slot_target(slot), avoid)
			if made.is_empty():
				made = _spice(_make_order_free())
		made["slot"] = slot
		if made.get("items") is Array:
			avoid = made["items"]
		_insert_random(made, at)
		at = -1
		taken[slot] = true
		have += 1
		slot += 1

## 随机单按难度位排在一起：放在比它难的第一张随机单前面；给了 at 就直接放 at。
func _insert_random(made: Dictionary, at: int) -> void:
	if at >= 0 and at <= orders.size():
		orders.insert(at, made)
		return
	var slot := int(made.get("slot", 0))
	for i in orders.size():
		var o = orders[i]
		if o is Dictionary and _is_random_order(o) and int(o.get("slot", 99)) > slot:
			orders.insert(i, made)
			return
	var tail := orders.size()
	for i in orders.size():
		if str(orders[i].get("kind", "")) == "craft":
			tail = i
			break
	orders.insert(tail, made)

## 按已完成记录补齐订单，不能重复发放已完成的经验配置行。
## 声望在统一领奖结算时入账，在 add_xp 和读档时检查。返回是否补了单。
func _ensure_story() -> bool:
	var old := str(orders)
	refill_orders()
	return old != str(orders)

## 随机订单：不给声望，奖励贝币，偶尔有卡包 / 祭典鼓。target 是这单的目标火苗。
func _make_order(target: int = -1, avoid: Array = []) -> Dictionary:
	if Data.random_curve_count() <= 0:
		return _spice(_make_order_free())
	var bounds := Data.random_bounds(level)
	var t := target
	if t < 1:
		t = bounds.x if bounds.x >= bounds.y else random_for("orders").randi_range(bounds.x, bounds.y)
	var made: Dictionary = Roll.make(level, float(t), random_for("orders"), avoid)
	if made.is_empty():
		made = _make_order_free()
	return _spice(made)

func _spice(made: Dictionary) -> Dictionary:
	if made.is_empty() or not (made.get("rw") is Dictionary):
		return made
	if random_for("orders").randf() < 0.25 and level >= Data.CARD_LEVEL:
		made["rw"]["pack"] = 1
	if random_for("orders").randf() < 0.5:
		made["rw"]["token"] = random_for("orders").randi_range(1, 3) * (made.get("items", []) as Array).size()
	return made

func _make_order_free() -> Dictionary:
	var r := random_for("orders").randf()
	var n := 1 if level < 2 or r < 0.45 else (2 if r < 0.85 else 3)
	var items := []
	var shell := 0
	var top: int = 2 + level / 2
	var open := Data.unlocked_lines(level)
	for i in n:
		var ln: Dictionary = open[random_for("orders").randi() % open.size()]
		var sub := str(ln.get("sub", ""))
		if level >= 2 and sub != "" and Data.product_open(level, sub) and random_for("orders").randf() < 0.15:
			var sl := random_for("orders").randi_range(1, mini(3, 1 + level / 3))
			items.append("%s_%d" % [sub, sl])
			shell += 12 * int(pow(2, sl - 1)) + random_for("orders").randi_range(0, 4)
			continue
		var ch: String = ln["main"]
		if not Data.product_open(level, ch):
			continue
		var l := random_for("orders").randi_range(1 if level < 2 else 2, mini(top, Data.max_lv(ch)))
		items.append("%s_%d" % [ch, l])
		shell += 3 * int(pow(2, l - 1)) + random_for("orders").randi_range(0, 4)
	var rw := {"shell": shell}
	return {"who": random_for("orders").randi() % Data.PEOPLE.size(), "items": items, "rw": rw, "story": false}

func _craft_count() -> int:
	var n := 0
	for o in orders:
		if str(o.get("kind", "")) == "craft":
			n += 1
	return n

## 挑一道菜：图鉴里还没做过的优先（越早解锁越先来）；都做过了就在最新解锁的 8 道里随机。
## avoid 里的菜（场上已有的制作单）不重复。
func _pick_dish(avoid: Array = []) -> Dictionary:
	var pool: Array = []
	for d in Data.dishes_for(level):
		if not (str(d["id"]) in avoid):
			pool.append(d)
	if pool.is_empty():
		return {}
	for d in pool:
		if not discovered.has(str(d["id"])):
			return d
	var recent := pool.slice(maxi(0, pool.size() - 8))
	return recent[random_for("orders").randi() % recent.size()]

func _craft_order(d: Dictionary) -> Dictionary:
	if d.is_empty():
		return {}
	var mats: Array = (d["mats"] as Array).duplicate()
	var shell := 4
	for id in mats:
		shell += 4 * int(pow(2.0, float(Data.lv(str(id)) - 1)))
	var rw := {"shell": shell}
	if random_for("orders").randf() < 0.4:
		rw["token"] = random_for("orders").randi_range(1, 3)
	var sand := Data.craft_sand(str(d["id"]))
	if sand != "":
		rw["rewards"] = [sand]
	return {
		"who": random_for("orders").randi() % Data.PEOPLE.size(),
		"kind": "craft",
		"dish": str(d["id"]),
		"mats": mats,
		"items": mats.duplicate(),
		"secs": int(d["secs"]),
		"rw": rw,
		"story": false,
		"phase": "need",
		"cell": -1,
		"t0": 0.0,
		"uid": "c%d" % random_for("orders").randi(),
	}

## 经验订单之后有空位时，保留制作单（同时最多 Data.craft_cap 张，菜不重复）；正在制作的订单不挤掉。
func _ensure_craft_order(replace: bool, avoid: String = "") -> void:
	if level < craft_level():
		return
	while _craft_count() < Data.craft_cap(level) and orders.size() < Data.order_total(level):
		var skip: Array = [avoid] if avoid != "" else []
		for o in orders:
			if str(o.get("kind", "")) == "craft":
				skip.append(str(o.get("dish", "")))
		var made := _craft_order(_pick_dish(skip))
		if made.is_empty():
			return
		if replace:
			replace = false
			for i in range(orders.size() - 1, -1, -1):
				if not bool(orders[i].get("story", false)) and str(orders[i].get("kind", "")) != "craft":
					orders[i] = made
					dirty()
					return
		orders.append(made)
		dirty()

## 经验订单按 story.json 顺序优先占用共享订单位：
## after 是已经放出过的最大序号（交单时传入），只发它后面的。行里记 si（序号），交单时据此放下一张。
func _add_story_orders(skip: Array = [], after: int = -1) -> void:
	var at := 0
	for o in orders:
		if o["story"]:
			at += 1
	## 只和场上的剧情单比重复；和随机单撞了也照发，不然这一级的声望会不够
	var listed: Array = orders.filter(func(o): return o is Dictionary and bool(o.get("story", false)))
	var protected := 0
	for o in orders:
		if str(o.get("kind", "")) == "craft" and str(o.get("phase", "need")) in ["cook", "ready"]: protected += 1
	var room := maxi(0, Data.order_total(level) - listed.size() - protected)
	while room > 0 and not pending_orders.is_empty():
		var row: Dictionary = pending_orders.pop_front()
		orders.insert(at, row)
		listed.append(row)
		at += 1
		room -= 1
	var list := Data.story_orders(level)
	for si in list.size():
		if room <= 0:
			break
		if si <= after or story_done.has("%d:%d" % [level, si]):
			continue
		var s: Dictionary = list[si]
		var items: Array = s["items"]
		if _story_listed(items, skip) or _story_listed(items, listed):
			continue
		room -= 1
		var rw := {"xp": int(s["xp"]), "shell": int(s["shell"])}
		if s.has("token"):
			rw["token"] = int(s["token"])
		if s.get("rewards") is Array and not (s["rewards"] as Array).is_empty():
			rw["rewards"] = (s["rewards"] as Array).duplicate()
		elif int(s.get("pack", 0)) > 0:
			var packs: Array = []
			for _i in int(s["pack"]):
				packs.append("pack_1")
			rw["rewards"] = packs
		var row := {"who": int(s["who"]), "items": items.duplicate(), "rw": rw, "story": true, "si": si, "story_level": level}
		if str(s.get("say", "")) != "":
			row["say"] = str(s["say"])
		orders.insert(at, row)
		at += 1
	_trim_orders()

func _story_listed(items: Array, rows: Array) -> bool:
	for row in rows:
		var got: Array = row["items"] if row is Dictionary else row
		if got.size() != items.size():
			continue
		var same := true
		for i in items.size():
			if str(got[i]) != str(items[i]):
				same = false
				break
		if same:
			return true
	return false

func board_has(id: String, exclude: Array = []) -> int:
	for k in board.size():
		if board[k]["id"] == id and board[k]["lock"] == 0 and not (k in exclude):
			return k
	return -1

func _match_ids(ids: Array) -> Array:
	var used := []
	for id in ids:
		var k := board_has(str(id), used)
		if k < 0:
			return []
		used.append(k)
	return used

func order_cells(o: Dictionary) -> Array:
	if str(o.get("kind", "")) == "craft":
		var phase := str(o.get("phase", "need"))
		if phase == "ready":
			var k := board_has(str(o.get("dish", "")))
			return [k] if k >= 0 else []
		if phase == "cook":
			return []
		return _match_ids(o.get("mats", []))
	return _match_ids(o["items"])

func order_ready(o: Dictionary) -> bool:
	if str(o.get("kind", "")) == "craft":
		return str(o.get("phase", "")) == "ready" and board_has(str(o.get("dish", ""))) >= 0
	return order_cells(o).size() == o["items"].size()

func craft_mats_ready(o: Dictionary) -> bool:
	if str(o.get("kind", "")) != "craft" or str(o.get("phase", "need")) != "need":
		return false
	var mats: Array = o.get("mats", [])
	return not mats.is_empty() and order_cells(o).size() == mats.size()

func wanted_ids() -> Dictionary:
	var d := {}
	for o in orders:
		if str(o.get("kind", "")) == "craft":
			var phase := str(o.get("phase", "need"))
			if phase == "ready":
				d[str(o.get("dish", ""))] = true
			elif phase == "need":
				for id in o.get("mats", []):
					d[str(id)] = true
			continue
		for id in o["items"]:
			d[id] = true
	return d

## 每个格子的订单底色。0 无关，1 普通绿（这单还没齐），2 亮绿（这单需求已经齐了）。
## 只给真正填进需求的那几格上色，多出来的相同物品保持原木底。凑齐的订单先占格子。
func order_cell_tone() -> PackedInt32Array:
	var tone := PackedInt32Array()
	tone.resize(board.size())
	var claimed: Array = []
	for o in orders:
		if not _order_filled(o):
			continue
		for k in order_cells(o):
			var i := int(k)
			if i < 0 or i >= tone.size():
				continue
			tone[i] = 2
			if not (i in claimed):
				claimed.append(i)
	for o in orders:
		if _order_filled(o):
			continue
		for k in _take_partial(o, claimed):
			tone[int(k)] = 1
	return tone

func _order_filled(o: Dictionary) -> bool:
	if str(o.get("kind", "")) == "craft":
		var phase := str(o.get("phase", "need"))
		if phase == "cook":
			return false
		if phase == "ready":
			return order_ready(o)
		return craft_mats_ready(o)
	return order_ready(o)

func _order_need_ids(o: Dictionary) -> Array:
	if str(o.get("kind", "")) == "craft":
		var phase := str(o.get("phase", "need"))
		if phase == "need":
			return o.get("mats", [])
		if phase == "ready":
			var dish := str(o.get("dish", ""))
			return [dish] if dish != "" else []
		return []
	var items = o.get("items", [])
	return items if items is Array else []

## 还没凑齐时，按需求逐件占格；找到几件就标几件。
func _take_partial(o: Dictionary, claimed: Array) -> Array:
	var got: Array = []
	for id in _order_need_ids(o):
		var sid := str(id)
		if sid == "":
			continue
		var k := board_has(sid, claimed)
		if k < 0:
			continue
		claimed.append(k)
		got.append(k)
	return got

func cooking(i: int) -> bool:
	return i >= 0 and i < board.size() and typeof(board[i].get("ck")) == TYPE_DICTIONARY

func cook_left(i: int) -> int:
	if not cooking(i):
		return 0
	var ck: Dictionary = board[i]["ck"]
	var left := float(ck["t0"]) + float(ck["secs"]) - now()
	return maxi(0, int(ceil(left)))

## 用沙漏加速这一格的制作：每份快 Data.rush_sec() 秒，一次用到做完为止（沙漏不够就全用上）。返回用了几份。
func rush_cook(i: int) -> int:
	if replay_input(): return int(Replay.perform("rush", {"cell": i}).get("used", 0))
	if not cooking(i) or rush < 1:
		return 0
	var n := mini(rush, rush_need(i))
	rush -= n
	var ck: Dictionary = board[i]["ck"]
	ck["t0"] = float(ck["t0"]) - float(n * Data.rush_sec())
	var uid := str(ck.get("uid", ""))
	for o in orders:
		if str(o.get("kind", "")) == "craft" and str(o.get("uid", "")) == uid:
			o["t0"] = float(ck["t0"])
	_tick_cooks()
	dirty()
	changed.emit()
	board_changed.emit()
	return n

## 做完这一格还要几份沙漏。
func rush_need(i: int) -> int:
	return maxi(1, int(ceil(float(cook_left(i)) / float(Data.rush_sec()))))

func _gather_anchor(cells: Array) -> int:
	var sx := 0.0
	var sy := 0.0
	for k in cells:
		sx += float(int(k) % COLS)
		sy += float(int(k) / COLS)
	sx /= float(cells.size())
	sy /= float(cells.size())
	var best: int = int(cells[0])
	var bd := 1e9
	for k in cells:
		var d := Vector2(int(k) % COLS, int(k) / COLS).distance_squared_to(Vector2(sx, sy))
		if d < bd:
			bd = d
			best = int(k)
	return best

## 材料飞向同一格并开始计时。返回每件材料的飞行：from、to、id、delay。
func begin_craft(oi: int) -> Array:
	if replay_input(): return Replay.perform("craft", {"cell": oi}).get("flights", [])
	if oi < 0 or oi >= orders.size():
		return []
	var o: Dictionary = orders[oi]
	if not craft_mats_ready(o):
		return []
	var cells := order_cells(o)
	var anchor := _gather_anchor(cells)
	var flights := []
	var mats: Array = []
	for n in cells.size():
		var k: int = int(cells[n])
		var id := str(board[k]["id"])
		mats.append(id)
		flights.append({"from": k, "to": anchor, "id": id, "delay": float(n) * 0.05})
		board[k]["id"] = ""
		board[k].erase("gm")
		board[k].erase("ck")
	var fly := 0.36 + 0.05 * float(maxi(cells.size() - 1, 0))
	var t0 := now() + fly
	board[anchor]["ck"] = {
		"dish": str(o["dish"]),
		"t0": t0,
		"secs": int(o["secs"]),
		"uid": str(o["uid"]),
		"mats": mats,
	}
	o["phase"] = "cook"
	o["cell"] = anchor
	o["t0"] = t0
	dirty()
	board_changed.emit()
	orders_changed.emit()
	return flights

func _reconcile_cooks() -> void:
	var live := {}
	for i in board.size():
		var ck = board[i].get("ck")
		if typeof(ck) == TYPE_DICTIONARY:
			live[str(ck.get("uid", ""))] = i
	for o in orders:
		if str(o.get("kind", "")) != "craft":
			continue
		if str(o.get("uid", "")) == "":
			o["uid"] = "c%d" % random_for("orders").randi()
		var phase := str(o.get("phase", "need"))
		if phase == "cook":
			var uid := str(o["uid"])
			if live.has(uid):
				o["cell"] = int(live[uid])
			elif board_has(str(o.get("dish", ""))) >= 0:
				o["phase"] = "ready"
			else:
				o["phase"] = "need"
				o["cell"] = -1
		elif phase == "ready" and board_has(str(o.get("dish", ""))) < 0:
			o["phase"] = "need"
			o["cell"] = -1
	_tick_cooks()

func _tick_cooks() -> void:
	if board.is_empty():
		return
	var done: Array = []
	for i in board.size():
		var ck = board[i].get("ck")
		if typeof(ck) != TYPE_DICTIONARY:
			continue
		if now() < float(ck["t0"]) + float(ck["secs"]):
			continue
		done.append(i)
	if done.is_empty():
		return
	for slot in done:
		var at := int(slot)
		var ck: Dictionary = board[at]["ck"]
		var dish := str(ck["dish"])
		var uid := str(ck.get("uid", ""))
		board[at]["id"] = dish
		board[at].erase("ck")
		discover(dish)
		for o in orders:
			if str(o.get("kind", "")) == "craft" and str(o.get("uid", "")) == uid:
				o["phase"] = "ready"
				o["cell"] = at
		cooked_pop.append(at)
	dirty()
	board_changed.emit()
	orders_changed.emit()
	if main != null and str(main.screen) == "board":
		Sfx.play("merge", 1.08)

## 交付订单，返回被移除的格子
func complete_order(oi: int) -> Array:
	if replay_input(): return Replay.perform("order", {"cell": oi}).get("cells", [])
	var o: Dictionary = orders[oi]
	var craft := str(o.get("kind", "")) == "craft"
	if craft and str(o.get("phase", "")) != "ready":
		return []
	var cells := order_cells(o)
	if craft:
		if cells.size() != 1:
			return []
	elif cells.size() != o["items"].size():
		return []
	cloud_event({"type": "order", "order": o.duplicate(true)})
	order_delivered.emit((o["items"] as Array).duplicate())
	for k in cells:
		board[k]["id"] = ""
		board[k].erase("ck")
	if o.get("story",false) and o.has("si"):
		story_done["%d:%d" % [int(o.get("story_level",level)),int(o["si"])]] = true
	SevenDay.record("orders", 1)
	MergeEvent.on_order(o)
	DuelRace.on_order(o)
	TigerEscape.on_order(o)
	orders.remove_at(oi)
	if not tutorial_on: refill_orders()
	check_pass_season()
	pass_pts += 2 if pass_tier >= 2 else 1
	cloud_mark()
	dirty()
	board_changed.emit()
	orders_changed.emit()
	changed.emit()
	return cells

# ---------------------------------------------------------------- 丰收通行证

func pass_reached() -> int:
	return int(_pass_cursor()["reached"])

func pass_prog_text() -> String:
	var c := _pass_cursor()
	return "%d/%d" % [int(c["into"]), int(c["need"])]

func pass_frac() -> float:
	var c := _pass_cursor()
	var need := int(c["need"])
	if need < 1:
		return 0.0
	return clampf(float(c["into"]) / float(need), 0.0, 1.0)

func pass_endless_ready() -> int:
	if pass_tier != 2:
		return 0
	var c := _pass_cursor()
	if int(c["reached"]) < Data.PASS_LEVELS.size():
		return 0
	var step := int(c["need"])
	if step < 1:
		return 0
	return maxi(0, int(int(c["extra"]) / float(step)) - pass_endless)

func _pass_cursor() -> Dictionary:
	var left := pass_pts
	var n := Data.PASS_LEVELS.size()
	for i in n:
		var need := Data.pass_need(i)
		if left < need:
			return {"reached": i, "into": left, "need": need, "extra": 0}
		left -= need
	if n == 0:
		return {"reached": 0, "into": 0, "need": 8, "extra": 0}
	var tail := Data.pass_need(n - 1)
	return {"reached": n, "into": tail, "need": tail, "extra": left}

func pass_got(prem: bool, lv: int) -> bool:
	return _pass_has(pass_prem if prem else pass_free, lv)

## track：free 免费 / prem 贵宾 / super 超级贵宾
func pass_got_in(track: String, lv: int) -> bool:
	match track:
		"free": return _pass_has(pass_free, lv)
		"prem": return _pass_has(pass_prem, lv)
		"super": return _pass_has(pass_super, lv)
	return false

func pass_claimable() -> bool:
	var reached := pass_reached()
	for i in reached:
		var lv := i + 1
		if not _pass_has(pass_free, lv):
			return true
		if pass_tier >= 1 and not _pass_has(pass_prem, lv):
			return true
		if pass_tier >= 2 and not _pass_has(pass_super, lv):
			return true
	return pass_endless_ready() > 0

func claim_pass_free(lv: int) -> Array:
	if replay_input(): return (await Replay.perform("pass", {"track": "free", "level": lv})).get("rewards", [])
	check_pass_season()
	if server_mode():
		return await _claim_pass_srv("free", lv)
	if lv < 1 or lv > Data.PASS_LEVELS.size():
		return []
	if pass_reached() < lv or _pass_has(pass_free, lv):
		return []
	pass_free.append(lv)
	dirty()
	changed.emit()
	return Data.PASS_LEVELS[lv - 1]["free"]

func claim_pass_prem(lv: int) -> Array:
	if replay_input(): return (await Replay.perform("pass", {"track": "prem", "level": lv})).get("rewards", [])
	check_pass_season()
	if server_mode():
		return await _claim_pass_srv("prem", lv)
	if lv < 1 or lv > Data.PASS_LEVELS.size() or _pass_has(pass_prem, lv):
		return []
	if pass_tier < 1:
		if main:
			main.toast("激活通行证后可领取")
		return []
	if pass_reached() < lv:
		return []
	pass_prem.append(lv)
	dirty()
	changed.emit()
	return Data.PASS_LEVELS[lv - 1]["prem"]

## 超级贵宾那一列：只有超级贵宾能领
func claim_pass_super(lv: int) -> Array:
	if replay_input(): return (await Replay.perform("pass", {"track": "super", "level": lv})).get("rewards", [])
	check_pass_season()
	if server_mode():
		return await _claim_pass_srv("super", lv)
	if lv < 1 or lv > Data.PASS_LEVELS.size() or _pass_has(pass_super, lv):
		return []
	if pass_tier < 2:
		if main:
			main.toast("超级贵宾可领取")
		return []
	if pass_reached() < lv:
		return []
	pass_super.append(lv)
	dirty()
	changed.emit()
	return Data.PASS_LEVELS[lv - 1].get("super", [])

func _claim_pass_srv(track: String, lv: int) -> Array:
	var rw: Array = [["chest_1", 1]]
	if track != "endless":
		if lv < 1 or lv > Data.PASS_LEVELS.size():
			return []
		rw = Data.PASS_LEVELS[lv - 1].get(track, [])
	var r: Dictionary = await _cloud().act("/v1/pass/claim", {"track": track, "level": lv}, rw)
	if not r.get("ok", false):
		if main:
			main.toast(str(r.get("message", "连不上服务器")))
		return []
	return rw

func claim_pass_endless() -> Array:
	if replay_input(): return (await Replay.perform("pass", {"track": "endless"})).get("rewards", [])
	check_pass_season()
	if server_mode():
		return await _claim_pass_srv("endless", 0)
	if pass_tier != 2:
		if main:
			main.toast("超级贵宾可领取循环奖励")
		return []
	if pass_endless_ready() <= 0:
		return []
	pass_endless += 1
	dirty()
	changed.emit()
	return [["chest_1", 1]]

## 通行证人民币标价（和服务器 server/config/economy.json 的 pass.vip_cny / super_cny 一致）
const PASS_CNY := {"vip": 30, "super": 68}

## 现在买这一档要付多少：已经是贵宾的升级超级只补差价（¥38）
func pass_cny(tier: String) -> int:
	if tier == "vip":
		return int(PASS_CNY["vip"])
	if pass_tier == 1:
		return maxi(0, int(PASS_CNY["super"]) - int(PASS_CNY["vip"]))
	return int(PASS_CNY["super"])

## 人民币买贵宾（¥30）：服务器下单 → 支付渠道（现在是 mock）回调开通。没连服务器的单机版直接开通。
func buy_pass_vip() -> bool:
	if Replay.active: return false
	if pass_tier >= 1:
		if main:
			main.toast("已经拥有")
		return false
	if server_mode():
		return await _pay_pass("vip")
	pass_tier = 1
	Rewards.grant([["fire_2", 150]])
	return true

## 人民币买超级贵宾（¥68）：贵宾、超级两列奖励都能领，一次性 +10 积分。
func buy_pass_super() -> bool:
	if Replay.active: return false
	if pass_tier >= 2:
		if main:
			main.toast("已经拥有")
		return false
	if server_mode():
		return await _pay_pass("super")
	var from_zero := pass_tier == 0
	pass_tier = 2
	if not pass_super_bonus:
		pass_super_bonus = true
		pass_pts += 10
	if from_zero:
		Rewards.grant([["fire_2", 150]])
	else:
		dirty()
		changed.emit()
	return true

func _pay_pass(tier: String) -> bool:
	var c = _cloud()
	var r: Dictionary = await c.act("/v1/pass/order", {"tier": tier})
	if not r.get("ok", false):
		_srv_fail(r)
		return false
	var paid: Dictionary = await c.act("/v1/payments/mock/%s/pay" % str(r.get("order_id", "")))
	if not paid.get("ok", false) or str(paid.get("status", "")) != "paid":
		_srv_fail(paid)
		return false
	take_give(paid.get("give", {}) if paid.get("give") is Dictionary else {})
	return true

func _pass_has(arr: Array, lv: int) -> bool:
	for x in arr:
		if int(x) == lv:
			return true
	return false

# ---------------------------------------------------------------- 建筑 / 卡牌

## 下一个要建的区域：新手引导期间固定篝火广场，之后挑已开放、下一件最便宜的。都建完或都未开放则空。
func next_build_id() -> String:
	if int(builds.get("fire", 0)) < 2 and build_can("fire"):
		return "fire"
	var best := ""
	var best_cost := 0
	for b in Data.BUILDS:
		var id := str(b["id"])
		if not build_can(id):
			continue
		var c := build_cost(id)
		if best == "" or c < best_cost:
			best = id
			best_cost = c
	return best

func build_open(id: String) -> bool:
	return level >= Data.build_unlock(Data.build_def(id))

## 已开放且还有没建的部件
func build_can(id: String) -> bool:
	var d := Data.build_def(id)
	return not d.is_empty() and build_open(id) and int(builds.get(id, 0)) < Data.build_stages(d)

## 下一件要建的部件；建完则空
func build_part(id: String) -> Dictionary:
	var parts := Data.build_parts(Data.build_def(id))
	var st := int(builds.get(id, 0))
	if st >= 0 and st < parts.size() and parts[st] is Dictionary:
		return parts[st]
	return {}

func build_cost(id: String) -> int:
	var part := build_part(id)
	if part.has("cost"):
		return maxi(0, int(part["cost"]))
	return 60 + int(builds.get(id, 0)) * 45

## 建好下一件部件时发出的奖励
func build_rewards(id: String) -> Array:
	var part := build_part(id)
	var out := []
	var all = part.get("rewards", [])
	if all is Array:
		for rw in all:
			if rw is Array and rw.size() >= 2 and str(rw[0]) != "":
				out.append([str(rw[0]), maxi(1, int(rw[1]))])
	return out

## 花贝币建下一件部件。成功返回 {"idx": 部件下标, "rewards": [...]}，失败返回空。
func do_build(id: String) -> Dictionary:
	if replay_input(): return await Replay.perform("build", {"id": id})
	if not build_can(id):
		return {}
	if server_mode():
		var rw := build_rewards(id)
		var r: Dictionary = await _cloud().act("/v1/build", {"area": id}, rw)
		if not r.get("ok", false):
			_srv_fail(r)
			if main and str(r.get("error", "")).begins_with("not_enough"):
				main.toast(str(r.get("message", "")))
			return {}
		return {"idx": int(r.get("give", {}).get("idx", int(builds.get(id, 1)) - 1)), "rewards": rw}
	var cost := build_cost(id)
	var rewards := build_rewards(id)
	if not spend("shell", cost):
		return {}
	var st := int(builds.get(id, 0))
	builds[id] = st + 1
	cloud_mark()
	dirty()
	changed.emit()
	return {"idx": st, "rewards": rewards}

func open_pack() -> Array:
	if replay_input(): return (await Replay.perform("pack")).get("cards", [])
	if level < Data.CARD_LEVEL:
		if main: main.toast("典藏卡在 %d 级解锁" % Data.CARD_LEVEL)
		return []
	if server_mode():
		var r: Dictionary = await _cloud().act("/v1/pack/open")
		if not r.get("ok", false):
			_srv_fail(r)
			return []
		var give: Dictionary = r.get("give", {})
		var got := []
		for c in give.get("cards", []):
			got.append([int(c[0]), int(c[1])])
		if give.has("albums_done") and main:
			main.toast("集齐卡册！大奖已放入暂存区")
		take_give(give)
		return got
	var out := []
	for i in 2:
		var a := random_for("cards").randi() % Data.ALBUMS.size()
		var c := random_for("cards").randi() % 9
		var key := "%d_%d" % [a, c]
		cards[key] = int(cards.get(key, 0)) + 1
		out.append([a, c])
	SevenDay.record("cards", out.size())
	cloud_mark()
	dirty()
	return out

func album_count(a: int) -> int:
	var n := 0
	for c in 9:
		if cards.has("%d_%d" % [a, c]):
			n += 1
	return n

func cards_total() -> int:
	var n := 0
	for a in Data.ALBUMS.size():
		n += album_count(a)
	return n

var _shell_refresh_busy := false
func refresh_shell() -> Dictionary:
	if replay_input(): return await Replay.perform("shell_refresh")
	if _shell_refresh_busy: return {"ok": false, "message": "正在刷新"}
	_shell_refresh_busy = true
	var result: Dictionary
	if server_mode():
		result = await _cloud().act("/v1/shop/shell/refresh")
	elif spend("amber", Data.STORE_SHELL_REFRESH):
		check_shell_period()
		shell_bought = {}
		result = {"ok": true}
	else: result = {"ok": false, "message": "琥珀不够了！"}
	_shell_refresh_busy = false
	if result.get("ok", false):
		dirty()
		changed.emit()
	return result

func _merge_coin(merged: String, origin: int) -> void:
	var uid := str(random_for("merge_drops").randi()) if Replay.active else (("sim-%s-%s" % [int(now()*1000000), rng.randi()]) if simulation_time >= 0 else Crypto.new().generate_random_bytes(16).hex_encode())
	var to := find_empty_near(origin) if not tutorial_on else -1
	cloud_event({"id": uid, "type": "merge", "item": merged, "cell": to})
	if to < 0: return
	var roll := float(uid.sha256_text().substr(0, 8).hex_to_int()) / 4294967296.0
	# 掷点用事件 id 的哈希，服务器按同一个 id 复算，结果一致
	var id := Data.resource_drop("main", roll, level, merged)
	if id == "": return
	Rewards.grant([[id, 1, "physical"]], Callable(), false, true, {"board_origin": to})
	if is_instance_valid(main): main.board_screen.board.fly_in(origin, to, id)

func can_move(i: int) -> bool:
	if i < 0 or i >= board.size(): return false
	if is_merge_bubble(i):
		return bubble_left(i) > 0 and not _bubble_busy.has(str(board[i]["bubble"].get("uid", "")))
	return is_free(i) and (cell_id(i) != "" or cooking(i))

func _drop_bubble(a: int, b: int) -> String:
	if not can_move(a) or (not is_free(b) and not can_move(b)): return ""
	var onto_empty := _vacant(b)
	for key in ["id", "lock", "bubble", "gm", "ck"]:
		var va = board[a].get(key)
		var vb = board[b].get(key)
		board[a].erase(key)
		board[b].erase(key)
		if va != null: board[b][key] = va
		if vb != null: board[a][key] = vb
	_sync_cook_cells()
	dirty()
	board_changed.emit()
	return "move" if onto_empty else "swap"
