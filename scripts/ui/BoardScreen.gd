class_name BoardScreen
extends Control
const Meme := preload("res://scripts/Meme.gd")

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
## 篝火竞速入口的宽度（在主角卡左边）
const RACE_W := 104.0
const EVENT_W := 104.0
const CHIP_ICON := {"shell": "shell_2", "pack": "pack_1", "token": "token_1"}

var _bubble_offer: Control
var _bubble_title: Label
var _bubble_time: Label
var _bubble_buy: TButton
var board: Board
var _orders: Scroller
var _info_name: Label
var _info_desc: Label
var _info_visual: DrawBox
var _info_action := {}
var _info_btn: TButton
var _del_btn: TButton
## 双倍火种开关（Data.BOOST_LEVEL 级解锁，圆钮，在顶栏集市小屋下面）
var _boost_btn: TButton
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
var _stash_busy := false
var _hammer_on := false
var _row_tween: Tween
var _base_btn: TButton
var _hammer_btn: TButton
var _pouch: TButton
var _race_entry: Control
var _tiger_entry: Control
var _duel_entry: Control
var _seven_entry: Control
var _merge_event_entry: Control
var _shown_was: Array = []
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
	# 篝火竞速入口：主角卡左边
	_race_entry = preload("res://scripts/ui/RaceEntry.gd").new()
	_race_entry.position = BASE_RECT.position
	_race_entry.size = Vector2(RACE_W, BASE_RECT.size.y)
	_orders.content.add_child(_race_entry)
	_merge_event_entry = preload("res://scripts/ui/MergeEventEntry.gd").new()
	_merge_event_entry.position = BASE_RECT.position
	_merge_event_entry.size = Vector2(EVENT_W, BASE_RECT.size.y)
	_orders.content.add_child(_merge_event_entry)
	_seven_entry = preload("res://scripts/ui/SevenDayEntry.gd").new()
	_seven_entry.position = BASE_RECT.position
	_seven_entry.size = Vector2(EVENT_W, BASE_RECT.size.y)
	_orders.content.add_child(_seven_entry)
	_duel_entry = preload("res://scripts/ui/DuelEntry.gd").new()
	_duel_entry.position = BASE_RECT.position
	_duel_entry.size = Vector2(EVENT_W, BASE_RECT.size.y)
	_orders.content.add_child(_duel_entry)
	_tiger_entry = preload("res://scripts/ui/TigerEscapeEntry.gd").new()
	_tiger_entry.position = BASE_RECT.position
	_tiger_entry.size = Vector2(EVENT_W, BASE_RECT.size.y)
	_orders.content.add_child(_tiger_entry)
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
	_info_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_visual = UI.box(self, Rect2(170, 1352, 300, 96), _paint_item_action)
	_info_btn = UI.hit(self, Rect2(150, 1300, 46, 46), _open_info)
	_info_btn.extra = func(ci, sz): Paint.glyph(ci, "info", sz * 0.5, 1.2)
	_del_btn = UI.btn(self, Rect2(486, 1360, 86, 80), "", "red", _on_delete)
	_del_btn.glyph = "trash"
	_del_lbl = UI.lbl(self, "丢弃", Rect2(476, 1326, 106, 34), 20, Art.CLAY, HORIZONTAL_ALIGNMENT_CENTER, 6, Color.WHITE)

	var home := UI.btn(self, Rect2(604, 1330, 106, 110), "", "teal", func(): G.main.show_screen("home"))
	home.extra = func(ci, sz): Paint.home_icon(ci, sz * 0.5 + Vector2(0, -2), 0.85)

	add_child(preload("res://scripts/ui/UfoEntry.gd").new())
	var gm := UI.btn(self, Rect2(12, 156, 68, 42), "GM", "teal", func():
		if Replay.active:
			var result: Dictionary = Replay.perform("gm")
			if result.has("error"): G.main.toast(str(result["error"]))
			return
		# 双倍火种不走服务器，先在本地解锁
		G.boost_gm = true
		G.dirty()
		G.changed.emit()
		if G.server_mode():
			var result: Dictionary = await G._cloud().act("/v1/gm/activities")
			if not result.get("ok", false):
				G.main.toast(str(result.get("message", "当前环境未开放 GM")))
				return
		else: G.gm_activities = true
		G.save_game()
		G.merge_event_changed.emit()
		G.changed.emit()
		G.main.toast("月石遗迹、香蕉活动、双倍火种已解锁"), 21)
	gm.name = "gm_activities"
	_boost_btn = UI.btn(self, Rect2(646, 118, 66, 66), "", "grey", _on_boost)
	_boost_btn.is_round = true
	_boost_btn.extra = _paint_boost
	_boost_btn.visible = false
	_build_bubble_offer()
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
	Sprites.draw(ci, "board_curtain_l", Rect2(0, 0, 90, 380))
	Sprites.draw(ci, "board_curtain_r", Rect2(sz.x - 90, 0, 90, 380))
	Sprites.draw(ci, "board_log", Rect2(-10, 372, sz.x + 20, 50))

