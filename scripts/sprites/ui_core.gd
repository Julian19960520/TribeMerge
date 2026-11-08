extends RefCounted
## 通用界面零件（按钮、面板、横幅、徽章、进度条……）的界面图登记和原始画法。
## 只给「生成物品图.bat」用；游戏里用 Paint.button 等，它们只贴这里生成的图。
## 登记格式见 scripts/BakeSprites.gd。

static func entries() -> Array:
	var out: Array = []
	for style in Paint.BTN:
		out.append({"key": "btn_" + style, "w": 240, "h": 88, "pad": 14, "nine": [34, 30, 34, 36],
			"draw": func(ci, r): live_button(ci, r, style)})
		out.append({"key": "rbtn_" + style, "w": 80, "h": 80, "pad": 12,
			"draw": func(ci, r): live_round_btn(ci, r.get_center(), 40.0, style)})
	out.append({"key": "panel", "w": 420, "h": 380, "pad": 18, "nine": [72, 64, 72, 72],
		"draw": func(ci, r): live_panel(ci, r, false)})
	out.append({"key": "panel_ornament", "w": 120, "h": 24, "pad": 6,
		"draw": func(ci, r): live_ornament(ci, r.get_center(), 1)})
	out.append({"key": "banner_base", "w": 420, "h": 84, "pad": 14, "nine": [72, 26, 72, 26],
		"draw": func(ci, r): live_banner_base(ci, r)})
	out.append({"key": "banner_fill", "w": 406, "h": 70, "pad": 4, "nine": [60, 20, 60, 20],
		"draw": func(ci, r): live_banner_fill(ci, r)})
	out.append({"key": "banner_top", "w": 420, "h": 84, "pad": 14, "nine": [72, 26, 72, 26],
		"draw": func(ci, r): live_banner_top(ci, r)})
	out.append({"key": "close_btn", "w": 70, "h": 70, "pad": 10,
		"draw": func(ci, r): live_close_btn(ci, r.get_center(), 26.0)})
	out.append({"key": "pill", "w": 216, "h": 40, "pad": 8, "nine": [22, 18, 22, 18],
		"draw": func(ci, r): live_pill(ci, r)})
	out.append({"key": "plus_badge", "w": 34, "h": 34, "pad": 4,
		"draw": func(ci, r): live_plus_badge(ci, r.get_center())})
	out.append({"key": "badge_num", "w": 38, "h": 38, "pad": 4,
		"draw": func(ci, r): live_badge_num(ci, r.get_center())})
	out.append({"key": "check_mark", "w": 34, "h": 34, "pad": 4,
		"draw": func(ci, r): live_check_mark(ci, r.get_center())})
	out.append({"key": "level_badge", "w": 250, "h": 230, "pad": 10,
		"draw": func(ci, r): live_level_badge(ci, r.get_center() + Vector2(0, -2), 220.0)})
	out.append({"key": "bar_bg", "w": 200, "h": 36, "pad": 6, "nine": [18, 17, 18, 17],
		"draw": func(ci, r): _bar_bg(ci, r)})
	out.append({"key": "bar_fill", "w": 194, "h": 30, "pad": 2, "nine": [15, 14, 15, 14],
		"draw": func(ci, r): ci.draw_colored_polygon(Art.rrect(r, r.size.y * 0.5, 10, 0.4), Color.WHITE)})
	# 细进度条单独画一套，九宫格缩太多会变尖
	out.append({"key": "bar_bg_thin", "w": 160, "h": 12, "pad": 5, "nine": [7, 6, 7, 6],
		"draw": func(ci, r): _bar_bg(ci, r)})
	out.append({"key": "bar_fill_thin", "w": 154, "h": 6, "pad": 2, "nine": [4, 3, 4, 3],
		"draw": func(ci, r): ci.draw_colored_polygon(Art.rrect(r, r.size.y * 0.5, 10, 0.4), Color.WHITE)})
	out.append({"key": "bar_hl", "w": 100, "h": 10, "pad": 2, "nine": [5, 4, 5, 4],
		"draw": func(ci, r): ci.draw_colored_polygon(Art.rrect(r, 4, 11, 0.0), Color.WHITE)})
	out.append({"key": "cell_bracket", "w": 96, "h": 96, "pad": 8, "nine": [44, 44, 44, 44], "static": true,
		"draw": func(ci, r): live_cell_bracket(ci, r, Color.WHITE)})
	out.append({"key": "speech_body", "w": 400, "h": 140, "pad": 14, "nine": [40, 36, 40, 40],
		"draw": func(ci, r): live_speech_body(ci, r)})
	out.append({"key": "speech_tail_l", "w": 80, "h": 64, "pad": 6,
		"draw": func(ci, r): live_speech_tail(ci, r.get_center(), true)})
	out.append({"key": "speech_tail_r", "w": 80, "h": 64, "pad": 6,
		"draw": func(ci, r): live_speech_tail(ci, r.get_center(), false)})
	return out

