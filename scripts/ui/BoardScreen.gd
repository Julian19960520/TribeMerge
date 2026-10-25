class_name BoardScreen
extends Control

const BOARD_POS := Vector2(24, 432)
## 暂存区、基地和订单在同一个横向滚动列表里
const ROW_RECT := Rect2(0, 140, 720, 236)
const ORDER_X := 272.0
const ORDER_H := 232.0
const STASH_RECT := Rect2(6, 6, 118, 226)
const BASE_RECT := Rect2(126, 6, 142, 226)
const CHIP_ICON := {"xp": "xp_1", "shell": "shell_1", "pack": "pack_1", "token": "token_1"}
const CHIP_ORDER := ["xp", "shell", "pack", "token"]

var board: Board
var _orders: Scroller
var _info_name: Label
var _info_desc: Label
var _info_btn: TButton
var _del_btn: TButton
var _inv_lbl: Label
var _xp_lbl: Label
var _lv_lbl: Label
var _stash_btn: TButton
var _base_btn: TButton
var _pouch: TButton
var _cards: Array[Control] = []
var _cards_root: Control

func stash_pos() -> Vector2:
	return _stash_btn.get_global_rect().get_center()

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

	_stash_btn = UI.hit(_orders.content, STASH_RECT, _on_stash)
	_stash_btn.extra = _paint_stash
	_base_btn = UI.hit(_orders.content, BASE_RECT, func(): G.main.open("level"))
	_base_btn.extra = _paint_base
	_lv_lbl = UI.lbl(_base_btn, "", Rect2(0, 150, BASE_RECT.size.x, 32), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK, true)
	_xp_lbl = UI.lbl(_base_btn, "", Rect2(14, 184, BASE_RECT.size.x - 20, 30), 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 5, Art.INK)
	_cards_root = Control.new()
	_cards_root.mouse_filter = MOUSE_FILTER_IGNORE
	_orders.content.add_child(_cards_root)

	_pouch = UI.hit(self, Rect2(10, 1312, 124, 150), func(): G.main.open("inventory"))
	_pouch.extra = func(ci, sz): Paint.pouch(ci, Vector2(sz.x * 0.5, 58), 1.2)
	_inv_lbl = UI.lbl(self, "", Rect2(10, 1410, 124, 40), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 8, Art.INK, true)

	UI.box(self, Rect2(140, 1300, 456, 170), _paint_info)
	_info_name = UI.lbl(self, "", Rect2(196, 1300, 300, 46), 24, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 7, Art.INK)
	_info_desc = UI.lbl(self, "", Rect2(170, 1352, 300, 96), 21, Color("6b4a2a"), HORIZONTAL_ALIGNMENT_CENTER)
	_info_desc.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_info_btn = UI.hit(self, Rect2(150, 1300, 46, 46), _open_info)
	_info_btn.extra = func(ci, sz): Paint.glyph(ci, "info", sz * 0.5, 1.2)
	_del_btn = UI.btn(self, Rect2(486, 1360, 86, 80), "", "red", _on_delete)
	_del_btn.glyph = "trash"
	UI.lbl(self, "丢弃", Rect2(476, 1326, 106, 34), 20, Art.CLAY, HORIZONTAL_ALIGNMENT_CENTER, 6, Color.WHITE)

	var home := UI.btn(self, Rect2(604, 1330, 106, 110), "", "teal", func(): G.main.show_screen("home"))
	home.extra = func(ci, sz): Paint.home_icon(ci, sz * 0.5 + Vector2(0, -2), 0.85)

	G.changed.connect(_refresh_hud)
	G.orders_changed.connect(_build_orders)
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
	for side in [0, 1]:
		var x0: float = 0.0 if side == 0 else sz.x
		var dir: float = 1.0 if side == 0 else -1.0
		var curtain := PackedVector2Array([Vector2(x0, 0), Vector2(x0 + dir * 90, 0), Vector2(x0 + dir * 60, 180), Vector2(x0 + dir * 30, 380), Vector2(x0, 380)])
		ci.draw_colored_polygon(curtain, Color("c9955a"))
		Art.outline(ci, Art.poly(Array(curtain), side), 3.0)
		Art.dashed(ci, Art.poly([Vector2(x0 + dir * 70, 10), Vector2(x0 + dir * 46, 180), Vector2(x0 + dir * 20, 370)], side + 2, 0.0), 9, 6, Color("f3d7a2"), 2.0)
	var log_r := Rect2(-10, 372, sz.x + 20, 50)
	var lg := Art.rrect(log_r, 22, 33, 1.0)
	Art.dilate(ci, lg, 3.0, Art.INK)
	Art.shade(ci, lg, Art.WOOD, 1)
	for i in 8:
		Art.pl(ci, [Vector2(30 + i * 90, 384), Vector2(70 + i * 90, 388), Vector2(100 + i * 90, 384)], 2.0, Color(0.4, 0.2, 0.05, 0.5), i)

