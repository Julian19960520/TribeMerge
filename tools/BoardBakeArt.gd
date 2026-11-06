extends RefCounted
## Offline-only source art. Never loaded by gameplay.
## 棋盘巨石 / 地砖 / 碎石的手绘源图。tools/bake_board.gd 把它们烘成 assets/board/*.png。
## 巨石按格子序号挑 4 种轮廓（圆墩、叠石、扁石板、立石）、4 种石色，再随机加青苔、草丛、小花、蘑菇、碎石、地衣，
## 63 个变体互不相同；同一变体 4 个抖动相位只差线条抖动。

const STONES := [
	[Color("b3a996"), Color("8d8270"), Color("d6ccb6")],   # 暖灰
	[Color("a7a39a"), Color("7f7b73"), Color("cfcac0")],   # 青灰
	[Color("b8a389"), Color("8f7a61"), Color("dcc8aa")],   # 赭灰
	[Color("9f9b8c"), Color("767264"), Color("c7c2b0")],   # 橄榄灰
]
const MOSS_HI := Color("a9d65a")
const GRASS := Color("8cc63f")
const GRASS_D := Color("5f9a2c")

static func r01(seed: int, k: int) -> float:
	return Art.srnd(seed * 131 + k * 17 + 7)

## 圆滑但带棱角的石头轮廓：椭圆上取点，半径抖动，再做一次 Chaikin 圆角。
static func lump(c: Vector2, rx: float, ry: float, seed: int, n: int = 9, rough: float = 0.14, flat_bottom: bool = true) -> PackedVector2Array:
	var base := PackedVector2Array()
	for k in n:
		var a := TAU * float(k) / float(n) + (r01(seed, k) - 0.5) * 0.35
		var m := 1.0 + (r01(seed, k + 40) - 0.5) * 2.0 * rough
		var p := Vector2(cos(a) * rx, sin(a) * ry) * m
		if flat_bottom and p.y > ry * 0.55:
			p.y = ry * 0.55 + (p.y - ry * 0.55) * 0.35
		base.append(c + p)
	var out := base
	for _it in 2:
		var sm := PackedVector2Array()
		for k in out.size():
			var a: Vector2 = out[k]
			var b: Vector2 = out[(k + 1) % out.size()]
			sm.append(a.lerp(b, 0.25))
			sm.append(a.lerp(b, 0.75))
		out = sm
	var j := PackedVector2Array()
	for k in out.size():
		j.append(out[k] + Art.jv(seed * 13 + k, minf(0.7, minf(rx, ry) * 0.04)))
	return j

static func _moved(pts: PackedVector2Array, d: Vector2) -> PackedVector2Array:
	var o := PackedVector2Array()
	for p in pts:
		o.append(p + d)
	return o

static func _largest(polys: Array) -> PackedVector2Array:
	var best := PackedVector2Array()
	var area := -1.0
	for p in polys:
		var bb := Art.bbox(p)
		if bb.get_area() > area and not Geometry2D.is_polygon_clockwise(p):
			area = bb.get_area()
			best = p
	if best.is_empty() and not polys.is_empty():
		best = polys[0]
	return best

## 一块石头：墨线外轮廓 → 底色 → 右下暗面 → 左上亮面 → 高光点
static func stone(ci: CanvasItem, body: PackedVector2Array, pal: Array, seed: int) -> void:
	Art.dilate(ci, body, 3.2, Art.INK)
	ci.draw_colored_polygon(body, pal[0])
	var bb := Art.bbox(body)
	var off := Vector2(-bb.size.x * 0.16, -bb.size.y * 0.2)
	for sh in Geometry2D.clip_polygons(body, _moved(body, off)):
		if not Geometry2D.is_polygon_clockwise(sh):
			ci.draw_colored_polygon(sh, pal[1])
	var hi_c := bb.position + Vector2(bb.size.x * 0.36, bb.size.y * 0.3)
	var hi := Art.ell(hi_c, Vector2(bb.size.x * 0.3, bb.size.y * 0.22), seed + 3, 0.12, 12, -0.25, 0.4)
	for h in Geometry2D.intersect_polygons(body, hi):
		ci.draw_colored_polygon(h, pal[2])
	ci.draw_colored_polygon(Art.ell(hi_c + Vector2(-bb.size.x * 0.08, -bb.size.y * 0.06), Vector2(5.5, 2.6), seed + 5, 0.0, 8, -0.4, 0.2), Color(1, 1, 1, 0.55))
	Art.outline(ci, body, 2.4, Art.INK)

