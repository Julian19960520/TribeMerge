class_name Paint
extends RefCounted
const Meme := preload("res://scripts/Meme.gd")
## 界面部件、角色、卡牌与村庄的程序化绘制。

const BTN := {
	"green": [Color("8cc63f"), Color("4f8a1f"), Color("c3ea7a")],
	"orange": [Color("f4a933"), Color("b9661a"), Color("ffd98a")],
	"grey": [Color("c2bbaf"), Color("847d72"), Color("e3ddd2")],
	"teal": [Color("4fb3a6"), Color("2a7469"), Color("8fe0d4")],
	"red": [Color("dd5a33"), Color("8f2e15"), Color("ff9a72")],
	"wood": [Color("c98b4a"), Color("7a4a22"), Color("e8b67a")],
	"hide": [Color("f6e7c8"), Color("c9a774"), Color("fffaf0")],
}

static func button(ci: CanvasItem, r: Rect2, style: String, seed: int = 0, pressed: bool = false) -> void:
	var cols: Array = BTN.get(style, BTN["green"])
	var rad: float = min(r.size.y * 0.5, 30.0)
	var depth: float = 0.0 if pressed else 7.0
	ci.draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(2, 6), r.size), rad, seed, 0.0), Color(0, 0, 0, 0.28))
	var base := Art.rrect(r, rad, seed, 0.7)
	Art.dilate(ci, base, 3.0, Art.INK)
	ci.draw_colored_polygon(base, cols[1])
	var top_r := Rect2(r.position + Vector2(0, 7.0 - depth), r.size - Vector2(0, 7))
	ci.draw_colored_polygon(Art.rrect(top_r, rad, seed + 1, 0.7), cols[0])
	var hl := Rect2(top_r.position + Vector2(rad * 0.6, 5), Vector2(top_r.size.x - rad * 1.2, top_r.size.y * 0.26))
	ci.draw_colored_polygon(Art.rrect(hl, hl.size.y * 0.5, seed + 2, 0.4), Color(cols[2], 0.75))
	for i in 7:
		var p := r.position + Vector2(Art.srnd(seed * 7 + i) * r.size.x * 0.8 + r.size.x * 0.1, Art.srnd(seed * 11 + i) * r.size.y * 0.5 + r.size.y * 0.35)
		ci.draw_circle(p, 1.5 + Art.srnd(i + seed) * 1.5, Color(0, 0, 0, 0.08))

static func round_btn(ci: CanvasItem, c: Vector2, rad: float, style: String, seed: int = 0) -> void:
	var cols: Array = BTN.get(style, BTN["teal"])
	ci.draw_colored_polygon(Art.ell(c + Vector2(0, 6), Vector2(rad, rad), seed, 0.0, 24, 0.0, 0.0), Color(0, 0, 0, 0.28))
	var base := Art.ell(c, Vector2(rad, rad), seed, 0.02, 24)
	Art.dilate(ci, base, 3.0, Art.INK)
	ci.draw_colored_polygon(base, cols[1])
	ci.draw_colored_polygon(Art.ell(c - Vector2(0, 3), Vector2(rad - 2, rad - 4), seed + 1, 0.02, 24), cols[0])
	ci.draw_colored_polygon(Art.ell(c + Vector2(-rad * 0.3, -rad * 0.45), Vector2(rad * 0.4, rad * 0.2), seed + 2, 0.0, 14, -0.4), Color(cols[2], 0.7))

static func panel(ci: CanvasItem, r: Rect2, seed: int = 1) -> void:
	ci.draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(0, 12), r.size), 28, seed, 0.0), Color(0, 0, 0, 0.35))
	var outer := Art.rrect(r, 28, seed, 1.0)
	Art.dilate(ci, outer, 3.0, Art.INK)
	ci.draw_colored_polygon(outer, Art.LEATHER)
	ci.draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(0, r.size.y * 0.5), Vector2(r.size.x, r.size.y * 0.5)), 28, seed + 5, 0.0), Color(0, 0, 0, 0.08))
	Art.dashed(ci, Art.rrect(r.grow(-7), 22, seed + 3, 0.0), 11, 7, Color("f3d7a2"), 2.2)
	var ir := r.grow(-16)
	var inner := Art.rrect(ir, 16, seed + 2, 1.0)
	ci.draw_colored_polygon(inner, Art.HIDE)
	for i in 46:
		var p := ir.position + Vector2(Art.srnd(i * 3 + seed) * ir.size.x, Art.srnd(i * 7 + seed + 1) * ir.size.y)
		ci.draw_circle(p, 2.0 + Art.srnd(i + 3) * 7.0, Color(0.6, 0.38, 0.15, 0.05))
	Art.outline(ci, inner, 2.5, Art.LEATHER_D)
	var bl := ir.position + Vector2(ir.size.x, ir.size.y)
	ci.draw_colored_polygon(Art.poly([bl + Vector2(-34, 0), bl + Vector2(0, -34), bl + Vector2(-8, -8)], seed), Art.HIDE2)
	Art.outline(ci, Art.poly([bl + Vector2(-34, 0), bl + Vector2(0, -34), bl + Vector2(-8, -8)], seed), 2.0, Art.LEATHER_D)
	_ornament(ci, Vector2(ir.get_center().x, ir.end.y - 18), seed)

static func _ornament(ci: CanvasItem, c: Vector2, seed: int) -> void:
	var col := Color(0.55, 0.36, 0.18, 0.45)
	ci.draw_colored_polygon(Art.star_pts(c, 7, 3, 4, seed), col)
	Art.pl(ci, [c + Vector2(-14, 0), c + Vector2(-30, -4), c + Vector2(-46, 0)], 2.0, col, seed)
	Art.pl(ci, [c + Vector2(14, 0), c + Vector2(30, -4), c + Vector2(46, 0)], 2.0, col, seed + 1)
	ci.draw_circle(c + Vector2(-54, 0), 3.0, col)
	ci.draw_circle(c + Vector2(54, 0), 3.0, col)

static func banner(ci: CanvasItem, r: Rect2, col: Color, seed: int = 2) -> void:
	ci.draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(0, 8), r.size), 16, seed, 0.0), Color(0, 0, 0, 0.3))
	var body := Art.rrect(r, 16, seed, 1.0)
	Art.dilate(ci, body, 3.0, Art.INK)
	ci.draw_colored_polygon(body, Art.OCHRE)
	var ir := r.grow(-7)
	ci.draw_colored_polygon(Art.rrect(ir, 11, seed + 1, 0.8), col)
	ci.draw_colored_polygon(Art.rrect(Rect2(ir.position + Vector2(10, 4), Vector2(ir.size.x - 20, ir.size.y * 0.3)), 8, seed + 2, 0.5), Color(1, 1, 1, 0.18))
	for i in 3:
		var y := ir.position.y + ir.size.y * (0.35 + 0.22 * float(i))
		Art.pl(ci, [Vector2(ir.position.x + 50, y), Vector2(ir.get_center().x - 60 + 30 * i, y + 2), Vector2(ir.end.x - 50, y)], 1.5, Color(0, 0, 0, 0.1), seed + i)
	for side in [0, 1]:
		var x: float = r.position.x + 24.0 if side == 0 else r.end.x - 24.0
		for k in 3:
			var xx := x + (float(k) - 1.0) * 7.0
			Art.ln(ci, Vector2(xx - 4, r.position.y - 2), Vector2(xx + 4, r.end.y + 2), 6.0, Art.INK, seed + k + side * 5)
			Art.ln(ci, Vector2(xx - 4, r.position.y - 2), Vector2(xx + 4, r.end.y + 2), 3.6, Art.ROPE, seed + k + side * 5)
		var dx: float = 52.0 if side == 0 else -52.0
		ci.draw_colored_polygon(Art.star_pts(Vector2(x + dx, r.get_center().y), 7, 3, 4, seed + side), Color(1, 1, 1, 0.55))

