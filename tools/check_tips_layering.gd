extends SceneTree
## 一次性提示不能和升级面板叠在一起，也不能圈一个看不见的目标把玩家卡住。
## 1. 制作订单排在订单栏最右、滚出画面：提示前先把那张卡滚进来，亮处在屏幕里。
## 2. 目标完全看不见时：没有亮处，点任意处就能继续。
## 3. 提示开着时升级：提示先让开；升级面板弹出前、开着的时候都不出提示；面板要等订单宝箱飞完才弹。
## 4. 不再出「升到 N 级啦！新内容来了」这条和升级面板重复的提示。
## godot --headless --path . --script tools/check_tips_layering.gd -- --replay-test --cloud-off
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1

func run() -> void:
	var g = root.get_node("G")
	g.new_game()
	g.tutorial_on = false
	g.seen_tutorial = true
	g.level = 6
	g.tips_seen = {"howto": true, "stash": true, "egen": true, "build": true}
	g.orders = []
	g.rules.orders.refill_orders()
	var has_craft := false
	for o in g.orders: if str(o.get("kind", "")) == "craft": has_craft = true
	if not has_craft:
		var made: Dictionary = g.rules.orders._craft_order(g.rules.orders._pick_dish())
		if not made.is_empty(): g.orders.append(g.order_identity(made))
	# 订单多到一排放不下，制作订单排在最后
	while g.orders.size() < 6:
		var extra: Dictionary = g.orders[0].duplicate(true)
		extra.erase("kind")
		extra["items"] = ["fruit_3"]
		extra.erase("id")
		g.orders.insert(0, g.order_identity(extra))
	var craft := -1
	for k in g.orders.size():
		if str(g.orders[k].get("kind", "")) == "craft": craft = k
	# 把制作订单挪到最后，让它在订单栏里滚出画面
	if craft >= 0 and craft != g.orders.size() - 1:
		var o = g.orders[craft]
		g.orders.remove_at(craft)
		g.orders.append(o)
		craft = g.orders.size() - 1
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.3).timeout
	main.show_screen("board", true)
	g.orders_changed.emit()
	await create_timer(0.6).timeout
	var bs = main.board_screen
	var tips = main.tips
	check(craft >= 0 and g.orders.size() >= 4, "测试局里有排在最后的制作订单（%d 张订单）" % g.orders.size())
	bs._orders.jump_to(0.0)
	var before: Rect2 = bs.order_card_rect(craft)
	check(before.get_area() < bs._cards[craft].get_global_rect().get_area() * 0.5, "制作订单一开始在订单栏外面")

	# 1. 提示前先把卡滚进来
	tips._poll = 1.0
	await create_timer(0.7).timeout
	check(tips.visible and tips._key == "craft", "出了制作订单提示")
	var lit: bool = not tips._holes.is_empty()
	for h in tips._holes:
		if not Rect2(Vector2.ZERO, tips.size).encloses(h): lit = false
	check(lit, "亮处在屏幕里看得见")
	check(bs.order_card_rect(craft).get_area() >= bs._cards[craft].get_global_rect().get_area() * 0.9, "那张订单卡被滚进了订单栏")
	tips._close(false)

	# 2. 目标看不见：点任意处继续
	check(tips.show_once("probe_offscreen", "看不见的目标", func(): return Rect2(5000, 5000, 100, 100)), "能显示目标在屏外的提示")
	check(tips._holes.is_empty() and tips._cont.text == "点击继续", "目标看不见时不亮，提示改成点击继续")
	await create_timer(0.4).timeout
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	tips._gui_input(click)
	check(not tips.visible, "点任意处能关掉，不会卡住")

	# 3. 提示开着时升级
	check(tips.show_once("probe_level", "升级前的提示", func(): return bs._stash_wrap.get_global_rect()), "升级前开着一条提示")
	var free: Array = []
	for i in g.board.size():
		if free.size() < 3 and int(g.board[i]["lock"]) == 0 and str(g.board[i]["id"]) == "": free.append(i)
	for i in [36, 37, 38]:
		if free.size() >= 3: break
		g.board[i] = {"id": "", "lock": 0}
		free.append(i)
	var items := []
	for k in 3:
		g.board[int(free[k])]["id"] = "fruit_%d" % (k + 2)
		items.append({"to": int(free[k]), "id": "fruit_%d" % (k + 2)})
	g.board_changed.emit()
	g.present("order_chest", {"items": items, "stashed": 0})
	g.present("level_up", {})
	await process_frame
	check(not tips.visible, "升级一发生，开着的提示就让开")
	check(not g.tips_seen.has("probe_level"), "让开的提示不算看过，之后还能再出")
	var overlap := false
	var flights_left_when_open := -1
	for _k in 40:
		await create_timer(0.1).timeout
		if tips.visible: overlap = true
		tips._poll = 1.0
		if main.popup_layer.get_child_count() > 0 and flights_left_when_open < 0:
			flights_left_when_open = bs.board.flights.size()
	check(not overlap, "升级面板弹出前和开着时都没有提示插进来")
	check(flights_left_when_open == 0, "升级面板等订单宝箱的物品都落到棋盘才弹")
	var has_panel := false
	for p in main.popup_layer.get_children():
		if p.has_meta("reward_screen"): has_panel = true
	check(has_panel, "升级面板弹出来了")
	for k in g.tips_seen.keys():
		if str(k).begins_with("unlock_"): check(false, "不该再出和升级面板重复的新内容提示")
	quit(1 if failures > 0 else 0)
