extends Control
## 活动积分飞入：交单 / 合成高级物品时，从订单卡或合成格冒出「活动图标 +分数」，
## 弹一下、停一拍，再沿弧线飞进对应的活动入口，入口跟着一弹。
## 挂在 G.main.fx_layer 上用全局坐标；播完自己删掉，不挡点击。

const POP := 0.24
const HOLD := 0.4
const FLY := 0.55
const ICON := 0.56
const GOLD := Color("ffe066")

var kind := "race"
var amount := 0
var from := Vector2.ZERO
var entry: Control
var delay := 0.0
## 几个活动同时得分时各自弹到的位置（相对冒出点），排成一排不叠在一起
var spread := Vector2(0, -44)
var _t := 0.0
var _landed := false

static func play(layer: Control, at: Vector2, target: Control, activity: String, n: int, wait: float, offset := Vector2(0, -44)) -> void:
	var fx = load("res://scripts/ui/board/ActivityPointsFx.gd").new()
	fx.from = at
	fx.entry = target
	fx.kind = activity
	fx.amount = n
	fx.delay = wait
	fx.spread = offset
	layer.add_child(fx)

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	position = Vector2.ZERO
	size = Vector2(720, 1480)

func _target() -> Vector2:
	if is_instance_valid(entry) and entry.is_visible_in_tree():
		var c := entry.get_global_rect().get_center() + Vector2(0, -24)
		return Vector2(clampf(c.x, 40.0, 680.0), c.y)
	return from + Vector2(0, -160)

func _process(delta: float) -> void:
	if delay > 0.0:
		delay -= delta
		return
	if _t == 0.0:
		Sfx.play("coin", 1.15)
	_t += delta
	if not _landed and _t >= POP + HOLD + FLY:
		_landed = true
		if is_instance_valid(entry) and "_bump" in entry:
			entry.set("_bump", 1.0)
		if is_instance_valid(entry):
			entry.queue_redraw()
			for c in entry.get_children():
				if c is CanvasItem: c.queue_redraw()
	if _t >= POP + HOLD + FLY + 0.12:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	if delay > 0.0:
		return
	var p := from
	var s := 1.0
	var label_a := 1.0
	if _t < POP:
		var k := _t / POP
		var e := 1.0 - pow(1.0 - k, 3.0)
		s = lerpf(0.3, 1.15, e)
		p = from + spread * e
	elif _t < POP + HOLD:
		var k := (_t - POP) / HOLD
		s = lerpf(1.15, 1.0, minf(k * 3.0, 1.0))
		p = from + spread + Vector2(0, -8.0 * k)
	else:
		var k := clampf((_t - POP - HOLD) / FLY, 0.0, 1.0)
		var e := k * k * (3.0 - 2.0 * k)
		var a := from + spread + Vector2(0, -8)
		var b := _target()
		var mid := a.lerp(b, 0.5) + Vector2(0, -90)
		p = a.lerp(mid, e).lerp(mid.lerp(b, e), e)
		s = lerpf(1.0, 0.6, e)
		label_a = 1.0 - clampf(k * 2.2, 0.0, 1.0)
		if _t > POP + HOLD + FLY:
			return
	# 底下一圈暖光，让图标从棋盘上跳出来
	draw_circle(p, 40.0 * s, Color(1.0, 0.9, 0.5, 0.35 * label_a))
	if kind == "fossil":
		FossilArt.shovel(self, p, 56.0 * s, -0.35)
	else:
		Sprites.at(self, "ev_entry_" + kind, p, ICON * s)
	if label_a <= 0.0:
		return
	var font: Font = G.font_title
	if font == null:
		return
	var fs := int(round(30.0 * s))
	var tag := TextCatalog.resolve("+%d" % amount)
	var at := p + Vector2(-80, 58.0 * s)
	draw_string_outline(font, at, TextCatalog.resolve(tag), HORIZONTAL_ALIGNMENT_CENTER, 160, fs, 7, Color(Art.INK, label_a))
	draw_string(font, at, TextCatalog.resolve(tag), HORIZONTAL_ALIGNMENT_CENTER, 160, fs, Color(GOLD, label_a))
