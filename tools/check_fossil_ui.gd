extends SceneTree
var failures := 0
var fossil

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1

func run() -> void:
	var g = root.get_node("G")
	var replay = root.get_node("Replay")
	g.set_process(false); replay.set_process(false)
	g.new_game(); g.tutorial_on = false; g.seen_tutorial = true
	fossil = load("res://scripts/events/FossilDig.gd")
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	main.show_screen("board", true)
	await process_frame
	check(main.board_screen._fossil_entry.visible, "fossil activity has a visible main-board entry")
	var popup = main.open("fossil")
	await process_frame
	check(popup.cells.get_child_count() == 9 and "3×3" in popup.stage_label.text, "popup builds nine clickable cells and the first-stage label")
	check(popup.primary.text == "去完成订单" and "铲子  0" == popup.count_label.text, "zero shovels shows the actual order route")
	await popup._primary()
	await create_timer(0.24).timeout
	check(main.screen == "board" and main.popup_layer.get_child_count() == 0, "order button closes activity and returns to the main board")
	fossil.on_order({})
	fossil.on_order({})
	fossil.on_order({})
	popup = main.open("fossil")
	await create_timer(0.35).timeout
	var b: Dictionary = fossil.board()
	for p in b["pieces"]:
		for cell in fossil.piece_cells(p, int(b["n"])):
			popup.cells.get_child(int(cell)).pressed.emit()
			await process_frame
	check(fossil.cleared() and popup.flies.size() > 0 and not popup.primary.enabled, "grid buttons excavate and keep the next-stage button locked during bone flights")
	await create_timer(0.95).timeout
	check(popup.flies.is_empty() and popup.primary.enabled and "下一关" in popup.primary.text, "completed bones finish their flights before next stage unlocks")
	popup._preview(2)
	await process_frame
	var preview = main.popup_layer.get_child(-1)
	var claim = preview.find_child("fossil_claim_2", true, false)
	check(claim != null and claim.enabled, "reached reward opens a claimable reward preview")
	claim.pressed.emit()
	await create_timer(0.3).timeout
	check(fossil.state()["claimed"] == [2], "reward preview claims progress through the shared reducer")
	for child in main.popup_layer.get_children():
		if child != popup: child.close()
	await create_timer(0.25).timeout
	await popup._primary()
	await process_frame
	check(popup.cells.get_child_count() == 16 and "4×4" in popup.stage_label.text, "next-stage button rebuilds a four by four grid")
	# Check the densest configured board and both silhouette rows in the fixed mobile design space.
	g.fossil_dig["stage"] = 10
	g.fossil_dig["board"] = fossil.make_board(str(fossil.state()["seed"]), 10)
	popup._refresh()
	await process_frame
	var all_inside := true
	for i in 11:
		var r: Rect2 = popup._slot_rect(i)
		if r.position.x < 60 or r.end.x > 660 or r.position.y < 390 or r.end.y > 560: all_inside = false
	check(popup.cells.get_child_count() == 144 and all_inside, "largest grid and all eleven bone silhouettes fit inside the mobile panel without scrolling")
	popup._instructions()
	await process_frame
	check(main.popup_layer.get_child_count() >= 2, "activity rules use the existing popup stack")
	main.free(); g.main = null
	print("RESULT ", failures, " failures")
	quit(0 if failures == 0 else 1)
