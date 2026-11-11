class_name Art
extends RefCounted
## 「石纹手作」绘图核心：线条沸腾 + 贴纸描边 + 双色块面。
## 物品图标统一在 100×100 的局部坐标里绘制（中心为原点）。

const INK := Color("3b2314")
## 货币入口用二级完整单件图标；棋盘实物按自己的等级显示数量。
const AMBER_ICON := "amber_2"
const HIDE := Color("f6e7c8")
const HIDE2 := Color("ead3a6")
const LEATHER := Color("a7622c")
const LEATHER_D := Color("6e3b17")
const OCHRE := Color("eaa53c")
const CLAY := Color("d2512d")
const MOSS := Color("8cc63f")
const MOSS_D := Color("4f7a1f")
const TEAL := Color("4fa39a")
const BONE := Color("fff7e6")
const BONE2 := Color("f1e2c0")
const STONE := Color("a7a197")
const STONE_D := Color("6f6a63")
const WOOD := Color("b97a3f")
const WOOD_D := Color("7a4a22")
const ROPE := Color("e6c98a")
const BERRY := Color("d8324a")
const LEAF := Color("72b23c")
const LEAF_D := Color("4b8227")
const SEED := Color("b07a3e")
const MEAT := Color("e8766a")
const ROAST := Color("c0682b")
const FIRE := Color("ff7b22")
const FIRE2 := Color("ffd23f")
## 双倍火种模式下生产器右下角的紫火
const FIRE_BOOST := Color("b45cff")
const SHELL := Color("f8d9bc")
const SHELL_D := Color("e7a98a")
const AMBER := Color("f39a1f")
const SKIN := Color("c98a5a")
const FISH := Color("6fb0c8")

static var boil: int = 0
## 线条抖动倍率。生成图片时由配置里的幅度写入，平时为 1。
static var wobble := 1.0

# ---------------------------------------------------------------- 随机与抖动

static func srnd(i: int) -> float:
	var v := sin(float(i) * 12.9898 + 4.1414) * 43758.5453
	return v - floor(v)

static func jit(i: int) -> float:
	var v := sin(float(i) * 78.233 + float(boil) * 37.719 + 1.7) * 43758.5453
	return ((v - floor(v)) * 2.0 - 1.0) * wobble

static func jv(i: int, amp: float) -> Vector2:
	return Vector2(jit(i), jit(i + 911)) * amp

# ---------------------------------------------------------------- 形状

static func ell(c: Vector2, r: Vector2, seed: int = 0, wob: float = 0.04, n: int = 20, rot: float = 0.0, amp: float = 0.9) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in n:
		var a := TAU * float(k) / float(n)
		var m := 1.0 + (srnd(seed * 31 + k) - 0.5) * 2.0 * wob
		var p := Vector2(cos(a) * r.x, sin(a) * r.y) * m
		pts.append(c + p.rotated(rot) + jv(seed * 13 + k, amp))
	return pts

static func poly(arr: Array, seed: int = 0, amp: float = 0.9) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var k := 0
	for p in arr:
		pts.append(p + jv(seed * 13 + k, amp))
		k += 1
	return pts

static func rot_pts(arr: Array, ang: float, off: Vector2 = Vector2.ZERO) -> Array:
	var out := []
	for p in arr:
		out.append((p as Vector2).rotated(ang) + off)
	return out

static func capsule(a: Vector2, b: Vector2, r: float, seed: int = 0) -> PackedVector2Array:
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x)
	var ang := n.angle()
	var pts := []
	for k in 7:
		var t := ang - PI * float(k) / 6.0
		pts.append(b + Vector2(cos(t), sin(t)) * r)
	for k in 7:
		var t := ang + PI - PI * float(k) / 6.0
		pts.append(a + Vector2(cos(t), sin(t)) * r)
	return poly(pts, seed, 0.6)

static func rrect(r: Rect2, rad: float, seed: int = 0, amp: float = 0.9, step: float = 46.0) -> PackedVector2Array:
	rad = min(rad, min(r.size.x, r.size.y) * 0.5)
	var cs := [r.position + Vector2(r.size.x - rad, rad), r.position + Vector2(r.size.x - rad, r.size.y - rad),
		r.position + Vector2(rad, r.size.y - rad), r.position + Vector2(rad, rad)]
	var base := []
	for ci in 4:
		var c: Vector2 = cs[ci]
		for s in 6:
			var a := -PI * 0.5 + PI * 0.5 * float(ci) + PI * 0.5 * float(s) / 5.0
			var q := c + Vector2(cos(a), sin(a)) * rad
			if base.is_empty() or (base[base.size() - 1] as Vector2).distance_to(q) > 0.75:
				base.append(q)
	if base.size() > 2 and (base[0] as Vector2).distance_to(base[base.size() - 1]) <= 0.75:
		base.pop_back()
	var out := PackedVector2Array()
	var n := base.size()
	var k := 0
	for i in n:
		var a: Vector2 = base[i]
		var b: Vector2 = base[(i + 1) % n]
		out.append(a + jv(seed * 13 + k, amp))
		k += 1
		var d := a.distance_to(b)
		if d > step:
			var m := int(d / step)
			for j in range(1, m + 1):
				out.append(a.lerp(b, float(j) / float(m + 1)) + jv(seed * 13 + k, amp))
				k += 1
	return out

static func flame_pts(c: Vector2, w: float, h: float, seed: int = 0, n: int = 26) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in n:
		var t := TAU * float(k) / float(n)
		var sh := pow(absf(sin(t * 0.5)), 1.6)
		var st := sin(t)
		var xa := w * absf(st) * sh * (1.0 + 0.16 * sin(t * 3.0 + float(boil) * 1.9 + float(seed)))
		var x := signf(st) * xa
		var y := -h * 0.5 * cos(t) + jit(seed * 13 + k) * 0.8 * sh
		pts.append(c + Vector2(x, y))
	return pts

static func star_pts(c: Vector2, r1: float, r2: float, n: int, seed: int = 0, rot: float = -PI * 0.5) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in n * 2:
		var a := rot + PI * float(k) / float(n)
		var r := r1 if k % 2 == 0 else r2
		pts.append(c + Vector2(cos(a), sin(a)) * r + jv(seed * 13 + k, 0.6))
	return pts

