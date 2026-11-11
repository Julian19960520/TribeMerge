extends SceneTree
var failures: Array = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func run() -> void:
	var g = root.get_node("G")
	var tasks = load("res://scripts/events/SevenDay.gd")
	g.new_game()
	g.set_process(false)
	g.seen_tutorial = true
	g.tutorial_on = false
	load("res://scripts/events/ActivityRules.gd").initialize()
	tasks.login("2026-11-01")
	tasks.login("2026-11-01")
	check(tasks.state()["stats"]["login_days"] == 1,"same login day counts once")
	tasks.login("2026-11-02")
	check(tasks.state()["stats"]["login_days"] == 2,"distinct login days accumulate")
	check(tasks.config()["days"].size() == 7,"seven pages configured")
	for day in tasks.config()["days"]: check(day["tasks"].size() == 5,"five tasks on each page")
	g.rules.progression.add_currency("shell",100)
	g.rules.progression.add_currency("amber",10)
	g.rules.progression.spend("amber",5)
	g.rules.progression.add_xp(30)
	check(tasks.state()["stats"]["shell"] == 100 and tasks.state()["stats"]["amber"] == 10 and tasks.state()["stats"]["amber_spent"] == 5 and tasks.state()["stats"]["xp"] == 30,"income/spend/xp follow game transactions")
	var cfg: Dictionary = tasks.config()
	var all: Array = []
	for day in cfg["days"]: all.append_array(day["tasks"])
	var ids := {}
	for t in all: ids[str(t["id"])] = true
	check(ids.size() == 35,"35 unique task ids")
	var logins_ok := true
	for k in 7:
		var first: Dictionary = cfg["days"][k]["tasks"][0]
		logins_ok = logins_ok and str(first["metric"]) == "login_days" and int(first["target"]) == k + 1
	check(logins_ok,"page N starts with login N days")
	# 同一统计项的目标逐页变大；积分不随页数下降
	var last := {}
	var ramp_ok := true
	var last_pts := 0
	for day in cfg["days"]:
		var page_max := 0
		for t in day["tasks"]:
			var m := str(t["metric"])
			ramp_ok = ramp_ok and int(t["target"]) > int(last.get(m, 0))
			last[m] = int(t["target"])
			if m != "login_days": page_max = maxi(page_max, int(t["points"]))
		ramp_ok = ramp_ok and page_max >= last_pts
		last_pts = page_max
	check(ramp_ok,"targets and points ramp from page 1 to 7")
	var kinds := {}
	for t in all: kinds[str(t["metric"])] = true
	check(kinds.size() == 9,"all nine task types present")
	var rewards_ok := true
	for t in all + cfg["milestones"]:
		for rw in t["rewards"]: rewards_ok = rewards_ok and load("res://scripts/Data.gd").is_known(str(rw[0])) and int(rw[1]) > 0
	check(rewards_ok,"every reward id is a real item")
	tasks.record("orders",75)
	check(tasks.done(tasks.find_entry("d7_2",false)),"seventh page completes early without date gate")
	var d7_pts := int(tasks.find_entry("d7_2",false)["points"])
	check((await tasks.claim("d7_2")).get("ok",false) and tasks.points() == d7_pts,"individual later-page claim grants points")
	check((await tasks.claim("d7_2")).has("error") and tasks.points() == d7_pts,"duplicate claim blocked")
	check((await tasks.claim("p120",true)).has("error"),"unreached milestone blocked")
	for metric in ["orders","merges","xp","cards","shell","amber","amber_spent"]: tasks.record(metric,10000)
	tasks.record("paid_cents",3000)
	check(not tasks.state()["stats"].has("paid_cents"),"offline purchase never fakes real payment")
	for day_number in range(3,8): tasks.login("2026-11-%02d" % day_number)
	for day in tasks.config()["days"]:
		for t in day["tasks"]:
			if tasks.done(t) and not tasks.got(t): await tasks.claim(str(t["id"]))
	var top := int(cfg["milestones"][-1]["points"])
	check(tasks.points() >= top,"all milestones accessible without paid tasks")
	var chests: int = g.stash.count("choice_1")
	check((await tasks.claim("p560",true)).get("ok",false) and g.stash.count("choice_1") == chests + 3,"milestone rewards use shared delivery")
	check((await tasks.claim("p560",true)).has("error"),"milestone pays once")
	var saved: Dictionary = g.seven_day.duplicate(true)
	g.save_game()
	g.seven_day = {}
	g.load_game()
	check(g.seven_day == saved,"all progress and claims survive reload")
	g.shell_bought = {"shell_0":3,"shell_1":3,"shell_5":2}
	g.rules.clock.check_shell_period()
	var amber: int = g.amber
	check((await g.refresh_shell()).get("ok",false) and g.amber == amber - 5 and g.shell_bought.is_empty(),"5 amber refresh replenishes every shell shop slot")
	g.amber = 0
	g.shell_bought = {"shell_0":3}
	check(not (await g.refresh_shell()).get("ok",false) and not g.shell_bought.is_empty(),"failed refresh preserves stock")
	# Force probability branches through configuration; no random test flakiness.
	for k in g.board.size(): g.board[k] = {"id":"","lock":0}
	g.board[0]["id"] = "fruit_1"
	g.board[1]["id"] = "fruit_1"
	var data = load("res://scripts/Data.gd")
	var original_rules: Dictionary = data.RULES
	data.RULES = original_rules.duplicate(true)
	data.RULES["merge_resource_drops"]["main"] = [{"item": "shell_1", "chance": 1.0, "min_level": 1, "items_only": true}]
	var merged_before: int = tasks.state()["stats"]["merges"]
	check(g.try_drop(0,1) == "merge" and g.board[0]["id"] == "shell_1","successful merge drops configured physical coin in nearest free cell")
	check(tasks.state()["stats"]["merges"] == merged_before+1,"merge counted exactly once")
	check(g.try_drop(1,1) == "" and tasks.state()["stats"]["merges"] == merged_before+1,"failed drag gives no task progress")
	g.board[2]["id"] = "fruit_1"; g.board[3]["id"] = "fruit_1"
	g.tutorial_on = true
	g.try_drop(2,3)
	check(g.board[2]["id"] == "","tutorial has no bonus coin")
	g.tutorial_on = false
	data.RULES["merge_resource_drops"]["main"] = []
	g.board[4]["id"] = "fruit_1"; g.board[5]["id"] = "fruit_1"
	g.try_drop(4,5)
	check(g.board[4]["id"] == "","zero configured probability yields no bonus")
	data.RULES = original_rules
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	main.show_screen("board",true)
	var p = main.open("seven_day")
	await process_frame
	check(p.tabs.size() == 7 and p.stage_buttons.size() == cfg["milestones"].size(),"panel renders seven bottom tabs and every milestone")
	p.page = 6; p._refresh()
	check(p.tasks_root.get_child_count() > 0,"last page renders independently")
	main.queue_free()
	await process_frame
	g.main = null
	print("RESULT: ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
