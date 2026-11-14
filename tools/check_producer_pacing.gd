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
	var boxes := 0; var compact := true; var restrained := true
	for lv in range(6, 41):
		var rw: Array = Data.level_rewards(lv)
		compact = compact and rw.size() <= 4
		for reward in rw:
			if str(reward[0]) == "chest_1":
				boxes += int(reward[1])
				restrained = restrained and lv % 5 == 0
			if Data.type_of(str(reward[0])) == "gen":
				var tier := Data.lv(str(reward[0]))
				var line: Dictionary = Data.line_of(str(reward[0]))
				restrained = restrained and (tier <= 3 or tier == 4 and lv == int(line["unlock"]))
	check(boxes == 7 and compact and restrained, "6～40级仅7个节点宝箱，每级不超过4项，成熟生产器只在新产线解锁时发4级")
	for line in Data.LINES:
		if int(line["unlock"]) == 1: continue
		var unlock := int(line["unlock"])
		var starter := 0
		for reward in Data.level_rewards(unlock):
			if str(reward[0]) == str(line["gen"]) + "_4": starter += int(reward[1])
		check(starter == 1 and not Data.gen_stats(str(line["gen"]) + "_4").is_empty(), "%s解锁只给一个可生产的4级" % line["name"])
		var earliest := -1
		for lv in range(unlock, 41):
			if int(fixed_budget(lv).get(str(line["gen"]), 0)) >= 16: earliest = lv; break
		check(earliest == unlock + 4, "%s固定投放在解锁4级后，再过4个角色等级可凑5级（%d级）" % [line["name"], earliest])
		check(int(fixed_budget(29).get(str(line["gen"]), 0)) < 32, "%s到29级固定奖励仍凑不出6级" % line["name"])
	check(int(fixed_budget(28)["basket"]) == 26 and int(fixed_budget(29)["basket"]) == 31 and int(fixed_budget(34)["basket"]) == 32, "食物线28级固定26份，29级31份加少量随机碎片接近6级，零随机34级兜底")
	g.level = 29
	for tier in range(1, 6):
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
		check(only_fragments and absf(actual - expected) < 0.005, "%d级宝箱实际产出仅一级碎片，概率%.2f%%（配置%.0f%%）" % [tier, actual * 100, expected * 100])
	g.stash = ["basket_6"]; g.level = 6
	var claim: Dictionary = replay.perform("level", {"level": 6}, replay.clock)
	check(not claim.has("error") and g.stash.count("anvil_4") == 1 and g.stash.has("basket_6"), "新奖励实际到账，已拥有的6级生产器不回收")
	check(replay.perform("level", {"level": 6}, replay.clock).has("error") and g.stash.count("anvil_4") == 1, "产线解锁奖励不能重复领取")
	print("RESULT: %d failures" % failures)
	quit(1 if failures else 0)
