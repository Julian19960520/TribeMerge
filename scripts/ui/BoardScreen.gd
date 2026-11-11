class_name BoardScreen
extends Control
const Meme := preload("res://scripts/Meme.gd")

const BOARD_POS := Vector2(24, 432)
## 暂存区、基地和订单在同一个横向滚动列表里
const ROW_RECT := Rect2(0, 140, 720, 304)
const ORDER_X := 272.0
const STASH_RECT := Rect2(6, 38, 118, 226)
const BASE_RECT := Rect2(126, 38, 142, 226)
const HAMMER_W := 130.0

var _bubble_offer: Control
var _bubble_title: Label
var _bubble_time: Label
var _bubble_buy: TButton
var board: Board
var _orders: Scroller
var _info_name: Label
var _info_desc: Label
var _info_visual: ItemActionPanel
var _info_action := {}
var _info_btn: TButton
var _del_btn: TButton
## 双倍体力开关（Data.BOOST_LEVEL 级解锁，圆钮，在顶栏集市小屋下面）
var _boost_btn: TButton
var _del_lbl: Label
var _undo_cell := -1
var _undo_id := ""
var _inv_lbl: Label
var _xp_lbl: Label
var _lv_lbl: Label
var _stash_btn: TButton
var _stash_wrap: Control
var _base_btn: TButton
var _hammer_btn: TButton
var _pouch: TButton
var _cards: Array[Control] = []
var _cards_root: OrderStrip
var _orders_pending := false
var _clock_elapsed := 0.0
var _order_shovel_visible := false
var _activity_row: BoardActivityRow
var _order_scroll: Tween

func stash_pos() -> Vector2:
	return _stash_wrap.global_position + _stash_wrap.size * 0.5

func _ready() -> void:
	size = Vector2(720, 1480)
	mouse_filter = MOUSE_FILTER_IGNORE
	UI.box(self, Rect2(0, 0, 720, 1480), _paint_bg, false)
	UI.box(self, Rect2(0, 0, 720, 430), _paint_scene)
	board = Board.new()
	board.position = BOARD_POS
	add_child(board)
	board.selected_changed.connect(_on_select)
	board.activated.connect(_on_activate)
	board.dropped_outside.connect(_on_drop_outside)

	_orders = Scroller.new()
	_orders.horizontal = true
	_orders.position = ROW_RECT.position
	_orders.size = ROW_RECT.size
	add_child(_orders)

	_stash_wrap = Control.new()
	_stash_wrap.position = STASH_RECT.position
	_stash_wrap.size = STASH_RECT.size
	_stash_wrap.pivot_offset = _stash_wrap.size * 0.5
	_stash_wrap.mouse_filter = MOUSE_FILTER_IGNORE
	_orders.content.add_child(_stash_wrap)
	_stash_btn = UI.hit(_stash_wrap, Rect2(Vector2.ZERO, STASH_RECT.size), _on_stash)
	_stash_btn.extra = _paint_stash
	_base_btn = UI.hit(_orders.content, BASE_RECT, func(): G.main.open("level"))
	_base_btn.extra = _paint_hero
	_lv_lbl = UI.lbl(_base_btn, "", Rect2(0, 140, BASE_RECT.size.x, 30), 18, Art.INK)
	_xp_lbl = UI.lbl(_base_btn, "", Rect2(26, 174, BASE_RECT.size.x - 34, 28), 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 5, Art.INK)
	_hammer_btn = UI.hit(_orders.content, Rect2(ORDER_X, BASE_RECT.position.y, HAMMER_W, BASE_RECT.size.y), _on_hammer)
	_hammer_btn.extra = _paint_hammer
	_hammer_btn.pivot_offset = Vector2(HAMMER_W, BASE_RECT.size.y) * 0.5
	_hammer_btn.visible = false
	_cards_root = OrderStrip.new()
	_cards_root.craft_requested.connect(_on_craft)
	_cards_root.delivery_requested.connect(_on_deliver)
	_cards_root.mouse_filter = MOUSE_FILTER_IGNORE
	_orders.content.add_child(_cards_root)
	_activity_row = BoardActivityRow.new(self, {"orders": _orders, "stash": _stash_wrap,
		"stash_button": _stash_btn, "base": _base_btn, "hammer": _hammer_btn, "cards": _cards_root})
	_activity_row.refresh(false)

	_pouch = UI.hit(self, Rect2(10, 1312, 124, 150), func(): G.main.open("inventory"))
	_pouch.extra = func(ci, sz): Paint.pouch(ci, Vector2(sz.x * 0.5, 58), 1.2)
	_inv_lbl = UI.lbl(self, "", Rect2(10, 1410, 124, 40), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 8, Art.INK, true)

	UI.box(self, Rect2(140, 1300, 456, 170), _paint_info)
	_info_name = UI.lbl(self, "", Rect2(196, 1300, 300, 46), 24, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 7, Art.INK)
	_info_desc = UI.lbl(self, "", Rect2(170, 1352, 300, 96), 21, Color("6b4a2a"), HORIZONTAL_ALIGNMENT_CENTER)
	_info_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_visual = ItemActionPanel.new()
	_info_visual.position = Vector2(170, 1352)
	_info_visual.size = Vector2(300, 96)
	add_child(_info_visual)
	_info_btn = UI.hit(self, Rect2(150, 1300, 46, 46), _open_info)
	_info_btn.extra = func(ci, sz): Paint.glyph(ci, "info", sz * 0.5, 1.2)
	_del_btn = UI.btn(self, Rect2(486, 1360, 86, 80), "", "red", _on_delete)
	_del_btn.glyph = "trash"
	_del_lbl = UI.lbl(self, "丢弃", Rect2(476, 1326, 106, 34), 20, Art.CLAY, HORIZONTAL_ALIGNMENT_CENTER, 6, Color.WHITE)

	var home := UI.btn(self, Rect2(604, 1330, 106, 110), "", "teal", func(): G.main.show_screen("home"))
	home.extra = func(ci, sz): Paint.home_icon(ci, sz * 0.5 + Vector2(0, -2), 0.85)

	add_child(preload("res://scripts/ui/UfoEntry.gd").new())
	var gm := UI.btn(self, Rect2(12, 156, 68, 42), "GM", "teal", func():
		var result: Dictionary = Replay.perform("gm")
		if result.has("error"): G.main.toast(str(result["error"]))
		else: G.main.toast("全部功能已解锁，卡册已开放"), 21)
	gm.name = "gm_activities"
	_boost_btn = UI.btn(self, Rect2(646, 118, 66, 66), "", "grey", _on_boost)
	_boost_btn.is_round = true
	_boost_btn.extra = _paint_boost
	_boost_btn.visible = false
	_build_bubble_offer()
	G.changed.connect(_refresh_hud)
	G.orders_changed.connect(_request_orders)
	G.board_changed.connect(_on_board_changed)
	_build_orders()
	_refresh_hud()
	_on_select(-1)

