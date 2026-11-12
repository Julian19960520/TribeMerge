extends SceneTree
## Actual GM buttons, ownership refresh, card details, saving and trusted replay.
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1

func run() -> void:
	var g = root.get_node("G")
	var replay = root.get_node("Replay")
	g.set_process(false); replay.set_process(false); root.get_node("Cloud").set_process(false)
	replay.active = true; replay.worker = false; replay.authorized = true; replay.executing = true
	replay.seq = 0; replay.base = 0; replay.pending = []; replay.inflight = {}
	g.simulation_time = 1793577600.0; replay.clock = int(g.simulation_time)
	replay.meta = {"allow_gm": true}; g.replay_meta = replay.meta
	g.new_game(); g.random_seed = "harvest-cards-current"; g.random_streams = {}
	g.random_for("cards").randi()
	g.seen_tutorial = true; g.tutorial_on = false
	replay.advance(); replay.executing = false
	g.clear_presentations()
	check(replay.checkpoint(), "collection fixture has an isolated checkpoint")
	check(Data.ALBUMS[0]["name"] == "采摘" and Data.ALBUMS[0]["art"].size() == 9 and Data.ALBUMS[0]["texts"].size() == 9, "harvest has nine approved names, illustrations and captions")
	for index in 9:
		var texture: Texture2D = CardArtwork.texture(0, index)
		check(texture != null and texture.get_width() == texture.get_height(), "square illustration loads for harvest card %d" % index)
	var cover_paths := []
	for album_index in Data.ALBUMS.size():
		var path := CardArtwork.cover_path(album_index)
		var cover := CardArtwork.cover(album_index)
		check(cover != null and not path in cover_paths and not path == CardArtwork.art_path(album_index, 0), "album %d loads its own independent cover" % album_index)
		cover_paths.append(path)
	var main = load("res://tools/RewardProbe.gd").new()
	root.add_child(main)
	await process_frame
	main.show_screen("board", true)
	check(not g.rules.progression.feature_unlocked(Data.CARD_LEVEL), "fresh level-one player has not unlocked the collection")
	g.seen_tutorial = false; g.tutorial_on = true
	main.begin_guide()
	var gm: Control = main.board_screen.get_node("gm_activities")
	var gm_point: Vector2 = main._guide.get_global_transform().affine_inverse() * gm.get_global_rect().get_center()
	check(not main._guide._has_point(gm_point), "the actual GM hit area remains clickable during the strong tutorial")
	gm.pressed.emit()
	check(g.level == 1 and g.rules.progression.feature_unlocked(Data.CARD_LEVEL) and main.home._cards_btn.visible, "board GM reveals the real collection without changing player level")
	var album = main.open("album", 0)
	check(album != null and album.box.get_node("album_cards").get_child_count() == 9, "real harvest album has nine tappable card slots")
	check(album.box.get_node("gm_random_card").position.y >= 1320 and album.box.get_node("album_cover").position.x < album.box.get_node("album_progress").position.x, "GM stays outside the panel and the cover precedes the reward controls")
	var unclaimed_wallet := [g.energy, g.shells, g.amber, g.rush, g.stash.duplicate()]
	var claim: Control = album.box.get_node("album_claim")
	var locked_hash: String = replay.digest()
	claim.pressed.emit()
	check(not claim.enabled and replay.digest() == locked_hash and main.flights.is_empty(), "incomplete album cannot grant or animate a reward")
	var normal_stream := str(g.random_save()["streams"]["cards"])
	for count in 9:
		album.box.get_node("gm_random_card").pressed.emit()
		check(g.rules.progression.album_count(0) == count + 1 and album.box.get_node("album_progress_count").text.contains("%d/9" % (count + 1)), "album GM acquires a missing card and refreshes collection progress %d" % (count + 1))
		var detail = main.popup_layer.top()
		check(detail.name == "collection_card_detail", "GM acquisition opens the received card")
		var caption: String = detail.box.get_node("card_text").text
		var picture: Control = detail.box.get_node("card_art")
		check(caption in Data.ALBUMS[0]["texts"] and picture.size == Vector2(672, 672) and detail.box.get_node("card_text").position.y > picture.get_rect().end.y, "detail shows the caption outside the full square picture frame")
		detail.free()
	check(str(g.random_save()["streams"]["cards"]) == normal_stream, "GM acquisitions do not advance the normal pack random stream")
	check(not replay.meta.get("album:0", false) and claim.enabled and [g.energy, g.shells, g.amber, g.rush, g.stash] == unclaimed_wallet, "completing a collection enables manual claiming without paying automatically")
	var wallet := [g.energy, g.shells, g.amber, g.rush]
	var stars_before: int = g.card_stars
	album.box.get_node("gm_random_card").pressed.emit()
	main.popup_layer.top().free()
	var copies := 0
	for amount in g.cards.values(): copies += int(amount)
	check(g.rules.progression.album_count(0) == 9 and copies == 9 and g.card_stars > stars_before, "a completed album converts its random duplicate into stars")
	check(wallet == [g.energy, g.shells, g.amber, g.rush], "duplicate acquisition does not grant the album reward again")
	album.box.get_node("album_cards/card_0_8").pressed.emit()
	check(main.popup_layer.top().box.get_node("card_text").text == Data.ALBUMS[0]["texts"][8], "tapping a collected card opens its own full illustration and caption")
	main.popup_layer.top().free()
	check(replay.pending.back()["name"] == "gm" and replay.pending.back()["args"]["action"] == "card", "the GM button records a replayable card command")
	main.flights.clear()
	claim.pressed.emit()
	check(replay.meta.get("album:0", false) and not claim.enabled and claim.text == "已领取" and g.amber == int(unclaimed_wallet[2]) + 30 and g.stash.count("chest_1") == unclaimed_wallet[4].count("chest_1") + 2, "actual claim button pays the configured collection rewards exactly once")
	check(main.flights.size() == 2 and main.flights[0]["to"].is_equal_approx(main.topbar.target("amber")) and main.flights[1]["to"].is_equal_approx(main.board_screen.stash_pos()), "claim animates currency to the HUD and items to the stash")
	check(replay.pending.back()["name"] == "album_claim", "manual claiming is a durable replay command")
	var paid_hash: String = replay.digest()
	claim.pressed.emit()
	check(replay.digest() == paid_hash and main.flights.size() == 2, "a repeated claim cannot grant rewards or replay their flight animation")
	main.close_all()
	check(CardArtwork.title(1) == "狩猎" and CardArtwork.caption(1, 5) == "兄弟，计划很顺利。现在换你拿一会儿。", "hunting presentation uses the approved theme and revised bait caption")
	for album_index in CardArtwork.PRESENTATIONS:
		main.close_all()
		var current = main.open("album", album_index)
		for count in 9:
			var owned: Dictionary = g.cards.duplicate()
			current.box.get_node("gm_random_card").pressed.emit()
			var received := -1
			for index in 9:
				var key := "%d_%d" % [album_index, index]
				if int(g.cards.get(key, 0)) > int(owned.get(key, 0)): received = index
			var detail = main.popup_layer.top()
			var title_shown := false
			for label in detail.box.find_children("*", "Label", true, false):
				if label.text == CardArtwork.card_name(album_index, received): title_shown = true
			check(received >= 0 and title_shown and detail.box.get_node("card_text").text == CardArtwork.caption(album_index, received) and CardArtwork.texture(album_index, received) != null, "album %d GM acquisition shows its presentation title, artwork and caption %d" % [album_index, count + 1])
			detail.free()
		check(g.rules.progression.album_count(album_index) == 9 and str(g.random_save()["streams"]["cards"]) == normal_stream, "album %d retains ownership slots and the independent GM random stream" % album_index)
	main.close_all()
	check(replay.checkpoint(), "GM cards and album rewards are saved")
	var saved: Dictionary = g.cards.duplicate()
	g.cards = {}
	check(g.load_game() and g.cards == saved, "save reload retains acquired cards")
	check(g.replay_meta.get("album:0", false) and not g.replay_meta.get("album:1", false) and not g.replay_meta.get("album:2", false), "save retains claimed and completed-but-unclaimed collections independently")
	var before: String = replay.digest()
	var invalid: Dictionary = replay.perform("gm", {"action": "card", "album": Data.ALBUMS.size()})
	check(invalid.has("error") and replay.digest() == before, "invalid album acquisition preserves all business state")
	replay.meta["allow_gm"] = false
	before = replay.digest()
	var denied: Dictionary = replay.perform("gm", {"action": "card", "album": 0})
	check(denied.has("error") and replay.digest() == before, "unauthorized GM acquisition preserves cards and random state")
	main.close_all()
	var collection = main.open("event")
	check(collection.box.get_node_or_null("gm_random_card") == null, "unauthorized sessions have no collection GM button")
	main.free(); g.main = null
	print("RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
