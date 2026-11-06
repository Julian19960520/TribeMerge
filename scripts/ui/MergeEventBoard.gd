class_name MergeEventBoard
extends Control
## 月石遗迹活动棋盘。三种格子状态一眼可分：
## 覆盖（lock=2）= 爬满藤蔓、刻着月纹的凸起石板，看不到物品；
## 显示但锁定（lock=1）= 凹陷的暗色石槽，物品冷色半透明，藤蔓缠角 + 石锁；
## 开放（lock=0）= 暖色砂岩地砖，物品全彩可拖动。
signal selection_changed(id: String, locked: bool)
signal action_finished(result: Dictionary)
var cfg: Dictionary
var cell := 96.0
var camera := 0.0
var selected := -1
var pressed := -1
var press_pos := Vector2.ZERO
var dragging := false
var cursor := Vector2.ZERO
var animating := false
var moves: Array = []
## 落地回弹（0→1）、覆盖石板掀开（0→1）、正在飞入的投放格。
var pops: Dictionary = {}
var lifts: Dictionary = {}
var incoming: Dictionary = {}
## 面板提供的特效层：fx.call(kind, 面板坐标, data)。
var fx: Callable
## 投放的遗物从这里（面板坐标）飞进棋盘。
var spawn_origin := Vector2.ZERO
var _t := 0.0
var _camera_tween: Tween

const INK := Color("3b2314")

func _ready() -> void:
	clip_contents = true
	mouse_filter = MOUSE_FILTER_STOP
	cell = size.x / int(cfg["board"]["cols"])
	camera = float(MergeEvent.state(cfg)["view"])
	G.merge_event_changed.connect(queue_redraw)
	G.boil_tick.connect(queue_redraw)

func center(i: int) -> Vector2:
	var cols := int(cfg["board"]["cols"])
	return Vector2((i % cols + 0.5) * cell, (i / cols - camera + 0.5) * cell)

func at(p: Vector2) -> int:
	var visible_index := MergeGrid.cell_at(p, cell, int(cfg["board"]["cols"]), int(cfg["board"]["visible_rows"]))
	return visible_index + int(round(camera)) * int(cfg["board"]["cols"]) if visible_index >= 0 else -1

func _color(key: String, fallback: String) -> Color:
	return Color(str(cfg["theme"].get(key, fallback)))

func _fx(kind: String, local: Vector2, data: Dictionary = {}) -> void:
	if fx.is_valid(): fx.call(kind, position + local, data)

