extends RefCounted
## One owner for lazy textures. Rendering commands retain their own references;
## this LRU bounds additional textures retained between screens and animations.

var budget_bytes: int
var resident_bytes := 0
var loads := 0
var hits := 0
var evictions := 0
var _clock := 0
var _entries: Dictionary = {}

func _init(budget := 64 * 1024 * 1024) -> void:
	budget_bytes = maxi(1, budget)

func fetch(path: String) -> Texture2D:
	_clock += 1
	if _entries.has(path):
		_entries[path]["used"] = _clock
		hits += 1
		return _entries[path]["texture"]
	var texture := load_texture(path)
	if texture == null:
		return null
	loads += 1
	# Four bytes per pixel is a conservative budget for these RGBA UI assets.
	# Do not call get_image(): imported textures should stay in renderer format.
	var cost := texture.get_width() * texture.get_height() * 4
	if cost > budget_bytes:
		return texture
	while resident_bytes + cost > budget_bytes and not _entries.is_empty():
		var oldest := ""
		var oldest_use := _clock + 1
		for key in _entries:
			if int(_entries[key]["used"]) < oldest_use:
				oldest = str(key)
				oldest_use = int(_entries[key]["used"])
		resident_bytes -= int(_entries[oldest]["bytes"])
		_entries.erase(oldest)
		evictions += 1
	_entries[path] = {"texture": texture, "bytes": cost, "used": _clock}
	resident_bytes += cost
	return texture

func clear() -> void:
	_entries.clear()
	resident_bytes = 0

func stats() -> Dictionary:
	return {"textures": _entries.size(), "resident_bytes": resident_bytes,
		"budget_bytes": budget_bytes, "loads": loads, "hits": hits, "evictions": evictions}

static func load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		# The bounded cache owns residency, rather than the global resource cache.
		var resource := ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE)
		if resource is Texture2D:
			return resource
	# Baking tools intentionally produce raw PNGs before an editor import.
	if FileAccess.file_exists(path):
		var image := Image.new()
		if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) == OK and not image.is_empty():
			return ImageTexture.create_from_image(image)
	return null
