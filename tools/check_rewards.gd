extends SceneTree
var failures: Array = []
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures.append(label)
func run() -> void:
	var g = root.get_node("G")
	var rewards = load("res://scripts/Rewards.gd")
	var popups = load("res://scripts/ui/Popups.gd")
	var data = load("res://scripts/Data.gd")
	g.new_game()
	g.set_process(false)
	g.seen_tutorial = true
	g.tutorial_on = false
	g.level = 8
	g.energy = 0
	g.stash = []
	var main = load("res://tools/RewardProbe.gd").new()
	root.add_child(main)
	main.show_screen("home", true)
	var origin := Vector2(200, 400)
	check(await popups._buy_offer("fire_4", {"key": "deal_2", "price": 0, "deal": true}, origin), "free shop purchase succeeds")
	check(g.energy == data.value_of("fire_4") and g.stash.is_empty(), "shop fire redeems its tier value without entering stash")
	check(main.flights.size() == 1 and main.flights[0]["to"].is_equal_approx(main.topbar.target("energy")), "home shop fire flies to energy bar")
	check(main.home._go_phase == 0, "resource-only reward never raises merge button")
	check(not await popups._buy_offer("fire_4", {"key": "deal_2", "price": 0, "deal": true}, origin) and g.energy == data.value_of("fire_4"), "duplicate free purchase cannot duplicate energy")
	main.flights.clear()
	var en: int = g.energy
	var sh: int = g.shells
	var am: int = g.amber
	var sa: int = g.rush
	rewards.grant([["fire_4", 7], ["shell_2", 8], ["amber_2", 9], ["sand_2", 10], ["fruit_3", 2]], func(_k): return origin)
	check(g.energy == en + 7 and g.shells == sh + 8 and g.amber == am + 9 and g.rush == sa + 10, "configured resource rewards use exact quantities, not icon tier multiplier")
	check(g.stash == ["fruit_3", "fruit_3"], "mixed reward items are accounted immediately")
	await create_timer(0.4).timeout
	check(main.flights.size() == 5 and main.flights[4]["to"].is_equal_approx(main.home.go_center()), "mixed home rewards split resource bars and merge button")
	main.flights.clear()
	main.show_screen("board", true)
	rewards.grant([["fruit_4", 1]], func(_k): return origin)
	check(main.flights.size() == 1 and main.flights[0]["to"].is_equal_approx(main.board_screen.stash_pos()), "board rewards target stash")
	en = g.energy
	var count: int = g.stash.size()
	rewards.grant([["fire_4", 7], ["fruit_4", 1]], func(_k): return origin, true, false)
	check(g.energy == en and g.stash.size() == count and main.flights[1]["to"].is_equal_approx(main.topbar.target("energy")), "already-applied rewards animate correct routes without duplicate credit")
	g.tokens = 0
	g.token_claimed = 0
	rewards.grant([["token_1", g.TOKEN_STEP * 2]], Callable(), false)
	check(g.stash.count("pack_1") == 2, "token conversion grants exactly two packs through shared entry")
	g.stash = []
	rewards.grant(rewards.items(["fire_1", "fire_4"]), Callable(), false)
	check(g.stash == ["fire_1"] and g.energy == en + data.value_of("fire_4"), "zero-value first-tier fire remains mergeable; collectible fire redeems")
	for i in g.board.size(): g.board[i] = {"id": "fruit_1", "lock": 0}
	g.board[0]["id"] = ""
	g.stash = []
	en = g.energy
	rewards.grant(rewards.items(["fire_4", "fruit_3"]), Callable(), false, true, {"board_origin": 0})
	check(g.board[0]["id"] == "fire_4" and g.energy == en and g.stash == ["fruit_3"], "chest keeps physical merge items and safely stashes overflow")
	main.show_screen("home", true)
	g.stash = []
	rewards.grant([["fruit_3", 1]], func(_k): return origin)
	main.show_screen("board", true)
	check(g.stash == ["fruit_3"], "switching screens during animation cannot lose reward")
	var p = popups.reward_screen([["fire_2", 3], ["fruit_4", 1]])
	main.add_child(p)
	en = g.energy
	p.on_tap.call()
	p.queue_free()
	await process_frame
	check(g.energy == en + 3 and g.stash.count("fruit_4") == 1, "claim then panel exit cannot pay twice")
	p = popups.reward_screen([["fire_2", 4]])
	main.add_child(p)
	en = g.energy
	p.queue_free()
	await process_frame
	check(g.energy == en + 4, "closing reward panel grants through silent fallback")
	main.queue_free()
	await process_frame
	g.main = null
	print("RESULT: ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
