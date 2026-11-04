class_name PassPopup
extends RefCounted
## 丰收通行证。头图固定，奖励轨道单独滚动。

const ROW := 156.0
const TRACK_TOP := 500.0
const LEFT_X := 16.0
const RIGHT_X := 454.0
const CARD_W := 250.0
const MID_X := 360.0

static func screen() -> PopupBase:
	var p := PopupBase.new()
	p.dim_alpha = 1.0
	p.set_meta("fullscreen", true)
	UI.box(p.box, Rect2(0, 0, 720, 1480), _paint_bg, false)
	var fs := Popups.fullscreen(p, TRACK_TOP)
	var sc: Scroller = fs[0]
	var root: Control = fs[1]
	var n := Data.PASS_LEVELS.size()
	var list_h := float(n + 1) * ROW
	var track := UI.box(root, Rect2(0, TRACK_TOP, 720, list_h), _paint_track)
	for i in n:
		var lv := i + 1
		var y := TRACK_TOP + float(i) * ROW
		var free_b := _blank(root, Rect2(LEFT_X, y + 8, CARD_W, ROW - 16))
		free_b.pressed.connect(_claim_free.bind(lv, free_b))
		var prem_b := _blank(root, Rect2(RIGHT_X, y + 8, CARD_W, ROW - 16))
		prem_b.pressed.connect(_claim_prem.bind(lv, prem_b))
	var end_b := _blank(root, Rect2(RIGHT_X, TRACK_TOP + float(n) * ROW + 8, CARD_W, ROW - 16))
	end_b.pressed.connect(_claim_endless.bind(end_b))
	var focus := mini(n, maxi(1, G.pass_reached() + 1))
	if G.pass_reached() >= n:
		focus = n
	sc.offset = float(focus - 1) * ROW
	sc.set_length(list_h + 28.0)
	var head := UI.box(p.box, Rect2(0, 128, 720, 372), _paint_head)
	UI.title(p.box, "丰收通行证", Rect2(168, 300, 384, 56), 36)
	var time_lbl := UI.lbl(p.box, "", Rect2(256, 364, 230, 42), 22, Art.INK)
	var prog_lbl := UI.lbl(p.box, "", Rect2(84, 446, 160, 36), 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK, true)
	var act := UI.btn(p.box, Rect2(418, 436, 270, 60), "", "green", func(): G.main.open("pass_buy"), 32)
	var refresh := func():
		time_lbl.text = G.fmt_time(G.event_left())
		prog_lbl.text = G.pass_prog_text()
		act.visible = G.pass_tier < 2
		act.text = "升级" if G.pass_tier == 1 else "激活"
		act.queue_redraw()
		head.queue_redraw()
		track.queue_redraw()
	refresh.call()
	Popups.live(p, G.changed, refresh)
	var clock := Timer.new()
	clock.wait_time = 1.0
	clock.autostart = true
	p.add_child(clock)
	clock.timeout.connect(func():
		if is_instance_valid(time_lbl):
			time_lbl.text = G.fmt_time(G.event_left()))
	return p

static func buy() -> PopupBase:
	var p := PopupBase.new()
	var r := Rect2(32, 188, 656, 1120)
	Popups.frame(p, r, "丰收通行证", Art.CLAY)
	UI.box(p.box, Rect2(r.position.x + 36, r.position.y + 48, r.size.x - 72, 250), _paint_hoard)
	var tw := 292.0
	var th := 700.0
	var y := r.position.y + 318.0
	_ticket(p, Rect2(r.position.x + 24, y, tw, th), false)
	_ticket(p, Rect2(r.end.x - 24 - tw, y, tw, th), true)
	return p

