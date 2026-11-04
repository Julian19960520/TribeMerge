class_name PAWood
extends PA
## 木头工艺线：木工桩 / 家具 / 木头工艺品

const FACE := Color("e8c48a")
const PLANK := Color("c48a4a")

## 竖着的圆木段：c 是顶面中心
static func _log_up(c: Vector2, w: float, h: float, s: int, col: Color = WOOD) -> Array:
	var body := arcp(c + Vector2(0, h), Vector2(w, w * 0.32), 0.0, PI, 10)
	body.append(c + Vector2(-w, 0))
	body.append(c + Vector2(w, 0))
	return [pg(body, s, col, 1), ov(c, w, w * 0.32, s + 1, FACE, 0.0, 1)]

static func _bark(ci: CanvasItem, c: Vector2, w: float, h: float, s: int) -> void:
	for k in 4:
		var x := c.x - w * 0.7 + float(k) * w * 0.45
		pl(ci, [Vector2(x, c.y + w * 0.35), Vector2(x + 2, c.y + h * 0.5), Vector2(x - 1, c.y + h + w * 0.1)], 1.5, Color(WOOD_D, 0.7), s + k)

static func _plank_lines(ci: CanvasItem, r: Rect2, n: int, s: int, vertical: bool = false) -> void:
	for k in range(1, n):
		var t := float(k) / float(n)
		if vertical:
			var x := r.position.x + r.size.x * t
			ln(ci, Vector2(x, r.position.y + 2), Vector2(x, r.end.y - 2), 1.6, Color(WOOD_D, 0.8), s + k)
		else:
			var y := r.position.y + r.size.y * t
			ln(ci, Vector2(r.position.x + 2, y), Vector2(r.end.x - 2, y), 1.6, Color(WOOD_D, 0.8), s + k)

static func _nails(ci: CanvasItem, pts: Array) -> void:
	for p in pts:
		ci.draw_circle(p, 1.8, WOOD_D.darkened(0.3))

