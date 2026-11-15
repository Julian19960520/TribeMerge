class_name MoonArt
extends RefCounted
## Offline-baked event art (moon ruins, cave murals...). Never creates a viewport or rasterizes geometry in gameplay.
## 每期活动在 theme.baked 指定自己的烘焙目录，默认月石遗迹。
enum { FLOOR, FLOOR_ALT, RECESS, SLAB, FRONTIER, LOCK }
const VARIANTS := 16
const TILE_SIZE := 128
const TILE_PAD := 16
const PANEL_PAD := 8
const NAMES := ["tiles", "scene", "frame", "corners", "track", "shelf", "card", "earn", "earn_glow", "spawn_on", "spawn_off"]
const DEFAULT_DIR := "res://assets/events/moon/baked"
static var _textures: Dictionary = {}
static var _dir := DEFAULT_DIR

static func texture(key: String) -> Texture2D:
	if not _textures.has(key):
		_textures[key] = load("%s/%s.png" % [_dir, key])
	return _textures[key]

static func warm(cfg: Dictionary = {}) -> void:
	var dir := str(cfg.get("theme", {}).get("baked", DEFAULT_DIR))
	if dir != _dir:
		_dir = dir
		_textures.clear()
	for key in NAMES: texture(key)

static func tile(ci: CanvasItem, rect: Rect2, seed: int, layer: int, alpha := 1.0) -> void:
	var variant := posmod(seed, VARIANTS)
	var source := Rect2(Vector2(variant % 4, layer * 4 + variant / 4) * TILE_SIZE, Vector2.ONE * TILE_SIZE)
	ci.draw_texture_rect_region(texture("tiles"), rect.grow(rect.size.x * TILE_PAD / 96.0), source, Color(1, 1, 1, alpha))

static func panel(ci: CanvasItem, key: String, sz: Vector2, tint := Color.WHITE) -> void:
	var tex := texture(key)
	var scale := sz / (tex.get_size() - Vector2.ONE * PANEL_PAD * 2)
	ci.draw_texture_rect(tex, Rect2(-Vector2.ONE * PANEL_PAD * scale, sz + Vector2.ONE * PANEL_PAD * 2 * scale), false, tint)