static func _ticket(p: PopupBase, r: Rect2, super_vip: bool) -> void:
	UI.box(p.box, r, func(ci, sz): _paint_ticket(ci, sz, not super_vip))
	UI.lbl(p.box, "超级贵宾" if super_vip else "贵宾", Rect2(r.position.x + 12, r.position.y + 20, r.size.x - 24, 50), 28, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK, true)
	UI.lbl(p.box, "解锁高级奖励", Rect2(r.position.x + 12, r.position.y + 96, r.size.x - 24, 36), 22, Color("6b4a2a"))
	UI.lbl(p.box, "+", Rect2(r.position.x, r.position.y + 136, r.size.x, 48), 40, Art.MOSS, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK, true)
	if super_vip:
		var x1 := r.position.x + 78.0
		var x2 := r.end.x - 86.0
		var iy := r.position.y + 230.0
		UI.icon(p.box, "fire_2", Vector2(x1, iy), 86)
		UI.lbl(p.box, "×150", Rect2(x1 - 50, iy + 44, 100, 32), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 5, Art.INK, true)
		UI.icon(p.box, "chest_1", Vector2(x2, iy), 86)
		UI.lbl(p.box, "解锁循环奖励", Rect2(x2 - 72, iy + 48, 150, 32), 16, Color("6b4a2a"))
		var y2 := iy + 146.0
		UI.icon(p.box, "token_1", Vector2(x1, y2), 80)
		UI.lbl(p.box, "×10", Rect2(x1 - 50, y2 + 42, 100, 32), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 5, Art.INK, true)
		UI.lbl(p.box, "订单额外 +1 积分", Rect2(x2 - 78, y2 - 8, 156, 64), 18, Color("6b4a2a"))
		_stamp(p, r)
	else:
		UI.icon(p.box, "fire_2", r.position + Vector2(r.size.x * 0.5, 268), 110)
		UI.lbl(p.box, "×150", Rect2(r.position.x, r.position.y + 322, r.size.x, 44), 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 7, Art.INK, true)
	var owned := G.pass_tier >= (2 if super_vip else 1)
	var b := UI.btn(p.box, Rect2(r.position.x + 24, r.end.y - 108, r.size.x - 48, 80), "79" if super_vip else "49", "green", Callable(), 36)
	b.res = "amber_3"
	if owned:
		b.text = "已拥有"
		b.res = ""
		b.enabled = false
	elif super_vip:
		b.pressed.connect(func(): _do_super(p))
	else:
		b.pressed.connect(func(): _do_vip(p))

static func _stamp(p: PopupBase, r: Rect2) -> void:
	var s := Rect2(r.end.x - 78, r.position.y - 8, 92, 92)
	UI.box(p.box, s, func(ci, sz):
		Art.fill(ci, Art.star_pts(sz * 0.5, 40, 32, 14, 4, 0.2), Art.CLAY, 3.0))
	var lab := UI.lbl(p.box, "超值", Rect2(s.position.x, s.position.y + 26, s.size.x, 40), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 5, Art.INK, true)
	lab.pivot_offset = lab.size * 0.5
	lab.rotation = 0.18

static func _do_vip(p: PopupBase) -> void:
	if not G.buy_pass_vip():
		return
	p.close()
	G.main.toast("已激活贵宾：火种 ×150，高级奖励已开放")

static func _do_super(p: PopupBase) -> void:
	var fresh := G.pass_tier == 0
	if not G.buy_pass_super():
		return
	p.close()
	if fresh:
		G.main.toast("已激活超级贵宾：火种 ×150，通行证 +10，循环奖励已开放")
	else:
		G.main.toast("已升级超级贵宾：通行证 +10，循环奖励已开放")

static func _claim_free(lv: int, btn: Control) -> void:
	var rw: Array = G.claim_pass_free(lv)
	if not rw.is_empty():
		_grant(btn, rw)

static func _claim_prem(lv: int, btn: Control) -> void:
	var rw: Array = G.claim_pass_prem(lv)
	if not rw.is_empty():
		_grant(btn, rw)

static func _claim_endless(btn: Control) -> void:
	var rw: Array = G.claim_pass_endless()
	if not rw.is_empty():
		_grant(btn, rw)

static func _grant(_btn: Control, rw: Array) -> void:
	G.main.present_rewards(rw)

static func _blank(parent: Node, r: Rect2) -> TButton:
	var b := TButton.new()
	b.position = r.position
	b.size = r.size
	b.style = "none"
	parent.add_child(b)
	return b

static func _paint_bg(ci: CanvasItem, sz: Vector2) -> void:
	Paint.vgrad(ci, Rect2(0, 0, sz.x, 470), Color("8fd0d4"), Color("f0deb0"))
	Paint.vgrad(ci, Rect2(0, 470, sz.x, sz.y - 470), Color("5a3c26"), Color("3a2618"))

