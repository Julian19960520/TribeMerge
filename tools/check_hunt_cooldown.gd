extends SceneTree
## 狩猎线冷却自检：狩猎陷阱 4 级起储 12 次、点完 60 分钟回满，每升一级只提升一项（+2 次或 -10 分钟）；其他产线不受影响。顺带截图。
## Godot --path . --script tools/check_hunt_cooldown.gd -- --cloud-off --save=user://hunt_cd_test/s.json --cloud-state=user://hunt_cd_test/c.json --rank-state=user://hunt_cd_test/r.json --hot-file=user://hunt_cd_test/h.json [--out=DIR]
const GEN := "trap_4"
const CELL := 24
var failures := 0
var out := "res://_shots/hunt_cd"
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
	root.get_viewport().get_texture().get_image().save_png(dir + "/hunt_" + n + ".png")
	print("shot ", dir + "/hunt_" + n + ".png")

func _clear_board() -> void:
	for i in g.board.size():
		g.board[i] = {"id": "", "lock": 0}

func _count() -> int:
	var t := 0
	for i in g.board.size():
		if str(g.board[i]["id"]) != "" and i != CELL:
			t += 1
	return t

func run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	g = root.get_node("G")
	check(not root.get_node("Cloud").enabled, "isolated test transport")
	g.new_game()
	g.tutorial_on = false
	g.seen_tutorial = true
	g.level = 12 # 低于赶大集开放等级，截图不被弹窗挡住
	g.simulation_time = 1793577600.0

	# 4 级起能生产：12 次 / 60 分，之后每升一级只提升一项（+2 次 或 -10 分），交替进行
	var want := {4: [12, 60], 5: [14, 60], 6: [14, 50], 7: [16, 50], 8: [16, 40]}
	var all_ok := true
	var prev := []
	for lv in range(1, 10):
		var st: Dictionary = Data.gen_stats("trap_%d" % lv)
		if st.is_empty():
			all_ok = all_ok and not want.has(lv)
			continue
		var cur := [int(st.get("charges", 0)), int(st.get("refill", 0))]
		all_ok = all_ok and want.has(lv) and cur == want[lv]
		if not prev.is_empty():
			var better := int(cur[0] > prev[0]) + int(cur[1] < prev[1])
			var worse: bool = cur[0] < prev[0] or cur[1] > prev[1]
			check(better == 1 and not worse, "trap_%d improves exactly one stat (%s → %s)" % [lv, prev, cur])
		prev = cur
	check(all_ok, "trap levels match the upgrade table")
	check(not Data.gen_stats("basket_4").has("charges"), "food line still has no cooldown")

	_clear_board()
	g.board[CELL]["id"] = GEN
	g.energy = 100
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout
	main.show_screen("board", true)
	await create_timer(0.6).timeout
	var bs = main.board_screen
	check(g.rules.board.gen_left(CELL) == 12 and g.rules.board.gen_wait(CELL) == 0, "starts full (%d left)" % g.rules.board.gen_left(CELL))
	for k in 5:
		bs._on_activate(CELL)
	check(g.rules.board.gen_left(CELL) == 7, "5 taps → 7 left")
	await _shot("partial")
	for k in 7:
		bs._on_activate(CELL)
	check(_count() == 12 and g.energy == 88, "12 items made, 12 energy spent")
	check(g.rules.board.gen_left(CELL) == 0 and g.rules.board.gen_wait(CELL) > 3595, "empty → resting %d s" % g.rules.board.gen_wait(CELL))
	bs._on_activate(CELL)
	check(_count() == 12 and g.energy == 88, "tap while resting produces nothing, costs nothing")
	await create_timer(3.0).timeout
	await _shot("resting")
	g.simulation_time += 3590.0
	check(g.rules.board.gen_left(CELL) == 0, "still resting at 59m50s")
	g.simulation_time += 11.0
	check(g.rules.board.gen_left(CELL) == 12, "full again after 1 h")

	print("FAILURES %d" % failures)
	quit(1 if failures > 0 else 0)
