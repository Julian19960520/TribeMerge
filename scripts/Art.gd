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
	# 宝箱、卡包、道具和四种资源都已改回 draw_item 现场绘制再烘焙成 PNG，不再走 SVG
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
	_outer = Transform2D(rot, Vector2.ONE * (size / 100.0), 0.0, c)
	if not _nested:
		ci.draw_colored_polygon(ell(Vector2(0, 40), Vector2(30, 6), 1, 0.0, 14, 0.0, 0.0), Color(0.2, 0.1, 0.0, 0.18))
	var s: int = abs(ch.hash()) % 97 + lv * 7
	match ch:
		"fire", "shell", "amber", "sand": _currency(ci, ch, lv, s, rim)
		"chest", "energybox", "premiumbox", "orderbox": _box(ci, ch, lv, s, rim)
		"choice": _choice_box(ci, id, lv, s, rim)
		"pack": _pack(ci, lv, s, rim)
		"upgrade": _upgrade(ci, s, rim)
		"scissors": _scissors(ci, s, rim)
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

# ---------------------------------------------------------------- 四种可领取资源
## 体力（闪电）、不拿拿（香蕉）、琥珀、沙漏共用一套等级排布：
## 1 级零件（不能领取）→ 2 级一整个 → 3 级两个 → 4 级四个 → 5 级一堆 → 6 级一筐。
## 每种资源只写「一个单位」的画法（_cur_parts 外形 + _cur_detail 细节），排布由 _cur_layout 决定。
const BANANA := Color("ffd447")
const BANANA_D := Color("c9962a")
const BOLT := Color("ffd23f")
const SAND_GLASS := Color("e3f3f1")
const SAND_FILL := Color("f2c35a")
const RIM_COL := Color(1, 0.98, 0.92, 0.96)

## 当前单位的局部→物品坐标变换。单位形状按「k = 1 时约 60 大小」画在原点附近，再经它摆到位置上。
static var _ut := Transform2D.IDENTITY

static func _X(pts: PackedVector2Array) -> PackedVector2Array:
	return _ut * pts

static func _Xv(v: Vector2) -> Vector2:
	return _ut * v

## 整体大小随等级变大（1 级最小、6 级占满格子），不因为一级只画一个就放大
const _CUR_G := [0.0, 0.66, 0.74, 0.84, 0.91, 0.97, 1.0]

static func _currency(ci: CanvasItem, ch: String, lv: int, s: int, rim: bool) -> void:
	lv = clampi(lv, 1, 6)
	if ch == "sand":
		_hourglass_item(ci, lv, s, rim)
		return
	var g: float = _CUR_G[lv]
	var drop := (1.0 - g) * 24.0
	if lv == 6:
		for k in 2:
			ci.draw_circle(Vector2(0, -6), 50.0 - 8.0 * k, Color(1, 0.88, 0.45, 0.14))
	var units := _cur_layout(ch, lv)
	for u in units:
		u[0] = u[0] * g + Vector2(0, drop)
		u[1] = u[1] * g
	var per: Array = []
	var ks: Array = []
	for i in units.size():
		var u: Array = units[i]
		_ut = Transform2D(u[2], Vector2(u[1], u[1]), 0.0, u[0])
		per.append(_cur_parts(ch, lv == 1, s + i * 7))
		ks.append(u[1])
	var basket := _cur_basket(s + 60) if lv == 6 else []
	if rim:
		for parts in per:
			for p in parts:
				dilate(ci, p[0], 9.0, RIM_COL)
		for p in basket:
			dilate(ci, p[0], 9.0, RIM_COL)
	if lv == 6:
		# 筐口里面的暗色
		var mouth := ell(Vector2(0, 2), Vector2(42, 10), s + 70, 0.03, 20)
		dilate(ci, mouth, 3.0, INK)
		ci.draw_colored_polygon(mouth, WOOD_D.darkened(0.35))
	for i in units.size():
		var u: Array = units[i]
		sil(ci, per[i], false)
		_ut = Transform2D(u[2], Vector2(u[1], u[1]), 0.0, u[0])
		_cur_detail(ci, ch, lv == 1, s + i * 7, ks[i])
	_ut = Transform2D.IDENTITY
	if lv == 6:
		sil(ci, basket, false)
		_weave(ci, Rect2(-34, 10, 68, 27), s + 61)
		pl(ci, [Vector2(-38, 4), Vector2(0, 7), Vector2(38, 4)], 2.0, ROPE.lightened(0.2), s + 62)
	if lv >= 5:
		var glints := [Vector2(-44, -30), Vector2(42, -42), Vector2(48, -10)] if lv == 6 else [Vector2(-38, -22), Vector2(36, -30)]
		for v in glints:
			ci.draw_colored_polygon(star_pts(v, 6, 2, 4, s + int(v.x)), Color(1, 1, 0.9))

## 每个单位：[中心, 缩放, 旋转]，按先后画（后画的压在上面）
static func _cur_layout(ch: String, lv: int) -> Array:
	match lv:
		1:
			if ch == "shell":
				# 半截不拿拿的重心在左边，挪回格子中间
				return [[Vector2(19, -5), 1.15, -0.35]]
			return [[Vector2(0, 2), 1.15, 0.0]]
		2:
			if ch == "shell":
				# 单根不拿拿斜着放（顶栏、订单里的资源图标就是它）
				return [[Vector2(-2, 6), 1.15, -0.62]]
			return [[Vector2(0, 0), 1.18, 0.08 if ch == "fire" else 0.0]]
		3:
			if ch == "shell":
				return [[Vector2(4, -10), 0.86, -0.22], [Vector2(-2, 10), 0.9, 0.08]]
			return [[Vector2(14, -6), 0.82, 0.16], [Vector2(-13, 6), 0.84, -0.14]]
		4:
			if ch == "shell":
				return [[Vector2(6, -24), 0.72, -0.42], [Vector2(8, -6), 0.74, -0.14],
					[Vector2(4, 10), 0.75, 0.12], [Vector2(-4, 26), 0.76, 0.36]]
			return [[Vector2(-15, -15), 0.64, -0.2], [Vector2(16, -13), 0.64, 0.22],
				[Vector2(-16, 14), 0.66, 0.1], [Vector2(15, 16), 0.66, -0.12]]
		5:
			var k := 0.56 if ch != "shell" else 0.56
			return [[Vector2(-30, 20), k, -0.12], [Vector2(0, 22), k, 0.06], [Vector2(30, 20), k, 0.18],
				[Vector2(-16, 0), k, -0.28], [Vector2(16, 0), k, 0.3],
				[Vector2(1, -20), k, -0.05]]
		_:
			var k := 0.6 if ch != "shell" else 0.6
			return [[Vector2(-24, -16), k, -0.35], [Vector2(24, -16), k, 0.35],
				[Vector2(-10, -32), k, -0.15], [Vector2(13, -36), k, 0.18],
				[Vector2(0, -14), k, 0.0]]

## 6 级的藤筐（前半截，盖住筐里东西的下半部）
static func _cur_basket(s: int) -> Array:
	var body := poly([Vector2(-42, 4), Vector2(42, 4), Vector2(32, 40), Vector2(-32, 40)], s, 0.6)
	var lip := capsule(Vector2(-44, 4), Vector2(44, 4), 6.0, s + 1)
	return [P(body, WOOD, 1), P(lip, WOOD.lightened(0.15), 1)]

static func _cur_parts(ch: String, frag: bool, s: int) -> Array:
	match ch:
		"fire":
			_ut = _ut * Transform2D(0.0, Vector2(1.3, 1.0), 0.0, Vector2.ZERO)
			return _bolt_parts(frag, s)
		"shell": return _banana_parts(frag, s)
		_: return _amber_parts(frag, s)

