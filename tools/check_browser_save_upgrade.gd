extends SceneTree
## The previous live browser checkpoint survives the cloud-save release.
const Store := preload("res://scripts/replay/Journal.gd")

func _initialize() -> void: run.call_deferred()

func run() -> void:
	for node in root.get_children(): node.set_process(false)
	var replay = root.get_node("Replay")
	var game = root.get_node("G")
	var phase := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="): phase = arg.trim_prefix("--phase=")
	if phase == "write":
		replay.executing = true
		replay.seq = 0; replay.base = 0; replay.pending = []; replay.inflight = {}
		replay.clock = 1794240000; replay.meta = {"allow_gm": true}
		game.random_seed = "browser-release-upgrade"; game.random_streams = {}
		game.new_game(); game.player_id = "existing-browser-player"
		game.level = 12; game.amber = 527; game.shells = 3891
		game.inv_cap = 9; game.inv = ["fruit_1", "tool_2"]
		game.stash = ["basket_5", "orderbox_5"]
		game.seen_tutorial = true; game.tutorial_on = false
		replay.advance(); replay._canonicalize_live(); replay.executing = false
		replay.snapshot()
		if not replay.checkpoint(): quit(1); return
		var expected := FileAccess.open(game.save_path + ".expected", FileAccess.WRITE)
		expected.store_string(replay.digest()); expected.close()
		var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.save_path))
		saved["replay_local"]["rules"] = replay.BEFORE_STORAGE_ROW_RULES
		if Store.write_checkpoint(game.save_path, saved) != OK: quit(1); return
		# Old-rule commands must not be applied to the new economy.
		if replay.perform("drop", {"from": 28, "to": 29}, replay.clock).has("error"): quit(1); return
		print("PASS prepared previous live browser checkpoint and old-rule journal")
	elif phase == "read":
		var valid: bool = replay.authorized and replay.recovery_error == "" and game.loaded_save
		valid = valid and replay.digest() == FileAccess.get_file_as_string(game.save_path + ".expected")
		valid = valid and game.level == 12 and game.amber == 527 and game.shells == 3891
		valid = valid and game.player_id == "existing-browser-player" and game.stash == ["basket_5", "orderbox_5"]
		valid = valid and game.inv_cap == 9 and game.inv == ["fruit_1", "tool_2"] and game.rules.progression.storage_price() == 50
		valid = valid and replay.pending.is_empty() and replay.inflight.is_empty() and replay.seq == 0
		valid = valid and replay.journal()["rules"] == replay.rules_hash()
		valid = valid and await game.expand_storage() and game.inv_cap == 10 and game.amber == 477 and game.rules.progression.storage_price() == 60
		print(("PASS " if valid else "FAIL ") + "previous browser progress survives and obsolete journal is discarded")
		quit(0 if valid else 1); return
	else: quit(2); return
	quit(0)
