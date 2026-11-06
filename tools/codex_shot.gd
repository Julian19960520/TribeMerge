extends SceneTree
## codex 改动的各界面截图（不碰真实存档）。
## Godot --path . --script tools/codex_shot.gd -- --save=user://codex_shot/s.json --cloud-off --rank-state=user://codex_shot/r.json --cloud-state=user://codex_shot/c.json --hot-file=user://codex_shot/h.json --out=DIR
var _started := false
var out := "."
func _process(_d: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false
func _shot(n: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(out + "/cx_" + n + ".png")
	print("shot ", n)
func _run() -> void:
	var g := root.get_node("G")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
	g.tutorial_on = false
	g.seen_tutorial = true
	g.level = 13
	g.gm_activities = true
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout
	_shot("home")
	main.show_screen("board")
	await create_timer(2.5).timeout
	_shot("board")
	# 选中一个格子看底部提示
	var bs = main.board_screen
	for i in 40:
		if str(g.cell_id(i)) != "":
			bs.board.select(i)
			break
	await create_timer(0.5).timeout
	_shot("board_select")
	bs.board.select(-1)
	for n in ["merge_event", "seven_day", "ufo", "daily_ad", "store", "inventory", "book"]:
		var p = main.open(n)
		await create_timer(1.2).timeout
		_shot("p_" + n)
		if p != null: p.close()
		await create_timer(0.4).timeout
	print("DONE")
	quit(0)
