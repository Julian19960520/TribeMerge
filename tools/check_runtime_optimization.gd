extends SceneTree
## Real failure, page-lifetime and independent-state regression checks.
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1

func run() -> void:
	var game = root.get_node("G")
	var replay = root.get_node("Replay")
	game.set_process(false); replay.set_process(false); root.get_node("Cloud").set_process(false)
	replay.active = true; replay.worker = false; replay.authorized = true; replay.executing = true
	replay.seq = 0; replay.base = 0; replay.pending = []; replay.inflight = {}
	replay.clock = 1794240000; game.simulation_time = replay.clock
	replay.meta = {"allow_gm": true}; game.replay_meta = replay.meta
	game.new_game(); game.level = 30; game.gm_activities = true
	game.tutorial_on = false; game.seen_tutorial = true; game.shells = 1000
	game.board = []
	for _i in 63: game.board.append({"id": "", "lock": 0})
	game.board[0]["id"] = "fruit_2"
	game.orders = [game.order_identity({"who": 0, "items": ["fruit_2"], "rw": {"shell": 10}, "story": false})]
	replay.advance(); replay._canonicalize_live(); replay.executing = false
	check(replay.checkpoint(), "runtime fixture has a durable checkpoint")
	var main = load("res://tools/RewardProbe.gd").new()
	root.add_child(main)
	await process_frame
	main.show_screen("board", true)
	await process_frame
	var screen = main.board_screen
	var board = screen.board
	var frames: int = board.frame_updates
	main.show_screen("home", true)
	for _frame in 4: await process_frame
	check(board.frame_updates == frames, "hidden board performs no frame scans or animation work")
	check(not screen.can_process() and main.home.can_process(), "page processing follows the active screen")
	var tags := []
	for child in main.home._spots_root.get_children(): tags.append(child.get_instance_id())
	var created: int = main.home.spot_created_count
	for amount in [1001, 1200, 900]:
		game.shells = amount; game.changed.emit()
		await process_frame
	var stable: bool = tags.size() == main.home._spots_root.get_child_count()
	for index in tags.size(): stable = stable and tags[index] == main.home._spots_root.get_child(index).get_instance_id()
	check(stable and main.home.spot_created_count == created, "currency changes retain every village tag and callback")
	var strip = screen._cards_root
	var refreshed: int = strip.refresh_count
	game.board_changed.emit(); game.orders_changed.emit()
	await process_frame
	check(strip.refresh_count == refreshed, "hidden order controls defer refreshes")
	main.show_screen("board", true)
	await process_frame
	check(strip.refresh_count == refreshed + 1, "returning to the board absorbs pending changes once")
	check(screen._activity_row.entries.size() == 6, "every registered board activity has one view")
	var ids := []
	for entry in screen._activity_row.entries: ids.append(entry["id"])
	check(ids == ["race", "merge", "seven", "duel", "tiger", "fossil"], "registered entries retain their configured order")
	var before: String = replay.digest()
	var path: String = game.save_path
	game.save_path = "/dev/null/unwritable.json"
	await screen._on_deliver(0)
	game.save_path = path
	check(replay.digest() == before and main.flights.is_empty(), "failed order journal write rolls back and displays no reward flights")
	var wallet: int = game.shells
	await screen._on_deliver(0)
	check(game.shells == wallet + 10 and not main.flights.is_empty(), "committed delivery settles once and presents the returned reward")
	# Unchanged branches in a transaction snapshot remain independent of live data.
	var saved: Dictionary = replay.snapshot()
	var reused: Dictionary = replay.snapshot(saved)
	game.board[1]["id"] = "fruit_3"
	check(saved["board"][1]["id"] == "" and reused["board"][1]["id"] == "", "snapshot reuse never aliases mutable live state")
	var normalized: Dictionary = replay.normalize({"x": [1.00000001, 2.1234567]})
	check(typeof(normalized["x"][0]) == TYPE_INT and is_equal_approx(normalized["x"][1], 2.123457), "one canonical numeric representation is used for nested values")
	main.free(); game.main = null
	# A second context has its own state, deterministic clock and random streams.
	var isolated = game.get_script().new()
	isolated.name = "IsolatedGame"
	isolated.save_path = path + ".isolated"
	isolated.simulation_time = 1794240000
	root.add_child(isolated)
	isolated.set_process(false)
	var metrics := {}
	var isolated_meta := {}
	var effects := {"record": func(metric, amount): metrics[metric] = int(metrics.get(metric, 0)) + amount,
		"login": func(): pass, "order": func(_o): pass,
		"settle": func(_rw, _delivery): return {}, "meta": func(): return isolated_meta}
	isolated.rules = game.rules.get_script().new(isolated,
		func(): return 1794240000.0, isolated.random_for, func(): return true, effects)
	isolated.tutorial_on = true
	isolated.board = [{"id": "fruit_2", "lock": 0}, {"id": "fruit_2", "lock": 0}]
	isolated.COLS = 2; isolated.ROWS = 1
	var primary: String = replay.digest()
	check(isolated.rules.board.try_drop(0, 1) == "merge" and isolated.board[1]["id"] == "fruit_3", "injected rules operate on the supplied independent game")
	check(metrics.get("merges", 0) == 1 and replay.digest() == primary, "isolated rule callbacks cannot mutate the primary game")
	isolated.free()
	print("RUNTIME_OPTIMIZATION failures: %d" % failures)
	quit(0 if failures == 0 else 1)