static func _cur_detail(ci: CanvasItem, ch: String, frag: bool, s: int, k: float) -> void:
	match ch:
		"fire":
			_ut = _ut * Transform2D(0.0, Vector2(1.3, 1.0), 0.0, Vector2.ZERO)
			_bolt_detail(ci, frag, s, k)
		"shell": _banana_detail(ci, frag, s, k)
		_: _amber_detail(ci, frag, s, k)

static func _lw(w: float, k: float) -> float:
	return w * clampf(k, 0.65, 1.2)

# ---------- 体力：闪电

const _BOLT := [Vector2(-5, -31), Vector2(14, -31), Vector2(5, -9), Vector2(18, -9), Vector2(-8, 32), Vector2(-2, 5), Vector2(-16, 5)]

static func _bolt_parts(frag: bool, s: int) -> Array:
	if frag:
		# 断下来的上半截闪电 + 两粒碎渣
		var top := poly([Vector2(-5, -27), Vector2(14, -27), Vector2(5, -5), Vector2(11, -5), Vector2(7, 1), Vector2(2, -2),
			Vector2(-2, 4), Vector2(-6, 0), Vector2(-12, 4)], s, 0.5)
		var c1 := poly([Vector2(10, 12), Vector2(18, 9), Vector2(15, 18)], s + 1, 0.3)
		var c2 := poly([Vector2(-8, 16), Vector2(-2, 14), Vector2(-4, 21)], s + 2, 0.3)
		return [P(_X(top), BOLT, 1), P(_X(c1), BOLT.darkened(0.06), 2), P(_X(c2), BOLT, 2)]
	return [P(_X(poly(_BOLT, s, 0.5)), BOLT, 1)]

static func _bolt_detail(ci: CanvasItem, frag: bool, s: int, k: float) -> void:
	var hl := Color(1, 1, 0.88, 0.9)
	if frag:
		ci.draw_polyline(_X(poly([Vector2(5, -23), Vector2(-4, -2)], s + 3, 0.3)), hl, _lw(3.0, k), true)
		ci.draw_polyline(_X(poly([Vector2(0, -2), Vector2(4, -4)], s + 4, 0.2)), INK, _lw(1.6, k), true)
		return
	ci.draw_polyline(_X(poly([Vector2(6, -26), Vector2(-6, 1), Vector2(-10, 1)], s + 3, 0.3)), hl, _lw(3.0, k), true)
	ci.draw_polyline(_X(poly([Vector2(12, -5), Vector2(0, 18)], s + 4, 0.3)), Color(1, 0.6, 0.1, 0.55), _lw(2.6, k), true)

# ---------- 不拿拿：香蕉

## 香蕉弧：t 从 0（梗那头，左）到 1（尖，右），弯成一个笑脸弧
static func _banana_pt(t: float, side: float) -> Vector2:
	var a := lerpf(PI * 0.86, PI * 0.14, t)
	var th := 3.0 + 10.0 * pow(sin(PI * clampf(t * 0.92 + 0.04, 0.0, 1.0)), 0.7)
	return Vector2(0, -34) + Vector2(cos(a), sin(a)) * (40.0 + th * side) + Vector2(0, 6)

static func _banana_body(t0: float, t1: float, s: int) -> PackedVector2Array:
	var arr := []
	var n := 14
	for i in n + 1:
		arr.append(_banana_pt(lerpf(t0, t1, float(i) / n), 1.0))
	for i in range(n, -1, -1):
		arr.append(_banana_pt(lerpf(t0, t1, float(i) / n), -1.0))
	return poly(arr, s, 0.4)

static func _banana_stem_dir() -> Vector2:
	return (_banana_pt(0.0, 0.0) - _banana_pt(0.06, 0.0)).normalized()

static func _banana_parts(frag: bool, s: int) -> Array:
	var stem_a := _banana_pt(0.0, 0.0)
	var stem := capsule(stem_a - _banana_stem_dir() * 2.0, stem_a + _banana_stem_dir() * 9.0 + Vector2(0, -2), 3.4, s + 1)
	if frag:
		# 半截不拿拿：梗那一半，断口露出果肉
		return [P(_X(_banana_body(0.0, 0.52, s)), BANANA, 1), P(_X(stem), LEAF_D.lerp(WOOD, 0.5), 1)]
	return [P(_X(_banana_body(0.0, 1.0, s)), BANANA, 1), P(_X(stem), LEAF_D.lerp(WOOD, 0.5), 1)]

static func _banana_detail(ci: CanvasItem, frag: bool, s: int, k: float) -> void:
	var t1 := 0.52 if frag else 1.0
	# 中间的棱
	var ridge := []
	for i in 9:
		ridge.append(_banana_pt(lerpf(0.12, t1 - 0.1, float(i) / 8.0), 0.15))
	ci.draw_polyline(_X(poly(ridge, s + 2, 0.3)), BANANA_D, _lw(1.8, k), true)
	# 背上的高光
	var hl := []
	for i in 7:
		hl.append(_banana_pt(lerpf(0.2, t1 - 0.18, float(i) / 6.0), -0.55))
	ci.draw_polyline(_X(poly(hl, s + 3, 0.2)), Color(1, 1, 0.9, 0.8), _lw(2.6, k), true)
	if frag:
		# 断口：奶白果肉 + 中间一点籽
		var a := _banana_pt(t1, 1.0)
		var b := _banana_pt(t1, -1.0)
		var c := (a + b) * 0.5
		var cut := ell(c, Vector2(a.distance_to(b) * 0.5, 4.5), s + 4, 0.06, 12, (b - a).angle(), 0.3)
		var cx := _X(cut)
		ci.draw_colored_polygon(cx, BONE)
		outline(ci, cx, 2.0, INK)
		ci.draw_circle(_Xv(c), 1.6 * k, SEED.darkened(0.2))
	else:
		# 尖上的小黑头
		var tip := _banana_pt(1.0, 0.0)
		ci.draw_colored_polygon(_X(ell(tip + Vector2(1.5, -1), Vector2(3.2, 2.6), s + 5, 0.0, 8)), Color("4a2a12"))
		# 梗上的切口
		var st := _banana_pt(0.0, 0.0) + _banana_stem_dir() * 9.0 + Vector2(0, -2)
		ci.draw_colored_polygon(_X(ell(st, Vector2(2.6, 2.6), s + 6, 0.0, 8)), Color("6a8a2a"))

# ---------- 琥珀：刻面宝石

const _AMB := [Vector2(-25, 2), Vector2(-14, -21), Vector2(10, -25), Vector2(25, -6), Vector2(18, 20), Vector2(-8, 25)]

static func _amber_parts(frag: bool, s: int) -> Array:
	if frag:
		# 碎琥珀：一大一小两块断片
		var a := poly([Vector2(-20, 4), Vector2(-10, -18), Vector2(8, -14), Vector2(4, -2), Vector2(10, 8), Vector2(-6, 16)], s, 0.4)
		var b := poly([Vector2(12, 6), Vector2(22, 0), Vector2(26, 14), Vector2(16, 20)], s + 1, 0.4)
		return [P(_X(a), AMBER, 1), P(_X(b), AMBER.darkened(0.06), 1)]
	return [P(_X(poly(_AMB, s, 0.5)), AMBER, 1)]