# ---------------------------------------------------------------- 绘制

func _paint_bg(ci: CanvasItem, sz: Vector2) -> void:
	Paint.vgrad(ci, Rect2(0, 400, sz.x, sz.y - 400), Color("3f6e3a"), Color("2c4f2a"))
	for row in 40:
		for col in 18:
			var p := Vector2(col * 42 + (row % 2) * 21, 410 + row * 28)
			ci.draw_colored_polygon(Art.ell(p, Vector2(18, 9), row * 18 + col, 0.0, 10, 0.0, 0.0), Color(0, 0, 0, 0.08))

func _paint_scene(ci: CanvasItem, sz: Vector2) -> void:
	Paint.vgrad(ci, Rect2(0, 0, sz.x, 380), Color("78c2c4"), Color("e9d9a6"))
	Paint.hills(ci, 300, sz.x, 60, Color("8bb39a"), 5, 400)
	for i in 4:
		Paint.palm(ci, Vector2(40 + i * 220, 380), 160 + i * 10, i + 10, Color("3c7a44"))
	Sprites.draw(ci, "board_curtain_l", Rect2(0, 0, 90, 380))
	Sprites.draw(ci, "board_curtain_r", Rect2(sz.x - 90, 0, 90, 380))
	Sprites.draw(ci, "board_log", Rect2(-10, 372, sz.x + 20, 50))

## 暂存区：临时物品像卡片一样叠放，点击把最上面一张放到棋盘
func _paint_stash(ci: CanvasItem, sz: Vector2) -> void:
	var n := G.stash.size()
	Sprites.draw(ci, "board_stash_tray", Rect2(6, 26, sz.x - 12, sz.y - 34))
	var shown := mini(n, 4)
	var top := G.rules.board.stash_claim_index()
	var order: Array[int] = []
	if top >= 0: order.append(top)
	for i in range(n - 1, -1, -1):
		if i != top: order.append(i)
	for j in shown:
		var k := shown - 1 - j
		var id: String = G.stash[order[k]]
		var off := Vector2(float(k) * 5.0, -float(k) * 9.0)
		var rot := (Art.srnd(n - k) - 0.5) * 0.14 if k > 0 else 0.0
		var cr := Rect2(Vector2(16, 44) + off, Vector2(sz.x - 36, 124))
		# 卡片图带阴影，绕卡片中心转
		Sprites.at(ci, "board_stash_card_top" if k == 0 else "board_stash_card", cr.get_center(), 1.0, rot)
		if k == 0:
			Art.item(ci, id, cr.get_center() + Vector2(0, -4), 90)
	if n == 0:
		ci.draw_string(G.font_body, Vector2(0, 116), "暂存区", HORIZONTAL_ALIGNMENT_CENTER, sz.x, 22, Color(1, 0.9, 0.75, 0.6))
	else:
		Paint.badge_num(ci, Vector2(sz.x - 14, 34))
		var t := str(n)
		ci.draw_string_outline(G.font_body, Vector2(sz.x - 34, 42), t, HORIZONTAL_ALIGNMENT_CENTER, 40, 22, 5, Art.INK)
		ci.draw_string(G.font_body, Vector2(sz.x - 34, 42), t, HORIZONTAL_ALIGNMENT_CENTER, 40, 22, Color.WHITE)
		if top < 0:
			ci.draw_string(G.font_body, Vector2(0, sz.y - 14), "%d级开启" % Data.CARD_LEVEL, HORIZONTAL_ALIGNMENT_CENTER, sz.x, 20, Art.BONE)
		else:
			var bob := 4.0 * sin(Time.get_ticks_msec() / 200.0)
			Sprites.draw(ci, "board_stash_arrow", Rect2(sz.x * 0.5 - 16, sz.y - 30 + bob, 32, 22))