static func _paint_head(ci: CanvasItem, sz: Vector2) -> void:
	Paint.hills(ci, 206, sz.x, 26, Color("7fb48a"), 2, 314)
	Paint.hills(ci, 242, sz.x, 14, Color("5c9a68"), 6, 318)
	Paint.palm(ci, Vector2(42, 250), 120, 3, Color("3f7a40"))
	Paint.palm(ci, Vector2(684, 256), 100, 8, Color("4a8a4a"))
	Art.item(ci, "basket_3", Vector2(112, 248), 72)
	Art.item(ci, "fruit_3", Vector2(628, 236), 60)
	Paint.heroine(ci, Vector2(226, 156), 112)
	Paint.mascot(ci, Vector2(528, 166), 100)
	Paint.banner(ci, Rect2(130, 160, 460, 82), Art.CLAY)
	Paint.pill(ci, Rect2(200, 236, 320, 42), 11)
	Paint.glyph(ci, "clock", Vector2(228, 257), 1.2)
	ci.draw_rect(Rect2(0, 308, sz.x, sz.y - 308), Art.LEATHER)
	ci.draw_rect(Rect2(0, 308, sz.x, 5), Art.LEATHER_D)
	Art.item(ci, "token_1", Vector2(48, 340), 58)
	var reached := G.pass_reached()
	Paint.bar(ci, Rect2(84, 324, 160, 30), G.pass_frac(), Art.MOSS, 14)
	_diamond(ci, Vector2(286, 340), 22, 26, Art.OCHRE, 15)
	_center_text(ci, Vector2(286, 340), str(reached), 22)

static func _paint_track(ci: CanvasItem, _sz: Vector2) -> void:
	var n := Data.PASS_LEVELS.size()
	var reached := G.pass_reached()
	for i in n:
		var y := float(i) * ROW
		var lv := i + 1
		var top := Art.MOSS if lv <= reached else Art.LEATHER_D
		var bot := Art.MOSS if lv + 1 <= reached or (lv == n and reached >= n) else Art.LEATHER_D
		_spine(ci, y, ROW * 0.5, top)
		_spine(ci, y + ROW * 0.5, ROW * 0.5, bot)
		var cur := lv == reached + 1
		var row: Dictionary = Data.PASS_LEVELS[i]
		_paint_card(ci, Rect2(LEFT_X, y + 8, CARD_W, ROW - 16), row["free"], G.pass_got(false, lv), reached < lv, cur, false, false, lv * 2)
		_paint_card(ci, Rect2(RIGHT_X, y + 8, CARD_W, ROW - 16), row["prem"], G.pass_got(true, lv), reached < lv, false, G.pass_tier < 1, true, lv * 2 + 1)
		var dcol := Art.LEATHER
		if lv <= reached:
			dcol = Art.OCHRE
		elif cur:
			dcol = Art.TEAL
		_diamond(ci, Vector2(MID_X, y + ROW * 0.5), 24, 28, dcol, 30 + lv)
		_center_text(ci, Vector2(MID_X, y + ROW * 0.5), str(lv), 24)
	var ey := float(n) * ROW
	_spine(ci, ey, ROW, Art.MOSS if reached >= n else Art.LEATHER_D)
	var ready := G.pass_endless_ready()
	var caught := G.pass_tier == 2 and G.pass_endless > 0 and ready == 0
	_paint_card(ci, Rect2(RIGHT_X, ey + 8, CARD_W, ROW - 16), [["chest_1", 1]], caught, ready <= 0, false, G.pass_tier != 2, true, 90)
	_diamond(ci, Vector2(MID_X, ey + ROW * 0.5), 40, 32, Art.OCHRE if reached >= n else Art.LEATHER, 91)
	_center_text(ci, Vector2(MID_X, ey + ROW * 0.5), "循环", 18)

static func _spine(ci: CanvasItem, y: float, h: float, col: Color) -> void:
	ci.draw_rect(Rect2(MID_X - 8, y, 16, h), Art.INK)
	ci.draw_rect(Rect2(MID_X - 5, y, 10, h), col)

