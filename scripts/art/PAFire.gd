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
	## 等级感：低级整体画小、火苗随等级变高；5 级起带暖光，7 级起有火星
	var k: float = [0.72, 0.78, 0.86, 0.93, 1.0, 1.0, 1.0, 0.9][clampi(lv, 1, 8) - 1]
	set_xf(ci, Transform2D(0.0, Vector2.ONE * k, 0.0, Vector2(0, (1.0 - k) * 34.0)))
	match lv:
		1:
			sil(ci, [stk(Vector2(-38, 26), Vector2(34, 6), 4.0, s, WOOD_D), stk(Vector2(-30, 8), Vector2(38, 28), 4.0, s + 1, WOOD),
				stk(Vector2(-20, 34), Vector2(26, -8), 3.4, s + 2, WOOD.darkened(0.05)), stk(Vector2(10, 4), Vector2(18, -14), 2.6, s + 3, WOOD_D, 2),
				stk(Vector2(-14, 22), Vector2(-24, 8), 2.6, s + 4, WOOD, 2)], rim)
		2:
			sil(ci, [bx(-42, 18, 84, 14, 4, s, WOOD), stk(Vector2(4, 18), Vector2(-2, -38), 3.4, s + 1, WOOD_D),
				stk(Vector2(-30, -26), Vector2(30, -20), 2.4, s + 2, ROPE, 2)], rim)
			glow(ci, Vector2(6, 18), 12, FIRE)
			ci.draw_colored_polygon(ell(Vector2(6, 20), Vector2(5, 3), s, 0.0, 10), FIRE)
			smoke(ci, Vector2(14, 10), 0.8)
			for j in 3:
				ln(ci, Vector2(-36.0 + float(j) * 10.0, 22), Vector2(-36.0 + float(j) * 10.0, 28), 1.4, Color(INK, 0.4), s + j)
		3:
			sil(ci, [stk(Vector2(-30, 32), Vector2(26, 22), 4.0, s, WOOD), stk(Vector2(30, 32), Vector2(-26, 22), 4.0, s + 1, WOOD_D)], rim)
			flame(ci, Vector2(0, 4), 20, 48, s, rim)
		4:
			glow(ci, Vector2(0, 0), 36, FIRE)
			var parts := _logs(32, s)
			parts.append_array(_stones(5, 0, 38, 72, s + 4))
			sil(ci, parts, rim)
			flame(ci, Vector2(0, -6), 26, 66, s + 10, false)
		5:
			glow(ci, Vector2(0, 4), 42, FIRE)
			var parts := [stk(Vector2(-38, 40), Vector2(-36, -24), 3.0, s, WOOD_D), stk(Vector2(38, 40), Vector2(36, -24), 3.0, s + 1, WOOD_D),
				stk(Vector2(-36, -24), Vector2(-42, -36), 2.6, s + 2, WOOD_D, 2), stk(Vector2(-36, -24), Vector2(-30, -36), 2.6, s + 3, WOOD_D, 2),
				stk(Vector2(36, -24), Vector2(42, -36), 2.6, s + 4, WOOD_D, 2), stk(Vector2(36, -24), Vector2(30, -36), 2.6, s + 5, WOOD_D, 2)]
			parts.append_array(_logs(36, s + 12))
			parts.append_array(_stones(5, 0, 40, 64, s + 6))
			sil(ci, parts, rim)
			flame(ci, Vector2(0, 6), 26, 58, s + 10, false)
			sil(ci, [stk(Vector2(-46, -26), Vector2(46, -26), 2.4, s + 20, WOOD, 2), ov(Vector2(-10, -23), 15, 10, s + 21, ROAST),
				circ(Vector2(16, -23), 8, s + 22, ROASTL)], false)
			grill(ci, Vector2(-10, -23), 18, 2, s)
			ci.draw_circle(Vector2(-10, -12), 1.8, Color(GOLD, 0.9))
		6:
			glow(ci, Vector2(0, 0), 52, FIRE)
			var parts := []
			for j in 3:
				parts.append(bx(-46, 30 - float(j) * 14.0, 24, 14, 5, s + j, STONE.darkened(0.04 * float(j))))
				parts.append(bx(22, 30 - float(j) * 14.0, 24, 14, 5, s + 3 + j, STONE.darkened(0.04 * float(j))))
			parts.append(bx(-50, -12, 100, 12, 4, s + 10, STONE_D.lightened(0.2)))
			sil(ci, parts, rim)
			ci.draw_rect(Rect2(-22, 2, 44, 42), Color("2a170c"))
			ci.draw_rect(Rect2(-22, 28, 44, 16), Color(FIRE, 0.45))
			flame(ci, Vector2(-8, 24), 14, 34, s + 12, false)
			flame(ci, Vector2(8, 22), 16, 40, s + 13, false)
			sil(ci, [ov(Vector2(-22, -20), 14, 7, s + 20, ROAST), circ(Vector2(2, -19), 7, s + 21, SHROOM),
				ov(Vector2(24, -19), 11, 6, s + 22, CORN, 0.2)], false)
			grill(ci, Vector2(-22, -20), 16, 2, s)
			steam(ci, Vector2(0, -28), 3, 16)
		7:
			glow(ci, Vector2(0, 8), 58, FIRE)
			var parts := [stk(Vector2(20, -30), Vector2(22, -46), 7.0, s, TAN_D)]
			parts.append(pg(arcp(Vector2(0, 38), Vector2(48, 66), PI, TAU, 20), s + 1, TAN, 0))
			for j in 3:
				parts.append(stk(Vector2(30, 38 - float(j) * 6.0), Vector2(52, 36 - float(j) * 6.0), 3.4, s + 4 + j, WOOD if j % 2 == 0 else WOOD_D, 2))
			sil(ci, parts, rim)
			zig(ci, -40, 40, 0, 3.0, 12, CLAY, 2.2, s)
			var door := arcp(Vector2(0, 38), Vector2(18, 28), PI, TAU, 10)
			ci.draw_colored_polygon(poly(door, s), Color("2a170c"))
			ci.draw_colored_polygon(poly(arcp(Vector2(0, 38), Vector2(15, 12), PI, TAU, 8), s + 1), Color(FIRE, 0.6))
			flame(ci, Vector2(-4, 26), 12, 26, s + 3, false)
			flame(ci, Vector2(6, 26), 10, 22, s + 4, false)
			outline(ci, poly(door, s), 2.0)
			for j in 4:
				ln(ci, Vector2(-34.0 + float(j) * 6.0, 12.0 + float(j) * 6.0), Vector2(-28.0 + float(j) * 6.0, 10.0 + float(j) * 6.0), 1.6, Color(INK, 0.35), s + j)
			smoke(ci, Vector2(22, -52), 0.9)
			sparks(ci, [Vector2(-34, -30), Vector2(40, -20)], 4.0)
		_:
			## 部落大灶：长条石灶两个火口，灶上架着整只烤兽的烤叉，旁边一口冒气的陶锅
			glow(ci, Vector2(0, 0), 64, FIRE)
			var parts := [bx(-52, 8, 104, 32, 5, s, STONE), bx(-56, 2, 112, 10, 4, s + 1, STONE_D.lightened(0.2))]
			for sd in [-1.0, 1.0]:
				parts.append(stk(Vector2(sd * 46.0, 4), Vector2(sd * 46.0, -40), 3.2, s + 2, WOOD_D))
				parts.append(stk(Vector2(sd * 46.0, -36), Vector2(sd * 52.0, -48), 2.6, s + 3, WOOD_D, 2))
				parts.append(stk(Vector2(sd * 46.0, -36), Vector2(sd * 40.0, -48), 2.6, s + 4, WOOD_D, 2))
			sil(ci, parts, rim)
			for x in [-26.0, 26.0]:
				ci.draw_colored_polygon(poly(arcp(Vector2(x, 40), Vector2(15, 22), PI, TAU, 10), s), Color("2a170c"))
				ci.draw_colored_polygon(poly(arcp(Vector2(x, 40), Vector2(13, 10), PI, TAU, 8), s + 1), Color(FIRE, 0.6))
				flame(ci, Vector2(x, 30), 13, 26, s + 5 + int(x), false)
				outline(ci, poly(arcp(Vector2(x, 40), Vector2(15, 22), PI, TAU, 10), s), 2.0)
			for j in 5:
				ln(ci, Vector2(-8.0 + float(j % 2) * 6.0, 14.0 + float(j) * 5.0), Vector2(-2.0 + float(j % 2) * 6.0, 14.0 + float(j) * 5.0), 1.6, Color(INK, 0.3), s + j)
			flame(ci, Vector2(0, -6), 22, 30, s + 9, false)
			var beast := [stk(Vector2(-58, -40), Vector2(58, -40), 2.6, s + 10, WOOD, 2),
				stk(Vector2(-16, -34), Vector2(-26, -18), 4.0, s + 11, ROAST.darkened(0.15)), stk(Vector2(18, -34), Vector2(28, -18), 4.0, s + 12, ROAST.darkened(0.15)),
				ov(Vector2(2, -40), 28, 13, s + 13, ROAST), ov(Vector2(-28, -44), 11, 9, s + 14, ROASTL),
				pg([Vector2(-30, -52), Vector2(-26, -62), Vector2(-21, -51)], s + 15, ROAST.darkened(0.05))]
			sil(ci, beast, false)
			grill(ci, Vector2(2, -40), 22, 3, s, -1.2)
			ci.draw_circle(Vector2(-31, -46), 1.8, INK)
			ci.draw_colored_polygon(ell(Vector2(-2, -48), Vector2(12, 4), s, 0.0, 10), Color(1, 0.9, 0.6, 0.45))
			sil(ci, [ov(Vector2(40, -8), 14, 11, s + 20, CLAYPOT), bx(28, -20, 24, 5, 2, s + 21, CLAYPOT.darkened(0.12))], false)
			zig(ci, 30, 50, -8, 2.0, 6, CHAR, 1.6, s)
			steam(ci, Vector2(40, -24), 2, 16)
			sparks(ci, [Vector2(-44, -62), Vector2(30, -66), Vector2(58, 10)], 5.0)
	reset_xf(ci)

