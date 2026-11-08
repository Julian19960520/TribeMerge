extends SceneTree
## 双倍火种自检：18 级前不可开；开启后生产器每次耗 2 火种、产物升 1 级、右下角紫火；火种不足 2 时不产出。顺带截图。
## Godot --path . --script tools/check_boost.gd -- --cloud-off --save=user://boost_test/s.json --cloud-state=user://boost_test/c.json --rank-state=user://boost_test/r.json --hot-file=user://boost_test/h.json [--out=DIR]
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

func run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	g = root.get_node("G")
	check(not g.server_mode(), "isolated local save (cloud off)")
	g.new_game()
	g.tutorial_on = false
	g.seen_tutorial = true
	var gen := _pick_gen()
	check(gen != "", "found a generator: %s" % gen)
	var drops: Array = []
	for d in Data.gen_stats(gen)["drops"]:
		drops.append(str(d["id"]))

	# 17 级：开不了
	g.level = Data.BOOST_LEVEL - 1
	g.set_boost(true)
	check(not g.boost_on() and g.gen_cost() == 1, "locked below Lv%d" % Data.BOOST_LEVEL)
	check(g.boost_drop(str(drops[0])) == str(drops[0]), "no level-up while locked")

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
	main.close_all()
	await _shot("off")

	# 关着：耗 1，原样掉落
	bs._on_activate(CELL)
	var m := _made()
	check(g.energy == 49 and m.size() == 1 and drops.has(m[0]), "off: cost 1, normal drop %s" % [m])

	# 打开
	bs._on_boost()
	check(g.boost_on() and g.gen_cost() == 2, "boost on → cost 2")
	_clear_board()
	g.board[CELL]["id"] = gen
	g.board_changed.emit()
	var e0: int = g.energy
	for k in 6:
		bs._on_activate(CELL)
	m = _made()
	var lifted := true
	for id in m:
		var base := "%s_%d" % [Data.chain(id), Data.lv(id) - 1]
		lifted = lifted and (drops.has(base) or (drops.has(id) and Data.next_id(id) == ""))
	check(g.energy == e0 - 2 * m.size() and m.size() > 0, "boost: %d taps spent %d energy" % [m.size(), e0 - g.energy])
	check(lifted, "boost: every drop is one level above the table: %s (table %s)" % [m, drops])
	main.close_all()
	await create_timer(3.0).timeout
	bs.board.select(-1)
	await _shot("on_badge")
	bs.board.select(CELL)
	await _shot("on")

	# 只剩 1 火种：不产出
	_clear_board()
	g.board[CELL]["id"] = gen
	g.energy = 1
	g.board_changed.emit()
	bs._on_activate(CELL)
	check(_made().is_empty() and g.energy == 1, "boost with 1 energy produces nothing")
	main.close_all()

	# 存档往返
	var d: Dictionary = g.to_dict() if g.has_method("to_dict") else {}
	if not d.is_empty():
		check(bool(d.get("boost", false)), "boost saved")

	bs._on_boost()
	check(not g.boost_on() and g.gen_cost() == 1, "toggle back off")
	print("DONE failures=%d" % failures)
	quit(1 if failures > 0 else 0)
