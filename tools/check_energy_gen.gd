extends SceneTree
## 体力生产器（火种罐 emberpot_1）自检：不耗体力、点满一批进入冷却、冷却结束整批回满、掉落按配置。顺带截图。
## Godot --path . --script tools/check_energy_gen.gd -- --cloud-off --save=user://egen_test/s.json --cloud-state=user://egen_test/c.json --rank-state=user://egen_test/r.json --hot-file=user://egen_test/h.json [--out=DIR]
const GEN := "emberpot_1"
const CELL := 24
var failures := 0
var out := "res://_shots/egen"
var g
var main

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures += 1

func _shot(n: String) -> void:
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(dir)
	root.get_viewport().get_texture().get_image().save_png(dir + "/egen_" + n + ".png")
	print("shot ", dir + "/egen_" + n + ".png")

func _clear_board() -> void:
	for i in g.board.size():
		g.board[i] = {"id": "", "lock": 0}

func _count_items() -> Dictionary:
	var n := {}
	for i in g.board.size():
		var id := str(g.board[i]["id"])
		if id != "" and i != CELL:
			n[id] = int(n.get(id, 0)) + 1
	return n

func _total(n: Dictionary) -> int:
	var t := 0
	for k in n:
		t += int(n[k])
	return t

func run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	g = root.get_node("G")
	check(not g.server_mode(), "isolated local save (cloud off)")
	g.new_game()
	g.tutorial_on = false
	g.seen_tutorial = true
	g.level = 10
	g.simulation_time = 1793577600.0
	var st: Dictionary = Data.gen_stats(GEN)
	check(Data.type_of(GEN) == "egen" and not st.is_empty() and bool(st.get("free", false)), "emberpot_1 is a configured energy generator")
	var charges := int(st.get("charges", 0))
	var refill_sec := int(st.get("refill", 0)) * 60
	var drop_ids: Array = []
	var weights := {}
	var wsum := 0.0
	for d in st.get("drops", []):
		var dd: Dictionary = d
		drop_ids.append(str(dd["id"]))
		weights[str(dd["id"])] = float(dd["p"])
		wsum += float(dd["p"])
	check(charges > 0 and refill_sec > 0, "charges %d, cooldown %d s from chains.json" % [charges, refill_sec])
	var only_fire := true
	for id in drop_ids:
		only_fire = only_fire and Data.type_of(str(id)) == "energy"
	check(not drop_ids.is_empty() and only_fire, "drops are energy items: %s" % [drop_ids])

	# 掉落分布：抽 20000 次，和配置比
	var seen := {}
	var draws := 20000
	for k in draws:
		var id: String = g.roll_produce(GEN)
		seen[id] = int(seen.get(id, 0)) + 1
	var dist_ok := true
	for id in seen:
		dist_ok = dist_ok and drop_ids.has(id)
	for id in drop_ids:
		var want: float = float(weights[id]) / wsum
		var got := float(seen.get(id, 0)) / float(draws)
		dist_ok = dist_ok and absf(got - want) < 0.015
		print("  drop %s want %.3f got %.3f" % [id, want, got])
	check(dist_ok, "roll_produce follows the drop table")

	_clear_board()
	g.board[CELL]["id"] = GEN
	g.energy = 37
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout
	main.show_screen("board", true)
	await create_timer(0.6).timeout
	var bs = main.board_screen
	check(g.gen_left(CELL) == charges and g.gen_wait(CELL) == 0, "starts full (%d left)" % g.gen_left(CELL))
	await _shot("full")

	# 点 5 下后截一张，再点满
	var e0: int = g.energy
	for k in 5:
		bs._on_activate(CELL)
	check(g.gen_left(CELL) == charges - 5, "5 taps used 5 charges")
	bs.board.select(CELL)
	await _shot("partial")
	for k in charges - 5:
		bs._on_activate(CELL)
	var made := _count_items()
	check(g.energy == e0, "tapping does not spend energy (%d → %d)" % [e0, g.energy])
	check(_total(made) == charges, "one batch produced %d items (want %d)" % [_total(made), charges])
	var all_drops := true
	for id in made:
		all_drops = all_drops and drop_ids.has(id)
	check(all_drops, "every produced item is in the drop table: %s" % [made])
	check(g.gen_left(CELL) == 0 and g.gen_wait(CELL) > refill_sec - 5, "empty → resting %d s" % g.gen_wait(CELL))

	# 休息中再点：不产出
	bs._on_activate(CELL)
	check(_total(_count_items()) == charges and g.energy == e0, "tap while resting produces nothing")

	# 体力为 0 时也能点（冷却结束后）
	g.energy = 0
	g.simulation_time += float(refill_sec) - 3600.0
	check(g.gen_left(CELL) == 0 and g.gen_wait(CELL) > 3500, "still resting 1 h before the end (%s left)" % g.fmt_time(g.gen_wait(CELL)))
	bs.board.select(CELL)
	await create_timer(3.0).timeout # 等「休息中」提示消失
	await _shot("cooldown")
	g.simulation_time += 3601.0
	check(g.gen_left(CELL) == charges and g.gen_wait(CELL) == 0, "cooldown over → full batch again")
	_clear_board()
	g.board[CELL]["id"] = GEN
	g.board_changed.emit()
	bs._on_activate(CELL)
	check(_total(_count_items()) == 1 and g.energy == 0 and g.gen_left(CELL) == charges - 1, "works with 0 energy after refill")

	# 拖动换位时冷却跟着生产器走
	var used_left: int = g.gen_left(CELL)
	g.try_drop(CELL, 0)
	check(str(g.board[0]["id"]) == GEN and g.gen_left(0) == used_left, "cooldown moves with the generator")
	check(Data.describe(GEN).find("免费") >= 0, "description mentions free taps")

	print("FAILURES %d" % failures)
	quit(1 if failures > 0 else 0)
