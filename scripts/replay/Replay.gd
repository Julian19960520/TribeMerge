extends Node
## Executes deterministic commands, durably records input, and uploads snapshots to the cloud.
const Values := preload("res://scripts/domain/StateValues.gd")
const Rules := preload("res://scripts/replay/Reducer.gd")
const JournalStore := preload("res://scripts/replay/Journal.gd")
const RewardUpgrade := preload("res://scripts/storage/EarlyRewardUpgrade.gd")
const FifthLineUpgrade := preload("res://scripts/storage/FifthLineUpgrade.gd")
const PROTOCOL := 1
const ENGINE := "4.6.3"
const CHECKPOINT_OPERATIONS := 32
const CHECKPOINT_SECONDS := 5.0
## Commands kept since the last cloud upload (only the snapshot is uploaded).
const MAX_PENDING := 500
## One compatible upgrade: recover old automatic payouts before switching to manual claims.
const AUTOMATIC_ALBUM_RULES := "85bcaca55a055ded5dcbff79bd78d98ea037c4de1dead8415f66b45cdf0c7550"
const MANUAL_ALBUM_RULES := "148e80059573539ac7a6780c5d7b775ce0de00abadb91be0ac300ec8ca3f3964"
const HUD_FIELDS := ["level", "xp", "energy", "shells", "amber", "rush", "energy_stamp", "boost", "boost_gm", "inv", "inv_chests", "inv_cap", "discovered", "book_claimed", "builds", "cards", "stash", "tokens", "token_claimed", "pass_pts", "pass_tier", "pass_free", "pass_prem", "pass_super", "pass_endless", "pass_super_bonus", "pass_season", "hot_bought", "hot_revision", "deals_bought", "deals_day", "shell_bought", "shell_period", "energy_buys", "offers", "ufo_offer", "gm_activities", "local_race", "duel_race", "tiger_escape", "fossil_dig"]
var active := false
var executing := false
var worker := false
var clock := 0
var seq := 0
var base := 0
var authorized := false
var pending: Array = []
var inflight: Dictionary = {}
var meta: Dictionary = {}
var recovery_error := ""
var _timer := 0.0
var _checkpoint_timer := 0.0
var _rules := ""
var _rules_revision := -1
var _session_rules := ""
var _failed_rules_edit := false
var _rules_edit_authorized := false
var _rules_edit_hash := ""
var _generation := ""
var _ops_since_checkpoint := 0
var _recovering := false
var _force_upload := false
var _reducer: RefCounted