static func gen(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			sil(ci, [bx(-30, -4, 74, 30, 14, s, WOOD), ov(Vector2(-30, 11), 10, 15, s + 1, FACE, 0.0, 1),
				stk(Vector2(10, -2), Vector2(18, -18), 2.6, s + 2, WOOD_D, 2), leaf(Vector2(18, -18), 14, 5, -0.8, s + 3)], rim)
			rings(ci, Vector2(-30, 11), Vector2(10, 15), s, 3)
			for k in 3:
				ln(ci, Vector2(-14.0 + float(k) * 18.0, 4), Vector2(-2.0 + float(k) * 18.0, 6), 1.5, Color(WOOD_D, 0.7), s + k)
		2:
			var cs := [Vector2(-24, 22), Vector2(0, 22), Vector2(24, 22), Vector2(-12, 2), Vector2(12, 2), Vector2(0, -18)]
			var parts := []
			for i in cs.size():
				var c: Vector2 = cs[i]
				parts.append(pg([c + Vector2(-12, 8), c + Vector2(0, -12), c + Vector2(12, 8)], s + i, FACE if i % 2 == 0 else FACE.darkened(0.06), 0))
			sil(ci, parts, rim)
			for c in cs:
				var v: Vector2 = c
				ln(ci, v + Vector2(-6, 6), v + Vector2(0, -4), 1.4, Color(WOOD_D, 0.6), s)
				ln(ci, v + Vector2(-12, 8), v + Vector2(12, 8), 3.0, WOOD, s + 1)
		3:
			var parts := _log_up(Vector2(0, -4), 30, 36, s)
			parts.append(stk(Vector2(-8, -10), Vector2(-32, -36), 3.0, s + 3, WOOD_D))
			parts.append(pg([Vector2(-12, -14), Vector2(4, -22), Vector2(8, -10), Vector2(-4, -4)], s + 4, STONE))
			sil(ci, parts, rim)
			rings(ci, Vector2(0, -4), Vector2(30, 9.6), s, 2)
			_bark(ci, Vector2(0, -4), 30, 36, s)
		4:
			var parts := [stk(Vector2(-30, 30), Vector2(-46, 40), 4.0, s, WOOD_D), stk(Vector2(30, 30), Vector2(46, 40), 4.0, s + 1, WOOD_D)]
			parts.append_array(_log_up(Vector2(0, -2), 36, 36, s + 2))
			parts.append(stk(Vector2(10, -6), Vector2(36, -38), 4.0, s + 5, WOOD))
			parts.append(pg([Vector2(-2, -14), Vector2(18, -18), Vector2(22, -4), Vector2(2, 2)], s + 6, Color("918b84")))
			sil(ci, parts, rim)
			rope(ci, Vector2(10, -6), Vector2(36, -38), 0.2, 2, 5.0, s)
			rings(ci, Vector2(0, -2), Vector2(36, 11.5), s, 2)
			_bark(ci, Vector2(0, -2), 36, 36, s)
			for p in [Vector2(-40, 30), Vector2(-30, 36), Vector2(36, 26)]:
				var v: Vector2 = p
				var ch := poly([v, v + Vector2(6, -2), v + Vector2(4, 3)], s)
				ci.draw_colored_polygon(ch, FACE)
				outline(ci, ch, 1.2)
		5:
			var parts := [stk(Vector2(-30, -6), Vector2(-42, 40), 3.4, s, WOOD_D), stk(Vector2(-30, -6), Vector2(-18, 40), 3.4, s + 1, WOOD_D),
				stk(Vector2(30, -6), Vector2(18, 40), 3.4, s + 2, WOOD_D), stk(Vector2(30, -6), Vector2(42, 40), 3.4, s + 3, WOOD_D),
				bx(-48, -14, 96, 12, 3, s + 4, PLANK), bx(-12, -30, 30, 10, 4, s + 5, WOOD_D.lightened(0.1)),
				pg([Vector2(-10, -22), Vector2(14, -22), Vector2(12, -16), Vector2(-8, -16)], s + 6, STONE)]
			sil(ci, parts, rim)
			for k in 4:
				var x := 24.0 + float(k) * 5.0
				ci.draw_arc(Vector2(x, -18), 4, PI, TAU, 6, FACE.darkened(0.1), 2.0, true)
		6:
			var parts := [stk(Vector2(-40, 40), Vector2(-40, -26), 3.6, s, WOOD_D), stk(Vector2(40, 40), Vector2(40, -14), 3.6, s + 1, WOOD_D),
				pg([Vector2(-50, -32), Vector2(50, -20), Vector2(50, -12), Vector2(-50, -24)], s + 2, PLANK),
				bx(-30, 18, 16, 22, 2, s + 3, PLANK), bx(-12, 10, 14, 30, 2, s + 4, PLANK.darkened(0.06)),
				bx(10, 26, 24, 14, 3, s + 5, WOOD)]
			sil(ci, parts, rim)
			_plank_lines(ci, Rect2(-50, -32, 100, 18), 6, s, true)
			sil(ci, [stk(Vector2(-20, -18), Vector2(-20, -4), 1.2, s + 6, ROPE, 2), pg([Vector2(-26, -4), Vector2(-14, -4), Vector2(-16, 6), Vector2(-24, 6)], s + 7, STONE),
				stk(Vector2(18, -14), Vector2(18, 0), 1.2, s + 8, ROPE, 2), pg([Vector2(14, 0), Vector2(26, 0), Vector2(22, 8), Vector2(12, 4)], s + 9, STONE)], false)
		_:
			glow(ci, Vector2(0, -6), 54, GOLD)
			var parts := [stk(Vector2(-40, 0), Vector2(-40, 40), 5.0, s, WOOD_D), stk(Vector2(40, 0), Vector2(40, 40), 5.0, s + 1, WOOD_D),
				bx(-50, -6, 100, 14, 4, s + 2, PLANK), bx(-14, -50, 28, 46, 8, s + 3, WOOD)]
			parts.append(pg([Vector2(-14, -40), Vector2(-28, -52), Vector2(-20, -36)], s + 4, WOOD))
			parts.append(pg([Vector2(14, -40), Vector2(28, -52), Vector2(20, -36)], s + 5, WOOD))
			parts.append(stk(Vector2(26, -12), Vector2(44, -28), 2.6, s + 6, WOOD_D, 2))
			parts.append(ov(Vector2(-32, -12), 8, 5, s + 7, STONE))
			sil(ci, parts, rim)
			eye(ci, Vector2(-6, -36), 4)
			eye(ci, Vector2(6, -36), 4)
			ci.draw_rect(Rect2(-8, -24, 16, 5), INK)
			zig(ci, -12, 12, -14, 2.5, 6, CLAY, 2.0, s)
			ln(ci, Vector2(-48, 1), Vector2(48, 1), 1.6, WOOD_D, s)
			for p in [Vector2(-22, -10), Vector2(30, -12), Vector2(18, -10)]:
				var v: Vector2 = p
				var ch := poly([v, v + Vector2(6, -2), v + Vector2(4, 3)], s)
				ci.draw_colored_polygon(ch, FACE)
				outline(ci, ch, 1.2)
			sparks(ci, [Vector2(-40, -40), Vector2(40, -44), Vector2(30, 20)])

static func main(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			sil(ci, _log_up(Vector2(0, 0), 24, 22, s), rim)
			rings(ci, Vector2(0, 0), Vector2(24, 7.7), s, 3)
			_bark(ci, Vector2(0, 0), 24, 22, s)
		2:
			var parts := [pg([Vector2(-26, 24), Vector2(-42, 36), Vector2(-20, 32)], s, WOOD_D), pg([Vector2(26, 24), Vector2(44, 34), Vector2(20, 32)], s + 1, WOOD_D),
				pg([Vector2(-4, 30), Vector2(-8, 42), Vector2(6, 32)], s + 2, WOOD_D)]
			parts.append_array(_log_up(Vector2(0, -6), 30, 34, s + 3))
			parts.append(leaf(Vector2(-24, -2), 14, 5, 2.4, s + 6, MOSS))
			sil(ci, parts, rim)
			rings(ci, Vector2(0, -6), Vector2(30, 9.6), s, 3)
			_bark(ci, Vector2(0, -6), 30, 34, s)
		3:
			sil(ci, [stk(Vector2(-16, -2), Vector2(-26, 36), 3.6, s, WOOD_D), stk(Vector2(16, -2), Vector2(26, 36), 3.6, s + 1, WOOD_D),
				stk(Vector2(0, 0), Vector2(0, 30), 3.6, s + 2, WOOD_D.darkened(0.1)), stk(Vector2(-22, 20), Vector2(22, 20), 2.4, s + 3, WOOD_D, 2),
				ov(Vector2(0, -6), 32, 11, s + 4, WOOD, 0.0, 1)], rim)
			rings(ci, Vector2(0, -6), Vector2(32, 11), s, 2)
		4:
			sil(ci, [bx(-22, 16, 44, 18, 4, s, WOOD_D), stk(Vector2(-8, 2), Vector2(-8, 18), 4.0, s + 1, WOOD),
				stk(Vector2(8, 2), Vector2(8, 18), 4.0, s + 2, WOOD), band(Vector2(0, -38), 40, 6.0, PI * 0.22, PI * 0.78, s + 3, PLANK)], rim)
			zig(ci, -18, 18, 25, 2.4, 8, OCHRE, 1.8, s)
		5:
			sil(ci, [bx(-38, 2, 14, 32, 4, s, WOOD_D), bx(24, 2, 14, 32, 4, s + 1, WOOD_D),
				bx(-46, -12, 92, 16, 6, s + 2, PLANK)], rim)
			_plank_lines(ci, Rect2(-46, -12, 92, 16), 3, s, true)
			_nails(ci, [Vector2(-31, -4), Vector2(31, -4)])
		6:
			var parts := [stk(Vector2(-34, -40), Vector2(-34, 40), 3.6, s, WOOD_D), stk(Vector2(34, -40), Vector2(34, 40), 3.6, s + 1, WOOD_D),
				bx(-40, -12, 80, 8, 3, s + 2, PLANK), bx(-40, 22, 80, 8, 3, s + 3, PLANK),
				ov(Vector2(-16, -22), 10, 10, s + 4, CLAYPOT), ov(Vector2(12, -22), 8, 10, s + 5, TAN),
				bx(-22, 8, 18, 14, 3, s + 6, ROPE.darkened(0.1)), circ(Vector2(16, 14), 8, s + 7, BERRY)]
			sil(ci, parts, rim)
			_nails(ci, [Vector2(-34, -8), Vector2(34, -8), Vector2(-34, 26), Vector2(34, 26)])
		7:
			sil(ci, [bx(-38, -18, 76, 54, 6, s, PLANK), bx(-42, -26, 84, 14, 5, s + 1, WOOD)], rim)
			_plank_lines(ci, Rect2(-38, -12, 76, 48), 4, s)
			ln(ci, Vector2(-30, -10), Vector2(30, 34), 3.0, Color(WOOD_D, 0.8), s)
			pl(ci, [Vector2(-10, -26), Vector2(0, -34), Vector2(10, -26)], 3.0, ROPE, s)
			_nails(ci, [Vector2(-32, -6), Vector2(32, -6), Vector2(-32, 30), Vector2(32, 30)])
		8:
			var parts := [band(Vector2(0, -26), 64, 4.0, PI * 0.3, PI * 0.7, s, WOOD_D)]
			parts.append(pg([Vector2(-36, -16), Vector2(36, -16), Vector2(30, 22), Vector2(-30, 22)], s + 1, WOOD))
			parts.append(pg([Vector2(-36, -16), Vector2(-28, -36), Vector2(-14, -16)], s + 2, WOOD.darkened(0.05)))
			parts.append(ov(Vector2(6, -16), 24, 6, s + 3, Color("e8d8b8"), 0.0, 1))
			sil(ci, parts, rim)
			weave(ci, Rect2(-30, -10, 60, 28), s)
		9:
			sil(ci, [stk(Vector2(-36, 0), Vector2(-42, 34), 4.0, s, WOOD_D), stk(Vector2(-28, 0), Vector2(-24, 34), 4.0, s + 1, WOOD_D),
				stk(Vector2(36, 0), Vector2(42, 34), 4.0, s + 2, WOOD_D), stk(Vector2(28, 0), Vector2(24, 34), 4.0, s + 3, WOOD_D),
				bx(-50, -10, 100, 14, 6, s + 4, PLANK)], rim)
			_plank_lines(ci, Rect2(-50, -10, 100, 14), 2, s)
			for k in 3:
				ln(ci, Vector2(-30.0 + float(k) * 30.0, -6), Vector2(-18.0 + float(k) * 30.0, -6), 1.4, Color(WOOD_D, 0.6), s + k)
		10:
			sil(ci, [bx(-50, -28, 12, 64, 4, s, WOOD_D), bx(40, -6, 10, 42, 4, s + 1, WOOD_D),
				bx(-46, 4, 92, 18, 5, s + 2, PLANK), pg([Vector2(-36, 4), Vector2(42, 4), Vector2(44, -4), Vector2(-20, -10)], s + 3, FUR),
				ov(Vector2(-28, -6), 12, 7, s + 4, BONE2)], rim)
			for k in 5:
				ln(ci, Vector2(-14.0 + float(k) * 12.0, -6), Vector2(-12.0 + float(k) * 12.0, 4), 1.6, Color(FUR_D, 0.7), s + k)
			_plank_lines(ci, Rect2(-46, 4, 92, 18), 2, s)
		11:
			sil(ci, [bx(-34, -40, 68, 78, 6, s, PLANK), bx(-38, -46, 76, 10, 4, s + 1, WOOD)], rim)
			ci.draw_rect(Rect2(-28, -32, 26, 62), PLANK.lightened(0.08))
			ci.draw_rect(Rect2(2, -32, 26, 62), PLANK.lightened(0.08))
			ci.draw_rect(Rect2(-28, -32, 26, 62), INK, false, 1.8)
			ci.draw_rect(Rect2(2, -32, 26, 62), INK, false, 1.8)
			for x in [-6.0, 6.0]:
				ci.draw_circle(Vector2(x, 0), 3.0, BONE2)
			zig(ci, -26, -4, -20, 2.4, 6, CLAY, 1.8, s)
			zig(ci, 4, 26, -20, 2.4, 6, CLAY, 1.8, s + 1)
		12:
			var back := [Vector2(-24, -4), Vector2(-28, -44), Vector2(-14, -50), Vector2(0, -44), Vector2(14, -50), Vector2(28, -44), Vector2(24, -4)]
			sil(ci, [pg(back, s, WOOD), stk(Vector2(-22, 6), Vector2(-26, 40), 3.8, s + 1, WOOD_D), stk(Vector2(22, 6), Vector2(26, 40), 3.8, s + 2, WOOD_D),
				bx(-32, -6, 64, 14, 5, s + 3, PLANK)], rim)
			ci.draw_circle(Vector2(0, -30), 7, OCHRE)
			outline(ci, ell(Vector2(0, -30), Vector2(7, 7), s, 0.0, 12), 1.6)
			for k in 2:
				ln(ci, Vector2(-14.0 + float(k) * 28.0, -40), Vector2(-14.0 + float(k) * 28.0, -10), 1.6, Color(WOOD_D, 0.7), s + k)
		_:
			glow(ci, Vector2(0, -10), 54, GOLD)
			var back := [Vector2(-30, 0), Vector2(-34, -40), Vector2(-14, -48), Vector2(0, -42), Vector2(14, -48), Vector2(34, -40), Vector2(30, 0)]
			sil(ci, [pg([Vector2(-30, -36), Vector2(-50, -54), Vector2(-40, -30)], s, BONE), pg([Vector2(30, -36), Vector2(50, -54), Vector2(40, -30)], s + 1, BONE),
				pg(back, s + 2, WOOD), bx(-42, 0, 14, 40, 5, s + 3, WOOD_D), bx(28, 0, 14, 40, 5, s + 4, WOOD_D),
				bx(-36, 2, 72, 18, 6, s + 5, CLAY), ov(Vector2(0, 0), 32, 6, s + 6, FUR, 0.0, 1)], rim)
			eye(ci, Vector2(-8, -30), 4.5)
			eye(ci, Vector2(8, -30), 4.5)
			ci.draw_rect(Rect2(-10, -18, 20, 5), INK)
			zig(ci, -30, 30, 12, 3, 10, GOLD, 2.2, s)
			for k in 2:
				ci.draw_circle(Vector2(-35.0 + float(k) * 70.0, -2), 5, AMBER)
			sparks(ci, [Vector2(-44, -10), Vector2(44, -14), Vector2(0, -56)])

static func sub(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			var parts := []
			var pts := arcp(Vector2(0, -16), Vector2(30, 40), PI * 0.15, PI * 0.85, 4)
			for i in pts.size():
				parts.append(circ(pts[i], 8, s + i, WOOD if i % 2 == 0 else FACE.darkened(0.1)))
			ci.draw_arc(Vector2(0, -16), 30, PI * 0.08, PI * 0.92, 14, INK, 3.0, true)
			sil(ci, parts, rim)
			for p in pts:
				ci.draw_circle(p, 2.0, WOOD_D)
		2:
			sil(ci, [stk(Vector2(-34, 34), Vector2(6, -4), 4.0, s, WOOD), ov(Vector2(16, -16), 16, 12, s + 1, WOOD, -0.8)], rim)
			ci.draw_colored_polygon(ell(Vector2(17, -17), Vector2(11, 7), s + 2, 0.0, 12, -0.8), WOOD_D.lightened(0.15))
		3:
			var parts := [bx(-34, -24, 68, 18, 8, s, PLANK)]
			for k in 9:
				parts.append(stk(Vector2(-28.0 + float(k) * 7.0, -10), Vector2(-28.0 + float(k) * 7.0, 26), 2.4, s + k + 1, PLANK, 2))
			sil(ci, parts, rim)
			zig(ci, -28, 28, -16, 2.4, 8, CLAY, 1.8, s)
		4:
			sil(ci, [bx(-36, -8, 60, 18, 9, s, WOOD), pg([Vector2(24, -8), Vector2(36, -4), Vector2(36, 6), Vector2(24, 10)], s + 1, WOOD_D)], rim)
			ci.draw_circle(Vector2(-4, -2), 3.4, INK)
			ci.draw_arc(Vector2(-30, 1), 18, PI * 0.5, PI * 1.2, 10, ROPE, 2.4, true)
			ln(ci, Vector2(-30, -6), Vector2(-30, 8), 1.6, Color(INK, 0.4), s)
		5:
			sil(ci, [pg(arcp(Vector2(0, 0), Vector2(36, 30), 0.0, PI, 14), s, WOOD, 0), ov(Vector2(0, 0), 36, 9, s + 1, WOOD_D, 0.0, 1),
				bx(-12, 26, 24, 8, 3, s + 2, WOOD_D)], rim)
			ci.draw_colored_polygon(ell(Vector2(0, 1), Vector2(30, 6), s, 0.0, 16), Color("4a2a12"))
			zig(ci, -30, 30, 12, 2.4, 10, OCHRE, 1.8, s)
		6:
			sil(ci, [pg([Vector2(-28, -8), Vector2(28, -8), Vector2(0, 34)], s, WOOD, 0), ov(Vector2(0, -8), 28, 9, s + 1, PLANK, 0.0, 1),
				stk(Vector2(0, -12), Vector2(0, -30), 3.4, s + 2, WOOD_D)], rim)
			for k in 3:
				ci.draw_arc(Vector2(0, -8), 18.0 + float(k) * 4.0, PI * 0.15, PI * 0.85, 8, CLAY if k % 2 == 0 else TEAL, 2.4, true)
			for k in 3:
				ci.draw_arc(Vector2(0, 30), 30.0 + float(k) * 6.0, PI * 1.2, PI * 1.35, 4, Color(INK, 0.4), 1.6, true)
		7:
			var body := [Vector2(-38, 0), Vector2(-14, -18), Vector2(16, -14), Vector2(28, -2), Vector2(42, -16), Vector2(40, 16), Vector2(28, 4), Vector2(14, 16), Vector2(-14, 18)]
			sil(ci, [pg(body, s, WOOD, 0)], rim)
			ci.draw_circle(Vector2(-24, -3), 3, INK)
			pl(ci, [Vector2(-14, -12), Vector2(-10, 0), Vector2(-14, 12)], 1.8, INK, s)
			for k in 3:
				pl(ci, [Vector2(-4.0 + float(k) * 10.0, -10), Vector2(2.0 + float(k) * 10.0, 0), Vector2(-4.0 + float(k) * 10.0, 10)], 1.6, Color(WOOD_D, 0.8), s + k)
		8:
			sil(ci, [bx(-26, 26, 52, 12, 4, s, WOOD_D), stk(Vector2(0, 16), Vector2(0, 28), 3.0, s + 1, WOOD_D),
				ov(Vector2(4, 4), 24, 14, s + 2, WOOD, -0.15), circ(Vector2(-20, -12), 11, s + 3, WOOD),
				pg([Vector2(-30, -12), Vector2(-42, -8), Vector2(-30, -6)], s + 4, OCHRE),
				pg([Vector2(22, 0), Vector2(42, -16), Vector2(36, 6)], s + 5, WOOD.darkened(0.08))], rim)
			ci.draw_circle(Vector2(-22, -14), 2.4, INK)
			for k in 3:
				pl(ci, [Vector2(-4.0 + float(k) * 8.0, -2), Vector2(4.0 + float(k) * 8.0, 6)], 1.6, Color(WOOD_D, 0.8), s + k)
		9:
			sil(ci, [ov(Vector2(0, 0), 32, 42, s, WOOD, 0.0, 1)], rim)
			for p in [Vector2(-12, -10), Vector2(12, -10)]:
				var e := ell(p, Vector2(8, 6), s, 0.06, 12)
				ci.draw_colored_polygon(e, Color("2a170c"))
				outline(ci, e, 1.8)
			ci.draw_colored_polygon(poly([Vector2(-4, -2), Vector2(4, -2), Vector2(6, 14), Vector2(-6, 14)], s), WOOD.darkened(0.15))
			ci.draw_colored_polygon(ell(Vector2(0, 26), Vector2(12, 4), s, 0.0, 12), Color("2a170c"))
			for k in 3:
				ln(ci, Vector2(-26, -24.0 + float(k) * 6.0), Vector2(-16, -24.0 + float(k) * 6.0), 2.4, CLAY, s + k)
				ln(ci, Vector2(16, -24.0 + float(k) * 6.0), Vector2(26, -24.0 + float(k) * 6.0), 2.4, CLAY, s + k + 5)
			zig(ci, -20, 20, 34, 2.4, 6, TEAL, 2.0, s)
		10:
			var parts := _log_up(Vector2(0, -18), 30, 50, s)
			parts[1] = ov(Vector2(0, -18), 30, 9.6, s + 1, Color("efdcb6"), 0.0, 1)
			sil(ci, parts, rim)
			for k in 6:
				var x := -26.0 + float(k) * 10.4
				ln(ci, Vector2(x, -12), Vector2(x + 5.0, 26), 2.0, ROPE, s + k)
				ln(ci, Vector2(x + 5.0, -12), Vector2(x, 26), 2.0, ROPE, s + k + 7)
			ci.draw_arc(Vector2(0, -6), 30, PI * 0.1, PI * 0.9, 12, CLAY, 3.0, true)
		_:
			glow(ci, Vector2(0, -6), 54, GOLD)
			var parts := [bx(-14, -32, 28, 74, 6, s, WOOD),
				pg([Vector2(-12, -34), Vector2(-50, -44), Vector2(-46, -30), Vector2(-12, -24)], s + 1, CLAY),
				pg([Vector2(12, -34), Vector2(50, -44), Vector2(46, -30), Vector2(12, -24)], s + 2, CLAY),
				pg([Vector2(-14, -32), Vector2(0, -52), Vector2(14, -32)], s + 3, OCHRE)]
			sil(ci, parts, rim)
			for k in 3:
				var y := -22.0 + float(k) * 22.0
				eye(ci, Vector2(-6, y), 3.4)
				eye(ci, Vector2(6, y), 3.4)
				ci.draw_rect(Rect2(-6, y + 7, 12, 3.5), INK)
				ln(ci, Vector2(-14, y + 13), Vector2(14, y + 13), 1.6, WOOD_D, s + k)
			zig(ci, -46, -16, -36, 2.0, 6, GOLD, 1.8, s)
			zig(ci, 16, 46, -36, 2.0, 6, GOLD, 1.8, s + 1)
			sparks(ci, [Vector2(-36, -12), Vector2(36, -14), Vector2(30, 30)])