## 暂存区：临时物品像卡片一样叠放，点击把最上面一张放到棋盘
func _paint_stash(ci: CanvasItem, sz: Vector2) -> void:
	var n := G.stash.size()
	var tray := Rect2(6, 26, sz.x - 12, sz.y - 34)
	var tb := Art.rrect(tray, 16, 41, 1.0)
	Art.dilate(ci, tb, 3.0, Art.INK)
	ci.draw_colored_polygon(tb, Color("8a5a32"))
	Art.dashed(ci, Art.rrect(tray.grow(-6), 12, 42, 0.0), 8, 6, Color(1, 0.85, 0.6, 0.45), 2.0)
	var shown := mini(n, 4)
	for j in shown:
		var k := shown - 1 - j
		var id: String = G.stash[n - 1 - k]
		var off := Vector2(float(k) * 5.0, -float(k) * 9.0)
		var rot := (Art.srnd(n - k) - 0.5) * 0.14 if k > 0 else 0.0
		var cr := Rect2(Vector2(16, 44) + off, Vector2(sz.x - 36, 124))
		var card := _rot_about(Art.rrect(cr, 14, 43 + k, 0.6), rot, cr.get_center())
		ci.draw_colored_polygon(_rot_about(Art.rrect(Rect2(cr.position + Vector2(0, 5), cr.size), 14, 43 + k, 0.0), rot, cr.get_center() + Vector2(0, 5)), Color(0, 0, 0, 0.25))
		Art.dilate(ci, card, 2.5, Art.INK)
		ci.draw_colored_polygon(card, Art.BONE if k == 0 else Art.BONE2)
		if k == 0:
			Art.dashed(ci, Art.rrect(cr.grow(-6), 10, 44, 0.0), 7, 5, Color(0.65, 0.4, 0.2, 0.4), 2.0)
			Art.item(ci, id, cr.get_center() + Vector2(0, -4), 90)
	if n == 0:
		ci.draw_string(G.font_body, Vector2(0, 116), "暂存区", HORIZONTAL_ALIGNMENT_CENTER, sz.x, 22, Color(1, 0.9, 0.75, 0.6))
	else:
		Paint.badge_num(ci, Vector2(sz.x - 14, 34))
		var t := str(n)
		ci.draw_string_outline(G.font_body, Vector2(sz.x - 34, 42), t, HORIZONTAL_ALIGNMENT_CENTER, 40, 22, 5, Art.INK)
		ci.draw_string(G.font_body, Vector2(sz.x - 34, 42), t, HORIZONTAL_ALIGNMENT_CENTER, 40, 22, Color.WHITE)
		var bob := 4.0 * sin(Time.get_ticks_msec() / 200.0)
		var arr := Art.poly([Vector2(sz.x * 0.5 - 16, sz.y - 30 + bob), Vector2(sz.x * 0.5 + 16, sz.y - 30 + bob), Vector2(sz.x * 0.5, sz.y - 8 + bob)], 3)
		Art.fill(ci, arr, Art.MOSS, 3.0)

