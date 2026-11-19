@tool
class_name TextCatalog
extends RefCounted
## Copy is addressed by catalogue key. zh_CN is the Chinese text.
## Other locales are applied only at presentation.
const PATH := "res://localization/texts.json"
const ROOT := "res://localization/"
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
static var _slots: RegEx

static func _load() -> void:
	if not _document.is_empty(): return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not parsed is Dictionary:
		push_error("Invalid text catalogue: " + PATH)
		return
	if parsed.has("files"):
		var entries := {}
		for relative in parsed["files"]:
			var part_path := ROOT + str(relative)
			var part: Variant = JSON.parse_string(FileAccess.get_file_as_string(part_path))
			if not part is Dictionary or not part.get("entries") is Dictionary:
				push_error("Invalid text catalogue: " + part_path)
				return
			var feature_name := str(part.get("feature", part_path.get_file().get_basename()))
			var prefix := part_path.get_base_dir().get_file() + "." + feature_name + "."
			for key in part["entries"]:
				var full := str(key)
				if not full.begins_with(prefix):
					full = prefix + full
				entries[full] = part["entries"][key]
		parsed["entries"] = entries
	elif not parsed.get("entries") is Dictionary:
		push_error("Invalid text catalogue: " + PATH)
		return
	_document = parsed
	for key in _document["entries"]:
		var canonical := _canonical(_document["entries"][key])
		if not canonical.is_empty():
			_sources[canonical] = key
	_slots = RegEx.new()
	_slots.compile("\\$\\{(\\d+)\\}")
	_rebuild()

static func document() -> Dictionary:
	_load()
	return _document

static func _canonical(entry: Dictionary) -> String:
	return str(entry.get("zh_CN", ""))

static func source(key: String) -> String:
	_load()
	var entry: Dictionary = _document.get("entries", {}).get(key, {})
	var value := _canonical(entry)
	return value if not value.is_empty() else key

static func text(key: String, arguments: Array = []) -> String:
	_load()
	var entry: Dictionary = _document.get("entries", {}).get(key, {})
	var result := _translation(entry) if not entry.is_empty() else key
	if not arguments.is_empty():
		var values := []
		for argument in arguments:
			values.append(resolve(argument) if argument is String else argument)
		result = fill(result, values)
	if result != _canonical(entry):
		if _rendered.size() >= CACHE_LIMIT: _rendered.clear()
		_rendered[result] = true
	return result

static func fill(template: String, arguments = null) -> String:
	_load()
	if arguments == null:
		return template
	var values: Array = arguments if arguments is Array else [arguments]
	var output := ""
	var offset := 0
	for slot in _slots.search_all(template):
		output += template.substr(offset, slot.get_start() - offset)
		var index := int(slot.get_string(1))
		output += str(values[index]) if index >= 0 and index < values.size() else slot.get_string()
		offset = slot.get_end()
	return output + template.substr(offset)

static func _translation(entry: Dictionary) -> String:
	var value := str(entry.get(_locale, ""))
	if value.is_empty(): value = _canonical(entry)
	return value

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
		var canonical := _canonical(entry)
		if canonical.is_empty(): continue
		var translated := _translation(entry)
		if canonical == translated: continue
		_changed = true
		var slots := _slots.search_all(canonical)
		if not slots.is_empty():
			var pattern := "^"
			var offset := 0
			var groups := {}
			var group := 1
			for slot in slots:
				pattern += _escape(canonical.substr(offset, slot.get_start() - offset))
				var index := slot.get_string(1)
				pattern += "([\\s\\S]*?)"
				if not groups.has(index):
					groups[index] = group
				group += 1
				offset = slot.get_end()
			pattern += _escape(canonical.substr(offset)) + "$"
			var regex := RegEx.new()
			if regex.compile(pattern) == OK:
				_templates.append({"key": key, "regex": regex, "groups": groups, "prefix": canonical.substr(0, slots[0].get_start()), "length": canonical.length()})
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
			for slot in _slots.search_all(translated):
				output += translated.substr(offset, slot.get_start() - offset)
				var index := slot.get_string(1)
				if template["groups"].has(index):
					output += _resolve(match.get_string(int(template["groups"][index])), depth + 1)
				else:
					output += slot.get_string()
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
