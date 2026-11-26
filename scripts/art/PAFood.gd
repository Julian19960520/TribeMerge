class_name PAFood
extends PA
## 食物线：果树 / 水果 / 坚果

const GRAPE := Color("7b4aa8")
const BLUE := Color("4f6fc4")
const PLUM := Color("e8b52e")  # 黄李：和紫色的无花果、蓝莓分开
const FIG := Color("7a4a6a")
const APPLE := Color("e0453a")
const PEAR := Color("c8d64a")
const POME := Color("c8283c")
const MANGO := Color("f5a623")
const PAPAYA := Color("f08a2a")
const COCO := Color("8a5a34")
const MELON := Color("4c9a3a")
const JACK := Color("a6b83c")

static func _fruit_parts(c: Vector2, r: float, col: Color, s: int, lf: bool = true) -> Array:
	var out := [circ(c, r, s, col, 0)]
	out.append(stk(c + Vector2(0, -r * 0.8), c + Vector2(2, -r * 1.25), 2.2, s + 1, WOOD_D, 2))
	if lf:
		out.append(leaf(c + Vector2(2, -r * 1.1), r * 0.9, r * 0.32, -0.5, s + 2))
	return out

## 生产器：从嫩芽长成果树。1~3 级只有绿叶（还不能生产），4 级起挂果，果子跟着这一级新开放的掉落走
const SOIL := Color("7a4f2a")
const BUD := Color("c4dc78")

static func _mound(c: Vector2, rx: float, ry: float, s: int) -> Array:
	return ov(c, rx, ry, s, SOIL, 0.0, 1)

## 一团树冠：先画后排的深色圆，再画前排的亮色圆
static func _canopy(back: Array, front: Array, s: int) -> Array:
	var out := []
	for k in back.size():
		var b: Vector3 = back[k]
		out.append(circ(Vector2(b.x, b.y), b.z, s + k, LEAF_D, 1))
	for k in front.size():
		var f: Vector3 = front[k]
		out.append(circ(Vector2(f.x, f.y), f.z, s + 20 + k, LEAF if k % 2 == 0 else LEAF.lightened(0.06), 1))
	return out

static func _berries(ci: CanvasItem, pts: Array, r: float, col: Color, s: int) -> void:
	for p in pts:
		ci.draw_circle(p, r + 1.6, INK)
	for k in pts.size():
		var p: Vector2 = pts[k]
		ci.draw_circle(p, r, col.darkened(0.18))
		ci.draw_circle(p + Vector2(-r * 0.12, -r * 0.12), r * 0.8, col)
		ci.draw_circle(p + Vector2(-r * 0.38, -r * 0.38), r * 0.28, Color(1, 1, 1, 0.6))

static func _cherries(ci: CanvasItem, tops: Array, s: int) -> void:
	for k in tops.size():
		var t: Vector2 = tops[k]
		ln(ci, t, t + Vector2(-4, 8), 1.4, WOOD_D, s + k)
		ln(ci, t, t + Vector2(4, 9), 1.4, WOOD_D, s + k + 9)
	var pts := []
	for t in tops:
		pts.append(t + Vector2(-5, 11))
		pts.append(t + Vector2(5, 12))
	_berries(ci, pts, 5.0, BERRY, s + 30)

static func _blue(ci: CanvasItem, cs: Array, s: int) -> void:
	var pts := []
	for c in cs:
		pts.append(c + Vector2(-3.8, 0))
		pts.append(c + Vector2(3.8, 0))
		pts.append(c + Vector2(0, 6))
	_berries(ci, pts, 4.0, BLUE, s)

static func _flower(ci: CanvasItem, c: Vector2, r: float) -> void:
	for j in 5:
		var pa := TAU * float(j) / 5.0 - PI * 0.5
		ci.draw_circle(c + Vector2(cos(pa), sin(pa)) * r, r * 1.05, Color(INK, 0.8))
	for j in 5:
		var pa := TAU * float(j) / 5.0 - PI * 0.5
		ci.draw_circle(c + Vector2(cos(pa), sin(pa)) * r, r * 0.8, Color("fff6e8"))
	ci.draw_circle(c, r * 0.6, GOLD)

