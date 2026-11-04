class_name BoardScreen
extends Control

const BOARD_POS := Vector2(24, 432)
## 暂存区、基地和订单在同一个横向滚动列表里
const ROW_RECT := Rect2(0, 140, 720, 304)
const ORDER_X := 272.0
const ORDER_H := 232.0
const ORDER_H_SHORT := 216.0
const STASH_RECT := Rect2(6, 38, 118, 226)
const BASE_RECT := Rect2(126, 38, 142, 226)
const HAMMER_W := 130.0
const ROW_GAP := 4.0
const CHIP_ICON := {"shell": "shell_2", "pack": "pack_1", "token": "token_1"}

var board: Board
var _orders: Scroller
var _info_name: Label
var _info_desc: Label
var _info_btn: TButton
var _del_btn: TButton
var _del_lbl: Label
var _undo_cell := -1
var _undo_id := ""
var _undo_pay := 0
var _inv_lbl: Label
var _xp_lbl: Label
var _lv_lbl: Label
var _stash_btn: TButton
var _stash_wrap: Control
var _stash_open := false
var _hammer_on := false
var _row_tween: Tween
var _base_btn: TButton
var _hammer_btn: TButton
var _pouch: TButton
var _cards: Array[Control] = []
var _cards_root: Control
## 订单在 _cards_root 内的右缘（含原来的 2px），滚动长度再叠上根节点目标 x
var _cards_right := ORDER_X + 2.0
var _order_scroll: Tween
## 上一帧已经可交付的订单，键是 who、items、story，不用下标
var _ready_order_keys := {}

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
	_cards_root = Control.new()
	_cards_root.mouse_filter = MOUSE_FILTER_IGNORE
	_orders.content.add_child(_cards_root)
	_apply_row(false)

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
	_del_lbl = UI.lbl(self, "丢弃", Rect2(476, 1326, 106, 34), 20, Art.CLAY, HORIZONTAL_ALIGNMENT_CENTER, 6, Color.WHITE)

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

## 主角阿焰的等级卡
func _paint_hero(ci: CanvasItem, sz: Vector2) -> void:
	var r := Rect2(4, 16, sz.x - 8, sz.y - 24)
	ci.draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(0, 8), r.size), 18, 45, 0.0), Color(0, 0, 0, 0.3))
	var b := Art.rrect(r, 18, 45, 1.0)
	Art.dilate(ci, b, 3.0, Art.INK)
	ci.draw_colored_polygon(b, Color("fbf0d6"))
	Art.dashed(ci, Art.rrect(r.grow(-6), 12, 46, 0.0), 8, 6, Color(0.65, 0.4, 0.2, 0.45), 2.0)
	var head_c := Vector2(sz.x * 0.5, 78)
	var head := Art.ell(head_c, Vector2(44, 44), 47, 0.02, 20)
	Art.dilate(ci, head, 3.0, Art.INK)
	ci.draw_colored_polygon(head, Art.OCHRE.lightened(0.28))
	ci.draw_colored_polygon(Art.ell(Vector2(sz.x * 0.5, 118), Vector2(42, 12), 46, 0.04, 16), Color("c9a56a"))
	Paint.bust(ci, Vector2(sz.x * 0.5, 96), 54)
	Paint.bar(ci, Rect2(12, 176, sz.x - 24, 24), float(G.xp) / float(G.xp_need()), Art.MOSS)
	Art.item(ci, "xp_1", Vector2(16, 188), 36)

## 贝币够建下一段部落时出现，点了回村庄升级
func _paint_hammer(ci: CanvasItem, sz: Vector2) -> void:
	var r := Rect2(4, 16, sz.x - 8, sz.y - 24)
	ci.draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(0, 8), r.size), 18, 48, 0.0), Color(0, 0, 0, 0.3))
	var b := Art.rrect(r, 18, 48, 1.0)
	Art.dilate(ci, b, 3.0, Art.INK)
	ci.draw_colored_polygon(b, Color("ffe9a8"))
	Art.dashed(ci, Art.rrect(r.grow(-6), 12, 49, 0.0), 8, 6, Color(0.65, 0.4, 0.2, 0.45), 2.0)
	var title := "升级"
	var tfs := 22
	var tw := G.font_title.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x
	var tp := Vector2((sz.x - tw) * 0.5, 46)
	ci.draw_string_outline(G.font_title, tp, title, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, 5, Art.INK)
	ci.draw_string(G.font_title, tp, title, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, Color("fff1c4"))
	Paint.hammer(ci, Vector2(sz.x * 0.5, 112), 1.35)
	var id := G.next_build_id()
	var cost := G.build_cost(id) if id != "" else 0
	Art.item(ci, "shell_2", Vector2(sz.x * 0.5 - 34, 186), 40)
	var text := str(cost)
	var fs := 22
	var pos := Vector2(sz.x * 0.5 - 6, 186 + (G.font_body.get_ascent(fs) - G.font_body.get_descent(fs)) * 0.5)
	ci.draw_string_outline(G.font_body, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Art.INK)
	ci.draw_string(G.font_body, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)

