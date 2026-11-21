class_name PAHunt
extends PA
## 狩猎线：狩猎陷阱 / 走兽 / 飞禽（麻雀、乌鸦、野鸡、野鸭、大雁、秃鹫、老鹰、鸵鸟）。每只猎物按自己的样子摆死亡姿势：倒挂、蜷着、仰翻、跪倒、趴倒……

const MOUSE := Color("9a9590")
const FROG := Color("6dbb4a")
const LIZ := Color("8fb04a")
const HARE := Color("c8a27a")
const HEDGE := Color("a07a58")
const FOX := Color("e07a2a")
const BADG := Color("7a7570")
const BOAR := Color("7a5236")
const GOAT := Color("e8dcc4")
const DEER := Color("b8783e")
const WOLF := Color("8e8c94")
const BISON := Color("5e3a22")
const BEAR := Color("6e4428")
const TIGER := Color("e89a3a")
const RHINO := Color("8a6a4a")
const MAMMOTH := Color("7a4e2e")

## 每级的整体缩放（以脚下地面为支点），让一条链从小到大
const GEN_SCALE := [1.0, 0.94, 1.0, 0.9, 1.03, 1.08, 0.92, 0.98, 1.1]
const MAIN_SCALE := [0.8, 0.74, 0.87, 0.94, 0.88, 0.95, 0.92, 0.95, 1.0, 1.0]
const SUB_SCALE := [0.75, 0.9, 0.85, 0.97, 0.95, 0.85, 1.04, 0.98]

static func _grow(ci: CanvasItem, k: float) -> Transform2D:
	var keep := xf
	xf = keep * Transform2D(0.0, Vector2(k, k), 0.0, Vector2(0, 38) * (1.0 - k))
	ci.draw_set_transform_matrix(xf)
	return keep

static func _ungrow(ci: CanvasItem, keep: Transform2D) -> void:
	xf = keep
	ci.draw_set_transform_matrix(xf)