## 主角阿焰的等级卡
func _paint_hero(ci: CanvasItem, sz: Vector2) -> void:
	Sprites.draw(ci, "board_hero_card", Rect2(Vector2.ZERO, sz))
	Meme.draw_chest(ci, Meme.HERO, Rect2(12, 44, sz.x - 24, 126))
	Paint.bar(ci, Rect2(12, 176, sz.x - 24, 24), float(G.xp) / float(G.rules.progression.xp_need()), Art.MOSS)
	Art.item(ci, "xp_1", Vector2(16, 188), 36)

## 不拿拿够建下一段部落时出现，点了回村庄升级
func _paint_hammer(ci: CanvasItem, sz: Vector2) -> void:
	Sprites.draw(ci, "board_hammer_card", Rect2(Vector2.ZERO, sz))
	var title := "升级"
	var tfs := 22
	var tw := G.font_title.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x
	var tp := Vector2((sz.x - tw) * 0.5, 46)
	ci.draw_string_outline(G.font_title, tp, title, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, 5, Art.INK)
	ci.draw_string(G.font_title, tp, title, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, Color("fff1c4"))
	Paint.hammer(ci, Vector2(sz.x * 0.5, 112), 1.35)
	var id := G.rules.progression.next_build_id()
	var cost := G.rules.progression.build_cost(id) if id != "" else 0
	Art.item(ci, "shell_2", Vector2(sz.x * 0.5 - 34, 186), 40)
	var text := str(cost)
	var fs := 22
	var pos := Vector2(sz.x * 0.5 - 6, 186 + (G.font_body.get_ascent(fs) - G.font_body.get_descent(fs)) * 0.5)
	ci.draw_string_outline(G.font_body, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Art.INK)
	ci.draw_string(G.font_body, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)

func _paint_info(ci: CanvasItem, sz: Vector2) -> void:
	Sprites.draw(ci, "board_info_panel", Rect2(Vector2.ZERO, sz))
	if board and (board.selected >= 0 or _undo_cell >= 0):
		Sprites.draw(ci, "board_info_tag", Rect2(26, 4, 304, 40))

# ---------------------------------------------------------------- 订单

func _order_missing(oi: int) -> int:
	return OrderCard.missing(G.orders[oi])

func _request_orders() -> void:
	if _orders_pending: return
	_orders_pending = true
	if is_visible_in_tree(): _flush_orders.call_deferred()

func _flush_orders() -> void:
	if not is_visible_in_tree(): return
	if not _orders_pending: return
	_build_orders()

func _build_orders() -> void:
	_orders_pending = false
	_order_shovel_visible = FossilDig.earning()
	(_cards_root as OrderStrip).refresh()
	_cards = (_cards_root as OrderStrip).cards_by_index
	_activity_row.refresh()

func _on_craft(oi: int) -> void:
	if oi < 0 or oi >= G.orders.size():
		return
	var flights: Array = G.begin_craft(oi)
	if flights.is_empty():
		return
	board.play_gather(flights)
	board.select(int(flights[0]["to"]))
	Sfx.play("whoosh", 0.9)

func _on_deliver(oi: int) -> void:
	if oi < 0 or oi >= G.orders.size() or oi >= _cards.size():
		return
	var card_pos := _cards[oi].get_global_rect().get_center()
	var fossil_earned := FossilDig.earning()
	var result: Dictionary = Replay.perform("order", {"cell": oi})
	if not result.get("ok", false):
		G.main.toast(str(result.get("error", "订单交付失败")))
		return
	_activity_row.order_delivered(card_pos, fossil_earned)
	board.select(-1)
	Sfx.play("coin")
	await get_tree().create_timer(0.35).timeout
	var who := int(result["who"])
	var say := str(result["say"])
	G.main.toast("%s：%s" % [Meme.customer_name(who, true), say if say != "" else Meme.line()])
	RewardPresenter.present(result["rewards"], func(_k): return card_pos)

# ---------------------------------------------------------------- 交互

func set_active(active: bool) -> void:
	visible = active
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	board.set_active(active)
	if active:
		if _orders_pending: _build_orders()
		_refresh_hud()

