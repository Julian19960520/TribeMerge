extends SceneTree
## 截图：区域地图、新手救济奖励、配方详情（不碰真实存档）。
## Godot --path . --script tools/ui_redesign_shot.gd -- --replay-test --cloud-off --out=DIR
var _started := false
var out := "."
var main
func _process(_d: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false
func _shot(n: String) -> void:
	await create_timer(0.8).timeout
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out + "/ui_" + n + ".png")
	print("shot ", n)
func _run() -> void:
	var g = root.get_node("G")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
	g.new_game()
	g.tutorial_on = false
	g.seen_tutorial = true
	g.level = 7
	g.builds["fire"] = 3
	g.builds["gather"] = 1
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout
	main.show_screen("home", true)
	await create_timer(1.0).timeout
	main.open("map")
	await _shot("map")
	main.close_all()
	main.open("onboarding_rescue")
	await _shot("rescue")
	main.close_all()
	main.show_screen("board", true)
	await create_timer(1.0).timeout
	var key := ""
	for k in Data.DISHES:
		if (Data.DISHES[k]["mats"] as Array).size() >= 2:
			key = str(k)
			break
	main.open("recipe", key)
	await _shot("recipe")
	main.close_all()
	main.open("howto")
	await _shot("howto")
	main.close_all()
	# 选中一个能换体力的高级物品：丢弃键变成换体力
	for i in g.board.size():
		if int(g.board[i]["lock"]) == 0:
			g.board[i]["id"] = "fruit_6"
			g.board_changed.emit()
			await create_timer(0.3).timeout
			main.board_screen.board.select(i)
			break
	await _shot("sell")
	g.energy = 0
	main.open("energy")
	await _shot("energy_free")
	print("DONE")
	quit(0)
