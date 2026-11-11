extends SceneTree
## 主棋盘截图：石头/地板、底部提示、合成泡泡、皇冠、图鉴成品页（不碰真实存档）。
## Godot --path . --script tools/board_shot.gd -- --save=user://board_shot/s.json --cloud-off --rank-state=user://board_shot/r.json --cloud-state=user://board_shot/c.json --hot-file=user://board_shot/h.json --out=DIR
const D := preload("res://scripts/Data.gd")
var _started := false
var out := "."
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
	root.get_viewport().get_texture().get_image().save_png(out + "/bs_" + n + ".png")
	print("shot ", n)
func _sel(i: int, n: String) -> void:
	main.board_screen.board.select(i)
	await create_timer(0.35).timeout
	await _shot(n)
func _run() -> void:
	g = root.get_node("G")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
	g.new_game()
	g.tutorial_on = false
	g.seen_tutorial = true
	g.level = 13
	g.amber = 120
	var cells := {
		0: "basket_6", 1: "fruit_5", 2: "fruit_5", 3: "shell_3", 4: "shell_6", 5: "anvil_5", 6: "chest_1",
		7: "seed_3", 8: "amber_6", 9: "sand_2", 10: "fire_6", 11: "loom_2", 12: "pack_1", 13: "fruit_9",
		14: "tool_7", 15: "cloth_4", 16: "fire_3",
	}
	for i in g.board.size():
		g.board[i] = {"id": "", "lock": 2} if i >= 28 else {"id": "", "lock": 0}
		if cells.has(i): g.board[i]["id"] = cells[i]
	g.board[20] = {"id": "gem_3", "lock": 1}
	g.board[21] = {"id": "fruit_8", "lock": 3, "bubble": {"uid": "shot", "item": "fruit_8", "expires": g.now() + 47, "price": D.bubble_price("fruit_8")}}
	for k in [30, 37, 44]: g.board[k]["id"] = "fruit_2"
	for k in g.board.size():
		if int(g.board[k]["lock"]) != 2 and str(g.board[k]["id"]) != "": g.rules.board.discover(str(g.board[k]["id"]))
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout
	main.show_screen("board")
	await create_timer(2.0).timeout
	await _shot("board")
	var names := {0: "gen", 1: "merge", 3: "collect", 4: "max", 11: "lowgen", 12: "pack", 20: "vine", 21: "bubble", 35: "rock", 6: "chest", 13: "high"}
	for i in names:
		await _sel(int(i), str(names[i]))
	main.board_screen.board.select(-1)
	await create_timer(0.3).timeout
	await _shot("idle")
	g.discovered["salad"] = true
	g.discovered["berrybowl"] = true
	g.book_claimed["salad"] = true
	var p = main.open("book", D.LINES.size())
	await create_timer(1.0).timeout
	await _shot("book_dish")
	if p != null: p.close()
	await create_timer(0.3).timeout
	p = main.open("book", 0)
	await create_timer(1.0).timeout
	await _shot("book_food")
	print("DONE")
	quit(0)
