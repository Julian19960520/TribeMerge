extends SceneTree
var failures := 0
var tiger

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1

func run() -> void:
	load("res://scripts/events/ActivitySchedule.gd").bypass = true # 只测单个活动玩法，不受档期轮换影响
	var g = root.get_node("G")
	tiger = load("res://scripts/events/TigerEscape.gd")
	g.new_game()
	g.set_process(false)
	g.tutorial_on = false
	g.seen_tutorial = true
	g.simulation_time = 2000.0
	g.level = 5
	check(tiger.local_action("join").has("error"), "locked below configured level")
	g.level = 6
	check(not tiger.local_action("join").has("error"), "join starts a new escape")
	check(tiger.local_action("join").has("error"), "cannot reset an active round")
	var m: Dictionary = tiger.round_state()
	check(m["stage"] == 0 and m["destroyed"] == -1, "runner starts ahead of tiger")
	check(m["bots"].size() == 99 and tiger.player_count(m) == 100, "round has 100 total participants (1 + 99)")
	check(tiger.stage_quota(m) == 90 and tiger.stage_remaining(m) == 90, "stage 1 starts with 90 qualifying spots")
	for k in 2: tiger.on_order({})
	check(m["stage"] == 0 and m["points"] == 2, "partial points do not skip a node")
	tiger.on_order({})
	check(m["stage"] == 1 and m["points"] == 0, "full progress jumps to next node")
	check(tiger.local_action("claim", 2).has("error"), "future reward cannot be claimed")
	check(tiger.local_action("claim", 1).get("rewards", []) == [["fire_2", 15]], "reached node unlocks configured gift")
	check(tiger.local_action("claim", 1).has("error"), "node gift pays once")

	# 模拟90个对手都在 t=1000 之前完成第1关，玩家已过第1关，第10名之后（10人）被淘汰
	g.simulation_time += 20000.0
	tiger.tick()
	check(m["destroyed"] >= 0 and m["status"] == "running", "stage 1 closes when 90 advance, player who passed survives")
	check(tiger.survivors(m) <= 90, "at least 10 eliminated after stage 1 closes")
	var sim_now: float = g.simulation_time
	g.simulation_time = -1
	g.save_game()
	g.simulation_time = sim_now
	g.tiger_escape = {}
	g.load_game()
	m = tiger.round_state()
	check(m["stage"] == 1 and 1 in m["claimed"] and m["destroyed"] >= 0, "save reload preserves escape and claims")

	# 推进足够长的时间，让后续阶段名额满并淘汰停留在第1关的玩家
	g.simulation_time += 200000.0
	tiger.on_order({})
	check(m["status"] == "lost" and m["stage"] == 1 and m["points"] == 0, "quota elimination eliminates slow runner")
	check(tiger.local_action("restart").get("rewards", [1]).is_empty(), "restart never repeats already claimed gift")
	m = tiger.round_state()
	for k in 7: tiger.on_order({})
	check(m["stage"] == 2, "multiple order targets advance in order")
	g.simulation_time += 200000.0
	tiger.tick()
	check(m["status"] == "lost", "offline time catches up and eliminates")
	check(tiger.local_action("restart").get("rewards", []).size() == 3, "restart settles every unclaimed reached gift")
	m = tiger.round_state()
	var total := 0
	for row in m["stages"]: total += int(row["points"])
	for k in total: tiger.on_order({})
	check(m["status"] == "won" and m["stage"] == 10, "all ten stages unlock grand prize")
	g.simulation_time += 200000.0
	tiger.tick()
	check(m["status"] == "won", "tiger cannot eliminate a completed run")

	# 主棋盘交互：交换与合成不加分，完成订单加分
	tiger.local_action("restart")
	for k in g.board.size(): g.board[k] = {"id": "", "lock": 0}
	g.board[0]["id"] = "fruit_1"
	g.board[1]["id"] = "fruit_2"
	check(g.try_drop(0, 1) == "swap" and tiger.round_state()["points"] == 0, "swapping main-board items gives no score")
	g.board[0]["id"] = "fruit_1"
	g.board[1]["id"] = "fruit_1"
	check(g.try_drop(0, 1) == "merge" and tiger.round_state()["points"] == 0, "real main-board merge gives no escape points")
	g.orders = [{"who": 2, "items": ["fruit_2"], "rw": {"shell": 1}, "story": false}]
	g.board[1]["id"] = "fruit_2"
	check(g.complete_order(0).size() == 1 and tiger.round_state()["points"] == 1, "real main-board order completion awards escape point")

	# 验证精确名额淘汰：第1关90名额，第91名起10人被吃掉
	m = tiger.round_state()
	var custom_bots: Array = []
	for i in 99:
		var arr := []
		# 前90个在100秒完成第1关，后9个在500秒完成第1关
		arr.append(100.0 if i < 90 else 500.0)
		custom_bots.append({"slot": i + 1, "name": "B%d" % i, "avatar": i % 8, "arrivals": arr, "stage": 0, "status": "running"})
	m["bots"] = custom_bots
	m["stage"] = 0
	m["points"] = 0
	m["stage_times"] = []
	m["destroyed"] = -1
	m["status"] = "running"
	g.simulation_time = float(m["start"]) + 100.0
	tiger.tick()
	check(m["status"] == "lost" and m["destroyed"] == 0, "when 90 opponents finish stage 1 first, slow player is eliminated")
	check(tiger.survivors(m) == 90, "exactly 90 survivors remain (10 eliminated)")

	# UI 与自动弹窗验证
	tiger.local_action("restart")
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	main.show_screen("board", true)
	await process_frame
	var tiger_view: Control = null
	for entry in main.board_screen._activity_row.entries:
		if entry["id"] == "tiger": tiger_view = entry["view"]
	check(tiger_view != null and tiger_view.visible, "activity entry appears in main-board task row")

	# 完成第1阶段条件时自动打开面板
	for k in 3: tiger.on_order({})
	await create_timer(0.45).timeout
	var open_tiger = null
	for p in main.popup_layer._stack:
		if is_instance_valid(p) and str(p.get_meta("popup_name", "")) == "tiger":
			open_tiger = p
	check(open_tiger != null, "completing stage condition automatically opens tiger panel")
	open_tiger.close()
	await create_timer(0.25).timeout

	# 被淘汰时自动打开面板并播放扑击动画
	g.simulation_time += 200000.0
	tiger.tick()
	await process_frame
	open_tiger = null
	for p in main.popup_layer._stack:
		if is_instance_valid(p) and str(p.get_meta("popup_name", "")) == "tiger":
			open_tiger = p
	check(open_tiger != null and open_tiger.attack_active, "being eliminated automatically opens tiger panel with attack animation")
	open_tiger._process(2.0)
	check(not open_tiger.attack_active and tiger.seen_attack(tiger.round_state()) >= 0, "attack finishes and is acknowledged")
	print("RESULT ", failures, " failures")
	quit(0 if failures == 0 else 1)
