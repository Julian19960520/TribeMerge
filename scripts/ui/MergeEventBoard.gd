class_name MergeEventBoard
extends Control
## 合成活动棋盘（火光岩画 / 月石遗迹共用）。三种格子状态一眼可分：
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
var _spawn_busy := false
var _bubbles := false
var _tap_busy := false

const INK := Color("3b2314")

func _ready() -> void:
	clip_contents = true
	mouse_filter = MOUSE_FILTER_STOP
	cell = size.x / int(cfg["board"]["cols"])
	camera = float(MergeEvent.state(cfg)["view"])
	G.merge_event_changed.connect(queue_redraw)

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
		_fx("text", Vector2(size.x / 2, cell * 0.9), {"text": TextCatalog.source("ui.mergeeventboard.519c2ec5a775"), "color": Color("bff3f0"), "size": 30}))
	Sfx.play("whoosh")

func _process(delta: float) -> void:
	_t += delta
	var busy := false
	if not moves.is_empty():
		busy = true
		for m in moves: m["t"] = minf(1, float(m["t"]) + delta / float(m.get("dur", 0.22)))
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
	if busy or _bubbles or _hint_id() != "" or _brush_ready(): queue_redraw()

## 落地后的反馈：合成闪光、解锁落叶、揭开石板。
func _landed(m: Dictionary) -> void:
	var i := int(m["to"])
	pops[i] = 0.0
	var r: Dictionary = m.get("result", {})
	if m.has("spark"): _fx("spark", center(i), {"small": true})
	if r.is_empty(): return
	var at_px := center(i)
	if str(r.get("kind", "")) == "merge":
		if bool(r.get("unlocked", false)):
			_fx("leaves", at_px, {"color": _color("vine", "7fae5a")})
			_fx("text", at_px + Vector2(0, -cell * 0.45), {"text": TextCatalog.source("ui.mergeeventboard.0ee51c1f367c"), "color": Color("fff3a6"), "size": 30})
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
	_bubbles = false
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
			if lock == 0: MoonArt.tile(self, r, i, MoonArt.FLOOR if (row + col) % 2 == 0 else MoonArt.FLOOR_ALT)
			else: MoonArt.tile(self, r, i, MoonArt.RECESS)
			var moving := dragging and i == pressed
			for m in moves:
				if int(m["to"]) == i: moving = true
			if incoming.has(i): moving = true
			if lock == 0:
				if hint != "" and id == hint and i != pressed and i != selected:
					_glow(r, Color("fff3a6"), 0.25 + 0.35 * pulse)
				if id != "" and not moving:
					var k := MergeEvent.kind(cfg, id)
					if k == "brush" and _brush_ready(): _glow(r, Color("ffc46a"), 0.3 + 0.4 * pulse)
					MergeEventArt.draw_item(self, cfg, id, ctr + Vector2(0, -2), cell * 0.84 * _pop(i), Color.WHITE, _t)
					if k == "reward" and MergeEvent.is_bubble(cfg, id): _bubbles = true
					if k == "brush": _draw_charges(ctr, s)
			elif lock == 1:
				if hint != "" and id == hint: _glow(r, Color("b8ff7a"), 0.45 + 0.5 * pulse)
				if not moving: MergeEventArt.draw_item(self, cfg, id, ctr + Vector2(0, -1), cell * 0.72, Color(0.66, 0.86, 0.95, 0.82))
				MoonArt.tile(self, r, i, MoonArt.LOCK)
			else:
				MoonArt.tile(self, r, i, MoonArt.FRONTIER if _frontier(cells, i, cols) else MoonArt.SLAB)
			if lifts.has(i):
				var t := float(lifts[i])
				draw_set_transform(ctr + Vector2(0, -t * cell * 0.35), (Art.srnd(i) - 0.5) * t * 0.6, Vector2.ONE * (1.0 + 0.2 * t))
				MoonArt.tile(self, Rect2(-Vector2.ONE * cell / 2, Vector2.ONE * cell), i, MoonArt.SLAB, 1.0 - t)
				draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
			if i == selected: Paint.cell_bracket(self, r.grow(-2), Color("ffe58a"))
	for m in moves:
		var t := float(m["t"])
		if t < 0: continue
		var p: Vector2 = (m["from"] as Vector2).lerp(center(int(m["to"])), MergeGrid.ease_back(t))
		if m.has("arc"): p.y -= sin(t * PI) * cell * 0.6
		MergeEventArt.draw_item(self, cfg, str(m["id"]), p, cell * 0.9, Color.WHITE, _t)
	_draw_queue(s)
	if dragging and pressed >= 0:
		draw_circle(cursor + Vector2(0, 18), cell * 0.32, Color(0, 0, 0, 0.18))
		MergeEventArt.draw_item(self, cfg, str(cells[pressed]["id"]), cursor + Vector2(0, -18), cell * 1.0)