static func _amber_detail(ci: CanvasItem, frag: bool, s: int, k: float) -> void:
	if frag:
		ci.draw_colored_polygon(_X(poly([Vector2(-10, -18), Vector2(8, -14), Vector2(-4, -4)], s + 3)), Color(1, 0.9, 0.5, 0.6))
		ci.draw_polyline(_X(poly([Vector2(4, -2), Vector2(-4, -4), Vector2(-12, 2)], s + 4, 0.3)), Color(0.5, 0.25, 0.0, 0.7), _lw(1.6, k), true)
		ci.draw_colored_polygon(_X(ell(Vector2(-10, -6), Vector2(4, 2.4), s + 5, 0.0, 8, -0.7)), Color(1, 1, 0.92, 0.75))
		return
	var core := Vector2(-1, -5)
	ci.draw_colored_polygon(_X(poly([_AMB[1], _AMB[2], core], s + 3)), Color(1, 0.9, 0.5, 0.65))
	ci.draw_colored_polygon(_X(poly([_AMB[0], _AMB[1], core], s + 4)), Color(1, 0.8, 0.3, 0.5))
	ci.draw_colored_polygon(_X(poly([_AMB[4], _AMB[5], core], s + 6)), Color(0.75, 0.38, 0.0, 0.35))
	for i in [0, 1, 2, 3, 4, 5]:
		ci.draw_line(_Xv(core), _Xv(_AMB[i]), Color(0.5, 0.25, 0.0, 0.6), _lw(1.5, k), true)
	if k >= 0.8:
		# 只有大一点的单块才看得清封在里面的小虫
		_amber_bug(ci, _Xv(Vector2(3, 8)), 9.0 * k, 0.55, s)
	ci.draw_colored_polygon(_X(ell(Vector2(-12, -10), Vector2(6, 3.2), s + 5, 0.0, 10, -0.8)), Color(1, 1, 0.92, 0.8))
	ci.draw_circle(_Xv(Vector2(-4, -16)), 1.8 * k, Color(1, 1, 0.92, 0.85))

## 封在琥珀里的小虫：sz 是身长，a 是清晰度
static func _amber_bug(ci: CanvasItem, c: Vector2, sz: float, a: float, s: int) -> void:
	var body := Color(0.24, 0.11, 0.0, 0.85 * a)
	var wing := Color(1, 0.97, 0.85, 0.42 * a)
	var k := sz / 30.0
	var w := maxf(1.0, 1.6 * k)
	for sx in [-1.0, 1.0]:
		ci.draw_colored_polygon(ell(c + Vector2(9 * sx, -6) * k, Vector2(10, 5) * k, s + 20 + int(sx), 0.0, 12, -0.5 * sx, 0.15), wing)
		for i in 3:
			var o := c + Vector2(0, -2 + i * 5) * k
			ln(ci, o, o + Vector2(sx * 11, -4 + i * 5) * k, w, body, s + i)
	ci.draw_colored_polygon(ell(c + Vector2(0, 8) * k, Vector2(5.5, 8) * k, s + 30, 0.0, 12, 0.0, 0.15), body)
	ci.draw_colored_polygon(ell(c + Vector2(0, -2) * k, Vector2(4.5, 4) * k, s + 31, 0.0, 10, 0.0, 0.15), body)
	ci.draw_circle(c + Vector2(0, -9) * k, 3.4 * k, body)

# ---------- 沙漏：木框沙漏

const _HG_H := 30.0
const _HG_W := 16.0
const _HG_CAP := 8.0
const _HG_NECK := 2.8

static func _hg_sand_mound(inner: float, w: float, neck: float, top_y: float, s: int) -> PackedVector2Array:
	var mound := PackedVector2Array()
	var base := inner - 2.0
	for k in 13:
		var x := lerpf(-1.0, 1.0, float(k) / 12.0)
		var y := lerpf(top_y + inner * 0.22, top_y, 1.0 - absf(x))
		mound.append(Vector2(x * _hg_half(y / inner, w, neck), y))
	for k in range(1, 7):
		var y := lerpf(top_y + inner * 0.22, base, float(k) / 6.0)
		mound.append(Vector2(_hg_half(y / inner, w, neck), y))
	for k in range(6, 0, -1):
		var y := lerpf(top_y + inner * 0.22, base, float(k) / 6.0)
		mound.append(Vector2(-_hg_half(y / inner, w, neck), y))
	return poly(Array(mound), s, 0.2)

# ---------- 沙漏：始终只有一个沙漏，越往上越华丽、越大
## 1 零件 → 2 两块木盖夹住玻璃（还没装立柱）→ 3 素木立柱 → 4 立柱缠草绳 → 5 深木骨珠 → 6 金饰宝石
## 各级：[缩放, 顶底盖颜色, 立柱颜色]
const _HG_LV := [
	[],
	[0.0, WOOD, WOOD_D],
	[0.94, WOOD, WOOD_D],
	[1.04, WOOD, WOOD_D],
	[1.14, Color("c48548"), WOOD_D],
	[1.26, Color("6e4326"), Color("5a3620")],
	[1.38, Color("e0a526"), Color("b97a1a")],
]