func _process(delta: float) -> void:
	_clock_elapsed += delta
	if _clock_elapsed < 1.0: return
	_clock_elapsed = fmod(_clock_elapsed, 1.0)
	_activity_row.refresh()
	if _bubble_offer != null and _bubble_offer.visible:
		if G.rules.board.is_merge_bubble(board.selected) and G.rules.board.bubble_left(board.selected) > 0:
			_bubble_tick()
		else:
			_on_select(board.selected)
	var i := board.selected
	if i < 0 or not G.rules.orders.cooking(i):
		return
	var text := "还要 %s。沙漏 %d（每份快 %s），做完要 %d 份。" % [Board._sec_text(maxi(G.rules.orders.cook_left(i), 1)), G.rush, Data.rush_text(), G.rules.orders.rush_need(i)]
	if _info_desc.text != text:
		_info_desc.text = text

func _on_board_changed() -> void:
	_request_orders()
	_refresh_hud()
	if board != null and board.selected >= 0:
		var id := str(G.board[board.selected]["id"])
		_on_select(board.selected)

func _on_hammer() -> void:
	var id := G.rules.progression.next_build_id()
	if id == "" or G.main.screen != "board":
		return
	G.main.show_screen("home")
	var tw := create_tween()
	tw.tween_interval(0.42)
	tw.tween_callback(func():
		if G.main.screen == "home":
			G.main.open("build", id))

func _refresh_hud() -> void:
	if not is_visible_in_tree(): return
	_refresh_bubble_offer()
	_inv_lbl.text = "%d/%d" % [G.inv.size(), G.inv_cap]
	_lv_lbl.text = "阿焰 Lv.%d" % G.level
	_xp_lbl.text = "%d/%d" % [G.xp, G.rules.progression.xp_need()]
	_sync_boost()
	_activity_row.refresh()
	if _order_shovel_visible != FossilDig.earning(): _request_orders()
	_stash_btn.queue_redraw()
	_base_btn.queue_redraw()
	_hammer_btn.queue_redraw()

func _on_select(i: int) -> void:
	_info_action = {}
	_info_visual.hide()
	_info_desc.show()
	_refresh_bubble_offer()
	var cooking := i >= 0 and G.rules.orders.cooking(i)
	# 巨石下面不一定有物品，空石头也显示巨石说明
	var has: bool = i >= 0 and (G.board[i]["id"] != "" or int(G.board[i]["lock"]) == 2)
	# 选中沙漏或正在制作（能用沙漏加速）的东西时，顶栏第三格换成沙漏
	var sand_ctx := cooking or (has and Data.CHAINS.has(Data.chain(str(G.board[i]["id"]))) and Data.chain(str(G.board[i]["id"])) == "sand")
	if G.main != null and G.main.topbar != null:
		G.main.topbar.set_sand_context(sand_ctx)
	if has and _undo_cell >= 0 and i != _undo_cell:
		_clear_undo()
	var pending := _undo_cell >= 0
	if cooking:
		var ck: Dictionary = G.board[i]["ck"]
		_info_btn.visible = true
		_info_desc.position.x = 170
		_info_desc.size.x = 300
		_info_name.text = "制作 %s" % Data.name_of(str(ck["dish"]))
		_set_desc("还要 %s。沙漏 %d（每份快 %s），做完要 %d 份。" % [Board._sec_text(maxi(G.rules.orders.cook_left(i), 1)), G.rush, Data.rush_text(), G.rules.orders.rush_need(i)])
		if pending:
			_show_undo_btn()
		else:
			_show_rush_btn()
	elif pending and not has:
		_info_btn.visible = true
		_show_undo_btn()
		_info_desc.position.x = 170
		_info_desc.size.x = 300
		_info_name.text = "%s (Lv.%d)" % [Data.name_of(_undo_id), Data.lv(_undo_id)]
		_set_desc(Data.describe(_undo_id))
	elif has:
		var c: Dictionary = G.board[i]
		_info_btn.visible = c["lock"] != 2
		_info_desc.position.x = 170
		_info_desc.size.x = 300
		if G.rules.board.is_merge_bubble(i):
			_info_name.text = "%s (Lv.%d)" % [Data.name_of(str(c["id"])), Data.lv(str(c["id"]))]
			_set_desc("用琥珀买下泡泡里的物品，\n倒计时结束泡泡就会消失。")
		elif c["lock"] == 2:
			_info_name.text = "巨石"
			_set_desc("在旁边合成就能震碎巨石，\n里面的物品会被藤蔓缠住。")
		elif Data.is_dish(c["id"]):
			_info_name.text = Data.name_of(c["id"])
			_set_desc(Data.describe(c["id"]))
			if pending:
				_show_undo_btn()
			else:
				_show_delete_btn(false)
		else:
			_info_name.text = "%s (Lv.%d)" % [Data.name_of(c["id"]), Data.lv(c["id"])]
			_set_item_action(str(c["id"]), int(c["lock"]) == 1)
		if pending:
			_show_undo_btn()
		elif Data.is_dish(c["id"]):
			_show_delete_btn(false)
		else:
			_show_delete_btn(c["lock"] == 0 and not Data.type_of(str(c["id"])) in ["gen", "egen"])
	else:
		_info_btn.visible = false
		_show_delete_btn(false)
		_info_name.text = ""
		_info_desc.position.x = 170
		_info_desc.size.x = 410
		_set_desc("点击物品查看详情，拖动相同物品合成。")
	for d in get_children():
		if d is DrawBox:
			d.queue_redraw()

