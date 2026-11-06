class_name OrderCurvePad
extends Control
## 随机订单难度曲线。横轴主角等级，纵轴理论火苗。点住圆点上下拖。
## 空白处长按再拖出选框，可多选；包围框上下边缩放高度，框内拖动整体升降。
const Meme := preload("res://scripts/Meme.gd")

const Roll := preload("res://scripts/OrderRoll.gd")

const LEVELS := 40
const VISIBLE := 8
const SPAN_MIN := 1.25
const SPAN_MAX := 39.0
const YSPAN_MIN := 6.0
const YSPAN_MAX := 12000.0
const HOLD_MS := 340
const HOLD_SLOP := 8.0

var edit
var page: Dictionary = {}
## 视野：横轴从 cam 起，跨 span 个等级；纵轴从 y0 到 y1。滚轮改的是目标值，画面再缓过去。
var cam := 0.0
var span := 7.0
var y0 := 0.0
var y1 := 32.0
var cam_to := 0.0
var span_to := 7.0
var y0_to := 0.0
var y1_to := 32.0
var _view_anim := false
var sel_c := 0
var sel_l := 0
var order: Dictionary = {}
var rng := RandomNumberGenerator.new()

var _roll_btn: TButton
var _item_hits: Array = []
var _mode := ""
var _press := Vector2.ZERO
var _press_cam := 0.0
var _press_y0 := 0.0
var _press_yspan := 1.0
var _pan_pix := Vector2.ZERO
var _pan_last := Vector2.ZERO
var _pan_last_t := 0
var _fling := false
var _drag_y0 := 0.0
var _drag_v0 := 0
var _drag_scale := 1.0
var _moved := false
var _clip: Control
var _ink: Control
var _overlay: Control
var _pen: CanvasItem
## 框选结果。键是 Vector2i(曲线, 等级)。
var _group: Dictionary = {}
var _grab: Dictionary = {}
var _grab_min := 1
var _grab_max := 1
var _scale_top := true
var _hold_t := 0
var _marquee_to := Vector2.ZERO

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	_clip = Control.new()
	_clip.mouse_filter = MOUSE_FILTER_IGNORE
	_clip.clip_contents = true
	add_child(_clip)
	_ink = Control.new()
	_ink.mouse_filter = MOUSE_FILTER_IGNORE
	_ink.draw.connect(_draw_plot)
	_clip.add_child(_ink)
	_overlay = Control.new()
	_overlay.mouse_filter = MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	rng.randomize()
	_normalize()
	span = float(VISIBLE - 1)
	cam = 0.0
	y0 = 0.0
	y1 = maxf(8.0, _max_in_window(cam, span) * 1.18)
	_sync_targets()
	var hint := UI.lbl(self, "纵轴是订单难度，等于这单物品的理论火苗。主产物 1 级 1、2 级 2、3 级 4，之后翻倍。副产物再除以 1 级掉率，例如 5% 时 1 级要 20 火苗。两条线是下限和上限，随机订单落在中间。", Rect2(16, 4, 688, 74), 18, Art.INK, HORIZONTAL_ALIGNMENT_LEFT)
	hint.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	hint.clip_text = true
	var by := _button_y()
	_roll_btn = UI.btn(self, Rect2(180, by, 360, 64), "换一单", "green", _roll, 28)
	_roll_btn.title_font = false
	_roll()
	if not G.boil_tick.is_connected(queue_redraw):
		G.boil_tick.connect(queue_redraw)

