extends SceneTree
## 不那那小摊：货从已解锁产线随机摆；同一周期不变；花琥珀补货会换货；能按摆出来的货购买。
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1

func _unique(rows: Array) -> bool:
	var seen := {}
	for d in rows:
		var id := str(d["id"])
		if seen.has(id):
			return false
		seen[id] = true
	return not rows.is_empty()

func run() -> void:
	var g = root.get_node("G")
	var D = load("res://scripts/Data.gd")
	g.new_game()
	g.tutorial_on = false
	g.seen_tutorial = true
	g.level = 30
	var allowed := {}
	for l in D.unlocked_lines(g.level):
		for ch in D.products(l):
			allowed[ch] = "main" if D.primary(l) == ch else "sub"
	var stall: Array = g.rules.shop.shell_stall()
	check(stall.size() == D.STORE_SHELL.size(), "小摊摆满模板的 %d 格" % D.STORE_SHELL.size())
	var ok_lines := true
	var ok_role := true
	for k in stall.size():
		var ch: String = D.chain(str(stall[k]["id"]))
		if not allowed.has(ch): ok_lines = false
		if D.draw_role(ch) != D.draw_role(D.chain(str(D.STORE_SHELL[k]["id"]))): ok_role = false
	check(ok_lines, "货都来自已解锁产线：%s" % str(stall.map(func(d): return d["id"])))
	check(ok_role, "每格主产物 / 副产物和模板一致")
	check(_unique(stall), "30 级货不重复：%s" % str(stall.map(func(d): return d["id"])))
	check(JSON.stringify(g.rules.shop.shell_stall()) == JSON.stringify(stall), "同一周期再看，货不变")
	# 低等级只摆当时开放的产线
	var g2_level: int = g.level
	g.level = 3
	g.shell_period = ""
	g._rule_meta().erase("shell_stall")
	var low: Array = g.rules.shop.shell_stall()
	var low_ok := true
	for d in low:
		var ch: String = D.chain(str(d["id"]))
		var open := false
		for l in D.unlocked_lines(3):
			if D.products(l).has(ch): open = true
		if not open and not D.STORE_SHELL.any(func(t): return str(t["id"]) == str(d["id"])): low_ok = false
	check(low_ok, "3 级只摆已开放产线的货：%s" % str(low.map(func(d): return d["id"])))
	check(_unique(low), "3 级货不重复：%s" % str(low.map(func(d): return d["id"])))
	g.level = 1
	g.shell_period = ""
	g._rule_meta().erase("shell_stall")
	var early: Array = g.rules.shop.shell_stall()
	check(_unique(early), "1 级货不重复：%s" % str(early.map(func(d): return d["id"])))
	var fruit_n := 0
	for d in early:
		if D.chain(str(d["id"])) == "fruit":
			fruit_n += 1
	check(fruit_n <= 1, "1 级樱桃只摆一件")
	g.level = g2_level
	g.shell_period = ""
	g._rule_meta().erase("shell_stall")
	stall = g.rules.shop.shell_stall()
	# 按摆出来的货购买
	g.shells = 9999
	var r: Dictionary = g.rules.progression.shop_buy("shell_0", str(stall[0]["id"]))
	check(r.get("ok", false) and int(g.shell_bought.get("shell_0", 0)) == 1, "能买摆出来的第一格")
	var bad: Dictionary = g.rules.progression.shop_buy("shell_0", "nothing_9")
	check(not bad.get("ok", false), "对不上的货买不了")
	# 花琥珀补货：清空已购、换一批货、周期号带补货次数
	var sigs := {}
	sigs[JSON.stringify(stall)] = true
	var base := str(g.shell_period)
	for i in 4:
		g.amber = 9999
		var rr: Dictionary = g.rules.progression.refresh_shell()
		check(rr.get("ok", false), "第 %d 次补货成功" % (i + 1))
		sigs[JSON.stringify(g.rules.shop.shell_stall())] = true
	check(g.shell_bought.is_empty(), "补货后已购清零")
	check(str(g.shell_period) == base + ":4", "周期号记下补货次数（%s）" % g.shell_period)
	check(sigs.size() >= 3, "补货会换货（5 次里出现 %d 种摆法）" % sigs.size())
	# 跨周期：补货次数清掉
	g.shell_period = "0:3"
	g.rules.clock.check_shell_period()
	check(not str(g.shell_period).contains(":"), "换周期后补货次数清零")
	print("RESULT ", failures, " failures")
	quit(0 if failures == 0 else 1)
