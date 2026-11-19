extends SceneTree
## 随机订单尽量不重复物品：同一单内部不重复，同时在场的随机单之间也不重复。
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1

func run() -> void:
	await process_frame
	var g = root.get_node("G")
	g.new_game()
	g.tutorial_on = false
	g.level = 12
	g.orders = []
	g.random_seed = "distinct-orders"
	g.random_streams = {}
	g.rules.orders.refill_orders()
	var seen := {}
	var shared := false
	var repeated := false
	var random_n := 0
	for o in g.orders:
		if not (o is Dictionary) or bool(o.get("story", false)) or str(o.get("kind", "")) == "craft":
			continue
		random_n += 1
		var local := {}
		for id in o.get("items", []):
			var key := str(id)
			if local.has(key): repeated = true
			local[key] = true
			if seen.has(key): shared = true
			seen[key] = true
	check(random_n >= 2 and not repeated and not shared, "同一批随机订单里的物品互不重复")
	var avoided := true
	for _i in 40:
		var first: Dictionary = g.rules.orders._make_order(48)
		var second: Dictionary = g.rules.orders._make_order(48, first.get("items", []))
		var used := {}
		for id in first.get("items", []):
			used[str(id)] = true
			if first.get("items", []).count(id) > 1: avoided = false
		for id in second.get("items", []):
			if used.has(str(id)) or second.get("items", []).count(id) > 1: avoided = false
	check(avoided, "后一单避开前一单和自己已经抽到的物品")
	print("%d failures" % failures)
	quit(1 if failures else 0)