func _show_rush_btn() -> void:
	_del_lbl.text = "加速"
	_del_btn.style = "orange"
	_del_btn.glyph = ""
	_del_btn.extra = Callable()
	_del_btn.visible = true
	_del_lbl.visible = true
	_del_btn.queue_redraw()

func _show_delete_btn(show: bool) -> void:
	_del_lbl.text = "丢弃"
	_del_btn.style = "red"
	_del_btn.glyph = "trash"
	_del_btn.extra = Callable()
	_del_btn.visible = show
	_del_lbl.visible = show
	_del_btn.queue_redraw()

func _show_undo_btn() -> void:
	_del_lbl.text = "撤销"
	_del_btn.style = "teal"
	_del_btn.glyph = ""
	_del_btn.extra = _paint_undo
	_del_btn.visible = true
	_del_lbl.visible = true
	_del_btn.queue_redraw()

func _paint_undo(ci: CanvasItem, sz: Vector2) -> void:
	var c := Vector2(sz.x * 0.5, sz.y * 0.5 - 3.0)
	var radius := 16.0
	var head := -PI * 0.5
	var tail := head + PI * 1.45
	ci.draw_arc(c, radius, tail, head, 24, Color.WHITE, 4.0, true)
	var dir := Vector2(sin(head), -cos(head))
	var side := Vector2(-dir.y, dir.x)
	var at := c + Vector2(cos(head), sin(head)) * radius
	ci.draw_colored_polygon(PackedVector2Array([at + dir * 8.0, at - dir * 5.0 + side * 6.0, at - dir * 5.0 - side * 6.0]), Color.WHITE)

func _open_info() -> void:
	if board.selected >= 0 and G.rules.orders.cooking(board.selected):
		G.main.open("item_info", str(G.board[board.selected]["ck"]["dish"]))
		return
	if board.selected >= 0 and G.board[board.selected]["id"] != "":
		G.main.open("item_info", G.board[board.selected]["id"])
	elif _undo_id != "":
		G.main.open("item_info", _undo_id)

func _on_delete() -> void:
	if _undo_cell >= 0:
		_on_undo()
		return
	var i := board.selected
	if i >= 0 and G.rules.orders.cooking(i):
		_on_rush(i)
		return
	if i < 0 or G.board[i]["lock"] != 0 or G.rules.board.cell_id(i) == "": return
	var id := G.rules.board.cell_id(i)
	var result: Dictionary = Replay.perform("discard", {"cell": i})
	if result.has("error"):
		G.main.toast(str(result["error"]))
		return
	_undo_cell = i
	_undo_id = id
	board.select(-1)

func _on_rush(i: int) -> void:
	if G.rush < 1:
		G.main.toast("没有沙漏。在棋盘上合成后再领取，一次能领更多。")
		Sfx.play("deny")
		board.shake(i)
		return
	var used := G.rush_cook(i)
	Sfx.play("pop", 1.15)
	if G.rules.orders.cooking(i):
		G.main.toast("用了 %d 份沙漏，还差 %d 份" % [used, G.rules.orders.rush_need(i)])
	else:
		G.main.toast("制作完成")

func _on_undo() -> void:
	var result: Dictionary = Replay.perform("undo")
	if result.has("error"): G.main.toast(str(result["error"]))
	_clear_undo()

func _clear_undo() -> void:
	# Clear local selection first: submitting discard_finish emits a board update.
	_undo_cell = -1
	_undo_id = ""
	if Replay.meta.has("trash"): Replay.perform("discard_finish")
	_del_lbl.text = "丢弃"
	_del_btn.style = "red"
	_del_btn.glyph = "trash"
	_del_btn.extra = Callable()
	_del_btn.queue_redraw()

func _sync_boost() -> void:
	var open := G.rules.board.boost_open()
	_boost_btn.visible = open
	_boost_btn.style = "purple" if G.rules.board.boost_on() else "grey"
	_boost_btn.queue_redraw()

func _on_boost() -> void:
	if not G.rules.board.boost_open():
		G.main.toast("%d级解锁双倍体力" % Data.BOOST_LEVEL)
		return
	G.set_boost(not G.boost)
	if G.boost:
		G.main.toast("双倍体力已开启：生产器每次耗 2 点体力，产物升 1 级")
	else:
		G.main.toast("双倍体力已关闭")

## 开关上画：火苗 + ×2，开着是紫火
func _paint_boost(ci: CanvasItem, sz: Vector2) -> void:
	var on := G.rules.board.boost_on()
	var c := sz * 0.5 + Vector2(0, -6)
	Sprites.at(ci, "board_boost_on" if on else "board_boost_off", c)
	var at := Vector2(0, sz.y - 10)
	ci.draw_string_outline(G.font_title, at, "×2" if on else "×1", HORIZONTAL_ALIGNMENT_CENTER, sz.x, 24, 6, Art.INK)
	ci.draw_string(G.font_title, at, "×2" if on else "×1", HORIZONTAL_ALIGNMENT_CENTER, sz.x, 24, Color.WHITE)

