extends Node
## 把 7 条产线的生产器 1~10 级画成一张总览图，看新画法用。不碰存档和物品图。
## Godot.exe --path . res://tools/gen_sheet.tscn -- --out=C:/path/sheet.png [--lines=food,wood] [--cell=160] [--lv=4]
## --measure：透明底、不套每级缩放（PAGen.raw），给 tools/gen_sizes.py 量每级原始大小用

const LINES := ["food", "wood", "tool", "hunt", "cloth", "fish", "pot"]

class Painter extends Node2D:
	var lines: Array = []
	var cell := 160.0
	var only_lv := 0
	var clear := false
	## 物品画多大（占格子边长的比例）；量尺寸时画小一点，宽的图不会被格子裁掉
	var size_k := 0.56
	func _draw() -> void:
		if not clear: draw_rect(Rect2(Vector2.ZERO, Vector2(cell * 10.0, cell * lines.size())), Color("efe6d2"))
		for r in lines.size():
			for lv in range(1, 11):
				if only_lv > 0 and lv != only_lv:
					continue
				var o := Vector2(cell * float(lv - 1), cell * float(r))
				if not clear: draw_rect(Rect2(o + Vector2(4, 4), Vector2(cell - 8, cell - 8)), Color("e4d7bb"))
				ProdArt.draw(self, str(lines[r]), "G", lv, o + Vector2(cell, cell) * 0.5, cell * size_k, true)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var out := "user://gen_sheet.png"
	var lines: Array = LINES.duplicate()
	var cell := 160.0
	var only := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
		if a.begins_with("--lines="): lines = Array(a.trim_prefix("--lines=").split(","))
		if a.begins_with("--cell="): cell = float(a.trim_prefix("--cell="))
		if a.begins_with("--lv="): only = int(a.trim_prefix("--lv="))
	var measure := "--measure" in OS.get_cmdline_user_args()
	PAGen.raw = measure
	var vp := SubViewport.new()
	vp.disable_3d = true
	vp.size = Vector2i(int(cell * 10.0), int(cell * lines.size()))
	vp.transparent_bg = measure
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var p := Painter.new()
	p.lines = lines
	p.cell = cell
	p.only_lv = only
	p.clear = measure
	if measure: p.size_k = 0.36
	vp.add_child(p)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out)
	print("saved ", out)
	get_tree().quit()
