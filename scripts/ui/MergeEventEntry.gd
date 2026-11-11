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
	var ready := unlocked and MergeEvent.complete(cfg, s) and not bool(s["claimed"])
	var badge := {"text": "×%d" % int(s.get("points", 0)), "style": "num"}
	if ready: badge = {"text": "领奖", "style": "go"}
	elif not unlocked: badge = {"text": "筹备中" if cfg.is_empty() else "%d级" % int(cfg["unlock_level"]), "style": "lock"}
	elif float(cfg.get("ends_at", 0)) - G.now() < 86400: badge = {"text": _left(float(cfg["ends_at"]) - G.now()), "style": "time"}
	# 默认的月石主题用程序手绘图；别的主题可以在配置里给自己的 entry_icon 贴图
	var icon := str(cfg.get("theme", {}).get("entry_icon", ""))
	var kind := "ruins" if icon == "" or icon.ends_with("/ruins.svg") else icon
	EventEntryArt.paint(ci, sz, kind, str(cfg.get("entry_title", "月石遗迹")), badge, not unlocked, ready)

static func _left(sec: float) -> String:
	var t := maxi(0, int(sec))
	return "%d时%02d分" % [t / 3600, t / 60 % 60] if t >= 3600 else "%d分%02d秒" % [t / 60, t % 60]

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
	fx.painter = func(ci, sz): ci.draw_texture_rect(MergeEventArt.texture(str(cfg["theme"]["point_icon"])), Rect2(Vector2.ZERO, sz), false)
	G.main.fx_layer.add_child(fx)
	var to := get_global_rect().get_center() - fx.size / 2
	var tw := fx.create_tween()
	tw.tween_property(fx, "position", to, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(fx.queue_free)
