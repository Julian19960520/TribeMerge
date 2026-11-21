class_name PACloth
extends PA
## 衣服线：晾架→皮匠作坊（生产器）/ 植物料（主产物：草、麻、棕榈、藤）/ 兽毛兽皮（副产物：兽毛、兽皮、毛皮）
## 旧画法 gen_old / main_old / sub_old 是原来的编织架、衣物、部落饰品，现在作为成品留着以后用；
## _main_art_v1 / _sub_art_v1 是上一版的衣服材料、作坊珍品。

const BARK := Color("8a735c")
const FLAX := Color("a9b25e")
const BUCK := Color("d9b47a")
const IVORY := Color("f1e6c8")
const PLUME := Color("f2ede2")

static func _vest(sc: float = 1.0, oy: float = 0.0) -> Array:
	var base := [Vector2(-14, -36), Vector2(-6, -30), Vector2(0, -12), Vector2(6, -30), Vector2(14, -36), Vector2(32, -28),
		Vector2(30, -6), Vector2(26, 36), Vector2(-26, 36), Vector2(-30, -6), Vector2(-32, -28)]
	var out := []
	for p in base:
		out.append((p as Vector2) * sc + Vector2(0, oy))
	return out

static func _tunic(sc: float = 1.0, oy: float = 0.0) -> Array:
	var base := [Vector2(-14, -36), Vector2(0, -26), Vector2(14, -36), Vector2(30, -30), Vector2(46, -8), Vector2(36, 0),
		Vector2(28, -10), Vector2(28, 38), Vector2(-28, 38), Vector2(-28, -10), Vector2(-36, 0), Vector2(-46, -8), Vector2(-30, -30)]
	var out := []
	for p in base:
		out.append((p as Vector2) * sc + Vector2(0, oy))
	return out

static func _strands(ci: CanvasItem, x0: float, x1: float, y0: float, y1: float, n: int, col: Color, s: int) -> void:
	for k in n:
		var x := lerpf(x0, x1, float(k) / float(n - 1))
		ln(ci, Vector2(x, y0), Vector2(x * 1.08, y1), 1.6, col, s + k)

static func _loom(c: Vector2, w: float, h: float, s: int) -> Array:
	return [stk(c + Vector2(-w, -h), c + Vector2(-w, h), 4.0, s, WOOD_D), stk(c + Vector2(w, -h), c + Vector2(w, h), 4.0, s + 1, WOOD_D),
		stk(c + Vector2(-w - 6, -h + 4), c + Vector2(w + 6, -h + 4), 4.0, s + 2, WOOD)]

## 一根绳拆成几段，能一起进剪影
static func _cl_cord(pts: Array, r: float, s: int, col: Color = ROPE) -> Array:
	var out := []
	for i in pts.size() - 1:
		out.append(stk(pts[i], pts[i + 1], r, s + i, col, 2))
	return out

## 细绳（项链、挂绳）：不进剪影，只描一道细黑边
static func _cl_string(ci: CanvasItem, pts: Array, s: int, w: float = 2.0, col: Color = ROPE) -> void:
	pl(ci, pts, w + 2.4, INK, s)
	pl(ci, pts, w, col, s)

## 羽毛的细节：羽轴、几道羽枝、染色的羽尖、可选的横纹
static func _cl_feather(ci: CanvasItem, base: Vector2, l: float, w: float, ang: float, s: int, tip: Color, bars: Color = Color(0, 0, 0, 0), tipa: float = 1.12) -> void:
	var d := Vector2(cos(ang), sin(ang))
	var n := Vector2(-d.y, d.x)
	if tip.a > 0.0:
		var tp := []
		for k in 11:
			var th := lerpf(-tipa, tipa, float(k) / 10.0)
			tp.append(base + d * (l * 0.5 + cos(th) * l * 0.5) + n * sin(th) * w)
		ci.draw_colored_polygon(PackedVector2Array(tp), tip)
	if bars.a > 0.0:
		for t in [0.42, 0.56]:
			var tf: float = t
			var hw := w * sqrt(maxf(1.0 - pow(tf * 2.0 - 1.0, 2.0), 0.0)) * 0.9
			ln(ci, base + d * l * tf - n * hw, base + d * l * tf + n * hw, 2.6, bars, s)
	ln(ci, base + d * l * 0.04, base + d * l * 0.9, 1.3, Color(INK, 0.5), s)
	for k in 4:
		var p := base + d * l * (0.28 + float(k) * 0.15)
		var sd := 1.0 if k % 2 == 0 else -1.0
		ln(ci, p, p + (d * 0.4 + n * sd) * w * 0.7, 1.0, Color(INK, 0.25), s + k)

## 扇贝：c 是铰合处，扇面朝 ang 方向张开
static func _cl_scallop_pts(c: Vector2, r: float, ang: float) -> Array:
	var pts := [Vector2(-r * 0.42, -r * 0.14), Vector2(r * 0.42, -r * 0.14), Vector2(r * 0.3, r * 0.02)]
	for k in 15:
		var a := lerpf(0.4, PI - 0.4, float(k) / 14.0)
		var rr := r if k % 2 == 0 else r * 0.92
		pts.append(Vector2(cos(a), sin(a)) * rr)
	pts.append(Vector2(-r * 0.3, r * 0.02))
	return rot_pts(pts, ang - PI * 0.5, c)

static func _cl_scallop(c: Vector2, r: float, ang: float, s: int, col: Color = SHELL) -> Array:
	return pg(_cl_scallop_pts(c, r, ang), s, col, 0)

static func _cl_scallop_det(ci: CanvasItem, c: Vector2, r: float, ang: float, s: int) -> void:
	for k in 5:
		var a := lerpf(0.7, PI - 0.7, float(k) / 4.0)
		var e := Vector2(cos(a), sin(a)) * r * 0.86
		ln(ci, c + Vector2(0, r * 0.08).rotated(ang - PI * 0.5), c + e.rotated(ang - PI * 0.5), 1.3, Color("c48c78"), s + k)

## 一颗挂着的弯牙：top 是挂点，bend 控制牙尖往哪边弯
static func _cl_tooth(top: Vector2, l: float, w: float, bend: float, s: int, col: Color = IVORY) -> Array:
	var lt := []
	var rt := []
	for k in 7:
		var t := float(k) / 6.0
		var cx := bend * l * t * t
		var hw := w * (1.0 - t * 0.9)
		lt.append(top + Vector2(cx - hw, t * l))
		rt.append(top + Vector2(cx + hw, t * l))
	rt.reverse()
	return pg(lt + rt, s, col, 1)

## 沿圆弧的一根獠牙：从 a0（粗根）长到 a1（尖）
static func _cl_horn(c: Vector2, r: float, a0: float, a1: float, w: float, s: int, col: Color = IVORY) -> Array:
	var outer := []
	var inner := []
	for k in 11:
		var t := float(k) / 10.0
		var a := lerpf(a0, a1, t)
		var hw := w * (1.0 - t * 0.9) * 0.5
		outer.append(c + Vector2(cos(a), sin(a)) * (r + hw))
		inner.append(c + Vector2(cos(a), sin(a)) * (r - hw))
	inner.reverse()
	return pg(outer + inner, s, col, 1)

## 略带俯视的一圈箍（臂环、头箍）：顶口整圈 + 前半圈的箍身
static func _cl_cyl(yt: float, yb: float, rx: float, ry: float, s: int, col: Color) -> Array:
	var body := arcp(Vector2(0, yt), Vector2(rx, ry), 0.0, PI, 14)
	body.append_array(arcp(Vector2(0, yb), Vector2(rx, ry), PI, 0.0, 14))
	return [ov(Vector2(0, yt), rx, ry, s, col.darkened(0.12), 0.0, 0), pg(body, s + 1, col, 0)]

static func _cl_hole(ci: CanvasItem, yt: float, rx: float, ry: float, s: int) -> void:
	var h := ell(Vector2(0, yt), Vector2(rx - 4.0, maxf(ry - 3.0, 2.0)), s, 0.0, 18)
	ci.draw_colored_polygon(h, Color("3a2416"))
	outline(ci, h, 1.2)

static func _cl_mx(y: float) -> float:
	return lerpf(-28.0, -40.0, (y + 12.0) / 38.0) + 3.0

