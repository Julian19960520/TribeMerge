class_name PACloth
extends PA
## 衣服线：编织架 / 草编衣物 / 战斗防具

const BARK := Color("9a6a3e")
const RATTAN := Color("c99a4a")

static func _vest(sc: float = 1.0, oy: float = 0.0) -> Array:
	var base := [Vector2(-14, -36), Vector2(-6, -30), Vector2(0, -12), Vector2(6, -30), Vector2(14, -36), Vector2(32, -28),
		Vector2(30, -6), Vector2(26, 36), Vector2(-26, 36), Vector2(-30, -6), Vector2(-32, -28)]
	var out := []
	for p in base:
		out.append((p as Vector2) * sc + Vector2(0, oy))
	return out

static func _tunic(sc: float = 1.0) -> Array:
	var base := [Vector2(-14, -36), Vector2(0, -26), Vector2(14, -36), Vector2(30, -30), Vector2(46, -8), Vector2(36, 0),
		Vector2(28, -10), Vector2(28, 38), Vector2(-28, 38), Vector2(-28, -10), Vector2(-36, 0), Vector2(-46, -8), Vector2(-30, -30)]
	var out := []
	for p in base:
		out.append((p as Vector2) * sc)
	return out

static func _strands(ci: CanvasItem, x0: float, x1: float, y0: float, y1: float, n: int, col: Color, s: int) -> void:
	for k in n:
		var x := lerpf(x0, x1, float(k) / float(n - 1))
		ln(ci, Vector2(x, y0), Vector2(x * 1.08, y1), 1.6, col, s + k)

static func _loom(c: Vector2, w: float, h: float, s: int) -> Array:
	return [stk(c + Vector2(-w, -h), c + Vector2(-w, h), 4.0, s, WOOD_D), stk(c + Vector2(w, -h), c + Vector2(w, h), 4.0, s + 1, WOOD_D),
		stk(c + Vector2(-w - 6, -h + 4), c + Vector2(w + 6, -h + 4), 4.0, s + 2, WOOD)]

