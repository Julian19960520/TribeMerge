class_name HomeScreen
extends Control

var _spots_root: Control
var _event_lbl: Label
var go: TButton
var _cards_btn: TButton
var _go_ix := -1
var _go_tw: Tween
var _go_n := 0
var _go_q: Array[Callable] = []
## 0 原位，1 滑入，2 到位，3 等滑出，4 滑出
var _go_phase := 0
var _village: DrawBox
## {区域 id: 部件下标}：正在播建造动画的那件，村庄层先不画
var _hide := {}
var _build_fx: Control
const PASS_K := 0.8
const RankPopupScript := preload("res://scripts/ui/RankPopup.gd")
const TribeWalkersScript := preload("res://scripts/ui/TribeWalkers.gd")
const CARD_YELLOW := Color("e7b45a")
const CARD_YELLOW_L := Color("f2c66e")

func _ready() -> void:
	size = Vector2(720, 1480)
	mouse_filter = MOUSE_FILTER_IGNORE
	_village = UI.box(self, Rect2(0, 0, 720, 1480), func(ci, sz): Paint.village(ci, sz, G.builds, G.level, _hide))
	# 「兄弟，我发现」小人在村里溜达（在牌子和按钮下面，只在小人身上接点击）
	var walkers := TribeWalkersScript.new()
	add_child(walkers)
	_spots_root = Control.new()
	_spots_root.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_spots_root)
	_build_spots()

	# 左上两张小卡：通行证、每日特惠（同一套黄色卡片）
	var ev := UI.hit(self, Rect2(14, 148, 100, 124), func(): G.main.open("pass"))
	ev.extra = func(ci, sz):
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * PASS_K)
		_paint_pass(ci, sz / PASS_K)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	UI.lbl(ev, "通行证", Rect2(0, 74, 100, 24), 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 5, Art.INK, true)
	_event_lbl = UI.lbl(ev, "", Rect2(24, 98, 72, 20), 13, Color("ffe7a8"), HORIZONTAL_ALIGNMENT_CENTER, 4, Art.INK)

	var deal := UI.hit(self, Rect2(14, 280, 100, 104), func(): G.main.open("store"))
	deal.extra = func(ci, sz):
		var r := Rect2(8, 3, sz.x - 16, 74)
		ci.draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(0, 4), r.size), 14, 92, 0.0), Color(0, 0, 0, 0.28))
		var b := Art.rrect(r, 14, 92, 0.9)
		Art.dilate(ci, b, 2.6, Art.INK)
		ci.draw_colored_polygon(b, CARD_YELLOW)
		ci.draw_colored_polygon(Art.rrect(r.grow(-5), 10, 93, 0.5), CARD_YELLOW_L)
		ci.draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(8, 6), Vector2(r.size.x - 16, 10)), 5, 94, 0.3), Color(1, 1, 1, 0.22))
		Art.item(ci, "chest_1", Vector2(sz.x * 0.5, 42), 70)
	UI.lbl(deal, "每日特惠", Rect2(0, 74, 100, 24), 17, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 5, Art.INK, true)
	# 礼包链（法币直购活动）：左边一列，每日特惠下面
	add_child(preload("res://scripts/ui/GiftChainCard.gd").new())

	var gear := UI.btn(self, Rect2(626, 150, 80, 80), "", "teal", func(): G.main.open("settings"))
	gear.is_round = true
	gear.glyph = "gear"

	# 排行榜：齿轮下面一枚奖杯
	var rank := UI.btn(self, Rect2(626, 246, 80, 80), "", "teal", func(): RankPopupScript.open())
	rank.is_round = true
	rank.extra = func(ci, sz): _paint_trophy(ci, sz * 0.5)
	UI.lbl(self, "排行", Rect2(616, 322, 100, 30), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK, true)

	var build := UI.btn(self, Rect2(16, 1316, 124, 128), "", "wood", _open_next_build)
	build.extra = func(ci, sz): Paint.hammer(ci, sz * 0.5 + Vector2(0, -6), 1.1)
	UI.lbl(build, "建造", Rect2(0, 86, 124, 34), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK)
	var bk := UI.btn(self, Rect2(150, 1330, 110, 112), "", "hide", func(): G.main.open("book"))
	bk.extra = func(ci, sz):
		Paint.book(ci, sz * 0.5 + Vector2(0, -10), 0.9)
		if G.book_prize_count() > 0:
			Paint.badge_num(ci, Vector2(sz.x - 18, 16), 4)
	UI.lbl(bk, "图鉴", Rect2(0, 72, 110, 34), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK)
	var cd := UI.btn(self, Rect2(270, 1330, 110, 112), "", "hide", func(): G.main.open("event"))
	cd.extra = func(ci, sz): Paint.cards_icon(ci, sz * 0.5 + Vector2(0, -10), 0.85)
	UI.lbl(cd, "卡册", Rect2(0, 72, 110, 34), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK)
	cd.visible = G.level >= Data.CARD_LEVEL
	_cards_btn = cd
	go = UI.btn(self, Rect2(398, 1310, 306, 136), "去合成", "green", func(): G.main.show_screen("board"), 54)
	_go_ix = go.get_index()
	go.extra = func(ci, sz):
		Art.item(ci, "fruit_2", Vector2(sz.x - 34, 20), 56)
		Art.item(ci, "roast_7", Vector2(30, sz.y - 22), 50)

	G.changed.connect(_build_spots)

