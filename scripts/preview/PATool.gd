class_name PATool
extends PA
## 工具线：石匠台 / 石器工具武器 / 矿石宝石

const FLINT := Color("8c8378")
const GREY := Color("c4bdb0")
const OBSID := Color("2b2430")
const OBSID_HL := Color("8a6fc0")

static func _slab(c: Vector2, w: float, h: float, s: int, col: Color = STONE) -> Array:
	return pg([c + Vector2(-w, -h * 0.3), c + Vector2(-w * 0.8, -h), c + Vector2(w * 0.85, -h * 0.9), c + Vector2(w, -h * 0.2),
		c + Vector2(w * 0.9, h), c + Vector2(-w * 0.9, h)], s, col, 0)

static func _flakes(ci: CanvasItem, pts: Array, s: int) -> void:
	for i in pts.size():
		var p: Vector2 = pts[i]
		var f := poly([p + Vector2(-3, -2), p + Vector2(3, -3), p + Vector2(2, 3)], s + i)
		ci.draw_colored_polygon(f, GREY)
		outline(ci, f, 1.4)

## 在石面上画削片疤：从 c 向每条边做扇形，深浅交替，再描疤线
static func _scars(ci: CanvasItem, pts: Array, c: Vector2, col: Color, s: int) -> void:
	for i in pts.size():
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % pts.size()]
		var m := c.lerp((a + b) * 0.5, 0.35)
		var tone := col.lightened(0.14) if i % 2 == 0 else col.darkened(0.1)
		ci.draw_colored_polygon(PackedVector2Array([m, a, b]), tone)
	for i in pts.size():
		var a: Vector2 = pts[i]
		var m := c.lerp(a, 0.35)
		pl(ci, [a, a.lerp(m, 0.5) + Vector2(1.5, -1.0), m], 1.3, Color(INK, 0.45), s + i)

## 鹿角锤：弯的主干带两个分叉
static func _antler(a: Vector2, b: Vector2, s: int) -> Array:
	var d := (b - a)
	var n := Vector2(-d.y, d.x).normalized()
	var mid := a.lerp(b, 0.5) + n * 5.0
	return [stk(a, mid, 6.0, s, BONE2), stk(mid, b, 5.0, s + 1, BONE2),
		stk(mid, mid + n * 13.0 + d.normalized() * 6.0, 3.2, s + 2, BONE2, 2),
		ov(a, 8.0, 7.0, s + 4, BONE2.darkened(0.08), 0.0, 1)]

## 晶簇分三排：后排、中排（最高）、前排（矮，贴着底座前沿往外斜）。
## 返回 [位置, 半宽, 高, 角度]，按从后往前排好，依次画就是前排盖住后排的根部。
static func _crystal_rows(fc: Vector2, rx: float, ry: float, hmax: float, w: float, counts: Array, s: int) -> Array:
	var rows := [[-0.55, 0.6, 0.72, 0.85, 0.35], [0.1, 0.42, 1.0, 1.0, 0.25], [0.85, 0.85, 0.36, 0.72, 0.8]]
	var out := []
	for r in 3:
		var n: int = counts[r]
		var cfg: Array = rows[r]
		for i in n:
			var xn := 0.0 if n == 1 else lerpf(-1.0, 1.0, float(i) / float(n - 1))
			var x: float = xn * rx * cfg[1] + (srnd(s + r * 7 + i) - 0.5) * 3.0
			var y: float = fc.y + ry * cfg[0] + absf(xn) * ry * (-0.25 if r < 2 else -0.1)
			var h: float = hmax * cfg[2] * (1.0 - 0.22 * absf(xn)) * (0.9 + 0.2 * srnd(s + r * 11 + i))
			out.append([Vector2(fc.x + x, y), w * cfg[3], h, xn * cfg[4]])
	return out

