extends RefCounted
## Paint 里图标、角色、卡牌、背景零件的界面图登记和原始画法。
## 只给「生成物品图.bat」用；游戏里用 Paint.hammer / Paint.glyph 等，它们只贴这里生成的图。
## 登记格式见 scripts/BakeSprites.gd。

const Meme := preload("res://scripts/Meme.gd")

## 小图标按 2 倍画，贴的时候 ×0.5
const GLYPHS := ["music", "sound", "vibrate", "hint", "chat", "faq", "globe", "gear", "info", "trash", "lock", "clock"]
const GLYPH_FIXED := ["info", "lock", "clock"]
## 生成时用的尺寸（贴图时按调用的尺寸 / 这个缩放）
const K_HAMMER := 1.4
const K_BOOK := 1.2
const K_CARDS := 1.45
const K_HUT := 1.1
const K_POUCH := 1.2
const K_HOME := 1.0
const S_GIFT := 86.0
const S_MASCOT := 120.0
const W_HERO := 200.0
const R_FACE := 40.0
const R_MINI := 20.0
const R_MOUTH := 34.0
const R_BUBBLE := 60.0
const K_SPOT := 1.4
const K_ROCK := 2.0
## 用得到的山丘、棕榈种子（调用处都是写死的数）
const HILL_SEEDS := [2, 3, 4, 5, 6, 7, 11, 723, 724, 907, 908]
const PALM_SEEDS := [0, 1, 2, 3, 4, 5, 8, 10, 11, 12, 13, 725, 726, 909, 910]
const CFG_KINDS := ["board", "story", "pass", "people", "amber", "rules", "rand", "unlock"]