func _process(delta: float) -> void:
	if _mode == "hold" and not _moved and Time.get_ticks_msec() - _hold_t >= HOLD_MS:
		_mode = "marquee"
		_marquee_to = _press
		mouse_default_cursor_shape = CURSOR_CROSS
		Sfx.play("tap")
		queue_redraw()
	if _mode == "drag" or _mode == "pan" or _mode == "hold" or _mode == "marquee" or _mode == "nudge" or _mode == "scale":
		return
	if _fling:
		_coast(delta)
		return
	if not _view_anim:
		return
	var k := 1.0 - exp(-delta * 8.0)
	cam = lerpf(cam, cam_to, k)
	span = lerpf(span, span_to, k)
	y0 = lerpf(y0, y0_to, k)
	y1 = lerpf(y1, y1_to, k)
	_clamp_live()
	var settled := absf(cam - cam_to) < 0.004 and absf(span - span_to) < 0.004
	settled = settled and absf(y0 - y0_to) < 0.05 and absf(y1 - y1_to) < 0.05
	if settled:
		cam = cam_to
		span = span_to
		y0 = y0_to
		y1 = y1_to
		_clamp_live()
		_sync_targets()
	queue_redraw()

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_UP:
		_wheel_zoom(true, e.position)
		accept_event()
		return
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_wheel_zoom(false, e.position)
		accept_event()
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_yield_scroll()
			_fling = false
			_pan_pix = Vector2.ZERO
			_press = e.position
			_moved = false
			var scale_hit := _hit_scale(e.position)
			if scale_hit != 0:
				_begin_group(e.position)
				_mode = "scale"
				_scale_top = scale_hit > 0
				mouse_default_cursor_shape = CURSOR_VSIZE
				accept_event()
				return
			var hit := _hit_point(e.position)
			if hit.x >= 0 and _group.size() >= 2 and _group.has(hit):
				_begin_group(e.position)
				_mode = "nudge"
				mouse_default_cursor_shape = CURSOR_VSIZE
				accept_event()
				return
			if hit.x >= 0:
				if not _group.is_empty():
					_group.clear()
				_mode = "drag"
				var changed := hit.x != sel_c or hit.y != sel_l
				sel_c = hit.x
				sel_l = hit.y
				_drag_y0 = e.position.y
				_drag_v0 = _diff(sel_c, sel_l)
				_drag_scale = (y1 - y0) / maxf(1.0, _plot().size.y)
				_sync_targets()
				mouse_default_cursor_shape = CURSOR_VSIZE
				Sfx.play("tap")
				if changed:
					_roll()
				queue_redraw()
			elif _group.size() >= 2 and _group_rect().has_point(e.position):
				_begin_group(e.position)
				_mode = "nudge"
				mouse_default_cursor_shape = CURSOR_VSIZE
			else:
				var leg := _hit_legend(e.position)
				if leg >= 0:
					_mode = ""
					if leg != sel_c:
						sel_c = leg
						_ensure_visible(sel_l)
						_roll()
					queue_redraw()
				elif _plot().grow(6.0).has_point(e.position):
					_mode = "hold"
					_hold_t = Time.get_ticks_msec()
					_marquee_to = e.position
					_sync_targets()
					_press_cam = cam
					_press_y0 = y0
					_press_yspan = maxf(y1 - y0, YSPAN_MIN)
					_pan_last = e.position
					_pan_last_t = Time.get_ticks_msec()
					mouse_default_cursor_shape = CURSOR_DRAG
				else:
					_mode = ""
			accept_event()
		else:
			var mode := _mode
			var moved := _moved
			_mode = ""
			mouse_default_cursor_shape = CURSOR_ARROW
			if mode == "pan" and moved:
				if Time.get_ticks_msec() - _pan_last_t > 80:
					_pan_pix = Vector2.ZERO
				_fling = _pan_pix.length() > 80.0
				if not _fling:
					_pan_pix = Vector2.ZERO
					_sync_targets()
			elif mode == "drag" and moved:
				_ease_include_value(float(_diff(sel_c, sel_l)))
			elif mode == "marquee":
				_finish_marquee()
			elif (mode == "nudge" or mode == "scale") and moved:
				_ease_group()
				_roll()
			elif mode == "hold" and not moved and not _group.is_empty():
				_group.clear()
				queue_redraw()
			accept_event()
	elif e is InputEventMouseMotion:
		if _mode == "hold":
			var held := Time.get_ticks_msec() - _hold_t >= HOLD_MS
			if not held and e.position.distance_to(_press) > HOLD_SLOP:
				_mode = "pan"
				_moved = true
			elif held:
				_mode = "marquee"
				_marquee_to = e.position
				Sfx.play("tap")
				if e.position.distance_to(_press) > 4.0:
					_moved = true
			else:
				accept_event()
				return
		if _mode == "pan":
			if e.position.distance_to(_press) > 4.0:
				_moved = true
			var now := Time.get_ticks_msec()
			var dt := maxf(0.001, float(now - _pan_last_t) / 1000.0)
			var inst: Vector2 = (e.position - _pan_last) / dt
			if inst.length() > 6000.0:
				inst = inst.normalized() * 6000.0
			_pan_pix = _pan_pix.lerp(inst, 0.45)
			_pan_last = e.position
			_pan_last_t = now
			var step := _step()
			if step > 1.0:
				cam = clampf(_press_cam - (e.position.x - _press.x) / step, 0.0, _cam_max())
			var plot := _plot()
			var yscale := _press_yspan / maxf(1.0, plot.size.y)
			var next_y0: float = _press_y0 + (e.position.y - _press.y) * yscale
			next_y0 = clampf(next_y0, 0.0, maxf(0.0, 12000.0 - _press_yspan))
			y0 = next_y0
			y1 = next_y0 + _press_yspan
			cam_to = cam
			y0_to = y0
			y1_to = y1
			_view_anim = false
			queue_redraw()
			accept_event()
		elif _mode == "drag":
			if e.position.distance_to(_press) > 4.0:
				_moved = true
			var v := int(round(float(_drag_v0) + (_drag_y0 - e.position.y) * _drag_scale))
			_apply_diff(clampi(v, 1, 9999))
			accept_event()
		elif _mode == "marquee":
			if e.position.distance_to(_press) > 4.0:
				_moved = true
			_marquee_to = e.position
			queue_redraw()
			accept_event()
		elif _mode == "nudge":
			if e.position.distance_to(_press) > 3.0:
				_moved = true
			_apply_nudge(e.position.y)
			accept_event()
		elif _mode == "scale":
			if e.position.distance_to(_press) > 3.0:
				_moved = true
			_apply_scale(e.position.y)
			accept_event()
		else:
			var scale_over := _hit_scale(e.position)
			var over := _hit_point(e.position)
			if scale_over != 0 or over.x >= 0:
				mouse_default_cursor_shape = CURSOR_VSIZE
			elif _group.size() >= 2 and _group_rect().has_point(e.position):
				mouse_default_cursor_shape = CURSOR_VSIZE
			elif _plot().has_point(e.position):
				mouse_default_cursor_shape = CURSOR_DRAG
			else:
				mouse_default_cursor_shape = CURSOR_ARROW

