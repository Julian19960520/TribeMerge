class_name Scroller
extends Control
## 惯性滚动容器。拖动超过阈值后，松手不会触发内部按钮。

var content: Control
var horizontal := false
var length := 0.0
var offset := 0.0
var _vel := 0.0
var _tracking := false
var _dragging := false
var _press := Vector2.ZERO
var _last := Vector2.ZERO
var _last_t := 0

func _init() -> void:
	clip_contents = true
	mouse_filter = MOUSE_FILTER_PASS
	content = Control.new()
	content.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(content)

func set_length(l: float) -> void:
	length = l
	content.size = Vector2(l, size.y) if horizontal else Vector2(size.x, l)
	offset = clampf(offset, 0.0, _max())
	_apply()

func _max() -> float:
	return maxf(0.0, length - (size.x if horizontal else size.y))

func _axis(v: Vector2) -> float:
	return v.x if horizontal else v.y

func _inside() -> bool:
	if not is_visible_in_tree():
		return false
	var h := get_viewport().gui_get_hovered_control()
	return h != null and (h == self or is_ancestor_of(h))

func _input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				if _inside():
					_tracking = true
					_dragging = false
					_press = get_global_mouse_position()
					_last = _press
					_last_t = Time.get_ticks_msec()
					_vel = 0.0
			elif _tracking:
				_tracking = false
				if _dragging:
					G.scroll_drag = true
					G.clear_scroll_drag.call_deferred()
		elif e.pressed and _inside() and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_vel += (-1.0 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0) * 900.0
	elif e is InputEventMouseMotion and _tracking:
		var p := get_global_mouse_position()
		if not _dragging and absf(_axis(p - _press)) > 12.0:
			_dragging = true
		if _dragging:
			var d := _axis(p - _last)
			var over := offset < 0.0 or offset > _max()
			offset -= d * (0.4 if over else 1.0)
			var now := Time.get_ticks_msec()
			var dt := maxf(1.0, float(now - _last_t)) / 1000.0
			_vel = lerpf(_vel, -d / dt, 0.4)
			_last_t = now
			_apply()
		_last = p

func _process(delta: float) -> void:
	if _tracking and _dragging:
		return
	if absf(_vel) > 1.0:
		offset += _vel * delta
		_vel *= exp(-delta * 4.0)
	else:
		_vel = 0.0
	var m := _max()
	if offset < 0.0:
		offset = lerpf(offset, 0.0, 1.0 - exp(-delta * 14.0))
		_vel *= 0.6
	elif offset > m:
		offset = lerpf(offset, m, 1.0 - exp(-delta * 14.0))
		_vel *= 0.6
	_apply()

func _apply() -> void:
	if horizontal:
		content.position = Vector2(-offset, 0)
	else:
		content.position = Vector2(0, -offset)
