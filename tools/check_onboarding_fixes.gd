extends SceneTree
## Reproduce the reported reward/recipe overlap, opening grid and misleading drops.
var failures := 0
var shots := ""
var g
var replay
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func shot(name: String) -> void:
	if shots == "": return
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(shots.path_join(name + ".png"))
func fresh() -> void:
	replay.executing = true
	replay.seq = 0; replay.base = 0; replay.pending = []; replay.inflight = {}
	replay.meta = {}; replay.clock = 1794240000
	g.random_seed = "onboarding-fixes"; g.random_streams = {}; g.new_game()
	replay.advance(); replay._canonicalize_live(); replay.executing = false
	g.clear_presentations()
func run() -> void:
	g = root.get_node("G"); replay = root.get_node("Replay")
	for node in root.get_children(): node.set_process(false)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots-dir="): shots = arg.trim_prefix("--shots-dir=")
	fresh()
	var free: Array = []; var visible_locked: Array = []
	for i in g.board.size():
		if int(g.board[i]["lock"]) == 0: free.append(i)
		if int(g.board[i]["lock"]) == 1: visible_locked.append(i)
	check(free == [23, 30] and visible_locked == [31], "参考图#3：仅第4/5行第3列可拖动，右边2级部件可见但锁定")
	var main = load("res://main.tscn").instantiate(); root.add_child(main)
	main.show_screen("board", true)
	replay.meta["onboarding"]["step"] = g.rules.onboarding.stage_index("merge1")
	main._guide._refresh()
	await shot("opening_merge1")
	var frames := [
		[23, 30, "basket_2", [29, 37], "merge2"],
		[30, 31, "basket_3", [24, 32, 38], "merge3"],
		[31, 32, "basket_4", [25, 33, 39], "first_order"]]
	for row in frames:
		var locks: Array = []
		for cell in g.board: locks.append(int(cell["lock"]))
		var result: Dictionary = replay.perform("drop", {"from": row[0], "to": row[1]}, replay.clock)
		var exposed: Array = []
		for i in g.board.size():
			if locks[i] == 2 and int(g.board[i]["lock"]) != 2: exposed.append(i)
		check(not result.has("error") and str(g.board[int(row[1])]["id"]) == str(row[2]) and exposed == row[3], "参考图合成落点与揭开顺序 " + str(row[0]) + "→" + str(row[1]) + " / " + str(exposed))
		main._guide._refresh()
		await shot(str(row[4]))
	check(float(main._guide._mat.get_shader_parameter("dim_a")) < 0.5, "强引导蒙层不透明度低于50%")
	main.popup_layer.clear()
	await process_frame
	await process_frame
	for i in g.board.size(): g.board[i] = {"id": "", "lock": 2}
	g.board[35] = {"id": "basket_1", "lock": 0}
	g.board[28] = {"id": "basket_1", "lock": 0}
	g.board[29] = {"id": "basket_2", "lock": 2}
	replay.meta["onboarding"]["step"] = g.rules.onboarding.stage_index("merge1")
	main._guide._refresh()
	check(main._guide.merge_hint() == Vector2i(35, 28), "旧版开局存档仍沿旧棋盘完成合成，不指向新版空格")
	await process_frame
	main.free(); g.main = null

	# The screenshot's exact condition: recipe_open at level three, but the
	# level-up reward was opened directly instead of via _rw_showing.
	fresh(); g.level = 3
	replay.meta["onboarding"]["step"] = g.rules.onboarding.stage_index("recipe_open")
	g.orders = [g.order_identity({"who": 0, "kind": "craft", "dish": "dish_salad", "mats": ["fruit_1"], "items": ["fruit_1"], "secs": 10, "phase": "need", "story": true, "onboarding": "craft1", "rw": {"shell": 2, "xp": 1}})]
	main = load("res://main.tscn").instantiate(); root.add_child(main)
	var reward = main.open("levelup")
	await process_frame
	main._guide._refresh()
	check(not main._rw_showing and not main.level_pending and not main._guide.visible and str(g.rules.onboarding.stage()["key"]) == "recipe_open", "升级奖励未领取时，配方手指和蒙层完全让开且步骤不跳过")
	await shot("level3_reward_unblocked")
	var tap := InputEventMouseButton.new(); tap.button_index = MOUSE_BUTTON_LEFT; tap.pressed = true
	reward._gui_input(tap)
	check(reward._closing, "升级奖励可以点击领取，不会被配方引导拦截")
	main._guide._refresh()
	check(not main._guide.visible, "奖励退场动画期间继续等待")
	await create_timer(0.35).timeout
	main.popup_layer.clear()
	await process_frame
	await process_frame
	main._guide._refresh()
	check(main._guide.visible and main._guide._step == "recipe_open", "奖励和开单提示关闭后恢复配方引导")
	await shot("recipe_after_reward")
	for entry in [["level_open", "build"], ["upgrade", "level"], ["recipe_open", "level"]]:
		replay.meta["onboarding"]["step"] = g.rules.onboarding.stage_index(str(entry[0]))
		var unrelated = main.open(str(entry[1]), "fire" if str(entry[1]) == "build" else null)
		main._guide._refresh()
		check(not main._guide.visible, "不穿透无关弹窗：" + str(entry[0]))
		unrelated.free()
	replay.meta["onboarding"]["step"] = g.rules.onboarding.stage_index("recipe_open")
	var recipe = main.open("recipe", "salad")
	main._guide._refresh()
	check(main._guide.visible and main._guide._step == "recipe_mats" and recipe.has_meta("recipe_mats"), "只有正确配方面板才能推进材料教学")
	await process_frame
	main.free(); g.main = null

	# Sample the real generator tap path after the one explicit new-product beat.
	fresh(); g.level = 3; g.energy = 25000
	replay.meta["onboarding"]["step"] = g.rules.onboarding.stage_index("free_level3")
	for i in g.board.size(): g.board[i] = {"id": "", "lock": 0}
	g.board[32]["id"] = "basket_5"
	var displayed := 0.0
	for drop in Data.gen_stats("basket_5")["drops"]:
		if str(drop["id"]) == "seed_1": displayed = float(drop["p"])
	check(displayed == 10 and g.rules.onboarding.scripted_drop("basket_5") == "", "面板10%与新手正常抽取共用同一份配置")
	var counts := {}; var valid := true
	replay.executing = true
	for _i in 20000:
		var result: Dictionary = replay._reducer.tap(32)
		if result.get("kind", "") != "produce": valid = false; break
		var id := str(result["id"])
		counts[id] = int(counts.get(id, 0)) + 1
		g.board[int(result["to"])]["id"] = ""
	replay.executing = false
	var seed_rate := float(counts.get("seed_1", 0)) / 20000.0
	print("SAMPLED ", counts, " seed=", seed_rate * 100.0, "%")
	check(valid and seed_rate > 0.09 and seed_rate < 0.11 and counts.size() == 2, "两万次真实生产：坚果约10%，5级只产1级物品")
	quit(1 if failures else 0)