func _sync_camera() -> void:
	var to := float(MergeEvent.state(cfg)["view"])
	if is_equal_approx(to, camera): return
	animating = true
	selected = -1
	selection_changed.emit("", false)
	if _camera_tween and _camera_tween.is_valid(): _camera_tween.kill()
	_camera_tween = create_tween()
	_camera_tween.tween_method(func(v): camera = v; queue_redraw(), camera, to, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_camera_tween.tween_callback(func():
		animating = false
		_fx("text", Vector2(size.x / 2, cell * 0.9), {"text": "更深的遗迹露出来了", "color": Color("bff3f0"), "size": 30}))
	Sfx.play("whoosh")

func _process(delta: float) -> void:
	_t += delta
	var busy := false
	if not moves.is_empty():
		busy = true
		for m in moves: m["t"] = minf(1, float(m["t"]) + delta / 0.22)
		for m in moves.filter(func(m): return float(m["t"]) >= 1): _landed(m)
		moves = moves.filter(func(m): return float(m["t"]) < 1)
		if moves.is_empty():
			animating = not incoming.is_empty()
			if not animating: _sync_camera()
	for d in [pops, lifts]:
		for k in d.keys():
			d[k] = float(d[k]) + delta / (0.42 if d == pops else 0.5)
			if float(d[k]) >= 1: d.erase(k)
			busy = true
	if busy or _hint_id() != "": queue_redraw()

## 落地后的反馈：合成闪光、解锁落叶、揭开石板。
func _landed(m: Dictionary) -> void:
	var i := int(m["to"])
	pops[i] = 0.0
	var r: Dictionary = m.get("result", {})
	if r.is_empty(): return
	var at_px := center(i)
	if str(r.get("kind", "")) == "merge":
		if bool(r.get("unlocked", false)):
			_fx("leaves", at_px, {"color": _color("vine", "7fae5a")})
			_fx("text", at_px + Vector2(0, -cell * 0.45), {"text": "解锁！", "color": Color("fff3a6"), "size": 30})
			Sfx.play("crumble")
		_fx("spark", at_px, {})
		for k in r.get("revealed", []):
			lifts[int(k)] = 0.0
			_fx("dust", center(int(k)), {"color": _color("covered", "6e8d93")})

func _hint_id() -> String:
	var s := MergeEvent.state(cfg)
	var k := pressed if dragging else selected
	if k < 0 or k >= s["cells"].size(): return ""
	var c: Dictionary = s["cells"][k]
	return str(c["id"]) if int(c["lock"]) == 0 else ""

func _draw() -> void:
	if cfg.is_empty(): return
	var s := MergeEvent.state(cfg)
	var cells: Array = s["cells"]
	var cols := int(cfg["board"]["cols"])
	draw_rect(Rect2(Vector2.ZERO, size), _color("recess", "2f5058").darkened(0.55))
	var hint := _hint_id()
	var pulse := 0.5 + 0.5 * sin(_t * 6.0)
	var first := maxi(0, int(floor(camera)))
	var last := mini(int(cfg["board"]["total_rows"]), int(ceil(camera)) + int(cfg["board"]["visible_rows"]))
	for row in range(first, last):
		for col in cols:
			var i := row * cols + col
			var c: Dictionary = cells[i]
			var ctr := center(i)
			var r := Rect2(ctr - Vector2.ONE * cell / 2, Vector2.ONE * cell)
			var lock := int(c["lock"])
			var id := str(c["id"])
			if lock == 0: _floor(r, i, row + col)
			else: _recess(r, i)
			var moving := dragging and i == pressed
			for m in moves:
				if int(m["to"]) == i: moving = true
			if incoming.has(i): moving = true
			if lock == 0:
				if hint != "" and id == hint and i != pressed and i != selected:
					_glow(r, Color("fff3a6"), 0.25 + 0.35 * pulse)
				if id != "" and not moving:
					MergeEvent.draw_item(self, cfg, id, ctr + Vector2(0, -2), cell * 0.84 * _pop(i))
			elif lock == 1:
				if hint != "" and id == hint: _glow(r, Color("b8ff7a"), 0.45 + 0.5 * pulse)
				if not moving: MergeEvent.draw_item(self, cfg, id, ctr + Vector2(0, -1), cell * 0.72, Color(0.66, 0.86, 0.95, 0.82))
				_vines(r, i)
				_lock_badge(ctr + Vector2(cell * 0.3, cell * 0.3))
			else:
				_slab(r, i, 1.0, _frontier(cells, i, cols))
			if lifts.has(i):
				var t := float(lifts[i])
				draw_set_transform(ctr + Vector2(0, -t * cell * 0.35), (Art.srnd(i) - 0.5) * t * 0.6, Vector2.ONE * (1.0 + 0.2 * t))
				_slab(Rect2(-Vector2.ONE * cell / 2, Vector2.ONE * cell), i, 1.0 - t, false)
				draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
			if i == selected: Paint.cell_bracket(self, r.grow(-2), Color("ffe58a"))
	for m in moves:
		var t := float(m["t"])
		var p: Vector2 = (m["from"] as Vector2).lerp(center(int(m["to"])), MergeGrid.ease_back(t))
		MergeEvent.draw_item(self, cfg, str(m["id"]), p, cell * 0.9)
	if dragging and pressed >= 0:
		draw_circle(cursor + Vector2(0, 18), cell * 0.32, Color(0, 0, 0, 0.18))
		MergeEvent.draw_item(self, cfg, str(cells[pressed]["id"]), cursor + Vector2(0, -18), cell * 1.0)

func _pop(i: int) -> float:
	if not pops.has(i): return 1.0
	var t := float(pops[i])
	return 1.0 + 0.28 * sin(t * PI * 2.0) * (1.0 - t)

func _frontier(cells: Array, i: int, cols: int) -> bool:
	for k in MergeGrid.neighbors(i, cols, cells.size()):
		if int(cells[k]["lock"]) == 0: return true
	return false

func _glow(r: Rect2, col: Color, a: float) -> void:
	var pts := Art.rrect(r.grow(-3), 14, 77, 0.0)
	draw_colored_polygon(pts, Color(col, a * 0.35))
	Art.outline(self, pts, 4.0, Color(col, a))

## 开放格：暖色砂岩，月光下的旧地砖。
func _floor(r: Rect2, i: int, parity: int) -> void:
	var base := _color("tile", "e6d9b2") if parity % 2 == 0 else _color("tile_alt", "d9c99c")
	var pts := Art.rrect(r.grow(-2.5), 12, 700 + i, 0.5)
	draw_colored_polygon(pts, base)
	draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(4, r.size.y * 0.7), Vector2(r.size.x - 8, r.size.y * 0.26)), 10, 900 + i, 0.3), Color(0.45, 0.3, 0.12, 0.1))
	draw_line(r.position + Vector2(12, 8), r.position + Vector2(r.size.x - 14, 8), Color(1, 1, 1, 0.35), 2.5)
	for k in 3:
		var p := r.position + Vector2(0.15 + Art.srnd(i * 7 + k) * 0.7, 0.2 + Art.srnd(i * 13 + k) * 0.65) * r.size
		draw_circle(p, 1.4 + Art.srnd(i + k * 5) * 2.2, Color(0.42, 0.28, 0.12, 0.13))
	Art.outline(self, pts, 1.6, Color(0.36, 0.25, 0.13, 0.35))