## 图鉴里还没领的新发现：红礼盒。
static func gift(ci: CanvasItem, c: Vector2, s: float) -> void:
	var w := s * 0.62
	var h := s * 0.48
	var box := Rect2(c + Vector2(-w * 0.5, -h * 0.22), Vector2(w, h))
	var body := Art.rrect(box, 8, 9, 0.4)
	Art.dilate(ci, body, 3.0, Art.INK)
	ci.draw_colored_polygon(body, Art.CLAY)
	var lid := Art.rrect(Rect2(box.position + Vector2(-4, -s * 0.14), Vector2(w + 8, s * 0.2)), 6, 10, 0.35)
	Art.dilate(ci, lid, 3.0, Art.INK)
	ci.draw_colored_polygon(lid, Color("e15a38"))
	ci.draw_rect(Rect2(c.x - s * 0.045, box.position.y, s * 0.09, h), Art.OCHRE)
	ci.draw_rect(Rect2(box.position.x, box.position.y + s * 0.04, w, s * 0.08), Art.OCHRE)
	ci.draw_colored_polygon(Art.ell(c + Vector2(-s * 0.12, -s * 0.24), Vector2(s * 0.12, s * 0.07), 11, 0.15, 12, 0.35), Art.OCHRE)
	ci.draw_colored_polygon(Art.ell(c + Vector2(s * 0.12, -s * 0.24), Vector2(s * 0.12, s * 0.07), 12, 0.15, 12, -0.35), Art.OCHRE)
	ci.draw_circle(c + Vector2(0, -s * 0.2), s * 0.055, Art.OCHRE)
	ci.draw_circle(c + Vector2(0, -s * 0.2), s * 0.055, Art.INK, false, 2.0, true)

static func close_btn(ci: CanvasItem, c: Vector2, rad: float = 26.0, seed: int = 4) -> void:
	ci.draw_colored_polygon(Art.ell(c + Vector2(0, 5), Vector2(rad, rad), seed, 0.0, 20, 0.0, 0.0), Color(0, 0, 0, 0.3))
	Art.sil(ci, [Art.P(Art.ell(c + Vector2(4, -rad - 2), Vector2(11, 5), seed + 1, 0.05, 12, -0.5), Art.LEAF, 1),
		Art.P(Art.ell(c, Vector2(rad, rad), seed + 2, 0.03, 22), Art.CLAY)], false)
	var k := rad * 0.42
	Art.sil(ci, [Art.P(Art.capsule(c + Vector2(-k, -k), c + Vector2(k, k), 4.5, seed + 3), Art.BONE, 2),
		Art.P(Art.capsule(c + Vector2(k, -k), c + Vector2(-k, k), 4.5, seed + 4), Art.BONE, 2)], false, 2.0)

static func pill(ci: CanvasItem, r: Rect2, seed: int = 5) -> void:
	var b := Art.rrect(r, r.size.y * 0.5, seed, 0.6)
	Art.dilate(ci, b, 3.0, Art.INK)
	ci.draw_colored_polygon(b, Art.BONE)
	ci.draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(6, r.size.y * 0.6), Vector2(r.size.x - 12, r.size.y * 0.32)), 8, seed + 1, 0.0), Color(0.6, 0.4, 0.2, 0.12))

static func plus_badge(ci: CanvasItem, c: Vector2, seed: int = 6) -> void:
	var b := Art.ell(c, Vector2(13, 13), seed, 0.02, 16)
	Art.dilate(ci, b, 2.5, Art.INK)
	ci.draw_colored_polygon(b, Art.MOSS)
	ci.draw_line(c + Vector2(-6, 0), c + Vector2(6, 0), Color.WHITE, 4.0, true)
	ci.draw_line(c + Vector2(0, -6), c + Vector2(0, 6), Color.WHITE, 4.0, true)

static func badge_num(ci: CanvasItem, c: Vector2, seed: int = 7) -> void:
	var b := Art.ell(c, Vector2(16, 16), seed, 0.02, 16)
	Art.dilate(ci, b, 2.5, Art.INK)
	ci.draw_colored_polygon(b, Art.CLAY)

static func level_badge(ci: CanvasItem, c: Vector2, s: float, seed: int = 8) -> void:
	var w := s * 0.5
	var arr := []
	for k in 9:
		var a := PI + PI * float(k) / 8.0
		arr.append(c + Vector2(cos(a) * w, sin(a) * w * 0.55 - s * 0.12))
	arr.append(c + Vector2(w * 0.92, s * 0.42))
	arr.append(c + Vector2(-w * 0.92, s * 0.42))
	var pts := Art.poly(arr, seed, 1.0)
	Art.dilate(ci, pts, 7.0, Color(1, 0.98, 0.9, 0.95))
	Art.dilate(ci, pts, 3.5, Art.INK)
	Art.shade(ci, pts, Color("b0a493"), 1)
	var inner := PackedVector2Array()
	for o in Geometry2D.offset_polygon(pts, -8.0):
		inner = o
	if inner.size() > 2:
		Art.outline(ci, inner, 2.0, Color(0.3, 0.2, 0.1, 0.5))
	for i in 5:
		var x := c.x - w * 0.6 + w * 0.3 * float(i)
		ci.draw_colored_polygon(Art.poly([Vector2(x, c.y + s * 0.3), Vector2(x + 5, c.y + s * 0.36), Vector2(x, c.y + s * 0.42), Vector2(x - 5, c.y + s * 0.36)], seed + i), Art.CLAY)

static func bar(ci: CanvasItem, r: Rect2, t: float, col: Color = Art.MOSS, seed: int = 9) -> void:
	var b := Art.rrect(r, r.size.y * 0.5, seed, 0.5)
	Art.dilate(ci, b, 3.0, Art.INK)
	ci.draw_colored_polygon(b, Color("5a3d24"))
	t = clampf(t, 0.0, 1.0)
	if t > 0.02:
		var fr := Rect2(r.position + Vector2(3, 3), Vector2(maxf(r.size.y - 6, (r.size.x - 6) * t), r.size.y - 6))
		ci.draw_colored_polygon(Art.rrect(fr, fr.size.y * 0.5, seed + 1, 0.4), col)
		ci.draw_colored_polygon(Art.rrect(Rect2(fr.position + Vector2(6, 2), Vector2(max(4, fr.size.x - 12), fr.size.y * 0.3)), 4, seed + 2, 0.0), Color(1, 1, 1, 0.35))

static func cell_bracket(ci: CanvasItem, r: Rect2, col: Color = Color("ffd23f")) -> void:
	var L := r.size.x * 0.3
	var rad := r.size.x * 0.16
	r = r.grow(-5.0)
	for corner in 4:
		var p := r.position + Vector2(r.size.x if corner % 2 == 1 else 0.0, r.size.y if corner >= 2 else 0.0)
		var sx := -1.0 if corner % 2 == 1 else 1.0
		var sy := -1.0 if corner >= 2 else 1.0
		var cc := p + Vector2(rad * sx, rad * sy)
		var arr := PackedVector2Array([p + Vector2(0, L * sy)])
		var a0 := atan2(0.0, -sx)
		var a1 := atan2(-sy, 0.0)
		if a1 - a0 > PI:
			a1 -= TAU
		elif a0 - a1 > PI:
			a1 += TAU
		for k in 9:
			var a := lerpf(a0, a1, float(k) / 8.0)
			arr.append(cc + Vector2(cos(a), sin(a)) * rad)
		arr.append(p + Vector2(L * sx, 0))
		for w in [11.0, 6.0]:
			var cl: Color = Art.INK if w > 7.0 else col
			ci.draw_polyline(arr, cl, w, true)
			ci.draw_circle(arr[0], w * 0.5, cl)
			ci.draw_circle(arr[arr.size() - 1], w * 0.5, cl)

static func check_mark(ci: CanvasItem, c: Vector2, s: float = 1.0) -> void:
	var b := Art.ell(c, Vector2(13, 13) * s, 3, 0.02, 16)
	Art.dilate(ci, b, 2.5, Art.INK)
	ci.draw_colored_polygon(b, Art.MOSS)
	ci.draw_polyline(PackedVector2Array([c + Vector2(-6, 0) * s, c + Vector2(-1, 5) * s, c + Vector2(7, -5) * s]), Color.WHITE, 3.5 * s, true)

# ---------------------------------------------------------------- 小图标（按钮内）

