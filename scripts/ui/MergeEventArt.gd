class_name MergeEventArt
extends RefCounted
## Activity and special-item presentation is independent of deterministic rules.

const TextureCache := preload("res://scripts/resources/TextureCache.gd")
const VisualRuntime := preload("res://scripts/resources/VisualRuntime.gd")
static var _cache = TextureCache.new(16 * 1024 * 1024)

static func texture(path: String) -> Texture2D:
	if not VisualRuntime.enabled(): return null
	return _cache.fetch(path)

## 活动格子里的物品：灯光 / 壁画 / 颜料按配置图标画；画笔按当前等级换图；
## 其余是奖励物品，借用主棋盘的物品图，箱子类外面包一层气泡。
static func draw_item(ci: CanvasItem, cfg: Dictionary, id: String, center: Vector2, size: float, tint := Color.WHITE, t := 0.0) -> void:
	if id == "": return
	var icon := _icon(cfg, id)
	if icon != "":
		var image := texture(icon)
		if image != null:
			TextureCache.hold(ci, image)
			ci.draw_texture_rect(image, Rect2(center - Vector2.ONE * size / 2, Vector2.ONE * size), false, tint)
		return
	if MergeEvent.kind(cfg, id) != "reward": return
	if MergeEvent.is_bubble(cfg, id): draw_bubble(ci, id, center, size, t, tint.a)
	else: Art.item(ci, id, center, size * 0.86)

static func _icon(cfg: Dictionary, id: String) -> String:
	for row in cfg.get("chain", []) + cfg.get("mural", []) + cfg.get("shards", []) + cfg.get("paints", []):
		if str(row["id"]) == id: return str(row.get("icon", ""))
	if cfg.has("brush") and id == str(cfg["brush"]["id"]):
		return str(MergeEvent.brush_level(cfg, MergeEvent.state(cfg)).get("icon", ""))
	return ""

## 箱子奖励的气泡：轻轻晃动的透明泡泡，点一下收进主棋盘暂存区。
static func draw_bubble(ci: CanvasItem, id: String, center: Vector2, size: float, t: float, alpha := 1.0) -> void:
	var ph := t * 2.6 + center.x * 0.013
	var radius := size * 0.44
	var wob := Vector2(1.0 + 0.035 * sin(ph), 1.0 - 0.035 * sin(ph))
	var c := center + Vector2(0, sin(ph * 0.5) * 1.5)
	ci.draw_set_transform(c, 0.0, wob)
	ci.draw_circle(Vector2.ZERO, radius, Color(1.0, 0.86, 0.6, 0.26 * alpha))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	Art.item(ci, id, c + Vector2(0, 2), size * 0.66, false)
	ci.draw_set_transform(c, 0.0, wob)
	ci.draw_arc(Vector2.ZERO, radius - 4.0, PI * 0.15, PI * 0.85, 18, Color(1.0, 0.78, 0.45, 0.55 * alpha), 4.0, true)
	ci.draw_arc(Vector2.ZERO, radius, 0, TAU, 48, Color(1.0, 0.93, 0.78, 0.9 * alpha), 3.0, true)
	ci.draw_arc(Vector2.ZERO, radius - 7.0, PI * 1.08, PI * 1.42, 12, Color(1, 1, 1, 0.92 * alpha), 4.0, true)
	ci.draw_circle(Vector2(-radius * 0.3, -radius * 0.74), 3.0, Color(1, 1, 1, 0.95 * alpha))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func cache_stats() -> Dictionary:
	return _cache.stats()