## 生产器：1~3 级只是做陷阱的材料、还没搭好（不能狩猎），4 级起是能用的陷阱，5 级篮筐陷阱开始抓麻雀
static func gen(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	var keep := _grow(ci, GEN_SCALE[clampi(lv, 1, 9) - 1])
	var dirt := Color("7a4f2a")
	match lv:
		1:
			## 一捆树枝：几根木棍，中间用草绳扎住，一头还带着片叶子
			var parts := [ov(Vector2(0, 34), 28, 4, s, dirt, 0.0, 1)]
			var d := Vector2(46, -22).normalized()
			var nrm := d.orthogonal()
			for k in 4:
				var o := nrm * (float(k) - 1.5) * 4.6
				parts.append(stk(Vector2(-22, 28) + o, Vector2(20, 8) + o + d * float(k % 2) * 3.0, 2.4, s + 1 + k, WOOD if k % 2 == 0 else WOOD.darkened(0.12), 2))
			parts.append(leaf(Vector2(20, 8) + nrm * -5.0, 11, 4, -0.9, s + 6))
			parts.append(stk(Vector2(-1, 18) - nrm * 11.0, Vector2(-1, 18) + nrm * 11.0, 3.4, s + 7, ROPE))
			sil(ci, parts, rim)
			ln(ci, Vector2(-1, 18) - nrm * 9.0 + d * 1.5, Vector2(-1, 18) + nrm * 9.0 + d * 1.5, 1.2, Color(INK, 0.4), s)
		2:
			## 尖木桩：三根削尖的木桩摞在地上，一根草绳松松地搭在上面
			var parts := [ov(Vector2(0, 35), 38, 5, s, dirt, 0.0, 1)]
			var stakes := [[Vector2(-34, 30), Vector2(18, 24)], [Vector2(-30, 21), Vector2(20, 13)], [Vector2(-24, 12), Vector2(14, 1)]]
			for k in stakes.size():
				var a: Vector2 = stakes[k][0]
				var b: Vector2 = stakes[k][1]
				var dd := (b - a).normalized()
				var nn := dd.orthogonal()
				parts.append(pg([a + nn * 3.2, b + nn * 3.2, b + dd * 14.0, b - nn * 3.2, a - nn * 3.2], s + 1 + k, WOOD.darkened(0.06 * float(k)), 1))
			for r in [[Vector2(-38, 31), 7.5], [Vector2(32, 31), 8.5], [Vector2(22, 35), 5.5], [Vector2(-26, 35), 5.0]]:
				parts.append(raw_rock(r[0], r[1], s + 20 + int(r[1]), STONE if int(r[1]) % 2 == 0 else STONE.darkened(0.08), 7, 0.22))
			sil(ci, parts, rim)
			for k in stakes.size():
				var a: Vector2 = stakes[k][0]
				var b: Vector2 = stakes[k][1]
				var dd := (b - a).normalized()
				var nn := dd.orthogonal()
				var tipp := poly([b + nn * 3.0, b + dd * 13.0, b - nn * 3.0], s + 9 + k, 0.3)
				safe_poly(ci, tipp, Color("ecd09a"))
				outline(ci, tipp, 1.4)
				ln(ci, b + nn * 1.5 + dd * 2.0, b + dd * 9.0, 1.0, Color(INK, 0.35), s + k)
			var rope_pts := [Vector2(-14, 36), Vector2(-12, 26), Vector2(-8, 18), Vector2(-10, 8), Vector2(-4, 2), Vector2(4, 6), Vector2(2, 16), Vector2(8, 26), Vector2(14, 34)]
			pl(ci, rope_pts, 4.6, INK, s)
			pl(ci, rope_pts, 2.6, ROPE, s)
		3:
			## 没搭好的落石陷阱：石板平放在地上，做「4 字形」机关的三根木棍还散在一边，没放诱饵
			var parts := [ov(Vector2(0, 36), 44, 5, s, dirt, 0.0, 1)]
			parts.append(pg([Vector2(-44, 30), Vector2(-38, 20), Vector2(8, 12), Vector2(20, 16), Vector2(16, 28), Vector2(-34, 36)], s + 1, STONE, 1))
			parts.append(stk(Vector2(14, 34), Vector2(42, 28), 2.6, s + 2, WOOD, 2))
			parts.append(stk(Vector2(22, 24), Vector2(44, 12), 2.4, s + 3, WOOD.darkened(0.1), 2))
			parts.append(stk(Vector2(26, 36), Vector2(36, 6), 2.4, s + 4, WOOD, 2))
			sil(ci, parts, rim)
			ln(ci, Vector2(-36, 21), Vector2(10, 14), 2.0, Color(1, 1, 1, 0.35), s)
			for k in 3:
				ln(ci, Vector2(-30.0 + float(k) * 14.0, 28.0 - float(k) * 3.0), Vector2(-24.0 + float(k) * 14.0, 26.0 - float(k) * 3.0), 1.6, Color(INK, 0.3), s + k)
		4: trap_old(ci, 1, s, rim)
		5: _basket_trap(ci, s, rim)
		6: trap_old(ci, 4, s, rim)
		7: trap_old(ci, 5, s, rim)
		8: trap_old(ci, 7, s, rim)
		_: trap_old(ci, 8, s, rim)
	_ungrow(ci, keep)

## 篮筐支棍陷阱：倒扣的草篮一边用木棍支起来，棍上拴着长绳，篮下撒着谷粒，一只麻雀正跳进去啄食——一拉绳就扣住
static func _basket_trap(ci: CanvasItem, s: int, rim: bool) -> void:
	var dirt := Color("7a4f2a")
	var lo := Vector2(-46, 33)
	var hi := Vector2(14, 0)
	var straw := Color("d9b264")
	var weave_c := Color("8e6428")
	var m := (lo + hi) * 0.5
	var half := (hi - lo).length() * 0.5
	var a := (hi - lo).angle()
	var dome := []
	for k in 17:
		var t := PI * float(k) / 16.0
		dome.append(m + Vector2(cos(t) * half, -sin(t) * 27.0).rotated(a))
	var inner := ell(m, Vector2(half, 8.0), s + 1, 0.02, 20, a)
	sil(ci, [ov(Vector2(0, 36), 46, 5, s, dirt, 0.0, 1), stk(Vector2(13, 2), Vector2(17, 36), 2.8, s + 2, WOOD, 2),
		P(inner, Color("4a3018"), 2), pg(dome, s + 3, straw, 1)], rim)
	## 草篮的编织纹：顺着篮身的几道弧 + 几根竖筋
	for r in [0.35, 0.6, 0.82]:
		var arc := []
		for k in 13:
			var t := PI * (0.06 + 0.88 * float(k) / 12.0)
			arc.append(m + Vector2(cos(t) * half * (0.35 + r * 0.65), -sin(t) * 27.0 * r).rotated(a))
		pl(ci, arc, 1.6, Color(weave_c, 0.85), s + int(r * 10.0))
	for k in 9:
		var t := PI * (0.1 + 0.8 * float(k) / 8.0)
		ln(ci, m + Vector2(cos(t) * half * 0.98, 0).rotated(a), m + Vector2(cos(t) * half * 0.9, -sin(t) * 25.5).rotated(a), 1.4, Color(weave_c, 0.75), s + k)
	pl(ci, [lo, m + Vector2(-half * 0.5, 2).rotated(a), m + Vector2(half * 0.5, 2).rotated(a), hi], 3.0, weave_c, s)
	## 篮子底下一小堆白米当诱饵，堆在支起来的那一边，看得见
	var heap := []
	for k in 13:
		var ang := PI + PI * float(k) / 12.0
		heap.append(Vector2(2, 34) + Vector2(cos(ang) * 16.0, sin(ang) * 10.0 * (1.0 + 0.08 * sin(ang * 5.0))))
	var hp := poly(heap, s + 40, 0.5)
	safe_poly(ci, hp, Color("f6efdc"))
	outline(ci, hp, 1.8)
	for g in [Vector2(-6, 30), Vector2(0, 28), Vector2(6, 30), Vector2(-2, 32.5), Vector2(4, 26), Vector2(10, 32.5), Vector2(-9, 33)]:
		ln(ci, g + Vector2(-1.6, 0.6), g + Vector2(1.6, -0.6), 1.2, Color(INK, 0.25), s + int(g.x))
	for g in [Vector2(22, 35.5), Vector2(27, 35)]:
		safe_poly(ci, ell(g, Vector2(2.6, 1.5), s + int(g.x), 0.0, 8, 0.4), Color("f6efdc"))
	hl(ci, Vector2(-3, 27), 4, 1.6, -0.2, 0.6)
	## 拴在支棍上的拉绳，沿着地面拖到右边
	var rope_pts := [Vector2(15, 12), Vector2(24, 20), Vector2(32, 31), Vector2(42, 35), Vector2(52, 33)]
	pl(ci, rope_pts, 4.0, INK, s)
	pl(ci, rope_pts, 2.2, ROPE, s)

static func main(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	var keep := _grow(ci, MAIN_SCALE[clampi(lv, 1, 10) - 1])
	_main_art(ci, lv, s, rim)
	_ungrow(ci, keep)

static func sub(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	var keep := _grow(ci, SUB_SCALE[clampi(lv, 1, 8) - 1])
	_sub_art(ci, lv, s, rim)
	_ungrow(ci, keep)

## 旧的生产器画法：1 落石陷阱 / 2 绳套 / 3 木夹子 / 4 尖桩陷阱 / 5 陷阱牢笼 / 6 武器架 / 7 猎人营帐 / 8 猛犸狩猎屋。
## 新 gen() 的 4~8 级借用其中 1、4、5、7、8；绳套、木夹子、武器架留着给以后别的物品用。
static func trap_old(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	var dirt := Color("7a4f2a")
	match lv:
		1:
			## 落石陷阱：一块大石板斜架在「4 字形」木棍上，底下放着诱饵莓果，一碰就砸下来
			var parts := [ov(Vector2(0, 36), 44, 5, s, dirt, 0.0, 1)]
			parts.append(stk(Vector2(18, 36), Vector2(18, -4), 2.8, s + 1, WOOD, 2))
			parts.append(stk(Vector2(-6, 24), Vector2(26, 20), 2.4, s + 2, WOOD.darkened(0.1), 2))
			parts.append(stk(Vector2(6, 4), Vector2(34, -14), 2.4, s + 3, WOOD, 2))
			var bait := [Vector2(2, 30), Vector2(10, 30), Vector2(6, 24)]
			for k in 3:
				parts.append(circ(bait[k], 4.6, s + 4 + k, BERRY, 2))
			parts.append(leaf(Vector2(6, 22), 9, 3, -1.2, s + 8))
			parts.append(pg([Vector2(-46, 28), Vector2(-40, 20), Vector2(24, -32), Vector2(36, -30), Vector2(34, -18), Vector2(-36, 36)], s + 10, STONE, 1))
			sil(ci, parts, rim)
			for k in 3:
				var x := -26.0 + float(k) * 20.0
				ln(ci, Vector2(x - 6, 24.0 - float(k) * 16.0), Vector2(x + 2, 20.0 - float(k) * 16.0), 1.6, Color(INK, 0.3), s + k)
			ln(ci, Vector2(-38, 21), Vector2(26, -29), 2.0, Color(1, 1, 1, 0.35), s)
			for b in bait:
				ci.draw_circle((b as Vector2) + Vector2(-1.5, -1.5), 1.3, Color(1, 1, 1, 0.6))
		2:
			## 绳套：把一棵小树拉弯，树梢垂下绳套，地上钉着扳机木桩
			var parts := [ov(Vector2(0, 36), 42, 5, s, dirt, 0.0, 1)]
			var tr := [Vector2(-30, 36), Vector2(-30, 4), Vector2(-20, -24), Vector2(4, -36), Vector2(22, -30)]
			for i in 4:
				parts.append(stk(tr[i], tr[i + 1], 4.4 - float(i) * 0.7, s + 1 + i, WOOD_D, 2))
			parts.append(leaf(Vector2(20, -30), 14, 5, -0.5, s + 6))
			parts.append(leaf(Vector2(20, -30), 12, 4.5, 0.6, s + 7, LEAF_D))
			parts.append(leaf(Vector2(4, -36), 12, 4.5, -1.6, s + 8))
			parts.append(stk(Vector2(20, -28), Vector2(14, 8), 1.6, s + 9, ROPE, 2))
			parts.append(stk(Vector2(26, 38), Vector2(26, 10), 2.8, s + 10, WOOD, 2))
			parts.append(stk(Vector2(18, 12), Vector2(32, 12), 2.2, s + 11, WOOD, 2))
			sil(ci, parts, rim)
			ci.draw_arc(Vector2(10, 24), 15, 0, TAU, 28, INK, 4.6, true)
			ci.draw_arc(Vector2(10, 24), 15, 0, TAU, 28, ROPE, 2.6, true)
			ci.draw_circle(Vector2(14, 9), 3.2, ROPE.darkened(0.2))
			ln(ci, Vector2(-30, 10), Vector2(-26, 22), 1.4, Color(INK, 0.3), s)
		3:
			## 木夹子：两块削出尖齿的木板，底下用绳子绑成活页，张开成 V 字，中间放一块肉当诱饵
			var parts := [ov(Vector2(0, 36), 44, 5, s, dirt, 0.0, 1), bx(-38, 26, 76, 9, 3, s + 1, WOOD_D)]
			parts.append(pg([Vector2(-8, 22), Vector2(6, 16), Vector2(10, 26), Vector2(-6, 28)], s + 2, MEAT, 1))
			var teeth := []
			for sd in [-1.0, 1.0]:
				var h: Vector2 = Vector2(sd * 3.0, 28)
				var d: Vector2 = Vector2(sd * 0.62, -0.78)
				var n: Vector2 = Vector2(-d.y, d.x) * (-sd)
				var e := h + d * 50.0
				parts.append(pg([h - n * 6.0, e - n * 6.0, e + n * 6.0, h + n * 6.0], s + 3 + int(sd), WOOD if sd < 0.0 else WOOD.darkened(0.06), 1))
				for k in 5:
					var q: Vector2 = h + d * (14.0 + float(k) * 8.0) + n * 5.0
					teeth.append(pg([q - d * 3.2, q + n * 8.0, q + d * 3.2], s + 10 + k + int(sd) * 5, BONE2, 2))
			sil(ci, parts + teeth, rim)
			for sd in [-1.0, 1.0]:
				var h: Vector2 = Vector2(sd * 3.0, 28)
				var d: Vector2 = Vector2(sd * 0.62, -0.78)
				ln(ci, h + d * 20.0, h + d * 44.0, 1.4, Color(INK, 0.3), s)
			for k in 3:
				ln(ci, Vector2(-8.0 + float(k) * 8.0, 25), Vector2(-5.0 + float(k) * 8.0, 34), 2.0, ROPE, s + k)
			hl(ci, Vector2(-1, 20), 3, 2, -0.3, 0.5)
		4:
			## 尖桩陷阱：地上挖的深坑，坑底竖着削尖的木桩，一半已经用树枝树叶盖住
			var parts := [ov(Vector2(0, 18), 46, 20, s, Color("6a4428"), 0.0, 1)]
			sil(ci, parts, rim)
			ci.draw_colored_polygon(ell(Vector2(0, 20), Vector2(37, 13), s, 0.04, 18), Color("2a170c"))
			var stakes := []
			for k in 5:
				var x := -4.0 + float(k) * 8.0
				var top := -4.0 - float(k % 2) * 8.0
				stakes.append(pg([Vector2(x - 3.5, 28), Vector2(x, top), Vector2(x + 3.5, 28)], s + 2 + k, WOOD))
			sil(ci, stakes, false)
			for k in 5:
				var x := -4.0 + float(k) * 8.0
				var top := -4.0 - float(k % 2) * 8.0
				ci.draw_colored_polygon(poly([Vector2(x - 1.4, top + 6), Vector2(x, top + 1), Vector2(x + 1.4, top + 6)], s + k), BONE2)
			var cover := [stk(Vector2(-44, 12), Vector2(-2, 30), 2.6, s + 10, WOOD_D, 2), stk(Vector2(-40, 26), Vector2(-4, 6), 2.6, s + 11, WOOD_D, 2)]
			for k in 5:
				var a := -0.6 + float(k) * 0.5
				cover.append(leaf(Vector2(-24, 18), 16, 6, PI + a, s + 12 + k, LEAF if k % 2 == 0 else LEAF_D.lightened(0.1)))
			cover.append(leaf(Vector2(-14, 20), 14, 5, -0.4, s + 20, LEAF))
			sil(ci, cover, false)
			for k in 3:
				vein(ci, Vector2(-24, 18), 16, PI - 0.6 + float(k) * 1.0, s + k)
		5:
			## 陷阱牢笼：木条绑成的笼子，门板用绳子吊在上面，里面放一块肉
			var parts := [ov(Vector2(0, 36), 42, 5, s, dirt, 0.0, 1)]
			parts.append(bx(-30, -14, 60, 48, 3, s + 1, Color("6a4a30"), 2))
			for x in [-30.0, -20.0, 20.0, 30.0]:
				parts.append(stk(Vector2(x, -18), Vector2(x, 36), 2.6, s + 2 + int(x), WOOD, 2))
			parts.append(stk(Vector2(-36, -16), Vector2(36, -16), 3.0, s + 10, WOOD_D, 2))
			parts.append(stk(Vector2(-34, 34), Vector2(34, 34), 3.0, s + 11, WOOD_D, 2))
			parts.append(stk(Vector2(0, -16), Vector2(0, -26), 1.6, s + 12, ROPE, 2))
			parts.append(bx(-15, -44, 30, 18, 2, s + 13, WOOD.darkened(0.05)))
			parts.append(pg([Vector2(-14, 16), Vector2(6, 10), Vector2(14, 24), Vector2(-6, 32)], s + 14, MEAT, 1))
			parts.append(stk(Vector2(10, 18), Vector2(20, 12), 2.6, s + 15, BONE, 2))
			for x in [-10.0, 0.0, 10.0]:
				parts.append(stk(Vector2(x, -14), Vector2(x, 4), 2.0, s + 16 + int(x), WOOD.darkened(0.1), 2))
			sil(ci, parts, rim)
			for k in 3:
				var x := -10.0 + float(k) * 10.0
				ln(ci, Vector2(x, -43), Vector2(x, -27), 1.6, Color(INK, 0.4), s + k)
			for x in [-30.0, -20.0, 20.0, 30.0]:
				ln(ci, Vector2(x - 3, -15), Vector2(x + 3, -17), 1.6, ROPE, s)
				ln(ci, Vector2(x - 3, 33), Vector2(x + 3, 35), 1.6, ROPE, s + 1)
			hl(ci, Vector2(-4, 18), 4, 2.5, -0.3, 0.5)
			ci.draw_colored_polygon(ell(Vector2(0, -8), Vector2(26, 5), s, 0.0, 12), Color(0, 0, 0, 0.18))
		6:
			## 武器架：两根带杈的木桩架着横杆，上面靠着三支石矛、一根石头大棒，横杆上挂一把石斧
			var parts := [ov(Vector2(0, 37), 44, 4, s, dirt, 0.0, 1)]
			var sp := [[Vector2(-22, 36), Vector2(-14, -34)], [Vector2(-8, 36), Vector2(-2, -38)], [Vector2(6, 36), Vector2(10, -34)]]
			for i in 3:
				var a0: Vector2 = sp[i][0]
				var a1: Vector2 = sp[i][1]
				var d := (a1 - a0).normalized()
				parts.append(stk(a0, a1, 2.2, s + 1 + i, WOOD, 2))
				var n := Vector2(-d.y, d.x)
				parts.append(pg([a1 - d * 2.0 + n * 4.5, a1 + d * 12.0, a1 - d * 2.0 - n * 4.5], s + 5 + i, STONE, 2))
			parts.append(stk(Vector2(24, 36), Vector2(20, -8), 3.0, s + 9, WOOD_D, 2))
			parts.append(ov(Vector2(19, -12), 7, 9, s + 10, STONE_D, -0.15, 1))
			for sd in [-1.0, 1.0]:
				parts.append(stk(Vector2(sd * 34.0, 36), Vector2(sd * 34.0, -14), 3.2, s + 11, WOOD_D, 2))
				parts.append(stk(Vector2(sd * 34.0, -12), Vector2(sd * 40.0, -22), 2.2, s + 12, WOOD_D, 2))
				parts.append(stk(Vector2(sd * 34.0, -12), Vector2(sd * 28.0, -22), 2.2, s + 13, WOOD_D, 2))
			parts.append(stk(Vector2(-40, -16), Vector2(40, -16), 2.8, s + 14, WOOD, 2))
			parts.append(stk(Vector2(-36, 20), Vector2(36, 20), 2.4, s + 15, WOOD.darkened(0.08), 2))
			parts.append(stk(Vector2(30, -14), Vector2(30, 0), 1.4, s + 16, ROPE, 2))
			parts.append(stk(Vector2(26, 0), Vector2(40, 8), 2.2, s + 17, WOOD, 2))
			parts.append(pg([Vector2(24, -4), Vector2(32, -2), Vector2(30, 10), Vector2(22, 6)], s + 18, STONE.darkened(0.08), 2))
			sil(ci, parts, rim)
			for i in 3:
				var a1: Vector2 = sp[i][1]
				ln(ci, a1 + Vector2(-1.5, 2), a1 + Vector2(1.5, -2), 1.6, ROPE, s + i)
			for k in 3:
				ci.draw_circle(Vector2(17.0 + float(k % 2) * 4.0, -16.0 + float(k) * 4.0), 1.4, Color(INK, 0.4))
			for sd in [-1.0, 1.0]:
				ln(ci, Vector2(sd * 34.0 - 3.0, -17), Vector2(sd * 34.0 + 3.0, -15), 1.6, ROPE, s)
				ln(ci, Vector2(sd * 34.0 - 3.0, 19), Vector2(sd * 34.0 + 3.0, 21), 1.6, ROPE, s + 1)
		7:
			## 猎人营帐：一顶兽皮小帐篷，旁边的木架上绷着一张晾晒的兽皮
			var parts := [ov(Vector2(0, 37), 46, 4, s, dirt, 0.0, 1)]
			parts.append(stk(Vector2(-22, -30), Vector2(-14, -40), 2.0, s + 1, WOOD_D, 2))
			parts.append(stk(Vector2(-22, -30), Vector2(-30, -40), 2.0, s + 2, WOOD_D, 2))
			parts.append(pg([Vector2(-46, 36), Vector2(-22, -30), Vector2(2, 36)], s + 3, Color("c99a68"), 1))
			parts.append(pg([Vector2(-28, 36), Vector2(-22, 10), Vector2(-16, 36)], s + 4, Color("3a2416")))
			parts.append(stk(Vector2(12, 36), Vector2(13, -18), 2.6, s + 5, WOOD, 2))
			parts.append(stk(Vector2(44, 36), Vector2(43, -18), 2.6, s + 6, WOOD, 2))
			parts.append(stk(Vector2(8, -14), Vector2(48, -14), 2.6, s + 7, WOOD_D, 2))
			parts.append(stk(Vector2(10, 28), Vector2(46, 28), 2.2, s + 8, WOOD_D, 2))
			var hide := [Vector2(16, -10), Vector2(22, -6), Vector2(34, -6), Vector2(40, -10), Vector2(38, 2), Vector2(42, 12), Vector2(38, 24),
				Vector2(32, 18), Vector2(24, 18), Vector2(18, 24), Vector2(14, 12), Vector2(18, 2)]
			parts.append(pg(hide, s + 9, Color("b07444"), 1))
			sil(ci, parts, rim)
			for k in 3:
				ln(ci, Vector2(-22, -30), Vector2(-40.0 + float(k) * 18.0, 34), 1.4, Color(INK, 0.3), s + k)
			pl(ci, [Vector2(-38, 22), Vector2(-32, 14), Vector2(-26, 22)], 2.0, CLAY, s)
			pl(ci, [Vector2(-16, 22), Vector2(-10, 14), Vector2(-4, 22)], 2.0, CLAY, s + 1)
			for p in [[Vector2(16, -10), Vector2(13, -14)], [Vector2(40, -10), Vector2(43, -14)], [Vector2(18, 24), Vector2(13, 28)], [Vector2(38, 24), Vector2(43, 28)], [Vector2(14, 12), Vector2(12, 12)], [Vector2(42, 12), Vector2(44, 12)]]:
				ln(ci, p[0], p[1], 1.4, ROPE, s)
			ci.draw_colored_polygon(ell(Vector2(28, 8), Vector2(7, 8), s, 0.0, 12), Color("d8a868", 0.6))
		_:
			## 猛犸狩猎屋：兽皮盖的圆顶屋，门口两根猛犸大牙交叉成拱门，屋顶架着猛犸头骨，墙脚一圈下颌骨，屋里亮着火
			glow(ci, Vector2(0, -2), 54, GOLD)
			var parts := [pg(arcp(Vector2(0, 38), Vector2(44, 56), PI, TAU, 18), s, Color("a8845a"), 1)]
			for k in 7:
				var x := -36.0 + float(k) * 12.0
				parts.append(ov(Vector2(x, 33), 7, 5, s + 1 + k, BONE2, 0.0, 1))
			parts.append(pg([Vector2(-12, 38), Vector2(-10, 4), Vector2(10, 4), Vector2(12, 38)], s + 10, Color("3a2416")))
			parts.append(band(Vector2(16, 38), 30, 3.8, PI * 1.02, PI * 1.5, s + 11, BONE))
			parts.append(band(Vector2(-16, 38), 30, 3.8, PI * 1.5, PI * 1.98, s + 12, BONE))
			parts.append(ov(Vector2(0, -20), 14, 10, s + 13, BONE))
			parts.append(band(Vector2(-14, -12), 10, 2.6, PI * 0.2, PI * 1.0, s + 14, BONE2))
			parts.append(band(Vector2(14, -12), 10, 2.6, 0.0, PI * 0.8, s + 15, BONE2))
			sil(ci, parts, rim)
			for k in 5:
				var a := lerpf(PI * 1.12, PI * 1.88, float(k) / 4.0)
				ln(ci, Vector2(0, 38) + Vector2(cos(a) * 30.0, sin(a) * 38.0), Vector2(0, 38) + Vector2(cos(a) * 42.0, sin(a) * 53.0), 2.0, Color(INK, 0.3), s + k)
			ci.draw_circle(Vector2(-5, -21), 3.2, INK)
			ci.draw_circle(Vector2(5, -21), 3.2, INK)
			ci.draw_colored_polygon(ell(Vector2(0, -12), Vector2(3, 4), s, 0.0, 8), Color(INK, 0.6))
			ci.draw_colored_polygon(ell(Vector2(0, 30), Vector2(7, 7), s, 0.1, 10), FIRE)
			ci.draw_colored_polygon(ell(Vector2(0, 32), Vector2(3.5, 4), s + 1, 0.1, 10), GOLD)
			sparks(ci, [Vector2(-42, -36), Vector2(40, -40), Vector2(42, 24)])

## 挂猎物的横木
static func _h_stick(y: float, s: int) -> Array:
	return stk(Vector2(-24, y), Vector2(24, y + 2), 3.4, s, WOOD)

## 弧形带：沿椭圆 c/r 从 a0 到 a1，厚 th
static func _h_arc(c: Vector2, r: Vector2, th: float, a0: float, a1: float, n: int = 14) -> Array:
	var out := []
	for k in n + 1:
		var a := lerpf(a0, a1, float(k) / float(n))
		out.append(c + Vector2(cos(a) * (r.x + th), sin(a) * (r.y + th)))
	for k in n + 1:
		var a := lerpf(a1, a0, float(k) / float(n))
		out.append(c + Vector2(cos(a) * (r.x - th), sin(a) * (r.y - th)))
	return out

static func _h_tongue(ci: CanvasItem, m: Vector2, ang: float, l: float = 5.0) -> void:
	var tg := ell(m + Vector2(cos(ang), sin(ang)) * l, Vector2(3.0, l), 3, 0.0, 10, ang - PI * 0.5)
	ci.draw_colored_polygon(tg, PINK)
	outline(ci, tg, 1.5)

## 深色皮毛上的叉叉眼
static func _h_xw(ci: CanvasItem, c: Vector2, r: float) -> void:
	ln(ci, c + Vector2(-r, -r), c + Vector2(r, r), 2.2, BONE, 1)
	ln(ci, c + Vector2(-r, r), c + Vector2(r, -r), 2.2, BONE, 2)

## 脚趾：从 p 沿 ang 扇开 n 根
static func _h_toes(ci: CanvasItem, p: Vector2, ang: float, l: float, n: int = 3, col: Color = INK, w: float = 1.8) -> void:
	for t in n:
		var a := ang + (float(t) - float(n - 1) * 0.5) * 0.7
		ln(ci, p, p + Vector2(cos(a), sin(a)) * l, w, col, t)

## 毛边：在 pts 上每隔一个点向外推一点
static func _h_shag(c: Vector2, r: Vector2, n: int, k: float, s: int, col: Color, below: float = 0.2) -> Array:
	var pts := []
	for i in n:
		var a := TAU * float(i) / float(n)
		var f := k if (i % 2 == 1 and sin(a) > below) else 1.0
		pts.append(c + Vector2(cos(a) * r.x * f, sin(a) * r.y * f))
	return pg(pts, s, col, 1)

static func _main_art(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			## 灰壁虎（最小的一只）：肚皮朝上摊开（俯视），四只小脚张开，尾巴卷起来
			var gk := Color("8e8a86")
			var belly := Color("d9d3c8")
			var parts := []
			var tl := [Vector2(0, 20), Vector2(2, 28), Vector2(8, 33), Vector2(15, 31), Vector2(16, 25)]
			for i in 4:
				parts.append(stk(tl[i], tl[i + 1], 3.4 - float(i) * 0.5, s + i, gk, 2))
			var feet := []
			for sd in [-1.0, 1.0]:
				parts.append(stk(Vector2(sd * 4.0, 4), Vector2(sd * 12.0, -2), 2.2, s + 10, gk, 2))
				parts.append(stk(Vector2(sd * 4.0, 16), Vector2(sd * 12.0, 22), 2.4, s + 12, gk, 2))
				feet.append([Vector2(sd * 12.0, -2), -PI * 0.5 + sd * 0.9])
				feet.append([Vector2(sd * 12.0, 22), PI * 0.5 - sd * 0.9])
			for f in feet:
				for k in 3:
					var a: float = f[1] + (float(k) - 1.0) * 0.6
					parts.append(circ((f[0] as Vector2) + Vector2(cos(a), sin(a)) * 3.6, 1.7, s + 20 + k, gk, 2))
			parts.append(ov(Vector2(0, 10), 6.5, 11, s + 30, gk, 0.0, 1))
			parts.append(ov(Vector2(0, -6), 6.5, 6, s + 31, gk, 0.0, 1))
			sil(ci, parts, rim)
			ci.draw_colored_polygon(ell(Vector2(0, 11), Vector2(4, 8), s, 0.0, 12), belly)
			ci.draw_colored_polygon(ell(Vector2(0, -6), Vector2(3.8, 3.4), s + 1, 0.0, 10), belly)
			xeye(ci, Vector2(-3.4, -8), 1.6, 1.6)
			xeye(ci, Vector2(3.4, -8), 1.6, 1.6)
		2:
			## 野兔：侧躺伸直，长耳朵向后贴在背上，大后腿蹬直，白尾巴翘着
			var parts := []
			parts.append(stk(Vector2(-12, 20), Vector2(-28, 28), 2.6, s, HARE.darkened(0.18), 2))
			parts.append(stk(Vector2(22, 22), Vector2(40, 26), 3.0, s + 1, HARE.darkened(0.18), 2))
			parts.append(ov(Vector2(6, 12), 22, 13, s + 2, HARE, 0.0, 1))
			parts.append(ov(Vector2(20, 12), 11, 11, s + 3, HARE.darkened(0.04), 0.0, 1))
			parts.append(stk(Vector2(24, 20), Vector2(44, 28), 3.6, s + 4, HARE.darkened(0.06), 2))
			parts.append(circ(Vector2(30, 2), 6, s + 5, BONE, 1))
			parts.append(stk(Vector2(-8, 22), Vector2(-24, 31), 2.8, s + 6, HARE.darkened(0.08), 2))
			parts.append(ov(Vector2(-2, -10), 18, 5, s + 7, HARE.darkened(0.1), -0.55, 1))
			parts.append(ov(Vector2(2, -4), 18, 5, s + 8, HARE, -0.3, 1))
			parts.append(ov(Vector2(-20, 9), 13, 10.5, s + 9, HARE, 0.0, 1))
			parts.append(ov(Vector2(-30, 13), 6, 5.5, s + 10, BONE2, 0.0, 1))
			sil(ci, parts, rim)
			ci.draw_colored_polygon(ell(Vector2(3, -4), Vector2(13, 2.2), s, 0.0, 10, -0.3), Color(PINK, 0.8))
			ci.draw_colored_polygon(ell(Vector2(4, 20), Vector2(16, 3.5), s + 1, 0.0, 12), Color(BONE, 0.6))
			ci.draw_colored_polygon(ell(Vector2(42, 28), Vector2(4, 2), s + 2, 0.0, 8), BONE2)
			ci.draw_circle(Vector2(-35, 11), 2.0, PINK.darkened(0.2))
			for k in 2:
				ln(ci, Vector2(-30, 13.0 + float(k) * 2.5), Vector2(-40, 12.0 + float(k) * 5.0), 1.0, Color(INK, 0.5), s + k)
			xeye(ci, Vector2(-21, 5), 2.6)
			hl(ci, Vector2(8, 3), 8, 3, -0.1, 0.35)
		3:
			## 狐狸：侧躺蜷成一团，大尾巴绕到前面盖住脚，下巴搁在尾巴尖上
			var parts := []
			parts.append(ov(Vector2(6, 8), 24, 15, s, FOX, 0.0, 1))
			parts.append(ov(Vector2(-4, 21), 4, 3.4, s + 1, FUR_D, 0.0, 2))
			parts.append(ov(Vector2(8, 22), 4, 3.4, s + 2, FUR_D, 0.0, 2))
			parts.append(pg(_h_arc(Vector2(4, 13), Vector2(26, 14), 6.5, -0.3, PI * 0.96), s + 3, FOX.darkened(0.04), 1))
			parts.append(ov(Vector2(-25, 18), 7, 6, s + 4, BONE, 0.3, 1))
			parts.append(pg([Vector2(-18, -2), Vector2(-4, -16), Vector2(-6, 0)], s + 5, FOX.darkened(0.1)))
			parts.append(ov(Vector2(-20, 4), 12, 10, s + 6, FOX, 0.0, 1))
			parts.append(pg([Vector2(-26, -2), Vector2(-42, 12), Vector2(-24, 12)], s + 7, FOX))
			sil(ci, parts, rim)
			ci.draw_colored_polygon(poly([Vector2(-26, 4), Vector2(-40, 12), Vector2(-24, 12), Vector2(-16, 10)], s), BONE)
			ci.draw_colored_polygon(poly([Vector2(-15, -3), Vector2(-7, -12), Vector2(-8, -2)], s + 1), Color(INK, 0.55))
			ci.draw_circle(Vector2(-41, 12), 2.2, INK)
			xeye(ci, Vector2(-22, 1), 2.6)
			for k in 3:
				ln(ci, Vector2(14.0 + float(k) * 6.0, -4), Vector2(12.0 + float(k) * 6.0, 4), 1.6, Color(FOX.darkened(0.4), 0.5), s + k)
			hl(ci, Vector2(10, -2), 8, 3, -0.15, 0.35)
		4:
			## 狼：侧躺，四条腿向前后直直伸开，舌头耷拉在地上
			var parts := []
			var dk := WOLF.darkened(0.22)
			parts.append(ov(Vector2(34, 16), 15, 6, s, WOLF.darkened(0.05), 0.3, 1))
			parts.append(stk(Vector2(-8, 14), Vector2(-24, 30), 3.4, s + 1, dk, 2))
			parts.append(stk(Vector2(18, 14), Vector2(36, 30), 3.6, s + 2, dk, 2))
			parts.append(ov(Vector2(6, 8), 24, 12, s + 3, WOLF, 0.0, 1))
			parts.append(stk(Vector2(-4, 16), Vector2(-18, 32), 3.8, s + 4, WOLF.darkened(0.08), 2))
			parts.append(stk(Vector2(12, 16), Vector2(28, 32), 4.0, s + 5, WOLF.darkened(0.08), 2))
			parts.append(pg([Vector2(-24, 2), Vector2(-17, -12), Vector2(-11, 2)], s + 6, WOLF.darkened(0.06)))
			parts.append(ov(Vector2(-22, 8), 12, 10, s + 7, WOLF, 0.0, 1))
			parts.append(pg([Vector2(-28, 3), Vector2(-44, 11), Vector2(-43, 18), Vector2(-26, 18)], s + 8, WOLF))
			sil(ci, parts, rim)
			for f in [[Vector2(-18, 32), PI * 0.6], [Vector2(28, 32), PI * 0.3], [Vector2(-24, 30), PI * 0.6], [Vector2(36, 30), PI * 0.3]]:
				_h_toes(ci, f[0], f[1], 3.5, 3, INK, 1.4)
			ci.draw_colored_polygon(poly([Vector2(-26, 14), Vector2(-42, 15), Vector2(-42, 18), Vector2(-24, 18)], s), BONE2)
			ci.draw_colored_polygon(ell(Vector2(-20, 13), Vector2(7, 3.5), s + 2, 0.0, 12), BONE2)
			ci.draw_colored_polygon(poly([Vector2(-21, 0), Vector2(-17, -8), Vector2(-14, 0)], s + 3), Color(INK, 0.5))
			ci.draw_colored_polygon(ell(Vector2(6, 16), Vector2(17, 3.5), s + 1, 0.0, 14), Color(BONE2, 0.7))
			ci.draw_circle(Vector2(-44, 12), 2.4, INK)
			xeye(ci, Vector2(-23, 5), 2.6)
			_h_tongue(ci, Vector2(-36, 18), PI * 0.55, 5.5)
			hl(ci, Vector2(10, 0), 9, 3, -0.1, 0.3)
		5:
			## 野猪：侧倒，四条腿直挺挺伸出去；头还是正的，看得见猪鼻子、朝上翘的獠牙和背上的鬃毛
			var parts := []
			var legs := [[Vector2(-2, 22), Vector2(-8, 35), 0.18], [Vector2(26, 20), Vector2(36, 32), 0.18], [Vector2(-8, 22), Vector2(-18, 34), 0.0], [Vector2(20, 22), Vector2(28, 35), 0.0]]
			for i in legs.size():
				var l: Array = legs[i]
				var a: Vector2 = l[0]
				var b: Vector2 = l[1]
				parts.append(stk(a, b, 4.2, s + i, BOAR.darkened(0.1 + float(l[2])), 2))
				parts.append(stk(b + (a - b).normalized() * 4.5, b, 4.5, s + 10 + i, BLACK, 2))
			var br := [Vector2(-16, 0)]
			for k in 11:
				var x := lerpf(-14.0, 30.0, float(k) / 10.0)
				br.append(Vector2(x, (-14.0 if k % 2 == 0 else -6.0) + absf(x - 4.0) * 0.12))
			br.append(Vector2(32, 0))
			parts.append(pg(br, s + 20, BOAR.darkened(0.35), 1))
			parts.append(stk(Vector2(33, 6), Vector2(40, 0), 1.8, s + 21, BOAR.darkened(0.2), 2))
			parts.append(ov(Vector2(41, -2), 3, 4.5, s + 22, BOAR.darkened(0.35), 0.5, 2))
			parts.append(ov(Vector2(8, 10), 26, 15, s + 23, BOAR, 0.0, 1))
			parts.append(pg([Vector2(-20, -4), Vector2(-14, -18), Vector2(-8, -2)], s + 24, BOAR.darkened(0.15)))
			parts.append(pg([Vector2(-10, -6), Vector2(-22, -6), Vector2(-40, 6), Vector2(-42, 18), Vector2(-26, 24), Vector2(-8, 20)], s + 25, BOAR, 1))
			parts.append(ov(Vector2(-43, 12), 4.5, 7.5, s + 26, Color("d0a080"), 0.0, 1))
			parts.append(pg([Vector2(-33, 17), Vector2(-36, 3), Vector2(-29, 15)], s + 27, BONE))
			sil(ci, parts, rim)
			ci.draw_circle(Vector2(-44, 9), 1.5, INK)
			ci.draw_circle(Vector2(-44, 15), 1.5, INK)
			ci.draw_colored_polygon(poly([Vector2(-17, -6), Vector2(-14, -14), Vector2(-11, -5)], s), Color(INK, 0.5))
			ci.draw_colored_polygon(ell(Vector2(8, 19), Vector2(18, 4), s + 1, 0.0, 14), Color("c08a64", 0.6))
			xeye(ci, Vector2(-24, 4), 2.6)
			_h_tongue(ci, Vector2(-34, 21), PI * 0.6, 4.0)
			hl(ci, Vector2(12, 1), 9, 3, -0.1, 0.3)
		6:
			## 鹿：前后腿折在身下卧倒，脖子垂下来，头侧搁在地上，鹿角歪向一边
			var parts := []
			var ac := BONE2.darkened(0.12)
			var ant := [[Vector2(-30, 15), Vector2(-36, -4)], [Vector2(-36, -4), Vector2(-32, -24)], [Vector2(-35, -6), Vector2(-46, -12)], [Vector2(-33, -16), Vector2(-42, -26)],
				[Vector2(-25, 14), Vector2(-20, -4)], [Vector2(-20, -4), Vector2(-10, -18)], [Vector2(-20, -6), Vector2(-8, -4)], [Vector2(-14, -12), Vector2(-14, -24)]]
			for i in ant.size():
				parts.append(stk(ant[i][0], ant[i][1], 2.8 if i % 4 < 2 else 2.4, s + i, ac, 2))
			parts.append(stk(Vector2(30, 24), Vector2(42, 30), 3.0, s + 10, DEER.darkened(0.1), 2))
			parts.append(stk(Vector2(40, 29.5), Vector2(45, 31), 3.2, s + 11, INK, 2))
			parts.append(ov(Vector2(8, 12), 26, 14, s + 12, DEER, 0.0, 1))
			parts.append(ov(Vector2(22, 12), 12, 12, s + 13, DEER.darkened(0.06), 0.0, 1))
			parts.append(circ(Vector2(33, 6), 4, s + 14, BONE, 1))
			parts.append(stk(Vector2(-10, 22), Vector2(-26, 30), 3.0, s + 15, DEER.darkened(0.08), 2))
			parts.append(stk(Vector2(-26, 30), Vector2(-31, 31), 3.2, s + 16, INK, 2))
			parts.append(stk(Vector2(-12, 6), Vector2(-24, 18), 6.5, s + 17, DEER, 2))
			parts.append(pg([Vector2(-22, 16), Vector2(-14, 8), Vector2(-17, 20)], s + 18, DEER.darkened(0.1)))
			parts.append(ov(Vector2(-31, 22), 11, 7, s + 19, DEER, 0.35, 1))
			sil(ci, parts, rim)
			ci.draw_colored_polygon(ell(Vector2(6, 20), Vector2(18, 4), s, 0.0, 14), Color(BONE2, 0.7))
			ci.draw_colored_polygon(ell(Vector2(-38, 26), Vector2(4, 3), s + 1, 0.0, 10, 0.35), BONE2)
			ci.draw_circle(Vector2(-41, 27), 1.8, INK)
			xeye(ci, Vector2(-29, 19), 2.4)
			_h_tongue(ci, Vector2(-36, 29), PI * 0.6, 3.5)
			hl(ci, Vector2(4, 2), 9, 3, -0.1, 0.35)
		7:
			## 野牛：前膝跪倒、后腿还撑着屁股翘起，大脑袋垂到地上，牛角朝上
			var parts := []
			var dark := BISON.darkened(0.2)
			var mane := Color("3e2616")
			parts.append(stk(Vector2(26, 4), Vector2(30, 30), 5.0, s, BISON.darkened(0.1), 2))
			parts.append(stk(Vector2(30, 29), Vector2(31, 34), 5.2, s + 1, INK, 2))
			parts.append(stk(Vector2(38, -10), Vector2(44, 6), 1.8, s + 2, dark, 2))
			parts.append(ov(Vector2(45, 8), 3, 5, s + 3, INK, 0.3, 2))
			parts.append(pg([Vector2(40, -12), Vector2(37, 4), Vector2(24, 14), Vector2(4, 20), Vector2(-14, 26), Vector2(-20, 8), Vector2(-10, -14), Vector2(12, -16)], s + 4, BISON, 1))
			parts.append(stk(Vector2(-10, 22), Vector2(-14, 32), 5.0, s + 5, mane, 2))
			parts.append(stk(Vector2(-14, 32), Vector2(2, 34), 4.4, s + 6, mane, 2))
			parts.append(_h_shag(Vector2(-10, -2), Vector2(15, 21), 22, 1.12, s + 7, mane, -2.0))
			parts.append(_h_shag(Vector2(-29, 20), Vector2(13, 12), 18, 1.15, s + 8, mane, -2.0))
			parts.append(ov(Vector2(-38, 27), 7, 6, s + 9, BISON.darkened(0.05), 0.0, 1))
			parts.append(band(Vector2(-40, 10), 7, 2.6, 0.1, -PI * 0.55, s + 10, BONE2))
			parts.append(band(Vector2(-18, 10), 7, 2.6, PI - 0.1, PI * 1.55, s + 11, BONE2.darkened(0.1)))
			sil(ci, parts, rim)
			for k in 5:
				ln(ci, Vector2(-18.0 + float(k) * 5.0, -14), Vector2(-20.0 + float(k) * 5.0, 2), 1.6, Color(BISON.lightened(0.2), 0.5), s + k)
			for k in 3:
				ln(ci, Vector2(10.0 + float(k) * 8.0, -10), Vector2(8.0 + float(k) * 8.0, 6), 1.6, Color(INK, 0.3), s + k)
			ci.draw_circle(Vector2(-42, 26), 1.6, INK)
			_h_xw(ci, Vector2(-28, 17), 2.6)
			_h_tongue(ci, Vector2(-36, 33), PI * 0.85, 3.5)
			hl(ci, Vector2(22, -8), 8, 3, -0.3, 0.25)
		8:
			## 剑齿虎：一身壮实的肌肉趴倒在地，前爪向前伸平；大脑袋侧着，嘴张开，两根长剑齿一直戳到地上，短尾巴
			var fur := TIGER
			var parts := []
			parts.append(stk(Vector2(34, 6), Vector2(48, -4), 3.2, s, fur.darkened(0.1), 2))
			parts.append(stk(Vector2(26, 24), Vector2(50, 33), 6.2, s + 1, fur.darkened(0.14), 2))
			parts.append(stk(Vector2(-6, 26), Vector2(-30, 33), 6.0, s + 2, fur.darkened(0.14), 2))
			parts.append(ov(Vector2(8, 12), 34, 19, s + 3, fur, 0.0, 1))
			parts.append(ov(Vector2(-12, 6), 16, 17, s + 4, fur.darkened(0.03), 0.0, 1))
			parts.append(stk(Vector2(-14, 26), Vector2(-46, 33), 6.6, s + 5, fur, 2))
			parts.append(circ(Vector2(-26, -14), 6, s + 6, fur.darkened(0.06), 1))
			parts.append(ov(Vector2(-32, 2), 17, 15, s + 7, fur, 0.0, 1))
			parts.append(pg([Vector2(-48, 4), Vector2(-40, 10), Vector2(-30, 12), Vector2(-46, 16)], s + 8, Color("5a2418"), 2))
			parts.append(pg([Vector2(-44, 9), Vector2(-42, 34), Vector2(-37, 11)], s + 9, BONE))
			parts.append(pg([Vector2(-35, 11), Vector2(-33, 31), Vector2(-29, 12)], s + 10, BONE))
			parts.append(ov(Vector2(-41, 1), 9, 6, s + 11, BONE, 0.0, 1))
			sil(ci, parts, rim)
			## 背上的条纹、脸上的纹、肚皮
			for k in 5:
				var x := -2.0 + float(k) * 9.0
				ci.draw_colored_polygon(poly([Vector2(x - 4, -5.0 + absf(float(k) - 2.0) * 1.2), Vector2(x + 4, -5.0 + absf(float(k) - 2.0) * 1.2), Vector2(x + 1, 9)], s + k), FUR_D)
			for k in 3:
				var x := -36.0 + float(k) * 6.0
				ci.draw_colored_polygon(poly([Vector2(x - 2, -12), Vector2(x + 2, -12), Vector2(x + 0.5, -5)], s + k + 5), FUR_D)
			ci.draw_colored_polygon(ell(Vector2(10, 27), Vector2(24, 3.5), s, 0.0, 14), Color(BONE, 0.6))
			_h_toes(ci, Vector2(-46, 33), PI * 0.85, 4.5, 3, INK, 1.6)
			_h_toes(ci, Vector2(50, 33), PI * 0.15, 4.5, 3, INK, 1.6)
			ci.draw_circle(Vector2(-49, -2), 2.6, INK)
			xeye(ci, Vector2(-32, -4), 3.0)
			hl(ci, Vector2(10, -1), 12, 3.5, -0.1, 0.3)
		9:
			## 披毛犀：侧倒、背朝前，两条粗腿从背后翘起来；大脑袋侧贴在地上，鼻子上一长一短两只角朝天
			var parts := []
			for i in 2:
				var a := Vector2(10.0 + float(i) * 20.0, -8)
				parts.append(stk(a, a + Vector2(8, -16), 5.4, s + i, RHINO.darkened(0.2), 2))
				parts.append(stk(a + Vector2(7, -13), a + Vector2(9, -18), 5.8, s + 4 + i, INK, 2))
			parts.append(stk(Vector2(44, 6), Vector2(48, 16), 1.8, s + 8, RHINO.darkened(0.3), 2))
			parts.append(_h_shag(Vector2(16, 10), Vector2(30, 21), 26, 1.08, s + 9, RHINO, -1.1))
			parts.append(pg([Vector2(-6, 2), Vector2(-2, -10), Vector2(4, 2)], s + 10, RHINO.darkened(0.12)))
			parts.append(pg([Vector2(4, 6), Vector2(-8, 0), Vector2(-28, 4), Vector2(-42, 14), Vector2(-44, 26), Vector2(-30, 32), Vector2(-4, 30)], s + 11, Color("b89070"), 1))
			parts.append(pg([Vector2(-44, 16), Vector2(-50, 0), Vector2(-54, -16), Vector2(-46, -8), Vector2(-32, 8)], s + 12, BONE2))
			parts.append(pg([Vector2(-28, 6), Vector2(-26, -10), Vector2(-22, -10), Vector2(-18, 4)], s + 13, BONE2))
			sil(ci, parts, rim)
			for k in 7:
				var x := 0.0 + float(k) * 6.5
				ln(ci, Vector2(x, -4.0 + absf(float(k) - 3.0) * 1.2), Vector2(x - 2, 10), 1.8, Color(RHINO.darkened(0.45), 0.55), s + k)
			for k in 3:
				ln(ci, Vector2(-48.0 + float(k) * 2.0, -4.0 + float(k) * 6.0), Vector2(-43.0 + float(k) * 2.5, -3.0 + float(k) * 6.0), 1.4, Color(INK, 0.35), s + k)
			ln(ci, Vector2(-42, 27), Vector2(-32, 29), 1.6, Color(INK, 0.6), s)
			ci.draw_colored_polygon(poly([Vector2(-4, 1), Vector2(-2, -6), Vector2(1, 1)], s), Color(INK, 0.45))
			xeye(ci, Vector2(-20, 14), 2.6)
			hl(ci, Vector2(20, -2), 10, 3, -0.1, 0.25)
		_:
			## 猛犸：正面趴倒，前腿向两边摊开，长鼻子瘫在地上，两根大象牙卷向两边
			glow(ci, Vector2(0, 4), 54, GOLD)
			var parts := []
			for sd in [-1.0, 1.0]:
				parts.append(stk(Vector2(sd * 24.0, 18), Vector2(sd * 40.0, 30), 8.0, s, MAMMOTH.darkened(0.12), 2))
			parts.append(_h_shag(Vector2(0, 2), Vector2(40, 28), 30, 1.1, s + 1, MAMMOTH.darkened(0.15)))
			parts.append(ov(Vector2(0, -26), 14, 9, s + 2, MAMMOTH.darkened(0.06), 0.0, 1))
			for sd in [-1.0, 1.0]:
				parts.append(ov(Vector2(sd * 23.0, -2), 11, 14, s + 3, MAMMOTH.darkened(0.3), sd * 0.3, 1))
			parts.append(ov(Vector2(0, 0), 19, 17, s + 5, Color("9a6a40"), 0.0, 1))
			parts.append(stk(Vector2(0, 10), Vector2(2, 26), 7.0, s + 6, Color("9a6a40"), 2))
			parts.append(stk(Vector2(2, 26), Vector2(12, 33), 5.6, s + 7, Color("9a6a40"), 2))
			parts.append(stk(Vector2(12, 33), Vector2(20, 29), 4.2, s + 8, Color("9a6a40"), 2))
			parts.append(band(Vector2(-23, 13), 13, 3.8, -0.1, PI * 1.15, s + 9, BONE))
			parts.append(band(Vector2(23, 13), 13, 3.8, PI + 0.1, -PI * 0.15, s + 10, BONE))
			sil(ci, parts, rim)
			for sd in [-1.0, 1.0]:
				for t in 3:
					ci.draw_circle(Vector2(sd * (36.0 + float(t) * 3.5), 34.0 - float(t) * 2.0), 2.0, BONE2)
				for k in 4:
					var x: float = sd * (28.0 + float(k) * 3.5)
					ln(ci, Vector2(x, -12), Vector2(x - sd * 1.5, 0), 1.6, Color(INK, 0.35), s + k)
			for k in 3:
				ln(ci, Vector2(-1, 16.0 + float(k) * 4.0), Vector2(5, 16.5 + float(k) * 4.0), 1.4, Color(INK, 0.4), s + k)
			xeye(ci, Vector2(-8, -4), 2.6)
			xeye(ci, Vector2(8, -4), 2.6)
			hl(ci, Vector2(-6, -24), 5, 2.5, -0.1, 0.35)
			sparks(ci, [Vector2(-42, -34), Vector2(42, -32), Vector2(-44, 4)])

static func _sub_art(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			## 麻雀：仰面朝天，两只小爪蜷着朝上，翅膀尖垂在两边
			var col := Color("a8784e")
			var parts := []
			for sd in [0.0, 1.0]:
				var a := Vector2(-2.0 + sd * 9.0, 4)
				parts.append(stk(a, a + Vector2(sd * 2.0 - 1.0, -16), 1.8, s + int(sd), OCHRE, 2))
			parts.append(pg([Vector2(18, 10), Vector2(36, 4), Vector2(38, 16), Vector2(18, 20)], s + 2, col.darkened(0.2)))
			parts.append(ov(Vector2(2, 14), 19, 13, s + 3, col, 0.0, 1))
			parts.append(ov(Vector2(6, 24), 14, 6, s + 4, col.darkened(0.15), 0.1, 1))
			parts.append(circ(Vector2(-18, 14), 10, s + 5, col, 1))
			parts.append(pg([Vector2(-26, 10), Vector2(-36, 16), Vector2(-25, 18)], s + 6, STONE_D))
			sil(ci, parts, rim)
			ci.draw_colored_polygon(ell(Vector2(2, 7), Vector2(14, 6), s, 0.0, 14), Color("e8d8b8"))
			ci.draw_colored_polygon(ell(Vector2(-18, 12), Vector2(5, 6), s + 1, 0.0, 10), Color("e8d8b8"))
			for sd in [0.0, 1.0]:
				var ft := Vector2(-3.0 + sd * 11.0, -12)
				ci.draw_arc(ft + Vector2(3, 0), 3.0, PI * 0.9, PI * 2.1, 8, INK, 1.8, true)
				ci.draw_arc(ft + Vector2(-2, 1), 2.6, PI * 1.0, PI * 2.2, 8, INK, 1.6, true)
			for k in 3:
				ln(ci, Vector2(-2.0 + float(k) * 7.0, 20), Vector2(4.0 + float(k) * 7.0, 27), 1.4, Color(INK, 0.4), s + k)
			xeye(ci, Vector2(-20, 15), 2.4, 2.0)
		2:
			## 乌鸦：侧躺，翅膀半张开搭在身上（羽毛不再大张，个头比野鸡小）
			var col := Color("2b2430")
			var parts := []
			var fe := []
			for k in 5:
				var a := lerpf(-PI * 0.78, -PI * 0.3, float(k) / 4.0)
				fe.append([Vector2(10, 12), 17.0 + 3.0 * sin(float(k) / 4.0 * PI), a])
				parts.append(leaf(Vector2(10, 12), fe[k][1], 5.0, a, s + k, col.lightened(0.08)))
			parts.append(pg([Vector2(24, 14), Vector2(38, 11), Vector2(38, 23), Vector2(24, 22)], s + 10, col))
			parts.append(ov(Vector2(6, 18), 19, 11, s + 11, col, 0.0, 1))
			parts.append(circ(Vector2(-15, 20), 9, s + 12, col, 1))
			parts.append(pg([Vector2(-21, 16), Vector2(-36, 23), Vector2(-21, 25)], s + 13, BLACK.lightened(0.15)))
			parts.append(stk(Vector2(2, 28), Vector2(8, 35), 1.6, s + 14, STONE_D, 2))
			sil(ci, parts, rim)
			for f in fe:
				vein(ci, f[0], f[1], f[2], s, Color("6a5a8a", 0.7))
			_h_toes(ci, Vector2(8, 35), PI * 0.2, 3.5, 3, STONE_D, 1.4)
			_h_xw(ci, Vector2(-16, 18), 2.4)
			hl(ci, Vector2(4, 13), 7, 2.5, -0.1, 0.3)
		3:
			## 野鸡：侧躺，身子圆鼓鼓的，一对长长的花尾羽拖在后面，红脸、绿脖子、白颈环
			var col := Color("b8622a")
			var parts := []
			parts.append(leaf(Vector2(16, 8), 40, 6.0, -0.22, s, Color("b89048")))
			parts.append(leaf(Vector2(16, 11), 38, 6.0, 0.04, s + 1, Color("c8a058")))
			parts.append(stk(Vector2(4, 26), Vector2(10, 34), 2.0, s + 2, STONE_D, 2))
			parts.append(ov(Vector2(4, 12), 22, 17, s + 3, col, 0.0, 1))
			parts.append(pg([Vector2(-6, 2), Vector2(12, -4), Vector2(26, 8), Vector2(20, 18), Vector2(4, 20)], s + 4, Color("8a4a22")))
			parts.append(stk(Vector2(-12, 8), Vector2(-24, 18), 6.0, s + 5, Color("2f8a6a"), 2))
			parts.append(circ(Vector2(-29, 21), 10.5, s + 6, Color("3a9a78"), 1))
			parts.append(pg([Vector2(-38, 20), Vector2(-48, 26), Vector2(-37, 28)], s + 7, BONE2))
			parts.append(ov(Vector2(-31, 20), 6.5, 7, s + 8, Color("e8402a"), 0.0, 2))
			parts.append(pg([Vector2(-28, 12), Vector2(-24, 4), Vector2(-22, 13)], s + 9, Color("2f8a6a").darkened(0.15), 2))
			sil(ci, parts, rim)
			for k in 5:
				var x := 22.0 + float(k) * 6.0
				ln(ci, Vector2(x, 2.0 - float(k) * 1.4 - 2.0), Vector2(x + 1, 6.0 - float(k) * 1.4 + 2.0), 1.4, Color(INK, 0.45), s + k)
				ln(ci, Vector2(x + 2, 10), Vector2(x + 3, 14), 1.4, Color(INK, 0.45), s + k + 5)
			ln(ci, Vector2(-17, 8), Vector2(-20, 16), 2.8, BONE, s)
			for k in 6:
				ci.draw_circle(Vector2(-6.0 + float(k) * 5.0, 12.0 + float(k % 2) * 5.0), 1.6, Color(INK, 0.4))
			_h_toes(ci, Vector2(10, 34), PI * 0.2, 3.5, 3, STONE_D, 1.4)
			xeye(ci, Vector2(-31, 19), 2.6, 2.0)
			hl(ci, Vector2(0, 2), 8, 3, -0.1, 0.3)
		4:
			## 野鸭：两只蹼脚被草绳拴在一根木棍上，整只倒挂下来，绿脑袋垂在最下面，黄嘴朝下
			var col := Color("9a7a5a")
			var parts := []
			parts.append(stk(Vector2(-28, -38), Vector2(28, -40), 3.2, s, WOOD, 2))
			for sd in [-1.0, 1.0]:
				var top := Vector2(2.0 + sd * 6.0, -30)
				parts.append(pg([top + Vector2(-5, 2), top + Vector2(0, -6), top + Vector2(5, 2)], s + 1 + int(sd), OCHRE, 2))
				parts.append(stk(top + Vector2(0, 1), Vector2(2.0 + sd * 4.0, -16), 2.0, s + 3 + int(sd), OCHRE, 2))
			parts.append(pg([Vector2(-10, -12), Vector2(14, -12), Vector2(2, -24)], s + 5, col.darkened(0.3)))
			parts.append(ov(Vector2(2, 2), 17, 20, s + 6, col, 0.0, 1))
			parts.append(pg([Vector2(-13, -8), Vector2(8, -12), Vector2(17, 4), Vector2(6, 18), Vector2(-11, 10)], s + 7, Color("7a5e44")))
			parts.append(stk(Vector2(2, 18), Vector2(0, 26), 6.0, s + 8, Color("2f8a4a"), 2))
			parts.append(circ(Vector2(-1, 29), 8.5, s + 9, Color("2f8a4a"), 1))
			parts.append(ov(Vector2(-6, 37), 7, 3.6, s + 10, OCHRE, 0.9, 1))
			sil(ci, parts, rim)
			var rope := [Vector2(-4, -39), Vector2(-3, -32), Vector2(8, -32), Vector2(9, -39)]
			pl(ci, rope, 4.0, INK, s)
			pl(ci, rope, 2.2, ROPE, s)
			ci.draw_colored_polygon(poly([Vector2(2, -4), Vector2(12, -2), Vector2(12, 5), Vector2(3, 3)], s), Color("3a6ac8"))
			ln(ci, Vector2(-5, 20), Vector2(7, 20), 2.6, BONE, s)
			ci.draw_colored_polygon(ell(Vector2(-6, 2), Vector2(4, 13), s + 1, 0.0, 12), Color(BONE2, 0.5))
			xeye(ci, Vector2(3, 29), 2.4, 2.0)
			hl(ci, Vector2(-8, -6), 3, 7, -0.1, 0.3)
		5:
			## 大雁：趴着蜷成一团，长脖子绕回来搭在背上，脑袋枕在翅膀上，一只橙脚从肚子底下露出来
			var col := Color("8c7b66")
			var neck := Color("cdbf9f")
			var parts := []
			parts.append(pg([Vector2(16, 30), Vector2(26, 36), Vector2(14, 38)], s, Color("e8925a"), 2))
			parts.append(pg([Vector2(-26, 10), Vector2(-42, 4), Vector2(-40, 18), Vector2(-26, 22)], s + 1, col.darkened(0.3)))
			parts.append(ov(Vector2(2, 16), 30, 18, s + 2, col, 0.0, 1))
			parts.append(pg([Vector2(-24, 8), Vector2(-2, -2), Vector2(24, 4), Vector2(18, 22), Vector2(-14, 22)], s + 3, col.darkened(0.15), 1))
			parts.append(stk(Vector2(26, 16), Vector2(34, 2), 6.0, s + 4, neck, 2))
			parts.append(stk(Vector2(34, 2), Vector2(28, -12), 5.6, s + 5, neck, 2))
			parts.append(stk(Vector2(28, -12), Vector2(14, -14), 5.4, s + 6, neck, 2))
			parts.append(circ(Vector2(6, -11), 8.5, s + 7, neck, 1))
			parts.append(pg([Vector2(0, -13), Vector2(-13, -9), Vector2(0, -6)], s + 8, Color("2b2430")))
			sil(ci, parts, rim)
			pl(ci, [Vector2(30, 14), Vector2(37, 2), Vector2(31, -14), Vector2(15, -18)], 2.4, Color("5a4430"), s)
			for row in 2:
				for k in 4:
					var c := Vector2(-14.0 + float(k) * 8.0 + float(row) * 4.0, 6.0 + float(row) * 7.0)
					pl(ci, arcp(c, Vector2(4.0, 3.0), PI * 0.05, PI * 0.95, 6), 1.5, Color(BONE2, 0.8), s + k + row * 4)
			ci.draw_colored_polygon(ell(Vector2(4, 29), Vector2(20, 3.5), s + 1, 0.0, 12), Color("ece4d4"))
			xeye(ci, Vector2(6, -13), 2.6, 2.0)
			hl(ci, Vector2(-6, 0), 9, 3, -0.1, 0.3)
		6:
			## 秃鹫（正面）：瘫坐着，两只大翅膀像斗篷一样从肩膀垂到地上，白毛领子，光秃秃的粉脖子耷拉下来，钩嘴脑袋垂到地面
			var col := Color("4a3a30")
			var parts := []
			for sd in [-1.0, 1.0]:
				var w := [Vector2(sd * 8.0, -22), Vector2(sd * 30.0, -16), Vector2(sd * 42.0, 6)]
				for k in 5:
					var x: float = sd * lerpf(44.0, 14.0, float(k) / 4.0)
					w.append(Vector2(x, 36.0 if k % 2 == 0 else 29.0))
				w.append(Vector2(sd * 8.0, 20))
				parts.append(pg(w, s + int(sd) + 2, col.darkened(0.08), 1))
			parts.append(ov(Vector2(0, 8), 16, 24, s + 4, col, 0.0, 1))
			parts.append(ov(Vector2(0, -18), 16, 8, s + 5, BONE2, 0.0, 1))
			parts.append(stk(Vector2(0, -16), Vector2(4, 4), 3.8, s + 6, PINK.darkened(0.15), 2))
			parts.append(stk(Vector2(4, 4), Vector2(2, 20), 3.6, s + 7, PINK.darkened(0.15), 2))
			parts.append(circ(Vector2(1, 26), 7.5, s + 8, PINK.darkened(0.15), 1))
			parts.append(pg([Vector2(-4, 30), Vector2(2, 40), Vector2(5, 31)], s + 9, BONE2))
			for sd in [-1.0, 1.0]:
				parts.append(stk(Vector2(sd * 9.0, 30), Vector2(sd * 13.0, 37), 2.2, s + 10 + int(sd), STONE_D, 2))
			sil(ci, parts, rim)
			for sd in [-1.0, 1.0]:
				for k in 4:
					var x: float = sd * (18.0 + float(k) * 6.0)
					ln(ci, Vector2(x, -10.0 + float(k) * 4.0), Vector2(x + sd * 2.0, 28), 1.6, Color(INK, 0.4), s + k)
				_h_toes(ci, Vector2(sd * 13.0, 37), PI * 0.5 - sd * 0.4, 3.5, 3, STONE_D, 1.4)
			for k in 5:
				ln(ci, Vector2(-10.0 + float(k) * 5.0, -21), Vector2(-11.0 + float(k) * 5.0, -14), 1.2, Color(INK, 0.25), s + k)
			xeye(ci, Vector2(-2, 24), 2.4, 2.0)
			hl(ci, Vector2(-6, -2), 4, 9, -0.1, 0.25)
		7:
			## 老鹰：背朝上，两只翅膀完全展开平铺，像个"大"字（最高级的金光让给了鸵鸟）
			var col := Color("6a4428")
			var parts := []
			for sd in [-1.0, 1.0]:
				for k in 5:
					var a: float = (PI if sd < 0.0 else 0.0) + sd * (-0.25 + float(k) * 0.16)
					parts.append(leaf(Vector2(sd * 36.0, -6.0 + float(k) * 1.5), 14.0 - float(k) * 0.8, 3.4, a, s + k + (0 if sd < 0.0 else 10), col.darkened(0.25)))
				parts.append(pg([Vector2(sd * 6.0, -10), Vector2(sd * 22.0, -16), Vector2(sd * 40.0, -12), Vector2(sd * 42.0, 0), Vector2(sd * 30.0, 6), Vector2(sd * 16.0, 10), Vector2(sd * 6.0, 10)], s + 20 + int(sd), col))
				parts.append(stk(Vector2(sd * 6.0, 18), Vector2(sd * 13.0, 24), 2.2, s + 24 + int(sd), GOLD, 2))
			parts.append(pg([Vector2(-6, 14), Vector2(-16, 38), Vector2(0, 41), Vector2(16, 38), Vector2(6, 14)], s + 26, Color("f4f0e8")))
			parts.append(ov(Vector2(0, 2), 10, 18, s + 27, col.darkened(0.1), 0.0, 1))
			parts.append(circ(Vector2(0, -20), 9, s + 28, Color("f4f0e8"), 1))
			parts.append(pg([Vector2(-6, -24), Vector2(-17, -21), Vector2(-15, -14), Vector2(-12, -17), Vector2(-6, -16)], s + 29, GOLD))
			sil(ci, parts, rim)
			for sd in [-1.0, 1.0]:
				ci.draw_colored_polygon(poly([Vector2(sd * 8.0, -8), Vector2(sd * 24.0, -12), Vector2(sd * 30.0, -6), Vector2(sd * 12.0, -2)], s), Color("a8784e", 0.7))
				for k in 4:
					var x: float = sd * (14.0 + float(k) * 6.0)
					ln(ci, Vector2(x, -2), Vector2(x + sd * 2.0, 8), 1.4, Color(INK, 0.4), s + k)
				_h_toes(ci, Vector2(sd * 13.0, 24), PI * 0.5 - sd * 0.5, 4.0, 3, INK, 1.6)
			for k in 3:
				ln(ci, Vector2(-8.0 + float(k) * 8.0, 26), Vector2(-9.0 + float(k) * 9.0, 38), 1.2, Color(INK, 0.3), s + k)
			xeye(ci, Vector2(-3, -21), 2.4, 2.0)
		_:
			## 鸵鸟：最大的一只。仰翻过去，两条粉色长腿直直踢向天上，蓬松的黑羽身子压在地上，白羽散开，长脖子软软地拖在地上，小脑袋
			glow(ci, Vector2(0, -2), 58, GOLD)
			var skin := Color("e3a58e")
			var parts := []
			parts.append(stk(Vector2(18, 0), Vector2(32, -20), 5.6, s, skin.darkened(0.12), 2))
			parts.append(stk(Vector2(32, -20), Vector2(44, -38), 3.2, s + 1, skin.darkened(0.12), 2))
			for k in 3:
				parts.append(leaf(Vector2(30, 18), 22.0 - float(k) * 3.0, 7.5, -0.3 + float(k) * 0.4, s + 2 + k, Color("f4f0e8")))
			parts.append(_h_shag(Vector2(4, 16), Vector2(30, 21), 26, 1.12, s + 6, Color("2e2a2c")))
			parts.append(stk(Vector2(8, 2), Vector2(18, -22), 6.0, s + 7, skin, 2))
			parts.append(stk(Vector2(18, -22), Vector2(26, -44), 3.4, s + 8, skin, 2))
			for k in 3:
				parts.append(leaf(Vector2(-8, 10), 22.0 - float(k) * 3.0, 7.0, -2.6 + float(k) * 0.4, s + 10 + k, Color("f4f0e8")))
			parts.append(stk(Vector2(-22, 22), Vector2(-32, 32), 5.2, s + 14, Color("d9bcae"), 2))
			parts.append(stk(Vector2(-32, 32), Vector2(-44, 33), 4.4, s + 15, Color("d9bcae"), 2))
			parts.append(stk(Vector2(-44, 33), Vector2(-50, 27), 4.0, s + 16, Color("d9bcae"), 2))
			parts.append(ov(Vector2(-52, 22), 6.5, 6, s + 17, Color("b8a8a0"), 0.0, 1))
			parts.append(pg([Vector2(-57, 20), Vector2(-62, 14), Vector2(-54, 17)], s + 18, Color("e8c8a0"), 2))
			sil(ci, parts, rim)
			for k in 6:
				var x := -14.0 + float(k) * 7.0
				pl(ci, [Vector2(x, 10.0 + float(k % 2) * 3.0), Vector2(x + 3, 18), Vector2(x + 1, 26)], 1.4, Color(1, 1, 1, 0.18), s + k)
			for leg in [[Vector2(26, -44), -1.3], [Vector2(44, -38), -1.0]]:
				_h_toes(ci, leg[0], leg[1], 5.0, 2, INK, 2.0)
			xeye(ci, Vector2(-52, 21), 2.2, 1.8)
			hl(ci, Vector2(-4, 4), 8, 3, -0.2, 0.3)
			sparks(ci, [Vector2(-46, -30), Vector2(-20, -44), Vector2(52, 8)])

## 旧画法（重画前保留，游戏里现在不调用）：1 灰壁虎 / 8 剑齿虎
static func beast_old(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			## 灰壁虎（个头小）：肚皮朝上摊开（俯视），四只脚张开露出吸盘趾，尾巴卷起来
			var gk := Color("8e8a86")
			var belly := Color("d9d3c8")
			set_xf(ci, Transform2D(0.0, Vector2.ONE * 0.8, 0.0, Vector2(0, 3)))
			var parts := []
			var tl := [Vector2(0, 14), Vector2(4, 26), Vector2(14, 33), Vector2(25, 29), Vector2(26, 19)]
			for i in 4:
				parts.append(stk(tl[i], tl[i + 1], 5.0 - float(i) * 1.0, s + i, gk, 2))
			var feet := []
			for sd in [-1.0, 1.0]:
				var f0 := Vector2(sd * 8.0, -10)
				var f1 := Vector2(sd * 20.0, -20)
				var h0 := Vector2(sd * 8.0, 10)
				var h1 := Vector2(sd * 22.0, 18)
				parts.append(stk(f0, f0 + (f1 - f0) * 0.55 + Vector2(0, 2), 3.0, s + 10, gk, 2))
				parts.append(stk(f0 + (f1 - f0) * 0.55 + Vector2(0, 2), f1, 2.6, s + 11, gk, 2))
				parts.append(stk(h0, h0 + (h1 - h0) * 0.5 - Vector2(0, 3), 3.4, s + 12, gk, 2))
				parts.append(stk(h0 + (h1 - h0) * 0.5 - Vector2(0, 3), h1, 2.8, s + 13, gk, 2))
				feet.append([f1, -PI * 0.5 + sd * 0.9])
				feet.append([h1, PI * 0.5 - sd * 0.9])
			for f in feet:
				for t in 4:
					var a: float = f[1] + (float(t) - 1.5) * 0.55
					parts.append(circ((f[0] as Vector2) + Vector2(cos(a), sin(a)) * 6.0, 2.4, s + 20 + t, gk, 2))
			parts.append(ov(Vector2(0, 0), 10, 19, s + 30, gk, 0.0, 1))
			parts.append(ov(Vector2(0, -26), 10, 9, s + 31, gk, 0.0, 1))
			sil(ci, parts, rim)
			for f in feet:
				for t in 4:
					var a: float = f[1] + (float(t) - 1.5) * 0.55
					ln(ci, f[0], (f[0] as Vector2) + Vector2(cos(a), sin(a)) * 5.0, 1.6, gk.darkened(0.25), t)
			ci.draw_colored_polygon(ell(Vector2(0, 1), Vector2(6.5, 15), s, 0.0, 16), belly)
			ci.draw_colored_polygon(ell(Vector2(0, -27), Vector2(6, 5), s + 1, 0.0, 12), belly)
			for k in 4:
				ln(ci, Vector2(-4, -8.0 + float(k) * 6.0), Vector2(4, -8.0 + float(k) * 6.0), 1.2, Color(gk.darkened(0.2), 0.5), s + k)
			xeye(ci, Vector2(-6, -30), 2.4, 2.0)
			xeye(ci, Vector2(6, -30), 2.4, 2.0)
			_h_tongue(ci, Vector2(0, -34), -PI * 0.5, 3.5)
			reset_xf(ci)
		8:
			## 剑齿虎：趴倒在地，前爪向前伸平，下巴贴地，两根长剑齿戳到地上
			var parts := []
			parts.append(stk(Vector2(-8, 22), Vector2(-32, 27), 4.6, s, TIGER.darkened(0.15), 2))
			parts.append(stk(Vector2(30, 24), Vector2(46, 30), 4.6, s + 1, TIGER.darkened(0.15), 2))
			parts.append(ov(Vector2(40, 8), 4, 4, s + 2, TIGER.darkened(0.1), 0.0, 2))
			parts.append(ov(Vector2(10, 15), 30, 13, s + 3, TIGER, 0.0, 1))
			parts.append(ov(Vector2(28, 16), 12, 12, s + 4, TIGER.darkened(0.04), 0.0, 1))
			parts.append(stk(Vector2(-12, 24), Vector2(-40, 31), 5.2, s + 5, TIGER, 2))
			parts.append(circ(Vector2(-17, 0), 5, s + 6, TIGER.darkened(0.06), 1))
			parts.append(ov(Vector2(-25, 10), 15, 13, s + 7, TIGER, 0.0, 1))
			parts.append(pg([Vector2(-36, 20), Vector2(-35, 36), Vector2(-31, 21)], s + 8, BONE))
			parts.append(pg([Vector2(-26, 21), Vector2(-25, 35), Vector2(-21, 21)], s + 9, BONE))
			parts.append(ov(Vector2(-34, 16), 9, 6.5, s + 10, BONE, 0.0, 1))
			sil(ci, parts, rim)
			for k in 4:
				var x := -4.0 + float(k) * 9.0
				ci.draw_colored_polygon(poly([Vector2(x - 3.5, 3), Vector2(x + 3.5, 3), Vector2(x + 1, 14)], s + k), FUR_D)
			for k in 3:
				var x := -30.0 + float(k) * 5.0
				ci.draw_colored_polygon(poly([Vector2(x - 2, -2), Vector2(x + 2, -2), Vector2(x + 0.5, 4)], s + k + 5), FUR_D)
			ci.draw_colored_polygon(ell(Vector2(8, 24), Vector2(20, 3.5), s, 0.0, 14), Color(BONE, 0.6))
			_h_toes(ci, Vector2(-40, 31), PI * 0.85, 4.0, 3, INK, 1.4)
			ci.draw_circle(Vector2(-40, 13), 2.2, INK)
			xeye(ci, Vector2(-25, 6), 2.6)
			_h_tongue(ci, Vector2(-30, 22), PI * 0.5, 4.0)
			hl(ci, Vector2(12, 5), 9, 3, -0.1, 0.3)

## 旧画法（重画前保留，游戏里现在不调用）：2 乌鸦 / 3 野鸡 / 4 野鸭 / 6 老鹰（原最高级，带金光）
static func bird_old(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		2:
			## 乌鸦：侧躺，一边翅膀像扇子一样摊开在地上
			var col := Color("2b2430")
			var parts := []
			var fe := []
			for k in 7:
				var a := lerpf(-PI * 0.92, -PI * 0.12, float(k) / 6.0)
				fe.append([Vector2(8, 10), 30.0 + 6.0 * sin(float(k) / 6.0 * PI), a])
				parts.append(leaf(Vector2(8, 10), fe[k][1], 6.0, a, s + k, col.lightened(0.08)))
			parts.append(pg([Vector2(24, 14), Vector2(42, 10), Vector2(42, 24), Vector2(24, 22)], s + 10, col))
			parts.append(ov(Vector2(6, 18), 20, 11, s + 11, col, 0.0, 1))
			parts.append(circ(Vector2(-16, 20), 9, s + 12, col, 1))
			parts.append(pg([Vector2(-22, 16), Vector2(-40, 24), Vector2(-22, 25)], s + 13, BLACK.lightened(0.15)))
			parts.append(stk(Vector2(2, 28), Vector2(8, 35), 1.6, s + 14, STONE_D, 2))
			sil(ci, parts, rim)
			for f in fe:
				vein(ci, f[0], f[1], f[2], s, Color("6a5a8a", 0.7))
			_h_toes(ci, Vector2(8, 35), PI * 0.2, 3.5, 3, STONE_D, 1.4)
			_h_xw(ci, Vector2(-17, 18), 2.4)
			hl(ci, Vector2(4, 13), 7, 2.5, -0.1, 0.3)
		3:
			## 野鸡：侧躺，一对长长的花尾羽拖在后面，红脸、绿脖子、白颈环
			var col := Color("b8622a")
			var parts := []
			parts.append(leaf(Vector2(14, 12), 38, 4.6, -0.2, s, Color("b89048")))
			parts.append(leaf(Vector2(14, 14), 36, 4.6, 0.04, s + 1, Color("c8a058")))
			parts.append(stk(Vector2(2, 24), Vector2(8, 33), 1.8, s + 2, STONE_D, 2))
			parts.append(ov(Vector2(2, 14), 18, 12, s + 3, col, 0.0, 1))
			parts.append(pg([Vector2(-6, 8), Vector2(10, 4), Vector2(22, 14), Vector2(6, 22)], s + 4, Color("8a4a22")))
			parts.append(stk(Vector2(-12, 12), Vector2(-24, 20), 5.0, s + 5, Color("2f8a6a"), 2))
			parts.append(circ(Vector2(-29, 22), 9.5, s + 6, Color("3a9a78"), 1))
			parts.append(pg([Vector2(-37, 21), Vector2(-46, 26), Vector2(-36, 28)], s + 7, BONE2))
			parts.append(ov(Vector2(-31, 21), 6, 6.5, s + 8, Color("e8402a"), 0.0, 2))
			parts.append(pg([Vector2(-28, 14), Vector2(-24, 7), Vector2(-23, 15)], s + 9, Color("2f8a6a").darkened(0.15), 2))
			sil(ci, parts, rim)
			for k in 5:
				var x := 20.0 + float(k) * 6.0
				ln(ci, Vector2(x, 6.0 - float(k) * 1.2 - 2.0), Vector2(x + 1, 10.0 - float(k) * 1.2 + 2.0), 1.4, Color(INK, 0.45), s + k)
				ln(ci, Vector2(x + 2, 13), Vector2(x + 3, 17), 1.4, Color(INK, 0.45), s + k + 5)
			ln(ci, Vector2(-17, 12), Vector2(-20, 19), 2.6, BONE, s)
			for k in 4:
				ci.draw_circle(Vector2(-4.0 + float(k) * 5.0, 14.0 + float(k % 2) * 4.0), 1.5, Color(INK, 0.4))
			_h_toes(ci, Vector2(8, 33), PI * 0.2, 3.5, 3, STONE_D, 1.4)
			xeye(ci, Vector2(-31, 20), 2.6, 2.0)
		4:
			## 野鸭：侧躺，绿脖子直直伸在地上，扁扁的黄嘴贴地，橙色蹼脚翘在后面
			var col := Color("9a7a5a")
			var parts := []
			for sd in [0.0, 1.0]:
				var a := Vector2(16.0 + sd * 7.0, 22)
				var b := a + Vector2(9, 9)
				parts.append(stk(a, b, 1.8, s + int(sd), OCHRE, 2))
				parts.append(pg([b + Vector2(-3, -1), b + Vector2(8, 2), b + Vector2(2, 7)], s + 2 + int(sd), OCHRE, 2))
			parts.append(pg([Vector2(28, 8), Vector2(40, 8), Vector2(28, 18)], s + 4, col.darkened(0.25)))
			parts.append(ov(Vector2(10, 14), 22, 12, s + 5, col, 0.0, 1))
			parts.append(stk(Vector2(-8, 12), Vector2(-24, 22), 5.0, s + 6, Color("2f8a4a"), 2))
			parts.append(circ(Vector2(-28, 23), 8.5, s + 7, Color("2f8a4a"), 1))
			parts.append(ov(Vector2(-41, 28), 8, 3.6, s + 8, OCHRE, 0.3, 1))
			parts.append(pg([Vector2(-4, 10), Vector2(14, 4), Vector2(30, 14), Vector2(10, 22)], s + 9, Color("7a5e44")))
			sil(ci, parts, rim)
			ci.draw_colored_polygon(poly([Vector2(10, 9), Vector2(20, 11), Vector2(18, 16), Vector2(8, 14)], s), Color("3a6ac8"))
			ln(ci, Vector2(-11, 11), Vector2(-14, 18), 2.6, BONE, s)
			ci.draw_colored_polygon(ell(Vector2(6, 22), Vector2(14, 3), s + 1, 0.0, 12), Color(BONE2, 0.6))
			ci.draw_circle(Vector2(-44, 27), 1.2, INK)
			xeye(ci, Vector2(-28, 20), 2.4, 2.0)
			hl(ci, Vector2(12, 6), 7, 2.5, -0.1, 0.3)
		6:
			## 老鹰：背朝上，两只翅膀完全展开平铺，像个"大"字
			glow(ci, Vector2(0, 0), 54, GOLD)
			var col := Color("6a4428")
			var parts := []
			for sd in [-1.0, 1.0]:
				for k in 5:
					var a: float = (PI if sd < 0.0 else 0.0) + sd * (-0.25 + float(k) * 0.16)
					parts.append(leaf(Vector2(sd * 36.0, -6.0 + float(k) * 1.5), 14.0 - float(k) * 0.8, 3.4, a, s + k + (0 if sd < 0.0 else 10), col.darkened(0.25)))
				parts.append(pg([Vector2(sd * 6.0, -10), Vector2(sd * 22.0, -16), Vector2(sd * 40.0, -12), Vector2(sd * 42.0, 0), Vector2(sd * 30.0, 6), Vector2(sd * 16.0, 10), Vector2(sd * 6.0, 10)], s + 20 + int(sd), col))
				parts.append(stk(Vector2(sd * 6.0, 18), Vector2(sd * 13.0, 24), 2.2, s + 24 + int(sd), GOLD, 2))
			parts.append(pg([Vector2(-6, 14), Vector2(-16, 38), Vector2(0, 41), Vector2(16, 38), Vector2(6, 14)], s + 26, Color("f4f0e8")))
			parts.append(ov(Vector2(0, 2), 10, 18, s + 27, col.darkened(0.1), 0.0, 1))
			parts.append(circ(Vector2(0, -20), 9, s + 28, Color("f4f0e8"), 1))
			parts.append(pg([Vector2(-6, -24), Vector2(-17, -21), Vector2(-15, -14), Vector2(-12, -17), Vector2(-6, -16)], s + 29, GOLD))
			sil(ci, parts, rim)
			for sd in [-1.0, 1.0]:
				ci.draw_colored_polygon(poly([Vector2(sd * 8.0, -8), Vector2(sd * 24.0, -12), Vector2(sd * 30.0, -6), Vector2(sd * 12.0, -2)], s), Color("a8784e", 0.7))
				for k in 4:
					var x: float = sd * (14.0 + float(k) * 6.0)
					ln(ci, Vector2(x, -2), Vector2(x + sd * 2.0, 8), 1.4, Color(INK, 0.4), s + k)
				_h_toes(ci, Vector2(sd * 13.0, 24), PI * 0.5 - sd * 0.5, 4.0, 3, INK, 1.6)
			for k in 3:
				ln(ci, Vector2(-8.0 + float(k) * 8.0, 26), Vector2(-9.0 + float(k) * 9.0, 38), 1.2, Color(INK, 0.3), s + k)
			xeye(ci, Vector2(-3, -21), 2.4, 2.0)
			sparks(ci, [Vector2(-42, -32), Vector2(42, -34), Vector2(38, 30)])

## 换姿势前的画法（游戏里现在不调用）：4 野鸭侧躺 / 5 大雁侧躺 / 6 秃鹫扑倒 / 8 鸵鸟侧倒
static func bird_pose_old(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		4:
			## 野鸭：侧躺，肥肥的身子，绿脖子直直伸在地上，扁扁的黄嘴贴地，橙色蹼脚翘在后面
			var col := Color("9a7a5a")
			var parts := []
			for sd in [0.0, 1.0]:
				var a := Vector2(18.0 + sd * 8.0, 24)
				var b := a + Vector2(10, 8)
				parts.append(stk(a, b, 2.0, s + int(sd), OCHRE, 2))
				parts.append(pg([b + Vector2(-3, -1), b + Vector2(9, 2), b + Vector2(2, 8)], s + 2 + int(sd), OCHRE, 2))
			parts.append(pg([Vector2(30, 4), Vector2(44, 4), Vector2(30, 16)], s + 4, col.darkened(0.25)))
			parts.append(ov(Vector2(10, 12), 25, 17, s + 5, col, 0.0, 1))
			parts.append(stk(Vector2(-10, 10), Vector2(-24, 20), 6.0, s + 6, Color("2f8a4a"), 2))
			parts.append(circ(Vector2(-29, 22), 10, s + 7, Color("2f8a4a"), 1))
			parts.append(ov(Vector2(-43, 28), 9, 4, s + 8, OCHRE, 0.3, 1))
			parts.append(pg([Vector2(-6, 6), Vector2(14, -2), Vector2(34, 10), Vector2(22, 20), Vector2(4, 18)], s + 9, Color("7a5e44")))
			sil(ci, parts, rim)
			ci.draw_colored_polygon(poly([Vector2(12, 4), Vector2(24, 7), Vector2(22, 13), Vector2(10, 10)], s), Color("3a6ac8"))
			ln(ci, Vector2(-13, 9), Vector2(-16, 17), 2.8, BONE, s)
			ci.draw_colored_polygon(ell(Vector2(8, 24), Vector2(17, 3.5), s + 1, 0.0, 12), Color(BONE2, 0.6))
			ci.draw_circle(Vector2(-46, 27), 1.3, INK)
			xeye(ci, Vector2(-29, 19), 2.6, 2.0)
			hl(ci, Vector2(10, 0), 8, 3, -0.1, 0.3)
		5:
			## 大雁：侧躺，灰褐色的身子，翅膀上一道道浅色横纹，长脖子伸在地上，后颈一道深褐条纹，黑嘴
			var col := Color("8c7b66")
			var neck := Color("cdbf9f")
			var parts := []
			for sd in [0.0, 1.0]:
				var a := Vector2(20.0 + sd * 9.0, 24)
				var b := a + Vector2(10, 9)
				parts.append(stk(a, b, 2.2, s + int(sd), Color("e8925a"), 2))
				parts.append(pg([b + Vector2(-3, -1), b + Vector2(10, 2), b + Vector2(2, 9)], s + 2 + int(sd), Color("e8925a"), 2))
			parts.append(pg([Vector2(32, 0), Vector2(48, 2), Vector2(34, 14)], s + 4, col.darkened(0.3)))
			parts.append(ov(Vector2(10, 10), 27, 18, s + 5, col, 0.0, 1))
			parts.append(pg([Vector2(-6, 2), Vector2(16, -9), Vector2(40, 4), Vector2(28, 18), Vector2(4, 16)], s + 6, col.darkened(0.15), 1))
			parts.append(stk(Vector2(-10, 8), Vector2(-27, 19), 6.0, s + 7, neck, 2))
			parts.append(stk(Vector2(-27, 19), Vector2(-35, 25), 5.4, s + 8, neck, 2))
			parts.append(circ(Vector2(-39, 26), 8.5, s + 9, neck, 1))
			parts.append(pg([Vector2(-45, 24), Vector2(-58, 29), Vector2(-45, 32)], s + 10, Color("2b2430")))
			sil(ci, parts, rim)
			pl(ci, [Vector2(-8, 3), Vector2(-20, 10), Vector2(-30, 17), Vector2(-37, 19.5)], 2.4, Color("5a4430"), s)
			for row in 2:
				for k in 4:
					var c := Vector2(6.0 + float(k) * 7.5 + float(row) * 3.5, 1.0 + float(row) * 7.0 + float(k) * 0.6)
					pl(ci, arcp(c, Vector2(3.8, 2.8), PI * 0.05, PI * 0.95, 6), 1.5, Color(BONE2, 0.8), s + k + row * 4)
			ci.draw_colored_polygon(ell(Vector2(8, 23), Vector2(18, 4), s + 1, 0.0, 12), Color("ece4d4"))
			xeye(ci, Vector2(-40, 23), 2.6, 2.0)
			hl(ci, Vector2(12, -2), 9, 3, -0.1, 0.3)
		6:
			## 秃鹫：扑倒在地，两边大翅膀像斗篷一样摊下来，光秃秃的长脖子伸在地上
			var col := Color("4a3a30")
			var parts := []
			parts.append(pg([Vector2(-4, -4), Vector2(-20, 6), Vector2(-26, 30), Vector2(-6, 26)], s, col.darkened(0.3)))
			var wing := [Vector2(-4, -6), Vector2(18, -14), Vector2(36, -2)]
			for k in 7:
				var x := lerpf(44.0, 4.0, float(k) / 6.0)
				wing.append(Vector2(x, 32.0 if k % 2 == 0 else 26.0))
			parts.append(pg([Vector2(30, 14), Vector2(46, 18), Vector2(40, 28)], s + 1, col.darkened(0.15)))
			parts.append(ov(Vector2(10, 10), 20, 15, s + 2, col, 0.0, 1))
			parts.append(pg(wing, s + 3, col.darkened(0.08), 1))
			parts.append(ov(Vector2(-10, 4), 10, 9, s + 4, BONE2, 0.0, 1))
			parts.append(stk(Vector2(-14, 8), Vector2(-28, 24), 3.6, s + 5, PINK.darkened(0.15), 2))
			parts.append(circ(Vector2(-31, 26), 7, s + 6, PINK.darkened(0.15), 1))
			parts.append(pg([Vector2(-36, 22), Vector2(-46, 26), Vector2(-42, 32), Vector2(-36, 30)], s + 7, BONE2))
			sil(ci, parts, rim)
			for k in 5:
				var x := 10.0 + float(k) * 7.0
				ln(ci, Vector2(x - 4, 0), Vector2(x, 26), 1.6, Color(INK, 0.45), s + k)
			for k in 4:
				ln(ci, Vector2(-16.0 + float(k) * 4.0, 0), Vector2(-15.0 + float(k) * 4.0, 8), 1.2, Color(INK, 0.25), s + k)
			ln(ci, Vector2(-44, 28), Vector2(-38, 28), 1.4, Color(INK, 0.6), s)
			xeye(ci, Vector2(-30, 24), 2.4, 2.0)
			hl(ci, Vector2(14, -4), 7, 2.5, -0.3, 0.25)
		8:
			## 鸵鸟：最大的一只。侧倒在地，一身蓬松的黑羽，翅膀和尾巴各一簇白羽，两条粉色长腿伸出去，长脖子弯在地上，小脑袋
			glow(ci, Vector2(0, 0), 58, GOLD)
			var skin := Color("e3a58e")
			var parts := []
			parts.append(stk(Vector2(22, 18), Vector2(37, 25), 5.4, s, skin.darkened(0.12), 2))
			parts.append(stk(Vector2(37, 25), Vector2(46, 33), 3.2, s + 1, skin.darkened(0.12), 2))
			for k in 3:
				parts.append(leaf(Vector2(30, -6), 26.0 - float(k) * 3.0, 8.0, -0.9 + float(k) * 0.45, s + 2 + k, Color("f4f0e8")))
			parts.append(_h_shag(Vector2(6, 4), Vector2(30, 24), 26, 1.12, s + 6, Color("2e2a2c"), -1.1))
			parts.append(stk(Vector2(12, 22), Vector2(26, 31), 6.0, s + 7, skin, 2))
			parts.append(stk(Vector2(26, 31), Vector2(40, 37), 3.4, s + 8, skin, 2))
			for k in 3:
				parts.append(leaf(Vector2(-6, -6), 26.0 - float(k) * 3.0, 7.5, -0.35 + float(k) * 0.32, s + 10 + k, Color("f4f0e8")))
			parts.append(stk(Vector2(-18, 8), Vector2(-29, 19), 5.2, s + 14, Color("d9bcae"), 2))
			parts.append(stk(Vector2(-29, 19), Vector2(-36, 29), 4.4, s + 15, Color("d9bcae"), 2))
			parts.append(stk(Vector2(-36, 29), Vector2(-42, 32), 4.0, s + 16, Color("d9bcae"), 2))
			parts.append(ov(Vector2(-46, 30), 7, 6, s + 17, Color("b8a8a0"), 0.0, 1))
			parts.append(pg([Vector2(-51, 29), Vector2(-58, 32), Vector2(-51, 34)], s + 18, Color("e8c8a0"), 2))
			sil(ci, parts, rim)
			for k in 6:
				var x := -12.0 + float(k) * 7.0
				pl(ci, [Vector2(x, 2.0 + float(k % 2) * 3.0), Vector2(x + 3, 9), Vector2(x + 1, 16)], 1.4, Color(1, 1, 1, 0.18), s + k)
			for leg in [[Vector2(40, 37), 0.1], [Vector2(46, 33), -0.4]]:
				_h_toes(ci, leg[0], leg[1], 5.0, 2, INK, 2.0)
			ln(ci, Vector2(-22, 11), Vector2(-26, 15), 1.2, Color(INK, 0.3), s)
			xeye(ci, Vector2(-47, 28), 2.2, 1.8)
			hl(ci, Vector2(-2, -14), 8, 3, -0.2, 0.3)
			sparks(ci, [Vector2(-44, -36), Vector2(46, -38), Vector2(50, 10)])