## 等级感：低级画小，逐级放大到原尺寸；最后三级身后有金光，越高越大，最高级再加火星
static func _tier(ci: CanvasItem, lv: int, n: int, body: Callable) -> void:
	var t: float = clampf(float(lv - 1) / float(n - 1), 0.0, 1.0)
	var k: float = lerpf(0.66, 1.0, t)
	set_xf(ci, Transform2D(0.0, Vector2.ONE * k, 0.0, Vector2(0, (1.0 - k) * 30.0)))
	var g: int = lv - (n - 3)
	if g >= 1:
		glow(ci, Vector2(0, 2), 34.0 + 9.0 * float(g), GOLD)
	body.call()
	if lv >= n:
		sparks(ci, [Vector2(-42, -34), Vector2(42, -38), Vector2(46, 28)])
	reset_xf(ci)

static func main(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	_tier(ci, lv, 14, func(): _main(ci, lv, s, rim))

static func sub(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	_tier(ci, lv, 12, func(): _sub(ci, lv, s, rim))

static func _main(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
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
			var parts := [stk(Vector2(-38, 38), Vector2(34, -36), 2.8, s, WOOD_D, 2)]
			for k in 3:
				var c := Vector2(-20, 20).lerp(Vector2(18, -20), float(k) / 2.0)
				parts.append_array(_shroom(c + Vector2(0, -8), 13, s + k * 3, -0.75))
			sil(ci, parts, rim)
			for k in 3:
				var c := Vector2(-20, 20).lerp(Vector2(18, -20), float(k) / 2.0)
				ln(ci, c + Vector2(-8, -12), c + Vector2(2, -2), 2.2, CHAR, s + k)
		8:
			## 果蔬串：并排两串，一串蘑菇-野果-玉米-紫薯，一串玉米-红薯-蘑菇-野果
			var parts := []
			var food := []
			for j in 2:
				var off := Vector2(-11, -11) if j == 0 else Vector2(11, 11)
				parts.append(stk(Vector2(-42, 38) + off, Vector2(38, -42) + off, 2.6, s + j, WOOD_D, 2))
				var pts := [Vector2(-26, 22) + off, Vector2(-10, 6) + off, Vector2(6, -10) + off, Vector2(22, -26) + off]
				if j == 0:
					food.append_array(_shroom(pts[0] + Vector2(0, -5), 10, s + 10, -0.78))
					food.append(ov(pts[1], 10, 8, s + 13, BERRY, -0.78, 1))
					food.append(ov(pts[2], 8, 11, s + 14, CORN, -0.78, 1))
					food.append(circ(pts[3], 8.5, s + 15, Color("c86ab8"), 1))
				else:
					food.append(ov(pts[0], 8, 11, s + 16, CORN, -0.78, 1))
					food.append(ov(pts[1], 10, 8, s + 17, YAM, -0.78, 1))
					food.append_array(_shroom(pts[2] + Vector2(0, -5), 10, s + 18, -0.78))
					food.append(ov(pts[3], 9, 8, s + 21, BERRY, -0.78, 1))
			sil(ci, parts + food, rim)
			grill(ci, Vector2(-21, -5), 12, 2, s, -0.78)
			grill(ci, Vector2(17, 17), 12, 2, s + 1, -0.78)
		9:
			## 一把烤串：三根串在底下攥成一把、用草绳扎住，往上散开，每根串着不同的烤菜
			var parts := []
			var tips := [Vector2(-30, -34), Vector2(0, -42), Vector2(30, -34)]
			for i in 3:
				parts.append(stk(Vector2(0, 38), tips[i], 2.6, s + i, WOOD_D, 2))
			var food := []
			for i in 3:
				var tp: Vector2 = tips[i]
				var d: Vector2 = (tp - Vector2(0, 38)).normalized()
				var ang: float = d.angle() + PI * 0.5
				var c0: Vector2 = tp - d * 10.0
				var c1: Vector2 = tp - d * 26.0
				var c2: Vector2 = tp - d * 42.0
				match i:
					0:
						food.append(ov(c0, 7, 8, s + 10, BERRY, ang, 1))
						food.append(ov(c1, 9, 7, s + 11, CORN, ang, 1))
						food.append(ov(c2, 8, 7, s + 12, YAM, ang, 1))
					1:
						food.append_array(_shroom(c0 + Vector2(0, 2), 10, s + 13))
						food.append(bx(c1.x - 7, c1.y - 7, 14, 14, 4, s + 16, PUMP))
						food.append(ov(c2, 8, 7, s + 17, Color("c86ab8"), ang, 1))
					_:
						food.append(ov(c0, 9, 7, s + 18, CORN, ang, 1))
						food.append(ov(c1, 7, 8, s + 19, BERRY, ang, 1))
						food.append_array(_shroom(c2 + Vector2(0, 2), 10, s + 20))
			sil(ci, parts + food, rim)
			for k in 3:
				ln(ci, Vector2(-6, 22.0 + float(k) * 4.0), Vector2(6, 20.0 + float(k) * 4.0), 2.4, ROPE, s + k)
			steam(ci, Vector2(0, -50), 2, 12)
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
		12:
			var body := ov(Vector2(0, 14), 42, 26, s, PUMP, 0.0, 0)
			sil(ci, [body, ov(Vector2(18, -22), 18, 7, s + 1, PUMP.darkened(0.08), 0.5, 1), stk(Vector2(22, -26), Vector2(24, -36), 3.0, s + 2, LEAF_D)], rim)
			ci.draw_colored_polygon(ell(Vector2(-4, -4), Vector2(28, 8), s + 3, 0.04, 16), Color("c8682a"))
			ci.draw_colored_polygon(ell(Vector2(-4, -3), Vector2(24, 6), s + 4, 0.04, 16), Color("e8b04a"))
			for k in 4:
				ci.draw_circle(Vector2(-18.0 + float(k) * 10.0, -3.0 + float(k % 2) * 2.0), 2.4, [BERRY, LEAF, SHROOM, BERRY][k])
			for k in 4:
				ci.draw_arc(Vector2(0, 14), 14.0 + float(k) * 8.0, PI * 0.2, PI * 0.8, 10, Color(INK, 0.3), 1.6, true)
			steam(ci, Vector2(-6, -12), 3, 22)
		13:
			## 烤菜木碗：一只大木碗，堆着烤玉米段、烤蘑菇、烤红薯、南瓜块和野葱
			var bowl := arcp(Vector2(0, 8), Vector2(44, 30), 0.0, PI, 16)
			var parts := []
			parts.append(ov(Vector2(-22, -2), 15, 10, s + 1, CORN, 0.3, 1))
			parts.append(ov(Vector2(20, -4), 16, 10, s + 2, YAM, -0.3))
			parts.append(bx(-10, -20, 20, 20, 5, s + 3, PUMP))
			parts.append_array(_shroom(Vector2(4, -26), 14, s + 4))
			parts.append(stk(Vector2(26, -6), Vector2(40, -30), 3.0, s + 7, LEAF_D, 2))
			parts.append(pg(bowl, s + 8, WOOD, 0))
			sil(ci, parts, rim)
			ci.draw_colored_polygon(ell(Vector2(20, -7), Vector2(10, 3.5), s, 0.0, 10, -0.3), YAM_IN)
			for k in 4:
				ci.draw_circle(Vector2(-29.0 + float(k) * 5.0, -4.0 + float(k % 2) * 2.0), 1.6, CHAR)
			ln(ci, Vector2(-40, 10), Vector2(40, 10), 2.0, WOOD_D, s)
			for k in 3:
				ci.draw_arc(Vector2(0, 8), 14.0 + float(k) * 8.0, PI * 0.25, PI * 0.75, 8, Color(INK, 0.3), 1.6, true)
			steam(ci, Vector2(0, -42), 3, 16)
		_:
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

static func _fruit_apple(c: Vector2, r: float, s: int) -> Array:
	return [circ(c, r, s, Color("b8402a")), stk(c + Vector2(0, -r * 0.8), c + Vector2(2, -r * 1.25), 2.4, s + 1, WOOD_D, 2)]

static func _sub(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			var parts := _bone(Vector2(14, -16), Vector2(-4, 4), 4.5, s)
			parts.append(ov(Vector2(-12, 16), 20, 16, s + 5, ROAST, -0.75))
			sil(ci, parts, rim)
			ln(ci, Vector2(-20, 10), Vector2(-6, 22), 2.0, CHAR, s)
		2:
			var cs := [Vector2(-14, 16), Vector2(14, 18), Vector2(0, -2)]
			sil(ci, [_cube(cs[0], 12, s), _cube(cs[1], 11, s + 1, ROAST.darkened(0.05)), _cube(cs[2], 12, s + 2, ROASTL)], rim)
			for c in cs:
				ln(ci, (c as Vector2) + Vector2(-6, -2), (c as Vector2) + Vector2(4, -8), 2.0, CHAR, s)
		3:
			var cubes := [Vector2(-18, 18), Vector2(0, 0), Vector2(18, -18)]
			var parts := [stk(Vector2(-40, 38), Vector2(38, -36), 3.0, s, WOOD_D, 2)]
			for i in 3:
				parts.append(_cube(cubes[i], 12, s + i, ROAST if i != 1 else ROASTL))
			sil(ci, parts, rim)
			for c in cubes:
				ln(ci, (c as Vector2) + Vector2(-7, -3), (c as Vector2) + Vector2(3, -9), 2.0, INK, s)
		4:
			## 烤肉大串：两根粗木签交叉，每根穿着四大块肉、中间夹着肥肉
			var parts := []
			var ends := [[Vector2(-24, 40), Vector2(44, -36)], [Vector2(24, 40), Vector2(-44, -36)]]
			for i in 2:
				var a0: Vector2 = ends[i][0]
				var a1: Vector2 = ends[i][1]
				parts.append(stk(a0, a1, 3.0, s + i, WOOD_D, 2))
			for i in 2:
				var a0: Vector2 = ends[i][0]
				var a1: Vector2 = ends[i][1]
				for k in 4:
					var c: Vector2 = a0.lerp(a1, 0.56 + float(k) * 0.13)
					var col: Color = ROAST if k % 2 == 0 else ROASTL
					parts.append(_cube(c, 9.0 if k % 2 == 0 else 7.5, s + 10 + i * 5 + k, col))
			sil(ci, parts, rim)
			for i in 2:
				var a0: Vector2 = ends[i][0]
				var a1: Vector2 = ends[i][1]
				for k in [0, 2]:
					var c: Vector2 = a0.lerp(a1, 0.56 + float(k) * 0.13)
					ln(ci, c + Vector2(-5, -1), c + Vector2(3, -6), 2.0, CHAR, s + k)
			steam(ci, Vector2(0, -34), 2, 14)
		5:
			var parts := [stk(Vector2(-6, 44), Vector2(6, -44), 2.8, s, WOOD_D, 2)]
			parts.append(pg([Vector2(20, -24), Vector2(34, -36), Vector2(34, -12)], s + 1, ROAST.darkened(0.1)))
			parts.append(ov(Vector2(-2, -8), 26, 14, s + 2, Color("c8823a"), -0.15))
			sil(ci, parts, rim)
			ci.draw_circle(Vector2(-18, -6), 2.6, INK)
			grill(ci, Vector2(0, -8), 20, 3, s, -0.9)
		6:
			## 烤兔：整只兔子穿在烤叉上，耳朵向后贴着，前后腿拉直
			var parts := [stk(Vector2(-50, -2), Vector2(50, -2), 2.4, s, WOOD_D, 2),
				stk(Vector2(-14, 6), Vector2(-36, 18), 3.6, s + 1, ROAST.darkened(0.12)), stk(Vector2(18, 6), Vector2(42, 16), 4.2, s + 2, ROAST.darkened(0.12)),
				ov(Vector2(4, -2), 24, 13, s + 3, ROAST), ov(Vector2(-24, -6), 11, 9, s + 4, ROASTL),
				ov(Vector2(-12, -20), 17, 5.5, s + 5, ROAST.darkened(0.05), -0.45), ov(Vector2(-6, -15), 16, 5.5, s + 6, ROASTL, -0.25)]
			sil(ci, parts, rim)
			grill(ci, Vector2(6, -2), 22, 3, s, -1.2)
			ci.draw_circle(Vector2(-28, -8), 2.0, INK)
			ci.draw_colored_polygon(ell(Vector2(2, -9), Vector2(10, 3), s, 0.0, 10), Color(1, 0.9, 0.6, 0.45))
			steam(ci, Vector2(4, -20), 2, 14)
		7:
			var parts := []
			for k in 4:
				var y := -18.0 + float(k) * 12.0
				parts.append(stk(Vector2(-42, y + 6), Vector2(-22, y), 3.4, s + k, BONE2))
			parts.append(pg([Vector2(-26, -24), Vector2(34, -20), Vector2(40, 22), Vector2(-26, 26)], s + 10, ROAST, 0))
			sil(ci, parts, rim)
			for k in 3:
				ln(ci, Vector2(-20, -10.0 + float(k) * 12.0), Vector2(34, -8.0 + float(k) * 12.0), 2.0, CHAR, s + k)
		8:
			sil(ci, [leaf(Vector2(0, 26), 42, 18, -2.6, s, LEAF_D), leaf(Vector2(0, 26), 42, 18, -0.55, s + 1, LEAF),
				ov(Vector2(0, 10), 24, 15, s + 2, ROAST, -0.2)], rim)
			grill(ci, Vector2(0, 8), 26, 3, s, -0.9)
			pl(ci, [Vector2(-34, 14), Vector2(-20, 24), Vector2(0, 28), Vector2(20, 24), Vector2(34, 14)], 2.4, ROPE, s)
			steam(ci, Vector2(0, -10), 3, 18)
		9:
			## 烤兽腿：大块兽腿放在大叶子上，旁边配野果
			var parts := [leaf(Vector2(0, 30), 46, 16, -2.7, s + 9, LEAF_D), leaf(Vector2(0, 30), 46, 16, -0.45, s + 10, LEAF)]
			parts.append_array(_bone(Vector2(-16, 18), Vector2(-36, 36), 5.5, s))
			parts.remove_at(3)
			parts.remove_at(3)
			parts.append(ov(Vector2(8, -6), 32, 25, s + 5, ROAST, -0.75))
			parts.append(circ(Vector2(32, 26), 6, s + 11, BERRY))
			parts.append(circ(Vector2(40, 20), 5, s + 12, BERRY.darkened(0.1)))
			sil(ci, parts, rim)
			ln(ci, Vector2(-2, -20), Vector2(20, 0), 2.0, INK, s)
			ln(ci, Vector2(-6, -8), Vector2(12, 10), 2.0, INK, s + 3)
			ci.draw_colored_polygon(ell(Vector2(-4, -14), Vector2(10, 4), s, 0.0, 10, -0.75), Color(1, 0.9, 0.6, 0.45))
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
			## 烤全牛：整头牛卧在一层大叶子上，腿收在身下，肩背隆起，头上一对弯牛角，烤得油亮
			var parts := [leaf(Vector2(0, 34), 54, 14, -2.9, s, LEAF_D), leaf(Vector2(0, 34), 54, 14, -0.25, s + 1, LEAF),
				ov(Vector2(0, 32), 52, 9, s + 2, LEAF, 0.0, 1)]
			for x in [-22.0, -8.0, 16.0, 30.0]:
				parts.append(ov(Vector2(x, 28), 7, 5, s + 3 + int(x), ROAST.darkened(0.15)))
			parts.append(ov(Vector2(6, 6), 42, 22, s + 8, ROAST))
			parts.append(ov(Vector2(-8, -10), 22, 10, s + 9, ROAST.darkened(0.04), -0.2))
			parts.append(ov(Vector2(-38, 4), 14, 12, s + 10, ROASTL))
			parts.append(ov(Vector2(-47, 11), 9, 7, s + 11, ROASTL.lightened(0.08)))
			parts.append(ov(Vector2(-26, -4), 7, 3.5, s + 12, ROAST.darkened(0.1), 0.6))
			parts.append(circ(Vector2(44, 22), 6, s + 13, BERRY))
			parts.append(circ(Vector2(-50, 26), 5, s + 14, BERRY.darkened(0.1)))
			sil(ci, parts, rim)
			sil(ci, [pg([Vector2(-34, -4), Vector2(-24, -12), Vector2(-20, -26), Vector2(-17, -11), Vector2(-30, 0)], s + 15, Color("efe2c4"), 2),
				pg([Vector2(-42, -4), Vector2(-52, -12), Vector2(-56, -26), Vector2(-59, -11), Vector2(-46, 0)], s + 16, Color("efe2c4"), 2)], false)
			grill(ci, Vector2(10, 6), 34, 4, s, -1.2)
			ci.draw_circle(Vector2(-40, 2), 2.0, INK)
			ci.draw_circle(Vector2(-50, 12), 1.3, INK)
			ci.draw_colored_polygon(ell(Vector2(0, -8), Vector2(18, 5), s, 0.0, 12), Color(1, 0.9, 0.6, 0.45))
			steam(ci, Vector2(6, -22), 3, 16)
		_:
			## 烤猛犸腿：一整条巨腿横放在木板上，配香草和野果，最高级
			var parts := [bx(-50, 22, 100, 16, 5, s + 9, WOOD)]
			parts.append_array(_bone(Vector2(-20, 14), Vector2(-46, 30), 7.0, s))
			parts.remove_at(3)
			parts.remove_at(3)
			parts.append(ov(Vector2(10, -6), 42, 30, s + 5, ROAST, -0.5))
			parts.append(leaf(Vector2(36, 24), 18, 6, -1.0, s + 10, LEAF))
			parts.append(leaf(Vector2(36, 24), 16, 6, -2.2, s + 11, LEAF_D))
			parts.append(circ(Vector2(46, 20), 6, s + 12, BERRY))
			sil(ci, parts, rim)
			for k in 3:
				ln(ci, Vector2(-12.0 + float(k) * 14.0, -28.0 + float(k) * 3.0), Vector2(6.0 + float(k) * 14.0, 6.0 + float(k) * 3.0), 2.2, INK, s + k)
			for k in 4:
				ln(ci, Vector2(-44.0 + float(k) * 26.0, 30), Vector2(-36.0 + float(k) * 26.0, 30), 1.4, Color(INK, 0.35), s + k)
			ci.draw_colored_polygon(ell(Vector2(-4, -20), Vector2(16, 6), s, 0.0, 12, -0.5), Color(1, 0.9, 0.6, 0.45))
			steam(ci, Vector2(10, -38), 3, 16)

static func _bone(a: Vector2, b: Vector2, r: float, s: int) -> Array:
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x)
	var col := Color("f3e6c8")
	return [stk(a, b, r, s, col, 1),
		circ(a + n * r * 0.9 - d * r * 0.4, r * 1.25, s + 1, col, 1),
		circ(a - n * r * 0.9 - d * r * 0.4, r * 1.25, s + 2, col, 1),
		circ(b + n * r * 0.9 + d * r * 0.4, r * 1.25, s + 3, col, 1),
		circ(b - n * r * 0.9 + d * r * 0.4, r * 1.25, s + 4, col, 1)]