static func _bar_bg(ci: CanvasItem, r: Rect2) -> void:
	var b := Art.rrect(r, r.size.y * 0.5, 9, 0.5)
	Art.dilate(ci, b, 3.0, Art.INK)
	ci.draw_colored_polygon(b, Color("5a3d24"))

static func live_banner_base(ci: CanvasItem, r: Rect2, seed: int = 2) -> void:
	ci.draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(0, 8), r.size), 16, seed, 0.0), Color(0, 0, 0, 0.3))
	var body := Art.rrect(r, 16, seed, 1.0)
	Art.dilate(ci, body, 3.0, Art.INK)
	ci.draw_colored_polygon(body, Art.OCHRE)

## 布面用白色画，运行时按横幅颜色染色
static func live_banner_fill(ci: CanvasItem, ir: Rect2, seed: int = 2) -> void:
	ci.draw_colored_polygon(Art.rrect(ir, 11, seed + 1, 0.8), Color.WHITE)

static func live_banner_top(ci: CanvasItem, r: Rect2, seed: int = 2) -> void:
	var ir := r.grow(-7)
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

static func live_button(ci: CanvasItem, r: Rect2, style: String, seed: int = 0, pressed: bool = false) -> void:
	var cols: Array = Paint.BTN.get(style, Paint.BTN["green"])
	var rad: float = min(r.size.y * 0.5, 30.0)
	var depth: float = 0.0 if pressed else 7.0
	ci.draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(2, 6), r.size), rad, seed, 0.0), Color(0, 0, 0, 0.28))
	var base := Art.rrect(r, rad, seed, 0.7)
	Art.dilate(ci, base, 3.0, Art.INK)
	ci.draw_colored_polygon(base, cols[1])
	var top_r := Rect2(r.position + Vector2(0, 7.0 - depth), r.size - Vector2(0, 7))
	ci.draw_colored_polygon(Art.rrect(top_r, minf(rad, minf(top_r.size.x, top_r.size.y) * 0.5 - 2.0), seed + 1, 0.7), cols[0])
	var hl := Rect2(top_r.position + Vector2(rad * 0.6, 5), Vector2(top_r.size.x - rad * 1.2, top_r.size.y * 0.26))
	ci.draw_colored_polygon(Art.rrect(hl, hl.size.y * 0.5, seed + 2, 0.4), Color(cols[2], 0.75))
	for i in 7:
		var p := r.position + Vector2(Art.srnd(seed * 7 + i) * r.size.x * 0.8 + r.size.x * 0.1, Art.srnd(seed * 11 + i) * r.size.y * 0.5 + r.size.y * 0.35)
		ci.draw_circle(p, 1.5 + Art.srnd(i + seed) * 1.5, Color(0, 0, 0, 0.08))