## 旧生产器：编织架 8 级（亚麻束 … 长老织机）
static func gen_old(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			## 亚麻束：一把割下的亚麻茎秆，腰上捆一道，上下都散开；顶上几朵小蓝花和籽球
			var parts := []
			var tips := []
			for k in 9:
				var t := float(k) / 8.0
				var mid := Vector2(lerpf(-6.0, 6.0, t), 10)
				var tip := Vector2(lerpf(-26.0, 26.0, t), -24.0 - sin(t * PI) * 12.0)
				var col := FLAX if k % 2 == 0 else FLAX.darkened(0.12)
				parts.append(stk(Vector2(lerpf(-14.0, 14.0, t), 38), mid, 2.0, s + k, col, 2))
				parts.append(stk(mid, tip, 2.0, s + k + 10, col, 2))
				tips.append(tip)
				if k % 3 == 0:
					parts.append(circ(tip, 3.2, s + k + 20, GRASS, 2))
			parts.append(bx(-11, 5, 22, 10, 3, s + 40, ROPE))
			sil(ci, parts, rim)
			for k in 3:
				var tp: Vector2 = tips[1 + k * 3]
				var fl := star_pts(tp, 8.0, 3.6, 5, s + k)
				ci.draw_colored_polygon(fl, SKY)
				outline(ci, fl, 1.2)
				ci.draw_circle(tp, 2.2, GOLD)
			for y in [7.0, 12.0]:
				ln(ci, Vector2(-10, y), Vector2(10, y + 1.0), 1.4, Color(INK, 0.45), s)
		2:
			## 晾麻架：两个人字木架挑一根横杆，上面搭着一绺绺晾干的麻
			var parts := [stk(Vector2(-40, 38), Vector2(-24, -34), 3.4, s, WOOD_D), stk(Vector2(-8, 38), Vector2(-24, -34), 3.4, s + 1, WOOD_D),
				stk(Vector2(40, 38), Vector2(24, -34), 3.4, s + 2, WOOD_D), stk(Vector2(8, 38), Vector2(24, -34), 3.4, s + 3, WOOD_D),
				stk(Vector2(-34, -26), Vector2(34, -26), 3.0, s + 4, WOOD)]
			for k in 4:
				var x := -18.0 + float(k) * 12.0
				parts.append(pg([Vector2(x - 5, -26), Vector2(x + 5, -26), Vector2(x + 4, 8), Vector2(x - 4, 8)], s + 10 + k, FLAX if k % 2 == 0 else FLAX.darkened(0.12)))
			sil(ci, parts, rim)
			for k in 4:
				var x := -18.0 + float(k) * 12.0
				for j in 2:
					ln(ci, Vector2(x - 2.0 + float(j) * 4.0, -20), Vector2(x - 2.0 + float(j) * 4.0, 6), 1.2, Color(INK, 0.3), s + k + j)
				ln(ci, Vector2(x - 5, -22), Vector2(x + 5, -22), 2.0, ROPE.darkened(0.15), s + k)
		3:
			## 编草框：平放在地上的小木框，前半截已经编出草席，后半截还是一根根经草
			var A := Vector2(-28, -12)
			var B := Vector2(28, -12)
			var C := Vector2(40, 26)
			var D := Vector2(-40, 26)
			sil(ci, [pg([A, B, C, D], s + 9, Color("6e5a34"), 0), stk(A + Vector2(-5, 0), B + Vector2(5, 0), 3.4, s, WOOD),
				stk(D + Vector2(-6, 0), C + Vector2(6, 0), 3.6, s + 1, WOOD), stk(A, D, 3.4, s + 2, WOOD), stk(B, C, 3.4, s + 3, WOOD)], rim)
			for k in 8:
				var t := (float(k) + 0.5) / 8.0
				ln(ci, Vector2(lerpf(-25.0, 25.0, t), -9), Vector2(lerpf(-36.0, 36.0, t), 23), 2.0, GRASS, s + k)
			var mat := [Vector2(_cl_mx(6.0), 6), Vector2(-_cl_mx(6.0), 6), Vector2(-_cl_mx(23.0), 23), Vector2(_cl_mx(23.0), 23)]
			ci.draw_colored_polygon(PackedVector2Array(mat), GRASS)
			for r in 5:
				var y := 8.0 + float(r) * 3.4
				ln(ci, Vector2(_cl_mx(y), y), Vector2(-_cl_mx(y), y), 1.0, Color(INK, 0.3), s + r)
				for k in 8:
					var t := (float(k) + (0.25 if r % 2 == 0 else 0.75)) / 8.0
					var x := lerpf(_cl_mx(y), -_cl_mx(y), t)
					ln(ci, Vector2(x, y), Vector2(x, y + 3.0), 1.4, GRASS_D, s + k)
			outline(ci, PackedVector2Array(mat), 1.4)
			pl(ci, [Vector2(20, 6), Vector2(30, 0), Vector2(36, -8), Vector2(46, -10)], 2.2, GRASS_D, s)
			sil(ci, [stk(A + Vector2(-5, 0), B + Vector2(5, 0), 3.4, s, WOOD), stk(D + Vector2(-6, 0), C + Vector2(6, 0), 3.6, s + 1, WOOD)], false)
			for p in [A, B, C, D]:
				ci.draw_circle(p, 4.0, ROPE)
				ci.draw_arc(p, 4.0, 0, TAU, 12, INK, 1.2, true)
		4:
			## 地桩织架：两根木桩打进地里，上下两根横杆绷着经线，上半截已经织出一段布
			var parts := [ov(Vector2(0, 36), 46, 8, s + 9, Color("8a6a44"), 0.0, 0),
				stk(Vector2(-34, 38), Vector2(-34, -32), 3.6, s, WOOD_D), stk(Vector2(34, 38), Vector2(34, -32), 3.6, s + 1, WOOD_D),
				stk(Vector2(-42, -24), Vector2(42, -24), 3.4, s + 2, WOOD), stk(Vector2(-40, 26), Vector2(40, 26), 3.4, s + 3, WOOD)]
			sil(ci, parts, rim)
			for k in 9:
				var x := lerpf(-26.0, 26.0, float(k) / 8.0)
				ln(ci, Vector2(x, -21), Vector2(x, 23), 1.6, ROPE.darkened(0.2), s + k)
			ci.draw_rect(Rect2(-28, -20, 56, 20), ROPE)
			weave(ci, Rect2(-28, -20, 56, 20), s)
			ci.draw_rect(Rect2(-28, -20, 56, 20), INK, false, 1.4)
			sil(ci, [stk(Vector2(-32, 6), Vector2(32, 6), 2.2, s + 5, BONE2, 2), stk(Vector2(-40, 26), Vector2(40, 26), 3.4, s + 3, WOOD)], false)
			for p in [Vector2(-34, -24), Vector2(34, -24), Vector2(-34, 26), Vector2(34, 26)]:
				ci.draw_circle(p, 4.0, ROPE)
				ci.draw_arc(p, 4.0, 0, TAU, 12, INK, 1.2, true)
		5:
			## 腰织机：经线一头绑在木桩上，一头绑在胸前横棍上，皮带兜到织工背后；已织出一段彩条布，骨梭横在中间
			var A := Vector2(24, -24)
			var B := Vector2(-16, 16)
			var d := (B - A).normalized()
			var n := Vector2(-d.y, d.x)
			var hw := 18.0
			var outer := []
			var inner := []
			for k in 13:
				var th := lerpf(-PI * 0.5, PI * 0.5, float(k) / 12.0)
				outer.append(B + n * (hw + 2.0) * sin(th) + d * 24.0 * cos(th))
				inner.append(B + n * (hw - 3.0) * sin(th) + d * 18.0 * cos(th))
			inner.reverse()
			var warp := [A + n * hw * 0.85, A - n * hw * 0.85, B - n * hw * 0.85, B + n * hw * 0.85]
			var far := stk(A + n * (hw + 4.0), A - n * (hw + 4.0), 3.2, s + 2, WOOD)
			var near := stk(B + n * (hw + 4.0), B - n * (hw + 4.0), 3.4, s + 3, WOOD)
			sil(ci, [stk(Vector2(44, 40), Vector2(44, -40), 4.0, s, WOOD_D), pg(outer + inner, s + 1, LEATHER, 0),
				pg(warp, s + 4, Color("efe0b8"), 0), far, near], rim)
			for k in 9:
				var t := lerpf(-0.85, 0.85, float(k) / 8.0)
				ln(ci, A + n * hw * t, B + n * hw * t, 1.3, ROPE.darkened(0.2), s + k)
			var C := B + (A - B) * 0.45
			var cloth := PackedVector2Array([B + n * hw * 0.9, B - n * hw * 0.9, C - n * hw * 0.9, C + n * hw * 0.9])
			ci.draw_colored_polygon(cloth, Color("efdcb0"))
			for st in [[0.1, 0.2, CLAY], [0.28, 0.36, TEAL]]:
				var p0 := B + (A - B) * float(st[0])
				var p1 := B + (A - B) * float(st[1])
				ci.draw_colored_polygon(PackedVector2Array([p0 + n * hw * 0.9, p0 - n * hw * 0.9, p1 - n * hw * 0.9, p1 + n * hw * 0.9]), st[2])
			outline(ci, cloth, 1.4)
			ln(ci, A + n * (hw + 2.0), Vector2(44, -34), 2.0, ROPE, s)
			ln(ci, A - n * (hw + 2.0), Vector2(44, -18), 2.0, ROPE, s + 1)
			var sh := B + (A - B) * 0.55
			sil(ci, [far, near, stk(sh + n * (hw + 9.0), sh - n * (hw + 9.0), 2.2, s + 6, BONE2, 2)], false)
		6:
			## 坠石织机：一人高的竖框，上面织着彩条布，下垂的经线一束束坠着陶土圆坠
			sil(ci, _loom(Vector2(0, -4), 34, 40, s), rim)
			var cloth := Rect2(-28, -38, 56, 30)
			ci.draw_rect(cloth, BONE2)
			for k in 3:
				ci.draw_rect(Rect2(-28, -34.0 + float(k) * 8.0, 56, 4), [CLAY, TEAL, OCHRE][k])
			ci.draw_rect(cloth, INK, false, 1.6)
			var weights := []
			for g in 5:
				var x := -22.0 + float(g) * 11.0
				for j in 3:
					ln(ci, Vector2(x - 4.0 + float(j) * 4.0, -8), Vector2(x, 22), 1.3, ROPE.darkened(0.2), s + g + j)
				weights.append(circ(Vector2(x, 27), 6.0, s + 20 + g, CLAYPOT))
			sil(ci, weights + [stk(Vector2(-40, 2), Vector2(40, 2), 2.2, s + 8, BONE2, 2)], false)
			for g in 5:
				ci.draw_circle(Vector2(-22.0 + float(g) * 11.0, 27), 1.8, INK)
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

## 旧主产物：衣物 13 级（草腰绳 … 酋长礼袍），现为成品
static func main_old(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			## 草腰绳：搓好的草绳绕成一圈当腰绳，前面打个结，垂下两根穗头
			var c := Vector2(0, -8)
			var back := []
			var front := []
			for k in 16:
				var a0 := TAU * float(k) / 16.0
				var a1 := TAU * float(k + 1) / 16.0
				var seg := stk(c + Vector2(cos(a0) * 32.0, sin(a0) * 12.0), c + Vector2(cos(a1) * 32.0, sin(a1) * 12.0), 3.4, s + k, GRASS_D if sin(a0 + 0.2) < 0.0 else GRASS)
				if sin(a0 + 0.2) < 0.0:
					back.append(seg)
				else:
					front.append(seg)
			var tas := [stk(Vector2(-2, 8), Vector2(-9, 32), 2.6, s + 30, GRASS, 2), stk(Vector2(2, 8), Vector2(7, 34), 2.6, s + 31, GRASS, 2),
				pg([Vector2(-9, 30), Vector2(-15, 42), Vector2(-3, 42)], s + 32, GRASS_D), pg([Vector2(7, 32), Vector2(1, 44), Vector2(13, 44)], s + 33, GRASS_D)]
			sil(ci, back + tas + front + [circ(Vector2(0, 5), 6, s + 40, GRASS)], rim)
			for k in 9:
				var a := lerpf(0.25, PI - 0.25, float(k) / 8.0)
				var p := c + Vector2(cos(a) * 32.0, sin(a) * 12.0)
				ln(ci, p + Vector2(-2, -3), p + Vector2(2, 3), 1.4, GRASS_D, s + k)
			ln(ci, Vector2(-4, 3), Vector2(4, 7), 1.4, GRASS_D, s)
		2:
			## 草腰带：编成宽带的草腰带，正中系个结，垂下四根草穗
			var parts := [bx(-42, -10, 84, 14, 6, s, GRASS), pg([Vector2(-8, -14), Vector2(8, -14), Vector2(10, 8), Vector2(-10, 8)], s + 1, GRASS_D)]
			for k in 4:
				var x := -9.0 + float(k) * 6.0
				parts.append(stk(Vector2(x, 6), Vector2(x * 1.4, 34), 2.2, s + 2 + k, GRASS, 2))
			sil(ci, parts, rim)
			for k in 10:
				var x := -38.0 + float(k) * 8.4
				ln(ci, Vector2(x, -8), Vector2(x + 4, 2), 1.4, GRASS_D, s + k)
		3:
			## 草裙：皮腰头上挂一圈齐膝的草穗
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
		4:
			## 树叶裙：草绳腰带上挂两层大树叶，后排长、前排短
			var parts := []
			for k in 7:
				var x := -27.0 + float(k) * 9.0
				parts.append(leaf(Vector2(x, -12), 46, 7.5, PI * 0.5 + x * 0.009, s + k, LEAF_D.lightened(0.08)))
			for k in 6:
				var x := -22.5 + float(k) * 9.0
				parts.append(leaf(Vector2(x, -10), 36, 7, PI * 0.5 + x * 0.009, s + 10 + k, LEAF))
			parts.append(stk(Vector2(-36, -14), Vector2(36, -14), 3.4, s + 30, ROPE))
			parts.append(stk(Vector2(30, -12), Vector2(36, 4), 2.0, s + 31, ROPE, 2))
			sil(ci, parts, rim)
			for k in 6:
				var x := -22.5 + float(k) * 9.0
				vein(ci, Vector2(x, -10), 36, PI * 0.5 + x * 0.009, s + k)
			ci.draw_circle(Vector2(30, -14), 3.6, ROPE.darkened(0.15))
		5:
			## 树叶披肩：围着领口三层树叶一层压一层往下垂，领口一圈草绳系着
			var neck := Vector2(0, -26)
			var rows := [[9, 48.0, 8.0, LEAF_D.lightened(0.05)], [8, 34.0, 7.0, LEAF], [7, 21.0, 6.0, LEAF.lightened(0.12)]]
			var fs := []
			for r in 3:
				var cfg: Array = rows[r]
				var n: int = cfg[0]
				for k in n:
					var a := lerpf(0.15, PI - 0.15, float(k) / float(n - 1))
					fs.append([neck + Vector2(cos(a) * 13.0, sin(a) * 5.0), cfg[1], cfg[2], a, cfg[3]])
			var parts := []
			for f in fs:
				parts.append(leaf(f[0], f[1], f[2], f[3], s + parts.size(), f[4]))
			sil(ci, parts, rim)
			for i in fs.size():
				var f: Array = fs[i]
				sil(ci, [parts[i]], false)
				vein(ci, f[0], f[1], f[3], s + i)
			var col := arcp(neck, Vector2(15, 6), 0.0, TAU, 20)
			pl(ci, col, 5.0, INK, s)
			pl(ci, col, 3.2, ROPE, s)
			pl(ci, [Vector2(-2, -20), Vector2(-6, -6)], 2.2, ROPE, s)
			pl(ci, [Vector2(2, -20), Vector2(5, -8)], 2.2, ROPE, s + 1)
			ci.draw_circle(Vector2(0, -20), 3.2, ROPE.darkened(0.15))
		6:
			## 草编蓑衣：四层草片一层压一层，越往下越宽，领口草绳扎紧（长到膝盖的雨披）
			var tiers := []
			for t in range(3, -1, -1):
				var y0 := -28.0 + float(t) * 15.0
				var y1 := y0 + 24.0
				var w0 := 10.0 + float(t) * 8.0
				var w1 := 18.0 + float(t) * 9.0
				var pts := [Vector2(-w0, y0), Vector2(w0, y0)]
				var nz := 6 + t * 2
				for k in nz + 1:
					pts.append(Vector2(lerpf(w1, -w1, float(k) / float(nz)), y1 + (4.0 if k % 2 == 0 else -2.0)))
				tiers.append([pg(pts, s + t, GRASS if t % 2 == 0 else GRASS.darkened(0.08), 0), y0, y1, w0, w1])
			var parts := []
			for tr in tiers:
				parts.append(tr[0])
			var collar := bx(-13, -34, 26, 8, 3, s + 10, ROPE)
			sil(ci, parts + [collar], rim)
			for tr in tiers:
				sil(ci, [tr[0]], false)
				var y0: float = tr[1]
				var y1: float = tr[2]
				var w0: float = tr[3]
				var w1: float = tr[4]
				for k in 7:
					var t := (float(k) + 0.5) / 7.0
					ln(ci, Vector2(lerpf(-w0, w0, t), y0 + 3.0), Vector2(lerpf(-w1, w1, t), y1 - 2.0), 1.2, Color(GRASS_D.darkened(0.2), 0.6), s + k)
			sil(ci, [collar], false)
			pl(ci, [Vector2(0, -26), Vector2(-4, -14)], 2.2, ROPE, s)
			pl(ci, [Vector2(0, -26), Vector2(5, -15)], 2.2, ROPE, s + 1)
		7:
			## 树皮衣：捶软的灰褐树皮缝成短袖衣，竖着的树皮纹，腰上一道草绳
			sil(ci, [pg(_tunic(), s, BARK, 0)], rim)
			for k in 6:
				var x := -20.0 + float(k) * 8.0
				pl(ci, [Vector2(x, -18), Vector2(x + 2, 0), Vector2(x - 1, 16), Vector2(x + 1, 34)], 1.5, Color(INK, 0.4), s + k)
			for k in 7:
				var p := Vector2(-22.0 + float(k) * 7.4, -6.0 + float((k * 5) % 7) * 5.0)
				ln(ci, p, p + Vector2(4, 0), 1.6, Color(BONE2, 0.5), s + k)
			pl(ci, [Vector2(-28, 10), Vector2(0, 14), Vector2(28, 10)], 4.0, ROPE, s)
			ci.draw_circle(Vector2(-4, 13), 3.0, ROPE.darkened(0.2))
		8:
			## 羽毛披风：一排排黄、红羽毛像瓦片一样从下往上压着铺满，领口一道皮边配骨扣
			var rows := [[14.0, 34.0, 7, Color("e8b23a")], [2.0, 28.0, 6, Color("c8463a")], [-10.0, 22.0, 5, Color("e8b23a")], [-22.0, 16.0, 4, Color("c8463a")]]
			var fs := []
			for cfg in rows:
				var y: float = cfg[0]
				var w: float = cfg[1]
				var n: int = cfg[2]
				for k in n:
					var x := lerpf(-w, w, float(k) / float(n - 1))
					fs.append([Vector2(x, y), 25.0, 6.5, PI * 0.5 + x * 0.006, cfg[3]])
			var parts := []
			for f in fs:
				parts.append(leaf(f[0], f[1], f[2], f[3], s + parts.size(), f[4]))
			var collar := bx(-19, -32, 38, 10, 4, s + 50, LEATHER)
			sil(ci, parts + [collar], rim)
			for i in fs.size():
				var f: Array = fs[i]
				sil(ci, [parts[i]], false)
				_cl_feather(ci, f[0], f[1], f[2], f[3], s + i, Color(0, 0, 0, 0))
			sil(ci, [collar, stk(Vector2(-6, -27), Vector2(6, -27), 2.2, s + 51, BONE2, 2)], false)
		9:
			## 鞣皮坎肩：浅黄的鞣制鹿皮，沿边一圈针脚，前襟皮绳交叉系着，下摆剪成短流苏
			var fr := []
			for k in 9:
				fr.append(stk(Vector2(-24.0 + float(k) * 6.0, 32), Vector2(-25.0 + float(k) * 6.25, 44), 1.8, s + 20 + k, BUCK, 2))
			fr.append(pg(_vest(), s, BUCK, 0))
			sil(ci, fr, rim)
			dashed(ci, poly(_vest(0.84), s), 4, 3, LEATHER_D, 1.4)
			ln(ci, Vector2(0, -12), Vector2(0, 36), 2.0, INK, s)
			for y in [-2.0, 10.0, 22.0]:
				ln(ci, Vector2(-5, y), Vector2(5, y + 7.0), 2.0, LEATHER_D, s)
				ln(ci, Vector2(5, y), Vector2(-5, y + 7.0), 2.0, LEATHER_D, s + 1)
			hl(ci, Vector2(-18, -14), 4, 9, -0.2, 0.35)
		10:
			## 流苏皮衫：带袖的鞣皮长衫，袖口和下摆垂一排长流苏，胸前一道彩珠绣带
			var col := Color("c99a62")
			var body := _tunic(0.9, -6.0)
			var parts := []
			for k in 4:
				var t := float(k) / 3.0
				for sd in [-1.0, 1.0]:
					var p := Vector2(lerpf(41.4, 32.4, t) * sd, lerpf(-13.2, -6.0, t))
					parts.append(stk(p, p + Vector2(1.5 * sd, 12), 1.6, s + k, col, 2))
			for k in 9:
				var x := -23.0 + float(k) * 5.75
				parts.append(stk(Vector2(x, 26), Vector2(x * 1.05, 40), 1.7, s + 10 + k, col, 2))
			parts.append(pg(body, s, col, 0))
			sil(ci, parts, rim)
			ci.draw_rect(Rect2(-25, -18, 50, 7), LEATHER_D)
			for k in 8:
				ci.draw_circle(Vector2(-21.0 + float(k) * 6.0, -14.5), 2.3, [TEAL, BERRY, BONE2][k % 3])
			ci.draw_rect(Rect2(-25, -18, 50, 7), INK, false, 1.2)
			pl(ci, [Vector2(-8, -29), Vector2(0, -20), Vector2(8, -29)], 1.6, Color(INK, 0.6), s)
			dashed(ci, poly([Vector2(-24, 22), Vector2(24, 22)], s), 4, 3, LEATHER_D, 1.2)
		11:
			## 毛皮斗篷：深棕兽毛的长斗篷，领口一圈蓬松的白毛，下摆参差的毛尖，胸前骨扣
			var cloak := [Vector2(-18, -30), Vector2(18, -30), Vector2(40, 30)]
			for k in 9:
				cloak.append(Vector2(lerpf(36.0, -36.0, float(k) / 8.0), 34.0 + (8.0 if k % 2 == 0 else 0.0)))
			cloak.append(Vector2(-40, 30))
			var fluff := []
			for k in 7:
				var t := float(k) / 6.0
				fluff.append(circ(Vector2(lerpf(-24.0, 24.0, t), -30.0 + sin(t * PI) * 6.0), 7.5, s + 10 + k, Color("eadcc0")))
			sil(ci, [pg(cloak, s, FUR, 0)] + fluff, rim)
			for k in 7:
				var x := -24.0 + float(k) * 8.0
				ln(ci, Vector2(x * 0.7, -16), Vector2(x * 1.2, 32), 1.6, Color(FUR_D, 0.8), s + k)
			for k in 7:
				var t := float(k) / 6.0
				ci.draw_arc(Vector2(lerpf(-24.0, 24.0, t), -30.0 + sin(t * PI) * 6.0), 3.5, PI * 1.1, PI * 1.6, 6, Color(INK, 0.2), 1.4, true)
			sil(ci, [stk(Vector2(-8, -18), Vector2(8, -18), 2.6, s + 30, BONE2, 2)], false)
		12:
			## 豹纹皮袄：金黄底黑斑的豹皮长袄，对襟两颗骨扣，袖口和下摆滚一圈白毛
			var body := _tunic(0.95)
			sil(ci, [pg(body, s, Color("e3a84a"), 0), bx(-29, 32, 58, 9, 4, s + 1, Color("eadcc0")),
				ov(Vector2(39, -4), 7, 4.5, s + 2, Color("eadcc0"), 2.47), ov(Vector2(-39, -4), 7, 4.5, s + 3, Color("eadcc0"), 0.67)], rim)
			for r in 4:
				for k in 4:
					var p := Vector2(-20.0 + float(k) * 13.0 + (6.0 if r % 2 == 1 else 0.0), -16.0 + float(r) * 12.0)
					if absf(p.x) < 4.0:
						continue
					p += Vector2((srnd(s + r * 4 + k) - 0.5) * 4.0, (srnd(s + r * 4 + k + 9) - 0.5) * 4.0)
					ci.draw_colored_polygon(ell(p, Vector2(3.2, 2.6), s + k, 0.1, 10), Color("c27a2a"))
					for j in 4:
						var a := TAU * float(j) / 4.0 + 0.4
						ci.draw_colored_polygon(ell(p + Vector2(cos(a), sin(a)) * 4.6, Vector2(1.9, 1.4), s + j, 0.1, 8, a + PI * 0.5), Color(BLACK, 0.85))
			ln(ci, Vector2(0, -26), Vector2(0, 32), 2.0, INK, s)
			sil(ci, [stk(Vector2(-6, -8), Vector2(6, -8), 2.4, s + 20, BONE2, 2), stk(Vector2(-6, 10), Vector2(6, 10), 2.4, s + 21, BONE2, 2)], false)
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

## 旧副产物：部落饰品 11 级（贝壳挂坠 … 酋长羽冠），现为成品
static func sub_old(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			## 贝壳挂坠：一根细绳挂一枚扇贝壳（最朴素）
			_cl_string(ci, arcp(Vector2(0, -36), Vector2(16, 34), PI, 0.0, 14), s)
			sil(ci, [_cl_scallop(Vector2(0, -2), 22, PI * 0.5, s)], rim)
			_cl_scallop_det(ci, Vector2(0, -2), 22, PI * 0.5, s)
			ci.draw_circle(Vector2(0, -2), 2.6, ROPE.darkened(0.2))
		2:
			## 兽牙项链：皮绳上穿五颗弯弯的兽牙，牙之间隔着小赭珠
			var c := Vector2(0, -40)
			_cl_string(ci, arcp(c, Vector2(32, 38), PI, 0.0, 18), s)
			var parts := []
			var tops := []
			for k in 4:
				var a := lerpf(PI * 0.7, PI * 0.3, float(k) / 3.0)
				parts.append(circ(c + Vector2(cos(a) * 32.0, sin(a) * 38.0), 3.4, s + 20 + k, OCHRE, 2))
			for k in 5:
				var a := lerpf(PI * 0.8, PI * 0.2, float(k) / 4.0)
				var top := c + Vector2(cos(a) * 32.0, sin(a) * 38.0)
				tops.append(top)
				var l := 34.0 if k == 2 else (28.0 if k % 2 == 1 else 22.0)
				parts.append(_cl_tooth(top, l, 8.0, -cos(a) * 0.35, s + k))
			sil(ci, parts, rim)
			for top in tops:
				var tp: Vector2 = top
				ln(ci, tp + Vector2(-6, 3), tp + Vector2(6, 3), 2.6, ROPE.darkened(0.2), s)
				hl(ci, tp + Vector2(-3, 11), 1.6, 5.0, 0.0, 0.55)
		3:
			## 彩石项链：一圈磨圆的彩色石珠，正中垂一块打磨光亮的绿石坠
			var c := Vector2(0, -40)
			_cl_string(ci, arcp(c, Vector2(30, 36), PI, 0.0, 18), s)
			var parts := []
			var beads := []
			for k in 13:
				var a := lerpf(PI * 0.88, PI * 0.12, float(k) / 12.0)
				beads.append(c + Vector2(cos(a) * 30.0, sin(a) * 36.0))
				parts.append(circ(beads[k], 4.8, s + k, [TEAL, CLAY, OCHRE, BERRY][k % 4]))
			parts.append(ov(Vector2(0, 12), 11, 14, s + 20, TEAL.darkened(0.05), 0.0, 1))
			sil(ci, parts, rim)
			for b in beads:
				ci.draw_circle((b as Vector2) + Vector2(-1.5, -1.5), 1.4, Color(1, 1, 1, 0.6))
			hl(ci, Vector2(-4, 6), 2.6, 5.0, -0.3, 0.6)
			ln(ci, Vector2(-4, -1), Vector2(4, -1), 2.6, ROPE.darkened(0.2), s)
		4:
			## 獠牙胸坠：两根野猪獠牙对拼成一弯大新月，正中绑一颗红石，挂在粗皮绳上，下面垂两根小羽毛
			_cl_string(ci, arcp(Vector2(0, -42), Vector2(20, 50), PI, 0.0, 16), s, 2.8, LEATHER)
			var fe := [[Vector2(-3, 14), 24.0, 4.8, PI * 0.5 + 0.3, PLUME], [Vector2(3, 14), 24.0, 4.8, PI * 0.5 - 0.3, TEAL]]
			var parts := []
			for f in fe:
				parts.append(leaf(f[0], f[1], f[2], f[3], s + parts.size(), f[4]))
			var cc := Vector2(0, -24)
			var tusks := [_cl_horn(cc, 32, PI * 0.5, PI * 0.95, 15, s + 5), _cl_horn(cc, 32, PI * 0.5, PI * 0.05, 15, s + 6)]
			var gem := circ(Vector2(0, 8), 7, s + 30, CLAY)
			sil(ci, parts + tusks + [gem], rim)
			for i in 2:
				var f: Array = fe[i]
				_cl_feather(ci, f[0], f[1], f[2], f[3], s + i, BLACK, Color(0, 0, 0, 0), 0.8)
			sil(ci, tusks, false)
			for sd in [-1.0, 1.0]:
				var arc := []
				for k in 8:
					var a := lerpf(PI * 0.5, PI * 0.5 - sd * PI * 0.4, float(k) / 7.0)
					arc.append(cc + Vector2(cos(a), sin(a)) * 28.0)
				pl(ci, arc, 1.4, Color(INK, 0.3), s)
				hl(ci, cc + Vector2(sd * 22.0, 22), 2.0, 5.0, sd * 0.8, 0.5)
			sil(ci, [gem], false)
			for k in 3:
				ln(ci, Vector2(-8, 4.0 + float(k) * 3.0), Vector2(8, 4.0 + float(k) * 3.0), 1.6, ROPE, s + k)
			hl(ci, Vector2(-2, 6), 1.6, 2.4, -0.3, 0.6)
		5:
			## 贝壳胸饰：皮做的半月形大领，钉两排小白贝，下沿一圈垂挂的扇贝（最隆重的胸前饰物）
			var cc := Vector2(0, -26)
			var outer := arcp(cc, Vector2(40, 44), 0.0, PI, 18)
			var inner := arcp(cc, Vector2(19, 21), PI, 0.0, 12)
			var collar := pg(outer + inner, s, LEATHER, 0)
			var shells := []
			var sp := []
			for k in 7:
				var a := lerpf(PI * 0.18, PI * 0.82, float(k) / 6.0)
				var p := cc + Vector2(cos(a) * 38.0, sin(a) * 42.0)
				sp.append([p, a])
				shells.append(_cl_scallop(p, 9.0, a, s + k))
			_cl_string(ci, [Vector2(30, -26), Vector2(24, -46)], s)
			_cl_string(ci, [Vector2(-30, -26), Vector2(-24, -46)], s)
			sil(ci, shells + [collar], rim)
			for k in 7:
				sil(ci, [shells[k]], false)
				_cl_scallop_det(ci, sp[k][0], 9.0, sp[k][1], s + k)
			sil(ci, [collar], false)
			for row in 2:
				var rx := 25.0 + float(row) * 9.0
				var ry := 27.0 + float(row) * 10.0
				var n := 7 + row * 2
				for k in n:
					var a := lerpf(PI * 0.08, PI * 0.92, float(k) / float(n - 1))
					var p := cc + Vector2(cos(a) * rx, sin(a) * ry)
					var e := ell(p, Vector2(3.4, 2.4), s + k, 0.0, 10, a + PI * 0.5)
					ci.draw_colored_polygon(e, Color("f6efe0"))
					outline(ci, e, 1.1)
					ln(ci, p - Vector2(cos(a + PI * 0.5), sin(a + PI * 0.5)) * 2.2, p + Vector2(cos(a + PI * 0.5), sin(a + PI * 0.5)) * 2.2, 1.0, Color(INK, 0.5), s)
		6:
			## 象牙手镯：猛犸象牙磨成的粗手镯，刻一圈折线纹，下半圈嵌三颗绿松石
			var c := Vector2(0, 4)
			sil(ci, ring(c, 27, 9.0, s, IVORY), rim)
			ci.draw_arc(c, 27, 0, TAU, 48, IVORY.darkened(0.08), 12.0, true)
			ci.draw_arc(c, 28, PI * 1.0, PI * 1.6, 16, IVORY, 6.0, true)
			ci.draw_arc(c, 19.5, PI * 1.05, PI * 1.95, 16, Color(LEATHER_D, 0.35), 3.0, true)
			var zz := []
			for k in 29:
				var a := TAU * float(k) / 28.0
				zz.append(c + Vector2(cos(a), sin(a)) * (24.0 if k % 2 == 0 else 30.0))
			pl(ci, zz, 1.3, Color(LEATHER_D, 0.55), s)
			for k in 3:
				var a := lerpf(PI * 0.3, PI * 0.7, float(k) / 2.0)
				var p := c + Vector2(cos(a), sin(a)) * 27.0
				sil(ci, [circ(p, 4.4, s + k, TEAL)], false)
				ci.draw_circle(p + Vector2(-1.4, -1.4), 1.3, Color(1, 1, 1, 0.7))
			ci.draw_arc(c, 32, PI * 1.15, PI * 1.45, 10, Color(1, 1, 1, 0.65), 2.4, true)
		7:
			## 羽饰臂环：宽皮臂箍，画一圈赭色折线，下沿垂三根羽毛，侧面挂一串小骨珠
			var fe := [[Vector2(-12, 14), 30.0, 5.5, PI * 0.5 + 0.25, PLUME], [Vector2(0, 16), 34.0, 6.0, PI * 0.5, TEAL],
				[Vector2(12, 14), 30.0, 5.5, PI * 0.5 - 0.25, PLUME]]
			var parts := []
			for f in fe:
				parts.append(leaf(f[0], f[1], f[2], f[3], s + parts.size(), f[4]))
			for k in 4:
				parts.append(circ(Vector2(26, 12.0 + float(k) * 6.0), 2.8, s + 10 + k, BONE2, 2))
			parts.append_array(_cl_cyl(-12, 4, 30, 6, s + 20, LEATHER))
			sil(ci, parts, rim)
			for i in 3:
				var f: Array = fe[i]
				_cl_feather(ci, f[0], f[1], f[2], f[3], s + i, BLACK if i != 1 else Color(0, 0, 0, 0))
			sil(ci, _cl_cyl(-12, 4, 30, 6, s + 20, LEATHER), false)
			_cl_hole(ci, -12, 30, 6, s)
			var zz := []
			for k in 15:
				var a := lerpf(0.08, PI - 0.08, float(k) / 14.0)
				zz.append(Vector2(cos(a) * 29.0, -4.0 + sin(a) * 6.0 + (3.0 if k % 2 == 0 else -3.0)))
			pl(ci, zz, 2.2, OCHRE, s)
		8:
			## 羽毛耳坠：一对耳坠——骨钩下串一颗红珠，再垂一根带横纹的长羽毛，羽尖染成青色
			var parts := []
			var fe := []
			for e in 2:
				var x := -14.0 + float(e) * 28.0
				var y0 := -38.0 + float(e) * 6.0
				var ang := PI * 0.5 + (0.08 if e == 0 else -0.08)
				fe.append([Vector2(x, y0 + 22), 46.0, 6.5, ang])
				parts.append(leaf(Vector2(x, y0 + 22), 46, 6.5, ang, s + e, PLUME))
				var hook := arcp(Vector2(x, y0), Vector2(5, 6), PI * 0.8, PI * 2.0, 8)
				hook.append(Vector2(x + 2, y0 + 7))
				hook.append(Vector2(x, y0 + 11))
				parts.append_array(_cl_cord(hook, 1.5, s + 10 + e * 10, BONE2))
				parts.append(circ(Vector2(x, y0 + 16), 5, s + 30 + e, BERRY))
			sil(ci, parts, rim)
			for e in 2:
				var f: Array = fe[e]
				_cl_feather(ci, f[0], f[1], f[2], f[3], s + e, TEAL, Color(LEATHER_D, 0.75))
				var b := Vector2(-14.0 + float(e) * 28.0, -38.0 + float(e) * 6.0 + 16.0)
				ci.draw_circle(b + Vector2(-1.6, -1.6), 1.4, Color(1, 1, 1, 0.65))
				ln(ci, b + Vector2(-3, 6), b + Vector2(3, 6), 2.0, ROPE, s)
		9:
			## 彩羽头带：皮头带上插五根彩色羽毛，带上一道骨白折线
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
		10:
			## 鹿角头冠：毛皮头箍上立一对分叉的鹿角，额前缀一排骨珠
			var ant := Color("d8c4a0")
			var parts := []
			for sd in [-1.0, 1.0]:
				var p0 := Vector2(sd * 12.0, 6)
				var p1 := Vector2(sd * 20.0, -16)
				var p2 := Vector2(sd * 33.0, -32)
				var p3 := Vector2(sd * 36.0, -46)
				parts.append(stk(p0, p1, 5.6, s, ant))
				parts.append(stk(p1, p2, 4.8, s + 1, ant))
				parts.append(stk(p2, p3, 4.0, s + 2, ant))
				parts.append(stk(p1, Vector2(sd * 10.0, -36), 4.0, s + 3, ant))
				parts.append(stk(p2, Vector2(sd * 21.0, -48), 3.6, s + 4, ant))
				parts.append(stk(Vector2(sd * 16.0, -6), Vector2(sd * 32.0, -12), 3.6, s + 5, ant))
			parts.append_array(_cl_cyl(8, 18, 32, 6, s + 20, FUR))
			sil(ci, parts, rim)
			_cl_hole(ci, 8, 32, 6, s)
			for k in 14:
				var a := lerpf(0.15, PI - 0.15, float(k) / 13.0)
				var p := Vector2(cos(a) * 31.0, 11.0 + sin(a) * 6.0)
				ln(ci, p, p + Vector2(1, 5), 1.4, Color(FUR_D, 0.8), s + k)
			var beads := []
			for k in 9:
				var a := lerpf(0.3, PI - 0.3, float(k) / 8.0)
				beads.append(circ(Vector2(cos(a) * 30.0, 18.0 + sin(a) * 6.0), 3.0, s + 40 + k, BONE2, 2))
			sil(ci, beads, false)
		_:
			## 酋长羽冠：一大圈白羽尖染黑的羽毛扇开成半圆，额前珠绣头箍正中镶一颗琥珀，两侧垂下羽毛长尾
			glow(ci, Vector2(0, -4), 56, GOLD)
			var cc := Vector2(0, 14)
			var fe := []
			for k in 11:
				var a := lerpf(-PI * 0.95, -PI * 0.05, float(k) / 10.0)
				fe.append([cc + Vector2(cos(a), sin(a)) * 8.0, 42.0, 6.6, a])
			var parts := []
			for f in fe:
				parts.append(leaf(f[0], f[1], f[2], f[3], s + parts.size(), PLUME))
			var tails := []
			for sd in [-1.0, 1.0]:
				tails.append(stk(Vector2(sd * 30.0, 18), Vector2(sd * 34.0, 28), 2.4, s + 30, LEATHER, 2))
				tails.append(leaf(Vector2(sd * 34.0, 26), 18, 4.2, PI * 0.5 - sd * 0.15, s + 31, PLUME))
			var band := bx(-34, 8, 68, 14, 6, s + 40, BERRY)
			sil(ci, parts + tails + [band], rim)
			for i in fe.size():
				var f: Array = fe[i]
				sil(ci, [parts[i]], false)
				_cl_feather(ci, f[0], f[1], f[2], f[3], s + i, BLACK, Color(0, 0, 0, 0), 0.7)
				ci.draw_colored_polygon(ell(f[0] + Vector2(cos(f[3]), sin(f[3])) * 5.0, Vector2(4.5, 3.0), s + i, 0.1, 10, f[3]), CLAY)
			for sd in [-1.0, 1.0]:
				_cl_feather(ci, Vector2(sd * 34.0, 26), 18, 4.2, PI * 0.5 - sd * 0.15, s, BLACK, Color(0, 0, 0, 0), 0.7)
			sil(ci, [band], false)
			zig(ci, -30, 30, 15, 2.6, 12, GOLD, 2.0, s)
			for k in 6:
				var x := -27.0 + float(k) * 10.8
				if absf(x) > 6.0:
					ci.draw_circle(Vector2(x, 15), 1.8, TEAL)
			sil(ci, [circ(Vector2(0, 15), 7.0, s + 50, AMBER)], false)
			hl(ci, Vector2(-2, 12), 2.0, 3.0, -0.3, 0.7)
			sparks(ci, [Vector2(-46, -40), Vector2(46, -42), Vector2(42, 34)])

# ================================================================ 新画法

const STRAW := Color("d9c272")
const FIBER := Color("e3d9a8")
const RAWHIDE := Color("c98f62")
const LEOPARD := Color("e8b24a")
const FOX := Color("f7f3ea")
const INDIGO := Color("2f4f9a")
const MADDER := Color("c8323a")
const SILK := Color("f4e6b8")
const TANPIT := Color("6b4424")

## 每级的整体缩放（以脚下地面为支点），让一条链从小到大
const GEN_SCALE := [1.0, 0.76, 0.99, 0.91, 0.91, 0.99, 0.98, 1.1]
const MAIN_SCALE := [1.11, 0.64, 0.68, 0.97, 0.97, 1.11, 1.36, 0.89, 1.0, 1.29, 1.03, 1.05]
const SUB_SCALE := [0.88, 0.7, 1.1, 1.1, 0.91, 0.89, 0.96, 0.94, 0.99, 1.14, 1.04]

static func _cl_grow(ci: CanvasItem, k: float) -> Transform2D:
	var keep := xf
	xf = keep * Transform2D(0.0, Vector2(k, k), 0.0, Vector2(0, 38) * (1.0 - k))
	ci.draw_set_transform_matrix(xf)
	return keep

static func _cl_ungrow(ci: CanvasItem, keep: Transform2D) -> void:
	xf = keep
	ci.draw_set_transform_matrix(xf)

## 一根上头带叉的木杆
static func _cl_post(foot: Vector2, top: Vector2, s: int, col: Color = WOOD_D) -> Array:
	var d := (top - foot).normalized()
	var n := Vector2(-d.y, d.x)
	return [stk(foot, top, 3.2, s, col), stk(top - d * 4.0, top + d * 3.0 + n * 6.0, 2.2, s + 1, col),
		stk(top - d * 4.0, top + d * 3.0 - n * 6.0, 2.2, s + 2, col)]

## 两根叉杆架一根横杆
static func _cl_rack(x0: float, x1: float, y: float, s: int) -> Array:
	var out := []
	out.append_array(_cl_post(Vector2(x0, 38), Vector2(x0, y), s))
	out.append_array(_cl_post(Vector2(x1, 38), Vector2(x1, y), s + 3))
	out.append(stk(Vector2(x0 - 8.0, y + 1.0), Vector2(x1 + 8.0, y + 1.0), 3.0, s + 6, WOOD))
	return out

## 挂在横杆上的一把草 / 麻：上窄下宽，返回剪影块
static func _cl_hang(x: float, y: float, w: float, l: float, s: int, col: Color) -> Array:
	return pg([Vector2(x - 3.0, y), Vector2(x + 3.0, y), Vector2(x + w, y + l), Vector2(x + w * 0.3, y + l + 3.0),
		Vector2(x - w * 0.3, y + l + 2.0), Vector2(x - w, y + l - 1.0)], s, col)

static func _cl_hang_det(ci: CanvasItem, x: float, y: float, w: float, l: float, s: int, col: Color) -> void:
	for k in 5:
		var t := lerpf(-0.75, 0.75, float(k) / 4.0)
		ln(ci, Vector2(x + t * 2.0, y + 5.0), Vector2(x + t * w, y + l - 1.0), 1.2, Color(col.darkened(0.35), 0.7), s + k)
	ln(ci, Vector2(x - 4.0, y + 5.0), Vector2(x + 4.0, y + 5.0), 2.6, ROPE.darkened(0.25), s)

## 撑开的兽皮轮廓（头在上，四条腿的皮角张开，尾巴在下）
static func _cl_hide_pts(c: Vector2, w: float, h: float, ang: float = 0.0) -> Array:
	var half := [Vector2(0, -1.0), Vector2(0.2, -0.95), Vector2(0.28, -0.74), Vector2(0.62, -0.86), Vector2(0.68, -0.7),
		Vector2(0.44, -0.46), Vector2(0.5, 0.0), Vector2(0.44, 0.42), Vector2(0.68, 0.7), Vector2(0.6, 0.86),
		Vector2(0.26, 0.7), Vector2(0.1, 0.86), Vector2(0.05, 1.1)]
	var pts := []
	for p in half:
		pts.append(Vector2(p.x * w, p.y * h))
	for i in range(half.size() - 1, 0, -1):
		var p: Vector2 = half[i]
		pts.append(Vector2(-p.x * w, p.y * h))
	return rot_pts(pts, ang, c)

## 毛茸茸的一圈边：把多边形每条边拆成小锯齿
static func _cl_fluff(pts: Array, step: float, amp: float) -> Array:
	var out := []
	var cen := Vector2.ZERO
	for p in pts:
		cen += p
	cen /= float(pts.size())
	for i in pts.size():
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % pts.size()]
		var n := maxi(int(a.distance_to(b) / step), 1)
		for k in n:
			var p := a.lerp(b, float(k) / float(n))
			if k % 2 == 1:
				p += (p - cen).normalized() * amp
			out.append(p)
	return out

## 线团：一个球加几道缠绕的线
static func _cl_ball_det(ci: CanvasItem, c: Vector2, r: float, s: int, cols: Array) -> void:
	for k in 6:
		var ang := -0.9 + float(k) * 0.34
		var col: Color = cols[k % cols.size()]
		var arc := arcp(Vector2.ZERO, Vector2(r * 0.92, r * (0.3 + float(k % 3) * 0.22)), PI * 0.08, PI * 0.92, 10)
		pl(ci, rot_pts(arc, ang, c), 1.8, col, s + k)

## ---------------------------------------------------------------- 生产器

## 生产器：1~3 级还在准备（割草、沤麻、搭架子），4 级晾架开始出草麻，6 级起绷皮、鞣皮出兽皮
static func gen(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	var keep := _cl_grow(ci, GEN_SCALE[clampi(lv, 1, 8) - 1])
	_gen_art(ci, lv, s, rim)
	_cl_ungrow(ci, keep)

static func _gen_art(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			## 一小捆刚割下的草，横着摊在地上，旁边一把石镰
			var sheaf := [Vector2(-28, 30), Vector2(-26, 24), Vector2(-4, 22), Vector2(20, 16), Vector2(28, 19), Vector2(24, 26),
				Vector2(28, 32), Vector2(8, 34), Vector2(-26, 36)]
			var parts := [pg(sheaf, s, STRAW, 0)]
			for k in 3:
				parts.append(ov(Vector2(26.0 - float(k) * 2.0, 17.0 + float(k) * 7.0), 6.0, 2.6, s + 10 + k, GRASS_D, -0.3, 1))
			parts.append(stk(Vector2(-6, 38), Vector2(10, 36), 2.6, s + 20, WOOD))
			parts.append(pg([Vector2(10, 37), Vector2(18, 31), Vector2(26, 33), Vector2(16, 39)], s + 21, STONE))
			sil(ci, parts, rim)
			for k in 5:
				var y := 25.0 + float(k) * 2.4
				pl(ci, [Vector2(-24, y + 2.0), Vector2(0, y - 0.5), Vector2(22, y - 4.0 + float(k) * 0.6)], 1.2, Color(GRASS_D, 0.7), s + k)
		2:
			## 沤麻坑：一圈石头围着一汪水，三束青麻竖着泡在水里，顶上露出绿叶和小蓝花
			var parts := []
			for k in 8:
				var a := TAU * float(k) / 8.0 + 0.3
				parts.append(raw_rock(Vector2(cos(a) * 34.0, 28.0 + sin(a) * 10.0), 6.5, s + k, STONE.lightened(0.08)))
			sil(ci, parts, rim)
			var water := ell(Vector2(0, 28), Vector2(29, 8), s + 21, 0.03, 20)
			ci.draw_colored_polygon(water, Color("5d9db0"))
			outline(ci, water, 1.6)
			var green := Color("6fa040")
			var xs := [-14.0, 1.0, 15.0]
			var tops := [-6.0, -14.0, -4.0]
			var stalks := []
			for k in 3:
				var x: float = xs[k]
				var y: float = tops[k]
				stalks.append(pg([Vector2(x - 3.5, 30), Vector2(x + 3.5, 30), Vector2(x + 5.0, y), Vector2(x - 5.0, y)], s + 30 + k, green))
				for j in 3:
					stalks.append(leaf(Vector2(x, y + 2.0), 9.0, 2.6, -PI * 0.5 + (float(j) - 1.0) * 0.6, s + 40 + k * 3 + j, LEAF))
			sil(ci, stalks, false)
			for k in 3:
				var x: float = xs[k]
				var y: float = tops[k]
				ln(ci, Vector2(x - 4.0, y + 14.0), Vector2(x + 4.0, y + 14.0), 2.4, ROPE.darkened(0.3), s + k)
				for j in 2:
					ci.draw_circle(Vector2(x - 3.0 + float(j) * 6.0, y - 6.0 + float(j) * 2.0), 2.2, SKY)
					ci.draw_circle(Vector2(x - 3.0 + float(j) * 6.0, y - 6.0 + float(j) * 2.0), 0.9, Color.WHITE)
			ci.draw_colored_polygon(ell(Vector2(0, 30), Vector2(26, 4), s + 22, 0.03, 18), Color("5d9db0", 0.85))
			for k in 2:
				pl(ci, arcp(Vector2(-8.0 + float(k) * 20.0, 30), Vector2(5, 1.6), 0.2, PI - 0.2, 6), 1.4, Color(1, 1, 1, 0.6), s + k)
		3:
			## 搭了一半的晾架：一根叉杆立着，横杆一头搭在叉上、一头落在地上，另一根杆子还躺着；地上堆着两捆等着挂的草，一卷绳
			var parts := []
			parts.append_array(_cl_post(Vector2(-20, 38), Vector2(-20, -16), s))
			parts.append(stk(Vector2(-26, -14), Vector2(30, 34), 2.8, s + 5, WOOD))
			parts.append_array(_cl_post(Vector2(-6, 36), Vector2(36, 34), s + 8))
			parts.append(ov(Vector2(14, 32), 9, 4.5, s + 12, ROPE, 0.0, 1))
			for k in 2:
				var c := Vector2(-34.0 + float(k) * 6.0, 32.0 - float(k) * 7.0)
				parts.append(pg([c + Vector2(-12, -3), c + Vector2(-4, -2), c + Vector2(12, -6), c + Vector2(14, 0), c + Vector2(12, 5), c + Vector2(-4, 3), c + Vector2(-12, 4)], s + 20 + k, STRAW if k == 0 else GRASS))
			sil(ci, parts, rim)
			pl(ci, arcp(Vector2(14, 32), Vector2(5, 2.4), 0.0, TAU, 12), 1.4, ROPE.darkened(0.3), s)
			pl(ci, [Vector2(-22, -13), Vector2(-18, -11), Vector2(-21, -8)], 2.0, ROPE.darkened(0.2), s)
			for k in 2:
				var c := Vector2(-34.0 + float(k) * 6.0, 32.0 - float(k) * 7.0)
				ln(ci, c + Vector2(-3, -3), c + Vector2(-3, 4), 2.4, ROPE.darkened(0.25), s + k)
				for j in 3:
					ln(ci, c + Vector2(0, -1.5 + float(j) * 1.6), c + Vector2(11, -3.5 + float(j) * 2.6), 1.0, Color(GRASS_D, 0.7), s + j)
		4:
			## 晾草架：架子搭好，横杆上挂着几把草、麻和一片棕榈叶
			var parts := _cl_rack(-32, 32, -26, s)
			var xs := [-22.0, -8.0, 20.0]
			for k in 3:
				parts.append(_cl_hang(xs[k], -24, 6.5, 30.0 + float(k % 2) * 4.0, s + 10 + k, STRAW if k % 2 == 0 else FLAX))
			parts.append_array(_cl_palm(Vector2(6, -24), 30, PI * 0.5, s + 30))
			sil(ci, parts, rim)
			for k in 3:
				_cl_hang_det(ci, xs[k], -24, 6.5, 30.0 + float(k % 2) * 4.0, s + k * 5, STRAW if k % 2 == 0 else FLAX)
			_cl_palm_det(ci, Vector2(6, -24), 30, PI * 0.5, s)
		5:
			## 晾架加一块捶麻石台：架子和上一级一样宽，前面摆着石台（木槌、一团麻线），地上盘着一卷藤
			var parts := _cl_rack(-36, 36, -28, s)
			var xs := [-24.0, -10.0, 4.0, 18.0]
			for k in 4:
				parts.append(_cl_hang(xs[k], -26, 6.0, 26.0, s + 10 + k, FLAX if k % 2 == 0 else STRAW))
			parts.append(pg([Vector2(4, 38), Vector2(2, 30), Vector2(10, 25), Vector2(40, 25), Vector2(46, 32), Vector2(44, 38)], s + 20, STONE, 1))
			parts.append(stk(Vector2(8, 16), Vector2(26, 23), 2.4, s + 22, WOOD))
			parts.append(ov(Vector2(8, 15), 6.5, 4.6, s + 23, WOOD_D, 0.4, 1))
			parts.append(circ(Vector2(36, 17), 8.5, s + 24, FIBER, 1))
			sil(ci, parts, rim)
			for k in 4:
				_cl_hang_det(ci, xs[k], -26, 6.0, 26.0, s + k * 5, FLAX if k % 2 == 0 else STRAW)
			ln(ci, Vector2(6, 31), Vector2(42, 31), 1.4, Color(STONE_D, 0.6), s)
			_cl_ball_det(ci, Vector2(36, 17), 8.5, s, [Color(FIBER.darkened(0.35), 0.9)])
			_cl_coil(ci, Vector2(-20, 34), 13, 5.5, 2, 2.6, s + 40, RATTAN, rim)
		6:
			## 绷皮架：木框里用绳子绷着一张兽皮，地上一把刮皮石刀
			var parts := []
			parts.append(stk(Vector2(-30, 38), Vector2(-30, -36), 3.2, s, WOOD_D))
			parts.append(stk(Vector2(30, 38), Vector2(30, -36), 3.2, s + 1, WOOD_D))
			parts.append(stk(Vector2(-36, -30), Vector2(36, -30), 3.0, s + 2, WOOD))
			parts.append(stk(Vector2(-36, 26), Vector2(36, 26), 3.0, s + 3, WOOD))
			var hide := _cl_hide_pts(Vector2(0, -2), 34, 22)
			parts.append(pg(hide, s + 4, RAWHIDE, 0))
			parts.append(pg([Vector2(30, 36), Vector2(40, 28), Vector2(46, 32), Vector2(38, 38)], s + 6, STONE))
			sil(ci, parts, rim)
			for p in [Vector2(-21, -21), Vector2(21, -21), Vector2(-23, 13), Vector2(23, 13), Vector2(0, -24), Vector2(0, 22)]:
				var v: Vector2 = p
				var to := Vector2(signf(v.x) * 28.0, v.y) if absf(v.x) > 1.0 else Vector2(v.x, signf(v.y) * 28.0 - (2.0 if v.y > 0 else -2.0))
				pl(ci, [v, to], 3.4, INK, s)
				pl(ci, [v, to], 1.6, ROPE, s)
			ci.draw_colored_polygon(ell(Vector2(0, -2), Vector2(11, 9), s, 0.05, 14), Color(RAWHIDE.lightened(0.18), 0.8))
		7:
			## 鞣皮坑加晾皮架：横杆上搭着三张皮，前面一个泡皮的坑，插着搅棍
			var parts := _cl_rack(-40, 40, -30, s)
			var cols := [LEATHER, FUR, BUCK]
			for k in 3:
				var x := -24.0 + float(k) * 24.0
				var w := 10.0
				parts.append(pg([Vector2(x - w, -30), Vector2(x + w, -30), Vector2(x + w + 2.0, 0), Vector2(x + 4.0, 4), Vector2(x - 2.0, 1), Vector2(x - w - 1.0, 3)], s + 10 + k, cols[k]))
			parts.append(ov(Vector2(4, 31), 30, 7.5, s + 20, STONE_D, 0.0, 1))
			parts.append(stk(Vector2(18, 30), Vector2(30, 6), 2.2, s + 21, WOOD))
			sil(ci, parts, rim)
			ci.draw_colored_polygon(ell(Vector2(4, 30), Vector2(25, 5), s + 22, 0.03, 18), TANPIT)
			pl(ci, arcp(Vector2(-6, 30), Vector2(6, 1.6), 0.2, PI - 0.2, 6), 1.2, Color(1, 1, 1, 0.35), s)
			for k in 3:
				var x := -24.0 + float(k) * 24.0
				ln(ci, Vector2(x - 8.0, -26), Vector2(x + 8.0, -26), 1.4, Color(INK, 0.35), s + k)
			for k in 6:
				ci.draw_circle(Vector2(-4.0 + float(k % 3) * 6.0, -18.0 + float(k / 3) * 9.0), 1.6, Color(FUR_D, 0.6))
		8:
			## 皮匠棚：兽皮缝起来搭成的大棚子，杆子从顶上交叉伸出，门口挂着一张豹皮
			glow(ci, Vector2(0, -2), 56, GOLD)
			var parts := []
			parts.append(stk(Vector2(-42, 38), Vector2(8, -44), 2.6, s, WOOD_D))
			parts.append(stk(Vector2(42, 38), Vector2(-8, -44), 2.6, s + 1, WOOD_D))
			parts.append(pg([Vector2(-40, 38), Vector2(-3, -34), Vector2(3, -34), Vector2(40, 38)], s + 2, LEATHER, 0))
			parts.append(pg([Vector2(-12, 38), Vector2(0, 4), Vector2(12, 38)], s + 3, Color("3a2416"), 2))
			parts.append(stk(Vector2(36, 38), Vector2(36, -14), 2.6, s + 4, WOOD))
			parts.append(pg(_cl_hide_pts(Vector2(42, 8), 13, 18), s + 5, LEOPARD))
			sil(ci, parts, rim)
			for k in 3:
				var t := 0.3 + float(k) * 0.22
				var a := Vector2(-3, -34).lerp(Vector2(-40, 38), t)
				var b := Vector2(3, -34).lerp(Vector2(40, 38), t)
				pl(ci, [a, b], 1.4, Color(INK, 0.35), s + k)
				var n := int(a.distance_to(b) / 7.0)
				for j in n:
					var p := a.lerp(b, (float(j) + 0.5) / float(n))
					ln(ci, p + Vector2(0, -2), p + Vector2(0, 2), 1.2, Color(BONE2, 0.8), s + j)
			zig(ci, -12, 12, 6, 2.0, 6, GOLD, 2.0, s)
			for p in [Vector2(40, -2), Vector2(45, 6), Vector2(39, 13), Vector2(45, 18), Vector2(41, 23)]:
				ci.draw_circle(p, 2.0, Color("5a3418"))
				ci.draw_circle(p + Vector2(0.6, 0.4), 0.9, Color(LEOPARD.darkened(0.15)))
			hl(ci, Vector2(-14, 2), 4, 12, 0.5, 0.25)
			sparks(ci, [Vector2(-44, -36), Vector2(28, -40), Vector2(-46, 18)])

## ---------------------------------------------------------------- 主产物入口（画法见文件末尾）

static func main(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	var keep := _cl_grow(ci, MAIN_SCALE[clampi(lv, 1, 12) - 1])
	_main_art(ci, lv, s, rim)
	_cl_ungrow(ci, keep)

## 上一版衣服材料（草茎 … 白狐皮），留着以后用
static func _main_art_v1(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			## 草茎：三根带穗头的草，从底下一点散开
			var parts := []
			var tips := [Vector2(-14, -16), Vector2(2, -24), Vector2(16, -14)]
			for k in 3:
				parts.append(stk(Vector2(0, 36), tips[k], 2.6, s + k, STRAW if k != 1 else GRASS, 1))
				var d: Vector2 = (tips[k] - Vector2(0, 36)).normalized()
				parts.append(ov(tips[k] + d * 6.0, 4.0, 9.0, s + 5 + k, GRASS_D, d.angle() + PI * 0.5, 1))
			parts.append(leaf(Vector2(0, 30), 18, 3.5, -2.3, s + 9, GRASS))
			sil(ci, parts, rim)
			for k in 3:
				var d: Vector2 = (tips[k] - Vector2(0, 36)).normalized()
				for j in 3:
					var p: Vector2 = tips[k] + d * (1.0 + float(j) * 4.5)
					ln(ci, p, p + d.rotated(0.7) * 3.0, 1.0, Color(INK, 0.35), s + j)
		2:
			## 麻纤维：一小撮浅色的麻丝，左头用草绳扎住，右边散开
			var pts := [Vector2(-26, 22), Vector2(-24, 16), Vector2(-4, 12), Vector2(16, 6), Vector2(28, 10), Vector2(24, 18),
				Vector2(30, 26), Vector2(18, 32), Vector2(-4, 30), Vector2(-24, 30)]
			sil(ci, [pg(pts, s, FIBER, 0), stk(Vector2(-18, 13), Vector2(-18, 33), 3.2, s + 1, GRASS_D)], rim)
			for k in 6:
				var y := 16.0 + float(k) * 2.8
				pl(ci, [Vector2(-14, y + 1.0), Vector2(2, y - 1.0), Vector2(14, y + 1.0), Vector2(24, y - 1.5 + float(k % 2) * 2.0)], 1.1, Color(FIBER.darkened(0.3), 0.8), s + k)
		3:
			## 麻线团：搓好的麻线绕成一个球，线头拖在外面
			var c := Vector2(0, 20)
			sil(ci, [circ(c, 16, s, FIBER, 0)], rim)
			_cl_ball_det(ci, c, 16, s, [Color(FIBER.darkened(0.35), 0.9), Color(FIBER.darkened(0.2), 0.9)])
			var tail := [Vector2(14, 28), Vector2(22, 34), Vector2(30, 33), Vector2(34, 37)]
			pl(ci, tail, 4.0, INK, s)
			pl(ci, tail, 2.0, FIBER, s)
		4:
			## 大树叶：一片又宽又长的叶子，带叶柄和叶脉
			var base := Vector2(-28, 32)
			var ang := -0.62
			var parts := [stk(Vector2(-38, 38), base, 2.2, s, LEAF_D, 2), leaf(base, 66, 21, ang, s + 1, LEAF)]
			sil(ci, parts, rim)
			var d := Vector2(cos(ang), sin(ang))
			var n := Vector2(-d.y, d.x)
			ln(ci, base + d * 4.0, base + d * 60.0, 1.8, LEAF_D, s)
			for k in 5:
				var p := base + d * (12.0 + float(k) * 10.0)
				var w := 17.0 * sin(PI * (12.0 + float(k) * 10.0) / 66.0)
				ln(ci, p, p + d * 6.0 + n * w * 0.85, 1.3, Color(LEAF_D, 0.8), s + k)
				ln(ci, p, p + d * 6.0 - n * w * 0.85, 1.3, Color(LEAF_D, 0.8), s + k + 5)
		5:
			## 蓑草捆：一大捆长草，捆两道，上下都散开
			var pts := [Vector2(-18, -32), Vector2(-6, -36), Vector2(8, -35), Vector2(19, -30), Vector2(10, -14), Vector2(10, 14),
				Vector2(20, 36), Vector2(4, 38), Vector2(-8, 38), Vector2(-21, 35), Vector2(-11, 14), Vector2(-11, -14)]
			sil(ci, [pg(pts, s, STRAW, 0)], rim)
			for k in 7:
				var t := lerpf(-1.0, 1.0, float(k) / 6.0)
				pl(ci, [Vector2(t * 16.0, -32), Vector2(t * 9.0, -14), Vector2(t * 9.0, 14), Vector2(t * 17.0, 35)], 1.2, Color(GRASS_D, 0.7), s + k)
			for y in [-12.0, 12.0]:
				var band := [Vector2(-12, y - 2.0), Vector2(11, y - 2.0), Vector2(11, y + 3.0), Vector2(-12, y + 3.0)]
				sil(ci, [pg(band, s + int(y), ROPE.darkened(0.15))], false)
		6:
			## 树皮片：从树上剥下来的一大片树皮，粗糙的外皮朝上，一头卷起来露出浅色的里子
			var sheet := [Vector2(-22, -6), Vector2(32, -18), Vector2(38, 18), Vector2(-16, 34)]
			sil(ci, [pg(sheet, s, BARK, 0), ov(Vector2(-22, 14), 9, 21, s + 1, Color("e3c9a0"), -0.25, 1)], rim)
			for k in 5:
				var t := 0.12 + float(k) * 0.19
				var a := Vector2(-22, -6).lerp(Vector2(32, -18), t)
				var b := Vector2(-16, 34).lerp(Vector2(38, 18), t)
				pl(ci, [a, a.lerp(b, 0.35) + Vector2(2, 0), a.lerp(b, 0.7) - Vector2(1, 0), b], 1.6, Color(INK, 0.4), s + k)
			for k in 3:
				var p := Vector2(0.0 + float(k) * 12.0, 2.0 + float(k % 2) * 12.0)
				ci.draw_colored_polygon(ell(p, Vector2(3, 1.4), s + k, 0.1, 8, -0.3), Color(BARK.darkened(0.3), 0.8))
			ci.draw_colored_polygon(ell(Vector2(-20, 13), Vector2(4, 15), s, 0.05, 12, -0.25), Color("b89770"))
			hl(ci, Vector2(-26, 8), 2, 8, -0.25, 0.4)
		7:
			## 皮绳卷：一条长皮绳一圈圈盘起来，绳头搭在外面
			var c := Vector2(0, 22)
			var parts := []
			parts.append(ov(c, 30, 15, s, LEATHER, 0.0, 1))
			sil(ci, parts, rim)
			for k in 4:
				var r := Vector2(26.0 - float(k) * 5.5, 12.0 - float(k) * 2.6)
				pl(ci, arcp(c, r, 0.0, TAU, 28), 3.2, LEATHER_D, s + k)
				pl(ci, arcp(c + Vector2(-1, -1.2), r, PI * 1.1, PI * 1.7, 10), 1.4, Color(1, 1, 1, 0.35), s + k)
			ci.draw_colored_polygon(ell(c, Vector2(6, 2.6), s, 0.0, 12), Color("3a2416"))
			sil(ci, [stk(c + Vector2(2, -1), c + Vector2(10, -14), 2.8, s + 1, LEATHER), stk(c + Vector2(10, -14), c + Vector2(20, -17), 2.6, s + 2, LEATHER)], false)
		8:
			## 生兽皮：一整张刚剥下的兽皮，毛朝上，四个皮角张开
			var pts := _cl_fluff(_cl_hide_pts(Vector2(0, 2), 42, 34, PI * 0.5), 4.0, 1.6)
			sil(ci, [pg(pts, s, FUR, 0)], rim)
			safe_poly(ci, PackedVector2Array(_cl_hide_pts(Vector2(0, 2), 26, 18, PI * 0.5)), Color(FUR.lightened(0.15), 0.8))
			for k in 8:
				var p := Vector2(-24.0 + float(k) * 7.0, -6.0 + float(k % 3) * 8.0)
				pl(ci, [p, p + Vector2(3, 2), p + Vector2(5, 0)], 1.2, Color(FUR_D, 0.6), s + k)
		9:
			## 鞣制皮革：鞣好的一大张皮，叠成两层，边上一排缝线，皮面光滑
			var back := [Vector2(-40, 6), Vector2(36, -6), Vector2(42, 32), Vector2(-34, 38)]
			var top := [Vector2(-36, -6), Vector2(30, -18), Vector2(34, 4), Vector2(14, 14), Vector2(-30, 22)]
			sil(ci, [pg(back, s, LEATHER, 0), pg(top, s + 1, BUCK, 0)], rim)
			pl(ci, [Vector2(-28, 18), Vector2(12, 10), Vector2(30, 2)], 1.4, Color(LEATHER_D, 0.5), s)
			dashed(ci, PackedVector2Array([Vector2(-30, -2), Vector2(26, -12)]), 3.0, 2.5, Color(LEATHER_D, 0.85), 1.6)
			dashed(ci, PackedVector2Array([Vector2(-32, 32), Vector2(36, 26)]), 3.0, 2.5, Color(BUCK, 0.9), 1.6)
			hl(ci, Vector2(-10, -4), 12, 2.5, -0.2, 0.35)
		10:
			## 毛皮：一张厚毛皮卷成一大卷，用皮绳捆两道，卷口露出浅色的皮里子
			var body := _cl_fluff([Vector2(-30, -8), Vector2(30, -14), Vector2(38, 0), Vector2(40, 22), Vector2(32, 34), Vector2(-28, 38), Vector2(-38, 28), Vector2(-38, 4)], 5.0, 2.8)
			var parts := [pg(body, s, FUR, 0), ov(Vector2(-33, 15), 10, 21, s + 1, FUR.lightened(0.1), 0.08, 1)]
			sil(ci, parts, rim)
			ci.draw_colored_polygon(ell(Vector2(-33, 15), Vector2(6, 15), s + 2, 0.05, 16, 0.08), HIDE2)
			for k in 3:
				pl(ci, arcp(Vector2(-33, 15), Vector2(5.0 - float(k) * 1.6, 13.0 - float(k) * 4.0), -PI * 0.5, PI * 1.5, 14), 1.4, Color(FUR_D, 0.7), s + k)
			for x in [-6.0, 20.0]:
				var band := [Vector2(x - 3.0, -12.0 + (x + 30.0) * -0.08), Vector2(x + 3.0, -12.0 + (x + 30.0) * -0.08), Vector2(x + 4.0, 37), Vector2(x - 2.0, 38)]
				sil(ci, [pg(band, s + int(x), LEATHER_D)], false)
			for k in 12:
				var p := Vector2(-22.0 + float(k % 6) * 10.0, -2.0 + float(k / 6) * 18.0 + float(k % 2) * 4.0)
				pl(ci, [p, p + Vector2(2, 3), p + Vector2(1, 6)], 1.3, Color(FUR_D, 0.6), s + k)
		11:
			## 豹皮：一整张金黄色带黑斑的豹皮，横着摊开，尾巴往下甩
			var pts := _cl_hide_pts(Vector2(2, 0), 46, 40, PI * 0.5)
			var tail := [Vector2(-42, 0), Vector2(-50, 8), Vector2(-52, 20), Vector2(-46, 30), Vector2(-38, 32)]
			var parts := []
			for i in 4:
				parts.append(stk(tail[i], tail[i + 1], 4.2 - float(i) * 0.5, s + 1 + i, LEOPARD))
			parts.append(pg(pts, s, LEOPARD, 0))
			sil(ci, parts, rim)
			safe_poly(ci, PackedVector2Array(_cl_hide_pts(Vector2(2, 0), 26, 22, PI * 0.5)), Color(BONE2, 0.45))
			for k in 16:
				var p := Vector2(-30.0 + float(k % 6) * 12.0 + float(k / 6) * 5.0, -18.0 + float(k / 6) * 15.0 + srnd(s + k) * 4.0)
				if absf(p.x - 2.0) > 38.0:
					continue
				for j in 4:
					var a := float(j) * PI * 0.5 + 0.4
					ci.draw_circle(p + Vector2(cos(a), sin(a)) * 3.0, 1.4, Color("3a2416"))
				ci.draw_circle(p, 1.5, LEOPARD.darkened(0.2))
			for k in 3:
				ci.draw_circle(tail[k + 1], 1.8, Color("3a2416"))
		12:
			## 白狐皮：雪白蓬松的一整张狐皮，后面一条又大又蓬的尾巴，带光
			glow(ci, Vector2(0, 2), 58, Color("bfe6ff"))
			var tail := _cl_fluff(rot_pts(arcp(Vector2.ZERO, Vector2(24, 11), 0.0, TAU, 14), 0.55, Vector2(-34, 16)), 4.0, 2.6)
			var body := _cl_fluff(_cl_hide_pts(Vector2(8, -2), 44, 36, PI * 0.5), 4.5, 2.6)
			sil(ci, [pg(tail, s + 1, FOX.darkened(0.06), 1), pg(body, s, FOX, 0)], rim)
			for k in 4:
				var p := Vector2(-46.0 + float(k) * 6.0, 6.0 + float(k) * 6.0)
				pl(ci, [p, p + Vector2(3, 2), p + Vector2(6, 2)], 1.3, Color("b9c2d4"), s + k + 10)
			for k in 9:
				var p := Vector2(-14.0 + float(k % 5) * 9.0, -12.0 + float(k / 5) * 14.0 + float(k % 2) * 4.0)
				pl(ci, [p, p + Vector2(2, 3), p + Vector2(1, 6)], 1.3, Color("b9c2d4"), s + k)
			hl(ci, Vector2(2, -12), 12, 3, -0.2, 0.55)
			sparks(ci, [Vector2(-44, -30), Vector2(40, -34), Vector2(50, 26)])

static func sub(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	var keep := _cl_grow(ci, SUB_SCALE[clampi(lv, 1, 11) - 1])
	_sub_art(ci, lv, s, rim)
	_cl_ungrow(ci, keep)

## 上一版作坊珍品（兽筋 … 彩丝锦），留着以后用
static func _sub_art_v1(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			## 兽筋：一小束半透明的筋，中间扎一道，两头散开微卷
			var pts := [Vector2(-24, 20), Vector2(-14, 23), Vector2(0, 24), Vector2(14, 22), Vector2(24, 18), Vector2(22, 26),
				Vector2(26, 32), Vector2(14, 31), Vector2(0, 32), Vector2(-14, 32), Vector2(-24, 34), Vector2(-21, 27)]
			sil(ci, [pg(pts, s, Color("f0e2c2"), 0), stk(Vector2(0, 20), Vector2(0, 36), 3.2, s + 10, ROPE.darkened(0.25))], rim)
			for k in 3:
				var y := 25.0 + float(k) * 2.6
				pl(ci, [Vector2(-20, y + 1.0), Vector2(-8, y), Vector2(8, y), Vector2(20, y - 1.0 + float(k))], 1.1, Color("c9ab7a"), s + k)
			hl(ci, Vector2(-12, 25), 6, 1.4, 0.0, 0.6)
		2:
			## 皮胶：熬出来的一块琥珀色胶块，透亮
			var pts := [Vector2(-18, 18), Vector2(-10, 6), Vector2(8, 4), Vector2(20, 14), Vector2(18, 32), Vector2(-4, 36), Vector2(-18, 30)]
			sil(ci, [pg(pts, s, Color("d98a2a"), 0)], rim)
			safe_poly(ci, poly([Vector2(-10, 14), Vector2(6, 10), Vector2(12, 20), Vector2(0, 28), Vector2(-10, 24)], s), Color(1, 0.85, 0.5, 0.45))
			hl(ci, Vector2(-8, 12), 4, 2, -0.5, 0.7)
			ci.draw_circle(Vector2(8, 26), 1.6, Color(1, 1, 1, 0.5))
		3:
			## 油脂块：一块乳白色的油脂，垫在一片树叶上
			var parts := [leaf(Vector2(-30, 34), 60, 11, -0.08, s, LEAF)]
			parts.append(pg([Vector2(-16, 14), Vector2(10, 10), Vector2(20, 18), Vector2(18, 32), Vector2(-14, 34), Vector2(-20, 24)], s + 1, Color("f6efd9"), 0))
			sil(ci, parts, rim)
			ln(ci, Vector2(-26, 34), Vector2(26, 31), 1.4, LEAF_D, s)
			pl(ci, [Vector2(-18, 20), Vector2(10, 16), Vector2(18, 22)], 1.2, Color(OCHRE, 0.35), s)
			hl(ci, Vector2(-6, 17), 7, 2.2, -0.15, 0.6)
		4:
			## 茜草红染料：一块扁石上淌着一摊红汁，上面横着一把扎好的红色茜草根
			var parts := [pg([Vector2(-34, 30), Vector2(-26, 22), Vector2(20, 20), Vector2(34, 26), Vector2(30, 36), Vector2(-30, 37)], s, STONE, 1)]
			sil(ci, parts, rim)
			safe_poly(ci, ell(Vector2(10, 28), Vector2(17, 5), s, 0.18, 16), MADDER)
			hl(ci, Vector2(5, 26.5), 5, 1.2, 0.0, 0.55)
			var roots := []
			for k in 3:
				var y := 12.0 + float(k) * 4.0
				roots.append(stk(Vector2(-30, y + 6.0), Vector2(8, y - 1.0 + float(k % 2) * 3.0), 3.0, s + 2 + k, Color("c4533f")))
			roots.append(stk(Vector2(8, 13), Vector2(16, 9), 1.8, s + 6, Color("c4533f"), 2))
			roots.append(stk(Vector2(9, 18), Vector2(18, 20), 1.8, s + 7, Color("c4533f"), 2))
			roots.append(stk(Vector2(-12, 11), Vector2(-12, 25), 2.8, s + 8, GRASS_D))
			sil(ci, roots, false)
			for k in 3:
				ln(ci, Vector2(-26, 17.0 + float(k) * 4.0), Vector2(-18, 16.0 + float(k) * 4.0), 1.0, Color(1, 1, 1, 0.35), s + k)
		5:
			## 靛蓝染料饼：一块厚厚的深蓝色圆饼，上面压着花纹，旁边两片蓝靛叶
			var parts := [leaf(Vector2(-14, 32), 34, 8, PI + 0.25, s, MOSS_D), leaf(Vector2(16, 34), 30, 7, -0.2, s + 1, MOSS_D)]
			parts.append(ov(Vector2(0, 26), 28, 11, s + 2, INDIGO.darkened(0.25), 0.0, 1))
			parts.append(ov(Vector2(0, 18), 28, 11, s + 3, INDIGO, 0.0, 1))
			sil(ci, parts, rim)
			safe_poly(ci, PackedVector2Array([Vector2(-28, 18), Vector2(28, 18), Vector2(28, 26), Vector2(-28, 26)]), INDIGO.darkened(0.25))
			outline(ci, ell(Vector2(0, 18), Vector2(28, 11), s + 3, 0.04, 20), 2.0)
			pl(ci, arcp(Vector2(0, 18), Vector2(17, 6.5), 0.0, TAU, 20), 1.4, Color("6f8fd8"), s)
			for k in 6:
				var a := TAU * float(k) / 6.0
				ci.draw_circle(Vector2(0, 18) + Vector2(cos(a) * 9.0, sin(a) * 3.5), 1.5, Color("8fa8e8"))
			hl(ci, Vector2(-12, 13), 6, 1.8, -0.1, 0.4)
		6:
			## 彩线团：红蓝两色线缠成的线团，插着一根骨针
			var c := Vector2(0, 18)
			var parts := [stk(Vector2(-22, -6), Vector2(10, 12), 1.8, s, BONE, 2), circ(c, 19, s + 1, MADDER, 0)]
			sil(ci, parts, rim)
			_cl_ball_det(ci, c, 19, s, [INDIGO, OCHRE, Color(MADDER.lightened(0.25))])
			var tail := [Vector2(16, 28), Vector2(26, 34), Vector2(36, 32), Vector2(42, 37)]
			pl(ci, tail, 4.2, INK, s)
			pl(ci, tail, 2.2, INDIGO, s)
			hl(ci, c + Vector2(-8, -8), 4, 2.5, -0.5, 0.5)
		7:
			## 毛毡：三块厚毛毡叠在一起，最上面那块折了个角，边上染了红条
			var parts := []
			var cols := [Color("b9ab92"), Color("d7c9ac"), Color("c4b59a")]
			for k in 3:
				var y := 30.0 - float(k) * 10.0
				var dx := float(k % 2) * 4.0 - 2.0
				parts.append(pg([Vector2(-34 + dx, y - 8.0), Vector2(34 + dx, y - 10.0), Vector2(36 + dx, y + 2.0), Vector2(-32 + dx, y + 4.0)], s + k, cols[k], 1))
			sil(ci, parts, rim)
			for k in 3:
				var y := 30.0 - float(k) * 10.0
				var dx := float(k % 2) * 4.0 - 2.0
				ln(ci, Vector2(-31 + dx, y + 1.0), Vector2(35 + dx, y - 1.0), 2.2, MADDER if k != 1 else INDIGO, s + k)
			safe_poly(ci, poly([Vector2(24, 0), Vector2(36, -1), Vector2(30, 8)], s), Color("ece0c4"))
			outline(ci, poly([Vector2(24, 0), Vector2(36, -1), Vector2(30, 8)], s), 1.4)
			for k in 10:
				ci.draw_circle(Vector2(-26.0 + float(k) * 5.5, 4.0 + float(k % 3) * 1.5), 0.8, Color(INK, 0.2))
		8:
			## 野蚕茧：一截带叶的小树枝，挂着三颗金黄发亮的茧
			var parts := [stk(Vector2(-40, -18), Vector2(40, -8), 2.6, s, WOOD)]
			parts.append(leaf(Vector2(-22, -16), 22, 7, -2.4, s + 1, LEAF))
			parts.append(leaf(Vector2(26, -10), 22, 7, -0.6, s + 2, LEAF))
			var cs := [Vector2(-18, 8), Vector2(2, 18), Vector2(22, 10)]
			for k in 3:
				var cc: Vector2 = cs[k]
				var top := Vector2(cc.x, lerpf(-17.0, -9.0, (cc.x + 40.0) / 80.0))
				parts.append(stk(top, cc + Vector2(0, -12), 0.9, s + 3 + k, Color("f1e2c0"), 2))
				parts.append(ov(cc, 8.0, 13.0, s + 6 + k, Color("f2c94a"), 0.0, 1))
			sil(ci, parts, rim)
			for k in 3:
				var cc: Vector2 = cs[k]
				for j in 3:
					pl(ci, arcp(cc + Vector2(0, -6.0 + float(j) * 6.0), Vector2(6.5, 2.2), 0.2, PI - 0.2, 6), 1.1, Color("c9962a"), s + j)
				hl(ci, cc + Vector2(-3, -4), 1.8, 4, 0.0, 0.7)
		9:
			## 彩织带：一卷织着花纹的布带，一头拉开铺在地上
			var parts := []
			parts.append(pg([Vector2(-2, 18), Vector2(20, 26), Vector2(44, 28), Vector2(44, 38), Vector2(18, 38), Vector2(-4, 30)], s, Color("f1e2c0"), 1))
			parts.append(pg([Vector2(-30, -6), Vector2(-4, -6), Vector2(-4, 32), Vector2(-30, 32)], s + 1, Color("f1e2c0"), 1))
			parts.append(ov(Vector2(-4, 13), 8, 19, s + 2, Color("e6d3ab"), 0.0, 1))
			sil(ci, parts, rim)
			var cols := [MADDER, TEAL, OCHRE, INDIGO]
			for k in 4:
				var x := -26.0 + float(k) * 6.0
				ln(ci, Vector2(x, -4), Vector2(x, 30), 2.2, cols[k], s + k)
			for k in 3:
				pl(ci, arcp(Vector2(-4, 13), Vector2(6.0 - float(k) * 1.8, 16.0 - float(k) * 5.0), -PI * 0.5, PI * 1.5, 16), 1.4, Color(WOOD_D, 0.6), s + k)
			zig(ci, 6, 42, 33, 2.0, 9, MADDER, 2.0, s)
			ln(ci, Vector2(4, 28), Vector2(42, 31), 1.6, TEAL, s)
			ln(ci, Vector2(6, 37), Vector2(42, 36.5), 1.6, OCHRE, s + 1)
		10:
			## 丝线卷：一个工字形木线轴，中间缠满有光泽的丝线
			glow(ci, Vector2(0, 2), 46, SILK)
			var parts := []
			parts.append(stk(Vector2(-30, -30), Vector2(30, -30), 3.4, s, WOOD))
			parts.append(stk(Vector2(-30, 32), Vector2(30, 32), 3.4, s + 1, WOOD))
			parts.append(pg([Vector2(-20, -26), Vector2(20, -26), Vector2(25, -10), Vector2(26, 10), Vector2(21, 28), Vector2(-21, 28), Vector2(-26, 10), Vector2(-25, -10)], s + 2, SILK, 0))
			sil(ci, parts, rim)
			for k in 9:
				var y := -22.0 + float(k) * 6.0
				var w := 20.0 + sin(PI * float(k) / 8.0) * 5.0
				ln(ci, Vector2(-w, y), Vector2(w, y - 1.5), 1.2, Color("d9bf7a"), s + k)
			ln(ci, Vector2(-24, 4), Vector2(25, 2), 3.0, MADDER, s)
			hl(ci, Vector2(-12, -4), 3, 18, 0.0, 0.6)
			hl(ci, Vector2(10, 4), 2, 12, 0.0, 0.35)
			sparks(ci, [Vector2(-40, 4), Vector2(40, -10)], 5.0)
		11:
			## 彩丝锦：一叠折好的花纹丝布，最上面一层垂下一角，带流苏和光
			glow(ci, Vector2(0, 6), 58, GOLD)
			var parts := []
			parts.append(pg([Vector2(-42, 14), Vector2(38, 6), Vector2(44, 30), Vector2(-36, 40)], s, MADDER, 0))
			parts.append(pg([Vector2(-40, -4), Vector2(36, -14), Vector2(42, 12), Vector2(26, 16), Vector2(30, 34), Vector2(16, 34), Vector2(12, 18), Vector2(-34, 24)], s + 1, Color("f6e3a8"), 0))
			sil(ci, parts, rim)
			zig(ci, -36, 34, 2, 2.4, 12, MADDER, 2.2, s)
			zig(ci, -34, 36, 12, 2.4, 12, INDIGO, 2.2, s + 1)
			for k in 4:
				var p := Vector2(-24.0 + float(k) * 16.0, -6.0 - float(k) * 2.4)
				ci.draw_colored_polygon(star_pts(p, 3.6, 1.6, 4, s + k), TEAL)
			ln(ci, Vector2(-36, 34), Vector2(40, 24), 2.2, GOLD, s)
			for k in 4:
				ln(ci, Vector2(17.0 + float(k) * 4.0, 34), Vector2(17.0 + float(k) * 4.0, 40), 1.6, GOLD, s + k)
			hl(ci, Vector2(-16, -2), 12, 2.5, -0.15, 0.55)
			sparks(ci, [Vector2(-46, -26), Vector2(42, -30), Vector2(48, 36)])

# ================================================================ 第二版：植物料 / 兽毛兽皮

const RATTAN := Color("c99a52")
const PALM := Color("7fb04a")
const PELT := Color("8a5a34")
const PELT_G := Color("9a948c")
const VINE := Color("d2ae6c")

## 一片扇形棕榈叶：叶片从 base 朝 ang 方向扇开
static func _cl_palm(base: Vector2, r: float, ang: float, s: int, col: Color = PALM) -> Array:
	var out := []
	for k in 7:
		var a := ang + lerpf(-0.95, 0.95, float(k) / 6.0)
		var l := r * (0.78 + 0.22 * sin(PI * float(k) / 6.0))
		out.append(leaf(base, l, r * 0.14, a, s + k, col if k % 2 == 0 else col.darkened(0.1)))
	return out

static func _cl_palm_det(ci: CanvasItem, base: Vector2, r: float, ang: float, s: int) -> void:
	for k in 7:
		var a := ang + lerpf(-0.95, 0.95, float(k) / 6.0)
		var l := r * (0.78 + 0.22 * sin(PI * float(k) / 6.0))
		ln(ci, base, base + Vector2(cos(a), sin(a)) * l * 0.85, 1.2, Color(LEAF_D, 0.8), s + k)

## 一根藤条：沿折线的粗杆，带一节节的藤节
static func _cl_cane(pts: Array, r: float, s: int, col: Color = RATTAN) -> Array:
	var out := []
	for i in pts.size() - 1:
		out.append(stk(pts[i], pts[i + 1], r, s + i, col, 1))
	return out

static func _cl_cane_det(ci: CanvasItem, pts: Array, r: float, s: int, step: float = 11.0) -> void:
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var d := (b - a).normalized()
		var n := Vector2(-d.y, d.x)
		var dist := a.distance_to(b)
		var t := step * 0.5
		while t < dist - 2.0:
			var p := a + d * t
			ln(ci, p - n * r * 0.9, p + n * r * 0.9, 1.4, Color(RATTAN.darkened(0.4), 0.9), s + int(t))
			t += step
		ln(ci, a + n * r * 0.35, b + n * r * 0.35, 1.0, Color(1, 1, 1, 0.35), s + i)

## 一圈盘起来的藤 / 绳：俯视的几圈椭圆
static func _cl_coil(ci: CanvasItem, c: Vector2, rx: float, ry: float, loops: int, w: float, s: int, col: Color, rim: bool) -> void:
	sil(ci, [ov(c, rx, ry, s, col, 0.0, 1)], rim)
	ci.draw_colored_polygon(ell(c, Vector2(rx * 0.32, ry * 0.32), s, 0.0, 14), Color("3a2416"))
	for k in loops:
		var f := 1.0 - (float(k) + 0.5) / float(loops) * 0.68
		var arc := arcp(c, Vector2(rx * f, ry * f), 0.0, TAU, 30)
		pl(ci, arc, w, col.darkened(0.35), s + k)
		pl(ci, arcp(c + Vector2(-0.6, -0.8), Vector2(rx * f, ry * f), PI * 1.05, PI * 1.75, 10), 1.3, Color(1, 1, 1, 0.35), s + k)

## 一撮 / 一团兽毛：毛茸茸的不规则团
static func _cl_tuft(c: Vector2, rx: float, ry: float, s: int, col: Color, n: int = 16) -> Array:
	var pts := []
	for k in n:
		var a := TAU * float(k) / float(n)
		var m := 1.0 if k % 2 == 0 else 0.8
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry) * m)
	return pg(pts, s, col, 0)

static func _cl_hair(ci: CanvasItem, c: Vector2, rx: float, ry: float, n: int, s: int, col: Color) -> void:
	for k in n:
		var p := c + Vector2((srnd(s * 3 + k) - 0.5) * rx * 1.3, (srnd(s * 7 + k) - 0.5) * ry * 1.2)
		pl(ci, [p, p + Vector2(2, 3), p + Vector2(1, 6)], 1.3, col, s + k)

## ---------------------------------------------------------------- 主产物：植物料（草 / 麻 / 棕榈 / 藤，每种 3 级）

static func _main_art(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			## 草茎：一根矮矮的带穗的草，底下一片细叶
			sil(ci, [stk(Vector2(0, 36), Vector2(2, 10), 2.4, s, STRAW), ov(Vector2(3, 4), 3.8, 8, s + 1, GRASS_D, 0.08, 1),
				leaf(Vector2(1, 32), 16, 3.2, -2.3, s + 2, GRASS)], rim)
			for j in 3:
				var p := Vector2(3, -1.0 + float(j) * 4.0)
				ln(ci, p, p + Vector2(3, 2), 1.0, Color(INK, 0.35), s + j)
		2:
			## 一把草：五六根草扎一道，穗头朝上散开
			var tips := [Vector2(-16, -16), Vector2(-7, -24), Vector2(2, -27), Vector2(11, -23), Vector2(18, -14)]
			var parts := []
			for k in 5:
				parts.append(stk(Vector2(-2.0 + float(k), 36), tips[k], 2.4, s + k, STRAW if k % 2 == 0 else GRASS))
				var d: Vector2 = (tips[k] - Vector2(0, 36)).normalized()
				parts.append(ov(tips[k] + d * 5.0, 3.6, 8.0, s + 10 + k, GRASS_D, d.angle() + PI * 0.5, 1))
			parts.append(stk(Vector2(-7, 16), Vector2(7, 16), 3.0, s + 20, ROPE.darkened(0.2)))
			sil(ci, parts, rim)
		3:
			## 干草捆：一大捆干草，捆两道，上下都散开
			var pts := [Vector2(-22, -30), Vector2(-8, -36), Vector2(8, -36), Vector2(22, -30), Vector2(12, -14), Vector2(12, 14),
				Vector2(24, 36), Vector2(6, 38), Vector2(-8, 38), Vector2(-24, 35), Vector2(-13, 14), Vector2(-13, -14)]
			sil(ci, [pg(pts, s, STRAW, 0)], rim)
			for k in 8:
				var t := lerpf(-1.0, 1.0, float(k) / 7.0)
				pl(ci, [Vector2(t * 19.0, -31), Vector2(t * 11.0, -14), Vector2(t * 11.0, 14), Vector2(t * 20.0, 35)], 1.2, Color(GRASS_D, 0.7), s + k)
			for y in [-12.0, 12.0]:
				sil(ci, [pg([Vector2(-14, y - 2.5), Vector2(13, y - 2.5), Vector2(13, y + 3.0), Vector2(-14, y + 3.0)], s + int(y), ROPE.darkened(0.15))], false)
		4:
			## 麻秆：三根刚割下的青麻秆，带小叶子，顶上开着小蓝花
			var green := Color("8cc04e")
			var tips := [Vector2(-12, -6), Vector2(2, -12), Vector2(14, -4)]
			var parts := []
			for k in 3:
				var tip: Vector2 = tips[k]
				var foot := Vector2(-3.0 + float(k) * 3.0, 36)
				parts.append(stk(foot, tip, 3.2, s + k, green))
				for j in 2:
					var p: Vector2 = foot.lerp(tip, 0.4 + float(j) * 0.25)
					parts.append(leaf(p, 10.0, 3.2, (tip - foot).angle() + (0.7 if j % 2 == 0 else -0.7), s + 10 + k * 2 + j, LEAF))
			sil(ci, parts, rim)
			for k in 3:
				var tip: Vector2 = tips[k]
				ci.draw_circle(tip, 3.4, INK)
				ci.draw_circle(tip, 2.4, SKY)
				ci.draw_circle(tip, 0.9, Color.WHITE)
		5:
			## 麻束：沤好晒干的麻剥成一束浅绿发白的麻丝，横放着捆两道，一头散开
			var pale := Color("d8dfb2")
			var pts := [Vector2(-34, 14), Vector2(18, 10), Vector2(30, 4), Vector2(36, 12), Vector2(32, 20), Vector2(38, 30),
				Vector2(20, 30), Vector2(-34, 32)]
			sil(ci, [pg(pts, s, pale, 0)], rim)
			for k in 5:
				var y := 15.0 + float(k) * 3.6
				pl(ci, [Vector2(-32, y), Vector2(16, y - 1.5 + float(k) * 0.3), Vector2(30, y - 6.0 + float(k) * 3.0)], 1.2, Color(pale.darkened(0.3), 0.8), s + k)
			for x in [-20.0, 4.0]:
				sil(ci, [pg([Vector2(x - 2.5, 10), Vector2(x + 3.0, 10), Vector2(x + 3.0, 34), Vector2(x - 2.5, 34)], s + int(x), ROPE.darkened(0.15))], false)
			ci.draw_colored_polygon(ell(Vector2(-34, 23), Vector2(3, 8.5), s, 0.05, 12), Color(pale.darkened(0.25)))
		6:
			## 麻线团：搓好的白麻线绕成一个大线团，线头拖出来
			var white := Color("f5f1e4")
			var c := Vector2(0, 16)
			sil(ci, [circ(c, 21, s, white, 0)], rim)
			_cl_ball_det(ci, c, 21, s, [Color("c9c2ae"), Color("ddd6c2")])
			var tail := [Vector2(18, 26), Vector2(26, 34), Vector2(36, 32), Vector2(42, 37)]
			pl(ci, tail, 4.2, INK, s)
			pl(ci, tail, 2.2, white, s)
		7:
			## 棕榈叶：一片小小的扇形棕榈叶，带一截叶柄
			var base := Vector2(0, 28)
			var parts := [stk(Vector2(4, 38), base, 2.2, s, LEAF_D)]
			parts.append_array(_cl_palm(base, 25, -PI * 0.5 - 0.2, s + 1))
			sil(ci, parts, rim)
			_cl_palm_det(ci, base, 25, -PI * 0.5 - 0.2, s)
		8:
			## 棕榈叶叠：三片棕榈叶叠在一起，扇面错开
			var parts := []
			var bases := [Vector2(-14, 18), Vector2(14, 18), Vector2(0, 22)]
			var angs := [-PI * 0.5 - 0.55, -PI * 0.5 + 0.55, -PI * 0.5]
			for k in 3:
				parts.append(stk(Vector2(0, 38), bases[k], 2.4, s + k * 10, LEAF_D))
			for k in 3:
				parts.append_array(_cl_palm(bases[k], 34, angs[k], s + 1 + k * 10, PALM.darkened(0.08 * float(2 - k))))
			sil(ci, parts, rim)
			_cl_palm_det(ci, bases[2], 34, angs[2], s)
		9:
			## 棕榈叶捆：一大捆棕榈叶，叶柄捆在一起立着，顶上扇面散开
			var parts := []
			var angs := [-PI * 0.5 - 0.8, -PI * 0.5 + 0.8, -PI * 0.5 - 0.3, -PI * 0.5 + 0.3]
			for k in 4:
				var top := Vector2(-6.0 + float(k) * 4.0, 18)
				parts.append(stk(Vector2(-3.0 + float(k) * 2.0, 38), top, 2.6, s + k * 10, LEAF_D))
				parts.append_array(_cl_palm(top, 38, angs[k], s + 1 + k * 10, PALM.darkened(0.06 * float(k % 2))))
			parts.append(stk(Vector2(-9, 30), Vector2(9, 30), 3.4, s + 50, ROPE.darkened(0.2)))
			sil(ci, parts, rim)
			_cl_palm_det(ci, Vector2(6, 18), 38, angs[3], s)
			_cl_palm_det(ci, Vector2(2, 18), 38, angs[2], s + 3)
		10:
			## 藤条：一根细藤弯成一个 C 字（比后面的藤环小），带几片叶子，末端一个小卷须
			var c := Vector2(0, 14)
			var pts := []
			for k in 17:
				var a := lerpf(-0.75, PI * 1.45 + 0.1, float(k) / 16.0) - PI * 0.5
				var r := 21.0 + sin(float(k) * 1.3) * 1.2
				pts.append(c + Vector2(cos(a + PI), sin(a + PI)) * r)
			var parts := _cl_vine(pts, 3.4, s, VINE)
			parts.append_array(_cl_vine_leaves(pts, [3, 7, 11, 14], 11.0, s + 20))
			sil(ci, parts, rim)
			_cl_tendril(ci, pts[pts.size() - 1], 5.0, s)
		11:
			## 藤环：一根长藤盘成一个立着的大圈，上下各缠一道，几片叶子从圈上冒出来
			var c := Vector2(0, 4)
			var parts := []
			var rs := [27.0, 32.0]
			for k in 2:
				parts.append_array(ring(c + Vector2(float(k) * 1.5, float(k) * 0.8), rs[k], 3.4, s + k * 3, VINE.darkened(0.08 * float(k)), 2))
			for a in [-2.2, -0.5, 1.2, 2.6]:
				var p: Vector2 = c + Vector2(cos(a), sin(a)) * 32.0
				parts.append(leaf(p, 13.0, 4.6, a + 0.6, s + 20 + int(a * 10.0), LEAF))
			for y in [-26.0, 34.0]:
				parts.append(stk(Vector2(-4, y), Vector2(4, y), 5.0, s + 30 + int(y), VINE.darkened(0.25)))
			sil(ci, parts, rim)
			for y in [-26.0, 34.0]:
				for j in 3:
					ln(ci, Vector2(-3.0 + float(j) * 3.0, y - 4.0), Vector2(-3.0 + float(j) * 3.0, y + 4.0), 1.0, Color(INK, 0.4), s + j)
		12:
			## 大藤捆：一大捆长藤横放，捆两道，两头散出藤梢和叶子，带光
			glow(ci, Vector2(0, 12), 56, GOLD)
			var parts := []
			var all := []
			for k in 5:
				var y := 8.0 + float(k) * 6.5
				var pts := _cl_vine_pts(Vector2(-44.0 + float(k % 3) * 2.0, y + 2.0 - float(k % 2) * 3.0), Vector2(44.0 - float(k % 2) * 3.0, y - 3.0 + float(k % 3) * 2.0), 2.4, 2.0 + float(k % 2), 12)
				all.append(pts)
				parts.append_array(_cl_vine(pts, 3.6, s + k * 20, VINE.darkened(0.07 * float(k % 3))))
			parts.append_array(_cl_vine_leaves(all[0], [1, 11], 13.0, s + 200))
			parts.append_array(_cl_vine_leaves(all[4], [2, 10], 13.0, s + 210))
			sil(ci, parts, rim)
			for x in [-18.0, 18.0]:
				sil(ci, [pg([Vector2(x - 3.5, 1), Vector2(x + 3.5, 0), Vector2(x + 3.5, 40), Vector2(x - 3.5, 40)], s + int(x), VINE.darkened(0.3))], false)
				for j in 3:
					ln(ci, Vector2(x - 3.0, 8.0 + float(j) * 11.0), Vector2(x + 3.0, 6.0 + float(j) * 11.0), 1.2, Color(INK, 0.4), s + j)
			_cl_tendril(ci, all[2][all[2].size() - 1], 5.0, s)
			sparks(ci, [Vector2(-44, -18), Vector2(36, -22), Vector2(48, 34)])

static func _sub_art(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			## 一撮兽毛：一小缕细细的毛，几根毛尖弯着散开
			var pts := [Vector2(-14, 32), Vector2(-6, 28), Vector2(6, 26), Vector2(14, 20), Vector2(12, 26), Vector2(18, 24), Vector2(12, 31), Vector2(16, 33), Vector2(2, 34), Vector2(-10, 35)]
			sil(ci, [pg(pts, s, PELT, 0)], rim)
			pl(ci, [Vector2(-10, 32), Vector2(2, 30), Vector2(12, 27)], 1.2, Color(FUR_D, 0.7), s)
		2:
			## 一团兽毛：一大团蓬松的毛，用草绳十字捆住
			var c := Vector2(0, 16)
			sil(ci, [_cl_tuft(c, 22, 20, s, PELT, 22)], rim)
			_cl_hair(ci, c, 22, 20, 9, s, Color(FUR_D, 0.7))
			pl(ci, arcp(c, Vector2(20, 6), 0.0, PI, 10), 3.6, INK, s)
			pl(ci, arcp(c, Vector2(20, 6), 0.0, PI, 10), 2.0, ROPE, s)
			pl(ci, arcp(c, Vector2(6, 18), -PI * 0.5, PI * 0.5, 10), 3.6, INK, s + 1)
			pl(ci, arcp(c, Vector2(6, 18), -PI * 0.5, PI * 0.5, 10), 2.0, ROPE, s + 1)
			hl(ci, c + Vector2(-9, -9), 5, 2.5, -0.4, 0.3)
		3:
			## 碎皮：一小块剥下来的边角皮
			sil(ci, [pg([Vector2(-16, 22), Vector2(-4, 14), Vector2(12, 18), Vector2(14, 30), Vector2(-2, 34), Vector2(-16, 32)], s, RAWHIDE, 0)], rim)
			ci.draw_colored_polygon(ell(Vector2(-2, 24), Vector2(6, 3.5), s, 0.1, 10), Color(RAWHIDE.lightened(0.2), 0.7))
		4:
			## 一堆碎皮：三块边角皮堆在一起，每块都和一块碎皮差不多大
			var parts := []
			var cs := [Vector2(-14, 28), Vector2(16, 30), Vector2(2, 16)]
			var cols := [RAWHIDE.darkened(0.12), RAWHIDE, BUCK]
			for k in 3:
				var c: Vector2 = cs[k]
				var r := 15.0
				parts.append(pg([c + Vector2(-r, -2), c + Vector2(-r * 0.3, -r * 0.6), c + Vector2(r, -r * 0.4), c + Vector2(r * 0.9, r * 0.45), c + Vector2(-r * 0.2, r * 0.55), c + Vector2(-r * 0.9, r * 0.4)], s + k, cols[k], 1))
			sil(ci, parts, rim)
			ci.draw_colored_polygon(ell(Vector2(2, 14), Vector2(6, 3), s, 0.1, 10), Color(1, 1, 1, 0.3))
		5:
			## 兽皮：一整张撑开的兽皮，皮面朝上
			var pts := _cl_hide_pts(Vector2(0, 8), 40, 32, PI * 0.5)
			sil(ci, [pg(pts, s, RAWHIDE, 0)], rim)
			safe_poly(ci, PackedVector2Array(_cl_hide_pts(Vector2(0, 8), 24, 17, PI * 0.5)), Color(RAWHIDE.lightened(0.15), 0.8))
			for k in 4:
				ln(ci, Vector2(-18.0 + float(k) * 12.0, -2), Vector2(-16.0 + float(k) * 12.0, 16), 1.2, Color(RAWHIDE.darkened(0.25), 0.5), s + k)
		6:
			## 两张兽皮：两张兽皮叠在一起，底下那张颜色深一点，皮角错开
			var parts := [pg(_cl_hide_pts(Vector2(4, 16), 40, 30, PI * 0.5 + 0.12), s, RAWHIDE.darkened(0.15), 1),
				pg(_cl_hide_pts(Vector2(-2, 6), 40, 30, PI * 0.5 - 0.06), s + 1, RAWHIDE, 0)]
			sil(ci, parts, rim)
			safe_poly(ci, PackedVector2Array(_cl_hide_pts(Vector2(-2, 6), 24, 16, PI * 0.5 - 0.06)), Color(RAWHIDE.lightened(0.15), 0.8))
		7:
			## 毛皮：一整张厚毛皮，毛朝上，四个皮角张开
			var pts := _cl_fluff(_cl_hide_pts(Vector2(0, 6), 42, 34, PI * 0.5), 4.0, 2.2)
			sil(ci, [pg(pts, s, PELT, 0)], rim)
			safe_poly(ci, PackedVector2Array(_cl_hide_pts(Vector2(0, 6), 26, 18, PI * 0.5)), Color(PELT.lightened(0.15), 0.8))
			_cl_hair(ci, Vector2(0, 6), 44, 26, 12, s, Color(FUR_D, 0.6))
		8:
			## 两张毛皮：一张灰毛皮叠在一张棕毛皮上
			var a := _cl_fluff(_cl_hide_pts(Vector2(6, 16), 40, 32, PI * 0.5 + 0.12), 4.0, 2.2)
			var b := _cl_fluff(_cl_hide_pts(Vector2(-3, 4), 40, 32, PI * 0.5 - 0.06), 4.0, 2.2)
			sil(ci, [pg(a, s, PELT, 1), pg(b, s + 1, PELT_G, 0)], rim)
			safe_poly(ci, PackedVector2Array(_cl_hide_pts(Vector2(-3, 4), 24, 16, PI * 0.5 - 0.06)), Color(PELT_G.lightened(0.15), 0.8))
			_cl_hair(ci, Vector2(-3, 4), 44, 24, 10, s, Color(PELT_G.darkened(0.35), 0.7))
		9:
			## 兽皮堆：一摞四张叠好的兽皮，皮角从两边耷拉出来，中间用皮绳捆一道
			var parts := []
			var cols := [RAWHIDE.darkened(0.18), BUCK.darkened(0.05), RAWHIDE.darkened(0.06), RAWHIDE]
			for k in 4:
				var y := 30.0 - float(k) * 8.5
				var dx := float(k % 2) * 5.0 - 2.5
				parts.append(pg([Vector2(-38 + dx, y - 5.0), Vector2(-24 + dx, y - 9.0), Vector2(26 + dx, y - 10.0), Vector2(40 + dx, y - 5.0),
					Vector2(46 + dx, y + 2.0), Vector2(38 + dx, y + 5.0), Vector2(-36 + dx, y + 6.0), Vector2(-44 + dx, y + 1.0)], s + k, cols[k], 1))
			parts.append(pg([Vector2(-36, 4), Vector2(-46, 10), Vector2(-40, 14)], s + 10, RAWHIDE))
			parts.append(pg([Vector2(38, 3), Vector2(50, 8), Vector2(42, 12)], s + 11, RAWHIDE))
			sil(ci, parts, rim)
			ci.draw_colored_polygon(ell(Vector2(0, 3), Vector2(22, 3), s, 0.1, 14), Color(RAWHIDE.lightened(0.15), 0.8))
			for k in 3:
				var y := 30.0 - float(k) * 8.5
				ln(ci, Vector2(-30, y + 3.5), Vector2(34, y + 3.0), 1.2, Color(INK, 0.3), s + k)
			sil(ci, [pg([Vector2(6, -6), Vector2(11, -6), Vector2(11, 37), Vector2(6, 37)], s + 20, LEATHER_D)], false)
		10:
			## 毛皮卷：一张厚毛皮卷成一大卷，圆的卷口稍微朝着玩家，看得到一圈圈卷进去的皮，身子往后伸，捆一道皮绳
			_cl_fur_roll_front(ci, Vector2(-6, 14), 22, Vector2(18, -12), s, PELT, rim)
		11:
			## 毛皮堆：三卷毛皮像柴垛一样堆起来，底下两卷，上面一卷卡在中间，卷口都稍微朝着玩家，带光；
			## 先给整堆画一圈奶白外边，再从后往前画（左下、右下、上），卷与卷之间没有白边
			glow(ci, Vector2(0, 6), 58, GOLD)
			var rolls := [[Vector2(-19, 22), s, PELT], [Vector2(19, 22), s + 10, PELT.darkened(0.1)], [Vector2(0, -9), s + 20, PELT_G]]
			if rim:
				for rl in rolls:
					for poly in _cl_fur_roll_polys(rl[0], 18, Vector2(13, -9), rl[1]):
						dilate(ci, poly, 9.0, RIM_COL)
			for rl in rolls:
				_cl_fur_roll_front(ci, rl[0], 18, Vector2(13, -9), rl[1], rl[2], false)
			sparks(ci, [Vector2(-44, -24), Vector2(40, -30), Vector2(50, 30)])

## 细藤：从 a 到 b 带波浪的一串点
static func _cl_vine_pts(a: Vector2, b: Vector2, amp: float, waves: float, n: int = 14) -> Array:
	var d := b - a
	var nrm := Vector2(-d.y, d.x).normalized()
	var out := []
	for k in n + 1:
		var t := float(k) / float(n)
		out.append(a.lerp(b, t) + nrm * sin(t * PI * waves) * amp)
	return out

## 整根藤是一个多边形（左右各偏移半个粗细），不会在接头处出现一道道横线；越往梢越细
static func _cl_vine(pts: Array, r: float, s: int, col: Color = RATTAN) -> Array:
	var n := pts.size()
	var lt := []
	var rt := []
	for i in n:
		var d: Vector2 = (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var nrm := Vector2(-d.y, d.x)
		var w := r * (1.0 - 0.35 * float(i) / float(n - 1))
		lt.append((pts[i] as Vector2) + nrm * w)
		rt.append((pts[i] as Vector2) - nrm * w)
	var d0: Vector2 = (pts[1] - pts[0]).normalized()
	rt.reverse()
	return [pg(lt + rt + [(pts[0] as Vector2) - d0 * r * 0.8], s, col, 2)]

## 沿藤在指定的点上长叶子，左右交替
static func _cl_vine_leaves(pts: Array, at: Array, l: float, s: int) -> Array:
	var out := []
	var k := 0
	for i in at:
		var idx := clampi(int(i), 1, pts.size() - 1)
		var d: Vector2 = pts[idx] - pts[idx - 1]
		var ang := d.angle() + (0.9 if k % 2 == 0 else -0.9)
		out.append(leaf(pts[idx], l, l * 0.36, ang, s + k, LEAF))
		k += 1
	return out

## 藤梢上的一个小卷须
static func _cl_tendril(ci: CanvasItem, c: Vector2, r: float, s: int) -> void:
	var arr := []
	for k in 14:
		var t := float(k) / 13.0
		var a := -PI * 0.5 + t * PI * 2.6
		arr.append(c + Vector2(cos(a), sin(a)) * r * (1.0 - t * 0.6) + Vector2(r, 0))
	pl(ci, arr, 3.4, INK, s)
	pl(ci, arr, 1.6, LEAF_D, s)

static func _main_art_v2(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			## 草茎：一根带穗的草，底下一片细叶
			sil(ci, [stk(Vector2(0, 36), Vector2(2, -18), 2.6, s, STRAW), ov(Vector2(2, -24), 4.2, 10, s + 1, GRASS_D, 0.05, 1),
				leaf(Vector2(1, 30), 22, 3.6, -2.2, s + 2, GRASS)], rim)
			for j in 4:
				var p := Vector2(2, -30.0 + float(j) * 4.0)
				ln(ci, p, p + Vector2(3, 2), 1.0, Color(INK, 0.35), s + j)
		2:
			## 一把草：五六根草扎一道，穗头朝上散开
			var tips := [Vector2(-16, -16), Vector2(-7, -24), Vector2(2, -27), Vector2(11, -23), Vector2(18, -14)]
			var parts := []
			for k in 5:
				parts.append(stk(Vector2(-2.0 + float(k), 36), tips[k], 2.4, s + k, STRAW if k % 2 == 0 else GRASS))
				var d: Vector2 = (tips[k] - Vector2(0, 36)).normalized()
				parts.append(ov(tips[k] + d * 5.0, 3.6, 8.0, s + 10 + k, GRASS_D, d.angle() + PI * 0.5, 1))
			parts.append(stk(Vector2(-7, 16), Vector2(7, 16), 3.0, s + 20, ROPE.darkened(0.2)))
			sil(ci, parts, rim)
		3:
			## 干草捆：一大捆干草，捆两道，上下都散开
			var pts := [Vector2(-22, -30), Vector2(-8, -36), Vector2(8, -36), Vector2(22, -30), Vector2(12, -14), Vector2(12, 14),
				Vector2(24, 36), Vector2(6, 38), Vector2(-8, 38), Vector2(-24, 35), Vector2(-13, 14), Vector2(-13, -14)]
			sil(ci, [pg(pts, s, STRAW, 0)], rim)
			for k in 8:
				var t := lerpf(-1.0, 1.0, float(k) / 7.0)
				pl(ci, [Vector2(t * 19.0, -31), Vector2(t * 11.0, -14), Vector2(t * 11.0, 14), Vector2(t * 20.0, 35)], 1.2, Color(GRASS_D, 0.7), s + k)
			for y in [-12.0, 12.0]:
				sil(ci, [pg([Vector2(-14, y - 2.5), Vector2(13, y - 2.5), Vector2(13, y + 3.0), Vector2(-14, y + 3.0)], s + int(y), ROPE.darkened(0.15))], false)
		4:
			## 麻丝：一小缕浅色的麻丝，左头扎住，右边散开
			var pts := [Vector2(-22, 24), Vector2(-20, 19), Vector2(-4, 16), Vector2(12, 12), Vector2(22, 15), Vector2(19, 21),
				Vector2(24, 28), Vector2(14, 32), Vector2(-4, 31), Vector2(-20, 31)]
			sil(ci, [pg(pts, s, FIBER, 0), stk(Vector2(-15, 16), Vector2(-15, 34), 2.8, s + 1, GRASS_D)], rim)
			for k in 5:
				var y := 19.0 + float(k) * 2.8
				pl(ci, [Vector2(-11, y + 1.0), Vector2(2, y - 1.0), Vector2(12, y + 1.0), Vector2(20, y - 1.0 + float(k % 2) * 2.0)], 1.1, Color(FIBER.darkened(0.3), 0.8), s + k)
		5:
			## 麻束：一束晒好的麻秆横躺着，捆两道，一头散出麻丝
			var pts := [Vector2(-34, 14), Vector2(18, 10), Vector2(30, 4), Vector2(36, 12), Vector2(32, 20), Vector2(38, 30),
				Vector2(20, 30), Vector2(-34, 32)]
			sil(ci, [pg(pts, s, FLAX, 0)], rim)
			for k in 5:
				var y := 15.0 + float(k) * 3.6
				pl(ci, [Vector2(-32, y), Vector2(16, y - 1.5 + float(k) * 0.3), Vector2(30, y - 6.0 + float(k) * 3.0)], 1.2, Color(FLAX.darkened(0.35), 0.8), s + k)
			for x in [-20.0, 4.0]:
				sil(ci, [pg([Vector2(x - 2.5, 10), Vector2(x + 3.0, 10), Vector2(x + 3.0, 34), Vector2(x - 2.5, 34)], s + int(x), ROPE.darkened(0.15))], false)
			ci.draw_colored_polygon(ell(Vector2(-34, 23), Vector2(3, 8.5), s, 0.05, 12), Color(FLAX.darkened(0.3)))
		6:
			## 麻线团：一个大线团，线头拖出来
			var c := Vector2(0, 16)
			sil(ci, [circ(c, 21, s, FIBER, 0)], rim)
			_cl_ball_det(ci, c, 21, s, [Color(FIBER.darkened(0.35), 0.9), Color(FIBER.darkened(0.2), 0.9)])
			var tail := [Vector2(18, 26), Vector2(26, 34), Vector2(36, 32), Vector2(42, 37)]
			pl(ci, tail, 4.2, INK, s)
			pl(ci, tail, 2.2, FIBER, s)
		7:
			## 棕榈叶：一片扇形的棕榈叶，带一截叶柄
			var base := Vector2(-4, 14)
			var parts := [stk(Vector2(10, 38), base, 2.4, s, LEAF_D)]
			parts.append_array(_cl_palm(base, 34, -PI * 0.5 - 0.2, s + 1))
			sil(ci, parts, rim)
			_cl_palm_det(ci, base, 34, -PI * 0.5 - 0.2, s)
		8:
			## 棕榈叶叠：三片棕榈叶叠在一起，扇面错开
			var parts := []
			var bases := [Vector2(-14, 18), Vector2(14, 18), Vector2(0, 22)]
			var angs := [-PI * 0.5 - 0.55, -PI * 0.5 + 0.55, -PI * 0.5]
			for k in 3:
				parts.append(stk(Vector2(0, 38), bases[k], 2.4, s + k * 10, LEAF_D))
			for k in 3:
				parts.append_array(_cl_palm(bases[k], 34, angs[k], s + 1 + k * 10, PALM.darkened(0.08 * float(2 - k))))
			sil(ci, parts, rim)
			_cl_palm_det(ci, bases[2], 34, angs[2], s)
		9:
			## 棕榈叶捆：一大捆棕榈叶，叶柄捆在一起立着，顶上扇面散开
			var parts := []
			var angs := [-PI * 0.5 - 0.8, -PI * 0.5 + 0.8, -PI * 0.5 - 0.3, -PI * 0.5 + 0.3]
			for k in 4:
				var top := Vector2(-6.0 + float(k) * 4.0, -2)
				parts.append(stk(Vector2(-3.0 + float(k) * 2.0, 38), top, 2.6, s + k * 10, LEAF_D))
				parts.append_array(_cl_palm(top, 38, angs[k], s + 1 + k * 10, PALM.darkened(0.06 * float(k % 2))))
			parts.append(stk(Vector2(-9, 22), Vector2(9, 22), 3.4, s + 50, ROPE.darkened(0.2)))
			sil(ci, parts, rim)
			_cl_palm_det(ci, Vector2(6, -2), 38, angs[3], s)
			_cl_palm_det(ci, Vector2(2, -2), 38, angs[2], s + 3)
		10:
			## 藤条：一根弯弯的长藤，一节一节
			var pts := [Vector2(-40, 30), Vector2(-20, 14), Vector2(4, 6), Vector2(24, -6), Vector2(38, -26)]
			sil(ci, _cl_cane(pts, 7.5, s) + [leaf(Vector2(4, 0), 16, 4.5, -1.9, s + 9, LEAF)], rim)
			_cl_cane_det(ci, pts, 7.5, s, 13.0)
		11:
			## 藤卷：一根长藤盘成好几圈，用细藤扎住
			_cl_coil(ci, Vector2(0, 18), 38, 19, 4, 4.0, s, RATTAN, rim)
			for sd in [-1.0, 1.0]:
				sil(ci, [stk(Vector2(sd * 30.0, 8), Vector2(sd * 33.0, 28), 2.2, s + 20 + int(sd), RATTAN.darkened(0.25))], false)
		12:
			## 大藤捆：一大捆粗藤横放，捆三道，带光
			glow(ci, Vector2(0, 10), 56, GOLD)
			var parts := []
			var ys := [30.0, 18.0, 6.0, 24.0, 12.0]
			for k in 5:
				var y: float = ys[k]
				parts.append(stk(Vector2(-44.0 + float(k % 2) * 4.0, y + 2.0), Vector2(44.0 - float(k % 3) * 3.0, y - 2.0), 6.0, s + k, RATTAN.darkened(0.06 * float(k % 2))))
			sil(ci, parts, rim)
			for k in 5:
				var y: float = ys[k]
				_cl_cane_det(ci, [Vector2(-44.0 + float(k % 2) * 4.0, y + 2.0), Vector2(44.0 - float(k % 3) * 3.0, y - 2.0)], 6.0, s + k, 14.0)
			for x in [-24.0, 0.0, 24.0]:
				sil(ci, [pg([Vector2(x - 3.0, 0), Vector2(x + 3.0, -1), Vector2(x + 3.0, 37), Vector2(x - 3.0, 38)], s + int(x), ROPE.darkened(0.2))], false)
			sparks(ci, [Vector2(-44, -22), Vector2(36, -26), Vector2(48, 30)])

## 上一版兽毛兽皮（一撮兽毛 … 毛皮堆，含一大蓬兽毛、小兽皮、毛皮条），留着以后用
static func _sub_art_v2(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			## 一撮兽毛：一小撮棕色的毛
			sil(ci, [_cl_tuft(Vector2(0, 28), 12, 8, s, PELT)], rim)
			_cl_hair(ci, Vector2(0, 28), 12, 8, 4, s, Color(FUR_D, 0.7))
		2:
			## 一团兽毛：一团蓬松的毛
			sil(ci, [_cl_tuft(Vector2(0, 22), 20, 15, s, PELT, 20)], rim)
			_cl_hair(ci, Vector2(0, 22), 20, 15, 8, s, Color(FUR_D, 0.7))
			hl(ci, Vector2(-7, 14), 5, 2.5, -0.3, 0.3)
		3:
			## 一大蓬兽毛：一大蓬毛，中间用绳子扎住
			sil(ci, [_cl_tuft(Vector2(-14, 16), 20, 20, s, PELT, 20), _cl_tuft(Vector2(14, 16), 20, 20, s + 1, PELT.lightened(0.08), 20)], rim)
			sil(ci, [stk(Vector2(0, -4), Vector2(0, 36), 3.0, s + 2, ROPE.darkened(0.2))], false)
			_cl_hair(ci, Vector2(-14, 16), 20, 20, 7, s, Color(FUR_D, 0.7))
			_cl_hair(ci, Vector2(14, 16), 20, 20, 7, s + 5, Color(FUR_D, 0.7))
		4:
			## 碎皮：两小块剥下来的边角皮
			sil(ci, [pg([Vector2(-26, 22), Vector2(-12, 14), Vector2(2, 18), Vector2(0, 32), Vector2(-20, 34)], s, RAWHIDE, 0),
				pg([Vector2(2, 26), Vector2(16, 18), Vector2(28, 24), Vector2(22, 36), Vector2(6, 36)], s + 1, RAWHIDE.darkened(0.08), 0)], rim)
			ci.draw_colored_polygon(ell(Vector2(-12, 25), Vector2(5, 3), s, 0.1, 10), Color(RAWHIDE.lightened(0.2), 0.7))
		5:
			## 小兽皮：一张兔子大小的灰皮，撑开摊着
			var pts := _cl_fluff(_cl_hide_pts(Vector2(0, 18), 24, 22, PI * 0.5), 3.5, 1.4)
			sil(ci, [pg(pts, s, PELT_G, 0)], rim)
			safe_poly(ci, PackedVector2Array(_cl_hide_pts(Vector2(0, 18), 14, 12, PI * 0.5)), Color(PELT_G.lightened(0.2), 0.8))
		6:
			## 大兽皮：一整张撑开的大兽皮，皮面朝上
			var pts := _cl_hide_pts(Vector2(0, 6), 42, 34, PI * 0.5)
			sil(ci, [pg(pts, s, RAWHIDE, 0)], rim)
			safe_poly(ci, PackedVector2Array(_cl_hide_pts(Vector2(0, 6), 26, 18, PI * 0.5)), Color(RAWHIDE.lightened(0.15), 0.8))
			for k in 4:
				ln(ci, Vector2(-18.0 + float(k) * 12.0, -4), Vector2(-16.0 + float(k) * 12.0, 14), 1.2, Color(RAWHIDE.darkened(0.25), 0.5), s + k)
		7:
			## 兽皮叠：三张撑过的兽皮叠在一起，皮角从边上露出来，颜色深浅不一
			var parts := []
			var cols := [RAWHIDE.darkened(0.15), BUCK, RAWHIDE]
			for k in 3:
				var c := Vector2(float(k % 2) * 6.0 - 3.0, 28.0 - float(k) * 10.0)
				parts.append(pg(_cl_hide_pts(c, 22, 40, PI * 0.5 + 0.04 * float(k - 1)), s + k, cols[k], 1))
			sil(ci, parts, rim)
			safe_poly(ci, PackedVector2Array(_cl_hide_pts(Vector2(-3, 8), 12, 24, PI * 0.5)), Color(RAWHIDE.lightened(0.15), 0.8))
			hl(ci, Vector2(-10, 4), 12, 2.5, -0.05, 0.35)
		8:
			## 毛皮条：一长条带厚毛的皮，弯着搭在地上
			var pts := []
			var spine := [Vector2(-40, 30), Vector2(-20, 18), Vector2(4, 16), Vector2(26, 8), Vector2(40, -8)]
			var top := []
			var bot := []
			for i in spine.size():
				var wd := lerpf(12.0, 6.0, float(i) / float(spine.size() - 1))
				top.append((spine[i] as Vector2) + Vector2(0, -wd))
				bot.append((spine[i] as Vector2) + Vector2(0, wd))
			bot.reverse()
			pts = _cl_fluff(top + bot, 4.0, 2.4)
			sil(ci, [pg(pts, s, PELT, 0)], rim)
			sil(ci, [_cl_tuft(Vector2(40, -9), 7, 6, s + 1, FOX)], false)
			pl(ci, spine.slice(0, 4), 2.0, Color(FUR_D, 0.6), s)
			for k in 8:
				var p: Vector2 = (spine[k / 2] as Vector2).lerp(spine[k / 2 + 1], 0.5 if k % 2 == 0 else 0.1) + Vector2(0, -4)
				pl(ci, [p, p + Vector2(2, 3), p + Vector2(1, 6)], 1.3, Color(FUR_D, 0.6), s + k)
		9:
			## 毛皮：一整张厚毛皮，毛朝上，四个皮角张开
			var pts := _cl_fluff(_cl_hide_pts(Vector2(0, 2), 44, 36, PI * 0.5), 4.0, 2.2)
			sil(ci, [pg(pts, s, PELT, 0)], rim)
			safe_poly(ci, PackedVector2Array(_cl_hide_pts(Vector2(0, 2), 26, 18, PI * 0.5)), Color(PELT.lightened(0.15), 0.8))
			_cl_hair(ci, Vector2(0, 2), 44, 26, 12, s, Color(FUR_D, 0.6))
		10:
			## 毛皮卷：一张厚毛皮卷成一大卷，用皮绳捆两道，卷口露出浅色的皮里子
			var body := _cl_fluff([Vector2(-30, -8), Vector2(30, -14), Vector2(38, 0), Vector2(40, 22), Vector2(32, 34), Vector2(-28, 38), Vector2(-38, 28), Vector2(-38, 4)], 5.0, 2.8)
			sil(ci, [pg(body, s, PELT, 0), ov(Vector2(-33, 15), 10, 21, s + 1, PELT.lightened(0.1), 0.08, 1)], rim)
			ci.draw_colored_polygon(ell(Vector2(-33, 15), Vector2(6, 15), s + 2, 0.05, 16, 0.08), HIDE2)
			for k in 3:
				pl(ci, arcp(Vector2(-33, 15), Vector2(5.0 - float(k) * 1.6, 13.0 - float(k) * 4.0), -PI * 0.5, PI * 1.5, 14), 1.4, Color(FUR_D, 0.7), s + k)
			for x in [-6.0, 20.0]:
				sil(ci, [pg([Vector2(x - 3.0, -12.0 - (x + 30.0) * 0.08), Vector2(x + 3.0, -12.0 - (x + 30.0) * 0.08), Vector2(x + 4.0, 37), Vector2(x - 2.0, 38)], s + int(x), LEATHER_D)], false)
			_cl_hair(ci, Vector2(4, 12), 56, 36, 12, s, Color(FUR_D, 0.6))
		11:
			## 毛皮堆：棕、灰、白三张厚毛皮堆成一大堆，带光
			glow(ci, Vector2(0, 6), 58, GOLD)
			var a := _cl_fluff([Vector2(-48, 22), Vector2(-30, 8), Vector2(30, 6), Vector2(48, 20), Vector2(44, 38), Vector2(-44, 38)], 5.0, 2.8)
			var b := _cl_fluff([Vector2(-38, 8), Vector2(-20, -8), Vector2(24, -10), Vector2(40, 6), Vector2(34, 22), Vector2(-34, 24)], 5.0, 2.6)
			var c := _cl_fluff([Vector2(-24, -8), Vector2(-8, -26), Vector2(14, -26), Vector2(28, -10), Vector2(20, 6), Vector2(-20, 8)], 4.5, 2.4)
			sil(ci, [pg(a, s, PELT, 0), pg(b, s + 1, PELT_G, 0), pg(c, s + 2, FOX, 0)], rim)
			_cl_hair(ci, Vector2(0, 30), 70, 8, 8, s, Color(FUR_D, 0.6))
			_cl_hair(ci, Vector2(0, 8), 56, 14, 8, s + 3, Color(PELT_G.darkened(0.35), 0.7))
			_cl_hair(ci, Vector2(2, -10), 36, 14, 6, s + 6, Color("b9c2d4"))
			sparks(ci, [Vector2(-44, -24), Vector2(40, -30), Vector2(50, 30)])

## 上一版植物料（草茎 … 大藤捆，藤是粗藤杆），留着以后用

## 一卷捆好的毛皮（横放）：c 是中心，w、h 是半长半高；左头露出卷口
static func _cl_fur_roll(ci: CanvasItem, c: Vector2, w: float, h: float, s: int, col: Color, rim: bool) -> void:
	var body := _cl_fluff([c + Vector2(-w, -h), c + Vector2(w * 0.8, -h - 1.0), c + Vector2(w, -h * 0.3), c + Vector2(w, h * 0.5), c + Vector2(w * 0.8, h),
		c + Vector2(-w, h)], 4.0, 2.2)
	sil(ci, [pg(body, s, col, 0), ov(c + Vector2(-w, 0), h * 0.5, h, s + 1, col.lightened(0.1), 0.0, 1)], rim)
	ci.draw_colored_polygon(ell(c + Vector2(-w, 0), Vector2(h * 0.3, h * 0.72), s + 2, 0.05, 14), HIDE2)
	pl(ci, arcp(c + Vector2(-w, 0), Vector2(h * 0.18, h * 0.45), -PI * 0.5, PI * 1.5, 12), 1.3, Color(col.darkened(0.4), 0.8), s)
	for x in [-w * 0.2, w * 0.5]:
		sil(ci, [pg([c + Vector2(x - 2.2, -h - 1.0), c + Vector2(x + 2.2, -h - 1.0), c + Vector2(x + 2.2, h + 1.0), c + Vector2(x - 2.2, h + 1.0)], s + int(x), LEATHER_D)], false)
	_cl_hair(ci, c + Vector2(4, 0), w * 1.4, h * 1.2, 6, s, Color(col.darkened(0.35), 0.6))

## 上一版副产物最高级：棕、灰、白三张摊开的厚毛皮堆成一堆，留着以后用
static func _fur_pile_v1(ci: CanvasItem, s: int, rim: bool) -> void:
		## 毛皮堆：棕、灰、白三张厚毛皮堆成一大堆，带光
		glow(ci, Vector2(0, 6), 58, GOLD)
		var a := _cl_fluff([Vector2(-48, 22), Vector2(-30, 8), Vector2(30, 6), Vector2(48, 20), Vector2(44, 38), Vector2(-44, 38)], 5.0, 2.8)
		var b := _cl_fluff([Vector2(-38, 8), Vector2(-20, -8), Vector2(24, -10), Vector2(40, 6), Vector2(34, 22), Vector2(-34, 24)], 5.0, 2.6)
		var c := _cl_fluff([Vector2(-24, -8), Vector2(-8, -26), Vector2(14, -26), Vector2(28, -10), Vector2(20, 6), Vector2(-20, 8)], 4.5, 2.4)
		sil(ci, [pg(a, s, PELT, 0), pg(b, s + 1, PELT_G, 0), pg(c, s + 2, FOX, 0)], rim)
		_cl_hair(ci, Vector2(0, 30), 70, 8, 8, s, Color(FUR_D, 0.6))
		_cl_hair(ci, Vector2(0, 8), 56, 14, 8, s + 3, Color(PELT_G.darkened(0.35), 0.7))
		_cl_hair(ci, Vector2(2, -10), 36, 14, 6, s + 6, Color("b9c2d4"))
		sparks(ci, [Vector2(-44, -24), Vector2(40, -30), Vector2(50, 30)])

## 卷口朝前的一卷毛皮：c 是卷口圆心，r 是半径，back 是身子往后伸的方向和长度
## 毛皮卷的身子和卷口两块轮廓（堆叠时先给整堆画一圈外描边要用）
static func _cl_fur_roll_polys(c: Vector2, r: float, back: Vector2, s: int) -> Array:
	var pts := []
	for k in 24:
		var a := TAU * float(k) / 24.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
		pts.append(c + back + Vector2(cos(a), sin(a)) * r * 0.96)
	var hull := Array(Geometry2D.convex_hull(PackedVector2Array(pts)))
	hull.pop_back()
	var body: PackedVector2Array = pg(_cl_fluff(hull, 4.0, 2.2), s, Color.WHITE)[0]
	var face: PackedVector2Array = pg(_cl_fluff(arcp(c, Vector2(r, r * 0.97), 0.0, TAU, 22).slice(0, 22), 3.5, 1.8), s + 1, Color.WHITE)[0]
	return [body, face]

static func _cl_fur_roll_front(ci: CanvasItem, c: Vector2, r: float, back: Vector2, s: int, col: Color, rim: bool) -> void:
	var polys := _cl_fur_roll_polys(c, r, back, s)
	sil(ci, [P(polys[0], col.darkened(0.08), 1), P(polys[1], col, 1)], rim)
	## 身子上的一道皮绳：沿后半个圆偏移，只画露在卷口外面的那段
	var band := arcp(c + back * 0.55, Vector2(r + 1.0, r + 1.0), -PI * 0.92, PI * 0.18, 14)
	pl(ci, band, 5.0, INK, s)
	pl(ci, band, 3.0, LEATHER_D.lightened(0.1), s)
	safe_poly(ci, ell(c, Vector2(r * 0.72, r * 0.7), s + 2, 0.04, 18), HIDE2)
	var sp := []
	for k in 40:
		var tt := float(k) / 39.0
		var a := tt * TAU * 2.6
		sp.append(c + Vector2(cos(a), sin(a)) * r * 0.68 * (1.0 - tt * 0.85))
	pl(ci, sp, 2.2, Color(col.darkened(0.15), 0.95), s)
	outline(ci, ell(c, Vector2(r * 0.72, r * 0.7), s + 2, 0.04, 18), 1.4, Color(INK, 0.6))
	_cl_hair(ci, c + back * 0.5 + Vector2(0, -r * 0.6), r * 0.8, r * 0.4, 3, s, Color(col.darkened(0.4), 0.6))

## 上一版副产物 10 级：侧面横放的毛皮卷（卷口在左边），留着以后用
static func _fur_roll_side_v1(ci: CanvasItem, s: int, rim: bool) -> void:
		## 毛皮卷：一张厚毛皮卷成一大卷，用皮绳捆两道，卷口露出浅色的皮里子
		var body := _cl_fluff([Vector2(-30, -8), Vector2(30, -14), Vector2(38, 0), Vector2(40, 22), Vector2(32, 34), Vector2(-28, 38), Vector2(-38, 28), Vector2(-38, 4)], 5.0, 2.8)
		sil(ci, [pg(body, s, PELT, 0), ov(Vector2(-33, 15), 10, 21, s + 1, PELT.lightened(0.1), 0.08, 1)], rim)
		ci.draw_colored_polygon(ell(Vector2(-33, 15), Vector2(6, 15), s + 2, 0.05, 16, 0.08), HIDE2)
		for k in 3:
			pl(ci, arcp(Vector2(-33, 15), Vector2(5.0 - float(k) * 1.6, 13.0 - float(k) * 4.0), -PI * 0.5, PI * 1.5, 14), 1.4, Color(FUR_D, 0.7), s + k)
		for x in [-6.0, 20.0]:
			sil(ci, [pg([Vector2(x - 3.0, -12.0 - (x + 30.0) * 0.08), Vector2(x + 3.0, -12.0 - (x + 30.0) * 0.08), Vector2(x + 4.0, 37), Vector2(x - 2.0, 38)], s + int(x), LEATHER_D)], false)
		_cl_hair(ci, Vector2(4, 12), 56, 36, 12, s, Color(FUR_D, 0.6))
