extends SceneTree
var failures := 0
var g
var replay
var main
const START := 1794240000
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func fresh() -> void:
	replay.executing = true
	replay.meta = {}; replay.seq = 0; replay.base = 0; replay.pending = []; replay.inflight = {}
	replay.clock = START; g.simulation_time = START
	g.new_game(); replay.advance(); replay._canonicalize_live(); replay.executing = false
	for i in g.board.size(): g.board[i] = {"id": "", "lock": 0}
	g.clear_presentations()
func click(button, global_point: Vector2) -> void:
	g.scroll_drag = false
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT; e.pressed = true
	e.position = button.get_global_transform().affine_inverse() * global_point
	button._gui_input(e)
	await create_timer(0.07).timeout
	e.pressed = false
	e.position = button.get_global_transform().affine_inverse() * global_point
	button._gui_input(e)
func scroller(node: Node):
	if node.get_script() == load("res://scripts/ui/Scroller.gd"): return node
	for child in node.get_children():
		var found = scroller(child)
		if found != null: return found
	return null
func run() -> void:
	g = root.get_node("G"); replay = root.get_node("Replay")
	for node in root.get_children(): node.set_process(false)
	fresh(); g.level = 3; g.builds["fire"] = 3
	var p: Dictionary = g.rules.onboarding.progress()
	p["step"] = g.rules.onboarding.stage_index("recipe_open")
	for row in g.rules.onboarding.config()["orders"]: p["issued"].append(str(row["tag"]))
	g.orders = []
	for _i in 5: g.orders.append(g.order_identity({"who": 0, "items": ["fruit_8"], "rw": {"shell": 1}, "story": false}))
	var recipe: Dictionary = g.rules.orders._craft_order(Data.DISHES["feast"])
	recipe["onboarding"] = "craft1"; recipe["guide_revision"] = int(g.rules.onboarding.config()["version"])
	g.orders.append(recipe)
	main = load("res://main.tscn").instantiate(); root.add_child(main)
	main.show_screen("board", true)
	await process_frame
	await process_frame
	var offers = main.get_node_or_null("OfferController")
	if offers != null: offers.set_process(false)
	var card = main.board_screen._cards.back()
	var spots: Array = card._formula_spots(recipe, card.size.x)
	var dish: Rect2 = card.recipe_icon_rect()
	var aligned := true
	for spot in spots: aligned = aligned and is_equal_approx(spot["c"].y, dish.get_center().y)
	check(aligned and spots.size() == 4 and spots[1]["c"].x - spots[0]["c"].x < spots[0]["s"], "多原料适度重叠，与右侧产物保持同一排")
	check(card.size.x < 300 and spots.back()["c"].x + spots.back()["s"] * 0.5 < dish.position.x - 30, "四种材料卡片仍紧凑，中央留出独立箭头位置")
	for delta in [Vector2.ZERO, Vector2(-30, 0), Vector2(30, 0), Vector2(0, -30), Vector2(0, 30), Vector2(-21, -21), Vector2(21, 21), Vector2(38, 0), Vector2(0, 38), Vector2(26, 26)]:
		g.rules.onboarding.progress()["step"] = g.rules.onboarding.stage_index("recipe_open")
		main._guide._refresh()
		var icon_rect: Rect2 = card.recipe_icon_global_rect()
		check(main._guide._holes.size() == 1 and main._guide._holes[0] == icon_rect and main.board_screen._orders.offset > 0, "配方引导只圈产物图标，并将目标自动滚进可视范围")
		var point: Vector2 = icon_rect.get_center() + delta
		check(not main._guide._has_point(point), "蒙层放行产物图标亮区 %s" % delta)
		await click(card._recipe_button, point)
		var popup = main.popup_layer.top()
		check(popup != null and popup.has_meta("recipe_mats"), "亮区边缘实际点击也能打开配方 %s" % delta)
		main.popup_layer.clear()
		await process_frame
		await process_frame
	g.tutorial_on = false
	main._guide._refresh()
	g.level = 4; g.rush = 100
	g.orders = [g.rules.orders._craft_order(Data.DISHES["fruitbasket"])]
	g.board[0]["id"] = "fruit_7"
	g.orders_changed.emit(); g.board_changed.emit()
	await process_frame
	await process_frame
	card = main.board_screen._cards[0]
	check(card._rewards_layer.visible and not card._time_bar.visible and card.cooking_progress() == 0, "未制作时保留奖励列表")
	check(card._make_host.visible and card.get_child(-1) == card._make_host and card._make_host.size == Vector2(112, 52), "材料齐后制作按钮画在奖励上面，宽度不变")
	var started: Dictionary = replay.perform("craft", {"cell": 0}, START)
	g.simulation_time = START + 1; replay.perform("tick", {}, START + 1)
	await process_frame
	await process_frame
	card = main.board_screen._cards[0]; card._update_clock()
	check(not started.has("error") and not card._rewards_layer.visible and card._time_bar.visible and not card._status.visible, "制作期间隐藏奖励列表和完成提示，显示时间进度条")
	# 制作时长随等级和菜的难度算（rules.craft_time），这里按订单上实际写入的秒数校验
	var cook_cell := int(g.orders[0].get("cell", 0))
	var secs := int(g.orders[0].get("secs", 0))
	var skip_icon: Control = card._skip_button.get_child(0)
	var skip_text: Control = card._skip_button.get_child(2)
	check(secs > 2 and card._skip_cost.text == str(g.rules.orders.rush_need(cook_cell)) and skip_icon.position.x + skip_icon.size.x <= skip_text.position.x + 4 and card._skip_cost.position.x > skip_icon.position.x + skip_icon.size.x * 0.4 and card._skip_cost.position.y > 20, "跳过按钮沙漏在左、文字在右，消耗数字位于图标右下角")
	var t0 := int(float(g.orders[0].get("t0", START)))
	var half := t0 + int(secs / 2)
	g.simulation_time = half; replay.perform("tick", {}, half)
	await process_frame
	card = main.board_screen._cards[0]; card._update_clock()
	var need: int = g.rules.orders.rush_need(cook_cell)
	check(absf(card.cooking_progress() - float(secs - g.rules.orders.cook_left(cook_cell)) / float(secs)) < 0.02 and card.cooking_progress() > 0.3 and card.cooking_progress() < 0.7 and card._skip_cost.text == str(need), "制作到一半时进度条和跳过费用同步更新")
	g.rush = 0; card._update_clock()
	check(not card._skip_button.enabled and card._skip_cost.text == str(need), "沙漏不足时仍显示费用，并禁用跳过")
	g.rush = 100; card._update_clock()
	await click(card._skip_button, card._skip_button.get_global_rect().get_center())
	await process_frame
	card = main.board_screen._cards[0]; card._update_clock()
	check(g.rush == 100 - need and card._rewards_layer.visible and not card._time_bar.visible and not card._skip_button.visible, "跳过扣除显示的费用，完成后恢复奖励列表")
	main.close_all()
	var book_rules = load("res://scripts/ui/popups/ItemPopups.gd")
	var last_seed := "seed_%d" % Data.max_lv("seed")
	var last_dish := str(Data.DISHES.keys().back())
	g.discovered = {last_seed: true, last_dish: true}; g.book_claimed = {}
	check(book_rules._book_has_reward(0) and book_rules._book_has_reward(Data.LINES.size()) and not book_rules._book_has_reward(1), "产线与制作页签只在各自有可领取奖励时标红点")
	var book = book_rules.book(1); root.add_child(book)
	await process_frame
	var tab_button
	for child in book.box.get_children():
		if child.has_meta("book_tab") and int(child.get_meta("book_tab")) == 0: tab_button = child
	await click(tab_button, tab_button.get_global_rect().get_center())
	var sc = scroller(book)
	var target
	for child in sc.content.get_children():
		if str(child.get_meta("book_item", "")) == last_seed: target = child
	check(sc.offset > 0 and sc.get_global_rect().encloses(target.get_global_rect()), "切到带红点的产线页签后自动定位到可领奖物品")
	var energy: int = g.energy
	check(int(replay.perform("book", {"id": last_seed}, replay.clock).get("energy", 0)) > 0 and g.energy > energy and not book_rules._book_has_reward(0), "领完该页最后一个奖励后红点立即消失")
	for child in book.box.get_children():
		if child.has_meta("book_tab") and int(child.get_meta("book_tab")) == Data.LINES.size(): tab_button = child
	await click(tab_button, tab_button.get_global_rect().get_center())
	sc = scroller(book)
	target = null
	for child in sc.content.get_children():
		if str(child.get_meta("book_item", "")) == last_dish: target = child
	check(sc.get_global_rect().encloses(target.get_global_rect()), "制作图鉴可领取物品保持可见，整页装得下时无需多余滚动")
	book.free()
	await process_frame
	main.free(); g.main = null
	await process_frame
	print("RESULT: %d failures" % failures)
	quit(1 if failures else 0)
