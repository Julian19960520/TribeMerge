class_name PACloth
extends PA
## 衣服线：编织架 / 衣物（主产物，只放穿在身上的衣服）/ 部落饰品（副产物，挂坠、手镯、头冠）

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

static func gen(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
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

static func main(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
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

static func sub(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
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