static func _paint_card(ci: CanvasItem, rect: Rect2, rewards: Array, claimed: bool, dimmed: bool, teal: bool, locked: bool, cream: bool, seed: int) -> void:
	var b := Art.rrect(rect, 18, seed, 0.7)
	if teal:
		Art.dilate(ci, b, 8.0, Art.INK)
		Art.dilate(ci, b, 5.0, Art.TEAL)
	else:
		Art.dilate(ci, b, 3.0, Art.INK)
	ci.draw_colored_polygon(b, Art.BONE if cream else Color("e4d0aa"))
	_paint_rewards(ci, rect, rewards)
	if dimmed:
		ci.draw_colored_polygon(b, Color(0.16, 0.09, 0.04, 0.42))
	if claimed:
		Paint.check_mark(ci, Vector2(rect.end.x - 26, rect.end.y - 24), 1.15)
	if locked:
		Paint.glyph(ci, "lock", Vector2(rect.end.x - 26, rect.position.y + 26), 1.45)

static func _paint_rewards(ci: CanvasItem, rect: Rect2, rewards: Array) -> void:
	var n := rewards.size()
	var gap := 118.0 if n > 1 else 0.0
	var f := G.font_title
	var fs := 22 if n <= 1 else 18
	var icon_s := 80.0 if n <= 1 else 58.0
	for i in n:
		var text := "×%d" % int(rewards[i][1])
		var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pair := icon_s * 0.62 + 6.0 + tw
		var cx := rect.get_center().x + (float(i) - (n - 1) * 0.5) * gap
		var left := cx - pair * 0.5
		var cy := rect.get_center().y
		Art.item(ci, str(rewards[i][0]), Vector2(left + icon_s * 0.42, cy), icon_s)
		var baseline := cy + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5
		_outlined(ci, Vector2(left + icon_s * 0.72, baseline), text, fs, Color.WHITE, f)

static func _paint_ticket(ci: CanvasItem, sz: Vector2, vip: bool) -> void:
	var r := Rect2(2, 8, sz.x - 4, sz.y - 14)
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

static func _paint_hoard(ci: CanvasItem, sz: Vector2) -> void:
	ci.draw_colored_polygon(Art.ell(Vector2(sz.x * 0.5, sz.y * 0.78), Vector2(sz.x * 0.38, 28), 2, 0.05, 20), Color(0.45, 0.24, 0.08, 0.28))
	var spots := [Vector2(0.18, 0.60), Vector2(0.34, 0.70), Vector2(0.50, 0.74), Vector2(0.66, 0.70), Vector2(0.82, 0.60), Vector2(0.28, 0.50), Vector2(0.72, 0.48)]
	var ids := ["amber_2", "amber_3", "amber_2", "amber_3", "amber_2", "amber_3", "amber_2"]
	var scales := [62.0, 74.0, 66.0, 76.0, 60.0, 58.0, 64.0]
	for i in spots.size():
		Art.item(ci, ids[i], Vector2(spots[i].x * sz.x, spots[i].y * sz.y), scales[i])
	Art.item(ci, "chest_1", Vector2(sz.x * 0.5, sz.y * 0.40), 170)
	Art.item(ci, "amber_3", Vector2(sz.x * 0.30, sz.y * 0.84), 78)
	Art.item(ci, "amber_2", Vector2(sz.x * 0.50, sz.y * 0.88), 56)
	Art.item(ci, "amber_3", Vector2(sz.x * 0.70, sz.y * 0.84), 72)

static func _diamond(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, seed: int) -> void:
	var pts := Art.poly([c + Vector2(0, -ry), c + Vector2(rx, 0), c + Vector2(0, ry), c + Vector2(-rx, 0)], seed, 0.55)
	Art.dilate(ci, pts, 3.0, Art.INK)
	ci.draw_colored_polygon(pts, col)
	ci.draw_colored_polygon(Art.poly([c + Vector2(-rx * 0.28, -4), c + Vector2(0, -ry + 7), c + Vector2(rx * 0.28, -4)], seed + 2, 0.2), Color(1, 1, 1, 0.28))

static func _center_text(ci: CanvasItem, c: Vector2, text: String, fs: int) -> void:
	var f := G.font_title
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := Vector2(c.x - w * 0.5, c.y + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5)
	_outlined(ci, pos, text, fs, Color.WHITE, f)

static func _outlined(ci: CanvasItem, pos: Vector2, text: String, fs: int, col: Color, font: Font) -> void:
	ci.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Art.INK)
	ci.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
