class_name OrderCard
extends DrawBox
## One persistent order card; callbacks follow the current order index after sorting.
signal craft_requested(index: int)
signal delivery_requested(index: int)
const CHIP_ICON := {"shell": "shell_2", "pack": "pack_1", "token": "token_1"}
const DISH_ICON_SIDE := 62.0
## 木桩截面中心（制作产物立在上面）、石板区域、石板上物品的中心高度、下面活动积分那一排
const STUMP_TOP := 94.0
const DISH_Y := 72.0
const SLAB_Y := 134.0
const SLAB_H := 58.0
const SLAB_ITEM_Y := 133.0
const POINTS_Y := 178.0
const SLAB_PAD := 14.0
var order_index := -1
var order: Dictionary = {}
var _state_signature := ""
var _shape_signature := ""
var _make_host: Control
var _deliver_host: Control
var _recipe_button: Control
var _status: Label
var _skip_button: TButton
var _skip_cost: Label
var _rewards_layer: DrawBox
var _time_bar: DrawBox
var _clock := 0.0
var _was_ready := false
var _breath: Tween
var _mat_hits: Array = []

func _ready() -> void:
	painter = _paint_order
	super._ready()

static func missing(o: Dictionary) -> int:
	if str(o.get("kind", "")) == "craft" and str(o.get("phase", "need")) != "need": return 0
	var ids: Array = o["mats"] if str(o.get("kind", "")) == "craft" else o["items"]
	var boards := []
	var slots := []
	var miss := 0
	for id in ids:
		if G.rules.orders.claim_supply(str(id), boards, slots).is_empty():
			miss += 1
	return miss

