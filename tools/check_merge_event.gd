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
	check(ev.on_order({"items":["fruit_1"]}) == 1 and ev.on_order({"items":["fruit_4"]}) == 2 and ev.on_order({"items":["fruit_8"]}) == 3, "orders award exactly 1 to 3 based on configured difficulty")
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
	ev._advance(c,scroll)
	check(scroll["view"]==6 and scroll["cells"][95]["id"]=="" and scroll["cells"].slice(36,78).any(func(v):return v["id"]=="moon_3"), "automatic scroll carries lower items into the new visible area")
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
	for tile in s["cells"]: tile["lock"] = 0
	var amber: int = g.amber
	var energy: int = g.energy
	check(not (await ev.act(c,"claim")).has("error"), "completed event grants rewards")
	check(g.amber == amber + 30 and g.energy == energy + 100 and g.stash.count("choice_1") == 1, "event pays configured currencies and choice chest")
	check((await ev.act(c,"claim")).has("error") and g.amber == amber + 30, "event completion pays once")
	for k in g.board.size(): g.board[k] = {"id":"fruit_1","lock":0}
	g.board[20]["id"] = "choice_1"
	check((await choice.choose(20,"choice_1",4)).has("error") and g.board[20]["id"] == "choice_1", "invalid choice retains chest")
	energy = g.energy
	check((await choice.choose(20,"choice_1",0)).get("id") == "fire_4" and g.board[20]["id"] == "fire_4" and g.energy == energy, "choice replaces original cell even when board is full; resource remains physical")
	check((await choice.choose(20,"choice_1",1)).has("error"), "used chest cannot choose again")
	g.board[20]["id"] = "choice_1"
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	main.show_screen("board",true)
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