func _draw() -> void:
	_draw_legend()
	var plot := _plot()
	var frame := Rect2(12, plot.position.y - 28, 696, plot.size.y + 64)
	var plate := Art.rrect(frame, 16, 3, 0.35)
	Art.dilate(self, plate, 3.0, Art.INK)
	draw_colored_polygon(plate, Color("fff7e6"))
	_draw_grid(plot)
	_clip.position = plot.position
	_clip.size = plot.size
	_ink.position = Vector2.ZERO
	_ink.size = plot.size
	_ink.queue_redraw()
	_overlay.position = Vector2.ZERO
	_overlay.size = size
	_overlay.queue_redraw()
	_draw_info()
	_draw_order()

func _draw_plot() -> void:
	var plot := _plot()
	_pen = _ink
	_ink.draw_set_transform(-plot.position, 0.0, Vector2.ONE)
	_draw_band(plot)
	var yr := maxf(y1 - y0, 0.001)
	for t in [0.0, 0.25, 0.5, 0.75, 1.0]:
		var y := _y_of(y0 + yr * float(t))
		_ink.draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), Color(0.55, 0.4, 0.25, 0.16), 1.5, true)
	var sx := _x_of(sel_l)
	if sx >= plot.position.x and sx <= plot.end.x:
		_ink.draw_line(Vector2(sx, plot.position.y), Vector2(sx, plot.end.y), Color(Art.OCHRE, 0.45), 2.0, true)
	_draw_curves(plot)
	_draw_selected_value(plot)
	_ink.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_pen = null

func _ci() -> CanvasItem:
	return _pen if _pen != null else self

func _button_y() -> float:
	return size.y - 80.0

func _info_y() -> float:
	return _button_y() - 286.0

func _plot() -> Rect2:
	var top := 152.0
	var bottom := _info_y() - 64.0
	return Rect2(96, top, size.x - 112.0, maxf(160.0, bottom - top))

func _step() -> float:
	return _plot().size.x / maxf(span, 0.001)

func _cam_max() -> float:
	return maxf(0.0, SPAN_MAX - span)

func _x_of(level_index: int) -> float:
	return _plot().position.x + (float(level_index) - cam) * _step()

func _y_of(v: float) -> float:
	var plot := _plot()
	var t := (v - y0) / maxf(y1 - y0, 0.001)
	return plot.end.y - t * plot.size.y

func _point(ci: int, li: int) -> Vector2:
	return Vector2(_x_of(li), _y_of(float(_diff(ci, li))))

func _curves() -> Array:
	var curves = page.get("curves", [])
	return curves if curves is Array else []

func _color(i: int) -> Color:
	return Color("4fa39a") if i == 0 else Color("d2512d")

func _diff(ci: int, li: int) -> int:
	var curves := _curves()
	if ci < 0 or ci >= curves.size():
		return 1
	var diff = curves[ci].get("diff", [])
	if not (diff is Array) or li < 0 or li >= diff.size():
		return 1
	return maxi(1, int(diff[li]))

func _legend_w(i: int) -> float:
	return 36.0 + _text_w(str(_curves()[i].get("name", "订单")), 20)

func _legend_at(i: int) -> Rect2:
	var x := 16.0
	for k in i:
		x += _legend_w(k) + 8.0
	return Rect2(x, 82, _legend_w(i), 34)

func _hit_legend(p: Vector2) -> int:
	for i in _curves().size():
		if _legend_at(i).has_point(p):
			return i
	return -1

func _point_on_screen(li: int) -> bool:
	var x := _x_of(li)
	var plot := _plot()
	return x >= plot.position.x - 2.0 and x <= plot.end.x + 2.0

func _hit_point(p: Vector2) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := 26.0
	for ci in range(_curves().size() - 1, -1, -1):
		for li in LEVELS:
			if not _point_on_screen(li):
				continue
			var d := _point(ci, li).distance_to(p)
			if ci == sel_c and li == sel_l:
				d -= 6.0
			if d < best_d:
				best_d = d
				best = Vector2i(ci, li)
	return best

func _in_group(ci: int, li: int) -> bool:
	return _group.has(Vector2i(ci, li))

func _marquee_rect() -> Rect2:
	return Rect2(Vector2(minf(_press.x, _marquee_to.x), minf(_press.y, _marquee_to.y)), (_marquee_to - _press).abs())

func _marquee_has(ci: int, li: int) -> bool:
	if _mode != "marquee":
		return false
	var r := _marquee_rect()
	if r.size.x < 10.0 and r.size.y < 10.0:
		return false
	return r.has_point(_point(ci, li))

func _group_rect() -> Rect2:
	var r := Rect2()
	var any := false
	for key in _group:
		var p := _point(int(key.x), int(key.y))
		if not any:
			r = Rect2(p, Vector2.ZERO)
			any = true
		else:
			r = r.expand(p)
	if not any:
		return Rect2()
	var box := r.grow(18.0)
	var plot := _plot().grow(6.0)
	if not box.intersects(plot, true):
		return Rect2()
	return box.intersection(plot)

func _hit_scale(p: Vector2) -> int:
	if _group.size() < 2:
		return 0
	var r := _group_rect()
	var top := Rect2(r.position.x, r.position.y - 12.0, r.size.x, 22.0)
	var bot := Rect2(r.position.x, r.end.y - 10.0, r.size.x, 22.0)
	if top.has_point(p):
		return 1
	if bot.has_point(p):
		return -1
	return 0

