class_name PAFood
extends PA
## 食物线：采集篮 / 水果 / 种子到树苗

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

static func gen(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
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

static func sub(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
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