## 已显示但锁定：凹陷的暗石槽。
func _recess(r: Rect2, i: int) -> void:
	var pts := Art.rrect(r.grow(-2.5), 12, 300 + i, 0.5)
	draw_colored_polygon(pts, _color("recess", "2f5058"))
	draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(4, 4), Vector2(r.size.x - 8, r.size.y * 0.32)), 10, 310 + i, 0.3), Color(0, 0, 0, 0.2))
	Art.outline(self, pts, 2.0, Color(_color("glow", "bff3f0"), 0.22))

## 覆盖格：爬满藤蔓的月纹石板（每块的月纹、裂缝、藤蔓都不同）。
func _slab(r: Rect2, i: int, alpha: float, frontier: bool) -> void:
	if alpha <= 0.01: return
	var h := Art.srnd(i * 3 + 1)
	var base := _color("covered", "6e8d93").lerp(_color("covered_alt", "7f9a97"), h)
	if frontier: base = base.lightened(0.1)
	var ink := Color(INK, alpha)
	var face := Rect2(r.position + Vector2(4, 3), r.size - Vector2(8, 12))
	var side := Art.rrect(Rect2(face.position + Vector2(0, 7), face.size), 13, 100 + i, 0.6)
	Art.dilate(self, side, 2.5, ink)
	draw_colored_polygon(side, Color(base.darkened(0.42), alpha))
	var top := Art.rrect(face, 13, 120 + i, 0.6)
	Art.dilate(self, top, 2.5, ink)
	draw_colored_polygon(top, Color(base, alpha))
	draw_colored_polygon(Art.rrect(Rect2(face.position + Vector2(face.size.x * 0.5, face.size.y * 0.45), face.size * Vector2(0.48, 0.52)), 11, 140 + i, 0.3), Color(0, 0, 0, 0.1 * alpha))
	draw_polyline(PackedVector2Array([face.position + Vector2(9, face.size.y - 16), face.position + Vector2(8, 12), face.position + Vector2(face.size.x - 16, 8)]), Color(1, 1, 1, 0.28 * alpha), 3.0)
	if frontier:
		Art.outline(self, top, 2.0, Color(_color("glow", "bff3f0"), 0.45 * alpha))
	_rune(face.get_center() + Vector2(0, 1), cell * 0.17, int(Art.srnd(i * 11 + 5) * 5.0), base, alpha)
	if Art.srnd(i * 5 + 2) > 0.45:
		var a := face.position + Vector2(face.size.x * (0.6 + Art.srnd(i) * 0.3), face.size.y - 3)
		draw_polyline(PackedVector2Array([a, a + Vector2(-6, -10), a + Vector2(-3, -18), a + Vector2(-10, -26)]), Color(base.darkened(0.55), 0.8 * alpha), 2.0)
	_slab_vine(face, i, alpha)