func _begin_group(at: Vector2) -> void:
	_grab.clear()
	var lo := 999999
	var hi := 1
	for key in _group:
		var v := _diff(int(key.x), int(key.y))
		_grab[key] = v
		lo = mini(lo, v)
		hi = maxi(hi, v)
	_grab_min = lo
	_grab_max = hi
	_drag_y0 = at.y
	_drag_scale = (y1 - y0) / maxf(1.0, _plot().size.y)

func _apply_nudge(y: float) -> void:
	var delta := (_drag_y0 - y) * _drag_scale
	var vals := {}
	for key in _grab:
		vals[key] = clampi(int(round(float(_grab[key]) + delta)), 1, 9999)
	_write_group(vals)

func _apply_scale(y: float) -> void:
	var delta := (_drag_y0 - y) * _drag_scale
	var vals := {}
	if _grab_max - _grab_min < 1:
		for key in _grab:
			vals[key] = clampi(int(round(float(_grab[key]) + delta)), 1, 9999)
		_write_group(vals)
		return
	var span_v := float(_grab_max - _grab_min)
	if _scale_top:
		var new_max := clampf(float(_grab_max) + delta, float(_grab_min), 9999.0)
		var s := (new_max - float(_grab_min)) / span_v
		for key in _grab:
			var orig := float(_grab[key])
			vals[key] = clampi(int(round(float(_grab_min) + (orig - float(_grab_min)) * s)), 1, 9999)
	else:
		var new_min := clampf(float(_grab_min) + delta, 1.0, float(_grab_max))
		var s := (float(_grab_max) - new_min) / span_v
		for key in _grab:
			var orig := float(_grab[key])
			vals[key] = clampi(int(round(float(_grab_max) + (orig - float(_grab_max)) * s)), 1, 9999)
	_write_group(vals)

func _write_group(vals: Dictionary) -> void:
	var curves := _curves()
	if curves.size() < 2:
		return
	var dirty := false
	for key in vals:
		var ci := int(key.x)
		var li := int(key.y)
		var diff: Array = curves[ci]["diff"]
		var v := int(vals[key])
		if li < 0 or li >= diff.size():
			continue
		if int(diff[li]) != v:
			diff[li] = v
			dirty = true
	var lo: Array = curves[0]["diff"]
	var hi: Array = curves[1]["diff"]
	var seen := {}
	for key in vals:
		var li := int(key.y)
		if seen.has(li) or li < 0 or li >= lo.size() or li >= hi.size():
			continue
		seen[li] = true
		if int(hi[li]) >= int(lo[li]):
			continue
		var lo_sel := _group.has(Vector2i(0, li))
		var hi_sel := _group.has(Vector2i(1, li))
		if lo_sel and hi_sel:
			var a := int(lo[li])
			var b := int(hi[li])
			lo[li] = mini(a, b)
			hi[li] = maxi(a, b)
		elif lo_sel:
			hi[li] = int(lo[li])
		elif hi_sel:
			lo[li] = int(hi[li])
		dirty = true
	if dirty:
		_touch()
	queue_redraw()

func _finish_marquee() -> void:
	var r := _marquee_rect()
	if r.size.x < 10.0 and r.size.y < 10.0:
		queue_redraw()
		return
	var next := {}
	for ci in _curves().size():
		for li in LEVELS:
			if r.has_point(_point(ci, li)):
				next[Vector2i(ci, li)] = true
	if next.size() < 2:
		_group.clear()
		if next.size() == 1:
			var only: Vector2i = next.keys()[0]
			if only.x != sel_c or only.y != sel_l:
				sel_c = only.x
				sel_l = only.y
				_roll()
		queue_redraw()
		return
	_group = next
	var best_li := sel_l
	var best_ci := sel_c
	var best_d := 999
	for key in _group:
		var d := absi(int(key.y) - sel_l)
		if d < best_d:
			best_d = d
			best_li = int(key.y)
			best_ci = int(key.x)
	if best_ci != sel_c or best_li != sel_l:
		sel_c = best_ci
		sel_l = best_li
		_roll()
	queue_redraw()

func _ease_group() -> void:
	if _group.is_empty():
		return
	var lo := 999999.0
	var hi := 1.0
	for key in _group:
		var v := float(_diff(int(key.x), int(key.y)))
		lo = minf(lo, v)
		hi = maxf(hi, v)
	_ease_include_value(lo)
	_ease_include_value(hi)

func _draw_overlay() -> void:
	if _mode == "marquee":
		var r := _marquee_rect()
		if r.size.x >= 2.0 or r.size.y >= 2.0:
			_overlay.draw_rect(r, Color(0.15, 0.4, 0.72, 0.16), true)
			_overlay.draw_rect(r, Color("1d4e89"), false, 2.0)
	if _group.size() < 2:
		return
	var box := _group_rect()
	if box.size.x < 4.0 or box.size.y < 4.0:
		return
	_overlay.draw_rect(box, Color(0.15, 0.4, 0.72, 0.10), true)
	_overlay.draw_rect(box, Color("1d4e89"), false, 2.0)
	_draw_grip(Vector2(box.get_center().x, box.position.y))
	_draw_grip(Vector2(box.get_center().x, box.end.y))

