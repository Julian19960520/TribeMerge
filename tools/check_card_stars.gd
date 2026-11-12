extends SceneTree
## Duplicate settlement, save upgrades, durable exchanges and real reward UI.
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1

func run() -> void:
	var g = root.get_node("G")
	var replay = root.get_node("Replay")
	if "--expect-star-upgrade" in OS.get_cmdline_user_args():
		check(g.loaded_save and g.level == 8 and g.card_stars == 13 and g.cards == {"0_0": 1, "0_8": 1}, "real startup upgrades the preceding browser save without resetting progress")
		check(replay.authorized and replay.recovery_error == "" and g.replay_meta.get("album:0", false), "upgrade preserves claimed rewards and starts a valid new journal")
		quit(0 if failures == 0 else 1)
		return
	g.set_process(false); replay.set_process(false); root.get_node("Cloud").set_process(false)
	replay.active = true; replay.worker = false; replay.authorized = true; replay.executing = true
	replay.seq = 0; replay.base = 0; replay.pending = []; replay.inflight = {}
	g.simulation_time = 1793577600.0; replay.clock = int(g.simulation_time)
	replay.meta = {"allow_gm": true}; g.replay_meta = replay.meta
	g.new_game(); g.random_seed = "card-stars-check"; g.random_streams = {}
	g.tutorial_on = false; g.seen_tutorial = true; g.level = 8
	replay.advance(); replay.executing = false
	check(replay.checkpoint(), "fixture has its own durable checkpoint")
	var rules = g.rules.progression
	var rewards: Array = rules.collect_cards([[0, 8], [0, 8], [0, 8]])
	check(g.cards == {"0_8": 1} and g.card_stars == 10 and rewards[0]["stars"] == 0 and rewards[1]["stars"] == 5 and rewards[2]["stars"] == 5, "a repeated card inside one acquisition grants stars exactly once per extra copy")
	var by_star := {}
	for index in 9: by_star[CardPacks.stars(0, index)] = index
	for rarity in range(1, 6):
		var index: int = by_star[rarity]
		g.cards["0_%d" % index] = 1
		var before: int = g.card_stars
		rules.collect_cards([[0, index]])
		check(g.card_stars - before == rarity, "%d-star duplicates grant %d stars" % [rarity, rarity])
	var legacy: Dictionary = replay.snapshot().duplicate(true)
	legacy.erase("card_stars")
	legacy["cards"] = {"0_0": 4, "0_8": 3, "1_1": 1}
	check(replay.restore(legacy) and g.card_stars == 13 and g.cards == {"0_0": 1, "0_8": 1, "1_1": 1}, "old duplicate inventories convert at their rarity while preserving unique cards")
	var current: Dictionary = replay.snapshot().duplicate(true)
	check(replay.restore(JSON.parse_string(JSON.stringify(current))) and g.card_stars == 13, "snapshot roundtrip cannot pay historical duplicates twice")
	current["card_stars"] = -1
	check(not replay.restore(current) and g.card_stars == 13, "negative star wallets are rejected atomically")
	g.card_stars = 99
	var before: String = replay.digest()
	check(replay.perform("card_star_exchange", {"cost": 100}).has("error") and replay.digest() == before, "insufficient stars consume nothing")
	for cost in [0, -100, 101, 999]:
		before = replay.digest()
		check(replay.perform("card_star_exchange", {"cost": cost}).has("error") and replay.digest() == before, "invalid exchange cost %d cannot create items or currency" % cost)
	g.card_stars = 700
	for cell in g.board: cell["id"] = "fruit_1"; cell["lock"] = 0
	g.stash = ["pack_5", "pack_3"]
	var rng_before: Dictionary = g.random_save().duplicate(true)
	for cost in [100, 200, 400]:
		var result: Dictionary = replay.perform("card_star_exchange", {"cost": cost, "pack": "pack_5"})
		var expected: String = CardPacks.exchange_offer(cost)["pack"]
		check(result.get("pack") == expected and g.stash[result["stash"]] == expected, "%d-star exchange uses configured goods and retains the exact pack on a full board" % cost)
	check(g.card_stars == 0 and g.random_save() == rng_before, "exchanging spends exactly 700 stars without drawing cards or advancing random streams")
	before = replay.digest()
	check(replay.perform("card_star_exchange", {"cost": 100}).has("error") and replay.digest() == before, "rapid extra purchase cannot overspend after the balance reaches zero")
	var stored: Dictionary = replay.snapshot().duplicate(true)
	g.card_stars = 999
	check(replay.restore(stored) and g.card_stars == 0 and g.stash == stored["stash"], "star wallet and purchased packs restore together")
	g.level = 7; g.card_stars = 400
	before = replay.digest()
	check(replay.perform("card_star_exchange", {"cost": 400}).has("error") and replay.digest() == before, "locked collection cannot exchange stars")
	g.level = 8
	# Reproduce the same-card case using a real deterministic pack command.
	g.cards = {}; g.card_stars = 0; g.stash = ["pack_1"]
	for attempt in 200:
		g.random_seed = "same-card-pack:%d" % attempt; g.random_streams = {}
		var preview: Dictionary = replay.snapshot().duplicate(true)
		var result: Dictionary = replay.perform("pack", {"stash": 0})
		var entries: Array = result.get("cards", [])
		if entries.size() == 2 and entries[0] == entries[1]:
			check(g.cards.size() == 1 and g.card_stars == CardPacks.duplicate_value(int(entries[0][0]), int(entries[0][1])) and result["card_rewards"][0]["stars"] == 0 and result["card_rewards"][1]["stars"] > 0, "real pack settlement recognizes its second identical draw as a duplicate")
			break
		check(replay.restore(preview), "pack seed fixture restores")
		if attempt == 199: check(false, "same-card pack fixture found")
	var main = load("res://tools/RewardProbe.gd").new()
	root.add_child(main)
	await process_frame
	g.card_stars = 250
	var collection = main.open("event")
	check(collection.box.get_node_or_null("card_star_wallet") != null, "collection exposes the lower-right star exchange button")
	collection.box.get_node("card_star_wallet").pressed.emit()
	var shop = main.popup_layer.top()
	check(shop.name == "card_star_shop" and shop.box.get_node("exchange_100").enabled and shop.box.get_node("exchange_200").enabled and not shop.box.get_node("exchange_400").enabled, "shop enables exactly the affordable tiers")
	shop.box.get_node("exchange_200").pressed.emit()
	var pack = main.popup_layer.top()
	check(g.card_stars == 50 and pack != shop and not shop.box.get_node("exchange_100").enabled, "actual purchase button deducts stars, refreshes the shop and opens its specific pack")
	for album in Data.ALBUMS.size():
		for index in 9: g.cards["%d_%d" % [album, index]] = 1
	pack.on_tap.call()
	check(pack.box.get_node_or_null("received_card_0") != null and not pack.box.get_node("receive_cards").enabled, "opening the purchased pack starts actual card reveal and blocks early collection")
	var settled: int = g.card_stars
	await create_timer(1.7).timeout
	check(not pack.box.get_node("received_card_0").visible and pack.box.find_children("converted_star*", "", true, false).size() > 0, "duplicate cards transform into animated stars")
	await create_timer(1.4).timeout
	check(pack.box.get_node("receive_cards").enabled and pack.box.get_node("card_star_wallet/balance").text == str(settled) and g.card_stars == settled, "flights finish at the wallet without granting currency a second time")
	pack.box.get_node("receive_cards").pressed.emit()
	await create_timer(0.25).timeout
	check(main.popup_layer.top() == shop and shop.box.get_node("star_shop_balance").text == str(settled), "closing rewards returns to the updated exchange shop")
	main.close_all()
	check(replay.checkpoint(), "star exchanges persist successfully")
	g.card_stars = 9999
	check(g.load_game() and g.card_stars == settled, "local reload keeps settled stars")
	var legacy_save: Dictionary = g.save_dict(true).duplicate(true)
	legacy_save.erase("card_stars")
	legacy_save["cards"] = {"0_0": 4, "0_8": 3}
	legacy_save["replay_meta"]["album:0"] = true
	legacy_save["replay_local"]["rules"] = replay.BEFORE_CARD_STARS_RULES
	check(g.StateCodec.write("/tmp/tribe-legacy-stars.json", legacy_save), "preceding-release startup fixture is written")
	main.free(); g.main = null
	print("RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