func _ready() -> void:
	var arguments := OS.get_cmdline_user_args()
	worker = "--replay-worker" in arguments or "--replay-service" in arguments
	active = worker or get_tree().get_script() == null or "--replay-test" in arguments
	_reducer = Rules.new(self)
	if not active: return
	meta = G.replay_meta
	seq = int(meta.get("seq", 0))
	clock = int(meta.get("at", 0))
	if worker: return
	var saved: Dictionary = G.replay_local
	base = int(saved.get("base", 0))
	pending = saved.get("pending", [])
	inflight = saved.get("inflight", {})
	authorized = bool(saved.get("authorized", false))
	_generation = str(saved.get("generation", ""))
	if _generation == "": _generation = _new_generation()
	# The client is authoritative for single-player progress: play starts at once,
	# online or not, and the cloud only stores snapshots.
	authorized = true
	if not Cloud.enabled: meta["allow_gm"] = true
	if G.random_seed == "": G.random_seed = Crypto.new().generate_random_bytes(32).hex_encode()
	var skip_journal := false
	var upgrade_fifth_line := G.loaded_save and not Cloud.enabled and FifthLineUpgrade.applies(str(saved.get("rules", "")), rules_hash(), [RewardUpgrade.FROM_RULES, AUTOMATIC_ALBUM_RULES])
	var upgrade_rewards := G.loaded_save and not Cloud.enabled and RewardUpgrade.applies(str(saved.get("rules", "")), rules_hash(), AUTOMATIC_ALBUM_RULES)
	var upgrade_albums := G.loaded_save and not Cloud.enabled and str(saved.get("rules", "")) == AUTOMATIC_ALBUM_RULES and (rules_hash() == MANUAL_ALBUM_RULES or upgrade_rewards)
	_reducer.legacy_album_rewards = upgrade_albums
	if G.loaded_save and str(saved.get("rules", "")) != rules_hash() and not upgrade_albums and not upgrade_rewards and not upgrade_fifth_line:
		if Cloud.enabled:
			# A new client version: keep the last checkpoint and drop only the few
			# seconds of journal written under the old rules.
			skip_journal = true
			pending = []
			inflight = {}
		else:
			recovery_error = "本地测试存档规则版本已更新"
			pending = []
			inflight = {}
			base = 0
			seq = 0
			meta = {}
			_generation = _new_generation()
			G.loaded_save = false
			Cloud._say.call_deferred(recovery_error + "，已开始新的测试进度")
			G.random_seed = Crypto.new().generate_random_bytes(32).hex_encode()
			G.random_streams = {}
	_session_rules = rules_hash()
	if authorized:
		if G.loaded_save:
			var current_config := FifthLineUpgrade.begin() if upgrade_fifth_line else {}
			var current_rewards := RewardUpgrade.begin() if upgrade_rewards else {}
			if not skip_journal: _recover()
			if upgrade_rewards: RewardUpgrade.finish(current_rewards)
			if upgrade_fifth_line: FifthLineUpgrade.finish(current_config)
		else:
			clock = int(Cloud.server_now())
			executing = true
			G.new_game()
			# GM tools exist in local tests and debug builds, never in release exports.
			meta = {"allow_gm": not Cloud.enabled or OS.is_debug_build()}
			advance()
			_canonicalize_live()
			snapshot()
			executing = false
			G.clear_presentations()
	_reducer.legacy_album_rewards = false
	if upgrade_albums or upgrade_rewards or upgrade_fifth_line:
		# The offline journal was recovered with its original payout behavior.
		# Already-paid markers, ownership, currencies and identity are retained.
		base = seq
		pending = []
		inflight = {}
	if not checkpoint() and (upgrade_albums or upgrade_rewards or upgrade_fifth_line): authorized = false

func journal() -> Dictionary:
	return {"base": base, "pending": pending, "inflight": inflight, "authorized": authorized,
		"generation": _generation, "rules": _session_rules if _session_rules != "" else rules_hash()}

func rules_hash() -> String:
	var revision: int = Data.ConfigFiles.revision
	if _rules == "" or revision != _rules_revision:
		var parts := ["tribe-rules-1-godot-" + ENGINE]
		for name in DirAccess.get_files_at("res://data"):
			if name.ends_with(".json"):
				var path := "res://data/" + name
				parts.append(path + ":" + FileAccess.get_sha256(path))
		parts.sort()
		_rules = "\n".join(parts).sha256_text()
		_rules_revision = revision
	return _rules

func snapshot(previous: Dictionary = {}) -> Dictionary:
	meta["seq"] = seq
	meta["at"] = clock
	G.replay_meta = meta
	var raw: Dictionary = G.save_dict(false)
	var out := {}
	var keys: Array = raw.keys()
	keys.sort()
	for key in keys:
		# Reuse owned immutable snapshot branches, never references to live state.
		# Metadata is always owned because tick comparison temporarily edits its clock.
		if key != "replay_meta" and previous.has(key) and raw[key] == previous[key]: out[key] = previous[key]
		else: out[key] = Values.copy(raw[key], true)
	return out

func normalize(value):
	return Values.copy(value, true)

func _canonicalize(value):
	return Values.in_place(value)

func _canonicalize_live() -> void:
	# Mutate nested business values directly; do not serialize/reload the game.
	G.replay_meta = meta
	var state: Dictionary = G.save_dict(false)
	for key in state:
		var value = state[key]
		if value is Array or value is Dictionary: _canonicalize(value)
		elif value is float: G.set(key, _canonicalize(value))

func digest() -> String:
	return JSON.stringify(snapshot()).sha256_text()

func restore(state: Dictionary) -> bool:
	var was_executing := executing
	executing = true
	if not G.load_snapshot(state):
		executing = was_executing
		return false
	meta = G.replay_meta
	seq = int(meta.get("seq", 0))
	clock = int(meta.get("at", 0))
	executing = was_executing
	return true

