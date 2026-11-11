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
	g.main=null
	g.simulation_time=1793577600
	g.level=2
	g.shells=1000
	g.tutorial_on=false
	g.orders=[{"who":1,"items":["fruit_1"],"rw":{"shell":1},"story":false}]
	for cell in g.board: cell["id"]=""; cell["lock"]=0
	g.board[0]["id"]="fruit_1"
	var bot=load("res://tools/sim/PlayerBot.gd").new()
	root.add_child(bot)
	bot.cfg={"stop_level":40,"play_events":false}
	bot.start=g.now()
	bot.stream=FileAccess.open("user://sim-policy-check.jsonl",FileAccess.WRITE)
	bot.before=bot.snap()
	var stage: int=g.builds["fire"]
	var cost: int=g.rules.progression.build_cost("fire")
	check(g.rules.orders.order_ready(g.orders[0]),"fixture has a ready order")
	check(await bot.upgrade_tribe(),"tribe upgrades independently while order is ready")
	check(g.builds["fire"]==stage+1 and g.board[0]["id"]=="fruit_1","upgrade preserves order materials")
	check(bot.events[-1]["category"]=="build" and bot.events[-1]["detail"]["cost"]==cost,"tribe action logs its own cost and category")
	g.shells=0
	check(not await bot.upgrade_tribe(),"insufficient coins cannot upgrade")
	check(bot.submit_orders() and bot.events[-1]["category"]=="order","orders execute separately from tribe upgrade")
	for entry in [[39,false],[40,true],[41,true]]:
		g.level=entry[0]
		check(bot.target_level_reached()==entry[1],"stop predicate at Lv%d"%entry[0])
	bot.record_reward("book","图鉴测试","真实来源标记")
	check(bot.events[-1]["category"]=="reward" and bot.events[-1]["reward_source"]=="book","reward source survives serialization")
	bot.stream.close()
	bot.queue_free()
	await process_frame
	print("RESULT: ",failures," failures")
	quit(1 if failures else 0)
