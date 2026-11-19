extends SceneTree
## 合成泡泡购买小卡截图（不碰真实存档）。
## Godot --path . --script tools/bubble_shot.gd -- --save=user://bb_shot/s.json --cloud-off --rank-state=user://bb_shot/r.json --cloud-state=user://bb_shot/c.json --hot-file=user://bb_shot/h.json --out=DIR [--cell=N]
var out := "."
var cell := 30
func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
		if a.begins_with("--cell="): cell = int(a.trim_prefix("--cell="))
	_run.call_deferred()
func _run() -> void:
	var g = root.get_node("G")
	g.new_game(); g.tutorial_on = false; g.seen_tutorial = true; g.level = 12
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout
	main.show_screen("board")
	await create_timer(1.0).timeout
	for c in main.popup_layer.get_children(): c.queue_free()
	var now: float = g.rules.board.context.now()
	g.board[cell] = {"id": "seed_3", "lock": 3, "bubble": {"price": 10, "uid": "shot", "expires": now + 46}}
	main.board_screen.board.select(cell)
	main.board_screen._on_select(cell)
	await create_timer(0.6).timeout
	await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(out + "/bubble_full_%d.png" % cell)
	print("shot")
	quit()