func _paint_info(ci: CanvasItem, sz: Vector2) -> void:
	var r := Rect2(4, 22, sz.x - 8, sz.y - 34)
	var b := Art.rrect(r, 20, 51, 1.0)
	ci.draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(0, 8), r.size), 20, 51, 0.0), Color(0, 0, 0, 0.3))
	Art.dilate(ci, b, 3.0, Art.INK)
	ci.draw_colored_polygon(b, Art.HIDE)
	Art.dashed(ci, Art.rrect(r.grow(-8), 14, 52, 0.0), 9, 6, Color(0.65, 0.4, 0.2, 0.5), 2.0)
	if board and (board.selected >= 0 or _undo_cell >= 0):
		var tag := Art.poly([Vector2(26, 4), Vector2(330, 4), Vector2(312, 24), Vector2(330, 44), Vector2(26, 44)], 53)
		Art.dilate(ci, tag, 3.0, Art.INK)
		ci.draw_colored_polygon(tag, Art.OCHRE)

# ---------------------------------------------------------------- 订单

static func _chips(o: Dictionary) -> Array:
	var out := []
	var rw: Dictionary = o["rw"]
	if rw.has("shell") and int(rw["shell"]) > 0:
		out.append([CHIP_ICON["shell"], int(rw["shell"])])
	var seen := {}
	var order: Array = []
	var rewards: Array = rw.get("rewards", [])
	if rewards.is_empty() and rw.has("pack") and int(rw["pack"]) > 0:
		rewards = []
		for _i in int(rw["pack"]):
			rewards.append("pack_1")
	for id in rewards:
		var s := str(id)
		if s == "":
			continue
		if not seen.has(s):
			seen[s] = 0
			order.append(s)
		seen[s] = int(seen[s]) + 1
	for s in order:
		out.append([s, int(seen[s])])
	if rw.has("token") and int(rw["token"]) > 0:
		out.append([CHIP_ICON["token"], int(rw["token"])])
	return out

## 图标占左侧，胶囊右端贴着数字。一位数比原来的 56 窄，位数多了再变宽。
static func _chip_text_w(t: String) -> float:
	if G.font_body == null:
		return 12.0 * float(t.length())
	return G.font_body.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x

static func _chip_w(count: int) -> float:
	return 38.0 + _chip_text_w(str(count))

static func _chips_span(chips: Array) -> float:
	if chips.is_empty():
		return 0.0
	var total := 0.0
	for k in chips.size():
		total += _chip_w(int(chips[k][1]))
	total += 6.0 * float(chips.size() - 1)
	return total

static func _order_w(o: Dictionary) -> float:
	var chips_w := 20.0 + _chips_span(_chips(o))
	if str(o.get("kind", "")) == "craft":
		var mats_n: int = o.get("mats", []).size()
		var icon: float = 48.0 if mats_n >= 4 else 58.0
		var step: float = icon * 0.9
		var span: float = float(mats_n) * step + float(maxi(mats_n - 1, 0)) * 8.0
		return maxf(maxf(span + 40.0, chips_w), 200.0)
	var n: int = o["items"].size()
	var items_w := 24.0 + n * 78.0 if n > 1 else 160.0
	return maxf(maxf(items_w, chips_w), 160.0)

func _order_missing(oi: int) -> int:
	var o: Dictionary = G.orders[oi]
	if str(o.get("kind", "")) == "craft" and str(o.get("phase", "need")) != "need":
		return 0
	var items: Array = o["mats"] if str(o.get("kind", "")) == "craft" else o["items"]
	var used := []
	var matched := 0
	for k in items.size():
		var id: String = items[k]
		var cell := G.board_has(id, used)
		if cell >= 0:
			used.append(cell)
			matched += 1
	return items.size() - matched

func _order_key(o: Dictionary) -> String:
	if str(o.get("kind", "")) == "craft":
		var go := "1" if G.craft_mats_ready(o) else "0"
		return "craft|%s|%s|%s" % [str(o.get("uid", "")), str(o.get("phase", "need")), go]
	var ids: PackedStringArray = []
	for id in o["items"]:
		ids.append(str(id))
	return "%s|%s|%s" % [str(o["who"]), "|".join(ids), "1" if o["story"] else "0"]

