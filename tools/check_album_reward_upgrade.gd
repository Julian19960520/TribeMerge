extends SceneTree
## Upgrade the previous offline checkpoint plus its uncheckpointed final card.
const Store := preload("res://scripts/replay/Journal.gd")

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
		replay.executing = true
		replay.seq = 0; replay.base = 0; replay.pending = []; replay.inflight = {}
		replay.clock = 1794240000
		replay.meta = {"allow_gm": true}
		game.random_seed = "album-upgrade-stable-seed"; game.random_streams = {}
		game.new_game()
		game.player_id = "album-upgrade-check"
		game.level = 12; game.seen_tutorial = true; game.tutorial_on = false
		game.gm_activities = true; game.amber = 77
		game.cards = {}
		for index in 8: game.cards["0_%d" % index] = 1
		for index in 9: game.cards["1_%d" % index] = 1
		replay.advance(); replay._canonicalize_live(); replay.executing = false
		game.clear_presentations()
		if not replay.checkpoint(): quit(1); return
		var old_checkpoint: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.save_path))
		replay.get("_reducer").legacy_album_rewards = true
		var received: Dictionary = replay.perform("gm", {"action": "card", "album": 0}, replay.clock)
		if received.has("error") or game.amber != 107: quit(1); return
		var file := FileAccess.open(expected_path, FileAccess.WRITE)
		file.store_string(replay.digest()); file.flush(); file.close()
		old_checkpoint["replay_local"]["rules"] = replay.AUTOMATIC_ALBUM_RULES
		if Store.write_checkpoint(game.save_path, old_checkpoint) != OK: quit(1); return
		quit(0)
	elif phase == "read":
		var expected := FileAccess.get_file_as_string(expected_path)
		var valid: bool = expected != "" and replay.digest() == expected and replay.authorized and replay.pending.is_empty()
		valid = valid and replay.journal()["rules"] == replay.rules_hash() and game.player_id == "album-upgrade-check" and game.level == 12
		valid = valid and game.amber == 107 and game.stash.count("chest_1") == 2 and replay.meta.get("album:0", false) and not replay.meta.get("album:1", false)
		var paid: Dictionary = replay.perform("album_claim", {"album": 0}, replay.clock)
		valid = valid and paid.has("error") and game.amber == 107
		var unclaimed: Dictionary = replay.perform("album_claim", {"album": 1}, replay.clock)
		valid = valid and not unclaimed.has("error") and game.amber == 137 and game.stash.count("chest_1") == 4
		print("ALBUM_UPGRADE ", "PASS" if valid else "FAIL")
		quit(0 if valid else 1)
	else: quit(2)
