extends RefCounted
## 活动入口和活动面板（通行证、双人竞速、外星补给、月石遗迹、香蕉竞速、排行、七日任务、赶大集、火种礼包、礼包链）的界面图登记和原始画法。
## 只给「生成物品图.bat」用；游戏里这些界面只贴这里生成的图。登记格式见 scripts/BakeSprites.gd。
## cr 是这张图在原来画法坐标系里的位置，运行时 Sprites.draw(ci, key, cr) 就贴回原处。

const Banana := preload("res://scripts/ui/Banana.gd")
const Meme := preload("res://scripts/Meme.gd")

const MEDAL := [Color("f2c35a"), Color("cfc9c0"), Color("d08a4a"), Color("a08a70")]
const PASS_TRACKS := ["free", "prem", "super", "endless"]
const SD_TIER := {10: Color("b49c74"), 15: Color("6fae7d"), 20: Color("4fa39a"), 25: Color("e0913a"), 30: Color("d2512d")}
const EN_HEAD := [Color("4fa39a"), Color("8cc63f"), Color("eaa53c")]
const EN_BODY := [Color("6cc0b2"), Color("a6d65a"), Color("ffd06a")]

## 按原坐标登记：画的时候把 cr 的左上角挪到图的内容区
static func _e(key: String, cr: Rect2, fn: Callable, pad: int = 12, nine = null) -> Dictionary:
	var d := {"key": key, "w": int(cr.size.x), "h": int(cr.size.y), "pad": pad,
		"draw": func(ci, r):
			ci.draw_set_transform(r.position - cr.position)
			fn.call(ci)
			ci.draw_set_transform(Vector2.ZERO)}
	if nine != null:
		d["nine"] = nine
	return d

static func entries() -> Array:
	var out: Array = []
	# ---------------- 通用小件
	out.append(_e("ev_ell_shadow", Rect2(0, 0, 100, 24), func(ci): ci.draw_colored_polygon(Art.ell(Vector2(50, 12), Vector2(50, 12), 3, 0.04, 20, 0.0, 0.5), Color.WHITE), 4))
	out.append(_e("ev_disc", Rect2(-50, -50, 100, 100), func(ci): ci.draw_colored_polygon(Art.ell(Vector2.ZERO, Vector2(50, 50), 430, 0.03, 20), Color.WHITE), 4))
	out.append(_e("ev_spark4", Rect2(-10, -10, 20, 20), func(ci): ci.draw_colored_polygon(Art.star_pts(Vector2.ZERO, 10, 3, 4, 7), Color.WHITE), 4))
	for k in MEDAL.size():
		out.append(_e("ev_medal_%d" % k, Rect2(-22, -22, 44, 44), func(ci): live_medal(ci, Vector2.ZERO, 22.0, MEDAL[k]), 5))
	out.append(_e("ev_info_badge", Rect2(-15, -15, 30, 30), func(ci): live_info_badge(ci, Vector2.ZERO), 6))
	out.append(_e("ev_clock_pill", Rect2(0, 0, 192, 50), func(ci): live_clock_pill(ci, Vector2(192, 50)), 6))
	_entry_art(out)
	_duel(out)
	_pass(out)
	_ufo(out)
	_merge(out)
	_race(out)
	_rank(out)
	_seven(out)
	_spree(out)
	_energy(out)
	_gift(out)
	return out

static func live_medal(ci: CanvasItem, c: Vector2, rad: float, col: Color, seed: int = 41, d: float = 2.4) -> void:
	var m := Art.ell(c, Vector2(rad, rad), seed, 0.03, 18)
	Art.dilate(ci, m, d, Art.INK)
	ci.draw_colored_polygon(m, col)

static func live_info_badge(ci: CanvasItem, c: Vector2) -> void:
	var b := Art.ell(c, Vector2(15, 15), 980, 0.04, 14)
	Art.dilate(ci, b, 2.5, Color.WHITE)
	ci.draw_colored_polygon(b, Color("3d8fd1"))
	ci.draw_circle(c + Vector2(0, -7), 2.6, Color.WHITE)
	ci.draw_rect(Rect2(c.x - 2.2, c.y - 2, 4.4, 11), Color.WHITE)

## 倒计时小牌（赶大集、火种礼包共用；钟表字形运行时另画）
static func live_clock_pill(ci: CanvasItem, sz: Vector2, seed: int = 901) -> void:
	var p := Art.rrect(Rect2(Vector2.ZERO, sz), 25, seed, 0.5)
	Art.dilate(ci, p, 3.0, Art.INK)
	ci.draw_colored_polygon(p, Art.BONE)
	ci.draw_circle(Vector2(27, sz.y * 0.5), 18, Art.OCHRE)

# ================================================================ 棋盘活动入口（EventEntryArt）

static var _grey := false
static var _xf := Transform2D.IDENTITY

static func _entry_art(out: Array) -> void:
	# 图片原点 = 地面中点，内容区 x -64..64、y -120..12；运行时中心 (0, -54)
	for kind in ["duel", "race", "ruins", "seven"]:
		for grey in [false, true]:
			out.append({"key": "ev_entry_%s%s" % [kind, "_grey" if grey else ""], "w": 128, "h": 132, "pad": 12,
				"draw": func(ci, r): live_entry(ci, kind, grey, r.position + Vector2(64, 120))})
	for style in EventEntryArt.PILL:
		out.append(_e("ev_pill_" + style, Rect2(0, 0, 80, 26), func(ci): live_entry_pill(ci, Rect2(0, 0, 80, 26), style), 6, [14, 13, 14, 13]))

static func live_entry_pill(ci: CanvasItem, r: Rect2, style: String) -> void:
	var cols: Array = EventEntryArt.PILL.get(style, EventEntryArt.PILL["num"])
	Art.fill(ci, Art.rrect(r, 13, 41, 0.5), cols[0], 3)
	if style in ["go", "gold", "teal"]:
		ci.draw_line(r.position + Vector2(10, 6), r.position + Vector2(r.size.x - 10, 6), Color(1, 1, 1, 0.45), 3, true)

## o：地面中点在画布上的位置
static func live_entry(ci: CanvasItem, kind: String, grey: bool, o: Vector2) -> void:
	_grey = grey
	_xf = Transform2D(0.0, o)
	ci.draw_set_transform(o)
	match kind:
		"duel": _en_duel(ci)
		"race": _en_race(ci)
		"ruins": _en_ruins(ci)
		"seven": _en_seven(ci)
	_grey = false
	ci.draw_set_transform(Vector2.ZERO)

static func _c(col: Color) -> Color:
	if not _grey: return col
	var l := col.get_luminance()
	return Color(l, l, l * 0.96, col.a).lerp(Color("8d877d"), 0.25)

static func _parts(ci: CanvasItem, parts: Array) -> void:
	for p in parts: p[1] = _c(p[1])
	Art.sil(ci, parts, true, 3.0)

## 双人竞速：两张头像对顶，中间红色 VS 星章，脚下一小堆香蕉
static func _en_duel(ci: CanvasItem) -> void:
	for side in 2:
		var c := Vector2(-24.0 if side == 0 else 24.0, -56.0 + (0.0 if side == 0 else -3.0))
		ci.draw_circle(c + Vector2(0, 3), 27, Color(0, 0, 0, 0.2))
		ci.draw_circle(c, 27, Art.INK)
		ci.draw_circle(c, 24.5, _c(Art.MOSS if side == 0 else Art.CLAY))
		ci.draw_circle(c, 20, _c(Art.BONE))
		# Meme 内部会改画布变换：换回屏幕坐标画，画完再恢复
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)
		Meme.live_portrait(ci, side, _xf * (c + Vector2(0, 2)), 42 * _xf.get_scale().x)
		ci.draw_set_transform_matrix(_xf)
		if _grey: ci.draw_circle(c, 25, Color(0.55, 0.53, 0.5, 0.55))
	for k in 4:
		var c := Vector2(-21.0 + k * 14.0, -8.0 + absf(k - 1.5) * 3.0)
		var rot := -0.5 + k * 0.33
		Art.dilate(ci, _banana(c, 30.0, rot), 4.0, Color(1, 0.98, 0.92, 0.96))
		if _grey: Art.fill(ci, _banana(c, 30.0, rot), _c(Color("ffd84a")), 2.4)
		else: Banana.draw(ci, c, 30.0, rot)
	var v := Vector2(0, -30)
	Art.fill(ci, Art.star_pts(v, 19, 13, 9, 61), _c(Art.CLAY), 2.6)
	ci.draw_circle(v, 10.5, _c(Color("e8673f")))
	EventEntryArt.text(ci, "VS", v + Vector2(0, 6), 16, Color.WHITE, 4)

## 香蕉竞速：一串香蕉靠着方格赛旗
static func _en_race(ci: CanvasItem) -> void:
	var pole := Art.capsule(Vector2(-26, -4), Vector2(-26, -100), 3.5, 51)
	var flag := Art.poly([Vector2(-24, -98), Vector2(4, -103), Vector2(30, -96), Vector2(28, -70), Vector2(2, -76), Vector2(-24, -72)], 52, 0.6)
	_parts(ci, [Art.P(pole, Color("8a5a2b"), 1), Art.P(flag, Color("fff7e6"), 2)])
	var top := [Vector2(-24, -98), Vector2(4, -103), Vector2(30, -96)]
	var bot := [Vector2(-24, -72), Vector2(2, -76), Vector2(28, -70)]
	for col in 4:
		for row in 2:
			if (col + row) % 2 == 1: continue
			var q := PackedVector2Array()
			for corner in [[col, row], [col + 1, row], [col + 1, row + 1], [col, row + 1]]:
				var u := float(corner[0]) / 4.0
				var a := _along(top, u)
				var b := _along(bot, u)
				q.append(a.lerp(b, float(corner[1]) / 2.0))
			ci.draw_colored_polygon(q, _c(Color("3b2314")))
	Art.outline(ci, flag, 2.6, Art.INK)
	Art.dot(ci, Vector2(-26, -102), 5.5, Art.INK)
	Art.dot(ci, Vector2(-26, -102), 3.5, _c(Art.OCHRE))
	var stem := Vector2(4, -12)
	var bunch := []
	for t in [-0.5, 0.42, -0.04]:
		var rot: float = PI * 0.5 + t
		bunch.append([rot, stem - Vector2(0.43 * 60.0, 0.6).rotated(rot)])
	for k in bunch:
		Art.dilate(ci, _banana(k[1], 60.0, k[0]), 7.0, Color(1, 0.98, 0.92, 0.96))
	for k in bunch:
		if _grey:
			Art.fill(ci, _banana(k[1], 60.0, k[0]), _c(Color("ffd84a")), 3)
		else:
			Banana.draw(ci, k[1], 60.0, k[0])
	var knob := Art.capsule(stem + Vector2(-2, 6), stem + Vector2(0, -4), 6.5, 53)
	Art.fill(ci, knob, _c(Color("6b4a2a")), 3)

