extends Control
## 升级时的「丰收圣筐」全屏动画（竞品是金色餐盖）：
## 压暗 → 圣筐从天上落到屏幕中间 → 晃两下 → 叶子盖被顶飞、金光一闪
## → 订单要的材料一件一件从筐口跳出，落到棋盘上各自的格子 → 圣筐和压暗一起散去。
## 动画只管表现；物品在规则里早已放好，这里只是先藏住那些格子，落地时再显出来。
## 播放期间挡住点击，播完自己删掉。total() 是整段时长，升级面板等它播完再弹。

const DROP := 0.42
const SHAKE := 0.5
const OPEN := 0.32
const STEP := 0.26
const FLY := 0.65
const OUTRO := 0.35
const BASKET := "basket_9"
const CENTER := Vector2(360, 700)
const BASKET_SIZE := 300.0

var items: Array = []
var stashed := 0
var _dim := 0.0
var _drop := -900.0
var _tilt := 0.0
var _lid := 0.0
var _rays := 0.0
var _squash := 0.0
var _t := 0.0
var _title: Label
var _shade: ColorRect
var _art: Control
var _sub: Label

## 整段动画（落筐、开盖、每件飞完、散场）的秒数
func total() -> float:
	return DROP + SHAKE + OPEN + STEP * float(maxi(items.size() - 1, 0)) + FLY + OUTRO

func _ready() -> void:
	size = Vector2(720, 1480)
	mouse_filter = MOUSE_FILTER_STOP
	## 压暗用一层 ColorRect 垫在最底下（筐和金光画在本节点上会被它盖住，所以本节点只画在 _art 上）
	_shade = ColorRect.new()
	_shade.color = Color(0.05, 0.03, 0.02, 0.0)
	_shade.position = Vector2(-400, -400)
	_shade.size = Vector2(1520, 2280)
	_shade.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_shade)
	_art = Control.new()
	_art.size = size
	_art.mouse_filter = MOUSE_FILTER_IGNORE
	_art.draw.connect(_paint)
	add_child(_art)
	_title = UI.lbl(self, "族人凑齐了大家想要的东西！", Rect2(0, 330, 720, 70), 44, Color("fff1c4"), HORIZONTAL_ALIGNMENT_CENTER, 10, Art.INK, true)
	_sub = UI.lbl(self, "升级礼 · 直接送到棋盘上", Rect2(0, 400, 720, 44), 26, Color("ffe7a8"), HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK)
	if stashed > 0:
		_sub.text = "升级礼 · 放不下的 %d 件进了暂存区" % stashed
	for l in [_title, _sub]:
		l.modulate.a = 0.0
		l.mouse_filter = MOUSE_FILTER_IGNORE
	var board = _board()
	if board != null:
		for it in items: board.conceal(int(it["to"]))
	_run()

func _board():
	var m = G.main
	if m == null or not is_instance_valid(m.board_screen): return null
	return m.board_screen.board

func _run() -> void:
	var tw := create_tween()
	tw.tween_property(self, "_dim", 0.74, 0.22)
	tw.parallel().tween_property(self, "_drop", 0.0, DROP).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_title, "modulate:a", 1.0, 0.3).set_delay(0.12)
	tw.parallel().tween_property(_sub, "modulate:a", 1.0, 0.3).set_delay(0.2)
	tw.tween_callback(func(): Sfx.play("drum"))
	# 晃两下：筐左右摆，越摆越急
	tw.tween_method(func(v: float):
		_tilt = sin(v * TAU * 2.5) * 0.13 * (0.4 + v)
		_squash = absf(sin(v * TAU * 2.5)) * 0.05, 0.0, 1.0, SHAKE)
	tw.tween_callback(func():
		_tilt = 0.0
		_squash = 0.0
		Sfx.play("whoosh"))
	# 盖子被顶飞，金光亮起
	tw.tween_property(self, "_lid", 1.0, OPEN).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "_rays", 1.0, OPEN * 0.8)
	tw.tween_callback(func(): Sfx.play("fanfare"))
	for k in items.size():
		var idx := k
		tw.tween_callback(func(): _launch(idx))
		if k < items.size() - 1:
			tw.tween_interval(STEP)
	# 东西飞出去以后压暗慢慢退，让玩家看清它们落在棋盘哪里
	tw.tween_property(self, "_dim", 0.35, FLY)
	tw.tween_property(self, "modulate:a", 0.0, OUTRO)
	tw.tween_callback(queue_free)