static func gen(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			## 嫩芽：一小堆土里冒出两片子叶
			sil(ci, [_mound(Vector2(0, 30), 20, 7, s), stk(Vector2(0, 26), Vector2(1, 8), 2.4, s + 1, LEAF_D, 2),
				leaf(Vector2(1, 8), 15, 5.5, -2.6, s + 2), leaf(Vector2(1, 8), 15, 5.5, -0.5, s + 3)], rim)
			for k in 3:
				ci.draw_circle(Vector2(-11.0 + float(k) * 10.0, 30.0 + float(k % 2) * 2.0), 1.5, Color(INK, 0.4))
		2:
			## 三叶苗：茎高一点，顶着三片叶子
			sil(ci, [_mound(Vector2(0, 30), 26, 8, s), stk(Vector2(0, 26), Vector2(0, -2), 2.8, s + 1, LEAF_D, 2),
				leaf(Vector2(0, -2), 21, 8, -2.75, s + 2), leaf(Vector2(0, -2), 21, 8, -0.39, s + 3),
				leaf(Vector2(0, -4), 20, 8, -1.57, s + 4), leaf(Vector2(0, 12), 12, 4.5, -2.9, s + 5)], rim)
			for ang in [-2.75, -0.39, -1.57]:
				vein(ci, Vector2(0, -3), 20, ang, s + int(ang * 10.0))
		3:
			## 小灌木：矮矮一丛绿叶，几颗青花苞，还没结果
			var parts := [_mound(Vector2(0, 31), 30, 8, s), stk(Vector2(-2, 30), Vector2(-14, 4), 2.2, s + 1, WOOD_D, 2),
				stk(Vector2(2, 30), Vector2(13, 2), 2.2, s + 2, WOOD_D, 2)]
			parts.append_array(_canopy([Vector3(-12, 0, 12), Vector3(12, -2, 12)],
				[Vector3(-19, 15, 12), Vector3(19, 14, 12), Vector3(-7, 8, 14), Vector3(8, 7, 14)], s + 3))
			sil(ci, parts, rim)
			for b in [Vector2(-18, 10), Vector2(-4, 0), Vector2(14, -6), Vector2(20, 12), Vector2(4, 16)]:
				ci.draw_colored_polygon(ell(b, Vector2(3.2, 4.2), s + int(b.x), 0.05, 8), BUD)
				outline(ci, ell(b, Vector2(3.2, 4.2), s + int(b.x), 0.05, 8), 1.4)
		4:
			## 野莓丛：圆鼓鼓一丛，第一次挂满红野莓——能摘了
			var parts := [_mound(Vector2(0, 32), 36, 8, s)]
			parts.append_array(_canopy([Vector3(-22, 6, 15), Vector3(22, 4, 15), Vector3(0, -12, 15)],
				[Vector3(-14, 14, 17), Vector3(14, 13, 17), Vector3(-8, -6, 16), Vector3(10, -6, 16)], s + 1))
			sil(ci, parts, rim)
			_berries(ci, [Vector2(-18, 10), Vector2(-4, -6), Vector2(14, 14), Vector2(18, -6), Vector2(0, 20)], 5.0, BERRY, s + 40)
		5:
			## 榛子丛：更高更密，挂几簇带绿苞的榛子（不画红果）
			var parts := [_mound(Vector2(0, 33), 40, 8, s)]
			parts.append_array(_canopy([Vector3(-26, 4, 16), Vector3(26, 2, 16), Vector3(-10, -20, 16), Vector3(12, -22, 16)],
				[Vector3(-16, 14, 18), Vector3(16, 13, 18), Vector3(-14, -6, 17), Vector3(12, -6, 17), Vector3(0, -26, 14)], s + 1))
			sil(ci, parts, rim)
			## 一颗一颗的榛子，各自歪一点，顶上一片锯齿边浅绿苞叶
			var nuts := [Vector3(-16, 8, -0.35), Vector3(15, 12, 0.3), Vector3(2, -16, 0.1), Vector3(20, -12, 0.45)]
			for k in nuts.size():
				var n: Vector3 = nuts[k]
				var cc := Vector2(n.x, n.y)
				var husk := []
				for j in 11:
					var ang := PI * 1.02 + PI * 0.96 * float(j) / 10.0
					husk.append(Vector2(cos(ang) * (10.0 if j % 2 == 0 else 6.5), -2.0 + sin(ang) * (7.0 if j % 2 == 0 else 4.0)))
				husk.append(Vector2(7, -1))
				husk.append(Vector2(-7, -1))
				var nut := []
				for j in 16:
					var ang := TAU * float(j) / 16.0
					nut.append(Vector2(cos(ang) * 7.0, 4.0 + sin(ang) * 7.5))
				sil(ci, [pg(rot_pts(nut, n.z, cc), s + 50 + k, Color("a5652e"), 0), pg(rot_pts(husk, n.z, cc), s + 60 + k, LEAF.lightened(0.15), 1)], false, 2.0)
		6:
			## 小果树：第一次长出树干，圆树冠挂成对的樱桃
			var parts := [_mound(Vector2(0, 34), 26, 6, s), stk(Vector2(0, 34), Vector2(0, -4), 5.0, s + 1, WOOD_D, 2),
				stk(Vector2(0, 8), Vector2(-12, -8), 2.6, s + 2, WOOD_D, 2)]
			parts.append_array(_canopy([Vector3(-24, -14, 17), Vector3(24, -16, 17)],
				[Vector3(-14, -6, 18), Vector3(14, -6, 18), Vector3(0, -28, 20)], s + 3))
			sil(ci, parts, rim)
			_cherries(ci, [Vector2(-14, -16), Vector2(12, -10)], s + 40)
		7:
			## 果树：树干更粗、分叉，树冠两三团，樱桃之外多了蓝莓串
			var parts := [_mound(Vector2(0, 35), 30, 6, s), stk(Vector2(0, 35), Vector2(0, 2), 5.6, s + 1, WOOD_D, 2),
				stk(Vector2(0, 6), Vector2(-16, -14), 3.4, s + 2, WOOD_D, 2), stk(Vector2(0, 2), Vector2(14, -16), 3.4, s + 3, WOOD_D, 2)]
			parts.append_array(_canopy([Vector3(-28, -16, 16), Vector3(28, -18, 16), Vector3(0, -40, 16)],
				[Vector3(-18, -8, 18), Vector3(18, -8, 18), Vector3(-12, -30, 18), Vector3(14, -32, 18), Vector3(0, -20, 18)], s + 4))
			sil(ci, parts, rim)
			_cherries(ci, [Vector2(-20, -16), Vector2(16, -34)], s + 40)
			_blue(ci, [Vector2(14, -10)], s + 60)
		8:
			## 大果树：粗树干露出树根，宽树冠，黄李、樱桃、蓝莓挂满
			var parts := [_mound(Vector2(0, 36), 36, 6, s), stk(Vector2(-6, 34), Vector2(-18, 38), 3.0, s + 1, WOOD_D, 2),
				stk(Vector2(6, 34), Vector2(20, 38), 3.0, s + 2, WOOD_D, 2), stk(Vector2(0, 36), Vector2(0, 0), 7.0, s + 3, WOOD_D, 2),
				stk(Vector2(0, 6), Vector2(-20, -14), 4.0, s + 4, WOOD_D, 2), stk(Vector2(0, 2), Vector2(18, -18), 4.0, s + 5, WOOD_D, 2)]
			parts.append_array(_canopy([Vector3(-34, -14, 17), Vector3(34, -16, 17), Vector3(-16, -44, 17), Vector3(16, -46, 17)],
				[Vector3(-22, -6, 19), Vector3(22, -6, 19), Vector3(-20, -28, 19), Vector3(20, -30, 19), Vector3(0, -40, 18), Vector3(0, -16, 16)], s + 6))
			sil(ci, parts, rim)
			_berries(ci, [Vector2(-22, -16), Vector2(20, -34), Vector2(24, -6)], 6.4, PAFood.PLUM, s + 40)
			_cherries(ci, [Vector2(-14, -44)], s + 50)
		_:
			## 丰收古树：最大的一棵，粗弯树干、根抓着地，树冠开白花、挂满各色果子
			glow(ci, Vector2(0, -20), 56, GOLD)
			var trunk := [Vector2(-10, 36), Vector2(-7, 18), Vector2(-9, 4), Vector2(-4, -8), Vector2(5, -8), Vector2(9, 6), Vector2(7, 20), Vector2(11, 36)]
			var parts := [_mound(Vector2(0, 37), 40, 6, s), stk(Vector2(-8, 33), Vector2(-26, 40), 3.4, s + 1, WOOD_D, 2),
				stk(Vector2(9, 33), Vector2(28, 39), 3.4, s + 2, WOOD_D, 2), stk(Vector2(0, 34), Vector2(-4, 41), 3.0, s + 3, WOOD_D, 2),
				pg(trunk, s + 4, WOOD_D, 1), stk(Vector2(-4, -2), Vector2(-24, -20), 4.4, s + 5, WOOD_D, 2), stk(Vector2(4, -4), Vector2(22, -22), 4.4, s + 6, WOOD_D, 2)]
			parts.append_array(_canopy([Vector3(-38, -16, 18), Vector3(38, -18, 18), Vector3(-18, -48, 18), Vector3(18, -50, 18)],
				[Vector3(-26, -8, 20), Vector3(26, -8, 20), Vector3(-22, -32, 20), Vector3(22, -34, 20), Vector3(0, -46, 20), Vector3(0, -20, 18)], s + 7))
			sil(ci, parts, rim)
			pl(ci, [Vector2(-3, 30), Vector2(-1, 16), Vector2(-4, 2)], 1.6, Color(INK, 0.35), s)
			for f in [Vector2(-34, -24), Vector2(-6, -54), Vector2(30, -18), Vector2(26, -46)]:
				_flower(ci, f, 3.0)
			_berries(ci, [Vector2(-22, -40), Vector2(10, -28)], 7.0, PAFood.FIG, s + 45)
			_berries(ci, [Vector2(-20, -6), Vector2(30, -32)], 6.4, PAFood.PLUM, s + 40)
			sparks(ci, [Vector2(-46, -50), Vector2(46, -54), Vector2(44, 20)])

static func main(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			sil(ci, [circ(Vector2(0, 8), 18, s, BERRY), leaf(Vector2(0, -8), 18, 6, -0.6, s + 1),
				stk(Vector2(0, -6), Vector2(-2, -16), 2.0, s + 2, WOOD_D, 2)], rim)
			for p in [Vector2(-5, 6), Vector2(6, 12), Vector2(2, 0)]:
				ci.draw_circle(p, 1.5, Color(1, 0.85, 0.6))
		2:
			sil(ci, [stk(Vector2(-14, 12), Vector2(4, -30), 1.8, s, LEAF_D, 2), stk(Vector2(16, 16), Vector2(4, -30), 1.8, s + 1, LEAF_D, 2),
				leaf(Vector2(4, -30), 20, 7, -0.2, s + 2),
				circ(Vector2(-14, 18), 15, s + 3, Color("c8102e")), circ(Vector2(16, 22), 15, s + 4, Color("d81e3e"))], rim)
		3:
			var cs := [Vector2(-10, 0), Vector2(10, -2), Vector2(0, 16), Vector2(-16, 18), Vector2(16, 16), Vector2(0, -16)]
			var parts := [leaf(Vector2(4, -22), 26, 9, -0.6, s), leaf(Vector2(-4, -22), 22, 8, -2.4, s + 1)]
			for i in cs.size():
				parts.append(circ(cs[i], 12, s + 2 + i, BLUE.darkened(0.05 * float(i % 3))))
			sil(ci, parts, rim)
			for c in cs:
				var v: Vector2 = c
				ci.draw_colored_polygon(star_pts(v + Vector2(0, -5), 3.6, 1.4, 5, s), BLUE.darkened(0.4))
		4:
			sil(ci, [ov(Vector2(0, 6), 26, 28, s, PLUM), stk(Vector2(2, -20), Vector2(4, -30), 2.2, s + 1, WOOD_D, 2),
				leaf(Vector2(4, -26), 22, 7, -0.4, s + 2)], rim)
			pl(ci, [Vector2(2, -20), Vector2(-6, 6), Vector2(0, 30)], 2.0, Color(INK, 0.5), s)
		5:
			var pts := []
			for k in 24:
				var a := TAU * float(k) / 24.0
				var r := 32.0 if sin(a) > 0.0 else lerpf(32.0, 11.0, absf(sin(a)) * absf(sin(a)))
				var y := sin(a) * (21.0 if sin(a) > 0.0 else 31.0)
				pts.append(Vector2(cos(a) * r, y + 10.0))
			sil(ci, [pg(pts, s, FIG, 0), stk(Vector2(0, -19), Vector2(4, -29), 3.0, s + 1, LEAF_D, 2)], rim)
			ci.draw_colored_polygon(ell(Vector2(9, 19), Vector2(9, 5.5), s, 0.05, 12), Color("e86a7a"))
			for k in 4:
				ci.draw_circle(Vector2(4.0 + float(k) * 3.4, 18.0 + float(k % 2) * 2.6), 1.4, Color("ffd2b0"))
		6:
			sil(ci, _fruit_parts(Vector2(0, 6), 30, APPLE, s), rim)
			ci.draw_colored_polygon(ell(Vector2(14, 14), Vector2(8, 12), s, 0.05, 12, 0.4), Color(1, 0.85, 0.3, 0.35))
		7:
			sil(ci, [circ(Vector2(0, 14), 28, s, PEAR), circ(Vector2(0, -12), 17, s + 1, PEAR),
				stk(Vector2(0, -26), Vector2(4, -40), 2.4, s + 2, WOOD_D, 2), leaf(Vector2(4, -36), 22, 7, -0.3, s + 3)], rim)
			for k in 5:
				ci.draw_circle(Vector2(-10.0 + float(k) * 6.0, 10.0 + float(k % 2) * 8.0), 1.4, Color(PEAR.darkened(0.35), 0.7))
		8:
			sil(ci, [circ(Vector2(0, 8), 32, s, POME),
				pg([Vector2(-9, -20), Vector2(-11, -32), Vector2(-4, -27), Vector2(0, -34), Vector2(4, -27), Vector2(11, -32), Vector2(9, -20)], s + 1, POME.darkened(0.15))], rim)
			var cut := ell(Vector2(8, 14), Vector2(16, 13), s + 2, 0.08, 14)
			ci.draw_colored_polygon(cut, Color("f5e6c8"))
			outline(ci, cut, 2.0)
			for k in 9:
				var p := Vector2(8, 14) + Vector2(cos(float(k) * 2.4) * (4.0 + float(k)), sin(float(k) * 2.4) * (3.0 + float(k) * 0.8))
				ci.draw_circle(p, 2.6, Color("e0284a"))
				ci.draw_circle(p + Vector2(-0.8, -0.8), 0.9, Color(1, 1, 1, 0.7))
		9:
			var parts := [stk(Vector2(0, -36), Vector2(4, -26), 2.6, s, WOOD_D, 2), leaf(Vector2(2, -32), 30, 12, -0.4, s + 1, LEAF)]
			var rows := [[-18.0, -6.0, 6.0, 18.0], [-12.0, 0.0, 12.0], [-6.0, 6.0], [0.0]]
			var k := 0
			for r in rows.size():
				for x in rows[r]:
					parts.append(circ(Vector2(x, -18.0 + float(r) * 14.0), 9.0, s + 3 + k, GRAPE.darkened(0.04 * float(k % 3))))
					k += 1
			sil(ci, parts, rim)
			vein(ci, Vector2(2, -32), 30, -0.4, s)
		10:
			var pts := []
			for k in 26:
				var a := TAU * float(k) / 26.0
				pts.append(Vector2(cos(a) * 26.0 * (1.0 + 0.12 * sin(a)), sin(a) * 34.0) + Vector2(cos(a) * -4.0 * cos(a), 0))
			var body := rot_pts(pts, 0.5, Vector2(0, 6))
			var top := Vector2(0, -34).rotated(0.5) + Vector2(0, 6)
			sil(ci, [stk(top + Vector2(-1, 3), top + Vector2(3, -9), 2.4, s + 1, WOOD_D, 2),
				leaf(top + Vector2(2, -7), 22, 7, -0.3, s + 2), pg(body, s, MANGO, 0)], rim)
			ci.draw_colored_polygon(ell(top + Vector2(-8, 16), Vector2(12, 15), s, 0.05, 12, 0.5), Color(0.9, 0.25, 0.2, 0.35))
			vein(ci, top + Vector2(2, -7), 22, -0.3, s)
		11:
			## 木瓜：后面一只整的（青转黄），前面一半剖开，橙肉里一腔黑籽
			var whole := []
			var half := []
			for k in 28:
				var a := TAU * float(k) / 28.0
				var p := Vector2(cos(a) * 15.0 * (1.0 + 0.32 * sin(a)), sin(a) * 30.0)
				whole.append(p.rotated(-0.45) + Vector2(-16, -4))
				half.append(Vector2(cos(a) * 20.0 * (1.0 + 0.3 * sin(a)), sin(a) * 32.0).rotated(0.22) + Vector2(12, 8))
			sil(ci, [pg(whole, s, Color("a8c43c"), 0), stk(Vector2(-28, -29), Vector2(-31, -39), 2.6, s + 1, WOOD_D, 2),
				pg(half, s + 2, Color("f2b33a"), 0)], rim)
			ci.draw_colored_polygon(poly(rot_pts([Vector2(-12, -10), Vector2(-20, 6), Vector2(-14, 20)], 0.0), s + 3), Color(PAPAYA, 0.55))
			var flesh := []
			var cav := []
			for k in 24:
				var a := TAU * float(k) / 24.0
				flesh.append(Vector2(cos(a) * 16.0 * (1.0 + 0.3 * sin(a)), sin(a) * 27.0).rotated(0.22) + Vector2(12, 9))
				cav.append(Vector2(cos(a) * 8.0 * (1.0 + 0.25 * sin(a)), sin(a) * 15.0).rotated(0.22) + Vector2(12, 13))
			ci.draw_colored_polygon(poly(flesh, s + 4), Color("ff8a3d"))
			ci.draw_colored_polygon(poly(cav, s + 5), Color("d9572a"))
			for k in 9:
				var p := Vector2((float(k % 3) - 1.0) * 4.6, -10.0 + float(k / 3) * 8.0 + float(k % 2) * 2.0).rotated(0.22) + Vector2(12, 13)
				ci.draw_circle(p, 2.6, INK)
				ci.draw_circle(p + Vector2(-0.8, -0.8), 0.8, Color(1, 1, 1, 0.6))
		12:
			## 椰子：整颗在后，前面半个壳更大，能看到白肉和椰汁
			sil(ci, [circ(Vector2(-14, -4), 28, s, COCO), ov(Vector2(16, 24), 28, 17, s + 1, COCO.darkened(0.1), 0.0, 1)], rim)
			ci.draw_colored_polygon(ell(Vector2(16, 17), Vector2(25, 10), s + 2, 0.04, 18), BONE)
			ci.draw_colored_polygon(ell(Vector2(16, 18), Vector2(18, 6), s + 3, 0.04, 16), Color("f7f3e4"))
			outline(ci, ell(Vector2(16, 17), Vector2(25, 10), s + 2, 0.04, 18), 2.0)
			for k in 3:
				ci.draw_circle(Vector2(-22.0 + float(k) * 8.0, -16.0 + float(k % 2) * 3.0), 2.6, FUR_D)
			for k in 10:
				var a := float(k) * 0.6 + 0.3
				ln(ci, Vector2(-14, -4) + Vector2(cos(a), sin(a)) * 16.0, Vector2(-14, -4) + Vector2(cos(a), sin(a)) * 24.0, 1.4, Color(INK, 0.4), s + k)
			for k in 5:
				var x := -6.0 + float(k) * 11.0
				ln(ci, Vector2(x, 30.0 - absf(x - 16.0) * 0.12), Vector2(x + 2.0, 37.0 - absf(x - 16.0) * 0.25), 1.4, Color(INK, 0.35), s + k + 20)
		13:
			## 西瓜：圆滚滚的整瓜带深色波纹，前面一牙切开的红瓤
			var mc := Vector2(-10, -4)
			var mr := 32.0
			sil(ci, [circ(mc, mr, s, Color("5cae46")), stk(mc + Vector2(0, -mr + 2), mc + Vector2(4, -mr - 8), 2.4, s + 1, WOOD_D, 2)], rim)
			for phi in [-0.78, -0.4, 0.0, 0.4, 0.78]:
				var arr := []
				for j in 15:
					var tt := -0.94 + float(j) / 14.0 * 1.88
					var hw := mr * sqrt(1.0 - tt * tt)
					arr.append(mc + Vector2(phi * hw + (2.2 if j % 2 == 0 else -2.2) * sqrt(1.0 - tt * tt), tt * mr))
				pl(ci, arr, 4.0, Color("2f6b22"), s + int(phi * 10.0))
			hl(ci, mc + Vector2(-14, -14), 7, 4, -0.7, 0.35)
			var apex := Vector2(24, -2)
			var rind := [apex]
			var white := [apex]
			var red := [apex]
			for k in 13:
				var a := lerpf(PI * 0.29, PI * 0.71, float(k) / 12.0)
				var d := Vector2(cos(a), sin(a))
				rind.append(apex + d * 34.0)
				white.append(apex + d * 30.5)
				red.append(apex + d * 28.0)
			sil(ci, [pg(rind, s + 2, Color("3f8a30"), 0)], rim)
			ci.draw_colored_polygon(poly(white, s + 3), Color("e9f2c4"))
			ci.draw_colored_polygon(poly(red, s + 4), Color("ef4a4a"))
			for k in 5:
				var a := lerpf(PI * 0.36, PI * 0.64, float(k) / 4.0)
				ci.draw_colored_polygon(ell(apex + Vector2(cos(a), sin(a)) * (16.0 + float(k % 2) * 6.0), Vector2(1.6, 2.6), s + k, 0.0, 8, a - PI * 0.5), INK)
		_:
			glow(ci, Vector2(0, 0), 52, GOLD)
			var pts := []
			for k in 36:
				var a := TAU * float(k) / 36.0
				var r := 1.0 if k % 2 == 0 else 0.93
				pts.append(Vector2(cos(a) * 34.0 * r, sin(a) * 42.0 * r))
			sil(ci, [pg(rot_pts(pts, 0.25, Vector2(0, 2)), s, JACK, 0), stk(Vector2(-8, -38), Vector2(-12, -48), 3.0, s + 1, WOOD_D, 2)], rim)
			for k in 22:
				var p := Vector2((srnd(s + k) - 0.5) * 50.0, (srnd(s + k + 40) - 0.5) * 66.0)
				if (p / Vector2(30, 38)).length() < 0.95:
					ci.draw_colored_polygon(star_pts(p, 3.2, 1.6, 4, s + k), JACK.darkened(0.3))
			sparks(ci, [Vector2(-36, -32), Vector2(34, -38), Vector2(38, 24)])

## 坚果的水滴形：上头尖、下头圆。tipk 越大顶上越尖
static func _drop(c: Vector2, w: float, h: float, rot: float, tipk: float = 0.45, n: int = 24) -> Array:
	var out := []
	for k in n:
		var t := TAU * float(k) / float(n)
		var f := 1.0 - tipk * (1.0 + cos(t)) * 0.5
		out.append(c + Vector2(w * sin(t) * f, -h * cos(t)).rotated(rot))
	return out

static func _dir(a: float) -> Vector2:
	return Vector2(cos(a), sin(a))

## 副产物：坚果，从小到大、从常见到稀有，每级一件
static func sub(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			## 松子：一粒象牙白小水滴，尖头一点褐
			var c := Vector2(0, 20)
			var pts := _drop(c, 12, 19, 0.35, 0.5)
			sil(ci, [pg(pts, s, Color("f3e4c0"), 0)], rim)
			var tip := c + Vector2(0, -19).rotated(0.35)
			safe_poly(ci, poly(_drop(tip + Vector2(0, 4).rotated(0.35), 3.8, 5.2, 0.35, 0.5, 12), s + 1), Color("8a5a2e"))
			hl(ci, c + Vector2(-3, 4), 2.5, 5, 0.35, 0.5)
		2:
			## 榛子：一颗圆榛子，顶上带尖、底下一块浅色圆疤，半裹在锯齿边的绿苞叶里
			var nut := Color("a5652e")
			var husk := [Vector2(-15, 6), Vector2(15, 6)]
			for k in 13:
				var ang := -PI * 0.02 - PI * 0.96 * float(k) / 12.0
				var r := 18.0 if k % 2 == 0 else 12.0
				husk.append(Vector2(cos(ang) * r, 4.0 + sin(ang) * r * 0.75))
			sil(ci, [ov(Vector2(0, 14), 15, 16, s, nut), pg(husk, s + 1, LEAF, 0),
				stk(Vector2(0, -6), Vector2(3, -14), 2.2, s + 2, WOOD_D, 2)], rim)
			safe_poly(ci, ell(Vector2(0, 24), Vector2(8, 4.5), s + 3, 0.04, 12), Color("e6c99a"))
			outline(ci, ell(Vector2(0, 24), Vector2(8, 4.5), s + 3, 0.04, 12), 1.4)
			hl(ci, Vector2(-7, 14), 3, 5, -0.4, 0.45)
		3:
			## 橡果：戴麻点小帽（比 4 级杏仁小一圈）
			sil(ci, [ov(Vector2(0, 16), 16, 19, s, SEED.lightened(0.05)),
				ov(Vector2(0, -1), 19, 9.5, s + 1, WOOD_D.lightened(0.1), 0.0, 1),
				stk(Vector2(0, -9), Vector2(3, -16), 2.2, s + 2, WOOD_D, 2)], rim)
			for k in 5:
				ln(ci, Vector2(-14.0 + float(k) * 7.0, -4), Vector2(-12.5 + float(k) * 6.2, 4), 1.3, Color(INK, 0.5), s + k)
			ci.draw_circle(Vector2(0, 34), 1.8, WOOD_D)
		4:
			## 杏仁：一颗扁水滴，浅棕带细麻点，一道浅纵纹
			var c := Vector2(0, 2)
			var rot := 0.4
			sil(ci, [pg(_drop(c, 24, 37, rot, 0.55), s, Color("c48f58"), 0)], rim)
			for k in 16:
				var lp := Vector2((srnd(s + k) - 0.5) * 22.0, -18.0 + srnd(s + k + 30) * 42.0)
				if absf(lp.x) < 13.0 - maxf(0.0, -lp.y) * 0.35:
					ci.draw_circle(c + lp.rotated(rot), 1.3, Color(INK, 0.32))
			pl(ci, [c + Vector2(4, -22).rotated(rot), c + Vector2(7, -4).rotated(rot), c + Vector2(6, 16).rotated(rot)], 1.6, Color(INK, 0.35), s)
		5:
			## 开心果：壳张着嘴，露出绿果仁和紫红薄衣
			var shell := Color("e9d7ae")
			var piv := Vector2(0, 38)
			var half_l := [Vector2(0, -24)]
			half_l.append_array(arcp(Vector2(0, 7), Vector2(23, 31), -PI * 0.5, -PI * 1.5, 14))
			var half_r := []
			for p in half_l:
				half_r.append(Vector2(-(p as Vector2).x, (p as Vector2).y))
			half_l = rot_pts(rot_pts(half_l, 0.0, -piv), -0.17, piv)
			half_r = rot_pts(rot_pts(half_r, 0.0, -piv), 0.17, piv)
			sil(ci, [ov(Vector2(0, 1), 11, 22, s, Color("9cc44a")), pg(half_l, s + 1, shell, 0), pg(half_r, s + 2, shell, 1)], rim)
			for b in [Vector2(-3, -15), Vector2(3, -9), Vector2(-1, -3)]:
				safe_poly(ci, ell(b, Vector2(2.6, 2.0), s + int(b.y), 0.1, 8), Color("a54a6e"))
			for side in [-1.0, 1.0]:
				pl(ci, [Vector2(side * 9.0, 30), Vector2(side * 15.0, 14), Vector2(side * 14.0, -2)], 1.4, Color(INK, 0.28), s + int(side))
		6:
			## 腰果：一颗弯月，中间一道合缝
			var C := Vector2(0, 0)
			var R := 25.0
			var a0 := PI * 0.02
			var a1 := PI * 0.88
			var N := 14
			var pts := []
			for k in N + 1:
				var u := float(k) / float(N)
				pts.append(C + _dir(lerpf(a0, a1, u)) * (R + _cashew_th(u)))
			for j in range(1, 6):
				pts.append(C + _dir(a1) * R + _dir(a1 + PI * float(j) / 6.0) * _cashew_th(1.0))
			for k in range(N, -1, -1):
				var u := float(k) / float(N)
				pts.append(C + _dir(lerpf(a0, a1, u)) * (R - _cashew_th(u)))
			for j in range(1, 6):
				pts.append(C + _dir(a0) * R + _dir(a0 + PI + PI * float(j) / 6.0) * _cashew_th(0.0))
			pts = rot_pts(rot_pts(pts, 0.0, Vector2(0, -14)), -0.12, Vector2(0, 14))
			sil(ci, [pg(pts, s, Color("e8c27e"), 0)], rim)
			var seam := []
			for k in 9:
				seam.append(C + _dir(lerpf(a0 + 0.15, a1 - 0.15, float(k) / 8.0)) * (R - 2.0))
			pl(ci, rot_pts(rot_pts(seam, 0.0, Vector2(0, -14)), -0.12, Vector2(0, 14)), 1.6, Color(INK, 0.35), s)
		7:
			## 板栗：油亮红褐，顶上一撮尖，底下一块浅色；后面衬半个张开的刺苞
			var bc := Vector2(15, 8)
			var burr := []
			for k in 30:
				var ang := TAU * float(k) / 30.0
				burr.append(bc + _dir(ang) * (23.0 if k % 2 == 0 else 29.0))
			var nc := Vector2(-7, 9)
			var nut := []
			for p in _drop(nc, 25, 27, -0.08, 0.55, 28):
				var v: Vector2 = p
				nut.append(Vector2(v.x, minf(v.y, nc.y + 22.0)))
			sil(ci, [pg(burr, s, Color("8fae3c"), 1), ov(bc + Vector2(2, -3), 16, 14, s + 1, Color("f1e6c6"), 0.0, 2), pg(nut, s + 2, Color("8c3d1f"), 0)], rim)
			var npoly := poly(nut, s + 2)
			for base in Geometry2D.intersect_polygons(npoly, PackedVector2Array([nc + Vector2(-40, 12), nc + Vector2(40, 12), nc + Vector2(40, 40), nc + Vector2(-40, 40)])):
				safe_poly(ci, base, Color("ddb98a"))
			pl(ci, [nc + Vector2(-23, 12.5), nc + Vector2(0, 11.5), nc + Vector2(23, 12.5)], 1.8, Color(INK, 0.6), s)
			outline(ci, npoly, 2.2)
			for k in 3:
				ln(ci, nc + Vector2(-1.5 + float(k) * 1.5, -26), nc + Vector2(-4.0 + float(k) * 4.0, -32), 1.4, Color("e6cf9a"), s + k)
			hl(ci, nc + Vector2(-10, -4), 4, 7, -0.3, 0.45)
		8:
			## 核桃：后面一整颗（上下微尖、中间一道凸棱、满是皱纹），前面一个大半壳盛着两瓣果仁
			var shell := Color("c4935c")
			var wc := Vector2(-12, -8)
			var whole := []
			for k in 32:
				var ang := TAU * float(k) / 32.0
				var tip := 1.0 + 0.14 * pow(absf(sin(ang)), 6.0)
				whole.append(wc + Vector2(cos(ang) * 26.0, sin(ang) * 29.0 * tip))
			var hc := Vector2(14, 12)
			var bowl := []
			for k in 17:
				var ang := PI + PI * float(k) / 16.0
				bowl.append(hc + Vector2(cos(ang) * 31.0, sin(ang) * 15.0))
			for k in range(1, 16):
				var ang := PI * float(k) / 16.0
				bowl.append(hc + Vector2(cos(ang) * 31.0, sin(ang) * 27.0))
			sil(ci, [pg(whole, s, shell, 0), pg(bowl, s + 1, shell.darkened(0.06), 1)], rim)
			## 整颗：中间凸棱 + 弯弯的皱纹
			pl(ci, [wc + Vector2(-2, -33), wc + Vector2(-0.5, -14), wc + Vector2(-2, 4), wc + Vector2(-1, 26)], 3.0, shell.darkened(0.35), s)
			pl(ci, [wc + Vector2(1, -31), wc + Vector2(2.5, -14), wc + Vector2(1, 4), wc + Vector2(2, 24)], 1.6, shell.lightened(0.3), s + 1)
			## 皱纹：一个个弯弯的小弧，像核桃壳上的坑
			for k in 12:
				var side := -1.0 if k % 2 == 0 else 1.0
				var y := -22.0 + float(k / 2) * 8.5 + srnd(s + k) * 3.0
				var x := side * (9.0 + srnd(s + k + 7) * 7.0)
				var a0 := srnd(s + k + 13) * TAU
				pl(ci, rot_pts(arcp(Vector2.ZERO, Vector2(4.5, 3.2), 0.0, PI * 1.3, 6), a0, wc + Vector2(x, y)), 1.7, Color(shell.darkened(0.4), 0.85), s + k)
			hl(ci, wc + Vector2(-13, -12), 4, 8, -0.3, 0.4)
			## 半壳：外壁几道皱纹，口沿一圈，里面是两瓣果仁
			for k in 4:
				var x := -20.0 + float(k) * 13.0
				pl(ci, [hc + Vector2(x, 7), hc + Vector2(x + 3.0, 15), hc + Vector2(x + 1.0, 22)], 1.6, Color(shell.darkened(0.4), 0.7), s + 30 + k)
			var rimp := ell(hc, Vector2(31, 15), s + 2, 0.02, 24)
			safe_poly(ci, rimp, shell.darkened(0.25))
			outline(ci, rimp, 2.0)
			## 果仁：左右两瓣鼓起的脑花，边缘起伏，中间一道深沟，每瓣几道弯褶
			for side in [-1.0, 1.0]:
				var lc := hc + Vector2(side * 12.5, -3.0)
				var lobe := []
				for k in 20:
					var ang := TAU * float(k) / 20.0
					var r := 1.0 + 0.13 * sin(ang * 5.0 + side)
					lobe.append(lc + Vector2(cos(ang) * 12.5 * r, sin(ang) * 11.0 * r))
				var lp := poly(lobe, s + 3 + int(side))
				safe_poly(ci, lp, Color("e2c088"))
				safe_poly(ci, poly(rot_pts(rot_pts(lobe, 0.0, -lc), 0.0, lc + Vector2(-1.2, -1.2)), s + 6 + int(side)), Color("f2d9a6"))
				outline(ci, lp, 1.8)
				pl(ci, arcp(lc + Vector2(side * 1.0, 0.5), Vector2(6.5, 5.0), PI * 1.1, PI * 1.9, 6), 1.5, Color(INK, 0.45), s + int(side) + 8)
				pl(ci, arcp(lc + Vector2(-side * 3.0, 3.5), Vector2(4, 3.5), PI * 0.1, PI * 0.9, 5), 1.3, Color(INK, 0.35), s + int(side) + 9)
			hl(ci, hc + Vector2(-15, -6), 3, 1.6, 0.0, 0.55)
		9:
			## 澳洲坚果：滚圆棕球，一点浅色圆斑，敲开一道缝露出奶白果仁
			var c := Vector2(0, 4)
			sil(ci, [circ(c, 33, s, Color("9a6034"))], rim)
			safe_poly(ci, ell(c + Vector2(9, -19), Vector2(6, 4), s + 1, 0.05, 10, 0.4), Color("d2ad7c"))
			var A := c + Vector2(-32, -11)
			var B := c + Vector2(22, 24)
			var nrm := (B - A).normalized().orthogonal()
			var up := []
			var dn := []
			for k in 11:
				var u := float(k) / 10.0
				var w := 3.8 * sin(PI * u)
				var zz := (2.2 if k % 2 == 0 else -1.0) * sin(PI * u)
				up.append(A.lerp(B, u) + nrm * (w + zz))
				dn.append(A.lerp(B, u) - nrm * (w - zz * 0.6))
			dn.reverse()
			var lens := poly(up + dn, s + 2)
			safe_poly(ci, lens, Color("f4e4bf"))
			outline(ci, lens, 2.0)
		10:
			## 巴西栗果荚：一个大木球，顶盖揭开，看得到里面一圈月牙果瓣
			var c := Vector2(0, 0)
			var pod := Color("7d5838")
			sil(ci, [circ(c, 38, s, pod, 0, 0.05)], rim)
			for k in 18:
				var p := c + Vector2((srnd(s + k) - 0.5) * 62.0, (srnd(s + k + 50) - 0.5) * 62.0)
				if (p - c).length() < 32.0 and not (absf(p.x) < 25.0 and absf(p.y + 15.0) < 12.0):
					safe_poly(ci, ell(p, Vector2(2.4, 1.6), s + k, 0.2, 8, srnd(s + k + 9) * 3.0), Color(INK, 0.28))
			var M := c + Vector2(0, -15)
			var mr := Vector2(22, 10)
			var mouth := ell(M, mr, s + 3, 0.04, 20)
			safe_poly(ci, mouth, Color("e2cfa6"))
			outline(ci, mouth, 2.4)
			for i in 7:
				var a := TAU * float(i) / 7.0 + 0.2
				var d := 0.36
				var sl := []
				for q in [[a - d, 0.22], [a - d, 0.86], [a - d * 0.5, 0.95], [a, 0.97], [a + d * 0.5, 0.95], [a + d, 0.86], [a + d, 0.22]]:
					sl.append(M + Vector2(cos(q[0]) * mr.x, sin(q[0]) * mr.y) * q[1])
				var sp := poly(sl, s + 10 + i, 0.4)
				safe_poly(ci, sp, Color("6e4426"))
				outline(ci, sp, 1.4)
				ln(ci, M + Vector2(cos(a - d * 0.4) * mr.x, sin(a - d * 0.4) * mr.y) * 0.5, M + Vector2(cos(a - d * 0.4) * mr.x, sin(a - d * 0.4) * mr.y) * 0.85, 1.2, Color("b48756"), s + i)
			sil(ci, [ov(c + Vector2(30, -38), 14, 7, s + 4, pod, -0.5, 1)], rim)
			safe_poly(ci, ell(c + Vector2(30, -38), Vector2(8, 3.5), s + 5, 0.05, 12, -0.5), pod.darkened(0.3))
			hl(ci, c + Vector2(-20, 4), 5, 9, -0.3, 0.3)
		11:
			## 黑胡桃：近乎黑的大圆壳，满是深沟
			var c := Vector2(0, 4)
			var r := 34.0
			sil(ci, [circ(c, r, s, Color("3e2c22"), 0, 0.07), stk(c + Vector2(0, -31), c + Vector2(2, -39), 2.6, s + 1, Color("3e2c22"), 2)], rim)
			for k in 7:
				var ph := -1.25 + float(k) * 0.42
				var dark := []
				var lite := []
				for j in 13:
					var y := -r * 0.88 + float(j) * r * 0.88 * 2.0 / 12.0
					var x := sin(ph) * sqrt(maxf(r * r - y * y, 0.0)) * 0.92 + 2.6 * sin(y * 0.35 + float(k) * 1.7)
					dark.append(c + Vector2(x, y))
					lite.append(c + Vector2(x + 2.4, y))
				pl(ci, lite, 1.4, Color("7a604c"), s + k)
				pl(ci, dark, 2.6, Color("1a110c"), s + k + 20)
			hl(ci, c + Vector2(-14, -16), 6, 10, -0.5, 0.35)
		_:
			## 海椰子：最大的一件。两瓣并在一起的油亮深褐大坚果，底下一圈毛糙的纤维外皮，背后金光
			glow(ci, Vector2(0, -4), 62, GOLD)
			var col := Color("5a3520")
			var tilt := -0.22
			var off := Vector2(0, 0)
			var lo := ell(Vector2(-21, -4), Vector2(28, 38), s, 0.03, 26, -0.1)
			var ro := ell(Vector2(21, -4), Vector2(28, 38), s + 1, 0.03, 26, 0.1)
			var merged := Geometry2D.merge_polygons(lo, ro)
			var outer: PackedVector2Array = merged[0]
			for m in merged:
				if (m as PackedVector2Array).size() > outer.size(): outer = m
			var collar := []
			for k in 15:
				var x := -44.0 + float(k) * 88.0 / 14.0
				collar.append(Vector2(x, 14.0 + (0.0 if k % 2 == 0 else -7.0) + absf(x) * 0.12))
			for k in 13:
				var ang := PI * float(k) / 12.0
				collar.append(Vector2(cos(ang) * 44.0, 22.0 + sin(ang) * 16.0))
			sil(ci, [P(PackedVector2Array(rot_pts(Array(outer), tilt, off)), col, 1),
				pg(rot_pts(collar, tilt, off), s + 2, Color("b88c56"), 1)], rim)
			## 中缝、两瓣的亮边和高光
			pl(ci, rot_pts([Vector2(0, -40), Vector2(-1, -24), Vector2(1, -8), Vector2(0, 10)], tilt, off), 2.8, Color("24140a"), s)
			for side in [-1.0, 1.0]:
				var arc := []
				for k in 9:
					var ang: float = -PI * 0.5 + side * (0.25 + 0.9 * float(k) / 8.0)
					arc.append(Vector2(side * 21.0, -4) + Vector2(cos(ang) * 24.0, sin(ang) * 34.0))
				pl(ci, rot_pts(arc, tilt, off), 2.2, Color("9a6a42"), s + int(side) + 3)
				hl(ci, off + Vector2(side * 21.0 - 9.0, -20).rotated(tilt), 5, 11, -0.35 + tilt, 0.45)
				hl(ci, off + Vector2(side * 21.0 - 4.0, -34).rotated(tilt), 2, 3, -0.35 + tilt, 0.6)
			## 纤维外皮的毛边
			for k in 11:
				var x := -38.0 + float(k) * 7.6
				pl(ci, rot_pts([Vector2(x, 16.0 + absf(x) * 0.12), Vector2(x + 1.5, 26.0), Vector2(x * 0.92, 34.0)], tilt, off), 1.4, Color("7a5530"), s + k)
			sparks(ci, [Vector2(-48, -46), Vector2(48, -48), Vector2(50, 16), Vector2(-50, 6)])

static func _cashew_th(u: float) -> float:
	return 11.5 + 4.0 * sin(PI * u)

## 旧的副产物「种子到树苗」画法，副产物改成坚果后保留在这里，留给以后别的物品用（游戏里现在不调用）。
## 1 草籽 / 2 榛子 / 3 橡果 / 4 松果 / 5 核桃 / 6 破壳种子 / 7 嫩芽 / 8 三叶苗 / 9 小树苗 / 10 根球树苗 / 11 开花树苗 / 12 挂果树苗
static func seed_old(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			sil(ci, [ov(Vector2(-12, 14), 7, 11, s, SEED, -0.5), ov(Vector2(12, 16), 7, 11, s + 1, SEED, 0.5),
				ov(Vector2(0, 0), 8, 12, s + 2, SEED.lightened(0.12))], rim)
		3:
			sil(ci, [ov(Vector2(0, 10), 20, 24, s, SEED.lightened(0.05)),
				ov(Vector2(0, -12), 24, 12, s + 1, WOOD_D.lightened(0.1), 0.0, 1),
				stk(Vector2(0, -22), Vector2(4, -30), 2.4, s + 2, WOOD_D, 2)], rim)
			for k in 5:
				ln(ci, Vector2(-18.0 + float(k) * 9.0, -16), Vector2(-16.0 + float(k) * 8.0, -6), 1.4, Color(INK, 0.5), s + k)
			ci.draw_circle(Vector2(0, 33), 2.0, WOOD_D)
		4:
			var parts := []
			for r in 5:
				var w := 20.0 - absf(float(r) - 1.5) * 4.0
				for k in 3:
					parts.append(ov(Vector2((float(k) - 1.0) * w * 0.7, -22.0 + float(r) * 12.0), 9, 7, s + r * 3 + k, WOOD.darkened(0.05 * float(k % 2)), 0.0, 1))
			parts.append(stk(Vector2(0, -34), Vector2(2, -44), 2.4, s + 30, WOOD_D, 2))
			sil(ci, parts, rim)
		5:
			## 核桃：一整颗带壳（上下微尖，中间一道棱），前面半个壳露出果仁
			var shell := Color("bf8a52")
			var wc := Vector2(-11, -8)
			var whole := []
			for k in 30:
				var ang := TAU * float(k) / 30.0
				var tip := 1.0 + 0.16 * pow(absf(sin(ang)), 6.0)
				whole.append(wc + Vector2(cos(ang) * 25.0, sin(ang) * 28.0 * tip))
			var hc := Vector2(16, 24)
			var cup := [hc + Vector2(-25, 0)]
			for k in 13:
				var ang := PI * float(k) / 12.0
				cup.append(hc + Vector2(-cos(ang) * 25.0, sin(ang) * 15.0))
			sil(ci, [pg(whole, s, shell, 0), pg(cup, s + 1, shell.darkened(0.08), 0)], rim)
			pl(ci, [wc + Vector2(0, -31), wc + Vector2(1.5, -12), wc + Vector2(-1, 6), wc + Vector2(1, 30)], 3.2, shell.darkened(0.3), s)
			pl(ci, [wc + Vector2(2.5, -29), wc + Vector2(3.5, -12), wc + Vector2(2, 6), wc + Vector2(3, 27)], 1.4, shell.lightened(0.25), s + 1)
			for k in 7:
				var side := -1.0 if k % 2 == 0 else 1.0
				var y := -18.0 + float(k) * 6.0
				var x := side * (9.0 + srnd(s + k) * 6.0)
				pl(ci, [wc + Vector2(x - 5.0, y), wc + Vector2(x - 1.0, y + 3.0), wc + Vector2(x + 5.0, y - 0.5)], 2.0, Color(INK, 0.6), s + k)
			for k in 4:
				ci.draw_circle(wc + Vector2(-14.0 + float(k) * 9.0 + srnd(s + k + 20) * 3.0, -22.0 + float(k % 2) * 40.0), 1.5, Color(INK, 0.35))
			var kern := []
			for k in 16:
				var ang := PI + PI * float(k) / 15.0
				var r := 1.0 + 0.12 * sin(ang * 6.0)
				kern.append(hc + Vector2(cos(ang) * 21.0 * r, sin(ang) * 12.0 * r + 1.0))
			kern.append(hc + Vector2(19, 3))
			kern.append(hc + Vector2(-19, 3))
			ci.draw_colored_polygon(poly(kern, s + 3), Color("e8cc92"))
			outline(ci, poly(kern, s + 3), 1.8)
			ln(ci, hc + Vector2(0, -10), hc + Vector2(0, 3), 1.8, Color(INK, 0.5), s)
			for x in [-10.0, 10.0]:
				pl(ci, [hc + Vector2(x - 5.0, -5), hc + Vector2(x, -1), hc + Vector2(x + 5.0, -5)], 1.6, Color(INK, 0.5), s + int(x))
		6:
			sil(ci, [ov(Vector2(0, 10), 26, 22, s, SEED), stk(Vector2(2, -6), Vector2(-4, -30), 2.6, s + 1, LEAF, 2),
				leaf(Vector2(-4, -28), 14, 5, -2.6, s + 2), leaf(Vector2(-4, -28), 14, 5, -0.4, s + 3)], rim)
			pl(ci, [Vector2(-18, 2), Vector2(-8, 8), Vector2(-2, 2), Vector2(6, 10), Vector2(14, 4)], 2.0, INK, s)
		7:
			sil(ci, [ov(Vector2(0, 24), 36, 13, s, Color("7a4f2a"), 0.0, 1), stk(Vector2(0, 16), Vector2(0, -6), 2.8, s + 1, LEAF, 2),
				leaf(Vector2(0, -6), 18, 6, -2.5, s + 2), leaf(Vector2(0, -6), 18, 6, -0.6, s + 3)], rim)
			for k in 4:
				ci.draw_circle(Vector2(-22.0 + float(k) * 14.0, 24.0 + float(k % 2) * 4.0), 1.8, Color(INK, 0.4))
		8:
			## 三叶苗：一根茎顶着三片叶子
			sil(ci, [ov(Vector2(0, 26), 38, 13, s, Color("7a4f2a"), 0.0, 1), stk(Vector2(0, 18), Vector2(0, -10), 3.0, s + 1, LEAF_D, 2),
				leaf(Vector2(0, -10), 27, 10, -2.75, s + 2), leaf(Vector2(0, -10), 27, 10, -0.39, s + 3),
				leaf(Vector2(0, -12), 26, 10, -1.57, s + 4)], rim)
			for ang in [-2.75, -0.39, -1.57]:
				vein(ci, Vector2(0, -11), 26, ang, s + int(ang * 10.0))
		9:
			sil(ci, [ov(Vector2(0, 30), 38, 12, s, Color("7a4f2a"), 0.0, 1), stk(Vector2(0, 24), Vector2(0, -34), 3.4, s + 1, WOOD, 2),
				leaf(Vector2(0, -6), 26, 9, -2.7, s + 2), leaf(Vector2(0, -2), 26, 9, -0.4, s + 3),
				leaf(Vector2(0, -24), 22, 8, -2.4, s + 4), leaf(Vector2(0, -22), 22, 8, -0.7, s + 5),
				leaf(Vector2(0, -34), 18, 7, -1.57, s + 6)], rim)
		10:
			sil(ci, [ov(Vector2(0, 22), 26, 18, s, Color("c9a06a"), 0.0, 1), stk(Vector2(0, 10), Vector2(0, -36), 3.6, s + 1, WOOD, 2),
				leaf(Vector2(0, -10), 26, 9, -2.7, s + 2), leaf(Vector2(0, -6), 26, 9, -0.4, s + 3),
				leaf(Vector2(0, -26), 22, 8, -2.4, s + 4), leaf(Vector2(0, -24), 22, 8, -0.7, s + 5),
				leaf(Vector2(0, -36), 18, 7, -1.57, s + 6)], rim)
			pl(ci, [Vector2(-25, 18), Vector2(0, 24), Vector2(25, 18)], 3.0, ROPE, s)
			rope(ci, Vector2(0, 40), Vector2(0, 6), 0.8, 2, 7.0, s)
			for k in 3:
				ln(ci, Vector2(-14.0 + float(k) * 12.0, 28), Vector2(-12.0 + float(k) * 12.0, 38), 1.4, Color(INK, 0.4), s + k)
		2:
			## 榛子：一颗圆榛子，顶上带尖、底下一块浅色圆疤，半裹在锯齿边的绿苞叶里
			var nut := Color("a5652e")
			var husk := [Vector2(-15, 6), Vector2(15, 6)]
			for k in 13:
				var ang := -PI * 0.02 - PI * 0.96 * float(k) / 12.0
				var r := 18.0 if k % 2 == 0 else 12.0
				husk.append(Vector2(cos(ang) * r, 4.0 + sin(ang) * r * 0.75))
			sil(ci, [ov(Vector2(0, 14), 15, 16, s, nut), pg(husk, s + 1, LEAF, 0),
				stk(Vector2(0, -6), Vector2(3, -14), 2.2, s + 2, WOOD_D, 2)], rim)
			ci.draw_colored_polygon(ell(Vector2(0, 24), Vector2(8, 4.5), s + 3, 0.04, 12), Color("e6c99a"))
			outline(ci, ell(Vector2(0, 24), Vector2(8, 4.5), s + 3, 0.04, 12), 1.4)
			hl(ci, Vector2(-7, 14), 3, 5, -0.4, 0.45)
		11:
			## 开花树苗：根球包好，树冠圆起来，开满粉白小花——下一级就挂果
			var parts := [ov(Vector2(0, 30), 24, 14, s, Color("c9a06a"), 0.0, 1), stk(Vector2(0, 20), Vector2(0, -6), 4.2, s + 1, WOOD_D, 2),
				circ(Vector2(-15, -16), 18, s + 2, LEAF), circ(Vector2(15, -16), 18, s + 3, LEAF), circ(Vector2(0, -30), 20, s + 4, LEAF.lightened(0.05))]
			sil(ci, parts, rim)
			for f in [Vector2(-20, -14), Vector2(12, -8), Vector2(4, -36), Vector2(20, -24), Vector2(-10, -30), Vector2(-4, -16)]:
				var fv: Vector2 = f
				for j in 5:
					var pa := TAU * float(j) / 5.0 - PI * 0.5
					ci.draw_circle(fv + Vector2(cos(pa), sin(pa)) * 3.4, 3.4, Color(INK, 0.8))
				for j in 5:
					var pa := TAU * float(j) / 5.0 - PI * 0.5
					ci.draw_circle(fv + Vector2(cos(pa), sin(pa)) * 3.4, 2.6, Color("ffc2d6"))
				ci.draw_circle(fv, 2.0, GOLD)
			pl(ci, [Vector2(-23, 28), Vector2(0, 34), Vector2(23, 28)], 3.0, ROPE, s)
		_:
			glow(ci, Vector2(0, -16), 46, GOLD)
			var parts := [ov(Vector2(0, 30), 24, 14, s, Color("c9a06a"), 0.0, 1), stk(Vector2(0, 20), Vector2(0, -6), 4.6, s + 1, WOOD_D, 2),
				circ(Vector2(-16, -18), 20, s + 2, LEAF), circ(Vector2(16, -18), 20, s + 3, LEAF), circ(Vector2(0, -34), 22, s + 4, LEAF.lightened(0.05))]
			sil(ci, parts, rim)
			var fr := [Vector2(-20, -16), Vector2(14, -10), Vector2(4, -36), Vector2(22, -28), Vector2(-10, -30)]
			sil(ci, [circ(fr[0], 6, s + 10, APPLE), circ(fr[1], 6, s + 11, APPLE), circ(fr[2], 6, s + 12, APPLE),
				circ(fr[3], 5, s + 13, APPLE), circ(fr[4], 5, s + 14, APPLE)], false)
			pl(ci, [Vector2(-23, 28), Vector2(0, 34), Vector2(23, 28)], 3.0, ROPE, s)
			sparks(ci, [Vector2(-36, -44), Vector2(36, -48), Vector2(34, 14)])

## 旧的生产器「采集篮」画法，生产器改成灌木到果树后保留在这里，留给以后别的物品用（游戏里现在不调用）。
## 1 干草束 / 2 草绳卷 / 3 半编草篓 / 4 小草篓 / 5 提手草篮 / 6 双耳藤筐 / 7 背篓 / 8 花编大背篓 / 9 丰收圣筐
static func basket_old(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			## 一小把干草，比水果的一级物品大不了多少
			var parts := []
			for k in 4:
				var x0 := -4.5 + float(k) * 3.0
				var x1 := -13.5 + float(k) * 9.0
				parts.append(stk(Vector2(x0, 6), Vector2(x1, -15), 3.6, s + k, GRASS, 2))
				parts.append(stk(Vector2(x0, 6), Vector2(x1 * 0.7, 26), 3.6, s + k + 10, GRASS.darkened(0.06), 2))
			for k in 4:
				parts.append(ov(Vector2(-13.5 + float(k) * 9.0, -18), 3.6, 6.0, s + 20 + k, OCHRE, 0.2 * (float(k) - 1.5), 1))
			parts.append(bx(-9, 2, 18, 7, 2, s + 30, ROPE.darkened(0.1)))
			sil(ci, parts, rim)
			ln(ci, Vector2(-8, 5.5), Vector2(8, 5.5), 1.4, WOOD_D, s)
		2:
			sil(ci, [ov(Vector2(0, 8), 36, 26, s, ROPE.darkened(0.06), 0.0, 1),
				stk(Vector2(28, 2), Vector2(42, -30), 4.0, s + 1, ROPE.darkened(0.06), 2)], rim)
			var arr := []
			for k in 70:
				var t := float(k) / 69.0
				var a := t * TAU * 3.4
				arr.append(Vector2(0, 8) + Vector2(cos(a) * 32.0, sin(a) * 22.0) * (1.0 - t * 0.85))
			pl(ci, arr, 2.0, Color(0.4, 0.22, 0.05, 0.7), s)
		3:
			## 编了一半的草篓：底下编好，上面一圈草茎还竖着，一根草绳搭在外面
			var parts := []
			for k in 7:
				var x := -21.0 + float(k) * 7.0
				parts.append(stk(Vector2(x * 0.9, 12), Vector2(x * 1.35, -24.0 + absf(float(k) - 3.0) * 1.5), 3.2, s + k, GRASS, 2))
			parts.append(pg([Vector2(-25, 9), Vector2(-17, 6), Vector2(-9, 10), Vector2(0, 7), Vector2(9, 11), Vector2(17, 7), Vector2(25, 10),
				Vector2(19, 32), Vector2(-19, 32)], s + 10, GRASS))
			parts.append(stk(Vector2(-22, 13), Vector2(-33, 4), 1.8, s + 11, GRASS.lightened(0.08), 2))
			parts.append(stk(Vector2(24, 10), Vector2(36, 22), 2.4, s + 12, ROPE.darkened(0.06), 2))
			parts.append(stk(Vector2(36, 22), Vector2(30, 34), 2.4, s + 13, ROPE.darkened(0.06), 2))
			sil(ci, parts, rim)
			weave(ci, Rect2(-20, 12, 40, 19), s)
		4:
			sil(ci, _basket_body(Vector2(0, -4), 28, 34, s, GRASS), rim)
			weave(ci, Rect2(-22, 4, 44, 26), s)
		5:
			var parts := [band(Vector2(0, -8), 30, 4.0, PI * 1.05, PI * 1.95, s, WOOD_D)]
			parts.append_array(_basket_body(Vector2(0, -8), 36, 42, s + 2))
			sil(ci, parts, rim)
			weave(ci, Rect2(-30, 0, 60, 34), s)
		6:
			var parts := [band(Vector2(-44, 2), 9, 3.0, PI * 0.5, PI * 1.5, s, WOOD_D),
				band(Vector2(44, 2), 9, 3.0, -PI * 0.5, PI * 0.5, s + 1, WOOD_D),
				leaf(Vector2(-6, -12), 26, 8, -2.6, s + 2), leaf(Vector2(6, -12), 26, 8, -0.5, s + 3)]
			parts.append_array(_fruit_parts(Vector2(-12, -12), 10, APPLE, s + 4, false))
			parts.append(circ(Vector2(10, -12), 9, s + 6, BLUE))
			parts.append_array(_basket_body(Vector2(0, -6), 44, 40, s + 8))
			sil(ci, parts, rim)
			weave(ci, Rect2(-36, 2, 72, 32), s)
		7:
			## 背篓：比花编大背篓矮一截，比双耳藤筐高
			var parts := [stk(Vector2(26, -20), Vector2(29, 32), 3.4, s, LEATHER, 2),
				leaf(Vector2(-8, -22), 22, 7, -2.2, s + 1), leaf(Vector2(4, -22), 24, 8, -1.0, s + 2),
				leaf(Vector2(0, -22), 20, 7, -1.6, s + 3, LEAF_D)]
			parts.append(pg([Vector2(-31, -22), Vector2(31, -22), Vector2(23, 34), Vector2(-23, 34)], s + 4, WOOD))
			parts.append(stk(Vector2(-34, -22), Vector2(34, -22), 5.0, s + 5, WOOD.lightened(0.15)))
			sil(ci, parts, rim)
			weave(ci, Rect2(-27, -14, 54, 44), s)
			ln(ci, Vector2(26, -20), Vector2(29, 32), 2.0, LEATHER_D, s)
		8:
			var parts := [stk(Vector2(28, -32), Vector2(32, 32), 3.4, s, LEATHER, 2),
				leaf(Vector2(-10, -36), 24, 7, -2.2, s + 1), leaf(Vector2(8, -36), 26, 8, -1.0, s + 2)]
			parts.append(pg([Vector2(-34, -36), Vector2(34, -36), Vector2(24, 38), Vector2(-24, 38)], s + 4, WOOD))
			parts.append(circ(Vector2(-14, -40), 10, s + 6, APPLE))
			parts.append(circ(Vector2(4, -42), 9, s + 7, GRAPE))
			parts.append(stk(Vector2(-37, -36), Vector2(37, -36), 5.0, s + 5, OCHRE))
			sil(ci, parts, rim)
			weave(ci, Rect2(-28, -28, 56, 62), s)
			for k in 2:
				var y := -16.0 + float(k) * 26.0
				var w := 31.0 - (y + 36.0) * 0.13
				ci.draw_rect(Rect2(-w, y, w * 2.0, 7), CLAY if k == 0 else TEAL)
				zig(ci, -w + 2.0, w - 2.0, y + 3.5, 2.2, 10, BONE, 1.6, s + k)
			for x in [-26.0, 0.0, 24.0]:
				ci.draw_colored_polygon(star_pts(Vector2(x, -36), 6, 2.6, 5, s + int(x)), BONE)
				ci.draw_circle(Vector2(x, -36), 2.0, GOLD)
		_:
			glow(ci, Vector2(0, -6), 54, GOLD)
			var parts := [ov(Vector2(-34, -26), 5, 22, s, BERRY, -0.5, 1), ov(Vector2(36, -26), 5, 22, s + 1, TEAL, 0.5, 1),
				leaf(Vector2(-10, -20), 28, 8, -2.6, s + 2), leaf(Vector2(10, -20), 28, 8, -0.4, s + 3)]
			for k in 4:
				parts.append(circ(Vector2(-6.0 + float(k) * 6.0, -38.0 + float(k % 2) * 6.0), 6, s + 10 + k, GRAPE))
			parts.append(circ(Vector2(-20, -22), 12, s + 20, APPLE))
			parts.append(ov(Vector2(18, -24), 10, 13, s + 21, PEAR))
			parts.append(circ(Vector2(2, -22), 11, s + 22, MANGO))
			parts.append_array(_basket_body(Vector2(0, -12), 46, 50, s + 30, OCHRE.darkened(0.15)))
			sil(ci, parts, rim)
			weave(ci, Rect2(-38, -4, 76, 42), s)
			ci.draw_rect(Rect2(-40, 10, 80, 7), CLAY)
			zig(ci, -38, 38, 13.5, 2.2, 14, GOLD, 1.8, s)
			sparks(ci, [Vector2(-40, -44), Vector2(38, -46), Vector2(30, 22)], 6)