static func gen(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			## 河卵石：一颗被水磨圆的扁石头
			var peb := Color("a8a49a")
			sil(ci, [ov(Vector2(0, 12), 30, 19, s, peb, -0.12)], rim)
			ci.draw_colored_polygon(ell(Vector2(4, 18), Vector2(24, 10), s + 1, 0.03, 18, -0.12), Color(peb.darkened(0.12), 0.7))
			hl(ci, Vector2(-10, 2), 11, 4, -0.25, 0.55)
			for k in 5:
				ci.draw_circle(Vector2(-14.0 + float(k) * 7.0 + srnd(s + k) * 4.0, 10.0 + srnd(s + k + 9) * 12.0), 1.3, Color(INK, 0.3))
		2:
			## 敲击石：手里的圆石砸向一块大燧石核，崩出石屑
			var core := [Vector2(-42, 38), Vector2(-46, 12), Vector2(-30, -6), Vector2(-2, -2), Vector2(10, 22), Vector2(-4, 40)]
			sil(ci, [pg(core, s, FLINT), ov(Vector2(16, -16), 17, 14, s + 1, Color("b5aea2"), 0.5)], rim)
			var scar := poly([Vector2(-30, -6), Vector2(-2, -2), Vector2(-10, 16), Vector2(-28, 12)], s + 2)
			ci.draw_colored_polygon(scar, GREY.lightened(0.2))
			outline(ci, scar, 1.6)
			ln(ci, Vector2(-40, 20), Vector2(-14, 32), 1.4, Color(INK, 0.3), s)
			hl(ci, Vector2(10, -24), 7, 3, -0.5, 0.5)
			for k in 4:
				ci.draw_circle(Vector2(8.0 + float(k) * 5.0, -6.0 + float(k % 2) * 3.0), 1.4, Color(INK, 0.35))
			_flakes(ci, [Vector2(18, 14), Vector2(28, 6), Vector2(-24, -18)], s)
			for k in 3:
				var a := -2.5 + float(k) * 0.5
				ln(ci, Vector2(-4, -6) + Vector2(cos(a), sin(a)) * 10.0, Vector2(-4, -6) + Vector2(cos(a), sin(a)) * 18.0, 2.2, OCHRE, s + k)
		3:
			## 石砧：一块平顶大石，台面磨得发亮，上面落着石片
			var body := [Vector2(-44, 4), Vector2(-36, -8), Vector2(36, -10), Vector2(44, 2), Vector2(40, 34), Vector2(-40, 34)]
			sil(ci, [pg(body, s, STONE)], rim)
			ci.draw_colored_polygon(ell(Vector2(0, -3), Vector2(38, 8), s + 1, 0.03, 20), STONE.lightened(0.18))
			outline(ci, ell(Vector2(0, -3), Vector2(38, 8), s + 1, 0.03, 20), 1.6)
			ci.draw_colored_polygon(ell(Vector2(-4, -3), Vector2(12, 3.5), s + 2, 0.0, 12), Color(STONE_D, 0.45))
			for k in 4:
				ln(ci, Vector2(-34.0 + float(k) * 22.0, 10), Vector2(-30.0 + float(k) * 22.0, 28), 1.4, Color(INK, 0.3), s + k)
			_flakes(ci, [Vector2(18, -4), Vector2(26, -1), Vector2(-22, -2)], s)
		4:
			## 骨锤石砧：石砧台面上横放一根兽骨锤，右边一块打了一半的燧石核
			var body := [Vector2(-44, 6), Vector2(-36, -6), Vector2(36, -8), Vector2(44, 4), Vector2(40, 36), Vector2(-40, 36)]
			sil(ci, [pg(body, s, STONE)], rim)
			var face := ell(Vector2(0, -1), Vector2(38, 8), s + 1, 0.03, 20)
			ci.draw_colored_polygon(face, STONE.lightened(0.18))
			outline(ci, face, 1.6)
			for k in 3:
				ln(ci, Vector2(-30.0 + float(k) * 26.0, 14), Vector2(-26.0 + float(k) * 26.0, 30), 1.4, Color(INK, 0.3), s + k)
			var a := Vector2(-34, -6)
			var b := Vector2(6, -12)
			var n := (b - a).normalized().orthogonal()
			sil(ci, [stk(a, b, 4.6, s + 2, BONE2), circ(a + n * 4.5, 6.0, s + 3, BONE2, 1), circ(a - n * 4.5, 6.0, s + 4, BONE2, 1),
				circ(b + n * 4.0, 5.5, s + 5, BONE2, 1), circ(b - n * 4.0, 5.5, s + 6, BONE2, 1),
				pg([Vector2(14, -6), Vector2(16, -24), Vector2(30, -28), Vector2(38, -12), Vector2(32, -2)], s + 7, FLINT)], rim)
			var sc := poly([Vector2(16, -24), Vector2(30, -28), Vector2(28, -14), Vector2(18, -12)], s + 8)
			ci.draw_colored_polygon(sc, GREY.lightened(0.2))
			outline(ci, sc, 1.4)
			ln(ci, a.lerp(b, 0.25), a.lerp(b, 0.75), 1.4, Color(BONE2.darkened(0.3), 0.8), s)
			_flakes(ci, [Vector2(-24, 10), Vector2(24, 8), Vector2(-8, 8)], s)
		5:
			sil(ci, [stk(Vector2(-30, 22), Vector2(-30, 40), 6, s, WOOD_D), stk(Vector2(30, 22), Vector2(30, 40), 6, s + 1, WOOD_D),
				_slab(Vector2(0, 14), 44, 12, s + 2, STONE.lightened(0.05)),
				pg([Vector2(-20, -8), Vector2(18, -14), Vector2(26, -6), Vector2(-14, 0)], s + 3, GREY),
				stk(Vector2(-34, -2), Vector2(-20, -6), 4.0, s + 4, WOOD)], rim)
			pl(ci, [Vector2(-30, 8), Vector2(0, 4), Vector2(30, 6)], 3.0, Color(STONE_D, 0.8), s)
			for p in [Vector2(30, -18), Vector2(36, -10)]:
				ci.draw_colored_polygon(ell(p, Vector2(2.4, 3.6), s, 0.0, 10), SKY)
		6:
			var parts := [stk(Vector2(-34, 6), Vector2(-36, 40), 4.5, s, WOOD_D), stk(Vector2(34, 6), Vector2(36, 40), 4.5, s + 1, WOOD_D),
				bx(-46, -4, 92, 14, 4, s + 2, WOOD)]
			parts.append(stk(Vector2(-30, -10), Vector2(-6, -16), 3.0, s + 3, WOOD_D))
			parts.append(pg([Vector2(-8, -24), Vector2(6, -22), Vector2(4, -8), Vector2(-8, -10)], s + 4, FLINT))
			parts.append(pg([Vector2(8, -10), Vector2(36, -16), Vector2(38, -10), Vector2(10, -6)], s + 5, GREY))
			parts.append(ov(Vector2(-36, -12), 8, 6, s + 6, STONE))
			sil(ci, parts, rim)
			ln(ci, Vector2(-44, 3), Vector2(44, 3), 1.6, WOOD_D, s)
		7:
			var parts := [stk(Vector2(-40, 40), Vector2(-34, -30), 4.0, s, WOOD_D), stk(Vector2(40, 40), Vector2(34, -30), 4.0, s + 1, WOOD_D),
				pg([Vector2(-48, -26), Vector2(0, -50), Vector2(48, -26), Vector2(44, -18), Vector2(-44, -18)], s + 2, LEAF_D.lightened(0.1)),
				_slab(Vector2(-4, 26), 26, 12, s + 3), stk(Vector2(-14, 2), Vector2(4, 12), 3.0, s + 4, BONE2),
				ov(Vector2(6, 12), 7, 5, s + 5, FLINT), raw_rock(Vector2(28, 30), 9, s + 6, FLINT)]
			sil(ci, parts, rim)
			for k in 5:
				ln(ci, Vector2(-40.0 + float(k) * 20.0, -24), Vector2(-28.0 + float(k) * 14.0, -40), 1.6, LEAF_D.darkened(0.3), s + k)
			_flakes(ci, [Vector2(20, 4), Vector2(26, -6)], s)
		_:
			glow(ci, Vector2(0, -4), 54, OBSID_HL)
			var parts := [pg([Vector2(-46, 40), Vector2(-46, -6), Vector2(0, -36), Vector2(46, -6), Vector2(46, 40)], s, STONE.darkened(0.05), 0),
				pg([Vector2(-52, -4), Vector2(0, -46), Vector2(52, -4), Vector2(46, 2), Vector2(0, -34), Vector2(-46, 2)], s + 1, WOOD_D),
				bx(-16, 6, 32, 34, 12, s + 2, Color("3a2416"))]
			parts.append(crystal(Vector2(-30, 40), 6, 16, -0.3, s + 3, OBSID))
			parts.append(crystal(Vector2(32, 40), 7, 20, 0.25, s + 4, OBSID))
			parts.append(crystal(Vector2(-20, 40), 5, 10, 0.1, s + 5, OBSID))
			sil(ci, parts, rim)
			ci.draw_colored_polygon(ell(Vector2(0, 30), Vector2(10, 6), s, 0.1, 10), FIRE)
			for st in [Vector2(-34, 14), Vector2(-30, 26), Vector2(34, 16), Vector2(28, 28)]:
				var v: Vector2 = st
				ln(ci, v, v + Vector2(10, 0), 1.6, Color(INK, 0.4), s)
			crystal_det(ci, Vector2(32, 40), 7, 20, 0.25, s, OBSID_HL)
			crystal_det(ci, Vector2(-30, 40), 6, 16, -0.3, s, OBSID_HL)
			sparks(ci, [Vector2(-42, -30), Vector2(40, -34), Vector2(0, -54)], 6)

static func main(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			## 碎石：两三块不起眼的小碎块
			sil(ci, [raw_rock(Vector2(-10, 18), 11, s, STONE, 5, 0.3), raw_rock(Vector2(11, 20), 9, s + 1, STONE.darkened(0.1), 5, 0.3),
				raw_rock(Vector2(0, 4), 10, s + 2, STONE.lightened(0.1), 5, 0.3)], rim)
		2:
			## 石片：一片薄而锋利的燧石片，有贝壳状的打击波纹
			var pts := [Vector2(-22, 26), Vector2(-24, 6), Vector2(-10, -18), Vector2(8, -28), Vector2(22, -12), Vector2(18, 12), Vector2(0, 28)]
			sil(ci, [pg(pts, s, FLINT)], rim)
			ci.draw_colored_polygon(poly([Vector2(8, -28), Vector2(22, -12), Vector2(18, 12), Vector2(10, 0)], s + 1), FLINT.lightened(0.2))
			for k in 3:
				ci.draw_arc(Vector2(-14, 26), 14.0 + float(k) * 9.0, -1.45, -0.25, 10, Color(INK, 0.35), 1.4, true)
			ci.draw_circle(Vector2(-14, 25), 3.0, Color(FLINT.darkened(0.25)))
		3:
			## 刮削器：一圈修出细齿的燧石刃，背面缠着皮子好握
			var pts := [Vector2(-32, 14), Vector2(32, 14)]
			for k in 17:
				var a := lerpf(-0.05, -PI + 0.05, float(k) / 16.0)
				var r := 33.0 if k % 2 == 0 else 29.5
				pts.append(Vector2(cos(a) * r, 14.0 + sin(a) * r * 0.85))
			var flint := Color("a9a49b")
			sil(ci, [pg(pts, s, flint), bx(-30, 10, 60, 16, 5, s + 1, LEATHER)], rim)
			ci.draw_colored_polygon(ell(Vector2(-4, -4), Vector2(16, 9), s + 2, 0.06, 14), flint.lightened(0.15))
			for k in 8:
				var a := lerpf(-0.25, -PI + 0.25, float(k) / 7.0)
				var c := Vector2(cos(a) * 28.0, 14.0 + sin(a) * 28.0 * 0.85)
				ci.draw_arc(c, 4.0, a + PI - 1.0, a + PI + 1.0, 6, Color(INK, 0.45), 1.3, true)
			for k in 4:
				ln(ci, Vector2(-22.0 + float(k) * 14.0, 11), Vector2(-18.0 + float(k) * 14.0, 25), 2.0, LEATHER.darkened(0.3), s + k)
		4:
			## 手斧：两面都打过的泪滴形大石器，削疤满身，刃口锋利
			var hand := Color("8f8c88")
			var base := []
			for k in 22:
				var a := TAU * float(k) / 22.0
				var y := sin(a)
				var w := 24.0 * (1.0 - 0.55 * maxf(-y, 0.0)) * (1.0 + 0.1 * maxf(y, 0.0))
				base.append(Vector2(cos(a) * w, y * 40.0 + 4.0) + Vector2(srnd(s + k) - 0.5, srnd(s + k + 30) - 0.5) * 3.0)
			var pts := rot_pts(base, 0.3)
			sil(ci, [pg(pts, s, hand, 0)], rim)
			var coarse := []
			for k in range(0, pts.size(), 3):
				coarse.append(pts[k])
			_scars(ci, coarse, Vector2(0, 6).rotated(0.3), hand, s)
			pl(ci, [Vector2(0, -32).rotated(0.3), Vector2(1, -8).rotated(0.3), Vector2(-1, 16).rotated(0.3), Vector2(0, 38).rotated(0.3)], 1.6, Color(INK, 0.5), s)
			hl(ci, Vector2(-8, -12).rotated(0.3), 5, 12, 0.3, 0.45)
		5:
			var blade := [Vector2(-12, 10), Vector2(2, -14), Vector2(32, -40), Vector2(24, -6), Vector2(2, 16)]
			sil(ci, [stk(Vector2(-32, 36), Vector2(-6, 8), 7.5, s + 1, WOOD), pg(blade, s, GREY)], rim)
			ln(ci, Vector2(-4, 12), Vector2(28, -36), 1.4, INK, s)
			rope(ci, Vector2(-32, 36), Vector2(-6, 8), 0.72, 3, 8.0, s)
		7:
			## 石锤：锤头是一块方石，能看到正面、顶面和一个端面
			var d := Vector2(36, -50).normalized()
			var n := Vector2(-d.y, d.x)
			var c := Vector2(14, -16)
			var v := Vector2(-6, -12)
			var A := c - n * 22.0 + d * 9.0
			var B := c + n * 22.0 + d * 9.0
			var C2 := c + n * 22.0 - d * 9.0
			var D := c - n * 22.0 - d * 9.0
			sil(ci, [stk(Vector2(-28, 40), c, 4.5, s, WOOD), pg([D, C2, B, B + v, A + v, D + v], s + 1, STONE, 0)], rim)
			var front := PackedVector2Array([A, B, C2, D])
			var top := PackedVector2Array([A, A + v, B + v, B])
			var side := PackedVector2Array([A, D, D + v, A + v])
			ci.draw_colored_polygon(front, STONE)
			ci.draw_colored_polygon(top, STONE.lightened(0.2))
			ci.draw_colored_polygon(side, STONE.darkened(0.15))
			for q in [front, top, side]:
				outline(ci, q, 1.6)
			for k in 3:
				ci.draw_circle(c + n * (-10.0 + float(k) * 9.0) + d * float(k % 2) * 3.0, 1.4, Color(INK, 0.3))
			rope(ci, Vector2(-28, 40), c, 0.86, 3, 6.0, s)
		9:
			## 骨针：皮垫上并排别着粗细两根骨针，针眼穿着筋线连到线团
			sil(ci, [bx(-36, -10, 54, 40, 9, s, LEATHER, 0), circ(Vector2(26, 24), 14, s + 1, Color("e2c79a"))], rim)
			dashed(ci, rrect(Rect2(-31, -5, 44, 30), 6, s), 4, 3, Color(BONE, 0.8), 1.6)
			for k in 2:
				var a0 := Vector2(-34.0 + float(k) * 14.0, -30.0)
				var a1 := a0 + Vector2(40, 54) * (1.0 - float(k) * 0.18)
				sil(ci, [stk(a0, a1, 3.6 - float(k) * 0.9, s + 2 + k, BONE2)], rim)
				var ang := (a1 - a0).angle() - PI * 0.5
				ci.draw_colored_polygon(ell(a0 + (a1 - a0).normalized() * 4.0, Vector2(1.4, 2.8) * (1.0 - float(k) * 0.25), s, 0.0, 8, ang), INK)
			for k in 4:
				var a := 0.4 + float(k) * 0.7
				pl(ci, [Vector2(26, 24) + Vector2(cos(a), sin(a)) * 12.0, Vector2(26, 24) + Vector2(cos(a + 1.6), sin(a + 1.6)) * 12.0], 1.4, Color(INK, 0.4), s + k)
			pl(ci, [Vector2(-31, -26), Vector2(-14, -36), Vector2(8, -30), Vector2(22, -10), Vector2(24, 10)], 2.0, Color("c9a26a"), s)
		11:
			## 鱼叉：比石矛高一级——磨光的骨质叉头带三道倒钩，柄上缠赭红纹，叉头系着一圈筋绳
			var d := Vector2(1, -1).normalized()
			var n := Vector2(d.y, -d.x)
			var base := Vector2(-42, 42)
			var neck := base + d * 66.0
			var loc := [Vector2(0, 6), Vector2(10, 7), Vector2(5, 15), Vector2(20, 8), Vector2(15, 17), Vector2(31, 8), Vector2(27, 15),
				Vector2(46, 0), Vector2(31, -8), Vector2(26, -14), Vector2(20, -7), Vector2(14, -15), Vector2(9, -6), Vector2(0, -6)]
			var head := []
			for q in loc:
				head.append(neck + d * q.x + n * q.y)
			var tipp := neck + d * 46.0
			sil(ci, [stk(base, neck + d * 4.0, 4.6, s, WOOD, 2), pg(head, s + 1, BONE2, 0),
				circ(Vector2(24, 26), 11, s + 2, ROPE, 1)], rim)
			ln(ci, neck + d * 2.0, tipp - d * 3.0, 1.4, Color(INK, 0.45), s)
			for k in 2:
				var c := base + d * (22.0 + float(k) * 12.0)
				ln(ci, c - n * 4.6, c + n * 4.6, 3.6, CLAY, s + k)
			rope(ci, base, neck, 0.96, 3, 6.0, s)
			ci.draw_arc(Vector2(24, 26), 7.0, 0.0, TAU, 14, Color(INK, 0.4), 1.4, true)
			ci.draw_arc(Vector2(24, 26), 3.5, 0.0, TAU, 10, Color(INK, 0.4), 1.4, true)
			pl(ci, [neck + n * 2.0, neck + n * 10.0 - d * 14.0, Vector2(30, 6), Vector2(32, 16)], 2.0, ROPE.darkened(0.15), s)
		6:
			## 石斧：木柄上绑一块楔形石头，越往外越宽，刃口是一道磨亮的弧
			var R := 0.35
			var o := Vector2(-6, 2)
			var head := rot_pts([Vector2(-10, -30), Vector2(-4, -36), Vector2(8, -33), Vector2(30, -45), Vector2(38, -37), Vector2(42, -24),
				Vector2(41, -10), Vector2(36, 1), Vector2(8, -12), Vector2(-4, -9), Vector2(-10, -14)], R, o)
			var hs := Vector2(0, 44).rotated(R) + o
			var he := Vector2(0, -40).rotated(R) + o
			sil(ci, [stk(hs, he, 4.8, s + 1, WOOD), pg(head, s, Color("8f8c88"), 0)], rim)
			var bevel := poly(rot_pts([Vector2(30, -45), Vector2(38, -37), Vector2(42, -24), Vector2(41, -10), Vector2(36, 1),
				Vector2(31, -5), Vector2(34, -16), Vector2(34, -28), Vector2(27, -38)], R, o), s + 2)
			ci.draw_colored_polygon(bevel, Color("c9c4bc"))
			outline(ci, bevel, 1.4)
			pl(ci, rot_pts([Vector2(14, -34), Vector2(18, -22), Vector2(14, -12)], R, o), 1.4, Color(INK, 0.4), s)
			for k in 4:
				var y := -32.0 + float(k) * 6.0
				ln(ci, Vector2(-7, y).rotated(R) + o, Vector2(7, y + 4.0).rotated(R) + o, 3.6, INK, s + k)
				ln(ci, Vector2(-7, y).rotated(R) + o, Vector2(7, y + 4.0).rotated(R) + o, 2.0, ROPE, s + k)
			rope(ci, hs, he, 0.12, 3, 6.0, s)
		10:
			var tip := [Vector2(22, -26), Vector2(30, -40), Vector2(46, -48), Vector2(38, -32), Vector2(30, -20)]
			sil(ci, [stk(Vector2(-44, 44), Vector2(28, -28), 3.6, s, WOOD, 2), pg(tip, s + 1, GREY),
				leaf(Vector2(-32, 32), 14, 4, 2.0, s + 2, BERRY), leaf(Vector2(-32, 32), 14, 4, 2.9, s + 3, OCHRE)], rim)
			ln(ci, Vector2(28, -28), Vector2(44, -46), 1.4, INK, s)
			rope(ci, Vector2(-44, 44), Vector2(28, -28), 0.92, 2, 5.0, s)
		8:
			## 石镐：木柄顶端横绑一块两头尖的弯月形石镐头
			var R := 0.25
			var o := Vector2(0, 6)
			var out := []
			for k in 15:
				var ang := deg_to_rad(lerpf(-166.0, -14.0, float(k) / 14.0))
				out.append(Vector2(0, 12) + Vector2(cos(ang), sin(ang)) * 46.0)
			out.append(Vector2(48, 2))
			for k in 15:
				var ang := deg_to_rad(lerpf(-22.0, -158.0, float(k) / 14.0))
				out.append(Vector2(0, 16) + Vector2(cos(ang), sin(ang)) * 37.0)
			out.append(Vector2(-48, 2))
			var head := rot_pts(out, R, o)
			var hs := Vector2(0, 44).rotated(R) + o
			var he := Vector2(0, -38).rotated(R) + o
			sil(ci, [stk(hs, he, 4.6, s, WOOD), pg(head, s + 1, Color("9a958e"), 0)], rim)
			var lower := []
			for k in 13:
				var ang := deg_to_rad(lerpf(-150.0, -30.0, float(k) / 12.0))
				lower.append(Vector2(0, 16) + Vector2(cos(ang), sin(ang)) * 37.0)
			for k in 13:
				var ang := deg_to_rad(lerpf(-30.0, -150.0, float(k) / 12.0))
				lower.append(Vector2(0, 14) + Vector2(cos(ang), sin(ang)) * 41.0)
			ci.draw_colored_polygon(poly(rot_pts(lower, R, o), s + 2), Color("7d7872"))
			var hi := []
			for k in 9:
				var ang := deg_to_rad(lerpf(-140.0, -60.0, float(k) / 8.0))
				hi.append(Vector2(0, 12) + Vector2(cos(ang), sin(ang)) * 42.0)
			pl(ci, rot_pts(hi, R, o), 2.4, Color(1, 1, 1, 0.45), s)
			for k in 3:
				var y := -40.0 + float(k) * 5.0
				ln(ci, Vector2(-7, y).rotated(R) + o, Vector2(7, y + 5.0).rotated(R) + o, 3.6, INK, s + k)
				ln(ci, Vector2(-7, y).rotated(R) + o, Vector2(7, y + 5.0).rotated(R) + o, 2.0, ROPE, s + k)
				ln(ci, Vector2(7, y).rotated(R) + o, Vector2(-7, y + 5.0).rotated(R) + o, 3.6, INK, s + k + 5)
				ln(ci, Vector2(7, y).rotated(R) + o, Vector2(-7, y + 5.0).rotated(R) + o, 2.0, ROPE, s + k + 5)
			rope(ci, hs, he, 0.15, 3, 6.0, s)
		12:
			var parts := [stk(Vector2(-40, -30), Vector2(-10, 14), 1.8, s, ROPE, 2), stk(Vector2(36, -34), Vector2(10, 14), 1.8, s + 1, ROPE, 2),
				ov(Vector2(0, 18), 18, 12, s + 2, LEATHER, 0.0, 1), circ(Vector2(0, 10), 10, s + 3, STONE)]
			parts.append(circ(Vector2(-40, -32), 4, s + 4, ROPE, 1))
			sil(ci, parts, rim)
			dashed(ci, ell(Vector2(0, 20), Vector2(13, 7), s, 0.0, 14), 4, 3, Color(BONE, 0.8), 1.6)
		13:
			## 弓箭：弓背朝箭头方向弯，弦往后拉到箭尾
			var bc := Vector2(-20, 0)
			var a0 := -PI * 0.36
			var a1 := PI * 0.36
			var bow := band(bc, 42, 4.2, a0, a1, s, WOOD, 1)
			var top := bc + Vector2(cos(a0), sin(a0)) * 42.0
			var bot := bc + Vector2(cos(a1), sin(a1)) * 42.0
			var nock := Vector2(-30, 0)
			ln(ci, top, nock, 1.8, INK, s)
			ln(ci, nock, bot, 1.8, INK, s + 2)
			sil(ci, [bow, stk(Vector2(-30, 0), Vector2(36, 0), 2.4, s + 1, WOOD.lightened(0.2), 2),
				pg([Vector2(34, -7), Vector2(50, 0), Vector2(34, 7)], s + 2, STONE_D),
				pg([Vector2(-40, -8), Vector2(-26, -1), Vector2(-26, 1), Vector2(-40, 8), Vector2(-34, 0)], s + 3, CLAY)], rim)
			ln(ci, top, nock, 1.8, INK, s)
			ln(ci, nock, bot, 1.8, INK, s + 2)
			rope(ci, bc + Vector2(42, -6), bc + Vector2(42, 6), 0.9, 2, 5.0, s)
		14:
			var blade := [Vector2(-10, 10), Vector2(36, -38), Vector2(44, -44), Vector2(40, -32), Vector2(0, 18)]
			sil(ci, [stk(Vector2(-36, 40), Vector2(-10, 14), 6.5, s, BONE2), pg(blade, s + 1, GREY),
				stk(Vector2(-16, 6), Vector2(4, 24), 3.6, s + 2, LEATHER)], rim)
			ln(ci, Vector2(-4, 12), Vector2(40, -38), 1.4, INK, s)
			rope(ci, Vector2(-36, 40), Vector2(-10, 14), 0.6, 3, 7.0, s)
		15:
			var head := [Vector2(0, -36), Vector2(-24, -48), Vector2(-34, -24), Vector2(-26, -6), Vector2(0, -20),
				Vector2(26, -6), Vector2(34, -24), Vector2(24, -48)]
			sil(ci, [stk(Vector2(0, -44), Vector2(0, 46), 5.0, s, WOOD_D), pg(head, s + 1, OBSID),
				leaf(Vector2(0, 30), 18, 4, 2.2, s + 2, BERRY), leaf(Vector2(0, 30), 18, 4, 0.9, s + 3, OCHRE)], rim)
			ci.draw_colored_polygon(poly([Vector2(-22, -44), Vector2(-30, -24), Vector2(-22, -14), Vector2(-16, -34)], s), Color(OBSID_HL, 0.6))
			ci.draw_colored_polygon(poly([Vector2(22, -44), Vector2(30, -24), Vector2(24, -16), Vector2(18, -36)], s + 1), Color(OBSID_HL, 0.45))
			rope(ci, Vector2(0, 46), Vector2(0, -44), 0.66, 3, 7.0, s)
			spark(ci, Vector2(-30, -40), 5)
		_:
			glow(ci, Vector2(0, -26), 40, GOLD)
			sil(ci, [stk(Vector2(0, -20), Vector2(0, 46), 4.5, s, WOOD_D),
				leaf(Vector2(-6, -24), 26, 5, -2.2, s + 1, BERRY), leaf(Vector2(6, -24), 26, 5, -0.9, s + 2, TEAL),
				leaf(Vector2(-4, -24), 22, 5, -2.7, s + 3, OCHRE), leaf(Vector2(4, -24), 22, 5, -0.4, s + 4, OCHRE),
				pg([Vector2(-14, -18), Vector2(-16, -34), Vector2(-6, -26), Vector2(0, -38), Vector2(6, -26), Vector2(16, -34), Vector2(14, -18)], s + 5, BONE2),
				circ(Vector2(0, -26), 10, s + 6, AMBER)], rim)
			hl(ci, Vector2(-3, -29), 4, 2.4)
			rope(ci, Vector2(0, 46), Vector2(0, -20), 0.68, 3, 6.0, s)
			sparks(ci, [Vector2(-30, -42), Vector2(28, -46), Vector2(24, 2)])

static func sub(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			## 燧石：一整块深青黑的玻璃质石头，表面有贝壳状波纹和高光，只有一层
			var fl := Color("3e4a5e")
			var pts := [Vector2(-26, 22), Vector2(-28, 2), Vector2(-14, -16), Vector2(6, -20), Vector2(24, -8), Vector2(28, 12), Vector2(16, 30), Vector2(-10, 34)]
			sil(ci, [pg(pts, s, fl, 0)], rim)
			ci.draw_colored_polygon(poly([Vector2(-14, -16), Vector2(6, -20), Vector2(24, -8), Vector2(4, -2), Vector2(-12, -4)], s + 1), fl.lightened(0.18))
			for k in 3:
				ci.draw_arc(Vector2(-18, 26), 10.0 + float(k) * 8.0, -1.4, 0.1, 10, Color(1, 1, 1, 0.2), 1.6, true)
			ln(ci, Vector2(-12, -4), Vector2(4, -2), 1.4, Color(INK, 0.4), s)
			ln(ci, Vector2(4, -2), Vector2(24, -8), 1.4, Color(INK, 0.4), s + 1)
			hl(ci, Vector2(0, -10), 8, 3, -0.2, 0.65)
			hl(ci, Vector2(14, 16), 3, 5, -0.6, 0.35)
		2:
			sil(ci, [raw_rock(Vector2(-4, 8), 24, s, Color("c4572d"), 8, 0.18), raw_rock(Vector2(22, 26), 9, s + 1, Color("d86a3a"), 6, 0.2)], rim)
			for k in 6:
				ci.draw_circle(Vector2(-30.0 + float(k) * 11.0, 34.0 + float(k % 2) * 2.0), 1.8, Color("d86a3a"))
		6:
			## 石英：乳白原石块做底，两三排透明晶柱从后往前长满顶面（最朴素，排数最少）
			var cs := _crystal_rows(Vector2(0, 24), 17, 6, 36, 6.5, [2, 1, 3], s)
			var basep := raw_rock(Vector2(0, 30), 22, s + 9, Color("d6dce3"), 7, 0.2)
			var crys := []
			for q in cs:
				crys.append(crystal(q[0], q[1], q[2], q[3], s + crys.size(), Color("f4f8fb")))
			sil(ci, [basep] + crys, rim)
			var face := ell(Vector2(0, 24), Vector2(19, 6), s + 10, 0.05, 16)
			ci.draw_colored_polygon(face, Color("eef2f6"))
			outline(ci, face, 1.6)
			for k in 3:
				pl(ci, [Vector2(-14.0 + float(k) * 11.0, 33), Vector2(-9.0 + float(k) * 11.0, 39)], 2.0, Color(1, 1, 1, 0.8), s + k)
			for i in cs.size():
				var q: Array = cs[i]
				sil(ci, [crys[i]], false)
				crystal_det(ci, q[0], q[1], q[2], q[3], s + i, Color("a8b8c8"))
		9:
			var pts := [Vector2(-20, 30), Vector2(-30, 0), Vector2(-8, -36), Vector2(10, -30), Vector2(28, 10), Vector2(14, 32)]
			sil(ci, [pg(pts, s, OBSID)], rim)
			ci.draw_colored_polygon(poly([Vector2(-8, -36), Vector2(10, -30), Vector2(0, 0), Vector2(-14, -4)], s), Color(OBSID_HL, 0.55))
			ci.draw_colored_polygon(poly([Vector2(-26, 0), Vector2(-14, -4), Vector2(-14, 20)], s + 1), Color(1, 1, 1, 0.2))
		3:
			sil(ci, [ov(Vector2(0, 6), 32, 28, s, Color("c86a3a"), 0.0, 1)], rim)
			for k in 5:
				var f := 1.0 - float(k) * 0.18
				ci.draw_colored_polygon(ell(Vector2(2, 8), Vector2(26, 22) * f, s + k, 0.06, 18), Color("f4d6b0") if k % 2 == 0 else Color("d8743a"))
			ci.draw_colored_polygon(ell(Vector2(3, 9), Vector2(5, 3.5), s, 0.0, 10), Color("8ad0d8"))
		4:
			sil(ci, [raw_rock(Vector2(0, 8), 28, s, Color("4fc2b4"), 9, 0.15)], rim)
			pl(ci, [Vector2(-22, -4), Vector2(-8, 4), Vector2(-2, -6), Vector2(14, 6), Vector2(22, 0)], 1.8, Color(INK, 0.55), s)
			pl(ci, [Vector2(-12, 20), Vector2(0, 14), Vector2(12, 24)], 1.8, Color(INK, 0.55), s + 3)
			hl(ci, Vector2(-10, -10), 8, 4)
		5:
			sil(ci, [raw_rock(Vector2(0, 8), 30, s, Color("2a4fa8"), 8, 0.14)], rim)
			for k in 9:
				var p := Vector2((srnd(s + k) - 0.5) * 36.0, (srnd(s + k + 20) - 0.5) * 30.0 + 8.0)
				ci.draw_colored_polygon(star_pts(p, 2.6, 1.0, 4, s + k), GOLD)
			hl(ci, Vector2(-12, -8), 8, 4)
		7:
			## 紫水晶：紫色晶簇团做底，顶面密布小晶尖；三排晶柱从后往前长满（比石英多一排宽度）
			var cs := _crystal_rows(Vector2(0, 25), 26, 7, 38, 6.5, [3, 2, 4], s)
			var basep := ov(Vector2(0, 30), 31, 12, s + 9, Color("5a3480"), 0.0, 1)
			var crys := []
			for q in cs:
				crys.append(crystal(q[0], q[1], q[2], q[3], s + crys.size(), PURPLE))
			sil(ci, [basep] + crys, rim)
			var face := ell(Vector2(0, 25), Vector2(27, 7), s + 10, 0.04, 18)
			ci.draw_colored_polygon(face, Color("7a4aa8"))
			outline(ci, face, 1.6)
			for k in 10:
				var p := Vector2(-22.0 + float(k) * 4.9, 25.0 + sin(float(k) * 1.9) * 3.5)
				ci.draw_colored_polygon(star_pts(p, 2.4, 0.9, 4, s + k), Color("d8b0f0"))
			for k in 4:
				ln(ci, Vector2(-20.0 + float(k) * 13.0, 35), Vector2(-18.0 + float(k) * 13.0, 40), 1.4, Color(1, 1, 1, 0.3), s + k)
			for i in cs.size():
				var q: Array = cs[i]
				sil(ci, [crys[i]], false)
				crystal_det(ci, q[0], q[1], q[2], q[3], s + i, Color("d8b0f0"))
		8:
			## 黄水晶：切出刻面的金黄水晶块做底，三排晶柱最密最高，整块透着光（最讲究）
			glow(ci, Vector2(0, 4), 48, Color("ffd66a"))
			var cs := _crystal_rows(Vector2(0, 15), 26, 6, 46, 7.0, [3, 3, 4], s)
			var blk := [Vector2(-30, 15), Vector2(-29, 25), Vector2(-19, 35), Vector2(0, 39), Vector2(19, 35), Vector2(29, 25), Vector2(30, 15)]
			for k in 11:
				var ang := lerpf(0.0, -PI, float(k) / 10.0)
				blk.append(Vector2(cos(ang) * 30.0, 15.0 + sin(ang) * 7.0))
			var crys := []
			for q in cs:
				crys.append(crystal(q[0], q[1], q[2], q[3], s + crys.size(), Color("f2b632")))
			sil(ci, [pg(blk, s + 9, Color("d89a1c"), 0)] + crys, rim)
			var face := ell(Vector2(0, 15), Vector2(30, 7), s + 10, 0.03, 22)
			ci.draw_colored_polygon(face, Color("ffd36a"))
			outline(ci, face, 1.6)
			for q in [[Vector2(-27, 18), Vector2(-29, 25), Vector2(-19, 35)], [Vector2(-12, 21.5), Vector2(-19, 35)], [Vector2(-12, 21.5), Vector2(0, 39)],
					[Vector2(12, 21.5), Vector2(0, 39)], [Vector2(12, 21.5), Vector2(19, 35)], [Vector2(27, 18), Vector2(29, 25), Vector2(19, 35)]]:
				pl(ci, q, 1.4, Color(INK, 0.4), s)
			ci.draw_colored_polygon(poly([Vector2(-27, 19), Vector2(-13, 22), Vector2(-19, 34), Vector2(-28, 25)], s + 11), Color(1, 1, 1, 0.3))
			ci.draw_colored_polygon(poly([Vector2(13, 22), Vector2(27, 19), Vector2(28, 25), Vector2(19, 34)], s + 12), Color(0.5, 0.25, 0, 0.18))
			for i in cs.size():
				var q: Array = cs[i]
				sil(ci, [crys[i]], false)
				crystal_det(ci, q[0], q[1], q[2], q[3], s + i, Color("ffe7a0"))
			sparks(ci, [Vector2(-20, -30), Vector2(32, -8)], 4.5)
		10:
			cut_gem(ci, Vector2(0, 4), 32, Color("e0283c"), s, rim)
			spark(ci, Vector2(-20, -24), 5)
		11:
			cut_gem(ci, Vector2(0, 2), 38, Color("2f6fe0"), s, rim)
			sparks(ci, [Vector2(-28, -28), Vector2(30, 24)], 5)
		_:
			## 神光钻石：大颗明亮式切工的钻石，冰蓝白，带彩色火光，放在金色托座上
			glow(ci, Vector2(0, -4), 56, Color("bfe8ff"))
			rays(ci, Vector2(0, -6), 40, 54, 8, Color(1, 1, 0.9, 0.55), 2.6, 0.2)
			var r := 38.0
			var c := Vector2(0, -2)
			var g := [c + Vector2(-r, -r * 0.12), c + Vector2(-r * 0.6, -r * 0.6), c + Vector2(r * 0.6, -r * 0.6),
				c + Vector2(r, -r * 0.12), c + Vector2(0, r * 0.95)]
			var mount := [Vector2(-14, 34), Vector2(14, 34), Vector2(20, 44), Vector2(-20, 44)]
			sil(ci, [pg(mount, s + 1, GOLD, 1), pg(g, s, Color("e8f6ff"), 0)], rim)
			var lc := Color("7fa8c8")
			ln(ci, g[0], g[3], 1.8, lc, s)
			var gx := [-0.6, -0.3, 0.0, 0.3, 0.6]
			for k in gx.size():
				var top := c + Vector2(r * gx[k], -r * 0.6)
				var mid := c + Vector2(r * (gx[k] * 1.55), -r * 0.12)
				if k < gx.size() - 1:
					ln(ci, top, c + Vector2(r * (gx[k] + 0.15) * 1.55, -r * 0.12), 1.3, lc, s + k)
				ln(ci, mid, g[4], 1.3, lc, s + k + 7)
			for k in 4:
				var mid := c + Vector2(r * (gx[k] + 0.15) * 1.55, -r * 0.12)
				ln(ci, mid, c + Vector2(r * gx[k + 1], -r * 0.6), 1.3, lc, s + k + 14)
			ci.draw_colored_polygon(poly([g[1], c + Vector2(-r * 0.3, -r * 0.6), c + Vector2(-r * 0.47, -r * 0.12), g[0]], s), Color(1, 1, 1, 0.75))
			ci.draw_colored_polygon(poly([c + Vector2(r * 0.47, -r * 0.12), c + Vector2(r * 0.93, -r * 0.12), g[4]], s + 1), Color("ffb0d8", 0.45))
			ci.draw_colored_polygon(poly([c + Vector2(-r * 0.47, -r * 0.12), c + Vector2(0, -r * 0.12), g[4]], s + 2), Color("a0e8ff", 0.45))
			ci.draw_colored_polygon(poly([c + Vector2(0, -r * 0.12), c + Vector2(r * 0.47, -r * 0.12), g[4]], s + 3), Color("fff0a0", 0.35))
			ln(ci, Vector2(-14, 36), Vector2(14, 36), 1.4, Color(INK, 0.4), s)
			ci.draw_colored_polygon(star_pts(Vector2(-18, -24), 9, 2.5, 4, s), Color.WHITE)
			sparks(ci, [Vector2(-40, -34), Vector2(38, -38), Vector2(40, 14), Vector2(-38, 16)], 5)