## 从轮廓边缘往里走的裂纹：三四段折线越走越细，可能分一个小叉
static func crack(ci: CanvasItem, body: PackedVector2Array, seed: int, col: Color = Color(0.25, 0.16, 0.1, 0.8)) -> void:
	var bb := Art.bbox(body)
	var c := bb.get_center()
	var k0 := int(r01(seed, 1) * float(body.size())) % body.size()
	# 只从上半圈或侧边起笔，避开被阴影压住的底边
	for _try in body.size():
		if (body[k0] as Vector2).y < c.y + bb.size.y * 0.1:
			break
		k0 = (k0 + 1) % body.size()
	var p: Vector2 = body[k0]
	var dir := (c - p).normalized().rotated((r01(seed, 2) - 0.5) * 0.8)
	var pts := [p - dir * 1.5]
	var seg := bb.size.y * (0.16 + r01(seed, 3) * 0.06)
	var steps := 3 + int(r01(seed, 4) * 2.0)
	for k in steps:
		dir = dir.rotated((0.7 if k % 2 == 0 else -0.7) * (0.5 + r01(seed, 5 + k)))
		p += dir * seg * (1.0 - float(k) * 0.15)
		pts.append(p)
	for k in pts.size() - 1:
		var w := lerpf(2.8, 1.2, float(k) / float(pts.size() - 1))
		Art.ln(ci, pts[k] as Vector2, pts[k + 1] as Vector2, w, col, seed + 21 + k)
	if r01(seed, 12) > 0.45:
		var b: Vector2 = pts[1]
		var bd: Vector2 = ((pts[2] as Vector2) - b).normalized().rotated(1.0 if r01(seed, 13) > 0.5 else -1.0)
		Art.ln(ci, b, b + bd * seg * 0.7, 1.4, col, seed + 30)

## 青苔从顶上披下来，下沿是一串圆弧
static func moss(ci: CanvasItem, body: PackedVector2Array, seed: int, depth: float) -> void:
	var bb := Art.bbox(body)
	var cap := PackedVector2Array()
	var x0 := bb.position.x - 4.0
	var x1 := bb.end.x * (0.75 + r01(seed, 9) * 0.3) + bb.position.x * (0.25 - r01(seed, 9) * 0.3)
	var y_top := bb.position.y - 6.0
	cap.append(Vector2(x0, y_top))
	cap.append(Vector2(x1, y_top))
	var n := 7
	for k in n + 1:
		var t := float(k) / float(n)
		var x := lerpf(x1, x0, t)
		var drip := depth * (0.55 + 0.45 * sin(t * PI * (2.0 + r01(seed, 11) * 2.0) + r01(seed, 12) * 3.0))
		cap.append(Vector2(x, bb.position.y + drip + (t - 0.5) * depth * 0.6))
	for m in Geometry2D.intersect_polygons(body, cap):
		if Geometry2D.is_polygon_clockwise(m):
			continue
		ci.draw_colored_polygon(m, Art.MOSS_D)
		for hm in Geometry2D.offset_polygon(_moved(m, Vector2(-1, -2)), -2.0, Geometry2D.JOIN_ROUND):
			ci.draw_colored_polygon(hm, Art.MOSS)
		Art.outline(ci, m, 2.0, Color(0.2, 0.3, 0.08, 0.9))
		var mb := Art.bbox(m)
		for k in 3:
			ci.draw_circle(mb.position + Vector2(mb.size.x * (0.2 + 0.3 * k), mb.size.y * 0.35), 1.8, MOSS_HI)

## 底部草丛：三五片尖叶
static func tuft(ci: CanvasItem, base: Vector2, seed: int, h: float) -> void:
	var blades := 3 + int(r01(seed, 30) * 3.0)
	for k in blades:
		var t := (float(k) / float(maxi(1, blades - 1)) - 0.5)
		var root := base + Vector2(t * 12.0, 0)
		var tip := root + Vector2(t * 14.0 + (r01(seed, 31 + k) - 0.5) * 6.0, -h * (0.7 + r01(seed, 36 + k) * 0.5))
		var w := 3.8
		var leaf := Art.poly([root + Vector2(-w, 0), tip, root + Vector2(w, 0)], seed + 40 + k, 0.3)
		Art.fill(ci, leaf, GRASS if k % 2 == 0 else GRASS_D, 1.6)

static func flower(ci: CanvasItem, c: Vector2, seed: int) -> void:
	Art.pl(ci, [c + Vector2(0, 12), c + Vector2(1, 5), c], 2.4, GRASS_D, seed)
	var col: Color = [Color("fff4d6"), Color("ffd23f"), Color("f29bb0")][int(r01(seed, 50) * 3.0) % 3]
	for k in 5:
		var a := TAU * float(k) / 5.0 + r01(seed, 51)
		Art.fill(ci, Art.ell(c + Vector2(cos(a), sin(a)) * 4.2, Vector2(3.4, 3.4), seed + k, 0.0, 8), col, 1.4)
	ci.draw_circle(c, 2.6, Color("e8902a"))