static func _rot_about(pts: PackedVector2Array, a: float, c: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append((p - c).rotated(a) + c)
	return out

## 基地：小屋图标 + 等级进度
func _paint_base(ci: CanvasItem, sz: Vector2) -> void:
	var r := Rect2(4, 26, sz.x - 8, sz.y - 34)
	var b := Art.rrect(r, 16, 45, 1.0)
	Art.dilate(ci, b, 3.0, Art.INK)
	ci.draw_colored_polygon(b, Color("a9dcd3"))
	ci.draw_colored_polygon(Art.ell(Vector2(sz.x * 0.5, 132), Vector2(60, 16), 46, 0.04, 16), Color("8bb39a"))
	Paint.palm(ci, Vector2(sz.x - 22, 132), 80, 7, Color("4a8a4a"))
	Paint.hut_icon(ci, Vector2(sz.x * 0.5 - 6, 100), 1.25)
	Art.outline(ci, b, 2.5, Art.LEATHER_D)
	Paint.bar(ci, Rect2(14, 186, sz.x - 22, 26), float(G.xp) / float(G.xp_need()), Art.MOSS)
	Art.item(ci, "xp_1", Vector2(14, 199), 40)

func _paint_info(ci: CanvasItem, sz: Vector2) -> void:
	var r := Rect2(4, 22, sz.x - 8, sz.y - 34)
	var b := Art.rrect(r, 20, 51, 1.0)
	ci.draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(0, 8), r.size), 20, 51, 0.0), Color(0, 0, 0, 0.3))
	Art.dilate(ci, b, 3.0, Art.INK)
	ci.draw_colored_polygon(b, Art.HIDE)
	Art.dashed(ci, Art.rrect(r.grow(-8), 14, 52, 0.0), 9, 6, Color(0.65, 0.4, 0.2, 0.5), 2.0)
	if board and board.selected >= 0:
		var tag := Art.poly([Vector2(26, 4), Vector2(330, 4), Vector2(312, 24), Vector2(330, 44), Vector2(26, 44)], 53)
		Art.dilate(ci, tag, 3.0, Art.INK)
		ci.draw_colored_polygon(tag, Art.OCHRE)

# ---------------------------------------------------------------- 订单

static func _chips(o: Dictionary) -> Array:
	var out := []
	for k in CHIP_ORDER:
		if o["rw"].has(k) and int(o["rw"][k]) > 0:
			out.append([k, int(o["rw"][k])])
	return out

static func _order_w(o: Dictionary) -> float:
	var n: int = o["items"].size()
	var items_w := 24.0 + n * 78.0 if n > 1 else 160.0
	var chips_w := 20.0 + _chips(o).size() * 62.0
	return maxf(maxf(items_w, chips_w), 160.0)

func _build_orders() -> void:
	for c in _cards_root.get_children():
		c.queue_free()
	_cards.clear()
	var x := ORDER_X
	for oi in G.orders.size():
		var o: Dictionary = G.orders[oi]
		var w := _order_w(o)
		var card := UI.box(_cards_root, Rect2(x, 0, w, ORDER_H), _paint_order.bind(oi))
		_cards.append(card)
		UI.lbl(card, Data.PEOPLE[o["who"]].get_slice(" ", 1), Rect2(80, 4, w - 84, 40), 20, Art.INK, HORIZONTAL_ALIGNMENT_LEFT)
		if G.order_ready(o):
			var b := UI.btn(card, Rect2(w * 0.5 - 70, 176, 140, 50), "交付", "green", _on_deliver.bind(oi), 28)
			b.sound = "coin"
		x += w + 4.0
	_orders.set_length(x + 2.0)
	_refresh_hud()

