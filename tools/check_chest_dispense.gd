extends SceneTree
## Chest ownership, partial contents and the real replay UI's resource flights.
var failures := 0
var g
var replay
var main
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func empty_board() -> void:
	g.board = []
	for i in 63: g.board.append({"id": "", "lock": 0})
func run() -> void:
	g = root.get_node("G"); replay = root.get_node("Replay")
	g.set_process(false); replay.set_process(false); root.get_node("Cloud").set_process(false)
	g.new_game(); g.tutorial_on = false; g.seen_tutorial = true; g.level = 10
	main = load("res://tools/RewardProbe.gd").new()
	root.add_child(main); main.show_screen("board", true)
	await process_frame
	var bs = main.board_screen
	for id in ["chest_1", "energybox_1", "choice_1"]:
		empty_board(); g.stash = [id]
		var rng_before: int = g.rng.state
		await bs._on_stash()
		check(g.stash.is_empty() and g.rules.board.cell_id(0) == id and not g.board[0].has("chest") and g.rng.state == rng_before, "%s leaves stash as an unopened physical box" % id)
	for cell in g.board: cell["id"] = "fruit_1"
	g.stash = ["chest_1"]
	await bs._on_stash()
	check(g.stash == ["chest_1"], "full board preserves the box in stash")
	empty_board(); g.stash = []; g.board[0]["id"] = "chest_1"
	var wallet: Array = [g.energy, g.shells, g.amber, g.rush]
	var first: Dictionary = await g.dispense_chest(0)
	check(not first.has("error") and first["remaining"] == 2 and g.rules.board.cell_id(0) == "chest_1" and g.rules.board.empty_count() == 61, "one tap releases exactly one physical item and keeps the chest")
	check(wallet == [g.energy, g.shells, g.amber, g.rush], "opening a chest does not redeem physical resource drops")
	var remaining: Array = g.board[0]["chest"].duplicate()
	check(g.try_drop(0, 5) == "move" and g.board[5]["chest"] == remaining and not g.board[0].has("chest"), "remaining contents follow a moved chest")
	g.inv = ["fruit_1"]; g.inv_chests = {}
	check(g.rules.board.store_cell(5) and g.inv_chests["1"] == remaining, "storage preserves a partially opened chest")
	check(g.rules.board.take_inventory(0, 2) and g.inv_chests["0"] == remaining, "taking an earlier storage item shifts the chest metadata")
	check(g.rules.board.take_inventory(0, 3) and g.board[3]["chest"] == remaining and g.inv_chests.is_empty(), "taking the chest back preserves its remaining drops")
	g.save_game(); g.load_game()
	check(g.board[3]["chest"] == remaining, "partial contents survive save and reload")
	bs.board.select(3); bs._on_delete(); bs._on_undo()
	check(g.rules.board.cell_id(3) == "chest_1" and g.board[3]["chest"] == remaining, "discard and undo preserve partial contents")
	var second: Dictionary = await g.dispense_chest(3)
	var last: Dictionary = await g.dispense_chest(3)
	check(second.get("id") == remaining[0] and last.get("id") == remaining[1] and last.get("to") == 3 and not g.board[3].has("chest"), "later taps preserve order and the final drop replaces the depleted box")
	for cell in g.board: cell["id"] = "fruit_1"
	g.board[0] = {"id": "energybox_1", "lock": 0}
	var blocked: Dictionary = await g.dispense_chest(0)
	check(blocked.has("error") and not g.board[0].has("chest"), "a full board cannot consume an unopened chest")
	g.board[0]["chest"] = ["fire_5"]
	var final_full: Dictionary = await g.dispense_chest(0)
	check(final_full.get("id") == "fire_5" and g.rules.board.cell_id(0) == "fire_5", "last drop can use the chest's own cell on a full board")
	# Exercise the actual replay branch and its existing flight dispatcher.
	replay.active = true; replay.authorized = true; replay.pending = []
	replay.clock = int(root.get_node("Cloud").server_now()); replay.seq = 0
	replay.meta = {"allow_gm": true}; g.random_seed = "chest-flight-check"; g.random_streams = {}
	for pair in [["fire_2", "energy", "energy"], ["shell_2", "shell", "shells"], ["amber_2", "amber", "amber"], ["sand_2", "sand", "rush"]]:
		empty_board(); g.board[0]["id"] = pair[0]; main.flights.clear()
		var before: int = g.get(pair[2])
		bs.board.select(0); await bs._on_activate(0)
		check(g.get(pair[2]) == before + Data.value_of(pair[0]) and g.rules.board.cell_id(0) == "", "%s collection credits its value once" % pair[0])
		check(main.flights.size() == 1 and main.flights[0]["id"] == pair[0] and main.flights[0]["from"].is_equal_approx(bs.board.cell_global(0)) and main.flights[0]["to"].is_equal_approx(main.topbar.target(pair[1])), "%s flies from its board cell to the matching resource bar" % pair[0])
	empty_board(); g.inv = []; g.inv_chests = {}; g.stash = ["energybox_1"]
	var fixture: Dictionary = replay.snapshot().duplicate(true)
	replay.pending = []
	await bs._on_stash()
	check(g.rules.board.cell_id(0) == "energybox_1" and not g.random_streams.has("chests"), "replay stash delivery does not open or roll a chest")
	bs.board._tap(0)
	await process_frame
	check(g.rules.board.cell_id(0) == "energybox_1" and g.board[0].get("chest", []) == ["fire_5", "fire_5"], "replay UI releases only the first energy item")
	g.try_drop(0, 7)
	bs._on_drop_outside(7, bs._pouch.get_global_rect().get_center())
	replay.perform("inventory", {"index": 0})
	await bs._on_activate(0); await bs._on_activate(0)
	check(g.rules.board.cell_id(0) == "fire_5" and not g.board[0].has("chest") and g.inv.is_empty(), "replay move, storage and later clicks preserve all three fixed drops")
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--output="): continue
		var ops := []
		for entry in replay.pending:
			var op: Dictionary = entry.duplicate(true); op.erase("hash"); ops.append(op)
		var file := FileAccess.open(arg.trim_prefix("--output="), FileAccess.WRITE)
		file.store_string(JSON.stringify({"before": fixture, "ops": ops, "hash": replay.digest()})); file.close()
	main.free(); g.main = null
	print("RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