func _draw_grip(c: Vector2) -> void:
	var g := Rect2(c - Vector2(16, 5), Vector2(32, 10))
	_overlay.draw_rect(g.grow(1.5), Color.WHITE, true)
	_overlay.draw_rect(g, Color("1d4e89"), true)

func _ensure_visible(level_index: int) -> void:
	if float(level_index) < cam_to:
		cam_to = float(level_index)
	elif float(level_index) > cam_to + span_to:
		cam_to = float(level_index) - span_to
	_clamp_targets()
	_view_anim = true

func _apply_diff(v: int) -> void:
	var curves := _curves()
	if sel_c < 0 or sel_c >= curves.size():
		return
	var diff: Array = curves[sel_c]["diff"]
	if sel_l < 0 or sel_l >= diff.size():
		return
	if int(diff[sel_l]) == v:
		queue_redraw()
		return
	diff[sel_l] = v
	var other := 1 - sel_c
	if other >= 0 and other < curves.size():
		var mate: Array = curves[other]["diff"]
		if sel_l < mate.size():
			if sel_c == 0 and int(mate[sel_l]) < v:
				mate[sel_l] = v
			elif sel_c == 1 and int(mate[sel_l]) > v:
				mate[sel_l] = v
	_touch()
	_roll()

func _coast(delta: float) -> void:
	if _pan_pix.length() < 40.0:
		_fling = false
		_pan_pix = Vector2.ZERO
		_sync_targets()
		return
	var plot := _plot()
	var step := _step()
	var yspan := maxf(y1 - y0, YSPAN_MIN)
	var yscale := yspan / maxf(1.0, plot.size.y)
	if step > 1.0:
		cam -= _pan_pix.x * delta / step
	y0 += _pan_pix.y * delta * yscale
	var cam_max := _cam_max()
	if cam <= 0.0:
		cam = 0.0
		_pan_pix.x = 0.0
	elif cam >= cam_max:
		cam = cam_max
		_pan_pix.x = 0.0
	var y_max := maxf(0.0, 12000.0 - yspan)
	if y0 <= 0.0:
		y0 = 0.0
		_pan_pix.y = 0.0
	elif y0 >= y_max:
		y0 = y_max
		_pan_pix.y = 0.0
	y1 = y0 + yspan
	cam_to = cam
	y0_to = y0
	y1_to = y1
	_pan_pix *= exp(-delta * 3.5)
	queue_redraw()

func _wheel_zoom(zoom_in: bool, at: Vector2) -> void:
	_fling = false
	_pan_pix = Vector2.ZERO
	var plot := _plot()
	var focus := at if plot.has_point(at) else plot.get_center()
	var fx := clampf((focus.x - plot.position.x) / maxf(plot.size.x, 1.0), 0.0, 1.0)
	var fy := clampf((plot.end.y - focus.y) / maxf(plot.size.y, 1.0), 0.0, 1.0)
	var factor := 0.86 if zoom_in else 1.0 / 0.86
	var ax := cam_to + fx * span_to
	var yr0 := maxf(y1_to - y0_to, 0.001)
	var ay := y0_to + fy * yr0
	span_to = clampf(span_to * factor, SPAN_MIN, SPAN_MAX)
	var yr := clampf(yr0 * factor, YSPAN_MIN, YSPAN_MAX)
	cam_to = ax - fx * span_to
	y0_to = ay - fy * yr
	y1_to = y0_to + yr
	_clamp_targets()
	_view_anim = true

func _sync_targets() -> void:
	cam_to = cam
	span_to = span
	y0_to = y0
	y1_to = y1
	_view_anim = false

func _clamp_live() -> void:
	span = clampf(span, SPAN_MIN, SPAN_MAX)
	cam = clampf(cam, 0.0, maxf(0.0, SPAN_MAX - span))
	var yr := clampf(y1 - y0, YSPAN_MIN, YSPAN_MAX)
	y0 = maxf(y0, 0.0)
	y1 = y0 + yr

func _clamp_targets() -> void:
	span_to = clampf(span_to, SPAN_MIN, SPAN_MAX)
	cam_to = clampf(cam_to, 0.0, maxf(0.0, SPAN_MAX - span_to))
	var yr := clampf(y1_to - y0_to, YSPAN_MIN, YSPAN_MAX)
	y0_to = maxf(y0_to, 0.0)
	y1_to = y0_to + yr

func _max_in_window(left: float, width: float) -> float:
	var m := 4.0
	var lo := maxi(0, int(floor(left)) - 1)
	var hi := mini(LEVELS - 1, int(ceil(left + width)) + 1)
	for c in _curves():
		var diff = c.get("diff", [])
		if not (diff is Array):
			continue
		for li in range(lo, hi + 1):
			if li < diff.size():
				m = maxf(m, float(int(diff[li])))
	return m

func _ease_include_value(v: float) -> void:
	var yr := maxf(y1_to - y0_to, YSPAN_MIN)
	var pad := yr * 0.14
	var changed := false
	if v > y1_to - pad:
		y1_to = v + pad
		changed = true
	if v < y0_to + pad:
		y0_to = maxf(0.0, v - pad)
		changed = true
	if not changed:
		return
	_clamp_targets()
	_view_anim = true

