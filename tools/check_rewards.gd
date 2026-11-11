extends SceneTree
## Settlement is durable business data; presentation can never pay it again.
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(condition: bool, label: String) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition: failures += 1
func run() -> void:
	var game = root.get_node("G")
	var replay = root.get_node("Replay")
	var rewards = load("res://scripts/Rewards.gd")
	var presenter = load("res://scripts/ui/RewardPresenter.gd")
	var panels = load("res://scripts/ui/popups/RewardPopups.gd")
	game.set_process(false); replay.set_process(false); root.get_node("Cloud").set_process(false)
	replay.active = true; replay.worker = true; replay.executing = true
	game.new_game(); game.tutorial_on = false; game.seen_tutorial = true; game.level = 8; game.energy = 0
	load("res://scripts/events/ActivityRules.gd").initialize()
	replay.executing = false
	var main = load("res://tools/RewardProbe.gd").new()
	root.add_child(main)
	await process_frame
	main.show_screen("home", true)
	var origin := Vector2(200, 400)
	var fire: Array = rewards.items(["fire_4"])
	rewards.settle(fire)
	presenter.present(fire, func(_index): return origin)
	check(game.energy == Data.value_of("fire_4") and game.stash.is_empty(), "physical shop resource redeems exactly its configured value")
	check(main.flights.size() == 1 and main.flights[0]["to"].is_equal_approx(main.topbar.target("energy")), "resource presentation targets the energy bar")
	check(main.home._go_phase == 0, "resource-only presentation does not raise merge button")
	var before: Dictionary = replay.snapshot()
	presenter.present(fire, func(_index): return origin)
	check(replay.snapshot() == before, "repeated presentation cannot change business state")
	var energy: int = game.energy
	var shells: int = game.shells
	var amber: int = game.amber
	var rush: int = game.rush
	rewards.settle([["fire_4", 7], ["shell_2", 8], ["amber_2", 9], ["sand_2", 10], ["fruit_3", 2]])
	check(game.energy == energy + 7 and game.shells == shells + 8 and game.amber == amber + 9 and game.rush == rush + 10, "numeric reward quantities are not multiplied by icon tier")
	check(game.stash == ["fruit_3", "fruit_3"], "item rewards enter stash at settlement time")
	game.stash = []; game.tokens = 0; game.token_claimed = 0
	rewards.settle([["token_1", game.TOKEN_STEP * 2]])
	check(game.stash.count("pack_1") == 2, "festival points produce exactly two packs")
	game.stash = []
	energy = game.energy
	rewards.settle(rewards.items(["fire_1", "fire_4"]))
	check(game.stash == ["fire_1"] and game.energy == energy + Data.value_of("fire_4"), "first tier remains mergeable while collectible tiers redeem")
	for index in game.board.size(): game.board[index] = {"id": "fruit_1", "lock": 0}
	game.board[0]["id"] = ""; game.stash = []; energy = game.energy
	var report: Dictionary = rewards.settle(rewards.items(["fire_4", "fruit_3"]), {"board_origin": 0})
	check(game.rules.board.cell_id(0) == "fire_4" and game.energy == energy and game.stash == ["fruit_3"] and report["overflow"] == 1, "chest items remain physical and overflow enters stash")
	var committed: Dictionary = replay.snapshot()
	var panel = panels.reward_screen([["fire_2", 3], ["fruit_4", 1]])
	main.add_child(panel)
	panel.on_tap.call()
	panel.queue_free()
	await process_frame
	check(replay.snapshot() == committed, "claiming and closing a display panel cannot pay twice")
	panel = panels.reward_screen([["fire_2", 4]])
	main.add_child(panel)
	panel.queue_free()
	await process_frame
	check(replay.snapshot() == committed, "interrupted display has no settlement side effects")
	game.clear_presentations()
	main.free(); game.main = null
	print("RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
