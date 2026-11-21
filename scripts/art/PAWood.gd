class_name PAWood
extends PA
## 木头线：林木 / 木料 / 林间收获。
## 旧图（木工桩、家具、木工艺品）留作成品图：gen_old / main_old / sub_old。

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

static func gen_old(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	_tier(ci, lv, 7, func(): _gen(ci, lv, s, rim))

static func main_old(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	_tier(ci, lv, 13, func(): _main(ci, lv, s, rim))

static func sub_old(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
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

# ================================================================ 新木头线：林木 / 木料 / 林间收获

const BARK := Color("7d5434")
const PINE := Color("4f8f3e")
const PINE_D := Color("33652e")
const EARTH := Color("9a6b45")
const SPLIT := Color("dcae72")
const POLE := Color("e6c08a")
const CEDAR := Color("a9503a")
const CEDAR_F := Color("eb9e6c")
const BIRCH := Color("f1ece0")
const BIRCH_IN := Color("e2a76a")
const RESIN := Color("efcf72")
const MUER := Color("5e3a2c")
const SHELF := Color("c99a5e")
const LINGZHI := Color("9c3d26")
const COMB := Color("eab63e")
const HONEY := Color("f5a21c")

const W_GEN := [0.677, 1.13, 1.03, 0.968, 1.092, 0.893, 1.022, 1.081]
const W_MAIN := [0.692, 0.737, 0.676, 0.677, 0.598, 0.877, 0.716, 0.818, 0.775, 0.824, 0.812, 0.957, 1.0, 0.832, 1.056, 1.143]
const W_SUB := [0.519, 0.735, 0.69, 0.676, 1.055, 0.861, 0.757, 0.805, 1.04, 0.914, 0.879, 0.893]

static func gen(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	var keep := _w_grow(ci, W_GEN[clampi(lv, 1, 8) - 1])
	_gen_art(ci, lv, s, rim)
	_w_ungrow(ci, keep)

static func main(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	var keep := _w_grow(ci, W_MAIN[clampi(lv, 1, 16) - 1])
	_main_art(ci, lv, s, rim)
	_w_ungrow(ci, keep)

static func sub(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	var keep := _w_grow(ci, W_SUB[clampi(lv, 1, 12) - 1])
	_sub_art(ci, lv, s, rim)
	_w_ungrow(ci, keep)

## 以脚下的地面点为中心整体缩放
static func _w_grow(ci: CanvasItem, k: float) -> Transform2D:
	var keep := xf
	xf = keep * Transform2D(0.0, Vector2(k, k), 0.0, Vector2(0, 38) * (1.0 - k))
	ci.draw_set_transform_matrix(xf)
	return keep

static func _w_ungrow(ci: CanvasItem, keep: Transform2D) -> void:
	xf = keep
	ci.draw_set_transform_matrix(xf)

## 一堆前后叠着的东西共用一圈白边
static func _w_rim(ci: CanvasItem, parts: Array) -> void:
	for p in parts:
		dilate(ci, p[0], 9.0, RIM_COL)

# ---------------------------------------------------------------- 松树

## 松树每层针叶的几何：[树梢点, 底边 y, 半宽]，从下往上
static func _pine_tiers(base: Vector2, h: float, w: float, n: int, lift: float) -> Array:
	var out := []
	var bot := base.y - h * lift
	var top := base.y - h
	var span := bot - top
	var th := span * 1.7 / (float(n) + 0.7)
	for i in n:
		var yb := bot - span * float(i) / (float(n) + 0.7)
		var yt := maxf(yb - th, top) if i < n - 1 else top
		var wi := w * (1.0 - 0.62 * float(i) / float(maxi(n - 1, 1)))
		out.append([Vector2(base.x, yt), yb, wi])
	return out

static func _pine_parts(base: Vector2, h: float, w: float, n: int, s: int, col: Color = PINE, lift: float = 0.18, tw: float = 0.0) -> Array:
	if tw <= 0.0:
		tw = maxf(w * 0.12, 2.6)
	var tt := base + Vector2(0, -h * maxf(lift + 0.2, 0.4))
	var parts := [pg([base + Vector2(-tw * 1.35, 1), base + Vector2(-tw, -3), tt + Vector2(-tw * 0.7, 0), tt + Vector2(tw * 0.7, 0), base + Vector2(tw, -3), base + Vector2(tw * 1.35, 1)], s, BARK, 1)]
	var tiers := _pine_tiers(base, h, w, n, lift)
	for i in tiers.size():
		var q: Array = tiers[i]
		var ap: Vector2 = q[0]
		var yb: float = q[1]
		var wi: float = q[2]
		var pts := [ap, Vector2(ap.x + wi * 0.42, lerpf(ap.y, yb, 0.5)), Vector2(ap.x + wi, yb)]
		var m := 4
		for k in range(1, m * 2):
			var x := lerpf(wi, -wi, float(k) / float(m * 2))
			pts.append(Vector2(ap.x + x, yb + (4.5 if k % 2 == 1 else -0.5) - absf(x) / wi * 1.5))
		pts.append(Vector2(ap.x - wi, yb))
		pts.append(Vector2(ap.x - wi * 0.42, lerpf(ap.y, yb, 0.5)))
		var c := col.lightened(0.04 * float(i))
		parts.append(pg(pts, s + i + 1, c, 1))
	return parts

static func _pine_det(ci: CanvasItem, base: Vector2, h: float, w: float, n: int, s: int, lift: float = 0.18) -> void:
	var tiers := _pine_tiers(base, h, w, n, lift)
	for i in tiers.size():
		var q: Array = tiers[i]
		var ap: Vector2 = q[0]
		var yb: float = q[1]
		var wi: float = q[2]
		pl(ci, [ap + Vector2(-2, 6), Vector2(ap.x - wi * 0.32, lerpf(ap.y, yb, 0.55)), Vector2(ap.x - wi * 0.62, yb - 3.0)], 2.0, Color(1, 1, 1, 0.28), s + i)
		if wi < 16.0:
			continue
		for k in 3:
			var x := lerpf(-wi * 0.5, wi * 0.6, float(k) / 2.0) + (srnd(s + i * 5 + k) - 0.5) * 4.0
			ln(ci, Vector2(ap.x + x, yb - 7.0), Vector2(ap.x + x + 1.5, yb - 2.0), 1.3, Color(INK, 0.3), s + i * 3 + k)

## 小树苗：针叶合成一整块剪影，只描外轮廓，层与层之间用深绿细线分开，免得黑线太密
static func _sapling(ci: CanvasItem, base: Vector2, h: float, w: float, n: int, s: int, col: Color, lift: float, tw: float, extra: Array, rim: bool) -> void:
	var ps := _pine_parts(base, h, w, n, s, col, lift, tw)
	var acc: PackedVector2Array = ps[1][0]
	for i in range(2, ps.size()):
		var m := Geometry2D.merge_polygons(acc, ps[i][0])
		var best: PackedVector2Array = m[0]
		for q in m:
			if (q as PackedVector2Array).size() > best.size():
				best = q
		acc = best
	sil(ci, extra + [ps[0], P(acc, col, 1)], rim, 2.4)
	var tiers := _pine_tiers(base, h, w, n, lift)
	for i in range(1, tiers.size()):
		var q: Array = tiers[i]
		var ap: Vector2 = q[0]
		var yb: float = q[1]
		var wi: float = q[2]
		var edge := []
		for k in 7:
			var x := lerpf(wi * 0.85, -wi * 0.85, float(k) / 6.0)
			edge.append(Vector2(ap.x + x, yb + (3.0 if k % 2 == 1 else 0.0) - absf(x) / wi * 1.5))
		pl(ci, edge, 1.4, col.darkened(0.35), s + i)
	for i in tiers.size():
		var q: Array = tiers[i]
		var ap: Vector2 = q[0]
		var yb: float = q[1]
		var wi: float = q[2]
		pl(ci, [ap + Vector2(-1.5, 5), Vector2(ap.x - wi * 0.4, yb - 2.0)], 1.8, Color(1, 1, 1, 0.3), s + i)

## 树根边上的小草丛
static func _tuft(ci: CanvasItem, c: Vector2, s: int) -> void:
	for k in 3:
		var a := -PI * 0.5 + (float(k) - 1.0) * 0.45
		ln(ci, c, c + Vector2(cos(a), sin(a)) * (6.0 + float(k % 2) * 3.0), 1.8, MOSS_D, s + k)

# ---------------------------------------------------------------- 原木、劈柴、木板

## 横躺的木头：c 是朝外那个截面的中心，r 截面半高，sq 截面扁度，d 往后延伸的向量
static func _log_geo(c: Vector2, r: float, d: Vector2, sq: float) -> Array:
	var rx := r * sq
	var body := [c + Vector2(0, -r)]
	for k in 11:
		var an := -PI * 0.5 + PI * float(k) / 10.0
		body.append(c + d + Vector2(cos(an) * rx, sin(an) * r))
	body.append(c + Vector2(0, r))
	var face := []
	for k in 18:
		var an := TAU * float(k) / 18.0
		face.append(c + Vector2(cos(an) * rx, sin(an) * r))
	return [body, face]

static func _log_parts(c: Vector2, r: float, d: Vector2, s: int, sq: float = 0.5, bark: Color = BARK, face: Color = FACE) -> Array:
	var g := _log_geo(c, r, d, sq)
	return [pg(g[0], s, bark, 1), pg(g[1], s + 1, face, 2)]

static func _log_det(ci: CanvasItem, c: Vector2, r: float, d: Vector2, s: int, sq: float = 0.5, nring: int = 2, ring_col: Color = WOOD) -> void:
	var rx := r * sq
	for k in nring:
		var f := 1.0 - (float(k) + 1.0) / (float(nring) + 1.0)
		var e := ell(c + Vector2(rx * 0.06, r * 0.04), Vector2(rx * f, r * f), s + k, 0.05, 16)
		outline(ci, e, 1.4, Color(ring_col.darkened(0.3), 0.75))
	ci.draw_circle(c + Vector2(rx * 0.08, r * 0.06), maxf(r * 0.07, 1.2), Color(ring_col.darkened(0.4), 0.8))
	for k in 3:
		var t := -0.55 + float(k) * 0.55
		var a := c + Vector2(rx * 0.9 * sqrt(1.0 - t * t) + 3.0, r * t)
		var b := c + d + Vector2(-2.0, r * t)
		pl(ci, [a, a.lerp(b, 0.35) + Vector2(0, 1.5), a.lerp(b, 0.7) + Vector2(0, -1.0), b], 1.3, Color(INK, 0.3), s + k)
	ln(ci, c + Vector2(4, -r * 0.8), c + d * 0.85 + Vector2(0, -r * 0.8), 2.0, Color(1, 1, 1, 0.22), s)

## 劈柴：截面是一块扇形，尖朝下；外圈弧边是树皮
static func _split_geo(c: Vector2, r: float, d: Vector2, a0: float, a1: float) -> Array:
	var rx := r * 0.62
	var face := [c]
	var arc := []
	for k in 8:
		var an := lerpf(a0, a1, float(k) / 7.0)
		var p := c + Vector2(cos(an) * rx, sin(an) * r)
		face.append(p)
		arc.append(p)
	var all := PackedVector2Array()
	for p in face:
		all.append(p)
		all.append((p as Vector2) + d)
	var hull := Geometry2D.convex_hull(all)
	hull.remove_at(hull.size() - 1)
	return [hull, face, arc]

static func _split_parts(c: Vector2, r: float, d: Vector2, a0: float = -PI * 0.5 - 0.8, a1: float = -PI * 0.5 + 0.8) -> Array:
	var g := _split_geo(c, r, d, a0, a1)
	return [P(g[0], SPLIT, 1)]

static func _split_det(ci: CanvasItem, c: Vector2, r: float, d: Vector2, s: int, a0: float = -PI * 0.5 - 0.8, a1: float = -PI * 0.5 + 0.8) -> void:
	var g := _split_geo(c, r, d, a0, a1)
	var arc: Array = g[2]
	for k in arc.size() - 1:
		var p0: Vector2 = arc[k]
		var p1: Vector2 = arc[k + 1]
		ci.draw_colored_polygon(PackedVector2Array([p0, p1, p1 + d, p0 + d]), BARK)
	var top := []
	for p in arc:
		top.append((p as Vector2) + d)
	pl(ci, top, 2.2, INK, s)
	for k in 2:
		var p: Vector2 = arc[2 + k * 3]
		pl(ci, [p + d * 0.15, p + d * 0.5 + Vector2(0, -1.5), p + d * 0.85], 1.2, Color(INK, 0.4), s + k)
	var fp := poly(g[1], s + 1, 0.5)
	ci.draw_colored_polygon(fp, FACE)
	outline(ci, fp, 2.2)
	var rx := r * 0.62
	for k in 2:
		var f := 0.4 + float(k) * 0.3
		var arr := []
		for j in 7:
			var an := lerpf(a0 + 0.08, a1 - 0.08, float(j) / 6.0)
			arr.append(c + Vector2(cos(an) * rx * f, sin(an) * r * f))
		pl(ci, arr, 1.3, Color(WOOD_D, 0.6), s + k)

## 方木 / 木板：前面一个长方形，往后上方拉出顶面和右侧端面
static func _box_faces(c: Vector2, hw: float, hh: float, v: Vector2) -> Array:
	var a := c + Vector2(-hw, -hh)
	var b := c + Vector2(hw, -hh)
	var d := c + Vector2(hw, hh)
	var e := c + Vector2(-hw, hh)
	return [[a, b, d, e], [a, a + v, b + v, b], [b, b + v, d + v, d]]

static func _box_part(c: Vector2, hw: float, hh: float, v: Vector2, col: Color) -> Array:
	var all := PackedVector2Array()
	for f in _box_faces(c, hw, hh, v):
		for p in f:
			all.append(p)
	var hull := Geometry2D.convex_hull(all)
	hull.remove_at(hull.size() - 1)
	return P(hull, col, 2)

static func _wbox(ci: CanvasItem, c: Vector2, hw: float, hh: float, v: Vector2, s: int, col: Color, grain: int = 3) -> void:
	sil(ci, [_box_part(c, hw, hh, v, col)], false)
	var faces := _box_faces(c, hw, hh, v)
	var tones := [col.darkened(0.12), col.lightened(0.12), col.lightened(0.22)]
	for i in 3:
		var q := poly(faces[i], s + i, 0.5)
		ci.draw_colored_polygon(q, tones[i])
		outline(ci, q, 1.6)
	var a := c + Vector2(-hw, -hh)
	for k in grain:
		var t := (float(k) + 1.0) / (float(grain) + 1.0)
		var p0 := a + v * t + Vector2(4, 0)
		var p1 := a + v * t + Vector2(hw * 2.0 - 4.0, 0)
		pl(ci, [p0, p0.lerp(p1, 0.3) + Vector2(0, 0.8), p0.lerp(p1, 0.55) + Vector2(0, -0.6), p0.lerp(p1, 0.8) + Vector2(0, 0.7), p1], 1.2, Color(WOOD_D, 0.55), s + k)

static func _box_rim(ci: CanvasItem, cfg: Array, rim: bool) -> void:
	if not rim:
		return
	var ps := []
	for q in cfg:
		ps.append(_box_part(q[0], q[1], q[2], q[3], WOOD))
	_w_rim(ci, ps)

# ---------------------------------------------------------------- 阔叶树、香柏

const OAK := Color("5f9e3a")
const BIRCH_LEAF := Color("9cc951")
const CEDAR_LEAF := Color("3f6b4a")
const CEDAR_BARK := Color("8a4a30")

## 阔叶树：粗树干分两杈，上面一团团圆树冠。blobs 是 [相对树梢中心的偏移, 半径]
static func _broad_parts(base: Vector2, h: float, tw: float, crown: Vector2, blobs: Array, s: int, leaf_col: Color, bark: Color = BARK) -> Array:
	var fork := base + Vector2(0, -h * 0.42)
	var parts := [pg([base + Vector2(-tw * 1.5, 1), base + Vector2(-tw, -4), fork + Vector2(-tw * 0.7, 0), fork + Vector2(tw * 0.7, 0), base + Vector2(tw, -4), base + Vector2(tw * 1.5, 1)], s, bark, 1),
		stk(fork, fork + Vector2(-tw * 2.2, -h * 0.2), tw * 0.5, s + 1, bark), stk(fork, fork + Vector2(tw * 2.0, -h * 0.22), tw * 0.5, s + 2, bark)]
	for i in blobs.size():
		var q: Array = blobs[i]
		var r: float = q[1]
		parts.append(ov(crown + (q[0] as Vector2), r, r * 0.86, s + 3 + i, leaf_col.darkened(0.06 * float((i + 1) % 2)), 0.0, 1, 0.06))
	return parts

static func _broad_det(ci: CanvasItem, crown: Vector2, blobs: Array, s: int) -> void:
	for i in blobs.size():
		var q: Array = blobs[i]
		var c: Vector2 = crown + (q[0] as Vector2)
		var r: float = q[1]
		ci.draw_arc(c + Vector2(-r * 0.1, -r * 0.05), r * 0.62, PI + 0.5, PI * 1.6, 6, Color(1, 1, 1, 0.3), 2.0, true)
		ci.draw_arc(c + Vector2(r * 0.15, r * 0.2), r * 0.45, 0.4, 1.4, 5, Color(INK, 0.25), 1.4, true)

const OAK_BLOBS := [[Vector2(-26, 10), 16.0], [Vector2(26, 10), 16.0], [Vector2(-14, -8), 18.0], [Vector2(16, -8), 18.0], [Vector2(0, 8), 20.0], [Vector2(0, -16), 17.0]]

## 香柏：一层层平展的大枝叶托盘
static func _cedar_pads(ci: CanvasItem, base: Vector2, s: int, rim: bool) -> void:
	var trunk := pg([Vector2(-14, 38), Vector2(-9, 30), Vector2(-6, -30), Vector2(6, -30), Vector2(9, 30), Vector2(14, 38)], s, CEDAR_BARK, 1)
	var roots := [pg([Vector2(-30, 39), Vector2(-9, 26), Vector2(-6, 36)], s + 1, CEDAR_BARK, 1), pg([Vector2(30, 39), Vector2(9, 26), Vector2(6, 36)], s + 2, CEDAR_BARK, 1)]
	var pads := [[Vector2(-20, 6), 26.0, 8.0], [Vector2(22, 0), 26.0, 8.0], [Vector2(-14, -18), 24.0, 7.5], [Vector2(16, -26), 20.0, 7.0], [Vector2(-2, -42), 16.0, 6.5]]
	var parts := [ov(base, 42, 7, s + 3, EARTH, 0.0, 2), trunk] + roots
	for i in pads.size():
		var q: Array = pads[i]
		var c: Vector2 = q[0]
		parts.append(stk(Vector2(0, c.y + 4), c + Vector2(-signf(c.x) * 6.0, 4), 2.6, s + 10 + i, CEDAR_BARK, 2))
	for i in pads.size():
		var q: Array = pads[i]
		var c: Vector2 = q[0]
		var rx: float = q[1]
		var ry: float = q[2]
		var pts := []
		for k in 13:
			var an := PI + PI * float(k) / 12.0
			pts.append(c + Vector2(cos(an) * rx, sin(an) * ry * 1.3 + (2.0 if k % 2 == 1 else 0.0)))
		for k in 9:
			var x := lerpf(rx, -rx, float(k) / 8.0)
			pts.append(c + Vector2(x, ry * 0.7 + (3.0 if k % 2 == 1 else 0.0) - absf(x) / rx * 3.0))
		parts.append(pg(pts, s + 20 + i, CEDAR_LEAF.lightened(0.05 * float(i)), 1))
	sil(ci, parts, rim)
	for k in 3:
		var x := -5.0 + float(k) * 5.0
		pl(ci, [Vector2(x, 34), Vector2(x + 1.0, 20), Vector2(x - 0.5, 6)], 1.4, Color(INK, 0.35), s + k)
	for i in pads.size():
		var q: Array = pads[i]
		var c: Vector2 = q[0]
		var rx: float = q[1]
		pl(ci, [c + Vector2(-rx * 0.7, -2), c + Vector2(-rx * 0.1, -6), c + Vector2(rx * 0.5, -4)], 2.0, Color(1, 1, 1, 0.28), s + i)


# ---------------------------------------------------------------- 生产器：林木

static func _gen_art(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	var base := Vector2(0, 36)
	match lv:
		1:
			## 树桩冒新枝：砍剩的老树桩，旁边钻出一根带两片叶子的嫩枝
			var top := Vector2(-4, 14)
			var parts := [ov(Vector2(0, 36), 30, 6, s, EARTH, 0.0, 2)]
			parts.append_array(_log_up(top, 18, 20, s + 1, BARK))
			parts.append(stk(Vector2(12, 26), Vector2(20, 2), 1.8, s + 3, WOOD_D, 2))
			parts.append(leaf(Vector2(20, 2), 13, 5, -1.0, s + 4))
			parts.append(leaf(Vector2(17, 10), 10, 4, 0.2, s + 5))
			sil(ci, parts, rim)
			rings(ci, top, Vector2(18, 18 * 0.32), s, 2)
			_bark(ci, top, 18, 20, s)
			_tuft(ci, Vector2(-26, 36), s)
		2:
			## 小松苗：土堆上一棵只有两层针叶的小松树
			_sapling(ci, base, 40, 15, 2, s + 1, PINE.lightened(0.12), 0.3, 1.6, [ov(base, 16, 5, s, EARTH, 0.0, 2)], rim)
		3:
			## 细瘦小杉：又细又高的小树，枝叶稀
			_sapling(ci, base, 72, 18, 3, s + 1, PINE.lightened(0.06), 0.34, 2.2, [ov(base, 18, 5, s, EARTH, 0.0, 2)], rim)
			_tuft(ci, Vector2(13, 36), s)
		4:
			## 松树：长成了的松树，四层针叶，树下落着一根枝
			_sapling(ci, base, 88, 32, 4, s + 1, PINE, 0.18, 0.0, [ov(base, 32, 6, s, EARTH, 0.0, 2), stk(Vector2(-30, 34), Vector2(-14, 30), 1.8, s + 9, WOOD_D, 2)], rim)
			_tuft(ci, Vector2(22, 36), s)
		5:
			## 白桦树：一棵白桦，树皮白底黑斑，树冠是一团团浅绿的小叶
			var crown := Vector2(0, -12)
			var blobs := [[Vector2(-20, 6), 12.0], [Vector2(20, 6), 12.0], [Vector2(-10, -8), 14.0], [Vector2(10, -8), 14.0], [Vector2(0, 8), 14.0], [Vector2(0, -20), 12.0]]
			var parts := [ov(base, 28, 6, s, EARTH, 0.0, 2), stk(Vector2(0, 37), Vector2(1, -4), 4.4, s + 1, BIRCH),
				stk(Vector2(1, 6), Vector2(-10, -4), 2.0, s + 2, BIRCH, 2), stk(Vector2(1, 2), Vector2(11, -6), 2.0, s + 3, BIRCH, 2)]
			for i in blobs.size():
				var q: Array = blobs[i]
				parts.append(ov(crown + (q[0] as Vector2), q[1], q[1] * 0.86, s + 4 + i, BIRCH_LEAF.darkened(0.08 * float(i % 2)), 0.0, 1, 0.07))
			sil(ci, parts, rim)
			_broad_det(ci, crown, blobs, s)
			for k in 3:
				var y := 33.0 - float(k) * 7.0
				ln(ci, Vector2(-3.5, y), Vector2(1.0, y - 1.0), 2.0, INK, s + k)
				ln(ci, Vector2(1.5, y - 3.5), Vector2(4.0, y - 4.0), 1.6, INK, s + k + 5)
			_tuft(ci, Vector2(20, 36), s)
		6:
			## 留着斧痕的橡树：一棵树冠圆滚滚的大橡树，树干上砍出一道白生生的斧口，口里卡着一把石斧，地上落着木屑
			var crown := Vector2(0, -30)
			var parts := [ov(base, 38, 6, s, EARTH, 0.0, 2)]
			parts.append_array(_broad_parts(base, 76, 7.0, crown, OAK_BLOBS, s + 1, OAK))
			sil(ci, parts, rim)
			_broad_det(ci, crown, OAK_BLOBS, s)
			var notch := poly([Vector2(8, 16), Vector2(0, 22), Vector2(8, 27)], s + 7, 0.3)
			ci.draw_colored_polygon(notch, FACE)
			outline(ci, notch, 1.6)
			sil(ci, [stk(Vector2(3, 22), Vector2(32, 12), 3.2, s + 12, WOOD),
				pg([Vector2(28, 2), Vector2(40, 7), Vector2(38, 26), Vector2(27, 22)], s + 13, Color("8f8c88"), 1)], false)
			ln(ci, Vector2(39, 8), Vector2(37, 24), 1.8, Color(1, 1, 1, 0.6), s)
			for p in [Vector2(-26, 36), Vector2(-17, 39), Vector2(16, 39), Vector2(24, 36)]:
				var ch := poly([p + Vector2(-3, -1), p + Vector2(2, -2.5), p + Vector2(3, 1), p + Vector2(-2, 2)], s + int(p.x))
				ci.draw_colored_polygon(ch, FACE)
				outline(ci, ch, 1.2)
		7:
			## 大枫树：一棵树冠红黄相间的大枫树，地上落了几片枫叶
			var crown := Vector2(0, -28)
			var maple := Color("e0782e")
			var blobs := [[Vector2(-26, 10), 15.0], [Vector2(26, 10), 15.0], [Vector2(-14, -8), 17.0], [Vector2(15, -8), 17.0], [Vector2(0, 8), 19.0], [Vector2(0, -18), 16.0]]
			var parts := [ov(base, 38, 6, s, EARTH, 0.0, 2)]
			parts.append_array(_broad_parts(base, 72, 6.5, crown, blobs, s + 1, maple))
			for i in blobs.size():
				var q: Array = parts[4 + i]
				q[1] = maple if i % 2 == 0 else Color("d44a2a")
			sil(ci, parts, rim)
			_broad_det(ci, crown, blobs, s)
			for p in [Vector2(-28, 36), Vector2(22, 38), Vector2(30, 34)]:
				var lf := star_pts(p, 4.5, 2.0, 5, s + int(p.x))
				ci.draw_colored_polygon(lf, Color("e0782e"))
				outline(ci, lf, 1.2)
		_:
			## 参天香柏：树干又粗又红，大枝平平地伸出去，托着一层层深绿的叶盘，最贵的香柏木就出在它身上
			_cedar_pads(ci, base, s, rim)
			sil(ci, [ov(Vector2(-16, 35), 7, 3, s + 30, MOSS, 0.0, 2), ov(Vector2(12, 36), 6, 2.5, s + 31, MOSS, 0.0, 2)], false)

# ---------------------------------------------------------------- 主产物：木料

static func _main_art(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	var twig := Color("8a5a34")
	match lv:
		1:
			## 小树枝：一根细细的小枝，带个小分杈和两片叶子
			sil(ci, [stk(Vector2(-24, 32), Vector2(22, -4), 2.6, s, twig, 2), stk(Vector2(-2, 15), Vector2(4, -10), 1.8, s + 1, twig, 2),
				leaf(Vector2(4, -10), 14, 5, -1.2, s + 2), leaf(Vector2(22, -4), 13, 5, -0.5, s + 3)], rim)
			ci.draw_colored_polygon(ell(Vector2(-24, 32), Vector2(2.2, 2.2), s, 0.0, 10), FACE)

		2:
			## 分叉树枝：一根粗一点的 Y 形树枝，断口露着白茬
			sil(ci, [stk(Vector2(-2, 36), Vector2(0, 8), 4.2, s, twig), stk(Vector2(0, 8), Vector2(-22, -20), 3.4, s + 1, twig),
				stk(Vector2(0, 8), Vector2(22, -14), 3.2, s + 2, twig), stk(Vector2(12, -2), Vector2(24, 2), 1.8, s + 3, twig, 2),
				leaf(Vector2(24, 2), 11, 4, 0.3, s + 4)], rim)
			for p in [Vector2(-22, -20), Vector2(22, -14)]:
				ci.draw_circle(p, 2.6, FACE)
			var cut := ell(Vector2(-2, 36), Vector2(4, 2.4), s, 0.0, 10)
			ci.draw_colored_polygon(cut, FACE)
			outline(ci, cut, 1.4)

		3:
			## 一捆树枝：六根树枝拢成一把，中间用草绳扎紧
			var parts := []
			for k in 6:
				var o := float(k) - 2.5
				var a := Vector2(-34.0 + srnd(s + k) * 6.0, 26.0 + o * 4.2)
				var b := Vector2(32.0 - srnd(s + k + 7) * 6.0, -6.0 + o * 4.2)
				parts.append(stk(a, b, 3.0 if k % 2 == 0 else 2.6, s + k, twig if k % 2 == 0 else twig.lightened(0.08)))
			parts.append(stk(Vector2(14, -6), Vector2(24, -18), 1.8, s + 9, twig, 2))
			sil(ci, parts, rim)
			for k in 6:
				var o := float(k) - 2.5
				ci.draw_circle(Vector2(-34.0 + srnd(s + k) * 6.0, 26.0 + o * 4.2), 1.8, FACE)
			rope(ci, Vector2(-34, 26), Vector2(32, -6), 0.5, 3, 15.0, s)

		4:
			## 木杆：一根剥了皮的直木杆，白黄光溜，上面还有几个节疤
			var a := Vector2(-36, 34)
			var b := Vector2(34, -26)
			sil(ci, [stk(a, b, 6.5, s, POLE)], rim)
			var dd := (b - a).normalized()
			var n := dd.orthogonal()
			ln(ci, a + dd * 8.0 - n * 2.5, b - dd * 6.0 - n * 2.5, 1.8, Color(1, 1, 1, 0.45), s)
			for t in [0.3, 0.62]:
				ci.draw_colored_polygon(ell(a.lerp(b, t) + n * 1.0, Vector2(2.6, 1.6), s, 0.0, 10, dd.angle()), WOOD_D)
			var cut := ell(a, Vector2(5.6, 5.6), s, 0.0, 12)
			ci.draw_colored_polygon(cut, FACE)
			outline(ci, cut, 1.4)

		5:
			## 一束木杆：四根木杆捆成一束，两头各扎一道绳
			var parts := []
			var ends := []
			for k in 4:
				var o := (float(k) - 1.5) * 8.0
				var a := Vector2(-38, 30) + Vector2(4, 5).normalized() * o + Vector2(srnd(s + k) * 5.0, 0)
				var b := Vector2(36, -24) + Vector2(4, 5).normalized() * o - Vector2(srnd(s + k + 3) * 5.0, 0)
				parts.append(stk(a, b, 4.4, s + k, POLE if k % 2 == 0 else POLE.darkened(0.06)))
				ends.append(a)
			sil(ci, parts, rim)
			for p in ends:
				var cut := ell(p, Vector2(3.6, 3.6), s, 0.0, 12)
				ci.draw_colored_polygon(cut, FACE)
				outline(ci, cut, 1.2)
			rope(ci, Vector2(-38, 30), Vector2(36, -24), 0.25, 2, 18.0, s)
			rope(ci, Vector2(-38, 30), Vector2(36, -24), 0.8, 2, 18.0, s + 4)

		6:
			## 一块劈柴：一截木头劈下来的一瓣，尖朝下，外头还带着树皮
			var c := Vector2(-14, 30)
			var d := Vector2(30, -14)
			sil(ci, _split_parts(c, 26, d), rim)
			_split_det(ci, c, 26, d, s)

		7:
			## 一抱劈柴：五瓣劈柴码在一起，下三上二
			var d := Vector2(22, -10)
			var cs := [Vector2(-30, 38), Vector2(-8, 38), Vector2(14, 38), Vector2(-19, 20), Vector2(3, 20)]
			var parts := []
			for p in cs:
				parts.append_array(_split_parts(p, 18, d))
			if rim:
				_w_rim(ci, parts)
			for i in cs.size():
				sil(ci, _split_parts(cs[i], 18, d), false)
				_split_det(ci, cs[i], 18, d, s + i * 5)

		8, 9:
			## 细原木 / 原木：一段带树皮的圆木横放着，截面一圈圈年轮；原木更粗，上面留着一截砍掉的枝杈
			var big := lv == 9
			var r := 17.0 if big else 12.0
			var c := Vector2(-26, 26 if big else 28)
			var d := Vector2(56, -16)
			var parts := _log_parts(c, r, d, s)
			var stub_a := c + d * 0.55 + Vector2(0, -r * 0.6)
			var stub_b := c + d * 0.55 + Vector2(4, -r - 10)
			if big:
				parts.insert(0, stk(stub_a, stub_b, 3.4, s + 7, BARK))
			sil(ci, parts, rim)
			_log_det(ci, c, r, d, s, 0.5, 3 if big else 2)
			if big:
				ci.draw_circle(stub_b, 2.4, FACE)

		10:
			## 两根原木：一根靠后一根靠前，并排躺着
			var d := Vector2(50, -14)
			var c1 := Vector2(-16, 12)
			var c2 := Vector2(-28, 30)
			var back := _log_parts(c1, 14, d, s)
			var front := _log_parts(c2, 15, d, s + 5)
			if rim:
				_w_rim(ci, back + front)
			sil(ci, back, false)
			_log_det(ci, c1, 14, d, s)
			sil(ci, front, false)
			_log_det(ci, c2, 15, d, s + 5)

		11:
			## 一垛原木：三根原木码成一垛，下两根上一根，截面冲外
			var d := Vector2(26, -18)
			var r := 15.0
			var cs := [Vector2(-12, -4), Vector2(-28, 22), Vector2(4, 22)]
			var all := []
			for p in cs:
				all.append_array(_log_parts(p, r, d, s, 0.82))
			if rim:
				_w_rim(ci, all)
			for i in 3:
				var p: Vector2 = cs[i]
				sil(ci, _log_parts(p, r, d, s + i * 4, 0.82), false)
				_log_det(ci, p, r, d, s + i * 4, 0.82, 3)

		12:
			## 劈开的半圆木：一根原木顺着纹理一劈两半，平的剖面朝上，露出直直的木纹
			var c := Vector2(-22, 24)
			var r := 18.0
			var d := Vector2(42, -26)
			var rx := r * 0.9
			var face := []
			for k in 11:
				var an := PI * float(k) / 10.0
				face.append(c + Vector2(cos(an) * rx, sin(an) * r))
			var all := PackedVector2Array()
			for p in face:
				all.append(p)
				all.append((p as Vector2) + d)
			var hull := Geometry2D.convex_hull(all)
			hull.remove_at(hull.size() - 1)
			sil(ci, [P(hull, BARK, 1)], rim)
			var flat := poly([c + Vector2(-rx, 0), c + Vector2(rx, 0), c + Vector2(rx, 0) + d, c + Vector2(-rx, 0) + d], s + 1, 0.4)
			ci.draw_colored_polygon(flat, SPLIT.lightened(0.1))
			outline(ci, flat, 1.8)
			for k in 3:
				var t := (float(k) + 1.0) / 4.0
				var p0 := c + Vector2(lerpf(-rx, rx, t), 0)
				pl(ci, [p0 + d * 0.06, p0 + d * 0.4 + Vector2(0, 0.8), p0 + d * 0.7 + Vector2(0, -0.6), p0 + d * 0.96], 1.2, Color(WOOD_D, 0.55), s + k)
			var fp := poly(face, s + 2, 0.4)
			ci.draw_colored_polygon(fp, FACE)
			outline(ci, fp, 2.2)
			for k in 2:
				var f := 0.35 + float(k) * 0.3
				var arr := []
				for j in 9:
					var an := PI * float(j) / 8.0
					arr.append(c + Vector2(cos(an) * rx * f, sin(an) * r * f))
				pl(ci, arr, 1.3, Color(WOOD_D, 0.6), s + k)

		13:
			## 木板：从半圆木上劈削出来的一块厚木板
			_box_rim(ci, [[Vector2(-6, 30), 36.0, 4.0, Vector2(14, -18)]], rim)
			_wbox(ci, Vector2(-6, 30), 36, 4, Vector2(14, -18), s, PLANK.lightened(0.12), 3)

		14:
			## 一摞木板：四块木板交错着摞起来
			var cfg := [[Vector2(-6, 36), 36.0, 4.0, Vector2(14, -16)], [Vector2(-2, 27), 36.0, 4.0, Vector2(14, -16)],
				[Vector2(-8, 18), 36.0, 4.0, Vector2(14, -16)], [Vector2(-3, 9), 36.0, 4.0, Vector2(14, -16)]]
			_box_rim(ci, cfg, rim)
			for i in cfg.size():
				var q: Array = cfg[i]
				_wbox(ci, q[0], q[1], q[2], q[3], s + i * 4, PLANK.lightened(0.12 - 0.05 * float(i % 2)), 2)

		15:
			## 大木梁：一根又长又粗、四面削方的大方木，面上一排石锛刮出的痕
			_box_rim(ci, [[Vector2(-8, 28), 40.0, 11.0, Vector2(12, -14)]], rim)
			_wbox(ci, Vector2(-8, 28), 40, 11, Vector2(12, -14), s, Color("b98048"), 3)
			for k in 5:
				var x := -40.0 + float(k) * 16.0
				ci.draw_arc(Vector2(x, 25), 5.0, 0.3, PI - 0.3, 6, Color(INK, 0.3), 1.3, true)

		_:
			## 香柏巨木：一大截红褐色的香柏，年轮又密又匀，透着香气，是木料里最珍贵的
			var c := Vector2(-22, 20)
			var r := 23.0
			var d := Vector2(52, -16)
			glow(ci, Vector2(2, 10), 56, GOLD)
			sil(ci, _log_parts(c, r, d, s, 0.5, CEDAR, CEDAR_F), rim)
			_log_det(ci, c, r, d, s, 0.5, 4, CEDAR)
			sparks(ci, [Vector2(-40, -18), Vector2(34, -32), Vector2(42, 22)])

# ---------------------------------------------------------------- 副产物：林间收获

## 蜂巢格子：在多边形里铺六边形小格，cap 是封了蜡盖的比例
static func _comb_cells(ci: CanvasItem, region: PackedVector2Array, r: float, s: int, cap: float = 0.3) -> void:
	var bb := bbox(region)
	var dx := r * 1.75
	var dy := r * 1.52
	var row := 0
	var y := bb.position.y + r
	while y < bb.end.y:
		var x := bb.position.x + r + (dx * 0.5 if row % 2 == 1 else 0.0)
		var k := 0
		while x < bb.end.x:
			var p := Vector2(x, y)
			if Geometry2D.is_point_in_polygon(p, region):
				var hex := PackedVector2Array()
				for j in 6:
					var an := PI / 6.0 + TAU * float(j) / 6.0
					hex.append(p + Vector2(cos(an), sin(an)) * r * 0.82)
				var capped := srnd(s + row * 17 + k) < cap
				ci.draw_colored_polygon(hex, COMB.lightened(0.25) if capped else HONEY.darkened(0.12))
				outline(ci, hex, 1.2, Color(COMB.darkened(0.45), 0.9))
				if not capped:
					ci.draw_circle(p + Vector2(-r * 0.2, -r * 0.2), r * 0.18, Color(1, 1, 1, 0.55))
			x += dx
			k += 1
		y += dy
		row += 1

static func _bee(ci: CanvasItem, c: Vector2, sz: float, s: int) -> void:
	ci.draw_colored_polygon(ell(c + Vector2(-sz * 0.2, -sz * 0.9), Vector2(sz * 0.55, sz * 0.38), s, 0.0, 10, -0.5), Color(1, 1, 1, 0.75))
	ci.draw_colored_polygon(ell(c + Vector2(sz * 0.3, -sz * 0.85), Vector2(sz * 0.5, sz * 0.34), s, 0.0, 10, 0.4), Color(1, 1, 1, 0.75))
	var body := ell(c, Vector2(sz * 0.8, sz * 0.55), s, 0.0, 14)
	fill(ci, body, Color("f2c230"), 1.8)
	for k in 2:
		ln(ci, c + Vector2(-sz * 0.15 + float(k) * sz * 0.4, -sz * 0.5), c + Vector2(-sz * 0.15 + float(k) * sz * 0.4, sz * 0.5), 2.0, INK, s + k)
	ci.draw_circle(c + Vector2(-sz * 0.85, 0), sz * 0.32, INK)

## 树皮筒：中空的树皮卷，截面是一圈卷起来的皮
static func _roll_parts(c: Vector2, r: float, d: Vector2, s: int, col: Color) -> Array:
	return _log_parts(c, r, d, s, 0.55, col, col.darkened(0.08))

static func _roll_det(ci: CanvasItem, c: Vector2, r: float, d: Vector2, s: int, inner: Color) -> void:
	var rx := r * 0.55
	var hole := ell(c, Vector2(rx * 0.72, r * 0.72), s, 0.03, 16)
	ci.draw_colored_polygon(hole, Color("3b2314"))
	var sp := []
	for k in 20:
		var t := float(k) / 19.0
		var an := -PI * 0.5 + t * TAU * 1.15
		var f := lerpf(0.7, 0.3, t)
		sp.append(c + Vector2(cos(an) * rx * f, sin(an) * r * f))
	pl(ci, sp, 2.4, inner, s)
	for k in 3:
		var t := -0.5 + float(k) * 0.5
		var a := c + Vector2(rx * 0.95 + 3.0, r * t)
		pl(ci, [a, a + d * 0.45 + Vector2(0, 1.5), a + d * 0.9], 1.2, Color(INK, 0.3), s + k)

static func _resin_blob(c: Vector2, r: float, s: int, drips: int = 2) -> Array:
	var pts := []
	var n := 14
	for k in n:
		var an := TAU * float(k) / float(n)
		var m := 0.86 + srnd(s + k) * 0.22
		var p := Vector2(cos(an) * r * m, sin(an) * r * 0.78 * m)
		if drips > 0 and sin(an) > 0.6 and k % 3 == 0:
			p.y += r * 0.45
		pts.append(c + p)
	return pg(pts, s, RESIN, 1)

static func _resin_det(ci: CanvasItem, c: Vector2, r: float, s: int) -> void:
	hl(ci, c + Vector2(-r * 0.35, -r * 0.35), r * 0.28, r * 0.14, -0.6, 0.75)
	ci.draw_circle(c + Vector2(r * 0.2, -r * 0.45), maxf(r * 0.08, 1.2), Color(1, 1, 1, 0.8))
	ci.draw_arc(c, r * 0.6, 0.3, 1.3, 6, Color(RESIN.darkened(0.25), 0.8), 1.4, true)

static func _sub_art(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			## 一条树皮：剥下来的一长条树皮，外面粗糙，顺着长有几道裂纹，下沿露出浅色的里子，一头翘起来
			var spine := []
			for k in 9:
				var t := float(k) / 8.0
				spine.append(Vector2(lerpf(-34.0, 32.0, t), lerpf(28.0, 6.0, t) - sin(PI * t) * 4.0))
			var up := []
			var dn := []
			var th := []
			for k in 9:
				var p: Vector2 = spine[k]
				var dd: Vector2 = ((spine[mini(k + 1, 8)] as Vector2) - (spine[maxi(k - 1, 0)] as Vector2)).normalized()
				var n := dd.orthogonal()
				var w := 12.0 + srnd(s + k) * 2.0
				up.append(p - n * w)
				dn.append(p + n * w)
				th.append(p + n * (w + 4.0))
			var dr := dn.duplicate()
			dr.reverse()
			var thr := th.duplicate()
			thr.reverse()
			sil(ci, [pg(dn + thr, s + 2, BIRCH_IN, 1), pg(up + dr, s, BARK, 1)], rim)
			for side in [-0.45, 0.1, 0.55]:
				var line := []
				for k in range(1, 8):
					var p: Vector2 = spine[k]
					var dd: Vector2 = ((spine[k + 1] as Vector2) - (spine[k - 1] as Vector2)).normalized()
					line.append(p + dd.orthogonal() * 12.0 * side + Vector2(0, (srnd(s + k + int(side * 10.0)) - 0.5) * 2.0))
				var cut := int(srnd(s + int(side * 7.0)) * 3.0) + 2
				pl(ci, line.slice(0, cut), 1.5, Color(INK, 0.5), s)
				pl(ci, line.slice(cut + 1), 1.5, Color(INK, 0.5), s + 1)
			var curl := poly([up[8], (up[8] as Vector2) + Vector2(4, -7), (dn[8] as Vector2) + Vector2(7, -5), dn[8]], s + 3, 0.4)
			ci.draw_colored_polygon(curl, BIRCH_IN)
			outline(ci, curl, 1.8)
		2:
			## 一卷树皮：一张树皮自己卷成了筒
			var c := Vector2(-20, 24)
			var d := Vector2(40, -14)
			sil(ci, _roll_parts(c, 16, d, s, BARK), rim)
			_roll_det(ci, c, 16, d, s, BIRCH_IN)
		3:
			## 一捆桦树皮：三卷白桦皮码在一起，白底黑斑，用草绳扎着
			var d := Vector2(34, -12)
			var cs := [Vector2(-12, 4), Vector2(-26, 26), Vector2(2, 26)]
			var all := []
			for p in cs:
				all.append_array(_roll_parts(p, 13, d, s, BIRCH))
			if rim:
				_w_rim(ci, all)
			for i in 3:
				var p: Vector2 = cs[i]
				sil(ci, _roll_parts(p, 13, d, s + i * 3, BIRCH), false)
				_roll_det(ci, p, 13, d, s + i * 3, BIRCH_IN)
				for k in 4:
					var q := p + Vector2(10.0 + float(k) * 7.0, -8.0 + srnd(s + i * 7 + k) * 14.0) + d * (float(k) * 0.05)
					ln(ci, q, q + Vector2(4, -1), 1.8, Color(INK, 0.75), s + k)
			rope(ci, Vector2(-26, 10), Vector2(30, -4), 0.62, 2, 22.0, s)
		4:
			## 松脂滴：一片树皮上淌下来一颗亮晶晶的松脂
			var chip := [Vector2(-30, 22), Vector2(-24, -2), Vector2(2, -10), Vector2(26, -4), Vector2(28, 16), Vector2(10, 26), Vector2(-14, 30)]
			var dc := Vector2(12, 26)
			var drop := []
			for k in 15:
				var an := -PI * 0.5 + TAU * float(k) / 15.0
				var r := 10.0 * (1.0 - 0.55 * maxf(-sin(an), 0.0) * maxf(-sin(an), 0.0))
				drop.append(dc + Vector2(cos(an) * r, sin(an) * 10.0 * (1.4 if sin(an) < 0.0 else 1.0)))
			sil(ci, [pg(chip, s, BARK, 1), pg(drop, s + 1, RESIN, 1)], rim)
			for k in 3:
				var y := 2.0 + float(k) * 8.0
				pl(ci, [Vector2(-22, y + 4), Vector2(-6, y), Vector2(10, y - 3)], 1.4, Color(INK, 0.4), s + k)
			_resin_det(ci, dc + Vector2(0, 2), 9, s)
		5:
			## 松脂块：一团凝固的松脂，里面夹着几根松针
			sil(ci, [_resin_blob(Vector2(0, 18), 22, s, 0)], rim)
			for k in 3:
				var p := Vector2(-10.0 + float(k) * 9.0, 14.0 + float(k % 2) * 8.0)
				ln(ci, p, p + Vector2(8, -4).rotated(float(k) * 0.8), 1.4, Color(PINE_D, 0.7), s + k)
			_resin_det(ci, Vector2(0, 18), 22, s)
		6:
			## 一团松脂：好大一坨松脂，往下淌着几道，旁边还滚着两颗小的
			var parts := [_resin_blob(Vector2(-2, 12), 28, s, 2), _resin_blob(Vector2(-30, 34), 7, s + 3, 0), _resin_blob(Vector2(28, 33), 8, s + 4, 0)]
			sil(ci, parts, rim)
			_resin_det(ci, Vector2(-2, 12), 28, s)
			_resin_det(ci, Vector2(28, 33), 8, s + 4)
		7:
			## 小木耳：一小截枯枝上冒出三朵棕褐色的木耳，薄薄的、边上起皱
			var ear := Color("7b4a38")
			var parts := [stk(Vector2(-34, 34), Vector2(32, 28), 5.0, s, BARK)]
			var ears := [[Vector2(-16, 18), 14.0, -0.25], [Vector2(6, 12), 17.0, 0.1], [Vector2(24, 18), 11.0, 0.35]]
			for i in ears.size():
				var e: Array = ears[i]
				var r: float = e[1]
				var rel := []
				for k in 16:
					var an := TAU * float(k) / 16.0
					var m := 1.0 + (0.12 if k % 2 == 0 else -0.05)
					rel.append(Vector2(cos(an) * r * m, sin(an) * r * 0.72 * m))
				parts.append(pg(rot_pts(rel, e[2], e[0]), s + i + 1, ear, 0))
			sil(ci, parts, rim)
			for i in ears.size():
				var e: Array = ears[i]
				var c: Vector2 = e[0]
				var r: float = e[1]
				pl(ci, rot_pts(arcp(Vector2.ZERO, Vector2(r * 0.5, r * 0.32), 0.3, PI - 0.3, 8), e[2], c + Vector2(0, -r * 0.1)), 1.6, Color(INK, 0.45), s + i)
				pl(ci, rot_pts(arcp(Vector2.ZERO, Vector2(r * 0.75, r * 0.5), PI + 0.5, TAU - 0.5, 8), e[2], c), 1.6, Color(1, 1, 1, 0.3), s + i + 3)
		8:
			## 一簇树菇：一截竖着的老木桩，侧面一层层长出半圆的树舌
			var top := Vector2(-4, -6)
			var parts := []
			parts.append_array(_log_up(top, 20, 40, s, BARK))
			var sh := [[Vector2(16, 26), 18.0], [Vector2(18, 10), 14.0], [Vector2(-24, 20), 13.0], [Vector2(14, -4), 10.0]]
			for i in sh.size():
				var q: Array = sh[i]
				var c: Vector2 = q[0]
				var r: float = q[1]
				var sgn := 1.0 if c.x > 0 else -1.0
				var pts := [c + Vector2(-sgn * r * 0.3, 2)]
				for k in 9:
					var an := lerpf(-PI * 0.5, PI * 0.5, float(k) / 8.0)
					pts.append(c + Vector2(sgn * cos(an) * r, sin(an) * r * 0.42 - r * 0.1))
				parts.append(pg(pts, s + 3 + i, SHELF, 1))
			sil(ci, parts, rim)
			rings(ci, top, Vector2(20, 20 * 0.32), s, 2)
			for i in sh.size():
				var q: Array = sh[i]
				var c: Vector2 = q[0]
				var r: float = q[1]
				var sgn := 1.0 if c.x > 0 else -1.0
				ln(ci, c + Vector2(-sgn * r * 0.1, r * 0.28), c + Vector2(sgn * r * 0.9, r * 0.22), 1.8, Color(BONE, 0.9), s + i)
				ln(ci, c + Vector2(sgn * r * 0.1, -r * 0.05), c + Vector2(sgn * r * 0.7, -r * 0.05), 1.2, Color(WOOD_D, 0.6), s + i + 3)
		9:
			## 大灵芝：一朵油亮的红褐色大灵芝，伞面一圈圈环纹，边缘一道黄白色，旁边一朵小的
			var stem := Color("6e2c1a")
			var parts := [stk(Vector2(4, 38), Vector2(2, 18), 4.0, s, stem),
				ov(Vector2(-22, 26), 12, 7, s + 1, LINGZHI, -0.2, 1), stk(Vector2(-20, 38), Vector2(-21, 30), 2.4, s + 2, stem, 2)]
			var cap := []
			for k in 16:
				var an := PI + PI * float(k) / 15.0
				cap.append(Vector2(4, 14) + Vector2(cos(an) * 34.0, sin(an) * 22.0))
			cap.append(Vector2(30, 18))
			cap.append(Vector2(10, 20))
			cap.append(Vector2(-6, 16))
			cap.append(Vector2(-28, 18))
			parts.append(pg(cap, s + 3, LINGZHI, 0))
			sil(ci, parts, rim)
			for k in 3:
				var f := 0.35 + float(k) * 0.22
				pl(ci, arcp(Vector2(4, 14), Vector2(34.0 * f, 22.0 * f), PI + 0.15, TAU - 0.15, 12), 1.6, Color(Color("4a1a10"), 0.6), s + k)
			pl(ci, arcp(Vector2(4, 15), Vector2(33, 21), PI + 0.05, TAU - 0.05, 16), 3.2, Color("f2d58a"), s)
			hl(ci, Vector2(-8, -2), 9, 3.5, -0.3, 0.55)
			ci.draw_arc(Vector2(-22, 25), 9.0, PI + 0.3, TAU - 0.3, 8, Color("f2d58a"), 2.0, true)
		10:
			## 一小块蜂巢：掰下来的一小块蜂巢，格子里汪着蜜
			var pts := poly([Vector2(-24, 34), Vector2(-28, 8), Vector2(-12, -6), Vector2(14, -4), Vector2(26, 12), Vector2(22, 34)], s, 0.5)
			sil(ci, [P(pts, COMB, 2)], rim)
			_comb_cells(ci, pts, 5.6, s, 0.25)
		11:
			## 蜂巢：一大块蜂巢，上半封着蜡盖，下边往外淌蜜，一只蜜蜂趴在上面
			var pts := poly([Vector2(-34, 30), Vector2(-36, 0), Vector2(-20, -18), Vector2(14, -20), Vector2(34, -4), Vector2(34, 28), Vector2(0, 34)], s, 0.5)
			var drip := pg([Vector2(-8, 30), Vector2(-4, 30), Vector2(-4, 40), Vector2(-6, 43), Vector2(-8, 40)], s + 1, HONEY, 2)
			sil(ci, [P(pts, COMB, 2), drip], rim)
			_comb_cells(ci, pts, 6.0, s, 0.45)
			_bee(ci, Vector2(18, -18), 7.0, s)
		_:
			## 滴蜜的大蜂巢：一整块挂在枯枝上的大蜂巢，金黄的蜜顺着往下滴，两只蜜蜂围着飞
			glow(ci, Vector2(0, 8), 56, GOLD)
			var br := stk(Vector2(-40, -30), Vector2(40, -34), 4.0, s, BARK)
			var pts := poly([Vector2(-32, -30), Vector2(30, -32), Vector2(38, -6), Vector2(32, 22), Vector2(10, 36), Vector2(-14, 34), Vector2(-34, 16), Vector2(-38, -10)], s + 1, 0.5)
			var drips := [pg([Vector2(-6, 34), Vector2(0, 34), Vector2(0, 42), Vector2(-3, 46), Vector2(-6, 42)], s + 2, HONEY, 2),
				pg([Vector2(16, 30), Vector2(20, 28), Vector2(20, 36), Vector2(18, 38), Vector2(16, 36)], s + 3, HONEY, 2)]
			sil(ci, [br, P(pts, COMB, 2)] + drips, rim)
			_comb_cells(ci, pts, 6.4, s, 0.4)
			_bee(ci, Vector2(-40, 10), 7.0, s)
			_bee(ci, Vector2(42, 8), 6.5, s + 3)
			sparks(ci, [Vector2(-42, -40), Vector2(40, -44)])