static func mushroom(ci: CanvasItem, c: Vector2, seed: int) -> void:
	var stem := Art.poly([c + Vector2(-3, 0), c + Vector2(3, 0), c + Vector2(2.4, -9), c + Vector2(-2.4, -9)], seed, 0.3)
	Art.fill(ci, stem, Art.BONE, 1.6)
	var cap := Art.poly([c + Vector2(-9, -8), c + Vector2(-6, -14), c + Vector2(0, -16), c + Vector2(6, -14), c + Vector2(9, -8)], seed + 1, 0.3)
	Art.fill(ci, cap, Art.CLAY, 1.8)
	ci.draw_circle(c + Vector2(-3, -12), 1.6, Art.BONE)
	ci.draw_circle(c + Vector2(3.5, -11), 1.3, Art.BONE)

static func pebble(ci: CanvasItem, c: Vector2, r: float, pal: Array, seed: int) -> void:
	var p := lump(c, r, r * 0.7, seed, 7, 0.18, false)
	Art.dilate(ci, p, 2.0, Art.INK)
	ci.draw_colored_polygon(p, pal[1])
	ci.draw_colored_polygon(Art.ell(c + Vector2(-r * 0.25, -r * 0.25), Vector2(r * 0.45, r * 0.25), seed, 0.0, 8, -0.3, 0.2), pal[2])

static func rock(ci: CanvasItem, r: Rect2, i: int) -> void:
	var s := i * 7 + 3
	var c := r.get_center() + Vector2(0, 6)
	var pal: Array = STONES[int(r01(s, 0) * 4.0) % 4]
	var shape := int(r01(s, 1) * 4.0) % 4
	ci.draw_colored_polygon(Art.ell(c + Vector2(2, 28), Vector2(40, 8), s, 0.0, 16, 0.0, 0.0), Color(0.24, 0.15, 0.06, 0.2))
	var bodies: Array = []
	match shape:
		0:  # 圆墩
			bodies.append(lump(c + Vector2(0, -2), 38 + r01(s, 2) * 4.0, 31 + r01(s, 3) * 4.0, s))
		1:  # 一大一小叠在一起
			var left := r01(s, 4) > 0.5
			var big_c := c + Vector2(-6 if left else 6, -4)
			bodies.append(lump(big_c, 33, 30, s))
			bodies.append(lump(c + Vector2(22 if left else -22, 16), 17, 13, s + 1))
		2:  # 扁石板，上面压一块小的
			bodies.append(lump(c + Vector2(0, 10), 41, 19, s, 10, 0.1))
			bodies.append(lump(c + Vector2(-8 + r01(s, 5) * 16.0, -14), 24, 17, s + 2))
		_:  # 立石，略斜
			var lean := (r01(s, 6) - 0.5) * 0.35
			var tall := lump(Vector2.ZERO, 25, 38, s, 9, 0.12)
			var rot := PackedVector2Array()
			for p in tall:
				rot.append(c + Vector2(0, -6) + p.rotated(lean))
			bodies.append(rot)
			bodies.append(lump(c + Vector2(-26 if lean > 0.0 else 26, 20), 13, 10, s + 3))
	for k in bodies.size():
		stone(ci, bodies[k], pal, s + k * 5)
	var main_body: PackedVector2Array = bodies[0]
	if r01(s, 7) > 0.25:
		crack(ci, main_body, s)
	if bodies.size() > 1 and r01(s, 8) > 0.5:
		crack(ci, bodies[1], s + 9)
	# 地衣斑点
	if r01(s, 13) > 0.55:
		var bb := Art.bbox(main_body)
		for k in 3:
			var p := bb.position + Vector2(bb.size.x * (0.55 + r01(s, 60 + k) * 0.3), bb.size.y * (0.45 + r01(s, 63 + k) * 0.35))
			ci.draw_circle(p, 2.2 + r01(s, 66 + k) * 1.6, Color(0.93, 0.78, 0.36, 0.7))
	if r01(s, 14) > 0.4:
		moss(ci, main_body, s, 9.0 + r01(s, 15) * 8.0)
	var deco := r01(s, 16)
	var foot := c + Vector2(-30 + r01(s, 17) * 12.0, 30)
	if r01(s, 18) > 0.35:
		tuft(ci, foot, s, 14.0 + r01(s, 19) * 6.0)
	if r01(s, 20) > 0.5:
		pebble(ci, c + Vector2(30 - r01(s, 21) * 8.0, 30), 5.0 + r01(s, 22) * 2.0, pal, s + 70)
	if deco < 0.16:
		flower(ci, c + Vector2(-22 + r01(s, 23) * 10.0, 20), s + 80)
	elif deco < 0.27:
		mushroom(ci, c + Vector2(26 - r01(s, 24) * 6.0, 32), s + 90)

