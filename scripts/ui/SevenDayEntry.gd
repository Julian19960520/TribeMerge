extends Control
var btn: TButton
func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	btn = UI.hit(self, Rect2(Vector2.ZERO, size), func(): G.main.open("seven_day"))
	btn.extra = _paint
	G.seven_day_changed.connect(func(): btn.queue_redraw())
func _paint(ci: CanvasItem, sz: Vector2) -> void:
	EventEntryArt.paint(ci,sz,"res://assets/events/entries/seven.svg","七日任务","领奖" if SevenDay.ready() else "成长","%d分" % SevenDay.points(),false,SevenDay.ready())