static func gen(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			var pts := arcp(Vector2(0, 34), Vector2(42, 56), PI, TAU, 16)
			sil(ci, [pg(pts, s, GRASS, 0)], rim)
			for k in 7:
				var x := -30.0 + float(k) * 10.0
				ln(ci, Vector2(x, 30), Vector2(x * 0.6, -4.0 - (30.0 - absf(x)) * 0.5), 1.6, GRASS_D, s + k)
			for k in 4:
				ln(ci, Vector2(-10.0 + float(k) * 8.0, -20), Vector2(-14.0 + float(k) * 10.0, -30), 1.8, GRASS_D, s + k + 9)
		2:
			var parts := [stk(Vector2(-40, 38), Vector2(-24, -34), 3.4, s, WOOD_D), stk(Vector2(-8, 38), Vector2(-24, -34), 3.4, s + 1, WOOD_D),
				stk(Vector2(40, 38), Vector2(24, -34), 3.4, s + 2, WOOD_D), stk(Vector2(8, 38), Vector2(24, -34), 3.4, s + 3, WOOD_D),
				stk(Vector2(-34, -26), Vector2(34, -26), 3.0, s + 4, WOOD)]
			for k in 4:
				var x := -18.0 + float(k) * 12.0
				parts.append(pg([Vector2(x - 5, -26), Vector2(x + 5, -26), Vector2(x + 4, 6), Vector2(x - 4, 6)], s + 10 + k, GRASS if k % 2 == 0 else GRASS_D.lightened(0.15)))
			sil(ci, parts, rim)
		3:
			sil(ci, [stk(Vector2(-36, -32), Vector2(36, -32), 3.6, s, WOOD), stk(Vector2(-36, 32), Vector2(36, 32), 3.6, s + 1, WOOD),
				stk(Vector2(-32, -36), Vector2(-32, 36), 3.6, s + 2, WOOD), stk(Vector2(32, -36), Vector2(32, 36), 3.6, s + 3, WOOD)], rim)
			ci.draw_rect(Rect2(-29, -29, 58, 34), GRASS)
			weave(ci, Rect2(-29, -29, 58, 34), s, Color(GRASS_D.darkened(0.3), 0.7))
			_strands(ci, -26, 26, 5, 28, 7, GRASS_D, s)
			for p in [Vector2(-32, -32), Vector2(32, -32), Vector2(-32, 32), Vector2(32, 32)]:
				ci.draw_circle(p, 4.0, ROPE)
		4:
			var parts := _loom(Vector2(0, 0), 32, 36, s)
			sil(ci, parts, rim)
			ci.draw_rect(Rect2(-26, -30, 52, 18), ROPE)
			weave(ci, Rect2(-26, -30, 52, 18), s)
			_strands(ci, -24, 24, -12, 22, 8, ROPE.darkened(0.2), s)
			var stones := []
			for k in 4:
				stones.append(ov(Vector2(-21.0 + float(k) * 14.0, 26), 5, 6, s + 20 + k, STONE))
			sil(ci, stones, false)
		5:
			var parts := [stk(Vector2(-20, -6), Vector2(-30, -40), 2.0, s, BONE2, 2), stk(Vector2(18, -6), Vector2(34, -36), 2.0, s + 1, BONE2, 2),
				circ(Vector2(-10, -6), 13, s + 2, CLAY), circ(Vector2(12, -8), 12, s + 3, TEAL), circ(Vector2(0, -16), 11, s + 4, OCHRE)]
			parts.append_array(_basket_body(Vector2(0, -2), 36, 40, s + 6))
			sil(ci, parts, rim)
			weave(ci, Rect2(-28, 6, 56, 30), s)
			for c in [[Vector2(-10, -6), 13.0], [Vector2(12, -8), 12.0], [Vector2(0, -16), 11.0]]:
				ci.draw_arc(c[0], c[1] * 0.6, 0.3, 2.6, 8, Color(1, 1, 1, 0.5), 1.6, true)
		6:
			var parts := _loom(Vector2(0, 0), 36, 38, s)
			parts.append(stk(Vector2(-42, 30), Vector2(42, 30), 4.0, s + 5, WOOD))
			sil(ci, parts, rim)
			var cloth := Rect2(-30, -32, 60, 40)
			ci.draw_rect(cloth, BONE2)
			for k in 3:
				ci.draw_rect(Rect2(-30, -26.0 + float(k) * 12.0, 60, 5), [CLAY, TEAL, OCHRE][k])
			ci.draw_rect(cloth, INK, false, 1.6)
			_strands(ci, -28, 28, 8, 30, 9, ROPE.darkened(0.2), s)
			sil(ci, [stk(Vector2(-40, 12), Vector2(40, 8), 3.0, s + 8, BONE2, 1)], false)
		7:
			var parts := _loom(Vector2(-18, -4), 22, 34, s)
			parts.append(stk(Vector2(10, -30), Vector2(46, -30), 2.2, s + 6, WOOD_D, 2))
			parts.append(pg([Vector2(16, -30), Vector2(40, -30), Vector2(38, -4), Vector2(18, -8)], s + 7, BERRY, 1))
			parts.append_array([ov(Vector2(24, 24), 22, 16, s + 8, CLAYPOT)])
			parts.append(ov(Vector2(24, 12), 20, 5, s + 9, CLAYPOT.darkened(0.1), 0.0, 1))
			sil(ci, parts, rim)
			ci.draw_colored_polygon(ell(Vector2(24, 12), Vector2(16, 3.5), s, 0.0, 14), TEAL)
			ci.draw_rect(Rect2(-36, -30, 36, 26), TEAL.lightened(0.2))
			zig(ci, -34, -2, -17, 3, 6, CLAY, 2.0, s)
			ci.draw_rect(Rect2(-36, -30, 36, 26), INK, false, 1.4)
			_strands(ci, -34, -2, -4, 26, 6, ROPE.darkened(0.2), s)
			steam(ci, Vector2(24, 6), 2, 16)
		_:
			glow(ci, Vector2(0, -6), 54, GOLD)
			var parts := _loom(Vector2(0, 2), 40, 38, s)
			parts.append(stk(Vector2(-46, 34), Vector2(46, 34), 4.0, s + 5, WOOD))
			for k in 5:
				parts.append(leaf(Vector2(-24.0 + float(k) * 12.0, -36), 20, 4.5, -PI * 0.5 + (float(k) - 2.0) * 0.25, s + 10 + k, [BERRY, TEAL, OCHRE, TEAL, BERRY][k]))
			sil(ci, parts, rim)
			var r := Rect2(-34, -30, 68, 50)
			ci.draw_rect(r, Color("f3dfb8"))
			ci.draw_rect(Rect2(-34, -24, 68, 9), CLAY)
			ci.draw_rect(Rect2(-34, -2, 68, 9), TEAL)
			zig(ci, -32, 32, -19.5, 3.0, 10, GOLD, 2.2, s)
			zig(ci, -32, 32, 2.5, 3.0, 10, GOLD, 2.2, s + 1)
			for k in 4:
				ci.draw_colored_polygon(star_pts(Vector2(-24.0 + float(k) * 16.0, 13), 4, 1.8, 4, s + k), OCHRE)
			ci.draw_rect(r, INK, false, 1.6)
			sparks(ci, [Vector2(-44, -40), Vector2(44, -42), Vector2(40, 24)])

static func main(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			var arr := [Vector2(-32, 22), Vector2(-16, 6), Vector2(0, 14), Vector2(14, -2), Vector2(30, -18)]
			var parts := []
			for i in arr.size() - 1:
				parts.append(stk(arr[i], arr[i + 1], 5.0, s + i, GRASS, 2))
			sil(ci, parts, rim)
			for i in 12:
				var t := float(i) / 11.0
				var k := mini(int(t * 3.999), 3)
				var p: Vector2 = (arr[k] as Vector2).lerp(arr[k + 1], t * 4.0 - float(k))
				ln(ci, p + Vector2(-3, -3), p + Vector2(3, 3), 1.6, GRASS_D, s + i)
		2:
			sil(ci, ring(Vector2(0, 4), 26, 7.0, s, GRASS), rim)
			for k in 14:
				var a := TAU * float(k) / 14.0
				ln(ci, Vector2(0, 4) + Vector2(cos(a), sin(a)) * 20.0, Vector2(0, 4) + Vector2(cos(a + 0.2), sin(a + 0.2)) * 32.0, 1.6, GRASS_D, s + k)
		3:
			var parts := ring(Vector2(0, 10), 30, 5.0, s, GRASS_D)
			for k in 5:
				parts.append(leaf(Vector2(-16.0 + float(k) * 8.0, 6.0 + absf(float(k) - 2.0) * 2.0), 20, 6, -PI * 0.5 + (float(k) - 2.0) * 0.4, s + 2 + k))
			sil(ci, parts, rim)
			for k in 8:
				var a := PI * 0.15 + float(k) * 0.35
				ln(ci, Vector2(0, 10) + Vector2(cos(a), sin(a)) * 26.0, Vector2(0, 10) + Vector2(cos(a + 0.2), sin(a + 0.2)) * 34.0, 1.6, GRASS_D.darkened(0.3), s + k)
		4:
			var parts := [bx(-42, -10, 84, 14, 6, s, GRASS), pg([Vector2(-8, -14), Vector2(8, -14), Vector2(10, 8), Vector2(-10, 8)], s + 1, GRASS_D)]
			for k in 4:
				var x := -9.0 + float(k) * 6.0
				parts.append(stk(Vector2(x, 6), Vector2(x * 1.4, 34), 2.2, s + 2 + k, GRASS, 2))
			sil(ci, parts, rim)
			for k in 10:
				var x := -38.0 + float(k) * 8.4
				ln(ci, Vector2(x, -8), Vector2(x + 4, 2), 1.4, GRASS_D, s + k)
		5:
			var parts := []
			for k in 13:
				var x := -26.0 + float(k) * 4.3
				var w := 3.4
				var top := -14.0
				var bot := 34.0 - absf(float(k) - 6.0) * 0.6
				parts.append(pg([Vector2(x - w, top), Vector2(x + w, top), Vector2(x * 1.35 + w, bot), Vector2(x * 1.35 - w, bot)], s + k, GRASS if k % 2 == 0 else GRASS.darkened(0.1)))
			parts.append(bx(-32, -22, 64, 12, 5, s + 20, LEATHER))
			sil(ci, parts, rim)
			ci.draw_circle(Vector2(0, -16), 4, BERRY)
		6:
			var parts := []
			for row in 3:
				var n := 5 + row
				for k in n:
					var t := float(k) / float(n - 1)
					var a := lerpf(0.35, PI - 0.35, t)
					var base := Vector2(cos(a) * (16.0 + float(row) * 9.0), -18.0 + sin(a) * (8.0 + float(row) * 10.0))
					parts.append(leaf(base, 20.0 + float(row) * 2.0, 7, a, s + row * 10 + k, LEAF if (k + row) % 2 == 0 else LEAF_D.lightened(0.15)))
			parts.append(band(Vector2(0, -26), 14, 3.0, 0.1, PI - 0.1, s + 40, ROPE.darkened(0.1)))
			sil(ci, parts, rim)
		7:
			sil(ci, [pg(_vest(), s, GRASS, 0)], rim)
			weave(ci, Rect2(-24, -22, 18, 54), s, Color(GRASS_D.darkened(0.3), 0.6))
			weave(ci, Rect2(6, -22, 18, 54), s + 3, Color(GRASS_D.darkened(0.3), 0.6))
			ln(ci, Vector2(0, -12), Vector2(0, 36), 2.0, INK, s)
			_strands(ci, -24, 24, 36, 42, 9, GRASS_D, s)
		8:
			sil(ci, [pg(_tunic(), s, BARK, 0)], rim)
			for k in 6:
				var x := -20.0 + float(k) * 8.0
				pl(ci, [Vector2(x, -18), Vector2(x + 2, 0), Vector2(x - 1, 16), Vector2(x + 1, 34)], 1.5, Color(INK, 0.4), s + k)
			pl(ci, [Vector2(-28, 10), Vector2(0, 14), Vector2(28, 10)], 4.0, ROPE, s)
			ci.draw_circle(Vector2(-4, 13), 3.0, ROPE.darkened(0.2))
		9:
			var parts := [ov(Vector2(0, 18), 48, 12, s, RATTAN.darkened(0.08), 0.0, 1),
				pg([Vector2(-34, 16), Vector2(0, -30), Vector2(34, 16)], s + 1, RATTAN), circ(Vector2(0, -30), 4, s + 2, WOOD_D, 1)]
			sil(ci, parts, rim)
			for k in 7:
				var x := -30.0 + float(k) * 10.0
				ln(ci, Vector2(0, -28), Vector2(x, 16), 1.4, Color(INK, 0.45), s + k)
			for k in 3:
				var y := -14.0 + float(k) * 10.0
				var w := (y + 30.0) * 0.74
				ln(ci, Vector2(-w, y), Vector2(w, y), 1.4, Color(INK, 0.4), s + k + 9)
			pl(ci, [Vector2(-30, 20), Vector2(-18, 34), Vector2(0, 38)], 2.0, ROPE, s)
		10:
			var parts := []
			var cols := [TEAL, BERRY, OCHRE, BERRY, TEAL]
			for k in 5:
				var a := -PI * 0.5 + (float(k) - 2.0) * 0.32
				parts.append(leaf(Vector2((float(k) - 2.0) * 9.0, 8), 40.0 - absf(float(k) - 2.0) * 5.0, 6.5, a, s + k, cols[k]))
			parts.append(bx(-36, 4, 72, 14, 6, s + 10, LEATHER))
			sil(ci, parts, rim)
			for k in 5:
				var a := -PI * 0.5 + (float(k) - 2.0) * 0.32
				vein(ci, Vector2((float(k) - 2.0) * 9.0, 8), 40.0 - absf(float(k) - 2.0) * 5.0, a, s + k, Color(INK, 0.5))
			zig(ci, -32, 32, 11, 2.4, 12, BONE, 1.8, s)
		11:
			var fr := []
			for k in 8:
				fr.append(pg([Vector2(-26.0 + float(k) * 7.4, 34), Vector2(-22.0 + float(k) * 7.4, 44), Vector2(-18.0 + float(k) * 7.4, 34)], s + 20 + k, FUR))
			fr.append(pg(_vest(), s, Color("d0975a"), 0))
			sil(ci, fr, rim)
			for k in 6:
				var p := Vector2((srnd(s + k) - 0.5) * 40.0, (srnd(s + k + 7) - 0.3) * 50.0)
				ci.draw_colored_polygon(ell(p, Vector2(4, 3), s + k, 0.15, 10), Color(FUR_D, 0.8))
			ln(ci, Vector2(0, -12), Vector2(0, 34), 2.0, INK, s)
			for y in [0.0, 14.0]:
				ln(ci, Vector2(-5, y), Vector2(5, y + 4), 2.4, ROPE, s)
		12:
			var cloak := [Vector2(-18, -32), Vector2(18, -32), Vector2(40, 30), Vector2(26, 42), Vector2(8, 36), Vector2(-8, 42), Vector2(-26, 36), Vector2(-40, 30)]
			sil(ci, [pg(cloak, s, FUR, 0), ov(Vector2(0, -32), 26, 10, s + 1, Color("e8d8b8"), 0.0, 1)], rim)
			for k in 7:
				var x := -24.0 + float(k) * 8.0
				ln(ci, Vector2(x * 0.7, -18), Vector2(x * 1.2, 32), 1.6, Color(FUR_D, 0.7), s + k)
			for k in 8:
				ln(ci, Vector2(-22.0 + float(k) * 6.0, -38), Vector2(-24.0 + float(k) * 6.0, -30), 1.6, Color(INK, 0.3), s + k + 9)
			sil(ci, [stk(Vector2(-10, -26), Vector2(10, -26), 3.0, s + 30, BONE2)], false)
		_:
			glow(ci, Vector2(0, -6), 54, GOLD)
			var parts := []
			for k in 9:
				var a := lerpf(PI * 1.1, PI * 1.9, float(k) / 8.0)
				parts.append(leaf(Vector2(0, -26), 30, 6, a, s + k, [BERRY, OCHRE, TEAL][k % 3]))
			var robe := [Vector2(-16, -30), Vector2(16, -30), Vector2(38, -20), Vector2(42, 42), Vector2(-42, 42), Vector2(-38, -20)]
			parts.append(pg(robe, s + 10, CLAY, 0))
			parts.append(ov(Vector2(0, -26), 24, 9, s + 11, Color("e8d8b8"), 0.0, 1))
			sil(ci, parts, rim)
			ci.draw_rect(Rect2(-6, -18, 12, 60), OCHRE)
			for y in [2.0, 24.0]:
				zig(ci, -38, 38, y, 3.0, 12, GOLD, 2.2, s + int(y))
			for k in 3:
				ci.draw_circle(Vector2(0, -8.0 + float(k) * 16.0), 3.0, TEAL)
			pl(ci, [Vector2(-38, 34), Vector2(38, 34)], 2.0, Color(INK, 0.5), s)
			sparks(ci, [Vector2(-44, -40), Vector2(44, -40), Vector2(42, 20)])

static func sub(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			sil(ci, [bx(-22, -24, 44, 52, 12, s, LEATHER, 0)], rim)
			for k in 4:
				var y := -14.0 + float(k) * 10.0
				ln(ci, Vector2(-6, y), Vector2(6, y + 8), 1.8, ROPE, s + k)
				ln(ci, Vector2(6, y), Vector2(-6, y + 8), 1.8, ROPE, s + k + 5)
			ln(ci, Vector2(-20, -16), Vector2(20, -16), 1.4, Color(INK, 0.4), s)
			ln(ci, Vector2(-20, 20), Vector2(20, 20), 1.4, Color(INK, 0.4), s + 1)
		2:
			var parts := [bx(-24, -26, 48, 56, 12, s, LEATHER, 1)]
			for k in 3:
				parts.append(bx(-18 + float(k) * 13.0, -18, 10, 40, 5, s + 2 + k, BONE2, 1))
			sil(ci, parts, rim)
			for k in 3:
				ci.draw_circle(Vector2(-13.0 + float(k) * 13.0, -12), 1.6, INK)
				ci.draw_circle(Vector2(-13.0 + float(k) * 13.0, 16), 1.6, INK)
		3:
			var pad := [Vector2(-22, -24), Vector2(22, -24), Vector2(28, 0), Vector2(18, 30), Vector2(0, 36), Vector2(-18, 30), Vector2(-28, 0)]
			sil(ci, [bx(-38, -12, 76, 10, 4, s, LEATHER_D), bx(-38, 12, 76, 10, 4, s + 1, LEATHER_D), pg(pad, s + 2, LEATHER, 0)], rim)
			dashed(ci, poly([Vector2(-16, -18), Vector2(16, -18), Vector2(21, 0), Vector2(13, 24), Vector2(0, 29), Vector2(-13, 24), Vector2(-21, 0)], s), 4, 3, ROPE, 1.6)
		4:
			sil(ci, [circ(Vector2(0, 4), 36, s, WOOD, 0)], rim)
			for k in 4:
				var x := -18.0 + float(k) * 12.0
				ln(ci, Vector2(x, -28 + absf(x) * 0.3), Vector2(x, 36 - absf(x) * 0.3), 1.8, WOOD_D, s + k)
			ci.draw_arc(Vector2(0, 4), 31, 0, TAU, 32, WOOD_D, 3.0, true)
			sil(ci, [circ(Vector2(0, 4), 9, s + 5, STONE)], false)
		5:
			sil(ci, [pg(_vest(), s, RATTAN, 0)], rim)
			weave(ci, Rect2(-26, -24, 20, 58), s, Color(WOOD_D, 0.6))
			weave(ci, Rect2(6, -24, 20, 58), s + 2, Color(WOOD_D, 0.6))
			ln(ci, Vector2(0, -12), Vector2(0, 36), 2.0, INK, s)
			for y in [-4.0, 12.0, 26.0]:
				ln(ci, Vector2(-6, y), Vector2(6, y), 3.0, LEATHER_D, s)
		6:
			sil(ci, [pg(_vest(), s, LEATHER, 0)], rim)
			for r in 4:
				for k in 5:
					var x := -20.0 + float(k) * 10.0
					var y := -18.0 + float(r) * 13.0
					if absf(x) < 4.0 and y < -10.0:
						continue
					var b := rrect(Rect2(x - 4, y, 8, 11), 3.5, s + r * 5 + k, 0.4)
					ci.draw_colored_polygon(b, BONE2)
					outline(ci, b, 1.4)
		7:
			var parts := [ov(Vector2(-28, 14), 8, 16, s, FUR, 0.2, 1), ov(Vector2(28, 14), 8, 16, s + 1, FUR, -0.2, 1),
				pg(arcp(Vector2(0, 10), Vector2(32, 38), PI, TAU, 16), s + 2, LEATHER, 0),
				bx(-36, 4, 72, 12, 6, s + 3, Color("e8d8b8"))]
			sil(ci, parts, rim)
			for k in 3:
				ln(ci, Vector2(0, -26), Vector2(-20.0 + float(k) * 20.0, 4), 1.6, Color(INK, 0.4), s + k)
			for k in 9:
				ln(ci, Vector2(-32.0 + float(k) * 8.0, 6), Vector2(-33.0 + float(k) * 8.0, 14), 1.4, Color(INK, 0.3), s + k)
		8:
			sil(ci, [pg([Vector2(-22, 2), Vector2(-46, -14), Vector2(-40, -36), Vector2(-36, -16), Vector2(-16, -6)], s, BONE2),
				pg([Vector2(22, 2), Vector2(46, -14), Vector2(40, -36), Vector2(36, -16), Vector2(16, -6)], s + 1, BONE2),
				pg(arcp(Vector2(0, 16), Vector2(30, 38), PI, TAU, 16), s + 2, STONE, 0),
				bx(-34, 10, 68, 12, 6, s + 3, LEATHER)], rim)
			ln(ci, Vector2(0, -20), Vector2(0, 10), 2.0, Color(INK, 0.5), s)
			for k in 7:
				ci.draw_circle(Vector2(-27.0 + float(k) * 9.0, 16), 1.8, INK)
		9:
			sil(ci, [ov(Vector2(0, 2), 34, 44, s, RATTAN, 0.0, 0)], rim)
			var arr := []
			for k in 50:
				var t := float(k) / 49.0
				var a := t * TAU * 2.6
				arr.append(Vector2(0, 2) + Vector2(cos(a) * 26.0, sin(a) * 34.0) * (1.0 - t * 0.92))
			pl(ci, arr, 4.0, CLAY, s)
			ci.draw_arc(Vector2(0, 2), 30, 0, TAU, 32, WOOD_D, 2.0, true)
			for k in 4:
				ln(ci, Vector2(-30, -16.0 + float(k) * 12.0), Vector2(30, -16.0 + float(k) * 12.0), 1.0, Color(WOOD_D, 0.4), s + k)
		10:
			sil(ci, [pg(_vest(1.05), s, Color("6f8a6a"), 0)], rim)
			for r in 6:
				for k in 7:
					var x := -26.0 + float(k) * 8.6 + (4.3 if r % 2 == 1 else 0.0)
					var y := -18.0 + float(r) * 9.0
					if absf(x) < 5.0 and y < -6.0:
						continue
					if absf(x) > 28.0:
						continue
					ci.draw_arc(Vector2(x, y), 4.6, 0.2, PI - 0.2, 6, Color(INK, 0.55), 1.6, true)
			ln(ci, Vector2(0, -12), Vector2(0, 38), 2.0, INK, s)
		_:
			glow(ci, Vector2(0, -4), 54, GOLD)
			var parts := [pg([Vector2(-26, -22), Vector2(-54, -6), Vector2(-50, -40), Vector2(-40, -16)], s, BONE, 1),
				pg([Vector2(26, -22), Vector2(54, -6), Vector2(50, -40), Vector2(40, -16)], s + 1, BONE, 1),
				ov(Vector2(-30, -18), 14, 10, s + 2, FUR, 0.0, 1), ov(Vector2(30, -18), 14, 10, s + 3, FUR, 0.0, 1),
				pg(_vest(1.0, 4.0), s + 4, Color("7a5a3a"), 0)]
			sil(ci, parts, rim)
			for r in 3:
				for k in 4:
					var x := -15.0 + float(k) * 10.0
					var b := rrect(Rect2(x - 4, -6.0 + float(r) * 12.0, 8, 10), 3.5, s + r * 4 + k, 0.4)
					ci.draw_colored_polygon(b, BONE2)
					outline(ci, b, 1.3)
			ci.draw_circle(Vector2(0, -14), 5.0, AMBER)
			outline(ci, ell(Vector2(0, -14), Vector2(5, 5), s, 0.0, 12), 1.6)
			sparks(ci, [Vector2(-46, -46), Vector2(46, -48), Vector2(40, 30)])
