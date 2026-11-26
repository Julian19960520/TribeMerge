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
## 第 6 版石料用的缩放
const MAIN_SCALE_V6 := [0.53, 0.78, 0.74, 0.82, 0.8, 0.934, 0.983, 1.099, 0.957, 0.936, 0.807, 0.9, 1.04, 1.158, 1.183, 1.13]
## 第 2 版宝石用的缩放
const SUB_SCALE_V2 := [1.05, 0.78, 0.8, 0.91, 0.95, 1.0, 1.18, 0.84, 0.91, 1.21, 1.5, 1.2]

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
	var keep := _st_grow(ci, MAIN_SCALE[clampi(lv, 1, MAIN_SCALE.size()) - 1])
	_main_art(ci, lv, s, rim)
	_st_ungrow(ci, keep)

static func sub(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	var keep := _st_grow(ci, SUB_SCALE[clampi(lv, 1, SUB_SCALE.size()) - 1])
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

# ---------------------------------------------------------------- 石料第 7 版：燧石 / 板岩 / 花岗岩 / 玄武岩，各 4 级
## 都是天然石头或粗坯，不装柄、不刻纹、不立起来。每段换一种搬运方式：地上 → 兽皮 → 木橇 → 圆木滚子加拉绳。

const MAIN_SCALE_V7 := [1.25, 1.08, 1.06, 1.02, 1.12, 1.06, 1.02, 1.0, 1.0, 0.98, 1.0, 1.0, 1.0, 0.98, 0.98, 1.0]
const SLATE := Color("a3b5c4")
const SLATE_D := Color("8299ad")
const GRANITE := Color("cdc9c1")
const GRANITE_W := Color("dacdc6")
const BASALT := Color("545a65")
const BASALT_L := Color("6b717d")
const HIDE_PAD := Color("c99b68")
const ST_ROPE := Color("c49a5c")

## 兽皮垫：一块毛边兽皮平铺在地上
static func _st_hide(c: Vector2, rx: float, ry: float, s: int) -> Array:
	var pts := []
	var n := 26
	for k in n:
		var a := TAU * float(k) / float(n)
		var m := 1.0 + (0.07 if k % 2 == 0 else -0.05) + (srnd(s + k) - 0.5) * 0.08
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry) * m)
	return pg(pts, s, HIDE_PAD, 1)

static func _st_hide_det(ci: CanvasItem, c: Vector2, rx: float, ry: float, s: int) -> void:
	for k in 4:
		var p := c + Vector2((srnd(s + k * 3) - 0.5) * rx * 1.5, (srnd(s + k * 3 + 1) - 0.2) * ry * 0.9)
		ci.draw_colored_polygon(ell(p, Vector2(4.0, 1.8), s + k, 0.15, 8), Color(LEATHER_D, 0.35))

## 一道捆绳
static func _st_rope(ci: CanvasItem, pts: Array, s: int) -> void:
	pl(ci, pts, 4.8, INK, s)
	pl(ci, pts, 2.6, ST_ROPE, s)

## 木橇：两根前头翘起的滑木（后一根高一点、深一点），中间几根横木
static func _st_sled_back(x0: float, x1: float, y: float, s: int) -> Array:
	return [stk(Vector2(x0 + 8, y - 7), Vector2(x1, y - 7), 3.0, s, WOOD_D), stk(Vector2(x1, y - 7), Vector2(x1 + 7, y - 15), 3.0, s + 1, WOOD_D)]

static func _st_sled_bars(x0: float, x1: float, y: float, s: int) -> Array:
	var out := []
	for k in 3:
		var x := lerpf(x0 + 10.0, x1 - 10.0, float(k) / 2.0)
		out.append(stk(Vector2(x, y), Vector2(x + 8, y - 7), 2.6, s + k, WOOD))
	return out

static func _st_sled_front(x0: float, x1: float, y: float, s: int) -> Array:
	return [stk(Vector2(x0, y), Vector2(x1 - 6, y), 3.4, s, WOOD), stk(Vector2(x1 - 6, y), Vector2(x1 + 2, y - 10), 3.4, s + 1, WOOD)]

## 垫木：两根长圆木顺着垫在底下（后一根高一点、深一点），右头露出年轮
static func _st_logs_back(x0: float, x1: float, y: float, s: int) -> Array:
	return [stk(Vector2(x0 + 8, y - 7), Vector2(x1 + 6, y - 7), 4.4, s, WOOD_D)]

static func _st_logs_front(x0: float, x1: float, y: float, s: int) -> Array:
	return [stk(Vector2(x0, y), Vector2(x1, y), 5.0, s, WOOD), ov(Vector2(x1 + 2, y), 3.4, 5.2, s + 1, WOOD.lightened(0.18), 0.0, 0)]

static func _st_logs_det(ci: CanvasItem, x0: float, x1: float, y: float, s: int) -> void:
	ci.draw_colored_polygon(ell(Vector2(x1 + 2, y), Vector2(1.6, 2.6), 0, 0.0, 10), Color(WOOD_D, 0.7))
	pl(ci, [Vector2(x0 + 6, y - 1.5), Vector2(lerpf(x0, x1, 0.5), y - 2.2), Vector2(x1 - 6, y - 1.5)], 1.2, Color(INK, 0.3), s)
	for k in 2:
		var x := lerpf(x0, x1, 0.3 + 0.4 * float(k))
		ln(ci, Vector2(x, y + 1), Vector2(x + 5, y + 2), 1.1, Color(INK, 0.35), s + k)

## 花岗岩的黑白斑点
static func _st_speck(ci: CanvasItem, pts: PackedVector2Array, s: int, n: int) -> void:
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	var k := 0
	var tries := 0
	while k < n and tries < n * 8:
		var p := r.position + Vector2(srnd(s + tries * 3) * r.size.x, srnd(s + tries * 3 + 1) * r.size.y)
		tries += 1
		if not Geometry2D.is_point_in_polygon(p, pts):
			continue
		var col := Color("2f2c2a", 0.75) if k % 3 != 0 else Color(1, 1, 1, 0.8)
		ci.draw_circle(p, 0.8 + srnd(s + tries * 5) * 0.9, col)
		k += 1

## 板岩侧面一层层的薄片线
static func _st_layers(ci: CanvasItem, c: Vector2, w: float, d: float, th: float, s: int, rot: float, n: int) -> void:
	var top := _st_slab_top(c, w, d, s, rot)
	for j in n:
		var t := float(j + 1) / float(n + 1)
		var lip := []
		for k in [0, 1, 2, 3, 4]:
			lip.append((top[k] as Vector2) + Vector2(0, th * t))
		pl(ci, lip, 1.2, Color(INK, 0.35), s + j)

## 一块板岩：石板 + 薄片线
static func _st_slate(ci: CanvasItem, c: Vector2, w: float, d: float, th: float, s: int, col: Color, rot: float) -> void:
	sil(ci, _st_slab_parts(c, w, d, th, s, col, rot), false)
	_st_layers(ci, c, w, d, th, s, rot, maxi(1, int(th / 5.0)))
	ln(ci, c + Vector2(-w * 0.5, -d * 0.35), c + Vector2(-w * 0.1, -d * 0.5), 2.2, Color(1, 1, 1, 0.35), s)

## 平躺的玄武岩六棱柱：c 是右端六边形截面的中心，往左（略往上）伸出 L
static func _st_hex_pts(c: Vector2, r: float) -> Array:
	var out := []
	for i in 6:
		var a := PI / 3.0 * float(i)
		out.append(c + Vector2(cos(a) * r * 0.5, sin(a) * r))
	return out

static func _st_hex_e(L: float) -> Vector2:
	return Vector2(-L, -5.0)

static func _st_hex_part(c: Vector2, r: float, L: float, col: Color) -> Array:
	var all := PackedVector2Array()
	for p in _st_hex_pts(c, r):
		all.append(p)
		all.append((p as Vector2) + _st_hex_e(L))
	var hull := Geometry2D.convex_hull(all)
	hull.remove_at(hull.size() - 1)
	return P(hull, col, 2)

static func _st_hex(ci: CanvasItem, c: Vector2, r: float, L: float, s: int, col: Color) -> void:
	sil(ci, [_st_hex_part(c, r, L, col)], false)
	var v := _st_hex_pts(c, r)
	var e := _st_hex_e(L)
	var tones := {2: col.darkened(0.12), 3: col.lightened(0.06), 4: col.lightened(0.2)}
	for i in [2, 3, 4]:
		var a: Vector2 = v[i]
		var b: Vector2 = v[(i + 1) % 6]
		var q := PackedVector2Array([a, b, b + e, a + e])
		ci.draw_colored_polygon(q, tones[i])
		outline(ci, q, 1.4)
	var end := poly(v, s, 0.4)
	ci.draw_colored_polygon(end, col.lightened(0.3))
	outline(ci, end, 1.8)
	## 截面上一道细裂、几个气孔
	pl(ci, [c + Vector2(-r * 0.2, -r * 0.6), c + Vector2(r * 0.05, -r * 0.1), c + Vector2(-r * 0.1, r * 0.4)], 1.2, Color(INK, 0.4), s)
	for k in 5:
		var p := (v[3] as Vector2).lerp(v[0] + e, 0.15 + 0.17 * float(k)) + Vector2(0, (srnd(s + k) - 0.5) * r * 0.6)
		ci.draw_circle(p, 1.1, Color(INK, 0.35))
	hl(ci, (v[4] as Vector2).lerp(v[5] + e, 0.4), L * 0.18, 1.4, 0.0, 0.35)

## 六棱柱底边在 x 处的 y（放滚子用）
static func _st_hex_bottom(c: Vector2, r: float, L: float, x: float) -> float:
	var x_end := c.x - r * 0.25
	return c.y + r * 0.866 - 5.0 * clampf((x_end - x) / L, 0.0, 1.0)

## 一组燧石片，从后往前画，共用一圈白边
static func _st_flint_pile(ci: CanvasItem, list: Array, s: int, rim: bool) -> void:
	list.sort_custom(func(a, b): return a[0].y < b[0].y)
	var parts := []
	var pts_all := []
	for i in list.size():
		var q: Array = list[i]
		var hull := Geometry2D.convex_hull(PackedVector2Array(_st_shard_pts(q[0], q[1], q[2], s + i * 5, 6)))
		hull.remove_at(hull.size() - 1)
		var pts := Array(hull)
		pts_all.append(pts)
		parts.append(pg(pts, s + i * 5, FLINT_N if i % 2 == 0 else FLINT_N.lightened(0.12), 0 if q[1] >= 8.0 else 1))
	if rim:
		_st_rim(ci, parts)
	for i in parts.size():
		var q: Array = list[i]
		sil(ci, [parts[i]], false)
		_scars(ci, pts_all[i], q[0], FLINT_N if i % 2 == 0 else FLINT_N.lightened(0.12), s + i)
		## 有的片边上还带一点白石皮
		if i % 3 == 0:
			var a: Vector2 = pts_all[i][0]
			var b: Vector2 = pts_all[i][1]
			var cc: Vector2 = q[0]
			var cp := poly([a, b, b.lerp(cc, 0.3), a.lerp(cc, 0.3)], s + i)
			ci.draw_colored_polygon(cp, CORTEX)
			outline(ci, cp, 1.2)
		hl(ci, (q[0] as Vector2) + Vector2(-q[1] * 0.2, -q[2] * 0.3), q[1] * 0.3, 1.4, -0.3, 0.45)

# ---------------------------------------------------------------- 石料第 8 版：16 级各是一种认得出的石头，都放在同一个小土坡上
## 照宝石线的思路：每级换一种石头；土坡不变；越往后越大、越稀罕，13 级起带光、越来越亮。
## 1~4 巴掌大的普通石头；5~8 大一块或敲开露出里面；9~12 大块石料、天然石形；13~16 罕见奇石。

const MAIN_SCALE := [0.880, 0.876, 0.882, 0.940, 0.899, 0.972, 0.975, 1.027, 1.004, 0.942, 1.054, 1.071, 0.971, 1.114, 1.074, 0.936]
const SOIL := Color("b08657")

## 小土坡：一块扁扁的土，左右各一撮小草
static func _sl_ground() -> Array:
	return ov(Vector2(0, 35), 34, 7.5, 91, SOIL, 0.0, 1)

static func _sl_ground_det(ci: CanvasItem) -> void:
	for x in [-30.0, 27.0]:
		for k in 3:
			var b := Vector2(x + float(k) * 3.0, 33)
			pl(ci, [b, b + Vector2(-2.0 + float(k) * 2.0, -7.0 - float(k % 2) * 2.0)], 1.8, MOSS_D, int(x) + k)
	ci.draw_circle(Vector2(-12, 38), 1.3, Color(INK, 0.25))
	ci.draw_circle(Vector2(14, 37), 1.1, Color(INK, 0.25))

## 先画土坡和所有零件的白边，再画土坡；石头由各级自己画
static func _sl_begin(ci: CanvasItem, parts: Array, rim: bool) -> void:
	var g := _sl_ground()
	if rim:
		_st_rim(ci, [g] + parts)
	sil(ci, [g], false)
	_sl_ground_det(ci)

## 在多边形里画几道横纹（砂岩、大理石用）
static func _sl_bands(ci: CanvasItem, body: PackedVector2Array, lines: Array, w: float, col: Color) -> void:
	for l in lines:
		for seg in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array(l), body):
			ci.draw_polyline(seg, col, w / Art.stroke_k, true)

## 竖着的六棱柱（玄武岩）：底边中心 b、半宽 w、高 h；看得到顶面和前面三块侧面
static func _sl_column_part(b: Vector2, w: float, h: float, col: Color) -> Array:
	var all := PackedVector2Array()
	for i in 6:
		var a := PI / 3.0 * float(i)
		var p := Vector2(cos(a) * w, sin(a) * w * 0.45)
		all.append(b + p)
		all.append(b + p - Vector2(0, h))
	var hull := Geometry2D.convex_hull(all)
	hull.remove_at(hull.size() - 1)
	return P(hull, col, 2)

