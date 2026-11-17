extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func run() -> void:
	for node in root.get_children(): node.set_process(false)
	var g = root.get_node("G")
	var replay = root.get_node("Replay")
	check(PriceBook.ready(), "server catalog loaded")
	check(PriceBook.price("fruit_5") == 16 and PriceBook.price("fruit_7") == 50 and PriceBook.price("fruit_8") == 97, "main product anchors")
	check(PriceBook.price("seed_3") == 22 and PriceBook.price("basket_1") == 120, "secondary and generator anchors")
	g.new_game(); g.tutorial_on = false; g.seen_tutorial = true
	g.simulation_time = 1794657600.0
	replay.active = true; replay.authorized = true; replay.meta["free_energy"] = true
	g.rules.clock._check_day()
	g.amber = 1000; g.energy = 0; g.energy_buys = 0
	for expected in [20,30,40,50,60,60]:
		check(g.rules.progression.energy_price() == expected, "energy tier %d" % expected)
		var before: int = g.amber
		check(g.rules.progression.buy_energy() and g.amber == before-expected, "exact energy charge")
	var count: int = g.energy_buys
	g.amber = 0
	check(not g.rules.progression.buy_energy() and g.energy_buys == count, "failed purchase retains tier")
	g.simulation_time += 86400
	g.rules.clock._check_day()
	check(g.energy_buys == 0 and g.rules.progression.energy_price() == 20, "daily tier reset")
	g.amber = 100
	var before_sand: int = g.rush
	var result: Dictionary = replay.perform("resource_buy", {"product":"sand:3"})
	check(result.get("ok",false) and g.amber == 94 and g.rush == before_sand+600, "one-hour sand pack grants 600 six-second units")
	var content := {"cost_amber":10,"rewards":[["fire_2",100]],"energy_purchase":{"day":g.rules.clock.today(),"count":1}}
	var before_energy: int = g.energy
	var granted: Dictionary = replay.perform("grant", {"id":"gr_economy_test", "content":content})
	var duplicate: Dictionary = replay.perform("grant", {"id":"gr_economy_test", "content":content})
	check(granted.get("ok",false) and duplicate.get("duplicate",false) and g.energy == before_energy+100 and g.amber == 84, "virtual grant charges and delivers once")
	check(PriceBook.reward_value([["fire_2",100],["sand_2",600],["shell_2",100]]) == 126.0, "shared reward valuation")
	var previous_hash: String = replay.rules_hash()
	var previous_level: int = g.level
	var previous_amber: int = g.amber
	var us = JSON.parse_string(FileAccess.get_file_as_string("res://server/public/catalog_US.json"))
	check(PriceBook.install(us) and Data.refresh(), "US server catalog installs")
	check(Data.AMBER_PACKS[0]["price"] == "$1.99" and int(Data.AMBER_PACKS[0]["n"]) == 110, "regional recharge shows server USD amount and price")
	check(PriceBook.product_text("pass:vip") == "$4.99" and PriceBook.product_text("pass:upgrade") == "$5", "pass price and upgrade preserve USD cents")
	check(load("res://scripts/events/Offers.gd").price_text("energy", 0) == "$2.99", "limited offer reads server-formatted USD price")
	check(replay.rules_hash() == previous_hash and g.level == previous_level and g.amber == previous_amber, "regional cash pricing preserves gameplay identity and progress")
	quit(0 if failures == 0 else 1)