## 和 Banana.draw 同一个形状，只要轮廓（描白边、置灰用）
static func _banana(c: Vector2, s: float, rot: float) -> PackedVector2Array:
	var body := PackedVector2Array()
	var inner: Array = []
	for i in 13:
		var u := float(i) / 12.0
		var a := lerpf(-1.05, 1.05, u)
		body.append(c + Vector2(sin(a) * s * 0.5, cos(a) * s * 0.34 - s * 0.16).rotated(rot))
		inner.append(c + Vector2(sin(a) * s * 0.46, cos(a) * s * 0.34 - s * 0.16 - sin(u * PI) * s * 0.32).rotated(rot))
	inner.reverse()
	for q in inner: body.append(q)
	return body

static func _along(pts: Array, u: float) -> Vector2:
	var t := u * (pts.size() - 1)
	var i := mini(int(t), pts.size() - 2)
	return (pts[i] as Vector2).lerp(pts[i + 1], t - i)

## 月石遗迹：长苔的石门，门洞里浮着发光的月牙石
static func _en_ruins(ci: CanvasItem) -> void:
	var hole := Art.poly([Vector2(-20, 0), Vector2(-20, -60), Vector2(-10, -72), Vector2(10, -72), Vector2(20, -60), Vector2(20, 0)], 71, 0.6)
	Art.fill(ci, hole, _c(Color("21434a")), 0)
	if not _grey:
		for k in 4:
			ci.draw_colored_polygon(Art.ell(Vector2(0, -40), Vector2(30 - k * 6, 34 - k * 7), 72, 0.0, 18, 0.0, 0.0), Color(0.5, 1.0, 0.92, 0.10 + k * 0.05))
	var lp := Art.poly([Vector2(-40, 0), Vector2(-42, -72), Vector2(-20, -74), Vector2(-19, 0)], 73, 0.9)
	var rp := Art.poly([Vector2(19, 0), Vector2(20, -74), Vector2(42, -72), Vector2(40, 0)], 74, 0.9)
	var beam := Art.poly([Vector2(-50, -70), Vector2(-46, -88), Vector2(46, -90), Vector2(51, -70)], 75, 0.9)
	var cap := Art.poly([Vector2(-22, -88), Vector2(-14, -100), Vector2(14, -101), Vector2(22, -89)], 76, 0.9)
	_parts(ci, [Art.P(lp, Color("a9a39a"), 1), Art.P(rp, Color("9d978d"), 1), Art.P(beam, Color("b7b1a6"), 1), Art.P(cap, Color("c4beb2"), 1)])
	for seg in [[Vector2(-38, -46), Vector2(-22, -48)], [Vector2(22, -30), Vector2(38, -28)], [Vector2(-40, -20), Vector2(-28, -18)], [Vector2(-10, -80), Vector2(-4, -88)], [Vector2(24, -78), Vector2(30, -86)]]:
		Art.ln(ci, seg[0], seg[1], 2.2, Art.INK, 77)
	for m in [[Vector2(-30, -88), 13.0], [Vector2(36, -70), 10.0], [Vector2(-40, -6), 11.0], [Vector2(38, -4), 9.0]]:
		var moss := Art.ell(m[0], Vector2(m[1], m[1] * 0.55), 78 + int(m[1]), 0.18, 12, 0.0, 0.6)
		Art.fill(ci, moss, _c(Art.LEAF), 2.4)
	var mc := Vector2(0, -40)
	if not _grey:
		ci.draw_circle(mc, 22, Color(0.55, 1.0, 0.93, 0.25))
	var cres := Geometry2D.clip_polygons(Art.ell(mc, Vector2(18, 18), 85, 0.03, 24), Art.ell(mc + Vector2(9, -7), Vector2(15, 15), 86, 0.0, 24, 0.0, 0.0))
	var moon: PackedVector2Array = cres[0] if not cres.is_empty() else Art.ell(mc, Vector2(12, 12), 85)
	Art.sil(ci, [Art.P(moon, _c(Color("8ff5e6")), 0)], false, 3.0)
	if not _grey:
		Art.fill(ci, Art.star_pts(mc + Vector2(14, -18), 5, 2, 4, 79), Color("fffbe0"), 1.6)
		Art.fill(ci, Art.star_pts(mc + Vector2(-13, 15), 4, 1.6, 4, 80), Color("fffbe0"), 1.4)

## 七日任务：系着皮绳的石板日历，刻着大大的 7，两边是计日刻痕
static func _en_seven(ci: CanvasItem) -> void:
	var slab := Art.rrect(Rect2(-40, -94, 80, 92), 14, 81, 1.1, 30)
	var strap := Art.poly([Vector2(-44, -84), Vector2(44, -86), Vector2(44, -70), Vector2(-44, -68)], 82, 0.7)
	_parts(ci, [Art.P(slab, Color("b4aea2"), 0), Art.P(strap, Color("b0682e"), 1)])
	for x in [-26.0, 26.0]:
		Art.fill(ci, Art.ell(Vector2(x, -77), Vector2(7, 5), 83, 0.08, 10), _c(Art.BONE), 2.4)
	var f: Font = G.font_title
	var fs := 58
	var w := f.get_string_size("7", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p := Vector2(-w * 0.5 - 2, -14)
	ci.draw_string_outline(f, p + Vector2(1, 2), "7", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Color(0.18, 0.12, 0.08, 0.55))
	ci.draw_string_outline(f, p, "7", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Art.INK)
	ci.draw_string(f, p, "7", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, _c(Color("d2512d")))
	for k in 3:
		Art.ln(ci, Vector2(-31, -58 + k * 12), Vector2(-21, -58 + k * 12), 3.0, Color(0.23, 0.14, 0.08, 0.75), 84 + k)
		Art.ln(ci, Vector2(21, -58 + k * 12), Vector2(31, -58 + k * 12), 3.0, Color(0.23, 0.14, 0.08, 0.75), 88 + k)
	for g in [[-38.0, 1.0], [-30.0, -1.0], [40.0, 1.0]]:
		var x: float = g[0]
		Art.fill(ci, Art.poly([Vector2(x - 6, 0), Vector2(x - 4 * g[1], -14), Vector2(x, -4), Vector2(x + 3, -16), Vector2(x + 7, 0)], 98 + int(x), 0.5), _c(Art.LEAF_D), 2.2)

# ================================================================ 双人竞速（DuelPopup）

static func _duel(out: Array) -> void:
	out.append(_e("ev_duel_vs", Rect2(-48, -48, 96, 100), func(ci): live_duel_vs(ci, Vector2.ZERO, 40.0), 6))
	out.append(_e("ev_duel_mound", Rect2(-130, -20, 260, 40), func(ci):
		Art.fill(ci, Art.ell(Vector2.ZERO, Vector2(130, 20), 930, 0.05, 22), Color("c9a46a"), 2.5), 6))
	for side in 2:
		out.append(_e("ev_duel_flag_%d" % side, Rect2(-4, -38, 34, 42), func(ci): live_duel_flag(ci, Vector2.ZERO, Art.MOSS if side == 0 else Art.CLAY), 5))

## VS 星章底（字运行时另写）
static func live_duel_vs(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_colored_polygon(Art.star_pts(c + Vector2(0, 4), r * 1.15, r * 0.8, 10, 970), Color(0, 0, 0, 0.2))
	Art.fill(ci, Art.star_pts(c, r * 1.15, r * 0.8, 10, 971), Art.CLAY, 3)
	ci.draw_circle(c, r * 0.72, Color("e8673f"))

## 香蕉堆顶上的小旗，apex 是旗杆脚
static func live_duel_flag(ci: CanvasItem, apex: Vector2, tint: Color) -> void:
	Art.ln(ci, apex, apex + Vector2(0, -34), 3, Art.INK)
	Art.fill(ci, PackedVector2Array([apex + Vector2(0, -34), apex + Vector2(26, -26), apex + Vector2(0, -18)]), tint, 2)

# ================================================================ 丰收通行证（PassPopup）

static func _pass(out: Array) -> void:
	for track in PASS_TRACKS:
		var w := 414.0 if track == "endless" else PassPopup.CARD_W
		for ready in [false, true]:
			out.append(_e("ev_pass_card_%s_%s" % [track, "ready" if ready else "idle"], Rect2(0, 0, w, PassPopup.CARD_H),
				func(ci): live_pass_card(ci, Rect2(0, 0, w, PassPopup.CARD_H), track, ready), 16, [56, 28, 28, 46]))
	out.append(_e("ev_pass_card_shade", Rect2(0, 0, PassPopup.CARD_W, PassPopup.CARD_H),
		func(ci): ci.draw_colored_polygon(Art.rrect(Rect2(0, 0, PassPopup.CARD_W, PassPopup.CARD_H), 18, 40, 0.6), Color.WHITE), 4, [56, 28, 28, 46]))
	out.append(_e("ev_pass_burst", Rect2(0, 0, 260, 260), func(ci): live_pass_burst(ci, Vector2(130, 130)), 4))
	out.append(_e("ev_pass_stamp", Rect2(0, 0, 92, 92), func(ci): Art.fill(ci, Art.star_pts(Vector2(46, 46), 40, 32, 14, 4, 0.2), Art.CLAY, 3.0), 6))
	out.append(_e("ev_pass_medal", Rect2(-48, -48, 96, 96), func(ci): live_pass_medal(ci, Vector2.ZERO), 6))
	var tab_cols := [PassPopup.CLOTH, Art.OCHRE, Art.TEAL]
	for k in 3:
		out.append(_e("ev_pass_tab_%d" % k, Rect2(0, 0, PassPopup.CARD_W, 38), func(ci):
			var tb := Art.rrect(Rect2(0, 0, PassPopup.CARD_W, 38), 12, 71 + k, 0.4)
			Art.dilate(ci, tb, 3.0, Art.INK)
			ci.draw_colored_polygon(tb, tab_cols[k]), 6))
	out.append(_e("ev_pass_totem", Rect2(-34, -28, 68, 60), func(ci): live_pass_totem(ci, Vector2.ZERO), 6))
	out.append(_e("ev_pass_price", Rect2(0, 0, 92, 38), func(ci):
		var b := Art.rrect(Rect2(0, 0, 92, 38), 16, 91, 0.4)
		Art.dilate(ci, b, 3.0, Art.INK)
		ci.draw_colored_polygon(b, Art.CLAY), 6))
	out.append(_e("ev_pass_flame", Rect2(-28, -18, 56, 36), func(ci): Art.fill(ci, Art.flame_pts(Vector2.ZERO, 22, 30, 5), Art.FIRE2, 2.5), 6))
	for st in ["done", "cur", "idle"]:
		out.append(_e("ev_pass_node_" + st, Rect2(-34, -34, 68, 68), func(ci): live_pass_node(ci, Vector2.ZERO, st), 14))
	for lit in [true, false]:
		out.append(_e("ev_pass_endless_" + ("lit" if lit else "dim"), Rect2(-52, -52, 104, 104), func(ci): live_pass_endless(ci, Vector2.ZERO, lit), 14))
	out.append(_e("ev_pass_endless_shade", Rect2(-33, -33, 66, 66), func(ci): ci.draw_colored_polygon(Art.ell(Vector2.ZERO, Vector2(32, 32), 151, 0.03, 22), Color.WHITE), 3))
	out.append(_e("ev_pass_note", Rect2(0, 0, 186, 104), func(ci): live_pass_note(ci, Rect2(0, 0, 186, 104)), 6))
	out.append(_e("ev_pass_base", Rect2(-136, 6, 272, 70), func(ci): live_pass_base(ci, Vector2.ZERO), 6))
	for vip in [true, false]:
		out.append(_e("ev_pass_ticket_" + ("vip" if vip else "super"), Rect2(0, 0, 288, 686), func(ci): live_pass_ticket(ci, Rect2(0, 0, 288, 686), vip), 14))

## 奖励卡底子：外框（能领的带金光）、布面、底边布条、缝线、角上骨珠。奖励和字运行时另画
static func live_pass_card(ci: CanvasItem, r: Rect2, track: String, ready: bool, seed: int = 40) -> void:
	var b := Art.rrect(r, 18, seed, 0.6)
	ci.draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(0, 6), r.size), 18, seed, 0.0), Color(0, 0, 0, 0.3))
	if ready:
		Art.dilate(ci, b, 11.0, Color(Art.FIRE2, 0.35))
		Art.dilate(ci, b, 7.0, Art.FIRE2)
		Art.dilate(ci, b, 4.0, Art.INK)
	else:
		Art.dilate(ci, b, 3.0, Art.INK)
	var body := PassPopup.CLOTH_L
	var band_col := PassPopup.CLOTH_D
	if track == "prem" or track == "endless":
		body = PassPopup.PREM
		band_col = PassPopup.PREM_D
	elif track == "super":
		body = PassPopup.SUPER
		band_col = PassPopup.SUPER_D
	ci.draw_colored_polygon(b, body)
	var band := Rect2(r.position.x, r.end.y - PassPopup.BAND_H, r.size.x, PassPopup.BAND_H)
	ci.draw_colored_polygon(PassPopup._clip_bottom(b, band.position.y), band_col)
	ci.draw_line(Vector2(r.position.x + 4, band.position.y), Vector2(r.end.x - 4, band.position.y), Color(Art.INK, 0.35), 2.0)
	var stitch := Art.rrect(r.grow(-8), 12, seed + 3, 0.3)
	stitch.append(stitch[0])
	Art.dashed(ci, stitch, 7.0, 6.0, Color(Art.LEATHER_D, 0.45), 2.0)
	if track != "free":
		for k in (2 if track == "prem" else 3):
			var c := Vector2(r.position.x + 20 + k * 13, r.position.y + 15)
			ci.draw_circle(c, 6.0, Art.INK)
			ci.draw_circle(c, 4.2, [Art.TEAL, Art.BONE, Art.CLAY][k])

