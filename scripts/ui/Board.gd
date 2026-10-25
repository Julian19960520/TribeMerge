class_name Board
extends Control
## 7×9 合成棋盘

signal selected_changed(i: int)
signal activated(i: int)
signal dropped_outside(i: int, global_pos: Vector2)

const CELL := 96.0
const ITEM := 84.0

var selected := -1
var press_cell := -1
var press_pos := Vector2.ZERO
var dragging := false
var drag_from := -1
var drag_pos := Vector2.ZERO
var drag_vis := Vector2.ZERO
var pops := {}
var hid := {}
var flights: Array = []
var moves: Array = []
var bursts: Array = []
var shakes := {}
var _t := 0.0

const DRAG_LIFT := Vector2(0, -14)
const MOVE_DUR := 0.26
## 越大越跟手
const DRAG_FOLLOW := 32.0

func _ready() -> void:
	size = Vector2(G.COLS * CELL, G.ROWS * CELL)
	mouse_filter = MOUSE_FILTER_STOP
	G.boil_tick.connect(queue_redraw)
	G.board_changed.connect(queue_redraw)
	G.orders_changed.connect(queue_redraw)

func _process(delta: float) -> void:
	_t += delta
	if dragging:
		drag_vis = drag_vis.lerp(drag_pos, 1.0 - exp(-delta * DRAG_FOLLOW))
	for m in moves:
		m["t"] += delta / float(m["dur"])
	for m in moves.duplicate():
		if m["t"] >= 1.0:
			moves.erase(m)
			_move_done(m)
	var busy := dragging or not pops.is_empty() or not flights.is_empty() or not bursts.is_empty() or not shakes.is_empty() or not moves.is_empty()
	for k in pops.keys():
		pops[k] += delta
		if pops[k] > 0.35:
			pops.erase(k)
	for k in shakes.keys():
		shakes[k] += delta
		if shakes[k] > 0.35:
			shakes.erase(k)
	for f in flights:
		f["t"] += delta / 0.28
	for f in flights.duplicate():
		if f["t"] >= 1.0:
			flights.erase(f)
			_unhide(f["to"])
			pop(f["to"])
	for b in bursts:
		b["t"] += delta
	bursts = bursts.filter(func(b): return b["t"] < 0.6)
	if busy:
		queue_redraw()

func cell_rect(i: int) -> Rect2:
	return Rect2(Vector2(i % G.COLS, i / G.COLS) * CELL, Vector2(CELL, CELL))

func cell_center(i: int) -> Vector2:
	return cell_rect(i).get_center()

func cell_global(i: int) -> Vector2:
	return get_global_transform() * cell_center(i)

func cell_at(p: Vector2) -> int:
	if p.x < 0 or p.y < 0 or p.x >= size.x or p.y >= size.y:
		return -1
	return int(p.y / CELL) * G.COLS + int(p.x / CELL)

func pop(i: int) -> void:
	pops[i] = 0.0

func shake(i: int) -> void:
	shakes[i] = 0.0

func burst(i: int) -> void:
	bursts.append({"p": cell_center(i), "t": 0.0, "seed": randi() % 1000})

func fly_in(from_i: int, to_i: int, id: String) -> void:
	hid[to_i] = int(hid.get(to_i, 0)) + 1
	flights.append({"from": cell_center(from_i), "to": to_i, "id": id, "t": 0.0})

func fly_in_from(global_from: Vector2, to_i: int, id: String) -> void:
	hid[to_i] = int(hid.get(to_i, 0)) + 1
	flights.append({"from": get_global_transform().affine_inverse() * global_from, "to": to_i, "id": id, "t": 0.0})

func select(i: int) -> void:
	selected = i
	selected_changed.emit(i)
	queue_redraw()

## 物品从 from（本地坐标）滑到格子 to，带 back 缓动；滑动期间该格不绘制
func slide(id: String, from: Vector2, to: int, under: String = "", done: String = "pop", dur: float = MOVE_DUR) -> void:
	hid[to] = int(hid.get(to, 0)) + 1
	moves.append({"id": id, "from": from, "to": to, "under": under, "done": done, "t": 0.0, "dur": dur})

