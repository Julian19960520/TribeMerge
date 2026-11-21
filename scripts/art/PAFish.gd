class_name PAFish
extends PA
## 渔猎线：渔具 / 水产 / 贝类。第一稿（池塘、成串的鱼、成堆的贝）在 *_v1，第二稿（只有鱼、鲍鱼和珍珠贝）在 *_v2。

const WATER := Color("7cc3e8")
const BANK := Color("cfae7a")
const REED := Color("8aa84a")
const CATTAIL := Color("7a4a22")
const ROCK := Color("b3ada2")
const MINNOW := Color("b9d3da")
const SILVER := Color("9cc4d6")
const CRUCIAN := Color("b8a565")
const CARP := Color("e39a3c")
const CARP_R := Color("d9622f")
const CATFISH := Color("6e6658")
const SALMON := Color("e8806a")
const STURGEON := Color("7f919c")
const KALUGA := Color("c9a65a")
const BELLY := Color("f3ead6")
const SNAIL := Color("a08a58")
const SHRIMP := Color("f0946a")
const CRAB := Color("8a6a3e")
const BLUECRAB := Color("4f8a9a")
const MUSSEL := Color("4d5a3c")
const NACRE := Color("ece6f2")
const PEARL := Color("f6f1e8")

const F_GEN := [1.069, 1.114, 1.147, 1.414, 1.233, 1.399, 1.194, 1.746]
const F_MAIN := [1.308, 0.692, 1.2, 1.031, 0.844, 0.763, 0.892, 1.12, 0.816, 0.999, 1.248, 1.15, 1.122, 1.107, 1.452, 1.224]
const F_SUB := [0.723, 0.78, 0.908, 0.837, 0.793, 1.094, 0.97, 1.024, 1.094, 1.249, 1.093, 1.256]