static func _sl_column(ci: CanvasItem, b: Vector2, w: float, h: float, col: Color, s: int) -> void:
	sil(ci, [_sl_column_part(b, w, h, col)], false)
	var v := []
	for i in 6:
		var a := PI / 3.0 * float(i)
		v.append(Vector2(cos(a) * w, sin(a) * w * 0.45))
	var up := Vector2(0, -h)
	## 前面三块：左亮、中、右暗
	var faces := [[3, 2, col.lightened(0.12)], [2, 1, col], [1, 0, col.darkened(0.2)]]
	for f in faces:
		var p0: Vector2 = b + v[f[0]]
		var p1: Vector2 = b + v[f[1]]
		var q := PackedVector2Array([p0 + up, p1 + up, p1, p0])
		ci.draw_colored_polygon(q, f[2])
		outline(ci, q, 1.3)
	var top := []
	for p in v:
		top.append(b + (p as Vector2) + up)
	ci.draw_colored_polygon(PackedVector2Array(top), col.lightened(0.3))
	outline(ci, PackedVector2Array(top), 1.6)
	ln(ci, b + v[2] + up * 0.6, b + v[2] + up * 0.4 + Vector2(2, 0), 1.1, Color(INK, 0.35), s)

static func _main_art(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			## 鹅卵石：一颗圆溜溜、灰色光滑的河卵石，身上一道浅色的环纹
			var body := ov(Vector2(0, 24), 22, 13, s, Color("9d9a95"), -0.08, 0)
			_sl_begin(ci, [body], rim)
			sil(ci, [body], false)
			pl(ci, [Vector2(-18, 22), Vector2(-6, 27), Vector2(8, 26), Vector2(19, 20)], 2.4, Color("cfccc6"), s)
		2:
			## 燧石：白色石皮的结核，敲开一面露出黑亮的芯
			var c := Vector2(0, 18)
			var parts := _st_half_parts(c, 22, s)
			_sl_begin(ci, parts, rim)
			sil(ci, parts, false)
			_st_half_det(ci, c, 22, s)
		3:
			## 砂岩：一块橙黄色的石块，侧面一层层的颜色深浅不同
			var pts := [Vector2(-28, 34), Vector2(-30, 16), Vector2(-22, 2), Vector2(4, -2), Vector2(26, 4), Vector2(30, 20), Vector2(26, 34)]
			var body := pg(pts, s, Color("e2a35e"), 0)
			_sl_begin(ci, [body], rim)
			sil(ci, [body], false)
			var bp := PackedVector2Array(body[0])
			var lines := []
			for k in 5:
				var y := 6.0 + float(k) * 6.0
				lines.append([Vector2(-34, y + 1.0), Vector2(-10, y - 1.5), Vector2(12, y + 1.5), Vector2(34, y - 1.0)])
			_sl_bands(ci, bp, lines.slice(0, 5, 2), 3.2, Color("c97f3c", 0.8))
			_sl_bands(ci, bp, lines.slice(1, 5, 2), 2.4, Color("f6cf98", 0.9))
		4:
			## 板岩：一块蓝灰色的厚板，侧面一层层的薄片纹
			var c := Vector2(0, 22)
			c = Vector2(0, 18)
			var slab := _st_slab_parts(c, 28, 11, 16, s, SLATE_D, -0.06)
			_sl_begin(ci, slab, rim)
			sil(ci, slab, false)
			_st_layers(ci, c, 28, 11, 16, s, -0.06, 4)
			ln(ci, c + Vector2(-16, -6), c + Vector2(-2, -10), 2.2, Color(1, 1, 1, 0.35), s)
			pl(ci, [c + Vector2(8, -9), c + Vector2(12, -2), c + Vector2(9, 4)], 1.3, Color(INK, 0.35), s + 5)
		5:
			## 石灰石：一大块米白色的石头，身上嵌着几枚小贝壳、几个小坑
			var pts := [Vector2(-32, 34), Vector2(-34, 12), Vector2(-24, -4), Vector2(0, -10), Vector2(24, -4), Vector2(34, 12), Vector2(30, 34)]
			var body := pg(pts, s, Color("e6dcc2"), 0)
			_sl_begin(ci, [body], rim)
			sil(ci, [body], false)
			for q in [[Vector2(-12, 8), 6.0, -0.3], [Vector2(12, 18), 5.0, 0.4], [Vector2(-4, 26), 4.0, 0.1]]:
				var c: Vector2 = q[0]
				var r: float = q[1]
				var fan := [c]
				for k in 7:
					var a := lerpf(-PI + 0.3, -0.3, float(k) / 6.0) + float(q[2])
					fan.append(c + Vector2(cos(a), sin(a)) * r)
				ci.draw_colored_polygon(PackedVector2Array(fan), Color("f6efdf"))
				for k in 4:
					var a := lerpf(-PI + 0.5, -0.5, float(k) / 3.0) + float(q[2])
					ln(ci, c, c + Vector2(cos(a), sin(a)) * r, 1.0, Color("a89a7c", 0.8), s + k)
				pl(ci, fan.slice(1), 1.3, Color("8c7d60", 0.8), s)
			for k in 5:
				ci.draw_circle(Vector2(-24.0 + float(k) * 12.0, 0.0 + float(k % 3) * 10.0), 1.6, Color(INK, 0.25))
		6:
			## 磁铁矿：一块黑亮的石头，顶上吸着一簇竖起来的铁屑
			var c := Vector2(0, 16)
			var body := raw_rock(c, 26, s + 3, Color("3d3d45"), 8, 0.16)
			_sl_begin(ci, [body], rim)
			sil(ci, [body], false)
			hl(ci, c + Vector2(-10, -8), 9, 3, -0.4, 0.45)
			ci.draw_colored_polygon(ell(c + Vector2(8, 6), Vector2(8, 4), s, 0.1, 10, -0.3), Color("6f7a92", 0.6))
			for k in 16:
				var a := lerpf(-PI + 0.6, -0.6, float(k) / 15.0)
				var root := c + Vector2(cos(a) * 18.0, sin(a) * 16.0)
				var d := Vector2(cos(a), sin(a)).rotated((srnd(s + k) - 0.5) * 0.4)
				ln(ci, root, root + d * (6.0 + srnd(s + k * 3) * 5.0), 1.3, Color("5c5f68"), s + k)
		7:
			## 浮石：一大块浅灰的轻石头，满身大大小小的气孔
			var c := Vector2(0, 14)
			var body := raw_rock(c, 29, s + 5, Color("d3cec4"), 9, 0.12)
			_sl_begin(ci, [body], rim)
			sil(ci, [body], false)
			var bp := PackedVector2Array(body[0])
			var n := 0
			for k in 60:
				var p := c + Vector2((srnd(s + k * 3) - 0.5) * 48.0, (srnd(s + k * 3 + 1) - 0.5) * 40.0)
				if n >= 16 or not Geometry2D.is_point_in_polygon(p, bp):
					continue
				## 一个个凹进去的气孔：深色洞、上沿一道阴影、下沿一道亮边
				var r := 2.6 + srnd(s + k * 7) * 3.2
				ci.draw_colored_polygon(ell(p, Vector2(r, r * 0.8), s + k, 0.12, 10), Color("6f685c"))
				ci.draw_arc(p, r, PI + 0.3, TAU - 0.3, 8, Color(INK, 0.55), 1.2, true)
				ci.draw_arc(p, r, 0.4, PI - 0.4, 8, Color(1, 1, 1, 0.6), 1.0, true)
				n += 1
		8:
			## 云母：一叠银亮的薄片，一片片错开，边上闪着光
			var parts := []
			var cfg := []
			for k in 6:
				var c := Vector2(float(k % 2) * 4.0 - 2.0, 30.0 - float(k) * 5.0)
				var pts := []
				for i in 6:
					var a := PI / 3.0 * float(i) + 0.15 * float(k)
					pts.append(c + Vector2(cos(a) * (28.0 - float(k) * 1.5), sin(a) * 9.0))
				var col := Color("e6e1d2") if k % 2 == 0 else Color("d3ccb8")
				cfg.append([pts, col, c])
				var th := []
				for p in pts:
					th.append((p as Vector2) + Vector2(0, 4))
				parts.append(P(Geometry2D.convex_hull(PackedVector2Array(pts + th)), col.darkened(0.08), 2))
			_sl_begin(ci, parts, rim)
			## 整叠先描一圈外轮廓，每片只描细线，免得一层层黑边
			var hull := Geometry2D.convex_hull(PackedVector2Array(parts.reduce(func(acc, p): return acc + Array(p[0]), [])))
			sil(ci, [P(hull, Color("d3ccb8"), 2)], false)
			safe_poly(ci, hull, Color("cfc7b0"))
			for k in 6:
				safe_poly(ci, parts[k][0], (cfg[k][1] as Color).darkened(0.18))
				var q: Array = cfg[k]
				ci.draw_colored_polygon(poly(q[0], s + k, 0.2), q[1])
				outline(ci, poly(q[0], s + k, 0.2), 1.0, Color(INK, 0.45))
				ln(ci, (q[2] as Vector2) + Vector2(-16, 1), (q[2] as Vector2) + Vector2(4, -1), 1.2, Color(1, 1, 1, 0.45), s + k)
			var top: Vector2 = cfg[5][2]
			ln(ci, top + Vector2(-14, -2), top + Vector2(6, -4), 2.4, Color(1, 1, 1, 0.7), s)
			ln(ci, top + Vector2(-6, 2), top + Vector2(10, 0), 1.6, Color(1, 1, 1, 0.5), s + 1)
		9:
			## 花岗岩：一大块粉灰色的花岗岩，满身黑白斑点
			var c := Vector2(0, 12)
			var body := raw_rock(c, 31, s + 2, Color("d6c3b8"), 9, 0.14)
			_sl_begin(ci, [body], rim)
			sil(ci, [body], false)
			_st_speck(ci, body[0], s, 46)
			hl(ci, c + Vector2(-12, -10), 10, 3, -0.4, 0.4)
		10:
			## 大理石：一块白色的大石块，身上几道弯弯曲曲的灰纹
			var pts := [Vector2(-34, 34), Vector2(-38, 8), Vector2(-26, -14), Vector2(4, -20), Vector2(30, -10), Vector2(38, 10), Vector2(32, 34)]
			var body := pg(pts, s, Color("f1eee8"), 0)
			_sl_begin(ci, [body], rim)
			sil(ci, [body], false)
			var face := poly([Vector2(4, -20), Vector2(30, -10), Vector2(38, 10), Vector2(32, 34), Vector2(16, 30), Vector2(12, -4)], s + 1, 0.4)
			ci.draw_colored_polygon(face, Color("dcd8d0"))
			pl(ci, [Vector2(12, -4), Vector2(16, 30)], 1.3, Color(INK, 0.3), s)
			_sl_bands(ci, PackedVector2Array(body[0]), [
				[Vector2(-40, -2), Vector2(-24, 4), Vector2(-14, -2), Vector2(0, 8), Vector2(20, 4), Vector2(40, 14)],
				[Vector2(-40, 20), Vector2(-26, 16), Vector2(-10, 24), Vector2(6, 18), Vector2(40, 30)]], 1.6, Color("8a909a", 0.75))
			_sl_bands(ci, PackedVector2Array(body[0]), [[Vector2(-30, -16), Vector2(-16, -6), Vector2(-20, 10)]], 1.0, Color("8a909a", 0.55))
		11:
			## 岩盐：几块粉色的方块晶体摞在一起，边上透着白
			var cubes := [[Vector2(-14, 22), 12.0, Vector2(7, -7)], [Vector2(14, 22), 11.0, Vector2(6, -6)], [Vector2(-2, 2), 13.0, Vector2(8, -8)], [Vector2(2, 28), 8.0, Vector2(5, -5)]]
			var parts := []
			for q in cubes:
				parts.append(_st_block_part(q[0], q[1], q[1], q[2], Color("f2a7b5")))
			_sl_begin(ci, parts, rim)
			for i in cubes.size():
				var q: Array = cubes[i]
				var c: Vector2 = q[0]
				var hw: float = q[1]
				var v: Vector2 = q[2]
				sil(ci, [parts[i]], false)
				var faces := _st_block_faces(c, hw, hw, v)
				var tones := [Color("f2a7b5"), Color("fbd3db"), Color("d77f93")]
				for f in 3:
					var qp := poly(faces[f], s + i * 3 + f, 0.4)
					ci.draw_colored_polygon(qp, tones[f])
					outline(ci, qp, 1.3)
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-hw, -hw), c + Vector2(-hw * 0.4, -hw), c + Vector2(-hw * 0.8, -hw * 0.4), c + Vector2(-hw, -hw * 0.4)]), Color(1, 1, 1, 0.55))
		12:
			## 玄武岩：几根黑色的天然六棱石柱挤着立在一起，高矮不一
			var cols := [[Vector2(-20, 32), 9.0, 30.0], [Vector2(18, 33), 9.0, 36.0], [Vector2(0, 30), 11.0, 50.0], [Vector2(-8, 36), 8.0, 18.0], [Vector2(9, 37), 8.0, 22.0]]
			var parts := []
			for q in cols:
				parts.append(_sl_column_part(q[0], q[1], q[2], BASALT))
			_sl_begin(ci, parts, rim)
			cols.sort_custom(func(a, b): return a[0].y < b[0].y)
			for i in cols.size():
				var q: Array = cols[i]
				_sl_column(ci, q[0], q[1], q[2], BASALT if i % 2 == 0 else BASALT_L, s + i)
		13:
			## 菊石化石：一块灰黄的石头，正面嵌着一个螺旋形的菊石，开始带一点光
			glow(ci, Vector2(0, 8), 40, Color("f6e6c0"))
			var pts := [Vector2(-36, 34), Vector2(-40, 8), Vector2(-28, -16), Vector2(2, -22), Vector2(30, -12), Vector2(40, 10), Vector2(34, 34)]
			var body := pg(pts, s, Color("b9ab90"), 0)
			_sl_begin(ci, [body], rim)
			sil(ci, [body], false)
			var c := Vector2(2, 8)
			var shell := ell(c, Vector2(22, 20), s, 0.02, 24)
			ci.draw_colored_polygon(shell, Color("ead7ae"))
			outline(ci, shell, 2.0)
			var spiral := []
			for k in 60:
				var th := float(k) / 59.0 * TAU * 2.6
				var r := 20.0 * exp(-0.19 * th)
				spiral.append(c + Vector2(cos(th + 0.6), sin(th + 0.6) * 0.92) * r)
			pl(ci, spiral, 2.0, Color("8c6f44"), s)
			for k in range(2, 58, 3):
				var p: Vector2 = spiral[k]
				ln(ci, p, p.lerp(c, 0.22), 1.1, Color("a6875a", 0.8), s + k)
			hl(ci, c + Vector2(-8, -10), 7, 2.4, -0.5, 0.5)
		14:
			## 熔岩石：一块黑石头，身上裂着几道发红光的缝
			glow(ci, Vector2(0, 8), 46, Color("ffb070"))
			var c := Vector2(0, 8)
			var body := raw_rock(c, 34, s + 4, Color("2f2b2d"), 9, 0.14)
			_sl_begin(ci, [body], rim)
			sil(ci, [body], false)
			var cracks := [[Vector2(-24, -8), Vector2(-10, 2), Vector2(-14, 14), Vector2(0, 24)], [Vector2(-10, 2), Vector2(8, -2), Vector2(20, -14)],
				[Vector2(8, -2), Vector2(14, 12), Vector2(26, 18)], [Vector2(-14, 14), Vector2(-28, 18)]]
			for cr in cracks:
				pl(ci, cr, 5.0, Color("ff6a1f", 0.55), s)
				pl(ci, cr, 2.6, Color("ffb23d"), s)
				pl(ci, cr, 1.0, Color("fff2b0"), s)
			hl(ci, c + Vector2(-14, -16), 9, 3, -0.4, 0.3)
			sparks(ci, [Vector2(30, -22)], 4)
		15:
			## 陨石：一块深色发亮的金属石头，表面一个个像拇指按出来的浅坑，带着冷光
			glow(ci, Vector2(0, 6), 52, Color("d8e4ff"))
			var c := Vector2(0, 6)
			var pts := []
			for k in 14:
				var a := TAU * float(k) / 14.0
				var m := 1.0 + 0.1 * sin(a * 3.0 + 0.6) + 0.05 * sin(a * 5.0)
				pts.append(c + Vector2(cos(a) * 36.0, sin(a) * 28.0) * m)
			var body := pg(pts, s, Color("5b5852"), 0)
			_sl_begin(ci, [body], rim)
			sil(ci, [body], false)
			var bp := PackedVector2Array(body[0])
			for k in 14:
				var p := c + Vector2((srnd(s + k * 5) - 0.5) * 58.0, (srnd(s + k * 5 + 1) - 0.5) * 44.0)
				if Geometry2D.is_point_in_polygon(p, bp):
					var e := ell(p, Vector2(5.0 + srnd(s + k) * 3.0, 3.5 + srnd(s + k + 2) * 2.0), s + k, 0.15, 10, srnd(s + k * 3) * PI)
					ci.draw_colored_polygon(e, Color("47443f"))
					ci.draw_arc(p + Vector2(0.5, 0.5), 3.5, 0.2, 2.4, 6, Color(1, 1, 1, 0.25), 1.0, true)
			## 一片磨亮的金属面
			var cut := poly([c + Vector2(6, -18), c + Vector2(26, -10), c + Vector2(24, 4), c + Vector2(8, -2)], s + 9, 0.3)
			ci.draw_colored_polygon(cut, Color("c9ccd2"))
			outline(ci, cut, 1.4)
			ln(ci, c + Vector2(10, -14), c + Vector2(22, -8), 1.6, Color(1, 1, 1, 0.8), s)
			sparks(ci, [Vector2(-32, -24), Vector2(34, -26), Vector2(38, 14)], 4)
		_:
			## 恐龙化石：一大块黄褐色石板，里面露出一个恐龙头骨，光最亮
			glow(ci, Vector2(0, 4), 60, Color("ffe7a8"))
			var pts := [Vector2(-42, 34), Vector2(-46, 6), Vector2(-38, -20), Vector2(-8, -28), Vector2(26, -24), Vector2(44, -6), Vector2(46, 18), Vector2(40, 34)]
			var body := pg(pts, s, Color("c8b08a"), 0)
			_sl_begin(ci, [body], rim)
			sil(ci, [body], false)
			var o := Vector2(0, 4)
			var skull := [Vector2(-32, 2), Vector2(-24, -6), Vector2(-6, -14), Vector2(12, -18), Vector2(26, -12), Vector2(32, 0), Vector2(26, 10),
				Vector2(12, 12), Vector2(-6, 10), Vector2(-30, 8)]
			var sk := poly(rot_pts(skull, -0.05, o), s + 1, 0.3)
			ci.draw_colored_polygon(sk, Color("f2e6c6"))
			outline(ci, sk, 2.0)
			## 下颌
			var jaw := poly(rot_pts([Vector2(-28, 10), Vector2(-6, 12), Vector2(14, 14), Vector2(24, 12), Vector2(20, 18), Vector2(0, 20), Vector2(-24, 16)], -0.05, o), s + 2, 0.3)
			ci.draw_colored_polygon(jaw, Color("e8d9b4"))
			outline(ci, jaw, 1.8)
			## 牙
			for k in 7:
				var x := -26.0 + float(k) * 6.0
				var tp := rot_pts([Vector2(x, 9), Vector2(x + 2.4, 13), Vector2(x + 4.8, 9)], -0.05, o)
				ci.draw_colored_polygon(PackedVector2Array(tp), Color("fffaf0"))
				pl(ci, tp, 1.0, Color(INK, 0.6), s + k)
			## 眼眶、鼻孔、颅骨上的孔
			var eye: Vector2 = rot_pts([Vector2(12, -6)], -0.05, o)[0]
			ci.draw_colored_polygon(ell(eye, Vector2(5.5, 5), s, 0.05, 12), Color("5a4630"))
			ci.draw_colored_polygon(ell(rot_pts([Vector2(-24, -1)], -0.05, o)[0], Vector2(2.6, 2), s + 1, 0.05, 8), Color("5a4630"))
			ci.draw_colored_polygon(ell(rot_pts([Vector2(22, -2)], -0.05, o)[0], Vector2(4, 5), s + 2, 0.05, 10), Color("5a4630"))
			## 后面几节颈椎
			for k in 3:
				var p := o + Vector2(36.0 + float(k) * 0.0, -2.0 + float(k) * 9.0)
				var vb := ell(p, Vector2(4.5, 3.5), s + k, 0.05, 10)
				ci.draw_colored_polygon(vb, Color("f2e6c6"))
				outline(ci, vb, 1.4)
			hl(ci, o + Vector2(-10, -10), 8, 2.4, -0.3, 0.5)
			sparks(ci, [Vector2(-36, -30), Vector2(36, -32), Vector2(42, 22), Vector2(-44, 20)], 5)