static func live_pass_burst(ci: CanvasItem, o: Vector2) -> void:
	ci.draw_colored_polygon(Art.star_pts(o, 120, 46, 12, 7), Color(Art.FIRE2, 0.55))
	ci.draw_colored_polygon(Art.star_pts(o, 76, 30, 8, 9, 0.2), Color(1, 1, 1, 0.75))
	for k in 8:
		var a := TAU * float(k) / 8.0 + 0.3
		ci.draw_colored_polygon(Art.star_pts(o + Vector2(cos(a), sin(a)) * 104.0, 12, 4, 4, k), Color.WHITE)

static func live_pass_medal(ci: CanvasItem, mc: Vector2) -> void:
	var medal := Art.ell(mc, Vector2(44, 44), 61, 0.03, 26)
	Art.dilate(ci, medal, 3.5, Art.INK)
	ci.draw_colored_polygon(medal, Art.OCHRE)
	ci.draw_colored_polygon(Art.ell(mc, Vector2(35, 35), 62, 0.03, 24), Color("d98d2a"))
	ci.draw_colored_polygon(Art.ell(mc + Vector2(-10, -18), Vector2(16, 7), 63, 0.0, 12, -0.4), Color(1, 1, 1, 0.3))
	for k in 8:
		var a := TAU * float(k) / 8.0
		ci.draw_circle(mc + Vector2(cos(a), sin(a)) * 40.0, 2.6, Art.BONE)

static func live_pass_totem(ci: CanvasItem, c: Vector2) -> void:
	var head := Art.rrect(Rect2(c.x - 30, c.y - 24, 60, 52), 12, 81, 0.5)
	Art.dilate(ci, head, 3.0, Art.INK)
	ci.draw_colored_polygon(head, Art.WOOD)
	ci.draw_colored_polygon(Art.rrect(Rect2(c.x - 30, c.y - 24, 60, 12), 6, 82, 0.0), Art.TEAL)
	ci.draw_line(Vector2(c.x - 30, c.y - 12), Vector2(c.x + 30, c.y - 12), Art.INK, 2.5)
	for s in [-1.0, 1.0]:
		var e := c + Vector2(13.0 * s, 0)
		ci.draw_circle(e, 7.0, Art.BONE)
		ci.draw_circle(e, 7.0, Art.INK, false, 2.0, true)
		ci.draw_circle(e + Vector2(0, 1), 3.0, Art.INK)
	ci.draw_rect(Rect2(c.x - 10, c.y + 13, 20, 6), Art.CLAY)
	ci.draw_rect(Rect2(c.x - 10, c.y + 13, 20, 6), Art.INK, false, 2.0)

## 图腾柱上的等级节点（数字运行时另写）。st：done 已到 / cur 正在攒 / idle 没到
static func live_pass_node(ci: CanvasItem, c: Vector2, st: String, seed: int = 101) -> void:
	var col := Color("6b5a4a")
	var inner := Color("5a4a3c")
	if st == "done":
		col = Art.OCHRE
		inner = Color("f4c35a")
	elif st == "cur":
		col = Art.TEAL
		inner = Color("6cc0b5")
	var disk := Art.ell(c, Vector2(PassPopup.NODE_R, PassPopup.NODE_R), seed, 0.03, 24)
	if st == "done":
		Art.dilate(ci, disk, 9.0, Color(Art.FIRE2, 0.3))
	Art.dilate(ci, disk, 3.5, Art.INK)
	ci.draw_colored_polygon(disk, col)
	ci.draw_colored_polygon(Art.ell(c, Vector2(PassPopup.NODE_R - 7, PassPopup.NODE_R - 7), seed + 20, 0.03, 22), inner)
	ci.draw_colored_polygon(Art.ell(c + Vector2(-9, -15), Vector2(12, 5), seed + 40, 0.0, 12, -0.4), Color(1, 1, 1, 0.1 if st == "idle" else 0.3))

static func live_pass_endless(ci: CanvasItem, c: Vector2, lit: bool) -> void:
	var pts := Art.star_pts(c, 50, 38, 10, 150, -PI * 0.5)
	if lit:
		Art.dilate(ci, pts, 10.0, Color(Art.FIRE2, 0.3))
	Art.fill(ci, pts, Art.CLAY if lit else Color("6b5a4a"), 3.5)
	ci.draw_colored_polygon(Art.ell(c, Vector2(32, 32), 151, 0.03, 22), Art.OCHRE if lit else Color("5a4a3c"))

static func live_pass_note(ci: CanvasItem, r: Rect2) -> void:
	var b := Art.rrect(r, 12, 160, 0.6)
	Art.dilate(ci, b, 3.0, Art.INK)
	ci.draw_colored_polygon(b, Art.WOOD_D)
	ci.draw_colored_polygon(Art.rrect(r.grow(-6), 9, 161, 0.4), Color("8a5a2c"))

## 柱脚的火光和石堆（篝火和字运行时另画）
static func live_pass_base(ci: CanvasItem, c: Vector2) -> void:
	ci.draw_colored_polygon(Art.ell(c + Vector2(0, 40), Vector2(130, 30), 170, 0.04, 26), Color(1, 0.55, 0.15, 0.16))
	for k in 7:
		var a := PI * (0.08 + 0.84 * float(k) / 6.0)
		var sc := c + Vector2(-cos(a) * 66.0, 30.0 - sin(a) * 6.0)
		Art.fill(ci, Art.ell(sc, Vector2(22, 15), 171 + k, 0.1, 14), Art.STONE if k % 2 == 0 else Color("bdb6aa"), 2.5)