static func entries() -> Array:
	var out: Array = []
	for kind in GLYPHS:
		out.append({"key": "paint_glyph_" + kind, "w": 104, "h": 104, "pad": 4, "static": kind != "gear",
			"draw": func(ci, r): live_glyph(ci, kind, r.get_center(), 2.0, Color.WHITE, false)})
	out.append({"key": "paint_glyph_gear_hole", "w": 28, "h": 28, "pad": 2, "static": true,
		"draw": func(ci, r): ci.draw_circle(r.get_center(), 12.0, Art.TEAL.darkened(0.3))})
	out.append({"key": "paint_gift", "w": 80, "h": 80, "pad": 8,
		"draw": func(ci, r): live_gift(ci, r.get_center(), S_GIFT)})
	out.append({"key": "paint_hammer", "w": int(124 * K_HAMMER), "h": int(124 * K_HAMMER), "pad": 8,
		"draw": func(ci, r): live_hammer(ci, r.get_center(), K_HAMMER)})
	out.append({"key": "paint_book", "w": int(92 * K_BOOK), "h": int(92 * K_BOOK), "pad": 6,
		"draw": func(ci, r): live_book(ci, r.get_center(), K_BOOK)})
	out.append({"key": "paint_cards", "w": int(116 * K_CARDS), "h": int(100 * K_CARDS), "pad": 6,
		"draw": func(ci, r): live_cards_icon(ci, r.get_center(), K_CARDS)})
	out.append({"key": "paint_hut", "w": int(106 * K_HUT), "h": int(100 * K_HUT), "pad": 6,
		"draw": func(ci, r): live_hut_icon(ci, r.get_center(), K_HUT)})
	out.append({"key": "paint_pouch", "w": int(96 * K_POUCH), "h": int(104 * K_POUCH), "pad": 6,
		"draw": func(ci, r): live_pouch(ci, r.get_center(), K_POUCH)})
	out.append({"key": "paint_home", "w": int(80 * K_HOME), "h": int(96 * K_HOME), "pad": 6,
		"draw": func(ci, r): live_home_icon(ci, r.get_center(), K_HOME)})
	for kind in CFG_KINDS:
		out.append({"key": "paint_cfg_" + kind, "w": 112, "h": 112, "pad": 6,
			"draw": func(ci, r): live_cfg(ci, kind, r.get_center(), 1.0)})
	out.append({"key": "paint_cfg_tile_base", "w": 32, "h": 32, "pad": 4, "nine": [9, 9, 9, 9],
		"draw": func(ci, r): Art.dilate(ci, _tile_pts(r, 1), 2.0, Art.INK)})
	out.append({"key": "paint_cfg_tile_fill", "w": 32, "h": 32, "pad": 4, "nine": [9, 9, 9, 9],
		"draw": func(ci, r): ci.draw_colored_polygon(_tile_pts(r, 1), Color.WHITE)})
	out.append({"key": "paint_cfg_tile_line", "w": 32, "h": 32, "pad": 4, "nine": [9, 9, 9, 9],
		"draw": func(ci, r): Art.outline(ci, _tile_pts(r, 1), 1.7, Art.INK)})
	out.append({"key": "paint_cfg_pip_fill", "w": 16, "h": 16, "pad": 3,
		"draw": func(ci, r): ci.draw_colored_polygon(Art.ell(r.get_center(), Vector2(6.5, 6.5), 0, 0.04, 10), Color.WHITE)})
	out.append({"key": "paint_cfg_pip_line", "w": 16, "h": 16, "pad": 3,
		"draw": func(ci, r): Art.outline(ci, Art.ell(r.get_center(), Vector2(6.5, 6.5), 0, 0.04, 10), 1.5, Art.INK)})
	# 脸：墨线底 + 白色皮肤（按肤色染）+ 五官
	var fw := int(R_FACE * 2.6)
	var fh := int(R_FACE * 2.4)
	out.append({"key": "paint_face_base", "w": fw, "h": fh, "pad": 6,
		"draw": func(ci, r): live_face_base(ci, r.get_center(), R_FACE, 0)})
	out.append({"key": "paint_face_skin", "w": fw, "h": fh, "pad": 6,
		"draw": func(ci, r): live_face_skin(ci, r.get_center(), R_FACE, 0)})
	out.append({"key": "paint_face_top", "w": fw, "h": fh, "pad": 6,
		"draw": func(ci, r): live_face_top(ci, r.get_center(), R_FACE, 0, true)})
	out.append({"key": "paint_face_top_plain", "w": fw, "h": fh, "pad": 6,
		"draw": func(ci, r): live_face_top(ci, r.get_center(), R_FACE, 0, false)})
	out.append({"key": "paint_mini_face_skin", "w": 46, "h": 46, "pad": 3,
		"draw": func(ci, r): ci.draw_colored_polygon(Art.ell(r.get_center(), Vector2(R_MINI, R_MINI * 1.02), 0, 0.03, 14), Color.WHITE)})
	out.append({"key": "paint_mini_face_line", "w": 46, "h": 46, "pad": 3,
		"draw": func(ci, r): live_mini_face_line(ci, r.get_center(), R_MINI, 0)})
	out.append({"key": "paint_face_mouth", "w": 24, "h": 48, "pad": 4,
		"draw": func(ci, r): live_face_mouth_only(ci, r.get_center(), R_MOUTH)})
	for kind in 4:
		out.append({"key": "paint_portrait_%d" % kind, "w": 150, "h": 216, "pad": 6,
			"draw": func(ci, r): live_portrait(ci, kind, r.get_center(), 100.0)})
	# 角色
	var mk := S_MASCOT / 100.0
	out.append({"key": "paint_mascot", "w": int(210 * mk), "h": int(200 * mk), "pad": 8,
		"draw": func(ci, r): live_mascot(ci, r.get_center(), S_MASCOT, "")})
	out.append({"key": "paint_mascot_hammer", "w": int(210 * mk), "h": int(200 * mk), "pad": 8,
		"draw": func(ci, r): live_mascot(ci, r.get_center(), S_MASCOT, "hammer")})
	var hk := W_HERO / 100.0
	out.append({"key": "paint_hero", "w": int(170 * hk), "h": int(200 * hk), "pad": 8,
		"draw": func(ci, r): live_hero_at(ci, r.get_center(), W_HERO)})
	# 岩画：白色画，按墨色染
	out.append({"key": "paint_rock_mammoth", "w": 200, "h": 144, "pad": 6,
		"draw": func(ci, r): live_mammoth(ci, r.get_center(), K_ROCK, Color.WHITE, 0, 1)})
	out.append({"key": "paint_rock_mammoth_tusk", "w": 200, "h": 144, "pad": 6,
		"draw": func(ci, r): live_mammoth(ci, r.get_center(), K_ROCK, Color.WHITE, 0, 2)})
	out.append({"key": "paint_rock_deer", "w": 168, "h": 200, "pad": 6,
		"draw": func(ci, r): live_deer(ci, r.get_center(), K_ROCK, Color.WHITE, 0)})
	out.append({"key": "paint_rock_hunter", "w": 88, "h": 152, "pad": 6,
		"draw": func(ci, r): live_hunter(ci, r.get_center(), K_ROCK, Color.WHITE, 0)})
	out.append({"key": "paint_rock_hand", "w": 120, "h": 120, "pad": 6,
		"draw": func(ci, r): live_hand(ci, r.get_center(), K_ROCK, Color.WHITE, 0)})
	out.append({"key": "paint_rock_fish", "w": 112, "h": 48, "pad": 6,
		"draw": func(ci, r): _at_k(ci, r.get_center(), K_ROCK, func(): live_fish_glyph(ci, Vector2.ZERO, Color.WHITE, 0))})
	out.append({"key": "paint_rock_rays", "w": 144, "h": 144, "pad": 6,
		"draw": func(ci, r): _at_k(ci, r.get_center(), K_ROCK, func(): live_sun_rays(ci, Vector2.ZERO, Color.WHITE))})
	out.append({"key": "paint_rock_flame", "w": 88, "h": 96, "pad": 6,
		"draw": func(ci, r): _at_k(ci, r.get_center(), K_ROCK, func(): ci.draw_colored_polygon(Art.flame_pts(Vector2.ZERO, 16, 40, 0), Color.WHITE))})
	# 卡牌
	out.append({"key": "paint_card_frame", "w": 172, "h": 242, "pad": 12, "nine": [24, 24, 24, 24],
		"draw": func(ci, r): live_card_frame(ci, r, 0)})
	out.append({"key": "paint_card_locked", "w": 156, "h": 174, "pad": 4,
		"draw": func(ci, r): live_card_locked_lines(ci, r)})
	out.append({"key": "paint_card_band", "w": 164, "h": 53, "pad": 4, "nine": [10, 10, 10, 10],
		"draw": func(ci, r): ci.draw_colored_polygon(Art.rrect(r, 6, 0, 0.4), Art.OCHRE)})
	out.append({"key": "paint_card_star", "w": 26, "h": 26, "pad": 4,
		"draw": func(ci, r): live_card_star(ci, r.get_center(), 0)})
	# 背景
	for seed in HILL_SEEDS:
		out.append({"key": "paint_hill_%d" % seed, "w": 720, "h": 130, "pad": 2, "static": true,
			"draw": func(ci, r): live_hill_profile(ci, r, seed)})
	out.append({"key": "paint_palm_trunk", "w": 12, "h": 128, "pad": 2,
		"draw": func(ci, r): Art.ln(ci, Vector2(r.get_center().x, r.position.y), Vector2(r.get_center().x, r.end.y), 9.0, Color.WHITE, 0)})
	for seed in PALM_SEEDS:
		out.append({"key": "paint_palm_%d" % seed, "w": 128, "h": 96, "pad": 4,
			"draw": func(ci, r): live_palm_crown(ci, r.get_center(), seed, Color.WHITE)})
	out.append({"key": "paint_campfire_glow", "w": 184, "h": 56, "pad": 4,
		"draw": func(ci, r): ci.draw_colored_polygon(Art.ell(r.get_center(), Vector2(90, 26), 1, 0.03, 24), Color(1, 0.6, 0.2, 0.2))})
	for st in [1, 3, 5]:
		out.append({"key": "paint_spot_hut_%d" % st, "w": int(212 * K_SPOT), "h": int(280 * K_SPOT), "pad": 6,
			"draw": func(ci, r): live_spot_hut(ci, r.get_center(), st, K_SPOT)})
	out.append({"key": "paint_bubble", "w": 128, "h": 128, "pad": 6,
		"draw": func(ci, r): live_bubble_frame(ci, r.get_center(), R_BUBBLE, false, 0)})
	out.append({"key": "paint_bubble_empty", "w": 128, "h": 128, "pad": 6,
		"draw": func(ci, r): live_bubble_frame(ci, r.get_center(), R_BUBBLE, true, 0)})
	return out

