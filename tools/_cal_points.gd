extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func _merges(id: String, start: int) -> Dictionary:
	# 从低级合到 id 的这一路上，各级合成次数
	var out := {}
	var L := Data.lv(id)
	for k in range(start, L + 1):
		out[k] = int(pow(2, L - k))
	return out
func run() -> void:
	var g = root.get_node("G")
	var replay = root.get_node("Replay")
	replay.set_process(false); root.get_node("Cloud").set_process(false)
	replay.active = true; replay.worker = false; replay.authorized = true; replay.executing = true
	g.simulation_time = 1793577600.0; replay.clock = int(g.simulation_time)
	g.new_game(); g.tutorial_on = false; g.seen_tutorial = true
	replay.advance(); replay.executing = false
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	for lvl in [8, 12, 18, 25, 32, 40]:
		g.level = lvl
		var fl: Array = []; var duel := 0.0; var m5 := 0.0; var m6 := 0.0; var op := 0.0; var lvls := {}; var n := 300
		for k in n:
			var tier := "hard" if rng.randf() < Data.hard_share(lvl) else "easy"
			var o: Dictionary = g.rules.orders._make_order(Data.tier_target(lvl, tier, rng))
			if o.is_empty(): continue
			fl.append(OrderRoll.total(o["items"]))
			duel += load("res://scripts/events/DuelRace.gd").order_points(o)
			for id in o["items"]:
				var L := Data.lv(str(id)); lvls[L] = int(lvls.get(L, 0)) + 1
				for kk in range(5, L + 1): m5 += pow(2, L - kk) * clampf(200.0 + 70.0 * (kk - 5), 200, 600)
				for kk in range(7, L + 1): m6 += pow(2, L - kk) * clampf(200.0 + 100.0 * (kk - 7), 200, 600)
			var eb := Data.tier_base(lvl, "easy") * 0.7
			var hb := Data.tier_base(lvl, "hard") * 1.3
			var d := clampf((OrderRoll.total(o["items"]) - eb) / maxf(1.0, hb - eb), 0.0, 1.0)
			op += clampf(snappedf(lerpf(200, 600, d) + rng.randf_range(-60, 60), 10), 200, 600)
		fl.sort()
		var avg := 0.0
		for f in fl: avg += f
		avg /= fl.size()
		print("Lv%d flames avg %.0f p10 %.0f p50 %.0f p90 %.0f | duel avg %.2f | merge5 %.0f merge7 %.0f orderpts %.0f | item lv %s | easy base %.0f hard base %.0f" % [lvl, avg, fl[fl.size()/10], fl[fl.size()/2], fl[fl.size()*9/10], duel / n, m5 / n, m6 / n, op / n, lvls, Data.tier_base(lvl, "easy"), Data.tier_base(lvl, "hard")])
	quit()