## 购买页的票：r 是票身（原来是 Rect2(2, 8, sz.x - 4, sz.y - 14)）
static func live_pass_ticket(ci: CanvasItem, r: Rect2, vip: bool) -> void:
	var b := Art.rrect(r, 18, 21 if vip else 22, 0.75)
	Art.dilate(ci, b, 3.0, Art.INK)
	ci.draw_colored_polygon(b, Art.OCHRE if vip else Art.TEAL)
	var inner := r.grow(-11)
	ci.draw_colored_polygon(Art.rrect(inner, 12, 23, 0.5), Art.HIDE)
	var band := Rect2(r.position.x + 16, r.position.y + 14, r.size.x - 32, 54)
	var bb := Art.rrect(band, 10, 24, 0.45)
	Art.dilate(ci, bb, 2.5, Art.INK)
	ci.draw_colored_polygon(bb, Art.LEATHER if vip else Art.TEAL.darkened(0.12))
	var stripe := Rect2(r.position.x + 18, r.position.y + 78, r.size.x - 36, 8)
	ci.draw_colored_polygon(Art.rrect(stripe, 3, 25, 0.2), Art.OCHRE)
	for side in 2:
		var x := r.position.x if side == 0 else r.end.x
		var hole := Art.ell(Vector2(x, r.get_center().y), Vector2(11, 11), 26 + side, 0.0, 14)
		ci.draw_colored_polygon(hole, Art.HIDE)
		Art.outline(ci, hole, 2.0, Art.LEATHER_D)

# ================================================================ 外星补给（UfoEntry / UfoPopup）

const UFO_C := Vector2(75, 68)
const UFO_RAD := 60.0
const UFO_SKY := Rect2(66, 380, 588, 300)
const UFO_TRAY := Rect2(66, 694, 588, 186)

static func _ufo(out: Array) -> void:
	out.append(_e("ev_ufo_back", Rect2(0, 0, 150, 140), live_ufo_back, 8))
	out.append(_e("ev_ufo_saucer", Rect2(-44, -26, 88, 44), live_ufo_saucer, 6))
	for on in [true, false]:
		out.append(_e("ev_ufo_light_" + ("on" if on else "off"), Rect2(-5, -5, 10, 10), func(ci):
			Art.fill(ci, Art.ell(Vector2.ZERO, Vector2(4, 3.5), 809, 0.1, 8), Art.FIRE2 if on else Color("e8b44a"), 1.8), 4))
	out.append({"key": "ev_ufo_front", "w": 150, "h": 140, "pad": 14, "draw": func(ci, r): live_ufo_front(ci, r.position)})
	out.append(_e("ev_ufo_star", Rect2(0, 0, 128, 128), func(ci): live_ufo_star(ci, Vector2(64, 64)), 8))
	out.append(_e("ev_ufo_clock", Rect2(0, 0, 158, 48), func(ci):
		var p := Art.rrect(Rect2(0, 0, 158, 48), 24, 733, 0.4)
		Art.dilate(ci, p, 3.0, Art.INK)
		ci.draw_colored_polygon(p, Color(0.07, 0.1, 0.16, 0.85)), 6))
	out.append(_e("ev_ufo_stamp", Rect2(0, 0, 300, 80), func(ci):
		var b := Art.rrect(Rect2(0, 0, 300, 80), 16, 743, 0.8)
		Art.dilate(ci, b, 3.5, Art.INK)
		ci.draw_colored_polygon(b, Color("c0452a"))
		Art.dashed(ci, Art.rrect(Rect2(0, 0, 300, 80).grow(-8), 10, 744, 0.0), 9, 6, Color("ffd9b0"), 2.5), 8))
	out.append(_e("ev_ufo_strike", Rect2(0, 0, 116, 52), func(ci):
		Art.ln(ci, Vector2(4, 42), Vector2(112, 12), 7.0, Art.INK, 741)
		Art.ln(ci, Vector2(4, 42), Vector2(112, 12), 4.0, Color("d8324a"), 741), 6))
	out.append(_e("ev_ufo_arrow", Rect2(0, 0, 70, 44), func(ci):
		var a := [Vector2(4, 14), Vector2(38, 14), Vector2(38, 2), Vector2(66, 22), Vector2(38, 42), Vector2(38, 30), Vector2(4, 30)]
		Art.fill(ci, Art.poly(a, 742, 0.5), Art.OCHRE, 3.0), 6))
	out.append(_e("ev_ufo_sky", UFO_SKY, func(ci):
		var sky := Art.rrect(UFO_SKY, 22, 721, 0.6)
		Art.dilate(ci, sky, 3.0, Art.INK)
		ci.draw_colored_polygon(sky, Color("1d2f55")), 8, [40, 40, 40, 40]))
	out.append(_e("ev_ufo_sky_line", UFO_SKY, func(ci): Art.outline(ci, Art.rrect(UFO_SKY, 22, 721, 0.6), 3.0, Art.INK), 8, [40, 40, 40, 40]))
	out.append(_e("ev_ufo_tray", UFO_TRAY, live_ufo_tray, 14))
	for bonus in [false, true]:
		out.append(_e("ev_ufo_tile_" + ("bonus" if bonus else "bone"), Rect2(0, 0, 102, 102), func(ci):
			var b := Art.rrect(Rect2(0, 0, 102, 102), 16, 750, 0.5)
			Art.dilate(ci, b, 2.5, Art.INK)
			ci.draw_colored_polygon(b, Color("ffe3a0") if bonus else Art.BONE), 6, [22, 22, 22, 22]))
	out.append(_e("ev_ufo_bonus_tag", Rect2(0, 0, 60, 28), func(ci):
		var t := Art.rrect(Rect2(0, 0, 60, 28), 10, 770, 0.4)
		Art.dilate(ci, t, 2.5, Art.INK)
		ci.draw_colored_polygon(t, Art.MOSS), 6))

## 入口气泡底：影子、墨线、玻璃边、夜空、牵引光
static func live_ufo_back(ci: CanvasItem) -> void:
	var C := UFO_C
	var bub := Art.ell(C, Vector2(UFO_RAD, UFO_RAD), 801, 0.03, 26)
	ci.draw_colored_polygon(Art.ell(C + Vector2(0, 6), Vector2(UFO_RAD + 2, UFO_RAD + 2), 802, 0.03, 26), Color(0, 0, 0, 0.25))
	Art.dilate(ci, bub, 3.0, Art.INK)
	ci.draw_colored_polygon(bub, Color("dff7f0"))
	ci.draw_colored_polygon(Art.ell(C, Vector2(UFO_RAD - 5, UFO_RAD - 5), 803, 0.03, 24), Color("27506a"))
	var beam := Art.poly([C + Vector2(-9, 8), C + Vector2(9, 8), C + Vector2(28, 44), C + Vector2(-28, 44)], 804)
	ci.draw_colored_polygon(beam, Color(0.8, 0.95, 0.5, 0.35))

## 飞碟（不含三颗灯，灯会闪，运行时另贴）
static func live_ufo_saucer(ci: CanvasItem) -> void:
	var dome := Art.ell(Vector2(0, -8), Vector2(17, 15), 805, 0.05, 16)
	Art.fill(ci, dome, Color("bfeee6"), 2.6)
	ci.draw_colored_polygon(Art.ell(Vector2(-6, -13), Vector2(4, 3), 806, 0.1, 8), Color(1, 1, 1, 0.8))
	var disc := Art.ell(Vector2(0, 2), Vector2(40, 11), 807, 0.04, 20)
	Art.fill(ci, disc, Color("a7b4b8"), 2.8)
	Art.fill(ci, Art.ell(Vector2(0, 0), Vector2(30, 5), 808, 0.05, 14), Color("d7e0e2"), 0.0)

## 玻璃高光、倒计时底条、「5折」小签。o 是入口左上角
static func live_ufo_front(ci: CanvasItem, o: Vector2) -> void:
	var C := UFO_C
	ci.draw_set_transform(o)
	Art.pl(ci, [C + Vector2(-40, -26), C + Vector2(-30, -40), C + Vector2(-16, -48)], 4.0, Color(1, 1, 1, 0.7), 812)
	var bar := Art.rrect(Rect2(C.x - 40, 88, 80, 28), 12, 813, 0.6)
	ci.draw_colored_polygon(bar, Color(0.08, 0.15, 0.2, 0.75))
	ci.draw_set_transform(o + Vector2(127, 16), 0.22, Vector2.ONE)
	Art.fill(ci, Art.rrect(Rect2(-28, -15, 56, 30), 9, 814, 0.6), Art.CLAY, 2.5)
	ci.draw_set_transform(Vector2.ZERO)

static func live_ufo_star(ci: CanvasItem, c: Vector2) -> void:
	var s := Art.star_pts(c, 62, 50, 14, 731)
	Art.dilate(ci, s, 3.5, Art.INK)
	ci.draw_colored_polygon(s, Art.CLAY)
	ci.draw_colored_polygon(Art.ell(c, Vector2(42, 42), 732, 0.03, 22), Color("e86a3c"))
	ci.draw_arc(c, 42, 0, TAU, 32, Color("ffd23f"), 3.0, true)

static func live_ufo_tray(ci: CanvasItem) -> void:
	var T := UFO_TRAY
	ci.draw_colored_polygon(Art.rrect(Rect2(T.position + Vector2(0, 8), T.size), 20, 727, 0.0), Color(0, 0, 0, 0.25))
	var tray := Art.rrect(T, 20, 728, 0.7)
	Art.dilate(ci, tray, 3.0, Art.INK)
	ci.draw_colored_polygon(tray, Art.WOOD)
	ci.draw_colored_polygon(Art.rrect(T.grow(-9), 14, 729, 0.5), Color("fff3d6"))
	Art.dashed(ci, Art.rrect(T.grow(-15), 12, 730, 0.0), 10, 7, Color("e0c08a"), 2.0)

# ================================================================ 月石遗迹（MergeEventPopup）