func _on_activate(i: int) -> void:
	if i < 0 or i >= G.board.size() or int(G.board[i]["lock"]) != 0: return
	if _guide_up() and not G.main._guide.allows_activate(i):
		board.shake(i)
		Sfx.play("deny")
		return
	if G.rules.orders.cooking(i): return
	var id := G.rules.board.cell_id(i)
	if Data.type_of(id) == "choice": G.main.open("choice_chest", i); return
	if Data.type_of(id) == "pack": G.main.open("pack", {"id": id, "cell": i}); return
	var result: Dictionary = await Replay.perform("tap", {"cell": i})
	if result.has("error"):
		if Data.type_of(id) in ["gen", "egen"] and G.energy < G.rules.board.gen_cost(): G.main.open("energy", "exhausted")
		else: G.main.toast(str(result["error"]))
	elif result.get("kind", "") == "produce": board.fly_in(i, int(result["to"]), str(result["id"]))
	elif result.get("kind", "") == "chest": _present_chest_drop(i, result)
	elif result.get("kind", "") == "collect":
		RewardPresenter.present([[str(result["id"]), int(result["amount"])]], func(_k): return board.cell_global(i))
		board.burst(i)
		board.select(-1)
		Sfx.play("coin")
	else:
		board.burst(i)
		board.select(-1)

func _present_chest_drop(i: int, result: Dictionary) -> void:
	if result.has("error"):
		G.main.toast(str(result["error"]))
		board.shake(i)
		Sfx.play("deny")
		return
	board.fly_in(i, int(result["to"]), str(result["id"]))
	board.pop(i)
	board.select(i if int(result["remaining"]) > 0 else -1)
	Sfx.play("pop", 1.1)

func _on_drop_outside(i: int, gp: Vector2) -> void:
	if G.rules.orders.cooking(i) or not G.rules.board.is_free(i): return
	if Data.is_dish(G.rules.board.cell_id(i)):
		G.main.toast("做好的食物留在棋盘上，点订单交付")
		Sfx.play("deny")
		return
	if not _pouch.get_global_rect().has_point(gp): return
	var result: Dictionary = Replay.perform("store", {"cell": i})
	if result.has("error"):
		G.main.toast(str(result["error"]))
		Sfx.play("deny")
		return
	_stored(i)

func _stored(i: int) -> void:
	# 棋盘先安排了拖出回位；存入成功后必须清掉，避免空格上继续画旧物品。
	board.cancel_slides(i)
	board.select(-1)
	Sfx.play("pop", 0.8)
	var tw := create_tween()
	_pouch.pivot_offset = _pouch.size * 0.5
	tw.tween_property(_pouch, "scale", Vector2(1.2, 0.85), 0.08)
	tw.tween_property(_pouch, "scale", Vector2.ONE, 0.15)

func _on_stash() -> void:
	if G.stash.is_empty():
		G.main.toast("奖励、购买和放不下的物品会暂存在这里")
		return
	var at := G.rules.board.stash_claim_index()
	if at < 0:
		G.main.toast("卡包已保留，%d级开启" % Data.CARD_LEVEL)
		return
	if Data.type_of(str(G.stash[at])) == "pack": G.main.open("pack", {"id": str(G.stash[at]), "stash": at}); return
	var result: Dictionary = await Replay.perform("stash", {"index": at})
	if result.has("error"): G.main.toast(str(result["error"]))
	elif result.has("to"): _fly_stash_to(str(result["id"]), int(result["to"]), 0.0)

func _stash_top_item_pos() -> Vector2:
	var sz := _stash_wrap.size
	var cr := Rect2(Vector2(16, 44), Vector2(sz.x - 36, 124))
	return _stash_wrap.get_global_transform() * (cr.get_center() + Vector2(0, -4))

## 物品图标飞到棋盘，画在 fx_layer，不走 Board 的 flights
func _fly_stash_to(id: String, to: int, delay: float) -> void:
	board.conceal(to)
	var from := _stash_top_item_pos()
	var dest := board.cell_global(to)
	var icon := DrawBox.new()
	icon.mouse_filter = MOUSE_FILTER_IGNORE
	icon.size = Vector2(90, 90)
	icon.pivot_offset = icon.size * 0.5
	icon.position = from - icon.size * 0.5
	icon.visible = delay <= 0.0
	icon.painter = func(ci, sz): Art.item(ci, id, sz * 0.5, sz.x)
	G.main.fx_layer.add_child(icon)
	var tw := icon.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
		tw.tween_callback(func(): icon.visible = true)
	var step := func(t: float) -> void:
		var e := 1.0 - pow(1.0 - t, 3.0)
		var p := from.lerp(dest, e) + Vector2(0, -80.0 * sin(PI * t))
		var s := lerpf(90.0, 84.0, e)
		icon.size = Vector2(s, s)
		icon.pivot_offset = icon.size * 0.5
		icon.position = p - icon.size * 0.5
	tw.tween_method(step, 0.0, 1.0, 0.28)
	tw.tween_callback(func():
		board.arrive(to)
		icon.queue_free())

