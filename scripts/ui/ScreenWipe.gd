extends Control
## 棋盘 ⇄ 部落的全屏转场：帐篷的布门帘。
## 两片帆布帘挂在顶上的木杆上，从两边拉拢，下摆跟着荡一下；
## 中间缝着一块皮章（去合成是藤筐，回部落是篝火）；
## 开帘时先把两片帘的下角往两边挽起、系住，中间露出一个三角口子，再整片拉向两边，木杆收上去。
## 帘子合拢那一刻在后面换界面，整个过程挡住点击。

const W := 720.0
const H := 1480.0
const MID := W * 0.5
const CLOSE := 0.34
const HOLD := 0.26
const OPEN := 0.46
const OUTER := -30.0
const OVERLAP := 12.0
const STRIPS := 4
const VSTEPS := 26
const CLOTH := Color("e6cfa2")
const CLOTH_D := Color("d2b684")
const CLOTH_L := Color("f1dfb8")
## 皮章图相对中心的内容框（同 scripts/sprites/tribe.gd 的 BADGE_BOX）
const BADGE_BOX := Rect2(-124, -120, 250, 250)

var _t := -1.0
var _swap := Callable()
var _swapped := false
var _icon := ""
var _label := ""

func _init() -> void:
	size = Vector2(W, H)
	mouse_filter = MOUSE_FILTER_IGNORE
	visible = false
	set_process(false)

func running() -> bool:
	return _t >= 0.0

## to: "board" 或 "home"。swap 在帘子合拢时调用。
func play(to: String, swap: Callable) -> void:
	_swap = swap
	_swapped = false
	_t = 0.0
	if to == "board":
		_icon = "basket_6"
		_label = "去合成"
	else:
		_icon = "fire_4"
		_label = "回部落"
	visible = true
	mouse_filter = MOUSE_FILTER_STOP
	set_process(true)
	Sfx.play("whoosh", 0.8)
	queue_redraw()

func _process(dt: float) -> void:
	if _t < 0.0:
		return
	var was := _t
	_t += dt
	if was < CLOSE and _t >= CLOSE:
		_do_swap()
	if was < CLOSE + 0.05 and _t >= CLOSE + 0.05:
		Sfx.play("drum", 0.9)
	if was < CLOSE + HOLD and _t >= CLOSE + HOLD:
		Sfx.play("whoosh", 1.1)
	if _t >= CLOSE + HOLD + OPEN:
		_t = -1.0
		visible = false
		mouse_filter = MOUSE_FILTER_IGNORE
		set_process(false)
		if not _swapped:
			_do_swap()
	queue_redraw()

func _do_swap() -> void:
	_swapped = true
	if _swap.is_valid():
		_swap.call()

# ---------------------------------------------------------------- 动作曲线

## 一片帘子这一刻的状态：o 拉开程度（0 合拢，1 收到屏外），l 下角挽起程度，lag 下摆相对上沿的偏移
func _state(delay: float) -> Dictionary:
	var t := _t - delay
	var o := 0.0
	var l := 0.0
	var lag := 0.0
	if t < CLOSE:
		var u := clampf(t / CLOSE, 0.0, 1.0)
		o = pow(1.0 - u, 3.0)
		lag = -90.0 * sin(PI * u)
	else:
		var h := t - CLOSE
		lag = 26.0 * sin(h * 15.0) * exp(-h * 6.5)
		var q := (t - CLOSE - HOLD) / OPEN
		if q > 0.0:
			var a := clampf(q / 0.62, 0.0, 1.0)
			l = a * a * (3.0 - 2.0 * a)
			var b := clampf((q - 0.32) / 0.68, 0.0, 1.0)
			o = b * b
			lag += -40.0 * b * (1.0 - b) * 4.0
	return {"o": o, "l": l, "lag": lag}

# ---------------------------------------------------------------- 帘子形状（按左片算，右片镜像）

