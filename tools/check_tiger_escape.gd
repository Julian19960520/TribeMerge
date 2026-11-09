extends SceneTree
var failures := 0
var tiger

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1

func run() -> void:
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
	for k in 2: tiger.on_order({})
	check(m["stage"] == 0 and m["points"] == 2, "partial points do not skip a node")
	tiger.on_order({})
	check(m["stage"] == 1 and m["points"] == 0, "full progress jumps to next node")
	check(tiger.local_action("claim", 2).has("error"), "future reward cannot be claimed")
	check(tiger.local_action("claim", 1).get("rewards", []) == [["fire_2", 15]], "reached node unlocks configured gift")
	check(tiger.local_action("claim", 1).has("error"), "node gift pays once")
	g.simulation_time += 10800
	tiger.tick()
	check(m["destroyed"] == 0 and m["status"] == "running", "first timed attack destroys node behind runner")
	var sim_now: float = g.simulation_time
	g.simulation_time = -1
	g.save_game()
	g.simulation_time = sim_now
	g.tiger_escape = {}
	g.load_game()
	m = tiger.round_state()
	check(m["stage"] == 1 and 1 in m["claimed"] and m["destroyed"] == 0, "save reload preserves escape and claims")
	g.simulation_time += 10800
	tiger.on_order({})
	check(m["status"] == "lost" and m["stage"] == 1 and m["points"] == 0, "attack deadline eliminates before merge can rescue runner")
	check(tiger.local_action("restart").get("rewards", [1]).is_empty(), "restart never repeats already claimed gift")
	m = tiger.round_state()
	for k in 7: tiger.on_order({})
	check(m["stage"] == 2, "multiple merge targets advance in order")
	g.simulation_time += 200000
	tiger.tick()
	check(m["status"] == "lost", "offline time catches up and eliminates")
	check(tiger.local_action("restart").get("rewards", []).size() == 3, "restart settles every unclaimed reached gift")
	m = tiger.round_state()
	var total := 0
	for row in m["stages"]: total += int(row["points"])
	for k in total: tiger.on_order({})
	check(m["status"] == "won" and m["stage"] == 10, "all ten stages unlock grand prize")
	g.simulation_time += 200000
	tiger.tick()
	check(m["status"] == "won", "tiger cannot eliminate a completed run")
	# Exercise the real main-board hook: swaps never score; successful merges do.
	tiger.local_action("restart")
	for k in g.board.size(): g.board[k] = {"id": "", "lock": 0}
	g.board[0]["id"] = "fruit_1"
	g.board[1]["id"] = "fruit_2"
	check(g.try_drop(0, 1) == "swap" and tiger.round_state()["points"] == 0, "swapping main-board items gives no score")
	g.board[0]["id"] = "fruit_1"
	g.board[1]["id"] = "fruit_1"
	check(g.try_drop(0, 1) == "merge" and tiger.round_state()["points"] == 0, "real main-board merge gives no escape points")
	# Accepted completion, rather than a merge, is the scoring hook.
	g.orders = [{"who": 2, "items": ["fruit_2"], "rw": {"shell": 1}, "story": false}]
	g.board[1]["id"] = "fruit_2"
	check(g.complete_order(0).size() == 1 and tiger.round_state()["points"] == 1, "real main-board order completion awards escape point")
	check(tiger.round_state()["bots"].size() == 15, "round contains fifteen simulated companions")
	var cohort: Dictionary = tiger.round_state()
	var bots: Array = cohort["bots"].duplicate(true)
	var arrivals: Array = []
	for k in cohort["stages"].size(): arrivals.append(float(cohort["interval"]) * 0.5 * (k + 1))
	cohort["bots"] = [{"name": "快", "stage": 0, "status": "running", "arrivals": arrivals}, {"name": "慢", "stage": 0, "status": "running", "arrivals": [float(cohort["interval"])]}]
	tiger._tick_bots(cohort, float(cohort["start"]) + float(cohort["interval"]) * 10)
	check(cohort["bots"][0]["status"] == "won" and cohort["bots"][0]["stage"] == 10, "fast simulated companion reaches the finish")
	check(cohort["bots"][1]["status"] == "lost" and cohort["bots"][1]["stage"] == 0, "slow companion is eliminated at exact deadline without offline resurrection")
	cohort["bots"] = bots
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	main.show_screen("board", true)
	await process_frame
	var panel = main.open("tiger")
	await process_frame
	check(panel != null and panel.path != null and panel.action_button.text == "去完成订单", "escape screen renders playable trail and action")
	check(main.board_screen._tiger_entry.visible, "activity entry appears in main-board task row")
	panel._preview(1)
	await process_frame
	check(main.popup_layer.get_child_count() >= 2, "node gift opens its reward preview")
	main.popup_layer.get_child(-1).close()
	await create_timer(0.25).timeout
	# Attack while the screen is open; no animation before the deadline.
	check(not panel.attack_active, "no attack animation before deadline")
	g.simulation_time += 10800
	tiger.tick()
	panel._refresh()
	check(panel.attack_active and panel.action_button.text == "追击中…", "open screen immediately plays attack before result")
	panel._process(0.5)
	check(panel.attack_active, "attack remains visible during pounce")
	panel._process(1.0)
	check(not panel.attack_active and tiger.seen_attack(tiger.round_state()) == 0, "attack finishes and is acknowledged once")
	panel._refresh()
	check(not panel.attack_active, "same attack never replays after refresh")
	# Closing before an attack, then opening later, replays the pending attack.
	panel.close()
	await create_timer(0.25).timeout
	tiger.local_action("restart")
	g.simulation_time += 10800
	tiger.tick()
	panel = main.open("tiger")
	await process_frame
	check(panel.attack_active, "opening screen after offline elimination replays attack")
	panel._process(2.0)
	check(not panel.attack_active, "offline replay reaches elimination result")
	panel.close()
	await create_timer(0.25).timeout
	panel = main.open("tiger")
	await process_frame
	check(not panel.attack_active, "reopening does not replay an acknowledged attack")
	print("RESULT ", failures, " failures")
	quit(0 if failures == 0 else 1)
