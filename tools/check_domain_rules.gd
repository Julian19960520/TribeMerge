extends SceneTree
## Current-format state boundaries and shared domain invariants.
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1

func clear_board(g) -> void:
	g.board = []
	for _i in g.COLS * g.ROWS:
		g.board.append({"id": "", "lock": 0})

func run() -> void:
	var g = root.get_node("G")
	var replay = root.get_node("Replay")
	g.set_process(false)
	replay.set_process(false)
	root.get_node("Cloud").set_process(false)
	replay.executing = true
	g.simulation_time = 1794240000.0
	g.rng.seed = 42
	g.new_game()
	check(g.orders[0]["uid"] != g.orders[1]["uid"], "initial orders have distinct stable identities")
	var twin_a: Dictionary = g.order_identity({"items": ["fruit_2"]})
	var twin_b: Dictionary = g.order_identity({"items": ["fruit_2"]})
	check(twin_a["uid"] != twin_b["uid"], "identical new orders retain distinct identities without UI mutation")
	g.tutorial_on = false
	g.seen_tutorial = true
	clear_board(g)
	g.board[0]["id"] = "fruit_2"
	g.board[1]["id"] = "fruit_2"
	check(g.try_drop(0, 1) == "merge" and g.rules.board.cell_id(1) == "fruit_3", "shared board rules merge the intended cells")
	check(g.rules.orders.board_has("fruit_3") == 1 and g.discovered.has("fruit_3"), "merged results enter the discovery ledger")
	g.amber = 100
	g.energy_buys = 0
	var price: int = g.rules.progression.energy_price()
	check(g.buy_energy() and g.amber == 100 - price and g.energy_buys == 1, "economy purchase spends once and advances daily pricing")
	var wallet: int = g.amber
	g.amber = 0
	check(not g.buy_energy() and g.energy_buys == 1 and g.amber == 0, "insufficient funds leave purchase state unchanged")
	check(not g.rules.progression.spend("amber", -100) and not g.rules.progression.spend("unknown", 1) and g.amber == 0, "invalid currency spends cannot create resources")
	g.amber = wallet
	g.orders = [{"who": 0, "items": ["fruit_3"], "rw": {"shell": 10}}]
	check(g.rules.orders.order_ready(g.orders[0]) and g.rules.orders.order_cells(g.orders[0]) == [1], "order rules use the real matching board cell")
	var local_before: Dictionary = g.settings.duplicate(true)
	var snapshot: Dictionary = g.business_snapshot().duplicate(true)
	check(int(snapshot["schema"]) == 1 and not snapshot.has("settings") and not snapshot.has("replay_local") and not snapshot.has("tiger_escape_seen"), "business snapshots exclude all local presentation and transport state")
	var with_local: Dictionary = g.save_dict()
	check(with_local.has("settings") and with_local.has("replay_local"), "checkpoints include local state explicitly")
	g.amber += 50
	check(g.load_snapshot(snapshot) and g.amber == wallet and g.settings == local_before, "strict restore changes only business state")
	var broken: Dictionary = snapshot.duplicate(true)
	broken.erase("orders")
	var before: Dictionary = g.business_snapshot().duplicate(true)
	check(not g.load_snapshot(broken) and g.business_snapshot() == before, "missing current fields are rejected atomically")
	broken = snapshot.duplicate(true)
	broken["schema"] = 0
	check(not g.load_snapshot(broken), "unsupported snapshot formats are rejected without migration")
	broken = snapshot.duplicate(true)
	broken["board"][0]["id"] = "xp_1"
	check(not g.load_snapshot(broken), "numeric rewards cannot be restored as physical board objects")
	var encoded: Dictionary = JSON.parse_string(JSON.stringify(snapshot))
	check(g.load_snapshot(encoded) and typeof(g.board[0]["lock"]) == TYPE_INT, "JSON snapshot restore normalizes nested integer values")
	g.random_streams = {}
	g.random_seed = "domain-test"
	var first: int = g.random_for("cards").randi()
	g.random_for("produce:basket_5").randi()
	g.random_streams = {}
	check(g.random_for("cards").randi() == first, "separate random systems preserve their own sequence")
	var seen := []
	g.presentation_event.connect(func(kind, _payload): seen.append(kind))
	g.set_block_signals(true)
	g.present("notice", {"text": "queued"})
	check(seen.is_empty(), "domain presentation waits while a command is uncommitted")
	g.set_block_signals(false)
	g.flush_presentations()
	check(seen == ["notice"], "committed semantic presentation is delivered once")
	g.set_block_signals(true)
	g.present("notice", {"text": "rollback"})
	g.clear_presentations()
	g.set_block_signals(false)
	g.flush_presentations()
	check(seen == ["notice"], "rollback discards all uncommitted presentation")
	print("RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