func _breath_check(host: Control) -> void:
	var tw := host.create_tween()
	tw.tween_property(host, "scale", Vector2(1.08, 1.08), 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(host, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.set_loops()

func _build_orders() -> void:
	for c in _cards_root.get_children():
		c.queue_free()
	var order: Array[int] = []
	var gap: Array[int] = []
	for oi in G.orders.size():
		order.append(oi)
		gap.append(_order_missing(oi))
	order.sort_custom(func(a: int, b: int) -> bool:
		var sa := gap[a] == 0
		var sb := gap[b] == 0
		if sa != sb:
			return sa
		var xa: bool = G.orders[a]["rw"].has("xp") and int(G.orders[a]["rw"]["xp"]) > 0
		var xb: bool = G.orders[b]["rw"].has("xp") and int(G.orders[b]["rw"]["xp"]) > 0
		if xa != xb:
			return xa
		if gap[a] == gap[b]:
			return a < b
		return gap[a] < gap[b]
	)
	_cards.resize(G.orders.size())
	var now_ready := {}
	var x := ORDER_X
	for oi in order:
		var o: Dictionary = G.orders[oi]
		var w := _order_w(o)
		var ready := G.order_ready(o)
		var can_make := G.craft_mats_ready(o)
		var h := ORDER_H_SHORT
		var card := UI.box(_cards_root, Rect2(x, 44, w, h), _paint_order.bind(oi))
		_cards[oi] = card
		var name_w := w - 84.0
		if str(o.get("kind", "")) == "craft":
			name_w = w - 156.0
		elif o["rw"].has("xp") and int(o["rw"]["xp"]) > 0:
			name_w = w - 132.0
		UI.lbl(card, Data.PEOPLE[o["who"]].get_slice(" ", 1), Rect2(80, 30, name_w, 32), 20, Art.INK, HORIZONTAL_ALIGNMENT_LEFT)
		var spots: Array = _formula_spots(o, w) if str(o.get("kind", "")) == "craft" else _order_item_spots(o, w)
		for spot in spots:
			var mid := str(spot["id"])
			var c: Vector2 = spot["c"]
			var s: float = float(spot["s"])
			UI.hit(card, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), _open_mat.bind(mid))
		if can_make or ready:
			var key := _order_key(o)
			var fresh := not _ready_order_keys.has(key)
			now_ready[key] = true
			var host := Control.new()
			host.mouse_filter = MOUSE_FILTER_IGNORE
			if can_make:
				host.size = Vector2(112, 52)
				host.position = Vector2(w * 0.5 - 56, h - 48)
			else:
				host.size = Vector2(72, 72)
				host.position = Vector2(w * 0.5 - 36, (h - 4) - 36)
			host.pivot_offset = host.size * 0.5
			card.add_child(host)
			if can_make:
				var make := UI.btn(host, Rect2(Vector2.ZERO, host.size), "制作", "orange", _on_craft.bind(oi), 28)
				make.sound = "pop"
			else:
				var b := UI.btn(host, Rect2(Vector2.ZERO, host.size), "", "green", _on_deliver.bind(oi))
				b.is_round = true
				b.sound = "coin"
				b.extra = func(ci: CanvasItem, sz: Vector2) -> void:
					var c := sz * 0.5
					var pts := PackedVector2Array([c + Vector2(-16, 1), c + Vector2(-4, 14), c + Vector2(18, -12)])
					ci.draw_polyline(pts, Color.WHITE, 6.0, true)
					for p in pts:
						ci.draw_circle(p, 3.0, Color.WHITE)
			if fresh:
				host.scale = Vector2.ZERO
				var tw := host.create_tween()
				tw.tween_property(host, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw.tween_callback(_breath_check.bind(host))
			else:
				host.scale = Vector2.ONE
				_breath_check(host)
		x += w + 4.0
	_ready_order_keys = now_ready
	_cards_right = x + 2.0
	_orders.set_length(_cards_right + _cards_x())
	_refresh_hud()

func _paint_order(ci: CanvasItem, sz: Vector2, oi: int) -> void:
	if oi >= G.orders.size():
		return
	var o: Dictionary = G.orders[oi]
	var story: bool = o["story"]
	var craft := str(o.get("kind", "")) == "craft"
	var phase := str(o.get("phase", "need"))
	var ready := G.order_ready(o)
	var r := Rect2(4, 20, sz.x - 8, sz.y - 24)
	ci.draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(0, 8), r.size), 18, oi, 0.0), Color(0, 0, 0, 0.3))
	var b := Art.rrect(r, 18, 60 + oi, 1.0)
	Art.dilate(ci, b, 3.0, Art.INK)
	var bg := Color("fbf0d6")
	if story:
		bg = Color("ffe9a8")
	if craft and phase == "cook":
		bg = Color("ffe4c4")
	elif craft and G.craft_mats_ready(o):
		bg = Color("fff3c4")
	if ready:
		bg = Color("eaf6c8")
	ci.draw_colored_polygon(b, bg)
	Art.dashed(ci, Art.rrect(r.grow(-6), 12, 61 + oi, 0.0), 8, 6, Color(0.65, 0.4, 0.2, 0.45), 2.0)
	var head := Art.ell(Vector2(40, 30), Vector2(32, 32), 62 + oi, 0.02, 20)
	Art.dilate(ci, head, 3.0, Art.INK)
	ci.draw_colored_polygon(head, Art.OCHRE.lightened(0.3) if story else Art.TEAL.lightened(0.3))
	Paint.portrait(ci, o["who"], Vector2(40, 28), 52)
	if o["rw"].has("xp") and int(o["rw"]["xp"]) > 0:
		var star := Vector2(sz.x - 20, 36)
		Art.item(ci, "xp_1", star, 52)
		var xp_n := str(int(o["rw"]["xp"]))
		var xp_fs := 22
		var xp_base := star.y + (G.font_body.get_ascent(xp_fs) - G.font_body.get_descent(xp_fs)) * 0.5
		var xp_pos := Vector2(star.x - 26, xp_base)
		ci.draw_string_outline(G.font_body, xp_pos, xp_n, HORIZONTAL_ALIGNMENT_CENTER, 52, xp_fs, 4, Art.INK)
		ci.draw_string(G.font_body, xp_pos, xp_n, HORIZONTAL_ALIGNMENT_CENTER, 52, xp_fs, Color.WHITE)
	if craft:
		var dish_s := 58.0
		var dc := Vector2(sz.x - 42.0, 50.0)
		var from := _paint_formula(ci, o, sz.x)
		ci.draw_colored_polygon(Art.ell(dc + Vector2(0, 3), Vector2(dish_s * 0.5, dish_s * 0.42), 63, 0.03, 18), Color(0.8, 0.65, 0.4, 0.35))
		Art.item(ci, str(o.get("dish", "")), dc, dish_s)
		if from.x >= 0.0:
			var dir := Vector2(1, -1).normalized()
			var tip := dc - dir * (dish_s * 0.5)
			var length := clampf((tip - from).length() * 0.55, 32.0, 48.0)
			_aim_arrow(ci, tip - dir * length, tip)
		if phase == "ready":
			Paint.check_mark(ci, dc + Vector2(dish_s * 0.32, dish_s * 0.26), 0.7)
		elif phase == "cook":
			_sign(ci, "制作中", dc + Vector2(0, 36), 14)
	else:
		var spots: Array = _order_item_spots(o, sz.x)
		var used := []
		for ik in spots.size():
			var spot: Dictionary = spots[ik]
			var id := str(spot["id"])
			var c: Vector2 = spot["c"]
			var s: float = float(spot["s"])
			ci.draw_colored_polygon(Art.ell(c + Vector2(0, 4), Vector2(s * 0.5, s * 0.42), 63 + ik, 0.03, 18), Color(0.8, 0.65, 0.4, 0.35))
			Art.item(ci, id, c, s)
			var cell := G.board_has(id, used)
			if cell >= 0:
				used.append(cell)
				Paint.check_mark(ci, c + Vector2(s * 0.36, s * 0.3), 0.9)
	var chips := _chips(o)
	var chip_y := 170.0
	var x := sz.x * 0.5 - _chips_span(chips) * 0.5
	for k in chips.size():
		var t := str(chips[k][1])
		var pill_w := _chip_w(int(chips[k][1]))
		var pill := Art.rrect(Rect2(x, chip_y - 14.0, pill_w, 28.0), 14, 65 + k, 0.4)
		ci.draw_colored_polygon(pill, Color(0.55, 0.35, 0.15, 0.18))
		Art.item(ci, str(chips[k][0]), Vector2(x + 12.0, chip_y), 36, false)
		var pos := Vector2(x + 26.0, chip_y + 8.0)
		ci.draw_string_outline(G.font_body, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 5, Color.WHITE)
		ci.draw_string(G.font_body, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Art.INK)
		x += pill_w + 6.0