static func _hourglass_item(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	if lv == 1:
		_hg_kit(ci, s, rim)
		return
	var cfg: Array = _HG_LV[lv]
	var k: float = cfg[0]
	var cap_col: Color = cfg[1]
	var post_col: Color = cfg[2]
	_ut = Transform2D(0.0, Vector2(k, k), 0.0, Vector2(0, (1.38 - k) * 16.0))
	var inner := _HG_H - _HG_CAP
	var cw := _HG_W + (4.0 if lv == 2 else 8.0) + (2.0 if lv >= 5 else 0.0)
	var px := _HG_W + 3.0
	var parts := [P(_X(_hourglass_pts(inner, _HG_W, _HG_NECK, 0.0)), SAND_GLASS, 1)]
	if lv >= 3:
		for x in [-px, px]:
			parts.append(P(_X(capsule(Vector2(x, -inner), Vector2(x, inner), 3.0 if lv < 5 else 3.6, s + int(x))), post_col, 1))
	if lv >= 5:
		# 四角的圆头：5 级骨珠，6 级金珠
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				var knob := ell(Vector2(cw * sx * 0.82, sy * (_HG_H + 2.0)), Vector2(4.2, 4.2), s + 20 + int(sx * 2 + sy), 0.05, 10)
				parts.append(P(_X(knob), BONE if lv == 5 else FIRE2, 1))
	parts.append(P(_X(rrect(Rect2(-cw, -_HG_H, cw * 2.0, _HG_CAP), 3.5, s + 1, 0.3)), cap_col, 1))
	parts.append(P(_X(rrect(Rect2(-cw, _HG_H - _HG_CAP, cw * 2.0, _HG_CAP), 3.5, s + 2, 0.3)), cap_col, 1))
	sil(ci, parts, rim)
	_hg_glass(ci, inner, lv, s, k)
	# 立柱中段：4、5 级缠草绳，6 级套金箍
	if lv >= 4:
		for x in [-px, px]:
			if lv >= 6:
				for yy in [-inner * 0.45, 0.0, inner * 0.45]:
					var ring := rrect(Rect2(x - 4.6, yy - 2.4, 9.2, 4.8), 2.0, s + 40, 0.2)
					dilate(ci, _X(ring), 1.4, INK)
					ci.draw_colored_polygon(_X(ring), FIRE2.lightened(0.15))
			else:
				for i in 4:
					var y := -6.0 + i * 4.0
					var a := _Xv(Vector2(x - 4, y - 1.5))
					var b := _Xv(Vector2(x + 4, y + 1.5))
					ci.draw_line(a, b, INK, 4.0, true)
					ci.draw_line(a, b, ROPE, 2.4, true)
	# 顶底盖上的花样
	for sy in [-1.0, 1.0]:
		var yc: float = sy * (_HG_H - _HG_CAP * 0.5)
		if lv == 4:
			ci.draw_polyline(_X(poly([Vector2(-cw + 4, yc), Vector2(cw - 4, yc)], s + 50, 0.3)), ROPE, 2.2, true)
		elif lv == 5:
			var zz := []
			for i in 9:
				zz.append(Vector2(-cw + 6 + i * (cw * 2.0 - 12.0) / 8.0, yc + (2.0 if i % 2 == 0 else -2.0)))
			ci.draw_polyline(_X(poly(zz, s + 51, 0.2)), OCHRE, 2.2, true)
		elif lv == 6:
			ci.draw_line(_Xv(Vector2(-cw + 5, yc - 2.2)), _Xv(Vector2(cw - 5, yc - 2.2)), Color(1, 1, 0.85, 0.75), 2.0, true)
			var gc := Vector2(0, yc)
			var gem := poly([gc + Vector2(0, -4.6), gc + Vector2(6, 0), gc + Vector2(0, 4.6), gc + Vector2(-6, 0)], s + 52, 0.1)
			dilate(ci, _X(gem), 1.4, INK)
			ci.draw_colored_polygon(_X(gem), BERRY)
	_ut = Transform2D.IDENTITY

## 玻璃里的沙、细沙流、玻璃描边和高光
static func _hg_glass(ci: CanvasItem, inner: float, _lv: int, s: int, _k: float) -> void:
	var w := _HG_W
	var sand := SAND_FILL
	ci.draw_colored_polygon(_X(_hourglass_pts(inner, w - 3.0, _HG_NECK - 1.0, 0.0, -inner * 0.5, -inner * 0.06)), sand)
	var top_y := inner * 0.38
	ci.draw_colored_polygon(_X(_hg_sand_mound(inner, w - 3.0, _HG_NECK - 1.0, top_y, s + 5)), sand)
	ci.draw_line(_Xv(Vector2(0, -inner * 0.08)), _Xv(Vector2(0, top_y + 2.0)), sand.darkened(0.08), 2.0, true)
	outline(ci, _X(_hourglass_pts(inner, w, _HG_NECK, 0.0)), 2.2, INK)
	ci.draw_polyline(_X(poly([Vector2(-w * 0.62, -inner * 0.82), Vector2(-w * 0.78, -inner * 0.55), Vector2(-w * 0.55, -inner * 0.25)], s + 6, 0.2)), Color(1, 1, 1, 0.85), 2.4, true)
	ci.draw_polyline(_X(poly([Vector2(-w * 0.62, inner * 0.3), Vector2(-w * 0.78, inner * 0.55)], s + 7, 0.2)), Color(1, 1, 1, 0.7), 2.4, true)

## 1 级：还没装起来的零件——一只空玻璃泡、一块木盖、一根木柱、一小撮沙
static func _hg_kit(ci: CanvasItem, s: int, rim: bool) -> void:
	var inner := _HG_H - _HG_CAP
	var gt := Transform2D(0.9, Vector2(0.62, 0.62), 0.0, Vector2(-4, -2))
	var glass := gt * _hourglass_pts(inner, _HG_W, _HG_NECK, 0.0)
	var cap := Transform2D(-0.08, Vector2.ONE, 0.0, Vector2(4, 22)) * rrect(Rect2(-17, -3.5, 34, 7), 3.0, s + 1, 0.3)
	var post := capsule(Vector2(18, -22), Vector2(24, 14), 2.8, s + 2)
	var pile := poly([Vector2(-28, 22), Vector2(-22, 13), Vector2(-15, 11), Vector2(-9, 16), Vector2(-6, 22)], s + 3, 0.3)
	sil(ci, [P(post, WOOD_D, 1), P(cap, WOOD, 1), P(glass, SAND_GLASS, 1), P(pile, SAND_FILL, 1)], rim)
	# 玻璃泡底下残留一点沙、高光
	ci.draw_colored_polygon(gt * _hg_sand_mound(inner, _HG_W - 3.0, _HG_NECK - 1.0, inner * 0.62, s + 5), SAND_FILL)
	outline(ci, glass, 2.2, INK)
	ci.draw_polyline(gt * poly([Vector2(-_HG_W * 0.62, -inner * 0.8), Vector2(-_HG_W * 0.78, -inner * 0.5)], s + 6, 0.2), Color(1, 1, 1, 0.85), 2.2, true)
	for i in 3:
		ci.draw_circle(Vector2(-2 + i * 5, 14 + (i % 2) * 3), 1.4, SAND_FILL.darkened(0.12))

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

# ---------------------------------------------------------------- 宝箱、卡包、道具
## 宝箱一律合着盖，每种宝箱一个外形：藤编宝箱 = 圆顶藤箱、体力宝箱 = 木桶、高级宝箱 = 尖顶匣、
## 订单补给箱 = 木板条箱、自选宝箱 = 三个小窗的箱子。正面的徽章画着里面会出的东西。
## 档次一眼区分：1 素 → 2 草绳箍 → 3 铜箍铆钉 → 4 深色箱身 + 金箍 + 宝石 → 5 金饰 + 皇冠 + 光晕星光。
const BOX_PURPLE := Color("8a5cc9")
const BOX_TRIM := [Color("7a4a22"), Color("7a4a22"), Color("e6c98a"), Color("c9803a"), Color("f0b93a"), Color("f7cf4a")]
const BOX_SCALE := [0.0, 0.8, 0.86, 0.92, 0.97, 1.0]

## draw_item 外层的「局部→画布」变换，嵌套画小物品时用
static var _outer := Transform2D.IDENTITY
static var _nested := false

static func _sub_item(ci: CanvasItem, id: String, p: Vector2, sz: float, rot: float = 0.0) -> void:
	var t := _outer
	var was := _nested
	_nested = true
	draw_item(ci, id, t * p, sz * t.get_scale().x, true, t.get_rotation() + rot)
	_nested = was
	_outer = t
	ci.draw_set_transform_matrix(t)

## 整体随档次略微变大：先改 _outer，画完换回
static func _box_begin(ci: CanvasItem, tier: int) -> Transform2D:
	var prev := _outer
	var g: float = BOX_SCALE[tier]
	_outer = prev * Transform2D(0.0, Vector2(g, g), 0.0, Vector2(0, (1.0 - g) * 30.0))
	ci.draw_set_transform_matrix(_outer)
	if tier >= 5:
		for k in 2:
			ci.draw_circle(Vector2(0, -4), 54.0 - 9.0 * k, Color(1, 0.86, 0.4, 0.16))
	return prev

static func _box_end(ci: CanvasItem, tier: int, prev: Transform2D, s: int) -> void:
	if tier >= 5:
		for v in [Vector2(-48, -30), Vector2(46, -40), Vector2(50, 10)]:
			ci.draw_colored_polygon(star_pts(v, 7, 2.2, 4, s + int(v.x)), Color(1, 1, 0.9))
	_outer = prev
	ci.draw_set_transform_matrix(prev)

static func _box(ci: CanvasItem, ch: String, lv: int, s: int, rim: bool) -> void:
	var tier := clampi(lv, 1, 5)
	var prev := _box_begin(ci, tier)
	match ch:
		"energybox": _box_barrel(ci, tier, s, rim)
		"premiumbox": _box_casket(ci, tier, s, rim)
		"orderbox": _box_crate(ci, tier, lv, s, rim)
		_: _box_trunk(ci, tier, s, rim)
	_box_end(ci, tier, prev, s)

## 竖着的箍带（跟着箱子上沿的高度 top 起）
static func _strap(ci: CanvasItem, x: float, top_l: float, top_r: float, bottom: float, w: float, col: Color, tier: int, s: int) -> void:
	var b := poly([Vector2(x - w * 0.5, top_l), Vector2(x + w * 0.5, top_r), Vector2(x + w * 0.5, bottom), Vector2(x - w * 0.5, bottom)], s, 0.3)
	dilate(ci, b, 2.0, INK)
	ci.draw_colored_polygon(b, col)
	if tier >= 4:
		ci.draw_line(Vector2(x - w * 0.18, maxf(top_l, top_r) + 2), Vector2(x - w * 0.18, bottom - 3), Color(1, 1, 0.85, 0.6), 2.0, true)
	elif tier == 2:
		var y := minf(top_l, top_r) + 4.0
		while y < bottom - 3.0:
			ci.draw_line(Vector2(x - w * 0.5, y), Vector2(x + w * 0.5, y + 3.0), Color(0.45, 0.3, 0.12, 0.6), 1.4, true)
			y += 5.0

static func _studs(ci: CanvasItem, pts: Array, col: Color) -> void:
	for v in pts:
		ci.draw_circle(v, 3.4, INK)
		ci.draw_circle(v, 2.2, col.lightened(0.3))

## 正面徽章：圆牌，边框颜色跟档次
static func _emblem(ci: CanvasItem, c: Vector2, r: float, tier: int, s: int) -> void:
	var e := ell(c, Vector2(r, r), s, 0.03, 18)
	dilate(ci, e, 2.4, INK)
	ci.draw_colored_polygon(e, BOX_TRIM[tier] if tier >= 3 else WOOD_D)
	var f := ell(c, Vector2(r - 3.4, r - 3.4), s + 1, 0.03, 18)
	ci.draw_colored_polygon(f, BONE if tier < 4 else Color("fff3c4"))
	outline(ci, f, 1.4, Color(0, 0, 0, 0.3))

static func _icon_bolt(ci: CanvasItem, c: Vector2, k: float) -> void:
	var b := PackedVector2Array()
	for p in _BOLT: b.append(c + p * Vector2(k * 1.2, k))
	dilate(ci, b, 1.6, INK)
	ci.draw_colored_polygon(b, BOLT)
	ci.draw_line(c + Vector2(5, -27) * Vector2(k * 1.2, k), c + Vector2(-5, 1) * Vector2(k * 1.2, k), Color(1, 1, 0.88, 0.9), 1.6, true)

static func _icon_amber(ci: CanvasItem, c: Vector2, k: float) -> void:
	var a := PackedVector2Array()
	for p in _AMB: a.append(c + p * k)
	dilate(ci, a, 1.6, INK)
	ci.draw_colored_polygon(a, AMBER)
	ci.draw_colored_polygon(PackedVector2Array([c + _AMB[1] * k, c + _AMB[2] * k, c + Vector2(-1, -5) * k]), Color(1, 0.9, 0.5, 0.7))
	ci.draw_circle(c + Vector2(-9, -8) * k, 2.2, Color(1, 1, 0.92, 0.85))

## 4 级起箱顶的宝石钮，5 级换成小皇冠
static func _box_crown(c: Vector2, tier: int, s: int) -> Array:
	if tier >= 5:
		var cr := poly([c + Vector2(-11, 4), c + Vector2(-12, -8), c + Vector2(-5, -2), c + Vector2(0, -11), c + Vector2(5, -2), c + Vector2(12, -8), c + Vector2(11, 4)], s, 0.2)
		return [P(cr, FIRE2, 1)]
	if tier == 4:
		return [P(poly([c + Vector2(0, -8), c + Vector2(7, 0), c + Vector2(0, 7), c + Vector2(-7, 0)], s, 0.2), BERRY, 1)]
	return []

# ---------- 藤编宝箱：圆顶藤箱，徽章里是一颗果子（会出各种产线物品和资源）

static func _dome_y(x: float) -> float:
	return -2.0 - 24.0 * sqrt(maxf(0.0, 1.0 - pow(x / 40.0, 2.0)))

static func _box_trunk(ci: CanvasItem, tier: int, s: int, rim: bool) -> void:
	var col := Color("c08a4a")
	if tier == 4: col = col.darkened(0.25)
	var trim: Color = BOX_TRIM[tier]
	var body := rrect(Rect2(-38, -2, 76, 40), 6, s, 0.5)
	var dome := []
	for i in 15:
		var x := lerpf(-40.0, 40.0, float(i) / 14.0)
		dome.append(Vector2(x, _dome_y(x)))
	var lid := poly(dome, s + 1, 0.4)
	var lip := rrect(Rect2(-41, -6, 82, 9), 4, s + 2, 0.3)
	var parts := [P(body, col, 1), P(lid, col.lightened(0.1), 1), P(lip, trim if tier >= 2 else col.darkened(0.25), 1)]
	parts.append_array(_box_crown(Vector2(0, -27), tier, s + 3))
	sil(ci, parts, rim)
	_weave(ci, Rect2(-32, 6, 64, 28), s + 4)
	for f in [0.42, 0.74]:
		var arc := []
		for i in 11:
			var x: float = lerpf(-34.0, 34.0, float(i) / 10.0) * (0.55 + f * 0.45)
			arc.append(Vector2(x, -4.0 - 22.0 * f * sqrt(maxf(0.0, 1.0 - pow(x / 38.0, 2.0)))))
		ci.draw_polyline(poly(arc, s + 5, 0.3), Color(0.35, 0.18, 0.05, 0.5), 1.8, true)
	if tier >= 2:
		for x in [-25.0, 25.0]:
			_strap(ci, x, _dome_y(x - 4.5) + 1.0, _dome_y(x + 4.5) + 1.0, 38.0, 9.0, trim, tier, s + 6 + int(x))
	if tier >= 3:
		_studs(ci, [Vector2(-25, 8), Vector2(25, 8), Vector2(-25, 30), Vector2(25, 30)], trim)
	_box_lock(ci, Vector2(0, 4), tier, s + 8)

# ---------- 体力宝箱：木桶，徽章是闪电

static func _barrel_hw(y: float) -> float:
	return 29.0 + 6.0 * sin(PI * (y + 28.0) / 66.0)

static func _box_barrel(ci: CanvasItem, tier: int, s: int, rim: bool) -> void:
	var col := Color("d9773a")
	if tier == 4: col = col.darkened(0.3)
	var trim: Color = BOX_TRIM[tier]
	var right := []
	var left := []
	for i in 13:
		var y := lerpf(-28.0, 38.0, float(i) / 12.0)
		right.append(Vector2(_barrel_hw(y), y))
		left.append(Vector2(-_barrel_hw(y), y))
	left.reverse()
	var body := poly(right + left, s, 0.5)
	var top := ell(Vector2(0, -28), Vector2(_barrel_hw(-28.0), 7.5), s + 1, 0.02, 20)
	var parts := [P(body, col, 1), P(top, col.darkened(0.15), 0)]
	parts.append_array(_box_crown(Vector2(0, -33), tier, s + 2))
	sil(ci, parts, rim)
	# 桶板
	for x0 in [-0.68, -0.34, 0.34, 0.68]:
		var st := []
		for i in 9:
			var y := lerpf(-21.0, 36.0, float(i) / 8.0)
			st.append(Vector2(x0 * _barrel_hw(y), y))
		ci.draw_polyline(poly(st, s + 3, 0.3), Color(0.3, 0.12, 0.02, 0.4), 1.8, true)
	ci.draw_colored_polygon(ell(Vector2(0, -28), Vector2(_barrel_hw(-28.0) - 6, 4), s + 4, 0.02, 16), col.darkened(0.3))
	# 桶箍：1 级藤条，2 级草绳，3 级铜，4、5 级金
	var hoop_col: Color = WOOD_D if tier == 1 else trim
	var ys := [-18.0, 28.0] if tier < 4 else [-18.0, 5.0, 28.0]
	for y in ys:
		if tier >= 4 and y == 5.0: continue
		var hw := _barrel_hw(y) + 0.5
		var h := poly([Vector2(-hw, y - 3.5), Vector2(0, y - 1.5), Vector2(hw, y - 3.5), Vector2(hw, y + 3.5), Vector2(0, y + 5.5), Vector2(-hw, y + 3.5)], s + 5 + int(y), 0.2)
		dilate(ci, h, 2.0, INK)
		ci.draw_colored_polygon(h, hoop_col)
		if tier >= 4:
			ci.draw_line(Vector2(-hw + 4, y - 2), Vector2(hw - 4, y - 2), Color(1, 1, 0.85, 0.6), 1.6, true)
	if tier >= 3:
		_studs(ci, [Vector2(-22, -17), Vector2(22, -17), Vector2(-22, 29), Vector2(22, 29)], trim)
	_emblem(ci, Vector2(0, 6), 17.0, tier, s + 8)
	_icon_bolt(ci, Vector2(0, 6), 0.36)

# ---------- 高级宝箱：紫色尖顶匣，徽章是琥珀

static func _box_casket(ci: CanvasItem, tier: int, s: int, rim: bool) -> void:
	var col := BOX_PURPLE
	if tier == 4: col = col.darkened(0.3)
	var trim: Color = BOX_TRIM[tier]
	var parts := []
	if tier >= 4:
		for x in [-28.0, 28.0]:
			parts.append(P(ell(Vector2(x, 39), Vector2(6, 5), s + int(x), 0.05, 10), trim, 1))
	var body := rrect(Rect2(-36, 2, 72, 36), 6, s, 0.5)
	var lid := poly([Vector2(-39, 4), Vector2(39, 4), Vector2(29, -20), Vector2(-29, -20)], s + 1, 0.5)
	var ridge := rrect(Rect2(-31, -26, 62, 8), 3.5, s + 2, 0.3)
	var lip := rrect(Rect2(-40, -1, 80, 8), 3.5, s + 3, 0.3)
	parts.append_array([P(body, col, 1), P(lid, col.lightened(0.1), 1), P(ridge, trim if tier >= 2 else col.darkened(0.25), 1), P(lip, trim if tier >= 2 else col.darkened(0.25), 1)])
	parts.append_array(_box_crown(Vector2(0, -30), tier, s + 4))
	sil(ci, parts, rim)
	ci.draw_colored_polygon(poly([Vector2(-30, 0), Vector2(30, 0), Vector2(24, -16), Vector2(-24, -16)], s + 5, 0.3), col.lightened(0.22))
	ci.draw_colored_polygon(rrect(Rect2(-30, 10, 60, 22), 4, s + 6, 0.3), col.darkened(0.12))
	if tier >= 2:
		for x in [-22.0, 22.0]:
			_strap(ci, x, -19.0, -19.0, 38.0, 8.0, trim, tier, s + 7 + int(x))
	if tier >= 3:
		# 四角包铜
		for c in [[Vector2(-36, 38), 1.0, -1.0], [Vector2(36, 38), -1.0, -1.0], [Vector2(-36, 2), 1.0, 1.0], [Vector2(36, 2), -1.0, 1.0]]:
			var o: Vector2 = c[0]
			var t := poly([o, o + Vector2(12 * c[1], 0), o + Vector2(0, 12 * c[2])], s + 8, 0.2)
			dilate(ci, t, 1.6, INK)
			ci.draw_colored_polygon(t, trim)
	var ec := Vector2(0, 17)
	var plate := poly([ec + Vector2(0, -19), ec + Vector2(18, 0), ec + Vector2(0, 19), ec + Vector2(-18, 0)], s + 9, 0.3)
	dilate(ci, plate, 2.4, INK)
	ci.draw_colored_polygon(plate, BOX_TRIM[tier] if tier >= 3 else WOOD_D)
	ci.draw_colored_polygon(poly([ec + Vector2(0, -15), ec + Vector2(14, 0), ec + Vector2(0, 15), ec + Vector2(-14, 0)], s + 10, 0.2), BONE if tier < 4 else Color("fff3c4"))
	_icon_amber(ci, ec + Vector2(0, 1), 0.38)

# ---------- 订单补给箱：5 级。包角木箱，两侧草绳提手，正面钉着盖了红蜡封的订单。
## 里面是订单正缺的东西，所以 1 级就带金属包角，比别的箱子起步更讲究。

static func _box_crate(ci: CanvasItem, tier: int, _lv: int, s: int, rim: bool) -> void:
	var col := Color("a8693a")
	if tier == 4: col = Color("6b3f22")
	var metal: Color = [Color(), Color("9a948a"), Color("9a948a"), Color("c9803a"), Color("f0b93a"), Color("f7cf4a")][tier]
	var body := rrect(Rect2(-37, -18, 74, 56), 5, s, 0.5)
	var lid := rrect(Rect2(-40, -30, 80, 15), 5, s + 1, 0.4)
	var parts := [P(body, col, 1), P(lid, col.lightened(0.12), 1)]
	parts.append_array(_box_crown(Vector2(0, -34), tier, s + 2))
	sil(ci, parts, rim)
	# 两侧草绳提手
	for sx in [-1.0, 1.0]:
		var hc := Vector2(37 * sx, 8)
		var a0 := -PI * 0.5 if sx > 0.0 else PI * 0.5
		ci.draw_arc(hc, 8.0, a0, a0 + PI, 12, INK, 6.0, true)
		ci.draw_arc(hc, 8.0, a0, a0 + PI, 12, ROPE, 3.4, true)
	# 木板缝 + 盖子上的木纹
	for y in [2.0, 20.0]:
		ln(ci, Vector2(-34, y), Vector2(34, y), 1.8, Color(0.25, 0.12, 0.04, 0.45), s + int(y))
	ln(ci, Vector2(-36, -22), Vector2(36, -22), 1.6, Color(0.25, 0.12, 0.04, 0.3), s + 3)
	ci.draw_line(Vector2(-34, -27), Vector2(34, -27), Color(1, 1, 1, 0.25), 2.0, true)
	# 竖箍：3 级起
	if tier >= 3:
		for x in [-26.0, 26.0]:
			_strap(ci, x, -30.0, -30.0, 38.0, 7.0, metal, tier, s + 4 + int(x))
	# 四角包角（每级都有，材质逐级：铁 → 铜 → 金）
	for c in [[Vector2(-37, -30), 1.0, 1.0], [Vector2(37, -30), -1.0, 1.0], [Vector2(-37, 38), 1.0, -1.0], [Vector2(37, 38), -1.0, -1.0]]:
		var o: Vector2 = c[0]
		var t := poly([o, o + Vector2(15 * c[1], 0), o + Vector2(15 * c[1], 5 * c[2]), o + Vector2(5 * c[1], 5 * c[2]), o + Vector2(5 * c[1], 15 * c[2]), o + Vector2(0, 15 * c[2])], s + 5, 0.2)
		dilate(ci, t, 1.6, INK)
		ci.draw_colored_polygon(t, metal)
		ci.draw_circle(o + Vector2(3 * c[1], 3 * c[2]), 1.5, metal.darkened(0.45))
	if tier >= 2:
		_studs(ci, [Vector2(-31, -9), Vector2(31, -9), Vector2(-31, 30), Vector2(31, 30)], metal)
	# 订单纸 + 红蜡封
	var paper := poly([Vector2(-15, -12), Vector2(15, -13), Vector2(16, 30), Vector2(-16, 31)], s + 6, 0.4)
	dilate(ci, paper, 2.0, INK)
	ci.draw_colored_polygon(paper, BONE if tier < 4 else Color("fff3c4"))
	ci.draw_circle(Vector2(0, -11), 3.0, INK)
	ci.draw_circle(Vector2(0, -11), 2.0, metal)
	for i in 3:
		var y := -3.0 + i * 8.0
		pl(ci, [Vector2(-11, y), Vector2(-8, y + 3), Vector2(-3, y - 3)], 2.2, LEAF_D, s + 7 + i)
		ln(ci, Vector2(1, y), Vector2(11, y), 1.8, Color(0.3, 0.2, 0.1, 0.6), s + 10 + i)
	var wax := ell(Vector2(9, 26), Vector2(7, 6.5), s + 13, 0.12, 12)
	ci.draw_colored_polygon(poly([Vector2(5, 29), Vector2(8, 38), Vector2(10, 31)], s + 14, 0.1), BERRY.darkened(0.2))
	ci.draw_colored_polygon(poly([Vector2(10, 30), Vector2(14, 37), Vector2(13, 29)], s + 15, 0.1), BERRY.darkened(0.2))
	dilate(ci, wax, 1.6, INK)
	ci.draw_colored_polygon(wax, BERRY)
	ci.draw_colored_polygon(star_pts(Vector2(9, 26), 3.6, 1.6, 5, s + 16), Color(1, 0.75, 0.75, 0.8))

## 自选宝箱：合着盖的青色箱子，正面只有锁扣（选什么点开再看）
static func _choice_box(ci: CanvasItem, _id: String, lv: int, s: int, rim: bool) -> void:
	var tier := clampi(lv, 1, 5)
	var prev := _box_begin(ci, tier)
	var col := TEAL.darkened(0.25) if tier == 4 else TEAL
	var trim: Color = BOX_TRIM[tier]
	var body := rrect(Rect2(-42, -6, 84, 44), 6, s, 0.5)
	var lid := rrect(Rect2(-44, -26, 88, 24), 11, s + 1, 0.5)
	var parts := [P(body, col, 1), P(lid, col.lightened(0.12), 1)]
	parts.append_array(_box_crown(Vector2(0, -30), tier, s + 2))
	sil(ci, parts, rim)
	ln(ci, Vector2(-40, -4), Vector2(40, -4), 2.0, Color(0, 0, 0, 0.3), s + 3)
	if tier >= 2:
		for x in [-40.0, 40.0]:
			_strap(ci, x, -24.0, -24.0, 38.0, 6.0, trim, tier, s + 4 + int(x))
	if tier >= 3:
		_studs(ci, [Vector2(-40, -16), Vector2(40, -16), Vector2(-40, 30), Vector2(40, 30)], trim)
	# 箱身两道浅色木纹
	for y in [10.0, 26.0]:
		ln(ci, Vector2(-34, y), Vector2(34, y), 1.6, Color(0, 0, 0, 0.18), s + int(y))
	_box_lock(ci, Vector2(0, -2), tier, s + 5)
	_box_end(ci, tier, prev, s)

## 正面锁扣：上面一片搭扣，下面锁身带钥匙孔
static func _box_lock(ci: CanvasItem, c: Vector2, tier: int, s: int) -> void:
	var col: Color = BOX_TRIM[tier] if tier >= 3 else OCHRE
	var hasp := rrect(Rect2(c.x - 5, c.y - 10, 10, 10), 3, s, 0.2)
	dilate(ci, hasp, 1.8, INK)
	ci.draw_colored_polygon(hasp, col.darkened(0.15))
	var body := rrect(Rect2(c.x - 10, c.y - 2, 20, 18), 5, s + 1, 0.2)
	dilate(ci, body, 2.2, INK)
	ci.draw_colored_polygon(body, col)
	ci.draw_line(c + Vector2(-6, 1), c + Vector2(6, 1), Color(1, 1, 0.85, 0.6), 1.6, true)
	ci.draw_circle(c + Vector2(0, 6), 2.6, INK)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-1.6, 7), c + Vector2(1.6, 7), c + Vector2(2.2, 12), c + Vector2(-2.2, 12)]), INK)
	if tier >= 4:
		var gem := poly([c + Vector2(0, -16), c + Vector2(4.5, -12), c + Vector2(0, -8), c + Vector2(-4.5, -12)], s + 2, 0.1)
		dilate(ci, gem, 1.4, INK)
		ci.draw_colored_polygon(gem, BERRY)

