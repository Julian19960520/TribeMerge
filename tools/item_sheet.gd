extends Node
## 把一条物品链的各级画成总览图，改物品画法时看效果用。不碰存档和物品图。
## Godot.exe --path . res://tools/item_sheet.tscn -- --out=C:/path/sheet.png --chain=tool [--cols=8] [--cell=160]
## --measure 时透明底、关掉发光闪光，给量尺寸用
## 每格下半截再画一个小号的（接近棋盘上的大小），看缩小后还认不认得出

class Painter extends Node2D:
	var chain := "tool"
	var n := 16
	var cols := 8
	var cell := 160.0
	var clear := false
	func _draw() -> void:
		var rows := int(ceil(float(n) / float(cols)))
		if not clear: draw_rect(Rect2(Vector2.ZERO, Vector2(cell * cols, cell * rows * 1.5)), Color("efe6d2"))
		for i in n:
			var o := Vector2(cell * float(i % cols), cell * 1.5 * float(i / cols))
			if not clear: draw_rect(Rect2(o + Vector2(4, 4), Vector2(cell - 8, cell - 8)), Color("e4d7bb"))
			ProdArt.draw_chain(self, chain, i + 1, o + Vector2(cell, cell) * 0.5, cell * 0.8, true)
			if not clear: draw_rect(Rect2(o + Vector2(cell * 0.3, cell + 4), Vector2(cell * 0.4, cell * 0.4)), Color("e4d7bb"))
			ProdArt.draw_chain(self, chain, i + 1, o + Vector2(cell * 0.5, cell * 1.2 + 4), cell * 0.22, true)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var out := "user://item_sheet.png"
	var p := Painter.new()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
		if a.begins_with("--chain="): p.chain = a.trim_prefix("--chain=")
		if a.begins_with("--cols="): p.cols = int(a.trim_prefix("--cols="))
		if a.begins_with("--cell="): p.cell = float(a.trim_prefix("--cell="))
	for c in JSON.parse_string(FileAccess.get_file_as_string("res://data/chains.json")):
		if c["id"] == p.chain:
			p.n = c["items"].size()
	## --measure：透明底、不画发光和闪光，量每级实际大小用
	p.clear = "--measure" in OS.get_cmdline_user_args()
	PA.glow_off = p.clear
	var rows := int(ceil(float(p.n) / float(p.cols)))
	var vp := SubViewport.new()
	vp.disable_3d = true
	vp.size = Vector2i(int(p.cell * p.cols), int(p.cell * 1.5 * rows))
	vp.transparent_bg = p.clear
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	vp.add_child(p)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out)
	print("saved ", out)
	get_tree().quit()
