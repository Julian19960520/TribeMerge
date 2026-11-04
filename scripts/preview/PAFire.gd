class_name PAFire
extends PA
## 火堆线：火塘 / 烤果蔬 / 烤肉

const CHEST := Color("7a3e1e")
const SHROOM := Color("b8743a")
const CORN := Color("f2c23a")
const YAM := Color("a8405a")
const YAM_IN := Color("f5a040")
const PUMP := Color("e8862a")
const ROASTL := Color("d0803a")

static func _stones(n: int, cx: float, y: float, w: float, s: int) -> Array:
	var out := []
	for i in n:
		out.append(ov(Vector2(cx - w * 0.5 + w * float(i) / float(n - 1), y), 9, 6, s + i, STONE, 0.0, 1))
	return out

static func _logs(y: float, s: int) -> Array:
	return [stk(Vector2(-34, y + 4), Vector2(28, y - 12), 6.0, s, WOOD), stk(Vector2(34, y + 4), Vector2(-28, y - 12), 6.0, s + 1, WOOD.darkened(0.08))]

static func _cube(c: Vector2, r: float, s: int, col: Color = ROAST) -> Array:
	return bx(c.x - r, c.y - r, r * 2.0, r * 2.0, r * 0.45, s, col)

static func _chestnut(c: Vector2, r: float, s: int) -> Array:
	var pts := [c + Vector2(0, -r * 1.15), c + Vector2(r, -r * 0.1), c + Vector2(r * 0.8, r * 0.75), c + Vector2(0, r), c + Vector2(-r * 0.8, r * 0.75), c + Vector2(-r, -r * 0.1)]
	return pg(pts, s, CHEST, 0)

static func _shroom(c: Vector2, r: float, s: int, ang: float = 0.0) -> Array:
	var stem := rot_pts([Vector2(-r * 0.35, 0), Vector2(r * 0.35, 0), Vector2(r * 0.42, r * 1.1), Vector2(-r * 0.42, r * 1.1)], ang, c)
	var cap := rot_pts(arcp(Vector2.ZERO, Vector2(r, r * 0.85), PI, TAU, 10) + [Vector2(r, r * 0.12), Vector2(-r, r * 0.12)], ang, c)
	return [pg(stem, s, BONE2), pg(cap, s + 1, SHROOM, 0)]

