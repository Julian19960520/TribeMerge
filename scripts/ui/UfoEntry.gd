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
## 全部贴预生成的图（scripts/sprites/events.gd），跟着全局沸腾线一起抖；配色压到夜空蓝 + 骨白 + 一点黄绿。
func _paint(ci: CanvasItem, _sz: Vector2) -> void:
	# 气泡底：墨线 + 骨白玻璃边 + 夜空底 + 牵引光
	Sprites.draw(ci, "ev_ufo_back", Rect2(0, 0, W, H))
	# 飞碟：轻轻晃，三颗灯轮流亮
	var o := C + Vector2(0, -12 + sin(_t * 3.0) * 2.0)
	var tilt := sin(_t * 2.2) * 0.07
	ci.draw_set_transform(o, tilt, Vector2.ONE)
	Sprites.draw(ci, "ev_ufo_saucer", Rect2(-44, -26, 88, 44))
	for k in 3:
		var on := int(_t * 3.0 + k) % 3 == 0
		Sprites.draw(ci, "ev_ufo_light_on" if on else "ev_ufo_light_off", Rect2(-25 + k * 20, 1, 10, 10))
	ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# 玻璃高光、倒计时底条、「5折」小签
	Sprites.draw(ci, "ev_ufo_front", Rect2(0, 0, W, H))

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