## 第 7 版石料（燧石 / 板岩 / 花岗岩 / 玄武岩各 4 级，用户觉得换段处像别的产线），留着备用
static func _main_art_v7(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			## 燧石子：一小颗燧石结核，外面白石皮，磕掉一小块露出黑芯
			var c := Vector2(0, 24)
			sil(ci, [pg(_st_nod_pts(c, 16, s), s, CORTEX, 1)], rim)
			_st_nod_det(ci, c, 16, s)
		2:
			## 燧石结核：一大颗疙疙瘩瘩的结核，两处磕开露出黑芯
			var c := Vector2(0, 14)
			sil(ci, [pg(_st_nod_pts(c, 28, s), s, CORTEX, 1)], rim)
			_st_nod_det(ci, c, 28, s)
			var w := ell(c + Vector2(-14, 10), Vector2(7, 5), s + 3, 0.1, 10, 0.4)
			safe_poly(ci, w, FLINT_N)
			outline(ci, w, 1.4)
		3:
			## 敲开的燧石：结核一敲两半，左边半块露出黑亮的断面，右边半块翻着白皮，地上两片碎屑
			var a := Vector2(-12, 16)
			var b := Vector2(20, 24)
			var right := pg(_st_nod_pts(b, 17, s + 9), s + 9, CORTEX, 1)
			var left := _st_half_parts(a, 24, s)
			if rim:
				_st_rim(ci, [right] + left)
			sil(ci, [right], false)
			_st_nod_det(ci, b, 17, s + 9, false)
			pl(ci, [b + Vector2(-15, -6), b + Vector2(-17, 4), b + Vector2(-13, 12)], 1.4, Color(INK, 0.4), s)
			sil(ci, left, false)
			_st_half_det(ci, a, 24, s)
			_st_flint_pile(ci, [[Vector2(-30, 36), 6.0, 3.5], [Vector2(6, 38), 5.0, 3.0]], s + 20, false)
		4:
			## 一堆燧石片：敲下来的一堆黑亮石片，有几片边上还带白皮
			_st_flint_pile(ci, [[Vector2(-18, 30), 15.0, 9.0], [Vector2(12, 32), 16.0, 9.0], [Vector2(-2, 20), 17.0, 10.0], [Vector2(-10, 8), 13.0, 8.0],
				[Vector2(14, 12), 12.0, 7.5], [Vector2(30, 28), 10.0, 6.0], [Vector2(-32, 32), 9.0, 6.0], [Vector2(2, 0), 10.0, 6.5]], s, rim)
		5:
			## 板岩片：一块薄板岩搁在兽皮上
			var hide := _st_hide(Vector2(0, 32), 40, 10, s)
			var slab := _st_slab_parts(Vector2(0, 22), 28, 11, 5, s + 3, SLATE, -0.05)
			if rim:
				_st_rim(ci, [hide] + slab)
			sil(ci, [hide], false)
			_st_hide_det(ci, Vector2(0, 32), 40, 10, s)
			_st_slate(ci, Vector2(0, 22), 28, 11, 5, s + 3, SLATE, -0.05)
		6:
			## 两片板岩：两块深一点的板岩错开叠着
			var hide := _st_hide(Vector2(0, 32), 44, 11, s)
			var a := _st_slab_parts(Vector2(6, 26), 30, 11, 6, s + 3, SLATE_D, 0.06)
			var b := _st_slab_parts(Vector2(-6, 16), 28, 11, 6, s + 7, SLATE_D.lightened(0.06), -0.08)
			if rim:
				_st_rim(ci, [hide] + a + b)
			sil(ci, [hide], false)
			_st_hide_det(ci, Vector2(0, 32), 44, 11, s)
			_st_slate(ci, Vector2(6, 26), 30, 11, 6, s + 3, SLATE_D, 0.06)
			_st_slate(ci, Vector2(-6, 16), 28, 11, 6, s + 7, SLATE_D.lightened(0.06), -0.08)
		7:
			## 一摞板岩：四块板岩摞起来，用藤绳十字捆着
			var hide := _st_hide(Vector2(0, 33), 46, 11, s)
			var cfg := []
			var all := [hide]
			for k in 4:
				var c := Vector2(float(k % 2) * 5.0 - 2.5, 26.0 - float(k) * 9.0)
				var rot := 0.05 * float(k % 2 * 2 - 1)
				var col := SLATE.darkened(0.04 * float(k % 2))
				cfg.append([c, 31.0 - float(k) * 1.5, rot, col])
				all.append_array(_st_slab_parts(c, cfg[k][1], 11, 6, s + k * 4, col, rot))
			if rim:
				_st_rim(ci, all)
			sil(ci, [hide], false)
			_st_hide_det(ci, Vector2(0, 33), 46, 11, s)
			for k in 4:
				var q: Array = cfg[k]
				_st_slate(ci, q[0], q[1], 11, 6, s + k * 4, q[3], q[2])
			var top: Vector2 = cfg[3][0]
			_st_rope(ci, [top + Vector2(-26, 3), top + Vector2(0, 1), top + Vector2(25, -2)], s)
			_st_rope(ci, [top + Vector2(-4, -9), top + Vector2(-1, 1), top + Vector2(0, 12), Vector2(1, 38)], s + 1)
			_st_rope(ci, [Vector2(-30, 14), Vector2(-31, 34)], s + 2)
			_st_rope(ci, [Vector2(29, 8), Vector2(30, 30)], s + 3)
		8:
			## 大块板岩：一整块厚板岩，侧面能看到一层层的页理，压在大兽皮上
			var hide := _st_hide(Vector2(0, 33), 48, 12, s)
			var c := Vector2(0, 12)
			var slab := _st_slab_parts(c, 38, 15, 16, s + 3, SLATE_D, -0.04)
			if rim:
				_st_rim(ci, [hide] + slab)
			sil(ci, [hide], false)
			_st_hide_det(ci, Vector2(0, 33), 48, 12, s)
			sil(ci, slab, false)
			_st_layers(ci, c, 38, 15, 16, s + 3, -0.04, 4)
			ln(ci, c + Vector2(-22, -6), c + Vector2(-6, -11), 2.4, Color(1, 1, 1, 0.3), s)
			pl(ci, [c + Vector2(10, -10), c + Vector2(16, -2), c + Vector2(12, 6)], 1.3, Color(INK, 0.35), s + 5)
		9, 10, 11, 12:
			_granite(ci, lv, s, rim)
		_:
			_basalt(ci, lv, s, rim)

## 花岗岩 9~12 级：都放在木橇上
static func _granite(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	var x0 := -40.0
	var x1 := 36.0
	var y := 36.0
	var back := _st_sled_back(x0, x1, y, s + 40)
	var bars := _st_sled_bars(x0, x1, y, s + 44)
	var front := _st_sled_front(x0, x1, y, s + 48)
	var body := []
	match lv:
		9:
			body = [raw_rock(Vector2(-2, 12), 26, s, GRANITE, 8, 0.18)]
		10:
			body = [pg([Vector2(-38, 30), Vector2(-42, 6), Vector2(-30, -16), Vector2(-4, -26), Vector2(22, -20), Vector2(38, -2), Vector2(40, 20), Vector2(30, 30)], s, GRANITE_W, 0)]
		11:
			body = [_st_block_part(Vector2(-6, 12), 28, 18, Vector2(10, -12), GRANITE)]
		_:
			var v := Vector2(6, -8)
			for q in [[Vector2(2, -6), 16.0, 10.0], [Vector2(-14, 16), 16.0, 10.0], [Vector2(18, 16), 16.0, 10.0]]:
				body.append(_st_block_part(q[0], q[1], q[2], v, GRANITE_W))
	if rim:
		_st_rim(ci, back + bars + front + body)
	sil(ci, back, false)
	sil(ci, bars, false)
	sil(ci, front, false)
	match lv:
		9:
			## 花岗岩块：一块圆滚滚的浅灰花岗岩，满身黑白斑点
			sil(ci, body, false)
			_st_speck(ci, body[0][0], s, 26)
			hl(ci, Vector2(-12, 0), 9, 3, -0.4, 0.4)
		10:
			## 花岗岩毛石：刚撬下来的大块粉灰花岗岩，一面是新鲜的断口
			sil(ci, body, false)
			var face := poly([Vector2(-4, -26), Vector2(22, -20), Vector2(38, -2), Vector2(16, 4), Vector2(-2, -6)], s + 1, 0.5)
			ci.draw_colored_polygon(face, GRANITE_W.lightened(0.2))
			outline(ci, face, 1.6)
			ci.draw_colored_polygon(poly([Vector2(38, -2), Vector2(40, 20), Vector2(30, 30), Vector2(18, 22), Vector2(16, 4)], s + 2, 0.5), GRANITE_W.darkened(0.14))
			pl(ci, [Vector2(16, 4), Vector2(18, 22), Vector2(30, 30)], 1.4, Color(INK, 0.35), s)
			_st_speck(ci, body[0][0], s, 40)
			_st_crack(ci, [Vector2(-28, -4), Vector2(-22, 8), Vector2(-26, 22)], 1.2, s + 3)
		11:
			## 凿方的花岗岩：凿成方块，面上留着一道道凿痕
			_st_block(ci, Vector2(-6, 12), 28, 18, Vector2(10, -12), s, GRANITE, 5)
			_st_speck(ci, body[0][0], s, 40)
		_:
			## 一垛方石：两块并排、上面再压一块，用藤绳捆在木橇上
			var v := Vector2(6, -8)
			var cfg := [[Vector2(-14, 16), 16.0, 10.0], [Vector2(18, 16), 16.0, 10.0], [Vector2(2, -6), 16.0, 10.0]]
			for i in 3:
				var q: Array = cfg[i]
				var col := GRANITE_W if i % 2 == 0 else GRANITE_W.darkened(0.06)
				_st_block(ci, q[0], q[1], q[2], v, s + i * 3, col, 2)
				_st_speck(ci, _st_block_part(q[0], q[1], q[2], v, col)[0], s + i * 7, 18)
			_st_rope(ci, [Vector2(-31, 6), Vector2(-14, 4), Vector2(-12, -16), Vector2(2, -17), Vector2(18, -16), Vector2(20, 4), Vector2(35, 6)], s)
			_st_rope(ci, [Vector2(-31, 6), Vector2(-31, 30)], s + 1)
			_st_rope(ci, [Vector2(35, 6), Vector2(35, 30)], s + 2)

## 玄武岩 13~16 级：放在圆木滚子上，拉绳拖着
static func _basalt(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		13:
			## 玄武岩短柱：一根天然六棱的黑石柱，平躺在两根滚子上
			var c := Vector2(24, 6)
			_basalt_cols(ci, [[c, 22.0, 40.0, BASALT]], [-24.0, 30.0], s, rim, [])
		14:
			## 两根玄武岩柱：一前一后两根并排躺着
			_basalt_cols(ci, [[Vector2(36, -2), 16.0, 58.0, BASALT_L], [Vector2(28, 16), 16.0, 56.0, BASALT]], [-36.0, 38.0], s, rim, [])
		15:
			## 玄武岩长柱：一根长长的六棱柱躺在三根滚子上，前头拴着拉绳
			var c := Vector2(40, 10)
			var rope := [Vector2(42, 6), Vector2(47, 12), Vector2(48, 24), Vector2(44, 34)]
			_basalt_cols(ci, [[c, 19.0, 84.0, BASALT]], [-46.0, 44.0], s, rim, rope)
		_:
			## 巨石：全线最大的一块粗糙巨石，压着三根滚子，两道拉绳，背后一圈淡光
			glow(ci, Vector2(0, 0), 62, Color("f3e2b0"))
			var body := pg([Vector2(-46, 22), Vector2(-48, 2), Vector2(-38, -22), Vector2(-12, -34), Vector2(16, -32), Vector2(38, -20), Vector2(48, 0), Vector2(46, 22), Vector2(30, 28), Vector2(-30, 28)], s, BASALT_L, 0)
			var lb := _st_logs_back(-44, 40, 36, s + 30)
			var lf := _st_logs_front(-46, 40, 37, s + 33)
			if rim:
				_st_rim(ci, lb + lf + [body])
			sil(ci, lb, false)
			sil(ci, [body], false)
			sil(ci, lf, false)
			_st_logs_det(ci, -46, 40, 37, s)
			var face := poly([Vector2(-12, -34), Vector2(16, -32), Vector2(38, -20), Vector2(14, -10), Vector2(-14, -16)], s + 1, 0.5)
			ci.draw_colored_polygon(face, BASALT_L.lightened(0.22))
			outline(ci, face, 1.6)
			ci.draw_colored_polygon(poly([Vector2(38, -20), Vector2(48, 0), Vector2(46, 22), Vector2(30, 28), Vector2(20, 8), Vector2(14, -10)], s + 2, 0.5), BASALT_L.darkened(0.2))
			pl(ci, [Vector2(14, -10), Vector2(20, 8), Vector2(30, 28)], 1.4, Color(INK, 0.4), s)
			_st_crack(ci, [Vector2(-30, -16), Vector2(-24, -2), Vector2(-30, 12)], 1.4, s + 3)
			for k in 8:
				ci.draw_circle(Vector2(-36.0 + float(k) * 8.0, 8.0 + float(k % 3) * 5.0), 1.2, Color(INK, 0.3))
			sil(ci, [ov(Vector2(-26, -24), 8, 3, s + 5, MOSS, -0.4, 2)], false)
			## 两道拉绳绕过巨石，往右下拖出去
			## 一道拉绳绕过巨石前头，往右下拖出去
			_st_rope(ci, [Vector2(30, -24), Vector2(37, -4), Vector2(36, 24)], s + 7)
			_st_rope(ci, [Vector2(37, -4), Vector2(46, 6), Vector2(50, 24), Vector2(46, 38)], s + 8)
			sparks(ci, [Vector2(-44, -30), Vector2(42, -34)], 4)

## 画几根平躺的六棱柱 + 底下的滚子（滚子的高度贴着第一根柱子的底边）
static func _basalt_cols(ci: CanvasItem, cols: Array, xs: Array, s: int, rim: bool, rope: Array) -> void:
	var main: Array = cols[cols.size() - 1]
	var y := _st_hex_bottom(main[0], main[1], main[2], main[0].x) + 3.0
	var x0: float = xs[0]
	var x1: float = xs[xs.size() - 1]
	var lb := _st_logs_back(x0, x1, y, s + 30)
	var lf := _st_logs_front(x0 - 2.0, x1, y + 1.0, s + 33)
	var parts := lb + lf
	for q in cols:
		parts.append(_st_hex_part(q[0], q[1], q[2], q[3]))
	if rim:
		_st_rim(ci, parts)
	sil(ci, lb, false)
	for i in cols.size():
		var q: Array = cols[i]
		_st_hex(ci, q[0], q[1], q[2], s + i * 11, q[3])
	sil(ci, lf, false)
	_st_logs_det(ci, x0 - 2.0, x1, y + 1.0, s)
	if not rope.is_empty():
		_st_rope(ci, rope, s + 50)

## 第 6 版石料（石片…盖顶巨石，工具零件 + 建筑石料），2026-11-26 换成四种石头的新版，留着备用
static func _main_art_v6(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
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

# ---------------------------------------------------------------- 宝石原石第 3 版：12 级各是一种宝石
## 前面是常见的，后面是公认名贵的；相邻两级颜色、外形都跳开。都是原石：不切面、不镶、不打孔。
## 第 5 级起长在石底上，第 8 级起带光，越往后越亮。

const SUB_SCALE_V3 := [0.95, 0.95, 0.95, 0.95, 1.0, 1.0, 0.95, 1.0, 1.08, 1.25, 1.05, 1.1]
const AGATE_CRUST := Color("a08c78")
const GM_AMBER := Color("f0a336")
const MALA := Color("34a86a")
const LAPIS := Color("2c4cab")
const OPAL := Color("e8eef1")
const EMERALD := Color("2fbf71")
const SAPPH := Color("2a5ccc")
const RUBY := Color("e0284f")
const MATRIX_G := Color("9a958d")
const MATRIX_W := Color("e2dacb")

## 各级都先把所有零件收齐，再一起画白边，然后按顺序画
static func _gm_rim(ci: CanvasItem, parts: Array, rim: bool) -> void:
	if rim:
		_st_rim(ci, parts)

## 一颗扁平的六角片状晶体（红宝石那种），斜着看
static func _gm_plate(c: Vector2, r: float, ang: float) -> Array:
	var out := []
	for i in 6:
		var a := PI / 3.0 * float(i) + 0.3
		out.append(c + Vector2(cos(a) * r, sin(a) * r * 0.55).rotated(ang))
	return out

## 平顶六棱柱（祖母绿那种）
static func _gm_prism(c: Vector2, w: float, h: float, ang: float) -> Array:
	return rot_pts([Vector2(-w, 0), Vector2(-w, -h), Vector2(-w * 0.45, -h - w * 0.4), Vector2(w * 0.45, -h - w * 0.4), Vector2(w, -h), Vector2(w, 0)], ang, c)

# ---------------------------------------------------------------- 宝石原石第 4 版：每级一种宝石，但都长在同一种灰石头上
## 升级感靠"石头里露出来的宝石越来越多、越来越透、越来越亮"：
## 1~3 灰石头上露出一小块；4~6 宝石占了半块石头；7~9 晶簇从石底长出来，开始发光；10~14 一颗大晶体，石底只剩一小块，越往后越亮。

const SUB_SCALE := [0.961, 1.036, 0.962, 0.938, 0.976, 0.861, 1.010, 0.943, 1.057, 1.040, 1.194, 1.033, 1.018, 1.028]
const CITRINE := Color("f2c23a")

static func _gm_rock(c: Vector2, r: float, s: int) -> Array:
	return raw_rock(c, r, s, MATRIX_G, 8, 0.14)

static func _gm_rock_det(ci: CanvasItem, c: Vector2, r: float, s: int) -> void:
	for k in 5:
		ci.draw_circle(c + Vector2((srnd(s + k * 3) - 0.5) * r * 1.3, (srnd(s + k * 3 + 1) - 0.1) * r * 0.6), 1.2, Color(INK, 0.25))
	hl(ci, c + Vector2(-r * 0.45, -r * 0.35), r * 0.25, r * 0.08, -0.4, 0.35)

const FLUOR := Color("9a74e0")
## 八面体四个面的颜色（亮 → 暗）和棱线色
const DIAM_TONES := [Color("fbfeff"), Color("cfe5f1"), Color("b9d6e7"), Color("98bdd6"), Color("6f93ad"), Color("e4f2fa")]
const PINK_TONES := [Color("fff0f6"), Color("ffc2dc"), Color("f7a6c8"), Color("e07aa8"), Color("b0507e"), Color("ffd0e4")]
const BLUE_TONES := [Color("eef6ff"), Color("a9cdfb"), Color("84b4f2"), Color("4f86d8"), Color("2f5aa0"), Color("bcd8fb")]

## 萤石立方晶：正面紫、顶面浅紫、侧面深紫，正面下半截一道绿
static func _gm_cube(ci: CanvasItem, c: Vector2, hw: float, v: Vector2, s: int) -> void:
	sil(ci, [_st_block_part(c, hw, hw, v, FLUOR)], false)
	var faces := _st_block_faces(c, hw, hw, v)
	var tones := [FLUOR, FLUOR.lightened(0.35), FLUOR.darkened(0.25)]
	for i in 3:
		var q := poly(faces[i], s + i, 0.4)
		ci.draw_colored_polygon(q, tones[i])
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-hw, hw * 0.25), c + Vector2(hw, hw * 0.25), c + Vector2(hw, hw), c + Vector2(-hw, hw)]), Color("7bd9a8", 0.85))
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(hw, hw * 0.25), c + Vector2(hw, hw * 0.25) + v, c + Vector2(hw, hw) + v, c + Vector2(hw, hw)]), Color("4fae80", 0.85))
	for i in 3:
		outline(ci, poly(faces[i], s + i, 0.4), 1.4)
	ln(ci, c + Vector2(-hw * 0.6, -hw * 0.6), c + Vector2(-hw * 0.6, hw * 0.1), 1.6, Color(1, 1, 1, 0.55), s)

