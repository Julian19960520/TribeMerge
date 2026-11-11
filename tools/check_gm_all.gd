extends SceneTree
## Actual board-button GM input and independent current-rule replay authorization.
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func reset_player(g, replay, allow_gm: bool, tutorial: bool) -> void:
	replay.active = true; replay.worker = false; replay.authorized = true; replay.executing = true
	replay.seq = 0; replay.base = 0; replay.pending = []; replay.inflight = {}
	g.simulation_time = 1793577600.0; replay.clock = int(g.simulation_time)
	replay.meta = {"allow_gm": allow_gm}; g.replay_meta = replay.meta
	g.new_game(); g.random_seed = "gm-all-current"; g.random_streams = {}
	g.seen_tutorial = true; g.tutorial_on = tutorial
	replay.advance(); replay.executing = false
	g.clear_presentations()
	check(replay.checkpoint(), "GM fixture starts from an isolated current checkpoint")
func run() -> void:
	var g = root.get_node("G")
	var replay = root.get_node("Replay")
	var offers = load("res://scripts/events/Offers.gd")
	var event = load("res://scripts/events/MergeEvent.gd")
	var tiger = load("res://scripts/events/TigerEscape.gd")
	var fossil = load("res://scripts/events/FossilDig.gd")
	var duel = load("res://scripts/events/DuelRace.gd")
	var race = load("res://scripts/net/Race.gd").inst()
	g.set_process(false); replay.set_process(false); root.get_node("Cloud").set_process(false)
	reset_player(g, replay, true, false)
	var main = load("res://tools/RewardProbe.gd").new()
	root.add_child(main); main.show_screen("board", true)
	await process_frame
	check(not g.rules.progression.feature_unlocked(Data.CARD_LEVEL) and not main.home._cards_btn.visible, "ordinary level-one accounts retain their feature gates")
	var wallet := [g.energy, g.shells, g.amber, g.rush]
	g.orders = []; g.tutorial_on = true
	var gm = main.board_screen.get_node("gm_activities")
	gm.pressed.emit()
	await process_frame
	check(g.gm_activities and g.level == 1 and g.xp == 0 and wallet == [g.energy, g.shells, g.amber, g.rush], "actual GM button unlocks features without granting levels or assets")
	check(not g.tutorial_on and g.seen_tutorial and main.home._cards_btn.visible and g.rules.board.boost_open(), "GM exits the tutorial and reveals cards and boost")
	check(event.available(event.current()) and tiger.unlocked() and fossil.unlocked() and duel.unlocked() and race.unlocked(), "GM opens every activity at level one")
	check(not event.state(event.current()).is_empty() and not fossil.state().is_empty(), "GM initializes newly visible activity state inside the same command")
	check(offers.unlocked("energy") and offers.unlocked("spree"), "GM opens both offer features independently of level")
	var all_builds := true
	for building in Data.BUILDS: all_builds = all_builds and g.rules.progression.build_open(str(building["id"]))
	check(all_builds and g.rules.progression.feature_unlocked(g.rules.orders.craft_level()) and not g.rules.orders._pick_dish().is_empty(), "GM unlocks building regions and all cooking recipes")
	var orders: Array = g.orders.duplicate(true)
	gm.pressed.emit()
	check(g.orders == orders and g.level == 1 and wallet == [g.energy, g.shells, g.amber, g.rush], "repeated GM input does not reroll orders or grant progression")
	check(replay.checkpoint(), "all-feature permission persists in the current checkpoint")
	g.gm_activities = false; g.boost_gm = false
	check(g.load_game() and g.rules.progression.feature_unlocked(999) and g.rules.board.boost_open(), "current save reload restores all-feature permission")
	g.stash = ["pack_1"]
	var cards: Array = g.open_pack("pack_1")
	check(cards.size() == 2 and g.stash.is_empty(), "GM opens saved packs below the ordinary card level")
	var popup = main.open("event")
	check(popup != null, "real card collection opens at level one after GM")
	main.close_all(); await process_frame
	reset_player(g, replay, false, true)
	var before: String = replay.digest()
	var denied: Dictionary = replay.perform("gm")
	check(denied.has("error") and replay.digest() == before and not g.gm_activities, "unauthorized GM input preserves the complete business state")
	reset_player(g, replay, true, true)
	g.stash = ["pack_1"]
	var fixture: Dictionary = replay.snapshot().duplicate(true)
	check(replay.checkpoint(), "independent GM sequence records the exact starting fixture")
	gm.pressed.emit()
	g.open_pack("pack_1"); offers.open_window("energy")
	check(g.rules.progression.feature_unlocked(Data.CARD_LEVEL) and g.cards.size() > 0 and offers.active("energy"), "authorized offline GM unlocks cards and offers through shared commands")
	check(replay.pending.size() == 3 and replay.pending[0]["name"] == "gm", "the actual button records exactly one authorized GM command")
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--output="): continue
		var ops := []
		for entry in replay.pending:
			var operation: Dictionary = entry.duplicate(true); operation.erase("hash"); ops.append(operation)
		var file := FileAccess.open(arg.trim_prefix("--output="), FileAccess.WRITE)
		file.store_string(JSON.stringify({"before": fixture, "ops": ops, "hash": replay.digest()})); file.close()
	main.free(); g.main = null
	print("RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
