extends Node
## 全局状态（autoload: G）

signal boil_tick
signal changed
signal board_changed
signal orders_changed

const COLS := 7
const ROWS := 9
const MAX_ENERGY := 100
const REGEN_SEC := 120
const SAVE_PATH := "user://tribe_save.json"
const INV_MAX := 10

var main: Node = null
var font_title: Font
var font_body: Font

var level := 1
var xp := 0
var energy := 100
var shells := 320
var amber := 140
var energy_stamp := 0.0
var board: Array = []
var inv: Array = []
var inv_cap := 5
var discovered := {}
var orders: Array = []
var builds := {}
var cards := {}
var reward_box: Array = []
var settings := {"music": true, "sound": true, "vibrate": true, "hint": true}
var hot_bought := {}
var deals_bought := {}
var deals_day := ""
var player_id := ""
var seen_tutorial := false

var _boil_t := 0.0
var _save_t := -1.0
var _regen_t := 0.0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	font_title = _sysfont(["STHupo", "Microsoft YaHei UI", "Microsoft YaHei"], 400)
	font_body = _sysfont(["Microsoft YaHei UI", "Microsoft YaHei", "SimHei"], 700)
	if not load_game():
		new_game()
	_check_day()

func _sysfont(names: Array, weight: int) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(names)
	f.font_weight = weight
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return f

func _process(delta: float) -> void:
	_boil_t += delta
	if _boil_t >= 0.125:
		_boil_t = fmod(_boil_t, 0.125)
		Art.boil = (Art.boil + 1) % 4
		boil_tick.emit()
	_regen_t += delta
	if _regen_t >= 1.0:
		_regen_t = 0.0
		_regen()
	if _save_t >= 0.0:
		_save_t -= delta
		if _save_t < 0.0:
			save_game()

func now() -> float:
	return Time.get_unix_time_from_system()

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

func secs_to_midnight() -> int:
	var t := Time.get_datetime_dict_from_system()
	return 86400 - (int(t["hour"]) * 3600 + int(t["minute"]) * 60 + int(t["second"]))

func event_left() -> int:
	return 35 * 86400 + 15 * 3600 - int(fmod(now(), 86400.0))

func _check_day() -> void:
	var d := Time.get_date_string_from_system()
	if d != deals_day:
		deals_day = d
		deals_bought = {}
		hot_bought = {}

# ---------------------------------------------------------------- 存档

func dirty() -> void:
	_save_t = 0.6

func new_game() -> void:
	level = 1
	xp = 0
	energy = 100
	shells = 320
	amber = 140
	energy_stamp = now()
	inv = []
	inv_cap = 5
	discovered = {}
	builds = {"fire": 1}
	cards = {}
	reward_box = ["pack_1"]
	player_id = "TRB" + str(rng.randi_range(10000000, 99999999))
	seen_tutorial = false
	_init_board()
	orders = []
	for i in 3:
		orders.append(_make_order())
	dirty()

func _init_board() -> void:
	board = []
	for i in COLS * ROWS:
		board.append({"id": "", "lock": 0})
	var open_items := {
		0: "berry_1", 1: "stone_1", 4: "berry_2", 6: "fish_1",
		8: "basket_2", 11: "hunt_2", 13: "fire_1",
		14: "berry_1", 17: "meat_1", 19: "shell_1",
		22: "stone_1", 24: "berry_1", 26: "meat_2",
	}
	for k in open_items:
		board[k]["id"] = open_items[k]
	var pool := ["berry_1", "berry_2", "stone_1", "stone_2", "meat_1", "meat_2", "fish_1", "shell_1", "fire_1", "amber_1"]
	var r := RandomNumberGenerator.new()
	r.seed = 1234
	for row in range(4, ROWS):
		for col in COLS:
			var i := row * COLS + col
			if row == 4 and col % 3 != 0:
				continue
			board[i]["id"] = pool[r.randi() % pool.size()]
			board[i]["lock"] = 1 if row <= 5 else 2
	for k in board:
		if k["id"] != "" and k["lock"] == 0:
			discover(k["id"])