## 在 c 处按 k 缩放画 fn（fn 用以原点为中心的坐标）
static func _at_k(ci: CanvasItem, c: Vector2, k: float, fn: Callable) -> void:
	ci.draw_set_transform(c, 0.0, Vector2.ONE * k)
	fn.call()
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func _tile_pts(r: Rect2, seed: int) -> PackedVector2Array:
	return Art.rrect(r, minf(8.0, r.size.x * 0.22), seed, 0.22)

# ---------------------------------------------------------------- 小图标

## gear_hole=false 时齿轮不画中间的孔（孔单独一张图，不染色）
static func live_glyph(ci: CanvasItem, kind: String, c: Vector2, s: float = 1.0, col: Color = Color.WHITE, gear_hole: bool = true) -> void:
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
			if gear_hole:
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

static func live_gift(ci: CanvasItem, c: Vector2, s: float) -> void:
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

# ---------------------------------------------------------------- 大图标

static func live_hammer(ci: CanvasItem, c: Vector2, s: float = 1.0) -> void:
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

static func live_book(ci: CanvasItem, c: Vector2, s: float = 1.0) -> void:
	ci.draw_set_transform(c, 0.0, Vector2.ONE * s)
	Art.sil(ci, [Art.P(Art.rrect(Rect2(-34, -30, 68, 60), 8, 1, 0.6), Art.LEATHER, 1),
		Art.P(Art.rrect(Rect2(-28, -26, 56, 50), 4, 2, 0.6), Art.HIDE, 2)])
	Art.ln(ci, Vector2(0, -26), Vector2(0, 24), 2.5, Art.LEATHER_D, 1)
	ci.draw_colored_polygon(Art.star_pts(Vector2(-14, -4), 9, 4, 4, 3), Art.CLAY)
	for i in 3:
		Art.ln(ci, Vector2(6, -12 + i * 10), Vector2(22, -12 + i * 10), 2.0, Color(0.4, 0.25, 0.1, 0.6), i)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func live_cards_icon(ci: CanvasItem, c: Vector2, s: float = 1.0) -> void:
	ci.draw_set_transform(c, 0.0, Vector2.ONE * s)
	Art.sil(ci, [Art.P(Art.poly(Art.rot_pts([Vector2(-20, -28), Vector2(20, -28), Vector2(20, 28), Vector2(-20, 28)], -0.25, Vector2(-10, 2)), 1), Art.TEAL, 1),
		Art.P(Art.poly(Art.rot_pts([Vector2(-20, -28), Vector2(20, -28), Vector2(20, 28), Vector2(-20, 28)], 0.2, Vector2(10, 0)), 2), Art.OCHRE, 1)])
	ci.draw_colored_polygon(Art.star_pts(Vector2(10, 0), 12, 5, 5, 3), Art.BONE)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func live_hut_icon(ci: CanvasItem, c: Vector2, s: float = 1.0) -> void:
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

