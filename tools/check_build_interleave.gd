extends SceneTree
## 部落建造交替推进：相邻两件部件轮流建，落成顺序不乱，总次数不变，费用和奖励只在落成时发。
var failures := 0
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var g = root.get_node("G")
	var D = load("res://scripts/Data.gd")
	g.new_game(); g.tutorial_on = false; g.seen_tutorial = true; g.level = 99; g.shells = 1000000; g.gm_activities = true
	var pr = g.rules.progression
	for b in D.BUILDS:
		var id := str(b["id"])
		var parts: Array = D.build_parts(b)
		var seq: Array = []
		var finished_order: Array = []
		var total := 0
		for pt in parts: total += D.part_steps(pt)
		var start: int = pr.build_progress(id)["done"]
		var guard := 0
		var reward_ok := true
		while pr.build_can(id) and guard < 500:
			guard += 1
			var t: int = pr.build_target(id)
			var will_finish: bool = pr.part_step(id, t) + 1 >= D.part_steps(parts[t])
			var r: Dictionary = pr.do_build(id)
			if r.is_empty(): break
			seq.append("%s%d" % [str(parts[t]["id"]), int(r["step"])])
			if bool(r["finished"]): finished_order.append(t)
			if bool(r["finished"]) != will_finish or (not bool(r["finished"]) and not (r["rewards"] as Array).is_empty()): reward_ok = false
		var in_order := true
		for k in finished_order.size():
			if k > 0 and finished_order[k] != finished_order[k - 1] + 1: in_order = false
		print(id, ": ", " ".join(seq))
		check(int(g.builds.get(id, 0)) == parts.size() and pr.build_progress(id)["done"] == total and seq.size() == total - start, id + " 全部建完，总次数不变")
		check(in_order, id + " 部件按原顺序落成")
		check(reward_ok, id + " 只有落成那次发奖")
	check(not g.builds.has("_ahead") and not g.builds.has("_steps"), "全部建完后不留进度残余")
	quit(1 if failures else 0)
