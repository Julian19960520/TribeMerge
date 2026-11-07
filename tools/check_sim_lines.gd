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
	g.tutorial_on=false
	g.simulation_time=1793577600
	for cell in g.board: cell["id"]=""; cell["lock"]=0
	g.inv=[]
	g.stash=[]
	var bot=load("res://tools/sim/PlayerBot.gd").new()
	root.add_child(bot)
	bot.start=g.now()
	bot.stream=FileAccess.open("user://sim-lines-check.jsonl",FileAccess.WRITE)
	g.board[0]["id"]="basket_2"
	check(bot.production_line_totals()["gen_total_food"]==2,"level 2 basket counts as 2")
	g.board[0]["id"]="basket_3"
	check(bot.production_line_totals()["gen_total_food"]==4,"level 3 basket counts as 4")
	g.board[0]["id"]="basket_2"
	g.board[1]["id"]="basket_3"
	var totals: Dictionary=bot.production_line_totals()
	check(totals["gen_total_food"]==6,"level 2 basket plus level 3 basket equals total 6")
	check(bot.production_line_levels()["gen_max_food"]==3,"highest level is 3 rather than equivalent total 6")
	check(totals.size()==7 and totals["gen_total_tool"]==0,"all seven lines have independent totals including zero")
	g.board[2]={"id":"basket_7","lock":1}
	g.board[3]={"id":"basket_7","lock":2}
	g.board[4]={"id":"basket_7","lock":3,"bubble":{"expires":g.now()+60}}
	g.board[5]["id"]="fruit_7"
	g.inv=["basket_1","anvil_3"]
	g.stash=["basket_2","loom_4","chest_1"]
	totals=bot.production_line_totals()
	check(totals["gen_total_food"]==9 and totals["gen_total_tool"]==4 and totals["gen_total_cloth"]==8,"owned board, storage and stash counted; ordinary items excluded")
	check(totals["gen_total_food"]==9,"locked, covered and unpurchased generators excluded")
	var levels: Dictionary=bot.production_line_levels()
	check(levels["gen_max_food"]==3 and levels["gen_max_tool"]==3 and levels["gen_max_cloth"]==4,"highest levels include storage and stash, excluding locked generators")
	g.inv.erase("anvil_3")
	g.board[6]["id"]="anvil_3"
	check(bot.production_line_totals()==totals,"moving from storage to board preserves totals")
	g.stash.erase("loom_4")
	g.board[7]["id"]="loom_4"
	check(bot.production_line_totals()==totals,"moving from stash to board preserves totals")
	check(bot.production_line_levels()==levels,"moving generators between owned locations preserves highest levels")
	g.board[0]["id"]="basket_2"
	g.board[1]["id"]="basket_2"
	bot.before=bot.snap()
	check(g.try_drop(0,1)=="merge","generator pair merges using actual game rules")
	bot.record("merge","测试生产器合成","核对一级份数守恒")
	var e: Dictionary=bot.events[-1]
	check(e["state"]["gen_total_food"]==7 and not e["delta"].has("gen_total_food"),"two level 2 generators become one level 3; equivalent count is conserved")
	check(e["state"]["gen_total_tool"]==4 and not e["delta"].has("gen_total_tool"),"unrelated line remains unchanged on merge")
	g.new_game()
	check(bot.production_line_totals()["gen_total_tool"]==0,"new run resets line totals")
	check(bot.production_line_levels()["gen_max_tool"]==0,"new run resets highest levels")
	bot.begin_resource_tracking()
	check(bot.snap()["amber_earned"]==0 and bot.snap()["sand_earned"]==0,"initial resources are excluded from earned totals")
	g.add_currency("amber",10)
	g.spend("amber",30)
	g.add_currency("amber",20)
	g.add_currency("sand",5)
	g.spend("sand",3)
	g.add_currency("sand",4)
	var resources: Dictionary=bot.snap()
	check(resources["amber_earned"]==30 and resources["gems"]==80,"same-action spending and income count gross earned amber, not net change")
	check(resources["sand_earned"]==9 and resources["sand"]==6,"sand earned total is separate from remaining quantity")
	check(bot.snap()==resources,"repeated snapshots do not count income twice")
	bot.resource_tracking=false
	g.new_game()
	bot.begin_resource_tracking()
	check(bot.snap()["amber_earned"]==0 and bot.snap()["sand_earned"]==0,"new run resets cumulative resource totals")
	for cell in g.board: cell["id"]=""; cell["lock"]=0
	g.inv=[]
	g.stash=[]
	g.tutorial_on=false
	g.board[0]["id"]="fruit_1"
	g.board[1]["id"]="fruit_1"
	g.board[1]["lock"]=1
	bot.before=bot.snap()
	var when: float=g.now()
	check(bot.merge_main(),"actual merge unlocks a vine cell")
	var unlock: Dictionary=bot.events[-1]
	var merge: Dictionary=bot.events[-2]
	check(unlock["category"]=="unlock" and unlock["detail"]["cell"]==1 and unlock["detail"]["board"]=="main","vine unlock has an independent event with grid location")
	check(unlock["time"]==merge["time"] and unlock["detail"]["merge_seq"]==merge["seq"] and g.now()==when,"unlock shares the merge time without advancing the clock")
	check(unlock["state"]==merge["state"] and unlock["delta"].is_empty(),"unlock does not duplicate resource or generator changes")
	check(not unlock.has("reason") and not merge.has("reason"),"recorded events omit decision reasons")
	for cell in g.board: cell["id"]=""; cell["lock"]=0
	g.board[0]["id"]="fruit_1"
	g.board[1]["id"]="fruit_1"
	g.board[2]["id"]="fruit_3"
	g.board[2]["lock"]=2
	bot.before=bot.snap()
	var count_before: int=bot.events.size()
	check(bot.merge_main(),"merge can reveal a covered neighbor")
	check(g.board[2]["lock"]==1 and bot.events.size()==count_before+1 and bot.events[-1]["category"]=="merge","revealing a vine beneath cover is not recorded as unlocking it")
	check(bot.reward_summary([["fire_3",2,"item"],["shell_2",60],["chest_1",1]])=="体力×10、贝币×60、藤编宝箱×1","reward summary follows credited resource units and physical item quantities")
	g.level=2
	bot.claimed_levels={}
	await bot.rewards()
	var reward: Dictionary=bot.events[-1]
	check(reward["reward_source"]=="level" and reward["detail"]["level"]==2 and not reward["detail"]["rewards"].is_empty(),"level reward stores actual claimed items")
	check(reward["detail"]["received"]==bot.reward_summary(reward["detail"]["rewards"]),"level reward receipt matches the recorded grant")
	bot.stream.close()
	bot.queue_free()
	await process_frame
	print("RESULT: ",failures," failures")
	quit(1 if failures else 0)
