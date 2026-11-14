extends Node
## 只重画宝箱（合盖 + 开盖）的 PNG，不清空其它物品图。改 Art.gd 里宝箱画法后用：
## Godot.exe --path . res://tools/bake_chests_quick.tscn
## 加 -- --open-only 只画开盖帧，-- --id=chest_3_open 只画这一个。参数沿用 assets/items/anim.json（px / bake_size / frames / amplitude）。

class Painter extends Node2D:
	var item_id := ""
	var rim := true
	var phase := 0
	var amp := 1.0
	var px := 256.0
	var size := 143.36
	func _draw() -> void:
		var pb := Art.boil
		var pw := Art.wobble
		Art.boil = phase
		Art.wobble = amp
		Art.draw_item(self, item_id, Vector2(px, px) * 0.5, size, rim)
		Art.boil = pb
		Art.wobble = pw

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var open_only := "--open-only" in OS.get_cmdline_user_args()
	var only_id := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--id="): only_id = a.trim_prefix("--id=")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/items/anim.json"))
	var side := int(manifest["px"])
	var vp := SubViewport.new()
	vp.disable_3d = true
	vp.transparent_bg = true
	vp.size = Vector2i(side, side)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var p := Painter.new()
	p.px = side
	p.size = float(manifest["bake_size"])
	p.amp = float(manifest["amplitude"])
	vp.add_child(p)
	var ids: Array = []
	for ch in Data.CHAINS:
		if str(Data.CHAINS[ch]["type"]) != "chest": continue
		for i in Data.CHAINS[ch]["items"].size():
			if not open_only: ids.append("%s_%d" % [ch, i + 1])
			ids.append("%s_%d_open" % [ch, i + 1])
	var dir := ProjectSettings.globalize_path("res://assets/items/png")
	var n := 0
	var added: Array = []
	if only_id != "": ids = ids.filter(func(x): return x == only_id)
	for id in ids:
		for r in [0, 1]:
			for f in int(manifest["frames"]):
				p.item_id = id
				p.rim = r == 1
				p.phase = f
				p.queue_redraw()
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				vp.get_texture().get_image().save_png(dir.path_join("%s_r%d_%d.png" % [id, r, f]))
				n += 1
		if not (id in manifest["ids"]): added.append(id)
	if not added.is_empty():
		# 只在有新 id 时改清单，按文本追加，保持原文件格式
		var text := FileAccess.get_file_as_string("res://assets/items/anim.json")
		var tail := ""
		for id in added: tail += ",\n\t\t\"%s\"" % id
		var at := text.find("\n\t],")
		var out := FileAccess.open("res://assets/items/anim.json", FileAccess.WRITE)
		out.store_string(text.substr(0, at) + tail + text.substr(at))
		out.close()
	print("BAKED %d chest frames" % n)
	get_tree().quit()