## 排行榜按钮上的石杯奖杯
func _paint_trophy(ci: CanvasItem, c: Vector2) -> void:
	var cup := Art.poly([c + Vector2(-17, -18), c + Vector2(17, -18), c + Vector2(14, -2), c + Vector2(6, 6), c + Vector2(-6, 6), c + Vector2(-14, -2)], 61, 0.4)
	for sx in [-1.0, 1.0]:
		var ear := Art.ell(c + Vector2(19 * sx, -10), Vector2(7, 7), 62 + int(sx), 0.02, 12)
		Art.dilate(ci, ear, 2.4, Art.INK)
		ci.draw_colored_polygon(ear, Art.AMBER)
	var stem := Art.poly([c + Vector2(-4, 5), c + Vector2(4, 5), c + Vector2(5, 13), c + Vector2(-5, 13)], 63, 0.2)
	var base := Art.rrect(Rect2(c + Vector2(-14, 12), Vector2(28, 9)), 3, 64, 0.3)
	for part in [stem, base]:
		Art.dilate(ci, part, 2.4, Art.INK)
		ci.draw_colored_polygon(part, Art.WOOD)
	Art.dilate(ci, cup, 2.6, Art.INK)
	ci.draw_colored_polygon(cup, Art.FIRE2)
	ci.draw_colored_polygon(Art.poly([c + Vector2(-12, -15), c + Vector2(-5, -15), c + Vector2(-8, -3)], 65, 0.2), Color(1, 1, 1, 0.45))

