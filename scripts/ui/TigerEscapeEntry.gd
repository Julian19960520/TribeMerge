extends Control
var button: TButton
var elapsed := 0.0
var _sync_elapsed := 0.0

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	button = UI.hit(self, Rect2(Vector2.ZERO, size), func(): G.main.open("tiger"))
	button.name = "tiger_entry"
	button.extra = _paint

func _process(delta: float) -> void:
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
	var m := TigerEscape.round_state()
	var text := TextCatalog.source("ui.tigerescapeentry.efdc22fca1c6")
	var style := "go"
	if not m.is_empty():
		if m["status"] == "running":
			text = TextCatalog.source("ui.tigerescapeentry.spots") % TigerEscape.stage_remaining(m)
			style = "time"
		else: text = TextCatalog.source("ui.raceentry.0e4062a72843")
	# 和其他活动入口同一套：贴纸主题图 + 状态小牌 + 名字（scripts/sprites/events.gd 的 _en_tiger）
	EventEntryArt.paint(ci, sz, "tiger", TextCatalog.source("ui.tigerescapeentry.5e7c1a9e58e6"), {"text": text, "style": style}, false, not TigerEscape.pending_rewards(m).is_empty())
