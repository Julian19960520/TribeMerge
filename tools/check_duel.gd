extends SceneTree
var failures:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func run() -> void:
	load("res://scripts/events/ActivitySchedule.gd").bypass = true # 只测单个活动玩法，不受档期轮换影响
	var g=root.get_node("G")
	var duel=load("res://scripts/events/DuelRace.gd")
	g.set_process(false)
	g.simulation_time=1793577600
	g.new_game()
	g.rng.seed=41
	check(duel.local_action("join").has("error"),"locked player cannot join")
	g.level=int(JSON.parse_string(FileAccess.get_file_as_string("res://data/duel_race.json"))["unlock_level"])
	check(duel.order_points({"items":["fruit_1"]})==1 and duel.order_points({"items":["fruit_8"]})==4,"legacy rounds: difficulty uses configured order points")
	# 新版订单按预计消耗体力给分（不限 10~45）
	var easy_pts: int = duel.order_score({"items":["fruit_3"]})
	var hard_pts: int = duel.order_score({"items":["fruit_10"]})
	var top_pts: int = duel.order_score({"items":["fruit_11"]})
	check(easy_pts==2 and hard_pts>45 and top_pts==140 and hard_pts>easy_pts,"order_score scales with expected energy (%d < %d < %d)" % [easy_pts, hard_pts, top_pts])
	# 主棋盘合成按高/小概率物品阶梯规则计分
	var main_merge := []
	for l in range(4, 11): main_merge.append(duel.merge_score("fruit_%d" % l))
	var sub_merge := []
	for l in range(1, 8): sub_merge.append(duel.merge_score("seed_%d" % l))
	check(main_merge==[0,1,1,2,2,2,3] and sub_merge==[0,1,2,2,2,3,3],"merge_score matches main/sub tier rules (%s / %s)" % [main_merge, sub_merge])
	check(duel.local_action("milestone",2).has("error"),"cannot claim wins in advance")
	var expected_targets := [30, 60, 100, 150, 210, 280, 360, 400, 400, 400, 400, 400]
	var first_opp_end := 0.0
	var last_opp_end := 0.0
	for round_id in 12:
		check(not (await duel.act("join")).has("error"),"join round %d"%(round_id+1))
		check(duel.local_action("join").has("error"),"active round cannot be overwritten")
		check(duel.local_action("claim").has("error"),"unfinished round cannot pay")
		# 新局（pv=3）忽略老入口和 200~600 通用积分入口
		duel.on_order({"items":["fruit_8"]})
		check(int(duel.state()["match"]["me"])==0,"new rounds ignore legacy per-order points")
		check(not duel.add_points(300),"pv=3 duel ignores legacy 200~600 activity points")
		var target:=int(duel.state()["match"]["target"])
		check(target==expected_targets[round_id],"round %d target is %d (got %d)"%[round_id+1,expected_targets[round_id],target])
		var opp_end := float(duel.state()["match"]["opponent_curve"].back()[0])
		if round_id == 0: first_opp_end = opp_end
		if round_id == 11: last_opp_end = opp_end
		for i in int(ceil(target/30.0)): duel.add_duel_points(30)
		var s: Dictionary=duel.state()
		check(s["match"]["status"]=="won" and int(s["wins"])==round_id+1,"first to target wins exactly once")
		check(not duel.add_duel_points(30),"settled match takes no more points")
		duel.tick()
		check(int(s["wins"])==round_id+1,"settled match cannot add another win")
		var before_e: int=g.energy
		var before_stash: int=g.stash.size()
		await duel.act("claim")
		check(g.energy==before_e+10 and g.stash.size()==before_stash+1,"winner receives 10 energy + 1 chest")
		check((await duel.act("claim")).has("error") and g.energy==before_e+10,"duplicate reward blocked")
	check(last_opp_end > first_opp_end * 2.0,"opponent duration scales up with target (%.0fs -> %.0fs)"%[first_opp_end,last_opp_end])
	check(duel.ready_milestones()==[2,5,8,12],"all four milestones visible and claimable")
	for at in [2,5,8,12]:
		check(not (await duel.act("milestone",at)).has("error"),"claim %d wins"%at)
		check((await duel.act("milestone",at)).has("error"),"milestone only once")
	check("premiumbox_1" in g.stash and "fire_3" in g.stash and "fire_4" in g.stash and "premiumbox_3" in g.stash and "scissors_1" in g.stash,"milestone physical rewards delivered to stash")
	await duel.act("join")
	g.simulation_time+=5000
	duel.add_duel_points(30)
	check(duel.state()["match"]["status"]=="lost" and duel.state()["wins"]==12,"elapsed opponent finish wins before late player order")
	var e_before: int=g.energy
	await duel.act("claim")
	check(g.energy==e_before+10,"loser receives 10 energy reward")
	g.simulation_time=-1
	g.save_game()
	g.duel_race={}
	g.load_game()
	check(duel.state()["wins"]==12 and duel.ready_milestones().is_empty(),"reload preserves wins and claimed milestones")
	g.new_game()
	check(duel.state()["wins"]==0,"new game resets duel progression")
	g.level=int(JSON.parse_string(FileAccess.get_file_as_string("res://data/duel_race.json"))["unlock_level"])
	g.simulation_time=1793577600
	g.rng.seed=7
	check(not (await duel.act("join")).has("error"),"join first match at 0 wins")
	check(int(duel.state()["match"]["target"])==30 and duel.next_target()==30,"0 wins keeps the 30 target")
	g.simulation_time+=5000
	duel.tick()
	check(duel.state()["match"]["status"]=="lost" and int(duel.state()["wins"])==0,"losing does not add a win")
	await duel.act("claim")
	check(duel.next_target()==30,"a loss does not raise the next target")
	check(not (await duel.act("join")).has("error"),"rejoin after a loss")
	check(int(duel.state()["match"]["target"])==30,"second match stays at 30 after a loss")
	for i in 2: duel.add_duel_points(30)
	check(duel.state()["match"]["status"]=="won" and int(duel.state()["wins"])==1,"winning once raises the win count")
	await duel.act("claim")
	check(duel.next_target()==60,"one win raises the next target to 60")
	print("RESULT: ",failures," failures")
	quit(1 if failures else 0)
