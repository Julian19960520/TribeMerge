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
	tasks.login("2026-11-01")
	tasks.login("2026-11-01")
	check(tasks.state()["stats"]["login_days"] == 1,"same login day counts once")
	tasks.login("2026-11-02")
	check(tasks.state()["stats"]["login_days"] == 2,"distinct login days accumulate")
	check(tasks.config()["days"].size() == 7,"seven pages configured")
	for day in tasks.config()["days"]: check(day["tasks"].size() == 5,"five tasks on each page")
	g.add_currency("shell",100)
	g.add_currency("amber",10)
	g.spend("amber",5)
	g.add_xp(30)
	check(tasks.state()["stats"]["shell"] == 100 and tasks.state()["stats"]["amber"] == 10 and tasks.state()["stats"]["amber_spent"] == 5 and tasks.state()["stats"]["xp"] == 30,"income/spend/xp follow game transactions")
	tasks.record("orders",180)
	check(tasks.done(tasks.find_entry("d7_2",false)),"seventh page completes early without date gate")
	var energy: int = g.energy
	check((await tasks.claim("d7_2")).get("ok",false) and tasks.points() == 10,"individual later-page claim grants points")
	check((await tasks.claim("d7_2")).has("error") and tasks.points() == 10,"duplicate claim blocked")
	check((await tasks.claim("p100",true)).has("error"),"unreached milestone blocked")
	for metric in ["orders","merges","xp","cards","shell","amber","amber_spent"]: tasks.record(metric,10000)
	tasks.record("paid_cents",3000)
	check(not tasks.state()["stats"].has("paid_cents"),"offline purchase never fakes real payment")
	for day_number in range(3,8): tasks.login("2026-11-%02d" % day_number)
	for day in tasks.config()["days"]:
		for t in day["tasks"]:
			if tasks.done(t) and not tasks.got(t): await tasks.claim(str(t["id"]))
	check(tasks.points() >= 300,"all milestones accessible without paid tasks")
	check((await tasks.claim("p300",true)).get("ok",false) and g.stash.count("choice_1") == 2,"milestone rewards use shared delivery")
	check((await tasks.claim("p300",true)).has("error"),"milestone pays once")
	var saved: Dictionary = g.seven_day.duplicate(true)
	g.save_game()
	g.seven_day = {}
	g.load_game()
	check(g.seven_day == saved,"all progress and claims survive reload")
	g.shell_bought = {"shell_0":3,"shell_1":3,"shell_5":2}
	g.check_shell_period()
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
	data.RULES["merge_coin_chance"] = 1.0
	var merged_before: int = tasks.state()["stats"]["merges"]
	check(g.try_drop(0,1) == "merge" and g.board[0]["id"] == "shell_1","successful merge drops physical coin in nearest free cell")
	check(tasks.state()["stats"]["merges"] == merged_before+1,"merge counted exactly once")
	check(g.try_drop(1,1) == "" and tasks.state()["stats"]["merges"] == merged_before+1,"failed drag gives no task progress")
	g.board[2]["id"] = "fruit_1"; g.board[3]["id"] = "fruit_1"
	g.tutorial_on = true
	g.try_drop(2,3)
	check(g.board[2]["id"] == "","tutorial has no bonus coin")
	g.tutorial_on = false
	data.RULES["merge_coin_chance"] = 0.0
	g.board[4]["id"] = "fruit_1"; g.board[5]["id"] = "fruit_1"
	g.try_drop(4,5)
	check(g.board[4]["id"] == "","zero configured probability yields no bonus")
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	main.show_screen("board",true)
	var p = main.open("seven_day")
	await process_frame
	check(p.tabs.size() == 7 and p.stage_buttons.size() == 5,"panel renders seven bottom tabs and five milestones")
	p.page = 6; p._refresh()
	check(p.tasks_root.get_child_count() > 0,"last page renders independently")
	main.queue_free()
	await process_frame
	g.main = null
	print("RESULT: ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
