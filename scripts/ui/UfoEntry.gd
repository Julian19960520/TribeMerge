extends Control
## 棋盘顶部的外星补给入口：圆形玻璃气泡里装着飞碟，下面挂倒计时胶囊，整体左右飘 + 上下轻晃。
## 气泡用深色夜空底，不管飘到订单卡还是活动入口上面，飞碟和倒计时都能看清。
const W := 150.0
const H := 172.0
const C := Vector2(75, 68)
const RAD := 60.0
## 飘动范围（相对 position）：右端 0，左端 -300
const SWING := 300.0
var hit: TButton
var timer: Label
var _clock := 0.0
var _shown := false
var _motion: Tween
var _t := 0.0
var _tex: Texture2D
func _ready() -> void:
	position = Vector2(560, 96)
	size = Vector2(W, H)
	mouse_filter = MOUSE_FILTER_IGNORE
	_tex = load(str(UfoOffer.config()["icon"]))
	hit = UI.hit(self, Rect2(Vector2.ZERO, size), UfoOffer.open_panel)
	hit.name = "ufo_entry"
	hit.extra = _paint
	timer = UI.lbl(hit, "", Rect2(26, 128, 98, 34), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 4, Color("1b2a33"))
	var tag := UI.lbl(hit, "5折", Rect2(98, 0, 58, 32), 19, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 5, Art.INK, true)
	tag.rotation = 0.22
	hit.visible = false
func _paint(ci: CanvasItem, _sz: Vector2) -> void:
	# 气泡
	ci.draw_circle(C + Vector2(0, 7), RAD + 3, Color(0, 0, 0, 0.28))
	ci.draw_circle(C, RAD + 3, Art.INK)
	ci.draw_circle(C, RAD, Color("dff7f0"))
	ci.draw_circle(C, RAD - 4, Color("234a63"))
	ci.draw_circle(C + Vector2(0, 6), RAD - 14, Color("2e6377"))
	ci.draw_circle(C + Vector2(0, 12), RAD - 28, Color("3d7d88"))
	for k in 9:
		var p := C + Vector2((Art.srnd(k * 5 + 1) - 0.5) * 84, (Art.srnd(k * 7 + 2) - 0.75) * 70)
		if p.distance_to(C) < RAD - 10:
			ci.draw_circle(p, 1.2 + Art.srnd(k) * 1.4, Color(1, 1, 0.85, 0.8))
	# 牵引光
	var beam := PackedVector2Array([C + Vector2(-10, 18), C + Vector2(10, 18), C + Vector2(30, 52), C + Vector2(-30, 52)])
	ci.draw_colored_polygon(beam, Color(0.76, 0.92, 0.48, 0.32))
	# 飞碟（轻轻摇）
	var tilt := sin(_t * 2.2) * 0.06
	ci.draw_set_transform(C + Vector2(0, -6 + sin(_t * 3.0) * 2.0), tilt, Vector2.ONE)
	ci.draw_texture_rect(_tex, Rect2(-54, -40, 108, 76), false)
	ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# 玻璃高光
	ci.draw_arc(C, RAD - 9, 3.55, 4.55, 18, Color(1, 1, 1, 0.75), 4.0, true)
	ci.draw_circle(C + Vector2(-38, -20), 4, Color(1, 1, 1, 0.7))
	# 倒计时胶囊
	var pill := Art.rrect(Rect2(22, 126, 106, 38), 19, 703, 0.4)
	Art.dilate(ci, pill, 3.0, Art.INK)
	ci.draw_colored_polygon(pill, Color("1b2a33"))
	# 「5折」小签
	ci.draw_set_transform(Vector2(127, 16), 0.22, Vector2.ONE)
	var t := Art.rrect(Rect2(-28, -15, 56, 30), 9, 704, 0.4)
	Art.dilate(ci, t, 2.5, Art.INK)
	ci.draw_colored_polygon(t, Art.CLAY)
	ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	if hit.visible:
		_t += delta
		# 左右飘：正弦来回，两端放慢；上下再叠一层小幅晃动
		var u := 0.5 - 0.5 * cos(_t * TAU / 9.0)
		var bob := sin(_t * TAU / 2.6) * 5.0
		if _motion == null or not _motion.is_valid():
			hit.position = Vector2(-SWING * u, bob)
		hit.queue_redraw()
	_clock += delta
	if _clock < 1: return
	_clock = 0
	if G.tutorial_on:
		hit.visible = false
		_shown = false
		return
	UfoOffer.tick()
	var show_offer := UfoOffer.active() and not G.tutorial_on
	var left := UfoOffer.remaining()
	timer.text = "%02d:%02d" % [left / 60, left % 60]
	if _shown == show_offer: return
	_shown = show_offer
	hit.visible = show_offer
	if _motion != null and _motion.is_valid(): _motion.kill()
	if show_offer:
		# 从右上方飞进来，再开始飘
		_t = 0.0
		hit.position = Vector2(200, -120)
		hit.scale = Vector2(0.6, 0.6)
		hit.pivot_offset = C
		_motion = create_tween().set_parallel(true)
		_motion.tween_property(hit, "position", Vector2.ZERO, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_motion.tween_property(hit, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_motion.chain().tween_callback(func(): _t = 0.0)