static func glyph(ci: CanvasItem, kind: String, c: Vector2, s: float = 1.0, col: Color = Color.WHITE) -> void:
	var w := 4.0 * s
	match kind:
		"music":
			ci.draw_circle(c + Vector2(-8, 10) * s, 6 * s, col)
			ci.draw_circle(c + Vector2(10, 6) * s, 6 * s, col)
			ci.draw_line(c + Vector2(-3, 10) * s, c + Vector2(-3, -12) * s, col, w)
			ci.draw_line(c + Vector2(15, 6) * s, c + Vector2(15, -16) * s, col, w)
			ci.draw_line(c + Vector2(-3, -12) * s, c + Vector2(15, -16) * s, col, w * 1.4)
		"sound":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-14, -5) * s, c + Vector2(-6, -5) * s, c + Vector2(3, -13) * s, c + Vector2(3, 13) * s, c + Vector2(-6, 5) * s, c + Vector2(-14, 5) * s]), col)
			ci.draw_arc(c + Vector2(4, 0) * s, 9 * s, -0.9, 0.9, 8, col, w * 0.8)
			ci.draw_arc(c + Vector2(4, 0) * s, 16 * s, -0.9, 0.9, 8, col, w * 0.8)
		"vibrate":
			ci.draw_rect(Rect2(c + Vector2(-8, -14) * s, Vector2(16, 28) * s), col, false, w * 0.8)
			for sx in [-1.0, 1.0]:
				ci.draw_polyline(PackedVector2Array([c + Vector2(14 * sx, -8) * s, c + Vector2(18 * sx, -3) * s, c + Vector2(14 * sx, 2) * s, c + Vector2(18 * sx, 7) * s]), col, w * 0.7)
		"hint":
			ci.draw_circle(c + Vector2(0, -4) * s, 11 * s, col)
			ci.draw_rect(Rect2(c + Vector2(-6, 6) * s, Vector2(12, 8) * s), col)
			for k in 5:
				var a := PI + PI * float(k) / 4.0
				ci.draw_line(c + Vector2(cos(a), sin(a)) * 15 * s + Vector2(0, -4) * s, c + Vector2(cos(a), sin(a)) * 20 * s + Vector2(0, -4) * s, col, w * 0.7)
		"chat":
			ci.draw_circle(c, 13 * s, col, false, w * 0.8, true)
			ci.draw_circle(c + Vector2(-5, 0) * s, 2 * s, col)
			ci.draw_circle(c + Vector2(0, 0) * s, 2 * s, col)
			ci.draw_circle(c + Vector2(5, 0) * s, 2 * s, col)
		"faq":
			ci.draw_circle(c, 13 * s, col, false, w * 0.8, true)
			ci.draw_arc(c + Vector2(0, -3) * s, 5 * s, PI, TAU + 0.6, 8, col, w * 0.7)
			ci.draw_circle(c + Vector2(0, 7) * s, 2 * s, col)
		"globe":
			ci.draw_circle(c, 13 * s, col, false, w * 0.8, true)
			ci.draw_line(c + Vector2(-13, 0) * s, c + Vector2(13, 0) * s, col, w * 0.6)
			ci.draw_arc(c, 13 * s, -PI * 0.5, PI * 0.5, 10, col, w * 0.6)
			ci.draw_line(c + Vector2(0, -13) * s, c + Vector2(0, 13) * s, col, w * 0.6)
		"gear":
			ci.draw_colored_polygon(Art.star_pts(c, 18 * s, 13 * s, 8, 3, 0.0), col)
			ci.draw_circle(c, 6 * s, Art.TEAL.darkened(0.3))
		"info":
			ci.draw_circle(c, 13 * s, Color("3f9ad6"))
			ci.draw_circle(c, 13 * s, Color.WHITE, false, 2.5 * s, true)
			ci.draw_circle(c + Vector2(0, -6) * s, 2.2 * s, Color.WHITE)
			ci.draw_line(c + Vector2(0, -1) * s, c + Vector2(0, 7) * s, Color.WHITE, 3.5 * s)
		"trash":
			ci.draw_rect(Rect2(c + Vector2(-10, -6) * s, Vector2(20, 22) * s), col, false, w * 0.8)
			ci.draw_line(c + Vector2(-14, -10) * s, c + Vector2(14, -10) * s, col, w)
			ci.draw_line(c + Vector2(-4, -15) * s, c + Vector2(4, -15) * s, col, w)
			ci.draw_line(c + Vector2(-3, -1) * s, c + Vector2(-3, 11) * s, col, w * 0.6)
			ci.draw_line(c + Vector2(3, -1) * s, c + Vector2(3, 11) * s, col, w * 0.6)
		"lock":
			ci.draw_arc(c + Vector2(0, -4) * s, 7 * s, PI, TAU, 8, Art.INK, 3.0 * s)
			ci.draw_rect(Rect2(c + Vector2(-9, -4) * s, Vector2(18, 14) * s), Color("e6c98a"))
			ci.draw_rect(Rect2(c + Vector2(-9, -4) * s, Vector2(18, 14) * s), Art.INK, false, 2.0 * s)
		"clock":
			ci.draw_circle(c, 11 * s, Art.OCHRE)
			ci.draw_circle(c, 11 * s, Art.INK, false, 2.0 * s, true)
			ci.draw_line(c, c + Vector2(0, -7) * s, Art.INK, 2.0 * s)
			ci.draw_line(c, c + Vector2(5, 2) * s, Art.INK, 2.0 * s)

# ---------------------------------------------------------------- 大图标（主页按钮）