static func live_round_btn(ci: CanvasItem, c: Vector2, rad: float, style: String, seed: int = 0) -> void:
	var cols: Array = Paint.BTN.get(style, Paint.BTN["teal"])
	ci.draw_colored_polygon(Art.ell(c + Vector2(0, 6), Vector2(rad, rad), seed, 0.0, 24, 0.0, 0.0), Color(0, 0, 0, 0.28))
	var base := Art.ell(c, Vector2(rad, rad), seed, 0.02, 24)
	Art.dilate(ci, base, 3.0, Art.INK)
	ci.draw_colored_polygon(base, cols[1])
	ci.draw_colored_polygon(Art.ell(c - Vector2(0, 3), Vector2(rad - 2, rad - 4), seed + 1, 0.02, 24), cols[0])
	ci.draw_colored_polygon(Art.ell(c + Vector2(-rad * 0.3, -rad * 0.45), Vector2(rad * 0.4, rad * 0.2), seed + 2, 0.0, 14, -0.4), Color(cols[2], 0.7))

static func live_panel(ci: CanvasItem, r: Rect2, with_ornament: bool = true, seed: int = 1) -> void:
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
	if with_ornament:
		live_ornament(ci, Vector2(ir.get_center().x, ir.end.y - 18), seed)

static func live_ornament(ci: CanvasItem, c: Vector2, seed: int) -> void:
	var col := Color(0.55, 0.36, 0.18, 0.45)
	ci.draw_colored_polygon(Art.star_pts(c, 7, 3, 4, seed), col)
	Art.pl(ci, [c + Vector2(-14, 0), c + Vector2(-30, -4), c + Vector2(-46, 0)], 2.0, col, seed)
	Art.pl(ci, [c + Vector2(14, 0), c + Vector2(30, -4), c + Vector2(46, 0)], 2.0, col, seed + 1)
	ci.draw_circle(c + Vector2(-54, 0), 3.0, col)
	ci.draw_circle(c + Vector2(54, 0), 3.0, col)

static func live_banner(ci: CanvasItem, r: Rect2, col: Color, seed: int = 2) -> void:
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

static func live_close_btn(ci: CanvasItem, c: Vector2, rad: float = 26.0, seed: int = 4) -> void:
	ci.draw_colored_polygon(Art.ell(c + Vector2(0, 5), Vector2(rad, rad), seed, 0.0, 20, 0.0, 0.0), Color(0, 0, 0, 0.3))
	Art.sil(ci, [Art.P(Art.ell(c + Vector2(4, -rad - 2), Vector2(11, 5), seed + 1, 0.05, 12, -0.5), Art.LEAF, 1),
		Art.P(Art.ell(c, Vector2(rad, rad), seed + 2, 0.03, 22), Art.CLAY)], false)
	var k := rad * 0.42
	Art.sil(ci, [Art.P(Art.capsule(c + Vector2(-k, -k), c + Vector2(k, k), 4.5, seed + 3), Art.BONE, 2),
		Art.P(Art.capsule(c + Vector2(k, -k), c + Vector2(-k, k), 4.5, seed + 4), Art.BONE, 2)], false, 2.0)

static func live_pill(ci: CanvasItem, r: Rect2, seed: int = 5) -> void:
	var b := Art.rrect(r, r.size.y * 0.5, seed, 0.6)
	Art.dilate(ci, b, 3.0, Art.INK)
	ci.draw_colored_polygon(b, Art.BONE)
	ci.draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(6, r.size.y * 0.6), Vector2(r.size.x - 12, r.size.y * 0.32)), 8, seed + 1, 0.0), Color(0.6, 0.4, 0.2, 0.12))

static func live_plus_badge(ci: CanvasItem, c: Vector2, seed: int = 6) -> void:
	var b := Art.ell(c, Vector2(13, 13), seed, 0.02, 16)
	Art.dilate(ci, b, 2.5, Art.INK)
	ci.draw_colored_polygon(b, Art.MOSS)
	ci.draw_line(c + Vector2(-6, 0), c + Vector2(6, 0), Color.WHITE, 4.0, true)
	ci.draw_line(c + Vector2(0, -6), c + Vector2(0, 6), Color.WHITE, 4.0, true)