func _leftmost_order_wanting(id: String) -> int:
	var best := -1
	var best_gap := 0
	for oi in G.orders.size():
		var items: Array = G.orders[oi]["items"]
		if not items.has(id):
			continue
		var g := _order_missing(oi)
		if best < 0 or g < best_gap or (g == best_gap and oi < best):
			best = oi
			best_gap = g
	return best

func _scroll_order_card(oi: int) -> void:
	var card := _cards[oi]
	var left := _cards_root.position.x + card.position.x
	var right := left + card.size.x
	if left >= _orders.offset + 8.0 and right <= _orders.offset + _orders.size.x - 8.0:
		return
	var dest := clampf(left + card.size.x * 0.5 - _orders.size.x * 0.5, 0.0, _orders._max())
	_orders._vel = 0.0
	if _order_scroll != null and _order_scroll.is_valid():
		_order_scroll.kill()
	_order_scroll = create_tween()
	_order_scroll.tween_property(_orders, "offset", dest, 0.35)

func on_merged(i: int) -> void:
	_build_orders()
	if _guide_up():
		guide_focus_row()
		return
	var oi := _leftmost_order_wanting(G.board[i]["id"])
	if oi >= 0:
		_scroll_order_card(oi)

func guide_focus_row() -> void:
	if _order_scroll != null and _order_scroll.is_valid():
		_order_scroll.kill()
	_orders._vel = 0.0
	_orders.offset = 0.0
	_orders._apply()

func guide_deliver_rect() -> Rect2:
	for oi in _cards.size():
		if oi >= G.orders.size() or not G.rules.orders.order_ready(G.orders[oi]):
			continue
		if _find_round_btn(_cards[oi]) == null:
			continue
		return _cards[oi].get_global_rect()
	return Rect2()

func _find_round_btn(n: Node) -> TButton:
	if n is TButton and (n as TButton).is_round:
		return n
	for c in n.get_children():
		var found := _find_round_btn(c)
		if found != null:
			return found
	return null

func _guide_up() -> bool:
	return G.main != null and G.main._guide != null and G.main._guide.visible

func _guide_spawn(near_i: int) -> int:
	if _guide_up():
		var forced: int = G.main._guide.spawn_cell()
		if forced >= 0:
			return forced
	return G.rules.board.find_empty_near(near_i)

## 选中合成泡泡时，泡泡上方弹出的购买小卡：泡泡里的物品 + 名字等级 + 倒计时 + 琥珀买下
const OFFER_W := 340.0
const OFFER_H := 132.0
func _build_bubble_offer() -> void:
	_bubble_offer = Control.new()
	_bubble_offer.size = Vector2(OFFER_W, OFFER_H + 18)
	_bubble_offer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bubble_offer)
	UI.box(_bubble_offer, Rect2(Vector2.ZERO, _bubble_offer.size), _paint_bubble_offer)
	_bubble_title = UI.lbl(_bubble_offer, "", Rect2(112, 12, OFFER_W - 124, 34), 24, Art.INK, HORIZONTAL_ALIGNMENT_LEFT)
	_bubble_time = UI.lbl(_bubble_offer, "", Rect2(140, 46, OFFER_W - 152, 28), 19, Color("2f6d93"), HORIZONTAL_ALIGNMENT_LEFT)
	_bubble_buy = UI.btn(_bubble_offer, Rect2(112, 76, OFFER_W - 126, 46), "", "green", Callable(), 24)
	_bubble_buy.res = Art.AMBER_ICON
	_bubble_buy.pressed.connect(func():
		var at := board.selected
		_bubble_buy.enabled = false
		var r: Dictionary = await G.buy_bubble(at)
		if not is_instance_valid(self): return
		if r.get("ok", false):
			board.pop(at)
			board.burst(at)
			Sfx.play("pop")
			_on_select(at)
		elif G.main:
			G.main.toast(str(r.get("message", "购买失败")))
		_refresh_bubble_offer())
	_bubble_offer.hide()

func _paint_bubble_offer(ci: CanvasItem, sz: Vector2) -> void:
	var card := Rect2(0, 0, sz.x, OFFER_H)
	var tip_x := 60.0
	if board != null and board.selected >= 0:
		tip_x = clampf(board.cell_center(board.selected).x + BOARD_POS.x - _bubble_offer.position.x, 26, sz.x - 26)
	var tail := Rect2(tip_x - 15, OFFER_H - 4, 30, 20)
	Sprites.draw(ci, "board_offer_under", card)
	Sprites.draw(ci, "board_offer_tail_ink", tail)
	Sprites.draw(ci, "board_offer_top", card)
	Sprites.draw(ci, "board_offer_tail_fill", tail)
	# 左边：泡泡里的物品
	var c := Vector2(58, OFFER_H * 0.5)
	ci.draw_circle(c, 44, Color(0.62, 0.88, 1.0, 0.35))
	var at := board.selected if board != null else -1
	if at >= 0 and at < G.board.size() and str(G.board[at]["id"]) != "":
		Art.item(ci, str(G.board[at]["id"]), c, 70, false)
	ci.draw_arc(c, 44, 0, TAU, 40, Color(Board.BUBBLE_RIM, 0.9), 3.0, true)
	ci.draw_arc(c, 37, PI * 1.08, PI * 1.42, 12, Color(1, 1, 1, 0.92), 5.0, true)
	ci.draw_circle(c + Vector2(-13, -33), 3.2, Color.WHITE)
	Paint.glyph(ci, "clock", Vector2(126, 60), 0.85)