static func _merge(out: Array) -> void:
	out.append(_e("ev_me_timer_fill", Rect2(0, 0, 292, 36), func(ci):
		ci.draw_colored_polygon(Art.rrect(Rect2(0, 0, 292, 36), 18, 51, 0.4), Color(0.05, 0.12, 0.16, 0.75)), 4))
	# 描边用白色画，运行时按主题光色染
	out.append(_e("ev_me_timer_line", Rect2(0, 0, 292, 36), func(ci):
		Art.outline(ci, Art.rrect(Rect2(0, 0, 292, 36), 18, 51, 0.4), 2.0, Color.WHITE), 4))
	out.append(_e("ev_me_groove", Rect2(0, 0, 508, 20), func(ci):
		var g := Art.rrect(Rect2(0, 0, 508, 20), 10, 408, 0.3)
		Art.dilate(ci, g, 3.0, Art.INK)
		ci.draw_colored_polygon(g, Color("10232a")), 6, [12, 10, 12, 10]))
	out.append(_e("ev_me_fill", Rect2(0, 0, 508, 20), func(ci):
		ci.draw_colored_polygon(Art.rrect(Rect2(0, 0, 508, 20), 10, 409, 0.2), Color.WHITE), 3, [10, 10, 10, 10]))
	for big in [false, true]:
		var r := 36.0 if big else 28.0
		for st in 3:
			out.append(_e("ev_me_node_%s_%d" % ["big" if big else "small", st], Rect2(-r, -r, r * 2, r * 2), func(ci): live_me_node(ci, Vector2.ZERO, r, st), 6))
	out.append(_e("ev_me_tag_on", Rect2(0, 0, 62, 26), func(ci): Art.fill(ci, Art.rrect(Rect2(0, 0, 62, 26), 13, 440, 0.3), Color("8cc63f"), 2.2, Art.INK), 5))
	out.append(_e("ev_me_tag_off", Rect2(0, 0, 54, 26), func(ci): Art.fill(ci, Art.rrect(Rect2(0, 0, 54, 26), 13, 440, 0.3), Color("10232a"), 2.2, Art.INK), 5))
	out.append(_e("ev_me_socket", Rect2(-25, -25, 50, 50), func(ci):
		var socket := Art.ell(Vector2.ZERO, Vector2(25, 25), 710, 0.03, 18)
		ci.draw_colored_polygon(socket, Color("223b42"))
		Art.outline(ci, socket, 2.0, Color(0, 0, 0, 0.35)), 4))
	out.append(_e("ev_me_reward_card", Rect2(0, 0, 170, 200), func(ci):
		Art.fill(ci, Art.rrect(Rect2(0, 0, 170, 200), 20, 480, 0.4), Color("24404a"), 3.0, Art.INK), 6, [26, 26, 26, 26]))
	out.append(_e("ev_me_banner", Rect2(-210, -58, 420, 116), func(ci):
		Art.fill(ci, Art.rrect(Rect2(-210, -58, 420, 116), 26, 901, 0.4), Color(0.12, 0.25, 0.3, 0.94), 3.0, Art.INK), 6))

## 里程碑底盘（奖励图标运行时另画）。st：0 没到 / 1 可领 / 2 已领
static func live_me_node(ci: CanvasItem, c: Vector2, r: float, st: int) -> void:
	var disc := Art.ell(c, Vector2(r, r), 420, 0.03, 22)
	Art.dilate(ci, disc, 3.0, Art.INK)
	ci.draw_colored_polygon(disc, Color("f2c14e") if st == 1 else (Color("3d6a6f") if st == 2 else Color("2e5058")))
	ci.draw_colored_polygon(Art.ell(c + Vector2(0, 3), Vector2(r - 6, r - 7), 430, 0.03, 20), Color(0, 0, 0, 0.18))

# ================================================================ 香蕉竞速（RacePopup）

const RACE_PILL := {"time": [Color("8a5a30"), Vector2(240, 40)], "me": [Color("ffd23f"), Vector2(100, 38)], "other": [Color("6b4a2a"), Vector2(100, 38)]}

static func _race(out: Array) -> void:
	out.append(_e("ev_race_row", Rect2(0, 0, 536, 52), func(ci):
		var b := Art.rrect(Rect2(0, 0, 536, 52), 14, 201, 0.4)
		ci.draw_colored_polygon(b, Art.BONE)
		Art.outline(ci, b, 2.0, Color("c9a77a")), 4, [18, 18, 18, 18]))
	for mine in [true, false]:
		out.append(_e("ev_race_result_" + ("me" if mine else "other"), Rect2(0, 0, 536, 72), func(ci):
			var b := Art.rrect(Rect2(0, 0, 536, 72), 14, 7, 0.4)
			ci.draw_colored_polygon(b, Color("ffe08a") if mine else Art.BONE)
			Art.outline(ci, b, 4.0 if mine else 2.0, Art.CLAY if mine else Color("c9a77a")), 5, [18, 18, 18, 18]))
	for st in ["me", "on", "off"]:
		out.append(_e("ev_race_seat_" + st, Rect2(-70, -70, 140, 140), func(ci): live_race_seat(ci, Vector2.ZERO, st), 8))
	out.append(_e("ev_race_seat_shade", Rect2(-70, -70, 140, 140), func(ci): ci.draw_colored_polygon(Art.ell(Vector2.ZERO, Vector2(70, 70), 500, 0.03, 22), Color.WHITE), 4))
	for rank in 3:
		out.append(_e("ev_race_chest_%d" % rank, Rect2(-44, -40, 88, 76), func(ci): live_race_chest(ci, Vector2.ZERO, rank, 64.0), 6))
	out.append(_e("ev_race_bubble", Rect2(0, 0, 200, 142), func(ci): Art.fill(ci, Art.rrect(Rect2(0, 0, 200, 142), 18, 480, 0.4), Art.BONE, 2.6), 5, [24, 24, 24, 24]))
	for mine in [true, false]:
		out.append(_e("ev_race_tube_" + ("me" if mine else "other"), Rect2(0, 0, 84, 582), func(ci): live_race_tube(ci, Rect2(0, 0, 84, 582), mine), 8, [28, 28, 28, 28]))
	for k in RACE_PILL:
		var sz: Vector2 = RACE_PILL[k][1]
		out.append(_e("ev_race_pill_" + k, Rect2(Vector2.ZERO, sz), func(ci):
			var b := Art.rrect(Rect2(Vector2.ZERO, sz), sz.y * 0.5, 600, 0.3)
			Art.dilate(ci, b, 2.4, Art.INK)
			ci.draw_colored_polygon(b, RACE_PILL[k][0]), 5, [20, 19, 20, 19]))

## 匹配座位：me 我（黄底红圈）/ on 已锁定 / off 还在换
static func live_race_seat(ci: CanvasItem, c: Vector2, st: String) -> void:
	var seat := Art.ell(c, Vector2(70, 70), 500, 0.03, 22)
	Art.dilate(ci, seat, 3.0, Art.INK)
	ci.draw_colored_polygon(seat, Color("ffe08a") if st == "me" else (Color("f3dfb4") if st == "on" else Color("d9c3a0")))
	if st == "me":
		Art.outline(ci, seat, 4.0, Art.CLAY)

## 金银铜宝箱（名次数字运行时另写）
static func live_race_chest(ci: CanvasItem, c: Vector2, rank: int, s: float) -> void:
	var col: Color = MEDAL[rank]
	var k := s / 64.0
	ci.draw_colored_polygon(Art.ell(c + Vector2(0, 24 * k), Vector2(30 * k, 7 * k), 470 + rank, 0.05, 14), Color(0, 0, 0, 0.22))
	var body := Art.rrect(Rect2(c + Vector2(-27, -6) * k, Vector2(54, 30) * k), 5 * k, 471 + rank, 0.5)
	Art.fill(ci, body, col.darkened(0.12), 2.6)
	var lid := Art.rrect(Rect2(c + Vector2(-30, -24) * k, Vector2(60, 20) * k), 8 * k, 472 + rank, 0.5)
	Art.fill(ci, lid, col.lightened(0.15), 2.6)
	ci.draw_colored_polygon(Art.rrect(Rect2(c + Vector2(-24, -21) * k, Vector2(48, 5) * k), 2 * k, 473 + rank, 0.2), Color(1, 1, 1, 0.45))
	for x in [-17.0, 17.0]:
		ci.draw_rect(Rect2(c + Vector2(x - 3, -23) * k, Vector2(6, 46) * k), col.darkened(0.45))
	var lock := Art.rrect(Rect2(c + Vector2(-7, -10) * k, Vector2(14, 15) * k), 3 * k, 474 + rank, 0.3)
	Art.fill(ci, lock, Color("5a3a1e"), 2.0)
	ci.draw_circle(c + Vector2(0, -3) * k, 2.2 * k, col.lightened(0.4))
	var mc := c + Vector2(26, -24) * k
	Art.fill(ci, Art.ell(mc, Vector2(13, 13) * k, 475 + rank, 0.03, 14), col, 2.2)

## 竹筒（竹节细线运行时另画）
static func live_race_tube(ci: CanvasItem, tr: Rect2, mine: bool) -> void:
	var tube := Art.rrect(tr, 24, 400, 0.4)
	Art.dilate(ci, tube, 3.0, Art.INK)
	ci.draw_colored_polygon(tube, Color("7a5230") if mine else Color("5e3f25"))
	ci.draw_colored_polygon(Art.rrect(Rect2(tr.position + Vector2(8, 10), Vector2(10, tr.size.y - 20)), 5, 420, 0.2), Color(1, 1, 1, 0.08))
	if mine:
		Art.outline(ci, tube, 4.0, Color("ffd23f"))

# ================================================================ 部落排行（RankPopup）