static func hammer(ci: CanvasItem, c: Vector2, s: float = 1.0) -> void:
	ci.draw_set_transform(c, 0.0, Vector2.ONE * s)
	var d := (Vector2(16, -16) - Vector2(-30, 34)).normalized()
	var ang := d.angle() + PI / 2.0
	var tip := Vector2(16, -16) + d * 8.0
	var head := PackedVector2Array()
	for p in Art.rrect(Rect2(-25, -13, 50, 26), 9, 2, 0.35):
		head.append((p as Vector2).rotated(ang) + tip)
	Art.sil(ci, [Art.P(Art.capsule(Vector2(-30, 34), Vector2(16, -16), 6.0, 1), Art.WOOD, 1),
		Art.P(head, Art.STONE, 1)])
	Art._rope(ci, Vector2(-30, 34), Vector2(16, -16), 0.82, 2, 7.0, 3)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func book(ci: CanvasItem, c: Vector2, s: float = 1.0) -> void:
	ci.draw_set_transform(c, 0.0, Vector2.ONE * s)
	Art.sil(ci, [Art.P(Art.rrect(Rect2(-34, -30, 68, 60), 8, 1, 0.6), Art.LEATHER, 1),
		Art.P(Art.rrect(Rect2(-28, -26, 56, 50), 4, 2, 0.6), Art.HIDE, 2)])
	Art.ln(ci, Vector2(0, -26), Vector2(0, 24), 2.5, Art.LEATHER_D, 1)
	ci.draw_colored_polygon(Art.star_pts(Vector2(-14, -4), 9, 4, 4, 3), Art.CLAY)
	for i in 3:
		Art.ln(ci, Vector2(6, -12 + i * 10), Vector2(22, -12 + i * 10), 2.0, Color(0.4, 0.25, 0.1, 0.6), i)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func cards_icon(ci: CanvasItem, c: Vector2, s: float = 1.0) -> void:
	ci.draw_set_transform(c, 0.0, Vector2.ONE * s)
	Art.sil(ci, [Art.P(Art.poly(Art.rot_pts([Vector2(-20, -28), Vector2(20, -28), Vector2(20, 28), Vector2(-20, 28)], -0.25, Vector2(-10, 2)), 1), Art.TEAL, 1),
		Art.P(Art.poly(Art.rot_pts([Vector2(-20, -28), Vector2(20, -28), Vector2(20, 28), Vector2(-20, 28)], 0.2, Vector2(10, 0)), 2), Art.OCHRE, 1)])
	ci.draw_colored_polygon(Art.star_pts(Vector2(10, 0), 12, 5, 5, 3), Art.BONE)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func hut_icon(ci: CanvasItem, c: Vector2, s: float = 1.0) -> void:
	ci.draw_set_transform(c, 0.0, Vector2.ONE * s)
	Art.sil(ci, [Art.P(Art.rrect(Rect2(-30, -2, 60, 34), 4, 1, 0.6), Art.WOOD, 1),
		Art.P(Art.poly([Vector2(-42, 2), Vector2(0, -38), Vector2(42, 2)], 2), Color("d9a54a"), 1),
		Art.P(Art.rrect(Rect2(-10, 8, 20, 24), 8, 3, 0.4), Art.LEATHER_D, 2)])
	for i in 5:
		var x := -28.0 + float(i) * 14.0
		Art.ln(ci, Vector2(x * 0.2, -32), Vector2(x, 0), 1.8, Color(0.45, 0.28, 0.05, 0.7), i)
	for i in 4:
		ci.draw_colored_polygon(Art.poly([Vector2(-30 + i * 16, 2), Vector2(-22 + i * 16, 2), Vector2(-26 + i * 16, 12)], i), Art.CLAY if i % 2 == 0 else Art.TEAL)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func pouch(ci: CanvasItem, c: Vector2, s: float = 1.0) -> void:
	ci.draw_set_transform(c, 0.0, Vector2.ONE * s)
	Art.sil(ci, [Art.P(Art.ell(Vector2(0, 8), Vector2(34, 30), 1, 0.06), Color("b9844e")),
		Art.P(Art.poly([Vector2(-16, -18), Vector2(-24, -36), Vector2(0, -30), Vector2(24, -36), Vector2(16, -18)], 2), Color("a3703f"), 1)])
	Art.pl(ci, [Vector2(-20, -18), Vector2(0, -14), Vector2(20, -18)], 4.0, Art.ROPE, 3)
	Art.dashed(ci, Art.ell(Vector2(0, 10), Vector2(24, 20), 4, 0.0, 20, 0.0, 0.0), 5, 4, Art.BONE, 2.0)
	ci.draw_circle(Vector2(0, 10), 7.0, Art.TEAL)
	ci.draw_circle(Vector2(0, 10), 7.0, Art.INK, false, 2.0, true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func home_icon(ci: CanvasItem, c: Vector2, s: float = 1.0) -> void:
	ci.draw_set_transform(c, 0.0, Vector2.ONE * s)
	Art.sil(ci, [Art.P(Art.poly([Vector2(-34, 30), Vector2(0, -34), Vector2(34, 30)], 1), Color("d9a54a"), 1),
		Art.P(Art.poly([Vector2(-10, 30), Vector2(0, 6), Vector2(10, 30)], 2), Art.LEATHER_D, 2)], false)
	for i in 4:
		Art.ln(ci, Vector2(0, -28), Vector2(-24 + i * 16, 28), 1.8, Color(0.45, 0.28, 0.05, 0.6), i)
	Art.ln(ci, Vector2(-6, -44), Vector2(6, -24), 3.0, Art.WOOD_D, 5)
	Art.ln(ci, Vector2(6, -44), Vector2(-6, -24), 3.0, Art.WOOD_D, 6)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## 配置首页上每个编辑器的标记。按这一页在改什么来画。
static func cfg_icon(ci: CanvasItem, kind: String, c: Vector2, size: float) -> void:
	var s := size / 100.0
	match kind:
		"chains":
			Art.item(ci, "fruit_1", c, size)
		"board":
			_cfg_board(ci, c, s)
		"story":
			_cfg_story(ci, c, s)
		"pass":
			_cfg_pass(ci, c, s)
		"albums":
			cards_icon(ci, c, s * 1.45)
		"people":
			_cfg_people(ci, c, s)
		"builds":
			hut_icon(ci, c + Vector2(0, 4.0 * s), s * 1.05)
		"level":
			Art.item(ci, "xp_1", c, size)
		"amber":
			_cfg_amber(ci, c, s)
		"rules":
			_cfg_rules(ci, c, s)
		"rand":
			_cfg_rand(ci, c, s)
		"unlock":
			_cfg_unlock(ci, c, s)

static func _cfg_rand(ci: CanvasItem, c: Vector2, s: float) -> void:
	ci.draw_set_transform(c, 0.0, Vector2.ONE * s)
	Art.ln(ci, Vector2(-36, 30), Vector2(38, 30), 3.0, Art.INK, 1)
	Art.ln(ci, Vector2(-36, 30), Vector2(-36, -34), 3.0, Art.INK, 2)
	var easy: Array = [Vector2(-28, 16), Vector2(-6, 8), Vector2(14, 6), Vector2(32, -8)]
	var hard: Array = [Vector2(-28, 20), Vector2(-6, 4), Vector2(14, -10), Vector2(32, -26)]
	var band := PackedVector2Array()
	for p in easy:
		band.append(p)
	for i in range(hard.size() - 1, -1, -1):
		band.append(hard[i])
	ci.draw_colored_polygon(band, Color(0.92, 0.65, 0.23, 0.45))
	Art.pl(ci, easy, 4.0, Art.TEAL, 3)
	Art.pl(ci, hard, 4.0, Art.CLAY, 4)
	for i in easy.size():
		Art.dot(ci, easy[i], 4.5, Art.TEAL)
		Art.dot(ci, hard[i], 4.5, Art.CLAY)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func _cfg_unlock(ci: CanvasItem, c: Vector2, s: float) -> void:
	ci.draw_set_transform(c, 0.0, Vector2.ONE * s)
	var cell := 18.0
	var gap := 4.0
	var origin := -((cell * 3.0 + gap * 2.0) * 0.5)
	for i in 9:
		var col := i % 3
		var row := int(i / 3.0)
		var r := Rect2(origin + float(col) * (cell + gap), origin + float(row) * (cell + gap), cell, cell)
		var on := i % 3 != 0
		_cfg_tile(ci, r, Color("8cc63f") if on else Color("c8c0b4"), 40 + i)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func _cfg_board(ci: CanvasItem, c: Vector2, s: float) -> void:
	ci.draw_set_transform(c, 0.0, Vector2.ONE * s)
	var cell := 22.0
	var gap := 4.0
	var origin := -((cell * 3.0 + gap * 2.0) * 0.5)
	var marks := {0: Art.BERRY, 4: Art.STONE, 7: Art.LEAF, 8: Art.AMBER}
	for i in 9:
		var col := i % 3
		var row := int(i / 3.0)
		var r := Rect2(origin + float(col) * (cell + gap), origin + float(row) * (cell + gap), cell, cell)
		_cfg_tile(ci, r, Color("fff7e6"), 20 + i)
		if marks.has(i):
			Art.fill(ci, Art.ell(r.get_center(), Vector2(6, 6), 30 + i, 0.05, 10), marks[i], 1.5)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func _cfg_story(ci: CanvasItem, c: Vector2, s: float) -> void:
	ci.draw_set_transform(c, 0.0, Vector2.ONE * s)
	var r := Rect2(-40, -26, 80, 54)
	var b := Art.rrect(r, 12, 4, 0.35)
	Art.dilate(ci, b, 2.4, Art.INK)
	ci.draw_colored_polygon(b, Color("ffe9a8"))
	Art.dashed(ci, Art.rrect(r.grow(-4), 8, 5, 0.0), 5, 4, Color(0.65, 0.4, 0.2, 0.55), 1.6)
	var head := Art.ell(Vector2(-16, 2), Vector2(14, 14), 6, 0.02, 16)
	Art.dilate(ci, head, 2.0, Art.INK)
	ci.draw_colored_polygon(head, Art.OCHRE.lightened(0.25))
	_mini_face(ci, Vector2(-16, 2), 11.0, Color("b97a4a"), 12)
	Art.fill(ci, Art.ell(Vector2(10, 6), Vector2(7, 7), 8, 0.04, 10), Art.BERRY, 1.5)
	Art.fill(ci, Art.ell(Vector2(20, 10), Vector2(7, 7), 9, 0.04, 10), Art.BERRY, 1.5)
	Art.ln(ci, Vector2(14, 2), Vector2(16, -8), 1.8, Art.LEAF_D, 2)
	Art.fill(ci, Art.ell(Vector2(20, -8), Vector2(6, 3), 10, 0.0, 8, -0.4), Art.LEAF, 1.3)
	Art.fill(ci, Art.star_pts(Vector2(26, -14), 9, 4, 5, 11), Art.OCHRE, 1.5)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func _cfg_pass(ci: CanvasItem, c: Vector2, s: float) -> void:
	ci.draw_set_transform(c, 0.0, Vector2.ONE * s)
	_cfg_tile(ci, Rect2(-34, -22, 32, 56), Color("e4d0aa"), 1)
	_cfg_tile(ci, Rect2(2, -22, 32, 56), Art.BONE, 2)
	Art.fill(ci, Art.star_pts(Vector2(0, -32), 13, 6, 5, 3), Art.OCHRE, 1.8)
	_cfg_pip(ci, Vector2(-18, -6), Art.SHELL)
	_cfg_pip(ci, Vector2(-18, 16), Art.MOSS)
	_cfg_pip(ci, Vector2(18, -6), Art.AMBER)
	_cfg_pip(ci, Vector2(18, 16), Art.TEAL)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func _cfg_people(ci: CanvasItem, c: Vector2, s: float) -> void:
	ci.draw_set_transform(c, 0.0, Vector2.ONE * s)
	Art.sil(ci, [Art.P(Art.ell(Vector2(0, 28), Vector2(34, 18), 2, 0.04, 16), Color("9c5a2a"), 1)], true, 2.0)
	var parts := []
	var cols := [Art.CLAY, Art.OCHRE, Art.BONE, Art.TEAL, Art.OCHRE]
	for i in 5:
		var a := -PI * 0.5 + (float(i) - 2.0) * 0.36
		parts.append(Art.P(Art.ell(Vector2(0, -6) + Vector2(cos(a), sin(a)) * 28.0, Vector2(6, 14), 8 + i, 0.04, 10, a + PI * 0.5), cols[i], 1))
	Art.sil(ci, parts, true, 2.0)
	face(ci, Vector2(0, 2), 18, Color("b97a4a"), 11)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func _cfg_amber(ci: CanvasItem, c: Vector2, s: float) -> void:
	ci.draw_set_transform(c, 0.0, Vector2.ONE * s)
	var gem := Art.poly([Vector2(-26, 2), Vector2(-14, -28), Vector2(12, -34), Vector2(28, -6), Vector2(16, 22), Vector2(-10, 26)], 4, 0.5)
	Art.sil(ci, [Art.P(gem, Art.AMBER, 1)], true, 2.2)
	ci.draw_colored_polygon(Art.poly([Vector2(-14, -28), Vector2(12, -34), Vector2(0, -8)], 5, 0.3), Color(1, 0.92, 0.55, 0.7))
	var sh := Art._scallop(Vector2(22, 20), 13, 0.15, 6)
	Art.sil(ci, [Art.P(sh, Art.SHELL, 1)], true, 1.8)
	Art._scallop_det(ci, Vector2(22, 20), 13, 0.15, 6)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func _cfg_rules(ci: CanvasItem, c: Vector2, s: float) -> void:
	ci.draw_set_transform(c, 0.0, Vector2.ONE * s)
	var board := Art.rrect(Rect2(-26, -36, 52, 72), 8, 7, 0.3)
	Art.sil(ci, [Art.P(board, Art.WOOD, 1)], true, 2.2)
	var hole := Art.ell(Vector2(0, -26), Vector2(3.6, 3.6), 8, 0.0, 10)
	ci.draw_colored_polygon(hole, Color("fff7e6"))
	Art.outline(ci, hole, 1.6, Art.INK)
	Art.fill(ci, Art.flame_pts(Vector2(-14, -10), 5, 12, 9), Art.FIRE, 1.3)
	Art.ln(ci, Vector2(-4, -12), Vector2(16, -12), 2.6, Art.INK, 1)
	for i in 4:
		var cell := Art.rrect(Rect2(-16.0 + float(i % 2) * 7.0, 0.0 + float(int(i / 2)) * 7.0, 6, 6), 1.4, 12 + i, 0.1)
		ci.draw_colored_polygon(cell, Art.BONE)
		Art.outline(ci, cell, 1.3, Art.INK)
	Art.ln(ci, Vector2(-1, 6), Vector2(16, 6), 2.6, Art.INK, 2)
	Art.ln(ci, Vector2(-14, 22), Vector2(16, 22), 2.6, Art.INK, 3)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func _cfg_tile(ci: CanvasItem, r: Rect2, fill: Color, seed: int) -> void:
	var b := Art.rrect(r, minf(8.0, r.size.x * 0.22), seed, 0.22)
	Art.dilate(ci, b, 2.0, Art.INK)
	ci.draw_colored_polygon(b, fill)
	Art.outline(ci, b, 1.7, Art.INK)

static func _cfg_pip(ci: CanvasItem, c: Vector2, col: Color) -> void:
	Art.fill(ci, Art.ell(c, Vector2(6.5, 6.5), int(c.x + c.y), 0.04, 10), col, 1.5)

static func _mini_face(ci: CanvasItem, c: Vector2, r: float, skin: Color, seed: int) -> void:
	Art.fill(ci, Art.ell(c, Vector2(r, r * 1.02), seed, 0.03, 14), skin, 1.6)
	for sx in [-1.0, 1.0]:
		ci.draw_circle(c + Vector2(r * 0.34 * sx, -r * 0.02), r * 0.16, Art.INK)
	Art.pl(ci, [c + Vector2(-r * 0.28, r * 0.32), c + Vector2(0, r * 0.52), c + Vector2(r * 0.28, r * 0.32)], maxf(1.5, r * 0.12), Art.INK, seed)

# ---------------------------------------------------------------- 角色

static func face(ci: CanvasItem, c: Vector2, r: float, skin: Color, seed: int, smile: bool = true) -> void:
	Art.sil(ci, [Art.P(Art.ell(c + Vector2(-r * 0.95, r * 0.1), Vector2(r * 0.2, r * 0.26), seed, 0.03, 12), skin),
		Art.P(Art.ell(c + Vector2(r * 0.95, r * 0.1), Vector2(r * 0.2, r * 0.26), seed + 1, 0.03, 12), skin),
		Art.P(Art.ell(c, Vector2(r, r * 1.02), seed + 2, 0.03, 24), skin)], false)
	for sx in [-1.0, 1.0]:
		var e := c + Vector2(r * 0.38 * sx, r * 0.08)
		ci.draw_colored_polygon(Art.ell(e, Vector2(r * 0.17, r * 0.22), seed + 3, 0.0, 14), Color.WHITE)
		ci.draw_circle(e + Vector2(0, r * 0.03), r * 0.13, Color("3a2412"))
		ci.draw_circle(e + Vector2(-r * 0.04, -r * 0.03), r * 0.05, Color.WHITE)
		Art.pl(ci, [e + Vector2(-r * 0.2, -r * 0.3), e + Vector2(0, -r * 0.36), e + Vector2(r * 0.2, -r * 0.3)], r * 0.06, Art.INK, seed + 4)
		ci.draw_colored_polygon(Art.ell(c + Vector2(r * 0.58 * sx, r * 0.42), Vector2(r * 0.14, r * 0.08), seed + 5, 0.0, 10), Color(0.95, 0.4, 0.3, 0.35))
	Art.pl(ci, [c + Vector2(-r * 0.05, r * 0.25), c + Vector2(r * 0.06, r * 0.36), c + Vector2(-r * 0.04, r * 0.38)], r * 0.05, skin.darkened(0.35), seed + 6)
	if smile:
		var m := []
		for k in 9:
			var a := lerpf(0.25, PI - 0.25, float(k) / 8.0)
			m.append(c + Vector2(cos(a) * r * 0.26, r * 0.48 + sin(a) * r * 0.16))
		ci.draw_colored_polygon(Art.poly(m, seed + 7, 0.3), Color("8a2a1a"))
		Art.pl(ci, m, r * 0.05, Art.INK, seed + 8)

static func portrait(ci: CanvasItem, kind: int, c: Vector2, s: float) -> void:
	ci.draw_set_transform(c, 0.0, Vector2.ONE * (s / 100.0))
	var skin: Color = [Color("b97a4a"), Color("d39a6a"), Color("a8693d"), Color("dca779")][kind % 4]
	var body_col: Color = [Color("9c5a2a"), Color("6e8a3a"), Color("8a4b2a"), Color("c98a4a")][kind % 4]
	Art.sil(ci, [Art.P(Art.ell(Vector2(0, 62), Vector2(48, 30), kind, 0.04, 20), body_col)], true)
	if kind == 0:
		var fcols := [Art.CLAY, Art.OCHRE, Art.BONE, Art.TEAL, Art.OCHRE, Art.CLAY, Art.BONE]
		var parts := []
		for i in 7:
			var a := -PI * 0.5 + (float(i) - 3.0) * 0.32
			parts.append(Art.P(Art.ell(Vector2(0, -6) + Vector2(cos(a), sin(a)) * 46.0, Vector2(9, 22), 20 + i, 0.03, 14, a + PI * 0.5), fcols[i], 1))
		Art.sil(ci, parts, true)
	elif kind == 1:
		Art.sil(ci, [Art.P(Art.ell(Vector2(0, 6), Vector2(42, 46), 30, 0.06, 22), Color("3a2414"), 1)], true)
	face(ci, Vector2(0, 2), 34, skin, 40 + kind)
	match kind:
		0:
			Art.sil(ci, [Art.P(Art.capsule(Vector2(-34, -18), Vector2(34, -18), 6.0, 50), Art.CLAY, 1)], false)
			for sx in [-1.0, 1.0]:
				Art.ln(ci, Vector2(18 * sx, 14), Vector2(28 * sx, 12), 3.0, Color("f5f0e0"), 51)
				Art.ln(ci, Vector2(18 * sx, 20), Vector2(28 * sx, 18), 3.0, Color("f5f0e0"), 52)
			Art.sil(ci, [Art.P(Art.poly([Vector2(-20, 24), Vector2(20, 24), Vector2(10, 46), Vector2(0, 52), Vector2(-10, 46)], 53), Color("d9d2c4"), 1)], false)
			face_mouth_only(ci, Vector2(0, 2), 34)
		1:
			Art.sil(ci, [Art.P(Art.ell(Vector2(0, -24), Vector2(36, 16), 60, 0.06, 18), Color("3a2414"), 1),
				Art.P(Art.capsule(Vector2(14, -38), Vector2(36, -48), 3.5, 61), Art.BONE, 2)], false)
			for i in 5:
				var x := -24.0 + float(i) * 12.0
				Art.sil(ci, [Art.P(Art.poly([Vector2(x - 4, 44), Vector2(x + 4, 44), Vector2(x, 56)], 62 + i), Art.BONE, 2)], false, 2.0)
			for sx in [-1.0, 1.0]:
				for k in 3:
					ci.draw_circle(Vector2(20 * sx, 14 + k * 5), 2.2, Color("f5f0e0"))
		2:
			var parts := []
			for i in 6:
				var x := -26.0 + float(i) * 10.5
				parts.append(Art.P(Art.poly([Vector2(x - 8, -16), Vector2(x + 2, -46 + (i % 2) * 6), Vector2(x + 10, -16)], 70 + i), Color("2e1c10"), 2))
			Art.sil(ci, parts, false)
			Art.sil(ci, [Art.P(Art.capsule(Vector2(-35, -18), Vector2(35, -18), 5.0, 76), Art.TEAL, 1)], false)
			Art.ln(ci, Vector2(-26, -4), Vector2(-14, 12), 2.5, Color(0.6, 0.2, 0.1), 77)
		_:
			Art.sil(ci, [Art.P(Art.ell(Vector2(0, -28), Vector2(30, 12), 80, 0.08), Color("6b3d1e"), 1),
				Art.P(Art.ell(Vector2(4, -42), Vector2(6, 12), 81, 0.05, 12, 0.4), Color("6b3d1e"), 1),
				Art.P(Art.ell(Vector2(14, -42), Vector2(10, 5), 82, 0.05, 12, -0.4), Art.LEAF, 1)], false)
			for p in [Vector2(-18, 18), Vector2(-14, 22), Vector2(18, 18), Vector2(14, 22)]:
				ci.draw_circle(p, 1.6, Color(0.5, 0.25, 0.1, 0.6))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func face_mouth_only(ci: CanvasItem, c: Vector2, r: float) -> void:
	var m := []
	for k in 9:
		var a := lerpf(0.25, PI - 0.25, float(k) / 8.0)
		m.append(c + Vector2(cos(a) * r * 0.26, r * 0.48 + sin(a) * r * 0.16))
	ci.draw_colored_polygon(Art.poly(m, 9, 0.3), Color("8a2a1a"))
	Art.pl(ci, m, r * 0.05, Art.INK, 9)

## 小牙：原来是剑齿虎幼崽，现在是披着虎皮帽的「兄弟，我发现」族人（Meme.XIAOYA）。
## 尺寸和原来的画法对齐：c 在身体中间，s 约等于整只的高度。prop == "hammer" 时手边贴一把石锤。
static func mascot(ci: CanvasItem, c: Vector2, s: float, prop: String = "") -> void:
	var k := s / 100.0
	var w := 128.0 / Meme.BUST_RECT.size.y * 100.0 * k
	var hc := c + Vector2(0, 62.0 * k - Meme.BUST_RECT.end.y * w / 100.0)
	var rot: float = Meme.TILT[Meme.XIAOYA]
	Meme.props_back(ci, Meme.XIAOYA, hc, w, rot)
	Meme.bust(ci, hc, w, rot)
	Meme.clothes(ci, Meme.XIAOYA, hc, w, rot)
	Meme.props_front(ci, Meme.XIAOYA, hc, w, rot)
	if prop == "hammer":
		hammer(ci, c + Vector2(52, 20) * k, 0.9 * k)

## 主角阿焰（Meme.HERO）和小牙站在一起。c、s 和原来的画法对齐（整张约 280*s/100 高）。
static func heroine(ci: CanvasItem, c: Vector2, s: float) -> void:
	var k := s / 100.0
	var w := 250.0 / Meme.BUST_RECT.size.y * 100.0 * k
	var hc := c + Vector2(-14, 130.0 * k - Meme.BUST_RECT.end.y * w / 100.0)
	_hero_at(ci, hc, w)
	mascot(ci, c + Vector2(96, 84) * k, 92.0 * k)

## 阿焰半身。原点在胸口，头顶朝上（尺寸和原来的画法对齐，整张约 164*s/100 高）。
static func bust(ci: CanvasItem, c: Vector2, s: float) -> void:
	var k := s / 100.0
	var w := 164.0 / Meme.BUST_RECT.size.y * 100.0 * k
	_hero_at(ci, c + Vector2(0, 58.0 * k - Meme.BUST_RECT.end.y * w / 100.0), w)

static func _hero_at(ci: CanvasItem, hc: Vector2, w: float) -> void:
	var rot: float = Meme.TILT[Meme.HERO]
	Meme.props_back(ci, Meme.HERO, hc, w, rot)
	Meme.bust(ci, hc, w, rot)
	Meme.clothes(ci, Meme.HERO, hc, w, rot)
	Meme.props_front(ci, Meme.HERO, hc, w, rot)

## 引导气泡。point_left 时尾巴朝左。
static func speech(ci: CanvasItem, r: Rect2, point_left: bool, seed: int = 8) -> void:
	var tail_y := r.position.y + r.size.y * 0.56
	var base_x := r.position.x + 12.0 if point_left else r.end.x - 12.0
	var tip := Vector2(r.position.x - 26.0, tail_y + 10.0) if point_left else Vector2(r.end.x + 26.0, tail_y + 10.0)
	var tail := PackedVector2Array([
		Vector2(base_x, tail_y - 24.0),
		tip,
		Vector2(base_x, tail_y + 22.0),
	])
	ci.draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(0, 8), r.size), 24, seed, 0.0), Color(0, 0, 0, 0.35))
	ci.draw_colored_polygon(tail, Art.BONE)
	var body := Art.rrect(r, 24, seed, 0.85)
	Art.dilate(ci, body, 3.0, Art.INK)
	ci.draw_colored_polygon(body, Art.BONE)
	Art.outline(ci, tail, 3.0, Art.INK)
	var patch := 8.0 if point_left else -20.0
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(base_x + patch, tail_y - 16.0),
		Vector2(base_x + patch + 18.0, tail_y - 16.0),
		Vector2(base_x + patch + 18.0, tail_y + 14.0),
		Vector2(base_x + patch, tail_y + 14.0),
	]), Art.BONE)
	Art.dashed(ci, Art.rrect(r.grow(-9), 16, seed + 2, 0.0), 9, 6, Color("e4c59a"), 2.0)