static func cracks(ci: CanvasItem, r: Rect2, i: int, u: float) -> void:
	var c := r.get_center() + Vector2(0, 4)
	var flash := Color(1, 0.95, 0.82, 0.85 * (1.0 - u))
	var deep := Color(0.15, 0.1, 0.08, 0.9)
	var w := lerpf(2.0, 4.5, u)
	Art.pl(ci, [c + Vector2(-8, -22), c + Vector2(2, -4), c + Vector2(-6, 16), c + Vector2(8, 30)], w, deep, i + 11)
	Art.pl(ci, [c + Vector2(2, -4), c + Vector2(22, -8), c + Vector2(34, 6)], w * 0.8, deep, i + 12)
	Art.pl(ci, [c + Vector2(-28, 2), c + Vector2(-12, 10), c + Vector2(-18, 28)], w * 0.8, deep, i + 13)
	Art.pl(ci, [c + Vector2(-6, -18), c, c + Vector2(4, 12)], w * 0.45, flash, i + 14)

static func frame(ci: CanvasItem, size: Vector2) -> void:
	var shape := Art.rrect(Rect2(-14, -14, size.x + 28, size.y + 28), 22, 77, 1.0)
	Art.dilate(ci, shape, 3.0, Art.INK)
	ci.draw_colored_polygon(shape, Art.LEATHER)
	Art.dashed(ci, Art.rrect(Rect2(-7, -7, size.x + 14, size.y + 14), 16, 78, 0.0), 11, 7, Color("f3d7a2"), 2.2)
	ci.draw_rect(Rect2(Vector2.ZERO, size), Art.HIDE2)

## 地砖：白底（运行时按格子着色），四边略压暗、带几粒浅色砂点。4 个变体排成一行。
static func floor_tile(ci: CanvasItem, k: int) -> void:
	var s := 500 + k * 11
	var tile := Art.rrect(Rect2(2, 2, 92, 92), 10, s, 0.5)
	ci.draw_colored_polygon(tile, Color(0.9, 0.9, 0.9))
	for o in Geometry2D.offset_polygon(_moved(tile, Vector2(0, -1.5)), -3.0, Geometry2D.JOIN_ROUND):
		ci.draw_colored_polygon(o, Color.WHITE)
	for j in 6:
		var p := Vector2(12 + r01(s, j) * 72.0, 12 + r01(s, j + 9) * 72.0)
		ci.draw_colored_polygon(Art.ell(p, Vector2(2.2, 1.4) * (0.7 + r01(s, j + 20)), s + j, 0.1, 7, r01(s, j + 30) * 3.0, 0.0), Color(0.84, 0.84, 0.84))
	if k % 2 == 1:
		var a := Vector2(14 + r01(s, 40) * 30.0, 70 + r01(s, 41) * 14.0)
		ci.draw_polyline(PackedVector2Array([a, a + Vector2(9, -3), a + Vector2(15, 1)]), Color(0.86, 0.86, 0.86), 1.6, true)

static func fragment(ci: CanvasItem, k: int) -> void:
	var pal: Array = STONES[k % 4]
	if k == 6:
		ci.draw_circle(Vector2(32, 32), 15, Art.INK)
		ci.draw_circle(Vector2(32, 32), 12, pal[0])
		ci.draw_circle(Vector2(28, 28), 4, pal[2])
	elif k == 7:
		ci.draw_circle(Vector2(32, 32), 28, Color(0.78, 0.7, 0.58, 1))
	else:
		var p := lump(Vector2(32, 32), 15 + k, 11 + (k % 3) * 2, 300 + k * 9, 6, 0.3, false)
		Art.dilate(ci, p, 2.4, Art.INK)
		ci.draw_colored_polygon(p, pal[0])
		var bb := Art.bbox(p)
		for sh in Geometry2D.clip_polygons(p, _moved(p, Vector2(-bb.size.x * 0.2, -bb.size.y * 0.25))):
			if not Geometry2D.is_polygon_clockwise(sh):
				ci.draw_colored_polygon(sh, pal[1])
		ci.draw_circle(Vector2(28, 27), 3, pal[2])