func _paint_order(ci: CanvasItem, sz: Vector2, oi: int) -> void:
	if oi >= G.orders.size():
		return
	var o: Dictionary = G.orders[oi]
	var story: bool = o["story"]
	var ready := G.order_ready(o)
	var r := Rect2(4, 20, sz.x - 8, sz.y - 24)
	ci.draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(0, 8), r.size), 18, oi, 0.0), Color(0, 0, 0, 0.3))
	var b := Art.rrect(r, 18, 60 + oi, 1.0)
	Art.dilate(ci, b, 3.0, Art.INK)
	var bg := Color("fbf0d6")
	if story:
		bg = Color("ffe9a8")
	if ready:
		bg = Color("eaf6c8")
	ci.draw_colored_polygon(b, bg)
	Art.dashed(ci, Art.rrect(r.grow(-6), 12, 61 + oi, 0.0), 8, 6, Color(0.65, 0.4, 0.2, 0.45), 2.0)
	var head := Art.ell(Vector2(40, 30), Vector2(32, 32), 62 + oi, 0.02, 20)
	Art.dilate(ci, head, 3.0, Art.INK)
	ci.draw_colored_polygon(head, Art.OCHRE.lightened(0.3) if story else Art.TEAL.lightened(0.3))
	Paint.portrait(ci, o["who"], Vector2(40, 28), 52)
	if story:
		Art.item(ci, "xp_1", Vector2(66, 50), 34)
	var items: Array = o["items"]
	var used := []
	for k in items.size():
		var id: String = items[k]
		var c := Vector2(sz.x * 0.5, 98) if items.size() == 1 else Vector2(sz.x * 0.5 + (float(k) - (items.size() - 1) * 0.5) * 78.0, 98)
		var s := 80.0 if items.size() == 1 else 68.0
		ci.draw_colored_polygon(Art.ell(c + Vector2(0, 4), Vector2(s * 0.5, s * 0.42), 63 + k, 0.03, 18), Color(0.8, 0.65, 0.4, 0.35))
		Art.item(ci, id, c, s)
		var cell := G.board_has(id, used)
		if cell >= 0:
			used.append(cell)
			Paint.check_mark(ci, c + Vector2(s * 0.36, s * 0.3), 0.9)
	var chips := _chips(o)
	var cx0 := sz.x * 0.5 - (chips.size() - 1) * 31.0
	for k in chips.size():
		var c := Vector2(cx0 + k * 62.0, 154)
		var pill := Art.rrect(Rect2(c - Vector2(28, 14), Vector2(56, 28)), 14, 65 + k, 0.4)
		ci.draw_colored_polygon(pill, Color(0.55, 0.35, 0.15, 0.18))
		Art.item(ci, CHIP_ICON[chips[k][0]], c + Vector2(-16, 0), 36, false)
		var t := str(chips[k][1])
		ci.draw_string_outline(G.font_body, c + Vector2(-2, 8), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 5, Color.WHITE)
		ci.draw_string(G.font_body, c + Vector2(-2, 8), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Art.INK)
	if not ready:
		ci.draw_string(G.font_body, Vector2(0, 206), "%d/%d" % [used.size(), items.size()], HORIZONTAL_ALIGNMENT_CENTER, sz.x, 22, Color(0.45, 0.3, 0.15))

func _on_deliver(oi: int) -> void:
	if oi >= G.orders.size() or oi >= _cards.size():
		return
	var o: Dictionary = G.orders[oi]
	var cells := G.order_cells(o)
	if cells.is_empty():
		return
	var card_pos := _cards[oi].get_global_rect().get_center()
	for k in cells.size():
		var from := board.cell_global(cells[k])
		G.main.fly(o["items"][k], from, card_pos, Callable(), 70)
	var rw: Dictionary = o["rw"]
	G.complete_order(oi)
	board.select(-1)
	Sfx.play("coin")
	await get_tree().create_timer(0.35).timeout
	G.main.toast("%s：谢谢你！" % Data.PEOPLE[o["who"]].get_slice(" ", 1))
	var stash_c := _stash_btn.get_global_rect().get_center()
	if rw.has("shell"):
		var n: int = rw["shell"]
		G.main.fly("shell_1", card_pos, G.main.topbar.target("shell"), func(): G.add_currency("shell", n), 60)
	if rw.has("pack"):
		var n: int = rw["pack"]
		var give_pack := func():
			for j in n:
				G.stash_push("pack_1")
		G.main.fly("pack_1", card_pos, stash_c, give_pack, 70)
	if rw.has("token"):
		var n: int = rw["token"]
		var give_token := func():
			if G.add_tokens(n) > 0:
				G.main.toast("祭典鼓攒满了，兽皮卡包已放入暂存区！")
		G.main.fly("token_1", card_pos, stash_c, give_token, 60)
	if rw.has("xp"):
		var n: int = rw["xp"]
		G.main.fly("xp_1", card_pos, _base_btn.get_global_rect().get_center() + Vector2(0, 50), _give_xp.bind(n), 60)

func _give_xp(n: int) -> void:
	if G.add_xp(n):
		await get_tree().create_timer(0.4).timeout
		G.main.open("levelup")

# ---------------------------------------------------------------- 交互

func _on_board_changed() -> void:
	_build_orders()
	_refresh_hud()

func _refresh_hud() -> void:
	_inv_lbl.text = "%d/%d" % [G.inv.size(), G.inv_cap]
	_lv_lbl.text = "部落 Lv.%d" % G.level
	_xp_lbl.text = "%d/%d" % [G.xp, G.xp_need()]
	_stash_btn.queue_redraw()
	_base_btn.queue_redraw()
	queue_redraw()
	for c in get_children():
		if c is DrawBox:
			c.queue_redraw()
	for c in _cards:
		c.queue_redraw()

