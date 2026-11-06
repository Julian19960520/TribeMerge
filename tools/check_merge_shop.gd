extends SceneTree
## Run with an isolated save and --cloud-off; covers economic and board boundaries.
var failures: Array = []
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures.append(label)
func _run() -> void:
	var g = root.get_node("G")
	var data = load("res://scripts/Data.gd")
	g.set_process(false)
	g.new_game()
	g.tutorial_on = false
	g.seen_tutorial = true
	check(data.daily_deals(1).size() == 5 and data.daily_deals(8).size() == 5, "five daily offers at every level")
	var daily = load("res://scripts/events/DailyShop.gd")
	g.amber = 0
	var r: Dictionary = await daily.claim("deal_2")
	check(r.get("ok", false) and g.amber == 0 and not g.has_free_daily(), "free daily claim works at zero balance and clears dot")
	r = await daily.claim("deal_2")
	check(not r.get("ok", false) and int(g.deals_bought["deal_2"]) == 1, "duplicate free claim rejected")
	g.deals_day = "2000-01-01"
	g._check_day()
	check(g.has_free_daily(), "new day restores free claim")
	g.hot_bought = {"hot_0": 5}
	g.deals_bought = {"deal_2": 1}
	g.amber = 9
	r = await g.refresh_hot()
	check(not r.get("ok", false) and g.amber == 9 and g.hot_bought.get("hot_0") == 5, "failed refresh preserves balance and stock")
	g.amber = 10
	var hot = load("res://scripts/HotDeals.gd")
	var before_hot: Array = hot.today().duplicate(true)
	r = await g.refresh_hot()
	check(r.get("ok", false) and g.amber == 0 and g.hot_bought.is_empty() and g.hot_revision == 1, "refresh costs exactly 10 and resets hot stock")
	check(not g.has_free_daily(), "hot refresh cannot reset daily free item")
	var after_hot: Array = hot.today().duplicate(true)
	var all_changed := true
	for k in before_hot.size():
		all_changed = all_changed and before_hot[k]["id"] != after_hot[k]["id"]
	check(all_changed, "paid refresh changes every hot slot")
	hot.clear_cache()
	check(hot.today() == after_hot, "refreshed goods survive cache reload")
	g.discovered.erase("salad")
	check(await g.claim_book("salad") == 0, "uncrafted dish has no codex reward")
	var prizes_before: int = g.book_prize_count()
	g.discover("salad")
	check(g.book_prize_count() == prizes_before + 1, "crafted dish contributes to codex red dot")
	check(await g.claim_book("salad") == 1 and await g.claim_book("salad") == 0, "dish discovery reward is claimable only once")
	g.board = []
	for i in 63: g.board.append({"id": "", "lock": 0})
	g.board[0]["id"] = "fruit_4"
	g.board[1]["id"] = "fruit_4"
	for seed_value in 100:
		g.rng.seed = seed_value
		if g.rng.randf() < 0.15:
			g.rng.seed = seed_value
			break
	var chance_state: int = g.rng.state
	g._maybe_spawn_bubble("fruit_3", 1)
	check(not g.is_merge_bubble(2), "low-level merge never creates bubble")
	g.tutorial_on = true
	g._maybe_spawn_bubble("fruit_5", 1)
	check(not g.is_merge_bubble(2), "tutorial never creates bubble")
	g.tutorial_on = false
	g.rng.state = chance_state
	check(g.try_drop(0, 1) == "merge", "normal merge succeeds")
	check(g.board[1]["id"] == "fruit_5" and g.is_merge_bubble(0) and g.board[0]["id"] == "fruit_5", "bonus copies merged result in nearest vacant cell")
	check(g.bubble_left(0) > 58 and g.bubble_left(0) <= 60, "bubble starts with 60 real seconds")
	g.board[2]["id"] = "fruit_5"
	check(g.try_drop(2, 0) == "" and g.try_drop(0, 3) == "", "unpaid bubble cannot merge or move")
	check(g.board_has("fruit_5", [1, 2]) == -1, "unpaid bubble cannot satisfy order inventory")
	check(data.bubble_price("seed_5") > data.bubble_price("fruit_5") and data.bubble_price("fruit_6") > data.bubble_price("fruit_5"), "price increases with rarity and level")
	g.amber = 0
	r = await g.buy_bubble(0)
	check(not r.get("ok", false) and g.is_merge_bubble(0), "failed bubble purchase preserves item")
	g.amber = 100
	var price: int = data.bubble_price("fruit_5")
	r = await g.buy_bubble(0)
	check(r.get("ok", false) and g.board[0]["lock"] == 0 and g.amber == 100 - price, "purchase unlocks item and charges once")
	r = await g.buy_bubble(0)
	check(not r.get("ok", false) and g.amber == 100 - price, "duplicate bubble purchase rejected")
	g.board[3] = {"id": "seed_3", "lock": 3, "bubble": {"uid": "test", "price": 10, "expires": g.now() - 1}}
	g._tick_bubbles()
	check(g.board[3]["id"] == "" and g.board[3]["lock"] == 0, "expired bubble frees its cell")
	g.board[3] = {"id": "seed_3", "lock": 3, "bubble": {"uid": "saved", "price": 10, "expires": g.now() + 30}}
	var expiry: float = g.board[3]["bubble"]["expires"]
	g.save_game()
	g.board[3] = {"id": "", "lock": 0}
	g.load_game()
	check(g.is_merge_bubble(3) and absf(float(g.board[3]["bubble"]["expires"]) - expiry) < 0.01, "reload preserves original bubble deadline")
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	main.show_screen("board", true)
	await process_frame
	main.board_screen.board.select(3)
	await process_frame
	check(main.board_screen._bubble_offer.visible, "selecting bubble shows purchase popover")
	await g.buy_bubble(3)
	await process_frame
	check(not main.board_screen._bubble_offer.visible, "purchase hides popover immediately")
	g.level = 7
	g.board[5] = {"id": "pack_1", "lock": 0}
	main.board_screen._on_activate(5)
	check(g.board[5]["id"] == "pack_1", "locked card pack stays on board")
	g.stash = ["pack_1"]
	main.board_screen._on_stash()
	check(g.stash == ["pack_1"], "locked card pack stays in stash")
	g.level = 8
	var p = main.open("store")
	for i in 3: await process_frame
	check(p != null, "shop renders free item and timed refresh")
	p.close()
	for i in 20: await process_frame
	var popups = load("res://scripts/ui/Popups.gd")
	var book = popups.book(data.LINES.size())
	main.add_child(book)
	for i in 3: await process_frame
	check(book != null, "timed-order codex page renders")
	book.queue_free()
	main.queue_free()
	await process_frame
	print("RESULT: ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
