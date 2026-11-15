extends SceneTree
## 订单档位与经验：简单/难单生成时定好固定经验（1/2），档内难度有浮动且两档不重叠；
## 每级只开放刚好够升级的经验，其余先关闭，升级后重新分配且经验值不变。
var failures := 0
var g
var replay
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func fresh(level: int, seed: String) -> void:
	replay.executing = true
	replay.meta = {}; replay.seq = 0; replay.base = 0; replay.pending = []; replay.inflight = {}
	replay.clock = 1794240000; g.simulation_time = replay.clock
	g.new_game(); g.random_seed = seed; g.random_streams = {}
	g.level = level; g.xp = 0; g.tutorial_on = false; g.seen_tutorial = true
	g.orders = []; g.pending_orders = []
	for i in g.board.size(): g.board[i] = {"id": "", "lock": 0}
	var k := 0
	for line in Data.unlocked_lines(level):
		g.board[k]["id"] = "%s_7" % str(line["gen"]); k += 1
	replay.executing = false
	g.clear_presentations()
func open_xp() -> int:
	var n := 0
	for o in g.orders: n += int(o["rw"].get("xp", 0))
	return n
func randoms() -> Array:
	return g.orders.filter(func(o): return not bool(o.get("story", false)) and str(o.get("kind", "")) != "craft")
func put_items(o: Dictionary) -> void:
	var used := {}
	for c in g.board.size():
		if g.board[c]["id"] == "" or Data.type_of(str(g.board[c]["id"])) == "item": g.board[c] = {"id": "", "lock": 0}
	var at := 20
	for id in o["items"]:
		g.board[at]["id"] = str(id); at += 1
func run() -> void:
	g = root.get_node("G"); replay = root.get_node("Replay")
	for node in root.get_children(): node.set_process(false)
	# 1. 档位、浮动与不重叠
	var diffs := {"easy": [], "hard": []}
	var tagged := true; var fixed_xp := true; var in_range := true; var min_easy := true
	for i in 60:
		fresh(20, "order-xp-%d" % i)
		g.rules.orders.refill_orders()
		var easy := 0
		for o in randoms():
			var tier := str(o.get("tier", ""))
			tagged = tagged and tier in ["easy", "hard"] and o.has("diff")
			if not tagged: continue
			fixed_xp = fixed_xp and int(o["xp_value"]) == (2 if tier == "hard" else 1)
			var r: Vector2 = Data.tier_range(20, tier)
			in_range = in_range and float(o["diff"]) >= floor(r.x) and float(o["diff"]) <= ceil(r.y)
			diffs[tier].append(int(o["diff"]))
			if tier == "easy": easy += 1
		min_easy = min_easy and easy >= Data.MIN_EASY
	check(tagged and fixed_xp, "每张随机单都带档位和固定经验：简单1、难2")
	check(in_range and min_easy, "目标难度落在本档范围内，场上至少保留%d张简单单" % Data.MIN_EASY)
	var easy_set := {}; var hard_set := {}
	for v in diffs["easy"]: easy_set[v] = true
	for v in diffs["hard"]: hard_set[v] = true
	check(easy_set.size() >= 6 and hard_set.size() >= 6, "同档订单难度有浮动（简单%d种、难%d种不同目标）" % [easy_set.size(), hard_set.size()])
	check(Data.tier_range(20, "easy").y <= Data.tier_range(20, "hard").x and Data.tier_range(30, "easy").y <= Data.tier_range(30, "hard").x, "简单单最高难度不超过难单最低难度")
	check(not diffs["hard"].is_empty() and not diffs["easy"].is_empty(), "20级同时出现简单单和难单（简单%d张、难%d张）" % [diffs["easy"].size(), diffs["hard"].size()])
	# 2. 只开放刚好够升级的经验
	var exact := true; var hidden_keep := true
	for i in 30:
		fresh(20, "order-open-%d" % i)
		g.xp = Data.xp_need(20) - 3
		g.rules.orders.refill_orders()
		var opened := open_xp()
		exact = exact and opened >= 3 and opened <= 4
		for o in g.orders:
			hidden_keep = hidden_keep and o.has("xp_value") and (not o["rw"].has("xp") or int(o["rw"]["xp"]) == int(o["xp_value"]))
	check(exact, "差3点经验时开放的经验刚好够升级（最多多1点结转）")
	check(hidden_keep, "开放的单显示自己固定的经验，关闭的单保留经验值不显示")
	# 3. 交付开放的单加对应经验；补位单在额度已满时关闭
	fresh(20, "order-deliver")
	g.xp = Data.xp_need(20) - 3
	g.rules.orders.refill_orders()
	var idx := -1
	for i in g.orders.size():
		if g.orders[i]["rw"].has("xp") and str(g.orders[i].get("kind", "")) != "craft": idx = i; break
	var target: Dictionary = g.orders[idx]
	var gain := int(target["xp_value"])
	var before: int = g.xp
	put_items(target)
	g.complete_order(idx)
	check(g.xp == before + gain and g.level == 20, "交付开放的单获得它的固定经验%d点" % gain)
	check(open_xp() + g.xp >= Data.xp_need(20) and open_xp() + g.xp <= Data.xp_need(20) + 1, "补位后开放的经验仍刚好够升级")
	# 4. 升级后重新分配，经验值不变
	var values := {}
	for o in g.orders: values[str(o["uid"])] = int(o["xp_value"])
	g.xp = Data.xp_need(20) - 1
	idx = -1
	for i in g.orders.size():
		if g.orders[i]["rw"].has("xp") and str(g.orders[i].get("kind", "")) != "craft": idx = i; break
	put_items(g.orders[idx])
	g.complete_order(idx)
	check(g.level == 21, "交付后升到21级")
	var same := true; var reopened := 0
	for o in g.orders:
		if values.has(str(o["uid"])):
			same = same and int(o["xp_value"]) == int(values[str(o["uid"])])
			if o["rw"].has("xp"): reopened += 1
	check(same, "升级后留在场上的单经验值不变")
	check(reopened > 0 and open_xp() + g.xp >= Data.xp_need(21) or open_xp() == g.orders.reduce(func(a, o): return a + int(o["xp_value"]), 0), "升级后在场的单优先重新开放经验")
	# 5. 经验表
	check(Data.xp_need(1) == 2 and Data.xp_need(2) == 5 and Data.xp_need(3) == 3 and Data.xp_need(5) == 5 and Data.xp_need(8) == 6 and Data.xp_need(12) == 7 and Data.xp_need(28) == 12 and Data.xp_need(29) == 14 and Data.xp_need(40) == 18 and Data.xp_need(45) == 18, "升级经验表按新配置")
	quit(1 if failures else 0)
