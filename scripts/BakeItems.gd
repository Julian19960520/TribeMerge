extends Node2D
## 用原始绘制代码把每种物品的每一帧画成 PNG，并写出动画配置。

var item_id := ""
var rim := true
var px := 256.0
var bake_size := 160.0
var amp := 1.0
var phase := 0

func _draw() -> void:
	var prev_w := Art.wobble
	var prev_b := Art.boil
	Art.wobble = amp
	Art.boil = phase
	Art.force_live = true
	Art.item(self, item_id, Vector2(px, px) * 0.5, bake_size, rim)
	Art.force_live = false
	Art.wobble = prev_w
	Art.boil = prev_b

func start(host: Node) -> void:
	await host.get_tree().process_frame
	var cfg := _cfg()
	var nframes: int = cfg["frames"]
	var amplitude: float = cfg["amplitude"]
	var frame_sec: float = cfg["frame_sec"]
	var side: int = cfg["px"]
	var fitted := float(side) * 0.56
	px = float(side)
	bake_size = fitted
	amp = amplitude
	var ids := _ids()
	var dir := ProjectSettings.globalize_path("res://assets/items/png")
	_empty_dir(dir)
	DirAccess.make_dir_recursive_absolute(dir)

	var vp := SubViewport.new()
	vp.disable_3d = true
	vp.transparent_bg = true
	vp.size = Vector2i(side, side)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(vp)
	vp.add_child(self)
	await host.get_tree().process_frame
	await RenderingServer.frame_post_draw

	var panel := ColorRect.new()
	panel.color = Color(0.16, 0.09, 0.05)
	panel.size = host.size
	host.add_child(panel)
	var label := Label.new()
	label.position = Vector2(40, 680)
	label.size = Vector2(640, 120)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color("fff1c4"))
	host.add_child(label)

	var total := ids.size() * 2 * nframes
	var done := 0
	var ok_ids: Array[String] = []
	for id in ids:
		var id_ok := true
		for rim_i in [1, 0]:
			for frame in nframes:
				item_id = id
				rim = rim_i == 1
				phase = frame
				queue_redraw()
				label.text = "绘制 %s  第 %d/%d 帧\n%d / %d" % [id, frame + 1, nframes, done + 1, total]
				await host.get_tree().process_frame
				await RenderingServer.frame_post_draw
				var img := vp.get_texture().get_image()
				var path := dir.path_join("%s_r%d_%d.png" % [id, rim_i, frame])
				if img == null or img.get_width() == 0 or img.save_png(path) != OK:
					push_error("写图片失败 " + path)
					id_ok = false
				done += 1
		if id_ok:
			ok_ids.append(id)
	var anim := {
		"frames": nframes,
		"amplitude": amplitude,
		"frame_sec": frame_sec,
		"px": side,
		"bake_size": fitted,
		"pattern": "png/{id}_r{rim}_{frame}.png",
		"ids": ok_ids,
	}
	var out := FileAccess.open(ProjectSettings.globalize_path("res://assets/items/anim.json"), FileAccess.WRITE)
	out.store_string(JSON.stringify(anim, "\t"))
	out.close()
	print("BAKED %d items, %d frames, amplitude %.2f" % [ok_ids.size(), nframes, amplitude])
	host.get_tree().quit()

static func _cfg() -> Dictionary:
	var path := "res://assets/items/bake.json"
	var defaults := {
		"说明": "改完后双击「生成物品图.bat」。frames 是帧数，amplitude 是线条抖动幅度（1 为原始强度），frame_sec 是每帧停留的秒数，px 是图片边长。",
		"frames": 4,
		"amplitude": 1.0,
		"frame_sec": 0.125,
		"px": 256,
	}
	if not FileAccess.file_exists(path):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/items"))
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(JSON.stringify(defaults, "\t"))
		f.close()
		return _clamp_cfg(defaults)
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		return _clamp_cfg(defaults)
	for k in defaults:
		if not data.has(k):
			data[k] = defaults[k]
	return _clamp_cfg(data)

static func _clamp_cfg(data: Dictionary) -> Dictionary:
	data["frames"] = clampi(int(data["frames"]), 1, 16)
	data["amplitude"] = clampf(float(data["amplitude"]), 0.0, 8.0)
	data["frame_sec"] = clampf(float(data["frame_sec"]), 0.016, 1.0)
	data["px"] = clampi(int(data["px"]), 128, 512)
	return data

static func _ids() -> Array[String]:
	var out: Array[String] = []
	for ch in Data.CHAINS:
		for i in Data.CHAINS[ch]["items"].size():
			out.append("%s_%d" % [ch, i + 1])
	return out

static func _empty_dir(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	var d := DirAccess.open(dir)
	if d == null:
		return
	for name in d.get_files():
		if name.ends_with(".png") or name.ends_with(".import"):
			d.remove(name)
