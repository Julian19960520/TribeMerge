class_name MergeEventBoard
extends Control
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
var burst_at := -1
var burst_t := 1.0
var _camera_tween: Tween
const ROCK := preload("res://assets/board/rocks_0.png")
const VINES := preload("res://assets/events/moon/vines.svg")
const FLOOR := preload("res://assets/board/floor.png")

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

func _sync_camera() -> void:
	var to := float(MergeEvent.state(cfg)["view"])
	if is_equal_approx(to, camera): return
	animating = true
	selected = -1
	selection_changed.emit("", false)
	if _camera_tween and _camera_tween.is_valid(): _camera_tween.kill()
	_camera_tween = create_tween()
	_camera_tween.tween_method(func(v): camera = v; queue_redraw(), camera, to, 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_camera_tween.tween_callback(func(): animating = false)

func _process(delta: float) -> void:
	if not moves.is_empty():
		for m in moves: m["t"] = minf(1, float(m["t"]) + delta / 0.24)
		moves = moves.filter(func(m): return float(m["t"]) < 1)
		if moves.is_empty():
			animating = false
			_sync_camera()
		queue_redraw()
	if burst_t < 1:
		burst_t = minf(1, burst_t + delta * 3)
		queue_redraw()

func _draw() -> void:
	if cfg.is_empty(): return
	var s := MergeEvent.state(cfg)
	var cells: Array = s["cells"]
	var cols := int(cfg["board"]["cols"])
	var theme: Dictionary = cfg["theme"]
	for row in range(maxi(0, int(floor(camera))), mini(int(cfg["board"]["total_rows"]), int(ceil(camera)) + int(cfg["board"]["visible_rows"]))):
		for col in cols:
			var i := row * cols + col
			var c: Dictionary = cells[i]
			var ctr := center(i)
			var r := Rect2(ctr - Vector2.ONE * cell / 2, Vector2.ONE * cell)
			var locked := int(c["lock"]) != 0
			var color := Color(str(theme["locked"])) if locked else Color(str(theme["tile"] if (row + col) % 2 == 0 else theme["tile_alt"]))
			draw_texture_rect(FLOOR, r.grow(-1), false, color)
			if i == selected: draw_style_box(_selection_style(), r.grow(-3))
			var hidden := dragging and i == pressed
			for m in moves:
				if int(m["to"]) == i: hidden = true
			if int(c["lock"]) == 2:
				var variant := posmod(i, 63)
				var rock_size := Vector2.ONE * cell * 128.0 / 96.0
				draw_texture_rect_region(ROCK, Rect2(ctr-rock_size/2, rock_size), Rect2((variant%9)*128, (variant/9)*128, 128,128), Color("b5d7d0"))
				continue
			if not hidden and str(c["id"]) != "":
				MergeEvent.draw_item(self, cfg, str(c["id"]), ctr + Vector2(0, -2), cell * 0.82, Color(0.75, 0.86, 0.87, 0.85) if locked else Color.WHITE)
			if locked:
				draw_texture_rect(VINES, r.grow(-3), false)
				Paint.glyph(self, "lock", ctr + Vector2(cell * 0.31, cell * 0.30), 0.55, Color("ead8a6"))
			else:
				var tier: int = cfg["chain"].find(MergeEvent.item(cfg, str(c["id"]))) + 1
				if tier > 0: draw_string(G.font_body, ctr + Vector2(-cell * 0.35, cell * 0.38), str(tier), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("42606a"))
	for m in moves:
		var t := float(m["t"])
		var p: Vector2 = (m["from"] as Vector2).lerp(center(int(m["to"])), MergeGrid.ease_back(t))
		MergeEvent.draw_item(self, cfg, str(m["id"]), p, cell * 0.88)
	if burst_at >= 0 and burst_t < 1:
		draw_arc(center(burst_at), 10 + burst_t * 45, 0, TAU, 24, Color(1, 0.9, 0.55, 1 - burst_t), 4)
	if dragging and pressed >= 0:
		MergeEvent.draw_item(self, cfg, str(cells[pressed]["id"]), cursor + Vector2(0, -18), cell * 0.98)

func _selection_style() -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = Color.TRANSPARENT
	st.border_color = Color("ffe191")
	st.set_border_width_all(3)
	st.set_corner_radius_all(10)
	return st

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
			moves.append({"id": id, "from": cursor + Vector2(0, -18), "to": b, "t": 0.0})
			if result["kind"] == "swap": moves.append({"id": str(result["under"]), "from": center(b), "to": a, "t": 0.0})
			if result["kind"] == "merge": burst_at = b; burst_t = 0; Sfx.play("merge")
			else: Sfx.play("pop")
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
		return
	moves.append({"id": str(result["id"]), "from": Vector2(size.x / 2, size.y + 100), "to": int(result["to"]), "t": 0.0})
	animating = true
	Sfx.play("pop")
	action_finished.emit(result)
