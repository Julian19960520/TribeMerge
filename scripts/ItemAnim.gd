extends Node
## Item frames are decoded when drawn, with a bounded cache shared across pages.

const TextureCache := preload("res://scripts/resources/TextureCache.gd")
const VisualRuntime := preload("res://scripts/resources/VisualRuntime.gd")
const CACHE_BYTES := 64 * 1024 * 1024
var frames := 4
var amplitude := 1.0
var frame_sec := 0.125
var tex_px := 256
var bake_size := 160.0
var _ids: Dictionary = {}
var _cache = TextureCache.new(CACHE_BYTES)
var _missing: Dictionary = {}
var _enabled := false

func _ready() -> void:
	_enabled = VisualRuntime.enabled() and not "--bake-items" in OS.get_cmdline_user_args()
	if not _enabled:
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/items/anim.json"))
	if not data is Dictionary:
		return
	frames = maxi(int(data.get("frames", 4)), 1)
	amplitude = float(data.get("amplitude", 1.0))
	frame_sec = maxf(float(data.get("frame_sec", 0.125)), 0.016)
	tex_px = maxi(int(data.get("px", 256)), 32)
	bake_size = maxf(float(data.get("bake_size", 160.0)), 1.0)
	for id in data.get("ids", []):
		_ids[str(id)] = true

func has_animation(id: String) -> bool:
	return _ids.has(id)

func frame_texture(id: String, rim: bool, frame: int) -> Texture2D:
	if not _enabled or not _ids.has(id):
		return null
	var path := "res://assets/items/png/%s_r%d_%d.png" % [id, 1 if rim else 0, posmod(frame, frames)]
	var texture: Texture2D = _cache.fetch(path)
	if texture == null and not _missing.has(id):
		_missing[id] = true
		push_warning("物品 %s 没有预绘制图片，请运行「生成物品图.bat」。" % id)
	return texture

func cache_stats() -> Dictionary:
	return _cache.stats()

func blit(ci: CanvasItem, id: String, c: Vector2, size: float, rim: bool, rot: float) -> bool:
	var texture := frame_texture(id, rim, Art.boil)
	if texture == null:
		return false
	var show := float(tex_px) * (size / bake_size)
	ci.draw_set_transform(c, rot, Vector2.ONE)
	ci.draw_texture_rect(texture, Rect2(-show * 0.5, -show * 0.5, show, show), false)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true
