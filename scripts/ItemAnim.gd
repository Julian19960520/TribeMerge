extends Node
## 预先绘制的物品序列帧。运行时只贴图，不实时绘制。

var frames := 4
var amplitude := 1.0
var frame_sec := 0.125
var tex_px := 256
var bake_size := 160.0
var _frame := 0
var _tex := {}
var _missing := {}

func _ready() -> void:
	if OS.get_cmdline_user_args().has("--bake-items"):
		return
	var path := "res://assets/items/anim.json"
	if not FileAccess.file_exists(path):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		return
	frames = maxi(int(data.get("frames", 4)), 1)
	amplitude = float(data.get("amplitude", 1.0))
	frame_sec = maxf(float(data.get("frame_sec", 0.125)), 0.016)
	tex_px = maxi(int(data.get("px", 256)), 32)
	bake_size = maxf(float(data.get("bake_size", 160.0)), 1.0)
	var ids: Array = data.get("ids", [])
	for id in ids:
		var pair := {}
		for rim_i in [0, 1]:
			var arr: Array[Texture2D] = []
			var ok := true
			for i in frames:
				var file := "res://assets/items/png/%s_r%d_%d.png" % [id, rim_i, i]
				var img := Image.new()
				var error := img.load_png_from_buffer(FileAccess.get_file_as_bytes(file))
				if error != OK or img.is_empty():
					ok = false
					break
				arr.append(ImageTexture.create_from_image(img))
			if ok:
				pair[rim_i] = arr
		if not pair.is_empty():
			_tex[str(id)] = pair
	if not _tex.is_empty():
		G.boil_tick.connect(_on_boil)

func _on_boil() -> void:
	_frame = (_frame + 1) % frames

func blit(ci: CanvasItem, id: String, c: Vector2, size: float, rim: bool, rot: float) -> bool:
	var key := 1 if rim else 0
	if not _tex.has(id) or not (_tex[id] as Dictionary).has(key):
		if not _missing.has(id):
			_missing[id] = true
			push_warning("物品 %s 没有预绘制图片，请运行「生成物品图.bat」。" % id)
		return false
	var rims: Dictionary = _tex[id]
	var arr: Array = rims[key]
	var tex: Texture2D = arr[_frame % arr.size()]
	var show := float(tex_px) * (size / bake_size)
	ci.draw_set_transform(c, rot, Vector2.ONE)
	ci.draw_texture_rect(tex, Rect2(-show * 0.5, -show * 0.5, show, show), false)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true
