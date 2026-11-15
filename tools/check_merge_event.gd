extends SceneTree
var failures: Array = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures.append(label)
func run() -> void:
	load("res://scripts/events/ActivitySchedule.gd").bypass = true # 只测单个活动玩法，不受档期轮换影响
	var g = root.get_node("G")
	var ev = load("res://scripts/events/MergeEvent.gd")
	var choice = load("res://scripts/events/ChoiceChest.gd")
	var replay = root.get_node("Replay")
	replay.set_process(false)
	root.get_node("Cloud").set_process(false)
	replay.active = true
	replay.authorized = true
	replay.clock = int(root.get_node("Cloud").server_now())
	g.new_game()
	g.tutorial_on = false
	g.seen_tutorial = true
	g.set_process(false)
	var c: Dictionary = ev.current()
	g.level = 9
	check(not ev.available(c) and ev.on_order({"items":["fruit_8"]}) == 0, "event locked below 10 and earns no points")
	g.level = 10
	load("res://scripts/events/ActivityRules.gd").initialize()
	var s: Dictionary = ev.state(c)
	check(ev.available(c) and s["points"] == 0, "event opens at level 10 with zero points")
	var cells: Array = s["cells"]
	check(cells.size() == 102 and ev.remaining(s) == 96, "initial 17x6 board locks everything except bottom row")
	check(ev.local_action(c,s,"spawn",{"view":10}).has("error") and s["spent"] == 0, "zero-point spawn cannot produce items")
	var top_tier := 0
	var low_tier := 0
	for k in 30: top_tier = maxi(top_tier, c["chain"].find(ev.item(c, str(cells[k]["id"]))) + 1)
	for k in range(84, 96): low_tier = maxi(low_tier, c["chain"].find(ev.item(c, str(cells[k]["id"]))) + 1)
	check(top_tier > low_tier and cells[90]["id"] == "glow_1" and cells[84]["id"] == "glow_1", "deeper rows hold higher relics; the first two rows start at tier 1")
	check(ev.on_order({"items":["fruit_1"]}) == 1 and ev.on_order({"items":["fruit_5"]}) == 2 and ev.on_order({"items":["fruit_8"]}) == 3, "orders award exactly 1 to 3 based on configured difficulty")
	var r: Dictionary = ev.local_action(c,s,"spawn",{"view":10})
	check(r.get("kind") == "spawn" and s["points"] == 5, "bubble consumes one point and fills nearest free cell")
	var from: int = r["to"]
	r = ev.local_action(c,s,"drop",{"from":from,"to":0,"view":10})
	check(r.has("error") and cells[0]["lock"] == 2, "cannot jump into unrevealed rows")
	check(ev.local_action(c,s,"drop",{"from":from,"to":90,"view":10}).has("error"), "covered items cannot merge directly")
	ev.local_action(c,s,"drop",{"from":from,"to":96,"view":10})
	var second: Dictionary = ev.local_action(c,s,"spawn",{"view":10})
	r = ev.local_action(c,s,"drop",{"from":second["to"],"to":96,"view":10})
	check(r.get("kind")=="merge" and cells[90]["lock"]==1 and cells[84]["lock"]==2, "adjacent merge reveals only immediate covered neighbors and leaves items locked")
	check(ev.local_action(c,s,"drop",{"from":96,"to":90,"view":10}).has("error"), "mismatched item cannot unlock a revealed tile")
	var third: Dictionary = ev.local_action(c,s,"spawn",{"view":10})
	r = ev.local_action(c,s,"drop",{"from":third["to"],"to":90,"view":10})
	check(r.get("kind")=="merge" and cells[90]["id"]=="glow_2" and cells[90]["lock"]==0 and cells[84]["lock"]==1, "matching revealed item unlocks and uncovers next neighbors")
	var scroll: Dictionary=s.duplicate(true)
	for k in range(60,102):scroll["cells"][k]={"lock":0,"id":""}
	scroll["cells"][101]["id"]="glow_3"
	scroll["discovered"]["glow_4"]=true
	ev._advance(c,scroll)
	check(scroll["view"]==7 and scroll["cells"][101]["id"]=="" and scroll["cells"].slice(42,84).any(func(v):return v["id"]=="glow_3"), "automatic scroll carries lower items into the new visible area")
	var stages: Dictionary=ev.fresh(c)
	for cell in stages["cells"]: cell["lock"]=0; cell["id"]=""
	stages["discovered"]["glow_3"]=true
	ev._advance(c,stages)
	check(stages["view"]==10,"clear rows alone cannot advance before tier unlock")
	for pair in [[4,7],[6,4],[8,0]]:
		stages["discovered"]["glow_%d"%pair[0]]=true
		ev._advance(c,stages)
		check(stages["view"]==pair[1],"tier %d advances configured rows"%pair[0])
		ev._advance(c,stages)
		check(stages["view"]==pair[1],"same tier cannot advance twice")
	var delayed: Dictionary=ev.fresh(c)
	delayed["discovered"]["glow_4"]=true
	for k in [93,94,95]: delayed["cells"][k]={"lock":0,"id":""}
	ev._advance(c,delayed)
	check(delayed["view"]==9 and delayed["cells"][90]["lock"]==2 and delayed["cells"].slice(93,96).any(func(v):return v["id"]=="brush"),"uncleared lower cells remain reachable with pending advancement")
	for cell in delayed["cells"].slice(78,96): cell["lock"]=0; cell["id"]=""
	delayed["cells"][95]["id"]="glow_8"
	ev.local_action(c,delayed,"recycle",{"cell":95,"view":9})
	check(delayed["view"]==7,"later action spends pending advancement without a new tier")
	# ---- 三条线：灯光掉壁画、壁画合成出奖励、画笔吃颜料画壁画
	var t: Dictionary = ev.fresh(c)
	var tc: Array = t["cells"]
	check(tc[98]["id"] == "brush" and t["brush"]["charges"] == 0 and tc[88]["id"] == "paint_1" and tc[88]["lock"] == 2, "brush starts on the bottom row and paint is buried under a covered tile")
	check(ev.local_action(c,t,"brush",{"cell":98,"view":10}).has("error") and not ev.can_brush(c,t,98), "empty brush cannot paint")
	for k in range(84, 96): tc[k] = {"id":"", "lock":0}
	tc[87] = {"id":"glow_1","lock":0}
	tc[88] = {"id":"paint_1","lock":2}
	tc[89] = {"id":"glow_1","lock":0}
	r = ev.local_action(c,t,"drop",{"from":87,"to":89,"view":10})
	check(r.get("kind") == "merge" and tc[88]["lock"] == 0, "revealed paint is usable at once")
	r = ev.local_action(c,t,"drop",{"from":88,"to":98,"view":10})
	check(r.get("kind") == "feed" and t["brush"]["charges"] == 2 and t["brush"]["fed"] == 1 and tc[88]["id"] == "", "paint dropped on the brush adds its charges")
	check(ev.can_brush(c,t,98), "charged brush can paint")
	r = ev.local_action(c,t,"brush",{"cell":98,"view":10},0.0)
	check(r.get("kind") == "brush" and str(r["id"]) == "mural_1" and t["brush"]["charges"] == 1 and tc[int(r["to"])]["id"] == "mural_1", "brush paints a mural next to itself and spends one charge")
	var m1: int = r["to"]
	r = ev.local_action(c,t,"brush",{"cell":98,"view":10},0.99)
	check(str(r.get("id")) == "mural_3", "brush roll follows configured tier weights")
	tc[int(r["to"])]["id"] = "mural_1"
	r = ev.local_action(c,t,"drop",{"from":int(r["to"]),"to":m1,"view":10})
	check(r.get("kind") == "merge" and tc[m1]["id"] == "mural_2" and r["placed"].size() == 1 and str(r["placed"][0]["id"]) == "fire_2", "mural merge leaves its reward on the event board")
	var fire_at: int = r["placed"][0]["to"]
	check(not ev.is_bubble(c,"fire_2") and ev.is_bubble(c,"chest_1"), "resources collect by tap, chests show as bubbles")
	r = ev.local_action(c,t,"collect",{"cell":fire_at,"view":10})
	check(r.get("kind") == "collect" and tc[fire_at]["id"] == "" and r["rewards"] == [["fire_2",1,"item"]], "collecting a resource clears the cell and returns its reward")
	# 底行压一块未揭开的格子，让后面几步都在同一视野里进行。
	tc[101] = {"id":"glow_1","lock":2}
	for k in 5: tc[84 + k] = {"id":"glow_5","lock":0}
	tc[89] = {"id":"glow_5","lock":0}
	r = ev.local_action(c,t,"drop",{"from":84,"to":85,"view":10})
	check(r.get("kind") == "merge" and tc[85]["id"] == "glow_6" and r["placed"].size() == 1 and str(r["placed"][0]["id"]) == "mural_1", "high light merge drops a mural")
	for k in range(60, 102):
		if tc[k]["id"] == "" and int(tc[k]["lock"]) == 0: tc[k]["id"] = "paint_2"
	tc[86]["id"] = "glow_5"
	r = ev.local_action(c,t,"drop",{"from":86,"to":87,"view":10})
	check(r.get("kind") == "merge" and r["queued"] == 0 and r["placed"].size() == 1 and str(r["placed"][0]["to"]) == "86", "drop fills the freed source cell first")
	tc[88]["id"] = "glow_6"
	r = ev.local_action(c,t,"drop",{"from":88,"to":87,"view":10})
	var full: bool = r.get("kind") == "merge" and int(r.get("queued", 0)) >= 1
	check(full and t["queue"].size() >= 1, "drops on a full board wait in the queue instead of vanishing")
	var waiting: int = t["queue"].size()
	r = ev.local_action(c,t,"recycle",{"cell":89,"view":10})
	check(t["queue"].size() == waiting - 1 and r.has("flushed"), "queued drops come out when a cell frees up")
	tc[60] = {"id":"mural_8","lock":0}
	r = ev.local_action(c,t,"collect",{"cell":60,"view":10})
	check(r.get("kind") == "hang" and tc[60]["id"] == "", "top-tier mural is hung on the wall")
	check(ev.local_action(c,t,"recycle",{"cell":98,"view":10}).has("error"), "brush cannot be recycled")
	var saved: Dictionary = g.save_dict().duplicate(true)
	g.save_game()
	g.merge_events = {}
	g.load_game()
	check(g.merge_events == saved["merge_events"], "event points and board survive save/reload")
	c = ev.current()
	s = ev.state(c)
	var next: Dictionary = ev.current(float(c["ends_at"]) + 1)
	check(next["key"] != c["key"] and ev.state(next).is_empty() and ev.fresh(next)["points"] == 0 and s["points"] == 3, "new period starts fresh without mutating the current state during a query")
	s["cells"][100] = {"id":"fire_3","lock":0}
	s["cells"][101] = {"id":"chest_1","lock":0}
	var e0: int = g.energy
	var st0: int = g.stash.count("chest_1")
	var got_fire: Dictionary = await ev.act(c,"collect",{"cell":100,"view":10})
	var got_chest: Dictionary = await ev.act(c,"collect",{"cell":101,"view":10})
	check(not got_fire.has("error") and g.energy == e0 + 5, "collecting fire on the event board pays energy")
	check(not got_chest.has("error") and g.stash.count("chest_1") == st0 + 1, "collecting a chest bubble sends it to the main board stash")
	check((await ev.act(c,"claim")).has("error"), "cannot claim unfinished board")
	s = ev.state(c)
	var ms: Array = ev.milestones(c)
	check(ms.size() >= 3 and int(ms[-1]["at"]) == ev.goal_total(c), "milestones end at the full board goal")
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
	s = ev.state(c)
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
