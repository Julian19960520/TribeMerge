extends SceneTree
## Only the Python wrapper may run this test; res://data must be an isolated copy.
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(condition: bool, description: String) -> void:
	print(("PASS " if condition else "FAIL ") + description)
	if not condition: failures += 1
func run() -> void:
	var isolated := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--config-test-root="): isolated = argument.trim_prefix("--config-test-root=")
	if isolated == "" or ProjectSettings.globalize_path("res://").trim_suffix("/") != isolated:
		push_error("Run check_config_editor_save.py to isolate configuration writes")
		quit(1)
		return
	var g = root.get_node("G")
	var replay = root.get_node("Replay")
	var cloud = root.get_node("Cloud")
	g.set_process(false); replay.set_process(false); cloud.set_process(false)
	g.new_game()
	g.seen_tutorial = true; g.tutorial_on = false
	var input_result = replay.perform("drop", {"from": 28, "to": 29})
	check(not input_result.has("error") and not replay.pending.is_empty(), "test session has committed progress and a pending operation")
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	main.show_screen("cfg", true)
	var editor = main.cfg_screen
	editor.call("_go", "rules")
	await process_frame
	await process_frame
	var path: String = editor.call("_page_path", "rules")
	var rules: Dictionary = editor.get("_pages")[path]
	var original_columns: int = rules["cols"]
	var next_columns := original_columns - 1
	var old_board_id: int = main.board_screen.get_instance_id()
	rules["cols"] = next_columns
	editor.get("_dirty")[path] = true
	editor.call("_save")
	await process_frame
	await process_frame
	check(g.COLS == next_columns and g.board.size() == next_columns * g.ROWS, "Save applies new board dimensions in a fresh session")
	check(g.level == 1 and g.tutorial_on and replay.pending.is_empty() and replay.inflight.is_empty(), "Save clears previous progress and command queues")
	check(main.cfg_screen == editor and main.screen == "cfg" and main.board_screen.get_instance_id() != old_board_id, "Save retains the editor and replaces gameplay views")
	check(not editor.get("_dirty").has(path), "successful Save clears the saved page's dirty marker")
	var persisted: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(int(persisted["cols"]) == next_columns, "configuration file contains the new dimensions")
	main.show_screen("board", true)
	check(main.get("_guide") != null and main.get("_guide").get("_step") != "", "new board initializes its tutorial or layout-aware plain guide")
	main.show_screen("cfg", true)
	var stable_hash := FileAccess.get_sha256(path)
	var stable_board: int = main.board_screen.get_instance_id()
	rules["cols"] = 0
	editor.get("_dirty")[path] = true
	editor.call("_save")
	check(FileAccess.get_sha256(path) == stable_hash and main.board_screen.get_instance_id() == stable_board, "invalid configuration is rejected without a write or session restart")
	editor.call("_load_pages"); editor.get("_dirty").clear()
	rules = editor.get("_pages")[path]
	cloud.enabled = true
	rules["cols"] = original_columns
	editor.get("_dirty")[path] = true
	editor.call("_save")
	check(FileAccess.get_sha256(path) == stable_hash and g.COLS == next_columns, "online Save cannot change files or current gameplay")
	cloud.enabled = false
	editor.call("_load_pages"); editor.get("_dirty").clear()
	rules = editor.get("_pages")[path]
	var state_before: String = replay.digest()
	var board_file := "res://data/board.json"
	var board_bytes := FileAccess.get_file_as_bytes(board_file)
	var old_save_path: String = g.save_path
	var blocker := isolated.path_join("not-a-directory")
	var file := FileAccess.open(blocker, FileAccess.WRITE)
	file.store_string("checkpoint failure fixture"); file.close()
	g.save_path = blocker.path_join("player.json")
	rules["cols"] = original_columns
	editor.get("_dirty")[path] = true
	editor.call("_save")
	g.save_path = old_save_path
	await process_frame
	check(FileAccess.get_sha256(path) == stable_hash and FileAccess.get_file_as_bytes(board_file) == board_bytes, "checkpoint failure restores exact configuration bytes")
	check(g.COLS == next_columns and replay.digest() == state_before and replay.authorized, "checkpoint failure restores the previous state, layout, and authorization")
	check(editor.get("_dirty").has(path), "failed Save retains the unsaved edit for review")
	main.free(); g.main = null
	print("CONFIG_EDITOR_SAVE: %d failures" % failures)
	quit(1 if failures else 0)
