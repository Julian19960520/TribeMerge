extends Control
var button: TButton
var elapsed := 0.0
var _sync_elapsed := 0.0
## 活动积分飞进来时图片弹一下（ActivityPointsFx 设成 1）
var _bump := 0.0

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	button = UI.hit(self, Rect2(Vector2.ZERO, size), func(): G.main.open("tiger"))
	button.name = "tiger_entry"
	button.extra = _paint

func _process(delta: float) -> void:
	if _bump > 0.0:
		_bump = maxf(0.0, _bump - delta * 3.0)
		button.queue_redraw()
	elapsed += delta
	_sync_elapsed += delta
	if _sync_elapsed >= 20.0:
		_sync_elapsed = 0.0
		var m := TigerEscape.round_state()
		if not m.is_empty() and str(m.get("status", "")) == "running" and Cloud.can_talk():
			TigerEscape.refresh_from_server()
	if elapsed >= 1:
		elapsed = 0
		button.queue_redraw()

func _paint(ci: CanvasItem, sz: Vector2) -> void:
	# 档期剩余时间；逃跑中再画已过的关数
	var m := TigerEscape.round_state()
	var info := {}
	if ActivitySchedule.scheduled("tiger"): info["left"] = ActivitySchedule.seconds_left("tiger")
	if not m.is_empty() and m["status"] == "running":
		info.merge({"have": int(m.get("stage", 0)), "need": m.get("stages", []).size(), "icon": "banana"})
	EventEntryArt.paint(ci, sz, "tiger", info, false, not TigerEscape.pending_rewards(m).is_empty(), _bump)
