class_name PA
extends Art
## 产线预览物品的公共画法。坐标同 Art：100×100，中心为原点，Y 朝下。

const TAN := Color("d9a066")
const TAN_D := Color("b07444")
const CHAR := Color("5a3418")
const PINK := Color("f29a9a")
const GOLD := Color("ffcf3f")
const PURPLE := Color("8a4fb0")
const SKY := Color("6fb7e6")
const GRASS := Color("c9b45a")
const GRASS_D := Color("9c8a3a")
const FUR := Color("8a5a34")
const FUR_D := Color("5e3a1e")
const CLAYPOT := Color("c8693a")
const BLACK := Color("2b2430")

static var xf := Transform2D.IDENTITY

static func set_xf(ci: CanvasItem, t: Transform2D) -> void:
	ci.draw_set_transform_matrix(xf * t)

static func reset_xf(ci: CanvasItem) -> void:
	ci.draw_set_transform_matrix(xf)

## 手绘抖动偶尔让细小形状自相交，无法三角化时退回凸包
static func sil(ci: CanvasItem, parts: Array, rim: bool = true, w: float = 3.0) -> void:
	for p in parts:
		var pts: PackedVector2Array = p[0]
		if Geometry2D.triangulate_polygon(pts).is_empty():
			p[0] = Geometry2D.convex_hull(pts)
	Art.sil(ci, parts, rim, w)