## 典藏卡包：系口的兽皮袋（1 级就是最早那只），中间圆章上的星星数 = 等级。
## 往上袋子越来越讲究：2 级绿边 → 3 级蓝边 + 骨珠穗 → 4 级深皮 + 紫边 + 羽毛 + 金线 → 5 级金皮 + 宝石 + 光晕
const PACK_SEAL := [Color(), Color("eaa53c"), Color("5f9e43"), Color("3f7fc0"), Color("8a5cc9"), Color("e0a526")]
const PACK_BODY := [Color(), Color("c98f55"), Color("c98f55"), Color("bf8450"), Color("8e5634"), Color("b8452f")]

static func _pack(ci: CanvasItem, lv: int, s: int, rim: bool) -> void:
	lv = clampi(lv, 1, 5)
	var prev := _box_begin(ci, lv)
	var col: Color = PACK_BODY[lv]
	var seal: Color = PACK_SEAL[lv]
	var parts := []
	if lv >= 4:
		# 袋口插两根羽毛
		for sx in [-1.0, 1.0]:
			var f := ell(Vector2(14 * sx, -47), Vector2(4.2, 9.5), s + 40 + int(sx), 0.05, 12, 0.55 * sx)
			parts.append(P(f, BERRY if sx < 0.0 else TEAL, 1))
	parts.append(P(rrect(Rect2(-32, -28, 64, 68), 14, s, 0.7), col, 1))
	parts.append(P(poly([Vector2(-22, -28), Vector2(-14, -42), Vector2(14, -42), Vector2(22, -28)], s + 1), col.darkened(0.1), 1))
	sil(ci, parts, rim)
	if lv >= 4:
		for sx in [-1.0, 1.0]:
			ci.draw_line(Vector2(10 * sx, -40), Vector2(19 * sx, -55), Color(1, 1, 1, 0.75), 1.3, true)
	# 底边彩色滚边（2 级起，颜色跟星级）
	if lv >= 2:
		var hem := poly([Vector2(-31, 22), Vector2(31, 22), Vector2(30, 32), Vector2(22, 39), Vector2(-22, 39), Vector2(-30, 32)], s + 2, 0.3)
		ci.draw_colored_polygon(hem, seal)
		ci.draw_polyline(poly([Vector2(-31, 22), Vector2(31, 22)], s + 3, 0.3), INK, 2.0, true)
		for i in 7:
			var x := -24.0 + i * 8.0
			ci.draw_colored_polygon(poly([Vector2(x - 3, 26), Vector2(x + 3, 26), Vector2(x, 31)], s + 4 + i, 0.1), seal.lightened(0.35))
	dashed(ci, rrect(Rect2(-26, -22, 52, 56), 10, s, 0.0), 5, 4, FIRE2 if lv >= 4 else BONE, 2.0)
	pl(ci, [Vector2(-24, -30), Vector2(0, -26), Vector2(24, -30)], 3.0, FIRE2 if lv >= 5 else ROPE, s)
	# 3 级起，绳头挂骨珠穗
	if lv >= 3:
		var bead: Color = BONE if lv == 3 else (TEAL if lv == 4 else BERRY)
		for sx in [-1.0, 1.0]:
			pl(ci, [Vector2(20 * sx, -29), Vector2(30 * sx, -22), Vector2(33 * sx, -10)], 2.0, ROPE, s + 5)
			for k in 2:
				var c := Vector2((31 + k) * sx, -20 + k * 8)
				ci.draw_circle(c, 4.0, INK)
				ci.draw_circle(c, 2.8, bead)
	# 圆章：1 级赭石兽爪印；2 级起换成等级颜色的星章
	var c := Vector2(0, 6)
	var r := 18.0 if lv == 1 else 20.0
	if lv >= 5:
		for i in 4:
			var a := PI * 0.25 + i * PI * 0.5
			var gp := c + Vector2(cos(a), sin(a)) * (r + 2.0)
			var gem := poly([gp + Vector2(0, -5), gp + Vector2(5, 0), gp + Vector2(0, 5), gp + Vector2(-5, 0)], s + 50 + i, 0.1)
			dilate(ci, gem, 1.4, INK)
			ci.draw_colored_polygon(gem, BERRY)
	var disc := ell(c, Vector2(r, r), s + 2, 0.02)
	dilate(ci, disc, 3.0, INK)
	ci.draw_colored_polygon(disc, seal)
	if lv == 1:
		ci.draw_circle(c + Vector2(0, 5), 6.0, INK)
		for i in 4:
			var a := -PI * 0.5 + (float(i) - 1.5) * 0.55
			ci.draw_circle(c + Vector2(0, 5) + Vector2(cos(a), sin(a)) * 11.0, 3.2, INK)
	else:
		ci.draw_arc(c, r - 3.5, 0.0, TAU, 28, seal.lightened(0.3), 1.6, true)
		for p in _pack_star_pos(lv):
			var st := star_pts(c + p[0], p[1], p[1] * 0.45, 5, s + 30)
			dilate(ci, st, 1.5, INK)
			ci.draw_colored_polygon(st, Color("ffe27a"))
	_box_end(ci, lv, prev, s)