static func gen(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			sil(ci, [stk(Vector2(-38, 26), Vector2(34, 6), 4.0, s, WOOD_D), stk(Vector2(-30, 8), Vector2(38, 28), 4.0, s + 1, WOOD),
				stk(Vector2(-20, 34), Vector2(26, -8), 3.4, s + 2, WOOD.darkened(0.05)), stk(Vector2(10, 4), Vector2(18, -14), 2.6, s + 3, WOOD_D, 2),
				stk(Vector2(-14, 22), Vector2(-24, 8), 2.6, s + 4, WOOD, 2)], rim)
		2:
			sil(ci, [bx(-42, 18, 84, 14, 4, s, WOOD), stk(Vector2(4, 18), Vector2(-2, -38), 3.4, s + 1, WOOD_D),
				stk(Vector2(-30, -26), Vector2(30, -20), 2.4, s + 2, ROPE, 2)], rim)
			ci.draw_colored_polygon(ell(Vector2(6, 20), Vector2(5, 3), s, 0.0, 10), FIRE)
			smoke(ci, Vector2(14, 10), 0.8)
			for k in 3:
				ln(ci, Vector2(-36.0 + float(k) * 10.0, 22), Vector2(-36.0 + float(k) * 10.0, 28), 1.4, Color(INK, 0.4), s + k)
		3:
			sil(ci, [stk(Vector2(-30, 32), Vector2(26, 22), 4.0, s, WOOD), stk(Vector2(30, 32), Vector2(-26, 22), 4.0, s + 1, WOOD_D)], rim)
			flame(ci, Vector2(0, 2), 20, 52, s, rim)
		4:
			var parts := _logs(32, s)
			parts.append_array(_stones(5, 0, 38, 72, s + 4))
			sil(ci, parts, rim)
			flame(ci, Vector2(0, -6), 26, 70, s + 10, false)
		5:
			var parts := [stk(Vector2(-38, 40), Vector2(-36, -24), 3.0, s, WOOD_D), stk(Vector2(38, 40), Vector2(36, -24), 3.0, s + 1, WOOD_D),
				stk(Vector2(-36, -24), Vector2(-42, -36), 2.6, s + 2, WOOD_D, 2), stk(Vector2(-36, -24), Vector2(-30, -36), 2.6, s + 3, WOOD_D, 2),
				stk(Vector2(36, -24), Vector2(42, -36), 2.6, s + 4, WOOD_D, 2), stk(Vector2(36, -24), Vector2(30, -36), 2.6, s + 5, WOOD_D, 2)]
			parts.append_array(_stones(5, 0, 38, 64, s + 6))
			sil(ci, parts, rim)
			flame(ci, Vector2(0, 8), 20, 50, s + 10, false)
			sil(ci, [stk(Vector2(-46, -26), Vector2(46, -26), 2.4, s + 20, WOOD, 2), ov(Vector2(0, -24), 16, 10, s + 21, ROAST)], false)
			grill(ci, Vector2(0, -24), 20, 2, s)
		6:
			var parts := []
			for k in 3:
				parts.append(bx(-44, 30 - float(k) * 14.0, 22, 14, 5, s + k, STONE.darkened(0.04 * float(k))))
				parts.append(bx(22, 30 - float(k) * 14.0, 22, 14, 5, s + 3 + k, STONE.darkened(0.04 * float(k))))
			parts.append(bx(-48, -12, 96, 12, 4, s + 10, STONE_D.lightened(0.2)))
			sil(ci, parts, rim)
			ci.draw_rect(Rect2(-22, 2, 44, 42), Color("2a170c"))
			flame(ci, Vector2(0, 26), 14, 32, s + 12, false)
			sil(ci, [ov(Vector2(-14, -18), 12, 6, s + 20, ROAST), circ(Vector2(16, -18), 7, s + 21, SHROOM)], false)
			steam(ci, Vector2(0, -26), 2, 14)
		7:
			var dome := arcp(Vector2(0, 36), Vector2(44, 62), PI, TAU, 18)
			sil(ci, [stk(Vector2(18, -26), Vector2(20, -42), 6.0, s, TAN_D), pg(dome, s + 1, TAN, 0)], rim)
			var door := arcp(Vector2(0, 36), Vector2(16, 24), PI, TAU, 10)
			ci.draw_colored_polygon(poly(door, s), Color("2a170c"))
			flame(ci, Vector2(0, 26), 10, 22, s + 3, false)
			outline(ci, poly(door, s), 2.0)
			for k in 4:
				ln(ci, Vector2(-34.0 + float(k) * 6.0, 4.0 + float(k) * 6.0), Vector2(-28.0 + float(k) * 6.0, 2.0 + float(k) * 6.0), 1.6, Color(INK, 0.35), s + k)
			smoke(ci, Vector2(20, -48), 0.8)
		_:
			glow(ci, Vector2(0, -16), 54, FIRE)
			var parts := [bx(-40, 26, 80, 14, 4, s, STONE_D.lightened(0.1)), bx(-30, 10, 60, 18, 4, s + 1, STONE),
				pg([Vector2(-36, -14), Vector2(36, -14), Vector2(24, 12), Vector2(-24, 12)], s + 2, STONE.lightened(0.1), 0)]
			sil(ci, parts, rim)
			flame(ci, Vector2(0, -38), 30, 72, s + 5, false)
			zig(ci, -30, 30, -2, 3.0, 10, CLAY, 2.2, s)
			for x in [-18.0, 0.0, 18.0]:
				ci.draw_colored_polygon(star_pts(Vector2(x, 19), 4, 1.8, 4, s + int(x)), OCHRE)
			sparks(ci, [Vector2(-40, -40), Vector2(40, -44), Vector2(42, 8)])

static func main(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			var cs := [Vector2(-14, 14), Vector2(14, 16), Vector2(0, -2)]
			sil(ci, [_chestnut(cs[0], 13, s), _chestnut(cs[1], 13, s + 1), _chestnut(cs[2], 14, s + 2)], rim)
			for c in cs:
				var v: Vector2 = c
				ci.draw_colored_polygon(ell(v + Vector2(0, 8), Vector2(8, 4), s, 0.0, 10), Color("d8b07a"))
				ln(ci, v + Vector2(-4, -8), v + Vector2(4, -2), 2.0, Color("f0d090"), s)
				ln(ci, v + Vector2(4, -8), v + Vector2(-4, -2), 2.0, Color("f0d090"), s + 1)
		2:
			sil(ci, _shroom(Vector2(0, 0), 32, s), rim)
			grill(ci, Vector2(0, -10), 36, 3, s, -0.35)
			for k in 4:
				ci.draw_circle(Vector2(-16.0 + float(k) * 10.0, -16.0 + float(k % 2) * 6.0), 2.4, Color(BONE, 0.7))
		3:
			var parts := []
			for k in 3:
				var x := -14.0 + float(k) * 14.0
				parts.append(stk(Vector2(x, -36), Vector2(x * 0.6, 14), 4.0, s + k, LEAF_D))
				parts.append(ov(Vector2(x * 0.5, 22), 7, 11, s + 5 + k, BONE2, 0.0, 1))
			sil(ci, parts, rim)
			for k in 6:
				ci.draw_circle(Vector2(-16.0 + float(k) * 7.0, -10.0 + float(k % 3) * 10.0), 2.0, CHAR)
		4:
			sil(ci, [ov(Vector2(0, 8), 30, 28, s, Color("8a6044"))], rim)
			for k in 3:
				ci.draw_arc(Vector2(0, 8), 14.0 + float(k) * 7.0, PI * 0.15, PI * 0.85, 10, Color(INK, 0.35), 1.6, true)
			var cut := ell(Vector2(0, -8), Vector2(16, 9), s, 0.12, 14)
			ci.draw_colored_polygon(cut, Color("e8d8e8"))
			outline(ci, cut, 2.0)
			for k in 5:
				ci.draw_circle(Vector2(-8.0 + float(k) * 4.0, -8.0 + float(k % 2) * 2.0), 1.4, Color("a888b8"))
			steam(ci, Vector2(0, -20), 2, 16)
		5:
			sil(ci, [ov(Vector2(0, 10), 40, 20, s, YAM, -0.25)], rim)
			var cut := ell(Vector2(4, 4), Vector2(26, 9), s + 1, 0.06, 18, -0.25)
			ci.draw_colored_polygon(cut, YAM_IN)
			outline(ci, cut, 2.0)
			ci.draw_colored_polygon(ell(Vector2(4, 4), Vector2(16, 4), s + 2, 0.0, 14, -0.25), Color("ffd070"))
			for k in 4:
				ci.draw_circle(Vector2(-30.0 + float(k) * 18.0, 16.0 + float(k % 2) * 4.0), 2.2, CHAR)
			steam(ci, Vector2(2, -8), 3, 20)
		6:
			var parts := [leaf(Vector2(-10, 30), 34, 9, -2.1, s, Color("b8c46a")), leaf(Vector2(10, 30), 34, 9, -1.0, s + 1, Color("a8b45a")),
				ov(Vector2(0, -2), 16, 36, s + 2, CORN, 0.0, 1)]
			sil(ci, parts, rim)
			for r in 7:
				for k in 3:
					var p := Vector2(-8.0 + float(k) * 8.0, -28.0 + float(r) * 8.5)
					if absf(p.x) > 12.0 - absf(float(r) - 3.0) * 1.0:
						continue
					ci.draw_colored_polygon(ell(p, Vector2(3.4, 3.4), s + r * 3 + k, 0.0, 8), CORN.lightened(0.2) if (r + k) % 4 != 0 else CHAR)
		7:
			sil(ci, _fruit_apple(Vector2(0, 8), 30, s), rim)
			for k in 4:
				var a := 0.6 + float(k) * 0.55
				pl(ci, [Vector2(0, 8) + Vector2(cos(a), sin(a) - 0.4) * 12.0, Vector2(0, 8) + Vector2(cos(a + 0.2), sin(a + 0.2)) * 24.0], 1.6, Color(INK, 0.4), s + k)
			ci.draw_colored_polygon(ell(Vector2(-14, 28), Vector2(5, 7), s, 0.0, 10), Color("c86a1a"))
			steam(ci, Vector2(0, -22), 2, 16)
		8:
			var parts := [stk(Vector2(-38, 38), Vector2(34, -36), 2.8, s, WOOD_D, 2)]
			for k in 3:
				var c := Vector2(-20, 20).lerp(Vector2(18, -20), float(k) / 2.0)
				parts.append_array(_shroom(c + Vector2(0, -8), 13, s + k * 3, -0.75))
			sil(ci, parts, rim)
			for k in 3:
				var c := Vector2(-20, 20).lerp(Vector2(18, -20), float(k) / 2.0)
				ln(ci, c + Vector2(-8, -12), c + Vector2(2, -2), 2.2, CHAR, s + k)
		9:
			sil(ci, [pg(arcp(Vector2(0, 0), Vector2(42, 34), 0.0, PI, 16), s, PUMP.darkened(0.08), 0),
				stk(Vector2(-4, -12), Vector2(-8, -26), 4.0, s + 1, LEAF_D)], rim)
			var face := ell(Vector2(0, 0), Vector2(40, 12), s + 2, 0.0, 22, 0.0, 0.4)
			ci.draw_colored_polygon(face, Color("f5a040"))
			outline(ci, face, 2.0)
			ci.draw_colored_polygon(ell(Vector2(0, 0), Vector2(22, 6), s + 3, 0.0, 16, 0.0, 0.3), Color("e8862a"))
			for k in 7:
				ci.draw_colored_polygon(ell(Vector2(-15.0 + float(k) * 5.0, (float(k % 2) - 0.5) * 3.0), Vector2(2.2, 1.4), s + k, 0.0, 8, 0.0, 0.0), BONE)
			for k in 4:
				ci.draw_arc(Vector2(0, -6), 14.0 + float(k) * 8.0, PI * 0.25, PI * 0.75, 8, Color(INK, 0.35), 1.6, true)
			for k in 3:
				ln(ci, Vector2(-30.0 + float(k) * 22.0, 14), Vector2(-22.0 + float(k) * 22.0, 22), 2.6, CHAR, s + k)
		10:
			var parts := [leaf(Vector2(0, 14), 36, 16, -2.4, s, LEAF_D), leaf(Vector2(0, 14), 36, 16, -0.75, s + 1, LEAF),
				ov(Vector2(0, 12), 30, 22, s + 2, LEAF, 0.0, 1)]
			sil(ci, parts, rim)
			pl(ci, [Vector2(-28, 8), Vector2(0, 16), Vector2(28, 8)], 3.0, ROPE, s)
			pl(ci, [Vector2(0, -10), Vector2(-2, 12), Vector2(0, 34)], 3.0, ROPE, s + 1)
			vein(ci, Vector2(0, 14), 36, -2.4, s)
			vein(ci, Vector2(0, 14), 36, -0.75, s + 1)
			steam(ci, Vector2(0, -20), 3, 18)
		11:
			var parts := [stk(Vector2(-44, 40), Vector2(40, -40), 2.8, s, WOOD_D, 2)]
			var pts := [Vector2(-28, 26), Vector2(-10, 8), Vector2(8, -10), Vector2(26, -28)]
			parts.append_array(_shroom(pts[0] + Vector2(0, -6), 11, s + 1, -0.78))
			parts.append(ov(pts[1], 12, 9, s + 4, BERRY, -0.78))
			parts.append(ov(pts[2], 9, 13, s + 5, CORN, -0.78, 1))
			parts.append(circ(pts[3], 10, s + 6, Color("c86ab8")))
			sil(ci, parts, rim)
			grill(ci, pts[1], 14, 2, s, -0.78)
			ln(ci, pts[3] + Vector2(-6, 0), pts[3] + Vector2(6, 0), 1.6, Color(BONE, 0.8), s)
		12:
			var parts := [pg([Vector2(-48, 22), Vector2(-40, 6), Vector2(42, 4), Vector2(48, 20), Vector2(40, 34), Vector2(-42, 34)], s, STONE, 0)]
			parts.append_array(_shroom(Vector2(-22, -6), 12, s + 2))
			parts.append(ov(Vector2(4, -2), 10, 16, s + 5, CORN, 1.2, 1))
			parts.append(ov(Vector2(28, -2), 12, 8, s + 6, YAM_IN, 0.0, 1))
			parts.append(circ(Vector2(14, 6), 7, s + 7, BERRY))
			sil(ci, parts, rim)
			grill(ci, Vector2(28, -2), 14, 2, s, -1.2)
			steam(ci, Vector2(0, -16), 3, 16)
		13:
			var body := ov(Vector2(0, 14), 42, 26, s, PUMP, 0.0, 0)
			sil(ci, [body, ov(Vector2(18, -22), 18, 7, s + 1, PUMP.darkened(0.08), 0.5, 1), stk(Vector2(22, -26), Vector2(24, -36), 3.0, s + 2, LEAF_D)], rim)
			ci.draw_colored_polygon(ell(Vector2(-4, -4), Vector2(28, 8), s + 3, 0.04, 16), Color("c8682a"))
			ci.draw_colored_polygon(ell(Vector2(-4, -3), Vector2(24, 6), s + 4, 0.04, 16), Color("e8b04a"))
			for k in 4:
				ci.draw_circle(Vector2(-18.0 + float(k) * 10.0, -3.0 + float(k % 2) * 2.0), 2.4, [BERRY, LEAF, SHROOM, BERRY][k])
			for k in 4:
				ci.draw_arc(Vector2(0, 14), 14.0 + float(k) * 8.0, PI * 0.2, PI * 0.8, 10, Color(INK, 0.3), 1.6, true)
			steam(ci, Vector2(-6, -12), 3, 22)
		_:
			glow(ci, Vector2(0, 0), 54, GOLD)
			var parts := [ov(Vector2(0, 24), 50, 16, s, LEAF, 0.0, 1)]
			parts.append_array(_shroom(Vector2(-26, -2), 13, s + 1))
			parts.append(ov(Vector2(-6, 2), 10, 20, s + 4, CORN, 1.1, 1))
			parts.append(ov(Vector2(22, 10), 18, 10, s + 5, YAM, -0.3))
			parts.append(circ(Vector2(4, -14), 12, s + 6, Color("b84a3a")))
			parts.append(circ(Vector2(30, -8), 9, s + 7, PUMP))
			parts.append(_chestnut(Vector2(-34, 16), 8, s + 8))
			sil(ci, parts, rim)
			ci.draw_colored_polygon(ell(Vector2(24, 6), Vector2(12, 4), s, 0.0, 12, -0.3), YAM_IN)
			steam(ci, Vector2(0, -28), 3, 20)
			sparks(ci, [Vector2(-42, -32), Vector2(42, -36), Vector2(44, 30)])

static func _fruit_apple(c: Vector2, r: float, s: int) -> Array:
	return [circ(c, r, s, Color("b8402a")), stk(c + Vector2(0, -r * 0.8), c + Vector2(2, -r * 1.25), 2.4, s + 1, WOOD_D, 2)]

static func sub(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			var cs := [Vector2(-14, 16), Vector2(14, 18), Vector2(0, -2)]
			sil(ci, [_cube(cs[0], 12, s), _cube(cs[1], 11, s + 1, ROAST.darkened(0.05)), _cube(cs[2], 12, s + 2, ROASTL)], rim)
			for c in cs:
				ln(ci, (c as Vector2) + Vector2(-6, -2), (c as Vector2) + Vector2(4, -8), 2.0, CHAR, s)
		2:
			var cubes := [Vector2(-18, 18), Vector2(0, 0), Vector2(18, -18)]
			var parts := [stk(Vector2(-40, 38), Vector2(38, -36), 3.0, s, WOOD_D, 2)]
			for i in 3:
				parts.append(_cube(cubes[i], 12, s + i, ROAST if i != 1 else ROASTL))
			sil(ci, parts, rim)
			for c in cubes:
				ln(ci, (c as Vector2) + Vector2(-7, -3), (c as Vector2) + Vector2(3, -9), 2.0, INK, s)
		3:
			var parts := [stk(Vector2(-6, 44), Vector2(6, -44), 2.8, s, WOOD_D, 2)]
			parts.append(pg([Vector2(20, -24), Vector2(34, -36), Vector2(34, -12)], s + 1, ROAST.darkened(0.1)))
			parts.append(ov(Vector2(-2, -8), 26, 14, s + 2, Color("c8823a"), -0.15))
			sil(ci, parts, rim)
			ci.draw_circle(Vector2(-18, -6), 2.6, INK)
			grill(ci, Vector2(0, -8), 20, 3, s, -0.9)
		4:
			var parts := _bone(Vector2(14, -16), Vector2(-4, 4), 4.5, s)
			parts.append(ov(Vector2(-12, 16), 20, 16, s + 5, ROAST, -0.75))
			sil(ci, parts, rim)
			ln(ci, Vector2(-20, 10), Vector2(-6, 22), 2.0, CHAR, s)
		5:
			var parts := []
			for k in 4:
				var y := -18.0 + float(k) * 12.0
				parts.append(stk(Vector2(-42, y + 6), Vector2(-22, y), 3.4, s + k, BONE2))
			parts.append(pg([Vector2(-26, -24), Vector2(34, -20), Vector2(40, 22), Vector2(-26, 26)], s + 10, ROAST, 0))
			sil(ci, parts, rim)
			for k in 3:
				ln(ci, Vector2(-20, -10.0 + float(k) * 12.0), Vector2(34, -8.0 + float(k) * 12.0), 2.0, CHAR, s + k)
		6:
			var parts := [stk(Vector2(-48, -6), Vector2(48, -6), 2.4, s, WOOD_D, 2),
				stk(Vector2(-12, 6), Vector2(-30, 26), 4.0, s + 1, ROAST.darkened(0.1)), stk(Vector2(20, 6), Vector2(36, 26), 4.5, s + 2, ROAST.darkened(0.1)),
				ov(Vector2(4, -2), 30, 15, s + 3, ROAST), ov(Vector2(-28, -10), 11, 9, s + 4, ROASTL),
				stk(Vector2(-26, -16), Vector2(-14, -30), 3.4, s + 5, ROAST, 1)]
			sil(ci, parts, rim)
			grill(ci, Vector2(4, -4), 26, 3, s, -1.2)
		7:
			var parts := _bone(Vector2(-14, 14), Vector2(-34, 34), 5.5, s)
			parts.remove_at(1)
			parts.remove_at(1)
			parts.append(ov(Vector2(10, -10), 30, 24, s + 5, ROAST, -0.75))
			sil(ci, parts, rim)
			ln(ci, Vector2(0, -22), Vector2(22, -2), 2.0, INK, s)
			ln(ci, Vector2(-4, -10), Vector2(14, 8), 2.0, INK, s + 3)
		8:
			sil(ci, [leaf(Vector2(0, 26), 42, 18, -2.6, s, LEAF_D), leaf(Vector2(0, 26), 42, 18, -0.55, s + 1, LEAF),
				ov(Vector2(0, 10), 24, 15, s + 2, ROAST, -0.2)], rim)
			grill(ci, Vector2(0, 8), 26, 3, s, -0.9)
			pl(ci, [Vector2(-34, 14), Vector2(-20, 24), Vector2(0, 28), Vector2(20, 24), Vector2(34, 14)], 2.4, ROPE, s)
			steam(ci, Vector2(0, -10), 3, 18)
		9:
			sil(ci, [pg([Vector2(-48, 22), Vector2(-40, 6), Vector2(42, 4), Vector2(48, 20), Vector2(40, 34), Vector2(-42, 34)], s, STONE, 0),
				ov(Vector2(-4, 2), 28, 14, s + 1, ROAST, -0.1), leaf(Vector2(22, 0), 18, 5, -0.6, s + 2), leaf(Vector2(22, 0), 16, 5, 0.3, s + 3)], rim)
			grill(ci, Vector2(-4, 2), 26, 3, s, -1.0)
			steam(ci, Vector2(-4, -12), 3, 16)
		10:
			var parts := [ov(Vector2(0, 28), 48, 11, s, LEAF, 0.0, 1)]
			for x in [-24.0, -10.0, 14.0, 28.0]:
				parts.append(stk(Vector2(x, 14), Vector2(x * 1.15, 28), 4.5, s + int(x), ROAST.darkened(0.15), 2))
			parts.append(ov(Vector2(4, 2), 38, 21, s + 4, ROAST))
			parts.append(ov(Vector2(-34, -4), 14, 12, s + 5, ROAST.lightened(0.05)))
			parts.append(pg([Vector2(-30, -14), Vector2(-26, -26), Vector2(-20, -14)], s + 7, ROAST.darkened(0.05)))
			parts.append(circ(Vector2(-47, 0), 7, s + 6, BERRY))
			sil(ci, parts, rim)
			for i in 3:
				var x := -12.0 + float(i) * 14.0
				ln(ci, Vector2(x, -12), Vector2(x + 8, 10), 2.2, INK, s + i)
			ci.draw_circle(Vector2(-36, -8), 2.2, INK)
		11:
			var parts := [stk(Vector2(-40, 40), Vector2(-38, -14), 3.0, s, WOOD_D), stk(Vector2(40, 40), Vector2(38, -14), 3.0, s + 1, WOOD_D),
				stk(Vector2(-38, -14), Vector2(-44, -24), 2.6, s + 2, WOOD_D, 2), stk(Vector2(-38, -14), Vector2(-32, -24), 2.6, s + 3, WOOD_D, 2),
				stk(Vector2(38, -14), Vector2(44, -24), 2.6, s + 4, WOOD_D, 2), stk(Vector2(38, -14), Vector2(32, -24), 2.6, s + 5, WOOD_D, 2)]
			for x in [-16.0, -4.0, 14.0, 24.0]:
				parts.append(stk(Vector2(x, -4), Vector2(x * 1.1, 14), 4.0, s + 10 + int(x), ROAST.darkened(0.15)))
			parts.append(stk(Vector2(-50, -16), Vector2(50, -16), 2.4, s + 6, WOOD, 2))
			parts.append(ov(Vector2(4, -14), 30, 14, s + 7, ROAST))
			parts.append(ov(Vector2(-28, -22), 10, 8, s + 8, ROASTL))
			parts.append(band(Vector2(-26, -24), 7, 2.4, PI * 0.9, PI * 1.9, s + 9, BONE2))
			sil(ci, parts, rim)
			grill(ci, Vector2(4, -14), 24, 3, s, -1.2)
			flame(ci, Vector2(0, 28), 12, 28, s + 20, false)
		_:
			glow(ci, Vector2(0, 0), 54, GOLD)
			var parts := _bone(Vector2(-20, 22), Vector2(-42, 42), 7.0, s)
			parts.remove_at(1)
			parts.remove_at(1)
			parts.append(ov(Vector2(8, -6), 40, 30, s + 5, ROAST, -0.75))
			sil(ci, parts, rim)
			for k in 3:
				ln(ci, Vector2(-10.0 + float(k) * 10.0, -28.0 + float(k) * 6.0), Vector2(14.0 + float(k) * 10.0, -4.0 + float(k) * 6.0), 2.2, INK, s + k)
			ci.draw_colored_polygon(ell(Vector2(-2, -18), Vector2(14, 6), s, 0.0, 12, -0.75), Color(1, 0.9, 0.6, 0.45))
			steam(ci, Vector2(10, -34), 3, 16)
			sparks(ci, [Vector2(-38, -30), Vector2(42, -38), Vector2(40, 30)])

static func _bone(a: Vector2, b: Vector2, r: float, s: int) -> Array:
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x)
	var col := Color("f3e6c8")
	return [stk(a, b, r, s, col, 1),
		circ(a + n * r * 0.9 - d * r * 0.4, r * 1.25, s + 1, col, 1),
		circ(a - n * r * 0.9 - d * r * 0.4, r * 1.25, s + 2, col, 1),
		circ(b + n * r * 0.9 + d * r * 0.4, r * 1.25, s + 3, col, 1),
		circ(b - n * r * 0.9 + d * r * 0.4, r * 1.25, s + 4, col, 1)]
