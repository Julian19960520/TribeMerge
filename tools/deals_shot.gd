extends SceneTree
## 外星补给 / 集市每日特惠 / 储物洞 / 自选宝箱 截图（不碰真实存档）。
## Godot --path . --script tools/deals_shot.gd -- --save=user://deal_shot/s.json --cloud-off --rank-state=user://deal_shot/r.json --cloud-state=user://deal_shot/c.json --hot-file=user://deal_shot/h.json --out=DIR [--only=ufo,store,...]
var _started := false
var out := "."
var only := []
func _process(_d: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false
func _shot(n: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(out + "/deal_" + n + ".png")
	print("shot ", n)
func _want(n: String) -> bool:
	return only.is_empty() or only.has(n)
func _run() -> void:
	var g := root.get_node("G")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
		if a.begins_with("--only="): only = a.trim_prefix("--only=").split(",")
	g.tutorial_on = false
	g.seen_tutorial = true
	g.level = 13
	g.gm_activities = true
	g.amber = 260
	g.shells = 420
	g.pass_tier = 1
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout
	main.show_screen("board")
	await create_timer(1.0).timeout
	var ufo = load("res://scripts/events/UfoOffer.gd")
	# 订单缺 3 件 → 飞碟礼包
	g.orders = [{"who": 2, "rw": {"shell": 40}, "story": false, "items": ["fruit_6", "tool_5"]}, {"who": 3, "rw": {"shell": 25}, "story": false, "items": ["cloth_5"]}]
	g.ufo_offer = {"next_at": g.now() + 9999, "offer": {"id": "shot", "items": ufo.candidate(), "expires_at": g.now() + 154, "paid": false}, "deliveries": {}}
	main.board_screen.queue_redraw()
	if _want("entry"):
		await create_timer(2.2).timeout
		_shot("ufo_entry")
		await create_timer(3.0).timeout
		_shot("ufo_entry_b")
	if _want("ufo"):
		var p = main.open("ufo")
		await create_timer(1.2).timeout
		_shot("ufo")
		g.ufo_offer["offer"]["expires_at"] = g.now() - 1
		await create_timer(2.0).timeout
		_shot("ufo_gone")
		p.close()
		await create_timer(0.4).timeout
	if _want("ad"):
		var p = main.open("daily_ad")
		await create_timer(2.2).timeout
		_shot("ad_wait")
		await create_timer(4.0).timeout
		_shot("ad_done")
		p.close()
		await create_timer(0.4).timeout
	if _want("store"):
		var p = main.open("store")
		await create_timer(1.2).timeout
		var sc = _find_scroller(p)
		for k in 4:
			if sc != null: sc.jump_to(k * 620.0)
			await create_timer(0.6).timeout
			_shot("store_%d" % k)
		p.close()
		await create_timer(0.4).timeout
	if _want("inventory"):
		g.inv_cap = 13
		g.inv = ["fruit_4", "tool_3", "cloth_5", "gem_2", "fire_4", "beast_3", "pot_3", "seed_2"]
		var p = main.open("inventory")
		await create_timer(1.2).timeout
		_shot("inventory")
		g.inv_cap = 42
		for k in 30: g.inv.append(["fruit_3", "tool_4", "furn_2", "bird_2"][k % 4])
		g.changed.emit()
		p.scroll.jump_to(400.0)
		await create_timer(0.8).timeout
		_shot("inventory_long")
		p.close()
		await create_timer(0.4).timeout
	if _want("chest"):
		g.board[g.idx(3, 4)]["id"] = "choice_1"
		g.board[g.idx(3, 4)]["lock"] = 0
		g.board_changed.emit()
		await create_timer(0.5).timeout
		var p = main.open("choice_chest", g.idx(3, 4))
		await create_timer(1.2).timeout
		_shot("chest")
		p._choose(1)
		await create_timer(0.6).timeout
		_shot("chest_pick")
		p.close()
		await create_timer(0.4).timeout
		g.board[g.idx(2, 4)]["id"] = "energybox_1"
		g.board[g.idx(2, 4)]["lock"] = 0
		g.board_changed.emit()
		await create_timer(0.8).timeout
		_shot("chest_board")
	print("DONE")
	quit(0)
func _find_scroller(n: Node) -> Node:
	for c in n.get_children():
		if c.has_method("jump_to") and c.has_method("set_length"): return c
		var r = _find_scroller(c)
		if r != null: return r
	return null
