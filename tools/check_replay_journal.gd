extends SceneTree
## Exercises command durability, torn writes, checkpoint generations and timer rollback.
const Store := preload("res://scripts/replay/Journal.gd")
var failures := 0
var replay
var game
const SAVE := "user://replay_journal_check/save.json"

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, label: String) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition: failures += 1

func reset_fixture() -> void:
	replay.active = true
	replay.authorized = true
	replay.worker = false
	replay.executing = true
	replay.pending = []
	replay.inflight = {}
	replay.meta = {"allow_gm": true}
	replay.seq = 0
	replay.base = 0
	replay.clock = 1794240000
	game.random_seed = "ab".repeat(32)
	game.random_streams = {}
	game.new_game()
	game.player_id = "journal-check"
	replay.advance()
	replay._canonicalize_live()
	replay.executing = false
	game.clear_presentations()
	replay.checkpoint()

func recover_checkpoint() -> void:
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	check(replay.restore(saved), "strict checkpoint restores")
	replay.pending = saved["replay_local"]["pending"]
	replay.inflight = saved["replay_local"]["inflight"]
	replay.base = int(saved["replay_local"]["base"])
	replay.set("_generation", saved["replay_local"]["generation"])
	replay._recover()

func run() -> void:
	replay = root.get_node("Replay")
	game = root.get_node("G")
	game.set_process(false)
	replay.set_process(false)
	root.get_node("Cloud").set_process(false)
	game.save_path = SAVE
	reset_fixture()
	var initial: Dictionary = replay.snapshot()
	var events := {"board": 0, "orders": 0}
	game.board_changed.connect(func(): events["board"] += 1)
	game.orders_changed.connect(func(): events["orders"] += 1)
	var operation: Dictionary = replay.perform("drop", {"from": 28, "to": 29}, replay.clock)
	check(operation.get("kind", "") == "merge", "merge executes through current reducer")
	check(events["board"] == 1 and events["orders"] == 0, "one board notification and no unchanged order notification")
	var expected: String = replay.digest()
	check(replay.pending.size() == 1 and FileAccess.file_exists(SAVE + ".journal"), "command is durable before presentation")
	var original_journal := FileAccess.get_file_as_string(SAVE + ".journal")
	var file := FileAccess.open(SAVE + ".journal", FileAccess.READ_WRITE)
	file.seek_end()
	file.store_string('{"payload":"incomplete')
	file.close()
	recover_checkpoint()
	check(replay.digest() == expected and replay.pending.size() == 1, "torn final journal record does not lose complete input")
	check(replay.seq == 1, "journal recovery does not duplicate sequence")
	replay.restore(initial)
	replay.pending = []
	replay.checkpoint()
	file = FileAccess.open(SAVE + ".journal", FileAccess.WRITE)
	file.store_string(original_journal)
	file.close()
	recover_checkpoint()
	check(replay.seq == 0 and replay.pending.is_empty(), "stale journal is ignored after checkpoint generation changes")

	reset_fixture()
	game.energy = 0
	game.energy_stamp = replay.clock - 240
	replay.checkpoint()
	var invalid: Dictionary = replay.perform("tap", {"cell": -1}, replay.clock)
	check(invalid.has("error") and game.energy == 2, "invalid input preserves legitimate elapsed energy regeneration")
	check(replay.pending.size() == 1 and replay.pending[0]["name"] == "tick", "elapsed time is durably recorded independently of invalid input")
	var before_failure: String = replay.digest()
	var previous_path: String = game.save_path
	game.save_path = "/dev/null/unwritable.json"
	var rejected: Dictionary = replay.perform("drop", {"from": 28, "to": 29}, replay.clock)
	game.save_path = previous_path
	check(rejected.has("error") and replay.digest() == before_failure, "journal write failure rolls back business changes")

	reset_fixture()
	replay.perform("drop", {"from": 28, "to": 29}, replay.clock)
	replay.inflight = {"batch": "ab".repeat(16), "ops": [replay.pending[0].duplicate(true)]}
	replay.checkpoint()
	replay.perform("drop", {"from": 29, "to": 28}, replay.clock)
	var later_hash: String = replay.digest()
	recover_checkpoint()
	check(replay.digest() == later_hash and replay.pending.size() == 2 and replay.inflight["batch"] == "ab".repeat(16), "in-flight batch and later offline inputs both survive restart")

	var timings := []
	for count in [0, 1000, 10000]:
		replay.pending = []
		for index in count: replay.pending.append({"seq": index, "at": 1794240000, "name": "drop", "args": {"from": 28, "to": 29}, "hash": "a".repeat(64)})
		var started := Time.get_ticks_usec()
		for iteration in 20: replay.snapshot()
		timings.append({"pending": count, "snapshot_mean_usec": (Time.get_ticks_usec() - started) / 20.0})
	check(not replay.snapshot().has("replay_local"), "business snapshot excludes local journal")
	var restart_ok := true
	for phase in ["write", "read"]:
		var output: Array = []
		var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tools/check_replay_restart.gd", "--", "--replay-test", "--cloud-off", "--save=user://replay_journal_check/restart.json", "--cloud-state=user://replay_journal_check/restart-cloud.json", "--phase=" + phase], output, true)
		if code != 0:
			restart_ok = false
			print("RESTART_OUTPUT ", output)
	check(restart_ok, "separate process autoload recovers a command without graceful checkpoint")
	var album_upgrade_ok := true
	for phase in ["write", "read"]:
		var output: Array = []
		var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tools/check_album_reward_upgrade.gd", "--", "--replay-test", "--cloud-off", "--save=user://replay_journal_check/album-upgrade.json", "--cloud-state=user://replay_journal_check/album-upgrade-cloud.json", "--phase=" + phase], output, true)
		if code != 0:
			album_upgrade_ok = false
			print("ALBUM_UPGRADE_OUTPUT ", output)
	check(album_upgrade_ok, "compatible album upgrade preserves ownership, old journal rewards and unclaimed albums")
	print("SNAPSHOT_MEASUREMENTS ", JSON.stringify(timings))
	replay.pending = []
	game.save_path = "user://replay_journal_check/finished.json"
	print("Replay journal failures: ", failures)
	quit(0 if failures == 0 else 1)
