extends SceneTree
var failures := 0
var g
var replay
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func clear_board() -> void:
	g.board = []
	for _i in 63: g.board.append({"id": "", "lock": 0})
func run() -> void:
	g = root.get_node("G"); replay = root.get_node("Replay")
	g.new_game(); g.set_process(false); replay.set_process(false); root.get_node("Cloud").set_process(false)
	g.level = 10; g.seen_tutorial = true; g.tutorial_on = false
	check(Data.max_lv("pack") == 5 and Data.max_lv("orderbox") == 10, "five pack grades and ten order chest grades are registered")
	for grade in range(1, 6):
		var id := "pack_%d" % grade
		var chances := CardPacks.probabilities(id)
		var sum := 0.0
		for p in chances: sum += float(p)
		check(is_equal_approx(sum, 1.0), "%s chances are normalized to 100 percent" % id)
		var cursor := 0.0
		for star in chances.size():
			if float(chances[star]) > 0: check(CardPacks.star_at_roll(id, cursor + float(chances[star]) * 0.5) == star + 1, "%s maps its %d-star probability interval" % [id, star + 1])
			cursor += float(chances[star])
		clear_board(); g.stash = [id]; g.cards = {}
		var drawn: Array = await g.open_pack(id)
		var valid: bool = drawn.size() == 2 and g.stash.is_empty()
		for card in drawn: valid = valid and float(chances[CardPacks.stars(card[0], card[1]) - 1]) > 0
		check(valid, "%s consumes the right pack and draws two cards from allowed star pools" % id)
	clear_board(); g.board[0]["id"] = "pack_1"; g.board[1]["id"] = "pack_1"
	check(g.try_drop(0, 1) == "merge" and g.rules.board.cell_id(1) == "pack_2", "two unopened card packs merge to the next grade")
	for grade in range(1, 11):
		check(SpecialChests.contents("orderbox_%d" % grade).size() == int(SpecialChests.config()["orderbox"]["levels"][grade - 1]["count"]), "order chest %d has its configured number of uses" % grade)
	var low := SpecialChests.order_weights("orderbox_1", {"fruit_2": 1, "fruit_8": 1})
	var high := SpecialChests.order_weights("orderbox_10", {"fruit_2": 1, "fruit_8": 1})
	check(float(high["fruit_8"]) / float(high["fruit_2"]) > float(low["fruit_8"]) / float(low["fruit_2"]), "higher chest grades favor higher-level order requirements")
	clear_board(); g.inv = []; g.inv_chests = {}; g.stash = []
	g.orders = [{"items": ["fruit_2", "tool_3"], "who": 0, "rw": {"shell": 1}}]
	g.board[0]["id"] = "orderbox_1"
	var first: Dictionary = await g.dispense_chest(0)
	check(str(first.get("id", "")) in ["fruit_2", "tool_3"] and first.get("remaining") == 1, "order chest releases one currently missing item")
	g.orders = [{"items": ["seed_3"], "who": 0, "rw": {"shell": 1}}]
	var next: Dictionary = await g.dispense_chest(0)
	check(next.get("id") == "seed_3" and g.rules.board.cell_id(0) == "seed_3", "next chest click adapts to changed orders and uses the last slot")
	clear_board(); g.orders = [{"items": ["fruit_6"], "who": 0, "rw": {"shell": 1}}]
	g.board[0]["id"] = "orderbox_5"
	await g.dispense_chest(0)
	var left: Array = g.board[0]["chest"].duplicate()
	var blocked: Dictionary = await g.dispense_chest(0)
	check(blocked.has("error") and g.board[0]["chest"] == left, "satisfied orders preserve all unused chest charges")
	check(g.rules.board.store_cell(0) and g.rules.board.take_inventory(0, 0) and g.board[0]["chest"] == left, "order chest charges survive storage")
	var premium: Array = await g.rules.board.open_chest("premiumbox_1")
	check(premium.size() == 8 and Data.chain(premium[0]) == "fire" and Data.chain(premium[1]) == "amber" and premium.all(func(id): return Data.chain(id) in ["fire", "amber"] and Data.lv(id) >= 2 and Data.lv(id) <= 6), "premium chest contains eight physical energy and gem drops across valid grades")
	clear_board(); g.board[0]["id"] = "premiumbox_1"
	var wallet := [g.energy, g.amber]
	for i in 8: await g.dispense_chest(0)
	check(g.rules.board.empty_count() == 55 and wallet == [g.energy, g.amber] and Data.type_of(g.rules.board.cell_id(0)) in ["energy", "amber"], "premium chest emits one object per click and does not redeem resources automatically")
	for target in ["fruit_4", "basket_4", "pack_4", "orderbox_4", "fire_5"]:
		clear_board(); g.board[0]["id"] = "upgrade_1"; g.board[1]["id"] = target
		var higher := Data.next_id(target)
		check(g.try_drop(0, 1) == "upgrade" and g.rules.board.cell_id(0) == "" and g.rules.board.cell_id(1) == higher, "upgrade tool raises %s by one level and is consumed" % target)
	clear_board(); g.board[0]["id"] = "upgrade_1"; g.board[1]["id"] = "fire_6"
	check(g.try_drop(0, 1) == "" and g.rules.board.cell_id(0) == "upgrade_1", "maximum-level targets keep the upgrade tool")
	for target in ["fruit_5", "basket_5", "pack_5", "orderbox_5", "fire_5"]:
		for cell in g.board: cell["id"] = "fruit_1"
		g.board[0]["id"] = "scissors_1"; g.board[1]["id"] = target
		var lower := "%s_%d" % [Data.chain(target), Data.lv(target) - 1]
		check(g.try_drop(0, 1) == "split" and g.rules.board.cell_id(0) == lower and g.rules.board.cell_id(1) == lower and g.rules.board.empty_count() == 0, "scissors split %s safely on a full board" % target)
	clear_board(); g.board[0]["id"] = "scissors_1"; g.board[1]["id"] = "fruit_1"
	check(g.try_drop(0, 1) == "" and g.rules.board.cell_id(0) == "scissors_1" and g.rules.board.cell_id(1) == "fruit_1", "first-level targets keep the scissors")
	for tool in ["upgrade_1", "scissors_1"]:
		for state in [{"lock": 1}, {"lock": 3, "bubble": {"expires": g.now() + 60}}, {"ck": {"t0": g.now(), "secs": 60}}]:
			clear_board(); g.board[0]["id"] = tool; g.board[1]["id"] = "fruit_4"
			g.board[1].merge(state, true)
			check(g.try_drop(0, 1) == "" and g.rules.board.cell_id(0) == tool and g.rules.board.cell_id(1) == "fruit_4", "%s preserves blocked targets and its own use" % tool)
		clear_board(); g.board[0]["id"] = tool
		check(g.try_drop(0, 1) == "move" and g.rules.board.cell_id(1) == tool, "%s moves normally onto an empty cell" % tool)
	clear_board(); g.board[0]["id"] = "upgrade_1"; g.board[1] = {"id": "orderbox_2", "lock": 0, "chest": [SpecialChests.ORDER_SLOT]}
	check(g.try_drop(0, 1) == "" and g.rules.board.cell_id(0) == "upgrade_1", "opened chests cannot be refilled using upgrade tools")
	g.board[0]["id"] = "scissors_1"
	check(g.try_drop(0, 1) == "" and g.rules.board.cell_id(0) == "scissors_1", "opened chests cannot duplicate their remaining contents")
	g.board[0] = {"id": "orderbox_2", "lock": 0}
	check(g.try_drop(0, 1) != "merge" and g.board[0].get("chest", []).size() + g.board[1].get("chest", []).size() == 1, "partially opened chests cannot merge into a full higher-level box")
	# A real offline command sequence for independent worker replay.
	clear_board(); g.inv = []; g.inv_chests = {}; g.stash = ["pack_5"]
	g.orders = [{"items": ["fruit_6", "tool_6", "seed_4"], "who": 0, "rw": {"shell": 1}}]
	for pair in [[0, "upgrade_1"], [1, "fruit_4"], [2, "scissors_1"], [3, "tool_5"], [4, "orderbox_2"], [5, "premiumbox_1"], [9, "pack_4"], [10, "upgrade_1"]]: g.board[pair[0]]["id"] = pair[1]
	replay.active = true; replay.authorized = true; replay.clock = int(root.get_node("Cloud").server_now()); replay.seq = 0; replay.meta = {"allow_gm": true}; replay.pending = []
	g.random_seed = "new-loot-replay"; g.random_streams = {}
	var fixture: Dictionary = replay.snapshot().duplicate(true)
	check(g.try_drop(0, 1) == "upgrade" and g.try_drop(2, 3) == "split", "offline replay executes both tool operations")
	await g.open_pack("pack_5", -1, 0)
	await g.dispense_chest(4); await g.dispense_chest(5)
	replay.perform("store", {"cell": 4}); replay.perform("inventory", {"index": 0})
	g.try_drop(0, 8)
	g.try_drop(10, 9); await g.open_pack("pack_5", 9)
	check(g.cards.values().reduce(func(total, n): return int(total) + int(n), 0) > 0 and g.inv.is_empty(), "new content works through the shared offline reducer")
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--output="): continue
		var ops := []
		for entry in replay.pending:
			var op: Dictionary = entry.duplicate(true); op.erase("hash"); ops.append(op)
		var file := FileAccess.open(arg.trim_prefix("--output="), FileAccess.WRITE)
		file.store_string(JSON.stringify({"before": fixture, "ops": ops, "hash": replay.digest()})); file.close()
	print("RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