func _paint_formula(ci: CanvasItem, o: Dictionary, width: float) -> Vector2:
	var spots: Array = _formula_spots(o, width)
	if spots.is_empty():
		return Vector2(-1, -1)
	var used := []
	var phase := str(o.get("phase", "need"))
	for k in spots.size():
		var spot: Dictionary = spots[k]
		var id := str(spot["id"])
		var c: Vector2 = spot["c"]
		var icon: float = float(spot["s"])
		ci.draw_colored_polygon(Art.ell(c + Vector2(0, 4), Vector2(icon * 0.5, icon * 0.42), 63 + k, 0.03, 18), Color(0.8, 0.65, 0.4, 0.35))
		Art.item(ci, id, c, icon)
		if phase == "need":
			var cell := G.board_has(id, used)
			if cell >= 0:
				used.append(cell)
				Paint.check_mark(ci, c + Vector2(icon * 0.34, icon * 0.28), 0.52)
		if k < spots.size() - 1:
			var nxt: Vector2 = spots[k + 1]["c"]
			_sign(ci, "+", Vector2((c.x + nxt.x) * 0.5, c.y), 18)
	var first: Vector2 = spots[0]["c"]
	var last: Vector2 = spots[spots.size() - 1]["c"]
	var icon0: float = float(spots[0]["s"])
	return Vector2((first.x + last.x) * 0.5, first.y - icon0 * 0.62)

