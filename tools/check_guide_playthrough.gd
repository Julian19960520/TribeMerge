extends SceneTree
## Drives the actual UI and shared commands from the opening through construction 3.
## No board items or currencies are injected. --shots-dir=DIR captures each lesson.
var failures := 0
var main
var game
var replay
var seen := {}
var shots := ""
var checkpoint_out := ""
var steps := 0
var checkpoint_checked := false
var free_seen := false
var manual_seen := false
var same_step := 0
var last_step := ""
var waited_min := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func _find(id: String, include_locked := false) -> int:
	for i in game.board.size():
		if str(game.board[i]["id"]) == id and (int(game.board[i]["lock"]) == 0 or include_locked and int(game.board[i]["lock"]) == 1): return i
	return -1
func _button(n: Node, name: String):
	if n is Control and n.has_signal("pressed") and (n.name == name or name == "build" and n.get("res") == "shell_2"): return n
	for child in n.get_children():
		var found = _button(child, name)
		if found != null: return found
	return null
func _tap_popups() -> bool:
	var p = main.popup_layer.top()
	if p == null: return false
	if p._closing: return true
	var step := str(game.rules.onboarding.stage().get("key", ""))
	if step in ["level_rule", "level_preview", "recipe_mats", "recipe_time", "recipe_ready"]:
		main._guide.skip_beat()
	elif step in ["level_close", "recipe_close", "build_preview"]: p.close()
	elif step == "build1":
		var button = _button(p, "build")
		if button != null: button.pressed.emit()
	elif step == "howto": p.close()
	elif p.on_tap.is_valid(): p.on_tap.call()
	else: p.close()
	return true
func _produce() -> bool:
	var id := str(game.rules.onboarding.config()["upgraded_generator"])
	var at := _find(id)
	if at < 0: at = _find(str(game.rules.onboarding.config()["generator"]))
	if at < 0: return false
	if game.energy == 0:
		# Use the level-four gift before buying stamina again.
		if game.level >= 4:
			var egen := _find("emberpot_1")
			if egen >= 0 and game.rules.board.gen_left(egen) > 0:
				replay.perform("tap", {"cell": egen}); return true
			var stashed: int = game.stash.find("emberpot_1")
			if stashed >= 0: replay.perform("stash", {"index": stashed}); return true
		var result: Dictionary = replay.perform("energy")
		if result.get("free", false): free_seen = true
		if result.has("error"):
			# Out of amber: wait like a player does while stamina comes back.
			waited_min += 10
			replay.perform("tick", {}, replay.clock + 600)
		return true
	var r: Dictionary = replay.perform("tap", {"cell": at})
	return not r.has("error")
func _free_play() -> bool:
	# The gift is a persistent producer; collect usable energy when it is needed.
	for chain in ["fire", "shell", "sand"]:
		for lv in range(6, 1, -1):
			var at := _find("%s_%d" % [chain, lv])
			if at >= 0 and (chain != "fire" or lv == 6 or game.energy == 0):
				replay.perform("tap", {"cell": at}); return true
	for oi in game.orders.size():
		var o: Dictionary = game.orders[oi]
		if game.rules.orders.order_ready(o): main.board_screen._on_deliver(oi); return true
		if game.rules.orders.craft_mats_ready(o): main.board_screen._on_craft(oi); return true
		if str(o.get("phase", "")) == "finished":
			manual_seen = true
			replay.perform("tap", {"cell": int(o["cell"])}); return true
		if str(o.get("phase", "")) == "cook":
			replay.perform("tick", {}, replay.clock + game.rules.orders.cook_left(int(o["cell"])) + 1); return true
	# Protect requested exact goods; combine everything else along reachable chains.
	var protect := {}
	for o in game.orders:
		for id in o.get("mats", o["items"]): protect[str(id)] = int(protect.get(str(id), 0)) + 1
	for lv in range(13, 0, -1):
		for chain in ["fruit", "seed", "fire", "shell"]:
			if lv >= Data.max_lv(chain): continue
			var id := "%s_%d" % [chain, lv]
			if protect.has(id) and game.rules.onboarding.count(id) <= int(protect[id]): continue
			var from := _find(id)
			if from < 0: continue
			for to in game.board.size():
				if to == from or str(game.board[to]["id"]) != id or int(game.board[to]["lock"]) == 2: continue
				var r: Dictionary = replay.perform("drop", {"from": from, "to": to})
				if not r.has("error"): return true
	if _produce(): return true
	# Board-full fallback sells a surplus item rather than rewriting the board.
	for i in game.board.size():
		var id := str(game.board[i]["id"])
		if int(game.board[i]["lock"]) == 0 and Data.type_of(id) == "item" and not protect.has(id):
			replay.perform("discard", {"cell": i}); replay.perform("discard_finish"); return true
	return false
