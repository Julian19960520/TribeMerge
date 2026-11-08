extends SceneTree
var failures:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func run() -> void:
	var g=root.get_node("G")
	var duel=load("res://scripts/events/DuelRace.gd")
	g.set_process(false)
	g.simulation_time=1793577600
	g.new_game()
	g.rng.seed=41
	check(duel.local_action("join").has("error"),"locked player cannot join")
	g.level=int(JSON.parse_string(FileAccess.get_file_as_string("res://data/duel_race.json"))["unlock_level"])
	check(duel.order_points({"items":["fruit_1"]})==1 and duel.order_points({"items":["fruit_8"]})==4,"difficulty uses configured order points")
	check(duel.local_action("milestone",2).has("error"),"cannot claim wins in advance")
	for round_id in 12:
		check(not (await duel.act("join")).has("error"),"join round %d"%(round_id+1))
		check(duel.local_action("join").has("error"),"active round cannot be overwritten")
		check(duel.local_action("claim").has("error"),"unfinished round cannot pay")
		for i in 8: duel.on_order({"items":["fruit_8"]})
		var s: Dictionary=duel.state()
		check(s["match"]["status"]=="won" and int(s["wins"])==round_id+1,"first to target wins exactly once")
		duel.on_order({"items":["fruit_8"]})
		duel.tick()
		check(int(s["wins"])==round_id+1,"settled match cannot add another win")
		var before: int=g.shells
		await duel.act("claim")
		check(g.shells==before+240,"winner receives configured coins")
		check((await duel.act("claim")).has("error") and g.shells==before+240,"duplicate reward blocked")
	check(duel.ready_milestones()==[2,5,8,12],"all four milestones visible and claimable")
	for at in [2,5,8,12]:
		check(not (await duel.act("milestone",at)).has("error"),"claim %d wins"%at)
		check((await duel.act("milestone",at)).has("error"),"milestone only once")
	await duel.act("join")
	g.simulation_time+=4000
	duel.on_order({"items":["fruit_8"]})
	check(duel.state()["match"]["status"]=="lost" and duel.state()["wins"]==12,"elapsed opponent finish wins before late player order")
	var coins: int=g.shells
	await duel.act("claim")
	check(g.shells==coins+60,"loser receives smaller configured reward")
	g.simulation_time=-1
	g.save_game()
	g.duel_race={}
	g.load_game()
	check(duel.state()["wins"]==12 and duel.ready_milestones().is_empty(),"reload preserves wins and claimed milestones")
	g.new_game()
	check(duel.state()["wins"]==0,"new game resets duel progression")
	print("RESULT: ",failures," failures")
	quit(1 if failures else 0)