func _refresh_bubble_offer() -> void:
	if _bubble_offer == null: return
	var at := board.selected
	_bubble_offer.visible = G.rules.board.is_merge_bubble(at) and G.rules.board.bubble_left(at) > 0
	if not _bubble_offer.visible: return
	var c: Dictionary = G.board[at]
	var p := BOARD_POS + board.cell_center(at)
	_bubble_offer.position = Vector2(clampf(p.x - OFFER_W * 0.5, 8, 720 - OFFER_W - 8), p.y - 48 - _bubble_offer.size.y)
	_bubble_title.text = "%s (Lv.%d)" % [Data.name_of(str(c["id"])), Data.lv(str(c["id"]))]
	_bubble_tick()
	_bubble_buy.text = "%d  买下" % int(c["bubble"]["price"])
	_bubble_buy.enabled = not G._bubble_busy.has(str(c["bubble"]["uid"]))
	_bubble_buy.queue_redraw()
	for child in _bubble_offer.get_children():
		if child is DrawBox: child.queue_redraw()

## 每帧只在秒数变化时改字
func _bubble_tick() -> void:
	var left := G.rules.board.bubble_left(board.selected)
	var text := "%d 秒后消失" % left
	if _bubble_time.text != text:
		_bubble_time.text = text
		_bubble_time.label_settings.font_color = Art.CLAY if left <= 10 else Color("2f6d93")

## 选中物品的简明操作说明（#11 #12）。图标按产出配置绘制，不逐帧创建控件。
## merge：【物品】+【物品】=【下一级】；produce：点击生产【产物】…；collect：【图标】点击获得 x 个 xx；max：已达最高级。
func _set_item_action(id: String, tangled: bool = false) -> void:
	var kind := Data.type_of(id)
	var production := Data.gen_stats(id)
	var next := Data.next_id(id)
	if kind in ["gen", "egen"] and not production.is_empty() and not tangled:
		var drops: Array = []
		for drop in production["drops"]:
			if not drops.has(str(drop["id"])):
				drops.append(str(drop["id"]))
		_info_action = {"mode": "produce", "items": drops}
	elif kind in ["energy", "shell", "amber", "sand"] and Data.value_of(id) > 0 and not tangled:
		_info_action = {"mode": "collect", "items": [id], "n": Data.value_of(id), "unit": Rewards.unit(id)}
	elif kind in ["item", "gen", "energy", "shell", "amber", "sand"] or tangled:
		if next != "":
			_info_action = {"mode": "merge", "items": [id, id, next]}
		else:
			_info_action = {"mode": "max", "items": [id]}
	elif kind == "choice":
		_set_desc("点击打开，三件物品里挑一件。")
	elif kind == "chest":
		var left: int = G.board[board.selected].get("chest", []).size() if board.selected >= 0 else 0
		var detail := Data.describe(id) if Data.chain(id) in ["orderbox", "premiumbox"] else "每次点击取出一个物品，领完后宝箱消失。"
		_set_desc("剩余%d件。%s" % [left, detail] if left > 0 else detail)
	elif kind == "pack":
		_set_desc("%d级卡包，每包%d张卡片，点击查看星级概率。" % [Data.lv(id), int(CardPacks.config()["cards_per_pack"])] if G.rules.progression.feature_unlocked(Data.CARD_LEVEL) else "%d级解锁收藏卡。" % Data.CARD_LEVEL)
	else:
		_set_desc(Data.describe(id))
	_info_visual.visible = not _info_action.is_empty()
	_info_desc.visible = _info_action.is_empty()
	_info_visual.set_action(_info_action)

## 纯文字说明：按词断行（不会把句号单独挤到下一行），放不下就缩小字号
func _set_desc(text: String) -> void:
	_info_desc.text = text
	# 写死换行的文案按行排，不再自动折行；其余按词折行
	var manual := text.contains("\n")
	_info_desc.autowrap_mode = TextServer.AUTOWRAP_OFF if manual else TextServer.AUTOWRAP_WORD_SMART
	var fs := 22
	var f: Font = G.font_body
	while fs > 16:
		var fits := true
		if manual:
			for line in text.split("\n"):
				fits = fits and f.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= _info_desc.size.x - 4
		else:
			fits = f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, _info_desc.size.x, fs).y <= _info_desc.size.y
		if fits:
			break
		fs -= 1
	_info_desc.label_settings.font_size = fs