func checkpoint() -> bool:
	if not active or worker or executing or _recovering: return true
	var previous_generation := _generation
	_generation = _new_generation()
	var error := JournalStore.write_checkpoint(G.save_path, G.save_dict(true))
	if error != OK:
		_generation = previous_generation
		Cloud._say("无法保存进度，请检查可用存储空间")
		return false
	JournalStore.rotate(_journal_path())
	_ops_since_checkpoint = 0
	_checkpoint_timer = 0.0
	return true

func restart_local_rules() -> bool:
	# This is a new local test session, never a migration of an existing game.
	if Cloud.enabled or worker or executing or not active: return false
	var before := snapshot()
	var old_pending := pending
	var old_inflight := inflight
	var old_base := base
	var old_authorized := authorized
	var old_generation := _generation
	var old_rules := _session_rules if _session_rules != "" else (_rules if _rules != "" else rules_hash())
	var old_ops := _ops_since_checkpoint
	var old_checkpoint_timer := _checkpoint_timer
	var old_loaded: bool = G.loaded_save
	var old_seen: Dictionary = G.tiger_escape_seen.duplicate(true)
	var old_layout := {}
	for field in ["COLS", "ROWS", "MAX_ENERGY", "REGEN_SEC", "RANDOM_ORDERS", "TOKEN_STEP"]:
		old_layout[field] = G.get(field)
	var was_blocked: bool = G.is_blocking_signals()
	G.set_block_signals(true)
	G.clear_presentations()
	executing = true
	authorized = false
	pending = []
	inflight = {}
	base = 0
	seq = 0
	clock = int(Cloud.server_now())
	meta = {"allow_gm": true}
	G.random_seed = Crypto.new().generate_random_bytes(32).hex_encode()
	G.random_streams = {}
	G._apply_rules()
	G.new_game()
	advance()
	_canonicalize_live()
	executing = false
	authorized = true
	_rules = ""
	_rules_revision = -1
	_session_rules = rules_hash()
	snapshot()
	if not checkpoint():
		# The previous state is a trusted in-memory transaction snapshot. Restore
		# fields directly because the editor has not restored the old data files yet.
		for field in old_layout: G.set(field, old_layout[field])
		G.random_load(before["replay_rng"])
		for field in G.StateCodec.FIELDS: G.set(field, before[field])
		G.clear_transient()
		meta = G.replay_meta
		seq = int(meta["seq"])
		clock = int(meta["at"])
		pending = old_pending
		inflight = old_inflight
		base = old_base
		_generation = old_generation
		_session_rules = old_rules
		_ops_since_checkpoint = old_ops
		_checkpoint_timer = old_checkpoint_timer
		G.loaded_save = old_loaded
		G.tiger_escape_seen = old_seen
		authorized = false
		_failed_rules_edit = true
		_rules_edit_authorized = old_authorized
		_rules_edit_hash = old_rules
		G.set_block_signals(was_blocked)
		return false
	_failed_rules_edit = false
	_rules_edit_hash = ""
	_rules_edit_authorized = false
	_timer = 0.0
	G.loaded_save = true
	G.clear_presentations()
	G.set_block_signals(was_blocked)
	notify_restored()
	return true

func restore_rules_edit_authorization() -> bool:
	# The editor calls this only after exact file rollback and Data.refresh().
	if Cloud.enabled or worker or executing: return false
	if not _failed_rules_edit: return true
	if rules_hash() != _rules_edit_hash: return false
	for pair in [["COLS", "cols"], ["ROWS", "rows"], ["MAX_ENERGY", "max_energy"], ["REGEN_SEC", "regen_sec"], ["RANDOM_ORDERS", "random_orders"], ["TOKEN_STEP", "token_step"]]:
		if int(G.get(pair[0])) != int(Data.RULES.get(pair[1], -1)): return false
	authorized = _rules_edit_authorized
	_failed_rules_edit = false
	_rules_edit_hash = ""
	_rules_edit_authorized = false
	return true

func _journal_path() -> String:
	return G.save_path + ".journal"

func _new_generation() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()

