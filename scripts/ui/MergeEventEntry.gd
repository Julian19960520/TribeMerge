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
	var ready := unlocked and MergeEvent.complete(cfg, s) and not bool(s["claimed"])
	var badge := {"text": "×%d" % int(s.get("points", 0)), "style": "num"}
	if ready: badge = {"text": TextCatalog.source("ui.duelentry.5375104054f0"), "style": "go"}
	elif not unlocked: badge = {"text": TextCatalog.source("ui.mergeevententry.1663dd3dc737") if cfg.is_empty() else TextCatalog.fill(TextCatalog.source("ui.duelentry.e0cda514ecc2"), int(cfg["unlock_level"])), "style": "lock"}
	elif float(cfg.get("ends_at", 0)) - G.now() < 86400: badge = {"text": _left(float(cfg["ends_at"]) - G.now()), "style": "time"}
	# 默认的月石主题用程序手绘图；别的主题可以在配置里给自己的 entry_icon 贴图
	var icon := str(cfg.get("theme", {}).get("entry_icon", ""))
	var kind := "ruins" if icon == "" or icon.ends_with("/ruins.svg") else icon
	EventEntryArt.paint(ci, sz, kind, str(cfg.get("entry_title", TextCatalog.source("ui.mergeevententry.973c334a813e"))), badge, not unlocked, ready)

static func _left(sec: float) -> String:
	var t := maxi(0, int(sec))
	return TextCatalog.fill(TextCatalog.source("ui.board.e9e4f4da0297"), [t / 3600, str(int(t / 60 % 60)).pad_zeros(2)]) if t >= 3600 else TextCatalog.fill(TextCatalog.source("notice.game.30c88ef0108b"), [t / 60, str(int(t % 60)).pad_zeros(2)])

func _txt(ci: CanvasItem, text: String, p: Vector2, fs: int, col: Color) -> void:
	var w := G.font_title.get_string_size(TextCatalog.resolve(text), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := p - Vector2(w / 2, 0)
	ci.draw_string_outline(G.font_title, pos, TextCatalog.resolve(text), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Art.INK)
	ci.draw_string(G.font_title, pos, TextCatalog.resolve(text), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
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