# ---------------------------------------------------------------- 岩画卡牌

const ALBUM_COL := [Color("c98a55"), Color("b8a27a"), Color("6b4a3a"), Color("a07858"), Color("c4a06a"), Color("8a9a8a"),
	Color("b9894a"), Color("8f8478"), Color("a86a4a"), Color("7f9a7a"), Color("94705a"), Color("5f6a8a")]

static func card_art(ci: CanvasItem, album: int, idx: int, r: Rect2) -> void:
	var bg: Color = ALBUM_COL[album % ALBUM_COL.size()]
	ci.draw_rect(r, bg)
	for i in 30:
		var p := r.position + Vector2(Art.srnd(album * 100 + idx * 10 + i) * r.size.x, Art.srnd(album * 77 + idx * 13 + i * 3) * r.size.y)
		ci.draw_circle(p, 2.0 + Art.srnd(i + idx) * 10.0, Color(bg.darkened(0.2), 0.35))
	var ink := Color("7a2412") if album != 2 else Color("f2c96a")
	var c := r.get_center()
	var s := r.size.x / 100.0
	ci.draw_set_transform(c, 0.0, Vector2.ONE * s)
	var motif := (album * 3 + idx) % 6
	match motif:
		0:
			_mammoth(ci, Vector2(-4, 6), 1.0, ink, idx)
		1:
			_deer(ci, Vector2(-6, 6), 1.0, ink, idx)
			_hunter(ci, Vector2(30, 10), 0.8, ink, idx)
		2:
			for i in 3:
				_hunter(ci, Vector2(-30 + i * 30, 8 + (i % 2) * 6), 0.9, ink, idx + i)
		3:
			for i in 4:
				_hand(ci, Vector2(-26 + (i % 2) * 52, -16 + (i / 2) * 36), 0.8, ink if i % 2 == 0 else Color(ink, 0.6), idx + i)
		4:
			ci.draw_circle(Vector2(0, -6), 16, ink)
			for k in 10:
				var a := TAU * float(k) / 10.0
				Art.ln(ci, Vector2(cos(a), sin(a)) * 22.0 + Vector2(0, -6), Vector2(cos(a), sin(a)) * 32.0 + Vector2(0, -6), 4.0, ink, k)
			_fish_glyph(ci, Vector2(0, 32), ink, idx)
		_:
			ci.draw_colored_polygon(Art.flame_pts(Vector2(0, 0), 16, 40, idx), ink)
			for i in 2:
				_hunter(ci, Vector2(-30 + i * 60, 10), 0.85, ink, idx + i)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func _mammoth(ci: CanvasItem, c: Vector2, s: float, col: Color, seed: int) -> void:
	ci.draw_colored_polygon(Art.ell(c, Vector2(30, 20) * s, seed, 0.08, 20), col)
	ci.draw_colored_polygon(Art.ell(c + Vector2(-28, -8) * s, Vector2(13, 13) * s, seed + 1, 0.05, 14), col)
	Art.pl(ci, [c + Vector2(-36, -2) * s, c + Vector2(-42, 14) * s, c + Vector2(-36, 26) * s], 5.0 * s, col, seed)
	Art.pl(ci, [c + Vector2(-30, 4) * s, c + Vector2(-40, 10) * s, c + Vector2(-46, 2) * s], 3.0 * s, Color("f5ead0"), seed + 1)
	for x in [-18.0, -6.0, 10.0, 22.0]:
		Art.ln(ci, c + Vector2(x, 12) * s, c + Vector2(x, 30) * s, 6.0 * s, col, seed + int(x))