## 圆章里 n 颗星的位置和大小
static func _pack_star_pos(n: int) -> Array:
	match n:
		2: return [[Vector2(-7, 0), 7.5], [Vector2(7, 0), 7.5]]
		3: return [[Vector2(0, -7), 6.8], [Vector2(-8, 5), 6.8], [Vector2(8, 5), 6.8]]
		4: return [[Vector2(-7, -6), 6.2], [Vector2(7, -6), 6.2], [Vector2(-7, 7), 6.2], [Vector2(7, 7), 6.2]]
		_:
			var out := [[Vector2(0, 1), 5.8]]
			for i in 4:
				var a := -PI * 0.75 + i * PI * 0.5
				out.append([Vector2(cos(a), sin(a)) * 10.5 + Vector2(0, 1), 5.2])
			return out

## 升阶符石：竖立的青色刻石，正面刻着发光的向上箭头
static func _upgrade(ci: CanvasItem, s: int, rim: bool) -> void:
	for k in 2:
		ci.draw_circle(Vector2(0, -4), 46.0 - 8.0 * k, Color(0.6, 1, 0.9, 0.14))
	var stone := poly([Vector2(-24, -30), Vector2(-6, -42), Vector2(20, -36), Vector2(28, -6), Vector2(24, 34), Vector2(-22, 36), Vector2(-30, 4)], s, 0.6)
	sil(ci, [P(stone, TEAL, 1)], rim)
	ci.draw_colored_polygon(poly([Vector2(-24, -30), Vector2(-6, -42), Vector2(-4, -20), Vector2(-26, 0)], s + 1, 0.3), Color(1, 1, 1, 0.22))
	var arrow := poly([Vector2(0, -28), Vector2(17, -6), Vector2(7, -6), Vector2(7, 22), Vector2(-7, 22), Vector2(-7, -6), Vector2(-17, -6)], s + 2, 0.4)
	dilate(ci, arrow, 3.0, Color(1, 0.95, 0.6, 0.45))
	dilate(ci, arrow, 1.6, INK)
	ci.draw_colored_polygon(arrow, FIRE2)
	ci.draw_colored_polygon(poly([Vector2(0, -24), Vector2(10, -10), Vector2(3, -10), Vector2(3, 18), Vector2(0, 18)], s + 3, 0.2), Color(1, 1, 0.85, 0.7))
	pl(ci, [Vector2(-18, 28), Vector2(-12, 24), Vector2(-6, 29)], 1.6, Color(0.1, 0.3, 0.3, 0.6), s + 4)
	pl(ci, [Vector2(14, 26), Vector2(19, 18)], 1.6, Color(0.1, 0.3, 0.3, 0.6), s + 5)
	for v in [Vector2(-34, -30), Vector2(34, -40), Vector2(36, 18)]:
		ci.draw_colored_polygon(star_pts(v, 6, 2, 4, s + int(v.x)), Color(1, 1, 0.9))

