extends SceneTree
## Each saved modal/navigation lesson must reopen the correct screen after restart.
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func run() -> void:
	var g = root.get_node("G")
	var replay = root.get_node("Replay")
	for node in root.get_children(): node.set_process(false)
	g.new_game(); replay.meta = {}
	replay.executing = true; replay.advance(); replay._canonicalize_live(); replay.executing = false
	for entry in [["recipe_time", "board", "recipe_time"], ["level_preview", "board", "level_rewards"], ["back1", "home", ""]]:
		replay.meta["onboarding"]["step"] = g.rules.onboarding.stage_index(str(entry[0]))
		g.orders = [g.order_identity({"who": 0, "kind": "craft", "dish": "salad", "mats": ["fruit_1"], "items": ["fruit_1"], "secs": 10, "phase": "need", "story": true, "onboarding": "craft1", "rw": {"shell": 2, "xp": 1}})]
		var before: int = g.amber
		var main = load("res://main.tscn").instantiate()
		root.add_child(main)
		await process_frame
		check(main.screen == str(entry[1]) and main._guide._step == str(entry[0]), "恢复 " + str(entry[0]) + " 的场景和步骤")
		if str(entry[2]) != "": check(main.popup_layer.top() != null and main.popup_layer.top().has_meta(str(entry[2])), "恢复时重新打开教学面板")
		check(g.amber == before, "恢复展示不重复结算奖励")
		main.free(); g.main = null
	quit(1 if failures else 0)