static func live_pouch(ci: CanvasItem, c: Vector2, s: float = 1.0) -> void:
	ci.draw_set_transform(c, 0.0, Vector2.ONE * s)
	Art.sil(ci, [Art.P(Art.ell(Vector2(0, 8), Vector2(34, 30), 1, 0.06), Color("b9844e")),
		Art.P(Art.poly([Vector2(-16, -18), Vector2(-24, -36), Vector2(0, -30), Vector2(24, -36), Vector2(16, -18)], 2), Color("a3703f"), 1)])
	Art.pl(ci, [Vector2(-20, -18), Vector2(0, -14), Vector2(20, -18)], 4.0, Art.ROPE, 3)
	Art.dashed(ci, Art.ell(Vector2(0, 10), Vector2(24, 20), 4, 0.0, 20, 0.0, 0.0), 5, 4, Art.BONE, 2.0)
	ci.draw_circle(Vector2(0, 10), 7.0, Art.TEAL)
	ci.draw_circle(Vector2(0, 10), 7.0, Art.INK, false, 2.0, true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func live_home_icon(ci: CanvasItem, c: Vector2, s: float = 1.0) -> void:
	ci.draw_set_transform(c, 0.0, Vector2.ONE * s)
	Art.sil(ci, [Art.P(Art.poly([Vector2(-34, 30), Vector2(0, -34), Vector2(34, 30)], 1), Color("d9a54a"), 1),
		Art.P(Art.poly([Vector2(-10, 30), Vector2(0, 6), Vector2(10, 30)], 2), Art.LEATHER_D, 2)], false)
	for i in 4:
		Art.ln(ci, Vector2(0, -28), Vector2(-24 + i * 16, 28), 1.8, Color(0.45, 0.28, 0.05, 0.6), i)
	Art.ln(ci, Vector2(-6, -44), Vector2(6, -24), 3.0, Art.WOOD_D, 5)
	Art.ln(ci, Vector2(6, -44), Vector2(-6, -24), 3.0, Art.WOOD_D, 6)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ---------------------------------------------------------------- 配置页图标

static func live_cfg(ci: CanvasItem, kind: String, c: Vector2, s: float) -> void:
	match kind:
		"board": _cfg_board(ci, c, s)
		"story": _cfg_story(ci, c, s)
		"pass": _cfg_pass(ci, c, s)
		"people": _cfg_people(ci, c, s)
		"amber": _cfg_amber(ci, c, s)
		"rules": _cfg_rules(ci, c, s)
		"rand": _cfg_rand(ci, c, s)
		"unlock": _cfg_unlock(ci, c, s)

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
		live_cfg_tile(ci, r, Color("8cc63f") if on else Color("c8c0b4"), 40 + i)
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
		live_cfg_tile(ci, r, Color("fff7e6"), 20 + i)
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
	live_mini_face(ci, Vector2(-16, 2), 11.0, Color("b97a4a"), 12)
	Art.fill(ci, Art.ell(Vector2(10, 6), Vector2(7, 7), 8, 0.04, 10), Art.BERRY, 1.5)
	Art.fill(ci, Art.ell(Vector2(20, 10), Vector2(7, 7), 9, 0.04, 10), Art.BERRY, 1.5)
	Art.ln(ci, Vector2(14, 2), Vector2(16, -8), 1.8, Art.LEAF_D, 2)
	Art.fill(ci, Art.ell(Vector2(20, -8), Vector2(6, 3), 10, 0.0, 8, -0.4), Art.LEAF, 1.3)
	Art.fill(ci, Art.star_pts(Vector2(26, -14), 9, 4, 5, 11), Art.OCHRE, 1.5)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func _cfg_pass(ci: CanvasItem, c: Vector2, s: float) -> void:
	ci.draw_set_transform(c, 0.0, Vector2.ONE * s)
	live_cfg_tile(ci, Rect2(-34, -22, 32, 56), Color("e4d0aa"), 1)
	live_cfg_tile(ci, Rect2(2, -22, 32, 56), Art.BONE, 2)
	Art.fill(ci, Art.star_pts(Vector2(0, -32), 13, 6, 5, 3), Art.OCHRE, 1.8)
	live_cfg_pip(ci, Vector2(-18, -6), Art.SHELL)
	live_cfg_pip(ci, Vector2(-18, 16), Art.MOSS)
	live_cfg_pip(ci, Vector2(18, -6), Art.AMBER)
	live_cfg_pip(ci, Vector2(18, 16), Art.TEAL)
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
	live_face(ci, Vector2(0, 2), 18, Color("b97a4a"), 11)
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

static func live_cfg_tile(ci: CanvasItem, r: Rect2, fill: Color, seed: int) -> void:
	var b := Art.rrect(r, minf(8.0, r.size.x * 0.22), seed, 0.22)
	Art.dilate(ci, b, 2.0, Art.INK)
	ci.draw_colored_polygon(b, fill)
	Art.outline(ci, b, 1.7, Art.INK)

static func live_cfg_pip(ci: CanvasItem, c: Vector2, col: Color) -> void:
	Art.fill(ci, Art.ell(c, Vector2(6.5, 6.5), int(c.x + c.y), 0.04, 10), col, 1.5)

# ---------------------------------------------------------------- 脸

static func live_mini_face(ci: CanvasItem, c: Vector2, r: float, skin: Color, seed: int) -> void:
	Art.fill(ci, Art.ell(c, Vector2(r, r * 1.02), seed, 0.03, 14), skin, 1.6)
	for sx in [-1.0, 1.0]:
		ci.draw_circle(c + Vector2(r * 0.34 * sx, -r * 0.02), r * 0.16, Art.INK)
	Art.pl(ci, [c + Vector2(-r * 0.28, r * 0.32), c + Vector2(0, r * 0.52), c + Vector2(r * 0.28, r * 0.32)], maxf(1.5, r * 0.12), Art.INK, seed)

## 小脸去掉肤色那层：描边 + 眼睛嘴巴
static func live_mini_face_line(ci: CanvasItem, c: Vector2, r: float, seed: int) -> void:
	Art.outline(ci, Art.ell(c, Vector2(r, r * 1.02), seed, 0.03, 14), 1.6, Art.INK)
	for sx in [-1.0, 1.0]:
		ci.draw_circle(c + Vector2(r * 0.34 * sx, -r * 0.02), r * 0.16, Art.INK)
	Art.pl(ci, [c + Vector2(-r * 0.28, r * 0.32), c + Vector2(0, r * 0.52), c + Vector2(r * 0.28, r * 0.32)], maxf(1.5, r * 0.12), Art.INK, seed)

static func _face_parts(c: Vector2, r: float, seed: int) -> Array:
	return [Art.ell(c + Vector2(-r * 0.95, r * 0.1), Vector2(r * 0.2, r * 0.26), seed, 0.03, 12),
		Art.ell(c + Vector2(r * 0.95, r * 0.1), Vector2(r * 0.2, r * 0.26), seed + 1, 0.03, 12),
		Art.ell(c, Vector2(r, r * 1.02), seed + 2, 0.03, 24)]

## 原样的整张脸（只给生成用的组合图调用）
static func live_face(ci: CanvasItem, c: Vector2, r: float, skin: Color, seed: int, smile: bool = true) -> void:
	Art.sil(ci, [Art.P(Art.ell(c + Vector2(-r * 0.95, r * 0.1), Vector2(r * 0.2, r * 0.26), seed, 0.03, 12), skin),
		Art.P(Art.ell(c + Vector2(r * 0.95, r * 0.1), Vector2(r * 0.2, r * 0.26), seed + 1, 0.03, 12), skin),
		Art.P(Art.ell(c, Vector2(r, r * 1.02), seed + 2, 0.03, 24), skin)], false)
	_face_features(ci, c, r, skin, seed, smile, true)

static func _face_features(ci: CanvasItem, c: Vector2, r: float, skin: Color, seed: int, smile: bool, nose: bool) -> void:
	for sx in [-1.0, 1.0]:
		var e := c + Vector2(r * 0.38 * sx, r * 0.08)
		ci.draw_colored_polygon(Art.ell(e, Vector2(r * 0.17, r * 0.22), seed + 3, 0.0, 14), Color.WHITE)
		ci.draw_circle(e + Vector2(0, r * 0.03), r * 0.13, Color("3a2412"))
		ci.draw_circle(e + Vector2(-r * 0.04, -r * 0.03), r * 0.05, Color.WHITE)
		Art.pl(ci, [e + Vector2(-r * 0.2, -r * 0.3), e + Vector2(0, -r * 0.36), e + Vector2(r * 0.2, -r * 0.3)], r * 0.06, Art.INK, seed + 4)
		ci.draw_colored_polygon(Art.ell(c + Vector2(r * 0.58 * sx, r * 0.42), Vector2(r * 0.14, r * 0.08), seed + 5, 0.0, 10), Color(0.95, 0.4, 0.3, 0.35))
	if nose:
		Art.pl(ci, [c + Vector2(-r * 0.05, r * 0.25), c + Vector2(r * 0.06, r * 0.36), c + Vector2(-r * 0.04, r * 0.38)], r * 0.05, skin.darkened(0.35), seed + 6)
	if smile:
		var m := []
		for k in 9:
			var a := lerpf(0.25, PI - 0.25, float(k) / 8.0)
			m.append(c + Vector2(cos(a) * r * 0.26, r * 0.48 + sin(a) * r * 0.16))
		ci.draw_colored_polygon(Art.poly(m, seed + 7, 0.3), Color("8a2a1a"))
		Art.pl(ci, m, r * 0.05, Art.INK, seed + 8)

## 脸第一层：墨线外轮廓 + 耳朵描边（固定颜色）
static func live_face_base(ci: CanvasItem, c: Vector2, r: float, seed: int) -> void:
	var parts := _face_parts(c, r, seed)
	for p in parts:
		Art.dilate(ci, p, 3.0, Art.INK)
	for i in 2:
		Art.outline(ci, parts[i], 2.2, Art.INK)

## 脸第二层：皮肤（白色画，按肤色染）。Art.shade 去掉高光；鼻子是肤色压暗
static func live_face_skin(ci: CanvasItem, c: Vector2, r: float, seed: int) -> void:
	for p in _face_parts(c, r, seed):
		var pts: PackedVector2Array = p
		ci.draw_colored_polygon(pts, Color.WHITE.darkened(0.22))
		var bb := Art.bbox(pts)
		var inset: float = min(bb.size.x, bb.size.y) * 0.1
		var off := Vector2(-bb.size.x, -bb.size.y) * 0.04
		for o in Geometry2D.offset_polygon(pts, -inset, Geometry2D.JOIN_ROUND):
			var moved := PackedVector2Array()
			for q in o:
				moved.append(q + off)
			ci.draw_colored_polygon(moved, Color.WHITE)
	Art.pl(ci, [c + Vector2(-r * 0.05, r * 0.25), c + Vector2(r * 0.06, r * 0.36), c + Vector2(-r * 0.04, r * 0.38)], r * 0.05, Color.WHITE.darkened(0.35), seed + 6)

## 脸第三层：高光、脸的描边、五官（固定颜色）
static func live_face_top(ci: CanvasItem, c: Vector2, r: float, seed: int, smile: bool) -> void:
	var parts := _face_parts(c, r, seed)
	for i in 3:
		var bb := Art.bbox(parts[i])
		var cen := bb.get_center()
		var hc := cen + Vector2(-bb.size.x * 0.2, -bb.size.y * 0.24)
		# 耳朵的高光落在脸里的会被脸盖住，不画
		if i < 2 and hc.distance_to(c) < r:
			continue
		ci.draw_colored_polygon(Art.ell(hc, Vector2(bb.size.x * 0.12, bb.size.y * 0.07), 3, 0.0, 10, -0.5, 0.3), Color(1, 1, 1, 0.5))
	Art.outline(ci, parts[2], 2.2, Art.INK)
	_face_features(ci, c, r, Color.WHITE, seed, smile, false)

static func live_face_mouth_only(ci: CanvasItem, c: Vector2, r: float) -> void:
	var m := []
	for k in 9:
		var a := lerpf(0.25, PI - 0.25, float(k) / 8.0)
		m.append(c + Vector2(cos(a) * r * 0.26, r * 0.48 + sin(a) * r * 0.16))
	ci.draw_colored_polygon(Art.poly(m, 9, 0.3), Color("8a2a1a"))
	Art.pl(ci, m, r * 0.05, Art.INK, 9)

static func live_portrait(ci: CanvasItem, kind: int, c: Vector2, s: float) -> void:
	Meme.portrait(ci, kind, c, s)

## 保留旧的程序化肖像供历史素材审阅，不用于生成或运行。
static func _legacy_portrait(ci: CanvasItem, kind: int, c: Vector2, s: float) -> void:
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
	live_face(ci, Vector2(0, 2), 34, skin, 40 + kind)
	match kind:
		0:
			Art.sil(ci, [Art.P(Art.capsule(Vector2(-34, -18), Vector2(34, -18), 6.0, 50), Art.CLAY, 1)], false)
			for sx in [-1.0, 1.0]:
				Art.ln(ci, Vector2(18 * sx, 14), Vector2(28 * sx, 12), 3.0, Color("f5f0e0"), 51)
				Art.ln(ci, Vector2(18 * sx, 20), Vector2(28 * sx, 18), 3.0, Color("f5f0e0"), 52)
			Art.sil(ci, [Art.P(Art.poly([Vector2(-20, 24), Vector2(20, 24), Vector2(10, 46), Vector2(0, 52), Vector2(-10, 46)], 53), Color("d9d2c4"), 1)], false)
			live_face_mouth_only(ci, Vector2(0, 2), 34)
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

# ---------------------------------------------------------------- 角色

static func live_mascot(ci: CanvasItem, c: Vector2, s: float, prop: String = "") -> void:
	Paint.mascot(ci, c, s, prop)

static func live_hero_at(ci: CanvasItem, hc: Vector2, w: float) -> void:
	Meme.draw_portrait(ci, Meme.HERO, Rect2(hc + Vector2(-0.6, -0.8) * w, Vector2(1.2, 1.6) * w))

static func live_heroine(ci: CanvasItem, c: Vector2, s: float) -> void:
	Paint.heroine(ci, c, s)

static func live_bust(ci: CanvasItem, c: Vector2, s: float) -> void:
	Paint.bust(ci, c, s)

# ---------------------------------------------------------------- 岩画

static func live_card_art(ci: CanvasItem, album: int, idx: int, r: Rect2) -> void:
	var bg: Color = Paint.ALBUM_COL[album % Paint.ALBUM_COL.size()]
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
			live_mammoth(ci, Vector2(-4, 6), 1.0, ink, idx)
		1:
			live_deer(ci, Vector2(-6, 6), 1.0, ink, idx)
			live_hunter(ci, Vector2(30, 10), 0.8, ink, idx)
		2:
			for i in 3:
				live_hunter(ci, Vector2(-30 + i * 30, 8 + (i % 2) * 6), 0.9, ink, idx + i)
		3:
			for i in 4:
				live_hand(ci, Vector2(-26 + (i % 2) * 52, -16 + (i / 2) * 36), 0.8, ink if i % 2 == 0 else Color(ink, 0.6), idx + i)
		4:
			ci.draw_circle(Vector2(0, -6), 16, ink)
			live_sun_rays(ci, Vector2(0, -6), ink)
			live_fish_glyph(ci, Vector2(0, 32), ink, idx)
		_:
			ci.draw_colored_polygon(Art.flame_pts(Vector2(0, 0), 16, 40, idx), ink)
			for i in 2:
				live_hunter(ci, Vector2(-30 + i * 60, 10), 0.85, ink, idx + i)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func live_sun_rays(ci: CanvasItem, c: Vector2, ink: Color) -> void:
	for k in 10:
		var a := TAU * float(k) / 10.0
		Art.ln(ci, Vector2(cos(a), sin(a)) * 22.0 + c, Vector2(cos(a), sin(a)) * 32.0 + c, 4.0, ink, k)

## part：0 全画，1 只画身子（不含象牙），2 只画象牙
static func live_mammoth(ci: CanvasItem, c: Vector2, s: float, col: Color, seed: int, part: int = 0) -> void:
	if part != 2:
		ci.draw_colored_polygon(Art.ell(c, Vector2(30, 20) * s, seed, 0.08, 20), col)
		ci.draw_colored_polygon(Art.ell(c + Vector2(-28, -8) * s, Vector2(13, 13) * s, seed + 1, 0.05, 14), col)
		Art.pl(ci, [c + Vector2(-36, -2) * s, c + Vector2(-42, 14) * s, c + Vector2(-36, 26) * s], 5.0 * s, col, seed)
	if part != 1:
		Art.pl(ci, [c + Vector2(-30, 4) * s, c + Vector2(-40, 10) * s, c + Vector2(-46, 2) * s], 3.0 * s, Color("f5ead0"), seed + 1)
	if part != 2:
		for x in [-18.0, -6.0, 10.0, 22.0]:
			Art.ln(ci, c + Vector2(x, 12) * s, c + Vector2(x, 30) * s, 6.0 * s, col, seed + int(x))

static func live_deer(ci: CanvasItem, c: Vector2, s: float, col: Color, seed: int) -> void:
	ci.draw_colored_polygon(Art.ell(c, Vector2(22, 10) * s, seed, 0.05, 16), col)
	Art.ln(ci, c + Vector2(-18, -4) * s, c + Vector2(-26, -20) * s, 5.0 * s, col, seed)
	ci.draw_colored_polygon(Art.ell(c + Vector2(-30, -22) * s, Vector2(7, 5) * s, seed + 1, 0.05, 10), col)
	Art.pl(ci, [c + Vector2(-28, -26) * s, c + Vector2(-24, -40) * s, c + Vector2(-16, -46) * s], 2.5 * s, col, seed)
	Art.pl(ci, [c + Vector2(-24, -38) * s, c + Vector2(-34, -46) * s], 2.5 * s, col, seed + 1)
	for x in [-14.0, -6.0, 8.0, 16.0]:
		Art.ln(ci, c + Vector2(x, 6) * s, c + Vector2(x + 2, 26) * s, 3.5 * s, col, seed + int(x))

static func live_hunter(ci: CanvasItem, c: Vector2, s: float, col: Color, seed: int) -> void:
	ci.draw_circle(c + Vector2(0, -24) * s, 5.0 * s, col)
	Art.ln(ci, c + Vector2(0, -18) * s, c + Vector2(0, 4) * s, 4.0 * s, col, seed)
	Art.ln(ci, c + Vector2(0, 4) * s, c + Vector2(-8, 22) * s, 3.5 * s, col, seed + 1)
	Art.ln(ci, c + Vector2(0, 4) * s, c + Vector2(8, 22) * s, 3.5 * s, col, seed + 2)
	Art.ln(ci, c + Vector2(0, -12) * s, c + Vector2(-10, -2) * s, 3.0 * s, col, seed + 3)
	Art.ln(ci, c + Vector2(0, -12) * s, c + Vector2(10, -18) * s, 3.0 * s, col, seed + 4)
	Art.ln(ci, c + Vector2(4, 4) * s, c + Vector2(18, -34) * s, 2.5 * s, col, seed + 5)

static func live_hand(ci: CanvasItem, c: Vector2, s: float, col: Color, seed: int) -> void:
	ci.draw_colored_polygon(Art.ell(c + Vector2(0, 6) * s, Vector2(10, 11) * s, seed, 0.06, 14), col)
	for k in 5:
		var a := -PI * 0.5 + (float(k) - 2.0) * 0.38
		if k == 0:
			a = PI * 0.95
		Art.ln(ci, c + Vector2(cos(a), sin(a)) * 8.0 * s + Vector2(0, 4) * s, c + Vector2(cos(a), sin(a)) * 22.0 * s + Vector2(0, 4) * s, 5.0 * s, col, seed + k)

static func live_fish_glyph(ci: CanvasItem, c: Vector2, col: Color, seed: int) -> void:
	ci.draw_colored_polygon(Art.ell(c, Vector2(16, 7), seed, 0.03, 14), col)
	ci.draw_colored_polygon(Art.poly([c + Vector2(14, 0), c + Vector2(24, -8), c + Vector2(24, 8)], seed), col)

# ---------------------------------------------------------------- 卡牌

static func live_card(ci: CanvasItem, r: Rect2, album: int, idx: int, owned: bool) -> void:
	live_card_frame(ci, r, album * 9 + idx)
	var ar := Rect2(r.position + Vector2(8, 8), Vector2(r.size.x - 16, r.size.y * 0.72))
	if owned:
		live_card_art(ci, album, idx, ar)
	else:
		ci.draw_rect(ar, Color("8a6a4a"))
		live_card_locked_lines(ci, ar)
	ci.draw_rect(ar, Art.INK, false, 2.0)
	var bandr := Rect2(r.position + Vector2(4, r.size.y * 0.74), Vector2(r.size.x - 8, r.size.y * 0.22))
	ci.draw_colored_polygon(Art.rrect(bandr, 6, idx, 0.4), Art.OCHRE)
	live_card_star(ci, Vector2(r.get_center().x, bandr.position.y + 2), idx)

static func live_card_frame(ci: CanvasItem, r: Rect2, seed: int) -> void:
	ci.draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(0, 6), r.size), 12, seed, 0.0), Color(0, 0, 0, 0.3))
	var b := Art.rrect(r, 12, seed, 0.6)
	Art.dilate(ci, b, 3.0, Art.INK)
	ci.draw_colored_polygon(b, Art.BONE)

