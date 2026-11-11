extends SceneTree

var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1

func tap(button) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.position = button.size * 0.5
	e.pressed = true
	button._gui_input(e)
	e.pressed = false
	button._gui_input(e)

func run() -> void:
	var g = root.get_node("G")
	var replay = root.get_node("Replay")
	g.new_game(); g.set_process(false); replay.set_process(false)
	root.get_node("Cloud").set_process(false)
	g.level = 13; g.seen_tutorial = true; g.tutorial_on = false
	check(ProjectSettings.get_setting("application/config/name") == "合合部落", "product is named 合合部落")
	g.hot_bought = {"hot_0": 2}
	g.random_seed = "shop-current-cache"; g.random_streams = {}
	replay.active = true; replay.authorized = true; replay.clock = int(root.get_node("Cloud").server_now())
	g.deals_day = g.rules.clock.today()
	replay.seq = 0; replay.pending = []
	replay.meta = {"allow_gm": true}
	load("res://scripts/events/ActivityRules.gd").initialize()
	var before: Dictionary = replay.snapshot().duplicate(true)
	var rows: Array = g.shop_view()
	check(rows.size() == 10, "current shop creates all ten configured supply slots")
	check(g.hot_bought.size() == 1 and int(g.hot_bought.get("hot_0", 0)) == 2, "opening the shop preserves same-day purchase counts")
	var random_after: Dictionary = g.random_save().duplicate(true)
	var seq: int = replay.seq
	check(g.shop_view() == rows and replay.seq == seq and g.random_save() == random_after, "same-day reopening preserves goods and random stream position")
	var saved: Dictionary = replay.snapshot()
	replay.restore(saved)
	check(g.shop_view() == rows and replay.seq == seq and g.random_save() == random_after, "current snapshot restores the cached ten-slot shop without rerolling")
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--output="): continue
		var ops := []
		for entry in replay.pending:
			var op: Dictionary = entry.duplicate(true); op.erase("hash"); ops.append(op)
		var file := FileAccess.open(arg.trim_prefix("--output="), FileAccess.WRITE)
		file.store_string(JSON.stringify({"before": before, "ops": ops, "hash": replay.digest()})); file.close()
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	var shop = main.open("store")
	await process_frame
	var goods: Control = shop.find_child("HotGoods", true, false)
	var bottom := 0.0
	var count := 0
	for node in goods.get_children():
		if node.get_script() == load("res://scripts/ui/DrawBox.gd") and node.size == Vector2(208, 250):
			count += 1
			bottom = maxf(bottom, node.position.y + node.size.y)
	var gap := -1.0
	for node in goods.get_parent().get_children():
		if node is Label and node.text == "热卖刷新": gap = node.position.y - bottom
	check(count == 10 and gap >= 0 and gap < 50, "all ten shop cards render and the refresh bar follows the last row")
	shop.close()
	await create_timer(0.2).timeout
	var ev = load("res://scripts/events/MergeEvent.gd")
	var cfg: Dictionary = ev.current()
	g.merge_events = {}
	load("res://scripts/events/ActivityRules.gd").initialize()
	var state: Dictionary = ev.state(cfg)
	state["points"] = 5
	var moon = main.open("merge_event")
	check(moon.spawn_btn.visible and not moon.orders_btn.visible, "moon event offers placement while points remain")
	for i in 5: tap(moon.spawn_btn)
	check(state["points"] == 0 and state["spent"] == 5 and moon.board.incoming.size() == 5, "five rapid taps place five unique items before any flight ends")
	check(not moon.spawn_btn.visible and moon.orders_btn.visible and moon.orders_btn.text == "去完成订单", "empty moon supplies immediately become the order button")
	var flights: Array = moon.fx.parts.filter(func(part): return part["k"] == "fly")
	flights[0]["done"].call()
	check(moon.board.animating and moon.board.incoming.size() == 4, "first landing keeps the remaining four flights protected")
	for i in range(1, flights.size()): flights[i]["done"].call()
	check(not moon.board.animating and moon.board.incoming.is_empty(), "board unlocks after all rapid placements land")
	# Remove manually completed test flights to avoid calling their completion twice.
	moon.fx.parts = moon.fx.parts.filter(func(part): return part["k"] != "fly")
	state["points"] = 2
	for cell in state["cells"]:
		if int(cell["lock"]) == 0: cell["id"] = "moon_1"
	moon._refresh()
	tap(moon.spawn_btn)
	check(state["points"] == 2 and state["spent"] == 5 and moon.spawn_btn.visible, "full event board preserves unspent supplies")
	state = ev.state(cfg)
	state["points"] = 0; moon._refresh()
	main.show_screen("home", true)
	tap(moon.orders_btn)
	check(main.screen == "board" and moon._closing, "moon order button closes the event and returns to orders")
	await create_timer(0.2).timeout
	# A second rapid batch uses the same durable command path.
	g.merge_events = {}
	load("res://scripts/events/ActivityRules.gd").initialize()
	ev.state(cfg)["points"] = 4
	replay.active = true; replay.pending = []
	var moon_before: Dictionary = replay.snapshot().duplicate(true)
	moon = main.open("merge_event")
	for i in 4: tap(moon.spawn_btn)
	var canonical: Dictionary = ev.state(cfg)
	check(int(canonical["points"]) == 0 and int(canonical["spent"]) == 4 and moon.board.incoming.size() == 4, "rapid placements keep all four committed item flights protected")
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--moon-output="): continue
		var ops := []
		for entry in replay.pending:
			var op: Dictionary = entry.duplicate(true); op.erase("hash"); ops.append(op)
		var file := FileAccess.open(arg.trim_prefix("--moon-output="), FileAccess.WRITE)
		file.store_string(JSON.stringify({"before": moon_before, "ops": ops, "hash": replay.digest()})); file.close()
	moon.close()
	await create_timer(0.2).timeout
	var race = load("res://scripts/net/Race.gd").inst()
	race._last_ms = Time.get_ticks_msec(); race.set_process(false)
	main.show_screen("home", true)
	var banana = load("res://scripts/ui/RacePopup.gd").race_panel()
	var orders = banana.find_child("race_go_orders", true, false)
	check(orders != null and orders.visible and orders.text == "去完成订单" and orders.position.y >= 1200, "banana race has a bottom order button")
	tap(orders)
	check(main.screen == "board" and banana._closing, "banana order button returns to orders")
	await create_timer(0.2).timeout
	main.queue_free(); await process_frame
	g.main = null
	print("RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