static func _deer(ci: CanvasItem, c: Vector2, s: float, col: Color, seed: int) -> void:
	ci.draw_colored_polygon(Art.ell(c, Vector2(22, 10) * s, seed, 0.05, 16), col)
	Art.ln(ci, c + Vector2(-18, -4) * s, c + Vector2(-26, -20) * s, 5.0 * s, col, seed)
	ci.draw_colored_polygon(Art.ell(c + Vector2(-30, -22) * s, Vector2(7, 5) * s, seed + 1, 0.05, 10), col)
	Art.pl(ci, [c + Vector2(-28, -26) * s, c + Vector2(-24, -40) * s, c + Vector2(-16, -46) * s], 2.5 * s, col, seed)
	Art.pl(ci, [c + Vector2(-24, -38) * s, c + Vector2(-34, -46) * s], 2.5 * s, col, seed + 1)
	for x in [-14.0, -6.0, 8.0, 16.0]:
		Art.ln(ci, c + Vector2(x, 6) * s, c + Vector2(x + 2, 26) * s, 3.5 * s, col, seed + int(x))

static func _hunter(ci: CanvasItem, c: Vector2, s: float, col: Color, seed: int) -> void:
	ci.draw_circle(c + Vector2(0, -24) * s, 5.0 * s, col)
	Art.ln(ci, c + Vector2(0, -18) * s, c + Vector2(0, 4) * s, 4.0 * s, col, seed)
	Art.ln(ci, c + Vector2(0, 4) * s, c + Vector2(-8, 22) * s, 3.5 * s, col, seed + 1)
	Art.ln(ci, c + Vector2(0, 4) * s, c + Vector2(8, 22) * s, 3.5 * s, col, seed + 2)
	Art.ln(ci, c + Vector2(0, -12) * s, c + Vector2(-10, -2) * s, 3.0 * s, col, seed + 3)
	Art.ln(ci, c + Vector2(0, -12) * s, c + Vector2(10, -18) * s, 3.0 * s, col, seed + 4)
	Art.ln(ci, c + Vector2(4, 4) * s, c + Vector2(18, -34) * s, 2.5 * s, col, seed + 5)