static func live_card_locked_lines(ci: CanvasItem, ar: Rect2) -> void:
	for i in 6:
		var y := ar.position.y + ar.size.y * float(i) / 6.0
		Art.ln(ci, Vector2(ar.position.x, y), Vector2(ar.end.x, y + 10), 2.0, Color(1, 1, 1, 0.08), i)

static func live_card_star(ci: CanvasItem, c: Vector2, seed: int) -> void:
	ci.draw_colored_polygon(Art.star_pts(c, 11, 5, 5, seed), Art.FIRE2)
	Art.outline(ci, Art.star_pts(c, 11, 5, 5, seed), 2.0)

# ---------------------------------------------------------------- 背景

## 原样的山丘（对照用）
static func live_hills(ci: CanvasItem, y: float, w: float, amp: float, col: Color, seed: int, bottom: float) -> void:
	var arr := PackedVector2Array()
	arr.append(Vector2(0, bottom))
	for k in 25:
		var x := w * float(k) / 24.0
		arr.append(Vector2(x, y - amp * (0.5 + 0.5 * sin(float(k) * 0.7 + float(seed))) - Art.srnd(seed + k) * amp * 0.3))
	arr.append(Vector2(w, bottom))
	ci.draw_colored_polygon(arr, col)

## 山脊那一截：r 的底边是 y，高 1.3 倍 amp（amp = r.size.y / 1.3）。往留白里多铺一点，拉伸时边缘不发虚
static func live_hill_profile(ci: CanvasItem, r: Rect2, seed: int) -> void:
	var amp := r.size.y / 1.3
	var y := r.end.y
	var arr := PackedVector2Array()
	arr.append(Vector2(r.position.x - 2, y + 2))
	for k in 25:
		var x := r.position.x + r.size.x * float(k) / 24.0
		var p := Vector2(x, y - amp * (0.5 + 0.5 * sin(float(k) * 0.7 + float(seed))) - Art.srnd(seed + k) * amp * 0.3)
		if k == 0:
			arr.append(Vector2(r.position.x - 2, p.y))
		arr.append(p)
		if k == 24:
			arr.append(Vector2(r.end.x + 2, p.y))
	arr.append(Vector2(r.end.x + 2, y + 2))
	ci.draw_colored_polygon(arr, Color.WHITE)