## 帘子上一点：s 从外边（0）到里边（1），v 从上（0）到下（1）
static func _pt(st: Dictionary, s: float, v: float) -> Vector2:
	# 上沿收到离外边 60 像素就不再收窄，剩下的整片往屏外推，免得褶子挤成一条线
	var o: float = st["o"]
	var ax: float = lerpf(MID + OVERLAP, OUTER + 60.0, o)
	var push := -190.0 * smoothstep(0.55, 1.0, o)
	var a := Vector2(ax, 30.0)
	var l: float = st["l"]
	var bx: float = lerpf(ax + float(st["lag"]), OUTER + 70.0, l * 0.92)
	var b := Vector2(bx, lerpf(H + 30.0, H * 0.42, l))
	# 里边是一条弧线：挽起后往中间鼓，像垂下来的布
	var c := (a + b) * 0.5 + Vector2(60.0 * l + float(st["lag"]) * 0.35, 0.0)
	var inner := a * (1.0 - v) * (1.0 - v) + c * 2.0 * (1.0 - v) * v + b * v * v
	inner.x = maxf(inner.x, OUTER + 20.0)
	var outer := Vector2(OUTER, lerpf(30.0, H + 30.0, v))
	return outer.lerp(inner, s) + Vector2(push, 0.0)

static func _mp(p: Vector2, mirror: bool) -> Vector2:
	return Vector2(W - p.x, p.y) if mirror else p

func _p(st: Dictionary, s: float, v: float, mirror: bool) -> Vector2:
	return _mp(_pt(st, s, v), mirror)

func _flap(st: Dictionary, mirror: bool) -> void:
	if float(st["o"]) > 0.995:
		return
	# 整片外轮廓（用来画投影和描边）
	var shape := PackedVector2Array()
	for k in VSTEPS + 1:
		shape.append(_p(st, 0.0, float(k) / VSTEPS, mirror))
	for k in STRIPS + 1:
		shape.append(_p(st, float(k) / STRIPS, 1.0, mirror))
	for k in range(VSTEPS, -1, -1):
		shape.append(_p(st, 1.0, float(k) / VSTEPS, mirror))
	var dir := -1.0 if mirror else 1.0
	_patch(st, mirror, 0.0, 1.0, 0.0, 1.0, 4, VSTEPS, Color(0, 0, 0, 0.25), Vector2(dir * 12.0, 6.0))
	# 褶子：一条条竖布，深浅相间，越收拢越挤
	for k in STRIPS:
		var s0 := float(k) / STRIPS
		var s1 := float(k + 1) / STRIPS
		# 每道褶子从折痕的暗处渐亮到鼓起的高光，再暗回下一道折痕
		var sm := lerpf(s0, s1, 0.4)
		_patch(st, mirror, s0, sm, 0.0, 1.0, 3, VSTEPS, CLOTH_D, Vector2.ZERO, CLOTH_L)
		_patch(st, mirror, sm, s1, 0.0, 1.0, 4, VSTEPS, CLOTH_L, Vector2.ZERO, CLOTH_D)
		if k < STRIPS - 1:
			var crease := PackedVector2Array()
			for j in VSTEPS + 1:
				crease.append(_p(st, s1, float(j) / VSTEPS, mirror))
			draw_polyline(crease, Color(Art.INK, 0.18), 3.0, true)
	# 下摆的花纹带：红底、赭石折线、一道青边
	_band(st, mirror, 0.86, 0.935, Art.CLAY)
	_band(st, mirror, 0.835, 0.85, Art.TEAL)
	var zz := PackedVector2Array()
	var n := STRIPS * 3
	for k in n + 1:
		zz.append(_p(st, float(k) / n, 0.875 if k % 2 == 0 else 0.92, mirror))
	draw_polyline(zz, Art.OCHRE, 5.0, true)
	# 里边的包边针脚
	var stitch := PackedVector2Array()
	for j in VSTEPS + 1:
		stitch.append(_p(st, 0.965, float(j) / VSTEPS, mirror))
	for j in stitch.size() - 1:
		draw_line(stitch[j], stitch[j].lerp(stitch[j + 1], 0.55), Color(Art.LEATHER_D, 0.7), 3.0, true)
	Art.outline(self, shape, 4.0, Art.INK)
	_fringe(st, mirror)
	_tie(st, mirror)

func _strip(st: Dictionary, mirror: bool, s0: float, s1: float, col: Color) -> void:
	_patch(st, mirror, s0, s1, 0.0, 1.0, 1, VSTEPS, col)

func _band(st: Dictionary, mirror: bool, v0: float, v1: float, col: Color) -> void:
	_patch(st, mirror, 0.0, 1.0, v0, v1, STRIPS * 2, 1, col)