## 带颜色的天然八面体：tones = [四个面由亮到暗, 棱线, 剪影底色]
static func _gm_octa(ci: CanvasItem, c: Vector2, r: float, ang: float, s: int, tones: Array) -> void:
	sil(ci, [pg(_st_octa(c, r, ang).slice(0, 4), s, tones[5], 2)], false)
	var v := _st_octa(c, r, ang)
	var q := []
	for p in v:
		q.append(c + ((p as Vector2) - c) * 0.93)
	ci.draw_colored_polygon(PackedVector2Array([q[0], q[3], q[4]]), tones[0])
	ci.draw_colored_polygon(PackedVector2Array([q[0], q[4], q[1]]), tones[1])
	ci.draw_colored_polygon(PackedVector2Array([q[3], q[2], q[4]]), tones[2])
	ci.draw_colored_polygon(PackedVector2Array([q[4], q[2], q[1]]), tones[3])
	for k in 4:
		ln(ci, v[4], v[k], 1.3, Color(tones[4], 0.85), s + k)
	ci.draw_colored_polygon(star_pts((v[0] as Vector2).lerp(v[3], 0.35), r * 0.22, r * 0.07, 4, s), Color.WHITE)

## 钻石类：石底 + 一颗大八面体 + 几颗小的，石沿盖住根部。small = [[中心, 半径, 角度], …]
static func _gm_diamond(ci: CanvasItem, s: int, rim: bool, tones: Array, r: float, small: Array, glow_col: Color, glow_r: float) -> void:
	glow(ci, Vector2(0, 2), glow_r, glow_col)
	var c := Vector2(0, 0)
	var rock := _gm_base()
	var parts := [rock, pg(_st_octa(c, r, 0.12).slice(0, 4), s, tones[5], 2)]
	for q in small:
		parts.append(pg(_st_octa(q[0], q[1], q[2]).slice(0, 4), s, tones[5], 2))
	_gm_rim(ci, parts, rim)
	sil(ci, [rock], false)
	_gm_octa(ci, c, r, 0.12, s, tones)
	for i in small.size():
		var q: Array = small[i]
		_gm_octa(ci, q[0], q[1], q[2], s + 7 + i, DIAM_TONES if tones == BLUE_TONES else tones)
	_gm_lip(ci, s)

