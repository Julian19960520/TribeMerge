extends SceneTree
var failures:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func run() -> void:
	var g=root.get_node("G")
	g.new_game()
	g.set_process(false)
	g.level=10
	g.seen_tutorial=true
	g.tutorial_on=false
	g.simulation_time=1793577600
	var duel=load("res://scripts/events/DuelRace.gd")
	var s: Dictionary=duel.state()
	s["wins"]=5
	s["claimed"]=["2"]
	var main=load("res://main.tscn").instantiate()
	root.add_child(main)
	var p=main.open("duel")
	p.set_process(false)
	await process_frame
	check(p.phase=="start" and p.find_child("duel_banana_pile_0",true,false)==null,"start panel has matching and milestones, without race progress")
	check(p.find_child("duel_reward_bubble",true,false)==null,"milestone rewards hidden until chest click")
	var gems: int=g.amber
	var chest=p.find_child("duel_milestone_5",true,false)
	chest.pressed.emit()
	check(p.find_child("duel_reward_bubble",true,false)!=null and g.amber==gems,"chest click previews without claiming")
	s["wins"]=6
	p._refresh()
	check(p.bubble_wins==5 and p.find_child("duel_claim_milestone",true,false)!=null,"start refresh preserves open reward bubble")
	p.find_child("duel_milestone_8",true,false).pressed.emit()
	check(p.bubble_wins==8 and p.find_child("duel_claim_milestone",true,false)==null,"locked chest opens preview without a claim button")
	p.find_child("duel_milestone_2",true,false).pressed.emit()
	check(p.bubble_wins==2 and p.find_child("duel_claim_milestone",true,false)==null,"claimed chest remains inspectable without another claim")
	p.on_tap.call()
	check(p.find_child("duel_reward_bubble",true,false)==null,"blank tap dismisses preview")
	p.find_child("duel_milestone_5",true,false).pressed.emit()
	p.find_child("duel_claim_milestone",true,false).pressed.emit()
	await process_frame
	check(g.amber==gems+20 and "5" in s["claimed"],"bubble claim awards configured reward once")
	check(p.bubble_wins==0 and p.find_child("duel_reward_bubble",true,false)==null,"claim dismisses bubble")
	await duel.act("milestone",5)
	check(g.amber==gems+20,"repeated claim cannot award twice")
	main.close_all()
	await create_timer(0.3).timeout
	p=main.open("duel")
	p.set_process(false)
	p.find_child("duel_action",true,false).pressed.emit()
	await process_frame
	check(p.phase=="matching" and p.find_child("duel_matching_portraits",true,false)!=null,"join opens the independent matching panel")
	check(p.find_child("duel_action",true,false)==null and p.find_child("duel_milestone_5",true,false)==null,"matching panel has no start, claim or milestone controls")
	var rounds: int=s["rounds"]
	p.close()
	await create_timer(0.3).timeout
	p=main.open("duel")
	p.set_process(false)
	check(p.phase=="matching" and s["rounds"]==rounds,"closing and reopening matching resumes without joining twice")
	p.matching_until=0
	p._refresh()
	check(p.phase=="progress" and p.find_child("duel_milestone_5",true,false)==null,"matching completes into a separate progress panel")
	for side in 2:
		var pile=p.find_child("duel_banana_pile_%d"%side,true,false)
		var person=p.find_child("duel_character_%d"%side,true,false)
		check(pile.position.y+pile.size.y<person.position.y,"banana pile above character %d"%side)
	p.find_child("duel_action",true,false).pressed.emit()
	await create_timer(0.3).timeout
	p=main.open("duel")
	p.set_process(false)
	check(p.phase=="progress" and s["rounds"]==rounds,"returning from orders resumes the current race")
	for i in 8: duel.on_order({"items":["fruit_8"]})
	p._refresh()
	check(p.phase=="result" and p.find_child("duel_banana_pile_0",true,false)==null,"finishing opens result without race or milestone content")
	var coins: int=g.shells
	p.find_child("duel_action",true,false).pressed.emit()
	await process_frame
	check(p.phase=="start" and s["match"]["claimed"] and g.shells==coins+240,"claim awards once and returns to the start panel")
	await duel.act("claim")
	check(g.shells==coins+240,"result cannot be claimed twice")
	await duel.act("join")
	g.simulation_time+=4000
	duel.tick()
	p._refresh()
	check(p.phase=="result" and s["match"]["status"]=="lost","opponent finish also opens result")
	coins=g.shells
	await p._action("claim")
	check(p.phase=="start" and g.shells==coins+60,"loss claims participation reward and returns to start")
	main.close_all()
	await create_timer(0.3).timeout
	var store=main.open("store")
	var order: Dictionary={}
	for label in store.find_children("*","Label",true,false):
		if label.text in ["每日特惠","贝币小摊","热卖","琥珀"]: order[label.text]=label.global_position.y
	check(order.size()==4 and order["每日特惠"]<order["贝币小摊"] and order["贝币小摊"]<order["热卖"] and order["热卖"]<order["琥珀"],"store order: daily, shell, hot, amber")
	main.close_all()
	await create_timer(0.3).timeout
	main.queue_free()
	await process_frame
	g.main=null
	print("RESULT: ",failures," failures")
	quit(1 if failures else 0)
