extends SceneTree
var failures:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func run() -> void:
	var g=root.get_node("G")
	var data=load("res://scripts/Data.gd")
	g.set_process(false)
	g.new_game()
	check(data.order_total(1)==2 and data.order_total(4)==3 and data.order_total(10)==4 and data.order_total(20)==5,"shared order cap grows at configured levels")
	g.tutorial_on=false
	g.seen_tutorial=true
	g.level=10
	g.orders=[]
	g.refill_orders()
	check(g.orders.size()==data.order_total(g.level),"refill reaches shared total cap")
	check(g.orders.filter(func(o):return int(o["rw"].get("xp",0))>0).size()==mini(data.story_orders(g.level).size(),data.order_total(g.level)),"configured experience orders take every available slot")
	var first: Dictionary=g.orders[0].duplicate(true)
	g.board=[]
	for i in g.COLS*g.ROWS: g.board.append({"id":"","lock":0})
	for i in first["items"].size():g.board[i]["id"]=first["items"][i]
	g.complete_order(0)
	check(not g.orders.any(func(o):return o.get("si",-1)==first["si"]),"completed experience row never respawns before XP settlement")
	check(g.orders.size()<=data.order_total(g.level),"delivery refills without exceeding cap")
	# Mark current experience catalog complete: remaining slots are regular/crafting orders.
	for si in data.story_orders(g.level).size():g.story_done["%d:%d"%[g.level,si]]=true
	g.orders=[]
	g.refill_orders()
	check(g.orders.size()==data.order_total(g.level) and not g.orders.any(func(o):return o.get("story",false)),"random/crafting fill gaps only after experience catalog is exhausted")
	# A level transition can displace unstarted random orders but must preserve cooking.
	var craft: Dictionary=g.orders.filter(func(o):return o.get("kind","")=="craft")[0]
	craft["phase"]="cook"
	craft["t0"]=g.now()
	g.level=11
	g.refill_orders()
	check(g.orders.has(craft) and g.orders.size()==data.order_total(g.level),"cooking order survives level transition within cap")
	check(g.orders.filter(func(o):return o.get("story",false)).size()==data.order_total(g.level)-1,"experience replaces random orders at level transition")
	# Legacy overfull experience orders are deferred, not lost.
	g.level=4
	g.orders=[]
	g.pending_orders=[]
	for i in 7:g.orders.append({"who":0,"story":true,"si":i,"story_level":4,"items":["fruit_2"],"rw":{"xp":1,"shell":1}})
	g._trim_orders()
	check(g.orders.size()==data.order_total(4) and g.pending_orders.size()==4,"legacy overflow is queued without dropping experience orders")
	g.save_game()
	g.orders=[]
	g.pending_orders=[]
	g.load_game()
	check(g.orders.size()<=data.order_total(4) and g.pending_orders.size()==4,"save/reload preserves deferred orders")
	g.level=41
	g.orders=[]
	g.pending_orders=[]
	g.refill_orders()
	check(g.orders.size()==data.order_total(41) and not g.orders.any(func(o):return o.get("story",false)),"after configured main story, only side orders remain")
	print("RESULT: ",failures," failures")
	quit(1 if failures else 0)