func _recover() -> void:
	var loaded: Dictionary = JournalStore.read(_journal_path(), _generation, seq)
	recovery_error = str(loaded["error"])
	_recovering = true
	for operation in loaded["ops"]:
		var before := snapshot()
		var result = perform(str(operation["name"]), operation["args"], int(operation["at"]))
		if _failed(result) or seq != int(operation["seq"]) or digest() != str(operation["hash"]):
			restore(before)
			recovery_error = "本地操作恢复校验失败，已保留最后完整操作"
			break
		pending.append(operation)
	_recovering = false
	G.clear_presentations()
	if recovery_error != "": push_error(recovery_error)

func _process(delta: float) -> void:
	if not active or worker or not authorized or executing: return
	_timer += delta
	_checkpoint_timer += delta
	if _timer >= 1.0:
		_timer = fmod(_timer, 1.0)
		perform("tick")
	if _ops_since_checkpoint > 0 and _checkpoint_timer >= CHECKPOINT_SECONDS: checkpoint()

func _failed(result) -> bool:
	return result is Dictionary and (result.has("error") or result.get("ok", true) == false)

func perform(name: String, args: Dictionary = {}, at := -1):
	if not active: return {"error": "未启用操作重放"}
	if executing: return {"error": "操作正在处理"}
	if not worker and not authorized: return {"error": "首次进入需要联网取得存档"}
	if not worker and not _recovering and _session_rules != "" and rules_hash() != _session_rules:
		return {"error": "配置已变化，请保存并重开测试局"}
	var before := snapshot()
	var old_opened: Array = G.opened.duplicate()
	var old_cooked: Array = G.cooked_pop.duplicate()
	var old_clock := clock
	var current_time := int(G.simulation_time) if G.simulation_time >= 0 else int(Cloud.server_now())
	var target_clock := maxi(clock, current_time if at < 0 else at)
	var was_blocked: bool = G.is_blocking_signals()
	G.set_block_signals(true)
	G.clear_presentations()
	clock = target_clock
	executing = true
	advance()
	var result: Dictionary = _reducer.dispatch(name, args)
	result["ok"] = not _failed(result)
	if not result["ok"] and not result.has("error"): result["error"] = str(result.get("message", "操作失败"))
	var failed := _failed(result)
	var committed_name := name
	var committed_args := args
	if failed:
		# Roll back the invalid input, then keep legitimate elapsed-time changes.
		restore(before)
		G.opened = old_opened
		G.cooked_pop = old_cooked
		G.clear_presentations()
		clock = target_clock
		advance()
		committed_name = "tick"
		committed_args = {}
	_canonicalize_live()
	var after := snapshot(before) if not worker or committed_name == "tick" else {}
	if committed_name == "tick":
		after["replay_meta"]["at"] = old_clock
		if after == before:
			clock = old_clock
			meta["at"] = old_clock
			executing = false
			G.clear_presentations()
			G.set_block_signals(was_blocked)
			return result
	seq += 1
	meta["seq"] = seq
	meta["at"] = clock
	if not worker and not _recovering:
		after["replay_meta"]["seq"] = seq
		after["replay_meta"]["at"] = clock
		var operation := {"seq": seq, "at": clock, "name": committed_name, "args": committed_args.duplicate(true), "hash": JSON.stringify(after).sha256_text()}
		var error := JournalStore.append(_journal_path(), _generation, operation)
		if error != OK:
			restore(before)
			G.opened = old_opened
			G.cooked_pop = old_cooked
			executing = false
			G.clear_presentations()
			G.set_block_signals(was_blocked)
			return {"error": "无法保存操作，请检查可用存储空间"}
		pending.append(operation)
		if pending.size() > MAX_PENDING: pending = pending.slice(pending.size() - MAX_PENDING)
		_ops_since_checkpoint += 1
	executing = false
	G.set_block_signals(was_blocked)
	if not worker and not _recovering:
		if _ops_since_checkpoint >= CHECKPOINT_OPERATIONS: checkpoint()
		_notify(before, after)
		G.flush_presentations()
	else:
		G.clear_presentations()
	return result

