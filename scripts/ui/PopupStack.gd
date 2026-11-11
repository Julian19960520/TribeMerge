class_name PopupStack
extends Control
## Owns popup lifetime and the matching top-bar close targets.
var topbar: TopBar
var _stack: Array[PopupBase] = []
func _ready() -> void:
	size = Vector2(720, 1480)
	mouse_filter = MOUSE_FILTER_IGNORE
func present(popup: PopupBase) -> void:
	if _stack.has(popup): return
	_stack.append(popup)
	add_child(popup)
	topbar.on_popup_opened()
	var close_target := popup.close
	if popup.has_meta("fullscreen"): topbar.push_close(close_target)
	popup.tree_exiting.connect(func():
		_stack.erase(popup)
		if popup.has_meta("fullscreen"): topbar.pop_close(close_target), CONNECT_ONE_SHOT)
	popup.tree_exited.connect(topbar.on_popup_exited, CONNECT_ONE_SHOT)
	popup.open()
func clear() -> void:
	for popup in _stack.duplicate():
		if is_instance_valid(popup): popup.queue_free()
func top() -> PopupBase:
	return _stack.back() if not _stack.is_empty() else null
