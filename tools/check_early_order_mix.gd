extends SceneTree
var failures := 0
var g
var replay
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func fresh(level: int) -> void:
	replay.executing = true
	replay.meta = {}; replay.pending = []; replay.inflight = {}; replay.seq = 0; replay.base = 0
	replay.clock = 1794240000; g.simulation_time = replay.clock
	g.new_game(); replay.advance(); replay._canonicalize_live(); replay.executing = false
	g.level = level; g.xp = 0; g.builds["fire"] = 3; g.orders = []
	for i in g.board.size(): g.board[i] = {"id": "", "lock": 0}
	g.board[0]["id"] = "basket_5"
	var p: Dictionary = g.rules.onboarding.progress()
	p["step"] = g.rules.onboarding.stage_index("recipe_open" if level == 3 else "free_energy_gift")
	for row in g.rules.onboarding.config()["orders"]:
		if int(row["level"]) < level:
			p["issued"].append(str(row["tag"])); p["delivered"].append(str(row["tag"]))
	g.clear_presentations()
func run() -> void:
	g = root.get_node("G"); replay = root.get_node("Replay")
	for node in root.get_children(): node.set_process(false)
	var rows: Array = g.rules.onboarding.config()["orders"]
	var level_two_fruit_units := 0
	var count := {3: {"craft": 0, "normal": 0, "xp": 0}, 4: {"craft": 0, "normal": 0, "xp": 0}}
	for row in rows:
		if int(row["level"]) == 2:
			for id in row["items"]:
				if Data.chain(str(id)) == "fruit":
					check(Data.lv(str(id)) <= 6, "2级手配果子需求不再要求石榴")
					level_two_fruit_units += 1 << (Data.lv(str(id)) - 1)
		if count.has(int(row["level"])):
			var tally: Dictionary = count[int(row["level"])]
			tally["craft" if row.has("dish") else "normal"] += 1
			tally["xp"] += int(row["xp"])
	check(level_two_fruit_units == 80, "2级果子基础材料量由224降至80")
	fresh(2)
	for level in [5, 6, 7]: g.board[level] = {"id": "fruit_%d" % level, "lock": 1}
	g.rules.onboarding.refill()
	var affordable := true
	for order in g.orders:
		for id in order["items"]:
			if Data.chain(str(id)) == "fruit": affordable = affordable and Data.lv(str(id)) <= 6 and not g.rules.orders.vine_plan()["keys"].has(str(id))
	check(affordable, "连续水果藤蔓也不能把2级订单升级为石榴，改用预算内非藤蔓材料")
	check(count[3] == {"craft": 1, "normal": 2, "xp": 3} and count[4] == {"craft": 2, "normal": 1, "xp": 5}, "3级1制作+2普通，4级2制作+1普通，各级总经验保持不变")
	check(Data.DISHES["salad"]["mats"] == ["fruit_5"] and Data.DISHES["fruitbasket"]["mats"] == ["fruit_7"] and Data.DISHES["trailpack"]["mats"] == ["seed_4", "fruit_5"], "制作材料提升至5级果子、7级果子，坚果配方只补一个5级果子")
	for level in [3, 4]:
		fresh(level); g.rules.onboarding.refill()
		var crafts := 0; var normals := 0
		for order in g.orders:
			if str(order.get("kind", "")) == "craft": crafts += 1
			else: normals += 1
		check(crafts == 1 and normals == 1, "%d级第一对实际订单同时有制作和普通合成单" % level)
		var original: Array = g.orders.duplicate(true)
		g.rules.onboarding.refill()
		check(original == g.orders, "重复刷新不改已有经验和订单身份")
	fresh(3)
	var old: Dictionary = g.order_identity({"who": 0, "items": ["fruit_3"], "mats": ["fruit_3"], "kind": "craft", "dish": "berrybowl", "secs": 10, "phase": "need", "story": true, "onboarding": "craft2", "guide_revision": 4, "rw": {"shell": 6, "xp": 1}})
	g.orders = [old]; var uid := str(old["uid"])
	g.rules.onboarding._sync_orders()
	check(not old.has("kind") and old["items"] == ["fruit_6"] and old["rw"]["xp"] == 1 and old["uid"] == uid, "旧3级未开工制作单转普通单，保留经验和身份")
	fresh(4)
	var ready: Dictionary = g.order_identity({"who": 0, "items": ["seed_4"], "mats": ["seed_4"], "kind": "craft", "dish": "trailpack", "secs": 240, "phase": "need", "story": true, "onboarding": "craft7", "guide_revision": 4, "rw": {"shell": 13, "xp": 2}})
	g.orders = [ready]; g.board[1]["id"] = "seed_4"
	g.rules.onboarding._sync_orders()
	check(ready["mats"] == ["seed_4"] and ready["rw"]["xp"] == 2, "旧配方已经备齐材料时保留可制作状态")
	ready["phase"] = "cook"; ready["guide_revision"] = 4
	g.rules.onboarding._sync_orders()
	check(ready["mats"] == ["seed_4"] and ready["phase"] == "cook", "正在制作的旧配方继续完成")
	quit(1 if failures else 0)
