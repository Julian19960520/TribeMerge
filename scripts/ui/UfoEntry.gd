extends Control
## 棋盘顶部的外星补给入口：圆形玻璃气泡里装着飞碟，内部底端显示倒计时，整体左右飘 + 上下轻晃。
## 气泡用深色夜空底，不管飘到订单卡还是活动入口上面，飞碟和倒计时都能看清。
const W := 150.0
const H := 140.0
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
func _ready() -> void:
	position = Vector2(560, 96)
	size = Vector2(W, H)
	mouse_filter = MOUSE_FILTER_IGNORE
	hit = UI.hit(self, Rect2(Vector2.ZERO, size), UfoOffer.open_panel)
	hit.name = "ufo_entry"
	hit.extra = _paint
	timer = UI.lbl(hit, "", Rect2(31, 86, 88, 30), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 4, Color("1b2a33"))
	var tag := UI.lbl(hit, "5折", Rect2(98, 0, 58, 32), 19, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 5, Art.INK, true)
	tag.rotation = 0.22
	hit.visible = false
## 全部用 Art 的抖动形状画，跟着全局沸腾线一起抖；配色压到夜空蓝 + 骨白 + 一点黄绿。
func _paint(ci: CanvasItem, _sz: Vector2) -> void:
	# 气泡：墨线 + 骨白玻璃边 + 夜空底
	var bub := Art.ell(C, Vector2(RAD, RAD), 801, 0.03, 26)
	ci.draw_colored_polygon(Art.ell(C + Vector2(0, 6), Vector2(RAD + 2, RAD + 2), 802, 0.03, 26), Color(0, 0, 0, 0.25))
	Art.dilate(ci, bub, 3.0, Art.INK)
	ci.draw_colored_polygon(bub, Color("dff7f0"))
	ci.draw_colored_polygon(Art.ell(C, Vector2(RAD - 5, RAD - 5), 803, 0.03, 24), Color("27506a"))
	# 牵引光
	var beam := Art.poly([C + Vector2(-9, 8), C + Vector2(9, 8), C + Vector2(28, 44), C + Vector2(-28, 44)], 804)
	ci.draw_colored_polygon(beam, Color(0.8, 0.95, 0.5, 0.35))
	# 飞碟：轻轻晃
	var o := C + Vector2(0, -12 + sin(_t * 3.0) * 2.0)
	var tilt := sin(_t * 2.2) * 0.07
	ci.draw_set_transform(o, tilt, Vector2.ONE)
	var dome := Art.ell(Vector2(0, -8), Vector2(17, 15), 805, 0.05, 16)
	Art.fill(ci, dome, Color("bfeee6"), 2.6)
	ci.draw_colored_polygon(Art.ell(Vector2(-6, -13), Vector2(4, 3), 806, 0.1, 8), Color(1, 1, 1, 0.8))
	var disc := Art.ell(Vector2(0, 2), Vector2(40, 11), 807, 0.04, 20)
	Art.fill(ci, disc, Color("a7b4b8"), 2.8)
	Art.fill(ci, Art.ell(Vector2(0, 0), Vector2(30, 5), 808, 0.05, 14), Color("d7e0e2"), 0.0)
	for k in 3:
		var on := int(_t * 3.0 + k) % 3 == 0
		Art.fill(ci, Art.ell(Vector2(-20 + k * 20, 6), Vector2(4, 3.5), 809 + k, 0.1, 8), Art.FIRE2 if on else Color("e8b44a"), 1.8)
	ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# 玻璃高光
	Art.pl(ci, [C + Vector2(-40, -26), C + Vector2(-30, -40), C + Vector2(-16, -48)], 4.0, Color(1, 1, 1, 0.7), 812)
	# 倒计时底条
	var bar := Art.rrect(Rect2(C.x - 40, 88, 80, 28), 12, 813, 0.6)
	ci.draw_colored_polygon(bar, Color(0.08, 0.15, 0.2, 0.75))
	# 「5折」小签
	ci.draw_set_transform(Vector2(127, 16), 0.22, Vector2.ONE)
	Art.fill(ci, Art.rrect(Rect2(-28, -15, 56, 30), 9, 814, 0.6), Art.CLAY, 2.5)
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
