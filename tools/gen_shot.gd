extends SceneTree
## 在真实棋盘上摆满 7 条产线的生产器截图（每行一条线），再截两页图鉴，看新 10 级生产器在游戏里的样子。不碰真实存档。
## Godot --path . --script tools/gen_shot.gd -- --save=user://gen_shot/s.json --cloud-off --rank-state=user://gen_shot/r.json --cloud-state=user://gen_shot/c.json --hot-file=user://gen_shot/h.json --out=DIR [--from=4]
const D := preload("res://scripts/Data.gd")
var _started := false
var out := "."
var from := 4
var g
var main
func _process(_d: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false
func _shot(n: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out + "/gs_" + n + ".png")
	print("shot ", n)
func _run() -> void:
	g = root.get_node("G")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
		if a.begins_with("--from="): from = int(a.trim_prefix("--from="))
	g.new_game()
	g.tutorial_on = false
	g.seen_tutorial = true
	g.level = 50
	var gens := ["basket", "carve", "anvil", "trap", "loom", "weir", "kiln"]
	var cols := 7
	for i in g.board.size():
		g.board[i] = {"id": "", "lock": 0}
	for r in gens.size():
		for c in cols:
			var lv := from + c
			var i := r * cols + c
			if lv <= 10 and i < g.board.size():
				g.board[i]["id"] = "%s_%d" % [gens[r], lv]
	for k in g.board.size():
		if str(g.board[k]["id"]) != "": g.rules.board.discover(str(g.board[k]["id"]))
	for gen in gens:
		for lv in range(1, 11): g.rules.board.discover("%s_%d" % [gen, lv])
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout
	main.show_screen("board")
	await create_timer(2.0).timeout
	await _shot("board_%d" % from)
	for idx in [0, 6]:
		var p = main.open("book", idx)
		await create_timer(1.0).timeout
		await _shot("book_%d" % idx)
		if p != null: p.close()
		await create_timer(0.3).timeout
	print("DONE")
	quit(0)
