extends SceneTree
## Graded packs and deferred items use current commands, never mutable shared config.
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func run() -> void:
	var g = root.get_node("G")
	var replay = root.get_node("Replay")
	var data = load("res://scripts/Data.gd")
	g.set_process(false); replay.set_process(false); root.get_node("Cloud").set_process(false)
	replay.active = true; replay.worker = true; replay.authorized = true; replay.executing = true
	g.simulation_time = 1793577600.0; replay.clock = int(g.simulation_time)
	replay.meta = {"allow_gm": false}; g.replay_meta = replay.meta
	g.new_game(); g.tutorial_on = false; g.seen_tutorial = true; g.level = 7
	replay.advance(); replay.executing = false
	var configured: Dictionary = data.LEVEL_REWARDS
	data.LEVEL_REWARDS = configured.duplicate(true)
	data.LEVEL_REWARDS[7] = [["pack_1", 2], ["chest_1", 1], ["fire_2", 50]]
	check(data.level_rewards(7) == [["chest_1", 1], ["fire_2", 50]], "early rewards exclude packs without changing other quantities")
	check(data.LEVEL_REWARDS[7][0] == ["pack_1", 2], "preview does not mutate its isolated configuration fixture")
	data.LEVEL_REWARDS[8] = [["pack_1", 2]]
	check(data.level_rewards(8) == [["pack_1", 2]], "level eight configured packs remain claimable")
	data.LEVEL_REWARDS = configured
	for level in range(2, 8):
		check(not data.level_rewards(level).any(func(row): return data.type_of(str(row[0])) == "pack"), "no packs before card unlock at level %d" % level)
	for cell in g.board: cell["id"] = "fruit_1"; cell["lock"] = 0
	g.stash = ["fruit_3", "pack_1", "fire_4", "pack_1"]
	var energy: int = g.energy
	check(not replay.perform("stash", {"index": g.rules.board.stash_claim_index()}).has("error") and g.energy == energy + data.value_of("fire_4"), "full board collects resources behind locked packs")
	check(replay.perform("stash", {"index": g.rules.board.stash_claim_index()}).has("error") and g.stash == ["fruit_3", "pack_1", "pack_1"], "full board preserves the next physical reward")
	g.board[0]["id"] = ""
	check(not replay.perform("stash", {"index": g.rules.board.stash_claim_index()}).has("error") and g.rules.board.cell_id(0) == "fruit_3", "physical reward skips locked packs and reaches the free cell")
	check(g.rules.board.stash_claim_index() == -1 and replay.perform("pack", {"stash": 0}).has("error") and g.stash == ["pack_1", "pack_1"], "locked-only stash keeps every pack and opens no cards")
	g.stash = ["chest_1", "pack_1"]; g.board[0]["id"] = ""
	check(not replay.perform("stash", {"index": 0}).has("error") and g.rules.board.cell_id(0) == "chest_1" and g.stash == ["pack_1"], "stored chest becomes a physical board object without opening early")
	g.stash = ["pack_1", "pack_1"]
	var saved: Dictionary = replay.snapshot().duplicate(true)
	g.stash = []
	check(replay.restore(JSON.parse_string(JSON.stringify(saved))) and g.stash == ["pack_1", "pack_1"] and g.rules.board.stash_claim_index() == -1, "deferred packs roundtrip through the strict current snapshot")
	g.level = 8
	check(g.rules.board.stash_claim_index() == 1, "stored packs unlock automatically at level eight")
	check(not replay.perform("pack", {"stash": 1}).has("error") and g.stash == ["pack_1"], "opening an unlocked pack consumes exactly one")
	g.level = 1; g.stash = ["pack_1"]
	replay.meta["allow_gm"] = true
	check(not replay.perform("gm").has("error") and g.rules.board.stash_claim_index() == 0, "authorized GM opens deferred packs below the ordinary level gate")
	check(not replay.perform("pack", {"stash": 0}).has("error") and g.stash.is_empty(), "GM pack opening uses the same current reducer without a level override")
	print("RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