## 三角双晶：圆钝的三角形厚片，正面一块小三角平面，三边斜棱面
static func _gm_macle_pts(c: Vector2, r: float) -> Array:
	var out := []
	for i in 3:
		var a := -PI * 0.5 + TAU * float(i) / 3.0
		var d := Vector2(cos(a), sin(a) * 0.85)
		var side := Vector2(-d.y, d.x)
		out.append(c + d * r + side * r * 0.16)
		out.append(c + d * r - side * r * 0.16)
	var hull := Geometry2D.convex_hull(PackedVector2Array(out))
	hull.remove_at(hull.size() - 1)
	return Array(hull)

## 菱形十二面体（正面看）：六边形外轮廓，里面一圈六块菱面围着中间一块平面
static func _gm_dodeca_pts(c: Vector2, r: float) -> Array:
	var out := []
	for i in 6:
		var a := -PI * 0.5 + TAU * float(i) / 6.0
		out.append(c + Vector2(cos(a), sin(a)) * r)
	return out

## 大颗宝石放在石底上：shape 是 "macle"（三角双晶）或 "dodeca"（十二面体）
static func _gm_gem_on_base(ci: CanvasItem, s: int, rim: bool, shape: String, tones: Array, r: float, glow_col: Color, glow_r: float) -> void:
	glow(ci, Vector2(0, 2), glow_r, glow_col)
	var c := Vector2(0, 0)
	var outer := _gm_macle_pts(c, r) if shape == "macle" else _gm_dodeca_pts(c, r)
	var thick := []
	if shape == "macle":
		for p in outer:
			thick.append((p as Vector2) + Vector2(0, 7))
	var rock := _gm_base()
	var body := P(Geometry2D.convex_hull(PackedVector2Array(outer + thick)), tones[5], 2)
	_gm_rim(ci, [rock, body], rim)
	sil(ci, [rock], false)
	sil(ci, [body], false)
	var n := outer.size()
	if shape == "macle":
		## 厚度那一圈侧面
		for i in n:
			var a: Vector2 = outer[i]
			var b: Vector2 = outer[(i + 1) % n]
			if (a + b).y * 0.5 > c.y - r * 0.2:
				ci.draw_colored_polygon(PackedVector2Array([a, b, b + Vector2(0, 7), a + Vector2(0, 7)]), tones[3])
	## 中间平面
	var k := 0.45 if shape == "macle" else 0.5
	var inner := []
	for p in outer:
		inner.append(c + ((p as Vector2) - c) * k + Vector2(-r * 0.04, -r * 0.04))
	## 一圈棱面：按朝向分亮暗（左上亮、右下暗）
	for i in n:
		var a: Vector2 = outer[i]
		var b: Vector2 = outer[(i + 1) % n]
		var mid := ((a + b) * 0.5 - c).normalized()
		var lit := clampf(0.5 - 0.5 * (mid.x * 0.6 + mid.y * 0.8), 0.0, 1.0)
		var col: Color = (tones[3] as Color).lerp(tones[1], lit)
		ci.draw_colored_polygon(PackedVector2Array([a, b, inner[(i + 1) % n], inner[i]]), col)
		ln(ci, a, inner[i], 1.2, Color(tones[4], 0.8), s + i)
	ci.draw_colored_polygon(PackedVector2Array(inner), tones[0])
	outline(ci, PackedVector2Array(inner), 1.3, Color(tones[4], 0.85))
	outline(ci, PackedVector2Array(outer), 2.2)
	ci.draw_colored_polygon(star_pts((inner[0] as Vector2).lerp(inner[n - 1], 0.5), r * 0.2, r * 0.065, 4, s), Color.WHITE)
	hl(ci, c + Vector2(-r * 0.25, -r * 0.2), r * 0.18, r * 0.06, -0.5, 0.6)
	_gm_lip(ci, s)

## 大晶体的石底：后面一块宽石头，晶体画完再盖一道石沿，像是从石头里长出来
static func _gm_base() -> Array:
	return _gm_rock(Vector2(0, 31), 26, 77)

static func _gm_lip(ci: CanvasItem, s: int) -> void:
	sil(ci, [ov(Vector2(0, 35), 21, 6, s, MATRIX_G.darkened(0.04), 0.0, 1)], false, 2.4)
	for k in 4:
		ci.draw_circle(Vector2(-14.0 + float(k) * 9.0, 36.0 + float(k % 2) * 1.5), 1.1, Color(INK, 0.25))

## 平顶六棱柱的明暗和高光
static func _gm_prism_det(ci: CanvasItem, c: Vector2, w: float, h: float, a: float, col: Color, s: int) -> void:
	ci.draw_colored_polygon(poly(rot_pts([Vector2(0, 0), Vector2(0, -h), Vector2(w * 0.45, -h - w * 0.4), Vector2(w, -h), Vector2(w, 0)], a, c), s), Color(0, 0, 0, 0.14))
	ln(ci, c, c + Vector2(0, -h).rotated(a), 1.4, Color(col.darkened(0.45), 0.7), s)
	ci.draw_colored_polygon(poly(rot_pts([Vector2(-w * 0.75, -3), Vector2(-w * 0.75, -h + 3), Vector2(-w * 0.3, -h + 1), Vector2(-w * 0.3, -3)], a, c), s), Color(1, 1, 1, 0.35))

