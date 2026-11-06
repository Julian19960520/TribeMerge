extends Control
var btn: TButton
func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	btn = UI.hit(self, Rect2(Vector2.ZERO, size), func(): G.main.open("seven_day"))
	btn.extra = _paint
	G.seven_day_changed.connect(func(): btn.queue_redraw())
func _paint(ci: CanvasItem, sz: Vector2) -> void:
	var ready := SevenDay.ready()
	var badge := {"text": "领奖", "style": "go"} if ready else {"text": "%d/%d" % [SevenDay.claimed_count(), SevenDay.task_count()], "style": "num"}
	EventEntryArt.paint(ci, sz, "seven", "七日任务", badge, false, ready)