## 通行证按钮：青色兽皮卡上一枚琥珀勋章（带当前等级）、两条飘带，底部是到下一级的进度；买了通行证换金边。
func _paint_pass(ci: CanvasItem, sz: Vector2) -> void:
	var prem := G.pass_tier > 0
	var card := Rect2(10, 4, sz.x - 20, 92)
	var body := Art.rrect(card, 18, 91, 0.9)
	ci.draw_colored_polygon(Art.rrect(Rect2(card.position + Vector2(0, 5), card.size), 18, 91, 0.0), Color(0, 0, 0, 0.28))
	if prem:
		Art.dilate(ci, body, 7.0, Art.INK)
		Art.dilate(ci, body, 4.4, Art.CLAY)
		Art.dilate(ci, body, 1.4, Art.INK)
	else:
		Art.dilate(ci, body, 3.2, Art.INK)
	ci.draw_colored_polygon(body, CARD_YELLOW)
	var inner := Art.rrect(card.grow(-6), 13, 92, 0.6)
	ci.draw_colored_polygon(inner, CARD_YELLOW_L)
	ci.draw_colored_polygon(Art.rrect(Rect2(card.position + Vector2(10, 8), Vector2(card.size.x - 20, 14)), 7, 93, 0.3), Color(1, 1, 1, 0.16))
	# 兽皮缝线
	Art.dashed(ci, Art.rrect(card.grow(-11), 9, 94, 0.0), 6, 5, Color(0.55, 0.32, 0.1, 0.45), 1.8)
	# 飘带
	var mc := Vector2(sz.x * 0.5, 38)
	for sx in [-1.0, 1.0]:
		var rib := Art.poly([mc + Vector2(8 * sx, 8), mc + Vector2(30 * sx, 14), mc + Vector2(40 * sx, 30), mc + Vector2(30 * sx, 28), mc + Vector2(28 * sx, 38), mc + Vector2(12 * sx, 22)], 95 + int(sx), 0.5)
		Art.dilate(ci, rib, 2.4, Art.INK)
		ci.draw_colored_polygon(rib, Art.TEAL)
		ci.draw_colored_polygon(Art.poly([mc + Vector2(14 * sx, 11), mc + Vector2(28 * sx, 16), mc + Vector2(34 * sx, 24), mc + Vector2(18 * sx, 18)], 97 + int(sx), 0.3), Color(1, 1, 1, 0.2))
	# 勋章：齿边琥珀 + 骨白内圈
	var outer := Art.star_pts(mc, 31, 26, 12, 98, -PI * 0.5)
	Art.dilate(ci, outer, 2.8, Art.INK)
	ci.draw_colored_polygon(outer, Art.BONE)
	var disc := Art.ell(mc, Vector2(20, 20), 99, 0.02, 18)
	Art.dilate(ci, disc, 2.2, Art.INK)
	ci.draw_colored_polygon(disc, Art.CLAY if prem else Art.AMBER)
	ci.draw_colored_polygon(Art.ell(mc + Vector2(-6, -7), Vector2(7, 4), 100, 0.0, 10, -0.5, 0.3), Color(1, 1, 1, 0.45))
	var f := G.font_title
	var lv := str(maxi(G.pass_reached(), 0) + 1)
	var fs := 24 if lv.length() < 2 else 20
	var tw := f.get_string_size(lv, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var tp := Vector2(mc.x - tw * 0.5, mc.y + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5)
	ci.draw_string_outline(f, tp, lv, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Art.INK)
	ci.draw_string(f, tp, lv, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	# 到下一级的进度
	var bar := Rect2(card.position.x + 12, card.end.y - 20, card.size.x - 24, 11)
	var bb := Art.rrect(bar, 5.5, 101, 0.2)
	Art.dilate(ci, bb, 2.0, Art.INK)
	ci.draw_colored_polygon(bb, Color(0.3, 0.17, 0.06, 0.85))
	var fr := G.pass_frac()
	if fr > 0.0:
		ci.draw_colored_polygon(Art.rrect(Rect2(bar.position, Vector2(maxf(11.0, bar.size.x * fr), bar.size.y)), 5.5, 102, 0.2), Art.MOSS)
		ci.draw_colored_polygon(Art.rrect(Rect2(bar.position + Vector2(3, 2), Vector2(maxf(5.0, bar.size.x * fr - 6.0), 3)), 1.5, 103, 0.0), Color(1, 1, 1, 0.35))
	# 剩余时间小牌
	var pill := Art.rrect(Rect2(14, 123, sz.x - 28, 22), 11, 104, 0.4)
	ci.draw_colored_polygon(pill, Color(0.17, 0.09, 0.03, 0.72))
	Paint.glyph(ci, "clock", Vector2(24, 134), 0.55, Color("ffe7a8"))
	if G.pass_claimable():
		var c := Vector2(sz.x - 14, 8)
		var bounce := absf(sin(float(Time.get_ticks_msec()) / 260.0)) * 4.0
		c.y -= bounce
		Paint.badge_num(ci, c, 9)
		var w := f.get_string_size("!", HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		var pos := Vector2(c.x - w * 0.5, c.y + (f.get_ascent(20) - f.get_descent(20)) * 0.5)
		ci.draw_string_outline(f, pos, "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 4, Art.INK)
		ci.draw_string(f, pos, "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)

func _process(_d: float) -> void:
	if _event_lbl and Engine.get_process_frames() % 30 == 0:
		_event_lbl.text = G.fmt_time(G.event_left())

func _build_spots() -> void:
	if _cards_btn != null:
		_cards_btn.visible = G.level >= Data.CARD_LEVEL
	for c in _spots_root.get_children():
		c.queue_free()
	for b in Data.BUILDS:
		var id: String = b["id"]
		var tag := UI.hit(_spots_root, Rect2(TribeArt.tag_at(id) - Vector2(74, 26), Vector2(148, 52)), _open_build.bind(id))
		tag.extra = func(ci, sz): _paint_tag(ci, sz, id)
	for c in get_children():
		if c is DrawBox:
			c.queue_redraw()

## 区域木牌：名字 + 进度条；未开放显示等级；钱够下一件时右上角亮红点
func _paint_tag(ci: CanvasItem, sz: Vector2, id: String) -> void:
	var b := Data.build_def(id)
	var total := Data.build_stages(b)
	var st := clampi(int(G.builds.get(id, 0)), 0, total)
	var open := G.build_open(id)
	var done := st >= total
	var seed := absi(id.hash()) % 90
	var r := Rect2(6, 6, sz.x - 12, sz.y - 12)
	var plank := Art.rrect(r, 10, seed, 0.8)
	Art.dilate(ci, plank, 3.0, Art.INK)
	ci.draw_colored_polygon(plank, Art.WOOD if open else Color("8c8476"))
	ci.draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(5, 3), Vector2(r.size.x - 10, 6)), 3, seed + 1, 0.3), Color(1, 1, 1, 0.22))
	var ic := Vector2(28, sz.y * 0.5)
	if not open:
		Paint.glyph(ci, "lock", ic, 0.9)
	elif done:
		Paint.check_mark(ci, ic, 0.8)
	else:
		Paint.hammer(ci, ic, 0.36)
	var f := G.font_title
	var fs := 20
	var name := str(b.get("name", id))
	var tp := Vector2(48, 26)
	ci.draw_string_outline(f, tp, name, HORIZONTAL_ALIGNMENT_LEFT, sz.x - 56, fs, 5, Art.INK)
	ci.draw_string(f, tp, name, HORIZONTAL_ALIGNMENT_LEFT, sz.x - 56, fs, Color.WHITE)
	if open:
		var bar := Rect2(48, 33, sz.x - 62, 9)
		ci.draw_colored_polygon(Art.rrect(bar, 4.5, seed + 2, 0.2), Color(0.2, 0.1, 0.03, 0.55))
		if st > 0:
			var fill := Rect2(bar.position, Vector2(maxf(9.0, bar.size.x * float(st) / float(maxi(total, 1))), bar.size.y))
			ci.draw_colored_polygon(Art.rrect(fill, 4.5, seed + 3, 0.2), Art.MOSS if not done else Art.OCHRE)
	else:
		var t := "Lv.%d 开放" % Data.build_unlock(b)
		ci.draw_string_outline(G.font_body, Vector2(48, 44), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Art.INK)
		ci.draw_string(G.font_body, Vector2(48, 44), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("ffe7a8"))
	if open and not done and G.shells >= G.build_cost(id):
		var c := Vector2(sz.x - 8, 6)
		Paint.badge_num(ci, c, seed + 4)
		var bf := G.font_title
		var w := bf.get_string_size("!", HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		var pos := Vector2(c.x - w * 0.5, c.y + (bf.get_ascent(20) - bf.get_descent(20)) * 0.5)
		ci.draw_string_outline(bf, pos, "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 4, Art.INK)
		ci.draw_string(bf, pos, "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)

func _open_build(id: String) -> void:
	if is_building():
		return
	G.main.open("build", id)

func _open_next_build() -> void:
	if is_building():
		return
	var id := G.next_build_id()
	if id == "":
		var all_done := true
		for b in Data.BUILDS:
			if int(G.builds.get(str(b["id"]), 0)) < Data.build_stages(b):
				all_done = false
		G.main.toast("部落已经全部建好啦！" if all_done else "升级主角等级，开放新的建造区域")
		return
	G.main.open("build", id)

# ---------------------------------------------------------------- 建造动画

func is_building() -> bool:
	return _build_fx != null and is_instance_valid(_build_fx)

## 部件从地基里敲出来：锤子敲三下扬起尘土 → 部件弹起落地 → 星星散开 → 领奖
func play_build(area: String, idx: int, kind: String, part_name: String, rewards: Array) -> void:
	if is_building():
		_build_fx.queue_free()
	_hide = {area: idx}
	_village.queue_redraw()
	var at := TribeArt.part_at(area, idx)
	var h := float(TribeArt._HEIGHT.get(kind, 80)) * TribeArt.VS
	var fx := Control.new()
	fx.size = size
	fx.mouse_filter = MOUSE_FILTER_STOP
	add_child(fx)
	_build_fx = fx
	var st := {"t": 0.0, "hits": 0, "popped": false}
	var dur := 2.3
	var box := UI.box(fx, Rect2(Vector2.ZERO, size), func(ci, _sz): _paint_build(ci, at, kind, h, float(st["t"])), false)
	var lbl := UI.lbl(fx, "%s 建成！" % part_name, Rect2(at.x - 200, at.y - h - 70, 400, 50), 32, Color("fff1c4"), HORIZONTAL_ALIGNMENT_CENTER, 10, Art.INK, true)
	lbl.position.x = clampf(lbl.position.x, -60.0, size.x - 340.0)
	lbl.modulate.a = 0.0
	lbl.pivot_offset = lbl.size * 0.5
	var tw := fx.create_tween()
	tw.tween_method(func(t: float):
		st["t"] = t
		var due := 0 if t < 0.12 else mini(3, int((t - 0.12) / 0.3) + 1)
		while int(st["hits"]) < due:
			st["hits"] = int(st["hits"]) + 1
			Sfx.play("tap", 0.8 + 0.15 * float(st["hits"]))
			if int(st["hits"]) == 1:
				Sfx.play("crumble")
		if t >= 1.05 and not bool(st["popped"]):
			st["popped"] = true
			Sfx.play("pop")
			Sfx.play("merge", 1.1)
			lbl.scale = Vector2(0.6, 0.6)
			var lt := lbl.create_tween().set_parallel(true)
			lt.tween_property(lbl, "modulate:a", 1.0, 0.18)
			lt.tween_property(lbl, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			lt.tween_property(lbl, "position:y", lbl.position.y - 26.0, 1.0)
		box.queue_redraw()
	, 0.0, dur, dur)
	tw.tween_callback(func():
		_hide = {}
		_village.queue_redraw()
		_build_spots()
		fx.queue_free()
		_build_fx = null
		if not rewards.is_empty():
			G.main.present_rewards(rewards))

func _paint_build(ci: CanvasItem, at: Vector2, kind: String, h: float, t: float) -> void:
	var glow_a := clampf(t / 0.2, 0.0, 1.0) * (1.0 - clampf((t - 1.8) / 0.5, 0.0, 1.0))
	ci.draw_colored_polygon(Art.ell(at, Vector2(70, 26), 3, 0.0, 24, 0.0, 0.0), Color(1, 0.9, 0.5, 0.35 * glow_a))
	if t < 1.05:
		# 施工中：半透明剪影一点点长高，锤子敲三下
		var grow := clampf(t / 1.0, 0.0, 1.0)
		TribeArt.flat = Color(1, 0.97, 0.88, 0.4 + 0.15 * sin(t * 30.0))
		TribeArt.part(ci, kind, at, TribeArt.VS, Vector2(1.0, 0.15 + 0.55 * grow))
		TribeArt.flat = Color(0, 0, 0, 0)
		var dash := Art.ell(at, Vector2(36, 13), 5, 0.0, 18, 0.0, 0.0)
		Art.dashed(ci, dash, 7, 6, Color(1, 1, 1, 0.9), 2.5)
		var swing := -1.2
		if t >= 0.12:
			var ph := fmod(t - 0.12, 0.3) / 0.3
			swing = -1.2 + 1.6 * pow(ph, 2.2) if ph < 0.75 else 0.4 - 1.6 * (ph - 0.75) / 0.25
		_hammer_at(ci, at + Vector2(54, -h * 0.4 - 24), -swing)
	else:
		# 弹出来：先拉高再压扁再回正
		var u := clampf((t - 1.05) / 0.5, 0.0, 1.0)
		var sy := 1.0 + sin(u * PI * 2.2) * 0.22 * (1.0 - u)
		var sx := 1.0 - (sy - 1.0) * 0.6
		if u < 0.16:
			sy = lerpf(0.5, 1.22, u / 0.16)
			sx = lerpf(1.2, 0.88, u / 0.16)
		TribeArt.part(ci, kind, at, TribeArt.VS, Vector2(sx, sy))
	for k in 3:
		_dust(ci, at, t - (0.12 + 0.3 * float(k) + 0.22), 4, k * 11)
	_dust(ci, at, t - 1.05, 8, 50)
	if t > 1.05:
		var u := clampf((t - 1.05) / 1.0, 0.0, 1.0)
		var c := at + Vector2(0, -h * 0.5)
		var ring := Art.ell(c, Vector2(1, 1) * (30.0 + u * 120.0), 7, 0.0, 28, 0.0, 0.0)
		Art.outline(ci, ring, 5.0 * (1.0 - u) + 0.5, Color(1, 0.95, 0.7, 0.8 * (1.0 - u)))
		for k in 10:
			var a := TAU * float(k) / 10.0 + 0.3
			var d := 30.0 + u * (90.0 + Art.srnd(k) * 50.0)
			var p := c + Vector2(cos(a), sin(a) * 0.8) * d + Vector2(0, u * u * 40.0)
			var r := 9.0 * (1.0 - u * 0.7)
			ci.draw_colored_polygon(Art.star_pts(p, r, r * 0.42, 4, k), Color(1, 0.9 if k % 2 == 0 else 0.75, 0.4, 1.0 - u * u))

func _dust(ci: CanvasItem, at: Vector2, dt: float, n: int, seed: int) -> void:
	if dt < 0.0 or dt > 0.6:
		return
	var u := dt / 0.6
	for k in n:
		var a := PI + PI * (float(k) + 0.5) / float(n) + (Art.srnd(seed + k) - 0.5) * 0.4
		var p := at + Vector2(cos(a) * (20.0 + u * 60.0), sin(a) * (6.0 + u * 22.0) - u * 10.0 + 6.0)
		var r := 10.0 + u * 12.0 + Art.srnd(seed + k * 3) * 6.0
		ci.draw_colored_polygon(Art.ell(p, Vector2(r, r * 0.8), seed + k, 0.1, 12), Color(0.93, 0.85, 0.7, 0.75 * (1.0 - u)))

## 锤子：pivot 是握把末端，ang 为 0 时锤头朝左敲在地基上
func _hammer_at(ci: CanvasItem, pivot: Vector2, ang: float) -> void:
	ci.draw_set_transform(pivot, ang, Vector2.ONE * 0.9)
	Art.sil(ci, [Art.P(Art.capsule(Vector2(0, 0), Vector2(-46, 0), 5.0, 1), Art.WOOD, 1),
		Art.P(Art.rrect(Rect2(-62, -17, 24, 34), 7, 2, 0.4), Art.STONE, 1)])
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ---------------------------------------------------------------- 去合成

func present_go(then: Callable) -> void:
	if go == null or not then.is_valid():
		return
	# 已在顶层并停住（含离开倒计时）：取消倒计时，本批马上飞
	if _go_phase == 2 or _go_phase == 3:
		_stop_go_tw()
		_go_phase = 2
		then.call()
		return
	_go_q.append(then)
	if _go_phase == 1:
		return
	if _go_phase == 0:
		_lift_go()
	_slide_go_in()

func go_center() -> Vector2:
	return Vector2(398, 1310) + Vector2(306, 136) * 0.5

func arm_go(n: int) -> void:
	_go_n += n

func release_go() -> void:
	if _go_n <= 0:
		return
	_go_n -= 1
	if _go_n > 0 or not _go_q.is_empty() or _go_phase != 2:
		return
	_go_phase = 3
	_stop_go_tw()
	_go_tw = create_tween()
	_go_tw.tween_interval(0.35)
	_go_tw.tween_callback(_start_go_out)

func recall_go() -> void:
	if go == null:
		return
	_stop_go_tw()
	_go_q.clear()
	_dock_go()

func _lift_go() -> void:
	var fx: Control = G.main.fx_layer
	if go.get_parent() != fx:
		go.reparent(fx)
	fx.move_child(go, 0)
	go.position = Vector2(398, 1480)

func _slide_go_in() -> void:
	_stop_go_tw()
	_go_phase = 1
	go.position = Vector2(398, go.position.y)
	_go_tw = create_tween()
	_go_tw.tween_property(go, "position:y", 1310.0, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_go_tw.tween_callback(_on_go_in)

func _on_go_in() -> void:
	if _go_phase != 1:
		return
	_go_phase = 2
	while not _go_q.is_empty():
		var cb: Callable = _go_q.pop_front()
		cb.call()

func _start_go_out() -> void:
	if _go_n > 0 or not _go_q.is_empty() or _go_phase != 3:
		return
	_go_phase = 4
	_go_tw = create_tween()
	_go_tw.tween_property(go, "position:y", 1480.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_go_tw.tween_callback(_finish_go_out)

func _finish_go_out() -> void:
	if _go_phase != 4:
		return
	_dock_go()

func _dock_go() -> void:
	_go_phase = 0
	if go.get_parent() != self:
		go.reparent(self)
	var ix := _go_ix
	if ix < 0 or ix >= get_child_count():
		ix = get_child_count() - 1
	move_child(go, ix)
	go.position = Vector2(398, 1310)

func _stop_go_tw() -> void:
	if _go_tw != null and _go_tw.is_valid():
		_go_tw.kill()
	_go_tw = null