func _launch(k: int) -> void:
	var it: Dictionary = items[k]
	var board = _board()
	var to := int(it["to"])
	var id := str(it["id"])
	var mouth := CENTER + Vector2(0, -BASKET_SIZE * 0.32)
	if board == null:
		return
	var xf: Transform2D = board.get_global_transform()
	var target: Vector2 = xf * board.cell_center(to)
	var s: float = board.ITEM * xf.get_scale().x
	_squash = 0.08
	create_tween().tween_property(self, "_squash", 0.0, 0.18)
	Sfx.play("pop", 1.0 + 0.08 * float(k))
	G.main.fly(id, mouth, target, func():
		if is_instance_valid(board): board.arrive(to), s)

func _process(dt: float) -> void:
	_t += dt
	_shade.color.a = _dim
	_art.queue_redraw()

func _paint() -> void:
	var ci: Control = _art
	var c := CENTER + Vector2(0, _drop)
	# 金光：开盖后在筐后面转
	if _rays > 0.01:
		var rot := _t * 0.6
		for k in 16:
			var a := rot + TAU * float(k) / 16.0
			var r := 520.0
			ci.draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a - 0.08), sin(a - 0.08)) * r, c + Vector2(cos(a + 0.08), sin(a + 0.08)) * r]), Color(1.0, 0.84, 0.38, 0.16 * _rays))
		for k in 4:
			ci.draw_circle(c + Vector2(0, -40), 60.0 + 34.0 * float(k), Color(1.0, 0.88, 0.5, 0.10 * _rays))
	# 圣筐
	var sq := Vector2(1.0 + _squash, 1.0 - _squash)
	# Art.item 自己会重设画布变换，所以筐按屏幕坐标画：绕筐底摆动，挤压用尺寸表现
	var foot := c + Vector2(0, BASKET_SIZE * 0.45)
	Art.item(ci, BASKET, foot + Vector2(0, -BASKET_SIZE * 0.45 * (1.0 - _squash)).rotated(_tilt), BASKET_SIZE * (1.0 + _squash * 0.5), true, _tilt)
	# 叶子盖：盖在筐口，开盖时往右上方翻飞、淡出
	var lid_at := Vector2(0, -BASKET_SIZE * 0.78) + Vector2(220, -560) * _lid
	ci.draw_set_transform(foot + lid_at.rotated(_tilt), _tilt + _lid * 2.4, sq)
	_draw_leaf_lid(ci, 1.0 - _lid)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## 两片交叠的大芭蕉叶，中间一根藤绳打结
func _draw_leaf_lid(ci: Control, a: float) -> void:
	if a <= 0.01:
		return
	var ink := Color(Art.INK, a)
	for side in [-1.0, 1.0]:
		var pts := PackedVector2Array()
		var n := 18
		for i in n + 1:
			var u := float(i) / float(n)
			var x := lerpf(-150.0, 150.0, u)
			var y := -sin(u * PI) * 46.0
			pts.append(Vector2(x, y + side * 6.0 - 8.0))
		for i in range(n, -1, -1):
			var u := float(i) / float(n)
			var x := lerpf(-150.0, 150.0, u)
			pts.append(Vector2(x, sin(u * PI) * 16.0 + side * 6.0 - 8.0))
		var col := Color("6aa84f") if side < 0 else Color("4f8f3a")
		var rot := Transform2D(side * 0.06, Vector2.ZERO)
		pts = rot * pts
		ci.draw_colored_polygon(pts, Color(col, a))
		var closed := pts.duplicate()
		closed.append(pts[0])
		ci.draw_polyline(closed, ink, 4.0, true)
		ci.draw_line(rot * Vector2(-140, -8 + side * 6.0), rot * Vector2(140, -8 + side * 6.0), Color(0.86, 0.95, 0.7, 0.8 * a), 3.0, true)
		for v in 6:
			var x := -110.0 + 44.0 * float(v)
			ci.draw_line(rot * Vector2(x, -8 + side * 6.0), rot * Vector2(x + 26.0, -38.0 + side * 6.0), Color(0.86, 0.95, 0.7, 0.55 * a), 2.0, true)
	# 藤绳结
	ci.draw_circle(Vector2(0, -14), 18.0, Color(Color("8a5a30"), a))
	ci.draw_arc(Vector2(0, -14), 18.0, 0.0, TAU, 20, ink, 3.0, true)
	ci.draw_line(Vector2(-6, -2), Vector2(-22, 24), Color(Color("8a5a30"), a), 7.0, true)
	ci.draw_line(Vector2(6, -2), Vector2(24, 22), Color(Color("8a5a30"), a), 7.0, true)
