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

static func gen(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			sil(ci, [ov(Vector2(-4, 10), 30, 20, s, STONE, -0.15), ov(Vector2(24, 26), 12, 8, s + 1, STONE.darkened(0.08))], rim)
		2:
			sil(ci, [ov(Vector2(-6, 10), 30, 22, s, STONE, -0.2)], rim)
			ci.draw_colored_polygon(poly([Vector2(10, -8), Vector2(24, 2), Vector2(18, 14), Vector2(6, 6)], s), GREY.lightened(0.15))
			outline(ci, poly([Vector2(10, -8), Vector2(24, 2), Vector2(18, 14), Vector2(6, 6)], s), 1.6)
			_flakes(ci, [Vector2(32, -14), Vector2(40, 0), Vector2(30, -28)], s)
			for k in 3:
				var a := -0.9 + float(k) * 0.45
				ln(ci, Vector2(28, -4) + Vector2(cos(a), sin(a)) * 18.0, Vector2(28, -4) + Vector2(cos(a), sin(a)) * 26.0, 2.0, OCHRE, s + k)
		3:
			sil(ci, [_slab(Vector2(0, 18), 40, 16, s), ov(Vector2(10, -10), 13, 10, s + 1, STONE_D.lightened(0.15))], rim)
			ln(ci, Vector2(-34, 12), Vector2(32, 10), 1.6, Color(INK, 0.4), s)
		4:
			sil(ci, [_slab(Vector2(0, 20), 42, 16, s),
				stk(Vector2(-30, -30), Vector2(10, -2), 4.0, s + 1, BONE2),
				circ(Vector2(-32, -32), 6, s + 2, BONE2, 1), ov(Vector2(14, -2), 12, 9, s + 3, FLINT, 0.4)], rim)
			_flakes(ci, [Vector2(30, -8), Vector2(36, -20)], s)
			ln(ci, Vector2(-34, 14), Vector2(34, 12), 1.6, Color(INK, 0.4), s)
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
			sil(ci, [ov(Vector2(-14, 18), 13, 9, s, STONE), ov(Vector2(14, 20), 11, 8, s + 1, STONE.darkened(0.1)),
				ov(Vector2(0, 4), 12, 9, s + 2, STONE.lightened(0.12))], rim)
		2:
			var pts := [Vector2(-26, 12), Vector2(-16, -18), Vector2(4, -28), Vector2(24, -10), Vector2(20, 18), Vector2(-4, 28)]
			sil(ci, [pg(pts, s, FLINT)], rim)
			for v in [Vector2(-16, -18), Vector2(24, -10), Vector2(-4, 28)]:
				ln(ci, Vector2(2, 0), v, 1.6, INK, s)
		3:
			var pts := [Vector2(-30, 18), Vector2(30, 18)]
			for k in 15:
				var a := lerpf(-0.1, -PI + 0.1, float(k) / 14.0)
				var r := 32.0 if k % 2 == 0 else 28.0
				pts.append(Vector2(cos(a) * r, 18.0 + sin(a) * r * 0.9))
			sil(ci, [pg(pts, s, GREY)], rim)
			for k in 3:
				ln(ci, Vector2(0, 16), Vector2(-16.0 + float(k) * 16.0, -6), 1.4, Color(INK, 0.5), s + k)
		4:
			var base := [Vector2(0, -38), Vector2(17, -10), Vector2(16, 18), Vector2(0, 36), Vector2(-16, 18), Vector2(-17, -10)]
			sil(ci, [pg(rot_pts(base, 0.4), s, GREY)], rim)
			var a := Vector2(0, -34).rotated(0.4)
			var b := Vector2(0, 32).rotated(0.4)
			ln(ci, a, b, 1.6, INK, s)
			for i in 3:
				var m := a.lerp(b, 0.25 + 0.22 * float(i))
				ln(ci, m, m + Vector2(12, -3).rotated(0.4), 1.4, INK, s + i)
				ln(ci, m, m + Vector2(-12, -3).rotated(0.4), 1.4, INK, s + i + 9)
		5:
			var blade := [Vector2(-12, 10), Vector2(2, -14), Vector2(32, -40), Vector2(24, -6), Vector2(2, 16)]
			sil(ci, [stk(Vector2(-32, 36), Vector2(-6, 8), 7.5, s + 1, WOOD), pg(blade, s, GREY)], rim)
			ln(ci, Vector2(-4, 12), Vector2(28, -36), 1.4, INK, s)
			rope(ci, Vector2(-32, 36), Vector2(-6, 8), 0.72, 3, 8.0, s)
		6:
			sil(ci, [stk(Vector2(-26, 38), Vector2(14, -12), 4.5, s, WOOD), ov(Vector2(16, -18), 22, 16, s + 1, STONE, 0.6)], rim)
			rope(ci, Vector2(-26, 38), Vector2(14, -12), 0.88, 3, 6.0, s)
		7:
			sil(ci, [stk(Vector2(-30, 32), Vector2(28, -30), 3.4, s, BONE2), ov(Vector2(22, -24), 6, 4, s + 1, BONE2, -0.8, 1)], rim)
			ci.draw_circle(Vector2(22, -24), 1.8, INK)
			pl(ci, [Vector2(22, -24), Vector2(30, -12), Vector2(18, 0), Vector2(30, 12), Vector2(16, 24), Vector2(26, 36)], 2.2, CLAY, s)
		8:
			var tip := [Vector2(16, -22), Vector2(40, -44), Vector2(28, -18), Vector2(34, -20), Vector2(22, -10)]
			sil(ci, [stk(Vector2(-40, 42), Vector2(18, -18), 3.6, s, WOOD, 2), pg(tip, s + 1, BONE2),
				pg([Vector2(26, -30), Vector2(18, -34), Vector2(24, -26)], s + 2, BONE2)], rim)
			rope(ci, Vector2(-40, 42), Vector2(18, -18), 0.92, 2, 5.0, s)
		9:
			var head := [Vector2(-10, -40), Vector2(30, -38), Vector2(43, -16), Vector2(32, 2), Vector2(-6, -8)]
			sil(ci, [stk(Vector2(-28, 42), Vector2(12, -32), 6.5, s + 1, WOOD), pg(head, s, Color("918b84"))], rim)
			ln(ci, Vector2(30, -38), Vector2(32, 2), 1.6, INK, s)
			rope(ci, Vector2(-28, 42), Vector2(12, -32), 0.74, 3, 8.0, s)
		10:
			var tip := [Vector2(22, -26), Vector2(30, -40), Vector2(46, -48), Vector2(38, -32), Vector2(30, -20)]
			sil(ci, [stk(Vector2(-44, 44), Vector2(28, -28), 3.6, s, WOOD, 2), pg(tip, s + 1, GREY),
				leaf(Vector2(-32, 32), 14, 4, 2.0, s + 2, BERRY), leaf(Vector2(-32, 32), 14, 4, 2.9, s + 3, OCHRE)], rim)
			ln(ci, Vector2(28, -28), Vector2(44, -46), 1.4, INK, s)
			rope(ci, Vector2(-44, 44), Vector2(28, -28), 0.92, 2, 5.0, s)
		11:
			var head := band(Vector2(0, 8), 40, 6.0, PI * 1.15, PI * 1.85, s, GREY, 0)
			sil(ci, [stk(Vector2(0, -32), Vector2(0, 44), 5.0, s + 1, WOOD), head], rim)
			rope(ci, Vector2(0, 44), Vector2(0, -32), 0.92, 3, 7.0, s)
		12:
			var parts := [stk(Vector2(-40, -30), Vector2(-10, 14), 1.8, s, ROPE, 2), stk(Vector2(36, -34), Vector2(10, 14), 1.8, s + 1, ROPE, 2),
				ov(Vector2(0, 18), 18, 12, s + 2, LEATHER, 0.0, 1), circ(Vector2(0, 10), 10, s + 3, STONE)]
			parts.append(circ(Vector2(-40, -32), 4, s + 4, ROPE, 1))
			sil(ci, parts, rim)
			dashed(ci, ell(Vector2(0, 20), Vector2(13, 7), s, 0.0, 14), 4, 3, Color(BONE, 0.8), 1.6)
		13:
			var bow := band(Vector2(16, 0), 40, 4.0, PI * 0.62, PI * 1.38, s, WOOD, 1)
			sil(ci, [bow, stk(Vector2(-30, 0), Vector2(34, 0), 2.5, s + 1, WOOD.lightened(0.2), 2),
				pg([Vector2(34, -7), Vector2(48, 0), Vector2(34, 7)], s + 2, STONE_D),
				pg([Vector2(-36, -9), Vector2(-24, -1), Vector2(-24, 1), Vector2(-36, 9), Vector2(-30, 0)], s + 3, CLAY)], rim)
			var top := Vector2(16, 0) + Vector2(cos(PI * 0.62), sin(PI * 0.62)) * 40.0
			var bot := Vector2(16, 0) + Vector2(cos(PI * 1.38), sin(PI * 1.38)) * 40.0
			ln(ci, top, Vector2(-14, 0), 1.6, INK, s)
			ln(ci, Vector2(-14, 0), bot, 1.6, INK, s + 2)
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
			sil(ci, [raw_rock(Vector2(0, 8), 26, s, FLINT, 7, 0.2)], rim)
			for k in 3:
				ci.draw_arc(Vector2(-8, 4), 8.0 + float(k) * 5.0, -0.4, 1.2, 8, Color(INK, 0.35), 1.4, true)
		2:
			sil(ci, [raw_rock(Vector2(-4, 8), 24, s, Color("c4572d"), 8, 0.18), raw_rock(Vector2(22, 26), 9, s + 1, Color("d86a3a"), 6, 0.2)], rim)
			for k in 6:
				ci.draw_circle(Vector2(-30.0 + float(k) * 11.0, 34.0 + float(k % 2) * 2.0), 1.8, Color("d86a3a"))
		3:
			var cs := [[Vector2(-12, 30), 7.0, 26.0, -0.35], [Vector2(12, 30), 6.0, 20.0, 0.4], [Vector2(0, 32), 8.0, 34.0, 0.0]]
			var parts := []
			for i in cs.size():
				parts.append(crystal(cs[i][0], cs[i][1], cs[i][2], cs[i][3], s + i, Color("eef3f7")))
			sil(ci, parts, rim)
			for i in cs.size():
				crystal_det(ci, cs[i][0], cs[i][1], cs[i][2], cs[i][3], s + i, Color("a8b8c8"))
		4:
			var pts := [Vector2(-20, 30), Vector2(-30, 0), Vector2(-8, -36), Vector2(10, -30), Vector2(28, 10), Vector2(14, 32)]
			sil(ci, [pg(pts, s, OBSID)], rim)
			ci.draw_colored_polygon(poly([Vector2(-8, -36), Vector2(10, -30), Vector2(0, 0), Vector2(-14, -4)], s), Color(OBSID_HL, 0.55))
			ci.draw_colored_polygon(poly([Vector2(-26, 0), Vector2(-14, -4), Vector2(-14, 20)], s + 1), Color(1, 1, 1, 0.2))
		5:
			sil(ci, [ov(Vector2(0, 6), 32, 28, s, Color("c86a3a"), 0.0, 1)], rim)
			for k in 5:
				var f := 1.0 - float(k) * 0.18
				ci.draw_colored_polygon(ell(Vector2(2, 8), Vector2(26, 22) * f, s + k, 0.06, 18), Color("f4d6b0") if k % 2 == 0 else Color("d8743a"))
			ci.draw_colored_polygon(ell(Vector2(3, 9), Vector2(5, 3.5), s, 0.0, 10), Color("8ad0d8"))
		6:
			sil(ci, [raw_rock(Vector2(0, 8), 28, s, Color("4fc2b4"), 9, 0.15)], rim)
			pl(ci, [Vector2(-22, -4), Vector2(-8, 4), Vector2(-2, -6), Vector2(14, 6), Vector2(22, 0)], 1.8, Color(INK, 0.55), s)
			pl(ci, [Vector2(-12, 20), Vector2(0, 14), Vector2(12, 24)], 1.8, Color(INK, 0.55), s + 3)
			hl(ci, Vector2(-10, -10), 8, 4)
		7:
			sil(ci, [raw_rock(Vector2(0, 8), 30, s, Color("2a4fa8"), 8, 0.14)], rim)
			for k in 9:
				var p := Vector2((srnd(s + k) - 0.5) * 36.0, (srnd(s + k + 20) - 0.5) * 30.0 + 8.0)
				ci.draw_colored_polygon(star_pts(p, 2.6, 1.0, 4, s + k), GOLD)
			hl(ci, Vector2(-12, -8), 8, 4)
		8:
			var parts := [raw_rock(Vector2(0, 26), 26, s, STONE, 8, 0.12)]
			var cs := [[Vector2(-14, 24), 6.0, 20.0, -0.45], [Vector2(14, 24), 6.0, 18.0, 0.5], [Vector2(-4, 22), 7.0, 30.0, -0.1], [Vector2(6, 24), 6.0, 24.0, 0.18]]
			for i in cs.size():
				parts.append(crystal(cs[i][0], cs[i][1], cs[i][2], cs[i][3], s + i + 1, PURPLE))
			sil(ci, parts, rim)
			for i in cs.size():
				crystal_det(ci, cs[i][0], cs[i][1], cs[i][2], cs[i][3], s + i, Color("d8b0f0"))
		9:
			sil(ci, [ov(Vector2(0, 6), 30, 24, s, Color("3fae6a"))], rim)
			ci.draw_colored_polygon(ell(Vector2(4, 10), Vector2(20, 14), s, 0.04, 16), Color("5ccf86"))
			hl(ci, Vector2(-10, -6), 10, 5)
			pl(ci, [Vector2(-34, -14), Vector2(-20, -24), Vector2(0, -28), Vector2(20, -24), Vector2(34, -14)], 2.4, ROPE, s)
		10:
			cut_gem(ci, Vector2(0, 4), 32, Color("e0283c"), s, rim)
			spark(ci, Vector2(-20, -24), 5)
		11:
			cut_gem(ci, Vector2(0, 2), 38, Color("2f6fe0"), s, rim)
			sparks(ci, [Vector2(-28, -28), Vector2(30, 24)], 5)
		_:
			glow(ci, Vector2(0, 0), 52, Color("bfa0ff"))
			var parts := [raw_rock(Vector2(0, 28), 24, s, STONE_D, 8, 0.12)]
			var cs := [[Vector2(-14, 24), 7.0, 22.0, -0.5, Color("ff7ab0")], [Vector2(16, 24), 7.0, 22.0, 0.5, Color("6fd0ff")],
				[Vector2(0, 20), 9.0, 38.0, 0.0, Color("c89bff")]]
			for i in cs.size():
				parts.append(crystal(cs[i][0], cs[i][1], cs[i][2], cs[i][3], s + i + 1, cs[i][4]))
			sil(ci, parts, rim)
			for i in cs.size():
				crystal_det(ci, cs[i][0], cs[i][1], cs[i][2], cs[i][3], s + i, Color.WHITE)
			ci.draw_colored_polygon(star_pts(Vector2(0, -6), 8, 3, 5, s), Color(1, 1, 0.85))
			sparks(ci, [Vector2(-34, -30), Vector2(32, -36), Vector2(36, 10), Vector2(-36, 6)], 5)
