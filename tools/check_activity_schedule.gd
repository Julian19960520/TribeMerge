extends SceneTree
## 活动档期：每档同一时间只开一个活动；切走后进行中的一局能打完、不能开新局；化石每期重开；同档共用奖励预算。
var failures := 0
var g
var sched
var race
var rules
var duel
var merge
var fossil
var tiger
const START := 1793577600.0 # 2026-11-02T00:00:00Z，与 data/activity_schedule.json 对齐
const DAY := 86400.0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func at(t: float) -> void:
	g.simulation_time = t
func run() -> void:
	g = root.get_node("G")
	sched = load("res://scripts/events/ActivitySchedule.gd")
	race = load("res://scripts/events/LocalRace.gd")
	rules = load("res://scripts/events/ActivityRules.gd")
	duel = load("res://scripts/events/DuelRace.gd")
	merge = load("res://scripts/events/MergeEvent.gd")
	fossil = load("res://scripts/events/FossilDig.gd")
	tiger = load("res://scripts/events/TigerEscape.gd")
	for node in root.get_children(): node.set_process(false)
	g.new_game(); g.tutorial_on = false; g.seen_tutorial = true; g.level = 20; g.gm_activities = false
	# 1. 每档每时刻只有一个活动在档期里
	var one := true
	for h in range(0, 24 * 60, 5):
		var t := START + h * 3600.0
		for slot in sched.config()["slots"]:
			var on := 0
			for row in slot["rotation"]:
				if sched.scheduled(str(row["activity"]), t): on += 1
			one = one and on == 1
	check(one, "60天内每个档期每时刻恰好开一个活动")
	check(sched.scheduled("race", START + 1) and not sched.scheduled("duel", START + 1) and sched.scheduled("duel", START + DAY + 1), "短局档轮换：第1期篝火竞速(24h)，第2期双人竞速(20h)")
	check(sched.scheduled("duel", START + DAY + 19 * 3600) and not sched.scheduled("duel", START + DAY + 20 * 3600 + 1) and sched.scheduled("race", START + DAY + 20 * 3600 + 1), "双人竞速持续20小时后切回篝火竞速")
	check(sched.scheduled("merge", START + 1) and not sched.scheduled("fossil", START + 1) and sched.scheduled("fossil", START + 7 * DAY + 1), "一周档轮换：第1周月石遗迹，第2周化石")
	check(sched.scheduled("seven", START + 1) and sched.slot_of("seven").is_empty(), "七日任务不在档期里，常驻开放")
	# 2. 短局：不在档期不能开新局，进行中的一局切走后仍可见、可打完
	at(START + 3600)
	g.local_race = {"current": {}, "results": []}
	check(bool(race.join().get("ok", false)) and race.busy(), "篝火竞速档期内可开局")
	at(START + DAY + 3600)
	check(rules._race_visible(), "换到双人竞速那天，还没比完的篝火竞速仍显示")
	g.local_race = {"current": {}, "results": []}
	check(not bool(race.join().get("ok", true)) and not rules._race_visible(), "不在档期时篝火竞速不能开新局，入口隐藏")
	g.duel_race = {"window": "", "wins": 0, "rounds": 0, "claimed": [], "match": {}}
	check(not duel.local_action("join").has("error") and duel.visible(), "双人竞速档期内可开局")
	var first_duel_win := str(g.duel_race.get("window", ""))
	# 模拟本期打赢 2 场并领掉 2 胜奖励
	duel.add_duel_points(30)
	duel.local_action("claim")
	g.duel_race["wins"] = 2
	g.duel_race["claimed"] = ["2"]
	# 再开一局保留为进行中，切走档期仍可见
	duel.local_action("join")
	at(START + DAY + 20 * 3600 + 3600)
	check(duel.visible(), "切回篝火竞速后，进行中的双人对决仍显示")
	g.duel_race = {"window": first_duel_win, "wins": 2, "rounds": 2, "claimed": ["2"], "match": {}}
	check(duel.local_action("join").has("error") and not duel.visible(), "不在档期时双人竞速不能开新局")
	# 下一次再次轮到双人竞速（再过 24h 篝火竞速 = START + 2*DAY + 20h + 1）时，本期累胜和里程碑自动重置
	at(START + 2 * DAY + 20 * 3600 + 3600)
	check(sched.scheduled("duel") and duel.visible(), "下一期双人竞速开放")
	check(int(duel.state()["wins"]) == 0 and int(duel.state()["rounds"]) == 0 and duel.state()["claimed"].is_empty() and str(duel.state()["window"]) != first_duel_win, "再次轮到双人竞速时，累胜与里程碑自动重置")
	check(duel.next_target() == 30, "重置后第一局目标分恢复为 30")
	# 3. 月石遗迹只在轮到它的那一周
	at(START + 3600)
	check(merge.available(merge.current()), "第1周月石遗迹开放")
	at(START + 7 * DAY + 3600)
	check(not merge.available(merge.current()), "第2周轮到化石，月石遗迹不开")
	# 4. 化石：档期内挖铲子（1天20小时=44h），换期重开
	at(START + 7 * DAY + 3600)
	g.fossil_dig = {}
	fossil.initialize()
	fossil.on_order({})
	var first_window := str(g.fossil_dig.get("window", ""))
	check(fossil.earning() and int(g.fossil_dig["shovels"]) == int(fossil.config()["shovels_per_order"]), "化石档期交单得铲子")
	at(START + 7 * DAY + 44 * 3600 + 3600)
	var before := int(g.fossil_dig["shovels"])
	fossil.on_order({})
	check(not fossil.earning() and int(g.fossil_dig["shovels"]) == before, "化石44小时结束切回月石后，交单不给化石铲子")
	at(START + 14 * DAY + 44 * 3600 + 3600)
	fossil.on_order({})
	check(str(g.fossil_dig["window"]) != first_window and int(g.fossil_dig["shovels"]) == int(fossil.config()["shovels_per_order"]) and int(g.fossil_dig["stage"]) == 1, "下一期化石换新布局、进度重开")
	# 5. 剑齿虎：档期内可开局
	at(START + 3600)
	g.tiger_escape = {"rounds": 0, "round": {}}
	check(not tiger.local_action("join").has("error") and tiger.visible(), "1～2天档剑齿虎可开局")
	# 6. GM 全开时不受档期限制
	g.gm_activities = true
	at(START + DAY + 3600)
	check(sched.scheduled("race") and sched.scheduled("duel") and sched.scheduled("fossil") and sched.scheduled("merge"), "GM 全开活动时所有档期活动同时可玩")
	g.gm_activities = false
	# 7. 同档共用奖励预算
	var schedule: Dictionary = sched.config()
	var budgets := {}
	var path := "res://server/public/catalog_CN.json"
	if FileAccess.file_exists(path):
		var audit: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path)).get("reward_audit", {})
		var same := true
		for slot in schedule["slots"]:
			if not slot.has("budget"): continue
			for row in slot["rotation"]:
				if audit.has(str(row["doc"])): same = same and int(audit[str(row["doc"])]["budget"]) == int(slot["budget"]) and str(audit[str(row["doc"])]["slot"]) == str(slot["id"])
		check(same, "服务端奖励预算按档统一：同档活动预算相同")
	print("RESULT: %d failures" % failures)
	quit(1 if failures else 0)
