extends RefCounted
## Strict current-format snapshots. Gameplay state never includes transport journals or presentation settings.
const Values := preload("res://scripts/domain/StateValues.gd")
const AtomicFile := preload("res://scripts/storage/AtomicFile.gd")
const SCHEMA := 1
const FIELDS := [
	"replay_meta", "player_id", "seen_tutorial", "tutorial_on",
	"level", "xp", "energy", "shells", "amber", "rush", "energy_stamp",
	"boost", "boost_gm", "board", "inv", "inv_chests", "inv_cap", "stash",
	"discovered", "book_claimed", "orders", "order_serial", "story_done", "pending_orders", "builds", "cards", "card_stars",
	"tokens", "token_claimed", "hot_bought", "hot_revision", "deals_bought", "deals_day",
	"shell_bought", "shell_period", "energy_buys",
	"pass_pts", "pass_tier", "pass_free", "pass_prem", "pass_super", "pass_endless", "pass_super_bonus", "pass_season",
	"fossil_dig", "ufo_offer", "offers", "local_race", "duel_race", "tiger_escape",
	"gm_activities", "seven_day", "merge_events",
]

static func capture(game: Node, include_local: bool = true) -> Dictionary:
	var state := {"schema": SCHEMA, "replay_rng": game.random_save()}
	for field in FIELDS:
		state[field] = game.get(field)
	if include_local:
		state["settings"] = game.settings
		state["tiger_escape_seen"] = game.tiger_escape_seen
		state["tips_seen"] = game.tips_seen
		var replay = game.get_node_or_null("/root/Replay")
		state["replay_local"] = replay.journal() if replay != null and replay.active else game.replay_local
	return state

static func normalize(value):
	return Values.copy(value)

## 订单补给箱从 10 级缩成 5 级：旧存档里的 6~10 级一律当作 5 级（只改物品 id，就地修改）。
static func migrate_ids(state: Dictionary) -> void:
	var cells = state.get("board")
	if cells is Array:
		for cell in cells:
			if cell is Dictionary and cell.get("id") is String:
				cell["id"] = _migrate_id(cell["id"])
	for field in ["inv", "stash"]:
		var items = state.get(field)
		if items is Array:
			for i in items.size():
				if items[i] is String: items[i] = _migrate_id(items[i])

static func _migrate_id(id: String) -> String:
	if id.begins_with("orderbox_") and id.get_slice("_", 1).is_valid_int() and int(id.get_slice("_", 1)) > 5:
		return "orderbox_5"
	return id

static func validate(game: Node, state: Dictionary) -> bool:
	if state.get("schema") != SCHEMA or not state.get("replay_rng") is Dictionary:
		return false
	migrate_ids(state)
	migrate_card_stars(state)
	var random_state: Dictionary = state["replay_rng"]
	if not random_state.get("seed") is String or not random_state.get("streams") is Dictionary:
		return false
	for field in FIELDS:
		if not state.has(field): return false
		var current = game.get(field)
		var incoming = state[field]
		match typeof(current):
			TYPE_DICTIONARY:
				if not incoming is Dictionary: return false
			TYPE_ARRAY:
				if not incoming is Array: return false
			TYPE_STRING:
				if not incoming is String: return false
			TYPE_BOOL:
				if not incoming is bool: return false
			TYPE_INT:
				if not (incoming is int or incoming is float): return false
				if not is_finite(float(incoming)) or float(incoming) != floor(float(incoming)): return false
			TYPE_FLOAT:
				if not (incoming is int or incoming is float) or not is_finite(float(incoming)): return false
	var cells: Array = state["board"]
	if cells.size() != game.COLS * game.ROWS: return false
	for cell in cells:
		if not cell is Dictionary or not cell.get("id") is String: return false
		var id := str(cell["id"])
		if id != "" and (not Data.is_known(id) or Data.is_numeric_resource(id)): return false
		if not cell.get("lock") is int and not cell.get("lock") is float: return false
		if float(cell["lock"]) != floor(float(cell["lock"])): return false
		if int(cell["lock"]) < 0 or int(cell["lock"]) > 3: return false
		if int(cell["lock"]) == 3 and not cell.get("bubble") is Dictionary: return false
	for container in [state["inv"], state["stash"]]:
		for item in container:
			if not item is String or not Data.is_known(item) or Data.is_numeric_resource(item): return false
	return int(state["level"]) >= 1 and int(state["inv_cap"]) >= 1 and int(state["card_stars"]) >= 0

## Older saves kept duplicate copies. Convert only when adding the new wallet,
## so reloading a checkpoint can never pay those copies twice.
static func migrate_card_stars(state: Dictionary) -> void:
	if state.has("card_stars"): return
	state["card_stars"] = 0
	if not state.get("cards") is Dictionary: return
	for key in state["cards"]:
		var parts := str(key).split("_")
		if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int(): continue
		var album := int(parts[0])
		var index := int(parts[1])
		if album < 0 or album >= Data.ALBUMS.size() or index < 0 or index >= Data.ALBUMS[album]["cards"].size(): continue
		var copies := int(state["cards"][key])
		if copies > 1:
			state["card_stars"] += (copies - 1) * CardPacks.duplicate_value(album, index)
			state["cards"][key] = 1

static func restore(game: Node, state: Dictionary) -> bool:
	if not validate(game, state): return false
	var clean: Dictionary = normalize(state)
	game.random_load(clean["replay_rng"])
	for field in FIELDS:
		game.set(field, clean[field])
	return true

static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

static func write(path: String, state: Dictionary) -> bool:
	var error := AtomicFile.write_json(path, state)
	if error != OK: push_error("Cannot write game checkpoint: " + error_string(error))
	return error == OK