static func _order_item_spots(o: Dictionary, width: float) -> Array:
	var items: Array = o.get("items", [])
	var n := items.size()
	var out: Array = []
	if n == 0:
		return out
	var s: float = 80.0 if n == 1 else 68.0
	for ik in n:
		var x: float = width * 0.5 if n == 1 else width * 0.5 + (float(ik) - float(n - 1) * 0.5) * 78.0
		out.append({"id": str(items[ik]), "c": Vector2(x, 116.0), "s": s})
	return out

static func _formula_spots(o: Dictionary, width: float) -> Array:
	var mats: Array = o.get("mats", [])
	var n := mats.size()
	var out: Array = []
	if n == 0:
		return out
	var icon: float = 48.0 if n >= 4 else 58.0
	var step: float = icon * 0.9
	var plus_w := 8.0
	var span: float = float(n) * step + float(maxi(n - 1, 0)) * plus_w
	var left: float = (width - span) * 0.5
	var y := 116.0
	for k in n:
		out.append({"id": str(mats[k]), "c": Vector2(left + step * 0.5, y), "s": icon})
		left += step
		if k < n - 1:
			left += plus_w
	return out

func _open_mat(id: String) -> void:
	G.main.open("item_info", id)

static func _aim_arrow(ci: CanvasItem, a: Vector2, tip: Vector2) -> void:
	var dir := (tip - a).normalized()
	var n := dir.orthogonal()
	var neck := tip - dir * 8.0
	Art.pl(ci, [a, neck], 6.0, Color.WHITE, 4)
	Art.pl(ci, [a, neck], 3.2, Art.INK, 4)
	var head := Art.poly([tip, neck + n * 5.5, neck - n * 5.5], 6, 0.15)
	Art.fill(ci, head, Art.INK, 2.0)

static func _sign(ci: CanvasItem, text: String, c: Vector2, fs: int) -> void:
	var f := G.font_body
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var baseline := c.y + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5
	var pos := Vector2(c.x - w * 0.5, baseline)
	ci.draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color.WHITE)
	ci.draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Art.INK)

func _on_craft(oi: int) -> void:
	if oi >= G.orders.size():
		return
	var flights: Array = G.begin_craft(oi)
	if flights.is_empty():
		return
	board.play_gather(flights)
	board.select(int(flights[0]["to"]))
	Sfx.play("whoosh", 0.9)

func _on_deliver(oi: int) -> void:
	if oi >= G.orders.size() or oi >= _cards.size():
		return
	var o: Dictionary = G.orders[oi]
	var cells := G.order_cells(o)
	if cells.is_empty():
		return
	var card_pos := _cards[oi].get_global_rect().get_center()
	var rw: Dictionary = (o["rw"] as Dictionary).duplicate(true)
	var who := int(o["who"])
	G.complete_order(oi)
	board.select(-1)
	Sfx.play("coin")
	await get_tree().create_timer(0.35).timeout
	G.main.toast("%s：谢谢你！" % Data.PEOPLE[who].get_slice(" ", 1))
	var stash_c := stash_pos()
	if rw.has("shell"):
		var shell_n: int = rw["shell"]
		G.main.fly("shell_2", card_pos, G.main.topbar.target("shell"), func(): G.add_currency("shell", shell_n), 60)
	if rw.has("rewards") and rw["rewards"] is Array and not (rw["rewards"] as Array).is_empty():
		var ids: Array = rw["rewards"]
		var give_rewards := func():
			for id in ids:
				if str(id) != "":
					G.stash_push(str(id))
		G.main.fly(str(ids[0]), card_pos, stash_c, give_rewards, 70)
	elif int(rw.get("pack", 0)) > 0:
		var pack_n: int = rw["pack"]
		var give_pack := func():
			for _j in pack_n:
				G.stash_push("pack_1")
		G.main.fly("pack_1", card_pos, stash_c, give_pack, 70)
	if rw.has("token"):
		var token_n: int = rw["token"]
		var give_token := func():
			var packs := G.add_tokens(token_n)
			if packs <= 0:
				return
			for _j in packs:
				G.stash.append("pack_1")
			G.dirty()
			G.changed.emit()
			G.main.toast("祭典鼓攒满了，兽皮卡包已放入暂存区！")
		G.main.fly("token_1", card_pos, stash_c, give_token, 60)
	if rw.has("xp"):
		var xp_n: int = rw["xp"]
		G.main.fly("xp_1", card_pos, _base_btn.get_global_rect().get_center() + Vector2(0, 50), _give_xp.bind(xp_n), 60)

