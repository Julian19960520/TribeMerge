extends SceneTree
## An old offline checkpoint plus pending claims survives the reward retune.
const Store := preload("res://scripts/replay/Journal.gd")
const Upgrade := preload("res://scripts/storage/EarlyRewardUpgrade.gd")
const ConfigUpgrade := preload("res://scripts/storage/FifthLineUpgrade.gd")

func _initialize() -> void: run.call_deferred()

func run() -> void:
	for node in root.get_children(): node.set_process(false)
	var replay = root.get_node("Replay")
	var game = root.get_node("G")
	var phase := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--phase="): phase = argument.trim_prefix("--phase=")
	var expected_path: String = game.save_path + ".expected"
	if phase == "write":
		var current_config := ConfigUpgrade.begin()
		var current := Upgrade.begin()
		replay.executing = true
		replay.seq = 7; replay.base = 7; replay.pending = []; replay.inflight = {}
		replay.clock = 1794240000
		replay.meta = {"allow_gm": true, "level:2": true}
		game.random_seed = "early-rewards-upgrade"; game.random_streams = {}
		game.new_game()
		game.player_id = "early-rewards-existing-player"
		game.level = 23; game.seen_tutorial = true; game.tutorial_on = false
		game.shells = 100000; game.amber = 77
		game.builds = {"fire": 2, "gather": 1}
		game.stash = ["basket_7"]
		replay.advance(); replay._canonicalize_live(); replay.executing = false
		game.clear_presentations()
		replay.snapshot()
		if not replay.checkpoint(): quit(1); return
		var old_checkpoint: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.save_path))
		var claim: Dictionary = replay.perform("level", {"level": 19}, replay.clock)
		var build: Dictionary = replay.perform("build", {"id": "gather"}, replay.clock)
		if claim.has("error") or build.has("error") or game.stash.count("basket_4") != 1 or game.stash.count("basket_3") != 1:
			quit(1); return
		var file := FileAccess.open(expected_path, FileAccess.WRITE)
		file.store_string(replay.digest()); file.flush(); file.close()
		old_checkpoint["replay_local"]["rules"] = Upgrade.FROM_RULES
		if Store.write_checkpoint(game.save_path, old_checkpoint) != OK: quit(1); return
		Upgrade.finish(current)
		ConfigUpgrade.finish(current_config)
		print("PASS prepared old checkpoint and uncheckpointed reward claims")
		quit(0)
	elif phase == "read":
		var expected := FileAccess.get_file_as_string(expected_path)
		var valid: bool = expected != "" and replay.digest() == expected and replay.authorized and replay.pending.is_empty() and replay.recovery_error == ""
		valid = valid and replay.journal()["rules"] == replay.rules_hash() and game.player_id == "early-rewards-existing-player" and game.level == 23
		valid = valid and game.stash.count("basket_7") == 1 and game.stash.count("basket_4") == 1 and game.stash.count("basket_3") == 1 and game.builds.get("gather") == 2
		var duplicate: Dictionary = replay.perform("level", {"level": 19}, replay.clock)
		valid = valid and duplicate.has("error") and replay.meta.get("level:2", false)
		var fresh: Dictionary = replay.perform("level", {"level": 13}, replay.clock)
		valid = valid and not fresh.has("error") and game.stash.count("anvil_1") == 1 and game.stash.count("anvil_4") == 0
		valid = valid and Data.build_def("gather")["parts"][1]["rewards"][0][0] == "basket_1"
		print(("PASS " if valid else "FAIL ") + "reward retune retains old ownership, replays old claims once and uses new grants thereafter")
		quit(0 if valid else 1)
	else: quit(2)
