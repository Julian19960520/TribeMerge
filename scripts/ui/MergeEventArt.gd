class_name MergeEventArt
extends RefCounted
## Activity and special-item presentation is independent of deterministic rules.

const TextureCache := preload("res://scripts/resources/TextureCache.gd")
const VisualRuntime := preload("res://scripts/resources/VisualRuntime.gd")
static var _cache = TextureCache.new(16 * 1024 * 1024)

static func texture(path: String) -> Texture2D:
	if not VisualRuntime.enabled(): return null
	return _cache.fetch(path)

static func draw_item(ci: CanvasItem, cfg: Dictionary, id: String, center: Vector2, size: float, tint := Color.WHITE) -> void:
	for row in cfg.get("chain", []):
		if str(row["id"]) != id: continue
		var image := texture(str(row["icon"]))
		if image != null:
			ci.draw_texture_rect(image, Rect2(center - Vector2.ONE * size / 2, Vector2.ONE * size), false, tint)
		return

static func cache_stats() -> Dictionary:
	return _cache.stats()
