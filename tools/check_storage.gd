extends SceneTree
var failures := []
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func run() -> void:
	var g = root.get_node("G")
	g.new_game();g.set_process(false);g.tutorial_on=false;g.seen_tutorial=true
	g.amber=100000
	check(g.rules.progression.storage_price()==50,"first expansion costs 50")
	for expected in [50, 50, 50, 50, 50, 60, 60, 60, 60, 60, 70, 70]:
		var price: int=g.rules.progression.storage_price()
		var before: int=g.amber
		check(price==expected,"slot %d uses its row price %d" % [g.inv_cap+1, expected])
		check(await g.expand_storage() and g.amber==before-expected,"expansion charges exactly the displayed row price")
	check(g.inv_cap==17,"expands beyond original ten-slot limit")
	g.amber=0
	var cap: int=g.inv_cap
	var price: int=g.rules.progression.storage_price()
	check(not await g.expand_storage() and g.inv_cap==cap and g.rules.progression.storage_price()==price,"insufficient funds preserve capacity and price")
	g.inv_cap=125
	g.inv=[]
	for k in 125:g.inv.append("fruit_1")
	g.save_game();g.inv_cap=5;g.inv=[];g.load_game()
	check(g.inv_cap==125 and g.inv.size()==125 and g.rules.progression.storage_price()==290,"large inventory and row price survive reload")
	for k in g.board.size():g.board[k]={"id":"fruit_1","lock":0}
	var main=load("res://main.tscn").instantiate()
	root.add_child(main);main.show_screen("board",true)
	var p=main.open("inventory")
	await process_frame
	check(p.slots.size()==30 and p.scroll.length>p.scroll.size.y,"large storage scrolls with only thirty pooled controls")
	p.scroll.jump_to(3000);p._layout()
	check(int(p.slots[0].get_meta("slot"))>=95,"scroll recycles controls onto later slots")
	p._take(124)
	check(g.inv.size()==125,"full board cannot lose stored item")
	g.board[0]["id"]=""
	p._take(124)
	check(g.inv.size()==124 and g.board[0]["id"]=="fruit_1","take from late storage row reaches free board cell")
	g.amber=5000
	await p._expand()
	check(g.inv_cap==126 and p.unlock.text.contains("290") and p.next_lbl.text=="同排同价，每排 +10","visible expansion keeps the same price within its row")
	var tasks=load("res://scripts/events/SevenDay.gd")
	for day in tasks.config()["days"]:
		var logins: Array=day["tasks"].filter(func(t):return str(t["metric"])=="login_days")
		check(day["tasks"].size()==5 and logins.size()==1 and int(logins[0]["target"])==int(day["day"]),"each page has matching login target and five tasks")
	main.queue_free();await process_frame;g.main=null
	print("RESULT: ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
