class_name CardArtwork
extends RefCounted
## Collection illustrations stay square and are loaded only when a card is shown.
const TextureCache := preload("res://scripts/resources/TextureCache.gd")
## Presentation updates must not change replay rules or reset existing saves.
const PRESENTATIONS := {
	1: "res://assets/cards/hunting/album.json",
	2: "res://assets/cards/cooking/album.json",
	3: "res://assets/cards/cave/album.json",
	5: "res://assets/cards/fishing/album.json",
	7: "res://assets/cards/discovery/album.json",
	8: "res://assets/cards/chief/album.json",
}
static var _cache = TextureCache.new(64 * 1024 * 1024)
static var _presentations: Dictionary = {}
static var _covers: Array = []

static func cover_path(album: int) -> String:
	if album < 0 or album >= Data.ALBUMS.size(): return ""
	if _covers.is_empty():
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/cards/covers/album.json"))
		if not value is Array or value.size() != Data.ALBUMS.size():
			push_error("Each collection requires its own cover illustration")
			return ""
		_covers = value
	return str(_covers[album])

static func cover(album: int) -> Texture2D:
	var path := cover_path(album)
	return _cache.fetch(path) if path != "" else null

static func _album(album: int) -> Dictionary:
	if album < 0 or album >= Data.ALBUMS.size(): return {}
	if not PRESENTATIONS.has(album): return Data.ALBUMS[album]
	if not _presentations.has(album):
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(PRESENTATIONS[album]))
		var valid := value is Dictionary
		if valid:
			valid = value.get("name", "") is String and not str(value.get("name", "")).is_empty()
		if valid:
			for field in ["cards", "texts", "art"]:
				var entries: Variant = value.get(field, [])
				if not entries is Array or entries.size() != Data.ALBUMS[album]["cards"].size():
					valid = false
					break
				for entry in entries:
					if not entry is String or entry.is_empty() or (field == "art" and not entry.begins_with("res://assets/cards/")):
						valid = false
						break
		if not valid:
			push_error("Invalid collection presentation: " + str(PRESENTATIONS[album]))
		_presentations[album] = value if valid else Data.ALBUMS[album]
	return _presentations[album]

static func title(album: int) -> String:
	return str(_album(album).get("name", ""))

static func card_name(album: int, index: int) -> String:
	var names: Array = _album(album).get("cards", [])
	return str(names[index]) if index >= 0 and index < names.size() else ""

static func art_path(album: int, index: int) -> String:
	var paths: Array = _album(album).get("art", [])
	return str(paths[index]) if index >= 0 and index < paths.size() else ""

static func texture(album: int, index: int) -> Texture2D:
	var path := art_path(album, index)
	return _cache.fetch(path) if path != "" else null

static func caption(album: int, index: int) -> String:
	var texts: Array = _album(album).get("texts", [])
	return str(texts[index]) if index >= 0 and index < texts.size() else ""

