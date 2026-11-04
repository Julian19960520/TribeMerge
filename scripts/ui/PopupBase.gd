class_name PopupBase
extends Control

signal closed

var dim: ColorRect
var box: Control
var dim_alpha := 0.62
var tap_to_close := false
var on_tap: Callable
var on_close: Callable
var _closing := false

func _init() -> void:
	size = Vector2(720, 1480)
	mouse_filter = MOUSE_FILTER_STOP
	dim = ColorRect.new()
	dim.color = Color(0.1, 0.05, 0.02, 0.0)
	dim.size = size
	dim.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(dim)
	box = Control.new()
	box.size = size
	box.pivot_offset = size * 0.5
	box.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(box)

func open() -> void:
	box.scale = Vector2(0.7, 0.7)
	box.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(dim, "color:a", dim_alpha, 0.2)
	tw.tween_property(box, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(box, "modulate:a", 1.0, 0.15)
	Sfx.play("whoosh")

func close() -> void:
	if _closing:
		return
	_closing = true
	if on_close.is_valid():
		on_close.call()
	mouse_filter = MOUSE_FILTER_IGNORE
	var tw := create_tween().set_parallel(true)
	tw.tween_property(dim, "color:a", 0.0, 0.18)
	tw.tween_property(box, "scale", Vector2(0.85, 0.85), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(box, "modulate:a", 0.0, 0.18)
	tw.chain().tween_callback(func():
		closed.emit()
		queue_free())

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if on_tap.is_valid():
			on_tap.call()
		elif tap_to_close:
			close()
