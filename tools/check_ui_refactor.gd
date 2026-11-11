extends SceneTree
## Integration checks for stable order controls, lazy tooling, and split view modules.
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(condition: bool, description: String) -> void:
	if condition: print("PASS ", description)
	else:
		failures += 1
		push_error(description)
func run() -> void:
	var g = root.get_node("G")
	var replay = root.get_node("Replay")
	var cloud = root.get_node("Cloud")
	g.set_process(false)
	replay.set_process(false)
	cloud.set_process(false)
	replay.worker = true
	replay.authorized = true
	g.new_game()
	g.tutorial_on = false
	g.seen_tutorial = true
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	# This fixture owns the popup stack; timed offers must not open between assertions.
	var offers = main.get_node_or_null("OfferController")
	if offers != null: offers.set_process(false)
	check(main.cfg_screen == null, "configuration editor is not constructed at startup")
	main.show_screen("board", true)
	var screen = main.board_screen
	var strip = screen.get("_cards_root")
	var created: int = strip.created_count
	var refreshed: int = strip.refresh_count
	var ids := []
	for card in strip.cards_by_index: ids.append(card.get_instance_id())
	g.board_changed.emit()
	g.orders_changed.emit()
	g.board_changed.emit()
	await process_frame
	check(strip.refresh_count == refreshed + 1, "multiple same-frame world notifications produce one order refresh")
	check(strip.created_count == created, "unchanged orders retain their controls")
	var before_currency: int = strip.refresh_count
	g.shells += 1
	g.changed.emit()
	await process_frame
	check(strip.refresh_count == before_currency and strip.created_count == created, "unrelated currency changes update the HUD without rebuilding orders")
	var result = replay.perform("drop", {"from": 28, "to": 29})
	await process_frame
	await process_frame
	check(not result.has("error"), "merge command reaches the shared reducer")
	check(strip.created_count == created, "a merge creates no replacement order cards")
	var retained := true
	for index in mini(ids.size(), strip.cards_by_index.size()):
		retained = retained and ids[index] == strip.cards_by_index[index].get_instance_id()
	check(retained, "completion-state changes preserve order card identity")
	if ids.size() >= 2:
		g.orders.reverse()
		g.orders_changed.emit()
		await process_frame
		check(strip.cards_by_index[0].get_instance_id() == ids.back(), "order reordering reuses the matching card and rebinds its index")
	main.show_screen("cfg", true)
	await process_frame
	check(main.cfg_screen != null, "configuration editor is created on first entry")
	var editor = main.cfg_screen
	for page in ["chains", "board", "story", "unlock", "rand", "pass", "albums", "people", "builds", "levels", "amber", "rules"]:
		editor.call("_go", page)
		await process_frame
		await process_frame
		check(editor.get("_root").get_child_count() > 0, "configuration page renders: " + page)
	editor.call("_go", "chains")
	await process_frame
	editor.call("_open_chain", 0)
	await process_frame
	check(editor.get("_sheet_open"), "chain editing sheet uses the extracted chain module")
	editor.call("_close_sheet")
	editor.call("_go", "board")
	await process_frame
	for mode in ["lock", "reward", "item"]:
		editor.get("board_page").call("_pick_board_mode", mode)
		await process_frame
		await process_frame
		check(editor.get("_board_mode") == mode, "board editor tool mode uses the extracted board module: " + mode)
	main.show_screen("board", true)
	g.level = 20
	for feature in ["energy", "howto", "store", "settings", "book", "inventory", "level", "event"]:
		var popup = main.open(feature)
		await process_frame
		check(popup != null and popup.is_inside_tree(), "popup registry opens: " + feature)
		main.close_all()
		await process_frame
		await process_frame
	check(main.popup_layer.top() == null, "popup stack removes closed views")
	var metrics := {"orders": ids.size(), "initial_cards": created, "cards_after_merge": strip.created_count}
	main.show_screen("cfg", true)
	editor.call("_go", "rules")
	await process_frame
	var rules_path: String = editor.call("_page_path", "rules")
	var working_rules: Dictionary = editor.get("_pages")[rules_path]
	var old_max_energy: int = working_rules["max_energy"]
	working_rules["max_energy"] = old_max_energy + 1
	editor.get("_dirty")[rules_path] = true
	var source_hash := FileAccess.get_sha256(rules_path)
	cloud.enabled = true
	editor.call("_refresh_save")
	check(not editor.get("_save_btn").enabled, "online sessions disable configuration saves")
	var state_before: String = replay.digest()
	editor.call("_save")
	check(replay.digest() == state_before and FileAccess.get_sha256(rules_path) == source_hash, "online save callback cannot modify gameplay or configuration")
	working_rules["max_energy"] = old_max_energy
	editor.get("_dirty").erase(rules_path)
	cloud.enabled = false
	editor.call("_refresh_save")
	check(editor.get("_save_btn").text.begins_with("保存并重开测试局"), "save button explicitly describes the test-session restart")
	var old_board_id: int = main.board_screen.get_instance_id()
	main.prepare_session_restart()
	replay.worker = false
	check(replay.restart_local_rules(), "local rules restart commits a fresh checkpoint")
	main.reset_session_views()
	check(main.cfg_screen == editor and main.screen == "cfg" and main.board_screen.get_instance_id() != old_board_id, "session restart replaces gameplay views while retaining the configuration page")
	check(g.level == 1 and g.tutorial_on and replay.pending.is_empty() and replay.inflight.is_empty(), "fresh session discards old progress and pending command queues")
	main.show_screen("board", true)
	check(main.get("_guide") != null and main.get("_guide").visible, "returning to the board initializes the new tutorial")
	print("UI_REFACTOR_METRICS ", JSON.stringify(metrics))
	main.free()
	g.main = null
	quit(1 if failures else 0)
