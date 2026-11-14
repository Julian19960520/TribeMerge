extends SceneTree
var failures := 0
var g
var replay
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func fresh() -> void:
	replay.executing = true
	replay.meta = {}; replay.seq = 0; replay.base = 0; replay.pending = []; replay.inflight = {}
	replay.clock = 1794240000; g.simulation_time = replay.clock
	g.new_game(); g.random_seed = "order-flow"; g.random_streams = {}
	replay.advance(); replay._canonicalize_live(); replay.executing = false
	for i in g.board.size(): g.board[i] = {"id": "", "lock": 0}
	g.clear_presentations()
func card(id: String, xp: int, stamp: int) -> Dictionary:
	var o: Dictionary = g.order_identity({"who": 0, "items": [id], "rw": {"shell": 1}, "story": false, "xp_level": stamp})
	if xp > 0: o["rw"]["xp"] = xp
	return o
func run() -> void:
	g = root.get_node("G"); replay = root.get_node("Replay")
	for node in root.get_children(): node.set_process(false)
	fresh(); g.level = 2
	var p: Dictionary = g.rules.onboarding.progress()
	p["step"] = g.rules.onboarding.stage_index("free_level2")
	for row in g.rules.onboarding.config()["orders"]: p["issued"].append(str(row["tag"]))
	var old: Dictionary = g.order_identity({"who": 1, "items": ["seed_4"], "rw": {"shell": 29, "xp": 1}, "story": true, "onboarding": "seed_second"})
	g.orders = [old]; var uid := str(old["uid"])
	g.board[0]["id"] = "seed_4"; g.board[1] = {"id": "seed_4", "lock": 1}
	replay.perform("tick", {}, replay.clock)
	check(old["items"] == ["seed_5"] and old["uid"] == uid and old["rw"]["xp"] == 1 and not g.rules.orders.order_ready(old), "截图旧订单转为藤蔓合成后的核桃，保留订单身份和经验")
	var merged: Dictionary = replay.perform("drop", {"from": 0, "to": 1}, replay.clock)
	check(merged.get("kind", "") == "merge" and g.board[1]["id"] == "seed_5" and g.board[1]["lock"] == 0 and g.rules.orders.order_ready(old), "解开藤蔓后直接满足订单，不再二选一")
	g.board[2] = {"id": "seed_5", "lock": 1}
	replay.perform("tick", {}, replay.clock)
	check(old["items"] == ["seed_6"], "新露出同级藤蔓时继续指向合成产物")
	g.board[2]["lock"] = 0; replay.perform("tick", {}, replay.clock)
	check(old["items"] == ["seed_6"], "已提升的目标不因藤蔓消失而倒退")
	fresh(); g.level = 8; g.tutorial_on = false; g.board[0]["id"] = "basket_5"
	for row in [[1, "seed_3"], [2, "seed_4"], [3, "fruit_4"]]: g.board[row[0]] = {"id": row[1], "lock": 1}
	var safe := true; var preferred := 0
	for _i in 150:
		var o: Dictionary = g.rules.orders._make_order(32)
		for id in o["items"]:
			if str(id) in ["seed_3", "seed_4", "fruit_4"]: safe = false
			if str(id) == "fruit_5": preferred += 1
	check(safe and preferred > 0, "随机订单避开可见藤蔓材料，原难度内偏好解锁产物")
	var crafts := 0; var xp := 0; var recipes := true
	for row in g.rules.onboarding.config()["orders"]:
		if int(row["level"]) != 4: continue
		xp += int(row["xp"])
		if row.has("dish"):
			crafts += 1
			var mats: Array = Data.DISHES[str(row["dish"])]["mats"]
			recipes = recipes and mats.size() <= 2
			for id in mats: recipes = recipes and Data.lv(str(id)) >= (4 if Data.chain(str(id)) == "seed" else 5)
	check(crafts == 2 and recipes and xp == Data.xp_need(4), "4级两张制作单各用一至两种较高级材料，总经验足够升级")
	var seed_demands := 0; var seed_units := 0
	for row in g.rules.onboarding.config()["orders"]:
		var ids: Array = Data.DISHES[str(row["dish"])]["mats"] if row.has("dish") else row["items"]
		for id in ids:
			if Data.chain(str(id)) == "seed": seed_demands += 1; seed_units += int(pow(2, Data.lv(str(id)) - 1))
	check(seed_demands == 2 and seed_units == 16, "新手坚果需求从4次降为2次，基础一级材料总量从64降为16")
	fresh(); g.level = 2
	p = g.rules.onboarding.progress(); p["step"] = g.rules.onboarding.stage_index("free_level2")
	for row in g.rules.onboarding.config()["orders"]: p["issued"].append(str(row["tag"]))
	var repeat: Dictionary = g.order_identity({"who": 0, "items": ["seed_5"], "rw": {"shell": 43, "xp": 1}, "story": true, "onboarding": "seed_last", "guide_revision": 3})
	var prepared: Dictionary = g.order_identity({"who": 0, "items": ["seed_5"], "rw": {"shell": 43, "xp": 1}, "story": true, "onboarding": "seed_second", "guide_revision": 3})
	g.orders = [repeat, prepared]; g.board[0]["id"] = "seed_5"
	# The ready legacy card remains fulfillable; verify the replacement separately.
	g.rules.onboarding._sync_orders()
	check(prepared["items"] == ["seed_5"] and prepared["rw"] == {"shell": 43, "xp": 1}, "已经备齐的核桃订单保持原材料和原奖励")
	g.board[0]["id"] = ""; repeat["guide_revision"] = 3
	g.rules.onboarding._sync_orders()
	check(repeat["items"] == ["fruit_5"] and repeat["rw"]["xp"] == 1, "尚未完成的重复核桃单直接减负为果子单，经验不变")
	fresh(); g.level = 4
	p = g.rules.onboarding.progress(); p["step"] = g.rules.onboarding.stage_index("free_level4")
	for row in g.rules.onboarding.config()["orders"]: p["issued"].append(str(row["tag"]))
	var migrated_recipe: Dictionary = g.order_identity({"who": 0, "items": ["seed_5"], "mats": ["seed_5"], "dish": "trailpack", "kind": "craft", "phase": "need", "manual_collect": true, "rw": {"shell": 13, "xp": 2}, "story": true, "onboarding": "craft7", "guide_revision": 3})
	g.orders = [migrated_recipe]
	g.rules.onboarding._sync_orders()
	check(migrated_recipe["mats"] == ["seed_4", "fruit_5"] and Data.is_dish(str(migrated_recipe["dish"])) and root.get_node("Items").has_animation(str(migrated_recipe["dish"])) and migrated_recipe["rw"]["xp"] == 2, "旧烘烤坚果单降为4级材料，保留经验并使用有效产物图片ID")
	g.board[0]["id"] = "seed_4"; g.board[1]["id"] = "fruit_5"
	var made: Dictionary = replay.perform("craft", {"cell": 0}, replay.clock)
	g.simulation_time = replay.clock + 250; replay.perform("tick", {}, int(g.simulation_time))
	var collected: Dictionary = replay.perform("tap", {"cell": 0}, replay.clock)
	var migrated_save: Dictionary = replay.snapshot()
	check(not made.has("error") and not collected.has("error") and g.board[0]["id"] == "trailpack" and replay.restore(migrated_save), "迁移后的制作订单可完成、取出并保存恢复")
	fresh(); g.level = 4; g.energy = 65
	p = g.rules.onboarding.progress(); p["step"] = g.rules.onboarding.stage_index("free_energy_gift")
	p["delivered"] = ["craft6", "craft7"]
	g.stash = ["emberpot_1", "basket_1"]
	var main = load("res://main.tscn").instantiate(); root.add_child(main); main.show_screen("board", true)
	main._guide._refresh()
	check(main._guide.visible and main._guide._mode == "stash" and g.rules.board.stash_claim_index() == 0, "两张制作完成后直接提示取火种罐，不强刷空体力")
	replay.perform("stash", {"index": 0}, replay.clock); main._guide._refresh()
	check(str(g.rules.onboarding.stage()["key"]) == "energy_gift" and g.energy == 65, "取出后直接接上火种罐教学，已有体力不扣除")
	await process_frame
	main.free(); g.main = null
	fresh(); g.level = 4
	p = g.rules.onboarding.progress(); p["step"] = g.rules.onboarding.stage_index("free_level4")
	for row in g.rules.onboarding.config()["orders"]: p["issued"].append(str(row["tag"]))
	var low: Dictionary = g.order_identity({"who": 0, "kind": "craft", "phase": "need", "dish": "dish_cutfruit", "mats": ["fruit_2"], "items": ["fruit_2"], "rw": {"shell": 5, "xp": 1}, "onboarding": "craft4", "story": true})
	var cooking: Dictionary = g.order_identity({"who": 1, "kind": "craft", "phase": "cook", "dish": "dish_fruitbasket", "mats": ["fruit_5", "fruit_6", "seed_3"], "items": ["fruit_5", "fruit_6", "seed_3"], "rw": {"shell": 35, "xp": 1}, "onboarding": "craft6", "story": true})
	g.orders = [low, cooking]; replay.perform("tick", {}, replay.clock)
	check(not low.has("kind") and low["rw"]["xp"] == 1 and cooking["phase"] == "cook" and cooking["mats"].size() == 3 and cooking["rw"]["xp"] == 1, "旧低级制作单转普通单，已开工材料和已有经验均保留")
	fresh(); g.tutorial_on = false; g.level = 10; g.xp = Data.xp_need(10) - 1
	replay.meta["order_xp_level"] = 10
	var star := card("fruit_2", 1, 10); var zero := card("fruit_3", 0, 10)
	g.orders = [star, zero]
	var incoming := card("fruit_4", 0, 0)
	g.rules.orders._insert_random(incoming, 0); g.rules.orders.assign_xp()
	check(star["rw"].get("xp", 0) == 1 and zero["rw"].get("xp", 0) == 0 and incoming["rw"].get("xp", 0) == 0, "新订单插到前面也不会抢走已有经验单")
	var snap: Dictionary = replay.snapshot(); replay.restore(snap)
	g.rules.orders.assign_xp()
	check(g.orders[1]["rw"].get("xp", 0) == 1 and g.orders[0]["rw"].get("xp", 0) == 0, "恢复存档不重新洗经验")
	g.orders = [zero, star, incoming]; g.board[0]["id"] = "basket_5"
	replay.executing = true; g.rules.progression.add_xp(1); replay.executing = false
	check(g.level == 11 and zero["rw"].get("xp", 0) == 1, "只有升级后才给已有无经验订单重新分配经验")
	fresh(); g.tutorial_on = false; g.level = 10; g.xp = Data.xp_need(10) - 2
	replay.meta["order_xp_level"] = 10; g.board[0]["id"] = "basket_5"; g.board[1]["id"] = "fruit_1"
	star = card("fruit_1", 1, 10); var waiting := card("fruit_5", 1, 10)
	g.orders = [star, waiting, card("fruit_6", 0, 10), card("fruit_7", 0, 10)]
	var delivered: Dictionary = replay.perform("order", {"cell": 0}, replay.clock)
	var stars := 0
	for o in g.orders: stars += int(o["rw"].get("xp", 0))
	check(not delivered.has("error") and waiting["rw"].get("xp", 0) == 1 and stars == 1, "交单先结算经验再补新单，已有星不转移也不超分")
	quit(1 if failures else 0)
