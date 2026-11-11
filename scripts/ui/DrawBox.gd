class_name DrawBox
extends Control
## Drawn controls only subscribe to animation while visible. Static painters opt out.

const VisualRuntime := preload("res://scripts/resources/VisualRuntime.gd")
var _in_view := false
var _boil_source: Node
var painter: Callable
var boil := true:
	set(value):
		boil = value
		if is_inside_tree(): _sync_boil()

func _ready() -> void:
	if mouse_filter == MOUSE_FILTER_STOP:
		mouse_filter = MOUSE_FILTER_IGNORE
	set_notify_transform(true)
	visibility_changed.connect(_sync_boil)
	resized.connect(_sync_boil)
	_sync_boil()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and is_node_ready(): _sync_boil()

func _exit_tree() -> void:
	# Teardown callbacks may change visibility after this control has left the
	# tree. Use the established source rather than resolving an absolute path.
	if is_instance_valid(_boil_source) and _boil_source.boil_tick.is_connected(_on_boil):
		_boil_source.boil_tick.disconnect(_on_boil)
	_boil_source = null
	_in_view = false

func _sync_boil() -> void:
	if not is_inside_tree():
		_in_view = false
		return
	var game := get_node_or_null("/root/G")
	if game == null: return
	_boil_source = game
	var connected: bool = game.boil_tick.is_connected(_on_boil)
	var visible_now := VisualRuntime.in_view(self)
	var animate := boil and visible_now
	if animate and not connected:
		game.boil_tick.connect(_on_boil)
	elif not animate and connected:
		game.boil_tick.disconnect(_on_boil)
	if visible_now and not _in_view: queue_redraw()
	_in_view = visible_now

func _draw() -> void:
	if painter.is_valid() and VisualRuntime.in_view(self):
		painter.call(self, size)

func _on_boil() -> void:
	if is_inside_tree(): queue_redraw()