static func live_badge_num(ci: CanvasItem, c: Vector2, seed: int = 7, radius: float = 16.0) -> void:
	var b := Art.ell(c, Vector2(radius, radius), seed, 0.02, 16)
	Art.dilate(ci, b, 2.5, Art.INK)
	ci.draw_colored_polygon(b, Art.CLAY)

static func live_level_badge(ci: CanvasItem, c: Vector2, s: float, seed: int = 8) -> void:
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

static func live_bar(ci: CanvasItem, r: Rect2, t: float, col: Color = Art.MOSS, seed: int = 9) -> void:
	var b := Art.rrect(r, r.size.y * 0.5, seed, 0.5)
	Art.dilate(ci, b, 3.0, Art.INK)
	ci.draw_colored_polygon(b, Color("5a3d24"))
	t = clampf(t, 0.0, 1.0)
	if t > 0.02:
		var fr := Rect2(r.position + Vector2(3, 3), Vector2(maxf(r.size.y - 6, (r.size.x - 6) * t), r.size.y - 6))
		ci.draw_colored_polygon(Art.rrect(fr, fr.size.y * 0.5, seed + 1, 0.4), col)
		ci.draw_colored_polygon(Art.rrect(Rect2(fr.position + Vector2(6, 2), Vector2(max(4, fr.size.x - 12), fr.size.y * 0.3)), 4, seed + 2, 0.0), Color(1, 1, 1, 0.35))

static func live_cell_bracket(ci: CanvasItem, r: Rect2, col: Color = Color("ffd23f")) -> void:
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

static func live_check_mark(ci: CanvasItem, c: Vector2, s: float = 1.0) -> void:
	var b := Art.ell(c, Vector2(13, 13) * s, 3, 0.02, 16)
	Art.dilate(ci, b, 2.5, Art.INK)
	ci.draw_colored_polygon(b, Art.MOSS)
	ci.draw_polyline(PackedVector2Array([c + Vector2(-6, 0) * s, c + Vector2(-1, 5) * s, c + Vector2(7, -5) * s]), Color.WHITE, 3.5 * s, true)

## 引导气泡。point_left 时尾巴朝左。
static func live_speech(ci: CanvasItem, r: Rect2, point_left: bool, seed: int = 8) -> void:
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

## 气泡身子（不带尾巴），九宫格拉伸
static func live_speech_body(ci: CanvasItem, r: Rect2, seed: int = 8) -> void:
	ci.draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(0, 8), r.size), 24, seed, 0.0), Color(0, 0, 0, 0.35))
	var body := Art.rrect(r, 24, seed, 0.85)
	Art.dilate(ci, body, 3.0, Art.INK)
	ci.draw_colored_polygon(body, Art.BONE)
	Art.dashed(ci, Art.rrect(r.grow(-9), 16, seed + 2, 0.0), 9, 6, Color("e4c59a"), 2.0)

## 气泡尾巴。base 是尾巴根部中点（身子边往里 12 像素）
static func live_speech_tail(ci: CanvasItem, base: Vector2, point_left: bool) -> void:
	var tip := base + (Vector2(-38, 10) if point_left else Vector2(38, 10))
	var a := base + Vector2(0, -24)
	var b := base + Vector2(0, 22)
	var tail := PackedVector2Array([a, tip, b])
	ci.draw_colored_polygon(tail, Art.BONE)
	ci.draw_polyline(PackedVector2Array([a + Vector2(0, -1.5), tip, b + Vector2(0, 1.5)]), Art.INK, 3.0, true)
	var x0 := base.x - 12.0 if point_left else base.x + 12.0
	var inner := 1.0 if point_left else -1.0
	# 盖住身子在尾巴根部的描边，让尾巴和身子连成一片
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(x0 - 4.0 * inner, a.y + 3), Vector2(x0 + 8.0 * inner, a.y + 3),
		Vector2(x0 + 8.0 * inner, b.y - 3), Vector2(x0 - 4.0 * inner, b.y - 3)]), Art.BONE)