static func _rank(out: Array) -> void:
	for rk in [1, 2, 3]:
		var h: float = RankPopup.STEP_H[rk - 1]
		out.append(_e("ev_rank_step_%d" % rk, Rect2(0, 0, 192, h), func(ci): live_rank_step(ci, Vector2(192, h), rk), 6))
		var ar := 42.0 if rk == 1 else 36.0
		for mine in [false, true]:
			out.append(_e("ev_rank_avatar_%d%s" % [rk, "_me" if mine else ""], Rect2(-ar - 8, -ar - 8, ar * 2 + 16, ar * 2 + 16), func(ci): live_rank_avatar(ci, Vector2.ZERO, ar, rk, mine), 4))
	out.append(_e("ev_rank_crown", Rect2(0, 0, 60, 40), func(ci):
		var pts := [Vector2(4, 36), Vector2(2, 10), Vector2(17, 22), Vector2(30, 2), Vector2(43, 22), Vector2(58, 10), Vector2(56, 36)]
		Art.fill(ci, Art.poly(pts, 90, 0.3), Art.FIRE2, 2.6), 5))
	for mine in [true, false]:
		out.append(_e("ev_rank_row_" + ("me" if mine else "other"), Rect2(0, 0, 584, 66), func(ci):
			var b := Art.rrect(Rect2(0, 0, 584, 66), 14, 7, 0.4)
			ci.draw_colored_polygon(b, Color("ffe08a") if mine else Art.BONE)
			Art.outline(ci, b, 4.0 if mine else 2.0, Art.CLAY if mine else Color("c9a77a")), 5, [18, 18, 18, 18]))

static func live_rank_step(ci: CanvasItem, sz: Vector2, rk: int) -> void:
	var body := Art.rrect(Rect2(Vector2(2, 2), sz - Vector2(4, 0)), 12, 70 + rk, 0.6)
	Art.dilate(ci, body, 3.0, Art.INK)
	ci.draw_colored_polygon(body, MEDAL[rk - 1].darkened(0.12))
	ci.draw_colored_polygon(Art.rrect(Rect2(Vector2(10, 10), Vector2(sz.x - 20, sz.y - 12)), 8, 73 + rk, 0.4), MEDAL[rk - 1])
	ci.draw_colored_polygon(Art.rrect(Rect2(Vector2(16, 14), Vector2(sz.x - 32, 12)), 6, 76 + rk, 0.3), Color(1, 1, 1, 0.3))

static func live_rank_avatar(ci: CanvasItem, c: Vector2, rad: float, rk: int, mine: bool) -> void:
	var ring := Art.ell(c, Vector2(rad + 5, rad + 5), 80 + rk, 0.02, 22)
	Art.dilate(ci, ring, 2.6, Art.INK)
	ci.draw_colored_polygon(ring, Art.CLAY if mine else MEDAL[rk - 1])
	var disc := Art.ell(c, Vector2(rad, rad), 83 + rk, 0.02, 22)
	Art.dilate(ci, disc, 1.8, Art.INK)
	ci.draw_colored_polygon(disc, [Art.TEAL, Art.LEATHER, Art.MOSS_D][rk - 1])

# ================================================================ 七日任务（SevenDayPopup）

const SD_RAIL_Y := 150.0

static func _seven(out: Array) -> void:
	out.append(_e("ev_sd_track", Rect2(0, 0, 632, 206), func(ci):
		Art.fill(ci, Art.rrect(Rect2(0, 0, 632, 206), 22, 711, 0.6), Color("f3dfb2"), 3)
		Art.fill(ci, Art.rrect(Rect2(8, SD_RAIL_Y - 30, 616, 62), 16, 712, 0.4), Color("e6cb95"), 0), 6))
	out.append(_e("ev_sd_flame", Rect2(-15, -20, 30, 40), func(ci):
		Art.fill(ci, Art.flame_pts(Vector2.ZERO, 11, 34, 714, 20), Art.FIRE, 2.4)
		ci.draw_colored_polygon(Art.flame_pts(Vector2(0, 6), 5, 16, 715, 16), Art.FIRE2), 5))
	for on in [true, false]:
		out.append(_e("ev_sd_stone_" + ("on" if on else "off"), Rect2(-24, -22, 48, 44), func(ci):
			var disc := Art.ell(Vector2.ZERO, Vector2(23, 21), 720, 0.05, 16)
			Art.dilate(ci, disc, 3.0, Art.INK)
			Art.shade(ci, disc, Color("ffcf4a") if on else Color("c9bfae"), 1), 6))
	out.append(_e("ev_sd_rope", Rect2(-3, 98, 6, 30), func(ci): Art.ln(ci, Vector2(0, 98), Vector2(0, SD_RAIL_Y - 22), 3.0, Color("a07a4a"), 725), 4))
	out.append(_e("ev_sd_grand_rib", Rect2(0, 0, 60, 24), func(ci): Art.fill(ci, Art.rrect(Rect2(0, 0, 60, 24), 8, 750, 0.4), Art.CLAY, 2.6), 5))
	out.append(_e("ev_sd_more", Rect2(-13, -11, 26, 22), func(ci): Art.fill(ci, Art.ell(Vector2.ZERO, Vector2(13, 11), 761, 0.03, 14), Art.TEAL, 2.4), 5))
	for st in ["ready", "claimed", "idle"]:
		out.append(_e("ev_sd_row_" + st, Rect2(0, 0, 624, 124), func(ci): live_sd_row(ci, Vector2(624, 124), st), 8))
	out.append(_e("ev_sd_row_glow", Rect2(0, 0, 624, 124), func(ci): Art.dilate(ci, Art.rrect(Rect2(0, 0, 624, 124), 20, 731, 0.5), 7.0, Color.WHITE), 10))
	for pts in SD_TIER:
		out.append(_e("ev_sd_tag_%d" % pts, Rect2(-40, -42, 80, 84), func(ci): live_sd_tag(ci, Vector2.ZERO, SD_TIER[pts], false), 8))
	out.append(_e("ev_sd_tag_claimed", Rect2(-40, -42, 80, 84), func(ci): live_sd_tag(ci, Vector2.ZERO, Color("bdb5a6"), true), 8))
	out.append(_e("ev_sd_ready_rib", Rect2(0, 0, 96, 30), func(ci): Art.fill(ci, Art.rrect(Rect2(0, 0, 96, 30), 10, 736, 0.4), Art.CLAY, 2.6), 5))
	out.append(_e("ev_sd_wip", Rect2(0, 0, 128, 56), func(ci): Art.fill(ci, Art.rrect(Rect2(0, 0, 128, 56), 16, 737, 0.4), Color("e8dcc2"), 2.5, Color("b5a688")), 5))

## 任务行底子（不含外圈呼吸光）。st：ready 可领 / claimed 已领 / idle 进行中
static func live_sd_row(ci: CanvasItem, sz: Vector2, st: String) -> void:
	var ready := st == "ready"
	var body := Art.rrect(Rect2(Vector2.ZERO, sz), 20, 731, 0.5)
	ci.draw_colored_polygon(Art.rrect(Rect2(Vector2(0, 5), sz), 20, 731, 0.5), Color(0.3, 0.18, 0.08, 0.22 if ready else 0.0))
	var bg := Color("d2ccbf") if st == "claimed" else (Color("dcf0b4") if ready else Color("f6ecd8"))
	Art.fill(ci, body, bg, 3 if ready else 2, Art.INK if ready else Color("b8a582"))
	if ready:
		Art.outline(ci, Art.rrect(Rect2(Vector2(5, 5), sz - Vector2(10, 10)), 16, 732, 0.3), 5, Art.MOSS_D)

static func live_sd_tag(ci: CanvasItem, c: Vector2, col: Color, claimed: bool) -> void:
	var tag := Art.ell(c, Vector2(38, 40), 733, 0.06, 18)
	Art.dilate(ci, tag, 3.0, Color("9a8e7c") if claimed else Art.INK)
	Art.shade(ci, tag, col, 0)

# ================================================================ 赶大集（SpreePopup / SpreeCard）

static func _spree(out: Array) -> void:
	var art := Rect2(0, 0, 592, 700)
	out.append(_e("ev_spree_bg", art, func(ci):
		var bg := Art.rrect(art, 22, 911, 0.6)
		Art.dilate(ci, bg, 3.0, Art.INK)
		ci.draw_colored_polygon(bg, Color("f7d59a")), 6))
	out.append(_e("ev_spree_scene", art, func(ci): live_spree_scene(ci, art.size), 6))
	out.append(_e("ev_spree_bunting", art, func(ci): live_spree_bunting(ci, art.size), 6))
	out.append(_e("ev_spree_bags_back", art, func(ci):
		live_spree_bag(ci, Vector2(art.size.x * 0.5 - 150, 330), -0.18, Art.OCHRE, 940, false)
		live_spree_bag(ci, Vector2(art.size.x * 0.5 + 150, 322), 0.16, Art.TEAL, 950, false), 6))
	out.append(_e("ev_spree_bags_front", art, func(ci):
		live_spree_bag(ci, Vector2(art.size.x * 0.5 - 150, 330), -0.18, Art.OCHRE, 940, true)
		live_spree_bag(ci, Vector2(art.size.x * 0.5 + 150, 322), 0.16, Art.TEAL, 950, true), 6))
	out.append(_e("ev_spree_top", art, func(ci):
		for k in 7:
			var p := Vector2(60 + Art.srnd(k * 13 + 3) * (art.size.x - 120), 70 + Art.srnd(k * 17 + 9) * 260)
			ci.draw_colored_polygon(Art.star_pts(p, 10, 3, 4, 960 + k), Color(1, 1, 1, 0.75))
		Art.outline(ci, Art.rrect(art, 22, 911, 0.6), 3.0, Art.INK), 6))
	out.append(_e("ev_spree_grid", Rect2(0, 0, 536, 286), func(ci):
		var p := Art.rrect(Rect2(0, 0, 536, 286), 22, 970, 0.6)
		ci.draw_colored_polygon(p, Color(0.24, 0.15, 0.08, 0.5))
		Art.outline(ci, p, 2.5, Color(1, 0.95, 0.85, 0.5)), 5))
	out.append(_e("ev_spree_burst", Rect2(0, 0, 150, 136), func(ci):
		var c := Vector2(75, 68)
		var s := Art.star_pts(c, 70, 58, 16, 990)
		Art.dilate(ci, s, 3.5, Art.INK)
		ci.draw_colored_polygon(s, Color("e5483a"))
		Art.dashed(ci, Art.ell(c, Vector2(50, 50), 991, 0.03, 24), 7, 5, Color(1, 0.9, 0.8, 0.8), 2.0), 8))
	out.append(_e("ev_spree_card_back", Rect2(0, 0, 100, 100), live_spree_card_back, 6))
	out.append(_e("ev_spree_card_front", Rect2(0, 0, 100, 100), live_spree_card_front, 6))

