extends SceneTree
var failures: Array = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures.append(label)
func run() -> void:
	var g = root.get_node("G")
	var ev = load("res://scripts/events/MergeEvent.gd")
	var choice = load("res://scripts/events/ChoiceChest.gd")
	g.new_game()
	g.tutorial_on = false
	g.seen_tutorial = true
	g.set_process(false)
	var c: Dictionary = ev.current()
	g.level = 9
	check(not ev.available(c) and ev.on_order({"items":["fruit_8"]}) == 0, "event locked below 10 and earns no points")
	g.level = 10
	var s: Dictionary = ev.state(c)
	check(ev.available(c) and s["points"] == 0, "event opens at level 10 with zero points")
	var cells: Array = s["cells"]
	check(cells.size() == 96 and ev.remaining(s) == 90, "initial 16x6 board locks everything except bottom row")
	check(ev.local_action(c,s,"spawn",{"view":9}).has("error") and s["spent"] == 0, "zero-point spawn cannot produce items")
	var top_tier := 0
	var low_tier := 0
	for k in 30: top_tier = maxi(top_tier, c["chain"].find(ev.item(c, str(cells[k]["id"]))) + 1)
	for k in range(60, 90): low_tier = maxi(low_tier, c["chain"].find(ev.item(c, str(cells[k]["id"]))) + 1)
	check(top_tier > low_tier and cells[84]["id"] == "moon_1" and cells[78]["id"] == "moon_1", "deeper rows hold higher relics; the first two rows start at tier 1")
	check(ev.on_order({"items":["fruit_1"]}) == 1 and ev.on_order({"items":["fruit_5"]}) == 2 and ev.on_order({"items":["fruit_8"]}) == 3, "orders award exactly 1 to 3 based on configured difficulty")
	var r: Dictionary = ev.local_action(c,s,"spawn",{"view":9})
	check(r.get("kind") == "spawn" and s["points"] == 5, "bubble consumes one point and fills nearest free cell")
	var from: int = r["to"]
	r = ev.local_action(c,s,"drop",{"from":from,"to":0,"view":9})
	check(r.has("error") and cells[0]["lock"] == 2, "cannot jump into unrevealed rows")
	check(ev.local_action(c,s,"drop",{"from":from,"to":84,"view":9}).has("error"), "covered items cannot merge directly")
	ev.local_action(c,s,"drop",{"from":from,"to":90,"view":9})
	var second: Dictionary = ev.local_action(c,s,"spawn",{"view":9})
	r = ev.local_action(c,s,"drop",{"from":second["to"],"to":90,"view":9})
	check(r.get("kind")=="merge" and cells[84]["lock"]==1 and cells[78]["lock"]==2, "adjacent merge reveals only immediate covered neighbors and leaves items locked")
	check(ev.local_action(c,s,"drop",{"from":90,"to":84,"view":9}).has("error"), "mismatched item cannot unlock a revealed tile")
	var third: Dictionary = ev.local_action(c,s,"spawn",{"view":9})
	r = ev.local_action(c,s,"drop",{"from":third["to"],"to":84,"view":9})
	check(r.get("kind")=="merge" and cells[84]["id"]=="moon_2" and cells[84]["lock"]==0 and cells[78]["lock"]==1, "matching revealed item unlocks and uncovers next neighbors")
	var scroll: Dictionary=s.duplicate(true)
	for k in range(54,96):scroll["cells"][k]={"lock":0,"id":""}
	scroll["cells"][95]["id"]="moon_3"
	scroll["discovered"]["moon_4"]=true
	ev._advance(c,scroll)
	check(scroll["view"]==6 and scroll["cells"][95]["id"]=="" and scroll["cells"].slice(36,78).any(func(v):return v["id"]=="moon_3"), "automatic scroll carries lower items into the new visible area")
	var stages: Dictionary=ev.fresh(c)
	for cell in stages["cells"]: cell["lock"]=0; cell["id"]=""
	stages["discovered"]["moon_3"]=true
	ev._advance(c,stages)
	check(stages["view"]==9,"clear rows alone cannot advance before tier unlock")
	for tier in [4,5,6]:
		stages["discovered"]["moon_%d"%tier]=true
		ev._advance(c,stages)
		check(stages["view"]==9-(tier-3)*3,"tier %d advances configured three rows"%tier)
		ev._advance(c,stages)
		check(stages["view"]==9-(tier-3)*3,"same tier cannot advance twice")
	var delayed: Dictionary=ev.fresh(c)
	delayed["discovered"]["moon_4"]=true
	for k in [88,89]: delayed["cells"][k]={"lock":0,"id":""}
	ev._advance(c,delayed)
	check(delayed["view"]==8 and delayed["cells"][84]["lock"]==2,"uncleared lower cells remain reachable with pending advancement")
	for cell in delayed["cells"].slice(72,90): cell["lock"]=0; cell["id"]=""
	delayed["cells"][89]["id"]="moon_8"
	ev.local_action(c,delayed,"recycle",{"cell":89,"view":8})
	check(delayed["view"]==6,"later action spends pending advancement without a new tier")
	var legacy: Dictionary=ev.fresh(c)
	legacy.erase("rules_version")
	for k in 90:legacy["cells"][k]["lock"]=1
	legacy["points"]=13
	ev.migrate(c,legacy)
	check(legacy["points"]==13 and legacy["cells"][84]["lock"]==1 and legacy["cells"][78]["lock"]==2, "old save migration preserves points and visible frontier")
	var saved: Dictionary = g.save_dict().duplicate(true)
	g.save_game()
	g.merge_events = {}
	g.load_game()
	check(g.merge_events == saved["merge_events"], "event points and board survive save/reload")
	c = ev.current()
	s = ev.state(c)
	var next: Dictionary = ev.current(float(c["ends_at"]) + 1)
	check(next["key"] != c["key"] and ev.state(next)["points"] == 0 and s["points"] == 3, "new period isolates all points and progress")
	check((await ev.act(c,"claim")).has("error"), "cannot claim unfinished board")
	var ms: Array = ev.milestones(c)
	check(ms.size() >= 3 and int(ms[-1]["at"]) == ev.goal_total(c), "milestones end at the full 90-cell goal")
	var opened := 0
	for tile in s["cells"]:
		if opened < int(ms[0]["at"]) and int(tile["lock"]) != 0 and tile != s["cells"][0]:
			tile["lock"] = 0
			opened += 1
	opened = 0
	for k in range(s["cells"].size() - 1, -1, -1):
		if int(s["cells"][k]["lock"]) == 0: opened += 1
	var stash_before: int = g.stash.size()
	var first: Dictionary = await ev.act(c,"claim")
	check(not first.has("error") and first["milestones"] == [0] and not s["claimed"] and g.stash.size() > stash_before, "first milestone chest pays mid-way and the board stays open")
	check((await ev.act(c,"claim")).has("error"), "a milestone pays once")
	for tile in s["cells"]: tile["lock"] = 0
	var amber: int = g.amber
	var energy: int = g.energy
	var want_amber := 0
	var want_energy := 0
	for k in range(1, ms.size()):
		for rw in ms[k]["rewards"]:
			if str(rw[0]).begins_with("amber"): want_amber += int(rw[1])
			if str(rw[0]).begins_with("fire"): want_energy += int(rw[1])
	var rest: Dictionary = await ev.act(c,"claim")
	check(not rest.has("error") and rest["milestones"].size() == ms.size() - 1 and s["claimed"], "completed event grants every remaining milestone at once")
	check(g.amber == amber + want_amber and g.energy == energy + want_energy and g.stash.count("choice_1") == 1, "event pays configured currencies and choice chest")
	check((await ev.act(c,"claim")).has("error") and g.amber == amber + want_amber, "event completion pays once")
	for k in g.board.size(): g.board[k] = {"id":"fruit_1","lock":0}
	g.board[20]["id"] = "choice_1"
	check((await choice.choose(20,"choice_1",4)).has("error") and g.board[20]["id"] == "choice_1", "invalid choice retains chest")
	energy = g.energy
	check((await choice.choose(20,"choice_1",0)).get("id") == "fire_5" and g.board[20]["id"] == "fire_5" and g.energy == energy, "choice replaces original cell even when board is full; resource remains physical")
	check((await choice.choose(20,"choice_1",1)).has("error"), "used chest cannot choose again")
	g.board[20]["id"] = "choice_1"
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	main.show_screen("board",true)
	var bs=main.board_screen
	for id in ["basket_1","basket_3","fruit_1"]:
		g.board[0]={"id":id,"lock":0}
		bs.board.selected=0
		bs._on_select(0)
		check(bs._del_btn.visible==(id=="fruit_1"),"discard visibility for "+id)
		if id!="fruit_1":
			bs._on_delete()
			check(g.board[0]["id"]==id,"generator cannot be discarded by direct callback")
	var p = main.open("choice_chest",20)
	check(p.options.size() == 3, "chest UI exposes exactly three choices")
	p.close()
	await create_timer(0.25).timeout
	check(g.board[20]["id"] == "choice_1", "closing choices without selecting preserves chest")
	p = main.open("merge_event")
	await process_frame
	check(p.board != null and p.spawn_btn != null and p.claim_btn.position.y<p.board.position.y, "event panel renders board, bubble and top rewards")
	check(not p.board.has_method("navigate") and p.find_child("event_history",true,false)==null, "no manual navigation or history button")
	p.close()
	main.queue_free()
	await process_frame
	g.main = null
	print("RESULT: ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