func _give_xp(n: int) -> void:
	if G.add_xp(n):
		await get_tree().create_timer(0.4).timeout
		G.main.open("levelup")

# ---------------------------------------------------------------- 交互

func _process(_delta: float) -> void:
	if board == null:
		return
	var i := board.selected
	if i < 0 or not G.cooking(i):
		return
	var text := "还要 %s。沙漏 %d，每份快 10 秒。" % [Board._sec_text(maxi(G.cook_left(i), 1)), G.rush]
	if _info_desc.text != text:
		_info_desc.text = text

func _on_board_changed() -> void:
	_build_orders()
	_refresh_hud()
	if board != null and board.selected >= 0:
		var id := str(G.board[board.selected]["id"])
		if G.cooking(board.selected) or Data.is_dish(id):
			_on_select(board.selected)

func _tribe_ready() -> bool:
	var id := G.next_build_id()
	return id != "" and G.shells >= G.build_cost(id)

func _cards_x() -> float:
	var x := 0.0 if not G.stash.is_empty() else -(BASE_RECT.position.x - STASH_RECT.position.x)
	if _tribe_ready():
		x += HAMMER_W + ROW_GAP
	return x

func _sync_row() -> void:
	var open := not G.stash.is_empty()
	if open == _stash_open and _tribe_ready() == _hammer_on:
		return
	_apply_row(true)

