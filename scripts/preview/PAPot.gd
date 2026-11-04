class_name PAPot
extends PA
## 陶艺线：陶窑 / 陶器皿 / 陶制工艺品

const RAW := Color("c99a6a")
const FIRED := Color("c8693a")
const PAINT := Color("e8a060")
const DARK := Color("3a2418")

## 旋转体器皿；mouth 为真时在口沿画一圈深色内壁
static func vessel(ci: CanvasItem, prof: Array, col: Color, s: int, rim: bool, extra: Array = [], mouth: bool = true) -> void:
	var parts := extra.duplicate()
	parts.append(pg(lathe(prof), s, col, 0))
	sil(ci, parts, rim)
	if mouth:
		var top: Vector2 = prof[0]
		var m := ell(Vector2(0, top.y), Vector2(top.x - 1.0, maxf(top.x * 0.22, 2.5)), s, 0.0, 16, 0.0, 0.3)
		ci.draw_colored_polygon(m, col.darkened(0.45))
		outline(ci, m, 1.8)

static func band_at(ci: CanvasItem, prof: Array, y: float, col: Color, w: float = 3.0) -> void:
	var hw := prof_w(prof, y) - 1.5
	ln(ci, Vector2(-hw, y), Vector2(hw, y), w, col, int(y))

static func zig_at(ci: CanvasItem, prof: Array, y: float, h: float, n: int, col: Color, w: float = 2.2) -> void:
	var hw := prof_w(prof, y) - 3.0
	zig(ci, -hw, hw, y, h, n, col, w, int(y))

