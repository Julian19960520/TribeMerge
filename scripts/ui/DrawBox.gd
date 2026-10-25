class_name DrawBox
extends Control
## 通用自绘控件：painter(ci, size) 每次线条沸腾时重绘。

var painter: Callable
var boil := true

func _ready() -> void:
	if mouse_filter == MOUSE_FILTER_STOP:
		mouse_filter = MOUSE_FILTER_IGNORE
	if boil:
		G.boil_tick.connect(queue_redraw)

func _draw() -> void:
	if painter.is_valid():
		painter.call(self, size)
