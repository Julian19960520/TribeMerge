extends SceneTree
## Local editor rule changes start a new durable session and never migrate WAL.
var failures := 0
func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, label: String) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition: failures += 1

func fit_layout(count: int) -> void:
	Data.BOARD = Data.BOARD.duplicate(true)
	Data.LOCKS = Data.LOCKS.duplicate(true)
	while Data.BOARD.size() < count: Data.BOARD.append("")
	while Data.LOCKS.size() < count: Data.LOCKS.append(0)
	Data.BOARD.resize(count)
	Data.LOCKS.resize(count)

func run() -> void:
	var game = root.get_node("G")
	var replay = root.get_node("Replay")
	var cloud = root.get_node("Cloud")
	for node in root.get_children(): node.set_process(false)
	game.save_path = "user://replay_rules_check/session.json"
	replay.active = true
	replay.worker = false
	cloud.enabled = false
	var original_rules: Dictionary = Data.RULES.duplicate(true)
	var original_board: Array = Data.BOARD.duplicate(true)
	var original_locks: Array = Data.LOCKS.duplicate(true)
	check(replay.restart_local_rules(), "local current-rule session starts")
	var prior_generation: String = replay.get("_generation")
	replay.perform("drop", {"from": 28, "to": 29})
	var old_journal := FileAccess.get_file_as_string(game.save_path + ".journal")
	check(replay.pending.size() == 1, "old test session has durable pending input")
	Data.RULES = original_rules.duplicate(true)
	Data.RULES["cols"] = int(original_rules["cols"]) + 1
	fit_layout(int(Data.RULES["cols"]) * int(Data.RULES["rows"]))
	check(replay.restart_local_rules(), "changed board dimensions create a new test session")
	check(game.COLS == int(original_rules["cols"]) + 1 and game.board.size() == game.COLS * game.ROWS, "new board uses the changed dimensions")
	check(replay.seq == 0 and replay.base == 0 and replay.pending.is_empty() and replay.inflight.is_empty(), "new rules clear sequence, confirmed base and upload queues")
	check(replay.get("_generation") != prior_generation, "new rules replace the old journal generation")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.save_path))
	check(saved["replay_meta"]["seq"] == 0 and int(saved["replay_meta"]["at"]) == replay.clock and saved["board"].size() == game.board.size(), "new test state and clock are atomically checkpointed")
	var fresh_hash: String = replay.digest()
	var file := FileAccess.open(game.save_path + ".journal", FileAccess.WRITE)
	file.store_string(old_journal)
	file.close()
	replay._recover()
	check(replay.digest() == fresh_hash and replay.pending.is_empty(), "old-rule journal is never replayed into the new session")

	cloud.enabled = true
	check(not replay.restart_local_rules() and replay.digest() == fresh_hash, "network sessions cannot edit runtime rules")
	cloud.enabled = false
	replay.worker = true
	check(not replay.restart_local_rules() and replay.digest() == fresh_hash, "validation workers cannot restart editor sessions")
	replay.worker = false

	var current_rules: Dictionary = Data.RULES.duplicate(true)
	var current_board: Array = Data.BOARD.duplicate(true)
	var current_locks: Array = Data.LOCKS.duplicate(true)
	var prior_path: String = game.save_path
	prior_generation = replay.get("_generation")
	Data.RULES = current_rules.duplicate(true)
	Data.RULES["rows"] = int(current_rules["rows"]) + 1
	fit_layout(int(Data.RULES["cols"]) * int(Data.RULES["rows"]))
	game.save_path = "/dev/null/rules-checkpoint.json"
	check(not replay.restart_local_rules(), "checkpoint failure rejects the rule restart")
	game.save_path = prior_path
	check(replay.digest() == fresh_hash and replay.get("_generation") == prior_generation and game.COLS == int(current_rules["cols"]) and game.ROWS == int(current_rules["rows"]), "failed restart restores state, board layout and journal generation")
	check(not replay.authorized and not replay.restore_rules_edit_authorization(), "failed restart stays blocked until the previous rules are restored")
	Data.RULES = current_rules
	Data.BOARD = current_board
	Data.LOCKS = current_locks
	check(replay.restore_rules_edit_authorization() and replay.authorized, "successful editor rollback restores the previous authorization")
	Data.RULES = original_rules
	Data.BOARD = original_board
	Data.LOCKS = original_locks
	check(replay.restart_local_rules(), "fixture restores original rules with a fresh test session")
	print("Replay rule restart failures: ", failures)
	quit(0 if failures == 0 else 1)