## 地面、地上的小土坑、两边的兽皮棚（棚下的货运行时另画）
static func live_spree_scene(ci: CanvasItem, sz: Vector2) -> void:
	var ground := [Vector2(10, 330), Vector2(sz.x * 0.3, 318), Vector2(sz.x * 0.7, 324), Vector2(sz.x - 10, 312), Vector2(sz.x - 10, sz.y - 12), Vector2(10, sz.y - 12)]
	ci.draw_colored_polygon(Art.poly(ground, 912), Color("d9b47a"))
	for k in 18:
		var p := Vector2(30 + Art.srnd(k * 3 + 5) * (sz.x - 60), 350 + Art.srnd(k * 7 + 1) * (sz.y - 380))
		ci.draw_colored_polygon(Art.ell(p, Vector2(6 + Art.srnd(k) * 6, 3), 913 + k, 0.2, 8), Color(0.55, 0.38, 0.2, 0.25))
	live_spree_stall(ci, Rect2(6, 120, 170, 230), Art.CLAY, 914)
	live_spree_stall(ci, Rect2(sz.x - 176, 110, 170, 240), Art.TEAL, 920)

static func live_spree_stall(ci: CanvasItem, r: Rect2, col: Color, seed: int) -> void:
	for x in [r.position.x + 18, r.end.x - 18]:
		Art.ln(ci, Vector2(x, r.position.y + 30), Vector2(x, r.end.y), 9.0, Art.INK, seed)
		Art.ln(ci, Vector2(x, r.position.y + 30), Vector2(x, r.end.y), 5.5, Art.WOOD, seed)
	var roof := Art.poly([r.position + Vector2(-6, 50), r.position + Vector2(r.size.x * 0.5, 0), Vector2(r.end.x + 6, r.position.y + 50), Vector2(r.end.x, r.position.y + 78), r.position + Vector2(0, 78)], seed + 1)
	Art.fill(ci, roof, col, 3.0)
	for k in 4:
		var x := r.position.x + 18 + k * (r.size.x - 36) / 3.0
		Art.ln(ci, Vector2(x, r.position.y + 30 - absf(k - 1.5) * 4), Vector2(x, r.position.y + 76), 6.0, Color(1, 1, 1, 0.3), seed + 2 + k)
	var shelf := Art.rrect(Rect2(r.position.x + 4, r.end.y - 56, r.size.x - 8, 22), 6, seed + 6, 0.6)
	Art.fill(ci, shelf, Art.WOOD, 2.5)

static func live_spree_bunting(ci: CanvasItem, sz: Vector2) -> void:
	var rope: Array = []
	for k in 13:
		var u := float(k) / 12.0
		rope.append(Vector2(14 + u * (sz.x - 28), 40 + sin(u * PI) * 54))
	Art.pl(ci, rope, 3.0, Art.WOOD_D, 915)
	var flags := [Art.CLAY, Art.OCHRE, Art.TEAL, Art.MOSS, Art.BONE, Art.BERRY]
	for k in 12:
		var a: Vector2 = rope[k]
		var b: Vector2 = rope[k + 1]
		var m := a.lerp(b, 0.5)
		var f := Art.poly([a.lerp(b, 0.15) + Vector2(0, 2), a.lerp(b, 0.85) + Vector2(0, 2), m + Vector2(0, 30)], 930 + k)
		Art.fill(ci, f, flags[k % flags.size()], 2.2)

## 草编袋：front = false 只画提手（在袋口物品后面），true 画袋身
static func live_spree_bag(ci: CanvasItem, c: Vector2, rot: float, band: Color, seed: int, front: bool) -> void:
	var f := func(pts: Array) -> Array:
		var out: Array = []
		for p in pts: out.append(c + (p as Vector2).rotated(rot))
		return out
	if not front:
		var handle: Array = f.call([Vector2(-34, -40), Vector2(-20, -92), Vector2(20, -92), Vector2(34, -40)])
		Art.pl(ci, handle, 6.0, Art.INK, seed)
		Art.pl(ci, handle, 3.5, Art.ROPE, seed)
		return
	var body := Art.poly(f.call([Vector2(-52, -38), Vector2(52, -38), Vector2(60, 56), Vector2(42, 74), Vector2(-42, 74), Vector2(-60, 56)]), seed + 1)
	Art.dilate(ci, body, 3.0, Art.INK)
	ci.draw_colored_polygon(body, Art.WOOD)
	for k in 5:
		var y := -26.0 + k * 20.0
		Art.pl(ci, f.call([Vector2(-52, y), Vector2(0, y + 4), Vector2(52, y)]), 2.0, Art.WOOD_D, seed + 2 + k)
	ci.draw_colored_polygon(Art.poly(f.call([Vector2(-56, -12), Vector2(56, -12), Vector2(57, 6), Vector2(-57, 6)]), seed + 8), band)
	Art.outline(ci, body, 3.0, Art.INK)

## 部落界面「赶大集」卡：卡底 + 袋子提手（物品在它和袋身之间）
static func live_spree_card_back(ci: CanvasItem) -> void:
	var r := Rect2(10, 3, 80, 80)
	ci.draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(0, 4), r.size), 14, 492, 0.0), Color(0, 0, 0, 0.28))
	var b := Art.rrect(r, 14, 492, 0.9)
	Art.dilate(ci, b, 2.6, Art.INK)
	ci.draw_colored_polygon(b, Color("e7b45a"))
	ci.draw_colored_polygon(Art.rrect(r.grow(-5), 10, 493, 0.5), Color("f2c66e"))
	var c := Vector2(50, 50)
	Art.pl(ci, [c + Vector2(-16, -10), c + Vector2(-10, -30), c + Vector2(10, -30), c + Vector2(16, -10)], 4.0, Art.INK, 494)
	Art.pl(ci, [c + Vector2(-16, -10), c + Vector2(-10, -30), c + Vector2(10, -30), c + Vector2(16, -10)], 2.2, Art.ROPE, 494)

static func live_spree_card_front(ci: CanvasItem) -> void:
	var c := Vector2(50, 50)
	var bag := Art.poly([c + Vector2(-24, -8), c + Vector2(24, -8), c + Vector2(28, 20), c + Vector2(-28, 20)], 495)
	Art.fill(ci, bag, Art.WOOD, 2.4)
	ci.draw_colored_polygon(Art.poly([c + Vector2(-26, 0), c + Vector2(26, 0), c + Vector2(27, 7), c + Vector2(-27, 7)], 496), Art.CLAY)
	Art.fill(ci, Art.star_pts(Vector2(84, 14), 15, 11, 10, 497), Color("e5483a"), 2.0)

# ================================================================ 火种大礼包（EnergyOfferPopup）

static func _energy(out: Array) -> void:
	out.append(_e("ev_energy_vines", Rect2(0, 74, 720, 276), live_energy_vines, 10))
	out.append(_e("ev_energy_hill", Rect2(96, 384, 528, 150), live_energy_hill, 8))
	for k in 3:
		out.append(_e("ev_energy_card_%d" % k, Rect2(0, 0, 206, 600), func(ci): live_energy_card(ci, Vector2(206, 600), k), 20))
	out.append(_e("ev_energy_best", Rect2(0, 0, 234, 56), func(ci):
		var sz := Vector2(234, 56)
		var p := Art.poly([Vector2(0, 6), Vector2(sz.x, 0), Vector2(sz.x - 14, sz.y * 0.5), Vector2(sz.x, sz.y), Vector2(0, sz.y - 4), Vector2(12, sz.y * 0.5)], 820)
		Art.fill(ci, p, Color("e8577a"), 3.0)
		Art.dashed(ci, Art.poly([Vector2(16, 12), Vector2(sz.x - 18, 8), Vector2(sz.x - 18, sz.y - 10), Vector2(16, sz.y - 10)], 821), 7, 5, Color(1, 0.9, 0.9, 0.7), 2.0), 6))

## 标题两侧的藤蔓野花（礼包面板头图坐标）
static func live_energy_vines(ci: CanvasItem) -> void:
	for side in [-1.0, 1.0]:
		var base := Vector2(360 + side * 290, 330)
		var vine: Array = []
		for k in 9:
			var u := float(k) / 8.0
			vine.append(base + Vector2(side * -sin(u * 2.4) * 40.0 - side * u * 30.0, -u * 230.0))
		Art.pl(ci, vine, 7.0, Art.INK, 711)
		Art.pl(ci, vine, 4.0, Art.LEAF_D, 711)
		for k in range(1, 8):
			var p: Vector2 = vine[k]
			var leaf := Art.ell(p + Vector2(side * 16, 0), Vector2(18, 8), 712 + k, 0.08, 10, side * 0.6 + (k % 2) * 0.8)
			Art.fill(ci, leaf, Art.LEAF, 2.2)
		for k in [2, 5, 8]:
			var p: Vector2 = vine[k]
			live_flower(ci, p + Vector2(side * -14, -6), Art.BERRY if k == 5 else Color("f39ab0"), 720 + k)

static func live_energy_hill(ci: CanvasItem) -> void:
	var hill := Art.ell(Vector2(360, 452), Vector2(250, 62), 730, 0.04, 30)
	ci.draw_colored_polygon(Art.ell(Vector2(360, 466), Vector2(252, 60), 731, 0.04, 30), Color(0, 0, 0, 0.3))
	Art.dilate(ci, hill, 3.0, Art.INK)
	ci.draw_colored_polygon(hill, Color("8a6038"))
	ci.draw_colored_polygon(Art.ell(Vector2(360, 440), Vector2(240, 48), 732, 0.05, 28), Art.LEAF)
	for k in 12:
		var p := Vector2(150 + Art.srnd(k * 5 + 1) * 420, 418 + Art.srnd(k * 3 + 7) * 34)
		Art.pl(ci, [p, p + Vector2(-4, -12), p + Vector2(2, -4), p + Vector2(6, -14)], 2.0, Art.LEAF_D, 733 + k)

