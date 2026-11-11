extends SceneTree
## 制作 / 沙漏自检：菜谱只用当级能拿到的材料、制作时长递增、同时几张制作单、附送沙漏、沙漏加速、合成掉沙漏。顺带截图到 _shots/craft。
## Godot --path . --script tools/check_craft.gd -- --cloud-off --save=user://craft_test/s.json --cloud-state=user://craft_test/c.json --rank-state=user://craft_test/r.json --hot-file=user://craft_test/h.json [--out=DIR]
var failures := 0
var out := "res://_shots/craft"
var g
var main

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures += 1

func _shot(n: String) -> void:
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(dir)
	root.get_viewport().get_texture().get_image().save_png(dir + "/craft_" + n + ".png")
	print("shot ", dir + "/craft_" + n + ".png")

func _crafts() -> Array:
	var a: Array = []
	for o in g.orders:
		if str(o.get("kind", "")) == "craft":
			a.append(o)
	return a

func run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	g = root.get_node("G")
	check(not root.get_node("Cloud").enabled, "isolated test transport")

	# ---- 菜谱
	var ids: Array = Data.DISHES.keys()
	check(ids.size() >= 20, "%d recipes" % ids.size())
	var mats_ok := true
	var prev_secs := 0
	var prev_unlock := 0
	var order_ok := true
	for id in ids:
		var d: Dictionary = Data.DISHES[id]
		var u := int(d["unlock"])
		for m in d["mats"]:
			if not Data.product_open(u, Data.chain(str(m))):
				mats_ok = false
				print("  locked mat ", id, " ", m)
		if u < prev_unlock or int(d["secs"]) < prev_secs:
			order_ok = false
		prev_unlock = u
		prev_secs = int(d["secs"])
		check(Data.dishes_for(u).has(d) and not Data.dishes_for(u - 1).has(d), "%s %s opens at Lv.%d, %s, sand %s" % [id, Data.name_of(id), u, g.fmt_time(int(d["secs"])), Data.craft_sand(id)])
	check(mats_ok, "every recipe uses only materials open at its unlock level")
	check(order_ok, "recipes sorted by unlock with non-decreasing cook time")
	check(int(Data.DISHES[ids[0]]["secs"]) <= 90 and int(Data.DISHES[ids[ids.size() - 1]]["secs"]) >= 3600, "cook time ~1 min early, hours late")

	# ---- 制作单数量、附送沙漏
	g.new_game()
	g.tutorial_on = false
	g.seen_tutorial = true
	g.simulation_time = 1793577600.0
	check(Data.craft_cap(2) == 0 and Data.craft_cap(3) == 1 and Data.craft_cap(15) == 1 and Data.craft_cap(16) == 2, "craft orders: 1 from Lv.3, 2 from Lv.16")
	g.level = 3
	g.orders = []
	g.pending_orders = []
	for si in 99:
		g.story_done["3:%d" % si] = true
	g.rules.orders.refill_orders()
	check(_crafts().size() == 1, "Lv.3 has one craft order")
	var c0: Dictionary = _crafts()[0] if not _crafts().is_empty() else {}
	check(str(c0.get("dish", "")) == "salad" and (c0.get("rw", {}).get("rewards", []) as Array) == ["sand_2"], "first craft is the undiscovered salad, rewards sand_2: %s" % [c0.get("rw", {})])
	g.level = 22
	g.orders = []
	g.pending_orders = []
	for si in 99:
		g.story_done["22:%d" % si] = true
	g.rules.orders.refill_orders()
	var cs := _crafts()
	check(cs.size() == 2 and str(cs[0]["dish"]) != str(cs[1]["dish"]), "Lv.22 has two different craft orders (%d)" % cs.size())

	# ---- 沙漏加速：每份 rush_sec 秒，一次用到做完
	var rs := Data.rush_sec()
	check(rs == 60, "one hourglass = %d s" % rs)
	g.board[10] = {"id": "", "lock": 0, "ck": {"dish": "grill", "t0": g.now(), "secs": 3000, "uid": "x", "mats": []}}
	g.rush = 20
	var used: int = g.rush_cook(10)
	check(used == 20 and g.rush == 0 and absi(g.rules.orders.cook_left(10) - (3000 - 20 * rs)) <= 1, "partial rush uses all 20 (left %d s)" % g.rules.orders.cook_left(10))
	g.rush = 100
	var need: int = g.rules.orders.rush_need(10)
	used = g.rush_cook(10)
	check(used == need and g.rush == 100 - need and not g.rules.orders.cooking(10) and str(g.board[10]["id"]) == "grill", "rush finishes with %d hourglasses, %d kept" % [need, g.rush])

	# ---- 合成掉沙漏
	check(Data.merge_sand_item("fruit_3", 2) == "" and Data.merge_sand_item("fruit_3", 3) == "sand_1" and Data.merge_sand_item("fruit_8", 9) == "sand_2" and Data.merge_sand_item("basket_3", 9) == "", "merge sand tiers / level gate / items only")

	# ---- 截图：图鉴成品页（全部发现）、棋盘上制作单与计时
	for id in ids:
		g.discovered[id] = true
		g.book_claimed[id] = true
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout
	main.open("book", Data.LINES.size())
	await _shot("book")
	var art: Variant = load("res://scripts/Art.gd")
	var grid := Control.new()
	grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid.draw.connect(func():
		grid.draw_rect(Rect2(Vector2.ZERO, Vector2(720, 1480)), Color("f3e3c2"))
		for k in ids.size():
			var c := Vector2(90 + (k % 4) * 180, 110 + (k / 4) * 196)
			art.item(grid, str(ids[k]), c, 150)
			grid.draw_string(g.font_title, c + Vector2(-80, 96), Data.name_of(str(ids[k])), HORIZONTAL_ALIGNMENT_CENTER, 160, 22, Color("6b4a2a")))
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	layer.add_child(grid)
	await _shot("all_dishes")
	layer.queue_free()
	await create_timer(0.3).timeout
	for p in main.find_children("*", "PopupBase", true, false):
		p.queue_free()
	g.level = 22
	g.orders = []
	for i in g.board.size():
		if int(g.board[i]["lock"]) == 0:
			g.board[i] = {"id": "", "lock": 0}
	g.rules.orders.refill_orders()
	cs = _crafts()
	var mats: Array = cs[0]["mats"]
	for k in mats.size():
		g.board[30 + k] = {"id": str(mats[k]), "lock": 0}
	g.board[40] = {"id": "", "lock": 0, "ck": {"dish": "feast", "t0": g.now() - 600.0, "secs": 4500, "uid": "y", "mats": []}}
	g.board[44] = {"id": "sand_4", "lock": 0}
	g.rush = 12
	main.show_screen("board", true)
	await create_timer(1.0).timeout
	for p in main.find_children("*", "PopupBase", true, false):
		p.queue_free()
	await create_timer(0.3).timeout
	g.board_changed.emit()
	g.orders_changed.emit()
	main.board_screen.board.select(40)
	await _shot("board_cooking")
	main.board_screen.board.select(44)
	await _shot("board_sand")
	print("RESULT ", "OK" if failures == 0 else "FAILED %d" % failures)
	quit(1 if failures > 0 else 0)