static func live_palm(ci: CanvasItem, base: Vector2, h: float, seed: int, col: Color = Color("2f6b3a")) -> void:
	var top := base + Vector2(Art.srnd(seed) * 30.0 - 15.0, -h)
	Art.ln(ci, base, top, 9.0, Color("6a4526"), seed)
	live_palm_crown(ci, top, seed, col)

static func live_palm_crown(ci: CanvasItem, top: Vector2, seed: int, col: Color) -> void:
	for k in 6:
		var a := -PI + PI * float(k) / 5.0 + (Art.srnd(seed + k) - 0.5) * 0.3
		var tip := top + Vector2(cos(a) * 60.0, sin(a) * 30.0 + 26.0)
		var mid := top + Vector2(cos(a) * 30.0, sin(a) * 30.0 - 6.0)
		ci.draw_colored_polygon(Art.poly([top, mid + Vector2(0, -8), tip, mid + Vector2(0, 8)], seed + k), col)

static func live_campfire_scene(ci: CanvasItem, c: Vector2, s: float) -> void:
	ci.draw_set_transform(c, 0.0, Vector2.ONE * s)
	ci.draw_colored_polygon(Art.ell(Vector2(0, 30), Vector2(90, 26), 1, 0.03, 24), Color(1, 0.6, 0.2, 0.2))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	Art.item(ci, "fire_4", c, 100.0 * s)

