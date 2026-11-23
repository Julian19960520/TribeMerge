extends SceneTree
## Production-equivalent budgets and real chest rolls, with no inventory caps.
var failures := 0
var g
var replay
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func _add(out: Dictionary, rewards: Array) -> void:
	for reward in rewards:
		var id := str(reward[0])
		if Data.type_of(id) != "gen": continue
		var chain := Data.chain(id)
		out[chain] = int(out.get(chain, 0)) + int(reward[1]) * (1 << (Data.lv(id) - 1))
func fixed_budget(level: int) -> Dictionary:
	# Optimistic upper bound: all initial locked parts and every available building.
	var out := {}
	for id in Data.BOARD:
		if str(id) != "": _add(out, [[str(id), 1]])
	for lv in range(2, level + 1): _add(out, Data.level_rewards(lv))
	for building in Data.BUILDS:
		if Data.build_unlock(building) > level: continue
		for part in Data.build_parts(building): _add(out, part["rewards"])
	return out
func run() -> void:
	g = root.get_node("G"); replay = root.get_node("Replay")
	for node in root.get_children(): node.set_process(false)
	replay.executing = true
	replay.meta = {}; replay.seq = 0; replay.base = 0; replay.pending = []; replay.inflight = {}
	replay.clock = 1794240000; g.simulation_time = replay.clock
	g.new_game(); g.tutorial_on = false; g.seen_tutorial = true
	replay.advance(); replay.executing = false
	var boxes := 0; var compact := true; var restrained := true; var single := true
	for lv in range(6, 41):
		var rw: Array = Data.level_rewards(lv)
		compact = compact and rw.size() <= 4
		var gens := 0
		for reward in rw:
			if str(reward[0]) == "chest_1":
				boxes += int(reward[1])
				restrained = restrained and lv % 5 == 0
			if Data.type_of(str(reward[0])) == "gen":
				gens += int(reward[1])
				var tier := Data.lv(str(reward[0]))
				var line: Dictionary = Data.line_of(str(reward[0]))
				restrained = restrained and (tier <= 4 or tier == 5 and lv == int(line["unlock"]))
		single = single and gens <= 1
	check(boxes == 7 and compact and restrained, "6～40级仅7个节点宝箱，每级不超过4项，5级生产器只在新产线解锁时发")
	check(single, "每个等级最多奖励一个生产器，各产线共用")
	var first_six := 99; var first_line := ""
	for line in Data.LINES:
		var unlock := int(line["unlock"])
		if unlock > 1:
			var starter := 0
			for reward in Data.level_rewards(unlock):
				if str(reward[0]) == str(line["gen"]) + "_5": starter += int(reward[1])
			check(starter == 1 and not Data.gen_stats(str(line["gen"]) + "_5").is_empty(), "%s解锁给一个可生产主副产物的5级" % line["name"])
		check(int(fixed_budget(unlock).get(str(line["gen"]), 0)) >= 16, "%s解锁当级固定份数够一个5级" % line["name"])
		for lv in range(unlock, 41):
			if int(fixed_budget(lv).get(str(line["gen"]), 0)) >= 32:
				if lv < first_six: first_six = lv; first_line = str(line["name"])
				break
		check(int(fixed_budget(27).get(str(line["gen"]), 0)) < 32, "%s到27级固定奖励凑不出6级" % line["name"])
	check(first_six >= 30 and first_six <= 36, "不靠宝箱碎片时最早%d级凑出6级（%s）兜底，28级前后靠宝箱碎片补齐" % [first_six, first_line])
	check(int(fixed_budget(28)["basket"]) == 30, "食物线28级固定30份，差2份一级碎片即可合出第一个6级")
	g.level = 29
	for tier in range(1, 5):
		g.random_seed = "producer-pacing:%d" % tier; g.random_streams = {}
		var id := "chest_%d" % tier
		var draws := 0; var generators := 0; var only_fragments := true
		for _i in 8000:
			for item in SpecialChests.contents(id, g):
				draws += 1
				if Data.type_of(str(item)) == "gen":
					generators += 1
					only_fragments = only_fragments and Data.lv(str(item)) == 1 and int(Data.line_of(str(item))["unlock"]) <= g.level
		var expected := float(SpecialChests.definition(id)["gen_chance"])
		var actual := float(generators) / float(draws)
		check(only_fragments and absf(actual - expected) < 0.005, "%d档宝箱实际产出仅一级碎片，概率%.2f%%（配置%.0f%%）" % [tier, actual * 100, expected * 100])
	g.stash = ["basket_6"]; g.level = 6
	var claim: Dictionary = replay.perform("level", {"level": 6}, replay.clock)
	check(not claim.has("error") and g.stash.count("anvil_5") == 1 and g.stash.has("basket_6"), "新奖励实际到账，已拥有的6级生产器不回收")
	check(replay.perform("level", {"level": 6}, replay.clock).has("error") and g.stash.count("anvil_5") == 1, "产线解锁奖励不能重复领取")
	print("RESULT: %d failures" % failures)
	quit(1 if failures else 0)