## 暂存区：临时物品像卡片一样叠放，点击把最上面一张放到棋盘
func _paint_stash(ci: CanvasItem, sz: Vector2) -> void:
	var n := G.stash.size()
	Sprites.draw(ci, "board_stash_tray", Rect2(6, 26, sz.x - 12, sz.y - 34))
	var shown := mini(n, 4)
	var top := G.stash_claim_index()
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
	Paint.bust(ci, Vector2(sz.x * 0.5, 96), 54)
	Paint.bar(ci, Rect2(12, 176, sz.x - 24, 24), float(G.xp) / float(G.xp_need()), Art.MOSS)
	Art.item(ci, "xp_1", Vector2(16, 188), 36)

## 贝币够建下一段部落时出现，点了回村庄升级
func _paint_hammer(ci: CanvasItem, sz: Vector2) -> void:
	Sprites.draw(ci, "board_hammer_card", Rect2(Vector2.ZERO, sz))
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
	Sprites.draw(ci, "board_info_panel", Rect2(Vector2.ZERO, sz))
	if board and (board.selected >= 0 or _undo_cell >= 0):
		Sprites.draw(ci, "board_info_tag", Rect2(26, 4, 304, 40))

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
		var xa: bool = int(G.orders[a]["rw"].get("xp",0)) > 0
		var xb: bool = int(G.orders[b]["rw"].get("xp",0)) > 0
		if xa != xb: return xa
		var sa := gap[a] == 0
		var sb := gap[b] == 0
		if sa != sb: return sa
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
		var name_w := w - 96.0
		if str(o.get("kind", "")) == "craft":
			name_w = w - 168.0
		elif o["rw"].has("xp") and int(o["rw"]["xp"]) > 0:
			name_w = w - 144.0
		UI.lbl(card, Data.PEOPLE[o["who"]].get_slice(" ", 1), Rect2(92, 30, name_w, 32), 20, Art.INK, HORIZONTAL_ALIGNMENT_LEFT)
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
	Sprites.draw(ci, "board_card_base", r)
	var bg := Color("fbf0d6")
	if story:
		bg = Color("ffe9a8")
	if craft and phase == "cook":
		bg = Color("ffe4c4")
	elif craft and G.craft_mats_ready(o):
		bg = Color("fff3c4")
	if ready:
		bg = Color("eaf6c8")
	Sprites.draw(ci, "board_card_fill", r, bg)
	Sprites.draw(ci, "board_card_dash", r)
	Sprites.at(ci, "board_head_story" if story else "board_head_npc", Vector2(46, 38))
	Meme.portrait(ci, int(o["who"]), Vector2(46, 37), 74)
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
		_spot_shadow(ci, dc + Vector2(0, 3), dish_s)
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
			_spot_shadow(ci, c + Vector2(0, 4), s)
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
		Sprites.draw(ci, "board_chip", Rect2(x, chip_y - 14.0, pill_w, 28.0))
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
		_spot_shadow(ci, c + Vector2(0, 4), icon)
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

## 物品底下的浅色椭圆影子，s 是物品尺寸
static func _spot_shadow(ci: CanvasItem, c: Vector2, s: float) -> void:
	Sprites.draw(ci, "board_spot_shadow", Rect2(c - Vector2(s * 0.5, s * 0.42), Vector2(s, s * 0.84)))

