extends RefCounted
## Spoken presentation only; dialogue edits must not change gameplay/save identity.
const CONFIG := "res://assets/characters/hero_voice.json"
static var _lines: Dictionary = {}

static func lines() -> Dictionary:
	if _lines.is_empty():
		var value: Variant = TextCatalog.hydrate(JSON.parse_string(FileAccess.get_file_as_string(CONFIG)))
		if value is Dictionary and value.get("onboarding") is Dictionary and value.get("tips") is Dictionary:
			_lines = value
		else:
			push_error("Invalid hero dialogue presentation")
	return _lines

static func text(group: String, key: String, fallback: String) -> String:
	var value: Variant = lines().get(group, {}).get(key, fallback)
	return str(value) if value is String and not value.is_empty() else fallback
