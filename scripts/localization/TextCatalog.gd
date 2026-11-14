@tool
class_name TextCatalog
extends RefCounted
## One editable copy source. Gameplay always consumes canonical source strings;
## translation happens only at presentation boundaries, never inside saved state.
const PATH := "res://localization/texts.json"
const CACHE_LIMIT := 1024
static var _document: Dictionary = {}
static var _sources: Dictionary = {}
static var _locale := "zh_CN"
static var _cache: Dictionary = {}
static var _rendered: Dictionary = {}
static var _templates: Array = []
static var _fragments: RegEx
static var _replacements: Dictionary = {}
static var _changed := false
static var _printf: RegEx

static func _load() -> void:
	if not _document.is_empty(): return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not parsed is Dictionary or not parsed.get("entries") is Dictionary:
		push_error("Invalid text catalogue: " + PATH)
		return
	_document = parsed
	for key in _document["entries"]:
		_sources[str(_document["entries"][key]["source"])] = key
	_printf = RegEx.new()
	_printf.compile("%(?:[-+ #0]*[0-9]*(?:\\.[0-9]+)?[sdifoxXc]|%)")
	_rebuild()

static func source(key: String) -> String:
	_load()
	return str(_document.get("entries", {}).get(key, {}).get("source", key))

static func text(key: String, arguments: Array = []) -> String:
	_load()
	var entry: Dictionary = _document.get("entries", {}).get(key, {})
	var result := _translation(entry) if not entry.is_empty() else key
	if not arguments.is_empty():
		var values := []
		for argument in arguments:
			values.append(resolve(argument) if argument is String else argument)
		result = result % values
	if result != str(entry.get("source", key)):
		if _rendered.size() >= CACHE_LIMIT: _rendered.clear()
		_rendered[result] = true
	return result

static func _translation(entry: Dictionary) -> String:
	var value := str(entry.get(_locale, ""))
	if value.is_empty(): value = str(entry.get("zh_CN", ""))
	return str(entry.get("source", "")) if value.is_empty() else value

static func locale() -> String:
	return _locale

static func set_locale(value: String) -> void:
	_load()
	if value == _locale: return
	_locale = value
	_rebuild()

static func reload() -> void:
	_document = {}
	_sources = {}
	_load()

static func _rebuild() -> void:
	_cache.clear()
	_rendered.clear()
	_templates.clear()
	_replacements.clear()
	_fragments = null
	_changed = false
	var fragments := []
	for key in _document.get("entries", {}):
		var entry: Dictionary = _document["entries"][key]
		var canonical := str(entry["source"])
		var translated := _translation(entry)
		if canonical == translated: continue
		_changed = true
		var slots := _printf.search_all(canonical)
		if slots.any(func(slot): return slot.get_string() != "%%"):
			var pattern := "^"
			var offset := 0
			for slot in slots:
				pattern += _escape(canonical.substr(offset, slot.get_start() - offset))
				var kind := slot.get_string().right(1)
				pattern += "%" if kind == "%" else ("(-?[0-9]+)" if kind in ["d", "i", "o", "x", "X"] else ("(-?[0-9.]+)" if kind == "f" else "([\\s\\S]*?)"))
				offset = slot.get_end()
			pattern += _escape(canonical.substr(offset)) + "$"
			var regex := RegEx.new()
			if regex.compile(pattern) == OK:
				_templates.append({"key": key, "regex": regex, "prefix": canonical.substr(0, slots[0].get_start()), "length": canonical.length()})
		else:
			_replacements[canonical] = translated
			fragments.append(canonical)
	_templates.sort_custom(func(a, b): return a["length"] > b["length"])
	fragments.sort_custom(func(a, b): return a.length() > b.length())
	if not fragments.is_empty():
		var patterns := PackedStringArray()
		for fragment in fragments: patterns.append(_escape(fragment))
		_fragments = RegEx.new()
		_fragments.compile("|".join(patterns))

static func _escape(value: String) -> String:
	var escaped := ""
	for character in value:
		if character in "\\.^$|?*+()[]{}": escaped += "\\"
		escaped += character
	return escaped

## Accepts exact keys, canonical copy, and existing formatted/concatenated copy.
## The compatibility path lets domain messages retain stable save/replay values.
static func resolve(value: String) -> String:
	_load()
	if value.begins_with("§") and value.ends_with("§"):
		return text(value.substr(1, value.length() - 2))
	if not _changed or value.is_empty(): return value
	if _cache.has(value): return _cache[value]
	if _rendered.has(value): return value
	var result := _resolve(value, 0)
	if _cache.size() >= CACHE_LIMIT: _cache.clear()
	_cache[value] = result
	if result != value:
		if _rendered.size() >= CACHE_LIMIT: _rendered.clear()
		_rendered[result] = true
	return result

static func _resolve(value: String, depth: int) -> String:
	if _sources.has(value): return text(_sources[value])
	if depth < 4:
		for template in _templates:
			if not value.begins_with(template["prefix"]): continue
			var match: RegExMatch = template["regex"].search(value)
			if match == null: continue
			var translated := text(template["key"])
			var output := ""
			var offset := 0
			var group := 1
			for slot in _printf.search_all(translated):
				output += translated.substr(offset, slot.get_start() - offset)
				if slot.get_string() == "%%": output += "%"
				else:
					output += _resolve(match.get_string(group), depth + 1)
					group += 1
				offset = slot.get_end()
			return output + translated.substr(offset)
	if _fragments == null: return value
	var output := ""
	var offset := 0
	for match in _fragments.search_all(value):
		output += value.substr(offset, match.get_start() - offset) + str(_replacements[match.get_string()])
		offset = match.get_end()
	return output + value.substr(offset)

## Resolve config references to canonical values before schema validation.
static func hydrate(value: Variant) -> Variant:
	if value is String:
		return source(value.substr(1, value.length() - 2)) if value.begins_with("§") and value.ends_with("§") else value
	if value is Array:
		var array := []
		for entry in value: array.append(hydrate(entry))
		return array
	if value is Dictionary:
		var dictionary := {}
		for key in value: dictionary[key] = hydrate(value[key])
		return dictionary
	return value

## Keep config-editor saves in reference form; identifiers and numbers pass through.
static func references(value: Variant) -> Variant:
	_load()
	if value is String: return "§" + str(_sources[value]) + "§" if _sources.has(value) else value
	if value is Array:
		var array := []
		for entry in value: array.append(references(entry))
		return array
	if value is Dictionary:
		var dictionary := {}
		for key in value: dictionary[key] = references(value[key])
		return dictionary
	return value