func _pop(i: int) -> float:
	if not pops.has(i): return 1.0
	var t := float(pops[i])
	return 1.0 + 0.28 * sin(t * PI * 2.0) * (1.0 - t)

func _brush_ready() -> bool:
	var s := MergeEvent.state(cfg)
	return s.has("brush") and int(s["brush"]["charges"]) > 0

## 画笔右下角的颜料余量：几滴颜料 = 还能画几幅。
func _draw_charges(ctr: Vector2, s: Dictionary) -> void:
	var n := int(s.get("brush", {}).get("charges", 0))
	var cap := int(cfg["brush"].get("max_charges", 8))
	var r := Rect2(ctr + Vector2(-cell * 0.02, cell * 0.2), Vector2(cell * 0.5, cell * 0.25))
	draw_colored_polygon(Art.rrect(r, r.size.y / 2, 7, 0.0), Color(0.18, 0.09, 0.05, 0.85))
	draw_circle(r.position + Vector2(r.size.y / 2, r.size.y / 2), r.size.y * 0.32, Color("e0703a") if n > 0 else Color("7a6a5a"))
	var fs := int(cell * 0.2)
	var txt := "%d/%d" % [n, cap]
	var w := G.font_title.get_string_size(TextCatalog.resolve(txt), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(G.font_title, Vector2(r.position.x + r.size.y + (r.size.x - r.size.y - w) / 2, r.position.y + r.size.y * 0.8), TextCatalog.resolve(txt), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("fff1d6"))

## 棋盘摆不下的奖励在洞口排队：左上角显示下一件和总数，有空格就自动出来。
func _draw_queue(s: Dictionary) -> void:
	var q: Array = s.get("queue", [])
	if q.is_empty(): return
	var r := Rect2(Vector2(8, 8), Vector2(cell * 1.25, cell * 0.62))
	draw_colored_polygon(Art.rrect(r, r.size.y / 2, 9, 0.0), Color(0.16, 0.08, 0.04, 0.82))
	draw_arc(r.position + Vector2(r.size.y / 2, r.size.y / 2), r.size.y / 2 - 2, 0, TAU, 24, Color(1, 0.8, 0.5, 0.5 + 0.3 * sin(_t * 4.0)), 2.0, true)
	MergeEventArt.draw_item(self, cfg, str(q[0]), r.position + Vector2(r.size.y / 2, r.size.y / 2), r.size.y * 0.9, Color.WHITE, _t)
	draw_string(G.font_title, r.position + Vector2(r.size.y + 4, r.size.y * 0.68), TextCatalog.resolve("×%d" % q.size()), HORIZONTAL_ALIGNMENT_LEFT, -1, int(cell * 0.24), Color("fff1d6"))

func _frontier(cells: Array, i: int, cols: int) -> bool:
	for k in MergeGrid.neighbors(i, cols, cells.size()):
		if int(cells[k]["lock"]) == 0: return true
	return false

func _glow(r: Rect2, col: Color, a: float) -> void:
	# 白色光框图，按颜色和亮度染色
	Sprites.draw(self, "board_glow", r.grow(-3), Color(col, a))

func _gui_input(e: InputEvent) -> void:
	if animating: return
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
			_animate_extras(result, b)
			Sfx.play("merge" if result["kind"] in ["merge", "feed"] else "pop")
			if result["kind"] == "feed":
				_fx("text", center(b) + Vector2(0, -cell * 0.5), {"text": TextCatalog.source("ui.mergeeventboard.b14cf6838e54") if bool(result.get("level_up", false)) else TextCatalog.source("ui.mergeeventboard.0d1fd47477ac") % item_charges(str(result["id"])), "color": Color("ffd68a"), "size": 28})
			selected = b
			action_finished.emit(result)
		animating = true
	elif b == a:
		var again := selected == b
		selected = b
		if not await _tap(b, again): return
	var cells: Array = MergeEvent.state(cfg)["cells"]
	if selected >= 0: selection_changed.emit("" if int(cells[selected]["lock"]) == 2 else str(cells[selected]["id"]), int(cells[selected]["lock"]) != 0)
	queue_redraw()

func item_charges(id: String) -> int:
	return int(MergeEvent.item(cfg, id).get("charges", 1))

## 合成掉出的壁画 / 奖励、洞口排队出来的物品：等主物品落地后再依次飞出。
func _animate_extras(result: Dictionary, origin: int) -> void:
	var delay := -1.0
	for p in result.get("placed", []):
		moves.append({"id": str(p["id"]), "from": center(origin), "to": int(p["to"]), "t": delay, "dur": 0.3, "arc": true, "spark": true})
		delay -= 0.5
	for p in result.get("flushed", []):
		moves.append({"id": str(p["id"]), "from": Vector2(size.x / 2, size.y + cell * 0.6), "to": int(p["to"]), "t": delay, "dur": 0.34, "spark": true})
		delay -= 0.5
	if int(result.get("queued", 0)) > 0:
		_fx("text", Vector2(size.x / 2, cell * 0.9), {"text": TextCatalog.source("ui.mergeeventboard.6d14fa859d57") % int(result["queued"]), "color": Color("ffd68a"), "size": 26})

## 点格子：画笔点一下画壁画；箱子气泡点一下收进暂存区；
## 资源先选中，再点一下领取；最高级的灯 / 壁画选中后再点挂上岩壁。返回 false 表示已自行收尾。
func _tap(i: int, again: bool) -> bool:
	var s := MergeEvent.state(cfg)
	var c: Dictionary = s["cells"][i]
	var id := str(c["id"])
	if int(c["lock"]) != 0 or id == "" or _tap_busy: return true
	var k := MergeEvent.kind(cfg, id)
	var action := ""
	if k == "brush": action = "brush"
	elif k == "reward" and (again or MergeEvent.is_bubble(cfg, id)): action = "collect"
	elif k in ["light", "mural"] and again and MergeEvent.next_id(cfg, id) == "": action = "collect"
	if action == "": return true
	_tap_busy = true
	var result: Dictionary = await MergeEvent.act(cfg, action, {"cell": i, "view": int(round(camera))})
	_tap_busy = false
	if not is_instance_valid(self): return false
	if result.has("error"):
		if str(result["error"]) != "": G.main.toast(str(result["error"]))
		Sfx.play("deny")
		return true
	match str(result["kind"]):
		"brush":
			moves.append({"id": str(result["id"]), "from": center(i), "to": int(result["to"]), "t": 0.0, "dur": 0.32, "arc": true, "spark": true})
			Sfx.play("pop")
		"collect":
			selected = -1
			_fx("collect", center(i), {"id": id, "text": TextCatalog.source("ui.mergeeventboard.81b7fd46fcd1") if bool(result.get("bubble", false)) else ""})
			Sfx.play("pop")
		"hang":
			selected = -1
			_fx("spark", center(i), {})
			_fx("text", center(i) + Vector2(0, -cell * 0.5), {"text": TextCatalog.source("ui.mergeeventboard.21ea3ee33e08"), "color": Color("ffd68a"), "size": 30})
			Sfx.play("fanfare")
	_animate_extras(result, i)
	if not moves.is_empty(): animating = true
	action_finished.emit(result)
	selection_changed.emit("" if selected < 0 else id, false)
	queue_redraw()
	return selected >= 0

func spawn() -> void:
	# 飞入动画不阻塞下一次投放；逻辑先占格，每次点击都落在独立空格。
	if _spawn_busy or dragging or not moves.is_empty(): return
	if _camera_tween and _camera_tween.is_running(): return
	_spawn_busy = true
	var result: Dictionary = await MergeEvent.act(cfg, "spawn", {"view": int(round(camera))})
	if not is_instance_valid(self): return
	_spawn_busy = false
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
			animating = not moves.is_empty() or not incoming.is_empty()
			if not animating: _sync_camera()
			_fx("spark", center(to), {"small": true})
			queue_redraw()})
	else:
		incoming.erase(to)
		moves.append({"id": str(result["id"]), "from": Vector2(size.x / 2, size.y + 100), "to": to, "t": 0.0})
	action_finished.emit(result)