## s 是整体缩放（原来按 st 算：0.9 + 0.08 * st）
static func live_spot_hut(ci: CanvasItem, c: Vector2, st: int, s: float = -1.0) -> void:
	if st == 0:
		return
	if s < 0.0:
		s = 0.9 + 0.08 * float(st)
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

## 奖励气泡的玻璃泡（不含里面的物品和数字）
static func live_bubble_frame(ci: CanvasItem, c: Vector2, rad: float, empty: bool, seed: int) -> void:
	var shadow := Art.ell(c + Vector2(0, rad * 0.28), Vector2(rad * 0.86, rad * 0.22), seed, 0.0, 14, 0.0, 0.0)
	ci.draw_colored_polygon(shadow, Color(0, 0, 0, 0.16))
	var body := Art.ell(c, Vector2(rad, rad * 0.94), seed, 0.035, 22)
	var glass := Color(0.9, 0.97, 1.0, 0.55) if empty else Color(0.86, 0.96, 1.0, 0.82)
	ci.draw_colored_polygon(body, glass)
	Art.outline(ci, body, maxf(2.0, rad * 0.09), Color(0.25, 0.4, 0.55, 0.4 if empty else 0.85))
	var shine := Art.ell(c + Vector2(-rad * 0.32, -rad * 0.38), Vector2(rad * 0.28, rad * 0.16), seed + 3, 0.0, 12, -0.5, 0.0)
	ci.draw_colored_polygon(shine, Color(1, 1, 1, 0.35 if empty else 0.72))
	if empty:
		var arm := rad * 0.34
		var w := maxf(2.0, rad * 0.12)
		ci.draw_line(c + Vector2(-arm, 0), c + Vector2(arm, 0), Color("6a8aaa"), w, true)
		ci.draw_line(c + Vector2(0, -arm), c + Vector2(0, arm), Color("6a8aaa"), w, true)

## 原样的奖励气泡（对照用）
static func live_reward_bubble(ci: CanvasItem, c: Vector2, rad: float, id: String, n: int, seed: int, lift: float = 0.0) -> void:
	c += Vector2(0, lift)
	live_bubble_frame(ci, c, rad, id == "", seed)
	if id == "":
		return
	Paint._bubble_content(ci, c, rad, id, n)