## 帘子上 s0..s1 × v0..v1 这一块，切成小四边形自己拼三角形画。
## 帘子弯起来后又长又斜，交给 draw_colored_polygon 三角化会失败，这里不需要三角化。
func _patch(st: Dictionary, mirror: bool, s0: float, s1: float, v0: float, v1: float, ns: int, nv: int, col: Color, off := Vector2.ZERO, col1 = null) -> void:
	var pts := PackedVector2Array()
	for j in nv + 1:
		var v := lerpf(v0, v1, float(j) / nv)
		for i in ns + 1:
			pts.append(_p(st, lerpf(s0, s1, float(i) / ns), v, mirror) + off)
	var idx := PackedInt32Array()
	var row := ns + 1
	for j in nv:
		for i in ns:
			var a := j * row + i
			idx.append_array([a, a + 1, a + row + 1, a, a + row + 1, a + row])
	var cols := PackedColorArray()
	cols.resize(pts.size())
	cols.fill(col)
	if col1 != null:
		# s 方向渐变，用 smoothstep 让高光柔一点
		for j in nv + 1:
			for i in ns + 1:
				var u := float(i) / ns
				cols[j * row + i] = col.lerp(col1, u * u * (3.0 - 2.0 * u))
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, pts, cols)

## 下摆的流苏：麻绳加一颗珠子，跟着下摆荡
func _fringe(st: Dictionary, mirror: bool) -> void:
	var swing: float = clampf(-float(st["lag"]) * 0.01, -0.6, 0.6) * (-1.0 if mirror else 1.0)
	for k in 12:
		var s := (float(k) + 0.5) / 12.0
		var a := _p(st, s, 1.0, mirror)
		var tip := a + Vector2.DOWN.rotated(swing) * 30.0
		draw_line(a, tip, Art.ROPE.darkened(0.15), 4.0, true)
		draw_circle(tip, 6.0, Art.TEAL if k % 2 == 0 else Art.CLAY)
		draw_arc(tip, 6.0, 0, TAU, 12, Art.INK, 2.0, true)

## 挽起后系住下角的麻绳
func _tie(st: Dictionary, mirror: bool) -> void:
	var l: float = st["l"]
	if l < 0.35:
		return
	var a := clampf((l - 0.35) / 0.4, 0.0, 1.0)
	var at := _p(st, 0.55, 1.0, mirror)
	var wall := _mp(Vector2(OUTER + 12.0 - 190.0 * smoothstep(0.55, 1.0, float(st["o"])), at.y - 20.0), mirror)
	draw_line(wall, wall.lerp(at, a), Art.ROPE, 7.0, true)
	draw_line(wall, wall.lerp(at, a), Color(Art.INK, 0.5), 2.0, true)

## 顶上的木杆，帘子挂在上面（预生成的图 tribe_wipe_pole）
func _pole(presence: float) -> void:
	var y := lerpf(-60.0, 10.0, presence)
	Sprites.draw(self, "tribe_wipe_pole", Rect2(-20, y, W + 40, 30))

func _draw() -> void:
	if _t < 0.0:
		return
	var left := _state(0.0)
	var right := _state(0.03)
	_flap(left, false)
	_flap(right, true)
	_pole(clampf((1.0 - minf(left["o"], right["o"])) * 3.0, 0.0, 1.0))
	_draw_badge()

# ---------------------------------------------------------------- 皮章

func _badge_scale() -> float:
	var h := _t - CLOSE + 0.02
	if h < 0.0:
		return 0.0
	if h < 0.18:
		var u := h / 0.18
		return 1.0 + 0.18 * sin(u * PI) - (1.0 - u) * (1.0 - u)
	var o := _t - CLOSE - HOLD + 0.06
	if o < 0.0:
		return 1.0
	var u := clampf(o / 0.14, 0.0, 1.0)
	return 1.0 - u * u

func _draw_badge() -> void:
	var s := _badge_scale()
	if s <= 0.01:
		return
	var ctr := Vector2(MID, H * 0.5 - 40)
	var wob := sin(_t * 4.0) * 0.03
	draw_set_transform(ctr, wob, Vector2(s, s))
	# 皮章（投影、皮面、针脚、骨白内圈）是预生成的图
	Sprites.draw(self, "tribe_wipe_badge", BADGE_BOX)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Art.item 自己会设变换，所以按屏幕坐标画、用尺寸做缩放
	Art.item(self, _icon, ctr + Vector2(0, -4) * s, 112.0 * s)
	if s > 0.6:
		var base := ctr + Vector2(-120, 160)
		var a := clampf((s - 0.6) / 0.4, 0.0, 1.0)
		draw_string_outline(G.font_title, base, _label, HORIZONTAL_ALIGNMENT_CENTER, 240, 44, 10, Color(Art.INK, a))
		draw_string(G.font_title, base, _label, HORIZONTAL_ALIGNMENT_CENTER, 240, 44, Color(1, 0.95, 0.8, a))