func _ease_cover_visible() -> void:
	var m := _max_in_window(cam_to, span_to)
	if m <= y1_to * 0.92 and m >= y0_to:
		return
	if m > y1_to * 0.92:
		y1_to = maxf(y1_to, m * 1.15)
	_clamp_targets()
	_view_anim = true

func _normalize() -> void:
	var changed := false
	if not (page.get("curves") is Array) or (page["curves"] as Array).is_empty():
		page["curves"] = _starter()
		changed = true
	var curves: Array = page["curves"]
	var kept: Array = []
	for raw in curves:
		if raw is Dictionary:
			kept.append(raw)
	if kept.size() != curves.size():
		curves = kept
		page["curves"] = curves
		changed = true
	for c in curves:
		if not (c.get("diff") is Array):
			c["diff"] = []
			changed = true
		var diff: Array = c["diff"]
		var idx := curves.find(c)
		while diff.size() < LEVELS:
			diff.append(Roll.default_diff(idx, diff.size()))
			changed = true
		if diff.size() > LEVELS:
			diff.resize(LEVELS)
			changed = true
		for k in diff.size():
			var v := maxi(1, int(diff[k]))
			if int(diff[k]) != v:
				diff[k] = v
				changed = true
	if curves.size() != 2:
		page["curves"] = _collapse(curves)
		curves = page["curves"]
		changed = true
	var names := ["下限", "上限"]
	for i in 2:
		if str(curves[i].get("name", "")) != names[i]:
			curves[i]["name"] = names[i]
			changed = true
	var lo: Array = curves[0]["diff"]
	var hi: Array = curves[1]["diff"]
	for k in lo.size():
		if int(hi[k]) < int(lo[k]):
			hi[k] = int(lo[k])
			changed = true
	if changed:
		_touch()

func _collapse(curves: Array) -> Array:
	if curves.is_empty():
		return _starter()
	var low: Array = []
	var high: Array = []
	for k in LEVELS:
		var mn := 999999
		var mx := 1
		var any := false
		for c in curves:
			var diff: Array = c.get("diff", [])
			if k >= diff.size():
				continue
			any = true
			mn = mini(mn, int(diff[k]))
			mx = maxi(mx, int(diff[k]))
		if not any:
			mn = Roll.default_diff(0, k)
			mx = Roll.default_diff(2, k)
		low.append(maxi(1, mn))
		high.append(maxi(int(low[k]), mx))
	return [{"name": "下限", "diff": low}, {"name": "上限", "diff": high}]

func _starter() -> Array:
	var low: Array = []
	var high: Array = []
	for k in LEVELS:
		low.append(Roll.default_diff(0, k))
		high.append(Roll.default_diff(2, k))
	return [{"name": "下限", "diff": low}, {"name": "上限", "diff": high}]

func _roll() -> void:
	var avoid: Array = []
	if order.get("items") is Array:
		avoid = order["items"]
	order = Roll.make(sel_l + 1, float(_diff(sel_c, sel_l)), rng, avoid)
	_sync_item_hits()
	queue_redraw()

func _touch() -> void:
	if edit != null and edit.has_method("_touch") and edit.has_method("_page_path"):
		edit._touch(str(edit._page_path("rand")))

func _yield_scroll() -> void:
	if edit != null and edit.get("_sc") != null:
		edit._sc.yield_gesture()

func _draw_legend() -> void:
	for i in _curves().size():
		var r := _legend_at(i)
		var col := _color(i)
		var on := i == sel_c
		var box := Art.rrect(r, 12, 8 + i, 0.25)
		if on:
			Art.dilate(self, box, 2.5, Art.INK)
		draw_colored_polygon(box, col.lightened(0.42) if on else Color("fff7e6"))
		var mid := r.get_center()
		draw_line(Vector2(r.position.x + 8, mid.y), Vector2(r.position.x + 28, mid.y), col, 4.0, true)
		draw_circle(Vector2(r.position.x + 18, mid.y), 6.5, Art.INK)
		draw_circle(Vector2(r.position.x + 18, mid.y), 4.5, col)
		_text(str(_curves()[i].get("name", "")), Vector2(r.position.x + 32, mid.y + 7), 20, Art.INK)

func _draw_grid(plot: Rect2) -> void:
	draw_line(Vector2(plot.position.x, plot.position.y), Vector2(plot.position.x, plot.end.y), Color("6b4a2a"), 2.0, true)
	draw_line(Vector2(plot.position.x, plot.end.y), Vector2(plot.end.x, plot.end.y), Color("6b4a2a"), 2.0, true)
	_text("火苗", Vector2(16, plot.position.y - 8), 16, Color("6b4a2a"))
	_text("等级", Vector2(16, plot.end.y + 22), 16, Color("6b4a2a"))
	var yr := maxf(y1 - y0, 0.001)
	for t in [0.0, 0.25, 0.5, 0.75, 1.0]:
		var v := y0 + yr * float(t)
		var y := _y_of(v)
		var label := Roll.fmt(v)
		var baseline := y + 6.0
		if float(t) >= 0.99:
			baseline = y + 18.0
		elif float(t) <= 0.01:
			baseline = y - 2.0
		_text(label, Vector2(plot.position.x - 10.0 - _text_w(label, 16), baseline), 16, Color("6b4a2a"))
	var stride := 1
	var step_px := _step()
	if step_px < 32.0:
		stride = int(ceil(32.0 / step_px))
	for li in LEVELS:
		if not _point_on_screen(li):
			continue
		if li != sel_l and stride > 1 and li % stride != 0:
			continue
		var label := str(li + 1)
		var fs := 18 if li == sel_l else 15
		var col := Art.CLAY if li == sel_l else Color("6b4a2a")
		_text_c(label, Vector2(_x_of(li), plot.end.y + 22), fs, col)

