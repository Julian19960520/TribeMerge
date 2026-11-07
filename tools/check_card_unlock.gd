extends SceneTree
var failures: Array = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures.append(label)
func run() -> void:
	var g = root.get_node("G")
	var data = load("res://scripts/Data.gd")
	g.new_game()
	g.set_process(false)
	g.tutorial_on = false
	g.seen_tutorial = true
	g.level = 7
	var configured: Dictionary = data.LEVEL_REWARDS.duplicate(true)
	data.LEVEL_REWARDS[7] = [["pack_1", 2], ["chest_1", 1], ["fire_2", 50]]
	check(data.level_rewards(7) == [["chest_1", 1], ["fire_2", 50]], "configured early level rewards exclude packs without changing other quantities")
	check(data.LEVEL_REWARDS[7][0] == ["pack_1", 2], "reward preview does not mutate configuration")
	data.LEVEL_REWARDS[8] = [["pack_1", 2]]
	check(data.level_rewards(8) == [["pack_1", 2]], "level eight configured packs remain claimable")
	data.LEVEL_REWARDS = configured
	for level in range(2, 8):
		check(not data.level_rewards(level).any(func(r): return data.type_of(str(r[0])) == "pack"), "no packs before card unlock at level %d" % level)
	var main = load("res://tools/RewardProbe.gd").new()
	root.add_child(main)
	main.show_screen("board", true)
	for i in g.board.size(): g.board[i] = {"id": "fruit_1", "lock": 0}
	g.stash = ["fruit_3", "pack_1", "fire_4", "pack_1"]
	var energy: int = g.energy
	await main.board_screen._on_stash()
	check(g.energy == energy + data.value_of("fire_4") and g.stash == ["fruit_3", "pack_1", "pack_1"], "full board can collect currency behind locked packs")
	await main.board_screen._on_stash()
	check(g.stash == ["fruit_3", "pack_1", "pack_1"], "full board never loses the next physical reward")
	g.board[0]["id"] = ""
	await main.board_screen._on_stash()
	check(g.board[0]["id"] == "fruit_3" and g.stash == ["pack_1", "pack_1"], "physical reward skips locked packs and reaches empty cell")
	await main.board_screen._on_stash()
	check(g.stash == ["pack_1", "pack_1"] and g.cards.is_empty(), "locked-only stash keeps every pack and opens no cards")
	g.stash = ["chest_1", "pack_1"]
	await main.board_screen._on_stash()
	check(not g.stash.has("chest_1") and g.stash.count("pack_1") == 1 and g.stash.size() > 1, "chest behind a locked pack opens with full-board overflow preserved")
	g.stash = ["pack_1", "pack_1"]
	g.save_game()
	g.stash = []
	g.load_game()
	check(g.stash == ["pack_1", "pack_1"] and g.stash_claim_index() == -1, "deferred packs survive save and reload")
	g.level = 8
	check(g.stash_claim_index() == 1, "stored packs unlock automatically at level eight")
	await main.board_screen._on_stash()
	check(g.stash == ["pack_1"], "opening an unlocked pack consumes exactly one")
	main.queue_free()
	await process_frame
	g.main = null
	print("RESULT: ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