static func spiral_at(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var arr := []
	for k in 24:
		var t := float(k) / 23.0
		var a := t * TAU * 1.6
		arr.append(c + Vector2(cos(a), sin(a) * 0.8) * r * (0.15 + t * 0.85))
	ci.draw_polyline(PackedVector2Array(arr), col, 2.4, true)

static func loop(c: Vector2, r: float, side: float, s: int, col: Color) -> Array:
	return band(c, r, 2.8, -PI * 0.5 if side > 0.0 else PI * 0.5, PI * 0.5 if side > 0.0 else PI * 1.5, s, col)

static func gen(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			sil(ci, [raw_rock(Vector2(0, 12), 30, s, RAW, 9, 0.12)], rim)
			for k in 3:
				ci.draw_arc(Vector2(-8.0 + float(k) * 9.0, 2), 4.0, 0.2, PI - 0.2, 6, Color(INK, 0.35), 2.0, true)
		2:
			sil(ci, [pg([Vector2(-40, 10), Vector2(-30, -4), Vector2(34, -8), Vector2(42, 8), Vector2(36, 30), Vector2(-34, 32)], s, RAW, 0)], rim)
			var palm := ell(Vector2(2, 12), Vector2(10, 9), s, 0.05, 12)
			ci.draw_colored_polygon(palm, RAW.darkened(0.15))
			for k in 4:
				var a := -2.4 + float(k) * 0.42
				ci.draw_colored_polygon(ell(Vector2(2, 12) + Vector2(cos(a), sin(a)) * 15.0, Vector2(2.6, 5), s + k, 0.0, 8, a + PI * 0.5), RAW.darkened(0.15))
			ci.draw_colored_polygon(ell(Vector2(14, 16), Vector2(2.6, 5), s, 0.0, 8, 0.6), RAW.darkened(0.15))
		3:
			var parts := []
			for k in 5:
				var y := 30.0 - float(k) * 9.0
				var w := 30.0 - absf(float(k) - 1.5) * 3.0
				parts.append(stk(Vector2(-w, y), Vector2(w, y), 5.0, s + k, RAW.darkened(0.03 * float(k % 2))))
			parts.append(stk(Vector2(28, -16), Vector2(42, -30), 4.0, s + 9, RAW))
			sil(ci, parts, rim)
		4:
			var prof := [Vector2(12, -26), Vector2(16, -14), Vector2(16, -4), Vector2(10, 2)]
			sil(ci, [bx(-40, 4, 80, 12, 4, s, PLANK_C), stk(Vector2(-32, 16), Vector2(-34, 38), 4.0, s + 1, WOOD_D), stk(Vector2(32, 16), Vector2(34, 38), 4.0, s + 2, WOOD_D),
				stk(Vector2(22, -4), Vector2(40, -14), 2.2, s + 3, WOOD, 2), _scallop_shell(Vector2(-28, -4), s + 4)], rim)
			vessel(ci, prof, RAW, s + 6, false)
		5:
			var prof := [Vector2(14, -34), Vector2(20, -20), Vector2(18, -8), Vector2(12, -2)]
			sil(ci, [stk(Vector2(0, 2), Vector2(0, 34), 5.0, s, WOOD_D), ov(Vector2(0, 34), 18, 5, s + 1, WOOD_D, 0.0, 1),
				ov(Vector2(0, 0), 36, 8, s + 2, WOOD, 0.0, 1)], rim)
			vessel(ci, prof, RAW, s + 3, false)
			for k in 3:
				ci.draw_arc(Vector2(0, 2), 40.0 + float(k) * 4.0, PI * 0.15, PI * 0.45, 6, Color(1, 1, 1, 0.6), 2.0, true)
		6:
			sil(ci, [ov(Vector2(0, 22), 48, 18, s, Color("6a4428"), 0.0, 1)], rim)
			ci.draw_colored_polygon(ell(Vector2(0, 22), Vector2(40, 12), s, 0.04, 18), Color("2a170c"))
			vessel(ci, [Vector2(10, -6), Vector2(14, 4), Vector2(12, 16)], FIRED, s + 2, false)
			sil(ci, [ov(Vector2(-24, 18), 12, 9, s + 4, FIRED), ov(Vector2(24, 18), 12, 9, s + 5, FIRED.darkened(0.06))], false)
			flame(ci, Vector2(-14, 8), 9, 24, s + 6)
			flame(ci, Vector2(14, 8), 9, 26, s + 7)
			sil(ci, [stk(Vector2(-34, 30), Vector2(34, 26), 3.4, s + 8, WOOD)], false)
		7:
			var dome := arcp(Vector2(0, 36), Vector2(40, 64), PI, TAU, 18)
			sil(ci, [stk(Vector2(0, -26), Vector2(0, -40), 6.0, s, TAN_D), pg(dome, s + 1, TAN, 0),
				ov(Vector2(-40, 30), 10, 8, s + 2, FIRED), ov(Vector2(40, 32), 8, 7, s + 3, FIRED.darkened(0.05))], rim)
			var door := arcp(Vector2(0, 36), Vector2(14, 22), PI, TAU, 10)
			ci.draw_colored_polygon(poly(door, s), Color("2a170c"))
			flame(ci, Vector2(0, 26), 9, 20, s + 4)
			outline(ci, poly(door, s), 2.0)
			smoke(ci, Vector2(2, -46), 0.8)
		8:
			sil(ci, [stk(Vector2(26, -30), Vector2(28, -50), 6.0, s, TAN_D), bx(-44, 4, 88, 36, 10, s + 1, TAN.darkened(0.05)),
				pg(arcp(Vector2(0, 6), Vector2(38, 46), PI, TAU, 16), s + 2, TAN, 0)], rim)
			var d1 := arcp(Vector2(0, 40), Vector2(12, 18), PI, TAU, 8)
			ci.draw_colored_polygon(poly(d1, s), Color("2a170c"))
			flame(ci, Vector2(0, 32), 8, 16, s + 3)
			outline(ci, poly(d1, s), 2.0)
			var d2 := rrect(Rect2(-12, -26, 24, 26), 8, s, 0.5)
			ci.draw_colored_polygon(d2, Color("5a3418"))
			outline(ci, d2, 2.0)
			ln(ci, Vector2(-42, 8), Vector2(42, 8), 2.0, Color(INK, 0.5), s)
			smoke(ci, Vector2(30, -56), 0.8)
		_:
			glow(ci, Vector2(0, -6), 54, GOLD)
			sil(ci, [stk(Vector2(26, -34), Vector2(28, -52), 6.0, s, TAN_D), bx(-46, 2, 92, 38, 10, s + 1, Color("e09a5a")),
				pg(arcp(Vector2(0, 4), Vector2(40, 48), PI, TAU, 16), s + 2, Color("e8aa6a"), 0),
				ov(Vector2(-46, 30), 9, 10, s + 3, PAINT), ov(Vector2(46, 30), 9, 10, s + 4, PAINT)], rim)
			var d1 := arcp(Vector2(0, 40), Vector2(12, 18), PI, TAU, 8)
			ci.draw_colored_polygon(poly(d1, s), Color("2a170c"))
			flame(ci, Vector2(0, 32), 8, 16, s + 5)
			zig(ci, -40, 40, 10, 3, 14, DARK, 2.4, s)
			spiral_at(ci, Vector2(-20, -16), 9, DARK)
			spiral_at(ci, Vector2(20, -16), 9, DARK)
			ci.draw_circle(Vector2(0, -24), 5, CLAY)
			smoke(ci, Vector2(30, -58), 0.8)
			sparks(ci, [Vector2(-44, -36), Vector2(42, -30), Vector2(0, -56)])

const PLANK_C := Color("c48a4a")

static func _scallop_shell(c: Vector2, s: int) -> Array:
	return pg(arcp(c, Vector2(9, 8), PI, TAU, 8) + [c + Vector2(3, 6), c + Vector2(-3, 6)], s, SHELL)

static func main(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			sil(ci, [circ(Vector2(0, 10), 22, s, RAW)], rim)
			ci.draw_arc(Vector2(-4, 6), 8, 0.4, 2.2, 8, Color(INK, 0.3), 2.0, true)
		2:
			var prof := [Vector2(16, -12), Vector2(15, 8), Vector2(12, 24), Vector2(8, 30)]
			vessel(ci, prof, RAW.darkened(0.05), s, rim)
		3:
			var prof := [Vector2(34, -6), Vector2(30, 10), Vector2(20, 22), Vector2(12, 26)]
			vessel(ci, prof, FIRED, s, rim)
			band_at(ci, prof, 4, CLAY.darkened(0.2), 2.4)
		4:
			sil(ci, [ov(Vector2(0, 14), 44, 16, s, FIRED, 0.0, 0)], rim)
			ci.draw_colored_polygon(ell(Vector2(0, 10), Vector2(36, 10), s + 1, 0.0, 18), FIRED.darkened(0.2))
			outline(ci, ell(Vector2(0, 10), Vector2(36, 10), s + 1, 0.0, 18), 1.8)
			ci.draw_colored_polygon(ell(Vector2(-6, 10), Vector2(18, 4), s + 2, 0.0, 14), Color(1, 1, 1, 0.15))
		5:
			var prof := [Vector2(14, -30), Vector2(16, -24), Vector2(28, -6), Vector2(28, 14), Vector2(18, 32)]
			vessel(ci, prof, FIRED, s, rim)
			zig_at(ci, prof, -10, 3, 8, CLAY.darkened(0.25))
		6:
			var prof := [Vector2(14, -32), Vector2(16, -26), Vector2(30, -8), Vector2(30, 12), Vector2(18, 34)]
			vessel(ci, prof, FIRED, s, rim, [loop(Vector2(-30, -6), 9, -1, s + 1, FIRED.darkened(0.06)), loop(Vector2(30, -6), 9, 1, s + 2, FIRED.darkened(0.06))])
			band_at(ci, prof, -14, CLAY.darkened(0.25))
			band_at(ci, prof, 18, CLAY.darkened(0.25))
		7:
			var prof := [Vector2(10, -34), Vector2(12, -24), Vector2(28, -4), Vector2(28, 16), Vector2(16, 34)]
			vessel(ci, prof, FIRED, s, rim, [pg([Vector2(-18, -18), Vector2(-40, -32), Vector2(-36, -24), Vector2(-24, -8)], s + 1, FIRED.darkened(0.04)),
				band(Vector2(30, -6), 14, 3.2, -PI * 0.6, PI * 0.45, s + 2, FIRED.darkened(0.08))])
			zig_at(ci, prof, 0, 3, 8, CLAY.darkened(0.25))
		8:
			var prof := [Vector2(34, -18), Vector2(32, -4), Vector2(24, 12), Vector2(10, 18)]
			vessel(ci, prof, FIRED.darkened(0.1), s, rim, [stk(Vector2(-18, 8), Vector2(-24, 40), 4.5, s + 1, FIRED.darkened(0.2)),
				stk(Vector2(18, 8), Vector2(24, 40), 4.5, s + 2, FIRED.darkened(0.2)), stk(Vector2(0, 10), Vector2(0, 38), 4.5, s + 3, FIRED.darkened(0.28)),
				bx(-30, -30, 8, 14, 3, s + 4, FIRED.darkened(0.1)), bx(22, -30, 8, 14, 3, s + 5, FIRED.darkened(0.1))])
			zig_at(ci, prof, -6, 2.6, 10, DARK)
		9:
			var low := [Vector2(20, 4), Vector2(30, 16), Vector2(26, 30), Vector2(14, 38)]
			var up := [Vector2(28, -30), Vector2(26, -12), Vector2(18, 4)]
			vessel(ci, low, FIRED.darkened(0.08), s, rim, [], false)
			vessel(ci, up, FIRED, s + 1, rim)
			for k in 5:
				ci.draw_circle(Vector2(-14.0 + float(k) * 7.0, -6), 2.0, DARK)
			steam(ci, Vector2(0, -36), 3, 16)
		10:
			var prof := [Vector2(5, -44), Vector2(8, -36), Vector2(16, -24), Vector2(18, -4), Vector2(12, 20), Vector2(4, 38), Vector2(1, 42)]
			vessel(ci, prof, PAINT.darkened(0.08), s, rim, [loop(Vector2(-18, -6), 6, -1, s + 1, PAINT.darkened(0.15)), loop(Vector2(18, -6), 6, 1, s + 2, PAINT.darkened(0.15))])
			for k in 4:
				band_at(ci, prof, -20.0 + float(k) * 9.0, Color(DARK, 0.7), 1.6)
		11:
			var prof := [Vector2(32, -36), Vector2(36, -28), Vector2(42, -6), Vector2(40, 16), Vector2(28, 36)]
			vessel(ci, prof, FIRED.darkened(0.05), s, rim)
			band_at(ci, prof, -26, CLAY.darkened(0.3), 3.0)
			for k in 6:
				ci.draw_arc(Vector2(-28.0 + float(k) * 11.0, 6), 5, 0.0, PI, 6, Color(INK, 0.45), 2.0, true)
			band_at(ci, prof, 22, CLAY.darkened(0.3), 3.0)
		12:
			var prof := [Vector2(14, -34), Vector2(16, -28), Vector2(32, -10), Vector2(32, 10), Vector2(18, 34)]
			vessel(ci, prof, PAINT, s, rim)
			band_at(ci, prof, -22, CLAY, 3.0)
			spiral_at(ci, Vector2(-16, -12), 8, DARK)
			spiral_at(ci, Vector2(8, -14), 8, DARK)
			zig_at(ci, prof, -24, 2.4, 6, CLAY)
			zig_at(ci, prof, 20, 3, 8, DARK)
			ci.draw_circle(Vector2(-4, 2), 2.4, CLAY)
		13:
			var prof := [Vector2(44, -12), Vector2(40, 6), Vector2(28, 22), Vector2(18, 28)]
			vessel(ci, prof, PAINT, s, rim)
			ci.draw_circle(Vector2(-10, 10), 8, DARK)
			ci.draw_circle(Vector2(-10, 10), 6, PAINT)
			ln(ci, Vector2(-14, 9), Vector2(-11, 9), 1.8, DARK, s)
			ln(ci, Vector2(-9, 9), Vector2(-6, 9), 1.8, DARK, s + 1)
			ci.draw_colored_polygon(poly([Vector2(-18, 6), Vector2(-24, 2), Vector2(-20, 10)], s), DARK)
			ci.draw_colored_polygon(poly([Vector2(-2, 6), Vector2(4, 2), Vector2(0, 10)], s + 1), DARK)
			var fish := [Vector2(6, 12), Vector2(16, 6), Vector2(26, 10), Vector2(32, 6), Vector2(30, 14), Vector2(26, 12), Vector2(16, 16)]
			ci.draw_colored_polygon(poly(fish, s), DARK)
			zig_at(ci, prof, -4, 2.0, 12, DARK, 1.8)
		_:
			glow(ci, Vector2(0, 0), 54, GOLD)
			var prof := [Vector2(16, -44), Vector2(18, -36), Vector2(40, -14), Vector2(40, 10), Vector2(22, 40)]
			vessel(ci, prof, PAINT, s, rim, [loop(Vector2(-34, 8), 7, -1, s + 1, PAINT.darkened(0.12)), loop(Vector2(34, 8), 7, 1, s + 2, PAINT.darkened(0.12))])
			zig_at(ci, prof, -32, 2.4, 6, DARK)
			ci.draw_colored_polygon(poly(lathe([Vector2(38, -22), Vector2(40, -16), Vector2(39, -12)]), s), CLAY)
			spiral_at(ci, Vector2(-20, -2), 10, DARK)
			spiral_at(ci, Vector2(6, -4), 10, DARK)
			ci.draw_circle(Vector2(26, -2), 4, CLAY)
			zig_at(ci, prof, 18, 3, 10, DARK)
			band_at(ci, prof, 28, CLAY, 3.0)
			sparks(ci, [Vector2(-42, -36), Vector2(44, -34), Vector2(40, 30)])

static func sub(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			var pts := arcp(Vector2(0, -16), Vector2(28, 38), PI * 0.15, PI * 0.85, 4)
			ci.draw_arc(Vector2(0, -16), 28, PI * 0.08, PI * 0.92, 14, INK, 3.0, true)
			var parts := []
			for i in pts.size():
				parts.append(circ(pts[i], 8, s + i, FIRED if i % 2 == 0 else PAINT))
			sil(ci, parts, rim)
			for p in pts:
				ci.draw_circle(p, 2.0, DARK)
		2:
			sil(ci, [ov(Vector2(4, 4), 28, 14, s, FIRED, -0.2), bx(-38, 0, 18, 12, 4, s + 1, FIRED.darkened(0.08))], rim)
			ci.draw_circle(Vector2(6, 0), 3.6, DARK)
			ci.draw_arc(Vector2(-40, 6), 12, PI * 0.5, PI * 1.3, 8, ROPE, 2.4, true)
		3:
			sil(ci, [stk(Vector2(0, -42), Vector2(0, 40), 2.6, s, WOOD, 2), ov(Vector2(0, 8), 30, 10, s + 1, FIRED, 0.0, 1),
				pg(arcp(Vector2(0, 8), Vector2(30, 10), 0.0, PI, 10) + [Vector2(-30, 4), Vector2(30, 4)], s + 2, FIRED.darkened(0.1))], rim)
			ci.draw_colored_polygon(ell(Vector2(0, 6), Vector2(26, 7), s, 0.0, 14), FIRED)
			ci.draw_circle(Vector2(0, 6), 4, WOOD)
			zig(ci, -24, 24, 6, 2.0, 10, DARK, 1.6, s)
			pl(ci, [Vector2(0, -42), Vector2(10, -36), Vector2(-6, -28), Vector2(8, -20)], 1.6, ROPE, s)
		4:
			sil(ci, [ov(Vector2(0, 6), 24, 30, s, DARK.lightened(0.15))], rim)
			ci.draw_circle(Vector2(0, -22), 3.6, INK)
			for p in [Vector2(-10, 2), Vector2(10, 2), Vector2(-6, 16), Vector2(6, 16)]:
				ci.draw_circle(p, 3.0, INK)
			zig(ci, -18, 18, -8, 2.0, 8, CLAY, 1.6, s)
		5:
			var prof := [Vector2(6, -26), Vector2(14, -16), Vector2(22, 8), Vector2(28, 22)]
			sil(ci, [pg(lathe(prof), s, FIRED, 0), band(Vector2(0, -30), 6, 2.4, PI, TAU, s + 1, FIRED.darkened(0.1)),
				circ(Vector2(0, 30), 6, s + 2, FIRED.darkened(0.2))], rim)
			ci.draw_colored_polygon(ell(Vector2(0, 22), Vector2(27, 5), s, 0.0, 14), FIRED.darkened(0.45))
			band_at(ci, prof, 4, CLAY.darkened(0.25), 2.4)
			for k in 3:
				ci.draw_arc(Vector2(0, 26), 34.0 + float(k) * 5.0, PI * 0.1, PI * 0.25, 4, Color(INK, 0.4), 1.6, true)
		6:
			sil(ci, [bx(-22, 26, 44, 10, 4, s, FIRED.darkened(0.15)), ov(Vector2(2, 8), 26, 16, s + 1, FIRED, -0.1),
				circ(Vector2(-22, -10), 12, s + 2, FIRED), pg([Vector2(-32, -12), Vector2(-46, -8), Vector2(-32, -4)], s + 3, PAINT.darkened(0.1)),
				pg([Vector2(22, 2), Vector2(44, -12), Vector2(40, 12)], s + 4, FIRED.darkened(0.08))], rim)
			ci.draw_circle(Vector2(-24, -12), 2.4, INK)
			ci.draw_arc(Vector2(4, 6), 12, PI * 1.1, PI * 1.8, 8, DARK, 2.0, true)
		7:
			sil(ci, [ov(Vector2(4, 8), 32, 20, s, FIRED), circ(Vector2(-28, 2), 14, s + 1, FIRED),
				ov(Vector2(-40, 6), 6, 7, s + 2, FIRED.darkened(0.08)), pg([Vector2(-26, -10), Vector2(-20, -22), Vector2(-16, -8)], s + 3, FIRED.darkened(0.05)),
				stk(Vector2(-10, 22), Vector2(-12, 34), 4.0, s + 4, FIRED.darkened(0.1)), stk(Vector2(20, 22), Vector2(22, 34), 4.0, s + 5, FIRED.darkened(0.1))], rim)
			ci.draw_circle(Vector2(-42, 4), 1.6, INK)
			ci.draw_circle(Vector2(-42, 9), 1.6, INK)
			ci.draw_circle(Vector2(-28, -2), 2.4, INK)
			spiral_at(ci, Vector2(8, 6), 9, DARK)
		8:
			sil(ci, [ov(Vector2(0, 2), 32, 40, s, FIRED, 0.0, 1)], rim)
			for p in [Vector2(-12, -10), Vector2(12, -10)]:
				var e := ell(p, Vector2(7, 5), s, 0.04, 12)
				ci.draw_colored_polygon(e, DARK)
			ci.draw_colored_polygon(poly([Vector2(-4, -2), Vector2(4, -2), Vector2(0, 12)], s), FIRED.darkened(0.2))
			var m := ell(Vector2(0, 24), Vector2(10, 5), s, 0.0, 12)
			ci.draw_colored_polygon(m, DARK)
			for k in 3:
				ln(ci, Vector2(-26, -26.0 + float(k) * 8.0), Vector2(-14, -22.0 + float(k) * 8.0), 2.4, Color("f4e8d0"), s + k)
				ln(ci, Vector2(26, -26.0 + float(k) * 8.0), Vector2(14, -22.0 + float(k) * 8.0), 2.4, Color("f4e8d0"), s + k + 4)
		9:
			sil(ci, [stk(Vector2(-8, 18), Vector2(-12, 40), 5.0, s, FIRED), stk(Vector2(8, 18), Vector2(12, 40), 5.0, s + 1, FIRED),
				stk(Vector2(-14, -6), Vector2(-26, 14), 4.0, s + 2, FIRED.darkened(0.06)), stk(Vector2(14, -6), Vector2(26, 14), 4.0, s + 3, FIRED.darkened(0.06)),
				ov(Vector2(0, 6), 15, 20, s + 4, FIRED), circ(Vector2(0, -24), 12, s + 5, FIRED)], rim)
			ci.draw_circle(Vector2(-4, -26), 2.0, INK)
			ci.draw_circle(Vector2(4, -26), 2.0, INK)
			ln(ci, Vector2(-3, -19), Vector2(3, -19), 1.6, INK, s)
			zig(ci, -12, 12, 4, 2.4, 6, DARK, 1.8, s)
		10:
			sil(ci, [stk(Vector2(-12, 22), Vector2(-16, 42), 5.0, s, FIRED.darkened(0.12)), stk(Vector2(12, 22), Vector2(16, 42), 5.0, s + 1, FIRED.darkened(0.12)),
				pg([Vector2(16, 12), Vector2(36, 34), Vector2(26, 38), Vector2(12, 22)], s + 2, FIRED.darkened(0.08)),
				ov(Vector2(2, 6), 26, 24, s + 3, FIRED), circ(Vector2(-14, -24), 13, s + 4, FIRED),
				pg([Vector2(-26, -24), Vector2(-40, -18), Vector2(-28, -14), Vector2(-24, -18)], s + 5, DARK.lightened(0.2)),
				pg([Vector2(-6, -30), Vector2(10, -36), Vector2(10, -24)], s + 6, FIRED.darkened(0.06))], rim)
			ci.draw_circle(Vector2(-16, -28), 3.0, INK)
			ci.draw_circle(Vector2(-16, -28), 1.2, Color.WHITE)
			for k in 3:
				ci.draw_arc(Vector2(10, 4), 6.0 + float(k) * 6.0, PI * 1.2, PI * 1.9, 6, Color(DARK, 0.6), 2.0, true)
		_:
			glow(ci, Vector2(0, -2), 54, GOLD)
			sil(ci, [ov(Vector2(0, 14), 26, 26, s, FIRED), ov(Vector2(-14, -2), 11, 12, s + 1, FIRED.darkened(0.04)),
				ov(Vector2(14, -2), 11, 12, s + 2, FIRED.darkened(0.04)), ov(Vector2(0, -20), 12, 9, s + 3, FIRED),
				circ(Vector2(0, -34), 9, s + 4, FIRED), ov(Vector2(0, 38), 14, 5, s + 5, FIRED.darkened(0.1))], rim)
			ln(ci, Vector2(-16, 6), Vector2(16, 6), 2.2, Color(DARK, 0.6), s)
			for k in 3:
				ci.draw_arc(Vector2(0, -34), 9.0 + float(k) * 0.1, PI * 1.1, PI * 1.9, 6, DARK, 2.0, true)
			zig(ci, -20, 20, 24, 2.4, 8, DARK, 1.8, s)
			for k in 3:
				ci.draw_circle(Vector2(-6.0 + float(k) * 6.0, -24), 2.0, AMBER)
			sparks(ci, [Vector2(-38, -30), Vector2(38, -34), Vector2(36, 30)])