func save_game() -> void:
	var d := {
		"level": level, "xp": xp, "energy": energy, "shells": shells, "amber": amber,
		"energy_stamp": energy_stamp, "board": board, "inv": inv, "inv_cap": inv_cap,
		"discovered": discovered, "orders": orders, "builds": builds, "cards": cards,
		"reward_box": reward_box, "settings": settings, "hot_bought": hot_bought,
		"deals_bought": deals_bought, "deals_day": deals_day, "player_id": player_id,
		"seen_tutorial": seen_tutorial,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY or not d.has("board"):
		return false
	level = int(d["level"])
	xp = int(d["xp"])
	energy = int(d["energy"])
	shells = int(d["shells"])
	amber = int(d["amber"])
	energy_stamp = float(d["energy_stamp"])
	board = d["board"]
	for c in board:
		c["lock"] = int(c["lock"])
	inv = d["inv"]
	inv_cap = int(d["inv_cap"])
	discovered = d["discovered"]
	orders = d["orders"]
	for o in orders:
		o["who"] = int(o["who"])
		o["reward"] = int(o["reward"])
		o["xp"] = int(o["xp"])
	builds = d["builds"]
	for k in builds:
		builds[k] = int(builds[k])
	cards = d["cards"]
	reward_box = d["reward_box"]
	settings = d["settings"]
	hot_bought = d.get("hot_bought", {})
	deals_bought = d.get("deals_bought", {})
	deals_day = d.get("deals_day", "")
	player_id = d.get("player_id", "TRB00000000")
	seen_tutorial = d.get("seen_tutorial", true)
	return true

func reset_game() -> void:
	new_game()
	save_game()
	board_changed.emit()
	orders_changed.emit()
	changed.emit()

# ---------------------------------------------------------------- 货币

func add_currency(kind: String, n: int) -> void:
	match kind:
		"energy": energy += n
		"shell": shells += n
		"amber": amber += n
	if kind == "energy" and energy >= MAX_ENERGY:
		energy_stamp = now()
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
	dirty()
	changed.emit()
	return true

func xp_need() -> int:
	return 6 + level * 3

func add_xp(n: int) -> bool:
	xp += n
	var up := false
	while xp >= xp_need():
		xp -= xp_need()
		level += 1
		up = true
	dirty()
	changed.emit()
	return up

# ---------------------------------------------------------------- 棋盘

func idx(c: int, r: int) -> int:
	return r * COLS + c

func cell_id(i: int) -> String:
	return board[i]["id"]

func is_free(i: int) -> bool:
	return board[i]["lock"] == 0

func empty_count() -> int:
	var n := 0
	for c in board:
		if c["id"] == "" and c["lock"] == 0:
			n += 1
	return n

func find_empty_near(i: int) -> int:
	var best := -1
	var bd := 1e9
	var c0 := Vector2(i % COLS, i / COLS)
	for k in board.size():
		if board[k]["id"] == "" and board[k]["lock"] == 0:
			var d := c0.distance_squared_to(Vector2(k % COLS, k / COLS)) + float(k) * 0.0001
			if d < bd:
				bd = d
				best = k
	return best

func place(i: int, id: String) -> void:
	board[i]["id"] = id
	discover(id)
	dirty()

func discover(id: String) -> bool:
	if id == "" or discovered.has(id):
		return false
	var ch := Data.chain(id)
	for l in range(1, Data.lv(id) + 1):
		discovered["%s_%d" % [ch, l]] = true
	return true

func unlock_around(i: int) -> void:
	var c := i % COLS
	var r := i / COLS
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nc: int = c + d.x
		var nr: int = r + d.y
		if nc < 0 or nr < 0 or nc >= COLS or nr >= ROWS:
			continue
		var k := idx(nc, nr)
		if board[k]["lock"] == 2:
			board[k]["lock"] = 1

## 返回 "merge" / "move" / "swap" / ""
func try_drop(a: int, b: int) -> String:
	if a == b:
		return ""
	var ida: String = board[a]["id"]
	var idb: String = board[b]["id"]
	var lb: int = board[b]["lock"]
	if ida == "" or board[a]["lock"] != 0:
		return ""
	if lb == 2:
		return ""
	if idb == ida and Data.next_id(ida) != "":
		var nx := Data.next_id(ida)
		board[a]["id"] = ""
		board[b]["id"] = nx
		board[b]["lock"] = 0
		discover(nx)
		unlock_around(b)
		dirty()
		board_changed.emit()
		return "merge"
	if lb != 0:
		return ""
	if idb == "":
		board[b]["id"] = ida
		board[a]["id"] = ""
		dirty()
		board_changed.emit()
		return "move"
	board[b]["id"] = ida
	board[a]["id"] = idb
	dirty()
	board_changed.emit()
	return "swap"

func roll_produce(gen_id: String) -> String:
	var r := rng.randf()
	if r < 0.05:
		return "fire_1"
	if r < 0.08:
		return "shell_1"
	var outs := Data.gen_outputs(gen_id)
	var ch: String = outs[rng.randi() % outs.size()]
	var lv := 1
	if rng.randf() < 0.12 * float(Data.lv(gen_id) - 1):
		lv = 2
	return "%s_%d" % [ch, lv]

func roll_chest() -> Array:
	var out := []
	var pool := ["berry_2", "stone_2", "meat_2", "fish_2", "fire_2", "shell_2", "amber_1", "berry_3", "meat_3"]
	for i in 3:
		out.append(pool[rng.randi() % pool.size()])
	return out

# ---------------------------------------------------------------- 订单

func _make_order() -> Dictionary:
	var n := 1 if level < 3 or rng.randf() < 0.5 else 2
	var items := []
	var reward := 0
	var top: int = min(5, 2 + level / 2)
	for i in n:
		var ch: String = Data.ORDER_CHAINS[rng.randi() % Data.ORDER_CHAINS.size()]
		var lv := rng.randi_range(2, mini(top, Data.max_lv(ch)))
		items.append("%s_%d" % [ch, lv])
		reward += 4 * int(pow(2, lv - 1)) + rng.randi_range(0, 6)
	return {"who": rng.randi() % Data.PEOPLE.size(), "items": items, "reward": reward, "xp": n + (1 if reward > 30 else 0)}

func board_has(id: String, exclude: Array = []) -> int:
	for k in board.size():
		if board[k]["id"] == id and board[k]["lock"] == 0 and not (k in exclude):
			return k
	return -1

func order_cells(o: Dictionary) -> Array:
	var used := []
	for id in o["items"]:
		var k := board_has(id, used)
		if k < 0:
			return []
		used.append(k)
	return used

func order_ready(o: Dictionary) -> bool:
	return order_cells(o).size() == o["items"].size()

func wanted_ids() -> Dictionary:
	var d := {}
	for o in orders:
		for id in o["items"]:
			d[id] = true
	return d

## 交付订单，返回被移除的格子
func complete_order(oi: int) -> Array:
	var o: Dictionary = orders[oi]
	var cells := order_cells(o)
	if cells.size() != o["items"].size():
		return []
	for k in cells:
		board[k]["id"] = ""
	orders.remove_at(oi)
	orders.append(_make_order())
	dirty()
	board_changed.emit()
	orders_changed.emit()
	return cells

# ---------------------------------------------------------------- 建筑 / 卡牌

func build_cost(id: String) -> int:
	return 60 + int(builds.get(id, 0)) * 45

func build_reward(id: String) -> int:
	return 15 + int(builds.get(id, 0)) * 5

func open_pack() -> Array:
	var out := []
	for i in 2:
		var a := rng.randi() % Data.ALBUMS.size()
		var c := rng.randi() % 9
		var key := "%d_%d" % [a, c]
		cards[key] = int(cards.get(key, 0)) + 1
		out.append([a, c])
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