static func bolt_pts(c: Vector2, w: float, h: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for p in [Vector2(0.22, -0.5), Vector2(-0.5, 0.06), Vector2(-0.05, 0.03), Vector2(-0.24, 0.5), Vector2(0.5, -0.12), Vector2(0.06, -0.08), Vector2(0.37, -0.5)]:
		pts.append(c + p * Vector2(w, h))
	return pts

static func bbox(pts: PackedVector2Array) -> Rect2:
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	return r

# ---------------------------------------------------------------- 描边与填充

static func outline(ci: CanvasItem, pts: PackedVector2Array, w: float = 3.0, col: Color = INK) -> void:
	var c := pts.duplicate()
	c.append(pts[0])
	ci.draw_polyline(c, col, w, true)

static func fill(ci: CanvasItem, pts: PackedVector2Array, col: Color, w: float = 3.0, line: Color = INK) -> void:
	ci.draw_colored_polygon(pts, col)
	if w > 0.0:
		outline(ci, pts, w, line)

static func dilate(ci: CanvasItem, pts: PackedVector2Array, d: float, col: Color) -> void:
	for o in Geometry2D.offset_polygon(pts, d, Geometry2D.JOIN_ROUND):
		ci.draw_colored_polygon(o, col)

static func shade(ci: CanvasItem, pts: PackedVector2Array, col: Color, mode: int = 0) -> void:
	if mode == 2:
		ci.draw_colored_polygon(pts, col)
		return
	ci.draw_colored_polygon(pts, col.darkened(0.22))
	var bb := bbox(pts)
	var inset: float = min(bb.size.x, bb.size.y) * 0.1
	var off := Vector2(-bb.size.x, -bb.size.y) * 0.04
	for o in Geometry2D.offset_polygon(pts, -inset, Geometry2D.JOIN_ROUND):
		var moved := PackedVector2Array()
		for p in o:
			moved.append(p + off)
		ci.draw_colored_polygon(moved, col)
	if mode == 0:
		var cen := bb.get_center()
		var hl := ell(cen + Vector2(-bb.size.x * 0.2, -bb.size.y * 0.24), Vector2(bb.size.x * 0.12, bb.size.y * 0.07), 3, 0.0, 10, -0.5, 0.3)
		ci.draw_colored_polygon(hl, Color(1, 1, 1, 0.5))

static func P(pts: PackedVector2Array, col: Color, mode: int = 0) -> Array:
	return [pts, col, mode]

## 贴纸剪影：奶白外边 → 墨线外轮廓 → 双色填充 → 细内线
static func sil(ci: CanvasItem, parts: Array, rim: bool = true, w: float = 3.0) -> void:
	if rim:
		for p in parts:
			dilate(ci, p[0], w + 6.0, Color(1, 0.98, 0.92, 0.96))
	for p in parts:
		dilate(ci, p[0], w, INK)
	for p in parts:
		shade(ci, p[0], p[1], p[2])
		outline(ci, p[0], 2.2, INK)

static func ln(ci: CanvasItem, a: Vector2, b: Vector2, w: float = 2.5, col: Color = INK, seed: int = 0) -> void:
	ci.draw_line(a + jv(seed, 0.6), b + jv(seed + 5, 0.6), col, w, true)

static func pl(ci: CanvasItem, arr: Array, w: float = 2.5, col: Color = INK, seed: int = 0) -> void:
	ci.draw_polyline(poly(arr, seed, 0.6), col, w, true)

static func dot(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(c, r, col)

static func dashed(ci: CanvasItem, pts: PackedVector2Array, dash: float, gap: float, col: Color, w: float = 2.0) -> void:
	var n := pts.size()
	var carry := 0.0
	var on := true
	for i in n:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % n]
		var seg := a.distance_to(b)
		var pos := 0.0
		while pos < seg:
			var lim := (dash if on else gap) - carry
			var e: float = min(seg, pos + lim)
			if on:
				ci.draw_line(a.lerp(b, pos / seg), a.lerp(b, e / seg), col, w, true)
			if pos + lim <= seg:
				on = not on
				carry = 0.0
			else:
				carry += e - pos
			pos = e

# ---------------------------------------------------------------- 物品图标

## 游戏运行时画物品：只贴预生成的 PNG（见「物品绘制.md」），没有图就空着，绝不现场绘制。
static func vector_item(id: String) -> String:
	if Data.chain(id) in ["orderbox", "premiumbox", "energybox", "chest", "choice", "fire", "shell", "amber", "sand", "upgrade", "scissors"] or (Data.chain(id) == "pack" and Data.lv(id) > 1):
		return "res://assets/ui/items/%s.svg" % id
	return ""

static func _vector_item(ci: CanvasItem, id: String, c: Vector2, size: float, rot: float) -> bool:
	var path := vector_item(id)
	if path == "": return false
	ci.draw_set_transform(c, rot, Vector2.ONE)
	ci.draw_texture_rect(MergeEventArt.texture(path), Rect2(-size / 2, -size / 2, size, size), false)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true

static func item(ci: CanvasItem, id: String, c: Vector2, size: float, rim: bool = true, rot: float = 0.0) -> void:
	if id == "":
		return
	if _vector_item(ci, id, c, size, rot): return
	Items.blit(ci, id, c, size, rim, rot)

## 用原始绘制代码现场画物品。只给生成 PNG 的工具和开发预览用，游戏里不要调用。
static func draw_item(ci: CanvasItem, id: String, c: Vector2, size: float, rim: bool = true, rot: float = 0.0) -> void:
	if id == "":
		return
	if _vector_item(ci, id, c, size, rot): return
	if Data.is_dish(id):
		_paint_dish(ci, id, c, size, rim, rot)
		return
	if Data.chain(id) == "sand":
		ci.draw_set_transform(c, rot, Vector2.ONE * (size / 100.0))
		var sand_s: int = absi(id.hash()) % 97
		_sand(ci, Data.lv(id), sand_s, rim)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	if Data.chain(id) == "emberpot":
		ci.draw_set_transform(c, rot, Vector2.ONE * (size / 100.0))
		_emberpot(ci, 41, rim)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var ch := id.get_slice("_", 0)
	var lv := int(id.get_slice("_", 1))
	var def: Dictionary = Data.CHAINS.get(ch, {})
	if def.has("line"):
		var role := Data.draw_role(ch)
		if role != "":
			ProdArt.draw(ci, def["line"], role, lv, c, size, rim)
			return
	ci.draw_set_transform(c, rot, Vector2.ONE * (size / 100.0))
	ci.draw_colored_polygon(ell(Vector2(0, 40), Vector2(30, 6), 1, 0.0, 14, 0.0, 0.0), Color(0.2, 0.1, 0.0, 0.18))
	var s: int = abs(ch.hash()) % 97 + lv * 7
	match ch:
		"fire": _fire(ci, lv, s, rim)
		"shell": _shell(ci, lv, s, rim)
		"amber": _amber(ci, lv, s, rim)
		"chest": _chest(ci, s, rim)
		"pack": _pack(ci, s, rim)
		"token": _token(ci, s, rim)
		"xp": _xp(ci, s, rim)
		_:
			sil(ci, [P(ell(Vector2.ZERO, Vector2(30, 30), s), STONE)], rim)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## 祭典鼓：活动积分
static func _token(ci: CanvasItem, s: int, rim: bool) -> void:
	var body := poly([Vector2(-30, -16), Vector2(30, -16), Vector2(24, 30), Vector2(-24, 30)], s, 0.6)
	var head := ell(Vector2(0, -16), Vector2(31, 11), s + 1, 0.03, 18)
	sil(ci, [P(body, CLAY, 1), P(head, BONE, 0),
		P(capsule(Vector2(16, -50), Vector2(4, -24), 3.0, s + 2), WOOD, 1),
		P(ell(Vector2(17, -52), Vector2(7, 7), s + 3, 0.04, 10), OCHRE)], rim)
	for k in 5:
		var x := -22.0 + k * 11.0
		ln(ci, Vector2(x, -6), Vector2(x * 0.82 + (3.0 if k % 2 == 0 else -3.0), 28), 2.0, ROPE, s + k)
	pl(ci, [Vector2(-28, 4), Vector2(0, 8), Vector2(27, 4)], 3.0, OCHRE, s + 6)
	for k in 3:
		ci.draw_colored_polygon(poly([Vector2(-16 + k * 16, 12), Vector2(-10 + k * 16, 12), Vector2(-13 + k * 16, 20)], s + k), TEAL)
	ci.draw_colored_polygon(ell(Vector2(-8, -19), Vector2(10, 3), s + 9, 0.0, 10), Color(1, 1, 1, 0.5))

## 声望星：主角经验
static func _xp(ci: CanvasItem, s: int, rim: bool) -> void:
	var st := star_pts(Vector2(0, 2), 40, 19, 5, s)
	sil(ci, [P(st, OCHRE, 1)], rim)
	ci.draw_colored_polygon(star_pts(Vector2(0, 2), 22, 11, 5, s + 1), Color("ffe27a"))
	ci.draw_circle(Vector2(-7, -6), 3.0, INK)
	ci.draw_circle(Vector2(7, -6), 3.0, INK)
	ci.draw_arc(Vector2(0, 2), 6.0, 0.3, PI - 0.3, 8, INK, 2.4, true)
	ci.draw_colored_polygon(ell(Vector2(-14, -16), Vector2(6, 3), s + 2, 0.0, 8, -0.6), Color(1, 1, 1, 0.6))

static func _weave(ci: CanvasItem, r: Rect2, s: int) -> void:
	var col := Color(0.35, 0.18, 0.05, 0.55)
	var y := r.position.y + 9.0
	while y < r.end.y:
		var shrink := (y - r.position.y) / r.size.y * 7.0
		ln(ci, Vector2(r.position.x + shrink, y), Vector2(r.end.x - shrink, y), 1.8, col, s + int(y))
		y += 9.0
	var x := r.position.x + 8.0
	var k := 0
	while x < r.end.x - 4.0:
		var off := 4.5 if k % 2 == 0 else 0.0
		var yy := r.position.y + off
		while yy < r.end.y - 4.0:
			ln(ci, Vector2(x, yy), Vector2(x, yy + 4.5), 2.0, col, s + k)
			yy += 9.0
		x += 9.0
		k += 1

static func _rope(ci: CanvasItem, a: Vector2, b: Vector2, t: float, n: int, half: float, s: int) -> void:
	var d := (b - a).normalized()
	var nn := Vector2(-d.y, d.x)
	for i in n:
		var m := a.lerp(b, t) - d * float(i) * 5.0
		ln(ci, m - nn * half - d * 2.0, m + nn * half + d * 2.0, 4.5, INK, s + i)
		ln(ci, m - nn * half - d * 2.0, m + nn * half + d * 2.0, 2.5, ROPE, s + i)

static func _basket_body(c: Vector2, w: float, h: float, s: int, col: Color = WOOD) -> Array:
	return [P(poly([c + Vector2(-w, 0), c + Vector2(w, 0), c + Vector2(w * 0.76, h), c + Vector2(-w * 0.76, h)], s), col, 1),
		P(capsule(c + Vector2(-w - 2, 0), c + Vector2(w + 2, 0), 5.5, s + 1), col.lightened(0.15), 1)]

static func _scallop(c: Vector2, sz: float, rot: float, s: int) -> PackedVector2Array:
	var arr := []
	var hinge := Vector2(0, sz * 0.75)
	arr.append(hinge + Vector2(-sz * 0.25, 0))
	for k in 21:
		var a := lerpf(-PI * 0.86, -PI * 0.14, float(k) / 20.0)
		var bump := 1.0 + 0.06 * absf(sin(float(k) * PI / 4.0 * 1.0))
		arr.append(hinge + Vector2(cos(a), sin(a)) * sz * 1.25 * bump)
	arr.append(hinge + Vector2(sz * 0.25, 0))
	arr.append(hinge + Vector2(sz * 0.18, sz * 0.18))
	arr.append(hinge + Vector2(-sz * 0.18, sz * 0.18))
	return poly(rot_pts(arr, rot, c - Vector2(0, sz * 0.1)), s, 0.5)

static func _scallop_det(ci: CanvasItem, c: Vector2, sz: float, rot: float, s: int) -> void:
	var hinge := c - Vector2(0, sz * 0.1) + Vector2(0, sz * 0.75).rotated(rot)
	for k in 5:
		var a := lerpf(-PI * 0.78, -PI * 0.22, float(k) / 4.0) + rot
		ln(ci, hinge, hinge + Vector2(cos(a), sin(a)) * sz * 1.1, 1.6, SHELL_D.darkened(0.25), s + k)

## 火种 6 级：火星 → 火苗 → 小火堆 → 篝火 → 熊熊大火 → 圣火
static func _fire(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			sil(ci, [P(star_pts(Vector2(0, 2), 30, 11, 4, s), FIRE2, 1)], rim)
			ci.draw_colored_polygon(star_pts(Vector2(0, 2), 14, 6, 4, s + 2), Color(1, 1, 0.85))
			for i in 3:
				ci.draw_circle(Vector2(-24 + 22 * i, -26 + 10 * (i % 2)), 3.0, FIRE)
		2:
			sil(ci, [P(flame_pts(Vector2(0, 0), 30, 84, s), FIRE, 1)], rim)
			ci.draw_colored_polygon(flame_pts(Vector2(0, 14), 16, 48, s + 3), FIRE2)
			ci.draw_colored_polygon(flame_pts(Vector2(0, 22), 7, 22, s + 5), Color(1, 1, 0.85))
		3:
			sil(ci, [P(flame_pts(Vector2(0, -6), 26, 70, s), FIRE, 1),
				P(capsule(Vector2(-28, 34), Vector2(22, 20), 5.0, s + 1), WOOD, 1),
				P(capsule(Vector2(28, 34), Vector2(-22, 20), 5.0, s + 2), WOOD_D, 1)], rim)
			ci.draw_colored_polygon(flame_pts(Vector2(0, 6), 14, 40, s + 3), FIRE2)
			ci.draw_colored_polygon(flame_pts(Vector2(0, 14), 6, 18, s + 5), Color(1, 1, 0.85))
		4:
			var parts := [P(flame_pts(Vector2(0, -10), 30, 80, s), FIRE, 1),
				P(capsule(Vector2(-36, 32), Vector2(30, 14), 7.0, s + 1), WOOD, 1),
				P(capsule(Vector2(36, 32), Vector2(-30, 14), 7.0, s + 2), WOOD.darkened(0.08), 1)]
			for i in 5:
				parts.append(P(ell(Vector2(-36 + 18 * i, 38), Vector2(9, 6), s + 3 + i, 0.1), STONE))
			sil(ci, parts, rim)
			ci.draw_colored_polygon(flame_pts(Vector2(0, 2), 16, 46, s + 3), FIRE2)
			ci.draw_colored_polygon(flame_pts(Vector2(0, 12), 7, 20, s + 5), Color(1, 1, 0.85))
		5:
			var parts := [P(flame_pts(Vector2(-22, -2), 18, 56, s + 9), FIRE, 1), P(flame_pts(Vector2(22, -2), 18, 56, s + 10), FIRE, 1),
				P(flame_pts(Vector2(0, -16), 30, 92, s), FIRE, 1),
				P(capsule(Vector2(-40, 34), Vector2(8, -6), 6.5, s + 1), WOOD, 1),
				P(capsule(Vector2(40, 34), Vector2(-8, -6), 6.5, s + 2), WOOD_D, 1),
				P(capsule(Vector2(-42, 32), Vector2(42, 32), 7.0, s + 11), WOOD.darkened(0.05), 1)]
			for i in 6:
				parts.append(P(ell(Vector2(-42 + 16.8 * i, 42), Vector2(9, 6), s + 3 + i, 0.1), STONE))
			sil(ci, parts, rim)
			ci.draw_colored_polygon(flame_pts(Vector2(0, -2), 17, 54, s + 3), FIRE2)
			ci.draw_colored_polygon(flame_pts(Vector2(-22, 8), 8, 26, s + 12), FIRE2)
			ci.draw_colored_polygon(flame_pts(Vector2(22, 8), 8, 26, s + 13), FIRE2)
			ci.draw_colored_polygon(flame_pts(Vector2(0, 10), 7, 22, s + 5), Color(1, 1, 0.85))
			for i in 4:
				ci.draw_circle(Vector2(-30 + 20 * i, -54 + 9 * (i % 2)), 2.6, FIRE2)
		_:
			for k in 2:
				ci.draw_circle(Vector2(0, -8), 46.0 - 8.0 * k, Color(1, 0.85, 0.35, 0.16))
			var bowl := poly([Vector2(-34, 6), Vector2(34, 6), Vector2(24, 24), Vector2(-24, 24)], s + 1, 0.4)
			var stem := rrect(Rect2(-10, 22, 20, 14), 3, s + 2, 0.3)
			var foot := rrect(Rect2(-28, 34, 56, 10), 4, s + 3, 0.3)
			sil(ci, [P(flame_pts(Vector2(0, -30), 30, 86, s), FIRE, 1), P(foot, STONE_D, 1), P(stem, STONE, 1), P(bowl, STONE, 0)], rim)
			ci.draw_colored_polygon(flame_pts(Vector2(0, -20), 17, 54, s + 3), FIRE2)
			ci.draw_colored_polygon(flame_pts(Vector2(0, -10), 7, 24, s + 5), Color(1, 1, 0.9))
			ci.draw_colored_polygon(rrect(Rect2(-26, 10, 52, 5), 2, s + 6, 0.2), OCHRE)
			for i in 3:
				ci.draw_colored_polygon(star_pts(Vector2(-14 + 14 * i, 17), 3.6, 1.4, 4, s + 7 + i), FIRE2)
			for v in [Vector2(-36, -40), Vector2(34, -50), Vector2(-26, -66), Vector2(28, -16)]:
				ci.draw_colored_polygon(star_pts(v, 6, 2, 4, s + int(v.x)), Color(1, 0.96, 0.7))

## 不拿拿 6 级：碎贝壳 → 贝壳 → 贝壳串 → 贝壳堆 → 贝壳篓 → 珍珠贝
static func _shell(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			sil(ci, [P(_scallop(Vector2(-4, 4), 22, -0.35, s), SHELL), P(poly([Vector2(16, 18), Vector2(28, 10), Vector2(26, 26)], s + 1, 0.4), SHELL_D)], rim)
			_scallop_det(ci, Vector2(-4, 4), 22, -0.35, s)
		2:
			sil(ci, [P(_scallop(Vector2(0, -2), 30, 0.0, s), SHELL)], rim)
			_scallop_det(ci, Vector2(0, -2), 30, 0.0, s)
		3:
			var cs := [Vector2(-24, 4), Vector2(0, 14), Vector2(24, 4)]
			var rs := [-0.3, 0.0, 0.3]
			var parts := []
			for i in 3:
				parts.append(P(_scallop(cs[i], 15, rs[i], s + i), SHELL if i != 1 else SHELL.lightened(0.05)))
			sil(ci, parts, rim)
			pl(ci, [Vector2(-42, -26), Vector2(-24, -8), Vector2(0, -2), Vector2(24, -8), Vector2(42, -26)], 2.5, WOOD_D, s)
			for i in 3:
				_scallop_det(ci, cs[i], 15, rs[i], s + i)
		4:
			var cs := [Vector2(-22, 18), Vector2(22, 18), Vector2(0, 20), Vector2(-12, -4), Vector2(14, -2), Vector2(0, -22)]
			var rs := [-0.4, 0.4, 0.0, -0.2, 0.25, 0.0]
			var parts := []
			for i in cs.size():
				parts.append(P(_scallop(cs[i], 17, rs[i], s + i), SHELL.darkened(0.04 * float(i % 3))))
			sil(ci, parts, rim)
			for i in cs.size():
				_scallop_det(ci, cs[i], 17, rs[i], s + i)
		5:
			var cs := [Vector2(-20, -12), Vector2(18, -14), Vector2(0, -24), Vector2(-4, -6)]
			var rs := [-0.35, 0.3, 0.0, 0.1]
			var parts := []
			for i in cs.size():
				parts.append(P(_scallop(cs[i], 15, rs[i], s + i), SHELL.darkened(0.04 * float(i % 2))))
			var body := poly([Vector2(-40, -6), Vector2(40, -6), Vector2(30, 40), Vector2(-30, 40)], s + 8, 0.5)
			sil(ci, parts + [P(body, WOOD, 1)], rim)
			for i in cs.size():
				_scallop_det(ci, cs[i], 15, rs[i], s + i)
			for k in 3:
				var y := 6.0 + k * 11.0
				var hw := 38.0 - k * 3.0
				pl(ci, [Vector2(-hw, y), Vector2(0, y + 2), Vector2(hw, y)], 1.6, WOOD_D, s + 10 + k)
			for k in 5:
				ln(ci, Vector2(-26 + k * 13, -4), Vector2(-20 + k * 10, 38), 1.4, Color(0.4, 0.22, 0.08, 0.5), s + 15 + k)
			ln(ci, Vector2(-42, -6), Vector2(42, -6), 4.0, ROPE, s + 20)
		_:
			ci.draw_circle(Vector2(0, 6), 44, Color(1, 0.95, 0.8, 0.18))
			var dish := ell(Vector2(0, 18), Vector2(40, 18), s + 1, 0.04, 22)
			sil(ci, [P(_scallop(Vector2(0, -12), 30, 0.0, s + 2), SHELL), P(dish, SHELL_D.lightened(0.1), 1)], rim)
			_scallop_det(ci, Vector2(0, -12), 30, 0.0, s + 2)
			ci.draw_colored_polygon(ell(Vector2(0, 16), Vector2(30, 11), s + 3, 0.03, 18), Color("f9c9c0"))
			var pearl := ell(Vector2(0, 10), Vector2(15, 15), s + 4, 0.01, 18)
			dilate(ci, pearl, 2.4, INK)
			ci.draw_colored_polygon(pearl, Color("f4f1ff"))
			ci.draw_colored_polygon(ell(Vector2(3, 14), Vector2(11, 9), s + 5, 0.0, 14), Color("dcd6f0"))
			ci.draw_colored_polygon(ell(Vector2(-5, 4), Vector2(5, 4), s + 6, 0.0, 10), Color(1, 1, 1, 0.95))
			for v in [Vector2(-30, -30), Vector2(32, -8), Vector2(22, -40)]:
				ci.draw_colored_polygon(star_pts(v, 6, 2, 4, s + int(v.y)), Color(1, 1, 0.9))

## 琥珀 6 级：前三级是圆润的树脂滴，第 4、5 级是不规则六边刻面，最后是金边心形；里面封着的小虫一级比一级大、一级比一级清楚。
## 琥珀屑 → 琥珀粒 → 琥珀块 → 虫珀 → 大琥珀 → 琥珀之心
static func _amber(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			sil(ci, [P(ell(Vector2(-12, 6), Vector2(13, 15), s, 0.1, 14, 0.3), AMBER),
				P(ell(Vector2(14, 14), Vector2(9, 10), s + 1, 0.1, 12), AMBER.darkened(0.08)),
				P(ell(Vector2(8, -14), Vector2(7, 8), s + 2, 0.1, 12), AMBER.lightened(0.05))], rim)
		2:
			sil(ci, [P(ell(Vector2(-2, 2), Vector2(24, 28), s, 0.07, 20, 0.25), AMBER)], rim)
			_amber_bug(ci, Vector2(0, 6), 8.0, 0.45, s)
			_amber_shine(ci, Vector2(-10, -10), 0.8, s)
		3:
			sil(ci, [P(ell(Vector2(0, 2), Vector2(34, 32), s, 0.08, 22, 0.15), AMBER)], rim)
			_amber_bug(ci, Vector2(2, 6), 13.0, 0.6, s)
			_amber_shine(ci, Vector2(-14, -12), 1.0, s)
		4:
			_amber_facet(ci, 1.08, s, rim)
			_amber_bug(ci, Vector2(0, 4), 19.0, 0.78, s)
		5:
			_amber_facet(ci, 1.3, s, rim)
			_amber_bug(ci, Vector2(0, 4), 27.0, 0.9, s)
			ci.draw_colored_polygon(star_pts(Vector2(-26, -30), 7, 2.2, 4, s + 7), Color(1, 1, 0.9, 0.9))
		_:
			for k in 2:
				ci.draw_circle(Vector2(0, 0), 48.0 - 8.0 * k, Color(1, 0.8, 0.3, 0.15))
			var heart := []
			for k in 28:
				var t := TAU * float(k) / 28.0
				var x := 16.0 * pow(sin(t), 3)
				var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
				heart.append(Vector2(x, y) * 2.5 + Vector2(0, -2))
			var hp := poly(heart, s, 0.4)
			if rim:
				dilate(ci, hp, 9.0, Color(1, 0.98, 0.92, 0.96))
			dilate(ci, hp, 7.0, INK)
			dilate(ci, hp, 4.6, OCHRE)
			dilate(ci, hp, 2.2, INK)
			shade(ci, hp, AMBER, 1)
			_amber_bug(ci, Vector2(0, 4), 31.0, 1.0, s)
			ci.draw_colored_polygon(ell(Vector2(-14, -16), Vector2(9, 5), s + 4, 0.0, 12, -0.6), Color(1, 1, 0.9, 0.55))
			for v in [Vector2(-38, -30), Vector2(36, -26), Vector2(30, 30)]:
				ci.draw_colored_polygon(star_pts(v, 6, 2, 4, s + int(v.x)), Color(1, 1, 0.9))

## 原来「琥珀块」那种不规则六边刻面：顶点连到偏上的一点，左上两块亮面
static func _amber_facet(ci: CanvasItem, k: float, s: int, rim: bool) -> void:
	var vs := [Vector2(-34, 4), Vector2(-20, -28), Vector2(14, -34), Vector2(34, -6), Vector2(24, 28), Vector2(-14, 32)]
	var sc: Array = []
	for v in vs:
		sc.append(v * k)
	var core := Vector2(0, -6) * k
	sil(ci, [P(poly(sc, s), AMBER, 1)], rim)
	ci.draw_colored_polygon(poly([sc[1], sc[2], core], s + 3), Color(1, 0.9, 0.5, 0.6))
	ci.draw_colored_polygon(poly([sc[0], sc[1], core], s + 4), Color(1, 0.8, 0.3, 0.5))
	for i in [1, 2, 3, 0, 5]:
		ln(ci, core, sc[i], 1.6, Color(0.5, 0.25, 0.0, 0.7), s)

static func _amber_shine(ci: CanvasItem, c: Vector2, k: float, s: int) -> void:
	ci.draw_colored_polygon(ell(c, Vector2(9, 5) * k, s + 4, 0.0, 12, -0.6), Color(1, 1, 0.92, 0.6))
	ci.draw_circle(c + Vector2(10, -4) * k, 2.2 * k, Color(1, 1, 0.92, 0.7))

## 封在琥珀里的小虫：sz 是身长，a 是清晰度（越高级越清楚）
static func _amber_bug(ci: CanvasItem, c: Vector2, sz: float, a: float, s: int) -> void:
	var body := Color(0.24, 0.11, 0.0, 0.85 * a)
	var wing := Color(1, 0.97, 0.85, 0.42 * a)
	var k := sz / 30.0
	var w := maxf(1.0, 1.6 * k)
	if sz >= 12.0:
		for sx in [-1.0, 1.0]:
			ci.draw_colored_polygon(ell(c + Vector2(9 * sx, -6) * k, Vector2(10, 5) * k, s + 20 + int(sx), 0.0, 12, -0.5 * sx, 0.15), wing)
	for sx in [-1.0, 1.0]:
		for i in 3:
			var o := c + Vector2(0, -2 + i * 5) * k
			ln(ci, o, o + Vector2(sx * 11, -4 + i * 5) * k, w, body, s + i)
		if sz >= 12.0:
			ln(ci, c + Vector2(0, -12) * k, c + Vector2(sx * 6, -19) * k, w * 0.8, body, s + 9)
	ci.draw_colored_polygon(ell(c + Vector2(0, 8) * k, Vector2(5.5, 8) * k, s + 30, 0.0, 12, 0.0, 0.15), body)
	ci.draw_colored_polygon(ell(c + Vector2(0, -2) * k, Vector2(4.5, 4) * k, s + 31, 0.0, 10, 0.0, 0.15), body)
	ci.draw_circle(c + Vector2(0, -9) * k, 3.4 * k, body)
	if sz >= 20.0:
		for i in 3:
			ln(ci, c + Vector2(-4.5, 5 + i * 3.4) * k, c + Vector2(4.5, 5 + i * 3.4) * k, w * 0.7, Color(1, 0.8, 0.4, 0.45 * a), s + 40 + i)

## 沙漏 6 级：从零件一步步装成完整沙漏。
## 玻璃沙泡（半个泡）→ 沙漏芯（两泡相连）→ 盖板沙漏（加上下木盖）→ 木框沙漏（加立柱）→ 骨饰沙漏（绑绳 + 骨头角）→ 黄金沙漏
const SAND_GLASS := Color("e3f3f1")
const SAND_FILL := Color("f2c35a")

## 火种罐（体力生产器）：鼓肚陶罐，腰上一圈草绳，罐口冒火苗、飞火星。生成 PNG 时按 boil 相位画出各帧。
static func _emberpot(ci: CanvasItem, s: int, rim: bool) -> void:
	ci.draw_colored_polygon(ell(Vector2(0, 44), Vector2(32, 6), 1, 0.0, 14, 0.0, 0.0), Color(0.2, 0.1, 0.0, 0.18))
	var body := poly([Vector2(-20, -16), Vector2(-34, 0), Vector2(-36, 18), Vector2(-26, 38), Vector2(26, 38),
		Vector2(36, 18), Vector2(34, 0), Vector2(20, -16)], s, 0.8)
	var neck := rrect(Rect2(-22, -24, 44, 12), 5, s + 1, 0.5)
	var flame := flame_pts(Vector2(0, -36), 22, 56, s + 2)
	var side_l := flame_pts(Vector2(-13, -30), 9, 26, s + 3)
	var side_r := flame_pts(Vector2(14, -31), 9, 28, s + 4)
	sil(ci, [P(side_l, FIRE, 1), P(side_r, FIRE, 1), P(flame, FIRE, 1), P(body, CLAY, 1), P(neck, OCHRE, 0)], rim)
	ci.draw_colored_polygon(flame_pts(Vector2(0, -30), 12, 32, s + 5), FIRE2)
	ci.draw_colored_polygon(flame_pts(Vector2(0, -26), 5, 14, s + 6), Color(1, 1, 0.85))
	# 罐口里的炭火
	for k in 3:
		ci.draw_circle(Vector2(-11 + 11 * k, -19) + jv(s + 20 + k, 0.6), 3.2, FIRE2)
	# 腰上一圈草绳 + 绳结
	var rope := capsule(Vector2(-35, 10), Vector2(35, 10), 4.0, s + 7)
	sil(ci, [P(rope, ROPE, 1)], false, 2.0)
	for k in 6:
		var x := -28.0 + 11.2 * k
		ln(ci, Vector2(x, 7), Vector2(x + 4, 13), 1.6, INK, s + 30 + k)
	# 罐身上赭石画的火纹
	pl(ci, [Vector2(-14, 30), Vector2(-9, 21), Vector2(-4, 28), Vector2(1, 19), Vector2(6, 28), Vector2(11, 21), Vector2(16, 30)], 2.4, OCHRE.darkened(0.15), s + 9)
	pl(ci, [Vector2(-24, -4), Vector2(-27, 6)], 2.4, Color(1, 1, 1, 0.55), s + 10)
	# 飞火星
	for k in 4:
		var p := Vector2(-30 + 20 * k, -58 + 10 * (k % 2)) + jv(s + 40 + k, 1.5)
		ci.draw_colored_polygon(star_pts(p, 5.5, 2.2, 4, s + 50 + k), FIRE2)

static func _sand(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	lv = clampi(lv, 1, 6)
	var h: float = [0, 30.0, 34.0, 38.0, 40.0, 42.0, 44.0][lv]
	var w: float = [0, 22.0, 21.0, 23.0, 24.0, 26.0, 27.0][lv]
	var cap_col: Color = [WOOD, WOOD, WOOD, WOOD, WOOD, WOOD_D, OCHRE][lv]
	var post_col: Color = [WOOD, WOOD, WOOD, WOOD, WOOD_D, BONE2, FIRE2.darkened(0.05)][lv]
	var neck := 3.2
	if lv == 1:
		# 零件：只有下半个玻璃泡，口上一圈细绳，里面装了些沙
		var inner := 34.0
		var bulb := _hourglass_pts(inner, w, 6.0, 0.0, inner * 0.02, inner)
		var moved := PackedVector2Array()
		for p in bulb:
			moved.append(p + Vector2(0, -inner * 0.5))
		sil(ci, [P(moved, SAND_GLASS, 1)], rim)
		var sand := _hourglass_pts(inner, w - 3.0, 4.0, 0.0, inner * 0.5, inner - 2.0)
		var sm := PackedVector2Array()
		for p in sand:
			sm.append(p + Vector2(0, -inner * 0.5))
		ci.draw_colored_polygon(sm, SAND_FILL)
		outline(ci, moved, 2.2, INK)
		var lip := capsule(Vector2(-9, -inner * 0.48), Vector2(9, -inner * 0.48), 3.2, s + 1)
		sil(ci, [P(lip, ROPE, 1)], false, 2.0)
		pl(ci, [Vector2(-w * 0.6, -2), Vector2(-w * 0.78, 6), Vector2(-w * 0.62, 16)], 2.4, Color(1, 1, 1, 0.85), s + 6)
		for k in 3:
			ci.draw_circle(Vector2(18 + k * 6, inner * 0.5 + 2 - (k % 2) * 3), 2.2, SAND_FILL.darkened(0.1))
		return
	var caps := lv >= 3
	var posts := lv >= 4
	var gold := lv == 6
	if gold:
		for k in 2:
			ci.draw_circle(Vector2(0, 0), 48.0 - 8.0 * k, Color(1, 0.85, 0.35, 0.16))
	var cap_h := 8.0 + float(lv) * 0.5 if caps else 0.0
	var inner := h - cap_h if caps else h - 4.0
	var cap_w := w + 9.0 + float(lv)
	var glass := _hourglass_pts(inner, w, neck, 0.0)
	var parts := [P(glass, SAND_GLASS, 1)]
	if posts:
		var px := w + 3.5
		for sx in [-1.0, 1.0]:
			parts.append(P(capsule(Vector2(px * sx, -inner), Vector2(px * sx, inner), 2.6 + float(lv) * 0.25, s + int(sx) + 3), post_col, 1))
	if caps:
		parts.append(P(rrect(Rect2(-cap_w, -h, cap_w * 2.0, cap_h), 3.5, s + 1, 0.3), cap_col, 1))
		parts.append(P(rrect(Rect2(-cap_w, h - cap_h, cap_w * 2.0, cap_h), 3.5, s + 2, 0.3), cap_col, 1))
	sil(ci, parts, rim)
	# 沙：上泡剩一半，下泡堆成小丘，中间一道细流
	ci.draw_colored_polygon(_hourglass_pts(inner, w - 3.0, neck - 1.0, 0.0, -inner * 0.5, -inner * 0.06), SAND_FILL)
	var mound := PackedVector2Array()
	var base := inner - 2.0
	var top_y := inner * 0.38
	for k in 13:
		var x := lerpf(-1.0, 1.0, float(k) / 12.0)
		var y := lerpf(top_y + inner * 0.22, top_y, 1.0 - absf(x))
		mound.append(Vector2(x * _hg_half(y / inner, w - 3.0, neck - 1.0), y))
	for k in range(1, 7):
		var y := lerpf(top_y + inner * 0.22, base, float(k) / 6.0)
		mound.append(Vector2(_hg_half(y / inner, w - 3.0, neck - 1.0), y))
	for k in range(6, 0, -1):
		var y := lerpf(top_y + inner * 0.22, base, float(k) / 6.0)
		mound.append(Vector2(-_hg_half(y / inner, w - 3.0, neck - 1.0), y))
	ci.draw_colored_polygon(poly(Array(mound), s + 5, 0.2), SAND_FILL)
	ci.draw_line(Vector2(0, -inner * 0.08), Vector2(0, top_y + 2.0), SAND_FILL.darkened(0.08), 2.2, true)
	outline(ci, glass, 2.2, INK)
	pl(ci, [Vector2(-w * 0.62, -inner * 0.82), Vector2(-w * 0.78, -inner * 0.55), Vector2(-w * 0.55, -inner * 0.25)], 2.4, Color(1, 1, 1, 0.85), s + 6)
	pl(ci, [Vector2(-w * 0.62, inner * 0.3), Vector2(-w * 0.78, inner * 0.55)], 2.4, Color(1, 1, 1, 0.7), s + 7)
	match lv:
		2:
			# 还没装盖：两头敞口，用细绳缠着腰
			for y in [-inner, inner]:
				var mouth := ell(Vector2(0, y), Vector2(_hg_half(1.0, w, neck), 3.0), s + int(y), 0.0, 12)
				outline(ci, mouth, 2.0, INK)
			ln(ci, Vector2(-7, -2), Vector2(7, 2), 3.0, ROPE, s + 8)
			ln(ci, Vector2(-7, 2), Vector2(7, -2), 3.0, ROPE, s + 9)
		5:
			for sx in [-1.0, 1.0]:
				for k in 2:
					var y := -inner * 0.45 + k * inner * 0.9
					ln(ci, Vector2((w + 3.5) * sx - 4, y - 3), Vector2((w + 3.5) * sx + 4, y + 3), 3.0, ROPE, s + k)
				for sy in [-1.0, 1.0]:
					var c := Vector2((w + 3.5) * sx, (h - cap_h * 0.5) * sy)
					var knob := ell(c + Vector2(4 * sx, 0), Vector2(5, 4.5), s + int(sx * 3 + sy), 0.05, 10)
					dilate(ci, knob, 2.0, INK)
					ci.draw_colored_polygon(knob, BONE)
		6:
			var gem := poly([Vector2(0, -h - 9), Vector2(8, -h - 2), Vector2(0, -h + 4), Vector2(-8, -h - 2)], s + 9, 0.3)
			dilate(ci, gem, 2.2, INK)
			ci.draw_colored_polygon(gem, TEAL)
			ci.draw_colored_polygon(poly([Vector2(0, -h - 9), Vector2(8, -h - 2), Vector2(0, -h - 3)], s + 10, 0.2), Color(1, 1, 1, 0.45))
			for y in [-h + cap_h * 0.5, h - cap_h * 0.5]:
				ln(ci, Vector2(-cap_w + 4, y), Vector2(cap_w - 4, y), 1.8, Color(1, 1, 0.85, 0.8), s + int(y))
			for v in [Vector2(-40, -30), Vector2(40, -14), Vector2(-34, 34)]:
				ci.draw_colored_polygon(star_pts(v, 6, 2, 4, s + int(v.x)), Color(1, 1, 0.9))

## 沙漏玻璃的半宽：u 是 -1（顶）到 1（底），中间最细
static func _hg_half(u: float, w: float, neck: float) -> float:
	var a := absf(u)
	var bulge := sin(PI * 0.5 * minf(1.0, a * 1.35))
	var taper := 1.0 - 0.18 * maxf(0.0, a - 0.8) / 0.2
	return neck + (w - neck) * bulge * taper

## 玻璃轮廓（或其中 y0..y1 这一段）
static func _hourglass_pts(inner: float, w: float, neck: float, _pad: float, y0: float = INF, y1: float = INF) -> PackedVector2Array:
	if y0 == INF:
		y0 = -inner
		y1 = inner
	var n := 16
	var left: Array = []
	var right: Array = []
	for k in n + 1:
		var y := lerpf(y0, y1, float(k) / float(n))
		var hw := _hg_half(y / inner, w, neck)
		right.append(Vector2(hw, y))
		left.append(Vector2(-hw, y))
	var pts := PackedVector2Array()
	for p in right:
		pts.append(p)
	for i in range(left.size() - 1, -1, -1):
		pts.append(left[i])
	return pts

static func _chest(ci: CanvasItem, s: int, rim: bool) -> void:
	sil(ci, [P(rrect(Rect2(-38, -8, 76, 46), 8, s, 0.6), WOOD, 1),
		P(rrect(Rect2(-42, -30, 84, 24), 10, s + 1, 0.6), CLAY, 1),
		P(rrect(Rect2(-8, -16, 16, 22), 5, s + 2, 0.5), Color("f3e6c8"), 1)], rim)
	_weave(ci, Rect2(-32, -2, 64, 36), s)
	pl(ci, [Vector2(-38, -20), Vector2(38, -20)], 2.5, ROPE, s)
	ci.draw_circle(Vector2(0, -2), 3.0, INK)
	for i in 4:
		var x := -30.0 + float(i) * 20.0
		ci.draw_colored_polygon(star_pts(Vector2(x, -24), 4, 2, 4, s + i), FIRE2)

static func _pack(ci: CanvasItem, s: int, rim: bool) -> void:
	var col := Color("c98f55")
	sil(ci, [P(rrect(Rect2(-32, -28, 64, 68), 14, s, 0.7), col, 1),
		P(poly([Vector2(-22, -28), Vector2(-14, -42), Vector2(14, -42), Vector2(22, -28)], s + 1), col.darkened(0.1), 1),
		P(ell(Vector2(0, 8), Vector2(18, 18), s + 2, 0.02), OCHRE)], rim)
	dashed(ci, rrect(Rect2(-26, -22, 52, 56), 10, s, 0.0), 5, 4, BONE, 2.0)
	pl(ci, [Vector2(-24, -30), Vector2(0, -26), Vector2(24, -30)], 3.0, ROPE, s)
	ci.draw_circle(Vector2(0, 13), 6.0, INK)
	for i in 4:
		var a := -PI * 0.5 + (float(i) - 1.5) * 0.55
		ci.draw_circle(Vector2(0, 13) + Vector2(cos(a), sin(a)) * 11.0, 3.2, INK)

# ---------------------------------------------------------------- 制作菜

static func _paint_dish(ci: CanvasItem, id: String, c: Vector2, size: float, rim: bool, rot: float) -> void:
	ci.draw_set_transform(c, rot, Vector2.ONE * (size / 100.0))
	ci.draw_colored_polygon(ell(Vector2(0, 40), Vector2(34, 7), 2, 0.0, 14, 0.0, 0.0), Color(0.2, 0.1, 0.0, 0.18))
	var s: int = absi(id.hash()) % 97
	match id:
		"salad":
			_dish_salad(ci, s, rim)
		"berrybowl":
			_dish_bowl(ci, s, rim)
		"platter":
			_dish_platter(ci, s, rim)
		"grill":
			_dish_grill(ci, s, rim)
		"feast":
			_dish_feast(ci, s, rim)
		"nutmix":
			_dish_nutmix(ci, s, rim)
		"cutfruit":
			_dish_cutfruit(ci, s, rim)
		"flintkit":
			_dish_flintkit(ci, s, rim)
		"fruitbasket":
			_dish_fruitbasket(ci, s, rim)
		"ochrebeads":
			_dish_ochrebeads(ci, s, rim)
		"trailpack":
			_dish_trailpack(ci, s, rim)
		"toolbelt":
			_dish_toolbelt(ci, s, rim)
		"bracer":
			_dish_bracer(ci, s, rim)
		"talisman":
			_dish_talisman(ci, s, rim)
		"warpaint":
			_dish_warpaint(ci, s, rim)
		"hunterkit":
			_dish_hunterkit(ci, s, rim)
		"furwrap":
			_dish_furwrap(ci, s, rim)
		"featherhat":
			_dish_featherhat(ci, s, rim)
		"skewer":
			_dish_skewer(ci, s, rim)
		"fruitboard":
			_dish_fruitboard(ci, s, rim)
		"mask":
			_dish_mask(ci, s, rim)
		"chiefseat":
			_dish_chiefseat(ci, s, rim)
		"potstew":
			_dish_potstew(ci, s, rim)
		"drumset":
			_dish_drumset(ci, s, rim)
		"grandfeast":
			_dish_grandfeast(ci, s, rim)
		"chiefgift":
			_dish_chiefgift(ci, s, rim)
		_:
			_dish_salad(ci, s, rim)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func _berry(c: Vector2, r: float, col: Color, s: int) -> Array:
	return [P(ell(c, Vector2(r, r * 0.92), s, 0.06, 14), col, 1)]

static func _dish_salad(ci: CanvasItem, s: int, rim: bool) -> void:
	var leaf := ell(Vector2(0, 10), Vector2(38, 20), s, 0.06, 18, 0.15)
	sil(ci, [P(leaf, LEAF, 1),
		P(ell(Vector2(-22, 8), Vector2(14, 8), s + 1, 0.08, 12, -0.7), LEAF_D, 1),
		P(ell(Vector2(22, 10), Vector2(14, 8), s + 2, 0.08, 12, 0.6), LEAF_D, 1)], rim)
	sil(ci, _berry(Vector2(-14, -2), 10, BERRY, s + 3), rim)
	sil(ci, _berry(Vector2(12, -8), 9, Color("7a4db8"), s + 4), rim)
	sil(ci, _berry(Vector2(1, 10), 9, CLAY, s + 5), rim)
	sil(ci, [P(ell(Vector2(16, -18), Vector2(9, 4), s + 6, 0.1, 10, 0.9), LEAF, 1)], rim)
	ci.draw_circle(Vector2(-18, -6), 2.2, Color(1, 1, 1, 0.7))
	ci.draw_circle(Vector2(8, -12), 2.0, Color(1, 1, 1, 0.65))

static func _dish_bowl(ci: CanvasItem, s: int, rim: bool) -> void:
	var bowl := poly([Vector2(-32, -2), Vector2(32, -2), Vector2(22, 26), Vector2(-22, 26)], s, 0.7)
	var lip := ell(Vector2(0, -2), Vector2(32, 10), s + 1, 0.04, 16)
	sil(ci, [P(bowl, WOOD, 1), P(lip, WOOD.lightened(0.12), 0)], rim)
	sil(ci, _berry(Vector2(-10, -6), 10, OCHRE, s + 3), rim)
	sil(ci, _berry(Vector2(12, -2), 8, BERRY, s + 4), rim)
	for k in 5:
		ci.draw_circle(Vector2(-6 + float(k) * 5, 6 + (k % 2) * 3), 2.4, SEED)

static func _dish_platter(ci: CanvasItem, s: int, rim: bool) -> void:
	sil(ci, [P(ell(Vector2(0, 8), Vector2(40, 22), s, 0.05, 18), LEAF, 1),
		P(ell(Vector2(-24, 6), Vector2(12, 7), s + 1, 0.08, 10, -0.5), LEAF_D, 1),
		P(ell(Vector2(26, 8), Vector2(12, 7), s + 2, 0.08, 10, 0.4), LEAF_D, 1)], rim)
	sil(ci, [P(capsule(Vector2(-22, 2), Vector2(18, -10), 3.2, s + 3), WOOD_D, 1)], rim)
	sil(ci, _berry(Vector2(-12, -2), 7, ROAST, s + 4), rim)
	sil(ci, _berry(Vector2(2, -6), 7, MEAT, s + 5), rim)
	sil(ci, _berry(Vector2(16, 2), 8, LEAF, s + 6), rim)
	sil(ci, _berry(Vector2(-2, 12), 8, CLAY, s + 7), rim)

static func _dish_grill(ci: CanvasItem, s: int, rim: bool) -> void:
	var stone := rrect(Rect2(-36, -6, 72, 34), 10, s, 0.6)
	sil(ci, [P(stone, STONE, 1)], rim)
	for k in 3:
		pl(ci, [Vector2(-28, 2 + k * 8), Vector2(28, 0 + k * 8)], 2.2, STONE_D, s + k)
	var fish := ell(Vector2(12, -4), Vector2(16, 8), s + 4, 0.05, 14, -0.3)
	var tail := poly([Vector2(24, -8), Vector2(34, -14), Vector2(32, 2), Vector2(24, 2)], s + 5, 0.6)
	sil(ci, [P(fish, FISH, 1), P(tail, FISH.darkened(0.15), 1)], rim)
	ci.draw_circle(Vector2(4, -6), 1.8, INK)
	var meat := ell(Vector2(-14, -2), Vector2(12, 9), s + 6, 0.06, 14, 0.4)
	sil(ci, [P(meat, ROAST, 1)], rim)
	pl(ci, [Vector2(-20, -4), Vector2(-8, 2)], 2.0, INK, s + 7)
	var flame := flame_pts(Vector2(0, 22), 8, 16, s + 8)
	fill(ci, flame, FIRE2, 2.0)

static func _dish_feast(ci: CanvasItem, s: int, rim: bool) -> void:
	sil(ci, [P(ell(Vector2(0, 12), Vector2(42, 20), s, 0.04, 18), WOOD, 1),
		P(ell(Vector2(0, 6), Vector2(34, 12), s + 1, 0.04, 16), WOOD.lightened(0.15), 0)], rim)
	var pot := poly([Vector2(-16, -8), Vector2(2, -8), Vector2(-2, 10), Vector2(-20, 10)], s + 2, 0.6)
	sil(ci, [P(pot, CLAY, 1), P(ell(Vector2(-8, -8), Vector2(10, 4), s + 3, 0.04, 12), OCHRE, 0)], rim)
	sil(ci, _berry(Vector2(16, -6), 9, ROAST, s + 4), rim)
	sil(ci, [P(capsule(Vector2(8, 8), Vector2(22, 16), 4.0, s + 5), MEAT, 1),
		P(ell(Vector2(22, 16), Vector2(6, 5), s + 6, 0.05, 10), BONE, 0)], rim)
	sil(ci, [P(ell(Vector2(-4, 14), Vector2(8, 5), s + 7, 0.06, 12), Color("8d4a32"), 1),
		P(capsule(Vector2(-4, 8), Vector2(-4, 16), 2.4, s + 8), BONE, 1)], rim)
	sil(ci, _berry(Vector2(6, -16), 7, BERRY, s + 9), rim)
## 坚果干粮：扎口皮袋，口里冒出坚果
static func _dish_nutmix(ci: CanvasItem, s: int, rim: bool) -> void:
	var sack := poly([Vector2(-26, -4), Vector2(-14, -16), Vector2(14, -16), Vector2(26, -4), Vector2(30, 22), Vector2(0, 32), Vector2(-30, 22)], s, 0.8)
	var parts: Array = [P(sack, LEATHER, 1)]
	for k in 3:
		var at := Vector2(-11 + float(k) * 11, -22 + float(k % 2) * 4)
		parts.append(P(ell(at + Vector2(0, 3), Vector2(7, 8), s + 3 + k, 0.05, 12), SEED, 1))
		parts.append(P(ell(at + Vector2(0, -4), Vector2(7.5, 4), s + 6 + k, 0.05, 10), WOOD_D, 1))
	parts.append(P(ell(Vector2(28, 26), Vector2(7, 8), s + 9, 0.05, 12), SEED, 1))
	parts.append(P(ell(Vector2(28, 19), Vector2(7.5, 4), s + 10, 0.05, 10), WOOD_D, 1))
	sil(ci, parts, rim)
	pl(ci, [Vector2(-20, -8), Vector2(20, -8)], 3.0, ROPE, s + 2)
	for k in 4:
		ci.draw_circle(Vector2(-14 + float(k) * 9, 12 + float(k % 2) * 6), 2.0, LEATHER_D)
## 石刀果盘：石板上切开的果子，旁边一把石刀
static func _dish_cutfruit(ci: CanvasItem, s: int, rim: bool) -> void:
	var parts: Array = [P(ell(Vector2(-4, 14), Vector2(38, 18), s, 0.08, 16), STONE, 1)]
	var cols: Array = [BERRY, Color("f2c94c"), Color("7a4db8")]
	for k in 3:
		var c := Vector2(-22 + float(k) * 16, 8 - float(k % 2) * 8)
		var col: Color = cols[k]
		parts.append(P(ell(c, Vector2(10, 9), s + 1 + k, 0.04, 14), col, 1))
		parts.append(P(ell(c + Vector2(0, -1), Vector2(7, 6), s + 4 + k, 0.03, 12), Color("ffe9c0"), 2))
	parts.append(P(poly([Vector2(14, 20), Vector2(40, 2), Vector2(44, 9), Vector2(20, 27)], s + 8, 0.6), STONE_D.lightened(0.25), 1))
	parts.append(P(capsule(Vector2(4, 28), Vector2(15, 23), 4.0, s + 9), WOOD, 1))
	sil(ci, parts, rim)
	for k in 3:
		ci.draw_circle(Vector2(-22 + float(k) * 16, 7 - float(k % 2) * 8), 1.8, INK)
## 燧石火镰：黑燧石 + 打火石，迸出火星
static func _dish_flintkit(ci: CanvasItem, s: int, rim: bool) -> void:
	var flint := poly([Vector2(-34, 10), Vector2(-24, -14), Vector2(-4, -18), Vector2(4, 4), Vector2(-10, 24), Vector2(-30, 24)], s, 1.0)
	sil(ci, [P(flint, Color("4a4550"), 1)], rim)
	pl(ci, [Vector2(-24, -6), Vector2(-14, 2), Vector2(-20, 14)], 2.0, Color("8a8494"), s + 1)
	var striker := poly([Vector2(6, 14), Vector2(30, 2), Vector2(38, 14), Vector2(14, 28)], s + 2, 0.8)
	sil(ci, [P(striker, OCHRE.darkened(0.1), 1), P(capsule(Vector2(30, 6), Vector2(40, -2), 3.0, s + 3), LEATHER, 1)], rim)
	fill(ci, star_pts(Vector2(4, -16), 9, 3.5, 4, s + 4), FIRE2, 2.0)
	fill(ci, star_pts(Vector2(18, -22), 6, 2.5, 4, s + 5), FIRE, 1.6)
	fill(ci, star_pts(Vector2(-4, -30), 5, 2.0, 4, s + 6), FIRE2, 1.4)

## 草编果篮：编织纹的草篮，上面堆果子
static func _dish_fruitbasket(ci: CanvasItem, s: int, rim: bool) -> void:
	var bas := poly([Vector2(-36, -2), Vector2(36, -2), Vector2(26, 30), Vector2(-26, 30)], s, 0.7)
	sil(ci, [P(_berry(Vector2(-16, -12), 11, BERRY, s + 1)[0][0], BERRY, 1), P(_berry(Vector2(4, -16), 11, OCHRE, s + 2)[0][0], OCHRE, 1),
		P(_berry(Vector2(20, -9), 10, Color("7a4db8"), s + 3)[0][0], Color("7a4db8"), 1), P(bas, ROPE, 1)], rim)
	for k in 5:
		var x := -26.0 + float(k) * 13.0
		pl(ci, [Vector2(x, 2), Vector2(x * 0.78, 28)], 2.0, WOOD, s + 4 + k)
	for k in 3:
		pl(ci, [Vector2(-31 + float(k) * 3, 9 + float(k) * 7), Vector2(31 - float(k) * 3, 9 + float(k) * 7)], 2.0, WOOD, s + 9 + k)
	sil(ci, [P(ell(Vector2(0, -1), Vector2(37, 5), s + 12, 0.04, 16), ROPE.darkened(0.12), 1)], false)
## 赭石项链：绳上一圈赭石珠，中间挂吊坠
static func _dish_ochrebeads(ci: CanvasItem, s: int, rim: bool) -> void:
	var arc: Array = []
	for k in 13:
		var a := PI * 0.05 + PI * 0.9 * float(k) / 12.0
		arc.append(Vector2(cos(a) * 32.0, -14.0 + sin(a) * 26.0))
	pl(ci, [arc[0], Vector2(0, -30), arc[12]], 2.4, ROPE.darkened(0.3), s)
	var parts: Array = []
	for k in 11:
		var p: Vector2 = arc[1 + k]
		var col := OCHRE if k % 2 == 0 else CLAY
		parts.append(P(ell(p, Vector2(6.5, 6.5), s + k, 0.05, 12), col, 1))
	parts.append(P(poly([Vector2(-11, 12), Vector2(11, 12), Vector2(0, 38)], s + 20, 0.8), Color("b5492d"), 1))
	sil(ci, parts, rim)
	ci.draw_circle(Vector2(-3, 18), 2.2, Color(1, 1, 1, 0.6))
## 远行干粮包：皮背包，顶上绑一卷草席
static func _dish_trailpack(ci: CanvasItem, s: int, rim: bool) -> void:
	var bag := rrect(Rect2(-26, -10, 52, 44), 12, s, 0.8)
	var flap := poly([Vector2(-26, -8), Vector2(26, -8), Vector2(22, 12), Vector2(-22, 12)], s + 1, 0.7)
	var roll := capsule(Vector2(-30, -18), Vector2(30, -18), 9.0, s + 2)
	sil(ci, [P(roll, ROPE, 1), P(bag, LEATHER, 1), P(flap, LEATHER_D.lightened(0.15), 1)], rim)
	pl(ci, [Vector2(-14, -26), Vector2(-14, -10)], 2.4, WOOD_D, s + 3)
	pl(ci, [Vector2(14, -26), Vector2(14, -10)], 2.4, WOOD_D, s + 4)
	sil(ci, [P(ell(Vector2(0, 14), Vector2(5, 5), s + 5, 0.04, 10), BONE, 1)], rim)
	sil(ci, _berry(Vector2(20, 24), 6, BERRY, s + 6), rim)

## 工具腰带：弯皮带上挂着石斧和石刀
static func _dish_toolbelt(ci: CanvasItem, s: int, rim: bool) -> void:
	var belt := poly([Vector2(-40, -10), Vector2(0, -2), Vector2(40, -10), Vector2(40, 0), Vector2(0, 8), Vector2(-40, 0)], s, 0.7)
	sil(ci, [P(belt, LEATHER, 1)], rim)
	sil(ci, [P(rrect(Rect2(-6, -6, 12, 12), 3, s + 1, 0.5), BONE2, 1)], rim)
	sil(ci, [P(capsule(Vector2(-22, 2), Vector2(-26, 34), 3.2, s + 2), WOOD, 1),
		P(poly([Vector2(-36, 6), Vector2(-20, 4), Vector2(-18, 16), Vector2(-34, 18)], s + 3, 0.6), STONE, 1)], rim)
	sil(ci, [P(poly([Vector2(16, 4), Vector2(26, 4), Vector2(22, 34)], s + 4, 0.6), STONE_D.lightened(0.25), 1),
		P(capsule(Vector2(21, 2), Vector2(21, 10), 4.0, s + 5), LEATHER_D, 1)], rim)

## 贝饰草裙：皮腰头下一圈草穗，腰头上挂三枚扇贝壳
static func _dish_bracer(ci: CanvasItem, s: int, rim: bool) -> void:
	var parts: Array = []
	for k in 9:
		var x := -24.0 + float(k) * 6.0
		var bot := 32.0 - absf(float(k) - 4.0) * 1.0
		var col := Color("c9b45a") if k % 2 == 0 else Color("b5a14e")
		parts.append(P(poly([Vector2(x - 4.4, -12), Vector2(x + 4.4, -12), Vector2(x * 1.25 + 4.4, bot), Vector2(x * 1.25 - 4.4, bot)], s + k, 0.3), col, 2))
	parts.append(P(rrect(Rect2(-32, -22, 64, 12), 5, s + 20, 0.5), LEATHER, 1))
	sil(ci, parts, rim)
	var shells: Array = []
	var cs: Array = []
	for k in 3:
		var c := Vector2(-20.0 + float(k) * 20.0, -14.0 + (4.0 if k == 1 else 0.0))
		cs.append(c)
		var pts: Array = [c + Vector2(-3, -1), c + Vector2(3, -1)]
		for j in 9:
			var a := lerpf(0.45, PI - 0.45, float(j) / 8.0)
			pts.append(c + Vector2(cos(a), sin(a)) * (17.0 if j % 2 == 0 else 15.5))
		shells.append(P(poly(pts, s + 30 + k, 0.2), SHELL, 1))
	sil(ci, shells, false, 2.0)
	for c in cs:
		for j in 3:
			var a := lerpf(1.0, PI - 1.0, float(j) / 2.0)
			ln(ci, (c as Vector2) + Vector2(0, 1), (c as Vector2) + Vector2(cos(a), sin(a)) * 14.0, 1.4, SHELL_D, s + j)
		ci.draw_circle((c as Vector2) + Vector2(0, -1), 2.0, ROPE)
## 宝石护符：木框里镶一颗绿宝石，挂绳
static func _dish_talisman(ci: CanvasItem, s: int, rim: bool) -> void:
	pl(ci, [Vector2(-26, -38), Vector2(0, -18), Vector2(26, -38)], 2.6, ROPE.darkened(0.3), s)
	var frame := poly([Vector2(0, -22), Vector2(24, 0), Vector2(0, 36), Vector2(-24, 0)], s + 1, 0.8)
	var gem := poly([Vector2(0, -12), Vector2(14, 2), Vector2(0, 26), Vector2(-14, 2)], s + 2, 0.5)
	sil(ci, [P(frame, WOOD, 1), P(gem, TEAL, 0)], rim)
	pl(ci, [Vector2(-14, 2), Vector2(14, 2)], 1.6, TEAL.darkened(0.3), s + 3)
	pl(ci, [Vector2(0, -12), Vector2(0, 26)], 1.6, TEAL.darkened(0.3), s + 4)
	for k in 2:
		sil(ci, [P(ell(Vector2(-18 + float(k) * 36, 22), Vector2(4, 7), s + 5 + k, 0.05, 10), Color("e9e3d0"), 1)], rim)

## 祭典彩妆：三小碗颜料（红、黄、白）和一支草刷
static func _dish_warpaint(ci: CanvasItem, s: int, rim: bool) -> void:
	var cols: Array = [CLAY, OCHRE, BONE]
	var at: Array = [Vector2(22, -6), Vector2(-20, 4), Vector2(6, 18)]
	var parts: Array = [P(capsule(Vector2(-34, -30), Vector2(-6, -10), 3.0, s + 7), WOOD, 1),
		P(poly([Vector2(-8, -14), Vector2(0, -8), Vector2(2, 0), Vector2(-10, -4)], s + 8, 0.6), CLAY, 1)]
	for k in 3:
		var c: Vector2 = at[k]
		var col: Color = cols[k]
		parts.append(P(ell(c + Vector2(0, 4), Vector2(15, 10), s + k, 0.04, 14), STONE, 1))
		parts.append(P(ell(c, Vector2(11, 5), s + 3 + k, 0.04, 12), col, 2))
	sil(ci, parts, rim)
## 猎人行囊：箭筒插着三支羽箭，旁边小皮囊
static func _dish_hunterkit(ci: CanvasItem, s: int, rim: bool) -> void:
	var tips: Array = [CLAY, BONE, TEAL]
	var parts: Array = []
	var shafts: Array = []
	for k in 3:
		var x := -18.0 + float(k) * 10.0
		var tip := Vector2(x - 6 + float(k) * 4, -32)
		var col: Color = tips[k]
		parts.append(P(poly([tip + Vector2(-7, 4), tip + Vector2(0, -9), tip + Vector2(7, 4)], s + 3 + k, 0.4), col, 1))
		shafts.append([Vector2(x, -4), tip + Vector2(0, 3)])
	parts.append(P(poly([Vector2(-28, -6), Vector2(8, -6), Vector2(4, 34), Vector2(-24, 34)], s + 6, 0.7), LEATHER, 1))
	parts.append(P(ell(Vector2(24, 18), Vector2(14, 14), s + 9, 0.06, 14), HIDE2, 1))
	parts.append(P(ell(Vector2(24, 6), Vector2(8, 4), s + 10, 0.05, 10), LEATHER_D, 1))
	for sh in shafts:
		var a: Array = sh
		pl(ci, a, 6.0, Color(1, 0.98, 0.92, 0.96), s)
	sil(ci, parts, rim)
	for sh in shafts:
		var a: Array = sh
		pl(ci, a, 3.0, WOOD_D, s + 1)
	pl(ci, [Vector2(-26, 6), Vector2(6, 6)], 2.2, ROPE, s + 7)
	pl(ci, [Vector2(-25, 22), Vector2(5, 22)], 2.2, ROPE, s + 8)
## 兔毛项圈：一圈蓬松的灰白兔毛围成项圈，前面垂三颗兽牙
static func _dish_furwrap(ci: CanvasItem, s: int, rim: bool) -> void:
	var fur := Color("eee5d4")
	var teeth: Array = []
	for k in 3:
		var x := -14.0 + float(k) * 14.0
		var l := 26.0 if k == 1 else 20.0
		var tp := PackedVector2Array([Vector2(x - 6, 10), Vector2(x + 6, 10), Vector2(x + 4, 10 + l * 0.6), Vector2(x + 2.5, 10 + l * 0.92),
			Vector2(x + 1, 10 + l), Vector2(x - 1, 10 + l * 0.8), Vector2(x - 4, 10 + l * 0.45)])
		teeth.append(P(tp, BONE, 2))
	var ring: Array = []
	for k in 64:
		var a := TAU * float(k) / 64.0
		var r := 1.0 - 0.07 * (0.5 + 0.5 * cos(a * 16.0))
		ring.append(Vector2(cos(a) * 40.0 * r, -6.0 + sin(a) * 22.0 * r))
	sil(ci, teeth + [P(poly(ring, s + 9, 0.5), fur, 1)], rim)
	var hole := ell(Vector2(0, -9), Vector2(20, 8), s, 0.04, 18)
	ci.draw_colored_polygon(hole, Color("5a4632"))
	outline(ci, hole, 1.6)
	for k in 12:
		var a := TAU * float(k) / 12.0 + 0.2
		var p := Vector2(cos(a) * 30.0, -6.0 + sin(a) * 15.0)
		ln(ci, p, p + Vector2(cos(a) * 5.0, sin(a) * 3.0 + 2.0), 1.4, Color(INK, 0.3), s + k)
	for k in 3:
		ci.draw_circle(Vector2(-14.0 + float(k) * 14.0, 12), 2.6, ROPE)

## 羽毛头冠：皮头带上一排彩色羽毛
static func _dish_featherhat(ci: CanvasItem, s: int, rim: bool) -> void:
	var cols: Array = [CLAY, OCHRE, TEAL, BONE, OCHRE]
	var parts: Array = []
	var quills: Array = []
	for k in 5:
		var a := -PI * 0.5 + (float(k) - 2.0) * 0.38
		var base := Vector2(cos(a) * 14.0, 14.0 + sin(a) * 6.0)
		var tip := base + Vector2(cos(a), sin(a)) * 38.0
		var col: Color = cols[k]
		parts.append(P(ell((base + tip) * 0.5, Vector2(8, 19), s + k, 0.05, 14, a + PI * 0.5), col, 1))
		quills.append([base, tip])
	parts.append(P(poly([Vector2(-34, 12), Vector2(34, 12), Vector2(30, 28), Vector2(-30, 28)], s + 12, 0.7), LEATHER, 1))
	sil(ci, parts, rim)
	for q in quills:
		var qa: Array = q
		pl(ci, [(qa[0] as Vector2).lerp(qa[1], 0.15), qa[1]], 1.6, INK, s + 6)
	for k in 4:
		var x := float(k) * 14.0
		fill(ci, poly([Vector2(-22 + x, 16), Vector2(-16 + x, 24), Vector2(-28 + x, 24)], s + 13 + k, 0.4), OCHRE, 1.4)
## 烤肉串拼盘：叶子上并排三串肉菜相间的串
static func _dish_skewer(ci: CanvasItem, s: int, rim: bool) -> void:
	sil(ci, [P(ell(Vector2(0, 14), Vector2(42, 18), s, 0.06, 16, -0.1), LEAF, 1)], rim)
	var veg: Array = [LEAF_D, OCHRE, CLAY]
	for k in 3:
		var a := Vector2(-36, float(k) * 10 - 4)
		var b := Vector2(36, float(k) * 10 - 14)
		pl(ci, [a, b], 2.4, WOOD_D, s + 1 + k)
		var cubes: Array = []
		for j in 4:
			var c := a.lerp(b, 0.2 + float(j) * 0.2)
			var col: Color = ROAST if (j + k) % 2 == 0 else veg[k]
			cubes.append(P(rrect(Rect2(c - Vector2(6, 6), Vector2(12, 12)), 3, s + 5 + j + k * 4, 0.4), col, 1))
		sil(ci, cubes, false, 2.0)
## 木托果盘：长方木板上各色果子
static func _dish_fruitboard(ci: CanvasItem, s: int, rim: bool) -> void:
	var board := rrect(Rect2(-40, 0, 80, 26), 8, s, 0.7)
	sil(ci, [P(ell(Vector2(4, -24), Vector2(8, 4), s + 8, 0.1, 10, 0.6), LEAF, 1),
		P(ell(Vector2(-22, -6), Vector2(12, 11), s + 4, 0.05, 14), Color("f2c94c"), 1),
		P(ell(Vector2(0, -10), Vector2(13, 13), s + 5, 0.05, 14), BERRY, 1),
		P(ell(Vector2(30, -12), Vector2(7, 7), s + 7, 0.05, 12), Color("6a3fa0"), 1),
		P(ell(Vector2(22, -4), Vector2(9, 9), s + 6, 0.05, 12), Color("7a4db8"), 1),
		P(board, WOOD, 1)], rim)
	for k in 2:
		pl(ci, [Vector2(-32, 11 + float(k) * 7), Vector2(32, 9 + float(k) * 7)], 1.4, WOOD_D, s + 1 + k)
## 祭典面具：椭圆木面具，彩绘条纹，顶上两根羽毛
static func _dish_mask(ci: CanvasItem, s: int, rim: bool) -> void:
	sil(ci, [P(ell(Vector2(-14, -32), Vector2(5, 12), s, 0.05, 12, -0.4), CLAY, 1), P(ell(Vector2(14, -32), Vector2(5, 12), s + 1, 0.05, 12, 0.4), TEAL, 1)], rim)
	var face := ell(Vector2(0, 2), Vector2(26, 34), s + 2, 0.04, 20)
	sil(ci, [P(face, WOOD, 1)], rim)
	ci.draw_colored_polygon(ell(Vector2(-10, -6), Vector2(7, 5), s + 3, 0.05, 12), INK)
	ci.draw_colored_polygon(ell(Vector2(10, -6), Vector2(7, 5), s + 4, 0.05, 12), INK)
	pl(ci, [Vector2(-20, 6), Vector2(-8, 10)], 3.4, CLAY, s + 5)
	pl(ci, [Vector2(20, 6), Vector2(8, 10)], 3.4, CLAY, s + 6)
	pl(ci, [Vector2(0, -24), Vector2(0, -12)], 3.4, OCHRE, s + 7)
	pl(ci, [Vector2(-10, 22), Vector2(0, 26), Vector2(10, 22)], 2.6, INK, s + 8)

## 酋长坐席：木座铺兽皮，靠背两侧一对兽角
static func _dish_chiefseat(ci: CanvasItem, s: int, rim: bool) -> void:
	sil(ci, [P(poly([Vector2(-26, -20), Vector2(-40, -36), Vector2(-30, -14)], s, 0.6), BONE, 1),
		P(poly([Vector2(26, -20), Vector2(40, -36), Vector2(30, -14)], s + 1, 0.6), BONE, 1)], rim)
	var back := rrect(Rect2(-26, -26, 52, 34), 8, s + 2, 0.7)
	var seat := rrect(Rect2(-34, 4, 68, 14), 5, s + 3, 0.6)
	var leg1 := poly([Vector2(-30, 18), Vector2(-22, 18), Vector2(-24, 36), Vector2(-30, 36)], s + 4, 0.5)
	var leg2 := poly([Vector2(22, 18), Vector2(30, 18), Vector2(30, 36), Vector2(24, 36)], s + 5, 0.5)
	sil(ci, [P(leg1, WOOD_D, 1), P(leg2, WOOD_D, 1), P(back, WOOD, 1), P(seat, WOOD, 1)], rim)
	var fur := poly([Vector2(-18, -18), Vector2(18, -18), Vector2(22, 8), Vector2(12, 14), Vector2(-12, 14), Vector2(-22, 8)], s + 6, 1.2)
	sil(ci, [P(fur, Color("c79a5e"), 1)], rim)
	for k in 3:
		ci.draw_colored_polygon(ell(Vector2(-8 + float(k) * 8, -6 + float(k % 2) * 8), Vector2(4, 3), s + 7 + k, 0.1, 10), LEATHER_D)

## 陶罐炖肉：红陶罐冒热气，骨头露出罐口
static func _dish_potstew(ci: CanvasItem, s: int, rim: bool) -> void:
	for k in 3:
		var x := -12.0 + float(k) * 12.0
		pl(ci, [Vector2(x, -22), Vector2(x - 4, -30), Vector2(x + 2, -38)], 2.2, Color(1, 1, 1, 0.75), s + k)
	sil(ci, [P(capsule(Vector2(6, -6), Vector2(20, -22), 3.4, s + 3), BONE, 1), P(ell(Vector2(21, -24), Vector2(5, 4), s + 4, 0.05, 10), BONE, 1)], rim)
	var pot := ell(Vector2(0, 12), Vector2(32, 24), s + 5, 0.03, 20)
	sil(ci, [P(pot, CLAY, 1), P(ell(Vector2(0, -8), Vector2(26, 7), s + 6, 0.03, 16), ROAST, 1)], rim)
	pl(ci, [Vector2(-22, 12), Vector2(-8, 6), Vector2(8, 6), Vector2(22, 12)], 2.0, OCHRE, s + 7)
	sil(ci, [P(ell(Vector2(-34, 8), Vector2(5, 7), s + 8, 0.05, 10), CLAY.darkened(0.15), 1), P(ell(Vector2(34, 8), Vector2(5, 7), s + 9, 0.05, 10), CLAY.darkened(0.15), 1)], rim)

## 祭典乐器：兽皮鼓、骨笛和摇铃
static func _dish_drumset(ci: CanvasItem, s: int, rim: bool) -> void:
	sil(ci, [P(capsule(Vector2(-34, -24), Vector2(4, -34), 4.0, s), BONE, 1)], rim)
	for k in 3:
		ci.draw_circle(Vector2(-24 + float(k) * 9, -28 - float(k) * 2.4), 1.8, INK)
	var body := poly([Vector2(-30, -6), Vector2(14, -6), Vector2(10, 32), Vector2(-26, 32)], s + 1, 0.6)
	sil(ci, [P(body, WOOD, 1), P(ell(Vector2(-8, -6), Vector2(22, 7), s + 2, 0.03, 16), HIDE, 1)], rim)
	for k in 4:
		var x := -24.0 + float(k) * 11.0
		pl(ci, [Vector2(x, -1), Vector2(x + 5, 28)], 1.8, ROPE, s + 3 + k)
	sil(ci, [P(capsule(Vector2(26, 34), Vector2(26, 12), 2.6, s + 8), WOOD_D, 1), P(ell(Vector2(26, 2), Vector2(11, 12), s + 9, 0.05, 14), OCHRE, 1)], rim)
	for k in 3:
		ci.draw_circle(Vector2(21 + float(k) * 5, 0 + float(k % 2) * 5), 1.8, CLAY)

## 篝火盛宴：中间篝火，上面架烤腿，两侧陶罐
static func _dish_grandfeast(ci: CanvasItem, s: int, rim: bool) -> void:
	sil(ci, [P(ell(Vector2(0, 26), Vector2(30, 8), s, 0.06, 14), STONE, 1)], rim)
	fill(ci, flame_pts(Vector2(0, 10), 16, 34, s + 1), FIRE, 2.2)
	fill(ci, flame_pts(Vector2(0, 16), 8, 18, s + 2), FIRE2, 0.0)
	pl(ci, [Vector2(-38, -16), Vector2(38, -16)], 3.0, WOOD_D, s + 3)
	sil(ci, [P(ell(Vector2(0, -16), Vector2(18, 9), s + 4, 0.05, 14), ROAST, 1), P(ell(Vector2(16, -16), Vector2(5, 5), s + 5, 0.05, 10), BONE, 1)], rim)
	sil(ci, [P(poly([Vector2(-44, 8), Vector2(-28, 8), Vector2(-30, 32), Vector2(-42, 32)], s + 6, 0.6), CLAY, 1)], rim)
	sil(ci, [P(poly([Vector2(28, 8), Vector2(44, 8), Vector2(42, 32), Vector2(30, 32)], s + 7, 0.6), OCHRE.darkened(0.15), 1)], rim)
	sil(ci, _berry(Vector2(36, 4), 5, BERRY, s + 8), rim)

## 酋长献礼：系布带的木箱，嵌宝石，闪着光
static func _dish_chiefgift(ci: CanvasItem, s: int, rim: bool) -> void:
	var box := rrect(Rect2(-32, -8, 64, 40), 6, s, 0.7)
	var lid := rrect(Rect2(-36, -20, 72, 16), 6, s + 1, 0.7)
	sil(ci, [P(ell(Vector2(-11, -26), Vector2(11, 6), s + 3, 0.05, 12, -0.4), CLAY, 1), P(ell(Vector2(11, -26), Vector2(11, 6), s + 4, 0.05, 12, 0.4), CLAY, 1),
		P(box, WOOD, 1), P(lid, WOOD_D.lightened(0.15), 1), P(rrect(Rect2(-6, -20, 12, 52), 3, s + 2, 0.4), CLAY, 1)], rim)
	sil(ci, [P(poly([Vector2(-24, 8), Vector2(-17, 0), Vector2(-10, 8), Vector2(-17, 17)], s + 5, 0.4), TEAL, 1),
		P(poly([Vector2(10, 8), Vector2(17, 0), Vector2(24, 8), Vector2(17, 17)], s + 6, 0.4), Color("7a4db8"), 1)], false, 2.0)
	fill(ci, star_pts(Vector2(32, -30), 8, 3, 4, s + 7), FIRE2, 1.6)
	fill(ci, star_pts(Vector2(-34, -30), 5, 2, 4, s + 8), FIRE2, 1.4)
