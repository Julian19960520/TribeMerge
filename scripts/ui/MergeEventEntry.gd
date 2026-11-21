extends Control
const TextureCache := preload("res://scripts/resources/TextureCache.gd")
var btn: TButton
var cfg: Dictionary
var _last_key := ""
var _tick := 0.0
func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	btn = UI.hit(self, Rect2(Vector2.ZERO, size), func():
		if MergeEvent.available(cfg): G.main.open("merge_event")
		else: G.main.toast(TextCatalog.source("ui.mergeevententry.5f6f7b72a9c0") if cfg.is_empty() else TextCatalog.fill(TextCatalog.source("ui.mergeevententry.b2377e256fd8"), int(cfg["unlock_level"]))))
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
	# 还没进过这一季时存档里没有棋盘：进度按 0 算
	var have := MergeEvent.progress(cfg, s) if not s.is_empty() else 0
	var ready := not s.is_empty() and not MergeEvent.claimable(cfg, s).is_empty()
	var info := {}
	if unlocked: info = {"left": float(cfg.get("ends_at", 0)) - G.now(), "have": have, "need": MergeEvent.goal_total(cfg), "icon": str(cfg.get("theme", {}).get("point_icon", ""))}
	elif not cfg.is_empty(): info = {"lock": TextCatalog.fill(TextCatalog.source("ui.duelentry.e0cda514ecc2"), int(cfg["unlock_level"]))}
	# 默认的月石主题用程序手绘图；别的主题可以在配置里给自己的 entry_icon 贴图
	var icon := str(cfg.get("theme", {}).get("entry_icon", ""))
	var kind := "ruins" if icon == "" or icon.ends_with("/ruins.svg") else icon
	EventEntryArt.paint(ci, sz, kind, info, not unlocked, ready)

func fly_from(origin: Vector2) -> void:
	if cfg.is_empty() or not MergeEvent.available(cfg): return
	var fx := DrawBox.new()
	fx.size = Vector2(54, 54)
	fx.position = origin - fx.size / 2
	fx.painter = func(ci, sz):
		var icon := MergeEventArt.texture(str(cfg["theme"]["point_icon"]))
		TextureCache.hold(ci, icon)
		ci.draw_texture_rect(icon, Rect2(Vector2.ZERO, sz), false)
	G.main.fx_layer.add_child(fx)
	var to := get_global_rect().get_center() - fx.size / 2
	var tw := fx.create_tween()
	tw.tween_property(fx, "position", to, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(fx.queue_free)