func _draw_band(plot: Rect2) -> void:
	if _curves().size() < 2:
		return
	var fill := Color("eaa53c")
	fill.a = 0.34
	var prev_lo := Vector2.ZERO
	var prev_hi := Vector2.ZERO
	var have := false
	for li in LEVELS:
		var lo := _point(0, li)
		var hi := _point(1, li)
		if have:
			var quad := _clip_band(prev_lo, prev_hi, lo, hi, plot.position.x, plot.end.x)
			if quad.size() >= 3:
				_ci().draw_colored_polygon(quad, fill)
		prev_lo = lo
		prev_hi = hi
		have = true

func _clip_band(a_lo: Vector2, a_hi: Vector2, b_lo: Vector2, b_hi: Vector2, left: float, right: float) -> PackedVector2Array:
	if a_lo.x > b_lo.x:
		return _clip_band(b_lo, b_hi, a_lo, a_hi, left, right)
	if b_lo.x < left or a_lo.x > right:
		return PackedVector2Array()
	var span_x := b_lo.x - a_lo.x
	if span_x < 0.001:
		return PackedVector2Array([a_hi, b_hi, b_lo, a_lo])
	var t0 := 0.0
	var t1 := 1.0
	if a_lo.x < left:
		t0 = (left - a_lo.x) / span_x
	if b_lo.x > right:
		t1 = (right - a_lo.x) / span_x
	var lo0 := a_lo.lerp(b_lo, t0)
	var hi0 := a_hi.lerp(b_hi, t0)
	var lo1 := a_lo.lerp(b_lo, t1)
	var hi1 := a_hi.lerp(b_hi, t1)
	return PackedVector2Array([hi0, hi1, lo1, lo0])

func _draw_curves(plot: Rect2) -> void:
	var curves := _curves()
	for pass_i in 2:
		for ci in curves.size():
			var selected := ci == sel_c
			if selected != (pass_i == 1):
				continue
			var col := _color(ci)
			var diff: Array = curves[ci]["diff"]
			var prev := Vector2.ZERO
			var have := false
			for li in diff.size():
				var p := _point(ci, li)
				if have:
					var seg := _xclip(prev, p, plot.position.x, plot.end.x)
					if seg.size() == 2:
						_ci().draw_line(seg[0], seg[1], col, 6.0 if selected else 3.5, true)
				prev = p
				have = true
			for li in LEVELS:
				if not _point_on_screen(li):
					continue
				var p := _point(ci, li)
				var picked := selected and li == sel_l
				var grouped := _in_group(ci, li) or _marquee_has(ci, li)
				var radius := 12.0 if picked else (8.0 if selected else 6.0)
				_ci().draw_circle(p, radius + 2.0, Art.INK)
				_ci().draw_circle(p, radius, col)
				if picked:
					_ci().draw_circle(p, 4.2, Color.WHITE)
				if grouped:
					var side := (radius + 7.0) * 2.0
					_ci().draw_rect(Rect2(p - Vector2(side, side) * 0.5, Vector2(side, side)), Color("1d4e89"), false, 2.5)

func _draw_selected_value(plot: Rect2) -> void:
	if not _point_on_screen(sel_l):
		return
	var p := _point(sel_c, sel_l)
	if p.y < plot.position.y or p.y > plot.end.y:
		return
	var label := str(_diff(sel_c, sel_l))
	var fs := 18
	var tw := _text_w(label, fs)
	var bubble := Rect2(p.x - tw * 0.5 - 8.0, p.y - 38.0, tw + 16.0, 24.0)
	if bubble.position.y < plot.position.y + 2.0:
		bubble.position.y = p.y + 16.0
	_ci().draw_rect(bubble, Color("3b2314"), true)
	_text(label, Vector2(bubble.position.x + 8.0, bubble.position.y + 18.0), fs, Color.WHITE)

func _draw_info() -> void:
	if _curves().is_empty():
		return
	var y := _info_y()
	var target := _diff(sel_c, sel_l)
	var left := "%d 级 · 下限 %d · 上限 %d" % [sel_l + 1, _diff(0, sel_l), _diff(1, sel_l)]
	_text(left, Vector2(24, y), 22, Art.INK)
	var items = order.get("items", [])
	if items is Array and not items.is_empty():
		var got := Roll.total(items)
		var err := absf(got - float(target))
		var col := Color("2f7a32") if err <= maxf(1.0, float(target) * 0.12) else Art.CLAY
		var tail := "这单 %s 火苗" % Roll.fmt(got)
		_text(tail, Vector2(36.0 + _text_w(left, 22), y), 22, col)

func _item_spots() -> Array:
	var items: Array = order["items"] if order.get("items") is Array else []
	var out: Array = []
	if items.is_empty():
		return out
	var r := _card_rect()
	var n := items.size()
	var slot := minf(150.0, (r.size.x - 40.0) / float(n))
	var cy := r.position.y + r.size.y * 0.50
	var x0 := r.get_center().x - (float(n) - 1.0) * slot * 0.5
	for i in n:
		var c := Vector2(x0 + float(i) * slot, cy)
		out.append({"id": str(items[i]), "rect": Rect2(c - Vector2(48, 50), Vector2(96, 116))})
	return out

