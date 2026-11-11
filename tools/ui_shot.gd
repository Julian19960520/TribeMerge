extends SceneTree
## 界面截图：化石挖掘、典藏卡册、棋盘活动栏等（不碰真实存档）。
## Godot --path . --script tools/ui_shot.gd -- --save=user://ui_shot/s.json --cloud-off --rank-state=user://ui_shot/r.json --cloud-state=user://ui_shot/c.json --hot-file=user://ui_shot/h.json --out=DIR [--only=fossil,album]
var out := "."
var only: Array = []
var g
var main

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
		if a.begins_with("--only="): only = a.trim_prefix("--only=").split(",")
	_run.call_deferred()

func _want(n: String) -> bool:
	return only.is_empty() or n in only

func _shot(n: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out + "/ui_" + n + ".png")
	print("shot ", n)

func _close_popups() -> void:
	for c in main.popup_layer.get_children(): c.queue_free()
	await process_frame

func _run() -> void:
	g = root.get_node("G")
	g.new_game()
	g.tutorial_on = false
	g.seen_tutorial = true
	g.level = 30
	g.amber = 120
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout
	main.show_screen("board")
	await create_timer(1.5).timeout
	if _want("board"):
		await _shot("board")
	if _want("fossil"):
		var fossil = load("res://scripts/events/FossilDig.gd")
		main.open("fossil")
		await create_timer(1.0).timeout
		await _shot("fossil_empty")
		await _close_popups()
		for i in 4: fossil.on_order({})
		var popup = main.open("fossil")
		await create_timer(0.6).timeout
		var b: Dictionary = fossil.board()
		var p0: Dictionary = b["pieces"][0]
		for cell in fossil.piece_cells(p0, int(b["n"])):
			popup.cells.get_child(int(cell)).pressed.emit()
			await process_frame
		await create_timer(1.4).timeout
		await _shot("fossil_dig")
		await _close_popups()
		# 后面的关卡：骨头多、格子小，有半挖开的骨头
		var big: Dictionary = fossil.make_board(str(g.fossil_dig["seed"]), 6)
		var dug: Array = []
		for k in big["pieces"].size():
			var cs: Array = fossil.piece_cells(big["pieces"][k], int(big["n"]))
			if k % 3 == 0:
				big["pieces"][k]["found"] = true
				dug.append_array(cs)
			elif k % 3 == 1:
				dug.append_array(cs.slice(0, maxi(1, cs.size() / 2)))
		big["dug"] = dug
		g.fossil_dig["stage"] = 6
		g.fossil_dig["recovered"] = 12
		g.fossil_dig["claimed"] = [2]
		g.fossil_dig["board"] = big
		main.open("fossil")
		await create_timer(1.0).timeout
		await _shot("fossil_late")
		await _close_popups()
	if _want("album"):
		for key in ["0_0", "0_3", "0_5", "0_8", "1_2"]: g.cards[key] = 1
		g.cards["0_3"] = 2
		main.open("event")
		await create_timer(1.0).timeout
		await _shot("album_book")
		await _close_popups()
		main.open("album", 0)
		await create_timer(1.0).timeout
		await _shot("album_page")
		await _close_popups()
		main.open("card", {"album": 0, "index": 0})
		await create_timer(1.0).timeout
		await _shot("album_card")
		await _close_popups()
	if _want("shop"):
		main.open("daily_ad")
		await create_timer(1.0).timeout
		await _shot("daily_ad")
		await _close_popups()
		main.open("store")
		await create_timer(1.0).timeout
		await _shot("store")
		await _close_popups()
	if _want("home"):
		main.show_screen("home")
		await create_timer(1.0).timeout
		var spree = main.find_child("spree_card", true, false)
		if spree != null:
			spree.visible = true
			spree.get_parent().set_process(false)
		await create_timer(0.3).timeout
		await _shot("home")
		main.show_screen("board")
		await create_timer(0.6).timeout
	if _want("orders"):
		main.board_screen._orders.jump_to(330)
		await create_timer(0.6).timeout
		await _shot("orders")
	quit()