## 拆分剪刀：两片燧石刃，木柄绑草绳，中间骨钉
static func _scissors(ci: CanvasItem, s: int, rim: bool) -> void:
	var parts := []
	var blades := []
	for sx in [-1.0, 1.0]:
		var a: float = 0.42 * sx
		var blade := rot_pts([Vector2(-4, 4), Vector2(-5, -18), Vector2(0, -44), Vector2(5, -18), Vector2(4, 4)], a, Vector2(0, -2))
		var handle_c := Vector2(0, 26).rotated(-a) + Vector2(0, -2)
		var shaft := capsule(Vector2(0, -2), handle_c, 4.5, s + 2 + int(sx))
		var ring := ell(handle_c + Vector2(0, 6).rotated(-a), Vector2(11, 9), s + 4 + int(sx), 0.05, 16, -a)
		blades.append(poly(blade, s + int(sx), 0.4))
		parts.append(P(ring, WOOD, 1))
		parts.append(P(shaft, WOOD, 1))
	parts.append(P(blades[0], STONE, 1))
	parts.append(P(blades[1], STONE.lightened(0.08), 1))
	sil(ci, parts, rim)
	# 指环中间的洞
	for sx in [-1.0, 1.0]:
		var a: float = 0.42 * sx
		var handle_c := Vector2(0, 26).rotated(-a) + Vector2(0, -2)
		var hole := ell(handle_c + Vector2(0, 6).rotated(-a), Vector2(5.5, 4), s + 8 + int(sx), 0.05, 12, -a)
		ci.draw_colored_polygon(hole, INK)
		# 柄上缠的草绳
		for k in 3:
			var p := Vector2(0, 8 + k * 4).rotated(-a) + Vector2(0, -2)
			ln(ci, p + Vector2(-5, 0).rotated(-a), p + Vector2(5, 2).rotated(-a), 2.2, ROPE, s + 10 + k)
	# 刃口高光与崩口
	for sx in [-1.0, 1.0]:
		var a: float = 0.42 * sx
		var h := rot_pts([Vector2(-1.5, -6), Vector2(-1.5, -34)], a, Vector2(0, -2))
		ln(ci, h[0], h[1], 2.0, Color(1, 1, 1, 0.6), s + 12)
	var pin := ell(Vector2(0, -2), Vector2(5, 5), s + 14, 0.05, 10)
	dilate(ci, pin, 1.8, INK)
	ci.draw_colored_polygon(pin, BONE)

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
