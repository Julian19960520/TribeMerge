extends SceneTree
## Child process fixture: exit after one WAL append, then verify autoload recovery.
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var replay = root.get_node("Replay")
	var game = root.get_node("G")
	for node in root.get_children(): node.set_process(false)
	var phase := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--phase="): phase = argument.trim_prefix("--phase=")
	var expected_file: String = game.save_path + ".expected"
	if phase == "write":
		replay.executing = true
		replay.seq = 0
		replay.clock = 1794240000
		replay.base = 0
		replay.pending = []
		replay.inflight = {}
		replay.meta = {"allow_gm": true}
		game.random_seed = "ef".repeat(32)
		game.random_streams = {}
		game.new_game()
		game.player_id = "restart-check"
		replay.advance()
		replay._canonicalize_live()
		replay.executing = false
		if not replay.checkpoint(): quit(1); return
		var result: Dictionary = replay.perform("drop", {"from": 28, "to": 29}, replay.clock)
		if result.get("kind", "") != "merge": quit(1); return
		var file := FileAccess.open(expected_file, FileAccess.WRITE)
		file.store_string(replay.digest())
		file.flush()
		file.close()
		# No graceful game save: the checkpoint still precedes this command.
		quit(0)
	elif phase == "read":
		var expected := FileAccess.get_file_as_string(expected_file)
		var valid: bool = expected != "" and replay.digest() == expected and replay.seq == 1 and replay.pending.size() == 1
		print("RESTART_RECOVERY ", "PASS" if valid else "FAIL")
		quit(0 if valid else 1)
	else:
		quit(2)
