extends SceneTree
## 活动积分检查：交单按难度随机 200~600、合成 7 级以上按等级 200~600，记进新版的篝火竞速 / 双人竞速 / 剑齿虎；
## 老存档里没打完的局仍按旧规则；合成和交单时冒分飞进入口（截图）。
## Godot --path . --script tools/check_activity_points.gd -- --cloud-off --save=user://ap_test/s.json --cloud-state=user://ap_test/c.json --rank-state=user://ap_test/r.json --hot-file=user://ap_test/h.json [--out=DIR]
var failures := 0
var out := "res://_shots/activity_points"
var g
var main
var AP
var Duel
var Tiger
var Race

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures += 1

func _shot(n: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("SKIP screenshot in headless renderer: ", n)
		return
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(dir)
	root.get_viewport().get_texture().get_image().save_png(dir + "/ap_" + n + ".png")
	print("shot ", dir + "/ap_" + n + ".png")

func _clear_board() -> void:
	for i in g.board.size():
		g.board[i] = {"id": "", "lock": 0}

func _long_item_chain() -> String:
	var best := ""
	for ch in Data.CHAINS:
		if str(Data.CHAINS[ch]["type"]) == "item" and (best == "" or Data.max_lv(ch) > Data.max_lv(best)):
			best = ch
	return best

func _scores() -> Array:
	var race := int(float(Race.state()["current"]["group"]["members"][0]["score"]))
	var duel := int(Duel.state()["match"]["me"])
	var tiger_m: Dictionary = Tiger.round_state()
	return [race, duel, int(tiger_m["points"]), int(tiger_m["stage"])]

func run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	AP = load("res://scripts/events/ActivityPoints.gd")
	Duel = load("res://scripts/events/DuelRace.gd")
	Tiger = load("res://scripts/events/TigerEscape.gd")
	Race = load("res://scripts/events/LocalRace.gd")
	g = root.get_node("G")
	g.set_process(false)
	var replay = root.get_node("Replay")
	replay.set_process(false); root.get_node("Cloud").set_process(false)
	replay.active = true; replay.worker = false; replay.authorized = true; replay.executing = true
	g.simulation_time = 1793577600.0; replay.clock = int(g.simulation_time)
	replay.meta = {"allow_gm": true}; g.replay_meta = replay.meta
	g.new_game(); g.tutorial_on = false; g.seen_tutorial = true
	replay.advance(); replay.executing = false
	load("res://scripts/events/ActivitySchedule.gd").bypass = true

	# 合成分表
	var ch := _long_item_chain()
	check(Data.max_lv(ch) >= 9, "long item chain %s (%d levels)" % [ch, Data.max_lv(ch)])
	var table := []
	for l in range(1, Data.max_lv(ch) + 1): table.append(AP.merge_points("%s_%d" % [ch, l]))
	print("merge points by level: ", table)
	check(table[5] == 0 and table[6] == 200 and table[7] == 300 and table[8] == 400, "lv6 0, lv7 200, lv8 300, lv9 400")
	var in_range := true
	for k in range(6, table.size()):
		in_range = in_range and table[k] >= 200 and table[k] <= 600 and (k == 6 or table[k] >= table[k - 1])
	check(in_range, "merge points 200~600 and rising with level")

	# 双人竞速：高概率主产物 / 小概率副产物合成分表 & 订单预计体力积分
	var main_scores := []
	for l in range(1, 14): main_scores.append(Duel.merge_score("fruit_%d" % l))
	check(main_scores == [0, 0, 0, 0, 1, 1, 2, 2, 2, 3, 3, 3, 4], "duel main merge scores lv1..13: %s" % [main_scores])
	var sub_scores := []
	for l in range(1, 10): sub_scores.append(Duel.merge_score("seed_%d" % l))
	check(sub_scores == [0, 1, 2, 2, 2, 3, 3, 3, 4], "duel sub merge scores lv1..9: %s" % [sub_scores])
	check(AP.merge_score_by_rule("fruit_5", {"table": [0, 0, 0, 0, 9]}) == 9, "custom table merge rule works")
	var s3: int = Duel.order_score({"items": ["fruit_3"]})
	var s10: int = Duel.order_score({"items": ["fruit_10"]})
	var s11: int = Duel.order_score({"items": ["fruit_11"]})
	check(s3 == 2 and s10 > 45 and s11 == 140, "duel order energy score uncapped: lv3=%d, lv10=%d, lv11=%d" % [s3, s10, s11])

	# 订单分：200~600、整十，难单平均高于简单单
	g.level = 25
	var rng := RandomNumberGenerator.new(); rng.seed = 3
	var easy := 0.0; var hard := 0.0; var ok_range := true; var ne := 0; var nh := 0
	for k in 200:
		var tier := "hard" if k % 2 == 0 else "easy"
		var o: Dictionary = g.rules.orders._make_order(Data.tier_target(25, tier, rng))
		var p: int = AP.order_points(o)
		ok_range = ok_range and p >= 200 and p <= 600 and p % 10 == 0
		if tier == "hard": hard += p; nh += 1
		else: easy += p; ne += 1
	check(ok_range, "order points always 200~600, multiples of 10")
	check(hard / nh > easy / ne + 100, "hard orders pay more: easy avg %.0f, hard avg %.0f" % [easy / ne, hard / nh])

	# 开三个新局：都带 pv
	g.level = 30
	check(Race.join().get("ok", false), "race joined")
	check(not Duel.local_action("join").has("error"), "duel joined")
	check(not Tiger.local_action("join").has("error"), "tiger joined")
	check(int(Race.state()["current"]["group"].get("pv", 1)) == AP.VERSION and int(Duel.state()["match"].get("pv", 1)) == Duel.DUEL_PV and int(Tiger.round_state().get("pv", 1)) == AP.VERSION, "new rounds are tagged pv")
	check(int(Race.state()["current"]["group"]["target"]) == 750 and int(Duel.state()["match"]["target"]) == 30 and int(Tiger.round_state()["stages"][0]["points"]) == 1800, "targets: race 750, duel round1 30, tiger stage1 1800")
	check(Duel.state()["match"]["opponent_curve"].size() == 30 and int(Duel.state()["match"]["opponent_curve"].back()[1]) == 30, "duel round1 opponent curve in 30 steps up to 30")

	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout
	main.show_screen("board", true)
	await create_timer(0.5).timeout
	main.close_all()
	var bs = main.board_screen
	bs._activity_row.refresh(false)

	# 合成两个 7 级 → 8 级：篝火/剑齿虎各 +300，双人竞速高概率 7→8 +2
	_clear_board()
	g.board[30] = {"id": "%s_7" % ch, "lock": 0}
	g.board[31] = {"id": "%s_7" % ch, "lock": 0}
	g.board_changed.emit()
	var before := _scores()
	var r: Dictionary = await replay.perform("drop", {"from": 30, "to": 31})
	var after := _scores()
	check(str(r.get("kind", "")) == "merge", "merged to %s_8" % ch)
	check(after[0] - before[0] == 300 and after[1] - before[1] == 2 and after[2] - before[2] == 300, "lv8 merge: race/tiger +300, duel +2 (%s → %s)" % [before, after])
	var fx_count := 0
	for c in main.fx_layer.get_children():
		if c.get_script() == bs._activity_row.ActivityPointsFx: fx_count += 1
	check(fx_count == 3, "three point badges fly from the merge cell (%d)" % fx_count)
	await create_timer(0.3).timeout
	await _shot("merge_pop")
	await create_timer(0.5).timeout
	await _shot("merge_fly")
	await create_timer(0.8).timeout

	# 合低级（3→4 级主产物）不给分；5→6 级主产物仅双人竞速 +1
	_clear_board()
	g.board[30] = {"id": "%s_3" % ch, "lock": 0}
	g.board[31] = {"id": "%s_3" % ch, "lock": 0}
	before = _scores()
	r = await replay.perform("drop", {"from": 30, "to": 31})
	check(_scores() == before, "lv4 main merge gives no points")
	_clear_board()
	g.board[30] = {"id": "%s_5" % ch, "lock": 0}
	g.board[31] = {"id": "%s_5" % ch, "lock": 0}
	before = _scores()
	r = await replay.perform("drop", {"from": 30, "to": 31})
	after = _scores()
	check(after[0] == before[0] and after[1] - before[1] == 1 and after[2] == before[2], "lv6 main merge: race/tiger +0, duel +1 (%s → %s)" % [before, after])

	# 交单：篝火/剑齿虎 200~600，双人竞速按预计体力得分（不超过目标分）
	_clear_board()
	var want: Array = g.orders[0]["items"] if g.orders.size() > 0 and str(g.orders[0].get("kind", "")) != "craft" else []
	if want.is_empty():
		g.orders.insert(0, g.rules.orders._make_order())
		want = g.orders[0]["items"]
	var expected_duel_pts: int = Duel.order_score(g.orders[0])
	for k in want.size(): g.board[10 + k] = {"id": str(want[k]), "lock": 0}
	g.orders_changed.emit(); g.board_changed.emit()
	await create_timer(0.3).timeout
	before = _scores()
	bs._on_deliver(0)
	after = _scores()
	var d_race: int = after[0] - before[0]
	var d_duel: int = after[1] - before[1]
	var duel_cap: int = int(Duel.state()["match"]["target"]) - before[1]
	check(d_race >= 200 and d_race <= 600 and d_duel == mini(expected_duel_pts, duel_cap), "order: race +%d, duel +%d expected %d (%s → %s, duel %s, tiger %s)" % [d_race, d_duel, expected_duel_pts, before, after, Duel.state()["match"]["status"], Tiger.round_state()["status"]])
	check(after[3] > before[3] or after[2] - before[2] == d_race, "order: tiger +%d (%s → %s)" % [d_race, before, after])
	main.close_all()
	if main.get("_guide") != null and is_instance_valid(main._guide): main._guide.visible = false
	await create_timer(0.3).timeout
	await _shot("order_pop")
	await create_timer(1.6).timeout
	# 交单那一侧的冒分单独再播一次截图（真交单会弹出新手提示挡住画面）
	main.close_all()
	g.stash = []
	for n in ["tips", "_guide"]:
		var node = main.get(n)
		if node is CanvasItem: node.visible = false
	g.board_changed.emit()
	await create_timer(0.3).timeout
	bs._points_origin = bs._cards[0].get_global_rect().get_center() if bs._cards.size() > 0 else Vector2(500, 200)
	bs.show_activity_points({"source": "order", "gains": [{"id": "race", "n": 460}, {"id": "duel", "n": 460}, {"id": "tiger", "n": 460}]})
	await create_timer(0.5).timeout
	await _shot("order_fx")
	await create_timer(1.4).timeout

	# 篝火竞速这一下正好到线：竞速收满，pv=2老双人竞速和剑齿虎照样加分
	Race.state()["current"]["group"]["members"][0]["score"] = 300.0
	Duel.state()["match"]["pv"] = AP.VERSION
	Duel.state()["match"]["status"] = "running"
	Duel.state()["match"]["target"] = 5400
	Duel.state()["match"]["me"] = 300
	before = _scores()
	var gains: Array = AP.grant(450)
	after = _scores()
	check(after[0] == 750 and after[1] - before[1] == 450 and (after[2] - before[2] == 450 or after[3] > before[3]), "race hits 750 on the same grant; pv=2 duel/tiger still +450 (%s → %s, gains %s)" % [before, after, gains])

	# 老局：没有 pv 的局还按旧规则（交单 +1 / 合成不加）
	var tm: Dictionary = Tiger.round_state()
	tm.erase("pv"); tm["points"] = 0; tm["stage"] = 0; tm["stages"] = Tiger.config()["stages"].duplicate(true)
	for st in tm["stages"]: st["points"] = 3
	var dm: Dictionary = Duel.state()["match"]
	dm.erase("pv"); dm["me"] = 0; dm["target"] = 30
	var rg: Dictionary = Race.state()["current"]["group"]
	rg.erase("pv"); rg["members"][0]["score"] = 0.0; rg["target"] = 150
	_clear_board()
	g.board[30] = {"id": "%s_8" % ch, "lock": 0}
	g.board[31] = {"id": "%s_8" % ch, "lock": 0}
	before = _scores()
	r = await replay.perform("drop", {"from": 30, "to": 31})
	check(_scores() == before, "legacy rounds ignore merge points")
	var legacy_order: Dictionary = g.rules.orders._make_order()
	g.rules.orders.context.on_order(legacy_order)
	after = _scores()
	check(after[2] == 1 and after[1] == Duel.order_points(legacy_order) and after[0] == mini(150, int(OrderRoll.total(legacy_order["items"]))), "legacy rounds keep old order scoring %s" % [after])

	print("DONE failures=%d" % failures)
	quit(1 if failures > 0 else 0)