static func _hand(ci: CanvasItem, c: Vector2, s: float, col: Color, seed: int) -> void:
	ci.draw_colored_polygon(Art.ell(c + Vector2(0, 6) * s, Vector2(10, 11) * s, seed, 0.06, 14), col)
	for k in 5:
		var a := -PI * 0.5 + (float(k) - 2.0) * 0.38
		if k == 0:
			a = PI * 0.95
		Art.ln(ci, c + Vector2(cos(a), sin(a)) * 8.0 * s + Vector2(0, 4) * s, c + Vector2(cos(a), sin(a)) * 22.0 * s + Vector2(0, 4) * s, 5.0 * s, col, seed + k)

static func _fish_glyph(ci: CanvasItem, c: Vector2, col: Color, seed: int) -> void:
	ci.draw_colored_polygon(Art.ell(c, Vector2(16, 7), seed, 0.03, 14), col)
	ci.draw_colored_polygon(Art.poly([c + Vector2(14, 0), c + Vector2(24, -8), c + Vector2(24, 8)], seed), col)

static func card(ci: CanvasItem, r: Rect2, album: int, idx: int, owned: bool, name: String = "") -> void:
	ci.draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(0, 6), r.size), 12, album + idx, 0.0), Color(0, 0, 0, 0.3))
	var b := Art.rrect(r, 12, album * 9 + idx, 0.6)
	Art.dilate(ci, b, 3.0, Art.INK)
	ci.draw_colored_polygon(b, Art.BONE)
	var ar := Rect2(r.position + Vector2(8, 8), Vector2(r.size.x - 16, r.size.y * 0.72))
	if owned:
		card_art(ci, album, idx, ar)
	else:
		ci.draw_rect(ar, Color("8a6a4a"))
		for i in 6:
			var y := ar.position.y + ar.size.y * float(i) / 6.0
			Art.ln(ci, Vector2(ar.position.x, y), Vector2(ar.end.x, y + 10), 2.0, Color(1, 1, 1, 0.08), i)
	ci.draw_rect(ar, Art.INK, false, 2.0)
	var bandr := Rect2(r.position + Vector2(4, r.size.y * 0.74), Vector2(r.size.x - 8, r.size.y * 0.22))
	ci.draw_colored_polygon(Art.rrect(bandr, 6, idx, 0.4), Art.OCHRE)
	ci.draw_colored_polygon(Art.star_pts(Vector2(r.get_center().x, bandr.position.y + 2), 11, 5, 5, idx), Art.FIRE2)
	Art.outline(ci, Art.star_pts(Vector2(r.get_center().x, bandr.position.y + 2), 11, 5, 5, idx), 2.0)

# ---------------------------------------------------------------- 背景与村庄

static func vgrad(ci: CanvasItem, r: Rect2, top: Color, bottom: Color) -> void:
	ci.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))