## 箭头图是横着的，转到方向后把中段拉到需要的长度
static func _aim_arrow(ci: CanvasItem, a: Vector2, tip: Vector2) -> void:
	ci.draw_set_transform(a, (tip - a).angle(), Vector2.ONE)
	Sprites.draw(ci, "board_aim_arrow", Rect2(0, -8, (tip - a).length(), 16))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

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
	_race_entry.fly_from(card_pos)
	_merge_event_entry.fly_from(card_pos)
	board.select(-1)
	Sfx.play("coin")
	await get_tree().create_timer(0.35).timeout
	var say := str(o.get("say", ""))
	G.main.toast("%s：%s" % [Data.PEOPLE[who].get_slice(" ", 1), say if say != "" else Meme.line()])
	var rewards: Array = []
	for pair in [["shell", "shell_2"], ["xp", "xp_1"], ["token", "token_1"]]:
		if int(rw.get(pair[0], 0)) > 0:
			rewards.append([pair[1], int(rw[pair[0]])])
	if rw.get("rewards") is Array and not rw["rewards"].is_empty():
		rewards.append_array(Rewards.items(rw["rewards"]))
	elif int(rw.get("pack", 0)) > 0:
		rewards.append(["pack_1", int(rw["pack"])])
	Rewards.grant(rewards, func(_k): return card_pos)

# ---------------------------------------------------------------- 交互

func _process(_delta: float) -> void:
	if board == null:
		return
	if Engine.get_process_frames() % 60 == 0:
		_sync_row() # 活动开放 / 结束时入口出现或收起
	if _bubble_offer != null and _bubble_offer.visible:
		if G.is_merge_bubble(board.selected) and G.bubble_left(board.selected) > 0:
			_bubble_tick()
		else:
			_on_select(board.selected)
	var i := board.selected
	if i < 0 or not G.cooking(i):
		return
	var text := "还要 %s。沙漏 %d（每份快 %s），做完要 %d 份。" % [Board._sec_text(maxi(G.cook_left(i), 1)), G.rush, Data.rush_text(), G.rush_need(i)]
	if _info_desc.text != text:
		_info_desc.text = text

func _on_board_changed() -> void:
	_build_orders()
	_refresh_hud()
	if board != null and board.selected >= 0:
		var id := str(G.board[board.selected]["id"])
		_on_select(board.selected)

func _tribe_ready() -> bool:
	var id := G.next_build_id()
	return id != "" and G.shells >= G.build_cost(id)

## 活动入口只显示已解锁的，顺序：香蕉竞速、月石遗迹、七日任务、双人竞速、剑齿虎逃生
func _entries_shown() -> Array:
	return [_race_entry.race.unlocked(), MergeEvent.available(MergeEvent.current()), true, DuelRace.unlocked(), TigerEscape.unlocked()]

func _entries_w() -> float:
	var shown := _entries_shown()
	var w := 0.0
	for i in shown.size():
		if shown[i]: w += (RACE_W if i == 0 else EVENT_W) + ROW_GAP
	return w

func _cards_x() -> float:
	var x := 0.0 if not G.stash.is_empty() else -(BASE_RECT.position.x - STASH_RECT.position.x)
	x += _entries_w() + ROW_GAP
	if _tribe_ready():
		x += HAMMER_W + ROW_GAP
	return x

func _sync_row() -> void:
	var open := not G.stash.is_empty()
	if open == _stash_open and _tribe_ready() == _hammer_on and _entries_shown() == _shown_was:
		return
	_apply_row(true)