func _on_select(i: int) -> void:
	var has: bool = i >= 0 and G.board[i]["id"] != ""
	_info_btn.visible = has and G.board[i]["lock"] != 2
	_del_btn.visible = has and G.board[i]["lock"] == 0
	for c in get_children():
		if c is Label and c.text == "丢弃":
			c.visible = _del_btn.visible
	if not has:
		_info_name.text = ""
		_info_desc.text = "点击物品查看详情，拖动相同物品合成。"
		_info_desc.position.x = 170
		_info_desc.size.x = 410
	else:
		var c: Dictionary = G.board[i]
		_info_desc.position.x = 170
		_info_desc.size.x = 300
		if c["lock"] == 2:
			_info_name.text = "巨石"
			_info_desc.text = "巨石挡路，在旁边合成物品就能撬开。"
		else:
			_info_name.text = "%s (Lv.%d)" % [Data.name_of(c["id"]), Data.lv(c["id"])]
			if c["lock"] == 1:
				_info_desc.text = "被藤蔓缠住了，拖一个相同的物品过来合成即可解开。"
			else:
				_info_desc.text = Data.describe(c["id"])
	for d in get_children():
		if d is DrawBox:
			d.queue_redraw()

func _open_info() -> void:
	if board.selected >= 0 and G.board[board.selected]["id"] != "":
		G.main.open("item_info", G.board[board.selected]["id"])

func _on_delete() -> void:
	var i := board.selected
	if i < 0 or G.board[i]["lock"] != 0 or G.board[i]["id"] == "":
		return
	G.board[i]["id"] = ""
	G.dirty()
	G.board_changed.emit()
	board.select(-1)
	Sfx.play("whoosh")

func _on_activate(i: int) -> void:
	var id: String = G.board[i]["id"]
	match Data.type_of(id):
		"gen":
			if G.energy <= 0:
				G.main.open("energy")
				return
			var to := G.find_empty_near(i)
			if to < 0:
				G.main.toast("棋盘满了，先合成或收起一些物品吧！")
				Sfx.play("deny")
				return
			G.spend("energy", 1)
			var out := G.roll_produce(id)
			var fresh := G.discover(out)
			G.board[to]["id"] = out
			G.dirty()
			board.fly_in(i, to, out)
			Sfx.play("pop", 1.0 + randf() * 0.2)
			G.board_changed.emit()
			if fresh:
				G.main.toast("新发现：%s！" % Data.name_of(out))
		"energy", "shell", "amber":
			var kind := Data.type_of(id)
			var v := Data.value_of(id)
			G.board[i]["id"] = ""
			G.dirty()
			G.board_changed.emit()
			board.select(-1)
			Sfx.play("coin")
			G.main.fly(id, board.cell_global(i), G.main.topbar.target(kind), func(): G.add_currency(kind, v), 70)
		"chest":
			var items := G.roll_chest()
			G.board[i]["id"] = ""
			var extra := 0
			for it in items:
				G.discover(it)
				var to := G.find_empty_near(i)
				if to < 0:
					G.stash.append(it)
					extra += 1
					continue
				G.board[to]["id"] = it
				board.fly_in(i, to, it)
			if extra > 0:
				G.main.toast("放不下的 %d 个物品进了暂存区" % extra)
				G.changed.emit()
			board.burst(i)
			board.select(-1)
			Sfx.play("merge", 1.2)
			G.dirty()
			G.board_changed.emit()
		"pack":
			G.board[i]["id"] = ""
			G.dirty()
			G.board_changed.emit()
			board.select(-1)
			G.main.open("pack")
		_:
			board.shake(i)

func _on_drop_outside(i: int, gp: Vector2) -> void:
	if _pouch.get_global_rect().has_point(gp):
		if G.inv.size() >= G.inv_cap:
			G.main.toast("储物洞已满！")
			Sfx.play("deny")
			return
		G.inv.append(G.board[i]["id"])
		G.board[i]["id"] = ""
		board.cancel_slides(i)
		G.dirty()
		G.board_changed.emit()
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
	var to := G.find_empty_near(G.idx(0, 0))
	if to < 0:
		G.main.toast("棋盘满了！")
		Sfx.play("deny")
		return
	var id: String = G.stash.pop_back()
	G.board[to]["id"] = id
	G.discover(id)
	G.dirty()
	board.fly_in_from(_stash_btn.get_global_rect().get_center(), to, id)
	Sfx.play("pop")
	G.board_changed.emit()
	G.changed.emit()

func on_merged(_i: int) -> void:
	_build_orders()
