extends SceneTree
var failures := 0
var g
var replay
const START := 1794240000
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func fresh(level: int) -> void:
	replay.executing = true
	replay.meta = {}; replay.seq = 0; replay.base = 0; replay.pending = []; replay.inflight = {}
	replay.clock = START; g.simulation_time = START
	g.new_game(); g.level = level; g.tutorial_on = false; g.seen_tutorial = true
	g.orders = []; g.pending_orders = []
	for i in g.board.size(): g.board[i] = {"id": "", "lock": 0}
	g.board[0]["id"] = "basket_5"
	replay.executing = false
	g.clear_presentations()
func run() -> void:
	g = root.get_node("G"); replay = root.get_node("Replay")
	for node in root.get_children(): node.set_process(false)
	var early := true; var middle := true; var late := true
	for recipe in Data.DISHES.values():
		if int(recipe["unlock"]) <= 7: early = early and int(recipe["secs"]) <= 10
		if int(recipe["unlock"]) <= 29: middle = middle and int(recipe["secs"]) <= 600
		if int(recipe["unlock"]) >= 30: late = late and int(recipe["secs"]) >= 600 and int(recipe["secs"]) <= 2400
	check(early and middle and late, "前期制作不超过10秒，29级以前不超过10分钟，30级后逐渐增长")
	var at30 := true; var at5 := true; var rising := true
	for recipe in Data.dishes_for(30): at30 = at30 and Data.craft_secs(30, str(recipe["id"])) >= 300 and Data.craft_secs(30, str(recipe["id"])) <= 600
	for recipe in Data.dishes_for(5): at5 = at5 and Data.craft_secs(5, str(recipe["id"])) <= 20
	for lv in range(4, 40): rising = rising and Data.craft_secs(lv + 1, "salad") >= Data.craft_secs(lv, "salad")
	check(at30 and at5 and rising, "实际制作时长随等级变长：5级不超过20秒，30级在5～10分钟，同一道菜等级越高越久")
	var hard_dish := ""; var easy_dish := ""
	for recipe in Data.dishes_for(30):
		if hard_dish == "" or int(recipe["secs"]) > int(Data.DISHES[hard_dish]["secs"]): hard_dish = str(recipe["id"])
		if easy_dish == "" or int(recipe["secs"]) < int(Data.DISHES[easy_dish]["secs"]): easy_dish = str(recipe["id"])
	check(Data.craft_secs(30, hard_dish) > Data.craft_secs(30, easy_dish), "同一等级难的菜比简单的菜做得久")
	check(Data.DISHES["salad"]["secs"] == 5 and Data.DISHES["fruitbasket"]["secs"] == 10 and Data.DISHES["trailpack"]["secs"] == 10, "三张新手制作单分别为5秒、10秒、10秒")
	fresh(5)
	for id in Data.DISHES: g.discovered[id] = true
	var seen := {}; var substantial := true
	for _i in 200:
		var recipe: Dictionary = g.rules.orders._pick_dish()
		seen[str(recipe["id"])] = true
		substantial = substantial and OrderRoll.total(recipe["mats"]) >= 32 and int(recipe["secs"]) <= 10
	check(substantial and seen.size() == 3 and seen.has("cutfruit") and not seen.has("berrybowl") and not seen.has("nutmix"), "5级新制作单使用较高级食材，入门菜退出新订单池，仍10秒内完成")
	check(Data.DISHES["cutfruit"]["unlock"] == 5 and Data.DISHES["cutfruit"]["mats"] == ["fruit_8"], "5级解锁需要石榴的新制作单")
	check(Data.random_bounds(5) == Vector2i(32, 96) and Data.random_bounds(6).x >= 32 and Data.random_bounds(6).y >= 96, "5级普通单难度由14～77提高到32～96，后续等级不回落")
	var acceptable := true
	for _i in 50:
		var order: Dictionary = g.rules.orders._make_order(Data.random_slot_target(5, 0))
		acceptable = acceptable and OrderRoll.total(order["items"]) >= 28
	check(acceptable, "5级实际生成的最简单普通单也达到新的材料预算")
	fresh(4)
	var waiting: Dictionary = g.rules.orders._craft_order(Data.DISHES["trailpack"])
	waiting["secs"] = 240; waiting["mats"] = ["seed_4"]; waiting["items"] = ["seed_4"]
	waiting["rw"] = {"shell": 13, "xp": 2}
	var original: Dictionary = waiting.duplicate(true)
	var pending: Dictionary = waiting.duplicate(true); pending["uid"] = g.next_order_uid()
	g.orders = [waiting]; g.pending_orders = [pending]; g.board[1]["id"] = "seed_4"
	g.rules.orders._tick_cooks()
	var short4 := Data.craft_secs(4, "trailpack")
	check(waiting["secs"] == short4 and pending["secs"] == short4 and waiting["uid"] == original["uid"] and waiting["mats"] == original["mats"] and waiting["rw"] == original["rw"], "旧待制作单和排队单同步缩短时长，已备齐材料、经验和身份保留")
	fresh(4)
	var cooking: Dictionary = g.rules.orders._craft_order(Data.DISHES["salad"])
	cooking.merge({"secs": 60, "phase": "cook", "cell": 2, "t0": START - 8.0, "manual_collect": true}, true)
	cooking["rw"]["xp"] = 1
	g.orders = [cooking]
	g.board[2]["ck"] = {"dish": "salad", "secs": 60, "t0": START - 8.0, "uid": cooking["uid"], "mats": ["fruit_5"]}
	g.rules.orders._tick_cooks()
	var salad4 := Data.craft_secs(4, "salad")
	check(salad4 < 8 and cooking["secs"] == salad4 and cooking["t0"] == START - 8.0 and cooking["phase"] == "finished" and g.board[2]["ck"]["finished"] and cooking["rw"]["xp"] == 1, "正在制作的旧单不重置开工时间，已超过新时长立即完成并等待领取")
	var snapshot: Dictionary = replay.snapshot()
	check(replay.restore(snapshot) and g.orders[0]["phase"] == "finished" and g.board[2]["ck"]["secs"] == salad4, "缩短后的制作状态可保存并恢复")
	fresh(29)
	var work: Dictionary = g.rules.orders._craft_order(Data.DISHES["mask"])
	work.merge({"secs": 6000, "phase": "cook", "cell": 3, "t0": START - 120.0}, true)
	g.orders = [work]
	g.board[3]["ck"] = {"dish": "mask", "secs": 6000, "t0": START - 120.0, "uid": work["uid"], "mats": work["mats"].duplicate()}
	g.rules.orders._tick_cooks()
	var mask29 := Data.craft_secs(29, "mask")
	check(mask29 < 6000 and work["secs"] == mask29 and work["phase"] == "cook" and g.rules.orders.cook_left(3) == mask29 - 120 and g.rules.orders.rush_need(3) == int(ceil((mask29 - 120) / float(Data.rush_sec()))), "29级旧长单缩到当前等级时长，保留已制作2分钟，剩余时间及沙漏费用同步")
	fresh(4)
	var faster: Dictionary = g.rules.orders._craft_order(Data.DISHES["salad"])
	faster["secs"] = 2; g.orders = [faster]
	g.rules.orders._tick_cooks()
	check(faster["secs"] == 2, "已经更快的旧单不会被延长")
	quit(1 if failures else 0)
