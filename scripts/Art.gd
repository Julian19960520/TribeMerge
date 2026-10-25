class_name Art
extends RefCounted
## 「石纹手作」绘图核心：线条沸腾 + 贴纸描边 + 双色块面。
## 物品图标统一在 100×100 的局部坐标里绘制（中心为原点）。

const INK := Color("3b2314")
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
const SHELL := Color("f8d9bc")
const SHELL_D := Color("e7a98a")
const AMBER := Color("f39a1f")
const SKIN := Color("c98a5a")
const FISH := Color("6fb0c8")

static var boil: int = 0

# ---------------------------------------------------------------- 随机与抖动

static func srnd(i: int) -> float:
	var v := sin(float(i) * 12.9898 + 4.1414) * 43758.5453
	return v - floor(v)

static func jit(i: int) -> float:
	var v := sin(float(i) * 78.233 + float(boil) * 37.719 + 1.7) * 43758.5453
	return (v - floor(v)) * 2.0 - 1.0

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

static func item(ci: CanvasItem, id: String, c: Vector2, size: float, rim: bool = true, rot: float = 0.0) -> void:
	if id == "":
		return
	var ch := id.get_slice("_", 0)
	var lv := int(id.get_slice("_", 1))
	ci.draw_set_transform(c, rot, Vector2.ONE * (size / 100.0))
	ci.draw_colored_polygon(ell(Vector2(0, 40), Vector2(30, 6), 1, 0.0, 14, 0.0, 0.0), Color(0.2, 0.1, 0.0, 0.18))
	var s: int = abs(ch.hash()) % 97 + lv * 7
	match ch:
		"berry": _berry(ci, lv, s, rim)
		"stone": _stone(ci, lv, s, rim)
		"meat": _meat(ci, lv, s, rim)
		"fish": _fish(ci, lv, s, rim)
		"basket": _basket(ci, lv, s, rim)
		"hunt": _hunt(ci, lv, s, rim)
		"fire": _fire(ci, lv, s, rim)
		"shell": _shell(ci, lv, s, rim)
		"amber": _amber(ci, lv, s, rim)
		"chest": _chest(ci, s, rim)
		"pack": _pack(ci, s, rim)
		_:
			sil(ci, [P(ell(Vector2.ZERO, Vector2(30, 30), s), STONE)], rim)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func _bry(c: Vector2, r: float, s: int) -> Array:
	return P(ell(c, Vector2(r, r * 0.96), s, 0.04, 16), BERRY)

static func _bry_dots(ci: CanvasItem, cs: Array) -> void:
	for c in cs:
		var v: Vector2 = c
		ci.draw_circle(v + Vector2(4, 3), 1.4, Color(1, 0.85, 0.6, 0.9))
		ci.draw_circle(v + Vector2(-2, 6), 1.4, Color(1, 0.85, 0.6, 0.9))