static func safe_poly(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	if Geometry2D.triangulate_polygon(pts).is_empty():
		pts = Geometry2D.convex_hull(pts)
	ci.draw_colored_polygon(pts, col)

# ---------------------------------------------------------------- 零件

static func circ(c: Vector2, r: float, s: int, col: Color, mode: int = 0, wob: float = 0.04) -> Array:
	return P(ell(c, Vector2(r, r), s, wob, 18), col, mode)

static func ov(c: Vector2, rx: float, ry: float, s: int, col: Color, rot: float = 0.0, mode: int = 0, wob: float = 0.04) -> Array:
	return P(ell(c, Vector2(rx, ry), s, wob, 20, rot), col, mode)

static func pg(arr: Array, s: int, col: Color, mode: int = 1) -> Array:
	return P(poly(arr, s), col, mode)

static func stk(a: Vector2, b: Vector2, r: float, s: int, col: Color = WOOD, mode: int = 1) -> Array:
	if r >= 3.0:
		return P(capsule(a, b, r, s), col, mode)
	var d := (b - a).normalized()
	var ang := Vector2(-d.y, d.x).angle()
	var pts := []
	for k in 7:
		var t := ang - PI * float(k) / 6.0
		pts.append(b + Vector2(cos(t), sin(t)) * r)
	for k in 7:
		var t := ang + PI - PI * float(k) / 6.0
		pts.append(a + Vector2(cos(t), sin(t)) * r)
	return P(poly(pts, s, r * 0.12), col, mode)

static func bx(x: float, y: float, w: float, h: float, rad: float, s: int, col: Color, mode: int = 1) -> Array:
	return P(rrect(Rect2(x, y, w, h), rad, s, 0.6), col, mode)

static func leaf(base: Vector2, l: float, w: float, ang: float, s: int, col: Color = LEAF) -> Array:
	var d := Vector2(cos(ang), sin(ang))
	return P(ell(base + d * l * 0.5, Vector2(l * 0.5, w), s, 0.03, 14, ang), col, 1)

static func vein(ci: CanvasItem, base: Vector2, l: float, ang: float, s: int, col: Color = LEAF_D) -> void:
	var d := Vector2(cos(ang), sin(ang))
	ln(ci, base + d * l * 0.15, base + d * l * 0.85, 1.6, col, s)

static func band(c: Vector2, r: float, th: float, a0: float, a1: float, s: int, col: Color, mode: int = 1) -> Array:
	return P(_arc_band(c, r, th, a0, a1, s), col, mode)

## 整圈的环：一圈的带状多边形会自相接触，拆成两半
static func ring(c: Vector2, r: float, th: float, s: int, col: Color, mode: int = 1) -> Array:
	return [band(c, r, th, -0.05, PI + 0.05, s, col, mode), band(c, r, th, PI - 0.05, TAU + 0.05, s + 1, col, mode)]

static func _arc_band(c: Vector2, r: float, th: float, a0: float, a1: float, s: int) -> PackedVector2Array:
	var arr := []
	for k in 13:
		var a := lerpf(a0, a1, float(k) / 12.0)
		arr.append(c + Vector2(cos(a), sin(a)) * (r + th))
	for k in 13:
		var a := lerpf(a1, a0, float(k) / 12.0)
		arr.append(c + Vector2(cos(a), sin(a)) * (r - th))
	return poly(arr, s, 0.6)

static func arcp(c: Vector2, r: Vector2, a0: float, a1: float, n: int = 12) -> Array:
	var out := []
	for k in n + 1:
		var a := lerpf(a0, a1, float(k) / float(n))
		out.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return out

## 旋转体：prof 是 Vector2(半宽, y)，从上到下
static func lathe(prof: Array, cx: float = 0.0) -> Array:
	var out := []
	for p in prof:
		var v: Vector2 = p
		out.append(Vector2(cx + v.x, v.y))
	for i in range(prof.size() - 1, -1, -1):
		var v: Vector2 = prof[i]
		if v.x < 2.5:
			continue
		out.append(Vector2(cx - v.x, v.y))
	return out

## 沿 prof 在高度 y 处的半宽
static func prof_w(prof: Array, y: float) -> float:
	for i in prof.size() - 1:
		var a: Vector2 = prof[i]
		var b: Vector2 = prof[i + 1]
		if y >= a.y and y <= b.y:
			return lerpf(a.x, b.x, (y - a.y) / maxf(b.y - a.y, 0.001))
	return 0.0

# ---------------------------------------------------------------- 细节

static func hl(ci: CanvasItem, c: Vector2, rx: float, ry: float, rot: float = -0.5, a: float = 0.5) -> void:
	ci.draw_colored_polygon(ell(c, Vector2(rx, ry), 5, 0.0, 10, rot, 0.3), Color(1, 1, 1, a))

static func xeye(ci: CanvasItem, c: Vector2, r: float, w: float = 2.4) -> void:
	ln(ci, c + Vector2(-r, -r), c + Vector2(r, r), w, INK, 1)
	ln(ci, c + Vector2(-r, r), c + Vector2(r, -r), w, INK, 2)

static func eye(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_circle(c, r, Color.WHITE)
	ci.draw_circle(c + Vector2(-r * 0.2, 0), r * 0.58, INK)

static func spark(ci: CanvasItem, c: Vector2, r: float, col: Color = Color(1, 1, 0.85)) -> void:
	ci.draw_colored_polygon(star_pts(c, r, r * 0.28, 4, 3), col)

static func sparks(ci: CanvasItem, pts: Array, r: float = 6.0) -> void:
	for p in pts:
		spark(ci, p, r)

static func glow(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	for k in 5:
		ci.draw_circle(c, r * (1.0 - 0.16 * float(k)), Color(col, 0.07 + 0.03 * float(k)))

static func rays(ci: CanvasItem, c: Vector2, r0: float, r1: float, n: int, col: Color, w: float = 3.0, off: float = 0.0) -> void:
	for k in n:
		var a := off + TAU * float(k) / float(n)
		var d := Vector2(cos(a), sin(a))
		ci.draw_line(c + d * r0, c + d * r1, col, w, true)

static func zig(ci: CanvasItem, x0: float, x1: float, y: float, h: float, n: int, col: Color, w: float = 2.2, s: int = 0) -> void:
	var arr := []
	for k in n + 1:
		arr.append(Vector2(lerpf(x0, x1, float(k) / float(n)), y + (h if k % 2 == 1 else -h)))
	pl(ci, arr, w, col, s)

static func steam(ci: CanvasItem, c: Vector2, n: int = 3, h: float = 22.0) -> void:
	for k in n:
		var x := c.x + (float(k) - float(n - 1) * 0.5) * 11.0
		var arr := []
		for j in 7:
			var t := float(j) / 6.0
			arr.append(Vector2(x + sin(t * 5.0 + float(k) + float(boil) * 0.8) * 3.5, c.y - t * h))
		ci.draw_polyline(PackedVector2Array(arr), Color(1, 1, 1, 0.75), 3.0, true)

static func smoke(ci: CanvasItem, c: Vector2, sc: float = 1.0) -> void:
	for k in 3:
		ci.draw_colored_polygon(ell(c + Vector2(float(k) * 5.0, -float(k) * 11.0) * sc, Vector2(7, 6) * sc * (1.0 + 0.2 * float(k)), 40 + k, 0.08, 12), Color(0.85, 0.82, 0.78, 0.75 - 0.15 * float(k)))

static func grill(ci: CanvasItem, c: Vector2, w: float, n: int, s: int, ang: float = -0.5) -> void:
	var d := Vector2(cos(ang), sin(ang))
	var nn := Vector2(-d.y, d.x)
	for k in n:
		var m := c + nn * (float(k) - float(n - 1) * 0.5) * 8.0
		ln(ci, m - d * w * 0.5, m + d * w * 0.5, 2.6, CHAR, s + k)

static func flame(ci: CanvasItem, c: Vector2, w: float, h: float, s: int, rim: bool = false) -> void:
	sil(ci, [P(flame_pts(c, w, h, s), FIRE, 1)], rim)
	safe_poly(ci, flame_pts(c + Vector2(0, h * 0.16), w * 0.55, h * 0.58, s + 3), FIRE2)
	if w >= 14.0:
		safe_poly(ci, flame_pts(c + Vector2(0, h * 0.27), w * 0.25, h * 0.26, s + 5), Color(1, 1, 0.85))

static func rope(ci: CanvasItem, a: Vector2, b: Vector2, t: float, n: int, half: float, s: int) -> void:
	var d := (b - a).normalized()
	var nn := Vector2(-d.y, d.x)
	for i in n:
		var m := a.lerp(b, t) - d * float(i) * 5.0
		ln(ci, m - nn * half - d * 2.0, m + nn * half + d * 2.0, 4.5, INK, s + i)
		ln(ci, m - nn * half - d * 2.0, m + nn * half + d * 2.0, 2.5, ROPE, s + i)

static func weave(ci: CanvasItem, r: Rect2, s: int, col: Color = Color(0.35, 0.18, 0.05, 0.55)) -> void:
	var y := r.position.y + 8.0
	while y < r.end.y:
		ln(ci, Vector2(r.position.x, y), Vector2(r.end.x, y), 1.6, col, s + int(y))
		y += 8.0
	var x := r.position.x + 6.0
	var k := 0
	while x < r.end.x - 2.0:
		var yy := r.position.y + (4.0 if k % 2 == 0 else 0.0)
		while yy < r.end.y - 3.0:
			ln(ci, Vector2(x, yy), Vector2(x, yy + 4.0), 1.8, col, s + k)
			yy += 8.0
		x += 8.0
		k += 1

## 带横纹的木头切面
static func rings(ci: CanvasItem, c: Vector2, r: Vector2, s: int, n: int = 3) -> void:
	for k in n:
		var f := 1.0 - (float(k) + 1.0) / (float(n) + 1.0)
		outline(ci, ell(c, r * f, s + k, 0.06, 16), 1.5, Color(WOOD_D, 0.8))

# ---------------------------------------------------------------- 宝石与石头

static func raw_rock(c: Vector2, r: float, s: int, col: Color, n: int = 7, jag: float = 0.25) -> Array:
	var arr := []
	for k in n:
		var a := TAU * float(k) / float(n) + srnd(s + k) * 0.4
		var m := 1.0 - jag + srnd(s * 7 + k) * jag * 2.0
		arr.append(c + Vector2(cos(a), sin(a) * 0.85) * r * m)
	return pg(arr, s, col)

## 刻面宝石（侧视）
static func cut_gem(ci: CanvasItem, c: Vector2, r: float, col: Color, s: int, rim: bool, extra: Array = []) -> void:
	var g := [c + Vector2(-r, -r * 0.18), c + Vector2(-r * 0.55, -r * 0.68), c + Vector2(r * 0.55, -r * 0.68),
		c + Vector2(r, -r * 0.18), c + Vector2(0, r * 0.92)]
	var parts := extra.duplicate()
	parts.append(pg(g, s, col, 1))
	sil(ci, parts, rim)
	var lc := Color(col.darkened(0.45), 0.8)
	ln(ci, g[0], g[3], 1.6, lc, s)
	for p in [c + Vector2(-r * 0.55, -r * 0.18), c + Vector2(0, -r * 0.18), c + Vector2(r * 0.55, -r * 0.18)]:
		ln(ci, p, g[4], 1.4, lc, s + 2)
	ln(ci, g[1], c + Vector2(-r * 0.25, -r * 0.18), 1.4, lc, s + 3)
	ln(ci, g[2], c + Vector2(r * 0.25, -r * 0.18), 1.4, lc, s + 4)
	ci.draw_colored_polygon(poly([g[1], c + Vector2(-r * 0.05, -r * 0.68), c + Vector2(-r * 0.3, -r * 0.18), g[0]], s), Color(1, 1, 1, 0.38))
	ci.draw_colored_polygon(poly([c + Vector2(-r * 0.55, -r * 0.18), c + Vector2(-r * 0.15, -r * 0.18), g[4]], s + 1), Color(1, 1, 1, 0.18))

## 六棱晶柱
static func crystal(c: Vector2, w: float, h: float, ang: float, s: int, col: Color) -> Array:
	var base := [Vector2(-w, 0), Vector2(-w, -h), Vector2(0, -h - w * 1.3), Vector2(w, -h), Vector2(w, 0)]
	return pg(rot_pts(base, ang, c), s, col, 1)

static func crystal_det(ci: CanvasItem, c: Vector2, w: float, h: float, ang: float, s: int, col: Color) -> void:
	var a := c + Vector2(0, 0).rotated(ang)
	var b := c + Vector2(0, -h).rotated(ang)
	var t := c + Vector2(0, -h - w * 1.3).rotated(ang)
	ln(ci, a, b, 1.4, Color(col.darkened(0.4), 0.7), s)
	ln(ci, b, t, 1.4, Color(col.darkened(0.4), 0.7), s + 1)
	ci.draw_colored_polygon(poly(rot_pts([Vector2(-w * 0.7, -2), Vector2(-w * 0.7, -h + 2), Vector2(-w * 0.2, -h - 1), Vector2(-w * 0.2, -2)], ang, c), s), Color(1, 1, 1, 0.3))

# ---------------------------------------------------------------- 猎物：侧躺的走兽

## 侧视、头朝左、侧躺：四条腿僵直地斜伸出去，叉叉眼，吐舌头。
## 整只自动下移到脚底贴近 y=34。o 里没写的键用下面 get 的默认值。
static func beast(ci: CanvasItem, s: int, rim: bool, o: Dictionary) -> void:
	var b: Vector2 = o.get("b", Vector2(24, 14))
	var col: Color = o.get("c", STONE)
	var c2: Color = o.get("c2", col.lightened(0.3))
	var hr: Vector2 = o.get("h", Vector2(b.y * 0.85, b.y * 0.75))
	var bc: Vector2 = o.get("bc", Vector2(6, 0))
	var hc: Vector2 = bc + (o.get("hp", Vector2(-b.x * 0.92, -b.y * 0.15)) as Vector2)
	var leg: float = o.get("leg", b.y * 0.9)
	var lw: float = o.get("lw", maxf(b.y * 0.2, 2.6))
	var lc: Color = o.get("lc", col.darkened(0.08))
	var hoof: Color = o.get("hoof", Color(0, 0, 0, 0))
	var sn: float = o.get("sn", hr.x * 0.5)
	var ear: String = o.get("ear", "round")
	var es: float = o.get("es", hr.y * 0.5)
	var tail: String = o.get("tail", "thin")
	var tl: float = o.get("tl", b.x * 0.8)
	var tc: Color = o.get("tc", col)
	var flags: Array = o.get("f", [])
	var top := bc.y + b.y * 0.35
	var ld := (o.get("ld", Vector2(0.62, 0.78)) as Vector2).normalized()
	var dy: float = o.get("dy", minf(34.0 - (top + leg * ld.y + lw), 36.0 - (bc.y + b.y)))

	set_xf(ci, Transform2D(0.0, Vector2.ONE, 0.0, Vector2(0, dy)))
	var parts := []
	var lx := [bc.x - b.x * 0.5, bc.x + b.x * 0.5]
	var dirs := [Vector2(-ld.x, ld.y), ld]
	# 远侧腿
	for i in 2:
		var a := Vector2(lx[i] + 5.0, top - 2.0)
		var d: Vector2 = (dirs[i] as Vector2).rotated(-0.25 if i == 0 else 0.25)
		parts.append(stk(a, a + d * leg, lw * 0.9, s + 20 + i, lc.darkened(0.2), 2))
	# 尾巴
	var tb := bc + Vector2(b.x * 0.9, -b.y * 0.1)
	match tail:
		"thin":
			parts.append(stk(tb, tb + Vector2(tl * 0.85, tl * 0.25), maxf(lw * 0.45, 1.6), s + 30, tc, 2))
		"bushy":
			parts.append(ov(tb + Vector2(tl * 0.45, tl * 0.1), tl * 0.55, tl * 0.24, s + 30, tc, 0.2, 1))
		"short":
			parts.append(circ(tb + Vector2(2, -2), maxf(tl * 0.2, 4.0), s + 30, tc, 1))
		"tuft":
			parts.append(stk(tb, tb + Vector2(tl * 0.7, tl * 0.5), 1.8, s + 30, tc, 2))
			parts.append(ov(tb + Vector2(tl * 0.75, tl * 0.6), 4, 6, s + 31, col.darkened(0.3), -0.6, 1))
		"long":
			parts.append(pg([tb + Vector2(0, -lw), tb + Vector2(tl, lw * 0.8), tb + Vector2(0, lw)], s + 30, tc, 1))
	# 身体
	if flags.has("spike"):
		var sp := []
		for k in 15:
			var a := lerpf(PI * 1.02, PI * 1.98, float(k) / 14.0)
			var r := 1.28 if k % 2 == 0 else 0.95
			sp.append(bc + Vector2(cos(a) * b.x * r, sin(a) * b.y * r * 1.1))
		sp.append(bc + Vector2(b.x, b.y * 0.2))
		sp.append(bc + Vector2(-b.x, b.y * 0.2))
		parts.append(pg(sp, s + 9, col.darkened(0.25), 1))
	if flags.has("fur"):
		var fp := []
		for k in 24:
			var a := TAU * float(k) / 24.0
			var r := 1.12 if (k % 2 == 1 and sin(a) > 0.2) else 1.0
			fp.append(bc + Vector2(cos(a) * b.x * r, sin(a) * b.y * r))
		parts.append(pg(fp, s + 2, col, 1))
	else:
		parts.append(ov(bc, b.x, b.y, s + 2, col, 0.0, 1))
	if flags.has("hump"):
		parts.append(ov(bc + Vector2(-b.x * 0.4, -b.y * 0.55), b.x * 0.48, b.y * 0.6, s + 3, col.darkened(0.15), 0.0, 1))
	if flags.has("mane"):
		parts.append(ov(hc + Vector2(hr.x * 0.95, -hr.y * 0.05), hr.x * 0.55, hr.y * 1.15, s + 66, col.darkened(0.22), 0.25, 1))
	# 近侧腿
	for i in 2:
		var a := Vector2(lx[i], top)
		var foot: Vector2 = a + (dirs[i] as Vector2) * leg
		parts.append(stk(a, foot, lw, s + 22 + i, lc, 2))
		if hoof.a > 0.0:
			parts.append(stk(foot - (dirs[i] as Vector2) * lw * 0.9, foot, lw * 1.08, s + 24 + i, hoof, 2))
	# 头
	if ear == "round":
		parts.append(circ(hc + Vector2(hr.x * 0.4, -hr.y * 0.8), es, s + 50, col.darkened(0.06), 1))
	elif ear == "pt":
		var e0 := hc + Vector2(hr.x * 0.2, -hr.y * 0.55)
		parts.append(pg([e0 + Vector2(-es * 0.5, 0), e0 + Vector2(es * 0.35, -es * 1.5), e0 + Vector2(es * 0.9, 0)], s + 50, col.darkened(0.06)))
	elif ear == "long":
		parts.append(ov(hc + Vector2(hr.x * 0.8 + es * 0.8, -hr.y * 0.3), es * 1.05, es * 0.34, s + 50, col.darkened(0.05), 0.15, 1))
		parts.append(ov(hc + Vector2(hr.x * 0.7 + es * 0.75, -hr.y * 0.75), es * 1.05, es * 0.34, s + 51, col, -0.3, 1))
	elif ear == "flap":
		parts.append(ov(hc + Vector2(hr.x * 0.6, hr.y * 0.1), es * 0.8, es, s + 50, col.darkened(0.1), 0.2, 1))
	if flags.has("trunk"):
		var t0 := hc + Vector2(-hr.x * 0.75, hr.y * 0.2)
		var tr := [t0, t0 + Vector2(-8, 12), t0 + Vector2(-10, 24), t0 + Vector2(-4, 32)]
		for i in 3:
			parts.append(stk(tr[i], tr[i + 1], 6.5 - float(i) * 1.3, s + 40 + i, col.darkened(0.04), 2))
	parts.append(ov(hc, hr.x, hr.y, s + 4, col, 0.0, 1))
	if sn > 0.0:
		parts.append(ov(hc + Vector2(-hr.x * 0.85, hr.y * 0.3), sn, hr.y * 0.52, s + 5, c2, 0.0, 1))
	if flags.has("tusk"):
		var t0 := hc + Vector2(-hr.x * 0.95, hr.y * 0.45)
		parts.append(pg([t0 + Vector2(3, 0), t0 + Vector2(-4, -10), t0 + Vector2(-2, 1)], s + 60, BONE))
	if flags.has("bigtusk"):
		var t0 := hc + Vector2(-hr.x * 0.3, hr.y * 0.75)
		parts.append(band(t0 + Vector2(-16, -10), 18, 3.6, PI * 0.15, PI * 1.05, s + 60, BONE))
	if flags.has("rhino"):
		var n0 := hc + Vector2(-hr.x * 1.25, -hr.y * 0.05)
		parts.append(pg([n0 + Vector2(-4, 2), n0 + Vector2(-10, -24), n0 + Vector2(8, 0)], s + 61, BONE2))
		parts.append(pg([n0 + Vector2(9, -3), n0 + Vector2(10, -15), n0 + Vector2(17, -5)], s + 62, BONE2))
	if flags.has("goat"):
		parts.append(band(hc + Vector2(12, 0), 12, 2.8, PI * 1.05, PI * 1.85, s + 63, BONE2.darkened(0.1)))
		parts.append(pg([hc + Vector2(-hr.x * 0.95, hr.y * 0.7), hc + Vector2(-hr.x * 0.7, hr.y * 1.8), hc + Vector2(-hr.x * 0.35, hr.y * 0.65)], s + 64, c2))
	if flags.has("bison"):
		parts.append(band(hc + Vector2(4, -2), 10, 2.6, PI * 1.1, PI * 1.6, s + 63, BONE2))
	if flags.has("antler"):
		var a0 := hc + Vector2(hr.x * 0.25, -hr.y * 0.7)
		var ac := BONE2.darkened(0.12)
		parts.append(stk(a0, a0 + Vector2(10, -22), 2.3, s + 70, ac, 2))
		parts.append(stk(a0 + Vector2(4, -9), a0 + Vector2(-6, -18), 2.0, s + 71, ac, 2))
		parts.append(stk(a0 + Vector2(8, -17), a0 + Vector2(20, -24), 2.0, s + 72, ac, 2))
		parts.append(stk(a0 + Vector2(10, -22), a0 + Vector2(6, -33), 2.0, s + 73, ac, 2))
	if flags.has("fang"):
		var f0 := hc + Vector2(-hr.x * 0.95, hr.y * 0.6)
		parts.append(pg([f0 + Vector2(-1, 0), f0 + Vector2(0, 13), f0 + Vector2(5, 0)], s + 65, BONE))
	sil(ci, parts, rim)
	# 花纹
	if flags.has("stripe"):
		for k in 4:
			var x := bc.x - b.x * 0.45 + float(k) * b.x * 0.3
			ci.draw_colored_polygon(poly([Vector2(x - 3.5, bc.y - b.y * 0.95), Vector2(x + 3.5, bc.y - b.y * 0.95), Vector2(x + 1, bc.y - b.y * 0.15)], s + k), FUR_D)
	if flags.has("spots"):
		for k in 4:
			var p := bc + Vector2((srnd(s + k) - 0.5) * b.x * 1.1, (srnd(s + k + 9) - 0.7) * b.y * 0.9)
			ci.draw_circle(p, 3.0, Color(col.darkened(0.35), 0.8))
	if flags.has("whitespots"):
		for k in 5:
			var p := bc + Vector2((srnd(s + k) - 0.5) * b.x * 1.2, (srnd(s + k + 9) - 0.75) * b.y * 0.8)
			ci.draw_circle(p, 2.4, Color(BONE, 0.9))
	if flags.has("badger"):
		ci.draw_colored_polygon(ell(hc + Vector2(-2, -2), Vector2(hr.x * 0.95, hr.y * 0.26), s, 0.0, 14), BONE)
	if flags.has("furline"):
		for k in 6:
			var x := bc.x - b.x * 0.7 + float(k) * b.x * 0.28
			ln(ci, Vector2(x, bc.y - b.y * 0.2), Vector2(x - 2, bc.y + b.y * 0.55), 1.8, Color(col.darkened(0.4), 0.6), s + k)
	ci.draw_colored_polygon(ell(bc + Vector2(-b.x * 0.05, b.y * 0.45), Vector2(b.x * 0.6, b.y * 0.32), s + 7, 0.0, 16), Color(c2, 0.5))
	if sn > 0.0:
		ci.draw_circle(hc + Vector2(-hr.x * 0.85 - sn * 0.75, hr.y * 0.15), maxf(sn * 0.2, 1.8), INK)
	xeye(ci, hc + Vector2(-hr.x * 0.25, -hr.y * 0.2), maxf(hr.y * 0.17, 2.6))
	if not flags.has("notongue"):
		var m := hc + Vector2(-hr.x * 0.7 - sn * 0.5, hr.y * 0.62)
		var tg := ell(m + Vector2(0, 5), Vector2(3.0, 5.0), s, 0.0, 10, 0.25)
		ci.draw_colored_polygon(tg, PINK)
		outline(ci, tg, 1.5)
	hl(ci, bc + Vector2(-b.x * 0.25, -b.y * 0.5), b.x * 0.22, b.y * 0.12, -0.2, 0.35)
	reset_xf(ci)

# ---------------------------------------------------------------- 猎物：侧躺的飞禽

static func bird(ci: CanvasItem, s: int, rim: bool, o: Dictionary) -> void:
	var b: Vector2 = o.get("b", Vector2(16, 11))
	var col: Color = o.get("c", WOOD)
	var c2: Color = o.get("c2", col.lightened(0.35))
	var wc: Color = o.get("wc", col.darkened(0.15))
	var hr: float = o.get("hr", b.y * 0.75)
	var bc: Vector2 = o.get("bc", Vector2(6, 0))
	var neck: float = o.get("neck", 0.0)
	var hc: Vector2 = bc + Vector2(-b.x * 0.95 - neck, b.y * 0.35 - neck * 0.1)
	if neck <= 0.0:
		hc = bc + Vector2(-b.x * 0.95, -b.y * 0.2)
	var hcol: Color = o.get("hc", col)
	var beak: String = o.get("beak", "short")
	var bk: Color = o.get("bk", OCHRE)
	var tail: String = o.get("tail", "fan")
	var tl: float = o.get("tl", b.x * 0.7)
	var tcol: Color = o.get("tc", wc)
	var leg: float = o.get("leg", b.y * 0.9)
	var flags: Array = o.get("f", [])
	var left := hc.x - hr * 2.0
	var right := bc.x + b.x * 0.8 + tl
	var sc: float = o.get("sc", minf(1.45, 86.0 / (right - left)))
	var dy: float = o.get("dy", minf(30.0 - sc * b.y, 34.0 - sc * (hc.y + hr)))
	var dx := -(left + right) * 0.5 * sc
	set_xf(ci, Transform2D(0.0, Vector2.ONE * sc, 0.0, Vector2(dx, dy)))

	var parts := []
	# 张开的远侧翅膀
	var wspan: float = o.get("wing", b.x * 1.1)
	parts.append(pg([bc + Vector2(-b.x * 0.3, -b.y * 0.5), bc + Vector2(b.x * 0.2, -b.y * 0.6 - wspan * 0.55), bc + Vector2(b.x * 0.55, -b.y * 0.5 - wspan * 0.6),
		bc + Vector2(b.x * 0.75, -b.y * 0.4)], s + 8, wc.darkened(0.12)))
	var tb := bc + Vector2(b.x * 0.8, -b.y * 0.05)
	match tail:
		"fan":
			parts.append(pg([tb + Vector2(0, -5), tb + Vector2(tl, -tl * 0.3), tb + Vector2(tl * 1.05, tl * 0.3), tb + Vector2(0, 5)], s + 30, tcol))
		"long":
			parts.append(pg([tb + Vector2(0, -4), tb + Vector2(tl, -tl * 0.18), tb + Vector2(tl * 0.95, tl * 0.02), tb + Vector2(0, 5)], s + 30, tcol))
		"short":
			parts.append(pg([tb + Vector2(0, -4), tb + Vector2(tl * 0.55, 0), tb + Vector2(0, 5)], s + 30, tcol))
	if neck > 0.0:
		parts.append(stk(bc + Vector2(-b.x * 0.6, 0), hc, hr * 0.6, s + 31, o.get("nc", col), 2))
	parts.append(ov(bc, b.x, b.y, s + 2, col, 0.0, 1))
	if flags.has("ruff"):
		parts.append(ov(bc + Vector2(-b.x * 0.75, -b.y * 0.2), hr * 0.9, hr * 1.05, s + 33, BONE2, 0.0, 1))
	parts.append(circ(hc, hr, s + 4, hcol, 1))
	match beak:
		"short":
			parts.append(pg([hc + Vector2(-hr * 0.8, -hr * 0.3), hc + Vector2(-hr * 1.65, hr * 0.05), hc + Vector2(-hr * 0.8, hr * 0.35)], s + 5, bk))
		"long":
			parts.append(pg([hc + Vector2(-hr * 0.8, -hr * 0.25), hc + Vector2(-hr * 2.3, hr * 0.15), hc + Vector2(-hr * 0.8, hr * 0.4)], s + 5, bk))
		"duck":
			parts.append(ov(hc + Vector2(-hr * 1.3, hr * 0.15), hr * 0.75, hr * 0.32, s + 5, bk, 0.0, 1))
		"hook":
			parts.append(pg([hc + Vector2(-hr * 0.7, -hr * 0.45), hc + Vector2(-hr * 1.6, -hr * 0.15), hc + Vector2(-hr * 1.5, hr * 0.6), hc + Vector2(-hr * 1.2, hr * 0.2), hc + Vector2(-hr * 0.7, hr * 0.35)], s + 5, bk))
	if flags.has("tufts"):
		parts.append(pg([hc + Vector2(-hr * 0.7, -hr * 0.55), hc + Vector2(-hr * 0.8, -hr * 1.45), hc + Vector2(-hr * 0.15, -hr * 0.85)], s + 6, col.darkened(0.15)))
		parts.append(pg([hc + Vector2(hr * 0.7, -hr * 0.55), hc + Vector2(hr * 0.8, -hr * 1.45), hc + Vector2(hr * 0.15, -hr * 0.85)], s + 7, col.darkened(0.15)))
	if flags.has("crest"):
		parts.append(pg([hc + Vector2(0, -hr * 0.8), hc + Vector2(hr * 0.9, -hr * 1.6), hc + Vector2(hr * 0.8, -hr * 0.4)], s + 6, BERRY))
	if flags.has("wattle"):
		parts.append(ov(hc + Vector2(-hr * 0.15, 0), hr * 0.5, hr * 0.42, s + 8, BERRY, 0.0, 2))
	# 近侧翅膀
	parts.append(pg([bc + Vector2(-b.x * 0.45, -b.y * 0.2), bc + Vector2(b.x * 0.15, -b.y * 0.55), bc + Vector2(b.x * 0.95, b.y * 0.05), bc + Vector2(b.x * 0.1, b.y * 0.55)], s + 9, wc))
	# 腿：僵直地斜伸出去
	var lcol: Color = o.get("lc", OCHRE)
	for i in 2:
		var a := bc + Vector2(-2.0 + float(i) * 7.0, b.y * 0.6)
		var d := Vector2(0.55 + float(i) * 0.25, 0.8).normalized()
		var ft := a + d * leg
		parts.append(stk(a, ft, 1.6, s + 40 + i, lcol, 2))
	sil(ci, parts, rim)
	for i in 2:
		var a := bc + Vector2(-2.0 + float(i) * 7.0, b.y * 0.6)
		var d := Vector2(0.55 + float(i) * 0.25, 0.8).normalized()
		var ft := a + d * leg
		for t in 3:
			ln(ci, ft, ft + d.rotated(-0.8 + float(t) * 0.8) * 5.0, 1.8, INK, s + t)
	if flags.has("chest"):
		ci.draw_colored_polygon(ell(bc + Vector2(-b.x * 0.4, b.y * 0.25), Vector2(b.x * 0.48, b.y * 0.5), s + 3, 0.0, 14), o.get("cc", c2))
	else:
		ci.draw_colored_polygon(ell(bc + Vector2(-b.x * 0.1, b.y * 0.5), Vector2(b.x * 0.6, b.y * 0.33), s + 3, 0.0, 14), Color(c2, 0.6))
	for k in 3:
		ln(ci, bc + Vector2(b.x * 0.05 + float(k) * b.x * 0.22, -b.y * 0.25), bc + Vector2(b.x * 0.35 + float(k) * b.x * 0.2, b.y * 0.25), 1.4, Color(INK, 0.4), s + k)
	if flags.has("face"):
		ci.draw_colored_polygon(ell(hc + Vector2(-hr * 0.2, 0), Vector2(hr * 0.72, hr * 0.8), s, 0.0, 14), BONE2)
	if flags.has("spot"):
		for k in 4:
			ci.draw_circle(bc + Vector2(-b.x * 0.4 + float(k) * b.x * 0.28, -b.y * 0.2 + b.y * 0.25 * float(k % 2)), 1.8, Color(INK, 0.45))
	xeye(ci, hc + Vector2(-hr * 0.2, -hr * 0.15), maxf(hr * 0.28, 2.4), 2.0)
	hl(ci, bc + Vector2(-b.x * 0.3, -b.y * 0.45), b.x * 0.2, b.y * 0.12, -0.3, 0.35)
	reset_xf(ci)
