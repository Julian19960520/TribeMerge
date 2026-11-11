class_name OrderCard
extends DrawBox
## One persistent order card; callbacks follow the current order index after sorting.
signal craft_requested(index: int)
signal delivery_requested(index: int)
const Meme := preload("res://scripts/Meme.gd")
const CHIP_ICON := {"shell": "shell_2", "pack": "pack_1", "token": "token_1"}
var order_index := -1
var order: Dictionary = {}
var _state_signature := ""
var _shape_signature := ""
var _name: Label
var _make_host: Control
var _deliver_host: Control
var _was_ready := false
var _breath: Tween

func _ready() -> void:
	painter = _paint_order
	super._ready()

static func missing(o: Dictionary) -> int:
	if str(o.get("kind", "")) == "craft" and str(o.get("phase", "need")) != "need": return 0
	var ids: Array = o["mats"] if str(o.get("kind", "")) == "craft" else o["items"]
	var used := []
	for id in ids:
		var cell := G.rules.orders.board_has(str(id), used)
		if cell >= 0: used.append(cell)
	return ids.size() - used.size()

func refresh(index: int, value: Dictionary) -> void:
	order_index = index
	order = value
	var shape := JSON.stringify([order.get("who", 0), order.get("items", []), order.get("mats", []), order.get("rw", {}), order.get("kind", ""), FossilDig.earning()])
	if shape != _shape_signature:
		_shape_signature = shape
		_build_content()
	var ready := G.rules.orders.order_ready(order)
	var can_make := G.rules.orders.craft_mats_ready(order)
	var matched := []
	var availability := []
	for id in order.get("mats", order.get("items", [])):
		var cell := G.rules.orders.board_has(str(id), matched)
		if cell >= 0: matched.append(cell)
		availability.append(cell >= 0)
	var signature := JSON.stringify([shape, order.get("phase", "need"), ready, can_make, availability, FossilDig.earning()])
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
	size = Vector2(width_for(order), 216.0)
	var name_w := size.x - 96.0
	if str(order.get("kind", "")) == "craft": name_w = size.x - 168.0
	elif int(order["rw"].get("xp", 0)) > 0: name_w = size.x - 144.0
	_name = UI.lbl(self, Meme.customer_name(int(order["who"]), true), Rect2(92, 30, name_w, 32), 20, Art.INK, HORIZONTAL_ALIGNMENT_LEFT)
	var spots := _formula_spots(order, size.x) if str(order.get("kind", "")) == "craft" else _order_item_spots(order, size.x)
	for spot in spots:
		var id := str(spot["id"])
		var at: Vector2 = spot["c"]
		var side := float(spot["s"])
		UI.hit(self, Rect2(at - Vector2.ONE * side * 0.5, Vector2.ONE * side), func(): G.main.open("item_info", id))
	_make_host = _action_host(Vector2(112, 52), Vector2(size.x * 0.5 - 56, size.y - 48))
	var make := UI.btn(_make_host, Rect2(Vector2.ZERO, _make_host.size), "制作", "orange", func(): craft_requested.emit(order_index), 28)
	make.sound = "pop"
	_deliver_host = _action_host(Vector2(72, 72), Vector2(size.x * 0.5 - 36, size.y - 40))
	var deliver := UI.btn(_deliver_host, Rect2(Vector2.ZERO, _deliver_host.size), "", "green", func(): delivery_requested.emit(order_index))
	deliver.is_round = true
	deliver.sound = "coin"
	deliver.extra = func(ci, sz):
		var center: Vector2 = sz * 0.5
		var points := PackedVector2Array([center + Vector2(-16, 1), center + Vector2(-4, 14), center + Vector2(18, -12)])
		ci.draw_polyline(points, Color.WHITE, 6.0, true)
		for point in points: ci.draw_circle(point, 3.0, Color.WHITE)
	_was_ready = false

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
	if FossilDig.earning(): out.append(["fossil_shovel", int(FossilDig.config()["shovels_per_order"])])
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

static func width_for(o: Dictionary) -> float:
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

func _paint_order(ci: CanvasItem, sz: Vector2) -> void:
	if order.is_empty(): return
	var o: Dictionary = order
	var story: bool = o["story"]
	var craft := str(o.get("kind", "")) == "craft"
	var phase := str(o.get("phase", "need"))
	var ready := G.rules.orders.order_ready(o)
	var r := Rect2(4, 20, sz.x - 8, sz.y - 24)
	Sprites.draw(ci, "board_card_base", r)
	var bg := Color("fbf0d6")
	if story:
		bg = Color("ffe9a8")
	if craft and phase == "cook":
		bg = Color("ffe4c4")
	elif craft and G.rules.orders.craft_mats_ready(o):
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
			var cell := G.rules.orders.board_has(id, used)
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
		if str(chips[k][0]) == "fossil_shovel": FossilArt.shovel(ci, Vector2(x + 12.0, chip_y), 30)
		else: Art.item(ci, str(chips[k][0]), Vector2(x + 12.0, chip_y), 36, false)
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
			var cell := G.rules.orders.board_has(id, used)
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