func _sync_item_hits() -> void:
	for b in _item_hits:
		if b is Node:
			(b as Node).queue_free()
	_item_hits.clear()
	for spot in _item_spots():
		var id := str(spot["id"])
		var btn := UI.hit(self, spot["rect"], func():
			if G.main != null and id != "":
				G.main.open("item_info", id))
		btn.z_index = 2
		_item_hits.append(btn)

func _card_rect() -> Rect2:
	var n := 1
	if order.get("items") is Array:
		n = maxi(1, (order["items"] as Array).size())
	var w := clampf(96.0 + float(n) * 156.0, 460.0, 688.0)
	var y := _info_y() + 16.0
	var h := _button_y() - 12.0 - y
	return Rect2((size.x - w) * 0.5, y, w, maxf(120.0, h))

func _draw_order() -> void:
	var r := _card_rect()
	var items: Array = order["items"] if order.get("items") is Array else []
	draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(0, 8), r.size), 18, 4, 0.0), Color(0, 0, 0, 0.28))
	var body := Art.rrect(r, 18, 60, 0.8)
	Art.dilate(self, body, 3.0, Art.INK)
	draw_colored_polygon(body, Color("fbf0d6"))
	Art.dashed(self, Art.rrect(r.grow(-6), 12, 61, 0.0), 8, 6, Color(0.65, 0.4, 0.2, 0.45), 2.0)
	if items.is_empty():
		_text_c("这个等级还没有能出的物品", r.get_center() + Vector2(0, 8), 22, Art.INK)
		return
	var head_c := r.position + Vector2(52, 46)
	var head := Art.ell(head_c, Vector2(30, 30), 62, 0.02, 20)
	Art.dilate(self, head, 3.0, Art.INK)
	draw_colored_polygon(head, Art.TEAL.lightened(0.3))
	var who := int(order.get("who", 0))
	Meme.portrait(self, who, head_c + Vector2(0, -2), 56)
	_text(_who_name(who), r.position + Vector2(92, 54), 22, Art.INK)
	var n := items.size()
	var slot := minf(150.0, (r.size.x - 40.0) / float(n))
	var cy := r.position.y + r.size.y * 0.50
	var x0 := r.get_center().x - (float(n) - 1.0) * slot * 0.5
	for i in n:
		var id := str(items[i])
		var c := Vector2(x0 + float(i) * slot, cy)
		draw_colored_polygon(Art.ell(c + Vector2(0, 4), Vector2(34, 26), 70 + i, 0.03, 16), Color(0.8, 0.65, 0.4, 0.35))
		Art.item(self, id, c, 78)
		var cost := Roll.fmt(Roll.flames(id))
		var fs := 16
		var tw := _text_w(cost, fs)
		var icon := 22.0
		var left := c.x - (icon + 2.0 + tw) * 0.5
		var base := c.y + 54.0
		Art.item(self, "fire_2", Vector2(left + icon * 0.5, base - 6.0), icon, false)
		_text(cost, Vector2(left + icon + 2.0, base), fs, Color("8a4b12"))
	var shell := int(order.get("rw", {}).get("shell", 0))
	var chip_c := Vector2(r.get_center().x, r.end.y - 26)
	draw_colored_polygon(Art.rrect(Rect2(chip_c - Vector2(46, 16), Vector2(92, 32)), 14, 80, 0.3), Color(0.55, 0.35, 0.15, 0.18))
	Art.item(self, "shell_2", chip_c + Vector2(-24, 0), 32, false)
	_text(str(shell), chip_c + Vector2(-6, 7), 20, Art.INK)

func _who_name(i: int) -> String:
	if Data.PEOPLE.is_empty():
		return ""
	var s := str(Data.PEOPLE[posmod(i, Data.PEOPLE.size())])
	var at := s.find(" ")
	return s.substr(at + 1) if at >= 0 else s

func _text_w(text: String, fs: int) -> float:
	var f: Font = G.font_body
	if f == null:
		return float(maxi(text.length(), 1)) * float(fs)
	return f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x

func _text(text: String, baseline_left: Vector2, fs: int, col: Color) -> void:
	var f: Font = G.font_body
	if f == null:
		return
	_ci().draw_string(f, baseline_left, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

func _text_c(text: String, baseline_center: Vector2, fs: int, col: Color) -> void:
	var f: Font = G.font_body
	if f == null:
		return
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	_ci().draw_string(f, Vector2(baseline_center.x - w * 0.5, baseline_center.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

func _xclip(a: Vector2, b: Vector2, left: float, right: float) -> PackedVector2Array:
	if a.x > b.x:
		var flipped := _xclip(b, a, left, right)
		if flipped.size() < 2:
			return flipped
		return PackedVector2Array([flipped[1], flipped[0]])
	if b.x < left or a.x > right:
		return PackedVector2Array()
	var span := b.x - a.x
	if span < 0.001:
		return PackedVector2Array([a, b])
	var aa := a
	var bb := b
	if a.x < left:
		aa = a.lerp(b, (left - a.x) / span)
	if b.x > right:
		bb = a.lerp(b, (right - a.x) / span)
	return PackedVector2Array([aa, bb])
