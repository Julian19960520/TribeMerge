class_name PATool
extends PA
## 工具线：采石场 / 石料 / 宝石原石。
## 旧图（石匠台、石器武器、矿石宝石）留作成品图：gen_old / main_old / sub_old。

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

static func gen_old(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
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

static func main_old(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
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

static func sub_old(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
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

# ================================================================ 采石场 / 石料 / 宝石原石

const PEB := Color("b3ab9f")
const CORTEX := Color("ebe3cf")
const FLINT_N := Color("4b505a")
const SAND := Color("d6ab6c")
const ROCK := Color("a59c8e")
const BEACH := Color("ecd6a2")
const QUARTZ := Color("eef3f7")
const MILKY := Color("d6dce3")
const TURQ := Color("4fc2b4")
const MATRIX := Color("8f7a62")
const DIAM := Color("e4f2fa")
const KIMB := Color("6f7c86")

## 每级整体缩放（以脚底为中心），按烘焙后的面积调
const GEN_SCALE := [0.92, 0.9, 0.73, 0.81, 0.89, 0.9, 0.96, 0.96]
const MAIN_SCALE := [0.53, 0.78, 0.74, 0.82, 0.8, 0.934, 0.983, 1.099, 0.957, 0.936, 0.807, 0.9, 1.04, 1.158, 1.183, 1.13]
const SUB_SCALE := [1.05, 0.78, 0.8, 0.91, 0.95, 1.0, 1.18, 0.84, 0.91, 1.21, 1.5, 1.2]

static func _st_grow(ci: CanvasItem, k: float) -> Transform2D:
	var keep := xf
	xf = keep * Transform2D(0.0, Vector2(k, k), 0.0, Vector2(0, 38) * (1.0 - k))
	ci.draw_set_transform_matrix(xf)
	return keep

static func _st_ungrow(ci: CanvasItem, keep: Transform2D) -> void:
	xf = keep
	ci.draw_set_transform_matrix(xf)

static func gen(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	var keep := _st_grow(ci, GEN_SCALE[clampi(lv, 1, 8) - 1])
	_gen_art(ci, lv, s, rim)
	_st_ungrow(ci, keep)

static func main(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	var keep := _st_grow(ci, MAIN_SCALE[clampi(lv, 1, 16) - 1])
	_main_art(ci, lv, s, rim)
	_st_ungrow(ci, keep)

static func sub(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	var keep := _st_grow(ci, SUB_SCALE[clampi(lv, 1, 12) - 1])
	_sub_art(ci, lv, s, rim)
	_st_ungrow(ci, keep)

## 一堆前后叠着的东西共用一圈白边，之后再从后往前逐个画（各自不带白边）
static func _st_rim(ci: CanvasItem, parts: Array) -> void:
	for p in parts:
		dilate(ci, p[0], 9.0, RIM_COL)

## 一组卵石：每项 [中心, 半宽, 半高, 颜色]，按从后往前自动排好
static func _st_pebs(ci: CanvasItem, list: Array, s: int, rim: bool) -> void:
	list.sort_custom(func(a, b): return a[0].y < b[0].y)
	var parts := []
	for i in list.size():
		var q: Array = list[i]
		parts.append(ov(q[0], q[1], q[2], s + i, q[3], 0.0, 0, 0.06))
	if rim:
		_st_rim(ci, parts)
	for i in parts.size():
		var q: Array = list[i]
		var c: Vector2 = q[0]
		sil(ci, [parts[i]], false)
		safe_poly(ci, ell(c + Vector2(q[1] * 0.1, q[2] * 0.4), Vector2(q[1] * 0.7, q[2] * 0.35), s + i, 0.04, 14), Color(0, 0, 0, 0.08))
		for k in 2:
			ci.draw_circle(c + Vector2((srnd(s + i * 5 + k) - 0.5) * q[1], (srnd(s + i * 5 + k + 9) - 0.2) * q[2] * 0.6), 1.1, Color(INK, 0.25))

## 燧石结核：疙疙瘩瘩的一团，外面是白色石皮
static func _st_nod_pts(c: Vector2, r: float, s: int) -> Array:
	var out := []
	var ph := srnd(s) * TAU
	for k in 18:
		var a := TAU * float(k) / 18.0
		var m := 1.0 + 0.12 * sin(a * 3.0 + ph) + 0.07 * sin(a * 5.0 + ph * 2.0)
		out.append(c + Vector2(cos(a), sin(a) * 0.8) * r * m)
	return out

static func _st_nod_det(ci: CanvasItem, c: Vector2, r: float, s: int, window: bool = true) -> void:
	for k in 6:
		ci.draw_circle(c + Vector2((srnd(s + k) - 0.5) * 1.2 * r, (srnd(s + k + 13) - 0.5) * 0.9 * r), 1.3, Color("bdb29a"))
	if window:
		var w := ell(c + Vector2(r * 0.2, r * 0.05), Vector2(r * 0.4, r * 0.27), s, 0.1, 12, 0.3)
		safe_poly(ci, w, FLINT_N)
		outline(ci, w, 1.4)
		hl(ci, c + Vector2(r * 0.1, -r * 0.04), r * 0.15, r * 0.06, -0.3, 0.55)

## 剖开的半块燧石：一圈白石皮，里面是深色有波纹的断面
static func _st_half_parts(c: Vector2, r: float, s: int) -> Array:
	var out := _st_nod_pts(c, r, s)
	var inn := []
	for p in out:
		inn.append(c + ((p as Vector2) - c) * 0.64 + Vector2(r * 0.04, -r * 0.04))
	return [pg(out, s, CORTEX, 1), pg(inn, s + 1, FLINT_N, 2)]

static func _st_half_det(ci: CanvasItem, c: Vector2, r: float, s: int) -> void:
	for k in 3:
		ci.draw_arc(c + Vector2(-r * 0.3, r * 0.25), r * (0.25 + 0.17 * float(k)), -1.45, -0.15, 10, Color(1, 1, 1, 0.18), 1.4, true)
	hl(ci, c + Vector2(-r * 0.2, -r * 0.3), r * 0.2, r * 0.08, -0.3, 0.45)

## 一块平放的石板：顶面不规则，往下一圈厚度
static func _st_slab_top(c: Vector2, w: float, d: float, s: int, rot: float) -> Array:
	var top := []
	for k in 8:
		var a := TAU * float(k) / 8.0 + 0.2
		var m := 0.9 + srnd(s + k) * 0.18
		top.append(c + Vector2(cos(a) * w, sin(a) * d).rotated(rot) * m)
	return top

static func _st_slab_parts(c: Vector2, w: float, d: float, th: float, s: int, col: Color = SAND, rot: float = 0.0) -> Array:
	var top := _st_slab_top(c, w, d, s, rot)
	var both := PackedVector2Array()
	for p in top:
		both.append(p)
		both.append((p as Vector2) + Vector2(0, th))
	var body := Geometry2D.convex_hull(both)
	body.remove_at(body.size() - 1)
	return [P(body, col.darkened(0.2), 2), pg(top, s + 1, col, 1)]

static func _st_slab_det(ci: CanvasItem, c: Vector2, w: float, d: float, th: float, s: int, rot: float = 0.0) -> void:
	var top := _st_slab_top(c, w, d, s, rot)
	var lip := []
	for k in [7, 0, 1, 2, 3, 4]:
		lip.append((top[k] as Vector2) + Vector2(0, th * 0.55))
	pl(ci, lip.slice(1, 5), 1.2, Color(INK, 0.3), s)
	for k in 3:
		ci.draw_circle(c + Vector2((srnd(s + k * 3) - 0.5) * w * 1.1, (srnd(s + k * 3 + 1) - 0.5) * d * 0.9), 1.2, Color(INK, 0.22))
	ln(ci, c + Vector2(-w * 0.5, -d * 0.35), c + Vector2(-w * 0.1, -d * 0.5), 2.2, Color(1, 1, 1, 0.35), s)

## 黑曜石：棱角分明的一块，玻璃面带紫光和一道白亮光
static func _st_shard_pts(c: Vector2, rx: float, ry: float, s: int, n: int = 7) -> Array:
	var out := []
	for k in n:
		var a := TAU * float(k) / float(n) + (srnd(s + k) - 0.5) * 0.5
		var m := 0.72 + srnd(s * 3 + k) * 0.42
		out.append(c + Vector2(cos(a) * rx, sin(a) * ry) * m)
	return out

static func _st_obs_det(ci: CanvasItem, pts: Array, c: Vector2, s: int) -> void:
	_scars(ci, pts, c, OBSID, s)
	ci.draw_colored_polygon(PackedVector2Array([c.lerp(pts[1], 0.9), c.lerp(pts[2], 0.9), c]), Color(OBSID_HL, 0.45))
	ln(ci, c.lerp(pts[2], 0.75), c.lerp(pts[3], 0.55), 2.2, Color(1, 1, 1, 0.6), s)
	ci.draw_circle(c.lerp(pts[2], 0.75), 1.6, Color(1, 1, 1, 0.8))

## 钻石原石：没打磨的八面体，转一点角度露出四个面
static func _st_octa(c: Vector2, r: float, ang: float) -> Array:
	return [c + Vector2(0, -r).rotated(ang), c + Vector2(r * 0.8, -r * 0.05).rotated(ang), c + Vector2(0, r).rotated(ang),
		c + Vector2(-r * 0.8, -r * 0.05).rotated(ang), c + Vector2(r * 0.24, r * 0.1).rotated(ang)]

static func _st_octa_part(c: Vector2, r: float, ang: float, s: int) -> Array:
	var v := _st_octa(c, r, ang)
	return pg([v[0], v[1], v[2], v[3]], s, DIAM, 2)

static func _st_octa_det(ci: CanvasItem, c: Vector2, r: float, ang: float, s: int) -> void:
	var v := _st_octa(c, r, ang)
	var q := []
	for p in v:
		q.append(c + ((p as Vector2) - c) * 0.93)
	ci.draw_colored_polygon(PackedVector2Array([q[0], q[3], q[4]]), Color("fbfeff"))
	ci.draw_colored_polygon(PackedVector2Array([q[0], q[4], q[1]]), Color("cfe5f1"))
	ci.draw_colored_polygon(PackedVector2Array([q[3], q[2], q[4]]), Color("b9d6e7"))
	ci.draw_colored_polygon(PackedVector2Array([q[4], q[2], q[1]]), Color("98bdd6"))
	for k in 4:
		ln(ci, v[4], v[k], 1.3, Color("6f93ad", 0.85), s + k)
	ci.draw_colored_polygon(PackedVector2Array([q[4].lerp(q[1], 0.3), q[4].lerp(q[2], 0.3), q[4].lerp(q[2], 0.6)]), Color("ffd0ea", 0.5))
	ci.draw_colored_polygon(star_pts((v[0] as Vector2).lerp(v[3], 0.35), r * 0.22, r * 0.07, 4, s), Color.WHITE)

## 一根小晶柱带细节
static func _st_crys(ci: CanvasItem, list: Array, s: int, col: Color, det: Color, rim: bool, extra: Array = []) -> void:
	var parts := extra.duplicate()
	for i in list.size():
		var q: Array = list[i]
		parts.append(crystal(q[0], q[1], q[2], q[3], s + i, col))
	sil(ci, parts, rim)
	for i in list.size():
		var q: Array = list[i]
		crystal_det(ci, q[0], q[1], q[2], q[3], s + i, det)

## 一面岩壁 / 大石头，带几道横向岩层
static func _st_strata(ci: CanvasItem, x0: float, x1: float, ys: Array, s: int) -> void:
	for i in ys.size():
		var y: float = ys[i]
		pl(ci, [Vector2(x0, y), Vector2(lerpf(x0, x1, 0.35), y - 2.0), Vector2(lerpf(x0, x1, 0.7), y + 1.5), Vector2(x1, y - 1.0)], 1.3, Color(INK, 0.22), s + i)

## 一道裂缝
static func _st_crack(ci: CanvasItem, pts: Array, w: float, s: int) -> void:
	pl(ci, pts, w + 1.6, INK, s)
	pl(ci, pts, w * 0.5, Color("3a2e26"), s)

## 有柄的石锤
static func _st_hammer(a: Vector2, b: Vector2, s: int) -> Array:
	var d := (b - a).normalized()
	return [stk(a, b, 3.2, s, WOOD), ov(b + d * 2.0, 9.0, 6.5, s + 1, STONE, d.angle() + PI * 0.5, 0)]

static func _gen_art(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			## 河滩乱石：一小片河滩，水边散着几颗石头
			sil(ci, [ov(Vector2(-4, 24), 30, 6, s, Color("8cc6e0"), 0.0, 2), ov(Vector2(0, 32), 34, 9, s + 1, BEACH, 0.0, 2)], rim)
			pl(ci, [Vector2(-28, 23), Vector2(-20, 22), Vector2(-12, 23)], 1.4, Color(1, 1, 1, 0.7), s)
			pl(ci, [Vector2(4, 21), Vector2(12, 20), Vector2(18, 21)], 1.4, Color(1, 1, 1, 0.7), s + 1)
			_st_pebs(ci, [[Vector2(-14, 32), 8, 5.5, PEB], [Vector2(9, 35), 6, 4, Color("a49c91")], [Vector2(18, 29), 4.5, 3, Color("c2b9ab")], [Vector2(-1, 28), 4, 3, PEB]], s + 3, false)
		2:
			## 碎石坡：一小堆乱糟糟的碎石
			var rocks := [[Vector2(-6, 8), 10.0], [Vector2(10, 12), 9.0], [Vector2(-20, 22), 10.0], [Vector2(2, 20), 11.0], [Vector2(22, 24), 9.0],
				[Vector2(-28, 33), 8.0], [Vector2(-10, 32), 10.0], [Vector2(10, 33), 9.0], [Vector2(28, 34), 7.0]]
			var parts := []
			for i in rocks.size():
				var q: Array = rocks[i]
				var col := ROCK.lightened(0.08) if i % 3 == 0 else (ROCK.darkened(0.08) if i % 3 == 1 else ROCK)
				parts.append(raw_rock(q[0], q[1], s + i * 3, col, 6, 0.28))
			if rim:
				_st_rim(ci, parts)
			for p in parts:
				sil(ci, [p], false)
		3:
			## 裂开的岩壁：一块大石头，中间一道裂缝，还没人动过
			var body := [Vector2(-40, 38), Vector2(-42, 12), Vector2(-30, -12), Vector2(-8, -22), Vector2(16, -18), Vector2(34, -4), Vector2(42, 18), Vector2(40, 38)]
			sil(ci, [pg(body, s, ROCK, 0)], rim)
			_st_strata(ci, -38, 38, [6.0, 22.0], s)
			_st_crack(ci, [Vector2(2, -20), Vector2(6, -8), Vector2(0, 4), Vector2(5, 16), Vector2(2, 26)], 2.0, s)
			_st_crack(ci, [Vector2(0, 4), Vector2(-10, 10)], 1.2, s + 4)
			sil(ci, [ov(Vector2(-14, -10), 7, 3, s + 5, MOSS, -0.3, 2)], false)
		4:
			## 撬石岩壁：裂缝撬开了，插着一根木撬棍，脚下落着撬下来的石块
			var body := [Vector2(-42, 38), Vector2(-44, 12), Vector2(-32, -12), Vector2(-8, -22), Vector2(16, -18), Vector2(34, -4), Vector2(42, 18), Vector2(40, 38)]
			var gap := [Vector2(0, -20), Vector2(8, -8), Vector2(4, 4), Vector2(8, 18), Vector2(3, 30), Vector2(-1, 18), Vector2(-3, 4), Vector2(-4, -8)]
			sil(ci, [pg(body, s, ROCK, 0), stk(Vector2(3, -6), Vector2(40, -34), 3.4, s + 1, WOOD), raw_rock(Vector2(26, 32), 10, s + 2, ROCK.lightened(0.06), 6, 0.25)], rim)
			ci.draw_colored_polygon(poly(gap, s), Color("3a2e26"))
			outline(ci, poly(gap, s), 1.8)
			sil(ci, [stk(Vector2(3, -6), Vector2(40, -34), 3.4, s + 1, WOOD)], false)
			_st_strata(ci, -40, 38, [8.0, 24.0], s)
			_st_pebs(ci, [[Vector2(-22, 34), 7, 5, PEB], [Vector2(-10, 36), 5, 3.5, Color("c2b9ab")], [Vector2(-30, 30), 4.5, 3, Color("a49c91")]], s + 4, false)
		5:
			## 采石坑：岩壁上凿出一块方方的新茬，前面摆着撬下的石板、卵石和石锤
			var wall := [Vector2(-46, 30), Vector2(-46, -2), Vector2(-30, -20), Vector2(10, -26), Vector2(36, -14), Vector2(46, 6), Vector2(46, 30)]
			var parts := [pg(wall, s, ROCK, 0)]
			parts.append_array(_st_slab_parts(Vector2(-24, 30), 18, 7, 5, s + 2, SAND))
			parts.append_array(_st_hammer(Vector2(34, 36), Vector2(20, 12), s + 4))
			if rim:
				_st_rim(ci, parts)
			sil(ci, [parts[0]], false)
			var cut := poly([Vector2(-12, -12), Vector2(20, -14), Vector2(20, 14), Vector2(-12, 16)], s + 1)
			ci.draw_colored_polygon(cut, ROCK.lightened(0.16))
			outline(ci, cut, 1.8)
			ci.draw_colored_polygon(poly([Vector2(20, -14), Vector2(26, -18), Vector2(26, 10), Vector2(20, 14)], s + 2), ROCK.darkened(0.2))
			_st_strata(ci, -44, 44, [-4.0, 22.0], s)
			sil(ci, parts.slice(1, 3), false)
			_st_slab_det(ci, Vector2(-24, 30), 18, 7, 5, s + 2)
			_st_pebs(ci, [[Vector2(4, 32), 7, 5, PEB], [Vector2(14, 35), 5, 3.5, Color("c2b9ab")]], s + 6, false)
			sil(ci, parts.slice(3, 5), false)
		6:
			## 石匠棚：木杆搭的斜顶棚，下面一块干活的大石台，两边分堆放着石料
			var parts := [stk(Vector2(-40, 38), Vector2(-36, -26), 3.6, s, WOOD_D), stk(Vector2(40, 38), Vector2(36, -26), 3.6, s + 1, WOOD_D),
				pg([Vector2(-50, -22), Vector2(0, -46), Vector2(50, -22), Vector2(46, -14), Vector2(-46, -14)], s + 2, GRASS)]
			sil(ci, parts, rim)
			for k in 6:
				ln(ci, Vector2(-40.0 + float(k) * 16.0, -16), Vector2(-28.0 + float(k) * 11.0, -38), 1.5, GRASS_D, s + k)
			var front := _st_slab_parts(Vector2(0, 26), 22, 8, 10, s + 3, ROCK)
			front.append_array(_st_hammer(Vector2(-12, 16), Vector2(4, 10), s + 5))
			sil(ci, front, false)
			_st_slab_det(ci, Vector2(0, 26), 22, 8, 10, s + 3)
			var nod := pg(_st_nod_pts(Vector2(-32, 32), 8, s + 7), s + 7, CORTEX, 1)
			sil(ci, [nod], false)
			_st_nod_det(ci, Vector2(-32, 32), 8, s + 7)
			sil(ci, _st_slab_parts(Vector2(32, 34), 11, 4, 3, s + 8, SAND), false)
			sil(ci, _st_slab_parts(Vector2(32, 29), 10, 4, 3, s + 9, SAND.lightened(0.05)), false)
		7:
			## 燧石矿坑：石坡上挖出一个黑乎乎的竖井，伸出一架木梯，坑壁嵌着白色燧石
			var hill := [Vector2(-48, 38), Vector2(-44, 4), Vector2(-26, -20), Vector2(0, -28), Vector2(26, -20), Vector2(44, 4), Vector2(48, 38)]
			var parts := [pg(hill, s, ROCK, 0)]
			if rim:
				_st_rim(ci, parts + [stk(Vector2(-4, 10), Vector2(-14, -40), 2.6, s, WOOD), stk(Vector2(10, 10), Vector2(2, -40), 2.6, s, WOOD)])
			sil(ci, parts, false)
			_st_strata(ci, -44, 44, [16.0, 30.0], s)
			var hole := ell(Vector2(2, 12), Vector2(20, 9), s + 1, 0.05, 18)
			ci.draw_colored_polygon(hole, Color("2e241d"))
			outline(ci, hole, 2.2)
			for k in 5:
				var c: Vector2 = [Vector2(-32, 6), Vector2(-22, 24), Vector2(30, 0), Vector2(34, 22), Vector2(-14, -10)][k]
				var p := pg(_st_nod_pts(c, 5.0, s + 10 + k), s + 10 + k, CORTEX, 1)
				sil(ci, [p], false)
			var ladder := [stk(Vector2(-4, 10), Vector2(-14, -40), 2.6, s + 2, WOOD), stk(Vector2(10, 10), Vector2(2, -40), 2.6, s + 3, WOOD)]
			sil(ci, ladder, false)
			for k in 4:
				var t := 0.2 + float(k) * 0.22
				ln(ci, Vector2(-4, 10).lerp(Vector2(-14, -40), t), Vector2(10, 10).lerp(Vector2(2, -40), t), 3.6, INK, s + k)
				ln(ci, Vector2(-4, 10).lerp(Vector2(-14, -40), t), Vector2(10, 10).lerp(Vector2(2, -40), t), 2.0, WOOD.lightened(0.15), s + k)
			for q in [[Vector2(26, 34), 8.0], [Vector2(38, 32), 6.0]]:
				var p := pg(_st_nod_pts(q[0], q[1], s + 20), s + 20, CORTEX, 1)
				sil(ci, [p], false)
				_st_nod_det(ci, q[0], q[1], s + 20)
		_:
			## 晶洞矿场：大石山上开着洞口，两边插着火把，洞里透出发光的晶体
			glow(ci, Vector2(0, 8), 56, Color("c99ae8"))
			var hill := [Vector2(-50, 38), Vector2(-48, 0), Vector2(-32, -26), Vector2(-6, -38), Vector2(22, -32), Vector2(42, -12), Vector2(50, 12), Vector2(50, 38)]
			var torches := [stk(Vector2(-36, 38), Vector2(-34, 2), 2.8, s + 1, WOOD_D), stk(Vector2(36, 38), Vector2(34, 2), 2.8, s + 2, WOOD_D)]
			sil(ci, [pg(hill, s, ROCK.darkened(0.05), 0)] + torches, rim)
			_st_strata(ci, -46, 46, [-14.0, 6.0], s)
			var mouth := [Vector2(-22, 38), Vector2(-22, 10), Vector2(-14, -6), Vector2(0, -12), Vector2(14, -6), Vector2(22, 10), Vector2(22, 38)]
			ci.draw_colored_polygon(poly(mouth, s + 3), Color("2e1f3a"))
			ci.draw_colored_polygon(ell(Vector2(0, 26), Vector2(18, 14), s, 0.0, 16), Color("8a4fb0", 0.45))
			_st_crys(ci, [[Vector2(-12, 38), 4.5, 16.0, -0.4], [Vector2(-3, 38), 5.5, 26.0, -0.1], [Vector2(8, 38), 5.0, 20.0, 0.25],
				[Vector2(16, 38), 3.5, 10.0, 0.6]], s + 4, PURPLE.lightened(0.15), Color("e0c0f8"), false)
			_st_crys(ci, [[Vector2(-18, 38), 3.0, 8.0, -0.7], [Vector2(2, 38), 3.0, 9.0, 0.1]], s + 9, QUARTZ, Color("a8b8c8"), false)
			outline(ci, poly(mouth, s + 3), 2.4)
			sil(ci, torches, false)
			for x in [-34.0, 34.0]:
				sil(ci, [stk(Vector2(x - 4.0, 4), Vector2(x + 4.0, 4), 3.4, s, ROPE)], false)
				flame(ci, Vector2(x, 0), 8, 14, s + int(x))
			sparks(ci, [Vector2(-10, -26), Vector2(20, -22), Vector2(-44, -20)], 5)

## 把一组点绕 pv 转 ang
static func _st_rot(arr: Array, ang: float, pv: Vector2) -> Array:
	var out := []
	for p in arr:
		out.append(pv + ((p as Vector2) - pv).rotated(ang))
	return out

## 方石块：正面、顶面、右侧面三面，v 是往后上方的进深
static func _st_block_faces(c: Vector2, hw: float, hh: float, v: Vector2) -> Array:
	var a := c + Vector2(-hw, -hh)
	var b := c + Vector2(hw, -hh)
	var d := c + Vector2(hw, hh)
	var e := c + Vector2(-hw, hh)
	return [[a, b, d, e], [a, a + v, b + v, b], [b, b + v, d + v, d]]

static func _st_block_part(c: Vector2, hw: float, hh: float, v: Vector2, col: Color) -> Array:
	var all := PackedVector2Array()
	for f in _st_block_faces(c, hw, hh, v):
		for p in f:
			all.append(p)
	var hull := Geometry2D.convex_hull(all)
	hull.remove_at(hull.size() - 1)
	return P(hull, col, 2)

static func _st_block(ci: CanvasItem, c: Vector2, hw: float, hh: float, v: Vector2, s: int, col: Color, chisel: int = 3) -> void:
	sil(ci, [_st_block_part(c, hw, hh, v, col)], false)
	var faces := _st_block_faces(c, hw, hh, v)
	var tones := [col, col.lightened(0.2), col.darkened(0.18)]
	for i in 3:
		var q := poly(faces[i], s + i, 0.6)
		ci.draw_colored_polygon(q, tones[i])
		outline(ci, q, 1.6)
	for k in chisel:
		var x := c.x - hw * 0.7 + (float(k) + 0.5) * hw * 1.4 / float(chisel)
		var y := c.y + (srnd(s + k) - 0.5) * hh * 0.8
		ln(ci, Vector2(x - 2.0, y - 2.5), Vector2(x + 2.0, y + 2.5), 1.3, Color(INK, 0.35), s + k)

static func _main_art(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			## 石片：一片薄而锋利的燧石片，有贝壳状的打击波纹
			var pts := [Vector2(-22, 34), Vector2(-24, 14), Vector2(-10, -10), Vector2(8, -20), Vector2(22, -4), Vector2(18, 20), Vector2(0, 36)]
			sil(ci, [pg(pts, s, FLINT)], rim)
			ci.draw_colored_polygon(poly([Vector2(8, -20), Vector2(22, -4), Vector2(18, 20), Vector2(10, 8)], s + 1), FLINT.lightened(0.2))
			for k in 3:
				ci.draw_arc(Vector2(-14, 34), 14.0 + float(k) * 9.0, -1.45, -0.25, 10, Color(INK, 0.35), 1.4, true)
			ci.draw_circle(Vector2(-14, 33), 3.0, Color(FLINT.darkened(0.25)))

		2:
			## 尖锐石片：一片又窄又尖的燧石片，两边修出细齿，做箭尖用
			var pts := rot_pts([Vector2(-13, 34), Vector2(-9, 12), Vector2(0, -22), Vector2(9, 12), Vector2(13, 34), Vector2(0, 38)], 0.22, Vector2(0, 8))
			sil(ci, [pg(pts, s, STONE_D.lightened(0.12), 0)], rim)
			_scars(ci, pts, rot_pts([Vector2(0, 16)], 0.22, Vector2(0, 8))[0], STONE_D.lightened(0.12), s)
			pl(ci, rot_pts([Vector2(0, -16), Vector2(1, 10), Vector2(0, 34)], 0.22, Vector2(0, 8)), 1.4, Color(1, 1, 1, 0.35), s)
			ci.draw_circle(rot_pts([Vector2(0, 33)], 0.22, Vector2(0, 8))[0], 2.4, STONE_D.darkened(0.1))

		3:
			## 矛头：两面都打薄的尖叶形矛头，边上一圈细削疤
			var base := []
			for k in 20:
				var a := TAU * float(k) / 20.0
				var y := sin(a)
				var w := 15.0 * (1.0 - 0.6 * maxf(-y, 0.0)) * (1.0 - 0.25 * maxf(y, 0.0))
				base.append(Vector2(cos(a) * w, y * 34.0 + 4.0))
			var pts := rot_pts(base, 0.5, Vector2(0, 2))
			sil(ci, [pg(pts, s, Color("a9a49b"), 0)], rim)
			var coarse := []
			for k in range(0, pts.size(), 2):
				coarse.append(pts[k])
			_scars(ci, coarse, Vector2(0, 6).rotated(0.5) + Vector2(0, 2), Color("a9a49b"), s)
			pl(ci, rot_pts([Vector2(0, -26), Vector2(1, 4), Vector2(0, 30)], 0.5, Vector2(0, 2)), 1.5, Color(INK, 0.45), s)

		4:
			## 半月石刀：照旧刮削器的样子——半圆形燧石片，弧边一圈修出细齿当刃口，平直的背上钻两个穿绳孔，收割草和谷穗用
			var flint := Color("a9a49b")
			var pts := [Vector2(-32, 30), Vector2(32, 30)]
			for k in 17:
				var an := lerpf(-0.05, -PI + 0.05, float(k) / 16.0)
				var r := 33.0 if k % 2 == 0 else 29.5
				pts.append(Vector2(cos(an) * r, 30.0 + sin(an) * r * 0.85))
			sil(ci, [pg(pts, s, flint)], rim)
			ci.draw_colored_polygon(ell(Vector2(-4, 12), Vector2(16, 9), s + 2, 0.06, 14), flint.lightened(0.15))
			for k in 8:
				var an := lerpf(-0.25, -PI + 0.25, float(k) / 7.0)
				var c := Vector2(cos(an) * 28.0, 30.0 + sin(an) * 28.0 * 0.85)
				ci.draw_arc(c, 4.0, an + PI - 1.0, an + PI + 1.0, 6, Color(INK, 0.45), 1.3, true)
			pl(ci, [Vector2(-29, 26), Vector2(29, 26)], 1.4, Color(INK, 0.3), s)
			for x in [-10.0, 10.0]:
				ci.draw_circle(Vector2(x, 21), 2.6, INK)
		5:
			## 长石刃：从石核上剥下来的一条长刃，微微弯，两边刃口平行，背上两道棱，根部有打击点
			var spine := []
			for k in 13:
				var t := float(k) / 12.0
				spine.append(Vector2(lerpf(-38.0, 38.0, t), lerpf(28.0, -10.0, t) - sin(PI * t) * 9.0))
			var up := []
			var dn := []
			var rid_a := []
			var rid_b := []
			for k in 13:
				var t := float(k) / 12.0
				var p: Vector2 = spine[k]
				var d: Vector2 = ((spine[mini(k + 1, 12)] as Vector2) - (spine[maxi(k - 1, 0)] as Vector2)).normalized()
				var n := Vector2(-d.y, d.x)
				var w := 11.0 * (1.0 - 0.85 * pow(t, 3.0)) * minf(1.0, 0.55 + t * 6.0) + 0.8
				up.append(p - n * w)
				dn.append(p + n * w)
				rid_a.append(p - n * w * 0.3)
				rid_b.append(p + n * w * 0.35)
			dn.reverse()
			var pts := up + dn
			sil(ci, [pg(pts, s, FLINT, 2)], rim)
			var midf := rid_a.duplicate()
			var rb := rid_b.duplicate()
			rb.reverse()
			safe_poly(ci, poly(midf + rb, s + 1, 0.4), FLINT.lightened(0.16))
			var edge := []
			for k in range(1, 12):
				edge.append((up[k] as Vector2).lerp(rid_a[k], 0.35))
			pl(ci, edge, 2.4, Color(1, 1, 1, 0.3), s)
			pl(ci, rid_a.slice(1, 12), 1.3, Color(INK, 0.45), s + 2)
			pl(ci, rid_b.slice(1, 12), 1.3, Color(INK, 0.45), s + 3)
			ci.draw_circle(spine[0] + Vector2(4, -1), 3.0, FLINT.darkened(0.2))
			for k in 2:
				ci.draw_arc(spine[0] + Vector2(4, -1), 7.0 + float(k) * 5.0, -1.1, 1.1, 8, Color(INK, 0.3), 1.2, true)

		6:
			## 石凿：一条窄长的磨制石楔，尾巴圆钝，前头磨出一道平直的刃，凿木头、刻花纹用
			var a := Vector2(-32, 30)
			var b := Vector2(32, -10)
			var d := (b - a).normalized()
			var n := Vector2(-d.y, d.x)
			var col := Color("8f8c88")
			var body := [a - d * 3.0 + n * 3.0, a + n * 5.5, b - d * 8.0 + n * 7.5, b + n * 7.5, b - n * 7.5, b - d * 8.0 - n * 7.5, a - n * 5.5, a - d * 3.0 - n * 3.0]
			var th := Vector2(0, 6)
			var side := [a + n * 5.5, b - d * 8.0 + n * 7.5, b + n * 7.5, b + n * 7.5 + th, b - d * 8.0 + n * 7.5 + th, a + n * 5.5 + th]
			sil(ci, [pg(side, s + 1, col.darkened(0.22), 2), pg(body, s, col.lightened(0.06), 2)], rim)
			var bevel := poly([b - d * 9.0 + n * 7.5, b + n * 7.5, b - n * 7.5, b - d * 9.0 - n * 7.5], s + 2, 0.4)
			ci.draw_colored_polygon(bevel, col.lightened(0.28))
			outline(ci, bevel, 1.4)
			ln(ci, b + n * 7.5, b - n * 7.5, 2.0, Color(1, 1, 1, 0.7), s)
			hl(ci, a.lerp(b, 0.4) + n * 2.5, 14, 1.8, d.angle(), 0.5)
			for k in 3:
				ci.draw_circle(a.lerp(b, 0.15 + float(k) * 0.2) - n * 2.0, 1.1, Color(INK, 0.3))

		7:
			## 石锛头：磨制的长梯形石块，尾窄头宽，一面平一面微拱，宽头只在一面磨出斜刃（和斧头的两面刃不同）
			var a := Vector2(-24, 26)
			var b := Vector2(20, 8)
			var d := (b - a).normalized()
			var n := Vector2(-d.y, d.x)
			var col := Color("8f8c88")
			var top := [a + n * 8.0 - d * 2.0, b + n * 17.0, b + d * 5.0 + n * 6.0, b + d * 5.0 - n * 6.0, b - n * 17.0, a - n * 8.0 - d * 2.0]
			var th := Vector2(0, 8)
			var side := [a + n * 8.0 - d * 2.0, b + n * 17.0, b + n * 17.0 + th, a + n * 8.0 - d * 2.0 + th * 0.7]
			sil(ci, [pg(side, s + 1, col.darkened(0.24), 2), pg(top, s, col.lightened(0.04), 2)], rim)
			var bev := poly([b - d * 12.0 + n * 17.0, b + n * 17.0, b + d * 5.0 + n * 6.0, b + d * 5.0 - n * 6.0, b - n * 17.0, b - d * 12.0 - n * 17.0], s + 2, 0.4)
			ci.draw_colored_polygon(bev, col.lightened(0.26))
			outline(ci, bev, 1.4)
			pl(ci, [b + n * 17.0 + th * 0.5, b + d * 5.0 + n * 6.0 + th * 0.4], 2.0, Color(1, 1, 1, 0.6), s)
			hl(ci, a.lerp(b, 0.42), 13, 3, d.angle(), 0.45)
			for k in 4:
				ci.draw_circle(a.lerp(b, 0.12 + float(k) * 0.16) + n * (float(k % 2) * 5.0 - 2.5), 1.1, Color(INK, 0.3))
		8:
			## 斧头坯：石斧上那块楔形斧头，越往外越宽，刃口磨出一道亮弧
			var R := 0.35
			var o := Vector2(-21, 18)
			var head := rot_pts([Vector2(-10, -30), Vector2(-4, -36), Vector2(8, -33), Vector2(30, -45), Vector2(38, -37), Vector2(42, -24),
				Vector2(41, -10), Vector2(36, 1), Vector2(8, -12), Vector2(-4, -9), Vector2(-10, -14)], R, o)
			sil(ci, [pg(head, s, Color("8f8c88"), 0)], rim)
			var bevel := poly(rot_pts([Vector2(30, -45), Vector2(38, -37), Vector2(42, -24), Vector2(41, -10), Vector2(36, 1),
				Vector2(31, -5), Vector2(34, -16), Vector2(34, -28), Vector2(27, -38)], R, o), s + 2)
			ci.draw_colored_polygon(bevel, Color("c9c4bc"))
			outline(ci, bevel, 1.4)
			pl(ci, rot_pts([Vector2(14, -34), Vector2(18, -22), Vector2(14, -12)], R, o), 1.4, Color(INK, 0.4), s)
			for k in 3:
				ci.draw_circle(rot_pts([Vector2(-2.0 + float(k) * 6.0, -24.0 + float(k % 2) * 4.0)], R, o)[0], 1.3, Color(INK, 0.3))

		9:
			## 石板：一块厚实的砂岩石板，铺地、垒火塘用
			sil(ci, _st_slab_parts(Vector2(0, 26), 30, 13, 7, s), rim)
			_st_slab_det(ci, Vector2(0, 26), 30, 13, 7, s)

		10:
			## 两块石板：两块砂岩石板错开叠着，底下那块颜色深一点
			var a := _st_slab_parts(Vector2(5, 28), 30, 12, 6, s, SAND.darkened(0.08), 0.08)
			var b := _st_slab_parts(Vector2(-3, 18), 28, 12, 6, s + 4, SAND, -0.06)
			if rim:
				_st_rim(ci, a + b)
			sil(ci, a, false)
			_st_slab_det(ci, Vector2(5, 28), 30, 12, 6, s, 0.08)
			sil(ci, b, false)
			_st_slab_det(ci, Vector2(-3, 18), 28, 12, 6, s + 4, -0.06)

		11:
			## 一摞石板：四块石板摞成一摞
			var all := []
			var cfg := []
			for k in 4:
				var c := Vector2(float(k % 2) * 6.0 - 3.0, 32.0 - float(k) * 10.0)
				var col := SAND.darkened(0.12 - float(k) * 0.04)
				cfg.append([c, 32.0 - float(k) * 1.5, 12.0, 7.0, s + k * 4, 0.06 * float(k % 2 * 2 - 1)])
				all.append_array(_st_slab_parts(c, cfg[k][1], 12, 7, s + k * 4, col, cfg[k][5]))
			if rim:
				_st_rim(ci, all)
			for k in 4:
				var q: Array = cfg[k]
				sil(ci, all.slice(k * 2, k * 2 + 2), false)
				_st_slab_det(ci, q[0], q[1], q[2], q[3], q[4], q[5])

		12:
			## 毛石：一块刚撬下来、还没凿方的粗大石块，一面是新鲜的断口
			var pts := [Vector2(-34, 38), Vector2(-38, 18), Vector2(-28, -2), Vector2(-6, -10), Vector2(18, -6), Vector2(34, 8), Vector2(36, 30), Vector2(26, 38)]
			sil(ci, [pg(pts, s, ROCK, 0)], rim)
			var face := poly([Vector2(-6, -10), Vector2(18, -6), Vector2(34, 8), Vector2(14, 14), Vector2(-4, 6)], s + 1, 0.5)
			ci.draw_colored_polygon(face, ROCK.lightened(0.2))
			outline(ci, face, 1.6)
			ci.draw_colored_polygon(poly([Vector2(34, 8), Vector2(36, 30), Vector2(26, 38), Vector2(16, 30), Vector2(14, 14)], s + 2, 0.5), ROCK.darkened(0.14))
			pl(ci, [Vector2(14, 14), Vector2(16, 30), Vector2(26, 38)], 1.4, Color(INK, 0.35), s)
			_st_crack(ci, [Vector2(-24, 4), Vector2(-18, 16), Vector2(-22, 28)], 1.2, s + 3)
			for k in 5:
				ci.draw_circle(Vector2(-26.0 + float(k) * 9.0, 22.0 + float(k % 3) * 4.0), 1.3, Color(INK, 0.28))

		13:
			## 方石：一块凿方的灰石块，砌墙基用
			if rim:
				_st_rim(ci, [_st_block_part(Vector2(-4, 22), 26, 16, Vector2(10, -12), ROCK)])
			_st_block(ci, Vector2(-4, 22), 26, 16, Vector2(10, -12), s, ROCK, 4)

		14:
			## 一垛方石：两块方石并排，上面再压一块
			var v := Vector2(6, -8)
			var cfg := [[Vector2(0, 10), 15.0, 9.0], [Vector2(-14, 29), 15.0, 9.0], [Vector2(16, 29), 15.0, 9.0]]
			if rim:
				var ps := []
				for q in cfg:
					ps.append(_st_block_part(q[0], q[1], q[2], v, ROCK))
				_st_rim(ci, ps)
			for i in 3:
				var q: Array = cfg[i]
				_st_block(ci, q[0], q[1], q[2], v, s + i * 3, ROCK if i % 2 == 0 else ROCK.lightened(0.06), 2)

		15:
			## 石柱：一根凿出来的长条石柱，立着
			var c := Vector2(-4, 4)
			if rim:
				_st_rim(ci, [_st_block_part(c, 13, 34, Vector2(9, -7), ROCK)])
			_st_block(ci, c, 13, 34, Vector2(9, -7), s, ROCK, 0)
			_st_strata(ci, -15, 7, [-14.0, 10.0, 26.0], s)
			for k in 4:
				ln(ci, Vector2(-12, -20.0 + float(k) * 14.0), Vector2(-8, -16.0 + float(k) * 14.0), 1.3, Color(INK, 0.35), s + k)

		_:
			## 盖顶巨石：又大又厚、边缘不规则的灰色平顶巨石板，盖石棚顶用
			_capstone(ci, s, rim)

## 石锛头初稿（灰绿色、侧视面包形），留着备用
static func _adze_v1(ci: CanvasItem, s: int, rim: bool) -> void:
	## 石锛头：一块厚实的长方石，一面平、一面拱起，前头磨出一道横刃，刨木头、挖独木舟用
	var col := Color("7f8a7a")
	var prof := [Vector2(-30, 36), Vector2(28, 36), Vector2(33, 33), Vector2(29, 22), Vector2(16, 12), Vector2(-6, 9), Vector2(-24, 12), Vector2(-32, 22)]
	var top := []
	var tv := Vector2(7, -9)
	for k in range(3, 8):
		top.append(prof[k])
	var topf := top.duplicate()
	for k in range(top.size() - 1, -1, -1):
		topf.append((top[k] as Vector2) + tv)
	sil(ci, [pg(topf, s + 1, col.lightened(0.18), 1), pg(prof, s, col, 1)], rim)
	var bev := poly([Vector2(22, 36), Vector2(28, 36), Vector2(33, 33), Vector2(29, 22), Vector2(22, 19)], s + 2, 0.4)
	ci.draw_colored_polygon(bev, col.lightened(0.3))
	outline(ci, bev, 1.4)
	hl(ci, Vector2(-10, 22), 10, 2, 0.0, 0.45)
	for k in 4:
		ci.draw_circle(Vector2(-22.0 + float(k) * 10.0, 28.0 + float(k % 2) * 2.0), 1.1, Color(INK, 0.3))


## 石料第五稿（有黑曜石四级、磨石、刻纹巨石），留着备用
static func _main_art_v5(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			## 石片：一片薄而锋利的燧石片，有贝壳状的打击波纹
			var pts := [Vector2(-22, 34), Vector2(-24, 14), Vector2(-10, -10), Vector2(8, -20), Vector2(22, -4), Vector2(18, 20), Vector2(0, 36)]
			sil(ci, [pg(pts, s, FLINT)], rim)
			ci.draw_colored_polygon(poly([Vector2(8, -20), Vector2(22, -4), Vector2(18, 20), Vector2(10, 8)], s + 1), FLINT.lightened(0.2))
			for k in 3:
				ci.draw_arc(Vector2(-14, 34), 14.0 + float(k) * 9.0, -1.45, -0.25, 10, Color(INK, 0.35), 1.4, true)
			ci.draw_circle(Vector2(-14, 33), 3.0, Color(FLINT.darkened(0.25)))

		2:
			## 尖锐石片：一片又窄又尖的燧石片，两边修出细齿，做箭尖用
			var pts := rot_pts([Vector2(-13, 34), Vector2(-9, 12), Vector2(0, -22), Vector2(9, 12), Vector2(13, 34), Vector2(0, 38)], 0.22, Vector2(0, 8))
			sil(ci, [pg(pts, s, STONE_D.lightened(0.12), 0)], rim)
			_scars(ci, pts, rot_pts([Vector2(0, 16)], 0.22, Vector2(0, 8))[0], STONE_D.lightened(0.12), s)
			pl(ci, rot_pts([Vector2(0, -16), Vector2(1, 10), Vector2(0, 34)], 0.22, Vector2(0, 8)), 1.4, Color(1, 1, 1, 0.35), s)
			ci.draw_circle(rot_pts([Vector2(0, 33)], 0.22, Vector2(0, 8))[0], 2.4, STONE_D.darkened(0.1))

		3:
			## 矛头：两面都打薄的尖叶形矛头，边上一圈细削疤
			var base := []
			for k in 20:
				var a := TAU * float(k) / 20.0
				var y := sin(a)
				var w := 15.0 * (1.0 - 0.6 * maxf(-y, 0.0)) * (1.0 - 0.25 * maxf(y, 0.0))
				base.append(Vector2(cos(a) * w, y * 34.0 + 4.0))
			var pts := rot_pts(base, 0.5, Vector2(0, 2))
			sil(ci, [pg(pts, s, Color("a9a49b"), 0)], rim)
			var coarse := []
			for k in range(0, pts.size(), 2):
				coarse.append(pts[k])
			_scars(ci, coarse, Vector2(0, 6).rotated(0.5) + Vector2(0, 2), Color("a9a49b"), s)
			pl(ci, rot_pts([Vector2(0, -26), Vector2(1, 4), Vector2(0, 30)], 0.5, Vector2(0, 2)), 1.5, Color(INK, 0.45), s)

		4:
			## 长石刃：从石核上剥下来的一条长刃，微微弯，两边刃口平行，背上两道棱，根部有打击点
			var spine := []
			for k in 13:
				var t := float(k) / 12.0
				spine.append(Vector2(lerpf(-38.0, 38.0, t), lerpf(28.0, -10.0, t) - sin(PI * t) * 9.0))
			var up := []
			var dn := []
			var rid_a := []
			var rid_b := []
			for k in 13:
				var t := float(k) / 12.0
				var p: Vector2 = spine[k]
				var d: Vector2 = ((spine[mini(k + 1, 12)] as Vector2) - (spine[maxi(k - 1, 0)] as Vector2)).normalized()
				var n := Vector2(-d.y, d.x)
				var w := 11.0 * (1.0 - 0.85 * pow(t, 3.0)) * minf(1.0, 0.55 + t * 6.0) + 0.8
				up.append(p - n * w)
				dn.append(p + n * w)
				rid_a.append(p - n * w * 0.3)
				rid_b.append(p + n * w * 0.35)
			dn.reverse()
			var pts := up + dn
			sil(ci, [pg(pts, s, FLINT, 2)], rim)
			var midf := rid_a.duplicate()
			var rb := rid_b.duplicate()
			rb.reverse()
			safe_poly(ci, poly(midf + rb, s + 1, 0.4), FLINT.lightened(0.16))
			var edge := []
			for k in range(1, 12):
				edge.append((up[k] as Vector2).lerp(rid_a[k], 0.35))
			pl(ci, edge, 2.4, Color(1, 1, 1, 0.3), s)
			pl(ci, rid_a.slice(1, 12), 1.3, Color(INK, 0.45), s + 2)
			pl(ci, rid_b.slice(1, 12), 1.3, Color(INK, 0.45), s + 3)
			ci.draw_circle(spine[0] + Vector2(4, -1), 3.0, FLINT.darkened(0.2))
			for k in 2:
				ci.draw_arc(spine[0] + Vector2(4, -1), 7.0 + float(k) * 5.0, -1.1, 1.1, 8, Color(INK, 0.3), 1.2, true)

		5:
			## 斧头坯：石斧上那块楔形斧头，越往外越宽，刃口磨出一道亮弧
			var R := 0.35
			var o := Vector2(-21, 18)
			var head := rot_pts([Vector2(-10, -30), Vector2(-4, -36), Vector2(8, -33), Vector2(30, -45), Vector2(38, -37), Vector2(42, -24),
				Vector2(41, -10), Vector2(36, 1), Vector2(8, -12), Vector2(-4, -9), Vector2(-10, -14)], R, o)
			sil(ci, [pg(head, s, Color("8f8c88"), 0)], rim)
			var bevel := poly(rot_pts([Vector2(30, -45), Vector2(38, -37), Vector2(42, -24), Vector2(41, -10), Vector2(36, 1),
				Vector2(31, -5), Vector2(34, -16), Vector2(34, -28), Vector2(27, -38)], R, o), s + 2)
			ci.draw_colored_polygon(bevel, Color("c9c4bc"))
			outline(ci, bevel, 1.4)
			pl(ci, rot_pts([Vector2(14, -34), Vector2(18, -22), Vector2(14, -12)], R, o), 1.4, Color(INK, 0.4), s)
			for k in 3:
				ci.draw_circle(rot_pts([Vector2(-2.0 + float(k) * 6.0, -24.0 + float(k % 2) * 4.0)], R, o)[0], 1.3, Color(INK, 0.3))

		6:
			## 石板：一块厚实的砂岩石板，铺地、垒火塘用
			sil(ci, _st_slab_parts(Vector2(0, 26), 30, 13, 7, s), rim)
			_st_slab_det(ci, Vector2(0, 26), 30, 13, 7, s)

		7:
			## 两块石板：两块砂岩石板错开叠着，底下那块颜色深一点
			var a := _st_slab_parts(Vector2(5, 28), 30, 12, 6, s, SAND.darkened(0.08), 0.08)
			var b := _st_slab_parts(Vector2(-3, 18), 28, 12, 6, s + 4, SAND, -0.06)
			if rim:
				_st_rim(ci, a + b)
			sil(ci, a, false)
			_st_slab_det(ci, Vector2(5, 28), 30, 12, 6, s, 0.08)
			sil(ci, b, false)
			_st_slab_det(ci, Vector2(-3, 18), 28, 12, 6, s + 4, -0.06)

		8:
			## 一摞石板：四块石板摞成一摞
			var all := []
			var cfg := []
			for k in 4:
				var c := Vector2(float(k % 2) * 6.0 - 3.0, 32.0 - float(k) * 10.0)
				var col := SAND.darkened(0.12 - float(k) * 0.04)
				cfg.append([c, 32.0 - float(k) * 1.5, 12.0, 7.0, s + k * 4, 0.06 * float(k % 2 * 2 - 1)])
				all.append_array(_st_slab_parts(c, cfg[k][1], 12, 7, s + k * 4, col, cfg[k][5]))
			if rim:
				_st_rim(ci, all)
			for k in 4:
				var q: Array = cfg[k]
				sil(ci, all.slice(k * 2, k * 2 + 2), false)
				_st_slab_det(ci, q[0], q[1], q[2], q[3], q[4], q[5])

		9:
			## 方石：一块凿方的灰石块，砌墙基用
			if rim:
				_st_rim(ci, [_st_block_part(Vector2(-4, 22), 26, 16, Vector2(10, -12), ROCK)])
			_st_block(ci, Vector2(-4, 22), 26, 16, Vector2(10, -12), s, ROCK, 4)

		10:
			## 一垛方石：两块方石并排，上面再压一块
			var v := Vector2(6, -8)
			var cfg := [[Vector2(0, 10), 15.0, 9.0], [Vector2(-14, 29), 15.0, 9.0], [Vector2(16, 29), 15.0, 9.0]]
			if rim:
				var ps := []
				for q in cfg:
					ps.append(_st_block_part(q[0], q[1], q[2], v, ROCK))
				_st_rim(ci, ps)
			for i in 3:
				var q: Array = cfg[i]
				_st_block(ci, q[0], q[1], q[2], v, s + i * 3, ROCK if i % 2 == 0 else ROCK.lightened(0.06), 2)

		11:
			## 石柱：一根凿出来的长条石柱，立着
			var c := Vector2(-4, 4)
			if rim:
				_st_rim(ci, [_st_block_part(c, 13, 34, Vector2(9, -7), ROCK)])
			_st_block(ci, c, 13, 34, Vector2(9, -7), s, ROCK, 0)
			_st_strata(ci, -15, 7, [-14.0, 10.0, 26.0], s)
			for k in 4:
				ln(ci, Vector2(-12, -20.0 + float(k) * 14.0), Vector2(-8, -16.0 + float(k) * 14.0), 1.3, Color(INK, 0.35), s + k)

		12:
			## 磨石：一块大扁石，顶面磨出一道长凹槽，上面放着一块手握的小磨石
			var top := ell(Vector2(0, 20), Vector2(38, 14), s, 0.04, 22)
			var both := PackedVector2Array()
			for p in top:
				both.append(p)
				both.append(p + Vector2(0, 12))
			var body := Geometry2D.convex_hull(both)
			body.remove_at(body.size() - 1)
			var hand := ov(Vector2(8, 12), 13, 6.5, s + 2, STONE.lightened(0.08), -0.15, 0)
			sil(ci, [P(body, ROCK.darkened(0.15), 2), P(top, ROCK.lightened(0.05), 1), hand], rim)
			var groove := ell(Vector2(-2, 20), Vector2(27, 7.5), s + 1, 0.03, 20)
			ci.draw_colored_polygon(groove, ROCK.darkened(0.12))
			outline(ci, groove, 1.4)
			ci.draw_colored_polygon(ell(Vector2(-2, 22), Vector2(22, 4.5), s + 3, 0.03, 18), ROCK.lightened(0.12))
			sil(ci, [hand], false)
			hl(ci, Vector2(3, 9), 5, 2, -0.15, 0.5)

		13:
			## 刻纹巨石：一块粗糙的大立石，正面凿出两组同心环的刻痕，脚下长着青苔
			var pts := [Vector2(-24, 38), Vector2(-30, 10), Vector2(-26, -20), Vector2(-14, -40), Vector2(4, -46), Vector2(18, -36), Vector2(26, -10), Vector2(30, 16), Vector2(26, 38)]
			sil(ci, [pg(pts, s, ROCK, 0)], rim)
			ci.draw_colored_polygon(poly([Vector2(18, -36), Vector2(26, -10), Vector2(30, 16), Vector2(26, 38), Vector2(15, 38), Vector2(17, 12), Vector2(15, -14), Vector2(9, -38)], s + 1), ROCK.darkened(0.14))
			pl(ci, [Vector2(9, -38), Vector2(15, -14), Vector2(17, 12), Vector2(15, 38)], 1.4, Color(INK, 0.35), s)
			var cc := Vector2(-6, -14)
			for r in [4.0, 9.0, 14.0]:
				var arc := arcp(cc, Vector2(r, r * 1.05), PI * 0.62, PI * 2.38, 18)
				pl(ci, rot_pts(arc, 0.0, Vector2(0, 1.2)), 2.2, Color(1, 1, 1, 0.3), s)
				pl(ci, arc, 2.6, Color(INK, 0.55), s)
			var ch := [cc, cc + Vector2(-2, 12), cc + Vector2(0, 22)]
			pl(ci, rot_pts(ch, 0.0, Vector2(0, 1.2)), 2.2, Color(1, 1, 1, 0.3), s)
			pl(ci, ch, 2.6, Color(INK, 0.55), s)
			var c2 := Vector2(4, 18)
			for r in [3.5, 8.0]:
				var arc2 := arcp(c2, Vector2(r, r * 1.05), PI * 1.1, PI * 2.9, 14)
				pl(ci, rot_pts(arc2, 0.0, Vector2(0, 1.2)), 2.2, Color(1, 1, 1, 0.3), s + 2)
				pl(ci, arc2, 2.6, Color(INK, 0.55), s + 2)
			sil(ci, [ov(Vector2(-12, 34), 14, 6, s + 3, MOSS, 0.0, 1), ov(Vector2(14, 35), 9, 5, s + 4, MOSS, 0.0, 1)], false)
			_st_pebs(ci, [[Vector2(-30, 38), 6, 4, PEB], [Vector2(30, 38), 5, 3.5, Color("a49c91")]], s + 5, false)

		14:
			## 黑曜石碎片：一小片黑亮的火山玻璃，边缘锋利
			var pts := [Vector2(-14, 34), Vector2(-12, 22), Vector2(2, 8), Vector2(14, 12), Vector2(10, 26), Vector2(-2, 35)]
			sil(ci, [pg(pts, s, OBSID, 2)], rim)
			_st_obs_det(ci, pts, Vector2(0, 24), s)

		15:
			## 黑曜石块：拳头大的一块，满是贝壳状的断面
			var pts := _st_shard_pts(Vector2(0, 20), 24, 18, s)
			sil(ci, [pg(pts, s, OBSID, 2)], rim)
			_st_obs_det(ci, pts, Vector2(2, 18), s)

		16:
			## 黑曜石刃：一大片两面打薄的黑曜石刃，黑亮带紫光，比黑曜石块值钱
			var base := []
			for k in 22:
				var an := TAU * float(k) / 22.0
				var y := sin(an)
				var w := 27.0 * (1.0 - 0.5 * maxf(-y, 0.0)) * (1.0 - 0.2 * maxf(y, 0.0))
				base.append(Vector2(cos(an) * w, y * 50.0))
			var o := Vector2(0, -4)
			var pts := rot_pts(base, 0.72, o)
			sil(ci, [pg(pts, s, OBSID, 2)], rim)
			var coarse := []
			for k in range(0, pts.size(), 2):
				coarse.append(pts[k])
			_scars(ci, coarse, o + Vector2(0, 4).rotated(0.72), OBSID, s)
			var ridge := rot_pts([Vector2(0, -34), Vector2(1, 0), Vector2(0, 32)], 0.72, o)
			ci.draw_colored_polygon(poly(rot_pts([Vector2(0, -34), Vector2(12, -6), Vector2(10, 14), Vector2(1, 0)], 0.72, o), s + 1), Color(OBSID_HL, 0.45))
			pl(ci, ridge, 1.6, Color(OBSID_HL, 0.9), s)
			pl(ci, rot_pts([Vector2(-8, -18), Vector2(-9, 4)], 0.72, o), 2.4, Color(1, 1, 1, 0.65), s + 2)
			ci.draw_circle(rot_pts([Vector2(-8, -18)], 0.72, o)[0], 1.8, Color.WHITE)

		_:
			## 大黑曜石：一大块黑曜石原石，满身贝壳状断面，透着紫光，是石料里最珍贵的
			glow(ci, Vector2(0, 6), 60, OBSID_HL)
			var pts := _st_shard_pts(Vector2(0, 10), 36, 28, s, 8)
			sil(ci, [pg(pts, s, OBSID, 2)], rim)
			_st_obs_det(ci, pts, Vector2(3, 8), s)
			ci.draw_colored_polygon(star_pts(Vector2(-14, -6), 6, 1.8, 4, s), Color.WHITE)
			sparks(ci, [Vector2(-42, -26), Vector2(38, -30), Vector2(44, 26)])

## 石料第四稿（有碎石、五块方石、黑曜石只有一级），留着备用
static func _main_art_v4(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			## 碎石：两三块不起眼的小碎石，当投石索弹丸、垫灶都行
			sil(ci, [raw_rock(Vector2(-10, 30), 11, s, STONE, 5, 0.3), raw_rock(Vector2(11, 32), 9, s + 1, STONE.darkened(0.1), 5, 0.3),
				raw_rock(Vector2(0, 18), 10, s + 2, STONE.lightened(0.1), 5, 0.3)], rim)

		2:
			## 石片：一片薄而锋利的燧石片，有贝壳状的打击波纹
			var pts := [Vector2(-22, 34), Vector2(-24, 14), Vector2(-10, -10), Vector2(8, -20), Vector2(22, -4), Vector2(18, 20), Vector2(0, 36)]
			sil(ci, [pg(pts, s, FLINT)], rim)
			ci.draw_colored_polygon(poly([Vector2(8, -20), Vector2(22, -4), Vector2(18, 20), Vector2(10, 8)], s + 1), FLINT.lightened(0.2))
			for k in 3:
				ci.draw_arc(Vector2(-14, 34), 14.0 + float(k) * 9.0, -1.45, -0.25, 10, Color(INK, 0.35), 1.4, true)
			ci.draw_circle(Vector2(-14, 33), 3.0, Color(FLINT.darkened(0.25)))

		3:
			## 尖锐石片：一片又窄又尖的燧石片，两边修出细齿，做箭尖用
			var pts := rot_pts([Vector2(-13, 34), Vector2(-9, 12), Vector2(0, -22), Vector2(9, 12), Vector2(13, 34), Vector2(0, 38)], 0.22, Vector2(0, 8))
			sil(ci, [pg(pts, s, STONE_D.lightened(0.12), 0)], rim)
			_scars(ci, pts, rot_pts([Vector2(0, 16)], 0.22, Vector2(0, 8))[0], STONE_D.lightened(0.12), s)
			pl(ci, rot_pts([Vector2(0, -16), Vector2(1, 10), Vector2(0, 34)], 0.22, Vector2(0, 8)), 1.4, Color(1, 1, 1, 0.35), s)
			ci.draw_circle(rot_pts([Vector2(0, 33)], 0.22, Vector2(0, 8))[0], 2.4, STONE_D.darkened(0.1))

		4:
			## 矛头：两面都打薄的尖叶形矛头，边上一圈细削疤
			var base := []
			for k in 20:
				var a := TAU * float(k) / 20.0
				var y := sin(a)
				var w := 15.0 * (1.0 - 0.6 * maxf(-y, 0.0)) * (1.0 - 0.25 * maxf(y, 0.0))
				base.append(Vector2(cos(a) * w, y * 34.0 + 4.0))
			var pts := rot_pts(base, 0.5, Vector2(0, 2))
			sil(ci, [pg(pts, s, Color("a9a49b"), 0)], rim)
			var coarse := []
			for k in range(0, pts.size(), 2):
				coarse.append(pts[k])
			_scars(ci, coarse, Vector2(0, 6).rotated(0.5) + Vector2(0, 2), Color("a9a49b"), s)
			pl(ci, rot_pts([Vector2(0, -26), Vector2(1, 4), Vector2(0, 30)], 0.5, Vector2(0, 2)), 1.5, Color(INK, 0.45), s)

		5:
			## 长石刃：从石核上剥下来的一条长刃，两条棱把背面分成三面，刃口笔直
			var a := Vector2(-34, 30)
			var b := Vector2(34, -16)
			var d := (b - a).normalized()
			var n := Vector2(-d.y, d.x)
			var L := (b - a).length()
			var pts := [a - d * 3.0, a + n * 7.0, a + d * L * 0.72 + n * 8.5, b + n * 1.5, b - n * 1.0, a + d * L * 0.72 - n * 8.5, a - n * 7.0]
			sil(ci, [pg(pts, s, GREY, 1)], rim)
			var mid := poly([a + n * 2.8, a + d * L * 0.72 + n * 3.2, b - d * 3.0, a + d * L * 0.72 - n * 3.2, a - n * 2.8], s + 1, 0.5)
			ci.draw_colored_polygon(mid, GREY.lightened(0.18))
			outline(ci, mid, 1.3, Color(INK, 0.5))
			ci.draw_circle(a + d * 3.0, 2.6, GREY.darkened(0.2))
			for k in 3:
				var t := 0.2 + float(k) * 0.2
				ln(ci, a + d * L * t + n * 7.5, a + d * L * t + n * 5.0, 1.1, Color(INK, 0.3), s + k)
			hl(ci, a + d * L * 0.45, 12, 1.5, d.angle(), 0.6)

		6:
			## 斧头坯：石斧上那块楔形斧头，越往外越宽，刃口磨出一道亮弧
			var R := 0.35
			var o := Vector2(-21, 18)
			var head := rot_pts([Vector2(-10, -30), Vector2(-4, -36), Vector2(8, -33), Vector2(30, -45), Vector2(38, -37), Vector2(42, -24),
				Vector2(41, -10), Vector2(36, 1), Vector2(8, -12), Vector2(-4, -9), Vector2(-10, -14)], R, o)
			sil(ci, [pg(head, s, Color("8f8c88"), 0)], rim)
			var bevel := poly(rot_pts([Vector2(30, -45), Vector2(38, -37), Vector2(42, -24), Vector2(41, -10), Vector2(36, 1),
				Vector2(31, -5), Vector2(34, -16), Vector2(34, -28), Vector2(27, -38)], R, o), s + 2)
			ci.draw_colored_polygon(bevel, Color("c9c4bc"))
			outline(ci, bevel, 1.4)
			pl(ci, rot_pts([Vector2(14, -34), Vector2(18, -22), Vector2(14, -12)], R, o), 1.4, Color(INK, 0.4), s)
			for k in 3:
				ci.draw_circle(rot_pts([Vector2(-2.0 + float(k) * 6.0, -24.0 + float(k % 2) * 4.0)], R, o)[0], 1.3, Color(INK, 0.3))

		7:
			## 石板：一块厚实的砂岩石板，铺地、垒火塘用
			sil(ci, _st_slab_parts(Vector2(0, 26), 30, 13, 7, s), rim)
			_st_slab_det(ci, Vector2(0, 26), 30, 13, 7, s)

		8:
			## 两块石板：两块砂岩石板错开叠着，底下那块颜色深一点
			var a := _st_slab_parts(Vector2(5, 28), 30, 12, 6, s, SAND.darkened(0.08), 0.08)
			var b := _st_slab_parts(Vector2(-3, 18), 28, 12, 6, s + 4, SAND, -0.06)
			if rim:
				_st_rim(ci, a + b)
			sil(ci, a, false)
			_st_slab_det(ci, Vector2(5, 28), 30, 12, 6, s, 0.08)
			sil(ci, b, false)
			_st_slab_det(ci, Vector2(-3, 18), 28, 12, 6, s + 4, -0.06)

		9:
			## 一摞石板：四块石板摞成一摞
			var all := []
			var cfg := []
			for k in 4:
				var c := Vector2(float(k % 2) * 6.0 - 3.0, 32.0 - float(k) * 10.0)
				var col := SAND.darkened(0.12 - float(k) * 0.04)
				cfg.append([c, 32.0 - float(k) * 1.5, 12.0, 7.0, s + k * 4, 0.06 * float(k % 2 * 2 - 1)])
				all.append_array(_st_slab_parts(c, cfg[k][1], 12, 7, s + k * 4, col, cfg[k][5]))
			if rim:
				_st_rim(ci, all)
			for k in 4:
				var q: Array = cfg[k]
				sil(ci, all.slice(k * 2, k * 2 + 2), false)
				_st_slab_det(ci, q[0], q[1], q[2], q[3], q[4], q[5])

		10:
			## 方石：一块凿方的灰石块，砌墙基用
			if rim:
				_st_rim(ci, [_st_block_part(Vector2(-4, 22), 26, 16, Vector2(10, -12), ROCK)])
			_st_block(ci, Vector2(-4, 22), 26, 16, Vector2(10, -12), s, ROCK, 4)

		11:
			## 一垛方石：五块方石垒成两层
			var cfg := [[Vector2(-24, 30), 14.0, 8.0], [Vector2(4, 30), 14.0, 8.0], [Vector2(32, 30), 13.0, 8.0],
				[Vector2(-12, 12), 14.0, 8.0], [Vector2(16, 12), 14.0, 8.0], [Vector2(2, -6), 13.0, 8.0]]
			var v := Vector2(6, -8)
			if rim:
				var ps := []
				for q in cfg:
					ps.append(_st_block_part(q[0], q[1], q[2], v, ROCK))
				_st_rim(ci, ps)
			for i in [5, 3, 4, 0, 1, 2]:
				var q: Array = cfg[i]
				_st_block(ci, q[0] - Vector2(4, 0), q[1], q[2], v, s + i * 3, ROCK if i % 2 == 0 else ROCK.lightened(0.06), 2)

		12:
			## 石柱：一根凿出来的长条石柱，立着
			var c := Vector2(-4, 4)
			if rim:
				_st_rim(ci, [_st_block_part(c, 13, 34, Vector2(9, -7), ROCK)])
			_st_block(ci, c, 13, 34, Vector2(9, -7), s, ROCK, 0)
			_st_strata(ci, -15, 7, [-14.0, 10.0, 26.0], s)
			for k in 4:
				ln(ci, Vector2(-12, -20.0 + float(k) * 14.0), Vector2(-8, -16.0 + float(k) * 14.0), 1.3, Color(INK, 0.35), s + k)

		13:
			## 磨石：一块大扁石，顶面磨出一道长凹槽，上面放着一块手握的小磨石
			var top := ell(Vector2(0, 20), Vector2(38, 14), s, 0.04, 22)
			var both := PackedVector2Array()
			for p in top:
				both.append(p)
				both.append(p + Vector2(0, 12))
			var body := Geometry2D.convex_hull(both)
			body.remove_at(body.size() - 1)
			var hand := ov(Vector2(8, 12), 13, 6.5, s + 2, STONE.lightened(0.08), -0.15, 0)
			sil(ci, [P(body, ROCK.darkened(0.15), 2), P(top, ROCK.lightened(0.05), 1), hand], rim)
			var groove := ell(Vector2(-2, 20), Vector2(27, 7.5), s + 1, 0.03, 20)
			ci.draw_colored_polygon(groove, ROCK.darkened(0.12))
			outline(ci, groove, 1.4)
			ci.draw_colored_polygon(ell(Vector2(-2, 22), Vector2(22, 4.5), s + 3, 0.03, 18), ROCK.lightened(0.12))
			sil(ci, [hand], false)
			hl(ci, Vector2(3, 9), 5, 2, -0.15, 0.5)

		14:
			## 刻纹巨石：一块粗糙的大立石，正面凿出两组同心环的刻痕，脚下长着青苔
			var pts := [Vector2(-24, 38), Vector2(-30, 10), Vector2(-26, -20), Vector2(-14, -40), Vector2(4, -46), Vector2(18, -36), Vector2(26, -10), Vector2(30, 16), Vector2(26, 38)]
			sil(ci, [pg(pts, s, ROCK, 0)], rim)
			ci.draw_colored_polygon(poly([Vector2(18, -36), Vector2(26, -10), Vector2(30, 16), Vector2(26, 38), Vector2(15, 38), Vector2(17, 12), Vector2(15, -14), Vector2(9, -38)], s + 1), ROCK.darkened(0.14))
			pl(ci, [Vector2(9, -38), Vector2(15, -14), Vector2(17, 12), Vector2(15, 38)], 1.4, Color(INK, 0.35), s)
			var cc := Vector2(-6, -14)
			for r in [4.0, 9.0, 14.0]:
				var arc := arcp(cc, Vector2(r, r * 1.05), PI * 0.62, PI * 2.38, 18)
				pl(ci, rot_pts(arc, 0.0, Vector2(0, 1.2)), 2.2, Color(1, 1, 1, 0.3), s)
				pl(ci, arc, 2.6, Color(INK, 0.55), s)
			var ch := [cc, cc + Vector2(-2, 12), cc + Vector2(0, 22)]
			pl(ci, rot_pts(ch, 0.0, Vector2(0, 1.2)), 2.2, Color(1, 1, 1, 0.3), s)
			pl(ci, ch, 2.6, Color(INK, 0.55), s)
			var c2 := Vector2(4, 18)
			for r in [3.5, 8.0]:
				var arc2 := arcp(c2, Vector2(r, r * 1.05), PI * 1.1, PI * 2.9, 14)
				pl(ci, rot_pts(arc2, 0.0, Vector2(0, 1.2)), 2.2, Color(1, 1, 1, 0.3), s + 2)
				pl(ci, arc2, 2.6, Color(INK, 0.55), s + 2)
			sil(ci, [ov(Vector2(-12, 34), 14, 6, s + 3, MOSS, 0.0, 1), ov(Vector2(14, 35), 9, 5, s + 4, MOSS, 0.0, 1)], false)
			_st_pebs(ci, [[Vector2(-30, 38), 6, 4, PEB], [Vector2(30, 38), 5, 3.5, Color("a49c91")]], s + 5, false)

		_:
			## 黑曜石刃：一大片两面打薄的黑曜石刃，黑亮带紫光，是石料里最珍贵的
			glow(ci, Vector2(0, -4), 60, OBSID_HL)
			var base := []
			for k in 22:
				var an := TAU * float(k) / 22.0
				var y := sin(an)
				var w := 27.0 * (1.0 - 0.5 * maxf(-y, 0.0)) * (1.0 - 0.2 * maxf(y, 0.0))
				base.append(Vector2(cos(an) * w, y * 50.0))
			var o := Vector2(0, -4)
			var pts := rot_pts(base, 0.72, o)
			sil(ci, [pg(pts, s, OBSID, 2)], rim)
			var coarse := []
			for k in range(0, pts.size(), 2):
				coarse.append(pts[k])
			_scars(ci, coarse, o + Vector2(0, 4).rotated(0.72), OBSID, s)
			var ridge := rot_pts([Vector2(0, -34), Vector2(1, 0), Vector2(0, 32)], 0.72, o)
			ci.draw_colored_polygon(poly(rot_pts([Vector2(0, -34), Vector2(12, -6), Vector2(10, 14), Vector2(1, 0)], 0.72, o), s + 1), Color(OBSID_HL, 0.45))
			pl(ci, ridge, 1.6, Color(OBSID_HL, 0.9), s)
			pl(ci, rot_pts([Vector2(-8, -18), Vector2(-9, 4)], 0.72, o), 2.4, Color(1, 1, 1, 0.65), s + 2)
			ci.draw_circle(rot_pts([Vector2(-8, -18)], 0.72, o)[0], 1.8, Color.WHITE)
			sparks(ci, [Vector2(-38, -30), Vector2(36, -30), Vector2(40, 26)])

## 石料第三稿（含燧石石核、锤头石，磨石在石柱前），留着备用
static func _main_art_v3(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			## 碎石：两三块不起眼的小碎石，当投石索弹丸、垫灶都行
			sil(ci, [raw_rock(Vector2(-10, 30), 11, s, STONE, 5, 0.3), raw_rock(Vector2(11, 32), 9, s + 1, STONE.darkened(0.1), 5, 0.3),
				raw_rock(Vector2(0, 18), 10, s + 2, STONE.lightened(0.1), 5, 0.3)], rim)
		2:
			## 石片：一片薄而锋利的燧石片，有贝壳状的打击波纹
			var pts := [Vector2(-22, 34), Vector2(-24, 14), Vector2(-10, -10), Vector2(8, -20), Vector2(22, -4), Vector2(18, 20), Vector2(0, 36)]
			sil(ci, [pg(pts, s, FLINT)], rim)
			ci.draw_colored_polygon(poly([Vector2(8, -20), Vector2(22, -4), Vector2(18, 20), Vector2(10, 8)], s + 1), FLINT.lightened(0.2))
			for k in 3:
				ci.draw_arc(Vector2(-14, 34), 14.0 + float(k) * 9.0, -1.45, -0.25, 10, Color(INK, 0.35), 1.4, true)
			ci.draw_circle(Vector2(-14, 33), 3.0, Color(FLINT.darkened(0.25)))
		3:
			## 燧石石核：斜立着的一块锥形燧石，顶上一个平的打击台面，四周一圈剥石刃留下的长条疤，脚下落着两片石片
			var R := -0.28
			var pv := Vector2(0, 14)
			var tc := Vector2(0, -12)
			var rx := 18.0
			var ry := 6.0
			var outl := []
			for k in 9:
				var an := PI + PI * float(k) / 8.0
				outl.append(tc + Vector2(cos(an) * rx, sin(an) * ry))
			outl.append_array([Vector2(rx * 1.08, 4), Vector2(rx * 0.85, 22), Vector2(rx * 0.4, 34), Vector2(0, 38), Vector2(-rx * 0.4, 34), Vector2(-rx * 0.85, 22), Vector2(-rx * 1.08, 4)])
			sil(ci, [pg([Vector2(-30, 35), Vector2(-21, 31), Vector2(-15, 36), Vector2(-25, 39)], s + 20, GREY, 1),
				pg([Vector2(16, 34), Vector2(26, 31), Vector2(30, 36), Vector2(20, 39)], s + 21, GREY, 1), pg(_st_rot(outl, R, pv), s, FLINT, 2)], rim)
			var n := 5
			for i in n:
				var a0 := PI * float(i) / float(n)
				var a1 := PI * float(i + 1) / float(n)
				var p0 := tc + Vector2(cos(a0) * rx, sin(a0) * ry)
				var p1 := tc + Vector2(cos(a1) * rx, sin(a1) * ry)
				var q0 := Vector2(p0.x * 0.2, 35.0 - absf(p0.x) * 0.1)
				var q1 := Vector2(p1.x * 0.2, 35.0 - absf(p1.x) * 0.1)
				var m0 := p0.lerp(q0, 0.45) + Vector2(p0.x * 0.16, 0)
				var m1 := p1.lerp(q1, 0.45) + Vector2(p1.x * 0.16, 0)
				safe_poly(ci, poly(_st_rot([p0, m0, q0, q1, m1, p1], R, pv), s + i, 0.5), FLINT.lightened(0.14) if i % 2 == 0 else FLINT.darkened(0.06))
				pl(ci, _st_rot([p0, m0, q0], R, pv), 1.3, Color(INK, 0.45), s + i)
				for k in 2:
					var c: Vector2 = _st_rot([p0.lerp(p1, 0.5) + Vector2(0, 4.0 + float(k) * 5.0)], R, pv)[0]
					ci.draw_arc(c, 4.0 + float(k), 0.5 + R, PI - 0.5 + R, 6, Color(INK, 0.28), 1.1, true)
			var plat := poly(_st_rot(Array(ell(tc, Vector2(rx, ry), s + 7, 0.03, 20)), R, pv), s + 7, 0.3)
			ci.draw_colored_polygon(plat, FLINT.lightened(0.28))
			outline(ci, plat, 1.8)
			hl(ci, _st_rot([tc + Vector2(-6, -1)], R, pv)[0], 6, 1.8, R, 0.5)
		4:
			## 长石刃：从石核上剥下来的一条长刃，两条棱把背面分成三面，刃口笔直
			var a := Vector2(-34, 30)
			var b := Vector2(34, -16)
			var d := (b - a).normalized()
			var n := Vector2(-d.y, d.x)
			var L := (b - a).length()
			var pts := [a - d * 3.0, a + n * 7.0, a + d * L * 0.72 + n * 8.5, b + n * 1.5, b - n * 1.0, a + d * L * 0.72 - n * 8.5, a - n * 7.0]
			sil(ci, [pg(pts, s, GREY, 1)], rim)
			var mid := poly([a + n * 2.8, a + d * L * 0.72 + n * 3.2, b - d * 3.0, a + d * L * 0.72 - n * 3.2, a - n * 2.8], s + 1, 0.5)
			ci.draw_colored_polygon(mid, GREY.lightened(0.18))
			outline(ci, mid, 1.3, Color(INK, 0.5))
			ci.draw_circle(a + d * 3.0, 2.6, GREY.darkened(0.2))
			for k in 3:
				var t := 0.2 + float(k) * 0.2
				ln(ci, a + d * L * t + n * 7.5, a + d * L * t + n * 5.0, 1.1, Color(INK, 0.3), s + k)
			hl(ci, a + d * L * 0.45, 12, 1.5, d.angle(), 0.6)
		5:
			## 矛头：两面都打薄的尖叶形矛头，边上一圈细削疤
			var base := []
			for k in 20:
				var a := TAU * float(k) / 20.0
				var y := sin(a)
				var w := 15.0 * (1.0 - 0.6 * maxf(-y, 0.0)) * (1.0 - 0.25 * maxf(y, 0.0))
				base.append(Vector2(cos(a) * w, y * 34.0 + 4.0))
			var pts := rot_pts(base, 0.5, Vector2(0, 2))
			sil(ci, [pg(pts, s, Color("a9a49b"), 0)], rim)
			var coarse := []
			for k in range(0, pts.size(), 2):
				coarse.append(pts[k])
			_scars(ci, coarse, Vector2(0, 6).rotated(0.5) + Vector2(0, 2), Color("a9a49b"), s)
			pl(ci, rot_pts([Vector2(0, -26), Vector2(1, 4), Vector2(0, 30)], 0.5, Vector2(0, 2)), 1.5, Color(INK, 0.45), s)
		6:
			## 斧头坯：石斧上那块楔形斧头，越往外越宽，刃口磨出一道亮弧
			var R := 0.35
			var o := Vector2(-21, 18)
			var head := rot_pts([Vector2(-10, -30), Vector2(-4, -36), Vector2(8, -33), Vector2(30, -45), Vector2(38, -37), Vector2(42, -24),
				Vector2(41, -10), Vector2(36, 1), Vector2(8, -12), Vector2(-4, -9), Vector2(-10, -14)], R, o)
			sil(ci, [pg(head, s, Color("8f8c88"), 0)], rim)
			var bevel := poly(rot_pts([Vector2(30, -45), Vector2(38, -37), Vector2(42, -24), Vector2(41, -10), Vector2(36, 1),
				Vector2(31, -5), Vector2(34, -16), Vector2(34, -28), Vector2(27, -38)], R, o), s + 2)
			ci.draw_colored_polygon(bevel, Color("c9c4bc"))
			outline(ci, bevel, 1.4)
			pl(ci, rot_pts([Vector2(14, -34), Vector2(18, -22), Vector2(14, -12)], R, o), 1.4, Color(INK, 0.4), s)
			for k in 3:
				ci.draw_circle(rot_pts([Vector2(-2.0 + float(k) * 6.0, -24.0 + float(k % 2) * 4.0)], R, o)[0], 1.3, Color(INK, 0.3))
		7:
			## 锤头石：一块凿得方方正正的锤头，腰上琢出一圈绑绳的浅槽
			var c := Vector2(-3, 24)
			if rim:
				_st_rim(ci, [_st_block_part(c, 22, 12, Vector2(7, -10), STONE)])
			_st_block(ci, c, 22, 12, Vector2(7, -10), s, STONE, 0)
			var g0 := Vector2(c.x - 2.0, c.y - 12.0)
			ci.draw_colored_polygon(PackedVector2Array([g0 + Vector2(-2.5, 0), g0 + Vector2(2.5, 0), g0 + Vector2(2.5, 24), g0 + Vector2(-2.5, 24)]), Color(STONE_D, 0.7))
			ci.draw_colored_polygon(PackedVector2Array([g0 + Vector2(-2.5, 0), g0 + Vector2(2.5, 0), g0 + Vector2(9.5, -10), g0 + Vector2(4.5, -10)]), Color(STONE_D, 0.6))
			for k in 3:
				ci.draw_circle(c + Vector2(-14.0 + float(k) * 6.0, -2.0 + float(k % 2) * 6.0), 1.3, Color(INK, 0.3))
		8:
			## 石板：一块厚实的砂岩石板，铺地、垒火塘用
			sil(ci, _st_slab_parts(Vector2(0, 26), 30, 13, 7, s), rim)
			_st_slab_det(ci, Vector2(0, 26), 30, 13, 7, s)
		9:
			## 一摞石板：四块石板摞成一摞
			var all := []
			var cfg := []
			for k in 4:
				var c := Vector2(float(k % 2) * 6.0 - 3.0, 32.0 - float(k) * 10.0)
				var col := SAND.darkened(0.12 - float(k) * 0.04)
				cfg.append([c, 32.0 - float(k) * 1.5, 12.0, 7.0, s + k * 4, 0.06 * float(k % 2 * 2 - 1)])
				all.append_array(_st_slab_parts(c, cfg[k][1], 12, 7, s + k * 4, col, cfg[k][5]))
			if rim:
				_st_rim(ci, all)
			for k in 4:
				var q: Array = cfg[k]
				sil(ci, all.slice(k * 2, k * 2 + 2), false)
				_st_slab_det(ci, q[0], q[1], q[2], q[3], q[4], q[5])
		10:
			## 方石：一块凿方的灰石块，砌墙基用
			if rim:
				_st_rim(ci, [_st_block_part(Vector2(-4, 22), 26, 16, Vector2(10, -12), ROCK)])
			_st_block(ci, Vector2(-4, 22), 26, 16, Vector2(10, -12), s, ROCK, 4)
		11:
			## 磨石：一块大扁石，顶面磨出一道长凹槽，上面放着一块手握的小磨石
			var top := ell(Vector2(0, 20), Vector2(38, 14), s, 0.04, 22)
			var both := PackedVector2Array()
			for p in top:
				both.append(p)
				both.append(p + Vector2(0, 12))
			var body := Geometry2D.convex_hull(both)
			body.remove_at(body.size() - 1)
			var hand := ov(Vector2(8, 12), 13, 6.5, s + 2, STONE.lightened(0.08), -0.15, 0)
			sil(ci, [P(body, ROCK.darkened(0.15), 2), P(top, ROCK.lightened(0.05), 1), hand], rim)
			var groove := ell(Vector2(-2, 20), Vector2(27, 7.5), s + 1, 0.03, 20)
			ci.draw_colored_polygon(groove, ROCK.darkened(0.12))
			outline(ci, groove, 1.4)
			ci.draw_colored_polygon(ell(Vector2(-2, 22), Vector2(22, 4.5), s + 3, 0.03, 18), ROCK.lightened(0.12))
			sil(ci, [hand], false)
			hl(ci, Vector2(3, 9), 5, 2, -0.15, 0.5)
		12:
			## 一垛方石：五块方石垒成两层
			var cfg := [[Vector2(-24, 30), 14.0, 8.0], [Vector2(4, 30), 14.0, 8.0], [Vector2(32, 30), 13.0, 8.0],
				[Vector2(-12, 12), 14.0, 8.0], [Vector2(16, 12), 14.0, 8.0], [Vector2(2, -6), 13.0, 8.0]]
			var v := Vector2(6, -8)
			if rim:
				var ps := []
				for q in cfg:
					ps.append(_st_block_part(q[0], q[1], q[2], v, ROCK))
				_st_rim(ci, ps)
			for i in [5, 3, 4, 0, 1, 2]:
				var q: Array = cfg[i]
				_st_block(ci, q[0] - Vector2(4, 0), q[1], q[2], v, s + i * 3, ROCK if i % 2 == 0 else ROCK.lightened(0.06), 2)
		13:
			## 石柱：一根凿出来的长条石柱，立着
			var c := Vector2(-4, 4)
			if rim:
				_st_rim(ci, [_st_block_part(c, 13, 34, Vector2(9, -7), ROCK)])
			_st_block(ci, c, 13, 34, Vector2(9, -7), s, ROCK, 0)
			_st_strata(ci, -15, 7, [-14.0, 10.0, 26.0], s)
			for k in 4:
				ln(ci, Vector2(-12, -20.0 + float(k) * 14.0), Vector2(-8, -16.0 + float(k) * 14.0), 1.3, Color(INK, 0.35), s + k)
		14:
			## 刻纹巨石：一块粗糙的大立石，正面凿出两组同心环的刻痕，脚下长着青苔
			var pts := [Vector2(-24, 38), Vector2(-30, 10), Vector2(-26, -20), Vector2(-14, -40), Vector2(4, -46), Vector2(18, -36), Vector2(26, -10), Vector2(30, 16), Vector2(26, 38)]
			sil(ci, [pg(pts, s, ROCK, 0)], rim)
			ci.draw_colored_polygon(poly([Vector2(18, -36), Vector2(26, -10), Vector2(30, 16), Vector2(26, 38), Vector2(15, 38), Vector2(17, 12), Vector2(15, -14), Vector2(9, -38)], s + 1), ROCK.darkened(0.14))
			pl(ci, [Vector2(9, -38), Vector2(15, -14), Vector2(17, 12), Vector2(15, 38)], 1.4, Color(INK, 0.35), s)
			var cc := Vector2(-6, -14)
			for r in [4.0, 9.0, 14.0]:
				var arc := arcp(cc, Vector2(r, r * 1.05), PI * 0.62, PI * 2.38, 18)
				pl(ci, rot_pts(arc, 0.0, Vector2(0, 1.2)), 2.2, Color(1, 1, 1, 0.3), s)
				pl(ci, arc, 2.6, Color(INK, 0.55), s)
			var ch := [cc, cc + Vector2(-2, 12), cc + Vector2(0, 22)]
			pl(ci, rot_pts(ch, 0.0, Vector2(0, 1.2)), 2.2, Color(1, 1, 1, 0.3), s)
			pl(ci, ch, 2.6, Color(INK, 0.55), s)
			var c2 := Vector2(4, 18)
			for r in [3.5, 8.0]:
				var arc2 := arcp(c2, Vector2(r, r * 1.05), PI * 1.1, PI * 2.9, 14)
				pl(ci, rot_pts(arc2, 0.0, Vector2(0, 1.2)), 2.2, Color(1, 1, 1, 0.3), s + 2)
				pl(ci, arc2, 2.6, Color(INK, 0.55), s + 2)
			sil(ci, [ov(Vector2(-12, 34), 14, 6, s + 3, MOSS, 0.0, 1), ov(Vector2(14, 35), 9, 5, s + 4, MOSS, 0.0, 1)], false)
			_st_pebs(ci, [[Vector2(-30, 38), 6, 4, PEB], [Vector2(30, 38), 5, 3.5, Color("a49c91")]], s + 5, false)
		_:
			## 黑曜石刃：一大片两面打薄的黑曜石刃，黑亮带紫光，是石料里最珍贵的
			glow(ci, Vector2(0, -4), 60, OBSID_HL)
			var base := []
			for k in 22:
				var an := TAU * float(k) / 22.0
				var y := sin(an)
				var w := 27.0 * (1.0 - 0.5 * maxf(-y, 0.0)) * (1.0 - 0.2 * maxf(y, 0.0))
				base.append(Vector2(cos(an) * w, y * 50.0))
			var o := Vector2(0, -4)
			var pts := rot_pts(base, 0.72, o)
			sil(ci, [pg(pts, s, OBSID, 2)], rim)
			var coarse := []
			for k in range(0, pts.size(), 2):
				coarse.append(pts[k])
			_scars(ci, coarse, o + Vector2(0, 4).rotated(0.72), OBSID, s)
			var ridge := rot_pts([Vector2(0, -34), Vector2(1, 0), Vector2(0, 32)], 0.72, o)
			ci.draw_colored_polygon(poly(rot_pts([Vector2(0, -34), Vector2(12, -6), Vector2(10, 14), Vector2(1, 0)], 0.72, o), s + 1), Color(OBSID_HL, 0.45))
			pl(ci, ridge, 1.6, Color(OBSID_HL, 0.9), s)
			pl(ci, rot_pts([Vector2(-8, -18), Vector2(-9, 4)], 0.72, o), 2.4, Color(1, 1, 1, 0.65), s + 2)
			ci.draw_circle(rot_pts([Vector2(-8, -18)], 0.72, o)[0], 1.8, Color.WHITE)
			sparks(ci, [Vector2(-38, -30), Vector2(36, -30), Vector2(40, 26)])

## 石料第二稿（含石镐头、黑曜石刃在第 9 级、彩绘巨石），留着备用
static func _main_art_v2(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			## 碎石：两三块不起眼的小碎石，当投石索弹丸、垫灶都行
			sil(ci, [raw_rock(Vector2(-10, 30), 11, s, STONE, 5, 0.3), raw_rock(Vector2(11, 32), 9, s + 1, STONE.darkened(0.1), 5, 0.3),
				raw_rock(Vector2(0, 18), 10, s + 2, STONE.lightened(0.1), 5, 0.3)], rim)
		2:
			## 石片：一片薄而锋利的燧石片，有贝壳状的打击波纹
			var pts := [Vector2(-22, 34), Vector2(-24, 14), Vector2(-10, -10), Vector2(8, -20), Vector2(22, -4), Vector2(18, 20), Vector2(0, 36)]
			sil(ci, [pg(pts, s, FLINT)], rim)
			ci.draw_colored_polygon(poly([Vector2(8, -20), Vector2(22, -4), Vector2(18, 20), Vector2(10, 8)], s + 1), FLINT.lightened(0.2))
			for k in 3:
				ci.draw_arc(Vector2(-14, 34), 14.0 + float(k) * 9.0, -1.45, -0.25, 10, Color(INK, 0.35), 1.4, true)
			ci.draw_circle(Vector2(-14, 33), 3.0, Color(FLINT.darkened(0.25)))
		3:
			## 燧石石核：一块被敲掉好几片的燧石核，顶上还留着白石皮，四周全是削疤
			var pts := [Vector2(-24, 36), Vector2(-29, 16), Vector2(-20, -2), Vector2(2, -8), Vector2(22, 0), Vector2(28, 20), Vector2(18, 37)]
			sil(ci, [pg(pts, s, FLINT, 0)], rim)
			_scars(ci, pts, Vector2(0, 18), FLINT, s)
			var cap := poly([Vector2(-20, -2), Vector2(2, -8), Vector2(22, 0), Vector2(12, 6), Vector2(-4, 4), Vector2(-16, 8)], s + 3)
			ci.draw_colored_polygon(cap, CORTEX)
			outline(ci, cap, 1.6)
			for k in 3:
				ci.draw_circle(Vector2(-10.0 + float(k) * 10.0, 1.0 + float(k % 2) * 2.0), 1.2, Color("bdb29a"))
		4:
			## 长石刃：一条细长的燧石刃，背上两道棱
			var a := Vector2(-34, 32)
			var b := Vector2(34, -20)
			var d := (b - a).normalized()
			var n := Vector2(-d.y, d.x)
			var L := (b - a).length()
			var up := []
			var dn := []
			for k in 9:
				var t := float(k) / 8.0
				var w := 8.5 * sin(PI * minf(t * 1.15 + 0.08, 1.0)) + 1.5
				var bow := sin(PI * t) * 4.0
				up.append(a + d * L * t + n * (w + bow))
				dn.append(a + d * L * t - n * (w - bow))
			dn.reverse()
			sil(ci, [pg(up + dn, s, GREY, 0)], rim)
			for off in [2.5, -3.0]:
				var ridge := []
				for k in range(1, 8):
					var t := float(k) / 8.0
					ridge.append(a + d * L * t + n * (sin(PI * t) * 4.0 + off * sin(PI * t)))
				pl(ci, ridge, 1.3, Color(INK, 0.4), s)
			hl(ci, a.lerp(b, 0.45) + n * 4.0, 10, 2, d.angle(), 0.5)
		5:
			## 矛头：两面都打薄的尖叶形矛头，边上一圈细削疤
			var base := []
			for k in 20:
				var a := TAU * float(k) / 20.0
				var y := sin(a)
				var w := 15.0 * (1.0 - 0.6 * maxf(-y, 0.0)) * (1.0 - 0.25 * maxf(y, 0.0))
				base.append(Vector2(cos(a) * w, y * 34.0 + 4.0))
			var pts := rot_pts(base, 0.5, Vector2(0, 2))
			sil(ci, [pg(pts, s, Color("a9a49b"), 0)], rim)
			var coarse := []
			for k in range(0, pts.size(), 2):
				coarse.append(pts[k])
			_scars(ci, coarse, Vector2(0, 6).rotated(0.5) + Vector2(0, 2), Color("a9a49b"), s)
			pl(ci, rot_pts([Vector2(0, -26), Vector2(1, 4), Vector2(0, 30)], 0.5, Vector2(0, 2)), 1.5, Color(INK, 0.45), s)
		6:
			## 斧头坯：石斧上那块楔形斧头，越往外越宽，刃口磨出一道亮弧
			var R := 0.35
			var o := Vector2(-21, 18)
			var head := rot_pts([Vector2(-10, -30), Vector2(-4, -36), Vector2(8, -33), Vector2(30, -45), Vector2(38, -37), Vector2(42, -24),
				Vector2(41, -10), Vector2(36, 1), Vector2(8, -12), Vector2(-4, -9), Vector2(-10, -14)], R, o)
			sil(ci, [pg(head, s, Color("8f8c88"), 0)], rim)
			var bevel := poly(rot_pts([Vector2(30, -45), Vector2(38, -37), Vector2(42, -24), Vector2(41, -10), Vector2(36, 1),
				Vector2(31, -5), Vector2(34, -16), Vector2(34, -28), Vector2(27, -38)], R, o), s + 2)
			ci.draw_colored_polygon(bevel, Color("c9c4bc"))
			outline(ci, bevel, 1.4)
			pl(ci, rot_pts([Vector2(14, -34), Vector2(18, -22), Vector2(14, -12)], R, o), 1.4, Color(INK, 0.4), s)
			for k in 3:
				ci.draw_circle(rot_pts([Vector2(-2.0 + float(k) * 6.0, -24.0 + float(k % 2) * 4.0)], R, o)[0], 1.3, Color(INK, 0.3))
		7:
			## 锤头石：一块凿得方方正正的锤头，腰上琢出一圈绑绳的浅槽
			var c := Vector2(-3, 24)
			if rim:
				_st_rim(ci, [_st_block_part(c, 22, 12, Vector2(7, -10), STONE)])
			_st_block(ci, c, 22, 12, Vector2(7, -10), s, STONE, 0)
			var g0 := Vector2(c.x - 2.0, c.y - 12.0)
			ci.draw_colored_polygon(PackedVector2Array([g0 + Vector2(-2.5, 0), g0 + Vector2(2.5, 0), g0 + Vector2(2.5, 24), g0 + Vector2(-2.5, 24)]), Color(STONE_D, 0.7))
			ci.draw_colored_polygon(PackedVector2Array([g0 + Vector2(-2.5, 0), g0 + Vector2(2.5, 0), g0 + Vector2(9.5, -10), g0 + Vector2(4.5, -10)]), Color(STONE_D, 0.6))
			for k in 3:
				ci.draw_circle(c + Vector2(-14.0 + float(k) * 6.0, -2.0 + float(k % 2) * 6.0), 1.3, Color(INK, 0.3))
		8:
			## 镐头坯：两头尖的弯月形镐头
			var R := 0.12
			var o := Vector2(0, 30)
			var out := []
			for k in 15:
				var ang := deg_to_rad(lerpf(-166.0, -14.0, float(k) / 14.0))
				out.append(Vector2(0, 12) + Vector2(cos(ang), sin(ang)) * 46.0)
			out.append(Vector2(48, 2))
			for k in 15:
				var ang := deg_to_rad(lerpf(-22.0, -158.0, float(k) / 14.0))
				out.append(Vector2(0, 18) + Vector2(cos(ang), sin(ang)) * 32.0)
			out.append(Vector2(-48, 2))
			sil(ci, [pg(rot_pts(out, R, o), s, Color("9a958e"), 0)], rim)
			var lower := []
			for k in 13:
				var ang := deg_to_rad(lerpf(-150.0, -30.0, float(k) / 12.0))
				lower.append(Vector2(0, 18) + Vector2(cos(ang), sin(ang)) * 32.0)
			for k in 13:
				var ang := deg_to_rad(lerpf(-30.0, -150.0, float(k) / 12.0))
				lower.append(Vector2(0, 15) + Vector2(cos(ang), sin(ang)) * 38.0)
			ci.draw_colored_polygon(poly(rot_pts(lower, R, o), s + 2), Color("7d7872"))
			var hi := []
			for k in 9:
				var ang := deg_to_rad(lerpf(-140.0, -60.0, float(k) / 8.0))
				hi.append(Vector2(0, 12) + Vector2(cos(ang), sin(ang)) * 42.0)
			pl(ci, rot_pts(hi, R, o), 2.4, Color(1, 1, 1, 0.45), s)
		9:
			## 黑曜石刃：一大片黑亮的黑曜石刃，带紫光
			var pts := [Vector2(-30, 36), Vector2(-28, 18), Vector2(-8, -2), Vector2(22, -24), Vector2(21, -2), Vector2(4, 20), Vector2(-14, 38)]
			sil(ci, [pg(pts, s, OBSID, 2)], rim)
			_st_obs_det(ci, pts, Vector2(-6, 14), s)
			ln(ci, Vector2(-24, 32), Vector2(17, -17), 1.4, Color(OBSID_HL, 0.7), s + 3)
		10:
			## 石板：一块厚实的砂岩石板，铺地、垒火塘用
			sil(ci, _st_slab_parts(Vector2(0, 26), 30, 13, 7, s), rim)
			_st_slab_det(ci, Vector2(0, 26), 30, 13, 7, s)
		11:
			## 一摞石板：四块石板摞成一摞
			var all := []
			var cfg := []
			for k in 4:
				var c := Vector2(float(k % 2) * 6.0 - 3.0, 32.0 - float(k) * 10.0)
				var col := SAND.darkened(0.12 - float(k) * 0.04)
				cfg.append([c, 32.0 - float(k) * 1.5, 12.0, 7.0, s + k * 4, 0.06 * float(k % 2 * 2 - 1)])
				all.append_array(_st_slab_parts(c, cfg[k][1], 12, 7, s + k * 4, col, cfg[k][5]))
			if rim:
				_st_rim(ci, all)
			for k in 4:
				var q: Array = cfg[k]
				sil(ci, all.slice(k * 2, k * 2 + 2), false)
				_st_slab_det(ci, q[0], q[1], q[2], q[3], q[4], q[5])
		12:
			## 方石：一块凿方的灰石块，砌墙基用
			if rim:
				_st_rim(ci, [_st_block_part(Vector2(-4, 22), 26, 16, Vector2(10, -12), ROCK)])
			_st_block(ci, Vector2(-4, 22), 26, 16, Vector2(10, -12), s, ROCK, 4)
		13:
			## 磨石：一块大扁石，顶面磨出一道长凹槽，上面放着一块手握的小磨石
			var top := ell(Vector2(0, 20), Vector2(38, 14), s, 0.04, 22)
			var both := PackedVector2Array()
			for p in top:
				both.append(p)
				both.append(p + Vector2(0, 12))
			var body := Geometry2D.convex_hull(both)
			body.remove_at(body.size() - 1)
			var hand := ov(Vector2(8, 12), 13, 6.5, s + 2, STONE.lightened(0.08), -0.15, 0)
			sil(ci, [P(body, ROCK.darkened(0.15), 2), P(top, ROCK.lightened(0.05), 1), hand], rim)
			var groove := ell(Vector2(-2, 20), Vector2(27, 7.5), s + 1, 0.03, 20)
			ci.draw_colored_polygon(groove, ROCK.darkened(0.12))
			outline(ci, groove, 1.4)
			ci.draw_colored_polygon(ell(Vector2(-2, 22), Vector2(22, 4.5), s + 3, 0.03, 18), ROCK.lightened(0.12))
			sil(ci, [hand], false)
			hl(ci, Vector2(3, 9), 5, 2, -0.15, 0.5)
		14:
			## 一垛方石：五块方石垒成两层
			var cfg := [[Vector2(-24, 30), 14.0, 8.0], [Vector2(4, 30), 14.0, 8.0], [Vector2(32, 30), 13.0, 8.0],
				[Vector2(-12, 12), 14.0, 8.0], [Vector2(16, 12), 14.0, 8.0], [Vector2(2, -6), 13.0, 8.0]]
			var v := Vector2(6, -8)
			if rim:
				var ps := []
				for q in cfg:
					ps.append(_st_block_part(q[0], q[1], q[2], v, ROCK))
				_st_rim(ci, ps)
			for i in [5, 3, 4, 0, 1, 2]:
				var q: Array = cfg[i]
				_st_block(ci, q[0] - Vector2(4, 0), q[1], q[2], v, s + i * 3, ROCK if i % 2 == 0 else ROCK.lightened(0.06), 2)
		15:
			## 石柱：一根凿出来的长条石柱，立着
			var c := Vector2(-4, 4)
			if rim:
				_st_rim(ci, [_st_block_part(c, 13, 34, Vector2(9, -7), ROCK)])
			_st_block(ci, c, 13, 34, Vector2(9, -7), s, ROCK, 0)
			_st_strata(ci, -15, 7, [-14.0, 10.0, 26.0], s)
			for k in 4:
				ln(ci, Vector2(-12, -20.0 + float(k) * 14.0), Vector2(-8, -16.0 + float(k) * 14.0), 1.3, Color(INK, 0.35), s + k)
		_:
			## 刻纹巨石：一块大立石，正面刻着赭红色的螺旋和折线纹，带光
			glow(ci, Vector2(0, -2), 56, GOLD)
			var pts := [Vector2(-26, 38), Vector2(-30, 0), Vector2(-24, -30), Vector2(-8, -44), Vector2(10, -44), Vector2(24, -30), Vector2(30, 0), Vector2(26, 38)]
			sil(ci, [pg(pts, s, ROCK.darkened(0.04), 0)], rim)
			var sp := []
			for k in 30:
				var t := float(k) / 29.0
				var a := t * TAU * 2.2
				sp.append(Vector2(0, -16) + Vector2(cos(a), sin(a)) * (2.0 + t * 13.0))
			pl(ci, sp, 3.0, CLAY, s)
			for row in 2:
				var y := 10.0 + float(row) * 12.0
				var zz := []
				for k in 9:
					zz.append(Vector2(-20.0 + float(k) * 5.0, y + (-4.0 if k % 2 == 0 else 4.0)))
				pl(ci, zz, 2.6, CLAY, s + row)
			for k in 3:
				ci.draw_circle(Vector2(-14.0 + float(k) * 14.0, 32), 2.4, OCHRE)
			hl(ci, Vector2(-16, -26), 5, 9, 0.2, 0.35)
			sparks(ci, [Vector2(-42, -30), Vector2(40, -34), Vector2(44, 20)])

## 石料初稿（卵石 / 燧石 / 砂岩石板 / 黑曜石各 4 级），改成工具料 + 建筑石材后留着备用
static func _main_art_v1(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			## 小卵石：一颗被水磨圆的小石头
			_st_pebs(ci, [[Vector2(0, 30), 12, 8, PEB]], s, rim)
		2:
			## 一把卵石：三颗大小不一的卵石
			_st_pebs(ci, [[Vector2(-10, 30), 10, 7, PEB], [Vector2(10, 31), 9, 6, Color("a49c91")], [Vector2(1, 21), 8, 5.5, Color("c2b9ab")]], s, rim)
		3:
			## 一兜卵石：小皮兜里装得冒尖的卵石
			var bp := [Vector2(-22, 8)]
			for k in 13:
				var a := lerpf(-0.15, PI + 0.15, float(k) / 12.0)
				bp.append(Vector2(cos(a) * 26.0, 16.0 + sin(a) * 21.0))
			bp.reverse()
			bp.append(Vector2(22, 8))
			var bag := pg(bp, s, LEATHER, 0)
			var pebs := [[Vector2(-11, 5), 8, 5.5, PEB], [Vector2(4, 2), 9, 6, Color("c2b9ab")], [Vector2(15, 6), 7, 5, Color("a49c91")], [Vector2(-3, -6), 7, 5, PEB]]
			if rim:
				var ps := [bag]
				for q in pebs:
					ps.append(ov(q[0], q[1], q[2], s, q[3], 0.0, 0, 0.06))
				_st_rim(ci, ps)
			_st_pebs(ci, pebs, s + 2, false)
			sil(ci, [bag, pg([Vector2(-23, 8), Vector2(23, 8), Vector2(22, 14), Vector2(-22, 14)], s + 1, LEATHER.darkened(0.12), 1)], false)
			pl(ci, [Vector2(-18, 11), Vector2(-6, 13), Vector2(8, 12), Vector2(19, 11)], 1.6, ROPE, s)
			pl(ci, [Vector2(19, 11), Vector2(26, 20), Vector2(22, 28)], 2.0, ROPE, s + 1)
			for k in 4:
				var x := -15.0 + float(k) * 10.0
				pl(ci, [Vector2(x, 15), Vector2(x * 1.1 + 1.0, 24), Vector2(x * 0.9, 30)], 1.3, Color(INK, 0.3), s + k)
		4:
			## 卵石堆：十颗卵石垒成一个小尖堆
			var list := []
			var rows := [[34.0, [-30.0, -11.0, 8.0, 27.0], 10.0, 7.0], [24.0, [-20.0, -1.0, 18.0], 10.0, 7.0], [14.0, [-10.0, 9.0], 9.0, 6.5], [4.0, [0.0], 9.0, 6.0]]
			var cols := [PEB, Color("a49c91"), Color("c2b9ab"), Color("b8ad9c")]
			var n := 0
			for r in rows:
				for x in r[1]:
					list.append([Vector2(x, r[0]), r[2], r[3], cols[n % 4]])
					n += 1
			_st_pebs(ci, list, s, rim)
		5:
			## 燧石碎块：一小块燧石，一边还带着白石皮，断口发暗有波纹
			var pts := [Vector2(-14, 34), Vector2(-17, 22), Vector2(-8, 10), Vector2(8, 8), Vector2(17, 17), Vector2(14, 31), Vector2(0, 36)]
			var cortex := [Vector2(-17, 22), Vector2(-8, 10), Vector2(8, 8), Vector2(17, 17), Vector2(9, 16), Vector2(-3, 19), Vector2(-12, 29)]
			sil(ci, [pg(pts, s, FLINT_N, 2), pg(cortex, s + 1, CORTEX, 1)], rim)
			for k in 3:
				ci.draw_arc(Vector2(13, 31), 8.0 + float(k) * 6.0, -2.9, -1.9, 8, Color(1, 1, 1, 0.2), 1.4, true)
			hl(ci, Vector2(4, 24), 5, 2, -0.4, 0.4)
		6:
			## 燧石结核：一整颗疙疙瘩瘩的燧石，白石皮上敲掉一小块，露出里面的黑色
			sil(ci, [pg(_st_nod_pts(Vector2(0, 22), 18, s), s, CORTEX, 1)], rim)
			_st_nod_det(ci, Vector2(0, 22), 18, s)
		7:
			## 剖开的燧石：一颗结核敲成两半，断面朝前
			var a := _st_half_parts(Vector2(-14, 24), 16, s)
			var b := _st_half_parts(Vector2(15, 26), 15, s + 5)
			if rim:
				_st_rim(ci, a + b)
			sil(ci, a, false)
			_st_half_det(ci, Vector2(-14, 24), 16, s)
			sil(ci, b, false)
			_st_half_det(ci, Vector2(15, 26), 15, s + 5)
		8:
			## 燧石堆：几颗整燧石和剖开的半块堆在一起
			var items := [[Vector2(-6, 6), 13.0, 0], [Vector2(-22, 20), 14.0, 0], [Vector2(14, 16), 15.0, 0], [Vector2(-10, 32), 12.0, 1], [Vector2(20, 33), 11.0, 1]]
			var all := []
			for i in items.size():
				var q: Array = items[i]
				if q[2] == 0:
					all.append_array([pg(_st_nod_pts(q[0], q[1], s + i * 4), s + i * 4, CORTEX, 1)])
				else:
					all.append_array(_st_half_parts(q[0], q[1], s + i * 4))
			if rim:
				_st_rim(ci, all)
			for i in items.size():
				var q: Array = items[i]
				if q[2] == 0:
					sil(ci, [pg(_st_nod_pts(q[0], q[1], s + i * 4), s + i * 4, CORTEX, 1)], false)
					_st_nod_det(ci, q[0], q[1], s + i * 4, i == 2)
				else:
					sil(ci, _st_half_parts(q[0], q[1], s + i * 4), false)
					_st_half_det(ci, q[0], q[1], s + i * 4)
		9:
			## 薄石片：一片薄薄的砂岩片
			sil(ci, _st_slab_parts(Vector2(0, 30), 17, 8, 3, s), rim)
			_st_slab_det(ci, Vector2(0, 30), 17, 8, 3, s)
		10:
			## 石板：一块厚实的砂岩石板
			sil(ci, _st_slab_parts(Vector2(0, 26), 30, 13, 7, s), rim)
			_st_slab_det(ci, Vector2(0, 26), 30, 13, 7, s)
		11:
			## 两块叠放的石板：底下那块颜色深一点，错开放
			var a := _st_slab_parts(Vector2(5, 28), 30, 12, 6, s, SAND.darkened(0.08), 0.08)
			var b := _st_slab_parts(Vector2(-3, 18), 28, 12, 6, s + 4, SAND, -0.06)
			if rim:
				_st_rim(ci, a + b)
			sil(ci, a, false)
			_st_slab_det(ci, Vector2(5, 28), 30, 12, 6, s, 0.08)
			sil(ci, b, false)
			_st_slab_det(ci, Vector2(-3, 18), 28, 12, 6, s + 4, -0.06)
		12:
			## 一摞石板：四块石板摞成一摞
			var all := []
			var cfg := []
			for k in 4:
				var c := Vector2(float(k % 2) * 6.0 - 3.0, 32.0 - float(k) * 10.0)
				var col := SAND.darkened(0.12 - float(k) * 0.04)
				cfg.append([c, 32.0 - float(k) * 1.5, 12.0, 7.0, s + k * 4, 0.06 * float(k % 2 * 2 - 1)])
				all.append_array(_st_slab_parts(c, cfg[k][1], 12, 7, s + k * 4, col, cfg[k][5]))
			if rim:
				_st_rim(ci, all)
			for k in 4:
				var q: Array = cfg[k]
				sil(ci, all.slice(k * 2, k * 2 + 2), false)
				_st_slab_det(ci, q[0], q[1], q[2], q[3], q[4], q[5])
		13:
			## 黑曜石碎片：一小片黑亮的火山玻璃，边缘锋利
			var pts := [Vector2(-14, 34), Vector2(-12, 22), Vector2(2, 8), Vector2(14, 12), Vector2(10, 26), Vector2(-2, 35)]
			sil(ci, [pg(pts, s, OBSID, 2)], rim)
			_st_obs_det(ci, pts, Vector2(0, 24), s)
		14:
			## 黑曜石块：拳头大的一块，满是贝壳状的断面
			var pts := _st_shard_pts(Vector2(0, 20), 24, 18, s)
			sil(ci, [pg(pts, s, OBSID, 2)], rim)
			_st_obs_det(ci, pts, Vector2(2, 18), s)
		15:
			## 大黑曜石：一大块黑曜石原石
			var pts := _st_shard_pts(Vector2(0, 10), 36, 28, s, 8)
			sil(ci, [pg(pts, s, OBSID, 2)], rim)
			_st_obs_det(ci, pts, Vector2(3, 8), s)
		_:
			## 黑曜石堆：好几块黑曜石堆在一起，透着紫光
			glow(ci, Vector2(0, 8), 56, OBSID_HL)
			var cfg := [[Vector2(-4, 2), 20.0, 16.0], [Vector2(-24, 20), 18.0, 14.0], [Vector2(20, 18), 20.0, 15.0], [Vector2(-6, 30), 16.0, 10.0], [Vector2(26, 33), 12.0, 7.0]]
			var all := []
			for i in cfg.size():
				var q: Array = cfg[i]
				all.append(pg(_st_shard_pts(q[0], q[1], q[2], s + i * 9), s + i, OBSID, 2))
			if rim:
				_st_rim(ci, all)
			for i in cfg.size():
				var q: Array = cfg[i]
				var pts := _st_shard_pts(q[0], q[1], q[2], s + i * 9)
				sil(ci, [all[i]], false)
				_st_obs_det(ci, pts, q[0], s + i)
			sparks(ci, [Vector2(-40, -20), Vector2(36, -18), Vector2(44, 24)])

static func _sub_art(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			## 石英碎粒：几颗躺着的小透明晶粒
			_st_crys(ci, [[Vector2(-12, 34), 4.0, 9.0, -1.25], [Vector2(8, 35), 4.5, 11.0, 1.2], [Vector2(-1, 27), 3.5, 7.0, -0.2]], s, QUARTZ, Color("a8b8c8"), rim)
		2:
			## 石英原石：乳白的石英块，顶上冒出几根晶尖
			_st_crys(ci, [[Vector2(-8, 16), 5.0, 14.0, -0.35], [Vector2(4, 12), 6.0, 18.0, 0.1], [Vector2(14, 18), 4.0, 10.0, 0.6]], s, QUARTZ, Color("a8b8c8"), rim,
				[raw_rock(Vector2(0, 26), 20, s + 9, MILKY, 7, 0.18)])
		3:
			## 石英晶簇：乳白原石块做底，两三排透明晶柱从后往前长满顶面
			var cs := _crystal_rows(Vector2(0, 24), 17, 6, 36, 6.5, [2, 1, 3], s)
			var basep := raw_rock(Vector2(0, 30), 22, s + 9, MILKY, 7, 0.2)
			var crys := []
			for q in cs:
				crys.append(crystal(q[0], q[1], q[2], q[3], s + crys.size(), QUARTZ))
			sil(ci, [basep] + crys, rim)
			var face := ell(Vector2(0, 24), Vector2(19, 6), s + 10, 0.05, 16)
			ci.draw_colored_polygon(face, Color("eef2f6"))
			outline(ci, face, 1.6)
			for i in cs.size():
				var q: Array = cs[i]
				sil(ci, [crys[i]], false)
				crystal_det(ci, q[0], q[1], q[2], q[3], s + i, Color("a8b8c8"))
		4:
			## 带矿脉的绿松石原石：褐色围岩里夹着几块蓝绿色
			sil(ci, [raw_rock(Vector2(0, 24), 22, s, MATRIX, 8, 0.18)], rim)
			for q in [[Vector2(-8, 18), 7.0, 4.5], [Vector2(8, 28), 6.0, 4.0], [Vector2(9, 14), 4.0, 3.0]]:
				var p := ell(q[0], Vector2(q[1], q[2]), s + int(q[1]), 0.18, 10, 0.3)
				ci.draw_colored_polygon(p, TURQ)
				outline(ci, p, 1.4)
			pl(ci, [Vector2(-1, 20), Vector2(4, 24), Vector2(8, 28)], 2.0, TURQ.darkened(0.1), s)
			hl(ci, Vector2(-10, 16), 3, 1.5, -0.3, 0.6)
		5:
			## 绿松石块：一整块蓝绿色的绿松石，带深色网纹
			sil(ci, [raw_rock(Vector2(0, 20), 24, s, TURQ, 9, 0.15)], rim)
			pl(ci, [Vector2(-18, 14), Vector2(-6, 20), Vector2(-1, 10), Vector2(12, 20), Vector2(19, 15)], 1.6, Color(INK, 0.5), s)
			pl(ci, [Vector2(-10, 32), Vector2(0, 26), Vector2(10, 33)], 1.6, Color(INK, 0.5), s + 3)
			pl(ci, [Vector2(-6, 20), Vector2(-4, 28)], 1.4, Color(INK, 0.45), s + 5)
			hl(ci, Vector2(-9, 6), 7, 3.5)
		6:
			## 一堆绿松石：几块绿松石堆在一起
			var cfg := [[Vector2(-2, 6), 14.0], [Vector2(-18, 22), 14.0], [Vector2(16, 20), 15.0], [Vector2(0, 32), 12.0]]
			var all := []
			for i in cfg.size():
				var q: Array = cfg[i]
				all.append(raw_rock(q[0], q[1], s + i * 5, TURQ.darkened(0.05 * float(i % 2)), 8, 0.15))
			if rim:
				_st_rim(ci, all)
			for i in cfg.size():
				var q: Array = cfg[i]
				var c: Vector2 = q[0]
				var r: float = q[1]
				sil(ci, [all[i]], false)
				pl(ci, [c + Vector2(-r * 0.6, -r * 0.1), c + Vector2(-r * 0.1, r * 0.2), c + Vector2(r * 0.2, -r * 0.3), c + Vector2(r * 0.6, r * 0.1)], 1.4, Color(INK, 0.5), s + i)
				hl(ci, c + Vector2(-r * 0.35, -r * 0.4), r * 0.3, r * 0.14)
		7:
			## 紫晶碎：一小块灰石头上长着几根紫色晶尖
			_st_crys(ci, [[Vector2(-7, 32), 5.0, 14.0, -0.35], [Vector2(3, 31), 6.0, 20.0, 0.08], [Vector2(12, 32), 4.0, 10.0, 0.5]], s, PURPLE, Color("d8b0f0"), rim,
				[raw_rock(Vector2(2, 34), 13, s + 9, ROCK, 6, 0.2)])
		8:
			## 紫晶簇：紫色晶簇团做底，三排晶柱从后往前长满
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
			for i in cs.size():
				var q: Array = cs[i]
				sil(ci, [crys[i]], false)
				crystal_det(ci, q[0], q[1], q[2], q[3], s + i, Color("d8b0f0"))
		9:
			## 紫晶洞：半个灰石壳，里面密密一圈紫色晶尖朝中间长，带光
			glow(ci, Vector2(0, 10), 52, Color("c99ae8"))
			sil(ci, [ov(Vector2(0, 14), 36, 27, s, ROCK.darkened(0.12), 0.0, 1), ov(Vector2(0, 9), 36, 27, s + 1, ROCK, 0.0, 1)], rim)
			var rim_e := ell(Vector2(0, 9), Vector2(29, 21), s + 2, 0.05, 22)
			ci.draw_colored_polygon(rim_e, Color("ece6f2"))
			outline(ci, rim_e, 1.6)
			ci.draw_colored_polygon(ell(Vector2(0, 9), Vector2(25, 17.5), s + 3, 0.04, 22), Color("4a2a6a"))
			var tones := [PURPLE.lightened(0.25), PURPLE, Color("c99ae8")]
			for ring_i in 3:
				var f: float = [0.92, 0.62, 0.32][ring_i]
				var n: int = [16, 11, 6][ring_i]
				for k in n:
					var a := TAU * float(k) / float(n) + float(ring_i) * 0.3
					var b := Vector2(0, 9) + Vector2(cos(a) * 25.0, sin(a) * 17.5) * f
					var d := (Vector2(0, 9) - b).normalized()
					var nrm := Vector2(-d.y, d.x)
					var l := 8.0 - float(ring_i) * 1.5
					var tri := PackedVector2Array([b + nrm * 3.2, b + d * l, b - nrm * 3.2])
					ci.draw_colored_polygon(tri, tones[(k + ring_i) % 3])
					ci.draw_polyline(PackedVector2Array([b + nrm * 3.2, b + d * l, b - nrm * 3.2]), Color("3a1e56"), 1.0, true)
			ci.draw_colored_polygon(star_pts(Vector2(-10, 2), 5, 1.5, 4, s), Color.WHITE)
			sparks(ci, [Vector2(-40, -18), Vector2(38, -20), Vector2(42, 30)], 5)
		10:
			## 嵌在石头里的小钻石：一块青灰色的石头，顶上冒出一颗小八面体
			var rock := raw_rock(Vector2(0, 26), 22, s, KIMB, 8, 0.18)
			sil(ci, [rock, _st_octa_part(Vector2(5, 10), 9, 0.15, s + 1)], rim)
			for k in 7:
				ci.draw_circle(Vector2((srnd(s + k) - 0.5) * 30.0, 30.0 + (srnd(s + k + 7) - 0.5) * 12.0), 1.3 + srnd(s + k + 3), Color("9fb07a") if k % 2 == 0 else Color(INK, 0.3))
			_st_octa_det(ci, Vector2(5, 10), 9, 0.15, s + 1)
			spark(ci, Vector2(16, -2), 4)
		11:
			## 钻石原石：一颗没打磨的八面体钻石，半透明发亮
			glow(ci, Vector2(0, 12), 40, Color("bfe8ff"))
			sil(ci, [_st_octa_part(Vector2(0, 12), 26, 0.12, s)], rim)
			_st_octa_det(ci, Vector2(0, 12), 26, 0.12, s)
			sparks(ci, [Vector2(-26, -12), Vector2(28, 30)], 4.5)
		_:
			## 一捧钻石原石：好几颗八面体钻石堆在一起，光芒四射
			glow(ci, Vector2(0, 6), 58, Color("bfe8ff"))
			rays(ci, Vector2(0, 4), 40, 54, 8, Color(1, 1, 0.9, 0.5), 2.6, 0.2)
			var cfg := [[Vector2(-2, 0), 20.0, 0.1], [Vector2(-22, 20), 16.0, -0.3], [Vector2(20, 18), 17.0, 0.35], [Vector2(-6, 30), 12.0, 0.6], [Vector2(12, 33), 10.0, -0.2]]
			var all := []
			for i in cfg.size():
				var q: Array = cfg[i]
				all.append(_st_octa_part(q[0], q[1], q[2], s + i))
			if rim:
				_st_rim(ci, all)
			for i in cfg.size():
				var q: Array = cfg[i]
				sil(ci, [all[i]], false)
				_st_octa_det(ci, q[0], q[1], q[2], s + i)
			sparks(ci, [Vector2(-40, -26), Vector2(36, -30), Vector2(44, 26), Vector2(-42, 30)], 5)

## 候选：柱础石（没选上），留着备用——方石座上托着一个圆鼓形石墩，顶面凿出插木柱的圆孔
static func _plinth(ci: CanvasItem, s: int, rim: bool) -> void:
	var v := Vector2(8, -9)
	var base_c := Vector2(-4, 30)
	var top := ell(Vector2(0, 0), Vector2(22, 7.5), s, 0.03, 22)
	var bot := ell(Vector2(0, 20), Vector2(24, 8), s + 1, 0.03, 22)
	var both := PackedVector2Array()
	for p in top:
		both.append(p)
	for p in bot:
		both.append(p)
	var drum := Geometry2D.convex_hull(both)
	drum.remove_at(drum.size() - 1)
	var parts := [_st_block_part(base_c, 32, 8, v, ROCK), P(drum, ROCK.darkened(0.1), 2), P(top, ROCK.lightened(0.1), 1)]
	if rim:
		_st_rim(ci, parts)
	_st_block(ci, base_c, 32, 8, v, s, ROCK.darkened(0.04), 5)
	sil(ci, [parts[1], parts[2]], false)
	for k in 5:
		var x := -18.0 + float(k) * 9.0
		ln(ci, Vector2(x, 8.0 + absf(x) * 0.05), Vector2(x + 1.0, 22.0 - absf(x) * 0.1), 1.2, Color(INK, 0.3), s + k)
	var hole := ell(Vector2(0, -1), Vector2(8, 2.8), s + 2, 0.0, 16)
	safe_poly(ci, hole, Color("3a2e26"))
	outline(ci, hole, 1.6)
	hl(ci, Vector2(-11, -2), 5, 1.6, 0.0, 0.45)

## 盖顶巨石（石料最后一级）——又大又厚、边缘不规则的灰色平顶巨石板
static func _capstone(ci: CanvasItem, s: int, rim: bool) -> void:
	var c := Vector2(0, 16)
	var top := []
	for k in 11:
		var a := TAU * float(k) / 11.0 + 0.15
		var m := 0.84 + srnd(s + k) * 0.22
		top.append(c + Vector2(cos(a) * 46.0, sin(a) * 16.0) * m)
	var th := Vector2(0, 15)
	var both := PackedVector2Array()
	for p in top:
		both.append(p)
		both.append((p as Vector2) + th)
	var body := Geometry2D.convex_hull(both)
	body.remove_at(body.size() - 1)
	sil(ci, [P(body, ROCK.darkened(0.16), 2), pg(top, s + 1, ROCK, 1)], rim)
	var lip := []
	for k in [0, 1, 2, 3, 4, 5]:
		lip.append((top[k] as Vector2) + th * 0.5)
	pl(ci, lip, 1.3, Color(INK, 0.3), s)
	for k in 7:
		var p := c + Vector2((srnd(s + k * 3) - 0.5) * 70.0, (srnd(s + k * 3 + 1) - 0.5) * 18.0)
		ci.draw_circle(p, 1.4 + srnd(s + k) * 1.4, Color(INK, 0.22))
	_st_crack(ci, [c + Vector2(-30, -6), c + Vector2(-18, 0), c + Vector2(-22, 8)], 1.2, s + 2)
	sil(ci, [ov(c + Vector2(22, -6), 9, 3.5, s + 3, MOSS, 0.0, 2)], false)
	ln(ci, c + Vector2(-20, -9), c + Vector2(4, -11), 2.4, Color(1, 1, 1, 0.3), s)

## 石梁（被盖顶巨石替掉），留着备用
static func _beam_v1(ci: CanvasItem, s: int, rim: bool) -> void:
	## 石梁：一条又长又厚的条石，横放着；搭在两根石柱上就是门框
	var c := Vector2(-6, 24)
	var v := Vector2(10, -12)
	if rim:
		_st_rim(ci, [_st_block_part(c, 40, 11, v, ROCK)])
	_st_block(ci, c, 40, 11, v, s, ROCK, 6)
	_st_strata(ci, -44, 32, [26.0], s)
	for x in [-30.0, 18.0]:
		ln(ci, Vector2(x, 14), Vector2(x + 2.0, 34), 1.3, Color(INK, 0.3), s + int(x))

## 石钻头（被半月石刀替掉），留着备用
static func _drill_v1(ci: CanvasItem, s: int, rim: bool) -> void:
	## 石钻头：底下宽、上面修出一根细长尖的小燧石，给骨头、木头、贝壳钻孔用
	var R := 0.3
	var pv := Vector2(0, 14)
	var pts := _st_rot([Vector2(-17, 36), Vector2(-19, 24), Vector2(-6, 17), Vector2(-3, -14), Vector2(0, -22), Vector2(3, -14),
		Vector2(6, 17), Vector2(18, 22), Vector2(16, 36), Vector2(0, 38)], R, pv)
	sil(ci, [pg(pts, s, FLINT, 1)], rim)
	for k in 4:
		var y := 12.0 - float(k) * 7.0
		for side in [-1.0, 1.0]:
			var p: Vector2 = _st_rot([Vector2(side * (5.0 - float(k) * 0.6), y)], R, pv)[0]
			ci.draw_arc(p, 2.4, PI * 0.5 - side * PI * 0.5 - 1.0, PI * 0.5 - side * PI * 0.5 + 1.0, 5, Color(INK, 0.4), 1.1, true)
	ci.draw_colored_polygon(poly(_st_rot([Vector2(-17, 34), Vector2(-18, 25), Vector2(-6, 19), Vector2(-4, 30)], R, pv), s + 1), FLINT.lightened(0.18))
	pl(ci, _st_rot([Vector2(0, -18), Vector2(0, 14)], R, pv), 1.4, Color(1, 1, 1, 0.35), s)

## 半月石刀初稿（平放、像小圆面包），留着备用
static func _knife_v1(ci: CanvasItem, s: int, rim: bool) -> void:
	## 半月石刀：一片磨薄的半月形石板，弧背上钻两个穿绳孔，平直的一边磨成刃口，收割草和谷穗用
	var col := Color("8e9196")
	var pts := []
	for k in 13:
		var an := lerpf(PI, TAU, float(k) / 12.0)
		pts.append(Vector2(cos(an) * 30.0, 30.0 + sin(an) * 20.0))
	pts.append(Vector2(26, 34))
	pts.append(Vector2(-26, 34))
	pts = rot_pts(pts, -0.12, Vector2.ZERO)
	sil(ci, [pg(pts, s, col, 1)], rim)
	var edge := poly(rot_pts([Vector2(-29, 29), Vector2(29, 29), Vector2(26, 34), Vector2(-26, 34)], -0.12, Vector2.ZERO), s + 1, 0.3)
	ci.draw_colored_polygon(edge, col.lightened(0.25))
	outline(ci, edge, 1.3)
	for x in [-7.0, 7.0]:
		var h: Vector2 = rot_pts([Vector2(x, 18)], -0.12, Vector2.ZERO)[0]
		ci.draw_circle(h, 3.2, INK)
		ci.draw_circle(h, 2.0, Color("3a2e26"))
	hl(ci, rot_pts([Vector2(-12, 20)], -0.12, Vector2.ZERO)[0], 8, 2, -0.12, 0.45)

## 半月石刀第二稿（浅灰平涂、弧背朝上），留着备用
static func _knife_v2(ci: CanvasItem, s: int, rim: bool) -> void:
	## 半月石刀：一片磨薄的半月形石板，弧背朝上，背上钻两个穿绳孔，下面平直的一边磨成发亮的刃口，收割草和谷穗用
	var col := Color("a3a6ab")
	var R := -0.22
	var o := Vector2(0, 26)
	var loc := []
	for k in 17:
		var an := lerpf(PI + 0.02, TAU - 0.02, float(k) / 16.0)
		loc.append(Vector2(cos(an) * 36.0, sin(an) * 22.0))
	loc.append(Vector2(33, 4))
	loc.append(Vector2(-33, 4))
	sil(ci, [pg(rot_pts(loc, R, o), s, col, 2)], rim)
	var inner := []
	for k in 13:
		var an := lerpf(PI + 0.25, TAU - 0.25, float(k) / 12.0)
		inner.append(Vector2(cos(an) * 30.0, -1.0 + sin(an) * 16.0))
	safe_poly(ci, poly(rot_pts(inner, R, o), s + 3, 0.3), col.darkened(0.06))
	var edge := poly(rot_pts([Vector2(-35, -2), Vector2(35, -2), Vector2(33, 4), Vector2(-33, 4)], R, o), s + 1, 0.3)
	ci.draw_colored_polygon(edge, col.lightened(0.3))
	outline(ci, edge, 1.3, Color(INK, 0.6))
	pl(ci, rot_pts([Vector2(-30, 2.5), Vector2(30, 2.5)], R, o), 1.4, Color(1, 1, 1, 0.8), s)
	for x in [-9.0, 9.0]:
		var h: Vector2 = rot_pts([Vector2(x, -12)], R, o)[0]
		ci.draw_circle(h, 2.8, INK)
		ci.draw_circle(h, 1.5, Color("5a4a3e"))
	hl(ci, rot_pts([Vector2(-20, -10)], R, o)[0], 6, 2.2, R - 0.5, 0.5)
