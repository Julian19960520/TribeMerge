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

## 等级感：低级整体画小、逐级放大，最后三级身后有金光，最高级再加火星
static func _tier(ci: CanvasItem, lv: int, n: int, body: Callable) -> void:
	var t: float = clampf(float(lv - 1) / float(n - 1), 0.0, 1.0)
	var k: float = lerpf(0.68, 1.0, t)
	set_xf(ci, Transform2D(0.0, Vector2.ONE * k, 0.0, Vector2(0, (1.0 - k) * 30.0)))
	var g: int = lv - (n - 3)
	if g >= 1:
		glow(ci, Vector2(0, -4), 34.0 + 9.0 * float(g), GOLD)
	body.call()
	if lv >= n:
		sparks(ci, [Vector2(-44, -36), Vector2(44, -40), Vector2(44, 26)])
	reset_xf(ci)

static func gen(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	_tier(ci, lv, 7, func(): _gen(ci, lv, s, rim))

static func main(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	_tier(ci, lv, 13, func(): _main(ci, lv, s, rim))

static func sub(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	_tier(ci, lv, 11, func(): _sub(ci, lv, s, rim))

static func _gen(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			sil(ci, [bx(-30, -4, 74, 30, 14, s, WOOD), ov(Vector2(-30, 11), 10, 15, s + 1, FACE, 0.0, 1),
				stk(Vector2(10, -2), Vector2(18, -18), 2.6, s + 2, WOOD_D, 2), leaf(Vector2(18, -18), 14, 5, -0.8, s + 3)], rim)
			rings(ci, Vector2(-30, 11), Vector2(10, 15), s, 3)
			for k in 3:
				ln(ci, Vector2(-14.0 + float(k) * 18.0, 4), Vector2(-2.0 + float(k) * 18.0, 6), 1.5, Color(WOOD_D, 0.7), s + k)
		2:
			## 劈柴堆：一截截木柴码成三层，截面朝外（浅色木心、深色树皮、劈开的裂缝），两侧各插一根木桩挡着
			var rows := [[Vector2(-27, 28), Vector2(-9, 28), Vector2(9, 28), Vector2(27, 28)], [Vector2(-18, 11), Vector2(0, 11), Vector2(18, 11)], [Vector2(-9, -6), Vector2(9, -6)]]
			var parts := [stk(Vector2(-40, 40), Vector2(-40, -4), 3.2, s, WOOD_D), stk(Vector2(40, 40), Vector2(40, -4), 3.2, s + 1, WOOD_D)]
			var i := 0
			for row in rows:
				for c0 in row:
					parts.append(circ(c0, 9.5, s + 2 + i, WOOD_D, 1))
					i += 1
			sil(ci, parts, rim)
			i = 0
			for row in rows:
				for c0 in row:
					var c: Vector2 = c0
					ci.draw_colored_polygon(ell(c, Vector2(7.4, 7.4), s + i, 0.05, 12), FACE if i % 2 == 0 else FACE.darkened(0.05))
					ci.draw_arc(c, 3.6, 0.0, TAU, 8, Color(WOOD_D, 0.45), 1.2, true)
					var a: float = 0.6 + float(i) * 1.3
					ln(ci, c, c + Vector2(cos(a), sin(a)) * 8.0, 1.8, WOOD_D, s + i)
					i += 1
		3:
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
		4:
			## 削木架：两副 X 形木架托着一根横放的原木，地上卷着刨花，旁边靠一把石锛
			var parts := []
			for x in [-30.0, 30.0]:
				parts.append(stk(Vector2(x - 12.0, 40), Vector2(x + 8.0, -12), 3.2, s + int(x), WOOD_D))
				parts.append(stk(Vector2(x + 12.0, 40), Vector2(x - 8.0, -12), 3.2, s + int(x) + 1, WOOD_D))
			parts.append(bx(-48, -14, 96, 20, 10, s + 4, WOOD))
			parts.append(ov(Vector2(-48, -4), 7, 10, s + 5, FACE, 0.0, 1))
			parts.append(stk(Vector2(40, 40), Vector2(48, -4), 2.6, s + 6, WOOD_D, 2))
			parts.append(pg([Vector2(42, -10), Vector2(56, -6), Vector2(54, 2), Vector2(44, 0)], s + 7, STONE, 1))
			sil(ci, parts, rim)
			ci.draw_colored_polygon(ell(Vector2(4, -10), Vector2(30, 3.5), s, 0.0, 12), FACE)
			for k in 3:
				ln(ci, Vector2(-30.0 + float(k) * 22.0, -2), Vector2(-16.0 + float(k) * 22.0, 0), 1.5, Color(WOOD_D, 0.7), s + k)
			for p in [Vector2(-16, 34), Vector2(2, 38), Vector2(18, 33)]:
				var v: Vector2 = p
				ci.draw_arc(v, 4.5, PI * 0.9, PI * 2.4, 10, FACE.darkened(0.08), 2.6, true)
				ci.draw_arc(v, 4.5, PI * 0.9, PI * 2.4, 10, Color(INK, 0.5), 1.0, true)
		5:
			var parts := [stk(Vector2(-40, 40), Vector2(-40, -26), 3.6, s, WOOD_D), stk(Vector2(40, 40), Vector2(40, -14), 3.6, s + 1, WOOD_D),
				pg([Vector2(-50, -32), Vector2(50, -20), Vector2(50, -12), Vector2(-50, -24)], s + 2, PLANK),
				bx(-30, 18, 16, 22, 2, s + 3, PLANK), bx(-12, 10, 14, 30, 2, s + 4, PLANK.darkened(0.06)),
				bx(10, 26, 24, 14, 3, s + 5, WOOD)]
			sil(ci, parts, rim)
			_plank_lines(ci, Rect2(-50, -32, 100, 18), 6, s, true)
			sil(ci, [stk(Vector2(-20, -18), Vector2(-20, -4), 1.2, s + 6, ROPE, 2), pg([Vector2(-26, -4), Vector2(-14, -4), Vector2(-16, 6), Vector2(-24, 6)], s + 7, STONE),
				stk(Vector2(18, -14), Vector2(18, 0), 1.2, s + 8, ROPE, 2), pg([Vector2(14, 0), Vector2(26, 0), Vector2(22, 8), Vector2(12, 4)], s + 9, STONE)], false)
		6:
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
		_:
			## 图腾工坊：两根柱子撑起的斜顶棚下，立着一根雕了一半的图腾柱（上半截刻好了脸，下半截还是原木），地上满是木屑
			var parts := [stk(Vector2(-46, 40), Vector2(-46, -30), 3.6, s, WOOD_D), stk(Vector2(46, 40), Vector2(46, -22), 3.6, s + 1, WOOD_D),
				pg([Vector2(-56, -38), Vector2(56, -26), Vector2(56, -16), Vector2(-56, -28)], s + 2, GRASS),
				bx(-14, -28, 28, 68, 6, s + 3, WOOD)]
			parts.append(pg([Vector2(-14, -20), Vector2(-30, -30), Vector2(-26, -14)], s + 4, WOOD))
			parts.append(pg([Vector2(14, -20), Vector2(30, -30), Vector2(26, -14)], s + 5, WOOD))
			parts.append(stk(Vector2(26, 40), Vector2(36, 4), 2.4, s + 6, WOOD_D, 2))
			parts.append(pg([Vector2(32, 0), Vector2(42, -2), Vector2(40, 8), Vector2(32, 8)], s + 7, STONE, 1))
			sil(ci, parts, rim)
			for k in 7:
				ln(ci, Vector2(-50.0 + float(k) * 16.0, -36.0 + float(k) * 1.8), Vector2(-46.0 + float(k) * 16.0, -24.0 + float(k) * 1.8), 1.6, Color(GRASS_D, 0.9), s + k)
			eye(ci, Vector2(-6, -16), 3.6)
			eye(ci, Vector2(6, -16), 3.6)
			ci.draw_rect(Rect2(-7, -6, 14, 4), INK)
			zig(ci, -12, 12, 4, 2.4, 6, CLAY, 2.0, s)
			ln(ci, Vector2(-14, 10), Vector2(14, 10), 1.8, WOOD_D, s)
			_bark(ci, Vector2(0, 8), 14, 30, s)
			for p in [Vector2(-34, 36), Vector2(-22, 38), Vector2(18, 38), Vector2(-28, 30)]:
				var v: Vector2 = p
				var ch := poly([v, v + Vector2(6, -2), v + Vector2(4, 3)], s)
				ci.draw_colored_polygon(ch, FACE)
				outline(ci, ch, 1.2)

static func _main(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			var parts := [pg([Vector2(-26, 24), Vector2(-42, 36), Vector2(-20, 32)], s, WOOD_D), pg([Vector2(26, 24), Vector2(44, 34), Vector2(20, 32)], s + 1, WOOD_D),
				pg([Vector2(-4, 30), Vector2(-8, 42), Vector2(6, 32)], s + 2, WOOD_D)]
			parts.append_array(_log_up(Vector2(0, -6), 30, 34, s + 3))
			parts.append(leaf(Vector2(-24, -2), 14, 5, 2.4, s + 6, MOSS))
			sil(ci, parts, rim)
			rings(ci, Vector2(0, -6), Vector2(30, 9.6), s, 3)
			_bark(ci, Vector2(0, -6), 30, 34, s)
		2:
			sil(ci, [stk(Vector2(-16, -2), Vector2(-26, 36), 3.6, s, WOOD_D), stk(Vector2(16, -2), Vector2(26, 36), 3.6, s + 1, WOOD_D),
				stk(Vector2(0, 0), Vector2(0, 30), 3.6, s + 2, WOOD_D.darkened(0.1)), stk(Vector2(-22, 20), Vector2(22, 20), 2.4, s + 3, WOOD_D, 2),
				ov(Vector2(0, -6), 32, 11, s + 4, WOOD, 0.0, 1)], rim)
			rings(ci, Vector2(0, -6), Vector2(32, 11), s, 2)
		3:
			sil(ci, [stk(Vector2(-36, 0), Vector2(-42, 34), 4.0, s, WOOD_D), stk(Vector2(-28, 0), Vector2(-24, 34), 4.0, s + 1, WOOD_D),
				stk(Vector2(36, 0), Vector2(42, 34), 4.0, s + 2, WOOD_D), stk(Vector2(28, 0), Vector2(24, 34), 4.0, s + 3, WOOD_D),
				bx(-50, -10, 100, 14, 6, s + 4, PLANK)], rim)
			_plank_lines(ci, Rect2(-50, -10, 100, 14), 2, s)
			for k in 3:
				ln(ci, Vector2(-30.0 + float(k) * 30.0, -6), Vector2(-18.0 + float(k) * 30.0, -6), 1.4, Color(WOOD_D, 0.6), s + k)
		4:
			## 鹿角衣架：一根立在树桩座上的木杆，顶上绑着一对鹿角当挂钩，挂着一张兽皮
			var parts := [ov(Vector2(0, 36), 22, 7, s, WOOD_D, 0.0, 1), stk(Vector2(0, 34), Vector2(0, -30), 3.6, s + 1, WOOD)]
			for sd in [-1.0, 1.0]:
				parts.append(stk(Vector2(0, -26), Vector2(sd * 22.0, -40), 2.6, s + 2, BONE2, 2))
				parts.append(stk(Vector2(sd * 12.0, -32), Vector2(sd * 12.0, -46), 2.2, s + 3, BONE2, 2))
				parts.append(stk(Vector2(sd * 22.0, -40), Vector2(sd * 30.0, -38), 2.2, s + 4, BONE2, 2))
			parts.append(pg([Vector2(-6, -24), Vector2(22, -26), Vector2(26, 6), Vector2(18, 14), Vector2(4, 10), Vector2(-4, 2)], s + 5, Color("d9b07a")))
			sil(ci, parts, rim)
			for p in [Vector2(10, -16), Vector2(18, -4), Vector2(6, 0)]:
				var v: Vector2 = p
				ci.draw_colored_polygon(ell(v, Vector2(3.2, 2.4), s + int(v.y), 0.1, 8), Color("8a5a30"))
			for k in 3:
				ln(ci, Vector2(-3, -22.0 + float(k) * 3.0), Vector2(3, -20.0 + float(k) * 3.0), 1.8, ROPE, s + k)
		5:
			sil(ci, [bx(-38, 2, 14, 32, 4, s, WOOD_D), bx(24, 2, 14, 32, 4, s + 1, WOOD_D),
				bx(-46, -12, 92, 16, 6, s + 2, PLANK)], rim)
			_plank_lines(ci, Rect2(-46, -12, 92, 16), 3, s, true)
			_nails(ci, [Vector2(-31, -4), Vector2(31, -4)])
		6:
			## 木梯：两根长木杆，中间五道横档用草绳绑住
			var parts := [stk(Vector2(-22, 42), Vector2(-14, -44), 3.6, s, WOOD_D), stk(Vector2(22, 42), Vector2(14, -44), 3.6, s + 1, WOOD_D)]
			for k in 5:
				var y := 30.0 - float(k) * 17.0
				var hw := 22.0 - (30.0 - y) * 0.094
				parts.append(stk(Vector2(-hw - 4.0, y), Vector2(hw + 4.0, y), 2.8, s + 2 + k, WOOD, 2))
			sil(ci, parts, rim)
			for k in 5:
				var y := 30.0 - float(k) * 17.0
				var hw := 22.0 - (30.0 - y) * 0.094
				for sd in [-1.0, 1.0]:
					ln(ci, Vector2(sd * hw - 3.0, y - 3.0), Vector2(sd * hw + 3.0, y + 3.0), 1.8, ROPE, s + k)
		7:
			var parts := [stk(Vector2(-34, -40), Vector2(-34, 40), 3.6, s, WOOD_D), stk(Vector2(34, -40), Vector2(34, 40), 3.6, s + 1, WOOD_D),
				bx(-40, -12, 80, 8, 3, s + 2, PLANK), bx(-40, 22, 80, 8, 3, s + 3, PLANK),
				ov(Vector2(-16, -22), 10, 10, s + 4, CLAYPOT), ov(Vector2(12, -22), 8, 10, s + 5, TAN),
				bx(-22, 8, 18, 14, 3, s + 6, ROPE.darkened(0.1)), circ(Vector2(16, 14), 8, s + 7, BERRY)]
			sil(ci, parts, rim)
			_nails(ci, [Vector2(-34, -8), Vector2(34, -8), Vector2(-34, 26), Vector2(34, 26)])
		8:
			sil(ci, [bx(-38, -18, 76, 54, 6, s, PLANK), bx(-42, -26, 84, 14, 5, s + 1, WOOD)], rim)
			_plank_lines(ci, Rect2(-38, -12, 76, 48), 4, s)
			ln(ci, Vector2(-30, -10), Vector2(30, 34), 3.0, Color(WOOD_D, 0.8), s)
			pl(ci, [Vector2(-10, -26), Vector2(0, -34), Vector2(10, -26)], 3.0, ROPE, s)
			_nails(ci, [Vector2(-32, -6), Vector2(32, -6), Vector2(-32, 30), Vector2(32, 30)])
		9:
			## 木躺椅：斜靠背、长座面的矮木椅，座面和靠背用草绳编成网
			var parts := [stk(Vector2(-38, 10), Vector2(-42, 38), 3.6, s, WOOD_D), stk(Vector2(30, 10), Vector2(34, 38), 3.6, s + 1, WOOD_D),
				stk(Vector2(-6, 10), Vector2(-4, 38), 3.2, s + 2, WOOD_D),
				pg([Vector2(-44, 4), Vector2(40, 4), Vector2(40, 14), Vector2(-44, 14)], s + 3, PLANK),
				pg([Vector2(18, 8), Vector2(40, -40), Vector2(50, -36), Vector2(30, 10)], s + 4, PLANK)]
			sil(ci, parts, rim)
			for k in 6:
				ln(ci, Vector2(-38.0 + float(k) * 9.0, 5), Vector2(-34.0 + float(k) * 9.0, 13), 1.6, ROPE, s + k)
			for k in 4:
				var c: Vector2 = Vector2(26, 0).lerp(Vector2(42, -34), float(k) / 3.0)
				ln(ci, c + Vector2(-3, -2), c + Vector2(7, 2), 1.6, ROPE, s + k)
			sil(ci, [ov(Vector2(40, -36), 9, 5, s + 9, Color("d9b07a"), -1.1, 1)], false)
		10:
			## 草垫木床：四截树桩当床脚，原木绑成床框，上面铺一层干草垫，再搭一张兽皮
			var parts := [bx(-48, 18, 14, 20, 4, s, WOOD_D), bx(34, 18, 14, 20, 4, s + 1, WOOD_D),
				bx(-52, 6, 104, 16, 8, s + 2, WOOD), bx(-48, -6, 96, 14, 6, s + 3, GRASS),
				pg([Vector2(-6, -8), Vector2(44, -10), Vector2(48, 4), Vector2(30, 10), Vector2(-2, 8)], s + 4, FUR),
				ov(Vector2(-34, -10), 13, 6, s + 5, GRASS_D, 0.0, 1)]
			sil(ci, parts, rim)
			for k in 8:
				ln(ci, Vector2(-44.0 + float(k) * 6.0, -4), Vector2(-42.0 + float(k) * 6.0, 6), 1.4, Color(GRASS_D, 0.9), s + k)
			for k in 4:
				ln(ci, Vector2(4.0 + float(k) * 10.0, -6), Vector2(6.0 + float(k) * 10.0, 6), 1.6, Color(FUR_D, 0.7), s + k)
			for x in [-40.0, 40.0]:
				ln(ci, Vector2(x - 4.0, 8), Vector2(x + 4.0, 18), 2.2, ROPE, s)
				ln(ci, Vector2(x + 4.0, 8), Vector2(x - 4.0, 18), 2.2, ROPE, s + 1)
			_plank_lines(ci, Rect2(-52, 6, 104, 16), 2, s)
		11:
			## 皮绳木柜：竖木板拼成的高柜，门用两道皮绳绑着，一根骨头当插销，顶上压着一块兽皮
			var parts := [bx(-32, -40, 64, 80, 6, s, PLANK), bx(-38, -48, 76, 12, 4, s + 1, WOOD),
				pg([Vector2(-30, -48), Vector2(20, -50), Vector2(28, -40), Vector2(10, -32), Vector2(-24, -36)], s + 2, FUR)]
			sil(ci, parts, rim)
			_plank_lines(ci, Rect2(-32, -34, 64, 74), 5, s, true)
			for y in [-14.0, 18.0]:
				sil(ci, [pg([Vector2(-36, y - 3.0), Vector2(36, y - 1.0), Vector2(36, y + 5.0), Vector2(-36, y + 3.0)], s + int(y), Color("6a3a1a"), 2)], false)
				ln(ci, Vector2(-34, y), Vector2(34, y + 2.0), 1.2, Color("b07a44"), s)
			sil(ci, [stk(Vector2(-8, 2), Vector2(14, 0), 2.8, s + 5, BONE2, 1), circ(Vector2(-10, 2), 3.4, s + 6, BONE2, 1), circ(Vector2(16, 0), 3.4, s + 7, BONE2, 1)], false)
			zig(ci, -26, 26, 32, 2.4, 8, CLAY, 1.8, s)
			for k in 3:
				ln(ci, Vector2(-16.0 + float(k) * 14.0, -44), Vector2(-14.0 + float(k) * 14.0, -38), 1.4, Color(FUR_D, 0.7), s + k)
		12:
			## 兽皮靠椅：高靠背木椅，靠背和座面搭着兽皮，靠背顶上挂一串兽牙
			var back := [Vector2(-26, -2), Vector2(-30, -46), Vector2(-16, -52), Vector2(0, -46), Vector2(16, -52), Vector2(30, -46), Vector2(26, -2)]
			var parts := [stk(Vector2(-24, 6), Vector2(-30, 40), 4.0, s, WOOD_D), stk(Vector2(24, 6), Vector2(30, 40), 4.0, s + 1, WOOD_D),
				stk(Vector2(-30, 26), Vector2(30, 26), 2.4, s + 2, WOOD_D, 2), pg(back, s + 3, WOOD),
				pg([Vector2(-22, -40), Vector2(22, -40), Vector2(24, -4), Vector2(-24, -4)], s + 4, Color("d9b07a")),
				bx(-34, -4, 68, 14, 5, s + 5, Color("e0bc88"))]
			sil(ci, parts, rim)
			for p in [Vector2(-12, -30), Vector2(10, -26), Vector2(-4, -12), Vector2(14, -10), Vector2(-24, 3), Vector2(4, 4), Vector2(24, 2)]:
				var v: Vector2 = p
				ci.draw_colored_polygon(ell(v, Vector2(3.6, 2.6), s + int(v.x), 0.1, 8), Color("8a5a30"))
			pl(ci, [Vector2(-22, -44), Vector2(-8, -38), Vector2(8, -38), Vector2(22, -44)], 1.8, ROPE, s)
			for k in 4:
				var x := -15.0 + float(k) * 10.0
				var y := -41.0 + absf(x) * -0.12
				var tooth := poly([Vector2(x - 2.4, y), Vector2(x + 2.4, y), Vector2(x, y + 9.0)], s + k)
				ci.draw_colored_polygon(tooth, BONE)
				outline(ci, tooth, 1.2)
			ci.draw_circle(Vector2(0, -22), 6, OCHRE)
			outline(ci, ell(Vector2(0, -22), Vector2(6, 6), s, 0.0, 12), 1.6)
		_:
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


static func _sub(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			## 木针：一根削尖的细木针，尾端钻了针眼，穿着一截草线
			sil(ci, [stk(Vector2(-24, 24), Vector2(32, -30), 4.6, s, FACE, 1), pg([Vector2(-20, 20), Vector2(-42, 42), Vector2(-27, 27)], s + 1, FACE, 2)], rim)
			ci.draw_circle(Vector2(30, -30), 2.4, Color("2a170c"))
			pl(ci, [Vector2(30, -30), Vector2(40, -20), Vector2(34, -6), Vector2(44, 6), Vector2(38, 20)], 3.4, INK, s)
			pl(ci, [Vector2(30, -30), Vector2(40, -20), Vector2(34, -6), Vector2(44, 6), Vector2(38, 20)], 2.0, Color("d8a848"), s)
			ln(ci, Vector2(-20, 18), Vector2(10, -10), 1.2, Color(WOOD_D, 0.6), s)
		2:
			var parts := []
			var pts := arcp(Vector2(0, -16), Vector2(30, 40), PI * 0.15, PI * 0.85, 4)
			for i in pts.size():
				parts.append(circ(pts[i], 8, s + i, WOOD if i % 2 == 0 else FACE.darkened(0.1)))
			ci.draw_arc(Vector2(0, -16), 30, PI * 0.08, PI * 0.92, 14, INK, 3.0, true)
			sil(ci, parts, rim)
			for p in pts:
				ci.draw_circle(p, 2.0, WOOD_D)
		3:
			sil(ci, [stk(Vector2(-34, 34), Vector2(6, -4), 4.0, s, WOOD), ov(Vector2(16, -16), 16, 12, s + 1, WOOD, -0.8)], rim)
			ci.draw_colored_polygon(ell(Vector2(17, -17), Vector2(11, 7), s + 2, 0.0, 12, -0.8), WOOD_D.lightened(0.15))
		4:
			var parts := [bx(-34, -24, 68, 18, 8, s, PLANK)]
			for k in 9:
				parts.append(stk(Vector2(-28.0 + float(k) * 7.0, -10), Vector2(-28.0 + float(k) * 7.0, 26), 2.4, s + k + 1, PLANK, 2))
			sil(ci, parts, rim)
			zig(ci, -28, 28, -16, 2.4, 8, CLAY, 1.8, s)
		5:
			## 木笛：一根斜放的长木管，管身一排孔，吹口一端缠着草绳，尾端挂一根羽毛
			sil(ci, [stk(Vector2(-40, 30), Vector2(36, -28), 6.0, s, WOOD), circ(Vector2(36, -28), 6.4, s + 1, WOOD_D, 1),
				leaf(Vector2(-36, 34), 24, 6, 2.2, s + 2, Color("e8e0d0"))], rim)
			ci.draw_circle(Vector2(36, -28), 2.6, Color("2a170c"))
			for k in 5:
				var c: Vector2 = Vector2(-20, 15).lerp(Vector2(18, -14), float(k) / 4.0)
				ci.draw_circle(c, 2.4, Color("2a170c"))
			for k in 3:
				var c: Vector2 = Vector2(24, -19).lerp(Vector2(30, -23.5), float(k) / 2.0)
				ln(ci, c + Vector2(-4, -5), c + Vector2(4, 5), 2.2, ROPE, s + k)
			ln(ci, Vector2(-34, 26), Vector2(-28, 22), 1.6, Color(WOOD_D, 0.7), s)
		6:
			## 木雕小人：一块木头刻成的小人，圆脑袋、刻出的眼睛和嘴，双手贴在肚子上，站在小木座上
			var parts := [bx(-20, 30, 40, 10, 4, s, WOOD_D), pg([Vector2(-16, -6), Vector2(16, -6), Vector2(20, 18), Vector2(12, 32), Vector2(-12, 32), Vector2(-20, 18)], s + 1, WOOD, 0),
				circ(Vector2(0, -22), 16, s + 2, WOOD),
				stk(Vector2(-16, -2), Vector2(-8, 14), 4.0, s + 3, WOOD.darkened(0.06)), stk(Vector2(16, -2), Vector2(8, 14), 4.0, s + 4, WOOD.darkened(0.06))]
			sil(ci, parts, rim)
			eye(ci, Vector2(-6, -24), 3.2)
			eye(ci, Vector2(6, -24), 3.2)
			ln(ci, Vector2(-5, -14), Vector2(5, -14), 2.0, INK, s)
			zig(ci, -14, 14, 22, 2.2, 6, CLAY, 1.8, s)
			for k in 3:
				ln(ci, Vector2(-10.0 + float(k) * 10.0, -40), Vector2(-8.0 + float(k) * 10.0, -34), 2.0, WOOD_D, s + k)
		7:
			sil(ci, [pg([Vector2(-28, -8), Vector2(28, -8), Vector2(0, 34)], s, WOOD, 0), ov(Vector2(0, -8), 28, 9, s + 1, PLANK, 0.0, 1),
				stk(Vector2(0, -12), Vector2(0, -30), 3.4, s + 2, WOOD_D)], rim)
			for k in 3:
				ci.draw_arc(Vector2(0, -8), 18.0 + float(k) * 4.0, PI * 0.15, PI * 0.85, 8, CLAY if k % 2 == 0 else TEAL, 2.4, true)
			for k in 3:
				ci.draw_arc(Vector2(0, 30), 30.0 + float(k) * 6.0, PI * 1.2, PI * 1.35, 4, Color(INK, 0.4), 1.6, true)
		8:
			var body := [Vector2(-38, 0), Vector2(-14, -18), Vector2(16, -14), Vector2(28, -2), Vector2(42, -16), Vector2(40, 16), Vector2(28, 4), Vector2(14, 16), Vector2(-14, 18)]
			sil(ci, [pg(body, s, WOOD, 0)], rim)
			ci.draw_circle(Vector2(-24, -3), 3, INK)
			pl(ci, [Vector2(-14, -12), Vector2(-10, 0), Vector2(-14, 12)], 1.8, INK, s)
			for k in 3:
				pl(ci, [Vector2(-4.0 + float(k) * 10.0, -10), Vector2(2.0 + float(k) * 10.0, 0), Vector2(-4.0 + float(k) * 10.0, 10)], 1.6, Color(WOOD_D, 0.8), s + k)
		9:
			sil(ci, [bx(-26, 26, 52, 12, 4, s, WOOD_D), stk(Vector2(0, 16), Vector2(0, 28), 3.0, s + 1, WOOD_D),
				ov(Vector2(4, 4), 24, 14, s + 2, WOOD, -0.15), circ(Vector2(-20, -12), 11, s + 3, WOOD),
				pg([Vector2(-30, -12), Vector2(-42, -8), Vector2(-30, -6)], s + 4, OCHRE),
				pg([Vector2(22, 0), Vector2(42, -16), Vector2(36, 6)], s + 5, WOOD.darkened(0.08))], rim)
			ci.draw_circle(Vector2(-22, -14), 2.4, INK)
			for k in 3:
				pl(ci, [Vector2(-4.0 + float(k) * 8.0, -2), Vector2(4.0 + float(k) * 8.0, 6)], 1.6, Color(WOOD_D, 0.8), s + k)
		10:
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
		_:
			var parts := _log_up(Vector2(0, -18), 30, 50, s)
			parts[1] = ov(Vector2(0, -18), 30, 9.6, s + 1, Color("efdcb6"), 0.0, 1)
			sil(ci, parts, rim)
			for k in 6:
				var x := -26.0 + float(k) * 10.4
				ln(ci, Vector2(x, -12), Vector2(x + 5.0, 26), 2.0, ROPE, s + k)
				ln(ci, Vector2(x + 5.0, -12), Vector2(x, 26), 2.0, ROPE, s + k + 7)
			ci.draw_arc(Vector2(0, -6), 30, PI * 0.1, PI * 0.9, 12, CLAY, 3.0, true)
