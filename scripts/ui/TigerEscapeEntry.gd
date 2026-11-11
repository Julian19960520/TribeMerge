extends Control
var button: TButton
var elapsed := 0.0

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	button = UI.hit(self, Rect2(Vector2.ZERO, size), func(): G.main.open("tiger"))
	button.name = "tiger_entry"
	button.extra = _paint

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= 1:
		elapsed = 0
		button.queue_redraw()

func _paint(ci: CanvasItem, sz: Vector2) -> void:
	var m := TigerEscape.round_state()
	var text := "出发"
	var style := "go"
	if not m.is_empty():
		if m["status"] == "running":
			text = "%d / %d" % [int(m["stage"]), m["stages"].size()]
			style = "time"
		else: text = "结算"
	# 和其他活动入口同一套：贴纸主题图 + 状态小牌 + 名字（scripts/sprites/events.gd 的 _en_tiger）
	EventEntryArt.paint(ci, sz, "tiger", "剑齿虎逃生", {"text": text, "style": style}, false, not TigerEscape.pending_rewards(m).is_empty())