static func gen(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	var keep := _f_grow(ci, F_GEN[clampi(lv, 1, 8) - 1])
	_gen_art(ci, lv, s, rim)
	_f_ungrow(ci, keep)

static func main(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	var keep := _f_grow(ci, F_MAIN[clampi(lv, 1, 16) - 1])
	_main_art(ci, lv, s, rim)
	_f_ungrow(ci, keep)

static func sub(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	var keep := _f_grow(ci, F_SUB[clampi(lv, 1, 12) - 1])
	_sub_art(ci, lv, s, rim)
	_f_ungrow(ci, keep)

static func _f_grow(ci: CanvasItem, k: float) -> Transform2D:
	var keep := xf
	xf = keep * Transform2D(0.0, Vector2(k, k), 0.0, Vector2(0, 38) * (1.0 - k))
	ci.draw_set_transform_matrix(xf)
	return keep

static func _f_ungrow(ci: CanvasItem, keep: Transform2D) -> void:
	xf = keep
	ci.draw_set_transform_matrix(xf)

static func _f_rim(ci: CanvasItem, parts: Array) -> void:
	for p in parts:
		dilate(ci, p[0], 9.0, RIM_COL)

## 两块多边形合成一块，取最大的那一片
static func _union(a: PackedVector2Array, b: PackedVector2Array) -> PackedVector2Array:
	var m := Geometry2D.merge_polygons(a, b)
	var best: PackedVector2Array = m[0]
	for q in m:
		if (q as PackedVector2Array).size() > best.size():
			best = q
	return best

# ---------------------------------------------------------------- 水、石、芦苇

static func _ripples(ci: CanvasItem, pts: Array, s: int) -> void:
	for i in pts.size():
		var p: Vector2 = pts[i]
		pl(ci, [p + Vector2(-6, 0), p + Vector2(-2, -1), p + Vector2(2, 0), p + Vector2(6, -1)], 1.6, Color(1, 1, 1, 0.75), s + i)

static func _stone(c: Vector2, rx: float, ry: float, s: int) -> Array:
	return ov(c, rx, ry, s, ROCK.lightened((srnd(s) - 0.5) * 0.16), 0.0, 0, 0.08)

static func _reed_parts(base: Vector2, h: float, lean: float, s: int, cattail: bool) -> Array:
	var top := base + Vector2(lean, -h)
	var out := [stk(base, top, 1.3, s, REED, 2)]
	if cattail:
		var d := (top - base).normalized()
		out.append(stk(top - d * 9.0, top - d * 1.0, 2.8, s + 1, CATTAIL, 1))
	return out

# ---------------------------------------------------------------- 鱼

## 侧面一条鱼，头朝左：返回 [身体, 尾巴, 背鳍] 三组点（以身体中心为原点）
static func _fish_geo(L: float, H: float, tail: float, fork: float) -> Array:
	var top := []
	var bot := []
	for k in 13:
		var t := float(k) / 12.0
		var pr := pow(sin(PI * (0.04 + 0.9 * t)), 0.7) * (1.0 - 0.55 * t * t) + 0.12 * t
		var x := lerpf(-L * 0.5, L * 0.5, t)
		top.append(Vector2(x, -H * pr))
		bot.append(Vector2(x, H * pr * 0.9))
	bot.reverse()
	var body := [Vector2(-L * 0.5 - H * 0.12, 0)] + top + bot
	var tb := Vector2(L * 0.5 - 2.0, 0)
	var tl := [tb + Vector2(0, -H * 0.22), tb + Vector2(tail, -H * 0.85), tb + Vector2(tail * (1.0 - fork), 0), tb + Vector2(tail, H * 0.85), tb + Vector2(0, H * 0.22)]
	var dorsal := [Vector2(-L * 0.1, -H * 0.85), Vector2(L * 0.04, -H * 1.42), Vector2(L * 0.2, -H * 0.8)]
	return [body, tl, dorsal]

static func _fish_parts(c: Vector2, L: float, H: float, ang: float, s: int, col: Color, tail: float = -1.0, fork: float = 0.45) -> Array:
	if tail < 0.0:
		tail = L * 0.3
	var g := _fish_geo(L, H, tail, fork)
	return [pg(rot_pts(g[1], ang, c), s, col.darkened(0.12), 1), pg(rot_pts(g[2], ang, c), s + 1, col.darkened(0.12), 1), pg(rot_pts(g[0], ang, c), s + 2, col, 0)]

static func _fp(c: Vector2, ang: float, p: Vector2) -> Vector2:
	return c + p.rotated(ang)

static func _fish_det(ci: CanvasItem, c: Vector2, L: float, H: float, ang: float, s: int, col: Color, scales: bool = true, whiskers: bool = false) -> void:
	ci.draw_colored_polygon(ell(_fp(c, ang, Vector2(L * 0.02, H * 0.48)), Vector2(L * 0.3, H * 0.26), s, 0.0, 14, ang), Color(BELLY, 0.6))
	var gill := []
	for p in arcp(Vector2(-L * 0.42, 0), Vector2(H * 0.28, H * 0.62), -1.15, 1.15, 8):
		gill.append(_fp(c, ang, p))
	pl(ci, gill, 1.5, Color(INK, 0.5), s)
	if scales:
		var step := maxf(H * 0.42, 3.0)
		var x := -L * 0.22
		var row := 0
		while x < L * 0.3:
			for y in [-0.3, 0.2]:
				var p := _fp(c, ang, Vector2(x + (step * 0.5 if row % 2 == 1 else 0.0), H * y))
				ci.draw_arc(p, step * 0.5, ang - 0.9, ang + 0.9, 5, Color(INK, 0.14), 1.0, true)
			x += step
			row += 1
	else:
		pl(ci, [_fp(c, ang, Vector2(-L * 0.3, -H * 0.05)), _fp(c, ang, Vector2(L * 0.42, 0))], 1.2, Color(INK, 0.25), s)
	var tb := Vector2(L * 0.5, 0)
	for k in 2:
		var dy := H * (0.3 + 0.25 * float(k))
		ln(ci, _fp(c, ang, tb + Vector2(2, -dy * 0.4)), _fp(c, ang, tb + Vector2(L * 0.2, -dy)), 1.1, Color(INK, 0.3), s + k)
		ln(ci, _fp(c, ang, tb + Vector2(2, dy * 0.4)), _fp(c, ang, tb + Vector2(L * 0.2, dy)), 1.1, Color(INK, 0.3), s + k + 2)
	var er := maxf(H * 0.17, 1.8)
	var e := _fp(c, ang, Vector2(-L * 0.4, -H * 0.18))
	ci.draw_circle(e, er, Color.WHITE)
	ci.draw_circle(e + Vector2(-er * 0.15, 0).rotated(ang), er * 0.6, INK)
	if whiskers:
		var m := _fp(c, ang, Vector2(-L * 0.5, H * 0.1))
		for k in 2:
			var w := Vector2(-L * 0.12, H * (0.4 + 0.5 * float(k))).rotated(ang)
			pl(ci, [m, m + w * 0.5 + Vector2(0, -1).rotated(ang), m + w], 1.3, Color(INK, 0.7), s + k)

## 一整条鱼（带白边或不带）
static func _fish(ci: CanvasItem, c: Vector2, L: float, H: float, ang: float, s: int, col: Color, rim: bool, scales: bool = true, whiskers: bool = false) -> void:
	sil(ci, _fish_parts(c, L, H, ang, s, col), rim)
	_fish_det(ci, c, L, H, ang, s, col, scales, whiskers)

## 一串鱼：草绳从上面的结垂下来，鱼头朝上挂着
static func _fish_string(ci: CanvasItem, knot: Vector2, fish: Array, s: int, col: Color, rim: bool) -> void:
	var all := []
	for q in fish:
		all.append_array(_fish_parts(q[0], q[1], q[2], q[3], s, col))
	if rim:
		_f_rim(ci, all)
	for q in fish:
		var c: Vector2 = q[0]
		var L: float = q[1]
		var mouth := _fp(c, q[3], Vector2(-L * 0.5, 0))
		pl(ci, [knot, knot.lerp(mouth, 0.5) + Vector2(0, 2), mouth], 3.6, INK, s)
		pl(ci, [knot, knot.lerp(mouth, 0.5) + Vector2(0, 2), mouth], 2.0, GRASS, s)
	for i in fish.size():
		var q: Array = fish[i]
		_fish(ci, q[0], q[1], q[2], q[3], s + i * 3, col, false)
	sil(ci, [circ(knot, 3.4, s, GRASS, 1)], false, 2.0)

## 鲟鱼：长身子、尖吻、背上一排骨板
static func _sturgeon(ci: CanvasItem, c: Vector2, L: float, H: float, s: int, col: Color, rim: bool) -> void:
	var snout := pg([c + Vector2(-L * 0.42, -H * 0.5), c + Vector2(-L * 0.5 - H * 1.3, H * 0.05), c + Vector2(-L * 0.42, H * 0.5)], s + 5, col.lightened(0.06), 1)
	var g := _fish_geo(L, H, L * 0.26, 0.5)
	var tl := rot_pts([Vector2(L * 0.48, -H * 0.3), Vector2(L * 0.5 + L * 0.3, -H * 1.5), Vector2(L * 0.5 + L * 0.1, 0), Vector2(L * 0.5 + L * 0.16, H * 0.7), Vector2(L * 0.48, H * 0.3)], 0.0, c)
	sil(ci, [pg(tl, s, col.darkened(0.12), 1), pg(rot_pts(g[2], 0.0, c), s + 1, col.darkened(0.12), 1), snout, pg(rot_pts(g[0], 0.0, c), s + 2, col, 0)], rim)
	_fish_det(ci, c, L, H, 0.0, s, col, false, true)
	for row in 2:
		var y := -H * (0.72 if row == 0 else 0.1)
		var n := 7 if row == 0 else 6
		for k in n:
			var x := lerpf(-L * 0.3, L * 0.4, float(k) / float(n - 1))
			var p := c + Vector2(x, y + (H * 0.1 if row == 0 else 0.0) * sin(float(k)))
			var r := H * (0.17 if row == 0 else 0.13)
			var dm := PackedVector2Array([p + Vector2(0, -r), p + Vector2(r * 1.2, 0), p + Vector2(0, r), p + Vector2(-r * 1.2, 0)])
			ci.draw_colored_polygon(dm, Color(BELLY, 0.95))
			outline(ci, dm, 1.0, Color(INK, 0.6))

# ---------------------------------------------------------------- 螺、虾蟹、蚌

## 田螺：一圈大的体螺层，上面一节比一节小地螺旋上去，螺口朝左下
static func _snail_whorls(r: float) -> Array:
	return [[Vector2(0, 0), r, r * 0.85], [Vector2(r * 0.5, -r * 0.78), r * 0.62, r * 0.52], [Vector2(r * 0.82, -r * 1.28), r * 0.38, r * 0.32], [Vector2(r * 1.0, -r * 1.58), r * 0.2, r * 0.18]]

static func _snail_parts(c: Vector2, r: float, ang: float, s: int) -> Array:
	var acc := PackedVector2Array()
	var ws := _snail_whorls(r)
	for i in ws.size():
		var q: Array = ws[i]
		var e := ell(q[0], Vector2(q[1], q[2]), s + i, 0.02, 18)
		acc = e if i == 0 else _union(acc, e)
	return [P(PackedVector2Array(rot_pts(Array(acc), ang, c)), SNAIL, 0)]

static func _snail_det(ci: CanvasItem, c: Vector2, r: float, ang: float, s: int) -> void:
	var ws := _snail_whorls(r)
	for i in range(1, ws.size()):
		var q: Array = ws[i]
		var p: Vector2 = q[0]
		pl(ci, rot_pts(arcp(p + Vector2(0, q[2] * 0.15), Vector2(q[1] * 1.05, q[2] * 0.9), PI * 0.15, PI * 0.95, 8), ang, c), 1.6, Color(INK, 0.55), s + i)
	for i in ws.size() - 1:
		var q: Array = ws[i]
		pl(ci, rot_pts(arcp(q[0], Vector2(q[1] * 0.7, q[2] * 0.55), PI * 1.15, PI * 1.75, 6), ang, c), 2.0, Color(SNAIL.darkened(0.35), 0.6), s + i + 5)
	var ap := ell(c + Vector2(-r * 0.32, r * 0.22).rotated(ang), Vector2(r * 0.45, r * 0.38), s, 0.03, 14, ang)
	ci.draw_colored_polygon(ap, Color("e8d6b0"))
	outline(ci, ap, 1.5)
	ci.draw_colored_polygon(ell(c + Vector2(-r * 0.3, r * 0.26).rotated(ang), Vector2(r * 0.3, r * 0.24), s + 1, 0.03, 12, ang), Color("5a4428"))
	hl(ci, c + Vector2(r * 0.25, -r * 0.35).rotated(ang), r * 0.22, r * 0.1, ang - 0.5, 0.55)

static func _snail(ci: CanvasItem, c: Vector2, r: float, ang: float, s: int, rim: bool) -> void:
	sil(ci, _snail_parts(c, r, ang, s), rim)
	_snail_det(ci, c, r, ang, s)

static func _crab(ci: CanvasItem, c: Vector2, r: float, s: int, col: Color, rim: bool) -> void:
	var parts := []
	for side in [-1.0, 1.0]:
		for k in 3:
			var a := c + Vector2(side * r * 0.7, r * (0.05 + 0.22 * float(k)))
			var b := a + Vector2(side * r * (0.55 + 0.1 * float(k)), -r * 0.05 + r * 0.25 * float(k))
			parts.append(stk(a, b, maxf(r * 0.09, 1.6), s + k, col.darkened(0.08), 2))
			parts.append(stk(b, b + Vector2(side * r * 0.15, r * 0.35), maxf(r * 0.08, 1.4), s + k + 3, col.darkened(0.08), 2))
		var arm := c + Vector2(side * r * 0.75, -r * 0.35)
		var claw := c + Vector2(side * r * 1.15, -r * 0.85)
		parts.append(stk(arm, claw, maxf(r * 0.13, 1.8), s + 7, col, 1))
		parts.append(ov(claw + Vector2(side * r * 0.05, -r * 0.12), r * 0.36, r * 0.27, s + 8, col.lightened(0.05), side * 0.6, 1))
	parts.append(ov(c, r, r * 0.68, s + 9, col, 0.0, 0))
	sil(ci, parts, rim)
	for side in [-1.0, 1.0]:
		var claw := c + Vector2(side * r * 1.2, -r * 0.97)
		ln(ci, claw, claw + Vector2(-side * r * 0.25, r * 0.02), 1.8, INK, s)
		var stalk := c + Vector2(side * r * 0.25, -r * 0.62)
		ln(ci, stalk, stalk + Vector2(0, -r * 0.22), 1.6, INK, s)
		ci.draw_circle(stalk + Vector2(0, -r * 0.26), maxf(r * 0.1, 1.6), INK)
	ci.draw_arc(c + Vector2(0, r * 0.1), r * 0.45, PI + 0.6, TAU - 0.6, 8, Color(INK, 0.3), 1.3, true)

static func _shrimp(ci: CanvasItem, c: Vector2, sz: float, s: int, rim: bool) -> void:
	var parts := []
	var segs := []
	for k in 6:
		var an := PI * 1.05 - float(k) * 0.42
		var p := c + Vector2(cos(an) * sz, sin(an) * sz * 0.8)
		segs.append(p)
	var tail: Vector2 = segs[5]
	parts.append(pg([tail, tail + Vector2(-sz * 0.35, sz * 0.25), tail + Vector2(-sz * 0.1, sz * 0.45), tail + Vector2(sz * 0.15, sz * 0.3)], s + 9, SHRIMP.darkened(0.08), 1))
	for k in range(5, -1, -1):
		var w := sz * (0.42 - 0.04 * float(k))
		parts.append(ov(segs[k], w, w * 0.8, s + k, SHRIMP, 0.0, 1, 0.02))
	sil(ci, parts, rim)
	var head: Vector2 = segs[0]
	for k in 2:
		pl(ci, [head + Vector2(-sz * 0.3, -sz * 0.1), head + Vector2(-sz * 0.6, -sz * (0.6 + 0.3 * float(k))), head + Vector2(-sz * 0.2, -sz * (1.2 + 0.2 * float(k)))], 1.2, Color(INK, 0.7), s + k)
	ci.draw_circle(head + Vector2(-sz * 0.12, -sz * 0.08), maxf(sz * 0.09, 1.4), INK)
	for k in range(1, 5):
		var p: Vector2 = segs[k]
		ln(ci, p + (c - p) * 0.05, p + (c - p) * 0.3, 1.1, Color(INK, 0.4), s + k)

## 蚌：长椭圆的壳，一头圆一头稍尖，壳上一圈圈生长纹
static func _mussel_pts(c: Vector2, L: float, H: float, ang: float) -> Array:
	var pts := []
	for k in 20:
		var an := TAU * float(k) / 20.0
		var x := cos(an) * L * 0.5
		var y := sin(an) * H * (1.0 - 0.25 * maxf(cos(an), 0.0))
		pts.append(Vector2(x, y))
	return rot_pts(pts, ang, c)

static func _mussel(ci: CanvasItem, c: Vector2, L: float, H: float, ang: float, s: int, rim: bool) -> void:
	sil(ci, [pg(_mussel_pts(c, L, H, ang), s, MUSSEL, 0)], rim)
	for k in 3:
		var f := 0.4 + float(k) * 0.22
		pl(ci, rot_pts(arcp(Vector2(-L * 0.25, 0), Vector2(L * 0.62 * f, H * f), -1.3, 1.3, 10), ang, c), 1.3, Color(Color("a7b38a"), 0.55), s + k)
	hl(ci, c + Vector2(-L * 0.12, -H * 0.45).rotated(ang), L * 0.16, H * 0.14, ang, 0.35)

## 张开的蚌：下半扇像只碟子，里面一层珍珠光；上半扇往后翻起
static func _open_mussel(ci: CanvasItem, c: Vector2, L: float, H: float, s: int, rim: bool, pearl: float = 0.0) -> void:
	var lower := []
	for k in 13:
		var an := PI * float(k) / 12.0
		lower.append(c + Vector2(cos(an) * L * 0.5, sin(an) * H))
	var upper := []
	for k in 13:
		var an := PI + PI * float(k) / 12.0
		upper.append(c + Vector2(cos(an) * L * 0.5 * 0.95, sin(an) * H * 1.5) + Vector2(L * 0.04, -H * 0.15))
	var inner := ell(c + Vector2(0, -H * 0.05), Vector2(L * 0.44, H * 0.55), s + 3, 0.02, 20)
	sil(ci, [pg(upper, s, MUSSEL.lightened(0.05), 1), pg(lower + [c + Vector2(-L * 0.5, -H * 0.2)], s + 1, MUSSEL, 1)], rim)
	var up_in := ell(c + Vector2(L * 0.04, -H * 0.85), Vector2(L * 0.4, H * 0.62), s + 4, 0.02, 20)
	ci.draw_colored_polygon(up_in, NACRE.darkened(0.06))
	outline(ci, up_in, 1.4)
	ci.draw_colored_polygon(inner, NACRE)
	outline(ci, inner, 1.6)
	ci.draw_colored_polygon(ell(c + Vector2(L * 0.12, H * 0.05), Vector2(L * 0.2, H * 0.22), s, 0.0, 12), Color(Color("f2c6d6"), 0.5))
	ci.draw_colored_polygon(ell(c + Vector2(-L * 0.14, -H * 0.15), Vector2(L * 0.16, H * 0.18), s + 1, 0.0, 12), Color(Color("bfe0f0"), 0.5))
	if pearl > 0.0:
		_pearl(ci, c + Vector2(0, -H * 0.05), pearl, s, false)

static func _pearl(ci: CanvasItem, c: Vector2, r: float, s: int, rim: bool) -> void:
	sil(ci, [circ(c, r, s, PEARL, 1, 0.01)], rim, 2.2)
	ci.draw_colored_polygon(ell(c + Vector2(r * 0.15, r * 0.2), Vector2(r * 0.6, r * 0.5), s, 0.0, 12), Color(Color("e8d8e8"), 0.6))
	ci.draw_circle(c + Vector2(-r * 0.35, -r * 0.35), maxf(r * 0.25, 1.0), Color.WHITE)

# ---------------------------------------------------------------- 生产器：渔场

## 水边小景：先画地面（岸），再铺水面（不描黑边，只有一圈深一点的水线），最后画水里水上的东西。白边按全部算
static func _scene(ci: CanvasItem, ground: Array, pools: Array, fg: Array, s: int, rim: bool) -> void:
	if rim:
		_f_rim(ci, ground + fg)
	sil(ci, ground, false)
	for i in pools.size():
		var q: Array = pools[i]
		var rot: float = q[3] if q.size() > 3 else 0.0
		var e := ell(q[0], Vector2(q[1], q[2]), s + i, 0.03, 22, rot)
		ci.draw_colored_polygon(e, WATER)
		outline(ci, e, 1.6, Color(WATER.darkened(0.35), 0.9))
		ci.draw_colored_polygon(ell((q[0] as Vector2) + Vector2(0, -float(q[2]) * 0.25), Vector2(float(q[1]) * 0.8, float(q[2]) * 0.5), s + i + 7, 0.03, 18, rot), WATER.lightened(0.12))
	if not fg.is_empty():
		sil(ci, fg, false)

## 渔场第一稿（池塘、鱼梁），留着备用
static func _gen_art_v1(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			## 浅水洼：一小汪水，边上几根芦苇、一块石头
			var fg := _reed_parts(Vector2(-24, 31), 30, -3, s + 2, true) + _reed_parts(Vector2(-19, 33), 22, 3, s + 4, false)
			fg.append(_stone(Vector2(22, 34), 6, 4.5, s + 6))
			_scene(ci, [ov(Vector2(0, 32), 32, 9, s, BANK, 0.0, 2)], [[Vector2(2, 31), 27.0, 6.5]], fg, s, rim)
			_ripples(ci, [Vector2(4, 30)], s)
		2:
			## 小河湾：一段弯弯的小河，岸边散着石头，一丛芦苇
			var bank := _union(ell(Vector2(-12, 25), Vector2(32, 12), s + 2, 0.03, 20, 0.3), ell(Vector2(14, 31), Vector2(32, 11), s + 3, 0.03, 20, -0.2))
			var fg := _reed_parts(Vector2(30, 26), 30, 2, s + 4, true) + _reed_parts(Vector2(35, 28), 20, 5, s + 6, false)
			fg.append(_stone(Vector2(-34, 30), 6, 4.5, s + 8))
			fg.append(_stone(Vector2(-4, 38), 7, 4.5, s + 9))
			_scene(ci, [P(bank, BANK, 2)], [[Vector2(-12, 24), 25.0, 7.5, 0.3], [Vector2(14, 31), 25.0, 7.5, -0.2]], fg, s, rim)
			_ripples(ci, [Vector2(-14, 23), Vector2(10, 30)], s)
		3:
			## 半截鱼梁：河里刚垒了三块石头，岸上还堆着两块等着搬
			var fg := []
			for k in 3:
				fg.append(_stone(Vector2(-28.0 + float(k) * 14.0, 27.0 + float(k) * 1.5), 7.5, 6.5, s + 2 + k))
			fg.append(_stone(Vector2(34, 37), 7, 5, s + 6))
			fg.append(_stone(Vector2(38, 30), 5.5, 4.5, s + 7))
			_scene(ci, [ov(Vector2(0, 30), 44, 12, s, BANK, 0.0, 2)], [[Vector2(-2, 30), 32.0, 7.0]], fg, s, rim)
			_ripples(ci, [Vector2(14, 31), Vector2(-6, 36)], s)
		4:
			## 石头鱼梁：一排石头拦过河，水从石缝里哗哗流过，鱼就被拦在里面
			var fg := []
			for k in 6:
				var t := float(k) / 5.0
				fg.append(_stone(Vector2(lerpf(-34.0, 34.0, t), 29.0 - sin(PI * t) * 6.0), 7.5, 6.5, s + 2 + k))
			_scene(ci, [ov(Vector2(0, 30), 46, 13, s, BANK, 0.0, 2)], [[Vector2(0, 30), 35.0, 7.5]], fg, s, rim)
			for k in 5:
				var t := (float(k) + 0.5) / 5.0
				var p := Vector2(lerpf(-34.0, 34.0, t), 29.0 - sin(PI * t) * 6.0)
				pl(ci, [p + Vector2(0, 3), p + Vector2(1, 7), p + Vector2(0, 10)], 1.6, Color(1, 1, 1, 0.85), s + k)
			sil(ci, [pg([Vector2(-8, 36), Vector2(-4, 32), Vector2(0, 36)], s + 20, SILVER, 1)], false, 2.0)
		5:
			## 鱼笼：一只藤编的鱼笼斜泡在浅水里，口大肚小，两根木桩把它别住
			var mouth := Vector2(-14, 16)
			var tip := Vector2(30, 24)
			var cone := [mouth + Vector2(0, -15), tip + Vector2(0, -4), tip + Vector2(4, 0), tip + Vector2(0, 4), mouth + Vector2(0, 15)]
			var fg := [stk(Vector2(-22, 34), Vector2(-24, 2), 2.4, s + 2, WOOD_D), stk(Vector2(28, 32), Vector2(30, 10), 2.4, s + 3, WOOD_D),
				pg(cone, s + 4, ROPE.darkened(0.1), 1), ov(mouth, 8, 15, s + 5, ROPE, 0.0, 1)]
			_scene(ci, [ov(Vector2(0, 32), 44, 11, s, BANK, 0.0, 2)], [[Vector2(0, 31), 34.0, 7.0]], fg, s, rim)
			for k in 4:
				var t := (float(k) + 1.0) / 5.0
				ci.draw_arc(mouth.lerp(tip, t), lerpf(15.0, 4.0, t), -PI * 0.5, PI * 0.5, 8, Color(WOOD_D, 0.7), 1.4, true)
			for k in 3:
				var y := -9.0 + float(k) * 9.0
				ln(ci, mouth + Vector2(4, y), tip + Vector2(-2, y * 0.2), 1.2, Color(WOOD_D, 0.6), s + k)
			ci.draw_colored_polygon(ell(mouth, Vector2(5, 11), s, 0.0, 14), Color("3b2314"))
			_ripples(ci, [Vector2(-30, 31), Vector2(14, 36)], s)
		6:
			## 渔网架：两根木桩搭一根横杆，上面晾着一张渔网，网下坠着几块小石头
			var net := [Vector2(-28, -13), Vector2(28, -15), Vector2(24, 10), Vector2(16, 22), Vector2(6, 18), Vector2(-4, 24), Vector2(-14, 18), Vector2(-24, 22)]
			var fg := [stk(Vector2(-30, 38), Vector2(-28, -18), 3.2, s + 2, WOOD), stk(Vector2(30, 38), Vector2(28, -18), 3.2, s + 3, WOOD),
				stk(Vector2(-36, -14), Vector2(36, -16), 3.0, s + 4, WOOD_D), pg(net, s + 5, ROPE.lightened(0.15), 2)]
			_scene(ci, [ov(Vector2(0, 37), 44, 7, s, BANK, 0.0, 2)], [[Vector2(0, 38), 32.0, 4.0]], fg, s, rim)
			var np := PackedVector2Array(net)
			for k in 9:
				var x := -36.0 + float(k) * 8.0
				for seg in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([Vector2(x, -16), Vector2(x + 26, 26)]), np):
					ci.draw_polyline(seg, Color(WOOD_D, 0.7), 1.2, true)
				for seg in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([Vector2(x + 26, -16), Vector2(x, 26)]), np):
					ci.draw_polyline(seg, Color(WOOD_D, 0.7), 1.2, true)
			sil(ci, [_stone(Vector2(-24, 25), 3.5, 3, s + 10), _stone(Vector2(-4, 27), 3.5, 3, s + 11), _stone(Vector2(16, 25), 3.5, 3, s + 12)], false, 2.0)
		7:
			## 水边渔棚：一座架在水上的小棚子，茅草顶，屋檐下挂着一条鱼
			var fg := []
			for x in [-24.0, -8.0, 8.0, 24.0]:
				fg.append(stk(Vector2(x, 36), Vector2(x, 10), 2.4, s + int(x), WOOD_D, 1))
			fg.append(bx(-32, 6, 64, 7, 2, s + 5, WOOD))
			fg.append(bx(-22, -16, 44, 24, 2, s + 6, Color("d9b07a")))
			fg.append(pg([Vector2(-36, -12), Vector2(0, -44), Vector2(36, -12), Vector2(30, -8), Vector2(-30, -8)], s + 7, GRASS, 1))
			_scene(ci, [ov(Vector2(0, 34), 46, 10, s, BANK, 0.0, 2)], [[Vector2(0, 34), 42.0, 8.0]], fg, s, rim)
			ci.draw_colored_polygon(rrect(Rect2(-6, -8, 12, 16), 2, s), Color("3b2314"))
			for k in 6:
				var x := -28.0 + float(k) * 11.0
				ln(ci, Vector2(x * 0.3, -38), Vector2(x, -10), 1.3, Color(GRASS_D, 0.8), s + k)
			ln(ci, Vector2(-30, 9), Vector2(30, 9), 1.2, Color(WOOD_D, 0.8), s)
			_ripples(ci, [Vector2(-34, 35), Vector2(33, 37)], s)
			pl(ci, [Vector2(22, -8), Vector2(22, -2)], 1.4, INK, s)
			_fish(ci, Vector2(22, 6), 14, 3.6, PI * 0.5, s + 30, SILVER, false, false)
		_:
			## 独木舟码头：一段木栈桥伸进水里，边上停着一条独木舟，船里横着一支桨
			var fg := []
			for p in [Vector2(-36, 14), Vector2(-20, 8), Vector2(-4, 2), Vector2(-26, 22), Vector2(-10, 16)]:
				fg.append(stk(p, p + Vector2(0, 14), 2.2, s + int(p.x), WOOD_D, 1))
			fg.append(pg([Vector2(-46, 8), Vector2(-6, -8), Vector2(6, -2), Vector2(-34, 16)], s + 6, WOOD, 1))
			var hull := []
			for k in 13:
				var t := float(k) / 12.0
				hull.append(Vector2(lerpf(-6.0, 46.0, t), lerpf(32.0, 20.0, t) - 4.0 * sin(PI * t)))
			for k in 13:
				var t := 1.0 - float(k) / 12.0
				hull.append(Vector2(lerpf(-6.0, 46.0, t), lerpf(32.0, 20.0, t) + 6.0 * sin(PI * t)))
			fg.append(pg(hull, s + 7, Color("8a5a34"), 1))
			_scene(ci, [ov(Vector2(0, 31), 50, 13, s, BANK, 0.0, 2)], [[Vector2(2, 30), 46.0, 11.0]], fg, s, rim)
			for k in 4:
				var t := (float(k) + 1.0) / 5.0
				ln(ci, Vector2(-46, 8).lerp(Vector2(-6, -8), t), Vector2(-34, 16).lerp(Vector2(6, -2), t), 1.3, Color(WOOD_D, 0.8), s + k)
			var inner := ell(Vector2(20, 24.5), Vector2(21, 3.2), s, 0.02, 18, -0.23)
			ci.draw_colored_polygon(inner, Color("4a2c14"))
			outline(ci, inner, 1.4)
			sil(ci, [stk(Vector2(6, 26), Vector2(32, 20), 1.8, s + 20, WOOD, 2), ov(Vector2(35, 19.5), 5, 2.4, s + 21, WOOD, -0.22, 1)], false, 2.0)
			pl(ci, [Vector2(-6, 0), Vector2(-2, 12), Vector2(0, 24)], 1.4, Color(ROPE, 0.95), s)
			_ripples(ci, [Vector2(-30, 36), Vector2(36, 34)], s)

# ---------------------------------------------------------------- 主产物：鱼

## 鱼第一稿（成串的鱼），留着备用
static func _main_art_v1(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			## 鱼苗：三条半透明的小鱼苗，大眼睛，身子还看得见骨头
			var fs := [[Vector2(-10, 26), 16.0, 3.6, -0.2], [Vector2(10, 33), 14.0, 3.2, 0.15], [Vector2(6, 18), 12.0, 2.8, -0.1]]
			var all := []
			for q in fs:
				all.append_array(_fish_parts(q[0], q[1], q[2], q[3], s, MINNOW))
			if rim:
				_f_rim(ci, all)
			for i in fs.size():
				var q: Array = fs[i]
				_fish(ci, q[0], q[1], q[2], q[3], s + i * 3, MINNOW, false, false)
		2:
			## 小鱼：一条银亮的小鱼
			_fish(ci, Vector2(-2, 26), 34, 8, -0.15, s, SILVER, rim)
		3:
			## 一串小鱼：三条小鱼用草绳穿着腮，提溜成一串
			_fish_string(ci, Vector2(0, -12), [[Vector2(-14, 14), 30.0, 7.0, PI * 0.5 + 0.25], [Vector2(0, 18), 32.0, 7.5, PI * 0.5], [Vector2(14, 14), 30.0, 7.0, PI * 0.5 - 0.25]], s, SILVER, rim)
		4:
			## 鲫鱼：身子短而厚的鲫鱼，背上青黄发亮
			_fish(ci, Vector2(-2, 22), 44, 15, -0.12, s, CRUCIAN, rim)
		5:
			## 一串鲫鱼：三条鲫鱼穿成一串
			_fish_string(ci, Vector2(0, -26), [[Vector2(-17, 8), 38.0, 12.0, PI * 0.5 + 0.22], [Vector2(0, 12), 40.0, 13.0, PI * 0.5], [Vector2(17, 8), 38.0, 12.0, PI * 0.5 - 0.22]], s, CRUCIAN, rim)
		6:
			## 鲤鱼：金黄的鲤鱼，大鳞片，嘴边两根短须
			_fish(ci, Vector2(-2, 20), 56, 15, -0.12, s, CARP, rim, true, true)
		7:
			## 大鲤鱼：一条红金色的大鲤鱼，尾巴翘起来
			_fish(ci, Vector2(-4, 16), 72, 19, -0.2, s, CARP_R, rim, true, true)
		8:
			## 鲶鱼：灰褐色的鲶鱼，扁脑袋，没有鳞，嘴边两条长胡子
			_fish(ci, Vector2(0, 24), 64, 12, -0.08, s, CATFISH, rim, false, true)
		9:
			## 大鲶鱼：一条又长又肥的大鲶鱼
			_fish(ci, Vector2(-2, 20), 82, 16, -0.12, s, CATFISH.darkened(0.05), rim, false, true)
		10:
			## 鲑鱼：粉红肉色的鲑鱼，背上一点点黑斑
			_fish(ci, Vector2(-2, 22), 64, 14, -0.15, s, SALMON, rim)
			for k in 5:
				ci.draw_circle(_fp(Vector2(-2, 22), -0.15, Vector2(-14.0 + float(k) * 8.0, -8.0 + float(k % 2) * 3.0)), 1.3, Color(INK, 0.6))
		11:
			## 一对鲑鱼：两条鲑鱼交叉着摆在一起
			var a := _fish_parts(Vector2(-2, 12), 64, 14, -0.35, s, SALMON)
			var b := _fish_parts(Vector2(2, 28), 64, 14, 0.3, s + 5, SALMON.darkened(0.05))
			if rim:
				_f_rim(ci, a + b)
			_fish(ci, Vector2(-2, 12), 64, 14, -0.35, s, SALMON, false)
			_fish(ci, Vector2(2, 28), 64, 14, 0.3, s + 5, SALMON.darkened(0.05), false)
		12:
			## 一串鲑鱼：三条大鲑鱼挂成一串
			_fish_string(ci, Vector2(0, -38), [[Vector2(-20, 4), 62.0, 13.0, PI * 0.5 + 0.2], [Vector2(0, 8), 66.0, 14.0, PI * 0.5], [Vector2(20, 4), 62.0, 13.0, PI * 0.5 - 0.2]], s, SALMON, rim)
		13:
			## 小鲟鱼：一条尖嘴、背上一排白骨板的小鲟鱼
			_sturgeon(ci, Vector2(4, 24), 56, 9, s, STURGEON, rim)
		14:
			## 鲟鱼：长长的鲟鱼
			_sturgeon(ci, Vector2(4, 22), 72, 11, s, STURGEON, rim)
		15:
			## 大鲟鱼：一条比人还长的大鲟鱼
			_sturgeon(ci, Vector2(2, 18), 70, 17, s, STURGEON.darkened(0.06), rim)
		_:
			## 鳇鱼王：河里最大的鳇鱼，金褐色，浑身发亮，是渔获里最珍贵的
			glow(ci, Vector2(0, 14), 58, GOLD)
			_sturgeon(ci, Vector2(2, 16), 70, 20, s, KALUGA, rim)
			sparks(ci, [Vector2(-40, -10), Vector2(34, -20), Vector2(44, 30)])

# ---------------------------------------------------------------- 副产物：水边收获

## 水边收获第一稿（成堆的螺和蚌），留着备用
static func _sub_art_v1(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			## 田螺：一只青褐色的田螺，螺口盖着小盖子
			_snail(ci, Vector2(0, 24), 14, -0.3, s, rim)
		2:
			## 一把田螺：三只田螺挤在一起
			var cs := [[Vector2(-12, 22), 12.0, -0.4], [Vector2(12, 20), 12.0, 0.3], [Vector2(0, 30), 13.0, -0.1]]
			var all := []
			for q in cs:
				all.append_array(_snail_parts(q[0], q[1], q[2], s))
			if rim:
				_f_rim(ci, all)
			for i in cs.size():
				var q: Array = cs[i]
				_snail(ci, q[0], q[1], q[2], s + i * 3, false)
		3:
			## 一堆田螺：六只田螺堆成一小堆
			var cs := [[Vector2(-8, 4), 11.0, -0.2], [Vector2(10, 6), 11.0, 0.4], [Vector2(-20, 20), 12.0, -0.5], [Vector2(2, 20), 12.0, 0.1], [Vector2(22, 22), 11.0, 0.5], [Vector2(-8, 34), 12.0, -0.2], [Vector2(14, 35), 11.0, 0.3]]
			var all := []
			for q in cs:
				all.append_array(_snail_parts(q[0], q[1], q[2], s))
			if rim:
				_f_rim(ci, all)
			for i in cs.size():
				var q: Array = cs[i]
				_snail(ci, q[0], q[1], q[2], s + i * 3, false)
		4:
			## 小河虾：一只弓着背的小河虾，长须
			_shrimp(ci, Vector2(6, 22), 22, s, rim)
		5:
			## 河蟹：一只青褐色的河蟹，举着两只钳子
			_crab(ci, Vector2(0, 24), 18, s, CRAB, rim)
		6:
			## 大青蟹：一只青蓝色的大螃蟹，钳子又大又壮
			_crab(ci, Vector2(0, 22), 24, s, BLUECRAB, rim)
		7:
			## 河蚌：一只合着的河蚌，黑绿的壳上一圈圈生长纹
			_mussel(ci, Vector2(0, 24), 52, 16, -0.15, s, rim)
		8:
			## 张开的河蚌：蚌壳张开，里面一层珍珠光
			_open_mussel(ci, Vector2(0, 26), 58, 14, s, rim)
		9:
			## 一堆河蚌：三只合着的河蚌，前面一只张着口
			var ms := [[Vector2(-14, 6), -0.3], [Vector2(16, 8), 0.25], [Vector2(-4, 18), 0.05]]
			var all := []
			for q in ms:
				all.append(pg(_mussel_pts(q[0], 46, 14, q[1]), s, MUSSEL, 0))
			if rim:
				_f_rim(ci, all)
			for i in ms.size():
				var q: Array = ms[i]
				_mussel(ci, q[0], 46, 14, q[1], s + i * 3, false)
			_open_mussel(ci, Vector2(2, 32), 50, 11, s + 20, rim)
		10:
			## 一颗小珍珠：一颗圆润的白珍珠，泛着粉光
			_pearl(ci, Vector2(0, 26), 11, s, rim)
			sparks(ci, [Vector2(14, 10)], 4.0)
		11:
			## 含珍珠的蚌：张开的蚌里躺着一颗大珍珠
			glow(ci, Vector2(0, 20), 42, Color("fff2d6"))
			_open_mussel(ci, Vector2(0, 26), 62, 15, s, rim, 8.0)
			sparks(ci, [Vector2(-24, 0), Vector2(26, -4)], 4.5)
		_:
			## 一捧珍珠：一片荷叶上堆着一捧大大小小的珍珠
			glow(ci, Vector2(0, 16), 56, GOLD)
			var lf := ell(Vector2(0, 30), Vector2(44, 12), s, 0.05, 24)
			sil(ci, [P(lf, LEAF, 1)], rim)
			for k in 5:
				var an := PI * 0.1 + float(k) * PI * 0.2
				ln(ci, Vector2(0, 30), Vector2(0, 30) + Vector2(cos(an) * 38.0, sin(an) * 10.0), 1.2, Color(LEAF_D, 0.8), s + k)
			var ps := [[Vector2(-20, 24), 7.0], [Vector2(-6, 26), 8.0], [Vector2(10, 25), 7.5], [Vector2(24, 26), 6.5], [Vector2(-13, 14), 7.5], [Vector2(3, 13), 8.5], [Vector2(18, 15), 7.0], [Vector2(-4, 2), 8.0], [Vector2(-28, 31), 5.0], [Vector2(30, 32), 5.0]]
			for q in ps:
				_pearl(ci, q[0], q[1], s, false)
			sparks(ci, [Vector2(-34, -10), Vector2(30, -16), Vector2(42, 14)])

# ================================================================ 第二稿：渔具 / 单条的鱼 / 单个的贝

const BONE_HOOK := Color("efe2c4")
const BAMBOO := Color("c9b864")
const TRAP := Color("c9a46a")
const FACE := Color("e8c48a")

# ---------------------------------------------------------------- 一种鱼

## 一种鱼。o 里可选：scales（默认有鳞）whisk 胡须、stripe 纵纹、bars 横斑、spots 斑点、spiny 刺背鳍、back_dorsal 背鳍靠后、snout 长吻、patch 肩斑、fin 鳍色
static func _sp(ci: CanvasItem, c: Vector2, L: float, H: float, ang: float, s: int, col: Color, rim: bool, o: Dictionary = {}) -> void:
	var g := _fish_geo(L, H, L * float(o.get("tail", 0.3)), float(o.get("fork", 0.45)))
	var fin: Color = o.get("fin", col.darkened(0.12))
	var parts := [pg(rot_pts(g[1], ang, c), s, fin, 1)]
	if o.get("spiny", false):
		var sp := [Vector2(-L * 0.22, -H * 0.75)]
		for k in 9:
			var x := lerpf(-L * 0.2, L * 0.26, float(k) / 8.0)
			sp.append(Vector2(x, -H * (1.5 if k % 2 == 0 else 1.05) * (1.0 - 0.2 * float(k) / 8.0)))
		sp.append(Vector2(L * 0.3, -H * 0.7))
		parts.append(pg(rot_pts(sp, ang, c), s + 1, fin, 1))
	elif o.get("back_dorsal", false):
		parts.append(pg(rot_pts([Vector2(L * 0.16, -H * 0.7), Vector2(L * 0.3, -H * 1.35), Vector2(L * 0.42, -H * 0.45)], ang, c), s + 1, fin, 1))
	else:
		parts.append(pg(rot_pts(g[2], ang, c), s + 1, fin, 1))
	if o.get("snout", false):
		parts.append(pg(rot_pts([Vector2(-L * 0.38, -H * 0.5), Vector2(-L * 0.5 - H * 1.3, -H * 0.12), Vector2(-L * 0.5 - H * 1.25, H * 0.18), Vector2(-L * 0.38, H * 0.55)], ang, c), s + 3, col, 1))
	parts.append(pg(rot_pts(g[0], ang, c), s + 2, col, 0))
	sil(ci, parts, rim)
	_fish_det(ci, c, L, H, ang, s, col, o.get("scales", true), o.get("whisk", false))
	if o.has("stripe"):
		pl(ci, [_fp(c, ang, Vector2(-L * 0.34, -H * 0.05)), _fp(c, ang, Vector2(0, -H * 0.02)), _fp(c, ang, Vector2(L * 0.46, 0))], maxf(H * 0.28, 1.8), o["stripe"], s)
	if o.has("bars"):
		for k in 5:
			var x := lerpf(-L * 0.2, L * 0.32, float(k) / 4.0)
			ln(ci, _fp(c, ang, Vector2(x, -H * 0.75)), _fp(c, ang, Vector2(x - H * 0.1, H * 0.35)), maxf(H * 0.22, 2.0), o["bars"], s + k)
	if o.has("spots"):
		for k in 9:
			var p := Vector2(lerpf(-L * 0.25, L * 0.36, srnd(s + k * 3)), lerpf(-H * 0.6, H * 0.4, srnd(s + k * 7 + 1)))
			ci.draw_colored_polygon(ell(_fp(c, ang, p), Vector2(H * 0.16, H * 0.12), s + k, 0.2, 8, ang), o["spots"])
	if o.has("patch"):
		ci.draw_colored_polygon(ell(_fp(c, ang, Vector2(-L * 0.2, -H * 0.1)), Vector2(H * 0.45, H * 0.3), s, 0.05, 10, ang), o["patch"])

## 鳗鱼：一条蛇一样弯来弯去的长身子，尾巴尖，背上一道长鳍
static func _eel(ci: CanvasItem, c: Vector2, L: float, W: float, s: int, col: Color, rim: bool) -> void:
	var spine := []
	for k in 17:
		var t := float(k) / 16.0
		spine.append(c + Vector2(lerpf(-L * 0.5, L * 0.5, t), sin(t * TAU * 1.1 + 0.4) * W * 1.3))
	var up := []
	var dn := []
	for k in 17:
		var t := float(k) / 16.0
		var p: Vector2 = spine[k]
		var d: Vector2 = ((spine[mini(k + 1, 16)] as Vector2) - (spine[maxi(k - 1, 0)] as Vector2)).normalized()
		var n := d.orthogonal()
		var w := W * (0.85 + 0.15 * sin(PI * minf(t * 3.0, 1.0))) * (1.0 - 0.8 * t * t)
		up.append(p + n * w)
		dn.append(p - n * w)
	dn.reverse()
	var body := [(spine[0] as Vector2) + Vector2(-W * 0.6, 0)] + up + [(spine[16] as Vector2) + Vector2(W * 0.4, 0)] + dn
	sil(ci, [pg(body, s, col, 0)], rim)
	var fin := []
	for k in range(3, 17):
		var p: Vector2 = up[k]
		var d: Vector2 = ((spine[mini(k + 1, 16)] as Vector2) - (spine[k - 1] as Vector2)).normalized()
		fin.append(p + d.orthogonal() * 1.5)
	pl(ci, fin, 1.4, Color(INK, 0.45), s)
	var belly := []
	for k in range(1, 12):
		belly.append((dn[16 - k] as Vector2).lerp(spine[k], 0.3))
	pl(ci, belly, 2.4, Color(BELLY, 0.55), s + 1)
	var hd: Vector2 = spine[1]
	ci.draw_circle(hd + Vector2(-W * 0.3, -W * 0.35), maxf(W * 0.22, 1.8), Color.WHITE)
	ci.draw_circle(hd + Vector2(-W * 0.35, -W * 0.35), maxf(W * 0.13, 1.1), INK)
	ci.draw_arc(hd + Vector2(W * 0.3, 0), W * 0.6, -1.0, 1.0, 6, Color(INK, 0.45), 1.3, true)

# ---------------------------------------------------------------- 各种贝、螺、虾

## 蛤蜊：圆三角的壳，顶上一个壳顶，一圈圈生长纹和几道褐色放射纹
static func _clam_shell(ci: CanvasItem, c: Vector2, r: float, s: int, rim: bool) -> void:
	var pts := []
	for k in 13:
		var an := PI * float(k) / 12.0
		pts.append(c + Vector2(cos(an) * r * 1.15, sin(an) * r * 0.8))
	pts.append(c + Vector2(-r * 0.95, -r * 0.35))
	pts.append(c + Vector2(-r * 0.1, -r * 0.95))
	pts.append(c + Vector2(r * 0.95, -r * 0.32))
	sil(ci, [pg(pts, s, Color("ead7ae"), 0)], rim)
	var um := c + Vector2(-r * 0.1, -r * 0.85)
	for k in 3:
		var a := PI * (0.25 + 0.25 * float(k))
		var tip := c + Vector2(cos(a) * r * 1.05, sin(a) * r * 0.72)
		ci.draw_colored_polygon(PackedVector2Array([um, tip + Vector2(-r * 0.12, 0), tip + Vector2(r * 0.12, 0)]), Color(Color("a8754a"), 0.45))
	for k in 3:
		var f := 0.45 + float(k) * 0.2
		pl(ci, arcp(c + Vector2(0, -r * 0.25 * (1.0 - f)), Vector2(r * 1.1 * f, r * 0.85 * f), 0.15, PI - 0.15, 10), 1.3, Color(INK, 0.3), s + k)

## 小龙虾：红色，身子朝左，两只大钳子往前伸，尾巴往下卷
static func _crayfish(ci: CanvasItem, c: Vector2, sz: float, s: int, rim: bool) -> void:
	var red := Color("d24a2a")
	var parts := []
	for side in [-1.0, 1.0]:
		var arm0 := c + Vector2(-sz * 0.55, side * sz * 0.12)
		var arm1 := c + Vector2(-sz * 0.95, side * sz * 0.4)
		parts.append(stk(arm0, arm1, maxf(sz * 0.08, 1.8), s + 1, red.darkened(0.08), 1))
		parts.append(ov(arm1 + Vector2(-sz * 0.3, side * sz * 0.08), sz * 0.34, sz * 0.16, s + 2, red, side * 0.25, 1))
	for k in 4:
		parts.append(stk(c + Vector2(-sz * 0.2 + float(k) * sz * 0.14, sz * 0.2), c + Vector2(-sz * 0.3 + float(k) * sz * 0.14, sz * 0.45), maxf(sz * 0.03, 1.2), s + 3 + k, red.darkened(0.15), 2))
	var tail := []
	for k in 4:
		var t := float(k) / 3.0
		tail.append(c + Vector2(sz * (0.35 + 0.28 * t), sz * (0.02 + 0.14 * t * t)))
	var tip: Vector2 = tail[3]
	parts.append(pg([tip + Vector2(0, -sz * 0.08), tip + Vector2(sz * 0.32, -sz * 0.05), tip + Vector2(sz * 0.36, sz * 0.12), tip + Vector2(sz * 0.2, sz * 0.25), tip + Vector2(0, sz * 0.12)], s + 8, red.darkened(0.05), 1))
	for k in range(3, -1, -1):
		var w := sz * (0.22 - 0.025 * float(k))
		parts.append(ov(tail[k], w, w * 0.85, s + 9 + k, red, 0.0, 1, 0.02))
	parts.append(ov(c + Vector2(-sz * 0.15, 0), sz * 0.5, sz * 0.28, s + 14, red, 0.0, 0))
	sil(ci, parts, rim)
	for side in [-1.0, 1.0]:
		var claw := c + Vector2(-sz * 1.25, side * sz * 0.48)
		ln(ci, claw + Vector2(-sz * 0.05, 0), claw + Vector2(sz * 0.22, -side * sz * 0.02), 1.6, INK, s)
		pl(ci, [c + Vector2(-sz * 0.6, side * sz * 0.05), c + Vector2(-sz * 1.0, side * sz * 0.1), c + Vector2(-sz * 1.4, side * sz * 0.02)], 1.2, Color(INK, 0.7), s + 2)
	ci.draw_circle(c + Vector2(-sz * 0.58, -sz * 0.12), maxf(sz * 0.05, 1.3), INK)
	ci.draw_arc(c + Vector2(-sz * 0.1, 0), sz * 0.3, -1.2, 1.2, 6, Color(INK, 0.3), 1.2, true)

## 扇贝：扇面朝上张开，一道道放射肋，底下两只小耳朵
static func _fan_shell(ci: CanvasItem, c: Vector2, r: float, s: int, rim: bool) -> void:
	var col := Color("ec9a6a")
	var hinge := c + Vector2(0, r * 0.6)
	var pts := [hinge]
	var ribs := 9
	for k in ribs * 2 + 1:
		var an := lerpf(-PI * 0.9, -PI * 0.1, float(k) / float(ribs * 2))
		var rr := r * (1.0 if k % 2 == 0 else 0.93)
		pts.append(hinge + Vector2(cos(an) * rr * 1.05, sin(an) * rr * 1.1))
	var ears := [pg([hinge + Vector2(-r * 0.45, -r * 0.15), hinge + Vector2(-r * 0.45, r * 0.12), hinge + Vector2(0, r * 0.08), hinge + Vector2(0, -r * 0.2)], s + 1, col.darkened(0.08), 1),
		pg([hinge + Vector2(r * 0.45, -r * 0.15), hinge + Vector2(r * 0.45, r * 0.12), hinge + Vector2(0, r * 0.08), hinge + Vector2(0, -r * 0.2)], s + 2, col.darkened(0.08), 1)]
	sil(ci, ears + [pg(pts, s, col, 0)], rim)
	for k in ribs:
		var an := lerpf(-PI * 0.9, -PI * 0.1, (float(k) * 2.0 + 1.0) / float(ribs * 2))
		ln(ci, hinge + Vector2(cos(an), sin(an)) * r * 0.15, hinge + Vector2(cos(an) * r * 0.95, sin(an) * r * 1.0), 1.3, Color(INK, 0.35), s + k)
	for k in 2:
		var f := 0.45 + float(k) * 0.28
		pl(ci, arcp(hinge, Vector2(r * 1.02 * f, r * 1.08 * f), -PI * 0.88, -PI * 0.12, 12), 2.0, Color(Color("f6d2b0"), 0.6), s + k)

## 海螺：尖顶一层层螺旋往上收，下面是胖胖的体螺层和一截水管，肩上一圈疙瘩，螺口外翻露出粉色
static func _conch(ci: CanvasItem, c: Vector2, r: float, s: int, rim: bool) -> void:
	var ang := 0.35
	var ws := [[Vector2(0, 0), r * 0.8, r * 0.72], [Vector2(0.05, -0.72), r * 0.55, r * 0.34], [Vector2(0.08, -1.08), r * 0.36, r * 0.24], [Vector2(0.1, -1.34), r * 0.2, r * 0.15]]
	var acc := PackedVector2Array()
	for i in ws.size():
		var q: Array = ws[i]
		var e := ell((q[0] as Vector2) * r, Vector2(q[1], q[2]), s + i, 0.02, 18)
		acc = e if i == 0 else _union(acc, e)
	acc = _union(acc, PackedVector2Array([Vector2(-0.35, 0.45) * r, Vector2(0.35, 0.45) * r, Vector2(0.12, 1.35) * r, Vector2(-0.02, 1.38) * r]))
	acc = _union(acc, PackedVector2Array([Vector2(-0.6, -0.4) * r, Vector2(-1.05, 0.05) * r, Vector2(-0.75, 0.6) * r, Vector2(-0.3, 0.5) * r]))
	sil(ci, [P(PackedVector2Array(rot_pts(Array(acc), ang, c)), Color("ecd2a6"), 0)], rim)
	for i in range(1, ws.size()):
		var q: Array = ws[i]
		pl(ci, rot_pts(arcp((q[0] as Vector2) * r + Vector2(0, q[2] * 0.4), Vector2(q[1] * 1.02, q[2] * 0.7), PI * 0.1, PI * 0.9, 8), ang, c), 1.5, Color(INK, 0.5), s + i)
	for k in 4:
		var p: Vector2 = rot_pts([Vector2(-0.42 + float(k) * 0.3, -0.52 - absf(float(k) - 1.5) * 0.04) * r], ang, c)[0]
		ci.draw_circle(p, r * 0.11, Color("f6e4c2"))
		ci.draw_arc(p, r * 0.11, 0, TAU, 8, Color(INK, 0.55), 1.2, true)
	for k in 3:
		pl(ci, rot_pts(arcp(Vector2(0, -0.1) * r, Vector2(r * 0.7, r * (0.3 + 0.15 * float(k))), PI * 0.05, PI * 0.45, 6), ang, c), 2.2, Color(Color("b07a4a"), 0.5), s + k)
	var lip := ell(c + Vector2(-0.5, 0.12).rotated(ang) * r, Vector2(r * 0.38, r * 0.5), s, 0.04, 16, ang)
	ci.draw_colored_polygon(lip, Color("f2a5a0"))
	outline(ci, lip, 1.6)
	ci.draw_colored_polygon(ell(c + Vector2(-0.44, 0.12).rotated(ang) * r, Vector2(r * 0.18, r * 0.32), s + 1, 0.04, 12, ang), Color("c96a6a"))

## 鲍鱼：耳朵形的扁壳，翻过来露出七彩的珍珠层，边上一排小孔
static func _abalone(ci: CanvasItem, c: Vector2, r: float, s: int, rim: bool) -> void:
	var outer := ell(c, Vector2(r * 1.15, r * 0.82), s, 0.04, 22, -0.15)
	sil(ci, [P(outer, Color("b09080"), 1)], rim)
	var inner := ell(c + Vector2(-r * 0.05, r * 0.05), Vector2(r * 0.95, r * 0.64), s + 1, 0.03, 20, -0.15)
	ci.draw_colored_polygon(inner, Color("cfe6e2"))
	var bands := [Color("9fd6cc"), Color("bba8dc"), Color("f0c6d6"), Color("a8d0ec")]
	for k in bands.size():
		var e := ell(c + Vector2(r * (0.35 - 0.2 * float(k)), r * (-0.1 + 0.08 * float(k))), Vector2(r * (0.55 - 0.08 * float(k)), r * 0.2), s + k, 0.1, 14, -0.4 + 0.25 * float(k))
		ci.draw_colored_polygon(e, Color(bands[k], 0.75))
	ci.draw_colored_polygon(ell(c + Vector2(-r * 0.1, r * 0.08), Vector2(r * 0.3, r * 0.22), s + 7, 0.05, 12), Color(1, 1, 1, 0.55))
	outline(ci, inner, 1.6)
	for k in 5:
		var an := -PI * 0.85 + float(k) * 0.3
		ci.draw_circle(c + Vector2(cos(an) * r * 1.03, sin(an) * r * 0.73), maxf(r * 0.07, 1.4), Color("3b2314"))
	ci.draw_arc(c + Vector2(r * 0.85, -r * 0.1), r * 0.18, 0, TAU * 0.8, 8, Color(INK, 0.5), 1.4, true)

## 鹦鹉螺：一圈卷起来的白壳，背上一道道褐色虎纹，螺口黑黑的
static func _nautilus(ci: CanvasItem, c: Vector2, r: float, s: int, rim: bool) -> void:
	var shell := _union(ell(c, Vector2(r, r * 0.94), s, 0.02, 24), ell(c + Vector2(-r * 0.5, r * 0.08), Vector2(r * 0.6, r * 0.8), s + 1, 0.02, 18))
	sil(ci, [P(shell, Color("f4ead6"), 0)], rim)
	var core := c + Vector2(r * 0.18, 0)
	var clip := ell(c + Vector2(r * 0.05, 0), Vector2(r * 0.9, r * 0.85), s + 2, 0.0, 22)
	for k in 7:
		var an := lerpf(-PI * 0.95, PI * 0.35, float(k) / 6.0)
		var d := Vector2(cos(an), sin(an))
		var line := PackedVector2Array([core + d * r * 0.3, core + d * r * 0.6 + d.orthogonal() * r * 0.12, core + d * r * 1.1 + d.orthogonal() * r * 0.05])
		for seg in Geometry2D.intersect_polyline_with_polygon(line, clip):
			ci.draw_polyline(seg, Color("b0602e"), maxf(r * 0.1, 2.0), true)
	var mouth := ell(c + Vector2(-r * 0.62, r * 0.1), Vector2(r * 0.26, r * 0.6), s + 3, 0.03, 14)
	ci.draw_colored_polygon(mouth, Color("3b2314"))
	pl(ci, arcp(c + Vector2(-r * 0.62, r * 0.1), Vector2(r * 0.3, r * 0.64), PI * 0.5, PI * 1.5, 10), 2.2, Color("f8f2ea"), s)
	ci.draw_arc(core, r * 0.16, 0, TAU * 0.85, 10, Color(INK, 0.5), 1.4, true)
	ci.draw_circle(core, r * 0.07, Color("8a5a34"))

# ---------------------------------------------------------------- 生产器：渔具

static func _gen_art_v2(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			## 削尖的木棍：一根树枝，一头用石片削尖了，地上落着几片木屑
			var a := Vector2(-30, 32)
			var b := Vector2(26, -20)
			var d := (b - a).normalized()
			var n := d.orthogonal()
			sil(ci, [stk(a, b - d * 12.0, 3.6, s, WOOD), pg([b, b - d * 14.0 + n * 3.6, b - d * 14.0 - n * 3.6], s + 1, FACE, 1)], rim)
			for k in 3:
				ln(ci, b - d * (4.0 + float(k) * 3.5) + n * 1.5, b - d * (8.0 + float(k) * 3.5) - n * 1.5, 1.1, Color(WOOD_D, 0.6), s + k)
			ci.draw_colored_polygon(ell(a, Vector2(3, 3), s, 0.0, 10), FACE)
			for p in [Vector2(14, 34), Vector2(24, 36), Vector2(30, 31)]:
				ci.draw_arc(p, 3.0, PI, TAU, 6, FACE, 2.4, true)
				ci.draw_arc(p, 3.0, PI, TAU, 6, Color(INK, 0.6), 1.0, true)
		2:
			## 骨鱼钩：一枚骨头磨的鱼钩，钩尖带倒刺，钩眼上拴着一段草绳
			var parts := [stk(Vector2(8, -22), Vector2(8, 14), 3.4, s, BONE_HOOK), band(Vector2(-4, 14), 12, 3.4, 0.0, PI, s + 1, BONE_HOOK),
				stk(Vector2(-16, 14), Vector2(-16, 0), 3.0, s + 2, BONE_HOOK), pg([Vector2(-16, -6), Vector2(-11, 4), Vector2(-17, 2)], s + 3, BONE_HOOK, 1),
				circ(Vector2(8, -26), 5.0, s + 4, BONE_HOOK, 1)]
			var cord := [Vector2(8, -26), Vector2(18, -30), Vector2(26, -22), Vector2(22, -12), Vector2(30, -4), Vector2(36, 6)]
			if rim:
				_f_rim(ci, parts)
				for k in cord.size() - 1:
					dilate(ci, PackedVector2Array([cord[k], cord[k + 1], (cord[k + 1] as Vector2) + Vector2(0.5, 0.5)]), 7.0, RIM_COL)
			sil(ci, parts, false)
			ci.draw_circle(Vector2(8, -26), 2.0, Color("3b2314"))
			pl(ci, cord, 4.0, INK, s)
			pl(ci, cord, 2.2, GRASS, s)
			hl(ci, Vector2(6, -6), 1.2, 8, 0.0, 0.6)
		3:
			## 没绑好的鱼叉：一根木杆，三根骨叉尖散在旁边，草绳才绕了一半
			var parts := [stk(Vector2(-36, 24), Vector2(28, -12), 3.2, s, WOOD)]
			for k in 3:
				var p := Vector2(4.0 + float(k) * 9.0, 30.0 + float(k % 2) * 3.0)
				parts.append(stk(p, p + Vector2(14, -4), 2.2, s + 1 + k, BONE_HOOK, 2))
				parts.append(pg([p + Vector2(14, -6), p + Vector2(20, -5), p + Vector2(14, -2)], s + 5 + k, BONE_HOOK, 1))
			parts.append(ov(Vector2(-22, 34), 10, 4.5, s + 9, GRASS, 0.0, 1))
			sil(ci, parts, rim)
			ci.draw_colored_polygon(ell(Vector2(-22, 33.5), Vector2(5, 2), s, 0.0, 10), Color(GRASS_D, 0.9))
			pl(ci, [Vector2(-14, 32), Vector2(-4, 20), Vector2(14, 0)], 2.0, GRASS, s)
			for k in 3:
				var p := Vector2(22, -9) + Vector2(-4, 2.2) * float(k)
				ln(ci, p + Vector2(-1.5, -3), p + Vector2(1.5, 3), 1.8, GRASS_D, s + k)
		4:
			## 鱼叉：木杆头上绑着三根骨尖，用草绳缠得紧紧的
			var a := Vector2(-30, 36)
			var b := Vector2(14, -14)
			var d := (b - a).normalized()
			var n := d.orthogonal()
			var parts := [stk(a, b + d * 4.0, 3.4, s, WOOD)]
			for k in 3:
				var o := (float(k) - 1.0) * 9.0
				var root := b + n * o * 0.3
				var tip := b + d * 30.0 + n * o
				parts.append(stk(root, tip, 2.2, s + 1 + k, BONE_HOOK, 2))
				parts.append(pg([tip + d * 5.0, tip - d * 2.0 + n * 3.0, tip - d * 1.0 - n * 0.5], s + 4 + k, BONE_HOOK, 1))
			sil(ci, parts, rim)
			for k in 3:
				var p := b - d * (2.0 + float(k) * 3.4)
				ln(ci, p + n * 5.0, p - n * 5.0 + d * 1.5, 2.6, GRASS_D, s + k)
				ln(ci, p + n * 4.0, p - n * 4.0 + d * 1.5, 1.4, GRASS, s + k)
			ci.draw_colored_polygon(ell(a, Vector2(3.2, 3.2), s, 0.0, 10), FACE)
		5:
			## 钓竿：一根细竹竿，竿梢垂下草绳线，线上一个浮子，底下吊着骨鱼钩
			var a := Vector2(-28, 34)
			var b := Vector2(16, -30)
			var d := (b - a).normalized()
			var n := d.orthogonal()
			var line := [b, b + Vector2(6, 10), Vector2(26, -4), Vector2(26, 14)]
			var parts := [stk(a, b, 3.0, s, BAMBOO), ov(Vector2(26, -4), 3.2, 4.4, s + 1, Color("e04a3a"), 0.0, 1)]
			var hook := [band(Vector2(23, 20), 3.6, 1.4, 0.0, PI * 1.05, s + 2, BONE_HOOK), stk(Vector2(26, 14), Vector2(26, 20), 1.4, s + 3, BONE_HOOK, 2)]
			if rim:
				_f_rim(ci, parts + hook)
				dilate(ci, PackedVector2Array(line + [Vector2(25, 14), Vector2(25, -4), b + Vector2(5, 10)]), 4.0, RIM_COL)
			sil(ci, [parts[0]], false)
			for k in 4:
				var p := a.lerp(b, 0.18 + float(k) * 0.2)
				ln(ci, p + n * 3.4, p - n * 3.4, 2.0, Color(GRASS_D, 0.9), s + k)
			pl(ci, line, 1.4, INK, s)
			sil(ci, [parts[1]] + hook, false, 2.0)
			ci.draw_colored_polygon(ell(Vector2(26, -6), Vector2(3.0, 1.8), s, 0.0, 10), Color.WHITE)
		6:
			## 鱼笼：一只藤条编的鱼笼，口大肚小，口里有一圈往里收的倒须，鱼进得去出不来
			var mouth := Vector2(-22, 14)
			var tip := Vector2(34, 22)
			var cone := [mouth + Vector2(0, -20), tip + Vector2(0, -5), tip + Vector2(5, 0), tip + Vector2(0, 5), mouth + Vector2(0, 20)]
			sil(ci, [pg(cone, s, TRAP, 1), ov(mouth, 10, 20, s + 1, TRAP.lightened(0.08), 0.0, 1)], rim)
			for k in 5:
				var t := (float(k) + 1.0) / 6.0
				ci.draw_arc(mouth.lerp(tip, t), lerpf(20.0, 5.0, t), -PI * 0.5, PI * 0.5, 10, Color(WOOD_D, 0.75), 1.6, true)
			for k in 5:
				var y := -14.0 + float(k) * 7.0
				ln(ci, mouth + Vector2(6, y), tip + Vector2(-3, y * 0.2), 1.2, Color(WOOD_D, 0.55), s + k)
			ci.draw_colored_polygon(ell(mouth, Vector2(6.5, 15), s, 0.0, 16), Color("3b2314"))
			for k in 6:
				var an := TAU * float(k) / 6.0
				ln(ci, mouth + Vector2(cos(an) * 6.0, sin(an) * 14.0), mouth + Vector2(cos(an) * 2.0 + 3.0, sin(an) * 4.0), 1.4, Color(TRAP, 0.9), s + k)
			ci.draw_arc(mouth, 10.0, -PI * 0.5, PI * 0.5, 12, Color(1, 1, 1, 0.3), 2.0, true)
			pl(ci, [tip + Vector2(2, -4), tip + Vector2(8, -8), tip + Vector2(10, -2)], 1.8, GRASS_D, s)
		7:
			## 渔网：两根木桩搭一根横杆，上面晾着一张渔网，网下沿坠着小石头，网里还挂着一条小鱼
			var net := [Vector2(-28, -13), Vector2(28, -15), Vector2(24, 10), Vector2(16, 24), Vector2(6, 19), Vector2(-4, 26), Vector2(-14, 19), Vector2(-24, 24)]
			sil(ci, [stk(Vector2(-30, 38), Vector2(-28, -18), 3.2, s + 2, WOOD), stk(Vector2(30, 38), Vector2(28, -18), 3.2, s + 3, WOOD),
				stk(Vector2(-36, -14), Vector2(36, -16), 3.0, s + 4, WOOD_D), pg(net, s + 5, ROPE.lightened(0.15), 2)], rim)
			_fish(ci, Vector2(-4, 6), 18, 4.5, 0.3, s + 20, SILVER, false, false)
			var np := PackedVector2Array(net)
			for k in 9:
				var x := -36.0 + float(k) * 8.0
				for seg in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([Vector2(x, -16), Vector2(x + 26, 28)]), np):
					ci.draw_polyline(seg, Color(WOOD_D, 0.7), 1.2, true)
				for seg in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([Vector2(x + 26, -16), Vector2(x, 28)]), np):
					ci.draw_polyline(seg, Color(WOOD_D, 0.7), 1.2, true)
			sil(ci, [_stone(Vector2(-24, 26), 3.5, 3, s + 10), _stone(Vector2(-4, 28), 3.5, 3, s + 11), _stone(Vector2(16, 26), 3.5, 3, s + 12)], false, 2.0)
		_:
			## 独木舟：一整根大树掏空的独木舟，舱里横着一支桨，船头堆着一卷渔网
			var hull := []
			for k in 15:
				var t := float(k) / 14.0
				hull.append(Vector2(lerpf(-42.0, 42.0, t), lerpf(14.0, 8.0, t) - 8.0 * pow(absf(t - 0.5) * 2.0, 3.0)))
			for k in 15:
				var t := 1.0 - float(k) / 14.0
				hull.append(Vector2(lerpf(-42.0, 42.0, t) * 0.96, lerpf(14.0, 8.0, t) + 22.0 * sin(PI * t) - 2.0))
			sil(ci, [pg(hull, s, Color("8a5a34"), 1)], rim)
			var inner := ell(Vector2(0, 12), Vector2(35, 5.5), s, 0.02, 22, -0.06)
			ci.draw_colored_polygon(inner, Color("4a2c14"))
			outline(ci, inner, 1.6)
			for k in 3:
				var x := -30.0 + float(k) * 26.0
				pl(ci, [Vector2(x, 20), Vector2(x + 10, 22), Vector2(x + 22, 21)], 1.3, Color(WOOD_D.darkened(0.2), 0.6), s + k)
			sil(ci, [ov(Vector2(-22, 8), 12, 6, s + 5, ROPE.lightened(0.1), 0.0, 1), stk(Vector2(-6, 14), Vector2(30, 0), 2.0, s + 6, WOOD, 2), ov(Vector2(34, -2), 6, 3, s + 7, WOOD, -0.4, 1)], false, 2.2)
			for k in 4:
				var x := -30.0 + float(k) * 5.0
				ln(ci, Vector2(x, 3), Vector2(x + 4, 13), 1.0, Color(WOOD_D, 0.6), s + k)
			ln(ci, Vector2(-44, 9), Vector2(44, 4), 2.0, Color(1, 1, 1, 0.25), s)

# ---------------------------------------------------------------- 主产物：鱼（每级一种）

static func _main_art_v2(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			## 麦穗鱼：一指长的小杂鱼，身上一道黑纵纹
			_sp(ci, Vector2(0, 26), 30, 6, -0.1, s, Color("b7a684"), rim, {"stripe": Color(INK, 0.45), "scales": false})
		2:
			## 鳑鲏：小小的、身子扁高，肩上一块蓝绿斑，鳍边发红
			_sp(ci, Vector2(0, 24), 30, 11, -0.1, s, Color("cfb4d0"), rim, {"patch": Color("4fb0b0"), "fin": Color("e07a5a")})
		3:
			## 白条鱼：细长银白的小鱼
			_sp(ci, Vector2(0, 26), 42, 7, -0.08, s, Color("cfdde4"), rim)
		4:
			## 鲫鱼：身子短而厚，背上青黄发亮
			_sp(ci, Vector2(0, 22), 44, 15, -0.1, s, CRUCIAN, rim)
		5:
			## 黄颡鱼：黄澄澄的，身上几块黑斑，没有鳞，嘴边四根须，背鳍一根硬刺
			_sp(ci, Vector2(0, 24), 50, 11, -0.08, s, Color("dcb443"), rim, {"scales": false, "whisk": true, "bars": Color(INK, 0.3), "fin": Color("b88a2a")})
		6:
			## 鲈鱼：青灰带银，身上几道暗横斑，背鳍一排硬刺
			_sp(ci, Vector2(0, 22), 54, 14, -0.1, s, Color("9fb08a"), rim, {"spiny": true, "bars": Color(INK, 0.18)})
		7:
			## 鲤鱼：金黄的鲤鱼，大鳞片，嘴边两根短须
			_sp(ci, Vector2(0, 20), 58, 16, -0.12, s, CARP, rim, {"whisk": true})
		8:
			## 鳜鱼：黄褐色，满身黑褐色的花斑，大嘴，背上一排硬刺
			_sp(ci, Vector2(0, 20), 60, 17, -0.1, s, Color("c9a862"), rim, {"spiny": true, "spots": Color("5a3a1e", 0.6), "scales": false})
		9:
			## 鲶鱼：灰褐色的鲶鱼，扁脑袋，没有鳞，两条长胡子
			_sp(ci, Vector2(0, 24), 66, 13, -0.08, s, CATFISH, rim, {"scales": false, "whisk": true, "back_dorsal": true})
		10:
			## 草鱼：又长又圆的草鱼，背上青褐，肚子发黄
			_sp(ci, Vector2(0, 22), 70, 15, -0.1, s, Color("a8a060"), rim)
		11:
			## 鳗鱼：一条蛇一样弯来弯去的黑绿色鳗鱼
			_eel(ci, Vector2(0, 22), 82, 7.5, s, Color("4f5e3e"), rim)
		12:
			## 狗鱼：长长的，尖尖的鸭嘴，绿底上一身浅色斑点，背鳍长在后头
			_sp(ci, Vector2(6, 22), 72, 12, -0.08, s, Color("6f8f4a"), rim, {"snout": true, "back_dorsal": true, "spots": Color("e6e0a0", 0.85), "scales": false})
		13:
			## 鲑鱼：粉红肉色的鲑鱼，背上一点点黑斑
			_sp(ci, Vector2(0, 22), 70, 16, -0.12, s, SALMON, rim, {"spots": Color(INK, 0.55)})
		14:
			## 青鱼：又粗又长、乌青发亮的大青鱼
			_sp(ci, Vector2(0, 20), 78, 18, -0.1, s, Color("4a5868"), rim)
		15:
			## 鲟鱼：尖嘴、背上一排白骨板的鲟鱼
			_sturgeon(ci, Vector2(2, 18), 70, 17, s, STURGEON, rim)
		_:
			## 鳇鱼王：河里最大的鳇鱼，金褐色，浑身发亮，是渔获里最珍贵的
			glow(ci, Vector2(0, 14), 58, GOLD)
			_sturgeon(ci, Vector2(2, 16), 70, 20, s, KALUGA, rim)
			sparks(ci, [Vector2(-40, -10), Vector2(34, -20), Vector2(44, 30)])

# ---------------------------------------------------------------- 副产物：水边收获（每级一种）

static func _sub_art_v2(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			## 田螺：一只青褐色的田螺，螺口盖着小盖子
			_snail(ci, Vector2(0, 24), 14, -0.3, s, rim)
		2:
			## 蛤蜊：圆三角的蛤蜊，奶黄底上几道褐色花纹
			_clam_shell(ci, Vector2(0, 24), 18, s, rim)
		3:
			## 河虾：一只弓着背的河虾，长须
			_shrimp(ci, Vector2(6, 22), 22, s, rim)
		4:
			## 河蚌：一只合着的河蚌，黑绿的壳上一圈圈生长纹
			_mussel(ci, Vector2(0, 24), 52, 16, -0.15, s, rim)
		5:
			## 小龙虾：一只通红的小龙虾，举着两只大钳子
			_crayfish(ci, Vector2(8, 22), 30, s, rim)
		6:
			## 河蟹：一只青褐色的河蟹，举着两只钳子
			_crab(ci, Vector2(0, 24), 18, s, CRAB, rim)
		7:
			## 扇贝：一扇橙红的扇贝，一道道放射肋
			_fan_shell(ci, Vector2(0, 18), 26, s, rim)
		8:
			## 海螺：纺锤形的大海螺，肩上一圈疙瘩，螺口粉红
			_conch(ci, Vector2(0, 14), 24, s, rim)
		9:
			## 大青蟹：一只青蓝色的大螃蟹，钳子又大又壮
			_crab(ci, Vector2(0, 22), 24, s, BLUECRAB, rim)
		10:
			## 鲍鱼：翻过来的鲍鱼壳，里面一层七彩的珍珠光，边上一排小孔
			_abalone(ci, Vector2(0, 22), 28, s, rim)
		11:
			## 鹦鹉螺：一圈卷起来的白壳，背上一道道褐色虎纹
			_nautilus(ci, Vector2(0, 16), 28, s, rim)
		_:
			## 珍珠贝：张开的大贝壳里躺着一颗又圆又亮的大珍珠，是水边最珍贵的东西
			glow(ci, Vector2(0, 16), 58, GOLD)
			_open_mussel(ci, Vector2(0, 24), 66, 16, s, rim, 10.0)
			sparks(ci, [Vector2(-34, -16), Vector2(30, -22), Vector2(40, 18)])

# ================================================================ 第三稿：渔具一级级长大 / 各种水产 / 加了远古贝类

const FROG := Color("86b04a")
const TADPOLE := Color("4e4a3a")
const LOACH := Color("a08a5a")
const PUFFER := Color("d8bf6c")
const CUTTLE := Color("d9a088")
const FLOUNDER := Color("b89a6a")
const SOFTSHELL := Color("7a8a4a")
const OCTO := Color("d8664a")
const RAY := Color("9a8a72")
const KOI_W := Color("f6f0e4")
const KOI_R := Color("e0462a")
const COELA := Color("41608e")
const LIMULUS := Color("9a8250")
const TRILO := Color("b89a6a")
const AMMO := Color("e0ad45")

## 沿一条中线铺出带宽度的长条（ws 是每个点的半宽），首尾各加一个圆头点
static func _tube(sp: Array, ws: Array) -> Array:
	var n := sp.size()
	var up := []
	var dn := []
	for k in n:
		var a: Vector2 = sp[maxi(k - 1, 0)]
		var b: Vector2 = sp[mini(k + 1, n - 1)]
		var nn := (b - a).normalized().orthogonal()
		var p: Vector2 = sp[k]
		var w: float = ws[k]
		up.append(p + nn * w)
		dn.append(p - nn * w)
	dn.reverse()
	var p0: Vector2 = sp[0]
	var p1: Vector2 = sp[n - 1]
	var d0 := (p0 - (sp[1] as Vector2)).normalized()
	var d1 := (p1 - (sp[n - 2] as Vector2)).normalized()
	return up + [p1 + d1 * float(ws[n - 1]) * 0.8] + dn + [p0 + d0 * float(ws[0]) * 0.8]

## 二次贝塞尔曲线上取 n+1 个点
static func _bez(a: Vector2, m: Vector2, b: Vector2, n: int) -> Array:
	var out := []
	for k in n + 1:
		var t := float(k) / float(n)
		out.append(a.lerp(m, t).lerp(m.lerp(b, t), t))
	return out

## 细线（鱼线、绳子）的白边
static func _line_rim(ci: CanvasItem, pts: Array) -> void:
	for k in pts.size() - 1:
		var a: Vector2 = pts[k]
		var b: Vector2 = pts[k + 1]
		var n := (b - a).normalized().orthogonal() * 0.6
		dilate(ci, PackedVector2Array([a + n, b + n, b - n, a - n]), 5.0, RIM_COL)

## 杆子上一圈圈缠着的草绳
static func _lash(ci: CanvasItem, p: Vector2, d: Vector2, w: float, n: int, s: int) -> void:
	var o := d.orthogonal()
	for k in n:
		var q := p - d * (float(k) * 3.0)
		ln(ci, q + o * w, q - o * w + d * 1.5, 2.8, GRASS_D, s + k)
		ln(ci, q + o * (w - 0.8), q - o * (w - 0.8) + d * 1.5, 1.4, GRASS, s + k)

# ---------------------------------------------------------------- 生产器：渔具

static func _gen_art(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			## 削尖的短木棍：一截短树枝，一头用石片削出白生生的尖，地上落着两片木屑
			var a := Vector2(-16, 30)
			var b := Vector2(14, 4)
			var d := (b - a).normalized()
			var n := d.orthogonal()
			var stub := a.lerp(b, 0.45)
			sil(ci, [stk(stub, stub + Vector2(-2, -8), 1.6, s + 2, WOOD_D, 1), stk(a, b - d * 9.0, 3.4, s, WOOD), pg([b, b - d * 11.0 + n * 3.4, b - d * 11.0 - n * 3.4], s + 1, FACE, 1)], rim)
			for k in 2:
				ln(ci, b - d * (4.0 + float(k) * 3.5) + n * 1.5, b - d * (7.0 + float(k) * 3.5) - n * 1.5, 1.1, Color(WOOD_D, 0.6), s + k)
			ci.draw_colored_polygon(ell(a, Vector2(2.6, 2.6), s, 0.0, 10), FACE)
			for p in [Vector2(20, 33), Vector2(28, 31)]:
				ci.draw_arc(p, 2.6, PI, TAU, 6, FACE, 2.2, true)
				ci.draw_arc(p, 2.6, PI, TAU, 6, Color(INK, 0.6), 1.0, true)
		2:
			## 骨尖矛：棍子长长了，头上用草绳绑着一枚带倒刺的骨尖
			var a := Vector2(-26, 34)
			var b := Vector2(10, -2)
			var d := (b - a).normalized()
			var n := d.orthogonal()
			var tip := [b - d * 3.0 + n * 2.8, b + d * 8.0 + n * 3.4, b + d * 5.0 + n * 6.5, b + d * 12.0 + n * 2.6, b + d * 20.0, b + d * 10.0 - n * 3.4, b - d * 3.0 - n * 2.8]
			sil(ci, [stk(a, b, 3.0, s, WOOD), pg(tip, s + 1, BONE_HOOK, 1)], rim)
			_lash(ci, b - d * 1.0, d, 4.2, 3, s)
			ln(ci, b + d * 3.0, b + d * 16.0, 1.1, Color(INK, 0.3), s)
			ci.draw_colored_polygon(ell(a, Vector2(2.4, 2.4), s, 0.0, 10), FACE)
		3:
			## 双齿木叉：找了根分叉的树枝，两个叉都削尖了，叉口用草绳勒紧
			var a := Vector2(-28, 36)
			var f := Vector2(2, 6)
			var d := (f - a).normalized()
			var parts := [stk(a, f, 3.2, s, WOOD)]
			var tips := []
			for side in [-1.0, 1.0]:
				var td := d.rotated(side * 0.3)
				var t0 := f - d * 2.0
				var t1 := f + td * 22.0
				var tn := td.orthogonal()
				parts.append(stk(t0, t1, 2.6, s + int(side + 2.0), WOOD))
				tips.append(pg([t1 + td * 9.0, t1 - td * 1.0 + tn * 2.6, t1 - td * 1.0 - tn * 2.6], s + int(side + 5.0), FACE, 1))
			sil(ci, parts + tips, rim)
			_lash(ci, f - d * 1.0, d, 4.8, 3, s)
			ci.draw_colored_polygon(ell(a, Vector2(2.6, 2.6), s, 0.0, 10), FACE)
		4:
			## 鱼叉：直直的木杆，头上绑一枚磨亮的骨叉头，两边各一个倒钩，叉尾垂着一截绳头
			var a := Vector2(-28, 34)
			var b := Vector2(8, 0)
			var d := (b - a).normalized()
			var n := d.orthogonal()
			var hp := [Vector2(-4, 2.6), Vector2(7, 3.0), Vector2(3, 8.0), Vector2(13, 3.4), Vector2(22, 0), Vector2(13, -3.4), Vector2(3, -8.0), Vector2(7, -3.0), Vector2(-4, -2.6)]
			var head := []
			for q in hp:
				var v: Vector2 = q
				head.append(b + d * v.x + n * v.y)
			sil(ci, [stk(a, b + d * 2.0, 3.0, s, WOOD), pg(head, s + 1, BONE_HOOK, 1)], rim)
			_lash(ci, b + d * 1.0, d, 4.0, 2, s)
			ln(ci, b + d * 4.0, b + d * 19.0, 1.2, Color(INK, 0.3), s)
			hl(ci, b + d * 10.0 + n * 1.2, 4.0, 1.0, d.angle(), 0.55)
			_lash(ci, a.lerp(b, 0.2), d, 4.0, 2, s + 7)
			ci.draw_colored_polygon(ell(a, Vector2(2.4, 2.4), s, 0.0, 10), FACE)
		5:
			## 钓竿：一根压弯了的竹竿，竿梢的线上挂着红白浮子，钩上咬着一条小鱼
			var rod := _bez(Vector2(-30, 34), Vector2(-14, -22), Vector2(16, -24), 14)
			var ws := []
			for k in 15:
				ws.append(lerpf(3.4, 1.8, float(k) / 14.0))
			var tip: Vector2 = rod[14]
			var flo := Vector2(24, -2)
			var mouth := Vector2(24, 12)
			var fc := Vector2(24, 23)
			var rodp := [pg(_tube(rod, ws), s, BAMBOO.lightened(0.1), 2)]
			var fl := [ov(flo, 4.0, 6.0, s + 1, Color.WHITE, 0.0, 1)]
			var fish := _fish_parts(fc, 21, 6.5, PI * 0.5, s + 20, SILVER)
			if rim:
				_f_rim(ci, rodp + fl + fish)
				_line_rim(ci, [tip, flo, mouth])
			sil(ci, rodp, false)
			for k in 3:
				var i := 3 + k * 3
				var p: Vector2 = rod[i]
				var o := ((rod[i + 1] as Vector2) - (rod[i - 1] as Vector2)).normalized().orthogonal()
				ln(ci, p + o * float(ws[i]), p - o * float(ws[i]), 1.4, Color(GRASS_D.darkened(0.2), 0.9), s + k)
			for k in 3:
				var p: Vector2 = rod[1 + k]
				var o := ((rod[2 + k] as Vector2) - (rod[k] as Vector2)).normalized().orthogonal()
				ln(ci, p + o * 3.6, p - o * 3.6, 2.4, ROPE.darkened(0.25), s + k)
			ln(ci, tip, flo + Vector2(0, -6), 1.3, INK, s)
			ln(ci, flo + Vector2(0, 6), mouth, 1.3, INK, s)
			sil(ci, fl, false, 2.0)
			var cap := PackedVector2Array(arcp(flo, Vector2(4.0, 6.0), PI, TAU, 10))
			ci.draw_colored_polygon(cap, Color("e04a3a"))
			ln(ci, flo + Vector2(-4, 0), flo + Vector2(4, 0), 1.4, INK, s)
			hl(ci, flo + Vector2(-1.5, -3), 1.2, 2.0, 0.0, 0.7)
			_fish(ci, fc, 21, 6.5, PI * 0.5, s + 20, SILVER, false, false)
		_:
			## 鱼笼、渔网、独木舟沿用第二稿
			_gen_art_v2(ci, lv, s, rim)

# ---------------------------------------------------------------- 各种水产

## 蝌蚪：圆滚滚的黑脑袋，后面一条摆来摆去的扁尾巴
static func _tadpole(ci: CanvasItem, c: Vector2, sz: float, s: int, rim: bool) -> void:
	var sp := []
	var ws := []
	for k in 11:
		var t := float(k) / 10.0
		sp.append(c + Vector2(sz * (0.2 + 1.6 * t), sin(t * PI * 1.6) * sz * 0.22 * t))
		ws.append(lerpf(sz * 0.5, sz * 0.06, pow(t, 0.8)))
	sil(ci, [pg(_tube(sp, ws), s, TADPOLE.lightened(0.3), 2), ov(c, sz * 0.62, sz * 0.52, s + 1, TADPOLE.lightened(0.12), 0.0, 0)], rim, 1.4)
	pl(ci, sp.slice(1, 9), 1.0, Color(INK, 0.2), s)
	ci.draw_colored_polygon(ell(c + Vector2(sz * 0.05, sz * 0.25), Vector2(sz * 0.35, sz * 0.18), s, 0.0, 12), Color(Color("a8a088"), 0.6))
	for k in 2:
		var e := c + Vector2(-sz * (0.28 - 0.3 * float(k)), -sz * 0.18)
		ci.draw_circle(e, maxf(sz * 0.12, 1.6), Color.WHITE)
		ci.draw_circle(e + Vector2(-0.4, 0), maxf(sz * 0.07, 1.0), INK)

## 青蛙：蹲着、头朝左，大眼睛鼓在头顶，后腿折起来
static func _frog(ci: CanvasItem, c: Vector2, sz: float, s: int, rim: bool) -> void:
	var k := sz / 16.0
	var foot := pg([c + Vector2(-2, 14) * k, c + Vector2(22, 12) * k, c + Vector2(24, 16) * k, c + Vector2(-4, 17) * k], s + 1, FROG.darkened(0.12), 1)
	var thigh := ov(c + Vector2(12, 6) * k, 10 * k, 7.5 * k, s + 2, FROG.darkened(0.04), -0.4, 1)
	var body := ov(c + Vector2(3, 2) * k, 15 * k, 10.5 * k, s + 3, FROG, -0.35, 0)
	var head := ov(c + Vector2(-11, -4) * k, 10 * k, 7.5 * k, s + 4, FROG, -0.1, 0)
	var eyeb := circ(c + Vector2(-9, -11) * k, 4.6 * k, s + 5, FROG.lightened(0.06), 1)
	var arm := stk(c + Vector2(-6, 4) * k, c + Vector2(-10, 15) * k, 2.4 * k, s + 6, FROG.darkened(0.06), 1)
	var hand := ov(c + Vector2(-12, 16) * k, 4 * k, 1.8 * k, s + 7, FROG.darkened(0.06), 0.0, 1)
	sil(ci, [foot, thigh, body, head, eyeb, arm, hand], rim)
	ci.draw_colored_polygon(ell(c + Vector2(-4, 6) * k, Vector2(10, 4.5) * k, s, 0.02, 14, -0.3), Color(Color("e8e4b0"), 0.75))
	for q in [Vector2(6, -4), Vector2(12, 0), Vector2(2, -1), Vector2(14, 7)]:
		ci.draw_colored_polygon(ell(c + (q as Vector2) * k, Vector2(2.2, 1.6) * k, s, 0.1, 8), Color(FROG.darkened(0.4), 0.6))
	pl(ci, [c + Vector2(-20, -2) * k, c + Vector2(-13, 1) * k, c + Vector2(-5, -1) * k], 1.4, Color(INK, 0.6), s)
	var e := c + Vector2(-9.5, -11.5) * k
	ci.draw_circle(e, 3.2 * k, Color("f2d24a"))
	ci.draw_colored_polygon(ell(e, Vector2(2.4, 1.2) * k, s, 0.0, 10), INK)
	ci.draw_circle(e + Vector2(-1, -1.2) * k, 0.9 * k, Color.WHITE)
	ci.draw_circle(c + Vector2(-19, -6) * k, 0.9 * k, Color(INK, 0.7))

## 泥鳅：细细长长、褐黄色，满身小黑点，嘴边一圈小胡子
static func _loach(ci: CanvasItem, c: Vector2, L: float, W: float, s: int, rim: bool) -> void:
	var sp := []
	var ws := []
	for k in 15:
		var t := float(k) / 14.0
		sp.append(c + Vector2(lerpf(-L * 0.5, L * 0.5, t), sin(t * TAU * 0.75 + 0.3) * W * 0.9))
		ws.append(W * (0.75 + 0.25 * sin(PI * minf(t * 2.5, 1.0))) * (1.0 - 0.55 * t))
	var end: Vector2 = sp[14]
	var tail := ov(end + Vector2(W * 0.9, 0), W * 1.1, W * 0.9, s + 1, LOACH.darkened(0.12), 0.0, 1)
	var dorsal := ov((sp[7] as Vector2) + Vector2(0, -W * 0.9), W * 0.9, W * 0.5, s + 2, LOACH.darkened(0.12), 0.0, 1)
	sil(ci, [tail, dorsal, pg(_tube(sp, ws), s, LOACH, 0)], rim)
	var belly := []
	for k in range(1, 12):
		belly.append((sp[k] as Vector2) + Vector2(0, float(ws[k]) * 0.5))
	pl(ci, belly, maxf(W * 0.5, 1.6), Color(BELLY, 0.5), s)
	for k in 12:
		var i := 2 + (k % 11)
		var p: Vector2 = sp[i]
		ci.draw_circle(p + Vector2(srnd(s + k) * 4.0 - 2.0, -float(ws[i]) * (0.15 + 0.45 * srnd(s + k * 5))), maxf(W * 0.14, 0.9), Color(INK, 0.45))
	var hd: Vector2 = sp[0]
	ci.draw_circle(hd + Vector2(W * 0.2, -W * 0.3), maxf(W * 0.2, 1.4), Color.WHITE)
	ci.draw_circle(hd + Vector2(W * 0.1, -W * 0.3), maxf(W * 0.12, 0.9), INK)
	for k in 3:
		var m := hd + Vector2(-W * 0.6, W * 0.25)
		pl(ci, [m, m + Vector2(-W * 0.5, W * (0.2 + 0.3 * float(k))), m + Vector2(-W * 0.9, W * (0.5 + 0.4 * float(k)))], 1.1, Color(INK, 0.7), s + k)

## 河豚：气鼓鼓的一个刺球，大眼睛、小嘴，背上几块褐斑
static func _puffer(ci: CanvasItem, c: Vector2, r: float, s: int, rim: bool) -> void:
	var parts := []
	parts.append(pg([c + Vector2(r * 0.85, -r * 0.2), c + Vector2(r * 1.45, -r * 0.6), c + Vector2(r * 1.3, 0), c + Vector2(r * 1.45, r * 0.6), c + Vector2(r * 0.85, r * 0.2)], s, PUFFER.darkened(0.12), 1))
	parts.append(pg([c + Vector2(-r * 0.1, -r * 0.92), c + Vector2(r * 0.25, -r * 1.25), c + Vector2(r * 0.42, -r * 0.8)], s + 1, PUFFER.darkened(0.12), 1))
	for k in 16:
		var an := TAU * float(k) / 16.0 + 0.2
		var d := Vector2(cos(an), sin(an))
		parts.append(pg([c + d * r * 0.88 + d.orthogonal() * r * 0.09, c + d * r * 1.2, c + d * r * 0.88 - d.orthogonal() * r * 0.09], s + 2 + k, PUFFER.lightened(0.15), 1))
	parts.append(pg([c + Vector2(-r * 1.0, -r * 0.08), c + Vector2(-r * 1.18, -r * 0.02), c + Vector2(-r * 1.18, r * 0.16), c + Vector2(-r * 0.98, r * 0.2)], s + 20, PUFFER.darkened(0.05), 1))
	parts.append(circ(c, r, s + 21, PUFFER, 0, 0.02))
	sil(ci, parts, rim)
	ci.draw_colored_polygon(ell(c + Vector2(0, r * 0.45), Vector2(r * 0.82, r * 0.45), s, 0.0, 18), Color(Color("f6f0dc"), 0.9))
	for q in [Vector2(-0.1, -0.55), Vector2(0.35, -0.4), Vector2(0.15, -0.1), Vector2(0.55, 0.05)]:
		ci.draw_colored_polygon(ell(c + (q as Vector2) * r, Vector2(r * 0.14, r * 0.11), s, 0.15, 10), Color(Color("7a5a2a"), 0.55))
	var fin := ell(c + Vector2(r * 0.1, r * 0.12), Vector2(r * 0.22, r * 0.14), s, 0.03, 10, 0.4)
	ci.draw_colored_polygon(fin, PUFFER.darkened(0.15))
	outline(ci, fin, 1.3)
	var e := c + Vector2(-r * 0.5, -r * 0.3)
	ci.draw_circle(e, r * 0.24, Color.WHITE)
	ci.draw_circle(e + Vector2(-r * 0.05, 0), r * 0.14, INK)
	ci.draw_circle(e + Vector2(-r * 0.1, -r * 0.06), r * 0.05, Color.WHITE)
	ci.draw_arc(e, r * 0.24, 0, TAU, 12, Color(INK, 0.7), 1.3, true)

## 乌贼：椭圆的身子一圈裙边鳍，头朝左，八只短腕加两条带吸盘头的长触手
static func _cuttle(ci: CanvasItem, c: Vector2, sz: float, s: int, rim: bool) -> void:
	var k := sz / 22.0
	var parts := []
	var root := c + Vector2(-24, 0) * k
	for i in 6:
		var a := PI + lerpf(-0.75, 0.75, float(i) / 5.0)
		var d := Vector2(cos(a), sin(a))
		var len := (17.0 - absf(float(i) - 2.5) * 1.2) * k
		var sp := _bez(root, root + d * len * 0.6, root + d * len + d.orthogonal() * (4.0 * k if i < 3 else -4.0 * k), 6)
		var ws := []
		for j in 7:
			ws.append(lerpf(3.2, 1.4, float(j) / 6.0) * k)
		parts.append(pg(_tube(sp, ws), s + i, CUTTLE, 2))
	parts.append(ov(c + Vector2(2, 0) * k, 26 * k, 12.5 * k, s + 11, Color(Color("eecab4")), 0.0, 1, 0.06))
	parts.append(ov(c + Vector2(-19, 0) * k, 7 * k, 7.5 * k, s + 12, CUTTLE, 0.0, 1))
	parts.append(ov(c + Vector2(3, 0) * k, 22 * k, 9.5 * k, s + 13, CUTTLE, 0.0, 0))
	sil(ci, parts, rim)
	for i in 6:
		var x := (-10.0 + float(i) * 5.5) * k
		pl(ci, [c + Vector2(x, -8 * k), c + Vector2(x + 1.5 * k, -4 * k), c + Vector2(x - 0.5 * k, 0)], 1.8, Color(Color("8a4a3a"), 0.45), s + i)
	var e := c + Vector2(-19, -2.5) * k
	ci.draw_circle(e, 3.2 * k, Color("f2e4b0"))
	pl(ci, [e + Vector2(-2, -0.8) * k, e + Vector2(-0.7, 0.8) * k, e + Vector2(0, 0), e + Vector2(0.7, 0.8) * k, e + Vector2(2, -0.8) * k], 1.6, INK, s)
	ci.draw_arc(e, 3.2 * k, 0, TAU, 12, Color(INK, 0.7), 1.2, true)

## 比目鱼：从上往下看的扁圆鱼，一圈裙边鳍，两只眼睛挤在同一边
static func _flounder(ci: CanvasItem, c: Vector2, sz: float, s: int, rim: bool) -> void:
	var k := sz / 26.0
	var tail := pg([c + Vector2(24, -3) * k, c + Vector2(37, -11) * k, c + Vector2(34, 0) * k, c + Vector2(37, 11) * k, c + Vector2(24, 3) * k], s, FLOUNDER.darkened(0.15), 1)
	var fringe := ov(c, 29 * k, 17 * k, s + 1, FLOUNDER.darkened(0.12), -0.05, 1, 0.05)
	var body := ov(c, 25 * k, 13.5 * k, s + 2, FLOUNDER, -0.05, 0)
	sil(ci, [tail, fringe, body], rim)
	for i in 18:
		var an := TAU * float(i) / 18.0
		var p := c + Vector2(cos(an) * 25.5, sin(an) * 14.0) * k
		ln(ci, p, c + Vector2(cos(an) * 28.5, sin(an) * 16.5) * k, 1.0, Color(INK, 0.28), s + i)
	for i in 10:
		var p := c + Vector2(lerpf(-14, 20, srnd(s + i * 3)), lerpf(-9, 9, srnd(s + i * 7 + 1))) * k
		ci.draw_arc(p, 2.0 * k, 0, TAU, 8, Color(Color("f2e2c0"), 0.75), 1.4, true)
		ci.draw_circle(p, 0.9 * k, Color(Color("6a4a2a"), 0.6))
	pl(ci, arcp(c + Vector2(4, 4) * k, Vector2(18, 6) * k, PI * 1.1, PI * 1.9, 12), 1.2, Color(INK, 0.3), s)
	for q in [Vector2(-15, -7), Vector2(-10, -10)]:
		var e := c + (q as Vector2) * k
		ci.draw_circle(e, 2.8 * k, Color.WHITE)
		ci.draw_circle(e + Vector2(-0.5, 0.3) * k, 1.7 * k, INK)
		ci.draw_arc(e, 2.8 * k, 0, TAU, 10, Color(INK, 0.7), 1.2, true)
	pl(ci, [c + Vector2(-25, -1) * k, c + Vector2(-22, 2) * k, c + Vector2(-19, 1) * k], 1.4, Color(INK, 0.7), s)

## 甲鱼：从上往下看，圆圆的软壳边，伸着长脖子和尖鼻头，四只带爪的蹼
static func _softshell(ci: CanvasItem, c: Vector2, sz: float, s: int, rim: bool) -> void:
	var k := sz / 20.0
	var skin := SOFTSHELL.lightened(0.12)
	var parts := []
	for q in [[Vector2(-12, -11), -2.4], [Vector2(-12, 11), 2.4], [Vector2(14, -10), -0.7], [Vector2(14, 10), 0.7]]:
		var p: Vector2 = q[0]
		var a: float = q[1]
		var d := Vector2(cos(a), sin(a))
		parts.append(ov(c + p * k + d * 4.0 * k, 7.0 * k, 4.0 * k, s + parts.size(), skin, a, 1))
	parts.append(pg([c + Vector2(19, -3) * k, c + Vector2(27, 0) * k, c + Vector2(19, 3) * k], s + 5, skin, 1))
	parts.append(stk(c + Vector2(-14, 0) * k, c + Vector2(-27, -2) * k, 3.6 * k, s + 6, skin, 1))
	parts.append(ov(c + Vector2(-30, -2.5) * k, 6.0 * k, 4.6 * k, s + 7, skin, 0.0, 1))
	parts.append(ov(c + Vector2(-36.5, -3) * k, 2.4 * k, 1.6 * k, s + 8, skin.darkened(0.1), 0.0, 1))
	parts.append(ov(c, 22 * k, 16 * k, s + 9, skin, 0.0, 1, 0.03))
	parts.append(ov(c + Vector2(1, 0) * k, 18 * k, 12.5 * k, s + 10, SOFTSHELL, 0.0, 0))
	sil(ci, parts, rim)
	for q in [Vector2(-12, -11), Vector2(-12, 11), Vector2(14, -10), Vector2(14, 10)]:
		var p := c + (q as Vector2) * k
		var d := ((q as Vector2) * Vector2(1.0, 1.2)).normalized()
		for j in 3:
			var o := d.orthogonal() * (float(j) - 1.0) * 2.4 * k
			ln(ci, p + d * 9.0 * k + o, p + d * 11.5 * k + o, 1.3, INK, s + j)
	ln(ci, c + Vector2(-14, 0) * k, c + Vector2(14, 0) * k, 1.4, Color(INK, 0.3), s)
	for i in 9:
		var p := c + Vector2(lerpf(-13, 15, srnd(s + i * 3)), lerpf(-9, 9, srnd(s + i * 7 + 2))) * k
		ci.draw_circle(p, 1.0 * k, Color(Color("3e4a22"), 0.6))
	for side in [-1.0, 1.0]:
		ci.draw_circle(c + Vector2(-31.5, -2.5 + side * 2.4) * k, 1.0 * k, INK)
	ci.draw_circle(c + Vector2(-38, -3) * k, 0.6 * k, INK)

## 章鱼：圆鼓鼓的脑袋，八条腕往四周弯着，腕上一排白吸盘
static func _octopus(ci: CanvasItem, c: Vector2, sz: float, s: int, rim: bool) -> void:
	var k := sz / 16.0
	var parts := []
	var arms := []
	for i in 8:
		var t := float(i) / 7.0
		var b := c + Vector2(lerpf(-9, 9, t), 15) * k
		var a := lerpf(PI * 0.92, PI * 0.08, t)
		var len := (24.0 - absf(t - 0.5) * 6.0) * k
		var curl := (1.8 if t < 0.5 else -1.8)
		var sp := []
		var ws := []
		var p := b
		var d := Vector2(cos(a), sin(a))
		for j in 11:
			var u := float(j) / 10.0
			sp.append(p)
			ws.append(lerpf(3.8, 0.8, u) * k)
			p += d * len / 10.0
			d = d.rotated(curl * 0.035 * float(j) * (1.0 if j > 4 else 0.3))
		arms.append(sp)
		parts.append(pg(_tube(sp, ws), s + i, OCTO.darkened(0.06), 1))
	parts.append(ov(c + Vector2(0, 12) * k, 11 * k, 6 * k, s + 9, OCTO.darkened(0.04), 0.0, 1))
	parts.append(ov(c + Vector2(0, -2) * k, 14 * k, 15 * k, s + 10, OCTO, 0.0, 0))
	sil(ci, parts, rim)
	for i in arms.size():
		var sp: Array = arms[i]
		for j in range(2, 9, 2):
			var p: Vector2 = sp[j]
			ci.draw_circle(p + Vector2(0, 0.6 * k), maxf(1.1 * k * (1.0 - float(j) / 12.0), 0.8), Color(Color("f6d6c6"), 0.9))
	for side in [-1.0, 1.0]:
		var e := c + Vector2(side * 6.0, 5.0) * k
		ci.draw_circle(e, 3.4 * k, Color("f6e6b0"))
		ci.draw_colored_polygon(ell(e, Vector2(2.4, 1.0) * k, s, 0.0, 10), INK)
		ci.draw_arc(e, 3.4 * k, 0, TAU, 12, Color(INK, 0.7), 1.2, true)
	for q in [Vector2(-5, -9), Vector2(4, -11), Vector2(8, -4)]:
		ci.draw_circle(c + (q as Vector2) * k, 1.4 * k, Color(Color("a83a2a"), 0.6))

## 鳐鱼：从上往下看，一块大菱形翅膀，后面一条细长的鞭子尾巴
static func _ray(ci: CanvasItem, c: Vector2, sz: float, s: int, rim: bool) -> void:
	var k := sz / 30.0
	var nose := c + Vector2(0, -20) * k
	var lw := c + Vector2(-32, 4) * k
	var rw := c + Vector2(32, 4) * k
	var rear := c + Vector2(0, 16) * k
	var body := []
	body.append_array(_bez(nose, c + Vector2(-16, -16) * k, lw, 6))
	body.append_array(_bez(lw, c + Vector2(-14, 14) * k, rear, 6).slice(1))
	body.append_array(_bez(rear, c + Vector2(14, 14) * k, rw, 6).slice(1))
	body.append_array(_bez(rw, c + Vector2(16, -16) * k, nose, 6).slice(1, 6))
	var tail := _bez(c + Vector2(0, 12) * k, c + Vector2(4, 30) * k, c + Vector2(28, 22) * k, 10)
	var ws := []
	for j in 11:
		ws.append(lerpf(2.4, 0.7, float(j) / 10.0) * k)
	var pel := [ov(c + Vector2(-7, 15) * k, 5 * k, 3.5 * k, s + 2, RAY.darkened(0.1), 0.5, 1), ov(c + Vector2(7, 15) * k, 5 * k, 3.5 * k, s + 3, RAY.darkened(0.1), -0.5, 1)]
	sil(ci, [pg(_tube(tail, ws), s, RAY.darkened(0.15), 1)] + pel + [pg(body, s + 4, RAY, 0)], rim)
	var sp: Vector2 = tail[3]
	ci.draw_colored_polygon(PackedVector2Array([sp, sp + Vector2(2, -4) * k, sp + Vector2(3, 1) * k]), Color(INK, 0.7))
	for i in 12:
		var p := c + Vector2(lerpf(-20, 20, srnd(s + i * 3)), lerpf(-6, 10, srnd(s + i * 7 + 2))) * k
		if absf(p.x - c.x) < 22.0 * k - absf(p.y - c.y - 2.0 * k) * 1.2:
			ci.draw_circle(p, 1.2 * k, Color(Color("efe2c4"), 0.8))
	pl(ci, [c + Vector2(0, -14) * k, c + Vector2(0, 12) * k], 1.6, Color(INK, 0.22), s)
	for side in [-1.0, 1.0]:
		var e := c + Vector2(side * 5.0, -8.0) * k
		ci.draw_circle(e, 2.0 * k, Color.WHITE)
		ci.draw_circle(e, 1.2 * k, INK)
		ci.draw_colored_polygon(ell(e + Vector2(side * 1.0, 3.6) * k, Vector2(1.4, 0.9) * k, s, 0.0, 8), Color(INK, 0.5))

## 锦鲤：白底上几大块红斑，长须、大尾巴
static func _koi(ci: CanvasItem, c: Vector2, L: float, H: float, ang: float, s: int, rim: bool) -> void:
	_sp(ci, c, L, H, ang, s, KOI_W, rim, {"whisk": true, "fin": Color("f0dcc8"), "tail": 0.38, "fork": 0.3})
	var body := PackedVector2Array(rot_pts(_fish_geo(L, H, L * 0.38, 0.3)[0], ang, c))
	for q in [[Vector2(-L * 0.25, -H * 0.62), Vector2(L * 0.09, H * 0.3)], [Vector2(-L * 0.02, -H * 0.45), Vector2(L * 0.15, H * 0.5)], [Vector2(L * 0.27, -H * 0.05), Vector2(L * 0.1, H * 0.42)], [Vector2(L * 0.08, H * 0.4), Vector2(L * 0.08, H * 0.25)]]:
		var e := ell(_fp(c, ang, q[0]), q[1], s, 0.15, 14, ang)
		for piece in Geometry2D.intersect_polygons(e, body):
			ci.draw_colored_polygon(piece, KOI_R)
	var er := maxf(H * 0.17, 1.8)
	var e := _fp(c, ang, Vector2(-L * 0.4, -H * 0.18))
	ci.draw_circle(e, er, Color.WHITE)
	ci.draw_circle(e + Vector2(-er * 0.15, 0).rotated(ang), er * 0.6, INK)

## 腔棘鱼：活化石。深蓝色，满身白斑，鳍长在肉柄上像小短腿，尾巴中间多出一小撮
static func _coela(ci: CanvasItem, c: Vector2, L: float, H: float, s: int, rim: bool) -> void:
	var g := _fish_geo(L, H, 0.0, 0.0)
	var fin := COELA.lightened(0.12)
	var tb := Vector2(L * 0.5 - 3.0, 0)
	var tail := [tb + Vector2(0, -H * 0.4), tb + Vector2(L * 0.2, -H * 1.0), tb + Vector2(L * 0.13, -H * 0.18), tb + Vector2(L * 0.27, -H * 0.08), tb + Vector2(L * 0.27, H * 0.08), tb + Vector2(L * 0.13, H * 0.18), tb + Vector2(L * 0.2, H * 1.0), tb + Vector2(0, H * 0.4)]
	var back := [pg(rot_pts(tail, 0.0, c), s, fin, 1),
		pg(rot_pts([Vector2(-L * 0.12, -H * 0.8), Vector2(-L * 0.02, -H * 1.5), Vector2(L * 0.08, -H * 0.85)], 0.0, c), s + 1, fin, 1)]
	for q in [[Vector2(L * 0.26, -H * 0.62), -0.75], [Vector2(L * 0.26, H * 0.62), 0.75], [Vector2(L * 0.02, H * 0.72), 1.0]]:
		var p: Vector2 = c + (q[0] as Vector2)
		var a: float = q[1]
		var d := Vector2(cos(a), sin(a))
		back.append(ov(p + d * H * 0.55, H * 0.6, H * 0.26, s + back.size(), fin, a, 1))
	var body := pg(rot_pts(g[0], 0.0, c), s + 20, COELA, 0)
	var pa := 0.85
	var pp := c + Vector2(-L * 0.2, H * 0.28)
	var pd := Vector2(cos(pa), sin(pa))
	var pect := [ov(pp + pd * H * 0.55, H * 0.6, H * 0.26, s + 21, fin, pa, 1)]
	if rim:
		_f_rim(ci, back + [body] + pect)
	sil(ci, back + [body], false)
	_fish_det(ci, c, L, H, 0.0, s, COELA, true, false)
	for i in 14:
		var p := c + Vector2(lerpf(-L * 0.3, L * 0.42, srnd(s + i * 3)), lerpf(-H * 0.65, H * 0.45, srnd(s + i * 7 + 1)))
		ci.draw_colored_polygon(ell(p, Vector2(H * 0.13, H * 0.09), s + i, 0.25, 8, srnd(s + i) * 3.0), Color(Color("e8eef2"), 0.85))
	sil(ci, pect, false, 2.0)
	pl(ci, [c + Vector2(-L * 0.52, H * 0.15), c + Vector2(-L * 0.4, H * 0.22)], 1.4, Color(INK, 0.6), s)

# ---------------------------------------------------------------- 弯虾、远古贝类

## 河虾：弓着背的一只虾，头朝左下，腹节一节节往右下卷到肚子底下，长须往后甩
static func _curl_shrimp(ci: CanvasItem, c: Vector2, R: float, s: int, rim: bool) -> void:
	var col := Color("f2a07a")
	var n := 7
	var segs := []
	for i in n:
		var t := float(i) / float(n - 1)
		var a := lerpf(-PI * 0.72, PI * 0.3, t)
		segs.append([c + Vector2(cos(a), sin(a)) * R * lerpf(1.0, 0.8, t), a + PI * 0.5, R * lerpf(0.52, 0.3, t)])
	var first: Array = segs[0]
	var back := -Vector2(cos(first[1]), sin(first[1]))
	var hc: Vector2 = (first[0] as Vector2) + back * R * 0.5
	var hf := hc + back * R * 0.6
	var last: Array = segs[n - 1]
	var lp: Vector2 = last[0]
	var ld := Vector2(cos(last[1]), sin(last[1]))
	var lo := ld.orthogonal()
	var parts := []
	parts.append(pg([lp + ld * R * 0.4 + lo * R * 0.05, lp + ld * R * 0.55 + lo * R * 0.4, lp - lo * R * 0.1, lp + ld * R * 0.55 - lo * R * 0.45], s, col.darkened(0.06), 1))
	parts.append(pg([lp - lo * R * 0.12, lp + ld * R * 0.75, lp + lo * R * 0.12], s + 1, col.darkened(0.1), 1))
	for i in range(n - 1, -1, -1):
		var q: Array = segs[i]
		parts.append(ov(q[0], R * 0.36, q[2], s + 2 + i, col, q[1], 1, 0.02))
	parts.append(pg([hf + back.orthogonal() * R * 0.05, hf + back * R * 0.5 + back.orthogonal() * R * 0.18, hf - back.orthogonal() * R * 0.1], s + 10, col.lightened(0.05), 1))
	parts.append(ov(hc, R * 0.7, R * 0.5, s + 11, col, back.angle(), 0))
	if rim:
		_f_rim(ci, parts)
	for i in 4:
		var q: Array = segs[i + 1]
		var p: Vector2 = q[0]
		var inw := (c - p).normalized()
		ln(ci, p + inw * float(q[2]) * 0.8, p + inw * (float(q[2]) + R * 0.2), 1.6, col.darkened(0.25), s + i)
	for j in 3:
		var p := hc + back * R * (0.2 - 0.25 * float(j)) + Vector2(0, R * 0.38)
		ln(ci, p, p + Vector2(-R * 0.06, R * 0.32), 1.6, col.darkened(0.25), s + j)
	sil(ci, parts, false, 2.4)
	for i in n:
		var q: Array = segs[i]
		var d := Vector2(cos(q[1]), sin(q[1]))
		var o := d.orthogonal()
		var p: Vector2 = q[0]
		ln(ci, p - o * float(q[2]) * 0.55 - d * R * 0.1, p - o * float(q[2]) * 0.55 + d * R * 0.1, 1.6, Color(1, 1, 1, 0.45), s + i)
	var eye := hc + back * R * 0.3 + back.orthogonal() * R * 0.22
	ci.draw_circle(eye, maxf(R * 0.1, 1.5), INK)
	ci.draw_circle(eye + Vector2(-0.4, -0.4), maxf(R * 0.035, 0.6), Color.WHITE)
	for j in 2:
		var p0 := hf + back * R * 0.1
		pl(ci, _bez(p0, p0 + Vector2(-R * 0.5, -R * (1.6 + 0.3 * float(j))), c + Vector2(R * (0.5 + 0.5 * float(j)), -R * (1.5 + 0.2 * float(j))), 8), 1.3, Color(INK, 0.7), s + j)

## 鲎：活化石。前面一块马蹄形大甲壳，中间六角形的腹甲两边带刺，后面一根长剑尾
static func _horseshoe(ci: CanvasItem, c: Vector2, r: float, s: int, rim: bool) -> void:
	var k := r / 24.0
	var pro := arcp(c, Vector2(25, 15) * k, PI * 0.9, PI * 2.1, 18)
	pro.append(c + Vector2(10, 6) * k)
	pro.append(c + Vector2(-10, 6) * k)
	var opi := [c + Vector2(-16, 4) * k, c + Vector2(16, 4) * k, c + Vector2(15, 15) * k, c + Vector2(7, 24) * k, c + Vector2(-7, 24) * k, c + Vector2(-15, 15) * k]
	var tl := _bez(c + Vector2(0, 20) * k, c + Vector2(3, 32) * k, c + Vector2(16, 38) * k, 8)
	var ws := []
	for j in 9:
		ws.append(lerpf(2.4, 0.8, float(j) / 8.0) * k)
	var parts := [pg(_tube(tl, ws), s, LIMULUS.darkened(0.15), 1)]
	for side in [-1.0, 1.0]:
		for j in 3:
			var p := c + Vector2(side * (15.5 - float(j) * 1.4), 8.0 + float(j) * 5.0) * k
			parts.append(pg([p + Vector2(0, -1.6) * k, p + Vector2(side * 5.0, 1.2) * k, p + Vector2(0, 1.6) * k], s + 2 + j, LIMULUS.darkened(0.1), 1))
	parts.append(pg(opi, s + 8, LIMULUS.darkened(0.05), 1))
	parts.append(pg(pro, s + 9, LIMULUS, 0))
	sil(ci, parts, rim)
	pl(ci, arcp(c + Vector2(0, 2) * k, Vector2(20, 16) * k, PI * 1.05, PI * 1.95, 14), 1.4, Color(INK, 0.35), s)
	pl(ci, [c + Vector2(0, -18) * k, c + Vector2(0, 4) * k], 1.6, Color(INK, 0.35), s)
	for side in [-1.0, 1.0]:
		pl(ci, [c + Vector2(side * 5, -15) * k, c + Vector2(side * 7, -6) * k, c + Vector2(side * 6, 4) * k], 1.3, Color(INK, 0.3), s)
		ci.draw_colored_polygon(ell(c + Vector2(side * 11.0, -6.0) * k, Vector2(2.2, 1.2) * k, s, 0.0, 8, side * 0.5), Color(INK, 0.75))
	pl(ci, [c + Vector2(0, 6) * k, c + Vector2(0, 22) * k], 1.3, Color(INK, 0.3), s)
	for side in [-1.0, 1.0]:
		pl(ci, [c + Vector2(side * 6, 6) * k, c + Vector2(side * 5, 20) * k], 1.2, Color(INK, 0.3), s)
	hl(ci, c + Vector2(-9, -11) * k, 6 * k, 2.4 * k, -0.4, 0.4)

## 三叶虫：远古的海底小虫，头甲两只月牙眼，身子一节节，竖着分成左中右三片
static func _trilobite(ci: CanvasItem, c: Vector2, r: float, s: int, rim: bool) -> void:
	var k := r / 20.0
	var parts := []
	for side in [-1.0, 1.0]:
		parts.append(pg([c + Vector2(side * 16, -6) * k, c + Vector2(side * 22, 10) * k, c + Vector2(side * 13, -3) * k], s + 1, TRILO.darkened(0.08), 1))
	var head := arcp(c + Vector2(0, -6) * k, Vector2(19, 14) * k, PI, TAU, 14)
	parts.append(pg(head, s + 2, TRILO, 1))
	parts.append(ov(c + Vector2(0, 24) * k, 9 * k, 5.5 * k, s + 3, TRILO.darkened(0.04), 0.0, 1))
	for j in 8:
		var y := (-3.0 + float(j) * 3.4) * k
		var w := (15.5 - float(j) * 0.8) * k
		parts.append(ov(c + Vector2(0, y), w, 2.2 * k, s + 4 + j, TRILO.lightened(0.04 * float(j % 2)), 0.0, 1, 0.02))
	sil(ci, parts, rim)
	var ax := ov(c + Vector2(0, 9) * k, 4.6 * k, 15 * k, s + 20, TRILO.lightened(0.12), 0.0, 1)
	sil(ci, [ax, ov(c + Vector2(0, -11) * k, 5.0 * k, 6.5 * k, s + 21, TRILO.lightened(0.12), 0.0, 0)], false, 1.6)
	for j in 7:
		var y := (-1.5 + float(j) * 3.4) * k
		ln(ci, c + Vector2(-4.2 * k, y), c + Vector2(4.2 * k, y), 1.0, Color(INK, 0.4), s + j)
	for side in [-1.0, 1.0]:
		var e := c + Vector2(side * 10.0, -10.0) * k
		ci.draw_arc(e, 3.2 * k, PI * (0.6 if side < 0 else -0.6), PI * (1.4 if side < 0 else 0.4), 8, INK, 2.2, true)
		ci.draw_circle(e + Vector2(side * 0.8, 0) * k, 1.2 * k, Color(INK, 0.6))

## 大菊石：远古的盘卷大螺，一圈套一圈往里卷，壳上一道道弯肋，金灿灿的
static func _ammonite(ci: CanvasItem, c: Vector2, R: float, s: int, rim: bool) -> void:
	var kk := log(1.0 / 0.46) / TAU
	sil(ci, [circ(c, R, s, AMMO, 0, 0.01)], rim)
	var spiral := []
	for j in 121:
		var th := TAU + TAU * 3.0 * float(j) / 120.0
		var rr := R * exp(-kk * th)
		spiral.append(c + Vector2(cos(th - 0.4), sin(th - 0.4)) * rr)
	for j in 64:
		var th := TAU * 3.0 * float(j) / 64.0
		var r0 := R * exp(-kk * th) * 0.97
		var r1 := R * exp(-kk * (th + TAU)) * 1.04
		var a0 := th - 0.4
		var mid := c + Vector2(cos(a0 + 0.08), sin(a0 + 0.08)) * (r0 + r1) * 0.5
		pl(ci, [c + Vector2(cos(a0), sin(a0)) * r0, mid, c + Vector2(cos(a0), sin(a0)) * r1], maxf(R * 0.035 * exp(-kk * th), 1.0), Color(Color("9a6420"), 0.55), s + j)
	pl(ci, spiral, 2.0, Color(INK, 0.8), s)
	ln(ci, c + Vector2(cos(-0.4), sin(-0.4)) * R, c + Vector2(cos(-0.4), sin(-0.4)) * R * 0.46, 2.0, Color(INK, 0.8), s)
	ci.draw_circle(c, R * 0.05, Color("7a4a18"))
	hl(ci, c + Vector2(-R * 0.45, -R * 0.55), R * 0.22, R * 0.09, -0.7, 0.55)

## 海马：头朝左，长嘴、头顶一个小冠，肚子往前挺，尾巴在底下卷成一圈，身上一节节的环纹
static func _seahorse(ci: CanvasItem, c: Vector2, sz: float, s: int, rim: bool) -> void:
	var k := sz / 20.0
	var col := Color("e8a040")
	var sp := []
	for q in [Vector2(3, -13), Vector2(6, -7), Vector2(6, 0), Vector2(4, 7), Vector2(0, 13), Vector2(0, 19), Vector2(4, 23), Vector2(9, 22), Vector2(10, 17), Vector2(6, 16)]:
		sp.append(c + (q as Vector2) * k)
	var ws := []
	for w in [5.5, 7.0, 7.5, 6.5, 4.6, 3.2, 2.4, 1.9, 1.5, 1.2]:
		ws.append(float(w) * k)
	var parts := []
	parts.append(pg([c + Vector2(10, -4) * k, c + Vector2(17, 0) * k, c + Vector2(16, 5) * k, c + Vector2(10, 6) * k], s, col.lightened(0.15), 1))
	parts.append(pg(_tube(sp, ws), s + 1, col, 0))
	parts.append(stk(c + Vector2(-3, -17) * k, c + Vector2(-14, -14) * k, 2.2 * k, s + 2, col.darkened(0.05), 1))
	parts.append(ov(c + Vector2(-14.5, -14) * k, 1.8 * k, 2.4 * k, s + 3, col.darkened(0.05), 0.0, 1))
	parts.append(pg([c + Vector2(-1, -21) * k, c + Vector2(1, -27) * k, c + Vector2(3, -24) * k, c + Vector2(5, -27) * k, c + Vector2(6, -20) * k], s + 4, col.darkened(0.08), 1))
	parts.append(ov(c + Vector2(1, -18) * k, 6.0 * k, 5.0 * k, s + 5, col, -0.3, 0))
	sil(ci, parts, rim)
	for j in range(1, 8):
		var a: Vector2 = sp[j - 1]
		var b: Vector2 = sp[j + 1]
		var p: Vector2 = sp[j]
		var o := (b - a).normalized().orthogonal()
		ln(ci, p + o * float(ws[j]) * 0.85, p - o * float(ws[j]) * 0.85, 1.2, Color(INK, 0.3), s + j)
	pl(ci, [(sp[1] as Vector2) + Vector2(-5, 0) * k, (sp[2] as Vector2) + Vector2(-6, 0) * k, (sp[3] as Vector2) + Vector2(-5, 0) * k], 2.6, Color(Color("f6dca0"), 0.7), s)
	var e := c + Vector2(-0.5, -19) * k
	ci.draw_circle(e, 2.0 * k, Color.WHITE)
	ci.draw_circle(e + Vector2(-0.4, 0) * k, 1.2 * k, INK)

## 乌贼（第四稿）：竖着摆，椭圆的身子朝上、两边一圈薄薄的裙边鳍，底下大眼睛，六只短腕加两条带吸盘头的长触手往下垂
static func _cuttle2(ci: CanvasItem, c: Vector2, sz: float, s: int, rim: bool) -> void:
	var k := sz / 20.0
	var parts := []
	var root := c + Vector2(0, 13) * k
	for side in [-1.0, 1.0]:
		var sp := _bez(root + Vector2(side * 4, 0) * k, root + Vector2(side * 13, 6) * k, root + Vector2(side * 13, 15) * k, 8)
		var ws := []
		for j in 9:
			ws.append(1.7 * k)
		parts.append(pg(_tube(sp, ws), s + 1, CUTTLE.darkened(0.05), 2))
		parts.append(ov(root + Vector2(side * 13, 16) * k, 3.0 * k, 3.8 * k, s + 2, CUTTLE.darkened(0.05), 0.0, 1))
	for i in 4:
		var t := float(i) / 3.0
		var b := root + Vector2(lerpf(-5, 5, t), -1) * k
		var tip := b + Vector2(lerpf(-5, 5, t), 11.0) * k
		var sp := _bez(b, b.lerp(tip, 0.5) + Vector2(lerpf(-2, 2, t), 0) * k, tip, 6)
		var ws := []
		for j in 7:
			ws.append(lerpf(3.6, 1.8, float(j) / 6.0) * k)
		parts.append(pg(_tube(sp, ws), s + 3 + i, CUTTLE, 2))
	parts.append(ov(c + Vector2(0, -6) * k, 19 * k, 16 * k, s + 10, Color("f2d6c4"), 0.0, 2, 0.05))
	parts.append(ov(c + Vector2(0, 10) * k, 10 * k, 6.5 * k, s + 11, CUTTLE, 0.0, 1))
	parts.append(ov(c + Vector2(0, -6) * k, 13 * k, 14.5 * k, s + 12, CUTTLE, 0.0, 0))
	sil(ci, parts, rim, 2.4)
	for j in 4:
		var y := (-15.0 + float(j) * 6.0) * k
		var w := sqrt(maxf(1.0 - pow((y / k + 6.0) / 14.5, 2.0), 0.0)) * 10.0 * k
		pl(ci, [c + Vector2(-w, y), c + Vector2(-w * 0.4, y - 1.5 * k), c + Vector2(w * 0.2, y + 0.5 * k), c + Vector2(w * 0.8, y - 1.0 * k)], 2.0, Color(Color("8a4a3a"), 0.45), s + j)
	for side in [-1.0, 1.0]:
		var e := c + Vector2(side * 5.5, 9) * k
		ci.draw_circle(e, 3.0 * k, Color("f2e4b0"))
		pl(ci, [e + Vector2(-1.8, -0.6) * k, e + Vector2(-0.7, 0.8) * k, e, e + Vector2(0.7, 0.8) * k, e + Vector2(1.8, -0.6) * k], 1.6, INK, s)
		ci.draw_arc(e, 3.0 * k, 0, TAU, 12, Color(INK, 0.7), 1.2, true)

## 鲨鱼：头朝左，尖鼻子，青灰的背、雪白的肚子，高高的三角背鳍，尾巴上长下短，腮上几道鳃裂
static func _shark(ci: CanvasItem, c: Vector2, L: float, H: float, s: int, rim: bool) -> void:
	var col := Color("7d93a6")
	var fin := col.darkened(0.1)
	var top := []
	var bot := []
	for k in 15:
		var t := float(k) / 14.0
		var pr := pow(sin(PI * (0.02 + 0.9 * t)), 0.6) * (1.0 - 0.62 * t) + 0.14 * t
		var x := lerpf(-L * 0.5, L * 0.46, t)
		top.append(c + Vector2(x, -H * pr))
		bot.append(c + Vector2(x, H * pr * 0.85 + H * 0.15 * (1.0 - t) * (1.0 - t)))
	bot.reverse()
	var body: Array = [c + Vector2(-L * 0.52, -H * 0.05)] + top + bot
	var tb := c + Vector2(L * 0.44, 0)
	var tail := [tb + Vector2(0, -H * 0.25), tb + Vector2(L * 0.24, -H * 1.5), tb + Vector2(L * 0.2, -H * 1.2), tb + Vector2(L * 0.08, 0), tb + Vector2(L * 0.15, H * 0.85), tb + Vector2(0, H * 0.25)]
	var back := [pg(tail, s, fin, 1),
		pg([c + Vector2(-L * 0.12, -H * 0.8), c + Vector2(-L * 0.02, -H * 2.0), c + Vector2(L * 0.04, -H * 1.9), c + Vector2(L * 0.1, -H * 0.7)], s + 1, fin, 1),
		pg([c + Vector2(L * 0.28, -H * 0.4), c + Vector2(L * 0.33, -H * 0.85), c + Vector2(L * 0.36, -H * 0.35)], s + 2, fin, 1),
		pg([c + Vector2(L * 0.26, H * 0.4), c + Vector2(L * 0.31, H * 0.8), c + Vector2(L * 0.34, H * 0.35)], s + 3, fin, 1)]
	var bp := pg(body, s + 4, col, 0)
	var pect := [pg([c + Vector2(-L * 0.18, H * 0.35), c + Vector2(-L * 0.06, H * 1.55), c + Vector2(-L * 0.01, H * 1.45), c + Vector2(-L * 0.02, H * 0.45)], s + 5, fin, 1)]
	if rim:
		_f_rim(ci, back + [bp] + pect)
	sil(ci, back + [bp], false)
	var poly := PackedVector2Array(body)
	for piece in Geometry2D.intersect_polygons(ell(c + Vector2(-L * 0.05, H * 0.75), Vector2(L * 0.5, H * 0.62), s, 0.0, 22), poly):
		ci.draw_colored_polygon(piece, Color("f2f0ea"))
	for k in 4:
		var x := -L * 0.3 + float(k) * L * 0.028
		pl(ci, [c + Vector2(x, -H * 0.25), c + Vector2(x - L * 0.012, 0), c + Vector2(x, H * 0.25)], 1.4, Color(INK, 0.55), s + k)
	var e := c + Vector2(-L * 0.38, -H * 0.22)
	ci.draw_circle(e, maxf(H * 0.16, 1.6), Color.WHITE)
	ci.draw_circle(e + Vector2(-0.3, 0), maxf(H * 0.11, 1.2), INK)
	pl(ci, [c + Vector2(-L * 0.44, H * 0.38), c + Vector2(-L * 0.38, H * 0.5), c + Vector2(-L * 0.32, H * 0.45)], 1.6, Color(INK, 0.75), s)
	hl(ci, c + Vector2(-L * 0.18, -H * 0.55), L * 0.12, H * 0.12, -0.1, 0.4)
	sil(ci, pect, false, 2.0)

# ---------------------------------------------------------------- 主产物：水产（每级一种，外形都不一样）

static func _main_art(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	## 第三稿里的鲫鱼（_main_art_v2 第 4 级）去掉了
	match lv:
		1:
			## 蝌蚪
			_tadpole(ci, Vector2(-8, 26), 11, s, rim)
		2:
			## 青蛙：蹲着的绿青蛙，金眼睛
			_frog(ci, Vector2(0, 20), 16, s, rim)
		3:
			## 麦穗鱼
			_main_art_v2(ci, 1, s, rim)
		4:
			## 泥鳅
			_loach(ci, Vector2(-2, 24), 58, 4.6, s, rim)
		5:
			## 河豚：气鼓鼓的刺球
			_puffer(ci, Vector2(-4, 20), 17, s, rim)
		6:
			## 鳜鱼
			_main_art_v2(ci, 8, s, rim)
		7:
			## 比目鱼
			_flounder(ci, Vector2(-4, 22), 26, s, rim)
		8:
			## 海马
			_seahorse(ci, Vector2(0, 14), 20, s, rim)
		9:
			## 乌贼：竖着摆的乌贼（横着的老画法是 _cuttle）
			_cuttle2(ci, Vector2(0, 6), 26, s, rim)
		10:
			## 章鱼
			_octopus(ci, Vector2(0, 8), 16, s, rim)
		11:
			## 鳗鱼
			_main_art_v2(ci, 11, s, rim)
		12:
			## 鳐鱼
			_ray(ci, Vector2(-4, 14), 30, s, rim)
		13:
			## 大锦鲤
			_koi(ci, Vector2(-4, 20), 66, 17, -0.1, s, rim)
		14:
			## 腔棘鱼
			_coela(ci, Vector2(-6, 18), 66, 17, s, rim)
		15:
			## 鲨鱼：青灰的背、雪白的肚子，高高的三角背鳍
			_shark(ci, Vector2(-4, 20), 72, 13, s, rim)
		_:
			## 鳇鱼王
			_main_art_v2(ci, 16, s, rim)

# ---------------------------------------------------------------- 副产物：贝类（每级一种，后段是远古的）

static func _sub_art(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			## 田螺
			_sub_art_v2(ci, 1, s, rim)
		2:
			## 河虾：弓着背、尾巴卷到肚子底下
			_curl_shrimp(ci, Vector2(4, 22), 15, s, rim)
		3, 4, 5, 6, 7:
			## 河蚌、小龙虾、河蟹、扇贝、海螺沿用第二稿
			_sub_art_v2(ci, lv + 1, s, rim)
		8:
			## 甲鱼
			_softshell(ci, Vector2(6, 20), 20, s, rim)
		9:
			## 鲎
			_horseshoe(ci, Vector2(-2, 10), 24, s, rim)
		10:
			## 三叶虫
			_trilobite(ci, Vector2(0, 12), 20, s, rim)
		11:
			## 鹦鹉螺
			_sub_art_v2(ci, 11, s, rim)
		_:
			## 大菊石：金色的盘卷大螺，最珍贵
			glow(ci, Vector2(0, 14), 58, GOLD)
			_ammonite(ci, Vector2(0, 14), 28, s, rim)
			sparks(ci, [Vector2(-36, -14), Vector2(32, -20), Vector2(40, 22)])
