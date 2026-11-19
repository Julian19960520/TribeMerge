extends SceneTree
## 好运爆发检查：25 级解锁；订单全都很难时点生产器偶尔出高 3 级的物品，订单好做时不出；触发时播特效。
## Godot --path . --script tools/check_lucky.gd -- --cloud-off --save=user://lucky_test/s.json --cloud-state=user://lucky_test/c.json --rank-state=user://lucky_test/r.json --hot-file=user://lucky_test/h.json [--out=DIR]
const CELL := 24
const TAPS := 160
var failures := 0
var out := "res://_shots/lucky"
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
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(dir)
	root.get_viewport().get_texture().get_image().save_png(dir + "/lucky_" + n + ".png")
	print("shot ", dir + "/lucky_" + n + ".png")

func _clear_board() -> void:
	for i in g.board.size():
		g.board[i] = {"id": "", "lock": 0}

func _pick_gen() -> String:
	for ch in Data.CHAINS:
		if str(Data.CHAINS[ch]["type"]) != "gen":
			continue
		for l in range(1, Data.max_lv(ch) + 1):
			var id := "%s_%d" % [ch, l]
			if not Data.gen_stats(id).is_empty():
				return id
	return ""

func _lift(id: String, steps: int) -> String:
	var cur := id
	for _k in steps:
		cur = Data.next_id(cur)
		if cur == "":
			return ""
	return cur

## 点 TAPS 次，返回 [普通产物数, 好运产物列表, 不对的产物列表]
func _tap_many(bs, gen: String, drops: Array) -> Array:
	var plain := 0
	var lucky: Array = []
	var wrong: Array = []
	for k in TAPS:
		_clear_board()
		g.board[CELL] = {"id": gen, "lock": 0}
		g.energy = 999
		var r: Dictionary = await g.get_node("/root/Replay").perform("tap", {"cell": CELL})
		var id := str(r.get("id", ""))
		var n := int(r.get("lucky", 0))
		if n > 0:
			lucky.append("%s(+%d)" % [id, n])
			var ok := n >= Data.LUCKY_STEPS_MIN and n <= Data.LUCKY_STEPS_MAX
			var hit := false
			for d in drops:
				if _lift(str(d), n) == id: hit = true
			if not (ok and hit): wrong.append(id)
		elif drops.has(id):
			plain += 1
		else:
			wrong.append(id)
	return [plain, lucky, wrong]

