extends SceneTree
## 参考竞品的分阶段新手流程：练习单不带经验、首次补体力免费、升级送订单材料、4 级送火种罐、提示只出一次。
## godot --headless --path . --script tools/check_onboarding_stages.gd -- --replay-test --cloud-off
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1

func _fresh(replay, game, level: int) -> void:
	replay.executing = true
	replay.seq = 0; replay.base = 0; replay.pending = []; replay.inflight = {}
	replay.clock = 1794240000; replay.meta = {}; game.simulation_time = replay.clock
	game.random_seed = "onboarding-stages"; game.random_streams = {}
	game.new_game()
	if level > 0:
		game.level = level; game.xp = 0; game.seen_tutorial = true; game.tutorial_on = false
		game.orders = []; game.pending_orders = []
		game.rules.orders.refill_orders()
	replay.advance(); replay._canonicalize_live(); replay.executing = false
	game.clear_presentations(); replay.snapshot()

func run() -> void:
	for node in root.get_children(): node.set_process(false)
	var replay = root.get_node("Replay")
	var game = root.get_node("G")

	_fresh(replay, game, 0)
	var xp := 0
	for o in game.orders: xp += int(o.get("rw", {}).get("xp", 0))
	check(xp == 0 and game.orders.is_empty(), "开场没有订单，练习单不提前发经验")
	check([Data.xp_need(1), Data.xp_need(2), Data.xp_need(3), Data.xp_need(4), Data.xp_need(5)] == [2, 5, 3, 5, 5], "前五级经验严格对应表格：2、5、3、5、5")

	# #79: a saved, claimable clear-land reward, never a hidden automatic refill.
	game.level = 2; game.energy = 0
	replay.meta["free_energy"] = true
	for i in range(14, 30): game.board[i] = {"id": "", "lock": 0}
	replay.perform("tick", {}, replay.clock)
	check(game.rules.onboarding.progress().get("rescue_pending", false), "再次耗尽且清出空地时准备15体力奖励")
	var rescue: Dictionary = replay.perform("onboarding_rescue", {}, replay.clock)
	check(not rescue.has("error") and game.energy == 15, "点击领取后才获得15体力")
	var rescue_state: Dictionary = replay.snapshot()
	replay.restore(rescue_state)
	check(replay.perform("onboarding_rescue", {}, replay.clock).has("error") and game.energy == 15, "恢复后清地奖励不能重复领取")
	_fresh(replay, game, 0)
	game.level = 4; game.energy = 0
	for i in game.board.size(): game.board[i] = {"id": "", "lock": 2}
	game.board[28] = {"id": "emberpot_1", "lock": 0}
	game.board[29] = {"id": "", "lock": 0}
	replay.meta["onboarding"]["step"] = game.rules.onboarding.stage_index("free_energy_gift")
	replay.perform("tick", {}, replay.clock)
	check(str(game.rules.onboarding.stage()["key"]) == "energy_gift", "有一个空位即可引导免费生产")
	var gift: Dictionary = replay.perform("tap", {"cell": 28}, replay.clock)
	check(gift.get("kind") == "produce" and game.energy == 0 and game.board[28]["id"] == "emberpot_1" and game.rules.board.gen_left(28) == 7, "引导与常规逻辑一致：保留火种罐，产出一件2～4级体力物品")
	var produced := str(gift.get("id", ""))
	replay.perform("tap", {"cell": 29}, replay.clock)
	check(game.energy == Data.value_of(produced) and str(game.rules.onboarding.stage()["key"]) == "free_level4", "点击实际产物获得体力，引导无需强制合成100体力")

	_fresh(replay, game, 1)
	game.xp = 2
	game.rules.orders.refill_orders()
	check(int(game.orders[0]["rw"].get("xp", 0)) == 1, "旧版2/3经验存档仍有带星心愿，不会因新经验表卡级")
	for i in game.board.size(): game.board[i] = {"id": "", "lock": 0}
	for i in game.orders[0]["items"].size(): game.board[i]["id"] = game.orders[0]["items"][i]
	replay.perform("order", {"cell": 0}, replay.clock)
	check(game.level == 2 and game.xp == 1, "旧版累计声望在下一单结算，保留溢出的1点经验")
	_fresh(replay, game, 3)
	for i in game.board.size(): game.board[i] = {"id": "", "lock": 0}
	game.board[0]["id"] = "fruit_5"
	game.orders = [game.order_identity(game.rules.orders._craft_order(Data.DISHES["salad"]))]
	replay.perform("craft", {"cell": 0}, replay.clock)
	# The player can skip once the material flight has landed.
	game.simulation_time = replay.clock + 1
	replay.perform("tick", {}, int(game.simulation_time))
	game.rush = 120
	var skipped: Dictionary = replay.perform("rush", {"cell": 0}, int(game.simulation_time))
	check(int(skipped.get("used", 0)) == 1 and game.rush == 119 and not game.rules.orders.cooking(0), "制作跳过按6秒一沙漏收费，空设备格也能正确加速")

	_fresh(replay, game, 3)
	game.energy = 0
	var amber: int = game.amber
	var r: Dictionary = replay.perform("energy", {}, replay.clock)
	check(not r.has("error") and bool(r.get("free", false)) and game.energy == 100 and game.amber == amber, "第一次补体力免费，补满 100")
	game.energy = 0
	r = replay.perform("energy", {}, replay.clock)
	check(not r.has("error") and not r.has("free") and game.amber == amber - 10 and game.energy == 100, "第二次补体力按原价花琥珀")

	_fresh(replay, game, 1)
	for i in game.board.size():
		if int(game.board[i]["lock"]) == 0 and Data.type_of(str(game.board[i]["id"])) == "item": game.board[i]["id"] = ""
	game.stash = []
	# 开几格空地，让订单宝箱有地方落
	for i in range(14, 28): game.board[i] = {"id": "", "lock": 0}
	game.orders = []
	game.rules.orders.refill_orders()
	# 升级那一刻：先换成 2 级订单，再按新订单缺的材料发订单宝箱
	var chest_events: Array = []
	game.presentation_event.connect(func(kind, payload): if kind == "order_chest": chest_events.append(payload))
	replay.executing = true
	var up: bool = game.rules.progression.add_xp(Data.xp_need(1) - game.xp)
	replay.executing = false
	var want: Array = game.rules.orders.missing_order_items(3)
	check(up and game.level == 2, "攒满经验升到 2 级")
	for e in game._presentation_events:
		if str(e["kind"]) == "order_chest": chest_events.append(e["payload"])
	var got: Array = []
	for e in chest_events:
		for it in e.get("items", []): got.append(str(it["id"]))
	check(not got.is_empty() and got.size() <= 3, "升级那一刻订单宝箱送出了材料（%s）" % [got])
	var on_board := true
	for it in (chest_events[0].get("items", []) if not chest_events.is_empty() else []):
		if str(game.board[int(it["to"])]["id"]) != str(it["id"]): on_board = false
	check(on_board, "这些材料已经放在棋盘上，界面按格子依次播落下动画")
	check(want.size() < got.size() or want.is_empty(), "送完以后订单缺的材料变少了")
	var before := {}
	for id in got: before[id] = _count(game, id)
	r = replay.perform("level", {"level": 2}, replay.clock)
	var again := false
	for id in got:
		if _count(game, id) > int(before[id]): again = true
	check(not r.has("error") and not r.has("help") and not again, "点开升级面板领奖不会再送一次订单材料")
	r = replay.perform("level", {"level": 2}, replay.clock)
	check(r.has("error"), "同一级奖励不能重复领")

	# 引导后全是随机单；经验只放在「还差几点升级」那么多张订单上，升级后重新分
	for lv in [2, 5, 9]:
		_fresh(replay, game, lv)
		for xp_now in [0, Data.xp_need(lv) - 1]:
			game.xp = xp_now
			game.orders = []
			replay.executing = true
			game.rules.orders.refill_orders()
			replay.executing = false
			var story := 0
			var with_xp := 0
			for o in game.orders:
				if bool(o.get("story", false)): story += 1
				if int(o.get("rw", {}).get("xp", 0)) > 0: with_xp += 1
			var want_xp: int = mini(Data.xp_need(lv) - xp_now, game.orders.size())
			check(story == 0, "%d 级引导后没有手配剧情单" % lv)
			check(with_xp == want_xp, "%d 级经验 %d/%d：%d 张订单里 %d 张带经验（应为 %d）" % [lv, xp_now, Data.xp_need(lv), game.orders.size(), with_xp, want_xp])
	_fresh(replay, game, 3)
	game.xp = Data.xp_need(3) - 1
	game.orders = []
	replay.executing = true
	game.rules.orders.refill_orders()
	var before_up := 0
	for o in game.orders: if int(o.get("rw", {}).get("xp", 0)) > 0: before_up += 1
	game.rules.progression.add_xp(1)
	var after_up := 0
	for o in game.orders: if int(o.get("rw", {}).get("xp", 0)) > 0: after_up += 1
	replay.executing = false
	check(before_up == 1 and after_up == mini(Data.xp_need(4), game.orders.size()) and after_up > before_up, "升级后原来没经验的订单带上了经验（%d → %d 张）" % [before_up, after_up])

	# 活动按等级逐个开放：开局什么活动都没有
	var ActivityRules = load("res://scripts/events/ActivityRules.gd")
	var UfoOffer = load("res://scripts/events/UfoOffer.gd")
	var Rewards = load("res://scripts/Rewards.gd")
	var seven_def: Dictionary = {}
	for d in ActivityRules.registry(): if str(d["id"]) == "seven": seven_def = d
	for lv in [1, 2, 3]:
		_fresh(replay, game, lv)
		var shown: Array = []
		for d in ActivityRules.board_entries():
			if d["visible"].call(): shown.append(str(d["id"]))
		if lv < 3: check(shown.is_empty(), "%d 级棋盘上没有任何活动入口（%s）" % [lv, shown])
		else: check(seven_def["visible"].call(), "3 级开放七日任务")
	check(Data.level_unlocks(3).has("新活动：七日任务") and Data.level_unlocks(7).has("新活动：恐龙化石"), "升级面板写出这一级新开的活动")
	_fresh(replay, game, 2)
	game.ufo_offer = {}
	ActivityRules.initialize()
	game.ufo_offer["next_at"] = 0
	UfoOffer.tick()
	check(not UfoOffer.active(), "飞碟商人 7 级前不来")

	# 卡册 8 级才开：之前发的卡包换成藤编宝箱，暂存区不会有点不开的卡包
	_fresh(replay, game, 5)
	game.stash = []
	Rewards.settle([["pack_1", 1]])
	check(game.stash == ["chest_1"], "5 级领到的卡包换成了藤编宝箱（%s）" % [game.stash])
	game.stash = ["fruit_2", "pack_1"]
	for i in range(14, 28): game.board[i] = {"id": "", "lock": 0}
	var took: Dictionary = replay.perform("stash", {"index": game.rules.board.stash_claim_index()}, replay.clock)
	check(str(took.get("id", "")) == "chest_1" and game.stash == ["fruit_2"], "老存档暂存区里的卡包点出来是藤编宝箱（%s）" % [took])
	_fresh(replay, game, 8)
	game.stash = []
	Rewards.settle([["pack_1", 1]])
	check(game.stash == ["pack_1"], "8 级以后照常发卡包")

	# 订单只要现有生产器掉得出来的东西：小草篓 4 级只掉野莓，就不能出要种子的单（含做饭单）
	var seedy := 0
	var rounds := 0
	for lv in [3, 4, 5, 6]:
		for trial in 6:
			_fresh(replay, game, lv)
			for i in game.board.size():
				var bid := str(game.board[i]["id"])
				if bid != "" and Data.type_of(bid) == "gen": game.board[i]["id"] = "basket_4" if Data.chain(bid) == "basket" else ""
			game.stash = []; game.inv = []
			game.random_seed = "sourced-%d-%d" % [lv, trial]; game.random_streams = {}
			game.orders = []
			replay.executing = true
			game.rules.orders.refill_orders()
			replay.executing = false
			rounds += 1
			for o in game.orders:
				for it in o.get("items", []) + o.get("mats", []):
					if Data.chain(str(it)) != "fruit": seedy += 1
	check(seedy == 0, "只有 4 级小草篓时，%d 轮出单都没要种子或别的产线（违规 %d 件）" % [rounds, seedy])
	check(not game.rules.orders.sourced_chains().has("seed"), "4 级小草篓掉不出种子")
	game.board[0]["id"] = "basket_5"; game.board[0]["lock"] = 0
	check(game.rules.orders.sourced_chains().has("seed"), "小草篓升到 5 级会掉种子，种子单就能出了")

	var lv4: Array = Data.level_rewards(4)
	var has_pot := false
	for rw in lv4: if str(rw[0]) == "emberpot_1": has_pot = true
	check(has_pot, "4 级奖励里有火种罐")
	check(Data.type_of("emberpot_1") == "egen", "火种罐是点了出体力的生产器")

	quit(1 if failures > 0 else 0)

func _count(game, id: String) -> int:
	var n: int = game.stash.count(id)
	for c in game.board:
		if str(c["id"]) == id: n += 1
	return n
