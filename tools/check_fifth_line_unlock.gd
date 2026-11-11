extends SceneTree
## Boundary behavior and recovery of the preceding release's fifth-line journal.
const Store := preload("res://scripts/replay/Journal.gd")
const Upgrade := preload("res://scripts/storage/FifthLineUpgrade.gd")
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func run() -> void:
	for node in root.get_children(): node.set_process(false)
	var replay = root.get_node("Replay")
	var game = root.get_node("G")
	var phase := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="): phase = arg.trim_prefix("--phase=")
	var expected_path: String = game.save_path + ".expected"
	if phase == "write":
		var current := Upgrade.begin()
		replay.executing = true
		replay.seq = 0; replay.base = 0; replay.pending = []; replay.inflight = {}
		replay.clock = 1794240000; replay.meta = {"allow_gm": true}
		game.random_seed = "fifth-line-upgrade"; game.random_streams = {}
		game.new_game(); game.player_id = "fifth-line-existing-player"
		game.level = 23; game.seen_tutorial = true; game.tutorial_on = false
		game.shells = 100000; game.stash = ["basket_5"]
		game.orders = []; game.pending_orders = []
		game.rules.orders.refill_orders()
		replay.advance(); replay._canonicalize_live(); replay.executing = false
		game.clear_presentations(); replay.snapshot()
		if not replay.checkpoint(): quit(1); return
		var checkpoint: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.save_path))
		for level in [21, 23]:
			var result: Dictionary = replay.perform("level", {"level": level}, replay.clock)
			if result.has("error"): quit(1); return
		if game.stash.count("hearth_4") != 2: quit(1); return
		var file := FileAccess.open(expected_path, FileAccess.WRITE)
		file.store_string(replay.digest()); file.flush(); file.close()
		checkpoint["replay_local"]["rules"] = Upgrade.FROM_RULES
		if Store.write_checkpoint(game.save_path, checkpoint) != OK: quit(1); return
		Upgrade.finish(current)
		check(true, "prepared old 23-level state and pending fifth-line rewards")
	elif phase == "read":
		check(replay.digest() == FileAccess.get_file_as_string(expected_path) and replay.recovery_error == "" and replay.authorized, "old checkpoint and pending rewards recover exactly")
		check(game.level == 23 and game.player_id == "fifth-line-existing-player" and game.stash.count("hearth_4") == 2, "existing progress and owned generators remain")
		check(replay.pending.is_empty() and replay.journal()["rules"] == replay.rules_hash(), "upgrade creates a current-rule checkpoint")
		check(Data.unlocked_lines(23).size() == 4 and Data.unlocked_lines(24).size() == 5, "fifth line opens at 24 rather than 23")
		check(not game.rules.progression.build_open("cook"), "fifth-line building stays closed at 23")
		var before_boundary := true
		for lv in range(1, 24):
			for reward in Data.level_rewards(lv):
				if Data.chain(str(reward[0])) == "hearth": before_boundary = false
			for order in Data.story_orders(lv):
				for id in order["items"]:
					if Data.chain(str(id)) in ["veg", "roast"]: before_boundary = false
			for recipe in Data.dishes_for(lv):
				for id in recipe["mats"]:
					if Data.chain(str(id)) in ["veg", "roast"]: before_boundary = false
		check(before_boundary and not Data.product_open(23, "veg") and not Data.product_open(23, "roast"), "pre-24 rewards, story, recipes and random-order pools exclude the fifth line")
		game.level = 24
		check(game.rules.progression.build_open("cook") and Data.product_open(24, "veg") and Data.product_open(24, "roast"), "24-level products and building open together")
		var count: int = game.stash.count("hearth_4")
		var fresh: Dictionary = replay.perform("level", {"level": 24}, replay.clock)
		check(not fresh.has("error") and game.stash.count("hearth_4") == count + 1, "24-level reward grants exactly one level 4 generator")
		var duplicate: Dictionary = replay.perform("level", {"level": 24}, replay.clock)
		check(duplicate.has("error") and game.stash.count("hearth_4") == count + 1, "24-level generator cannot be claimed twice")
		check(not Data.gen_stats("hearth_4").is_empty(), "the granted level 4 generator can produce immediately")
		var parts: int = 0
		for part in Data.build_parts(Data.build_def("cook")):
			for reward in part["rewards"]:
				if Data.chain(str(reward[0])) == "hearth": parts += int(reward[1]) * (1 << (Data.lv(str(reward[0])) - 1))
		check(8 + parts >= 16 and Data.gen_stats("hearth_5")["drops"].any(func(drop): return Data.chain(str(drop["id"])) == "roast"), "available building rewards can upgrade the starter to produce roast without later level rewards")
	else: quit(2); return
	quit(0 if failures == 0 else 1)
