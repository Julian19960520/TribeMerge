extends SceneTree
var failures := 0
var fossil

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1

func run() -> void:
	fossil = load("res://scripts/events/FossilDig.gd")
	var g = root.get_node("G")
	var replay = root.get_node("Replay")
	g.set_process(false); replay.set_process(false)
	g.new_game(); g.tutorial_on = false; g.seen_tutorial = true
	g.random_seed = "fossil-tests"; g.random_streams = {}
	check(fossil.state().is_empty(), "viewing entry state does not mutate a save")
	fossil.local_action("refresh")
	var b: Dictionary = fossil.board()
	check(b["n"] == 3 and b["pieces"].size() == 2, "first stage is 3 by 3 with two bones")
	check(fossil.local_action("dig", 0).has("error") and b["dug"].is_empty(), "no shovel cannot expose a cell")
	var other_stream: int = g.random_for("cards").state
	var layouts := []
	var layouts_valid := true
	for seed in ["alpha", "beta", "gamma", "delta"]:
		for stage in range(1, 11):
			var layout: Dictionary = fossil.make_board(seed, stage)
			if layout.is_empty(): layouts_valid = false; continue
			var occupied := {}
			for p in layout["pieces"]:
				for cell in fossil.piece_cells(p, int(layout["n"])):
					if cell < 0 or cell >= int(layout["n"]) * int(layout["n"]) or occupied.has(cell): layouts_valid = false
					occupied[cell] = true
			if layout["n"] != stage + 2 or layout["pieces"].size() != stage + 1: layouts_valid = false
			layouts.append({"seed": seed, "stage": stage, "board": layout})
	check(layouts_valid, "all ten growing stages place every bone inside the grid without overlaps across four seeds")
	check(g.random_for("cards").state == other_stream, "fossil layouts do not advance the card random stream")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--layouts="):
			var f := FileAccess.open(arg.trim_prefix("--layouts="), FileAccess.WRITE)
			f.store_string(JSON.stringify(layouts)); f.close()
	# Exercise the actual main board completion hook, including a failed order.
	for cell in g.board.size(): g.board[cell] = {"id": "", "lock": 0}
	g.orders = [{"who": 2, "items": ["fruit_1"], "rw": {"shell": 1}, "story": false}]
	g.complete_order(0)
	check(fossil.state()["shovels"] == 0, "incomplete main-board order earns no shovels")
	g.board[0]["id"] = "fruit_1"
	g.complete_order(0)
	check(fossil.state()["shovels"] == 3, "accepted main-board order earns exactly three shovels")
	g.board[2]["id"] = "fruit_1"; g.board[3]["id"] = "fruit_1"
	g.try_drop(2, 3)
	check(fossil.state()["shovels"] == 3, "merges do not earn order shovels")
	var occupied := {}
	for p in b["pieces"]:
		for cell in fossil.piece_cells(p, 3): occupied[cell] = true
	for cell in 9:
		if not occupied.has(cell):
			fossil.local_action("dig", cell)
			check(fossil.state()["shovels"] == 2 and fossil.state()["recovered"] == 0, "empty soil consumes one shovel without awarding a bone")
			break
	g.fossil_dig["shovels"] = 100
	var first: Array = fossil.piece_cells(b["pieces"][0], 3)
	fossil.local_action("dig", int(first[0]))
	check(not b["pieces"][0]["found"] and fossil.state()["recovered"] == 0, "partial exposure does not collect a bone")
	var before := JSON.stringify(fossil.state())
	check(fossil.local_action("dig", int(first[0])).has("error") and JSON.stringify(fossil.state()) == before, "repeat dig cannot spend another shovel or score again")
	check(fossil.local_action("next").has("error"), "partial stage cannot be skipped")
	check(fossil.local_action("claim", 2).has("error"), "future milestone cannot be claimed")
	for cell in first:
		if not cell in b["dug"]: fossil.local_action("dig", int(cell))
	check(b["pieces"][0]["found"] and fossil.state()["recovered"] == 1, "complete exposure collects exactly one bone")
	for p in b["pieces"]:
		for cell in fossil.piece_cells(p, 3):
			if not cell in b["dug"]: fossil.local_action("dig", int(cell))
	check(fossil.cleared() and fossil.state()["recovered"] == 2, "stage completes when all bones are found without digging all empty cells")
	var shells_before: int = g.shells
	var result: Dictionary = await fossil.act("claim", 2)
	check(not result.has("error") and g.shells == shells_before + 100, "milestone grants its configured currencies through the common reward function")
	check(fossil.local_action("claim", 2).has("error"), "claimed milestone cannot pay twice")
	var saved: Dictionary = g.business_snapshot().duplicate(true)
	g.fossil_dig = {}; g.load_snapshot(saved)
	check(fossil.cleared() and fossil.state()["claimed"] == [2] and fossil.state()["recovered"] == 2, "snapshot reload preserves uncovered cells, collected bones and claimed rewards")
	var shovels: int = fossil.state()["shovels"]
	fossil.local_action("next")
	check(fossil.board()["n"] == 4 and fossil.board()["pieces"].size() == 3 and fossil.state()["shovels"] == shovels, "next stage grows one row and column and adds a bone while retaining unused shovels")
	# Full client-command journal is replayed by the independent production worker.
	replay.active = true; replay.authorized = true; replay.worker = false; replay.pending = []; replay.meta = {"allow_gm": true}; replay.seq = 0; replay.clock = 1794268800
	g.new_game(); g.tutorial_on = false; g.seen_tutorial = true
	g.random_seed = "fossil-worker"; g.random_streams = {}
	for cell in g.board.size(): g.board[cell] = {"id": "", "lock": 0}
	for i in 9: g.board[i]["id"] = "fruit_1"
	g.orders = [{"who": 2, "items": ["fruit_1"], "rw": {"shell": 1}, "story": false}]
	fossil.local_action("refresh")
	g.fossil_dig["shovels"] = 12; g.fossil_dig["earned"] = 12
	var initial: Dictionary = replay.snapshot().duplicate(true)
	replay.perform("order", {"cell": 0}, replay.clock)
	replay.perform("fossil", {"action": "refresh"}, replay.clock)
	for p in fossil.board()["pieces"]:
		for cell in fossil.piece_cells(p, 3):
			replay.perform("fossil", {"action": "dig", "value": cell}, replay.clock)
	replay.perform("fossil", {"action": "claim", "value": 2}, replay.clock)
	replay.perform("fossil", {"action": "next"}, replay.clock)
	var request := {"data": initial, "ops": replay.pending.duplicate(true)}
	var input := "/tmp/fossil-worker-input.json"
	var output := "/tmp/fossil-worker-output.json"
	var file := FileAccess.open(input, FileAccess.WRITE); file.store_string(JSON.stringify(request)); file.close()
	var stdout: Array = []
	var exit_code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://scripts/replay/worker.gd", "--", "--cloud-off", "--replay-worker", "--save=user://fossil-worker-test.json", "--input=" + input, "--output=" + output], stdout, true)
	var verified = JSON.parse_string(FileAccess.get_file_as_string(output))
	check(exit_code == 0 and verified is Dictionary and verified.get("ok", false) and verified.get("hash", "") == replay.digest(), "independent headless server worker reproduces order shovels, digging and their exact save hash")
	# The appended wire code must remain encodable without shifting existing codes.
	var wire = preload("res://scripts/net/ReplayWire.gd").encode({"base": 0, "rules": "0".repeat(64), "hash": replay.digest(), "batch": "1".repeat(32), "ops": replay.pending})
	check(not wire.is_empty(), "new fossil commands use the compact replay wire format")
	print("RESULT ", failures, " failures")
	quit(0 if failures == 0 else 1)
