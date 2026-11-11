@tool
extends RefCounted
## Configuration registry. Shared values are recursively read-only; editor reads are owned copies.
const Schema := preload("res://scripts/config/config_schema.gd")
const LINES := "res://data/lines.json"
const CHAINS := "res://data/chains.json"
const REWARD_RESOURCES := "res://data/reward_resources.json"
const PEOPLE := "res://data/people.json"
const STORY := "res://data/story.json"
const ALBUMS := "res://data/albums.json"
const AMBER := "res://data/amber_packs.json"
const BUILDS := "res://data/builds.json"
const LEVELS := "res://data/levels.json"
const STORE := "res://data/store.json"
const STORE_SHELL := "res://data/store_shell.json"
const PASS := "res://data/pass.json"
const BOARD := "res://data/board.json"
const RULES := "res://data/rules.json"
const DISHES := "res://data/dishes.json"
const RANDOM_ORDERS := "res://data/random_orders.json"
const UNLOCKS := "res://data/unlocks.json"
const DAILY_DEALS := "res://data/daily_deals.json"
const FILES := ["lines", "chains", "reward_resources", "people", "story", "albums", "amber_packs", "builds", "levels", "store", "store_shell", "pass", "board", "rules", "dishes", "random_orders", "unlocks", "daily_deals", "choice_chests", "card_packs", "special_chests", "seven_day", "duel_race", "tiger_escape", "fossil_dig", "merge_events", "ufo_offer", "offers", "gift_chain", "race", "replay_economy", "replay_build"]
static var revision := 0
static var last_errors := PackedStringArray()
static var _cache: Dictionary = {}

static func read(path: String) -> Variant:
	var value: Variant = shared(path)
	return value.duplicate(true) if value is Array or value is Dictionary else value

static func shared(path: String) -> Variant:
	if _cache.has(path): return _cache[path]
	var value: Variant = _parse(path)
	if value == null: return null
	_freeze(value)
	_cache[path] = value
	return value

static func _parse(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		last_errors = PackedStringArray(["%s: missing configuration" % path])
		return null
	var parser := JSON.new()
	var error := parser.parse(FileAccess.get_file_as_string(path))
	if error != OK:
		last_errors = PackedStringArray(["%s:%d: %s" % [path, parser.get_error_line(), parser.get_error_message()]])
		return null
	return ints(parser.data)

static func documents(overrides: Dictionary = {}, fresh := false) -> Dictionary:
	var docs := {}
	for name in FILES:
		var path := "res://data/%s.json" % name
		docs[name] = overrides[path] if overrides.has(path) else (_parse(path) if fresh else shared(path))
	return docs

static func validate(overrides: Dictionary = {}, fresh := false) -> bool:
	last_errors = Schema.validate(documents(overrides, fresh))
	return last_errors.is_empty()

static func refresh() -> bool:
	var docs := documents({}, true)
	last_errors = Schema.validate(docs)
	if not last_errors.is_empty(): return false
	var next := {}
	for name in FILES:
		var value: Variant = docs[name]
		_freeze(value)
		next["res://data/%s.json" % name] = value
	_cache = next
	revision += 1
	return true

static func invalidate() -> void:
	_cache = {}
	revision += 1

static func write(path: String, value: Variant) -> Error:
	return write_batch({path: value})

static func write_batch(changes: Dictionary) -> Error:
	if changes.is_empty(): return OK
	for path in changes:
		if not _registered_path(path):
			last_errors = PackedStringArray(["Unknown configuration: %s" % str(path)])
			return ERR_INVALID_PARAMETER
	if not validate(changes): return ERR_INVALID_DATA
	var snapshot := {}
	for path in changes:
		snapshot[path] = (JSON.stringify(changes[path], "\t") + "\n").to_utf8_buffer()
	return OK if restore_files(snapshot) else ERR_FILE_CANT_WRITE

## Capture exact bytes. A failed capture returns no partial snapshot.
static func capture_files(paths: Array) -> Dictionary:
	last_errors = PackedStringArray()
	var result := {}
	for path in paths:
		if not _registered_path(path):
			last_errors.append("Unknown configuration: %s" % str(path))
			return {}
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			last_errors.append("Cannot capture %s: %s" % [path, error_string(FileAccess.get_open_error())])
			return {}
		var length := file.get_length()
		var bytes := file.get_buffer(length)
		file.close()
		if bytes.size() != length:
			last_errors.append("Incomplete configuration capture: %s" % path)
			return {}
		result[path] = bytes
	return result

## Restore exact bytes without JSON reformatting. Stage every replacement and
## rollback copy before touching originals; a rejected commit restores the whole prefix.
static func restore_files(snapshot: Dictionary) -> bool:
	return _restore_files(snapshot, func(source: String, target: String) -> Error: return DirAccess.rename_absolute(source, target))

static func _restore_files(snapshot: Dictionary, replace: Callable) -> bool:
	last_errors = PackedStringArray()
	if snapshot.is_empty(): return true
	for path in snapshot:
		if not _registered_path(path) or not snapshot[path] is PackedByteArray:
			last_errors.append("Invalid configuration byte snapshot: %s" % str(path))
			return false
	var current := capture_files(snapshot.keys())
	if current.size() != snapshot.size(): return false
	var staged := {}
	var suffix := ".restore-%d" % Time.get_ticks_usec()
	for path in snapshot:
		var next_path := str(path) + suffix + ".new"
		var old_path := str(path) + suffix + ".old"
		staged[path] = {"next": next_path, "old": old_path}
		var error := _store_bytes(next_path, snapshot[path])
		if error == OK: error = _store_bytes(old_path, current[path])
		if error != OK:
			last_errors.append("Cannot stage configuration restore: %s (%s)" % [path, error_string(error)])
			_clean_restore(staged)
			return false
	var installed := []
	for path in snapshot:
		var error: int = replace.call(staged[path]["next"], path)
		if error != OK:
			last_errors.append("Cannot commit configuration restore: %s (%s)" % [path, error_string(error)])
			var retained := {}
			installed.reverse()
			for original in installed:
				var backup: String = staged[original]["old"]
				var rollback := DirAccess.rename_absolute(backup, original)
				if rollback != OK:
					retained[backup] = true
					last_errors.append("Configuration rollback retained at %s (%s)" % [backup, error_string(rollback)])
			_clean_restore(staged, retained)
			return false
		installed.append(path)
	_clean_restore(staged)
	invalidate()
	return true

static func _registered_path(path: Variant) -> bool:
	if not path is String: return false
	var name := str(path).get_file().trim_suffix(".json")
	return name in FILES and path == "res://data/%s.json" % name

static func _store_bytes(path: String, bytes: PackedByteArray) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_buffer(bytes)
	file.flush()
	var error := file.get_error()
	file.close()
	return error

static func _clean_restore(staged: Dictionary, retained: Dictionary = {}) -> void:
	for entry in staged.values():
		for temporary in entry.values():
			if not retained.has(temporary): DirAccess.remove_absolute(temporary)

static func ints(value: Variant) -> Variant:
	if value is float: return int(value) if value == floor(value) else value
	if value is Array:
		var result := []
		for entry in value: result.append(ints(entry))
		return result
	if value is Dictionary:
		var result := {}
		for key in value: result[key] = ints(value[key])
		return result
	return value

static func _freeze(value: Variant) -> void:
	if value is Array:
		for entry in value: _freeze(entry)
		value.make_read_only()
	elif value is Dictionary:
		for key in value: _freeze(value[key])
		value.make_read_only()