## 刻在石板上的月纹：凹槽暗线 + 下沿高光。
func _rune(c: Vector2, s: float, kind: int, base: Color, alpha: float) -> void:
	var dark := Color(base.darkened(0.5), alpha)
	var lip := Color(base.lightened(0.35), 0.8 * alpha)
	for pass_ in 2:
		var col := lip if pass_ == 0 else dark
		var o := Vector2(1.2, 1.8) if pass_ == 0 else Vector2.ZERO
		var w := 2.0 if pass_ == 0 else 4.0
		match kind:
			0:
				draw_arc(c + o, s, PI * 0.35, PI * 1.65, 18, col, w, true)
				draw_arc(c + o + Vector2(s * 0.45, 0), s * 0.75, PI * 0.5, PI * 1.5, 14, col, w * 0.7, true)
			1:
				draw_arc(c + o, s, 0, TAU, 22, col, w, true)
				draw_circle(c + o, s * 0.28, col)
			2:
				var pts := PackedVector2Array()
				for k in 22:
					var t := float(k) / 21.0
					pts.append(c + o + Vector2.from_angle(t * TAU * 1.6) * s * (0.15 + t * 0.9))
				draw_polyline(pts, col, w, true)
			3:
				draw_arc(c + o + Vector2(0, s * 0.7), s * 1.15, PI * 1.22, PI * 1.78, 12, col, w, true)
				draw_arc(c + o + Vector2(0, -s * 0.7), s * 1.15, PI * 0.22, PI * 0.78, 12, col, w, true)
				draw_circle(c + o, s * 0.3, col)
			_:
				for k in 3:
					draw_circle(c + o + Vector2.from_angle(-PI / 2 + k * TAU / 3) * s * 0.75, s * 0.22, col)
				draw_arc(c + o, s * 1.05, 0, TAU, 22, col, w * 0.6, true)

## 石板上的藤蔓：从上角垂下，带几片叶子；有的石板只有一撮苔藓。
func _slab_vine(face: Rect2, i: int, alpha: float) -> void:
	var v := Art.srnd(i * 17 + 3)
	var leaf := Color(_color("vine", "7fae5a"), alpha)
	var dark := Color(_color("vine", "7fae5a").darkened(0.5), alpha)
	if v < 0.28:
		var m := face.position + Vector2(face.size.x * (0.25 + Art.srnd(i) * 0.5), face.size.y - 2)
		for k in 3: draw_circle(m + Vector2((k - 1) * 7, -2 - (k % 2) * 3), 5.5, leaf)
		return
	var left := v < 0.64
	var x0 := face.position.x + (8.0 if left else face.size.x - 8.0)
	var dir := 1.0 if left else -1.0
	var pts := PackedVector2Array()
	var len := 0.45 + Art.srnd(i * 23) * 0.45
	for k in 7:
		var t := float(k) / 6.0
		pts.append(Vector2(x0 + dir * sin(t * 3.2 + i) * 6.0 + Art.jit(i * 31 + k) * 0.8, face.position.y - 2 + t * face.size.y * len))
	draw_polyline(pts, Color(INK, alpha), 5.0, true)
	draw_polyline(pts, dark.lightened(0.25), 2.6, true)
	for k in [1, 3, 5]:
		if k >= pts.size(): continue
		var side := 1.0 if k % 4 == 1 else -1.0
		_leaf(pts[k] + Vector2(side * dir * 6, 0), 0.6 * side * dir + 0.3, 7.5, leaf, alpha)

func _leaf(c: Vector2, rot: float, s: float, col: Color, alpha: float) -> void:
	var pts := Art.ell(c, Vector2(s, s * 0.55), int(c.x * 3 + c.y), 0.02, 10, rot, 0.3)
	Art.dilate(self, pts, 1.6, Color(INK, alpha))
	draw_colored_polygon(pts, col)
	draw_line(c - Vector2.from_angle(rot) * s * 0.7, c + Vector2.from_angle(rot) * s * 0.7, Color(col.darkened(0.35), alpha), 1.4)

## 锁定格的藤蔓：两股从对角缠进来，物品还能看清。
func _vines(r: Rect2, i: int) -> void:
	var leaf := _color("vine", "7fae5a")
	for corner in 2:
		var a := r.position + (Vector2(4, 6) if corner == 0 else Vector2(r.size.x - 4, r.size.y - 8))
		var b := r.position + (Vector2(r.size.x * 0.42, 3) if corner == 0 else Vector2(r.size.x * 0.56, r.size.y - 3))
		var mid := r.position + (Vector2(r.size.x * 0.2, r.size.y * 0.24) if corner == 0 else Vector2(r.size.x * 0.8, r.size.y * 0.74))
		var pts := PackedVector2Array()
		for k in 9:
			var t := float(k) / 8.0
			var p := a.lerp(mid, t).lerp(mid.lerp(b, t), t)
			pts.append(p + Vector2(0, sin(t * 9.0 + i) * 2.0))
		draw_polyline(pts, INK, 5.0, true)
		draw_polyline(pts, leaf.darkened(0.25), 2.6, true)
		_leaf(pts[3] + Vector2(4, 4) * (1 if corner == 0 else -1), 0.8 + corner * PI, 7.0, leaf, 1.0)
		_leaf(pts[6] + Vector2(-3, 5) * (1 if corner == 0 else -1), -0.4 + corner * PI, 6.0, leaf.lightened(0.15), 1.0)