func _apply_row(animate: bool) -> void:
	if _row_tween != null and _row_tween.is_valid():
		_row_tween.kill()
	var open := not G.stash.is_empty()
	var hammer := _tribe_ready()
	var shown := _entries_shown()
	_shown_was = shown
	var entries := [_race_entry, _merge_event_entry, _seven_entry, _duel_entry, _tiger_entry]
	var xs := []
	var cx: float = BASE_RECT.position.x if open else STASH_RECT.position.x
	for i in entries.size():
		xs.append(cx)
		entries[i].visible = shown[i]
		if shown[i]: cx += (RACE_W if i == 0 else EVENT_W) + ROW_GAP
	var race_x: float = xs[0]
	var event_x: float = xs[1]
	var seven_x: float = xs[2]
	var duel_x: float = xs[3]
	var tiger_x: float = xs[4]
	var base_x := cx
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
		_race_entry.position.x = race_x
		_merge_event_entry.position.x = event_x
		_seven_entry.position.x = seven_x
		_duel_entry.position.x = duel_x
		_tiger_entry.position.x = tiger_x
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
	_row_tween.tween_property(_tiger_entry, "position:x", tiger_x, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_row_tween.tween_property(_duel_entry, "position:x", duel_x, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_row_tween.tween_property(_seven_entry, "position:x", seven_x, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_row_tween.tween_property(_merge_event_entry, "position:x", event_x, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_row_tween.tween_property(_race_entry, "position:x", race_x, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
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
	_refresh_bubble_offer()
	_inv_lbl.text = "%d/%d" % [G.inv.size(), G.inv_cap]
	_lv_lbl.text = "阿焰 Lv.%d" % G.level
	_xp_lbl.text = "%d/%d" % [G.xp, G.xp_need()]
	_sync_boost()
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
	_info_action = {}
	_info_visual.hide()
	_info_desc.show()
	_refresh_bubble_offer()
	var cooking := i >= 0 and G.cooking(i)
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
		_set_desc("还要 %s。沙漏 %d（每份快 %s），做完要 %d 份。" % [Board._sec_text(maxi(G.cook_left(i), 1)), G.rush, Data.rush_text(), G.rush_need(i)])
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
		if G.is_merge_bubble(i):
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
	if Data.type_of(id) in ["gen", "egen"]: return
	if Data.is_dish(id):
		G.main.toast("做好的食物要交给订单")
		Sfx.play("deny")
		return
	if Replay.active:
		var result: Dictionary = Replay.perform("discard", {"cell": i})
		if result.has("error"): return
		_undo_cell = i; _undo_id = id; _undo_pay = 0
		board.select(-1)
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
	var used := G.rush_cook(i)
	Sfx.play("pop", 1.15)
	if G.cooking(i):
		G.main.toast("用了 %d 份沙漏，还差 %d 份" % [used, G.rush_need(i)])
	else:
		G.main.toast("制作完成")

func _on_undo() -> void:
	if Replay.active:
		Replay.perform("undo")
		_clear_undo()
		return
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
	if Replay.active:
		# Clear the selection state before emitting the reducer's change signals.
		_undo_cell = -1; _undo_id = ""; _undo_pay = 0
		if Replay.meta.has("trash"): Replay.perform("discard_finish")
	if _undo_pay > 0:
		G.cloud_event({"type": "refund", "item": _undo_id})
		G.add_currency("shell", _undo_pay)
		_undo_pay = 0
	_undo_cell = -1
	_undo_id = ""
	_del_lbl.text = "丢弃"
	_del_btn.style = "red"
	_del_btn.glyph = "trash"
	_del_btn.extra = Callable()
	_del_btn.queue_redraw()

# ---------------------------------------------------------------- 双倍火种

func _sync_boost() -> void:
	var open := G.boost_open()
	_boost_btn.visible = open
	_boost_btn.style = "purple" if G.boost_on() else "grey"
	_boost_btn.queue_redraw()

func _on_boost() -> void:
	if not G.boost_open():
		G.main.toast("%d级解锁双倍火种" % Data.BOOST_LEVEL)
		return
	G.set_boost(not G.boost)
	if G.boost:
		G.main.toast("双倍火种已开启：生产器每次耗 2 火种，产物升 1 级")
	else:
		G.main.toast("双倍火种已关闭")

## 开关上画：火苗 + ×2，开着是紫火
func _paint_boost(ci: CanvasItem, sz: Vector2) -> void:
	var on := G.boost_on()
	var c := sz * 0.5 + Vector2(0, -6)
	Sprites.at(ci, "board_boost_on" if on else "board_boost_off", c)
	var at := Vector2(0, sz.y - 10)
	ci.draw_string_outline(G.font_title, at, "×2" if on else "×1", HORIZONTAL_ALIGNMENT_CENTER, sz.x, 24, 6, Art.INK)
	ci.draw_string(G.font_title, at, "×2" if on else "×1", HORIZONTAL_ALIGNMENT_CENTER, sz.x, 24, Color.WHITE)

func _on_activate(i: int) -> void:
	if i < 0 or i >= G.board.size() or int(G.board[i]["lock"]) != 0:
		return
	if _guide_up() and not G.main._guide.allows_activate(i):
		board.shake(i)
		Sfx.play("deny")
		return
	if G.cooking(i):
		return
	var id: String = G.board[i]["id"]
	if Replay.active:
		if Data.type_of(id) == "choice": G.main.open("choice_chest", i); return
		if Data.type_of(id) == "pack": G.main.open("pack"); return
		var result: Dictionary = await Replay.perform("tap", {"cell": i})
		if result.has("error"):
			if Data.type_of(id) in ["gen", "egen"] and G.energy < G.gen_cost(): G.main.open("energy", "exhausted")
			else: G.main.toast(str(result["error"]))
		elif result.get("kind", "") == "produce": board.fly_in(i, int(result["to"]), str(result["id"]))
		else: board.burst(i); board.select(-1)
		return
	if Data.is_dish(id):
		G.main.toast("点订单上的对勾交付")
		Sfx.play("deny")
		return
	match Data.type_of(id):
		"gen", "egen":
			var free := Data.type_of(id) == "egen"
			if Data.gen_stats(id).is_empty():
				var nxt := 0 if free else Data.first_prod_lv(Data.chain(id))
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
			var cost := 0 if free else G.gen_cost()
			if not free and G.energy < cost:
				if G.energy > 0:
					G.main.toast("双倍火种每次要 %d 火种" % cost)
				G.main.open("energy", "exhausted")
				return
			var to := _guide_spawn(i)
			if to < 0:
				G.main.toast("棋盘满了，先合成或收起一些物品吧！")
				Sfx.play("deny")
				return
			if not free:
				G.spend("energy", cost)
			G.gen_use(i)
			var out := G.roll_produce(id)
			if not free:
				out = G.boost_drop(out)
			if free:
				G.cloud_event({"type": "egen", "gen": id, "item": out})
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
			G.cloud_event({"type": "collect", "item": id})
			Rewards.grant([[id, v]], func(_k): return board.cell_global(i))
		"choice":
			G.main.open("choice_chest", i)
		"chest":
			# 宝箱由服务器开：连不上就留在原地
			var items: Array = await G.open_chest(id)
			if items.is_empty() or str(G.board[i]["id"]) != id:
				return
			G.board[i]["id"] = ""
			Rewards.grant(Rewards.items(items), Callable(), true, true, {"board_origin": i})
			board.burst(i)
			board.select(-1)
			Sfx.play("merge", 1.2)
			G.dirty()
			G.board_changed.emit()
		"pack":
			if G.level < Data.CARD_LEVEL:
				G.main.toast("典藏卡在 %d 级解锁" % Data.CARD_LEVEL)
				return
			G.board[i]["id"] = ""
			G.dirty()
			G.board_changed.emit()
			board.select(-1)
			G.main.open("pack")
		_:
			board.shake(i)

func _on_drop_outside(i: int, gp: Vector2) -> void:
	if G.cooking(i) or not G.is_free(i):
		return
	if Data.is_dish(str(G.board[i]["id"])):
		G.main.toast("做好的食物留在棋盘上，点订单交付")
		Sfx.play("deny")
		return
	if _pouch.get_global_rect().has_point(gp):
		if Replay.active:
			Replay.perform("store", {"cell": i})
			board.select(-1)
			return
		if Data.type_of(str(G.board[i]["id"])) == "egen":
			# 冷却记在格子上，收进储物洞会丢掉；服务器也按账号限次，所以火种罐只能留在棋盘
			G.main.toast("%s要留在棋盘上" % Data.name_of(str(G.board[i]["id"])))
			Sfx.play("deny")
			return
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
	if Replay.active:
		var at := G.stash_claim_index()
		if at < 0: return
		if Data.type_of(str(G.stash[at])) == "pack": G.main.open("pack"); return
		var result: Dictionary = await Replay.perform("stash", {"index": at})
		if result.has("error"): G.main.toast(str(result["error"]))
		elif result.has("to"): _fly_stash_to(str(result["id"]), int(result["to"]), 0.0)
		return
	if _stash_busy: return
	if G.stash.is_empty():
		G.main.toast("奖励、购买和放不下的物品会暂存在这里")
		return
	var index := G.stash_claim_index()
	if index < 0:
		G.main.toast("卡包已保留，%d级开启" % Data.CARD_LEVEL)
		return
	var id: String = G.stash[index]
	match Data.type_of(id):
		"pack":
			if G.level < Data.CARD_LEVEL:
				G.main.toast("典藏卡在 %d 级解锁" % Data.CARD_LEVEL)
				return
			G.stash.remove_at(index)
			G.dirty()
			G.changed.emit()
			G.main.open("pack")
		"energy", "shell", "amber", "sand" when Data.value_of(id) > 0:
			G.stash.remove_at(index)
			var kind := Data.type_of(id)
			var v := Data.value_of(id)
			G.dirty()
			G.changed.emit()
			Sfx.play("coin")
			G.cloud_event({"type": "collect", "item": id})
			Rewards.grant([[id, v]], func(_k): return stash_pos())
		"chest":
			_stash_busy = true
			await _take_stash_chest(index)
			_stash_busy = false
		_:
			var to := G.find_empty_near(G.idx(0, 0))
			if to < 0:
				G.main.toast("棋盘满了！")
				Sfx.play("deny")
				return
			G.stash.remove_at(index)
			G.board[to]["id"] = id
			G.discover(id)
			G.dirty()
			_fly_stash_to(id, to, 0.0)
			Sfx.play("pop")
			G.board_changed.emit()
			G.changed.emit()

## 暂存区顶上的宝箱：先改完棋盘和暂存，再发一次信号
func _take_stash_chest(index: int) -> void:
	if index < 0 or index >= G.stash.size(): return
	var id := str(G.stash[index])
	var got: Array = await G.open_chest(id)
	if got.is_empty() or index >= G.stash.size() or str(G.stash[index]) != id:
		return
	G.stash.remove_at(index)
	Rewards.grant(Rewards.items(got), Callable(), true, true, {"board_origin": G.idx(0, 0), "from_stash": true})
	Sfx.play("merge", 1.2)

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
	_bubble_offer.visible = G.is_merge_bubble(at) and G.bubble_left(at) > 0
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
	var left := G.bubble_left(board.selected)
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
		if id == "energybox_1":
			var opens: Array = DailyShop.energy_chest_items()
			_set_desc("点击打开，获得%d个%s。" % [opens.size(), Data.name_of(str(opens[0]))] if not opens.is_empty() else "点击打开，获得火种。")
		else:
			_set_desc("点击打开，获得3个随机物品。")
	elif kind == "pack":
		_set_desc("点击获得2张收藏卡。" if G.level >= Data.CARD_LEVEL else "%d级解锁收藏卡。" % Data.CARD_LEVEL)
	else:
		_set_desc(Data.describe(id))
	_info_visual.visible = not _info_action.is_empty()
	_info_desc.visible = _info_action.is_empty()
	_info_visual.queue_redraw()

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

const HINT_INK := Color("6b4a2a")

## 图标底下的浅色圆角托盘，让每个图标都有同样大小的“格子”
static func _hint_plate(ci: CanvasItem, c: Vector2, s: float, seed: int, hot: bool = false) -> void:
	Sprites.draw(ci, "board_plate_hot" if hot else "board_plate", Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)))

## 手绘的 + / = 号：白芯墨边，和标题字一个风格
static func _hint_op(ci: CanvasItem, c: Vector2, op: String) -> void:
	var bars: Array = []
	if op == "+":
		bars = [[c + Vector2(-10, 0), c + Vector2(10, 0)], [c + Vector2(0, -10), c + Vector2(0, 10)]]
	else:
		bars = [[c + Vector2(-10, -5), c + Vector2(10, -5)], [c + Vector2(-10, 5), c + Vector2(10, 5)]]
	for b in bars:
		ci.draw_line(b[0], b[1], Art.INK, 9.0, true)
		ci.draw_circle(b[0], 4.5, Art.INK)
		ci.draw_circle(b[1], 4.5, Art.INK)
	for b in bars:
		ci.draw_line(b[0], b[1], Art.BONE, 4.0, true)
		ci.draw_circle(b[0], 2.0, Art.BONE)
		ci.draw_circle(b[1], 2.0, Art.BONE)

static func _hint_text(ci: CanvasItem, pos: Vector2, text: String, fs: int, col: Color = HINT_INK, outline := false) -> float:
	var f: Font = G.font_title if outline else G.font_body
	if outline:
		ci.draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Art.INK)
	ci.draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	return f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x

static func _text_w(text: String, fs: int, title := false) -> float:
	var f: Font = G.font_title if title else G.font_body
	return f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x

## 文字基线：让 fs 号字在 y 处垂直居中
static func _mid_base(y: float, fs: int, title := false) -> float:
	var f: Font = G.font_title if title else G.font_body
	return y + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5

func _paint_item_action(ci: CanvasItem, sz: Vector2) -> void:
	if _info_action.is_empty(): return
	var mode := str(_info_action["mode"])
	var items: Array = _info_action["items"]
	var y := sz.y * 0.5
	if mode == "merge":
		# 3 个 78 托盘 + 2 个 33 运算符 = 300
		var plate := 76.0
		var op_w := (sz.x - plate * 3.0) * 0.5
		for k in 3:
			var cx := plate * 0.5 + k * (plate + op_w)
			_hint_plate(ci, Vector2(cx, y), plate, k, k == 2)
			Art.item(ci, str(items[k]), Vector2(cx, y), plate * 0.86, false)
		_hint_op(ci, Vector2(plate + op_w * 0.5, y), "+")
		_hint_op(ci, Vector2(plate * 2.0 + op_w * 1.5, y), "=")
	elif mode == "produce":
		var label := "点击生产"
		var fs := 22
		var lw := _text_w(label, fs)
		_hint_text(ci, Vector2(0, _mid_base(y, fs)), label, fs)
		var x0 := lw + 8.0
		var area := sz.x - x0
		var n := items.size()
		var rows := 1 if n <= 4 else 2
		var cols := ceili(float(n) / float(rows))
		var step := minf(area / float(cols), 62.0 if rows == 1 else 52.0)
		var plate := step - 4.0
		var row_h := sz.y / float(rows)
		var used := step * float(cols)
		for k in n:
			var row := k / cols
			var col := k % cols
			# 第二行少一个时也居中
			var in_row := cols if row < rows - 1 else n - cols * (rows - 1)
			var cx := x0 + (area - used) * 0.5 + (float(col) + 0.5 + (cols - in_row) * 0.5) * step
			var cy := row_h * (float(row) + 0.5)
			_hint_plate(ci, Vector2(cx, cy), plate, k)
			Art.item(ci, str(items[k]), Vector2(cx, cy), plate * 0.94, false)
	elif mode == "collect":
		var plate := 72.0
		_hint_plate(ci, Vector2(plate * 0.5, y), plate, 3, true)
		Art.item(ci, str(items[0]), Vector2(plate * 0.5, y), plate * 0.86, false)
		var a := "点击获得"
		var num := str(int(_info_action["n"]))
		var b := str(_info_action["unit"])
		var fa := 22
		var fn := 32
		var total := _text_w(a, fa) + 6.0 + _text_w(num, fn, true) + 4.0 + _text_w(b, fa)
		var x := plate + maxf(10.0, (sz.x - plate - total) * 0.5)
		x += _hint_text(ci, Vector2(x, _mid_base(y, fa)), a, fa) + 6.0
		x += _hint_text(ci, Vector2(x, _mid_base(y, fn, true)), num, fn, Art.FIRE2, true) + 4.0
		_hint_text(ci, Vector2(x, _mid_base(y, fa)), b, fa)
	else:
		var plate := 76.0
		_hint_plate(ci, Vector2(plate * 0.5, y), plate, 5, true)
		Art.item(ci, str(items[0]), Vector2(plate * 0.5, y), plate * 0.86, false)
		ci.draw_texture_rect(Board.MAX_CROWN, Rect2(plate - 30, y - plate * 0.5 - 8, 38, 30), false)
		var t := "已达最高级"
		var fs := 24
		_hint_text(ci, Vector2(plate + (sz.x - plate - _text_w(t, fs)) * 0.5, _mid_base(y, fs)), t, fs)
