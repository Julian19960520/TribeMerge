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
	TigerArt.draw(ci, Vector2(sz.x * 0.5, sz.y - 105), 90)
	var m := TigerEscape.round_state()
	var text := "出发"
	var style := "go"
	if not m.is_empty():
		if m["status"] == "running":
			text = "%d / %d" % [int(m["stage"]), m["stages"].size()]
			style = "time"
		else: text = "结算"
	EventEntryArt._pill(ci, Vector2(sz.x * 0.5, sz.y - 42), text, style)
	EventEntryArt.text(ci, "剑齿虎逃生", Vector2(sz.x * 0.5, sz.y - 8), 20, Color("fff0c5"))
	if not TigerEscape.pending_rewards(m).is_empty(): Paint.badge_num(ci, Vector2(sz.x - 18, 30), 8, 10)
