extends SceneTree
## One purchase automatically completes the original tribe construction animation.
var failures := 0
var g
var replay
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func button(node: Node):
	if node is Control and node.has_signal("pressed") and node.get("res") == "shell_2": return node
	for child in node.get_children():
		var found = button(child)
		if found != null: return found
	return null
func has_control(node: Node, name: String) -> bool:
	if str(node.name) == name: return true
	for child in node.get_children():
		if has_control(child, name): return true
	return false
func clear_popups(main) -> void:
	main.popup_layer.clear()
	await process_frame
	await process_frame
func run() -> void:
	g = root.get_node("G"); replay = root.get_node("Replay")
	for node in root.get_children(): node.set_process(false)
	replay.executing = true; replay.meta = {}; replay.seq = 0; replay.base = 0
	replay.pending = []; replay.inflight = {}; replay.clock = 1794240000
	g.simulation_time = replay.clock
	g.new_game(); g.shells = 1000; g.energy = 20; g.energy_stamp = replay.clock
	replay.advance(); replay._canonicalize_live(); replay.executing = false
	replay.meta["onboarding"]["step"] = g.rules.onboarding.stage_index("build1")
	var main = load("res://main.tscn").instantiate(); root.add_child(main)
	main.tips.set_process(false)
	await create_timer(0.4).timeout
	var popup = main.popup_layer.top()
	var buy = button(popup)
	check(buy != null and popup.get_meta("build_rects", []).size() == 1, "新手使用普通部件建造面板，引导只指向建造按钮")
	if buy == null: quit(1); return
	var before: int = g.shells; var cost: int = g.rules.progression.build_cost("fire")
	var energy: int = g.energy
	buy.pressed.emit()
	buy.pressed.emit()
	check(g.builds["fire"] == 2 and g.shells == before - cost, "一次点击只建一件、只扣一次费用，连点不能重复购买")
	check(main.home.is_building() and not has_control(main.home._build_fx, "install_build") and not has_control(main.home._build_fx, "skip_build"), "点击建造立即播放动画，不出现开箱、安装或跳过按钮")
	await create_timer(0.5).timeout
	check(main.home.is_building() and not main._rw_showing, "施工过程中先播放锤击和落地，不提前展示奖励")
	await create_timer(2.2).timeout
	check(not main.home.is_building() and main.home._hide.is_empty() and main._rw_showing, "无任何二次操作，动画自动完成并展示建成奖励")
	check(g.energy == energy + 10, "第一件建造奖励只结算一次")
	var reward = main.popup_layer.top()
	if reward != null and reward.on_tap.is_valid(): reward.on_tap.call()
	await create_timer(0.35).timeout
	check(g.energy == energy + 10, "关闭奖励展示不会重复发奖")
	await clear_popups(main)

	# Even a building panel opened on the board must route through the animation.
	g.tutorial_on = false; g.seen_tutorial = true
	main.show_screen("board", true)
	popup = main.open("build", "fire"); buy = button(popup)
	before = g.shells; cost = g.rules.progression.build_cost("fire")
	buy.pressed.emit()
	check(main.screen == "home" and main.home.is_building() and g.shells == before - cost, "从棋盘进入的建造也会切回部落播放动画")
	await create_timer(2.7).timeout
	check(not main.home.is_building() and main._rw_showing, "普通建造同样自动播完并显示奖励")
	await clear_popups(main)
	g.shells = 0
	popup = main.open("build", "fire"); buy = button(popup)
	var built: int = g.builds["fire"]
	buy.pressed.emit()
	check(g.builds["fire"] == built and not main.home.is_building(), "费用不足时不扣款、不播放动画、不发奖")
	await clear_popups(main)

	# Saved reference-only preview/help beats remain compatible and need no tap.
	g.tutorial_on = true; g.seen_tutorial = false
	for key in ["build_preview", "howto"]:
		replay.meta["onboarding"]["step"] = g.rules.onboarding.stage_index(key)
		main._guide._refresh()
		check(main.popup_layer.top() == null and str(g.rules.onboarding.stage().get("key", "")) == "back2", "旧步骤自动接回建造后引导：" + key)
	check(g.tips_seen.get("howto", false), "跳过旧说明后，不会在新手结束时再强制弹出")
	await process_frame
	main.free(); g.main = null
	quit(1 if failures else 0)