static func _sub_art(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			## 绿松石：灰石头正面露出一块蓝绿色，带褐色细网纹
			var c := Vector2(0, 18)
			var rock := _gm_rock(c, 27, s + 9)
			sil(ci, [rock], rim)
			_gm_rock_det(ci, c, 27, s)
			var gc := c + Vector2(4, -2)
			var patch := poly(_st_nod_pts(gc, 14, s + 4), s, 0.4)
			sil(ci, [P(patch, TURQ, 0)], false, 2.0)
			for k in 4:
				var a := gc + Vector2((srnd(s + k * 4) - 0.5) * 16.0, (srnd(s + k * 4 + 1) - 0.5) * 12.0)
				pl(ci, [a, a + Vector2(4, -2), a + Vector2(8, 1)], 1.2, Color(MATRIX.darkened(0.2), 0.8), s + k)
		2:
			## 粉水晶：灰石头顶上掰开一块，露出一大块粉色半透明的水晶
			var c := Vector2(0, 20)
			var rock := _gm_rock(c, 27, s + 9)
			var gc := c + Vector2(3, -12)
			var chunk := [gc + Vector2(-16, 8), gc + Vector2(-14, -6), gc + Vector2(-4, -14), gc + Vector2(8, -12), gc + Vector2(16, -2), gc + Vector2(14, 9)]
			var gem := pg(chunk, s, Color("f5a3c0"), 1)
			_gm_rim(ci, [rock, gem], rim)
			sil(ci, [rock], false)
			_gm_rock_det(ci, c + Vector2(0, 6), 22, s)
			sil(ci, [gem], false)
			## 几个断面：左亮、右暗
			ci.draw_colored_polygon(poly([gc + Vector2(-14, -6), gc + Vector2(-4, -14), gc + Vector2(-2, -2), gc + Vector2(-12, 4)], s + 1, 0.3), Color("ffd0e0"))
			ci.draw_colored_polygon(poly([gc + Vector2(8, -12), gc + Vector2(16, -2), gc + Vector2(14, 9), gc + Vector2(4, 4)], s + 2, 0.3), Color("e07fa3"))
			pl(ci, [gc + Vector2(-4, -14), gc + Vector2(-2, -2), gc + Vector2(4, 4), gc + Vector2(8, -12)], 1.3, Color("b45a80", 0.7), s)
			ci.draw_circle(gc + Vector2(-9, -6), 2.0, Color(1, 1, 1, 0.85))
		3:
			## 孔雀石：石头上半截长满了鼓包状的绿石头，一圈圈深浅绿纹
			var c := Vector2(0, 26)
			var rock := _gm_rock(c, 26, s + 9)
			var bumps := [[Vector2(-14, 10), 11.0], [Vector2(12, 10), 12.0], [Vector2(-1, 2), 13.0], [Vector2(0, 16), 11.0], [Vector2(-22, 18), 7.0], [Vector2(22, 19), 7.0]]
			var parts := [rock]
			for i in bumps.size():
				var q: Array = bumps[i]
				parts.append(ov(q[0], q[1], q[1] * 0.92, s + i, MALA, 0.0, 1))
			_gm_rim(ci, parts, rim)
			sil(ci, [rock], false)
			_gm_rock_det(ci, c + Vector2(0, 6), 22, s)
			bumps.sort_custom(func(a, b): return a[0].y < b[0].y)
			for i in bumps.size():
				var q: Array = bumps[i]
				var bc: Vector2 = q[0]
				var r: float = q[1]
				sil(ci, [ov(bc, r, r * 0.92, s + i, MALA, 0.0, 1)], false)
				for k in 2:
					ci.draw_arc(bc + Vector2(r * 0.08, r * 0.1), r * (0.72 - 0.3 * float(k)), PI * 0.85, PI * 2.1, 14, Color("1d6b43", 0.75) if k == 0 else Color("7fe0a8", 0.8), 1.8, true)
				ci.draw_circle(bc + Vector2(-r * 0.35, -r * 0.4), r * 0.16, Color(1, 1, 1, 0.45))
		4:
			## 萤石：灰石头上冒出三颗方方正正的紫色立方晶，每颗下半截带一道绿
			var c := Vector2(0, 26)
			var rock := _gm_rock(c, 27, s + 9)
			var cubes := [[Vector2(-1, 4), 11.0, Vector2(6, -6)], [Vector2(-17, 12), 7.0, Vector2(5, -5)], [Vector2(17, 13), 6.5, Vector2(4, -4)]]
			var parts := [rock]
			for q in cubes:
				parts.append(_st_block_part(q[0], q[1], q[1], q[2], FLUOR))
			_gm_rim(ci, parts, rim)
			sil(ci, [rock], false)
			_gm_rock_det(ci, c + Vector2(0, 8), 22, s)
			for i in cubes.size():
				_gm_cube(ci, cubes[i][0], cubes[i][1], cubes[i][2], s + i * 3)
		5:
			## 金矿石：灰石头上半截嵌着一大块金灿灿的狗头金，身上还有几道金线
			var c := Vector2(0, 26)
			var rock := _gm_rock(c, 28, s + 9)
			var nug := []
			for k in 14:
				var a := TAU * float(k) / 14.0
				var m := 1.0 + 0.16 * sin(a * 3.0 + 1.0) + 0.08 * sin(a * 5.0)
				nug.append(Vector2(2, 2) + Vector2(cos(a) * 22.0, sin(a) * 15.0) * m)
			var gold := pg(nug, s, GOLD, 1)
			_gm_rim(ci, [rock, gold], rim)
			sil(ci, [rock], false)
			_gm_rock_det(ci, c + Vector2(0, 6), 22, s)
			pl(ci, [Vector2(-22, 24), Vector2(-15, 30), Vector2(-4, 33), Vector2(6, 40)], 1.8, Color("e9b72c"), s + 1)
			for p in [Vector2(14, 32), Vector2(20, 26), Vector2(-26, 34)]:
				ci.draw_circle(p, 1.8, GOLD)
			sil(ci, [gold], false)
			## 疙疙瘩瘩的凹坑和亮点
			for k in 6:
				var p := Vector2(2, 2) + Vector2((srnd(s + k * 3) - 0.5) * 30.0, (srnd(s + k * 3 + 1) - 0.5) * 18.0)
				ci.draw_colored_polygon(ell(p, Vector2(3.0, 2.0), s + k, 0.2, 8), Color("c48a1c", 0.8))
			hl(ci, Vector2(-8, -6), 8, 3, -0.3, 0.7)
			ci.draw_circle(Vector2(12, -4), 1.8, Color(1, 1, 1, 0.9))
		6:
			## 海蓝宝石：一截淡蓝透明的粗晶柱从灰石头里斜着长出来，根部埋在石头里
			var c := Vector2(0, 26)
			var rock := _gm_rock(c, 30, s + 9)
			var a := 0.45
			var o := Vector2(-4, 16)
			var col := Color("8fdcec")
			var gem := pg(_gm_prism(o, 12.0, 42.0, a), s, col, 1)
			var o2 := Vector2(-14, 20)
			var gem2 := pg(_gm_prism(o2, 7.0, 24.0, -0.4), s + 5, col, 1)
			_gm_rim(ci, [rock, gem, gem2], rim)
			sil(ci, [gem2], false)
			_gm_prism_det(ci, o2, 7.0, 24.0, -0.4, col, s + 5)
			sil(ci, [gem], false)
			_gm_prism_det(ci, o, 12.0, 42.0, a, col, s)
			## 石头盖住晶柱根部
			sil(ci, [rock], false)
			_gm_rock_det(ci, c + Vector2(0, 4), 24, s)
		7:
			## 紫水晶簇：一簇透明的紫晶从石底长出来
			glow(ci, Vector2(0, 8), 34, Color("e9d6ff"))
			var list := [[Vector2(-16, 30), 5.0, 18.0, -0.55], [Vector2(-6, 30), 6.0, 30.0, -0.2], [Vector2(6, 30), 6.5, 36.0, 0.1],
				[Vector2(17, 31), 5.0, 22.0, 0.5], [Vector2(0, 33), 4.5, 14.0, -0.05]]
			_st_crys(ci, list, s, PURPLE.lightened(0.18), Color("e0c0f8"), rim, [_gm_rock(Vector2(0, 34), 24, s + 9)])
		8:
			## 黄水晶簇：一簇透明的金黄晶体，比紫晶更高更密
			glow(ci, Vector2(0, 6), 38, Color("fff1c2"))
			var list := [[Vector2(-20, 31), 5.0, 20.0, -0.6], [Vector2(-10, 30), 6.0, 34.0, -0.28], [Vector2(2, 30), 7.0, 42.0, -0.02],
				[Vector2(13, 30), 6.0, 30.0, 0.3], [Vector2(22, 32), 4.5, 16.0, 0.65], [Vector2(-3, 34), 5.0, 16.0, 0.15]]
			_st_crys(ci, list, s, CITRINE, Color("fff0b0"), rim, [_gm_rock(Vector2(0, 35), 24, s + 9)])
			sparks(ci, [Vector2(24, -16)], 4)
		9:
			## 祖母绿：几根翠绿的平顶六棱柱从石底斜着长出来
			glow(ci, Vector2(2, 4), 42, Color("c8f7dc"))
			var cfg := [[Vector2(-14, 30), 6.5, 24.0, -0.45], [Vector2(14, 30), 7.0, 28.0, 0.4], [Vector2(0, 30), 10.0, 42.0, 0.05]]
			var rock := _gm_rock(Vector2(0, 34), 24, s + 9)
			var parts := [rock]
			for i in cfg.size():
				var q: Array = cfg[i]
				parts.append(pg(_gm_prism(q[0], q[1], q[2], q[3]), s + i, EMERALD, 1))
			_gm_rim(ci, parts, rim)
			sil(ci, parts, false)
			for i in cfg.size():
				var q: Array = cfg[i]
				_gm_prism_det(ci, q[0], q[1], q[2], q[3], EMERALD, s + i)
			sparks(ci, [Vector2(-24, -14), Vector2(24, -18)], 4)
		10:
			## 蓝宝石：一颗大的深蓝桶形晶体立在一小块石底上
			glow(ci, Vector2(0, 10), 48, Color("c4d6ff"))
			var o := Vector2(0, 8)
			var pts := rot_pts([Vector2(0, -36), Vector2(14, -20), Vector2(17, 14), Vector2(0, 32), Vector2(-17, 14), Vector2(-14, -20)], 0.2, o)
			var gem := pg(pts, s, SAPPH, 1)
			var rock := _gm_base()
			_gm_rim(ci, [gem, rock], rim)
			sil(ci, [rock], false)
			sil(ci, [gem], false)
			ci.draw_colored_polygon(poly(rot_pts([Vector2(0, -36), Vector2(14, -20), Vector2(17, 14), Vector2(0, 32), Vector2(3, 14), Vector2(3, -20)], 0.2, o), s + 1, 0.3), SAPPH.darkened(0.22))
			for y in [-12.0, -2.0, 8.0]:
				pl(ci, rot_pts([Vector2(-15, y), Vector2(0, y + 2.0), Vector2(16, y)], 0.2, o), 1.2, Color(1, 1, 1, 0.3), s + int(y))
			pl(ci, rot_pts([Vector2(0, -36), Vector2(3, -20), Vector2(3, 14), Vector2(0, 32)], 0.2, o), 1.4, Color(INK, 0.4), s)
			ci.draw_colored_polygon(poly(rot_pts([Vector2(-11, -18), Vector2(-5, -27), Vector2(-4, 6), Vector2(-11, 8)], 0.2, o), s + 2, 0.3), Color(1, 1, 1, 0.38))
			_gm_lip(ci, s)
			sparks(ci, [Vector2(-24, -24), Vector2(26, -10), Vector2(24, 24)], 4)
		11:
			## 红宝石：一颗粗壮的红色六棱晶体，顶上看得见六角形的平面，旁边一颗小的
			glow(ci, Vector2(0, 4), 52, Color("ffc6d0"))
			var rock := _gm_base()
			var big := _gm_prism(Vector2(4, 30), 16.0, 34.0, 0.12)
			var small := _gm_prism(Vector2(-18, 32), 8.0, 14.0, -0.5)
			var parts := [pg(small, s + 2, RUBY, 1), pg(big, s + 1, RUBY, 1), rock]
			_gm_rim(ci, parts, rim)
			sil(ci, [rock], false)
			sil(ci, parts.slice(0, 2), false)
			_gm_prism_det(ci, Vector2(-18, 32), 8.0, 14.0, -0.5, RUBY, s + 2)
			_gm_prism_det(ci, Vector2(4, 30), 16.0, 34.0, 0.12, RUBY, s + 1)
			## 顶面的六角形
			var tc := Vector2(4, 30) + Vector2(0, -34 - 16 * 0.2).rotated(0.12)
			var hexp := []
			for i in 6:
				var a := PI / 3.0 * float(i)
				hexp.append(tc + Vector2(cos(a) * 11.0, sin(a) * 4.0).rotated(0.12))
			ci.draw_colored_polygon(poly(hexp, s, 0.2), RUBY.lightened(0.3))
			outline(ci, poly(hexp, s, 0.2), 1.4)
			_gm_lip(ci, s)
			sparks(ci, [Vector2(-28, -18), Vector2(30, -22), Vector2(30, 18)], 4)
		_:
			_gm_top(ci, lv, s, rim)

## 12 钻石、13 绿萤石、14 蓝铜矿（后两个照用户给的参考图画）。
## 没选上的候选都留着备用：_gm_alt_a（彩钻原石）、_gm_alt_b（西瓜碧玺 / 黑欧泊 / 钻石压轴）、_gm_alt_old（三角粉钻 / 十二面体蓝钻）、_gm_red_spikes（红色尖晶簇）
static func _gm_top(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		12:
			## 钻石：一颗大八面体嵌在一小块石底上，亮得发光
			_gm_diamond(ci, s, rim, DIAM_TONES, 32, [], Color("eaf7ff"), 58)
			sparks(ci, [Vector2(-30, -24), Vector2(30, -28), Vector2(36, 8), Vector2(-36, 6), Vector2(0, -42)], 5)
		13:
			_gm_green_fluorite(ci, s, rim)
		_:
			_gm_azurite(ci, s, rim)

## 候选 A：彩钻原石（13 粉钻、14 蓝钻，嵌在黑色母岩里）
static func _gm_alt_a(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	if lv == 13:
		_gm_kimb(ci, s, rim, PINK_TONES, [[Vector2(6, -4), 27.0, 0.22], [Vector2(-21, 14), 14.0, -0.45]], Color("ffd6ea"), 62)
		sparks(ci, [Vector2(-32, -26), Vector2(32, -30), Vector2(38, 10), Vector2(0, -46), Vector2(-38, -4)], 5)
	else:
		rays(ci, Vector2(0, 0), 38, 62, 12, Color(0.75, 0.88, 1.0, 0.35), 4.0, 0.13)
		_gm_kimb(ci, s, rim, BLUE_TONES, [[Vector2(0, -4), 34.0, 0.1]], Color("cfe6ff"), 66)
		sparks(ci, [Vector2(-34, -28), Vector2(34, -32), Vector2(42, 6), Vector2(0, -50), Vector2(-42, 2), Vector2(18, -44)], 6)

## 候选 B：12 西瓜碧玺、13 黑欧泊、14 钻石压轴
static func _gm_alt_b(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		12:
			_gm_tourmaline(ci, s, rim)
		13:
			_gm_black_opal(ci, s, rim)
		_:
			rays(ci, Vector2(0, 0), 38, 62, 12, Color(0.85, 0.94, 1.0, 0.4), 4.0, 0.13)
			_gm_diamond(ci, s, rim, DIAM_TONES, 36, [], Color("eaf7ff"), 66)
			sparks(ci, [Vector2(-34, -28), Vector2(34, -32), Vector2(42, 6), Vector2(0, -50), Vector2(-42, 2), Vector2(18, -44)], 6)

## 上一版：13 三角形粉钻、14 十二面体蓝钻（用户觉得像切割过的）
static func _gm_alt_old(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	if lv == 13:
		_gm_gem_on_base(ci, s, rim, "macle", PINK_TONES, 36, Color("ffd6ea"), 62)
		sparks(ci, [Vector2(-32, -26), Vector2(32, -30), Vector2(38, 10), Vector2(0, -46), Vector2(-38, -4)], 5)
	else:
		rays(ci, Vector2(0, 0), 38, 62, 12, Color(0.75, 0.88, 1.0, 0.35), 4.0, 0.13)
		_gm_gem_on_base(ci, s, rim, "dodeca", BLUE_TONES, 34, Color("cfe6ff"), 66)
		sparks(ci, [Vector2(-34, -28), Vector2(34, -32), Vector2(42, 6), Vector2(0, -50), Vector2(-42, 2), Vector2(18, -44)], 6)

const GFL_TONES := [Color("e6ffc4"), Color("aef07a"), Color("8adc52"), Color("5cb236"), Color("3a7a1e"), Color("9be463")]

## 绿萤石：一颗大的绿色八面体顶在上面，下面挤着几颗小的，右下角一团褐色的葡萄状小球（伴生矿）
static func _gm_green_fluorite(ci: CanvasItem, s: int, rim: bool) -> void:
	glow(ci, Vector2(0, -2), 54, Color("e0ffc8"))
	var rock := _gm_base()
	var octs := [[Vector2(-15, 12), 14.0, -0.35], [Vector2(15, 14), 13.0, 0.4], [Vector2(-2, 18), 15.0, 0.1], [Vector2(4, -12), 26.0, 0.18]]
	var bumps := [[Vector2(18, 26), 5.0], [Vector2(24, 22), 4.5], [Vector2(12, 29), 4.5], [Vector2(22, 30), 4.0], [Vector2(28, 27), 3.5], [Vector2(16, 21), 3.5]]
	var parts := [rock]
	for q in octs:
		parts.append(pg(_st_octa(q[0], q[1], q[2]).slice(0, 4), s, GFL_TONES[5], 2))
	for q in bumps:
		parts.append(ov(q[0], q[1], q[1], s, Color("c08a34"), 0.0, 1))
	_gm_rim(ci, parts, rim)
	sil(ci, [rock], false)
	## 褐色小球在小晶体后面
	for i in bumps.size():
		var q: Array = bumps[i]
		sil(ci, [ov(q[0], q[1], q[1], s + i, Color("c08a34"), 0.0, 1)], false, 2.0)
		ci.draw_circle((q[0] as Vector2) + Vector2(-1, -1.2), q[1] * 0.35, Color("f0c36a", 0.8))
	for i in octs.size():
		var q: Array = octs[i]
		_gm_octa(ci, q[0], q[1], q[2], s + i * 3, GFL_TONES)
	## 大晶体顶上一层雾白（萤石顶面常见）
	var big: Array = octs[3]
	var v := _st_octa(big[0], big[1], big[2])
	ci.draw_colored_polygon(PackedVector2Array([v[0], (v[0] as Vector2).lerp(v[3], 0.4), (v[0] as Vector2).lerp(v[4], 0.45), (v[0] as Vector2).lerp(v[1], 0.4)]), Color(1, 1, 1, 0.35))
	_gm_lip(ci, s)
	sparks(ci, [Vector2(-30, -30), Vector2(32, -26), Vector2(36, 10)], 4)

## 红色尖晶簇：一个小土包上密密麻麻冒出一堆尖尖的红色晶体，像一团火
static func _gm_red_spikes(ci: CanvasItem, s: int, rim: bool) -> void:
	glow(ci, Vector2(0, 0), 56, Color("ffc2c2"))
	var rock := _gm_base()
	var mound := ov(Vector2(0, 14), 26, 14, s, Color("c81a26"), 0.0, 1)
	## 每根尖晶：[根部, 角度, 长, 宽]
	var spikes := []
	var n := 15
	for k in n:
		var u := float(k) / float(n - 1)
		var ang := lerpf(-PI + 0.45, -0.45, u) + (srnd(s + k) - 0.5) * 0.25
		var root := Vector2(0, 12) + Vector2(cos(ang) * 18.0, sin(ang) * 10.0) * (0.5 + srnd(s + k * 3) * 0.3)
		var ln_ := 24.0 + srnd(s + k * 7) * 12.0 - absf(u - 0.5) * 14.0
		spikes.append([root, ang, ln_, 11.0 + srnd(s + k * 5) * 4.0])
	## 正面再补一排短的、朝前上方的
	for k in 5:
		var x := -18.0 + float(k) * 9.0
		spikes.append([Vector2(x, 24), -PI * 0.5 + x * 0.02 + (srnd(s + k * 11) - 0.5) * 0.3, 14.0 + srnd(s + k * 13) * 6.0, 10.0])
	var parts := [rock, mound]
	for q in spikes:
		parts.append(P(_gm_spike_pts(q[0], q[1], q[2], q[3]), Color("e0202c"), 1))
	_gm_rim(ci, parts, rim)
	sil(ci, [rock], false)
	sil(ci, [mound], false)
	spikes.sort_custom(func(a, b): return a[0].y < b[0].y)
	for i in spikes.size():
		var q: Array = spikes[i]
		var pts := _gm_spike_pts(q[0], q[1], q[2], q[3])
		sil(ci, [P(pts, Color("e0202c"), 2)], false, 1.4)
		## 左半亮、右半暗
		ci.draw_colored_polygon(PackedVector2Array([pts[0], pts[1], pts[3]]), Color("ff5a5e"))
		ci.draw_colored_polygon(PackedVector2Array([pts[1], pts[2], pts[3]]), Color("a90f1c"))
		ln(ci, pts[1], pts[3], 1.0, Color("7a0a14", 0.5), s + i)
		if i % 3 == 1:
			ln(ci, (pts[1] as Vector2).lerp(pts[0], 0.3), (pts[1] as Vector2).lerp(pts[3], 0.45), 1.6, Color(1, 1, 1, 0.85), s + i)
	_gm_lip(ci, s)
	sparks(ci, [Vector2(-34, -24), Vector2(30, -30), Vector2(38, 4)], 4)

## 一根尖晶的四个点：根部左、尖、根部右、根部中间稍往里（分出亮暗两面）
static func _gm_spike_pts(root: Vector2, ang: float, l: float, w: float) -> PackedVector2Array:
	var d := Vector2(cos(ang), sin(ang))
	var n := Vector2(-d.y, d.x)
	return PackedVector2Array([root + n * w * 0.5, root + d * l, root - n * w * 0.5, root + d * w * 0.4])

## 蓝铜矿：一把深蓝色的扁长柱从米色石底上扇形张开，柱头圆钝，身上带浅蓝的斑和细点
static func _gm_azurite(ci: CanvasItem, s: int, rim: bool) -> void:
	glow(ci, Vector2(0, -4), 56, Color("c8d4ff"))
	var rock := raw_rock(Vector2(0, 31), 26, 77, Color("d9cfb8"), 8, 0.14)
	var blades := [[-0.72, 46.0, 14.0], [0.7, 44.0, 14.0], [-0.36, 56.0, 15.0], [0.34, 54.0, 15.0], [0.0, 62.0, 16.0], [-0.55, 34.0, 13.0], [0.5, 32.0, 13.0], [-0.12, 36.0, 13.0], [0.18, 34.0, 13.0]]
	var root := Vector2(0, 26)
	var parts := [rock]
	for q in blades:
		parts.append(P(_gm_blade_pts(root, q[0], q[1], q[2]), Color("2a45c8"), 1))
	_gm_rim(ci, parts, rim)
	sil(ci, [rock], false)
	for i in blades.size():
		var q: Array = blades[i]
		var pts := _gm_blade_pts(root, q[0], q[1], q[2])
		sil(ci, [P(pts, Color("2a45c8"), 1)], false, 2.2)
		var qa: float = q[0]
		var ql: float = q[1]
		var qw: float = q[2]
		var d := Vector2(sin(qa), -cos(qa))
		var nn := Vector2(-d.y, d.x)
		## 一侧亮一点的棱面
		ci.draw_colored_polygon(PackedVector2Array([root + d * 6.0, root + d * (ql - 4.0), root + d * (ql - 4.0) + nn * qw * 0.45, root + d * 6.0 + nn * qw * 0.4]), Color("4a6ee6"))
		## 浅蓝斑和细点
		var m := root + d * ql * (0.35 + srnd(s + i) * 0.3)
		ci.draw_colored_polygon(ell(m, Vector2(qw * 0.45, 4.0), s + i, 0.25, 8, qa), Color("5fb8f0", 0.85))
		for k in 4:
			ci.draw_circle(root + d * ql * (0.25 + 0.18 * float(k)) + nn * (srnd(s + i * 9 + k) - 0.5) * qw, 0.9, Color(1, 1, 1, 0.6))
		ci.draw_circle(root + d * (ql - 5.0) - nn * qw * 0.2, 1.6, Color(1, 1, 1, 0.75))
	## 根部米色的伴生石和一点橙色
	for k in 5:
		var p := root + Vector2(-14.0 + float(k) * 7.0, 2.0 + float(k % 2) * 3.0)
		sil(ci, [ov(p, 4.5, 3.5, s + k, Color("e8dcc0"), 0.0, 1)], false, 1.8)
	ci.draw_circle(root + Vector2(-8, -4), 2.6, Color("e8902a"))
	sparks(ci, [Vector2(-34, -26), Vector2(30, -34), Vector2(36, 6)], 4)

## 一根扁长柱：从根部朝 ang 方向（0 是正上，往右为正）伸出长 l、宽 w，头部圆钝
static func _gm_blade_pts(root: Vector2, ang: float, l: float, w: float) -> PackedVector2Array:
	var d := Vector2(sin(ang), -cos(ang))
	var n := Vector2(-d.y, d.x)
	var out := PackedVector2Array([root - n * w * 0.35, root + n * w * 0.35])
	out.append(root + d * (l - w * 0.5) + n * w * 0.5)
	for k in 5:
		var a := float(k) / 4.0 * PI
		out.append(root + d * (l - w * 0.5) + (n * cos(a) + d * sin(a)) * w * 0.5)
	out.append(root + d * (l - w * 0.5) - n * w * 0.5)
	return out

const KIMB_ROCK := Color("3f4556")

## 边角圆钝的八面体剪影：四个角各切成两点
static func _gm_round_octa(c: Vector2, r: float, ang: float) -> Array:
	var v := _st_octa(c, r, ang).slice(0, 4)
	var out := []
	for i in 4:
		var p: Vector2 = v[i]
		var a: Vector2 = v[(i + 3) % 4]
		var b: Vector2 = v[(i + 1) % 4]
		out.append(p.lerp(a, 0.14))
		out.append(p.lerp(b, 0.14))
	return out

## 磨砂原石钻：圆钝外形，左右两大块明暗，表面一层雾白，几个三角生长纹，没有对称的切割棱面
static func _gm_rough_octa(ci: CanvasItem, c: Vector2, r: float, ang: float, s: int, tones: Array) -> void:
	var pts := _gm_round_octa(c, r, ang)
	sil(ci, [pg(pts, s, tones[5], 2)], false)
	var v := _st_octa(c, r, ang)
	var top: Vector2 = v[0]
	var bot: Vector2 = v[2]
	var mid := c + Vector2(r * 0.18, r * 0.05).rotated(ang)
	## 右下半边暗一点：沿一条弯的棱线分开
	var right := [top.lerp(mid, 0.08)]
	for p in pts:
		if ((p as Vector2) - c).rotated(-ang).x > r * 0.05:
			right.append(p)
	right.append(bot.lerp(mid, 0.08))
	right.append(mid)
	safe_poly(ci, poly(right, s + 1, 0.3), Color(tones[3], 0.75))
	pl(ci, [top.lerp(c, 0.12), mid, bot.lerp(c, 0.12)], 1.4, Color(tones[4], 0.6), s)
	## 左上一块亮面
	safe_poly(ci, poly([top.lerp(c, 0.2), mid.lerp(top, 0.3), mid.lerp(v[3], 0.5), v[3].lerp(c, 0.25)], s + 2, 0.4), Color(tones[0], 0.7))
	## 磨砂：整体蒙一层雾白
	ci.draw_colored_polygon(poly(pts, s, 0.0), Color(1, 1, 1, 0.16))
	## 几道淡淡的生长纹，顺着右下那块面
	for k in 3:
		var q0 := c + Vector2(r * 0.12 + float(k) * r * 0.1, r * 0.05 + float(k) * r * 0.14).rotated(ang)
		pl(ci, [q0, q0 + Vector2(r * 0.18, -r * 0.1).rotated(ang)], 1.1, Color(1, 1, 1, 0.35), s + k)
	hl(ci, c + Vector2(-r * 0.3, -r * 0.25).rotated(ang), r * 0.16, r * 0.05, -0.6, 0.5)

## 彩钻放在黑色母岩上：后面一块深蓝黑的石头带几个橄榄绿点，钻石画完再盖一道石沿
static func _gm_kimb(ci: CanvasItem, s: int, rim: bool, tones: Array, gems: Array, glow_col: Color, glow_r: float) -> void:
	glow(ci, Vector2(0, 2), glow_r, glow_col)
	var rock := raw_rock(Vector2(0, 30), 28, 77, KIMB_ROCK, 8, 0.14)
	var parts := [rock]
	for q in gems:
		parts.append(pg(_gm_round_octa(q[0], q[1], q[2]), s, tones[5], 2))
	_gm_rim(ci, parts, rim)
	sil(ci, [rock], false)
	for k in 7:
		ci.draw_circle(Vector2(-22.0 + float(k) * 7.5, 26.0 + float(k % 3) * 4.0), 1.5, Color("8fae5a", 0.8))
	gems.sort_custom(func(a, b): return a[0].y < b[0].y)
	for i in gems.size():
		var q: Array = gems[i]
		_gm_rough_octa(ci, q[0], q[1], q[2], s + i * 5, tones)
	sil(ci, [ov(Vector2(0, 35), 23, 6, s, KIMB_ROCK.lightened(0.05), 0.0, 1)], false, 2.4)
	for k in 5:
		ci.draw_circle(Vector2(-16.0 + float(k) * 8.0, 36.0 + float(k % 2) * 1.5), 1.2, Color("8fae5a", 0.75))

## 西瓜碧玺：一根长晶柱带竖条纹，下半截粉、上半截绿，顶面截面外圈绿、里面粉，旁边一根小的
static func _gm_tourmaline(ci: CanvasItem, s: int, rim: bool) -> void:
	glow(ci, Vector2(0, 4), 52, Color("f6d6e6"))
	var rock := _gm_base()
	var cfg := [[Vector2(-16, 30), 7.0, 26.0, -0.42], [Vector2(4, 30), 12.0, 56.0, 0.14]]
	var parts := [rock]
	for q in cfg:
		parts.append(pg(_gm_prism(q[0], q[1], q[2], q[3]), s, Color("4fb36a"), 1))
	_gm_rim(ci, parts, rim)
	sil(ci, [rock], false)
	for i in cfg.size():
		var q: Array = cfg[i]
		var o: Vector2 = q[0]
		var w: float = q[1]
		var h: float = q[2]
		var a: float = q[3]
		sil(ci, [parts[1 + i]], false)
		## 下半截粉红
		ci.draw_colored_polygon(poly(rot_pts([Vector2(-w, 0), Vector2(-w, -h * 0.45), Vector2(w, -h * 0.55), Vector2(w, 0)], a, o), s + i, 0.3), Color("ef6f9a"))
		pl(ci, rot_pts([Vector2(-w, -h * 0.45), Vector2(w, -h * 0.55)], a, o), 1.2, Color(INK, 0.35), s)
		## 竖条纹
		for k in 3:
			var x := -w * 0.5 + float(k) * w * 0.5
			ln(ci, o + Vector2(x, -2).rotated(a), o + Vector2(x, -h + 2).rotated(a), 1.1, Color(0, 0, 0, 0.18), s + k)
		ci.draw_colored_polygon(poly(rot_pts([Vector2(-w * 0.75, -3), Vector2(-w * 0.75, -h + 3), Vector2(-w * 0.35, -h + 1), Vector2(-w * 0.35, -3)], a, o), s, 0.3), Color(1, 1, 1, 0.3))
		## 顶面：外圈绿、里面粉
		var tc := o + Vector2(0, -h - w * 0.2).rotated(a)
		var ring := ell(tc, Vector2(w * 0.95, w * 0.42), s + 3, 0.0, 14, a)
		ci.draw_colored_polygon(ring, Color("3e9a58"))
		ci.draw_colored_polygon(ell(tc, Vector2(w * 0.55, w * 0.24), s + 4, 0.0, 12, a), Color("ff86ad"))
		outline(ci, ring, 1.4)
	_gm_lip(ci, s)
	sparks(ci, [Vector2(-30, -20), Vector2(30, -28), Vector2(32, 16)], 4)

## 黑欧泊：一大块黑色的欧泊原石坐在石底上，满身鲜艳的彩虹斑
static func _gm_black_opal(ci: CanvasItem, s: int, rim: bool) -> void:
	glow(ci, Vector2(0, 2), 56, Color("d8ccff"))
	var rock := _gm_base()
	var c := Vector2(0, 2)
	var pts := []
	for k in 14:
		var a := TAU * float(k) / 14.0
		var m := 1.0 + 0.1 * sin(a * 3.0 + 0.4) + 0.06 * sin(a * 5.0 + 1.0)
		pts.append(c + Vector2(cos(a) * 34.0, sin(a) * 27.0) * m)
	var body := pg(pts, s, Color("2a2833"), 1)
	_gm_rim(ci, [rock, body], rim)
	sil(ci, [rock], false)
	sil(ci, [body], false)
	var fire := [Color("ff4d6d"), Color("3fe08a"), Color("3f8cff"), Color("ffb02e"), Color("b05cff"), Color("2fd6d6"), Color("ffe14d")]
	var bp := PackedVector2Array(body[0])
	var n := 0
	for k in 60:
		var p := c + Vector2((srnd(s + k * 5) - 0.5) * 60.0, (srnd(s + k * 5 + 1) - 0.5) * 46.0)
		if n >= 16 or not Geometry2D.is_point_in_polygon(p, bp):
			continue
		var e := ell(p, Vector2(5.5 + srnd(s + k) * 3.0, 3.0 + srnd(s + k + 3) * 2.0), s + k, 0.25, 7, srnd(s + k * 2) * PI)
		ci.draw_colored_polygon(e, Color(fire[n % fire.size()], 0.95))
		n += 1
	hl(ci, c + Vector2(-16, -12), 9, 3, -0.4, 0.55)
	_gm_lip(ci, s)
	sparks(ci, [Vector2(-34, -24), Vector2(34, -26), Vector2(38, 12)], 4)

## 第 3 版宝石（12 种外形各异、没有统一底座，用户觉得乱、看不出升级），留着备用
static func _sub_art_v3(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			## 石英晶柱：几根白色透明的尖头晶柱长在一起
			var list := [[Vector2(-10, 34), 6.0, 26.0, -0.4], [Vector2(12, 34), 5.5, 22.0, 0.45], [Vector2(1, 36), 7.5, 38.0, 0.02]]
			_st_crys(ci, list, s, QUARTZ, Color("a8b8c8"), rim, [ov(Vector2(0, 35), 16, 5, s + 9, MILKY, 0.0, 2)])
		2:
			## 玛瑙原石：褐灰外皮的圆卵石，敲开的一面露出一圈圈红白条纹
			var c := Vector2(0, 12)
			var body := pg(_st_nod_pts(c, 28, s), s, AGATE_CRUST, 1)
			_gm_rim(ci, [body], rim)
			sil(ci, [body], false)
			var cols := [Color("f4e6d6"), Color("d65a28"), Color("f6d2b0"), Color("b8401c"), Color("f2e2cf"), Color("e07a3a")]
			for k in cols.size():
				var t := 1.0 - float(k) * 0.15
				var e := ell(c + Vector2(4, 2), Vector2(20, 16) * t, s + k, 0.06, 18, 0.2)
				ci.draw_colored_polygon(e, cols[k])
			outline(ci, ell(c + Vector2(4, 2), Vector2(20, 16), s, 0.06, 18, 0.2), 1.8)
			## 心里一小窝晶粒
			for k in 5:
				ci.draw_circle(c + Vector2(4, 2) + Vector2(cos(float(k) * 1.3) * 3.0, sin(float(k) * 1.3) * 2.0), 1.4, Color(1, 1, 1, 0.85))
			hl(ci, c + Vector2(-2, -6), 7, 2.4, -0.3, 0.5)
		3:
			## 绿松石块：蓝绿色疙瘩块，身上一张褐色细网纹
			var c := Vector2(0, 14)
			var pts := _st_nod_pts(c, 27, s + 4)
			var body := pg(pts, s, TURQ, 0)
			_gm_rim(ci, [body], rim)
			sil(ci, [body], false)
			var poly_pts := PackedVector2Array(body[0])
			for k in 7:
				var a := c + Vector2((srnd(s + k * 4) - 0.5) * 40.0, (srnd(s + k * 4 + 1) - 0.5) * 32.0)
				var b := a + Vector2((srnd(s + k * 4 + 2) - 0.5) * 22.0, (srnd(s + k * 4 + 3) - 0.5) * 16.0)
				var m := a.lerp(b, 0.5) + Vector2(3, -2)
				if Geometry2D.is_point_in_polygon(a, poly_pts) and Geometry2D.is_point_in_polygon(b, poly_pts):
					pl(ci, [a, m, b], 1.3, Color(MATRIX.darkened(0.2), 0.8), s + k)
			hl(ci, c + Vector2(-10, -10), 8, 3, -0.4, 0.55)
		4:
			## 琥珀：一块圆润的金黄半透明琥珀，里面封着一只小飞虫
			var c := Vector2(0, 12)
			var pts := []
			for k in 16:
				var a := TAU * float(k) / 16.0
				var m := 1.0 + 0.08 * sin(a * 2.0 + 0.7) + 0.05 * sin(a * 3.0)
				pts.append(c + Vector2(cos(a) * 30.0, sin(a) * 25.0) * m)
			var body := pg(pts, s, GM_AMBER, 1)
			_gm_rim(ci, [body], rim)
			sil(ci, [body], false)
			ci.draw_colored_polygon(ell(c + Vector2(-3, -3), Vector2(20, 15), s + 1, 0.05, 16), Color("ffc961", 0.75))
			## 小虫：一只看得清的小飞虫，两片透明翅膀、深色身子、细腿
			var bug := c + Vector2(3, 3)
			var bc := Color("6a3a12", 0.85)
			for k in 3:
				var dx := -3.0 + float(k) * 3.5
				pl(ci, [bug + Vector2(dx, 2), bug + Vector2(dx - 2.0, 6), bug + Vector2(dx - 4.0, 9)], 1.2, bc, s + k)
			ci.draw_colored_polygon(ell(bug + Vector2(-5, -8), Vector2(8, 4), s + 2, 0.0, 12, -0.7), Color(1, 0.97, 0.85, 0.75))
			ci.draw_colored_polygon(ell(bug + Vector2(3, -8), Vector2(7, 3.6), s + 4, 0.0, 12, 0.5), Color(1, 0.97, 0.85, 0.75))
			ci.draw_colored_polygon(ell(bug, Vector2(8, 3.6), s + 3, 0.0, 12), bc)
			ci.draw_circle(bug + Vector2(9, -1), 3.0, bc)
			hl(ci, c + Vector2(-14, -10), 8, 3, -0.5, 0.6)
			ci.draw_circle(c + Vector2(16, -8), 1.8, Color(1, 1, 1, 0.7))
		5:
			## 紫水晶簇：一簇紫色尖晶长在灰色石底上
			var list := [[Vector2(-16, 30), 5.0, 18.0, -0.55], [Vector2(-6, 30), 6.0, 30.0, -0.2], [Vector2(6, 30), 6.5, 36.0, 0.1],
				[Vector2(17, 31), 5.0, 22.0, 0.5], [Vector2(0, 33), 4.5, 14.0, -0.05]]
			_st_crys(ci, list, s, PURPLE.lightened(0.18), Color("e0c0f8"), rim, [raw_rock(Vector2(0, 34), 24, s + 9, MATRIX_G, 8, 0.15)])
		6:
			## 孔雀石：一团鼓包的葡萄状绿石头，每个鼓包上一圈圈深浅绿纹
			var bumps := [[Vector2(-16, 22), 14.0], [Vector2(14, 24), 15.0], [Vector2(-2, 8), 16.0], [Vector2(0, 28), 13.0], [Vector2(-22, 32), 9.0], [Vector2(24, 34), 8.0]]
			var parts := []
			for i in bumps.size():
				var q: Array = bumps[i]
				parts.append(ov(q[0], q[1], q[1] * 0.92, s + i, MALA, 0.0, 1))
			_gm_rim(ci, parts, rim)
			bumps.sort_custom(func(a, b): return a[0].y < b[0].y)
			for i in bumps.size():
				var q: Array = bumps[i]
				var c: Vector2 = q[0]
				var r: float = q[1]
				sil(ci, [ov(c, r, r * 0.92, s + i, MALA, 0.0, 1)], false)
				for k in 3:
					var rr := r * (0.78 - 0.22 * float(k))
					ci.draw_arc(c + Vector2(r * 0.08, r * 0.1), rr, PI * 0.85, PI * 2.1, 14, Color("1d6b43", 0.75) if k % 2 == 0 else Color("7fe0a8", 0.8), 1.8, true)
				ci.draw_circle(c + Vector2(-r * 0.35, -r * 0.4), r * 0.16, Color(1, 1, 1, 0.45))
		7:
			## 青金石：一块方方的深蓝石头，撒着金色小点，带一道白纹
			var pts := [Vector2(-30, 34), Vector2(-34, 6), Vector2(-24, -12), Vector2(6, -18), Vector2(30, -8), Vector2(34, 18), Vector2(26, 36)]
			var body := pg(pts, s, LAPIS, 0)
			_gm_rim(ci, [body], rim)
			sil(ci, [body], false)
			var top := poly([Vector2(-24, -12), Vector2(6, -18), Vector2(30, -8), Vector2(8, -2), Vector2(-20, -4)], s + 1, 0.4)
			ci.draw_colored_polygon(top, LAPIS.lightened(0.22))
			outline(ci, top, 1.5)
			ci.draw_colored_polygon(poly([Vector2(30, -8), Vector2(34, 18), Vector2(26, 36), Vector2(14, 30), Vector2(8, -2)], s + 2, 0.4), LAPIS.darkened(0.22))
			pl(ci, [Vector2(8, -2), Vector2(14, 30)], 1.4, Color(INK, 0.4), s)
			pl(ci, [Vector2(-28, 14), Vector2(-14, 8), Vector2(-4, 16), Vector2(6, 10)], 2.4, Color("e8ecf5", 0.85), s + 3)
			var bp := PackedVector2Array(body[0])
			var n := 0
			for k in 60:
				var p := Vector2(-32.0 + srnd(s + k * 3) * 64.0, -16.0 + srnd(s + k * 3 + 1) * 50.0)
				if n < 16 and Geometry2D.is_point_in_polygon(p, bp):
					ci.draw_circle(p, 1.0 + srnd(s + k) * 1.0, Color("ffd34d"))
					n += 1
		8:
			## 蛋白石：一块乳白的椭圆石头，表面闪着一片片彩虹色
			glow(ci, Vector2(0, 12), 44, Color("f6e9ff"))
			var c := Vector2(0, 12)
			var body := ov(c, 32, 24, s, OPAL, -0.12, 1)
			_gm_rim(ci, [body], rim)
			sil(ci, [body], false)
			var fire := [Color("ff8fb8"), Color("7fe0c0"), Color("8fb4ff"), Color("ffcf6a"), Color("c49cff"), Color("6fe08a"), Color("ff9f6a")]
			for k in 9:
				var p := c + Vector2((srnd(s + k * 5) - 0.5) * 44.0, (srnd(s + k * 5 + 1) - 0.5) * 30.0)
				var f := ell(p, Vector2(5.0 + srnd(s + k) * 4.0, 2.6 + srnd(s + k + 3) * 2.0), s + k, 0.2, 7, srnd(s + k * 2) * PI)
				ci.draw_colored_polygon(f, Color(fire[k % fire.size()], 0.85))
			hl(ci, c + Vector2(-14, -10), 9, 3, -0.4, 0.6)
			sparks(ci, [Vector2(26, -14)], 4)
		9:
			## 祖母绿原石：白色石头里斜插出一根翠绿的平顶六棱柱，旁边一根小的
			glow(ci, Vector2(4, 4), 46, Color("bff5d6"))
			var rock := raw_rock(Vector2(0, 32), 28, s, MATRIX_W, 8, 0.15)
			var big := _gm_prism(Vector2(4, 28), 10.0, 40.0, 0.25)
			var small := _gm_prism(Vector2(-14, 30), 6.0, 20.0, -0.45)
			var parts := [pg(small, s + 2, EMERALD, 1), pg(big, s + 1, EMERALD, 1), rock]
			_gm_rim(ci, parts, rim)
			sil(ci, [rock], false)
			for k in 6:
				ci.draw_circle(Vector2(-22.0 + float(k) * 9.0, 32.0 + float(k % 2) * 4.0), 1.2, Color(INK, 0.25))
			sil(ci, parts.slice(0, 2), false)
			for q in [[Vector2(4, 28), 10.0, 40.0, 0.25], [Vector2(-14, 30), 6.0, 20.0, -0.45]]:
				var c: Vector2 = q[0]
				var w: float = q[1]
				var h: float = q[2]
				var a: float = q[3]
				ci.draw_colored_polygon(poly(rot_pts([Vector2(0, 0), Vector2(0, -h), Vector2(w * 0.45, -h - w * 0.4), Vector2(w, -h), Vector2(w, 0)], a, c), s), Color(0, 0, 0, 0.14))
				ln(ci, c + Vector2(0, 0).rotated(a), c + Vector2(0, -h).rotated(a), 1.4, Color(EMERALD.darkened(0.45), 0.7), s)
				ci.draw_colored_polygon(poly(rot_pts([Vector2(-w * 0.75, -3), Vector2(-w * 0.75, -h + 3), Vector2(-w * 0.3, -h + 1), Vector2(-w * 0.3, -3)], a, c), s), Color(1, 1, 1, 0.35))
			## 晶柱根部被石头裹住一圈
			ci.draw_colored_polygon(ell(Vector2(2, 27), Vector2(16, 5), s + 7, 0.15, 12), MATRIX_W)
			pl(ci, Array(ell(Vector2(2, 27), Vector2(16, 5), s + 7, 0.15, 12)).slice(0, 7), 1.6, INK, s)
			sparks(ci, [Vector2(22, -18)], 4)
		10:
			## 蓝宝石原石：一颗两头尖的深蓝桶形晶体，身上一道道横纹
			glow(ci, Vector2(0, 8), 48, Color("b8cdff"))
			var pts := rot_pts([Vector2(0, -36), Vector2(13, -20), Vector2(16, 14), Vector2(0, 34), Vector2(-16, 14), Vector2(-13, -20)], 0.35, Vector2(0, 2))
			var body := pg(pts, s, SAPPH, 1)
			_gm_rim(ci, [body], rim)
			sil(ci, [body], false)
			var right := poly(rot_pts([Vector2(0, -36), Vector2(13, -20), Vector2(16, 14), Vector2(0, 34), Vector2(3, 14), Vector2(3, -20)], 0.35, Vector2(0, 2)), s + 1, 0.3)
			ci.draw_colored_polygon(right, SAPPH.darkened(0.22))
			for y in [-12.0, -2.0, 8.0]:
				pl(ci, rot_pts([Vector2(-14, y), Vector2(0, y + 2.0), Vector2(15, y)], 0.35, Vector2(0, 2)), 1.2, Color(1, 1, 1, 0.3), s + int(y))
			pl(ci, rot_pts([Vector2(0, -36), Vector2(3, -20), Vector2(3, 14), Vector2(0, 34)], 0.35, Vector2(0, 2)), 1.4, Color(INK, 0.4), s)
			ci.draw_colored_polygon(poly(rot_pts([Vector2(-10, -18), Vector2(-5, -26), Vector2(-4, 6), Vector2(-10, 8)], 0.35, Vector2(0, 2)), s + 2, 0.3), Color(1, 1, 1, 0.35))
			sparks(ci, [Vector2(-22, -24), Vector2(24, 20)], 4)
		11:
			## 红宝石原石：灰石底上长着三片扁平的六角红晶
			glow(ci, Vector2(0, 10), 50, Color("ffc0cc"))
			var rock := raw_rock(Vector2(0, 30), 30, s, MATRIX_G, 8, 0.15)
			var cfg := [[Vector2(-14, 14), 13.0, -0.5], [Vector2(14, 12), 14.0, 0.45], [Vector2(0, 2), 17.0, 0.05]]
			var parts := [rock]
			for i in cfg.size():
				var q: Array = cfg[i]
				var pts := _gm_plate(q[0], q[1], q[2])
				var th := []
				for p in pts:
					th.append((p as Vector2) + Vector2(0, 6))
				parts.append(P(Geometry2D.convex_hull(PackedVector2Array(pts + th)), RUBY.darkened(0.25), 1))
				parts.append(pg(pts, s + i, RUBY, 1))
			_gm_rim(ci, parts, rim)
			sil(ci, [rock], false)
			for i in cfg.size():
				var q: Array = cfg[i]
				sil(ci, [parts[1 + i * 2], parts[2 + i * 2]], false)
				var pts := _gm_plate(q[0], q[1], q[2])
				var inner := []
				for p in pts:
					inner.append((q[0] as Vector2) + ((p as Vector2) - (q[0] as Vector2)) * 0.55)
				ci.draw_colored_polygon(poly(inner, s + i, 0.2), RUBY.lightened(0.2))
				outline(ci, poly(inner, s + i, 0.2), 1.2, Color(RUBY.darkened(0.5), 0.6))
				ci.draw_circle((q[0] as Vector2) + Vector2(-q[1] * 0.35, -q[1] * 0.15), 1.8, Color(1, 1, 1, 0.8))
			sparks(ci, [Vector2(-28, -14), Vector2(28, -10)], 4)
		_:
			## 钻石原石：一颗天然八面体，搁在一小撮碎石上，亮得发光
			glow(ci, Vector2(0, 4), 56, Color("e8f6ff"))
			_st_pebs(ci, [[Vector2(-18, 34), 9, 5, Color("8d8a86")], [Vector2(16, 35), 8, 4.5, Color("a39f99")], [Vector2(0, 37), 11, 5, Color("7f7c78")],
				[Vector2(-28, 36), 7, 4, Color("a39f99")], [Vector2(28, 36), 7, 4, Color("8d8a86")]], s + 20, rim)
			var c := Vector2(0, 2)
			sil(ci, [_st_octa_part(c, 30, 0.12, s)], rim)
			_st_octa_det(ci, c, 30, 0.12, s)
			sparks(ci, [Vector2(-30, -22), Vector2(30, -26), Vector2(34, 10), Vector2(-34, 8)], 5)

## 第 2 版宝石原石（石英 / 绿松石 / 紫晶 / 钻石各 3 级），2026-11-26 换成 12 种各不相同的宝石，留着备用
static func _sub_art_v2(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
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
