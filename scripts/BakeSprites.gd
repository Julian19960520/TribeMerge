extends Node2D
## 把 scripts/sprites/*.gd 里登记的界面图逐帧画成 PNG，写出 assets/sprites/{目录文件名}.json。
## 只在生成图片时运行（「生成物品图.bat」），游戏里不会用到。
##
## 目录文件写法：每个文件一个 `static func entries() -> Array`，每项是：
##   key    唯一名字，建议带区域前缀，如 "btn_green"、"board_vine"、"tribe_totem"
##   w, h   内容尺寸（像素）。运行时 Sprites.draw 的 rect 就对应这块
##   pad    四周额外留白，给阴影、描边、抖动用，默认 12
##   nine   [左, 上, 右, 下] 九宫格边宽（内容坐标），可省略；有它就能拉成任意尺寸
##   static true 表示不抖动，只画 1 帧
##   draw   Callable(ci: CanvasItem, r: Rect2)，r 是内容区域，画法和原来的现场绘制一样
## 只生成一部分：--only=前缀或目录文件名,…（如 --only=board 只画 scripts/sprites/board.gd 里的；其余已有的图保留）
## 清单按目录文件分开写：assets/sprites/{目录文件名}.json

const DIR := "res://assets/sprites"
const CATALOG := "res://scripts/sprites"

var _entry := {}
var _phase := 0

func _draw() -> void:
	if _entry.is_empty():
		return
	var prev := Art.boil
	Art.boil = _phase
	var pad := float(_entry.get("pad", 12))
	(_entry["draw"] as Callable).call(self, Rect2(pad, pad, float(_entry["w"]), float(_entry["h"])))
	Art.boil = prev

static func catalog() -> Array:
	var out: Array = []
	var d := DirAccess.open(CATALOG)
	if d == null:
		return out
	var files := d.get_files()
	files.sort()
	for f in files:
		if not f.ends_with(".gd"):
			continue
		var script = load(CATALOG.path_join(f))
		if script == null or not script.has_method("entries"):
			continue
		for e in script.entries():
			e["_file"] = f
			out.append(e)
	return out

func start(host: Node, frames: int) -> void:
	var only: PackedStringArray = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.trim_prefix("--only=").split(",", false)
	var entries := catalog()
	var keys := {}
	for e in entries:
		if keys.has(e["key"]):
			push_error("界面图 key 重复：%s（%s 和 %s）" % [e["key"], keys[e["key"]], e["_file"]])
		keys[e["key"]] = e["_file"]
	var todo: Array = []
	for e in entries:
		if only.is_empty():
			todo.append(e)
			continue
		for p in only:
			if str(e["key"]).begins_with(p) or str(e["_file"]).get_basename() == p:
				todo.append(e)
				break

	var dir := ProjectSettings.globalize_path(DIR.path_join("png"))
	DirAccess.make_dir_recursive_absolute(dir)
	if only.is_empty():
		_empty_dir(dir)
	# 每个目录文件一份清单（assets/sprites/{文件名}.json），几处同时生成也不会互相覆盖
	var manifests := {}
	for e in todo:
		var stem: String = str(e["_file"]).get_basename()
		if manifests.has(stem):
			continue
		var m := {}
		var mp := DIR.path_join(stem + ".json")
		if not only.is_empty() and FileAccess.file_exists(mp):
			var old = JSON.parse_string(FileAccess.get_file_as_string(mp))
			if typeof(old) == TYPE_DICTIONARY:
				m = old.get("sprites", {})
		manifests[stem] = m

	var vp := SubViewport.new()
	vp.disable_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(vp)
	vp.add_child(self)
	var label := Label.new()
	label.position = Vector2(40, 860)
	label.size = Vector2(640, 120)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color("fff1c4"))
	host.add_child(label)

	var n := 0
	for e in todo:
		n += 1
		var pad := int(e.get("pad", 12))
		var nf := 1 if bool(e.get("static", false)) else frames
		vp.size = Vector2i(int(e["w"]) + pad * 2, int(e["h"]) + pad * 2)
		var ok := true
		for f in nf:
			_entry = e
			_phase = f
			queue_redraw()
			label.text = "界面图 %s  第 %d/%d 帧\n%d / %d" % [e["key"], f + 1, nf, n, todo.size()]
			await host.get_tree().process_frame
			await RenderingServer.frame_post_draw
			var img := _unpremultiply(vp.get_texture().get_image())
			var path := dir.path_join("%s_%d.png" % [e["key"], f])
			if img == null or img.get_width() == 0 or img.save_png(path) != OK:
				push_error("写图片失败 " + path)
				ok = false
		if ok:
			var m := {"w": int(e["w"]), "h": int(e["h"]), "pad": pad, "frames": nf}
			if e.has("nine"):
				m["nine"] = e["nine"]
			manifests[str(e["_file"]).get_basename()][e["key"]] = m
	_entry = {}
	for stem in manifests:
		var sprites: Dictionary = manifests[stem]
		# 目录里已经删掉的登记，清单里也去掉
		for k in sprites.keys():
			if not keys.has(k):
				sprites.erase(k)
		var out := FileAccess.open(ProjectSettings.globalize_path(DIR.path_join(stem + ".json")), FileAccess.WRITE)
		out.store_string(JSON.stringify({"sprites": sprites}, "	", true))
		out.close()
	print("BAKED %d sprites" % todo.size())
	label.queue_free()
	vp.queue_free()

## 透明底的视口里，半透明颜色存下来是「预乘」过的（白色 18% 会变成灰）。还原成普通透明度再存。
static func _unpremultiply(img: Image) -> Image:
	if img == null:
		return img
	img.convert(Image.FORMAT_RGBA8)
	var data := img.get_data()
	for i in range(0, data.size(), 4):
		var a := data[i + 3]
		if a == 0 or a == 255:
			continue
		var k := 255.0 / float(a)
		data[i] = mini(int(data[i] * k + 0.5), 255)
		data[i + 1] = mini(int(data[i + 1] * k + 0.5), 255)
		data[i + 2] = mini(int(data[i + 2] * k + 0.5), 255)
	return Image.create_from_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, data)

static func _empty_dir(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for name in d.get_files():
		if name.ends_with(".png") or name.ends_with(".import"):
			d.remove(name)
