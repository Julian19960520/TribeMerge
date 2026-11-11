extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(condition: bool, label: String) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition: failures += 1
func run() -> void:
	var game = root.get_node("G")
	var replay = root.get_node("Replay")
	var rewards = load("res://scripts/Rewards.gd")
	game.set_process(false); replay.set_process(false); root.get_node("Cloud").set_process(false)
	replay.active = true; replay.worker = true; replay.executing = true
	game.new_game(); game.tutorial_on = false; game.seen_tutorial = true; game.level = 8
	load("res://scripts/events/ActivityRules.gd").initialize()
	check(not Data.CHAINS.has("xp") and not Data.CHAINS.has("token") and Data.REWARD_RESOURCES.size() == 2, "numeric rewards are separate from mergeable chains")
	check(Data.type_of("xp_1") == "xp" and Data.type_of("token_1") == "token" and not Data.is_board_item("xp_1"), "numeric reward IDs cannot be placed on boards")
	for flag in ["item", "physical"]:
		game.xp = 0; game.tokens = 0; game.token_claimed = 0; game.stash = []
		for cell in game.board: cell["id"] = ""
		rewards.settle([["xp_1", 1, flag], ["token_1", 2, flag]], {"board_origin": 0})
		check(game.xp == 1 and game.tokens == 2 and game.stash.is_empty() and game.rules.orders.board_has("xp_1") < 0 and game.rules.orders.board_has("token_1") < 0, "%s flag cannot turn numeric rewards into board objects" % flag)
	game.tokens = 0; game.token_claimed = 0
	rewards.settle([["token_1", 20, "physical"]], {"board_origin": 0})
	check(game.stash.count("pack_1") == 2 and not game.stash.has("token_1"), "numeric points create real card packs")
	var snapshot: Dictionary = game.business_snapshot().duplicate(true)
	check(game.load_snapshot(JSON.parse_string(JSON.stringify(snapshot))), "current snapshot roundtrips through JSON")
	for field in ["board", "inv", "stash"]:
		var invalid: Dictionary = snapshot.duplicate(true)
		if field == "board": invalid["board"][0] = {"id": "xp_1", "lock": 0}
		else: invalid[field] = ["token_1"]
		var before: Dictionary = game.business_snapshot().duplicate(true)
		check(not game.load_snapshot(invalid) and game.business_snapshot() == before, "strict snapshot rejects numeric objects in %s without migration" % field)
	replay.executing = false
	game.clear_presentations()
	print("RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