func cancel_slides(i: int) -> void:
	for m in moves.duplicate():
		if m["to"] == i:
			moves.erase(m)
			_unhide(i)

func _unhide(i: int) -> void:
	var n := int(hid.get(i, 0)) - 1
	if n <= 0:
		hid.erase(i)
	else:
		hid[i] = n

func _move_done(m: Dictionary) -> void:
	var i: int = m["to"]
	_unhide(i)
	match m["done"]:
		"merge":
			Sfx.play("merge", 0.9 + 0.08 * float(Data.lv(G.cell_id(i))))
			burst(i)
			pop(i)
		"pop":
			pop(i)
	queue_redraw()

static func ease_back(t: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(t - 1.0, 3.0) + c1 * pow(t - 1.0, 2.0)

# ---------------------------------------------------------------- 输入

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			press_cell = cell_at(e.position)
			press_pos = e.position
			dragging = false
		else:
			if dragging:
				_drop(e.position)
			elif press_cell >= 0 and cell_at(e.position) == press_cell:
				_tap(press_cell)
			press_cell = -1
			dragging = false
			drag_from = -1
			queue_redraw()
	elif e is InputEventMouseMotion and press_cell >= 0:
		if not dragging and e.position.distance_to(press_pos) > 10.0:
			var c: Dictionary = G.board[press_cell]
			if c["id"] != "" and c["lock"] == 0 and not hid.has(press_cell):
				dragging = true
				drag_from = press_cell
				drag_vis = cell_center(press_cell) - DRAG_LIFT
				select(press_cell)
				Sfx.play("tap", 1.3)
		if dragging:
			drag_pos = e.position

func _tap(i: int) -> void:
	var c: Dictionary = G.board[i]
	if c["id"] == "":
		select(-1)
		return
	if selected == i and c["lock"] == 0:
		pop(i)
		activated.emit(i)
	else:
		Sfx.play("tap")
		pop(i)
		select(i)

func _drop(p: Vector2) -> void:
	var from := drag_from
	var vis := drag_vis + DRAG_LIFT
	var id_from := G.cell_id(from)
	var to := cell_at(p)
	if to < 0:
		slide(id_from, vis, from)
		dropped_outside.emit(from, get_global_transform() * p)
		return
	var id_to := G.cell_id(to)
	var res := G.try_drop(from, to)
	match res:
		"merge":
			slide(id_from, vis, to, id_to, "merge", 0.16)
			select(to)
			if G.main:
				G.main.on_merged(to)
		"move", "swap":
			Sfx.play("pop", 0.9)
			slide(id_from, vis, to)
			if res == "swap":
				slide(id_to, cell_center(to), from)
			select(to)
		_:
			slide(id_from, vis, from)
			if to != from:
				Sfx.play("deny")
				shake(to)

# ---------------------------------------------------------------- 绘制

func _draw() -> void:
	var frame := Art.rrect(Rect2(-14, -14, size.x + 28, size.y + 28), 22, 77, 1.0)
	Art.dilate(self, frame, 3.0, Art.INK)
	draw_colored_polygon(frame, Art.LEATHER)
	Art.dashed(self, Art.rrect(Rect2(-7, -7, size.x + 14, size.y + 14), 16, 78, 0.0), 11, 7, Color("f3d7a2"), 2.2)
	draw_rect(Rect2(Vector2.ZERO, size), Art.HIDE2)
	var wanted := G.wanted_ids()
	for i in G.board.size():
		var r := cell_rect(i)
		var c: Dictionary = G.board[i]
		var col := Art.HIDE if (i % G.COLS + i / G.COLS) % 2 == 0 else Color("f0dcb4")
		if c["lock"] == 0 and wanted.has(c["id"]) and not hid.has(i):
			col = Color("a8d86a")
		draw_rect(r.grow(-1.5), col)
	for i in G.board.size():
		if i == drag_from and dragging:
			continue
		if hid.has(i):
			continue
		_draw_cell(i)
	var sel_c := cell_center(selected) if selected >= 0 else Vector2.ZERO
	for m in moves:
		var to := cell_center(m["to"])
		var p: Vector2 = m["from"].lerp(to, ease_back(clampf(m["t"], 0.0, 1.0)))
		if m["under"] != "":
			Art.item(self, m["under"], to, ITEM)
		Art.item(self, m["id"], p, ITEM * lerpf(1.15, 1.0, clampf(m["t"] * 1.5, 0.0, 1.0)))
		if m["to"] == selected and m["under"] == "":
			sel_c = p
	if selected >= 0 and not dragging:
		var pulse := 1.0 + 0.04 * sin(_t * 6.0)
		var sz := Vector2(CELL, CELL) * pulse
		Paint.cell_bracket(self, Rect2(sel_c - sz * 0.5, sz).grow(-4))
	for f in flights:
		var t: float = f["t"]
		var e := 1.0 - pow(1.0 - t, 3.0)
		var to := cell_center(f["to"])
		var p: Vector2 = f["from"].lerp(to, e) + Vector2(0, -80.0 * sin(PI * t))
		Art.item(self, f["id"], p, ITEM * (0.7 + 0.3 * e))
	for b in bursts:
		_draw_burst(b)
	if dragging and drag_from >= 0:
		var r0 := cell_rect(drag_from)
		draw_rect(r0.grow(-6), Color(0.3, 0.2, 0.1, 0.12))
		var hov := cell_at(drag_pos)
		if hov >= 0 and hov != drag_from:
			var ok: bool = G.board[hov]["id"] == G.board[drag_from]["id"] and Data.next_id(G.board[drag_from]["id"]) != "" and G.board[hov]["lock"] != 2
			if ok:
				draw_colored_polygon(Art.rrect(cell_rect(hov).grow(-3), 16, hov, 0.0), Color(1, 0.85, 0.2, 0.45))
		var tilt := clampf((drag_pos.x - drag_vis.x) * 0.004, -0.25, 0.25)
		Art.item(self, G.board[drag_from]["id"], drag_vis + DRAG_LIFT, ITEM * 1.15, true, tilt)

func _draw_cell(i: int) -> void:
	var c: Dictionary = G.board[i]
	var r := cell_rect(i)
	var ctr := r.get_center()
	var sc := 1.0
	if pops.has(i):
		var t: float = pops[i] / 0.35
		sc = 1.0 + 0.28 * sin(PI * t) * (1.0 - t * 0.5)
	if shakes.has(i):
		ctr.x += sin(shakes[i] * 60.0) * 6.0 * (1.0 - shakes[i] / 0.35)
	if c["lock"] == 2:
		_draw_rock(r, i)
		return
	if c["id"] == "":
		return
	if c["lock"] == 0 and Data.type_of(c["id"]) == "gen":
		draw_colored_polygon(Art.rrect(r.grow(-6), 14, i, 0.6), Color(1, 0.86, 0.45, 0.55))
		Art.outline(self, Art.rrect(r.grow(-6), 14, i, 0.6), 2.0, Color(0.7, 0.45, 0.1, 0.6))
	Art.item(self, c["id"], ctr, ITEM * sc)
	if c["lock"] == 1:
		_draw_vine(r, i)
	elif Data.type_of(c["id"]) == "gen" and G.energy > 0:
		var bolt := Art.flame_pts(r.position + Vector2(80, 78), 7, 18, i)
		Art.fill(self, bolt, Art.FIRE2, 2.0)

## 巨石：不规则多边形大石 + 小石块 + 裂纹 + 青苔
func _draw_rock(r: Rect2, i: int) -> void:
	var c := r.get_center() + Vector2(0, 4)
	var base := []
	for k in 9:
		var a := TAU * float(k) / 9.0 + Art.srnd(i * 13 + k) * 0.3
		var rad := 36.0 + Art.srnd(i * 7 + k) * 8.0
		base.append(c + Vector2(cos(a) * rad * 1.08, sin(a) * rad * 0.9))
	var big := Art.poly(base, i, 0.8)
	draw_colored_polygon(Art.ell(c + Vector2(0, 30), Vector2(38, 9), i, 0.0, 14), Color(0, 0, 0, 0.18))
	var small := Art.poly([c + Vector2(18, 14), c + Vector2(38, 8), c + Vector2(46, 26), c + Vector2(30, 36), c + Vector2(14, 30)], i + 5, 0.6)
	Art.sil(self, [Art.P(big, Color("a39b8d"), 1), Art.P(small, Color("8c8476"), 1)], false, 3.0)
	var top := Art.poly([c + Vector2(-26, -18), c + Vector2(-6, -32), c + Vector2(18, -26), c + Vector2(6, -10), c + Vector2(-16, -6)], i + 9, 0.6)
	draw_colored_polygon(top, Color(1, 1, 1, 0.22))
	var crack := Color(0.25, 0.2, 0.15, 0.75)
	Art.pl(self, [c + Vector2(-4, -10), c + Vector2(4, 4), c + Vector2(-2, 14), c + Vector2(6, 26)], 2.4, crack, i + 2)
	Art.pl(self, [c + Vector2(4, 4), c + Vector2(16, 0)], 2.0, crack, i + 3)
	Art.pl(self, [c + Vector2(-30, 6), c + Vector2(-20, 12), c + Vector2(-22, 22)], 2.0, crack, i + 4)
	var moss := Art.ell(c + Vector2(-20, -24), Vector2(15, 7), i + 6, 0.12, 12, -0.4)
	Art.fill(self, moss, Art.MOSS, 2.0)
	draw_colored_polygon(Art.ell(c + Vector2(-24, -26), Vector2(6, 3), i + 7, 0.0, 8, -0.4), Color(1, 1, 1, 0.35))
	for k in 3:
		draw_circle(c + Vector2(-8 + k * 12, 22 - (k % 2) * 6), 1.6, Color(0.3, 0.25, 0.2, 0.5))

func _draw_vine(r: Rect2, i: int) -> void:
	draw_rect(r.grow(-3), Color(0.25, 0.4, 0.1, 0.28))
	var p := r.position
	Art.pl(self, [p + Vector2(4, 30), p + Vector2(30, 46), p + Vector2(56, 34), p + Vector2(92, 52)], 7.0, Art.INK, i)
	Art.pl(self, [p + Vector2(4, 30), p + Vector2(30, 46), p + Vector2(56, 34), p + Vector2(92, 52)], 4.0, Art.LEAF_D, i)
	Art.pl(self, [p + Vector2(10, 92), p + Vector2(34, 66), p + Vector2(64, 76), p + Vector2(88, 6)], 7.0, Art.INK, i + 3)
	Art.pl(self, [p + Vector2(10, 92), p + Vector2(34, 66), p + Vector2(64, 76), p + Vector2(88, 6)], 4.0, Art.LEAF_D, i + 3)
	for lp in [Vector2(30, 46), Vector2(64, 76), Vector2(80, 30)]:
		var v := Art.ell(p + lp, Vector2(9, 5), i + int(lp.x), 0.05, 10, 0.6)
		Art.fill(self, v, Art.LEAF, 2.0)

func _draw_burst(b: Dictionary) -> void:
	var t: float = b["t"] / 0.6
	var p: Vector2 = b["p"]
	var rr := 20.0 + 70.0 * t
	draw_arc(p, rr, 0, TAU, 32, Color(1, 0.9, 0.4, 1.0 - t), 6.0 * (1.0 - t) + 1.0, true)
	for k in 8:
		var a := TAU * float(k) / 8.0 + float(b["seed"])
		var q := p + Vector2(cos(a), sin(a)) * (30.0 + 80.0 * t)
		var star := Art.star_pts(q, 10.0 * (1.0 - t) + 2.0, 4.0 * (1.0 - t) + 1.0, 4, k)
		draw_colored_polygon(star, Color(Art.FIRE2, 1.0 - t))
	for k in 5:
		var a := TAU * float(k) / 5.0 + 0.4 + float(b["seed"])
		var q := p + Vector2(cos(a), sin(a)) * (20.0 + 50.0 * t) + Vector2(0, 30.0 * t * t)
		draw_circle(q, 8.0 * (1.0 - t) + 2.0, Color(1, 1, 1, 0.8 * (1.0 - t)))
