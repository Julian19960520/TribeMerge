extends SceneTree
## Verify all production lines and sample the actual one-energy tap path.
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func run() -> void:
	var g = root.get_node("G"); var replay = root.get_node("Replay")
	for node in root.get_children(): node.set_process(false)
	for line in Data.LINES:
		var generator := str(line["gen"])
		var last_yield := 0.0
		var valid := true
		for level in range(4, Data.max_lv(generator) + 1):
			var total := 0.0; var secondary := 0.0; var equivalent := 0.0; var highest := 0
			for drop in Data.gen_stats("%s_%d" % [generator, level])["drops"]:
				var id := str(drop["id"]); var chance := float(drop["p"])
				total += chance; highest = maxi(highest, Data.lv(id))
				if Data.secondaries(line).has(Data.chain(id)): secondary += chance
				equivalent += chance * float(1 << (Data.lv(id) - 1)) / 100.0
			# 只配了一种产物的产线没有稀有产物
			var expected_secondary := {4: 0, 5: 10, 6: 10, 7: 12, 8: 14, 9: 15} if not Data.secondaries(line).is_empty() else {4: 0, 5: 0, 6: 0, 7: 0, 8: 0, 9: 0}
			valid = valid and total == 100 and secondary == float(expected_secondary[level]) and equivalent >= last_yield
			if level == 5: valid = valid and highest == 1
			if level == 6: valid = valid and highest == 2
			if level > 5: valid = valid and equivalent > last_yield
			last_yield = equivalent
		check(valid, generator + "：5级副产物10%，6级开始出2级物品，后续产能逐级提高且权重合计100%")
	replay.executing = true
	replay.meta = {}; replay.seq = 0; replay.base = 0; replay.pending = []; replay.inflight = {}
	replay.clock = 1794240000; g.simulation_time = replay.clock
	g.new_game(); g.tutorial_on = false; g.boost = 1; g.energy = 25000
	g.random_seed = "generator-six-growth"; g.random_streams = {}
	for i in g.board.size(): g.board[i] = {"id": "", "lock": 0}
	g.board[0]["id"] = "basket_6"
	var counts := {}; var valid := true
	for _i in 20000:
		g.board[0].erase("gm") # Remove cooldown only; the actual tap still charges energy.
		var before: int = g.energy
		var result: Dictionary = replay._reducer.tap(0)
		if result.get("kind", "") != "produce" or g.energy != before - 1: valid = false; break
		var id := str(result["id"])
		counts[id] = int(counts.get(id, 0)) + 1
		g.board[int(result["to"])]["id"] = ""
	replay.executing = false
	var second := float(counts.get("fruit_2", 0)) / 20000.0
	var secondary := float(counts.get("seed_1", 0)) / 20000.0
	print("SAMPLED level6 ", counts)
	check(valid and counts.size() == 3 and second > 0.19 and second < 0.21 and secondary > 0.09 and secondary < 0.11 and g.energy == 5000, "两万次真实点击：每次1体力，2级主产物约20%、副产物约10%，不越级出3级")
	quit(1 if failures else 0)
