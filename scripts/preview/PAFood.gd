class_name PAFood
extends PA
## 食物线：采集篮 / 水果 / 种子到树苗

const GRAPE := Color("7b4aa8")
const BLUE := Color("4f6fc4")
const PLUM := Color("9b3f74")
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

static func gen(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			var parts := []
			for k in 7:
				var x0 := -12.0 + float(k) * 4.0
				var x1 := -26.0 + float(k) * 8.6
				parts.append(stk(Vector2(x0, 4), Vector2(x1, -34), 2.6, s + k, GRASS, 2))
				parts.append(stk(Vector2(x0, 4), Vector2(x1 * 0.8, 36), 2.6, s + k + 10, GRASS.darkened(0.06), 2))
			for k in 5:
				parts.append(ov(Vector2(-22.0 + float(k) * 11.0, -36), 3.6, 7, s + 20 + k, OCHRE, 0.2 * float(k - 2), 1))
			parts.append(bx(-16, -2, 32, 10, 3, s + 30, ROPE.darkened(0.1)))
			sil(ci, parts, rim)
			ln(ci, Vector2(-14, 3), Vector2(14, 3), 1.6, WOOD_D, s)
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
			sil(ci, _basket_body(Vector2(0, -4), 28, 34, s, GRASS), rim)
			weave(ci, Rect2(-22, 4, 44, 26), s)
		4:
			var parts := [band(Vector2(0, -8), 30, 4.0, PI * 1.05, PI * 1.95, s, WOOD_D)]
			parts.append_array(_basket_body(Vector2(0, -8), 36, 42, s + 2))
			sil(ci, parts, rim)
			weave(ci, Rect2(-30, 0, 60, 34), s)
		5:
			var parts := [band(Vector2(-44, 2), 9, 3.0, PI * 0.5, PI * 1.5, s, WOOD_D),
				band(Vector2(44, 2), 9, 3.0, -PI * 0.5, PI * 0.5, s + 1, WOOD_D),
				leaf(Vector2(-6, -12), 26, 8, -2.6, s + 2), leaf(Vector2(6, -12), 26, 8, -0.5, s + 3)]
			parts.append_array(_fruit_parts(Vector2(-12, -12), 10, APPLE, s + 4, false))
			parts.append(circ(Vector2(10, -12), 9, s + 6, BLUE))
			parts.append_array(_basket_body(Vector2(0, -6), 44, 40, s + 8))
			sil(ci, parts, rim)
			weave(ci, Rect2(-36, 2, 72, 32), s)
		6:
			var parts := [stk(Vector2(26, -30), Vector2(30, 30), 3.4, s, LEATHER, 2),
				leaf(Vector2(-8, -34), 24, 7, -2.2, s + 1), leaf(Vector2(4, -34), 26, 8, -1.0, s + 2),
				leaf(Vector2(0, -34), 22, 7, -1.6, s + 3, LEAF_D)]
			parts.append(pg([Vector2(-30, -34), Vector2(30, -34), Vector2(22, 38), Vector2(-22, 38)], s + 4, WOOD))
			parts.append(stk(Vector2(-33, -34), Vector2(33, -34), 5.0, s + 5, WOOD.lightened(0.15)))
			sil(ci, parts, rim)
			weave(ci, Rect2(-26, -26, 52, 60), s)
			ln(ci, Vector2(26, -30), Vector2(30, 30), 2.0, LEATHER_D, s)
		7:
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
				var r := 28.0 if sin(a) > 0.0 else lerpf(28.0, 10.0, absf(sin(a)) * absf(sin(a)))
				var y := sin(a) * (24.0 if sin(a) > 0.0 else 40.0)
				pts.append(Vector2(cos(a) * r, y + 6.0))
			sil(ci, [pg(pts, s, FIG, 0), stk(Vector2(0, -32), Vector2(4, -42), 3.0, s + 1, LEAF_D, 2)], rim)
			ci.draw_colored_polygon(ell(Vector2(8, 18), Vector2(8, 6), s, 0.05, 12), Color("e86a7a"))
			for k in 4:
				ci.draw_circle(Vector2(4.0 + float(k) * 3.0, 17.0 + float(k % 2) * 3.0), 1.4, Color("ffd2b0"))
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
			sil(ci, [pg(rot_pts(pts, 0.5, Vector2(0, 6)), s, MANGO, 0), stk(Vector2(-14, -22), Vector2(-16, -32), 2.4, s + 1, WOOD_D, 2),
				leaf(Vector2(-15, -30), 22, 7, -2.6, s + 2)], rim)
			ci.draw_colored_polygon(ell(Vector2(-10, -6), Vector2(12, 14), s, 0.05, 12, 0.5), Color(0.9, 0.25, 0.2, 0.35))
		11:
			sil(ci, [ov(Vector2(-10, 0), 20, 34, s, PAPAYA.darkened(0.05), 0.35), ov(Vector2(18, 14), 16, 28, s + 1, PAPAYA, 0.35)], rim)
			ci.draw_colored_polygon(ell(Vector2(18, 14), Vector2(11, 22), s + 2, 0.05, 16, 0.35), Color("ff9f50"))
			for k in 8:
				ci.draw_circle(Vector2(18, 14) + Vector2(cos(float(k) * 1.6) * 3.0, -14.0 + float(k) * 4.0).rotated(0.35) - Vector2(18, 14).rotated(0.35) + Vector2(18, 14), 2.6, INK)
			ln(ci, Vector2(-22, -26), Vector2(-26, -36), 2.6, WOOD_D, s)
		12:
			sil(ci, [circ(Vector2(-10, 4), 30, s, COCO), ov(Vector2(22, 26), 20, 12, s + 1, COCO.darkened(0.1), 0.0, 1)], rim)
			ci.draw_colored_polygon(ell(Vector2(22, 22), Vector2(16, 7), s + 2, 0.05, 14), BONE)
			for k in 3:
				ci.draw_circle(Vector2(-18.0 + float(k) * 8.0, -8.0 + float(k % 2) * 3.0), 2.6, FUR_D)
			for k in 10:
				var a := float(k) * 0.6 + 0.3
				ln(ci, Vector2(-10, 4) + Vector2(cos(a), sin(a)) * 18.0, Vector2(-10, 4) + Vector2(cos(a), sin(a)) * 26.0, 1.4, Color(INK, 0.4), s + k)
		13:
			sil(ci, [ov(Vector2(-6, 0), 40, 32, s, MELON, -0.15),
				pg([Vector2(14, 34), Vector2(46, 34), Vector2(30, 6)], s + 1, Color("4c9a3a"))], rim)
			for k in 5:
				var x := -36.0 + float(k) * 15.0
				pl(ci, [Vector2(x, -24 + absf(x) * 0.3), Vector2(x + 4, 0), Vector2(x, 26 - absf(x) * 0.3)], 5.0, Color("2f6b22"), s + k)
			ci.draw_colored_polygon(poly([Vector2(17, 31), Vector2(43, 31), Vector2(30, 10)], s), Color("ef4a4a"))
			for p in [Vector2(26, 26), Vector2(33, 26), Vector2(30, 19)]:
				ci.draw_circle(p, 1.6, INK)
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

static func sub(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			sil(ci, [ov(Vector2(-12, 14), 7, 11, s, SEED, -0.5), ov(Vector2(12, 16), 7, 11, s + 1, SEED, 0.5),
				ov(Vector2(0, 0), 8, 12, s + 2, SEED.lightened(0.12))], rim)
		2:
			for k in 2:
				var c := Vector2(-12.0 + float(k) * 22.0, 6.0 + float(k) * 4.0)
				var a := -0.4 + float(k) * 0.8
				var pts := [Vector2(0, -24), Vector2(10, -2), Vector2(8, 16), Vector2(0, 22), Vector2(-8, 16), Vector2(-10, -2)]
				sil(ci, [pg(rot_pts(pts, a, c), s + k, Color("3a3438"), 0)], rim)
				for j in 3:
					var x := -5.0 + float(j) * 5.0
					ln(ci, c + Vector2(x, -18).rotated(a), c + Vector2(x * 1.2, 16).rotated(a), 2.0, BONE2, s + j)
		3:
			var pts := arcp(Vector2(0, -10), Vector2(42, 34), PI * 0.15, PI * 0.85, 12)
			pts.append_array(arcp(Vector2(0, -24), Vector2(36, 34), PI * 0.8, PI * 0.2, 12))
			sil(ci, [pg(pts, s, LEAF, 0), stk(Vector2(34, 2), Vector2(42, -8), 2.4, s + 1, LEAF_D, 2)], rim)
			for k in 4:
				var x := -18.0 + float(k) * 12.0
				ci.draw_circle(Vector2(x, 14.0 + absf(x) * -0.06), 6.0, Color("a5d65a"))
				outline(ci, ell(Vector2(x, 14.0 + absf(x) * -0.06), Vector2(6, 6), s + k, 0.0, 12), 1.6)
		4:
			sil(ci, [ov(Vector2(0, 10), 20, 24, s, SEED.lightened(0.05)),
				ov(Vector2(0, -12), 24, 12, s + 1, WOOD_D.lightened(0.1), 0.0, 1),
				stk(Vector2(0, -22), Vector2(4, -30), 2.4, s + 2, WOOD_D, 2)], rim)
			for k in 5:
				ln(ci, Vector2(-18.0 + float(k) * 9.0, -16), Vector2(-16.0 + float(k) * 8.0, -6), 1.4, Color(INK, 0.5), s + k)
			ci.draw_circle(Vector2(0, 33), 2.0, WOOD_D)
		5:
			var parts := []
			for r in 5:
				var w := 20.0 - absf(float(r) - 1.5) * 4.0
				for k in 3:
					parts.append(ov(Vector2((float(k) - 1.0) * w * 0.7, -22.0 + float(r) * 12.0), 9, 7, s + r * 3 + k, WOOD.darkened(0.05 * float(k % 2)), 0.0, 1))
			parts.append(stk(Vector2(0, -34), Vector2(2, -44), 2.4, s + 30, WOOD_D, 2))
			sil(ci, parts, rim)
		6:
			sil(ci, [circ(Vector2(0, 4), 30, s, Color("c9a06a"))], rim)
			ln(ci, Vector2(0, -26), Vector2(0, 34), 2.4, INK, s)
			for k in 6:
				var y := -18.0 + float(k) * 8.0
				pl(ci, [Vector2(-22, y), Vector2(-14, y + 3), Vector2(-6, y - 2)], 1.6, Color(INK, 0.5), s + k)
				pl(ci, [Vector2(6, y + 2), Vector2(14, y - 2), Vector2(22, y + 3)], 1.6, Color(INK, 0.5), s + k + 9)
		7:
			sil(ci, [ov(Vector2(0, 10), 26, 22, s, SEED), stk(Vector2(2, -6), Vector2(-4, -30), 2.6, s + 1, LEAF, 2),
				leaf(Vector2(-4, -28), 14, 5, -2.6, s + 2), leaf(Vector2(-4, -28), 14, 5, -0.4, s + 3)], rim)
			pl(ci, [Vector2(-18, 2), Vector2(-8, 8), Vector2(-2, 2), Vector2(6, 10), Vector2(14, 4)], 2.0, INK, s)
		8:
			sil(ci, [ov(Vector2(0, 24), 36, 13, s, Color("7a4f2a"), 0.0, 1), stk(Vector2(0, 16), Vector2(0, -6), 2.8, s + 1, LEAF, 2),
				leaf(Vector2(0, -6), 18, 6, -2.5, s + 2), leaf(Vector2(0, -6), 18, 6, -0.6, s + 3)], rim)
			for k in 4:
				ci.draw_circle(Vector2(-22.0 + float(k) * 14.0, 24.0 + float(k % 2) * 4.0), 1.8, Color(INK, 0.4))
		9:
			sil(ci, [ov(Vector2(0, 26), 38, 13, s, Color("7a4f2a"), 0.0, 1), stk(Vector2(0, 18), Vector2(0, -12), 3.0, s + 1, LEAF_D, 2),
				leaf(Vector2(0, -12), 30, 11, -2.6, s + 2), leaf(Vector2(0, -12), 30, 11, -0.5, s + 3)], rim)
			vein(ci, Vector2(0, -12), 30, -2.6, s)
			vein(ci, Vector2(0, -12), 30, -0.5, s + 1)
		10:
			sil(ci, [ov(Vector2(0, 30), 38, 12, s, Color("7a4f2a"), 0.0, 1), stk(Vector2(0, 24), Vector2(0, -34), 3.4, s + 1, WOOD, 2),
				leaf(Vector2(0, -6), 26, 9, -2.7, s + 2), leaf(Vector2(0, -2), 26, 9, -0.4, s + 3),
				leaf(Vector2(0, -24), 22, 8, -2.4, s + 4), leaf(Vector2(0, -22), 22, 8, -0.7, s + 5),
				leaf(Vector2(0, -34), 18, 7, -1.57, s + 6)], rim)
		11:
			sil(ci, [ov(Vector2(0, 22), 26, 18, s, Color("c9a06a"), 0.0, 1), stk(Vector2(0, 10), Vector2(0, -36), 3.6, s + 1, WOOD, 2),
				leaf(Vector2(0, -10), 26, 9, -2.7, s + 2), leaf(Vector2(0, -6), 26, 9, -0.4, s + 3),
				leaf(Vector2(0, -26), 22, 8, -2.4, s + 4), leaf(Vector2(0, -24), 22, 8, -0.7, s + 5),
				leaf(Vector2(0, -36), 18, 7, -1.57, s + 6)], rim)
			pl(ci, [Vector2(-25, 18), Vector2(0, 24), Vector2(25, 18)], 3.0, ROPE, s)
			rope(ci, Vector2(0, 40), Vector2(0, 6), 0.8, 2, 7.0, s)
			for k in 3:
				ln(ci, Vector2(-14.0 + float(k) * 12.0, 28), Vector2(-12.0 + float(k) * 12.0, 38), 1.4, Color(INK, 0.4), s + k)
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