func refresh(index: int, value: Dictionary) -> void:
	order_index = index
	order = value
	var shape := JSON.stringify([order.get("who", 0), order.get("items", []), order.get("mats", []), order.get("rw", {}), order.get("kind", ""), FossilDig.earning()])
	if shape != _shape_signature:
		_shape_signature = shape
		_build_content()
	var ready := G.rules.orders.order_ready(order)
	var can_make := G.rules.orders.craft_mats_ready(order)
	var boards := []
	var slots := []
	var availability := []
	for id in order.get("mats", order.get("items", [])):
		availability.append(not G.rules.orders.claim_supply(str(id), boards, slots).is_empty())
	var signature := JSON.stringify([shape, order.get("phase", "need"), ready, can_make, availability, FossilDig.earning()])
	_update_clock()
	if signature == _state_signature: return
	_state_signature = signature
	_make_host.visible = can_make
	_deliver_host.visible = ready and not can_make
	var action: Control = _make_host if can_make else _deliver_host
	var enabled := can_make or ready
	if enabled and not _was_ready:
		if _breath != null and _breath.is_valid(): _breath.kill()
		action.scale = Vector2.ZERO
		_breath = action.create_tween()
		_breath.tween_property(action, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_breath.tween_callback(_start_breath.bind(action))
	elif not enabled and _breath != null and _breath.is_valid(): _breath.kill()
	_was_ready = enabled
	queue_redraw()

func _build_content() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_mat_hits = []
	size = Vector2(width_for(order), 216.0)
	var craft := str(order.get("kind", "")) == "craft"
	var spots := _formula_spots(order, size.x) if craft else _order_item_spots(order, size.x)
	for spot in spots:
		var id := str(spot["id"])
		var at: Vector2 = spot["c"]
		var side := float(spot["s"])
		var hit := UI.hit(self, Rect2(at - Vector2.ONE * side * 0.5, Vector2.ONE * side), func(): G.main.open("item_info", id))
		if craft: _mat_hits.append(hit)
	_deliver_host = _action_host(Vector2(64, 64), Vector2(size.x * 0.5 - 32, SLAB_Y - 30))
	var deliver := UI.btn(_deliver_host, Rect2(Vector2.ZERO, _deliver_host.size), "", "green", func(): delivery_requested.emit(order_index))
	deliver.is_round = true
	deliver.sound = "coin"
	deliver.extra = func(ci, sz):
		var center: Vector2 = sz * 0.5
		var points := PackedVector2Array([center + Vector2(-14, 1), center + Vector2(-3, 12), center + Vector2(16, -11)])
		ci.draw_polyline(points, Color.WHITE, 6.0, true)
		for point in points: ci.draw_circle(point, 3.0, Color.WHITE)
	_recipe_button = UI.hit(self, recipe_icon_rect().grow(17), func(): G.main.open("recipe", str(order.get("dish", ""))))
	_recipe_button.visible = str(order.get("kind", "")) == "craft"
	_status = UI.lbl(self, "", Rect2(8, SLAB_Y + 8, size.x - 16, 26), 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 5, Art.INK)
	# 加速键骑在卡片下沿正中：沙漏在左，份数贴在图标右下角，文字在右
	_skip_button = UI.btn(self, Rect2(size.x * 0.5 - 64, SLAB_Y + SLAB_H + 4, 128, 50), "", "teal", func(): G.main.board_screen._on_rush(int(order.get("cell", -1))), 22)
	UI.icon(_skip_button, "sand_2", Vector2(28, 24), 40, false)
	_skip_cost = UI.lbl(_skip_button, "", Rect2(32, 24, 30, 24), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 5, Art.INK)
	UI.lbl(_skip_button, TextCatalog.source("ui.ordercard.fc50a99caae0"), Rect2(52, 0, 70, 46), 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK)
	_rewards_layer = UI.box(self, Rect2(0, POINTS_Y - 20, size.x, 40), _paint_rewards, false)
	_time_bar = UI.box(self, Rect2(10, POINTS_Y - 17, size.x - 20, 34), _paint_cook_time, false)
	# 对勾和制作键压在石板台面上：盖住材料和木桩下半截，侧面的奖励露出来。
	move_child(_deliver_host, -1)
	_make_host = _action_host(Vector2(112, 52), Vector2(size.x * 0.5 - 56, SLAB_Y - 20))
	var make := UI.btn(_make_host, Rect2(Vector2.ZERO, _make_host.size), TextCatalog.source("ui.ordercard.da2dadcd3ff9"), "orange", func(): craft_requested.emit(order_index), 28)
	make.sound = "pop"
	_was_ready = false

func recipe_icon_rect() -> Rect2:
	return Rect2(Vector2(size.x * 0.5, DISH_Y) - Vector2.ONE * DISH_ICON_SIDE * 0.5, Vector2.ONE * DISH_ICON_SIDE)

func recipe_icon_global_rect() -> Rect2:
	return get_global_transform() * recipe_icon_rect()

func _process(dt: float) -> void:
	_clock += dt
	if _clock < 0.5 or not is_visible_in_tree(): return
	_clock = 0.0
	_update_clock()

func _update_clock() -> void:
	if _status == null or order.is_empty(): return
	var phase := str(order.get("phase", "need"))
	var show_mats := phase == "need" or phase == "cook"
	for hit in _mat_hits:
		if is_instance_valid(hit): hit.visible = show_mats
	_skip_button.visible = phase == "cook"
	_rewards_layer.visible = phase != "cook"
	_time_bar.visible = phase == "cook"
	_status.visible = phase == "finished"
	if phase == "cook":
		var at := int(order.get("cell", -1))
		var cost := G.rules.orders.rush_need(at)
		_skip_cost.text = TextCatalog.resolve(str(cost))
		_skip_button.tooltip_text = TextCatalog.resolve(TextCatalog.fill(TextCatalog.source("ui.ordercard.39298616da42"), cost))
		_skip_button.enabled = G.rush >= cost
		_skip_button.queue_redraw()
		_time_bar.queue_redraw()
	elif phase == "finished": _status.text = TextCatalog.resolve(TextCatalog.source("ui.ordercard.53fd66caee61"))
	else: _status.text = ""

func _action_host(dimensions: Vector2, at: Vector2) -> Control:
	var host := Control.new()
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.size = dimensions
	host.position = at
	host.pivot_offset = dimensions * 0.5
	add_child(host)
	return host

func _start_breath(host: Control) -> void:
	if not is_instance_valid(host) or not host.visible: return
	_breath = host.create_tween().set_loops()
	_breath.tween_property(host, "scale", Vector2.ONE * 1.08, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_breath.tween_property(host, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## 石板侧面那一排：经验、贝壳以外的所有奖励（礼包、token、沙漏、活动积分），图标 + 数字
static func _chips(o: Dictionary) -> Array:
	var out := []
	var rw: Dictionary = o["rw"]
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
	if int(rw.get("sand", 0)) > 0: out.append(["sand_2", int(rw["sand"])])
	if FossilDig.earning(): out.append(["fossil_shovel", FossilDig.order_shovels(o)])
	if DuelRace.active_v3(): out.append(["duel_points", DuelRace.order_score(o)])
	return out

## 右上角的小牌：经验在上，贝壳在下（「+8」）
static func _badges(o: Dictionary) -> Array:
	var out := []
	var rw: Dictionary = o["rw"]
	if int(rw.get("xp", 0)) > 0: out.append(["xp_1", str(int(rw["xp"])), Color("f08a2c")])
	if int(rw.get("shell", 0)) > 0: out.append([CHIP_ICON["shell"], "+%d" % int(rw["shell"]), Color("8a5a32")])
	return out

static func _text_w(t: String, fs: int) -> float:
	if G.font_body == null:
		return 12.0 * float(t.length())
	return G.font_body.get_string_size(TextCatalog.resolve(t), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x

## 图标 30，数字压在图标右下角
static func _chip_w(count: int) -> float:
	return maxf(30.0, 20.0 + _text_w(str(count), 18))

static func _chips_span(chips: Array) -> float:
	if chips.is_empty():
		return 0.0
	var total := 0.0
	for k in chips.size():
		total += _chip_w(int(chips[k][1]))
	total += 6.0 * float(chips.size() - 1)
	return total

static func _badge_w(text: String) -> float:
	return 40.0 + _text_w(text, 20)

static func _badges_w(o: Dictionary) -> float:
	var w := 0.0
	for b in _badges(o): w = maxf(w, _badge_w(str(b[1])))
	return w

static func width_for(o: Dictionary) -> float:
	var chips_w := 16.0 + _chips_span(_chips(o))
	var badges_w := _badges_w(o)
	if str(o.get("kind", "")) == "craft":
		# 小牌贴在木桩右上，左边缘不压住成品太多
		var stump_w := 2.0 * (badges_w + DISH_ICON_SIDE * 0.5 - 4.0) if badges_w > 0.0 else 120.0
		return maxf(maxf(_formula_span(o) + SLAB_PAD * 2.0 + 12.0, chips_w), maxf(stump_w, 150.0))
	var items_w := _items_span(o) + SLAB_PAD * 2.0 + 12.0
	return maxf(maxf(items_w, chips_w), maxf(badges_w + 24.0, 130.0))

func _paint_order(ci: CanvasItem, sz: Vector2) -> void:
	if order.is_empty(): return
	var o: Dictionary = order
	var story: bool = o["story"]
	var craft := str(o.get("kind", "")) == "craft"
	var phase := str(o.get("phase", "need"))
	var ready := G.rules.orders.order_ready(o)
	var slab := Rect2(6, SLAB_Y, sz.x - 12, SLAB_H)
	# 状态光：能交绿、材料齐黄、剧情单金
	var glow := Color(0, 0, 0, 0)
	if ready: glow = Color("8fe05a")
	elif craft and phase == "need" and G.rules.orders.craft_mats_ready(o): glow = Color("ffd23f")
	elif story: glow = Color("ffb347")
	if craft:
		var cx := sz.x * 0.5
		if glow.a > 0.0:
			ci.draw_colored_polygon(Art.ell(Vector2(cx, STUMP_TOP - 14), Vector2(54, 40), 102, 0.0, 24), Color(glow, 0.3))
		Sprites.draw(ci, "board_order_stump", Rect2(cx - 50, STUMP_TOP - 20, 100, 100))
	if glow.a > 0.0: Sprites.draw(ci, "board_order_glow", slab, Color(glow, 0.85))
	Sprites.draw(ci, "board_order_slab", slab)
	if craft:
		var dc := recipe_icon_rect().get_center()
		Art.item(ci, str(o.get("dish", "")), dc, DISH_ICON_SIDE)
		if phase == "ready": _ready_mark(ci, dc, DISH_ICON_SIDE, 1.0)
		if phase == "need" or phase == "cook": _paint_formula(ci, o, sz.x)
	else:
		var spots: Array = _order_item_spots(o, sz.x)
		var boards := []
		var slots := []
		for spot in spots:
			var id := str(spot["id"])
			var c: Vector2 = spot["c"]
			var s: float = float(spot["s"])
			_spot_shadow(ci, c + Vector2(0, s * 0.34), s)
			Art.item(ci, id, c, s)
			if not G.rules.orders.claim_supply(id, boards, slots).is_empty():
				_ready_mark(ci, c, s, 0.9)
	_paint_badges(ci, sz)

## 经验 / 贝壳小牌：墨边圆角牌，图标压在左端，白字带墨边
func _paint_badges(ci: CanvasItem, sz: Vector2) -> void:
	var y := 50.0
	# 几块牌右边缘对齐。制作单贴着木桩右上（压住成品一点边）；普通单靠右
	var right := sz.x - 6.0
	if str(order.get("kind", "")) == "craft":
		right = minf(right, sz.x * 0.5 + DISH_ICON_SIDE * 0.5 - 10.0 + _badges_w(order))
	for b in _badges(order):
		var text := str(b[1])
		var w := _badge_w(text)
		var r := Rect2(right - w, y - 14.0, w, 28.0)
		Sprites.draw(ci, "board_epill_ink", r)
		Sprites.draw(ci, "board_epill_fill", r, b[2])
		Art.item(ci, str(b[0]), Vector2(r.position.x + 14.0, y), 34, false)
		var pos := Vector2(r.position.x + 32.0, y + (G.font_body.get_ascent(20) - G.font_body.get_descent(20)) * 0.5)
		ci.draw_string_outline(G.font_body, pos, TextCatalog.resolve(text), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 5, Art.INK)
		ci.draw_string(G.font_body, pos, TextCatalog.resolve(text), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
		y += 34.0

func _paint_rewards(ci: CanvasItem, sz: Vector2) -> void:
	if order.is_empty(): return
	var chips := _chips(order)
	var chip_y := 20.0
	var x := sz.x * 0.5 - _chips_span(chips) * 0.5
	for k in chips.size():
		var t := str(chips[k][1])
		var id := str(chips[k][0])
		var ic := Vector2(x + 15.0, chip_y - 3.0)
		if id == "fossil_shovel": FossilArt.shovel(ci, ic, 26)
		elif id == "duel_points": Sprites.at(ci, "ev_entry_duel", ic, 0.3)
		else: Art.item(ci, id, ic, 30, false)
		var pos := Vector2(x + 20.0, chip_y + 11.0)
		ci.draw_string_outline(G.font_body, pos, TextCatalog.resolve(t), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, Art.INK)
		ci.draw_string(G.font_body, pos, TextCatalog.resolve(t), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
		x += _chip_w(int(chips[k][1])) + 6.0

func cooking_progress() -> float:
	if str(order.get("phase", "need")) == "need": return 0.0
	var at := int(order.get("cell", -1))
	var duration := float(order.get("secs", 1))
	if at >= 0 and at < G.board.size() and G.board[at].get("ck") is Dictionary:
		duration = float(G.board[at]["ck"].get("secs", duration))
	return clampf(1.0 - float(G.rules.orders.cook_left(at)) / maxf(1.0, duration), 0.0, 1.0)

## 正在做：左边一个小闹钟，右边火色进度条，条上写剩余时间（「6秒」「2分05秒」这种短写法）
func _paint_cook_time(ci: CanvasItem, sz: Vector2) -> void:
	var clock := Vector2(16, sz.y * 0.5)
	var bar := Rect2(clock.x + 8, sz.y * 0.5 - 12, sz.x - clock.x - 8, 24)
	Paint.bar(ci, bar, cooking_progress(), Color("f08a2c"))
	_paint_clock(ci, clock, 15.0)
	var text := TextCatalog.resolve(Board._sec_text(G.rules.orders.cook_left(int(order.get("cell", -1)))))
	var font: Font = G.font_body
	var fs := 18
	var tw := font.get_string_size(TextCatalog.resolve(text), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var at := Vector2(bar.position.x + 10 + (bar.size.x - 10 - tw) * 0.5, sz.y * 0.5 + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5)
	ci.draw_string_outline(font, at, TextCatalog.resolve(text), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Art.INK)
	ci.draw_string(font, at, TextCatalog.resolve(text), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)

## 小闹钟：墨边奶白钟面，分针跟着进度转
func _paint_clock(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_circle(c, r + 2.5, Art.INK)
	ci.draw_circle(c, r, Color("f08a2c"))
	ci.draw_circle(c, r - 3.5, Art.BONE)
	for k in 4:
		var d := Vector2.UP.rotated(PI * 0.5 * k)
		ci.draw_line(c + d * (r - 6.5), c + d * (r - 4.5), Art.INK, 2.0, true)
	var a := TAU * cooking_progress() - PI * 0.5
	ci.draw_line(c, c + Vector2(cos(a), sin(a)) * (r - 6.0), Art.INK, 2.4, true)
	ci.draw_line(c, c + Vector2(0, -1).rotated(-0.9) * (r - 8.5), Art.INK, 2.4, true)
	ci.draw_circle(c, 2.2, Art.INK)

func _paint_formula(ci: CanvasItem, o: Dictionary, width: float) -> void:
	var spots: Array = _formula_spots(o, width)
	var boards := []
	var slots := []
	var phase := str(o.get("phase", "need"))
	for spot in spots:
		var id := str(spot["id"])
		var c: Vector2 = spot["c"]
		var icon: float = float(spot["s"])
		_spot_shadow(ci, c + Vector2(0, icon * 0.34), icon)
		Art.item(ci, id, c, icon)
		if phase == "need" and not G.rules.orders.claim_supply(id, boards, slots).is_empty():
			_ready_mark(ci, c, icon, 0.72)

## 石板上一排物品，居中，不重叠
static func _order_item_spots(o: Dictionary, width: float) -> Array:
	var items: Array = o.get("items", [])
	var n := items.size()
	var out: Array = []
	var s: float = 60.0 if n == 1 else 54.0
	for ik in n:
		var x: float = width * 0.5 + (float(ik) - float(n - 1) * 0.5) * (s + 6.0)
		out.append({"id": str(items[ik]), "c": Vector2(x, SLAB_ITEM_Y), "s": s})
	return out

static func _items_span(o: Dictionary) -> float:
	var n: int = o.get("items", []).size()
	if n == 0: return 0.0
	var s: float = 60.0 if n == 1 else 54.0
	return s + float(n - 1) * (s + 6.0)

## 制作原料：石板上一排，略微叠着
static func _formula_spots(o: Dictionary, width: float) -> Array:
	var mats: Array = o.get("mats", [])
	var n := mats.size()
	var out: Array = []
	var icon: float = 50.0 if n >= 4 else 54.0
	var step: float = icon * 0.72
	var left: float = (width - _formula_span(o)) * 0.5
	for k in n:
		out.append({"id": str(mats[k]), "c": Vector2(left + icon * 0.5, SLAB_ITEM_Y), "s": icon})
		left += step
	return out

static func _formula_span(o: Dictionary) -> float:
	var n: int = o.get("mats", []).size()
	if n == 0: return 0.0
	var icon: float = 50.0 if n >= 4 else 54.0
	return icon + float(n - 1) * icon * 0.72

## 材料已在棋盘上：单独一个绿色对勾，在物品右下角。
static func _ready_mark(ci: CanvasItem, c: Vector2, item_s: float, scale: float) -> void:
	Paint.check_tick(ci, Vector2(c.x + item_s * 0.32, c.y + item_s * 0.5 - 8.0 * scale), scale)

## 石板台面上物品脚下的一小片影子
static func _spot_shadow(ci: CanvasItem, c: Vector2, s: float) -> void:
	ci.draw_colored_polygon(Art.ell(c + Vector2(0, s * 0.1), Vector2(s * 0.38, s * 0.1), 104, 0.0, 16), Color(0.25, 0.2, 0.15, 0.25))