func run() -> void:
	game = root.get_node("G"); replay = root.get_node("Replay")
	game.simulation_time = 1794240000
	game.new_game()
	replay.meta = {}; replay.seq = 0; replay.base = 0; replay.pending = []; replay.inflight = {}
	replay.clock = 1794240000
	game.random_seed = "reference-full-playthrough"; game.random_streams = {}
	replay.executing = true; replay.advance(); replay._canonicalize_live(); replay.executing = false
	game.clear_presentations()
	main = load("res://main.tscn").instantiate(); root.add_child(main)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots-dir="): shots = arg.trim_prefix("--shots-dir=")
		if arg.begins_with("--checkpoint-out="): checkpoint_out = arg.trim_prefix("--checkpoint-out=")
	await create_timer(0.2).timeout
	check(main.screen == "home" and game.orders.is_empty(), "#1 外景开场，尚无订单")
	check(game.energy == 100 and game.shells == 0 and game.amber == 30, "开局100体力、0不那那、30琥珀")
	for k in 3500:
		steps += 1
		game.simulation_time = replay.clock
		if not game.tutorial_on: break
		var guide = main._guide
		var step := str(game.rules.onboarding.stage().get("key", ""))
		var mode := str(game.rules.onboarding.stage().get("mode", ""))
		same_step = same_step + 1 if step == last_step else 0
		last_step = step
		if same_step > (1800 if mode == "free" else 50):
			check(false, "引导卡在 " + step)
			print("STATE ", game.level, " ", game.xp, " energy ", game.energy, " amber ", game.amber, " orders ", game.orders)
			print("BOARD ", game.board)
			break
		if not seen.has(step):
			seen[step] = true
			print("STEP ", step, " lv=", game.level, " xp=", game.xp, " energy=", game.energy, " money=", game.shells, " amber=", game.amber, " waited=", waited_min)
			if shots != "":
				await create_timer(0.45).timeout
				await RenderingServer.frame_post_draw
				root.get_viewport().get_texture().get_image().save_png(shots + "/" + step + ".png")
		if not checkpoint_checked and step == "gen_merge3":
			var snap: Dictionary = replay.snapshot()
			var before := JSON.stringify(game.rules.onboarding.progress())
			replay.restore(snap)
			check(JSON.stringify(game.rules.onboarding.progress()) == before, "中途恢复保留当前步骤和已发订单，不重发奖励")
			checkpoint_checked = true
		if main.home.is_building():
			pass # Construction finishes on its own; never open or install a crate.
		elif _tap_popups(): pass
		elif main.level_pending or main._rw_showing or main._wipe.running(): pass
		elif guide.visible and guide._mode == "stash": main.board_screen._on_stash()
		elif mode in ["dialog", "banner"]: guide.skip_beat()
		elif mode == "enter_board" or mode == "back": main.home.go.pressed.emit()
		elif mode == "merge":
			var pair: Vector2i = guide.merge_hint()
			if pair.x >= 0:
				var merge_result: Dictionary = replay.perform("drop", {"from": pair.x, "to": pair.y})
				if k < 30: print("MERGE ", pair, " ", merge_result)
		elif mode in ["produce", "collect", "energy_gen", "take_dish"]:
			if mode == "take_dish": manual_seen = true
			var at: int = guide._cell_target()
			if at >= 0: main.board_screen._on_activate(at)
		elif mode == "submit": main.board_screen._on_deliver(guide._order_index())
		elif mode == "open_build": main.board_screen._on_hammer()
		elif mode == "level_open": main.board_screen._base_btn.pressed.emit()
		elif mode == "recipe_open":
			var oi: int = guide._order_index()
			if oi >= 0: main.open("recipe", str(game.orders[oi]["dish"]))
		elif mode == "cook": main.board_screen._on_craft(guide._order_index())
		elif mode == "stash": main.board_screen._on_stash()
		elif step in ["build2_wait", "build3_wait"]:
			main.board_screen._on_hammer()
			await create_timer(0.65).timeout
			var b = _button(main.popup_layer, "build")
			if b != null: b.pressed.emit()
		elif mode == "free":
			if not _free_play():
				check(false, "无法继续自由阶段 " + step)
				print("STATE ", game.level, " ", game.xp, " energy ", game.energy, " amber ", game.amber, " stash ", game.stash, " orders ", game.orders)
				print("BOARD ", game.board)
				break
		await create_timer(0.03 if mode == "free" else 0.12).timeout
		if k % 200 == 199: print("PROGRESS ", k, " ", step)
	check(not game.tutorial_on and game.level >= 5 and int(game.builds.get("fire", 0)) >= 4, "#131 完整流程走到5级、第三次建设完")
	for row in game.rules.onboarding.config()["stages"]:
		var key := str(row["key"])
		if key == "complete": continue
		check(seen.has(key) or game.rules.onboarding.progress().get("completed", []).has(key), "实际经过 " + key)
	check(free_seen, "体力耗尽后用过首次免费补充")
	check(manual_seen, "菜做完后从设备取出，再提交订单")
	check(checkpoint_checked, "在生产器升级中途恢复过快照")
	var opened := []
	for i in game.board.size():
		if int(game.board[i]["lock"]) != 2: opened.append(i)
	print("OPENED ", opened)
	print("COMMANDS ", steps, " WAITED_MIN ", waited_min, " AMBER ", game.amber)
	if failures == 0 and checkpoint_out != "":
		var file := FileAccess.open(checkpoint_out, FileAccess.WRITE)
		file.store_string(JSON.stringify(replay.snapshot(), "\t")); file.close()
	await create_timer(1.0).timeout
	main.free(); game.main = null
	await process_frame
	await process_frame
	quit(1 if failures else 0)