static func live_flower(ci: CanvasItem, c: Vector2, col: Color, seed: int) -> void:
	for k in 5:
		var a := TAU * k / 5.0
		Art.fill(ci, Art.ell(c + Vector2.from_angle(a) * 9, Vector2(8, 6), seed + k, 0.1, 8, a), col, 2.0)
	ci.draw_circle(c, 5, Art.FIRE2)

static func live_energy_card(ci: CanvasItem, sz: Vector2, k: int) -> void:
	ci.draw_colored_polygon(Art.rrect(Rect2(Vector2(0, 10), sz), 24, 750 + k, 0.0), Color(0, 0, 0, 0.3))
	var b := Art.rrect(Rect2(Vector2.ZERO, sz), 24, 751 + k, 0.8)
	Art.dilate(ci, b, 3.0, Art.INK)
	ci.draw_colored_polygon(b, EN_HEAD[k])
	ci.draw_colored_polygon(Art.rrect(Rect2(8, 8, sz.x - 16, sz.y - 16), 18, 754 + k, 0.6), EN_BODY[k])
	for j in 6:
		var x: float = 22.0 + j * (sz.x - 44) / 5.0
		Art.ln(ci, Vector2(x, 14), Vector2(x, sz.y - 14), 10.0, Color(1, 1, 1, 0.12), 757 + j)
	for j in 7:
		var p := Vector2(16 + j * (sz.x - 32) / 6.0, 4 + (j % 2) * 6)
		Art.fill(ci, Art.ell(p, Vector2(20, 10), 760 + j + k * 7, 0.08, 10, -0.5 + j * 0.17), Art.LEAF, 2.2)
	live_flower(ci, Vector2(sz.x * 0.36, 0), Color("f39ab0"), 780 + k * 5)
	live_flower(ci, Vector2(sz.x * 0.68, 6), Color("8fc7ff") if k == 0 else Art.BERRY, 790 + k * 5)
	var inner := Art.rrect(Rect2(16, 92, sz.x - 32, 360), 16, 800 + k, 0.5)
	ci.draw_colored_polygon(inner, Color("f5e7cf"))
	Art.outline(ci, inner, 2.0, Color(0, 0, 0, 0.15))

# ================================================================ 部落礼包链（GiftChainPopup / GiftChainCard）

const GIFT_W := 580.0
const GIFT_H := 236.0
const GIFT_ROPE := Rect2(150, 570, 420, 640)

static func _gift(out: Array) -> void:
	for live in [true, false]:
		out.append(_e("ev_gift_card_" + ("live" if live else "lock"), Rect2(0, 0, GIFT_W, GIFT_H), func(ci): live_gift_card(ci, Vector2(GIFT_W, GIFT_H), live), 8))
		out.append(_e("ev_gift_seal_" + ("live" if live else "lock"), Rect2(0, 0, 150, 38), func(ci):
			Art.fill(ci, Art.rrect(Rect2(0, 0, 150, 38), 12, 750, 0.8), Art.CLAY if live else Color("8a4a2e"), 2.6), 6))
	for paid in [true, false]:
		out.append(_e("ev_gift_badge_" + ("paid" if paid else "free"), Rect2(-28, -26, 56, 52), func(ci):
			var badge := Art.ell(Vector2.ZERO, Vector2(26, 24), 740, 0.05, 16)
			Art.dilate(ci, badge, 2.6, Art.INK)
			ci.draw_colored_polygon(badge, Art.CLAY if paid else Color("8a6a3a")), 5))
	out.append(_e("ev_gift_lock", Rect2(0, 0, GIFT_W, GIFT_H), func(ci): live_gift_lock(ci, Vector2(GIFT_W, GIFT_H)), 8))
	out.append(_e("ev_gift_rope", GIFT_ROPE, live_gift_rope, 8))
	out.append(_e("ev_giftcard_base", Rect2(0, 0, 100, 100), live_giftcard_base, 6))
	out.append(_e("ev_giftcard_box", Rect2(0, 0, 100, 100), live_giftcard_box, 6))

## 礼包卡底：影子、陶土板、木纹、内衬、虚线（步数徽章、奖励、印章、锁运行时另贴）
static func live_gift_card(ci: CanvasItem, sz: Vector2, live: bool, i: int = 0) -> void:
	var r := Rect2(Vector2.ZERO, sz - Vector2(0, 8))
	ci.draw_colored_polygon(Art.rrect(Rect2(Vector2(0, 8), r.size), 22, 700 + i, 0.0), Color(0, 0, 0, 0.32))
	var b := Art.rrect(r, 22, 710 + i, 1.0)
	Art.dilate(ci, b, 3.0, Art.INK)
	ci.draw_colored_polygon(b, Color("b8743e") if live else Color("7d5a3e"))
	for k in 4:
		var y := 16.0 + k * 52.0 + Art.srnd(i * 7 + k) * 10.0
		Art.ln(ci, Vector2(24, y), Vector2(sz.x - 24, y + (Art.srnd(i + k * 3) - 0.5) * 6.0), 1.6, Color(0.25, 0.12, 0.05, 0.18), i * 10 + k)
	var ir := Rect2(70, 22, sz.x - 140, 148)
	ci.draw_colored_polygon(Art.rrect(ir, 16, 720 + i, 0.6), Color("f3e2c0") if live else Color("c9b391"))
	Art.dashed(ci, Art.rrect(ir.grow(-6), 12, 730 + i, 0.0), 6, 5, Color(0.55, 0.32, 0.1, 0.4), 1.6)

## 锁着的预览：压暗 + 绳子捆上 + 石锁底（锁形字运行时另画）
static func live_gift_lock(ci: CanvasItem, sz: Vector2, i: int = 0) -> void:
	var r := Rect2(Vector2.ZERO, sz - Vector2(0, 8))
	ci.draw_colored_polygon(Art.rrect(r, 22, 710 + i, 1.0), Color(0.12, 0.06, 0.02, 0.38))
	Art.ln(ci, Vector2(sz.x * 0.5 - 6, 0), Vector2(sz.x * 0.5 + 6, r.size.y), 7.0, Art.ROPE, i * 3 + 1)
	Art.ln(ci, Vector2(sz.x * 0.5 - 6, 0), Vector2(sz.x * 0.5 + 6, r.size.y), 2.0, Color(0.45, 0.3, 0.12, 0.8), i * 3 + 2)
	var lc := Vector2(sz.x - 36, r.size.y * 0.5 + 6)
	var plate := Art.ell(lc, Vector2(28, 28), 760 + i, 0.06, 14)
	Art.dilate(ci, plate, 2.6, Art.INK)
	ci.draw_colored_polygon(plate, Art.STONE)

## 卡片之间串着的两股绳子 + 绳结（面板坐标）
static func live_gift_rope(ci: CanvasItem) -> void:
	var slot := func(k: int) -> float: return 24.0 + k * (GIFT_H + 52.0)
	var top := 372.0 - 24.0
	for k in 3:
		var y0: float = top + slot.call(k) + GIFT_H - 30.0
		var y1: float = top + slot.call(k + 1) + 20.0
		if k == 2:
			y1 = 1290.0 - 90.0
		for side in [-1.0, 1.0]:
			var x: float = 70.0 + GIFT_W * 0.5 + side * 200.0
			Art.ln(ci, Vector2(x, y0), Vector2(x + side * 4.0, y1), 8.0, Art.INK, k * 4 + int(side))
			Art.ln(ci, Vector2(x, y0), Vector2(x + side * 4.0, y1), 5.0, Art.ROPE, k * 4 + int(side) + 1)
			var m := Vector2(x + side * 2.0, (y0 + y1) * 0.5)
			var knot := Art.ell(m, Vector2(9, 8), 770 + k * 2 + int(side), 0.08, 10)
			Art.dilate(ci, knot, 2.0, Art.INK)
			ci.draw_colored_polygon(knot, Color("c9a35e"))

## 部落界面「礼包链」卡底（光芒、物品、礼盒、闪光、红点运行时另画）
static func live_giftcard_base(ci: CanvasItem) -> void:
	var r := Rect2(10, 3, 80, 80)
	ci.draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(0, 4), r.size), 14, 292, 0.0), Color(0, 0, 0, 0.28))
	var b := Art.rrect(r, 14, 292, 0.9)
	Art.dilate(ci, b, 2.6, Art.INK)
	ci.draw_colored_polygon(b, Color("e7b45a"))
	ci.draw_colored_polygon(Art.rrect(r.grow(-5), 10, 293, 0.5), Color("f2c66e"))
	ci.draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(8, 6), Vector2(r.size.x - 16, 10)), 5, 294, 0.3), Color(1, 1, 1, 0.22))

## 红色礼盒 + 金色缎带 + 蝴蝶结
static func live_giftcard_box(ci: CanvasItem) -> void:
	var c0 := Vector2(50, 44)
	var bx := Rect2(c0.x - 22, 40, 44, 32)
	var lid := Rect2(c0.x - 26, 30, 52, 13)
	ci.draw_colored_polygon(Art.rrect(Rect2(bx.position + Vector2(0, 3), bx.size), 4, 301, 0), Color(0, 0, 0, 0.22))
	Art.fill(ci, Art.rrect(bx, 4, 302, 0.4), Art.CLAY, 2.4)
	ci.draw_rect(Rect2(bx.position.x, bx.position.y + 2, 6, bx.size.y - 4), Color(1, 1, 1, 0.18))
	Art.fill(ci, Art.rrect(lid, 4, 303, 0.4), Color("e8673f"), 2.4)
	ci.draw_rect(Rect2(c0.x - 5, lid.position.y + 1.5, 10, bx.end.y - lid.position.y - 3), Art.FIRE2)
	ci.draw_rect(Rect2(bx.position.x + 1.5, bx.position.y + 12, bx.size.x - 3, 8), Art.FIRE2)
	for side in [-1, 1]:
		var loop := Art.ell(Vector2(c0.x + side * 11, lid.position.y - 6), Vector2(11, 7), 304 + side, 0.05, 12, side * 0.4)
		Art.fill(ci, loop, Art.FIRE2, 2.2)
	ci.draw_circle(Vector2(c0.x, lid.position.y - 3), 5.5, Art.INK)
	ci.draw_circle(Vector2(c0.x, lid.position.y - 3), 4, Color("ffb02e"))
