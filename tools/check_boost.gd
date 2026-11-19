extends SceneTree
## 多倍体力检查：当前Replay命令执行普通门槛、2倍/4倍消耗、产物升级、旧存档迁移和授权GM解锁。
## Godot --path . --script tools/check_boost.gd -- --cloud-off --save=user://boost_test/s.json --cloud-state=user://boost_test/c.json --rank-state=user://boost_test/r.json --hot-file=user://boost_test/h.json [--out=DIR]
const StateCodec := preload("res://scripts/domain/StateCodec.gd")
const CELL := 24
var failures := 0
var out := "res://_shots/boost"
var g
var main

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
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(dir)
	root.get_viewport().get_texture().get_image().save_png(dir + "/boost_" + n + ".png")
	print("shot ", dir + "/boost_" + n + ".png")

func _clear_board() -> void:
	for i in g.board.size():
		g.board[i] = {"id": "", "lock": 0}

func _made() -> Array:
	var a: Array = []
	for i in g.board.size():
		var id := str(g.board[i]["id"])
		if id != "" and i != CELL:
			a.append(id)
	return a

## 找一个耗火种、能生产的生产器
func _pick_gen() -> String:
	for ch in Data.CHAINS:
		if str(Data.CHAINS[ch]["type"]) != "gen":
			continue
		for l in range(1, Data.max_lv(ch) + 1):
			var id := "%s_%d" % [ch, l]
			if not Data.gen_stats(id).is_empty():
				return id
	return ""

func _lifted_by(base: String, steps: int) -> String:
	var cur := base
	for _k in steps:
		var nxt := Data.next_id(cur)
		if nxt == "":
			break
		cur = nxt
	return cur

