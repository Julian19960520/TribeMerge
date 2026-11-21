extends Control
var btn: TButton
func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	btn = UI.hit(self, Rect2(Vector2.ZERO, size), func(): G.main.open("seven_day"))
	btn.extra = _paint
	G.seven_day_changed.connect(func(): btn.queue_redraw())
func _paint(ci: CanvasItem, sz: Vector2) -> void:
	# 剩余时间（从第一天登录算 7 天）+ 积分进度（满分 = 最后一档里程碑）
	var stages: Array = SevenDay.config()["milestones"]
	var need := int(stages[-1]["points"]) if not stages.is_empty() else 0
	EventEntryArt.paint(ci, sz, "seven", {"left": SevenDay.seconds_left(), "have": mini(SevenDay.points(), need), "need": need, "icon": "tag"}, false, SevenDay.ready())