static func hills(ci: CanvasItem, y: float, w: float, amp: float, col: Color, seed: int, bottom: float) -> void:
	var arr := PackedVector2Array()
	arr.append(Vector2(0, bottom))
	for k in 25:
		var x := w * float(k) / 24.0
		arr.append(Vector2(x, y - amp * (0.5 + 0.5 * sin(float(k) * 0.7 + float(seed))) - Art.srnd(seed + k) * amp * 0.3))
	arr.append(Vector2(w, bottom))
	ci.draw_colored_polygon(arr, col)

static func palm(ci: CanvasItem, base: Vector2, h: float, seed: int, col: Color = Color("2f6b3a")) -> void:
	var top := base + Vector2(Art.srnd(seed) * 30.0 - 15.0, -h)
	Art.ln(ci, base, top, 9.0, Color("6a4526"), seed)
	for k in 6:
		var a := -PI + PI * float(k) / 5.0 + (Art.srnd(seed + k) - 0.5) * 0.3
		var tip := top + Vector2(cos(a) * 60.0, sin(a) * 30.0 + 26.0)
		var mid := top + Vector2(cos(a) * 30.0, sin(a) * 30.0 - 6.0)
		ci.draw_colored_polygon(Art.poly([top, mid + Vector2(0, -8), tip, mid + Vector2(0, 8)], seed + k), col)

static func campfire_scene(ci: CanvasItem, c: Vector2, s: float) -> void:
	ci.draw_set_transform(c, 0.0, Vector2.ONE * s)
	ci.draw_colored_polygon(Art.ell(Vector2(0, 30), Vector2(90, 26), 1, 0.03, 24), Color(1, 0.6, 0.2, 0.2))
	Art.item(ci, "fire_4", Vector2.ZERO, 100)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## hide = {区域 id: 部件下标}：正在播建造动画的那件先不画
static func village(ci: CanvasItem, sz: Vector2, builds: Dictionary, level: int = 99, hide: Dictionary = {}) -> void:
	# 地平线在 450 左右；篝火广场的位置决定小路和广场
	var hub := TribeArt.area_at("fire")
	vgrad(ci, Rect2(0, 0, sz.x, 450), Color("7cc6c9"), Color("f6dca0"))
	ci.draw_circle(Vector2(540, 200), 56, Color(1, 0.95, 0.7, 0.6))
	ci.draw_circle(Vector2(540, 200), 39, Color("fff1b8"))
	hills(ci, 320, sz.x, 90, Color("8fb4a8"), 3, 490)
	hills(ci, 390, sz.x, 70, Color("6f9c6a"), 7, 530)
	vgrad(ci, Rect2(0, 450, sz.x, sz.y - 450), Color("9cc35a"), Color("6d9a3c"))
	hills(ci, 490, sz.x, 40, Color("86b54e"), 11, 590)
	for i in 5:
		palm(ci, Vector2(30 + i * 160 + Art.srnd(i) * 40, 490), 110 + Art.srnd(i + 3) * 50, i)
	var river := PackedVector2Array()
	for k in 15:
		var y := 530.0 + float(k) * 70.0
		river.append(Vector2(700 + sin(float(k) * 0.8) * 14.0, y))
	for k in 15:
		var y := 530.0 + float(14 - k) * 70.0
		river.append(Vector2(740 + sin(float(14 - k) * 0.8) * 14.0, y))
	ci.draw_colored_polygon(river, Color("5fb4c8"))
	var path := PackedVector2Array()
	var top := hub.y - 50.0
	var plen := sz.y - top
	for k in 9:
		var t := float(k) / 8.0
		path.append(Vector2(360 + sin(t * 4.0) * 40.0 - 50.0 * (1.0 - t), top + t * plen))
	for k in 9:
		var t := 1.0 - float(k) / 8.0
		path.append(Vector2(360 + sin(t * 4.0) * 40.0 + 50.0 + 40.0 * t, top + t * plen))
	ci.draw_colored_polygon(path, Color("d9b778"))
	ci.draw_colored_polygon(Art.ell(hub + Vector2(0, -10), Vector2(180, 96), 2, 0.04, 30, 0.0, 0.0), Color("d9b778"))
	for i in 40:
		var p := Vector2(Art.srnd(i * 5) * sz.x, 510 + Art.srnd(i * 9) * (sz.y - 530))
		Art.pl(ci, [p, p + Vector2(-4, -10), p + Vector2(0, -2), p + Vector2(5, -11)], 2.0, Color("4f7a1f"), i)
	TribeArt.village(ci, builds, level, hide)

static func _spot_hut(ci: CanvasItem, c: Vector2, st: int) -> void:
	if st == 0:
		return
	var s := 0.9 + 0.08 * float(st)
	ci.draw_set_transform(c, 0.0, Vector2.ONE * s)
	ci.draw_colored_polygon(Art.ell(Vector2(0, 40), Vector2(96, 18), 1, 0.0, 20, 0.0, 0.0), Color(0, 0, 0, 0.15))
	Art.sil(ci, [Art.P(Art.rrect(Rect2(-70, -20, 140, 64), 10, 2, 0.8), Art.WOOD, 1),
		Art.P(Art.poly([Vector2(-96, -10), Vector2(0, -110), Vector2(96, -10)], 3), Color("d9a54a"), 1),
		Art.P(Art.rrect(Rect2(-18, 0, 36, 44), 16, 4, 0.5), Art.LEATHER_D, 2)])
	for i in 8:
		Art.ln(ci, Vector2(0, -104), Vector2(-84 + i * 24, -14), 2.0, Color(0.45, 0.28, 0.05, 0.6), i)
	if st >= 3:
		for i in 6:
			ci.draw_colored_polygon(Art.poly([Vector2(-80 + i * 30, -10), Vector2(-64 + i * 30, -10), Vector2(-72 + i * 30, 6)], i), Art.CLAY if i % 2 == 0 else Art.TEAL)
	if st >= 5:
		Art.sil(ci, [Art.P(Art.ell(Vector2(0, -120), Vector2(14, 10), 9, 0.05), Color("f3e6c8"))], false)
		ci.draw_circle(Vector2(-5, -122), 2.5, Art.INK)
		ci.draw_circle(Vector2(5, -122), 2.5, Art.INK)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## 格子上的奖励气泡。id 为空时画一枚淡淡的空泡，给编辑器点选。
static func reward_bubble(ci: CanvasItem, c: Vector2, rad: float, id: String, n: int, seed: int, lift: float = 0.0) -> void:
	c += Vector2(0, lift)
	var shadow := Art.ell(c + Vector2(0, rad * 0.28), Vector2(rad * 0.86, rad * 0.22), seed, 0.0, 14, 0.0, 0.0)
	ci.draw_colored_polygon(shadow, Color(0, 0, 0, 0.16))
	var body := Art.ell(c, Vector2(rad, rad * 0.94), seed, 0.035, 22)
	var glass := Color(0.9, 0.97, 1.0, 0.55) if id == "" else Color(0.86, 0.96, 1.0, 0.82)
	ci.draw_colored_polygon(body, glass)
	Art.outline(ci, body, maxf(2.0, rad * 0.09), Color(0.25, 0.4, 0.55, 0.85 if id != "" else 0.4))
	var shine := Art.ell(c + Vector2(-rad * 0.32, -rad * 0.38), Vector2(rad * 0.28, rad * 0.16), seed + 3, 0.0, 12, -0.5, 0.0)
	ci.draw_colored_polygon(shine, Color(1, 1, 1, 0.72 if id != "" else 0.35))
	if id == "":
		var arm := rad * 0.34
		var w := maxf(2.0, rad * 0.12)
		ci.draw_line(c + Vector2(-arm, 0), c + Vector2(arm, 0), Color("6a8aaa"), w, true)
		ci.draw_line(c + Vector2(0, -arm), c + Vector2(0, arm), Color("6a8aaa"), w, true)
		return
	var icon_y := -rad * 0.08 if n > 1 else 0.0
	Art.item(ci, id, c + Vector2(0, icon_y), rad * 1.45, false)
	if n <= 1 or G.font_title == null:
		return
	var f: Font = G.font_title
	var fs := int(clampf(round(rad * 0.58), 11.0, 20.0))
	var text := str(n)
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := c + Vector2(-tw * 0.5, rad * 0.62)
	ci.draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(3, int(fs / 5.0)), Art.INK)
	ci.draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