func run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	g = root.get_node("G")
	g.set_process(false)
	var replay = root.get_node("Replay")
	replay.set_process(false); root.get_node("Cloud").set_process(false)
	replay.active = true; replay.worker = false; replay.authorized = true; replay.executing = true
	g.simulation_time = 1793577600.0; replay.clock = int(g.simulation_time)
	replay.meta = {"allow_gm": true}; g.replay_meta = replay.meta
	g.new_game(); g.tutorial_on = false; g.seen_tutorial = true
	g.gm_activities = false
	replay.advance(); replay.executing = false
	var gen := _pick_gen()
	var drops: Array = []
	for d in Data.gen_stats(gen)["drops"]:
		drops.append(str(d["id"]))
	var ch := Data.chain(str(drops[0]))
	check(Data.max_lv(ch) >= 6, "drop chain %s long enough" % ch)
	var real_orders: Array = g.orders.duplicate(true)
	g.level = 30
	var base: Dictionary = g.rules.orders._make_order().duplicate(true)
	check(not base.is_empty(), "found a plain order to copy")
	var hard_order := base.duplicate(true)
	hard_order["items"] = ["%s_%d" % [ch, Data.max_lv(ch)]]
	var easy_order := base.duplicate(true)
	easy_order["items"] = [str(drops[0])]
	check(Data.LUCKY_LEVEL == 25, "unlocks at Lv25")
	check(Data.level_unlocks(25).size() > Data.level_unlocks(24).size() or Data.level_unlocks(25).size() > 0, "Lv25 announces lucky")

	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout
	main.show_screen("board", true)
	await create_timer(0.5).timeout
	main.close_all()
	var bs = main.board_screen

	# all_orders_hard 判定
	g.level = 30
	_clear_board()
	g.inv = []; g.stash = []
	g.orders = [hard_order.duplicate(true)]
	check(g.rules.orders.all_orders_hard(Data.LUCKY_HARD_GAP), "far-off order counts as hard")
	g.board[3] = {"id": "%s_%d" % [ch, Data.max_lv(ch) - 2], "lock": 0}
	check(not g.rules.orders.all_orders_hard(Data.LUCKY_HARD_GAP), "owning target-2 makes it not hard")
	g.board[3] = {"id": "%s_%d" % [ch, Data.max_lv(ch) - 3], "lock": 0}
	check(g.rules.orders.all_orders_hard(Data.LUCKY_HARD_GAP), "owning target-3 is still hard")
	g.orders = [hard_order.duplicate(true), easy_order.duplicate(true)]
	check(not g.rules.orders.all_orders_hard(Data.LUCKY_HARD_GAP), "one easy order breaks it")
	g.orders = []
	check(not g.rules.orders.all_orders_hard(Data.LUCKY_HARD_GAP), "no orders → not hard")

	# 24 级：订单再难也不出
	g.level = Data.LUCKY_LEVEL - 1
	g.orders = [hard_order.duplicate(true)]
	var r: Array = await _tap_many(bs, gen, drops)
	check(r[1].is_empty() and r[2].is_empty(), "Lv%d: no lucky drops in %d taps (%d plain)" % [Data.LUCKY_LEVEL - 1, TAPS, r[0]])

	# 25 级 + 订单都很难：偶尔出高 3 级
	g.level = Data.LUCKY_LEVEL
	g.orders = [hard_order.duplicate(true), hard_order.duplicate(true)]
	r = await _tap_many(bs, gen, drops)
	check(not r[1].is_empty(), "Lv%d hard orders: %d lucky of %d taps %s" % [Data.LUCKY_LEVEL, r[1].size(), TAPS, r[1]])
	check(r[1].size() < TAPS / 4, "lucky stays rare (%d/%d)" % [r[1].size(), TAPS])
	check(r[2].is_empty(), "every lucky drop is +%d~+%d over a table drop: wrong=%s" % [Data.LUCKY_STEPS_MIN, Data.LUCKY_STEPS_MAX, r[2]])
	var seen := {}
	for s in r[1]: seen[str(s).get_slice("+", 1)] = true
	check(seen.size() >= 2, "lucky step count varies: %s" % [seen.keys()])
	# 链尾：只剩 1 级的升不了，剩 2 级的最多 +2
	var top := Data.max_lv(ch)
	var room_ok := true
	for k in 40:
		var near: Dictionary = g.rules.board.lucky_drop("%s_%d" % [ch, top - 1])
		if not near.is_empty(): room_ok = false
		var two: Dictionary = g.rules.board.lucky_drop("%s_%d" % [ch, top - 2])
		if not two.is_empty() and int(two["steps"]) != 2: room_ok = false
	check(room_ok, "near chain top: no lucky with 1 level left, capped at +2 with 2 left")

	# 25 级 + 有一张好做的单：不出
	g.orders = [hard_order.duplicate(true), easy_order.duplicate(true)]
	r = await _tap_many(bs, gen, drops)
	check(r[1].is_empty(), "easy order present: no lucky drops (%d plain)" % r[0])

	# 特效：直接播一次截图
	g.orders = real_orders
	g.changed.emit()
	_clear_board()
	g.board[CELL] = {"id": gen, "lock": 0}
	g.board[CELL + 2] = {"id": _lift(str(drops[0]), 4), "lock": 0}
	g.board_changed.emit()
	await create_timer(0.3).timeout
	bs.LuckyDropFx.play(bs.board, CELL, CELL + 2, 4)
	var fx_alive := false
	for c in bs.board.get_children():
		if c.get_script() == bs.LuckyDropFx: fx_alive = true
	check(fx_alive, "lucky fx node spawned")
	await create_timer(0.48).timeout
	await _shot("burst")
	await create_timer(0.5).timeout
	await _shot("label")
	await create_timer(1.2).timeout
	fx_alive = false
	for c in bs.board.get_children():
		if c.get_script() == bs.LuckyDropFx: fx_alive = true
	check(not fx_alive, "lucky fx frees itself")
	var sfx = root.get_node("Sfx")
	check(sfx.EFFECTS.has("lucky"), "lucky sfx registered")
	var wav: AudioStreamWAV = sfx._make(Callable(sfx, "_lucky"), 1.5)
	check(wav.data.size() > 0, "lucky sfx synthesizes")

	print("DONE failures=%d" % failures)
	quit(1 if failures > 0 else 0)