func run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	g = root.get_node("G")
	check(not root.get_node("Cloud").enabled, "isolated test transport")
	g.set_process(false)
	var replay = root.get_node("Replay")
	replay.set_process(false); root.get_node("Cloud").set_process(false)
	replay.active = true; replay.worker = false; replay.authorized = true; replay.executing = true
	g.simulation_time = 1793577600.0; replay.clock = int(g.simulation_time)
	replay.meta = {"allow_gm": true}; g.replay_meta = replay.meta
	g.new_game(); g.tutorial_on = false; g.seen_tutorial = true
	replay.advance(); replay.executing = false
	var gen := _pick_gen()
	check(gen != "", "found a generator: %s" % gen)
	var drops: Array = []
	for d in Data.gen_stats(gen)["drops"]:
		drops.append(str(d["id"]))

	# 17 级：2倍和4倍都开不了
	g.level = Data.BOOST_LEVEL - 1
	g.set_boost(true)
	check(not g.rules.board.boost_on() and not g.rules.board.boost_4_open() and g.rules.board.gen_cost() == 1, "locked below Lv%d" % Data.BOOST_LEVEL)
	g.set_boost_mult(4)
	check(g.rules.board.boost_mult() == 1 and g.rules.board.gen_cost() == 1, "4x locked below Lv%d" % Data.BOOST_LEVEL)
	check(g.rules.board.boost_drop(str(drops[0])) == str(drops[0]), "no level-up while locked")

	g.level = Data.BOOST_LEVEL
	_clear_board()
	g.board[CELL]["id"] = gen
	g.energy = 50
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout
	main.show_screen("board", true)
	await create_timer(0.6).timeout
	var bs = main.board_screen
	check(bs._boost_btn.visible, "toggle visible at Lv%d" % Data.BOOST_LEVEL)
	check(not g.rules.board.boost_4_open(), "4x locked at Lv%d" % Data.BOOST_LEVEL)
	main.close_all()
	await _shot("off")

	# 关着：耗 1，原样掉落
	bs._on_activate(CELL)
	var m := _made()
	check(g.energy == 49 and m.size() == 1 and drops.has(m[0]), "off: cost 1, normal drop %s" % [m])

	# 18 级不能直接切到 4 倍
	g.set_boost_mult(4)
	check(g.rules.board.boost_mult() == 1, "Lv%d: direct 4x request stays 1x" % Data.BOOST_LEVEL)

	# 打开 2 倍
	bs._on_boost()
	check(g.rules.board.boost_on() and g.rules.board.boost_mult() == 2 and g.rules.board.gen_cost() == 2, "boost 2x on → cost 2")
	_clear_board()
	g.board[CELL]["id"] = gen
	g.board_changed.emit()
	var e0: int = g.energy
	for k in 6:
		bs._on_activate(CELL)
	m = _made()
	var lifted := true
	for id in m:
		var matched := false
		for d in drops:
			if _lifted_by(str(d), 1) == id:
				matched = true; break
		lifted = lifted and matched
	check(g.energy == e0 - 2 * m.size() and m.size() > 0, "boost 2x: %d taps spent %d energy" % [m.size(), e0 - g.energy])
	check(lifted, "boost 2x: every drop is one level above the table: %s (table %s)" % [m, drops])
	main.close_all()
	await create_timer(0.2).timeout
	bs.board.select(-1)
	await _shot("on_badge")
	bs.board.select(CELL)
	await _shot("on")

	# 只剩 1 火种：2 倍不产出
	_clear_board()
	g.board[CELL]["id"] = gen
	g.energy = 1
	g.board_changed.emit()
	bs._on_activate(CELL)
	check(_made().is_empty() and g.energy == 1, "boost 2x with 1 energy produces nothing")
	main.close_all()

	# 存档往返（2倍）
	var d: Dictionary = g.save_dict()
	if not d.is_empty():
		check(int(d.get("boost", 1)) == 2, "boost 2x saved")

	# 18 级再点一次回到 1 倍（跳过 4 倍）
	bs._on_boost()
	check(not g.rules.board.boost_on() and g.rules.board.boost_mult() == 1 and g.rules.board.gen_cost() == 1, "Lv%d: toggle cycles 2x → 1x" % Data.BOOST_LEVEL)

	# 41 级：4 倍依然未解锁
	g.level = Data.BOOST_4_LEVEL - 1
	g.changed.emit()
	check(not g.rules.board.boost_4_open(), "4x locked at Lv%d" % (Data.BOOST_4_LEVEL - 1))
	g.set_boost_mult(4)
	check(g.rules.board.boost_mult() == 1, "Lv%d: 4x rejected" % (Data.BOOST_4_LEVEL - 1))

	# 42 级：解锁 4 倍体力
	check(Data.BOOST_4_LEVEL == 42, "BOOST_4_LEVEL is 42")
	check(Data.level_unlocks(Data.BOOST_4_LEVEL).has(TextCatalog.source("notice.data.e3408ef57afa")), "Lv42 level_unlocks announces 4x boost")
	g.level = Data.BOOST_4_LEVEL
	g.energy = 60
	g.changed.emit()
	check(g.rules.board.boost_4_open(), "4x unlocked at Lv%d" % Data.BOOST_4_LEVEL)
	# 循环切换：1 → 2 → 4 → 1
	bs._on_boost()
	check(g.rules.board.boost_mult() == 2 and bs._boost_btn.style == "purple", "Lv42: 1x → 2x")
	bs._on_boost()
	check(g.rules.board.boost_mult() == 4 and g.rules.board.gen_cost() == 4 and bs._boost_btn.style == "red", "Lv42: 2x → 4x (cost 4, red button)")

	_clear_board()
	g.board[CELL]["id"] = gen
	g.board_changed.emit()
	e0 = g.energy
	for k in 6:
		bs._on_activate(CELL)
	m = _made()
	var lifted4 := true
	for id in m:
		var matched := false
		for drop_id in drops:
			if _lifted_by(str(drop_id), 2) == id:
				matched = true; break
		lifted4 = lifted4 and matched
	check(g.energy == e0 - 4 * m.size() and m.size() > 0, "boost 4x: %d taps spent %d energy" % [m.size(), e0 - g.energy])
	check(lifted4, "boost 4x: every drop is two levels above the table: %s (table %s)" % [m, drops])
	# 满级物品与次满级物品在 4 倍下都正确封顶，菜品不升级
	var ch0 := Data.chain(str(drops[0]))
	var max_l := Data.max_lv(ch0)
	check(g.rules.board.boost_drop("%s_%d" % [ch0, max_l]) == "%s_%d" % [ch0, max_l], "boost 4x clamps max level item")
	if max_l >= 2:
		check(g.rules.board.boost_drop("%s_%d" % [ch0, max_l - 1]) == "%s_%d" % [ch0, max_l], "boost 4x clamps max-1 item to max")
	if not Data.DISHES.is_empty():
		var dish_id := str(Data.DISHES.keys()[0])
		check(g.rules.board.boost_drop(dish_id) == dish_id, "boost 4x does not alter dishes")

	# 只剩 3 火种：4 倍不产出
	_clear_board()
	g.board[CELL]["id"] = gen
	g.energy = 3
	g.board_changed.emit()
	bs._on_activate(CELL)
	check(_made().is_empty() and g.energy == 3, "boost 4x with 3 energy produces nothing")
	main.close_all()

	# 存档往返（4倍）与旧布尔存档迁移
	var d4: Dictionary = g.save_dict()
	check(int(d4.get("boost", 1)) == 4, "boost 4x saved")
	var legacy_true := d4.duplicate(true)
	legacy_true["boost"] = true
	check(StateCodec.restore(g, legacy_true) and g.boost == 2 and g.rules.board.boost_mult() == 2, "legacy save boost=true migrates to 2")
	var legacy_false := d4.duplicate(true)
	legacy_false["boost"] = false
	check(StateCodec.restore(g, legacy_false) and g.boost == 1 and g.rules.board.boost_mult() == 1, "legacy save boost=false migrates to 1")
	check(StateCodec.restore(g, d4) and g.boost == 4 and g.rules.board.boost_mult() == 4, "current save boost=4 restores cleanly")
	var invalid_boost := d4.duplicate(true)
	invalid_boost["boost"] = 3
	check(not StateCodec.validate(g, invalid_boost), "invalid boost value 3 rejected by StateCodec")

	# 4 倍再点一次回到 1 倍
	bs._on_boost()
	check(g.rules.board.boost_mult() == 1 and g.rules.board.gen_cost() == 1, "Lv42: toggle cycles 4x → 1x")

	# GM 按钮：低等级也能解锁 2 倍与 4 倍
	g.level = 3
	g.boost_gm = false
	g.gm_activities = false
	g.changed.emit()
	check(not bs._boost_btn.visible and not g.rules.board.boost_open() and not g.rules.board.boost_4_open(), "Lv3: toggle hidden")
	var gm_btn = bs.get_node("gm_activities")
	gm_btn.pressed.emit()
	await create_timer(0.3).timeout
	check(g.boost_gm and g.rules.board.boost_open() and g.rules.board.boost_4_open() and bs._boost_btn.visible, "GM button unlocks 2x and 4x boost at Lv3")
	bs._on_boost()
	check(g.rules.board.boost_mult() == 2 and g.rules.board.gen_cost() == 2, "Lv3 after GM: 1x → 2x")
	bs._on_boost()
	check(g.rules.board.boost_mult() == 4 and g.rules.board.gen_cost() == 4, "Lv3 after GM: 2x → 4x")
	var d2: Dictionary = g.save_dict()
	if not d2.is_empty():
		check(bool(d2.get("boost_gm", false)) and int(d2.get("boost", 1)) == 4, "GM unlock and 4x boost saved")
	main.close_all()
	await _shot("gm_lv3")
	main.free(); g.main = null
	print("RESULT: %d failures" % failures)
	quit(1 if failures > 0 else 0)