func _notify(before: Dictionary, after: Dictionary) -> void:
	if before.get("board") != after.get("board"): G.board_changed.emit()
	if before.get("orders") != after.get("orders") or before.get("pending_orders") != after.get("pending_orders"): G.orders_changed.emit()
	for field in HUD_FIELDS:
		if before.get(field) != after.get(field):
			G.changed.emit()
			break
	if before.get("merge_events") != after.get("merge_events"): G.merge_event_changed.emit()
	if before.get("seven_day") != after.get("seven_day"): G.seven_day_changed.emit()

func notify_restored() -> void:
	G.board_changed.emit()
	G.orders_changed.emit()
	G.changed.emit()
	G.merge_event_changed.emit()
	G.seven_day_changed.emit()

func advance() -> void:
	_reducer.advance()

func gift_view() -> Dictionary:
	return _reducer.gift_view()

## Whether local progress exists that the cloud has not stored yet.
func needs_upload() -> bool:
	return active and not worker and authorized and (_force_upload or not pending.is_empty())

## Boot / login: decide between this device's progress and the cloud snapshot.
func connect_session(why: String) -> void:
	Cloud._busy = true
	var response: Array = await Cloud._call("POST", "/v2/session", {})
	Cloud._busy = false
	if response[0] != 200:
		Cloud._offline("boot")
		return
	var data: Dictionary = response[1]
	var version := int(data.get("version", 0))
	if str(data.get("data", "")) == "":
		# Nothing in the cloud yet: this device's progress becomes the first save.
		base = 0
		_force_upload = true
	elif why == "login" or (version != base and not bool(data.get("mine", false))):
		# The account was played on another device since this one last synced.
		if not adopt(data):
			Cloud._say("云端存档无法读取，暂不同步本机进度")
			Cloud._offline("boot")
			return
		if why != "login": Cloud._say("已载入其他设备上的最新进度")
	elif version != base:
		# Our own earlier upload whose reply was lost; this device is newer.
		_force_upload = true
	Cloud._after_boot()
	if needs_upload(): upload()

## Replace local progress with a cloud snapshot after verifying its integrity.
func adopt(data: Dictionary) -> bool:
	var raw := Marshalls.base64_to_raw(str(data.get("data", ""))).decompress_dynamic(4 * 1024 * 1024, FileAccess.COMPRESSION_GZIP)
	var text := raw.get_string_from_utf8()
	if text == "" or text.sha256_text() != str(data.get("hash", "")): return false
	var state = JSON.parse_string(text)
	if not state is Dictionary: return false
	var previous := snapshot()
	if not restore(state):
		restore(previous)
		return false
	pending = []
	inflight = {}
	_force_upload = false
	base = int(data["version"])
	G.loaded_save = true
	if not checkpoint(): return false
	Cloud.last_sync = Cloud.server_now()
	Cloud._save_state()
	notify_restored()
	Cloud.restored.emit()
	return true

## Upload the whole current snapshot. Commands performed meanwhile stay pending.
func upload() -> void:
	if Cloud._busy or not Cloud.can_talk() or executing or not needs_upload(): return
	var text := JSON.stringify(snapshot())
	var uploaded_seq := seq
	var body := {"base": base, "hash": text.sha256_text(),
		"data": Marshalls.raw_to_base64(text.to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))}
	inflight = {"seq": uploaded_seq, "base": base}
	Cloud._busy = true
	Cloud._last_up = Cloud._ticks()
	var response: Array = await Cloud._call("POST", "/v2/save", body)
	Cloud._busy = false
	inflight = {}
	if response[0] != 200:
		if response[0] != 0 and response[0] != 401: push_warning("Cloud save rejected: %s" % str(response[1]))
		Cloud._offline("upload")
		return
	var data: Dictionary = response[1]
	if data.get("conflict", false):
		if adopt(data): Cloud._say("账号在其他设备上有更新的进度，已载入云端存档")
		else: Cloud._offline("upload")
		return
	pending = pending.filter(func(operation): return int(operation["seq"]) > uploaded_seq)
	base = int(data["version"])
	_force_upload = false
	Cloud.last_sync = Cloud.server_now()
	Cloud._save_state()
	checkpoint()
	Cloud.online = true
	Cloud.uploads += 1
	Cloud.synced.emit("replay", true)