func _apply_row(animate: bool) -> void:
	if _row_tween != null and _row_tween.is_valid():
		_row_tween.kill()
	var open := not G.stash.is_empty()
	var hammer := _tribe_ready()
	var base_x := BASE_RECT.position.x if open else STASH_RECT.position.x
	var hammer_x := base_x + BASE_RECT.size.x + ROW_GAP
	var cards_x := _cards_x()
	var stash_was := _stash_open
	var hammer_was := _hammer_on
	_stash_open = open
	_hammer_on = hammer
	_orders.set_length(_cards_right + cards_x)
	if not animate:
		_stash_wrap.visible = open
		_stash_wrap.scale = Vector2.ONE if open else Vector2.ZERO
		_stash_btn.mouse_filter = MOUSE_FILTER_STOP if open else MOUSE_FILTER_IGNORE
		_base_btn.position.x = base_x
		_hammer_btn.visible = hammer
		_hammer_btn.scale = Vector2.ONE
		_hammer_btn.position.x = hammer_x
		_hammer_btn.mouse_filter = MOUSE_FILTER_STOP if hammer else MOUSE_FILTER_IGNORE
		_cards_root.position.x = cards_x
		return
	if open:
		_stash_wrap.visible = true
		_stash_btn.mouse_filter = MOUSE_FILTER_STOP
	else:
		_stash_btn.mouse_filter = MOUSE_FILTER_IGNORE
	if hammer:
		_hammer_btn.visible = true
		_hammer_btn.mouse_filter = MOUSE_FILTER_STOP
		if not hammer_was:
			_hammer_btn.scale = Vector2.ZERO
	else:
		_hammer_btn.mouse_filter = MOUSE_FILTER_IGNORE
	_row_tween = create_tween()
	_row_tween.set_parallel(true)
	if open != stash_was:
		var stash_dur := 0.22 if open else 0.16
		_row_tween.tween_property(_stash_wrap, "scale", Vector2.ONE if open else Vector2.ZERO, stash_dur).set_trans(Tween.TRANS_BACK if open else Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT if open else Tween.EASE_IN)
	if hammer != hammer_was:
		var hammer_dur := 0.22 if hammer else 0.16
		_row_tween.tween_property(_hammer_btn, "scale", Vector2.ONE if hammer else Vector2.ZERO, hammer_dur).set_trans(Tween.TRANS_BACK if hammer else Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT if hammer else Tween.EASE_IN)
	_row_tween.tween_property(_base_btn, "position:x", base_x, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_row_tween.tween_property(_hammer_btn, "position:x", hammer_x, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_row_tween.tween_property(_cards_root, "position:x", cards_x, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if not open or not hammer:
		_row_tween.chain().tween_callback(_row_finish_hide)

func _row_finish_hide() -> void:
	if not _stash_open and G.stash.is_empty():
		_stash_wrap.visible = false
		_stash_btn.mouse_filter = MOUSE_FILTER_IGNORE
	if not _hammer_on and not _tribe_ready():
		_hammer_btn.visible = false
		_hammer_btn.scale = Vector2.ONE
		_hammer_btn.mouse_filter = MOUSE_FILTER_IGNORE

func _on_hammer() -> void:
	var id := G.next_build_id()
	if id == "" or G.main.screen != "board":
		return
	G.main.show_screen("home")
	var tw := create_tween()
	tw.tween_interval(0.42)
	tw.tween_callback(func():
		if G.main.screen == "home":
			G.main.open("build", id))

func _refresh_hud() -> void:
	_inv_lbl.text = "%d/%d" % [G.inv.size(), G.inv_cap]
	_lv_lbl.text = "阿焰 Lv.%d" % G.level
	_xp_lbl.text = "%d/%d" % [G.xp, G.xp_need()]
	_sync_row()
	_stash_btn.queue_redraw()
	_base_btn.queue_redraw()
	_hammer_btn.queue_redraw()
	queue_redraw()
	for c in get_children():
		if c is DrawBox:
			c.queue_redraw()
	for c in _cards:
		c.queue_redraw()

func _on_select(i: int) -> void:
	var cooking := i >= 0 and G.cooking(i)
	var has: bool = i >= 0 and G.board[i]["id"] != ""
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
		_info_desc.text = "还要 %s。沙漏 %d，每份快 10 秒。" % [Board._sec_text(maxi(G.cook_left(i), 1)), G.rush]
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
		_info_desc.text = Data.describe(_undo_id)
	elif has:
		var c: Dictionary = G.board[i]
		_info_btn.visible = c["lock"] != 2
		_info_desc.position.x = 170
		_info_desc.size.x = 300
		if c["lock"] == 2:
			_info_name.text = "巨石"
			_info_desc.text = "巨石挡路。在旁边合成后，石头崩开，里面的物品会被藤蔓缠住。"
		elif Data.is_dish(c["id"]):
			_info_name.text = Data.name_of(c["id"])
			_info_desc.text = Data.describe(c["id"])
			if pending:
				_show_undo_btn()
			else:
				_show_delete_btn(false)
		else:
			_info_name.text = "%s (Lv.%d)" % [Data.name_of(c["id"]), Data.lv(c["id"])]
			if c["lock"] == 1:
				_info_desc.text = "被藤蔓缠住了，拖一个相同的物品过来合成即可解开。"
			else:
				_info_desc.text = Data.describe(c["id"])
		if pending:
			_show_undo_btn()
		elif Data.is_dish(c["id"]):
			_show_delete_btn(false)
		else:
			_show_delete_btn(c["lock"] == 0)
	else:
		_info_btn.visible = false
		_show_delete_btn(false)
		_info_name.text = ""
		_info_desc.text = "点击物品查看详情，拖动相同物品合成。"
		_info_desc.position.x = 170
		_info_desc.size.x = 410
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
	if board.selected >= 0 and G.cooking(board.selected):
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
	if i >= 0 and G.cooking(i):
		_on_rush(i)
		return
	if i < 0 or G.board[i]["lock"] != 0 or G.board[i]["id"] == "":
		return
	var id: String = G.board[i]["id"]
	if Data.is_dish(id):
		G.main.toast("做好的食物要交给订单")
		Sfx.play("deny")
		return
	_undo_cell = i
	_undo_id = id
	_undo_pay = Data.value_of(id) if Data.type_of(id) == "item" else 0
	G.board[i]["id"] = ""
	G.dirty()
	G.board_changed.emit()
	board.select(-1)
	Sfx.play("whoosh")

func _on_rush(i: int) -> void:
	if G.rush < 1:
		G.main.toast("没有沙漏。在棋盘上合成后再领取，一次能领更多。")
		Sfx.play("deny")
		board.shake(i)
		return
	G.rush_cook(i)
	Sfx.play("pop", 1.15)
	if G.cooking(i):
		G.main.toast("快了 10 秒")
	else:
		G.main.toast("制作完成")

func _on_undo() -> void:
	var i := _undo_cell
	var id := _undo_id
	if i < 0 or id == "":
		_clear_undo()
		_on_select(board.selected)
		return
	if G.board[i]["id"] != "":
		G.main.toast("这个格子已经有东西了")
		_clear_undo()
		_on_select(board.selected)
		return
	_undo_pay = 0
	G.board[i]["id"] = id
	_clear_undo()
	G.dirty()
	G.board_changed.emit()
	board.select(i)
	Sfx.play("pop")

func _clear_undo() -> void:
	if _undo_pay > 0:
		G.add_currency("shell", _undo_pay)
		_undo_pay = 0
	_undo_cell = -1
	_undo_id = ""
	_del_lbl.text = "丢弃"
	_del_btn.style = "red"
	_del_btn.glyph = "trash"
	_del_btn.extra = Callable()
	_del_btn.queue_redraw()

func _on_activate(i: int) -> void:
	if _guide_up() and not G.main._guide.allows_activate(i):
		board.shake(i)
		Sfx.play("deny")
		return
	if G.cooking(i):
		return
	var id: String = G.board[i]["id"]
	if Data.is_dish(id):
		G.main.toast("点订单上的对勾交付")
		Sfx.play("deny")
		return
	match Data.type_of(id):
		"gen":
			if Data.gen_stats(id).is_empty():
				var nxt := Data.first_prod_lv(Data.chain(id))
				if nxt <= 0:
					G.main.toast("这一级不能生产")
				else:
					G.main.toast("合成到 %d 级才能生产" % nxt)
				board.shake(i)
				Sfx.play("deny")
				return
			if G.gen_left(i) == 0:
				G.main.toast("%s休息中，%s后恢复" % [Data.name_of(id), G.fmt_time(G.gen_wait(i))])
				board.shake(i)
				Sfx.play("deny")
				return
			if G.energy <= 0:
				G.main.open("energy")
				return
			var to := _guide_spawn(i)
			if to < 0:
				G.main.toast("棋盘满了，先合成或收起一些物品吧！")
				Sfx.play("deny")
				return
			G.spend("energy", 1)
			G.gen_use(i)
			var out := G.roll_produce(id)
			if _guide_up():
				var forced := str(G.main._guide.force_drop(i))
				if forced != "":
					out = forced
			var fresh := G.discover(out)
			G.board[to]["id"] = out
			G.dirty()
			board.fly_in(i, to, out)
			Sfx.play("pop", 1.0 + randf() * 0.2)
			G.board_changed.emit()
			if fresh:
				G.main.toast("新发现：%s！" % Data.name_of(out))
		"energy", "shell", "amber", "sand":
			var kind := Data.type_of(id)
			var v := Data.value_of(id)
			if v <= 0:
				Sfx.play("deny")
				G.main.toast("%s 要合成到 2 级才能收取" % Data.name_of(id))
				return
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
	if G.cooking(i):
		return
	if Data.is_dish(str(G.board[i]["id"])):
		G.main.toast("做好的食物留在棋盘上，点订单交付")
		Sfx.play("deny")
		return
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
	var id: String = G.stash.back()
	match Data.type_of(id):
		"pack":
			G.stash.pop_back()
			G.dirty()
			G.changed.emit()
			G.main.open("pack")
		"energy", "shell", "amber", "sand" when Data.value_of(id) > 0:
			G.stash.pop_back()
			var kind := Data.type_of(id)
			var v := Data.value_of(id)
			G.dirty()
			G.changed.emit()
			Sfx.play("coin")
			G.main.fly(id, stash_pos(), G.main.topbar.target(kind), func(): G.add_currency(kind, v), 70)
		"chest":
			_take_stash_chest()
		_:
			var to := G.find_empty_near(G.idx(0, 0))
			if to < 0:
				G.main.toast("棋盘满了！")
				Sfx.play("deny")
				return
			G.stash.pop_back()
			G.board[to]["id"] = id
			G.discover(id)
			G.dirty()
			_fly_stash_to(id, to, 0.0)
			Sfx.play("pop")
			G.board_changed.emit()
			G.changed.emit()

## 暂存区顶上的宝箱：先改完棋盘和暂存，再发一次信号
func _take_stash_chest() -> void:
	G.stash.pop_back()
	var extra := 0
	var placed := 0
	for it in G.roll_chest():
		G.discover(it)
		var to := G.find_empty_near(G.idx(0, 0))
		if to < 0:
			G.stash.append(it)
			extra += 1
			continue
		G.board[to]["id"] = it
		var delay := placed * 0.14
		_fly_stash_to(it, to, delay)
		if delay <= 0.0:
			Sfx.play("pop")
		else:
			get_tree().create_timer(delay).timeout.connect(func(_d := delay): Sfx.play("pop"))
		placed += 1
	if extra > 0:
		G.main.toast("放不下的 %d 个物品进了暂存区" % extra)
	Sfx.play("merge", 1.2)
	G.dirty()
	if placed > 0:
		G.board_changed.emit()
	G.changed.emit()

## 顶卡物品中心：和 _paint_stash 里 k==0 的那张一致，换到暂存区全局坐标
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
		if oi >= G.orders.size() or not G.order_ready(G.orders[oi]):
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
	return G.find_empty_near(near_i)
