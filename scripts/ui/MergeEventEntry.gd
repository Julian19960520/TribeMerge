extends Control
var btn: TButton
var cfg: Dictionary
var _last_key := ""
var _tick := 0.0
func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	btn = UI.hit(self, Rect2(Vector2.ZERO, size), func():
		if MergeEvent.available(cfg): G.main.open("merge_event")
		else: G.main.toast("活动尚未开始" if cfg.is_empty() else "%d级开放" % int(cfg["unlock_level"])))
	btn.extra = _paint
	G.merge_event_changed.connect(_refresh)
	_refresh()
func _refresh() -> void:
	cfg = MergeEvent.current()
	btn.queue_redraw()
func _process(delta: float) -> void:
	_tick += delta
	if _tick >= 1:
		_tick = 0
		_refresh()
func _paint(ci: CanvasItem, sz: Vector2) -> void:
	var unlocked := MergeEvent.available(cfg)
	var s := MergeEvent.state(cfg) if unlocked else {}
	var ready := unlocked and MergeEvent.complete(cfg,s) and not bool(s["claimed"])
	var status := ("领奖" if ready else "探索") if unlocked else ("筹备中" if cfg.is_empty() else "%d级解锁" % int(cfg["unlock_level"]))
	var icon := str(cfg.get("theme",{}).get("entry_icon","res://assets/events/entries/ruins.svg"))
	EventEntryArt.paint(ci,sz,icon,str(cfg.get("entry_title","月石遗迹")),status,"×%d" % int(s.get("points",0)) if unlocked else "",not unlocked,unlocked and (int(s.get("points",0))>0 or ready) and not bool(s.get("claimed",false)))

func _txt(ci: CanvasItem, text: String, p: Vector2, fs: int, col: Color) -> void:
	var w := G.font_title.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := p - Vector2(w / 2, 0)
	ci.draw_string_outline(G.font_title, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Art.INK)
	ci.draw_string(G.font_title, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
func fly_from(origin: Vector2) -> void:
	if cfg.is_empty() or not MergeEvent.available(cfg): return
	var fx := DrawBox.new()
	fx.size = Vector2(54, 54)
	fx.position = origin - fx.size / 2
	fx.painter = func(ci, sz): ci.draw_texture_rect(MergeEvent.texture(str(cfg["theme"]["point_icon"])), Rect2(Vector2.ZERO, sz), false)
	G.main.fx_layer.add_child(fx)
	var to := get_global_rect().get_center() - fx.size / 2
	var tw := fx.create_tween()
	tw.tween_property(fx, "position", to, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(fx.queue_free)
