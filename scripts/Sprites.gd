extends Node
## 预生成的界面贴图（面板、按钮、棋盘零件、村庄部件、小人……）。运行时只贴图，绝不现场绘制。
## 图从 scripts/sprites/*.gd 的目录登记、由「生成物品图.bat」画出来，放在 assets/sprites/png/{key}_{帧}.png。
## 没有图就什么都不画，输出面板提示一次。
##
## 三种用法：
##   Sprites.draw(ci, key, rect)          把图铺到 rect；登记了 nine 就九宫格拉伸，否则整张拉伸
##   Sprites.at(ci, key, center, scale)   按原尺寸（乘 scale）画在中心点，可旋转
##   Sprites.has(key)                     有没有这张图

const DIR := "res://assets/sprites"

## key -> {w, h, pad, nine: [l, t, r, b] 或空, frames}
var _meta := {}
## key -> Array[Texture2D]，第一次用到才读
var _tex := {}
var _missing := {}

func _ready() -> void:
	reload()

func reload() -> void:
	_meta.clear()
	_tex.clear()
	_missing.clear()
	var d := DirAccess.open(DIR)
	if d == null:
		return
	for f in d.get_files():
		if not f.ends_with(".json"):
			continue
		var data = JSON.parse_string(FileAccess.get_file_as_string(DIR.path_join(f)))
		if typeof(data) != TYPE_DICTIONARY:
			continue
		var sprites: Dictionary = data.get("sprites", {})
		for key in sprites:
			_meta[str(key)] = sprites[key]

func has(key: String) -> bool:
	return not _frames(key).is_empty()

## 登记时的内容尺寸（不含 pad）。没有这张图返回 Vector2.ZERO。
func size_of(key: String) -> Vector2:
	if not _meta.has(key):
		return Vector2.ZERO
	var m: Dictionary = _meta[key]
	return Vector2(float(m.get("w", 0)), float(m.get("h", 0)))

## 把图铺进 rect（rect 是内容区域，阴影、描边这些外扩的 pad 会自动算上）。
func draw(ci: CanvasItem, key: String, r: Rect2, mod: Color = Color.WHITE) -> void:
	var tex := _current(key)
	if tex == null:
		return
	var m: Dictionary = _meta[key]
	var pad := float(m.get("pad", 0))
	var nine = m.get("nine", null)
	if not (nine is Array and nine.size() == 4):
		# 整张拉伸：留白跟着一起缩放
		var k := r.size / Vector2(maxf(float(m.get("w", 1)), 1.0), maxf(float(m.get("h", 1)), 1.0))
		ci.draw_texture_rect(tex, Rect2(r.position - k * pad, r.size + k * pad * 2.0), false, mod)
		return
	var dst := r.grow(pad)
	var w := float(tex.get_width())
	var h := float(tex.get_height())
	var tl := Vector2(float(nine[0]) + pad, float(nine[1]) + pad)
	var br := Vector2(float(nine[2]) + pad, float(nine[3]) + pad)
	# 目标比九宫格边还小时，按比例缩边，避免角互相穿插
	var k := minf(1.0, minf(dst.size.x / maxf(tl.x + br.x, 1.0), dst.size.y / maxf(tl.y + br.y, 1.0)))
	RenderingServer.canvas_item_add_nine_patch(ci.get_canvas_item(), dst, Rect2(0, 0, w, h), tex.get_rid(),
		tl * k, br * k, RenderingServer.NINE_PATCH_STRETCH, RenderingServer.NINE_PATCH_STRETCH, true, mod)

## 以 c 为中心按登记尺寸 × s 画，可旋转。
func at(ci: CanvasItem, key: String, c: Vector2, s: float = 1.0, rot: float = 0.0, mod: Color = Color.WHITE) -> void:
	var tex := _current(key)
	if tex == null:
		return
	var m: Dictionary = _meta[key]
	var pad := float(m.get("pad", 0))
	var full := Vector2(float(m.get("w", 0)) + pad * 2.0, float(m.get("h", 0)) + pad * 2.0) * s
	if rot == 0.0:
		ci.draw_texture_rect(tex, Rect2(c - full * 0.5, full), false, mod)
		return
	ci.draw_set_transform(c, rot, Vector2.ONE)
	ci.draw_texture_rect(tex, Rect2(-full * 0.5, full), false, mod)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _current(key: String) -> Texture2D:
	var arr := _frames(key)
	if arr.is_empty():
		return null
	return arr[Art.boil % arr.size()]

func _frames(key: String) -> Array:
	if _tex.has(key):
		return _tex[key]
	var arr: Array = []
	if _meta.has(key):
		var n := maxi(int(_meta[key].get("frames", 1)), 1)
		for i in n:
			var t := _load("%s/png/%s_%d.png" % [DIR, key, i])
			if t == null:
				arr.clear()
				break
			arr.append(t)
	if arr.is_empty() and not _missing.has(key):
		_missing[key] = true
		push_warning("界面图 %s 还没生成，请运行「生成物品图.bat」。" % key)
	_tex[key] = arr
	return arr

static func _load(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var t = load(path)
		if t is Texture2D:
			return t
	# 刚生成、编辑器还没导入时直接读文件
	if FileAccess.file_exists(path):
		var img := Image.new()
		if img.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) == OK and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return null
