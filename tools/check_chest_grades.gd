extends SceneTree
## Validate every graded chest through the current shared reducer and snapshot format.
var failures := 0
var g
var replay

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1

func clear_board() -> void:
	g.board = []
	for _i in g.COLS * g.ROWS: g.board.append({"id": "", "lock": 0})

func run() -> void:
	var art = load("res://scripts/Art.gd")
	var choice = load("res://scripts/events/ChoiceChest.gd")
	g = root.get_node("G")
	replay = root.get_node("Replay")
	g.set_process(false); replay.set_process(false); root.get_node("Cloud").set_process(false)
	root.get_node("Rank").set_process(false)
	g.simulation_time = 1793577600.0
	replay.active = true; replay.worker = true; replay.authorized = true; replay.executing = true
	replay.meta = {"allow_gm": true}; replay.seq = 0; replay.clock = int(g.simulation_time)
	g.replay_meta = replay.meta
	g.new_game(); g.level = 20; g.tutorial_on = false; g.seen_tutorial = true
	g.random_seed = "graded-chests"; g.random_streams = {}
	replay.advance(); replay.executing = false
	check(Data.name_of("shell_2") == "不拿拿" and Data.CHAINS["shell"]["name"] == "不拿拿", "currency and physical rewards use the current banana name")
	for chain in ["energybox", "premiumbox", "chest", "choice"]:
		check(Data.max_lv(chain) == 5, "%s has five grades" % chain)
		for grade in range(1, 6):
			var id := "%s_%d" % [chain, grade]
			check(not Data.describe(id).is_empty() and ResourceLoader.exists(art.vector_item(id)), "%s has a description and exported icon" % id)
			clear_board(); g.board[0]["id"] = id
			if chain == "choice":
				var picks: Array = choice.definition(id)["choices"]
				check(picks.size() == 3 and picks.all(func(item): return Data.is_board_item(str(item))), "%s offers three valid rewards" % id)
				for option in picks.size():
					clear_board(); g.board[0]["id"] = id
					var selected: Dictionary = replay.perform("choice", {"cell": 0, "option": option})
					check(not selected.has("error") and selected.get("id") == picks[option] and g.rules.board.cell_id(0) == picks[option], "%s choice %d delivers its configured physical reward once" % [id, option + 1])
			else:
				var count := SpecialChests.count(id)
				var wallet := [g.energy, g.amber, g.shells, g.rush]
				var valid := count > 0
				for index in count:
					var drop: Dictionary = replay.perform("tap", {"cell": 0})
					valid = valid and not drop.has("error") and int(drop.get("remaining", -1)) == count - index - 1 and Data.is_board_item(str(drop.get("id", "")))
				check(valid and g.rules.board.empty_count() == g.board.size() - count and wallet == [g.energy, g.amber, g.shells, g.rush], "%s dispenses all configured contents as physical items through commands" % id)
			clear_board(); g.board[0]["id"] = id; g.board[1]["id"] = id
			var merged: Dictionary = replay.perform("drop", {"from": 0, "to": 1})
			check(merged.get("kind") == "merge" and g.rules.board.cell_id(1) == "%s_%d" % [chain, grade + 1] if grade < 5 else merged.get("kind") != "merge", "%s follows the configured merge ceiling" % id)
	var previous := 0
	for grade in range(1, 6):
		var total := 0
		for id in SpecialChests.definition("energybox_%d" % grade)["items"]: total += Data.value_of(str(id))
		check(total > previous * 2, "energy chest %d rewards waiting to merge two lower boxes" % grade)
		previous = total
	clear_board(); g.board[0]["id"] = "energybox_5"; g.board[1]["id"] = "energybox_5"
	var first: Dictionary = replay.perform("tap", {"cell": 0})
	check(first.get("remaining") == 29 and first.get("id") == "fire_6", "highest energy box dispenses exactly one drop per tap")
	var left: Array = g.board[0]["chest"].duplicate()
	check(replay.perform("drop", {"from": 0, "to": 1}).get("kind") != "merge", "partially opened chests cannot merge to refresh contents")
	var chest_cell: int = 0 if g.board[0].has("chest") else 1
	g.inv = []; g.inv_chests = {}
	var stored: Dictionary = replay.perform("store", {"cell": chest_cell})
	var restored: Dictionary = replay.perform("inventory", {"index": 0})
	var destination := int(restored.get("to", -1))
	check(not stored.has("error") and destination >= 0 and g.board[destination]["chest"] == left, "high-grade partial contents survive storage commands")
	var snapshot: Dictionary = replay.snapshot().duplicate(true)
	g.board[destination].erase("chest")
	check(replay.restore(JSON.parse_string(JSON.stringify(snapshot))) and g.board[destination]["chest"] == left, "partial contents roundtrip in the strict current snapshot")
	for cell in g.board: cell["id"] = "fruit_1"
	g.board[0] = {"id": "premiumbox_5", "lock": 0}
	var random_before: Dictionary = g.random_save().duplicate(true)
	check(replay.perform("tap", {"cell": 0}).has("error") and not g.board[0].has("chest") and g.random_save() == random_before, "full board preserves unopened contents and random state")
	# Output a real current-client command sequence for independent server replay.
	clear_board(); g.inv = []; g.inv_chests = {}; g.stash = []
	for pair in [[0,"energybox_2"],[1,"energybox_2"],[5,"premiumbox_4"],[8,"chest_5"],[12,"choice_5"]]: g.board[pair[0]]["id"] = pair[1]
	replay.worker = false; replay.seq = 0; replay.meta = {"allow_gm": true}; replay.pending = []; replay.inflight = {}
	g.random_seed = "graded-chests-fixture"; g.random_streams = {}
	var fixture: Dictionary = replay.snapshot().duplicate(true)
	check(replay.checkpoint(), "independent replay fixture uses the current checkpoint and journal")
	for operation in [["drop", {"from": 0, "to": 1}], ["tap", {"cell": 1}], ["tap", {"cell": 5}], ["tap", {"cell": 8}], ["store", {"cell": 1}], ["inventory", {"index": 0}], ["choice", {"cell": 12, "option": 1}]]:
		check(not replay.perform(operation[0], operation[1]).has("error"), "graded replay command %s commits" % operation[0])
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--output="): continue
		var ops := []
		for entry in replay.pending:
			var op: Dictionary = entry.duplicate(true); op.erase("hash"); ops.append(op)
		var file := FileAccess.open(arg.trim_prefix("--output="), FileAccess.WRITE)
		file.store_string(JSON.stringify({"before": fixture, "ops": ops, "hash": replay.digest()})); file.close()
	print("RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