static func _berry(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			sil(ci, [
				P(capsule(Vector2(0, -6), Vector2(0, -22), 2.4, s), LEAF_D, 2),
				P(ell(Vector2(-15, 16), Vector2(9, 13), s + 1, 0.05, 16, -0.5), SEED),
				P(ell(Vector2(15, 18), Vector2(9, 13), s + 2, 0.05, 16, 0.5), SEED),
				P(ell(Vector2(0, 6), Vector2(10, 14), s + 3, 0.05, 16), SEED.lightened(0.12)),
				P(ell(Vector2(-11, -24), Vector2(12, 6), s + 4, 0.05, 12, -0.5), LEAF, 1),
				P(ell(Vector2(11, -26), Vector2(12, 6), s + 5, 0.05, 12, 0.5), LEAF, 1)], rim)
		2:
			sil(ci, [_bry(Vector2(0, 8), 27, s),
				P(ell(Vector2(-10, -20), Vector2(11, 5), s + 1, 0.05, 12, -0.5), LEAF, 1),
				P(ell(Vector2(10, -20), Vector2(11, 5), s + 2, 0.05, 12, 0.5), LEAF, 1),
				P(ell(Vector2(0, -24), Vector2(5, 10), s + 3, 0.05, 12), LEAF_D, 1)], rim)
			_bry_dots(ci, [Vector2(-6, 6), Vector2(8, 14), Vector2(4, -4), Vector2(-10, 20)])
		3:
			var cs := [Vector2(-12, 10), Vector2(12, -6), Vector2(8, 22), Vector2(-16, -14)]
			sil(ci, [P(capsule(Vector2(-32, 34), Vector2(26, -30), 3.0, s), WOOD_D, 2),
				P(ell(Vector2(26, -32), Vector2(13, 6), s + 1, 0.05, 12, -0.7), LEAF, 1),
				_bry(cs[3], 11, s + 2), _bry(cs[0], 14, s + 3), _bry(cs[1], 13, s + 4), _bry(cs[2], 12, s + 5)], rim)
			_bry_dots(ci, cs)
		4:
			sil(ci, [P(ell(Vector2(0, 10), Vector2(46, 28), s, 0.04, 22, -0.3), LEAF, 1)], rim)
			pl(ci, [Vector2(-42, 23), Vector2(0, 10), Vector2(42, -3)], 2.2, LEAF_D, s)
			var cs := [Vector2(-14, 2), Vector2(6, -2), Vector2(-4, 18), Vector2(16, 12), Vector2(24, -8)]
			sil(ci, [_bry(cs[0], 12, s + 1), _bry(cs[1], 12, s + 2), _bry(cs[2], 12, s + 3), _bry(cs[3], 11, s + 4), _bry(cs[4], 10, s + 5)], false)
			_bry_dots(ci, cs)
		_:
			var cs := [Vector2(-26, -10), Vector2(-8, -18), Vector2(12, -16), Vector2(28, -8), Vector2(0, -30), Vector2(-16, -28)]
			var parts := [P(ell(Vector2(22, -30), Vector2(14, 7), s, 0.05, 12, -0.6), LEAF, 1)]
			for i in cs.size():
				parts.append(_bry(cs[i], 12, s + i + 1))
			parts.append(P(poly([Vector2(-40, -6), Vector2(40, -6), Vector2(30, 38), Vector2(-30, 38)], s), WOOD, 1))
			parts.append(P(capsule(Vector2(-42, -6), Vector2(42, -6), 6.0, s + 9), WOOD.lightened(0.15), 1))
			sil(ci, parts, rim)
			_weave(ci, Rect2(-34, 2, 68, 34), s)
			_bry_dots(ci, cs)

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

static func _stone(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			sil(ci, [P(ell(Vector2(-16, 16), Vector2(15, 11), s, 0.1), STONE),
				P(ell(Vector2(15, 18), Vector2(13, 10), s + 1, 0.1), STONE.darkened(0.1)),
				P(ell(Vector2(0, -2), Vector2(14, 11), s + 2, 0.1), STONE.lightened(0.12))], rim)
		2:
			var pts := poly([Vector2(-30, 12), Vector2(-20, -22), Vector2(4, -34), Vector2(28, -12), Vector2(24, 20), Vector2(-6, 32)], s)
			sil(ci, [P(pts, Color("6d6a78"), 1)], rim)
			ci.draw_colored_polygon(poly([Vector2(-20, -22), Vector2(4, -34), Vector2(2, -2)], s + 3), Color(1, 1, 1, 0.2))
			for v in [Vector2(-20, -22), Vector2(28, -12), Vector2(-6, 32), Vector2(-30, 12)]:
				ln(ci, Vector2(2, -2), v, 1.8, INK, s)
		3:
			var base := [Vector2(0, -42), Vector2(17, -12), Vector2(15, 20), Vector2(0, 40), Vector2(-15, 20), Vector2(-17, -12)]
			var pts := poly(rot_pts(base, 0.6), s)
			sil(ci, [P(pts, Color("c4bdb0"), 1)], rim)
			var a := Vector2(0, -38).rotated(0.6)
			var b := Vector2(0, 36).rotated(0.6)
			ln(ci, a, b, 1.8, INK, s)
			for i in 4:
				var t := 0.2 + 0.18 * float(i)
				var m := a.lerp(b, t)
				ln(ci, m, m + Vector2(12, -2).rotated(0.6), 1.5, INK, s + i)
				ln(ci, m, m + Vector2(-12, -2).rotated(0.6), 1.5, INK, s + i + 9)
		4:
			var blade := poly([Vector2(-12, 10), Vector2(2, -14), Vector2(32, -40), Vector2(24, -6), Vector2(2, 16)], s)
			sil(ci, [P(capsule(Vector2(-32, 36), Vector2(-6, 8), 7.5, s + 1), WOOD, 1), P(blade, Color("c4bdb0"), 1)], rim)
			ln(ci, Vector2(-4, 12), Vector2(28, -36), 1.5, INK, s)
			_rope(ci, Vector2(-32, 36), Vector2(-6, 8), 0.72, 3, 8.0, s)
		_:
			var head := poly([Vector2(-10, -40), Vector2(30, -38), Vector2(43, -16), Vector2(32, 2), Vector2(-6, -8)], s)
			sil(ci, [P(capsule(Vector2(-28, 42), Vector2(12, -32), 6.5, s + 1), WOOD, 1), P(head, Color("918b84"), 1)], rim)
			ln(ci, Vector2(30, -38), Vector2(32, 2), 1.6, INK, s)
			ci.draw_colored_polygon(poly([Vector2(30, -36), Vector2(42, -16), Vector2(32, 0)], s + 3), Color(1, 1, 1, 0.22))
			_rope(ci, Vector2(-28, 42), Vector2(12, -32), 0.74, 3, 8.0, s)

static func _rope(ci: CanvasItem, a: Vector2, b: Vector2, t: float, n: int, half: float, s: int) -> void:
	var d := (b - a).normalized()
	var nn := Vector2(-d.y, d.x)
	for i in n:
		var m := a.lerp(b, t) - d * float(i) * 5.0
		ln(ci, m - nn * half - d * 2.0, m + nn * half + d * 2.0, 4.5, INK, s + i)
		ln(ci, m - nn * half - d * 2.0, m + nn * half + d * 2.0, 2.5, ROPE, s + i)

static func _bone_parts(a: Vector2, b: Vector2, r: float, s: int) -> Array:
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x)
	var col := Color("f3e6c8")
	return [P(capsule(a, b, r, s), col, 1),
		P(ell(a + n * r * 0.9 - d * r * 0.4, Vector2(r * 1.25, r * 1.25), s + 1, 0.03, 14), col, 1),
		P(ell(a - n * r * 0.9 - d * r * 0.4, Vector2(r * 1.25, r * 1.25), s + 2, 0.03, 14), col, 1),
		P(ell(b + n * r * 0.9 + d * r * 0.4, Vector2(r * 1.25, r * 1.25), s + 3, 0.03, 14), col, 1),
		P(ell(b - n * r * 0.9 + d * r * 0.4, Vector2(r * 1.25, r * 1.25), s + 4, 0.03, 14), col, 1)]

static func _meat(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			sil(ci, _bone_parts(Vector2(-24, 14), Vector2(24, -14), 7.0, s), rim)
		2:
			sil(ci, [P(ell(Vector2(0, 4), Vector2(38, 28), s, 0.1, 22, -0.2), MEAT)], rim)
			pl(ci, [Vector2(-28, -6), Vector2(-10, -14), Vector2(12, -12), Vector2(30, -2)], 4.0, Color(1, 0.93, 0.88), s)
			pl(ci, [Vector2(-20, 12), Vector2(0, 6), Vector2(18, 14)], 3.0, Color(1, 0.9, 0.86, 0.85), s + 3)
		3:
			var cubes := [Vector2(-18, 18), Vector2(0, 0), Vector2(18, -18)]
			var parts := [P(capsule(Vector2(-40, 38), Vector2(38, -36), 3.0, s), WOOD_D, 2)]
			for i in 3:
				var c: Vector2 = cubes[i]
				parts.append(P(rrect(Rect2(c - Vector2(12, 12), Vector2(24, 24)), 6, s + i, 0.6), ROAST if i != 1 else ROAST.lightened(0.1), 1))
			sil(ci, parts, rim)
			for c in cubes:
				var v: Vector2 = c
				ln(ci, v + Vector2(-7, -3), v + Vector2(3, -9), 2.0, INK, s)
				ln(ci, v + Vector2(-3, 5), v + Vector2(7, -1), 2.0, INK, s + 2)
		4:
			var parts := _bone_parts(Vector2(-14, 14), Vector2(-34, 34), 5.5, s)
			parts.remove_at(1)
			parts.remove_at(1)
			parts.append(P(ell(Vector2(10, -10), Vector2(30, 24), s + 5, 0.06, 22, -0.75), ROAST))
			sil(ci, parts, rim)
			ln(ci, Vector2(0, -22), Vector2(22, -2), 2.0, INK, s)
			ln(ci, Vector2(-4, -10), Vector2(14, 8), 2.0, INK, s + 3)
		_:
			var parts := [P(ell(Vector2(0, 28), Vector2(48, 11), s, 0.04, 22), LEAF, 1)]
			for x in [-24.0, -10.0, 14.0, 28.0]:
				parts.append(P(capsule(Vector2(x, 14), Vector2(x * 1.15, 28), 4.5, s + int(x)), ROAST.darkened(0.15), 2))
			parts.append(P(capsule(Vector2(-50, -2), Vector2(50, -2), 3.0, s + 3), WOOD_D, 2))
			parts.append(P(ell(Vector2(4, 2), Vector2(38, 21), s + 4, 0.04, 22), ROAST))
			parts.append(P(ell(Vector2(-34, -4), Vector2(14, 12), s + 5, 0.04, 16), ROAST.lightened(0.05)))
			parts.append(P(ell(Vector2(-47, 0), Vector2(6, 6), s + 6, 0.02, 12), BERRY))
			sil(ci, parts, rim)
			for i in 3:
				var x := -12.0 + float(i) * 14.0
				ln(ci, Vector2(x, -12), Vector2(x + 8, 10), 2.2, INK, s + i)
			ci.draw_circle(Vector2(-36, -8), 2.2, INK)

static func _fishp(c: Vector2, L: float, col: Color, rot: float, s: int) -> Array:
	var d := Vector2(cos(rot), sin(rot))
	var n := Vector2(-d.y, d.x)
	var t0 := c + d * L * 0.34
	var tail := poly([t0, t0 + d * L * 0.26 + n * L * 0.2, t0 + d * L * 0.17, t0 + d * L * 0.26 - n * L * 0.2], s)
	var fin := poly([c - n * L * 0.16, c - n * L * 0.3 + d * L * 0.12, c - n * L * 0.14 + d * L * 0.2], s + 1)
	return [P(tail, col.darkened(0.1), 1), P(fin, col.darkened(0.15), 1), P(ell(c, Vector2(L * 0.42, L * 0.21), s + 2, 0.02, 22, rot), col)]

static func _fish_det(ci: CanvasItem, c: Vector2, L: float, rot: float, s: int, stripes: int = 0) -> void:
	var d := Vector2(cos(rot), sin(rot))
	var n := Vector2(-d.y, d.x)
	var eye := c - d * L * 0.26 - n * L * 0.04
	ci.draw_circle(eye, L * 0.065, Color.WHITE)
	ci.draw_circle(eye, L * 0.035, INK)
	var g := c - d * L * 0.15
	pl(ci, [g - n * L * 0.12, g - d * L * 0.03, g + n * L * 0.12], 1.8, INK, s)
	for i in stripes:
		var m := c + d * L * (0.0 + 0.1 * float(i))
		ln(ci, m - n * L * 0.12, m + n * L * 0.1, 2.2, Color(0.15, 0.3, 0.4, 0.5), s + i)

static func _fish(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			sil(ci, _fishp(Vector2(-2, 4), 58, FISH.lightened(0.15), 0.0, s), rim)
			_fish_det(ci, Vector2(-2, 4), 58, 0.0, s)
		2:
			sil(ci, _fishp(Vector2(-4, 2), 84, FISH, -0.2, s), rim)
			_fish_det(ci, Vector2(-4, 2), 84, -0.2, s, 3)
		3:
			var parts := [P(capsule(Vector2(-6, 44), Vector2(6, -44), 3.0, s), WOOD_D, 2)]
			parts.append_array(_fishp(Vector2(4, -16), 60, FISH, 0.15, s + 3))
			parts.append_array(_fishp(Vector2(-2, 18), 60, FISH.darkened(0.08), -0.1, s + 7))
			sil(ci, parts, rim)
			_fish_det(ci, Vector2(4, -16), 60, 0.15, s, 2)
			_fish_det(ci, Vector2(-2, 18), 60, -0.1, s + 5, 2)
		_:
			var parts := [P(ell(Vector2(0, 14), Vector2(48, 18), s, 0.04, 22, -0.1), LEAF, 1)]
			parts.append_array(_fishp(Vector2(-2, 2), 86, Color("d08a42"), -0.15, s + 3))
			sil(ci, parts, rim)
			_fish_det(ci, Vector2(-2, 2), 86, -0.15, s)
			for i in 3:
				var x := -6.0 + float(i) * 12.0
				ln(ci, Vector2(x, -12), Vector2(x + 8, 12), 2.4, Color(0.3, 0.12, 0.02, 0.8), s + i)

static func _basket_body(c: Vector2, w: float, h: float, s: int, col: Color = WOOD) -> Array:
	return [P(poly([c + Vector2(-w, 0), c + Vector2(w, 0), c + Vector2(w * 0.76, h), c + Vector2(-w * 0.76, h)], s), col, 1),
		P(capsule(c + Vector2(-w - 2, 0), c + Vector2(w + 2, 0), 5.5, s + 1), col.lightened(0.15), 1)]

static func _arc_band(c: Vector2, r: float, th: float, a0: float, a1: float, s: int) -> PackedVector2Array:
	var arr := []
	for k in 13:
		var a := lerpf(a0, a1, float(k) / 12.0)
		arr.append(c + Vector2(cos(a), sin(a)) * (r + th))
	for k in 13:
		var a := lerpf(a1, a0, float(k) / 12.0)
		arr.append(c + Vector2(cos(a), sin(a)) * (r - th))
	return poly(arr, s, 0.6)

static func _basket(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			sil(ci, [P(ell(Vector2(0, 8), Vector2(34, 26), s, 0.04), ROPE.darkened(0.08)),
				P(capsule(Vector2(26, 0), Vector2(40, -30), 4.0, s + 1), ROPE.darkened(0.08), 2)], rim)
			var arr := []
			for k in 60:
				var t := float(k) / 59.0
				var a := t * TAU * 3.2
				arr.append(Vector2(0, 8) + Vector2(cos(a) * 30.0, sin(a) * 22.0) * (1.0 - t * 0.85))
			pl(ci, arr, 2.0, Color(0.4, 0.22, 0.05, 0.7), s)
		2:
			sil(ci, _basket_body(Vector2(0, -2), 30, 36, s), rim)
			_weave(ci, Rect2(-24, 6, 48, 28), s)
		3:
			var parts := [P(_arc_band(Vector2(0, -6), 30, 4.0, PI * 1.05, PI * 1.95, s), WOOD_D, 1)]
			parts.append_array(_basket_body(Vector2(0, -6), 38, 44, s + 2))
			sil(ci, parts, rim)
			_weave(ci, Rect2(-32, 2, 64, 36), s)
		_:
			var parts := [P(_arc_band(Vector2(0, -10), 36, 4.5, PI * 1.05, PI * 1.95, s), WOOD_D, 1),
				P(ell(Vector2(-22, -18), Vector2(16, 7), s + 1, 0.05, 12, -0.8), LEAF, 1),
				P(ell(Vector2(22, -20), Vector2(16, 7), s + 2, 0.05, 12, 0.8), LEAF, 1),
				_bry(Vector2(-6, -16), 10, s + 3), _bry(Vector2(10, -14), 9, s + 4),
				P(ell(Vector2(-24, -8), Vector2(8, 6), s + 5, 0.1), STONE)]
			parts.append_array(_basket_body(Vector2(0, -8), 44, 48, s + 6, WOOD.darkened(0.05)))
			sil(ci, parts, rim)
			_weave(ci, Rect2(-38, 0, 76, 40), s)

static func _hunt(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			sil(ci, [P(capsule(Vector2(-34, 36), Vector2(30, -32), 6.5, s), WOOD, 1),
				P(capsule(Vector2(4, -4), Vector2(18, -22), 3.0, s + 1), WOOD, 2),
				P(ell(Vector2(22, -26), Vector2(10, 5), s + 2, 0.05, 12, -0.6), LEAF, 1)], rim)
			ci.draw_circle(Vector2(-12, 12), 2.5, WOOD_D)
			ci.draw_circle(Vector2(10, -10), 2.0, WOOD_D)
		2:
			var tip := poly([Vector2(22, -24), Vector2(34, -44), Vector2(30, -18)], s)
			tip = poly([Vector2(20, -22), Vector2(26, -36), Vector2(40, -42), Vector2(34, -28), Vector2(28, -18)], s)
			sil(ci, [P(capsule(Vector2(-38, 40), Vector2(24, -24), 3.6, s + 1), WOOD, 2), P(tip, Color("8f8a82"), 1)], rim)
			_rope(ci, Vector2(-38, 40), Vector2(24, -24), 0.9, 2, 5.0, s)
			ln(ci, Vector2(-30, 32), Vector2(-24, 38), 3.0, CLAY, s)
		3:
			var bow := _arc_band(Vector2(16, 0), 40, 4.0, PI * 0.62, PI * 1.38, s)
			sil(ci, [P(bow, WOOD, 1),
				P(capsule(Vector2(-30, 0), Vector2(34, 0), 2.5, s + 1), WOOD.lightened(0.2), 2),
				P(poly([Vector2(34, -7), Vector2(48, 0), Vector2(34, 7)], s + 2), STONE_D, 1),
				P(poly([Vector2(-36, -9), Vector2(-24, -1), Vector2(-24, 1), Vector2(-36, 9), Vector2(-30, 0)], s + 3), CLAY, 1)], rim)
			var top := Vector2(16, 0) + Vector2(cos(PI * 0.62), sin(PI * 0.62)) * 40.0
			var bot := Vector2(16, 0) + Vector2(cos(PI * 1.38), sin(PI * 1.38)) * 40.0
			ln(ci, top, Vector2(-14, 0), 1.6, INK, s)
			ln(ci, Vector2(-14, 0), bot, 1.6, INK, s + 2)
		_:
			var arr := []
			for k in 13:
				var t := float(k) / 12.0
				var a := lerpf(PI * 0.9, PI * 2.05, t)
				var r := lerpf(14.0, 4.0, t)
				arr.append(Vector2(0, 8) + Vector2(cos(a), sin(a)) * 32.0 + Vector2(cos(a), sin(a)) * r)
			for k in 13:
				var t := 1.0 - float(k) / 12.0
				var a := lerpf(PI * 0.9, PI * 2.05, t)
				var r := lerpf(14.0, 4.0, t)
				arr.append(Vector2(0, 8) + Vector2(cos(a), sin(a)) * 32.0 - Vector2(cos(a), sin(a)) * r)
			sil(ci, [P(poly(arr, s), Color("eedcae"), 1)], rim)
			for i in 3:
				var a := lerpf(PI * 1.05, PI * 1.7, float(i) / 2.0)
				var r1 := lerpf(14.0, 4.0, (a - PI * 0.9) / (PI * 1.15))
				var c := Vector2(0, 8) + Vector2(cos(a), sin(a)) * 32.0
				ln(ci, c + Vector2(cos(a), sin(a)) * r1, c - Vector2(cos(a), sin(a)) * r1, 3.5, WOOD_D, s + i)
			pl(ci, [Vector2(-30, 12), Vector2(-6, 34), Vector2(24, 30), Vector2(36, 12)], 2.5, CLAY, s)

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
		_:
			var parts := [P(flame_pts(Vector2(0, -10), 30, 80, s), FIRE, 1),
				P(capsule(Vector2(-36, 32), Vector2(30, 14), 7.0, s + 1), WOOD, 1),
				P(capsule(Vector2(36, 32), Vector2(-30, 14), 7.0, s + 2), WOOD.darkened(0.08), 1)]
			for i in 5:
				parts.append(P(ell(Vector2(-36 + 18 * i, 38), Vector2(9, 6), s + 3 + i, 0.1), STONE))
			sil(ci, parts, rim)
			ci.draw_colored_polygon(flame_pts(Vector2(0, 2), 16, 46, s + 3), FIRE2)
			ci.draw_colored_polygon(flame_pts(Vector2(0, 12), 7, 20, s + 5), Color(1, 1, 0.85))

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

static func _shell(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			sil(ci, [P(_scallop(Vector2(0, -2), 30, 0.0, s), SHELL)], rim)
			_scallop_det(ci, Vector2(0, -2), 30, 0.0, s)
		2:
			var cs := [Vector2(-24, 4), Vector2(0, 14), Vector2(24, 4)]
			var rs := [-0.3, 0.0, 0.3]
			var parts := []
			for i in 3:
				parts.append(P(_scallop(cs[i], 15, rs[i], s + i), SHELL if i != 1 else SHELL.lightened(0.05)))
			sil(ci, parts, rim)
			pl(ci, [Vector2(-42, -26), Vector2(-24, -8), Vector2(0, -2), Vector2(24, -8), Vector2(42, -26)], 2.5, WOOD_D, s)
			for i in 3:
				_scallop_det(ci, cs[i], 15, rs[i], s + i)
		_:
			var cs := [Vector2(-22, 18), Vector2(22, 18), Vector2(0, 20), Vector2(-12, -4), Vector2(14, -2), Vector2(0, -22)]
			var rs := [-0.4, 0.4, 0.0, -0.2, 0.25, 0.0]
			var parts := []
			for i in cs.size():
				parts.append(P(_scallop(cs[i], 17, rs[i], s + i), SHELL.darkened(0.04 * float(i % 3))))
			sil(ci, parts, rim)
			for i in cs.size():
				_scallop_det(ci, cs[i], 17, rs[i], s + i)

static func _amber(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	match lv:
		1:
			sil(ci, [P(ell(Vector2(-4, 4), Vector2(20, 24), s, 0.08, 18, 0.3), AMBER), P(ell(Vector2(20, 20), Vector2(9, 10), s + 1, 0.08, 14), AMBER.darkened(0.08))], rim)
		2:
			var pts := poly([Vector2(-34, 4), Vector2(-20, -28), Vector2(14, -34), Vector2(34, -6), Vector2(24, 28), Vector2(-14, 32)], s)
			sil(ci, [P(pts, AMBER, 1)], rim)
			ci.draw_colored_polygon(poly([Vector2(-20, -28), Vector2(14, -34), Vector2(0, -6)], s + 3), Color(1, 0.9, 0.5, 0.6))
			ci.draw_colored_polygon(poly([Vector2(-34, 4), Vector2(-20, -28), Vector2(0, -6)], s + 4), Color(1, 0.8, 0.3, 0.5))
			for v in [Vector2(-20, -28), Vector2(14, -34), Vector2(34, -6), Vector2(-34, 4), Vector2(-14, 32)]:
				ln(ci, Vector2(0, -6), v, 1.6, Color(0.5, 0.25, 0.0, 0.7), s)
		_:
			sil(ci, [P(ell(Vector2(0, 2), Vector2(38, 34), s, 0.1, 22), AMBER)], rim)
			ci.draw_colored_polygon(ell(Vector2(4, 6), Vector2(11, 6), s + 2, 0.0, 12, 0.4), Color(0.25, 0.12, 0.0, 0.8))
			ci.draw_circle(Vector2(-7, 2), 5.0, Color(0.25, 0.12, 0.0, 0.8))
			for i in 3:
				ln(ci, Vector2(-2 + 7 * i, 4), Vector2(-8 + 9 * i, 18), 1.5, Color(0.25, 0.12, 0.0, 0.8), s + i)
				ln(ci, Vector2(-2 + 7 * i, 6), Vector2(-4 + 9 * i, -8), 1.5, Color(0.25, 0.12, 0.0, 0.8), s + i + 5)
			ci.draw_colored_polygon(ell(Vector2(-6, -12), Vector2(12, 6), s + 4, 0.0, 12, -0.5), Color(1, 1, 0.9, 0.4))
			ci.draw_colored_polygon(ell(Vector2(-14, -16), Vector2(10, 5), s + 4, 0.0, 12, -0.5), Color(1, 0.95, 0.7, 0.45))

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