## 石锁：小石块 + 月牙锁孔。
func _lock_badge(c: Vector2) -> void:
	draw_arc(c + Vector2(0, -6), 7.5, PI, TAU, 10, INK, 6.0, true)
	draw_arc(c + Vector2(0, -6), 7.5, PI, TAU, 10, Color("c9d3cf"), 2.6, true)
	var body := Art.rrect(Rect2(c + Vector2(-11, -6), Vector2(22, 17)), 5, 61, 0.3)
	Art.fill(self, body, Color("c9d3cf"), 2.5, INK)
	draw_arc(c + Vector2(-0.5, 2.5), 4.2, PI * 0.35, PI * 1.65, 10, Color("3e6068"), 2.4, true)

func _gui_input(e: InputEvent) -> void:
	if animating or MergeEvent.busy: return
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_LEFT and e.device != -1:
			if e.pressed: _press(e.position)
			else: _release(e.position)
			accept_event()
	elif e is InputEventMouseMotion and e.device != -1: _motion(e.position)
	elif e is InputEventScreenTouch:
		if e.index != 0: return
		if e.pressed: _press(e.position)
		else: _release(e.position)
		accept_event()
	elif e is InputEventScreenDrag and e.index == 0: _motion(e.position); accept_event()

func _press(p: Vector2) -> void:
	pressed = at(p)
	press_pos = p
	cursor = p
	dragging = false

func _motion(p: Vector2) -> void:
	if pressed < 0: return
	var c: Dictionary = MergeEvent.state(cfg)["cells"][pressed]
	if p.distance_to(press_pos) > 10 and int(c["lock"]) == 0 and str(c["id"]) != "": dragging = true
	cursor = p
	queue_redraw()

func _release(p: Vector2) -> void:
	if pressed < 0: return
	var a := pressed
	var b := at(p)
	var held := dragging
	dragging = false
	pressed = -1
	if held:
		var s := MergeEvent.state(cfg)
		var id := str(s["cells"][a]["id"])
		var result: Dictionary = await MergeEvent.act(cfg, "drop", {"from": a, "to": b, "view": int(round(camera))})
		if not is_instance_valid(self): return
		if result.has("error"):
			moves.append({"id": id, "from": cursor + Vector2(0, -18), "to": a, "t": 0.0})
			if str(result["error"]) != "": G.main.toast(str(result["error"]))
			Sfx.play("deny")
		else:
			moves.append({"id": id, "from": cursor + Vector2(0, -18), "to": b, "t": 0.0, "result": result})
			if result["kind"] == "swap": moves.append({"id": str(result["under"]), "from": center(b), "to": a, "t": 0.0})
			Sfx.play("merge" if result["kind"] == "merge" else "pop")
			selected = b
			action_finished.emit(result)
		animating = true
	elif b == a:
		selected = b
	var cells: Array = MergeEvent.state(cfg)["cells"]
	if selected >= 0: selection_changed.emit("" if int(cells[selected]["lock"]) == 2 else str(cells[selected]["id"]), int(cells[selected]["lock"]) != 0)
	queue_redraw()

func spawn() -> void:
	if animating or MergeEvent.busy: return
	var result: Dictionary = await MergeEvent.act(cfg, "spawn", {"view": int(round(camera))})
	if not is_instance_valid(self): return
	if result.has("error"):
		if str(result["error"]) != "": G.main.toast(str(result["error"]))
		Sfx.play("deny")
		return
	var to := int(result["to"])
	incoming[to] = true
	animating = true
	Sfx.play("pop")
	if fx.is_valid():
		fx.call("fly", position + center(to), {"id": str(result["id"]), "from": spawn_origin, "done": func():
			if not is_instance_valid(self): return
			incoming.erase(to)
			pops[to] = 0.0
			animating = not moves.is_empty()
			_fx("spark", center(to), {"small": true})
			queue_redraw()})
	else:
		incoming.erase(to)
		moves.append({"id": str(result["id"]), "from": Vector2(size.x / 2, size.y + 100), "to": to, "t": 0.0})
	action_finished.emit(result)
