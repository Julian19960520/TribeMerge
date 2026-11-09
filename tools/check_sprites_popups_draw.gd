extends RefCounted
## 弹窗界面图对照：左半边现场画（原始画法），右半边贴预生成的图。
const PS := preload("res://scripts/sprites/popups.gd")

static func paint(ci: CanvasItem, sz: Vector2) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, sz), Color("f3e6cc"))
	ci.draw_rect(Rect2(720, 0, 720, sz.y), Color("e9dcc0"))
	for side in 2:
		var live := side == 0
		var o := Vector2(side * 720, 0)
		_part(ci, o, live)

static func _at(ci: CanvasItem, o: Vector2, fn: Callable) -> void:
	ci.draw_set_transform(o)
	fn.call()
	ci.draw_set_transform(Vector2.ZERO)

static func _part(ci: CanvasItem, o: Vector2, live: bool) -> void:
	# 每日特惠卡（底 + 染色身子 + 内底 + 小签）
	_at(ci, o + Vector2(20, 30), func():
		var sz := Vector2(124, 236)
		var full := Rect2(Vector2.ZERO, sz)
		var col := Color("8a5bb8")
		var t := Rect2(sz.x * 0.5 - 32, -13, 64, 28)
		if live:
			PS.live_card_base(ci, full, 18, 0.8, 105)
			ci.draw_colored_polygon(Art.rrect(full, 18, 105, 0.8), col)
			ci.draw_colored_polygon(Art.rrect(Rect2(7, 7, sz.x - 14, 122), 14, 310, 0.6), Art.BONE)
			ci.draw_colored_polygon(Art.ell(Vector2(sz.x * 0.5, 110), Vector2(32, 6), 115, 0.0, 14), Color(0, 0, 0, 0.1))
			Art.dilate(ci, Art.rrect(t, 12, 120, 0.4), 2.5, Art.INK)
			ci.draw_colored_polygon(Art.rrect(t, 12, 120, 0.4), Color("e0cdf5"))
		else:
			Sprites.draw(ci, "pop_card18_base", full)
			Sprites.draw(ci, "pop_card18_fill", full, col)
			Sprites.draw(ci, "pop_inner14", Rect2(7, 7, sz.x - 14, 122), Art.BONE)
			Sprites.at(ci, "pop_spot_shadow", Vector2(sz.x * 0.5, 110), 1.0, 0.0, Color(0, 0, 0, 0.1))
			Sprites.draw(ci, "pop_tag_base", t)
			Sprites.draw(ci, "pop_tag_fill", t, Color("e0cdf5"))
		Art.item(ci, "fire_2", Vector2(sz.x * 0.5, 72), 86))
	# 集市卡 + 印章
	_at(ci, o + Vector2(170, 30), func():
		var sz := Vector2(208, 250)
		var full := Rect2(Vector2.ZERO, sz)
		if live:
			PS.live_card_base(ci, full, 20, 1.0, 300)
			ci.draw_colored_polygon(Art.rrect(full, 20, 300, 1.0), Art.OCHRE)
			ci.draw_colored_polygon(Art.rrect(Rect2(10, 10, sz.x - 20, sz.y - 86), 14, 310, 0.6), Art.BONE)
			Art.fill(ci, Art.star_pts(Vector2(30, 24), 38, 32, 12, 5), Art.CLAY, 3.0)
		else:
			Sprites.draw(ci, "pop_card20_base", full)
			Sprites.draw(ci, "pop_card20_fill", full, Art.OCHRE)
			Sprites.draw(ci, "pop_inner14", Rect2(10, 10, sz.x - 20, sz.y - 86), Art.BONE)
			Sprites.at(ci, "pop_seal", Vector2(30, 24), 38.0 / 36.0))
	# 刷新条
	_at(ci, o + Vector2(20, 310), func():
		var sz := Vector2(660, 66)
		var full := Rect2(Vector2.ZERO, sz)
		if live:
			PS.live_card_base(ci, full, 18, 0.8, 105)
			ci.draw_colored_polygon(Art.rrect(full, 18, 105, 0.8), Color("6c492e"))
			ci.draw_colored_polygon(Art.rrect(Rect2(6, 5, sz.x - 12, sz.y * 0.4), 12, 126, 0.3), Color(1, 1, 1, 0.08))
		else:
			Sprites.draw(ci, "pop_card18_base", full)
			Sprites.draw(ci, "pop_card18_fill", full, Color("6c492e"))
			Sprites.draw(ci, "pop_bar_hl", Rect2(6, 5, sz.x - 12, sz.y * 0.4), Color(1, 1, 1, 0.08)))
	# 分节标题
	_at(ci, o + Vector2(400, 40), func():
		var col := Color("8a5a30")
		if live:
			Art.ln(ci, Vector2(26, 20), Vector2(100, 20), 2.0, Color(col, 0.5), 1)
			ci.draw_colored_polygon(Art.star_pts(Vector2(110, 20), 6, 2.5, 4, 3), Color(col, 0.6))
		else:
			Sprites.draw(ci, "pop_sec_line", Rect2(26, 17, 74, 6), Color(col, 0.5))
			Sprites.at(ci, "pop_sec_star", Vector2(110, 20), 1.0, 0.0, Color(col, 0.6)))
	# 格子、建造卡、页签、小箭头、胶囊
	_at(ci, o + Vector2(400, 90), func():
		var r := Rect2(0, 0, 104, 104)
		var bc := Rect2(120, 0, 172, 160)
		if live:
			var b := Art.rrect(r, 16, 150, 0.6)
			ci.draw_colored_polygon(b, Color("ecd9b3"))
			Art.outline(ci, b, 2.0, Color(0.6, 0.4, 0.2, 0.35))
			PS.live_build_card_on(ci, bc)
			ci.draw_colored_polygon(Art.poly([Vector2(107, 45), Vector2(118, 52), Vector2(107, 59)], 1), Color(0.75, 0.6, 0.4, 0.8))
			ci.draw_colored_polygon(Art.rrect(Rect2(0, 180, 280, 40), 20, 131, 0.6), Color(0.6, 0.45, 0.25, 0.25))
		else:
			Sprites.draw(ci, "pop_slot16_fill", r, Color("ecd9b3"))
			Sprites.draw(ci, "pop_slot16_line", r, Color(0.6, 0.4, 0.2, 0.35))
			Sprites.draw(ci, "pop_bcard_on", bc)
			Sprites.draw(ci, "pop_info_arrow", Rect2(107, 45, 11, 14))
			Sprites.draw(ci, "pop_pill20", Rect2(0, 180, 280, 40), Color(0.6, 0.45, 0.25, 0.25)))
	_at(ci, o + Vector2(20, 400), func():
		for k in 2:
			var tr := Rect2(k * 120, 3, 102, 82)
			if live: PS.live_book_tab(ci, tr, k == 0)
			else: Sprites.draw(ci, "pop_booktab_on" if k == 0 else "pop_booktab_off", tr))
	# 领奖：光芒、台座、星点、数量胶囊
	# Sprites.at 带旋转时会把变换清零，这一组直接用绝对坐标
	var q := o + Vector2(300, 400)
	var rc := q + Vector2(80, 80)
	var rr := 78.0
	if live:
		ci.draw_colored_polygon(Art.star_pts(rc, rr * 0.98, rr * 0.62, 8, 40, 0.3), Color(1, 0.6, 0.2, 0.5))
		PS.live_rw_plate(ci, rc + Vector2(0, rr * 0.66), rr)
		ci.draw_colored_polygon(Art.star_pts(q + Vector2(200, 30), 6 * 2.2, 6 * 0.6, 4, 1), Color(1, 0.6, 0.2))
		PS.live_rw_badge(ci, Rect2(q + Vector2(180, 100), Vector2(100, 36)))
	else:
		Sprites.at(ci, "pop_rw_burst", rc, rr / PS.RW_R, 0.3, Color(1, 0.6, 0.2, 0.5))
		Sprites.at(ci, "pop_rw_plate", rc + Vector2(0, rr * 0.66), rr / PS.RW_R)
		Sprites.at(ci, "pop_sparkle", q + Vector2(200, 30), 6.0 / PS.SPARK_R, 0.0, Color(1, 0.6, 0.2))
		Sprites.draw(ci, "pop_rw_badge", Rect2(q + Vector2(180, 100), Vector2(100, 36)))
	# 引导框、输入框、选择格
	_at(ci, o + Vector2(20, 580), func():
		var h := Rect2(10, 10, 100, 100).grow(7)
		var f := Rect2(140, 10, 260, 56)
		if live:
			PS.live_guide_frame(ci, h)
			PS.live_field(ci, f)
			PS.live_choice(ci, Rect2(420, 6, 100, 94), true)
			PS.live_choice(ci, Rect2(540, 6, 100, 94), false)
		else:
			Sprites.draw(ci, "pop_guide_frame", h)
			Sprites.draw(ci, "pop_field", f)
			Sprites.draw(ci, "pop_choice_on", Rect2(420, 6, 100, 94))
			Sprites.draw(ci, "pop_choice_off", Rect2(540, 6, 100, 94)))
	# 储物洞格子
	_at(ci, o + Vector2(20, 720), func():
		var keys := ["pop_inv_niche", "pop_inv_next", "pop_inv_rocks"]
		for k in 3:
			ci.draw_set_transform(o + Vector2(20 + k * 120, 720))
			if live:
				match k:
					0: PS.live_inv_niche(ci, PS.INV_SLOT)
					1: PS.live_inv_next(ci, PS.INV_SLOT)
					2: PS.live_inv_rocks(ci)
			else:
				Sprites.draw(ci, keys[k], PS.INV_SLOT)
		ci.draw_set_transform(o + Vector2(20, 840))
		if live: PS.live_inv_shelf(ci, Vector2(620, 126))
		else: Sprites.draw(ci, "pop_inv_shelf", PS.INV_SHELF))
	# 自选宝箱卡（选中）、丰收祭卡册圈 + 飘带、广告进度条
	_at(ci, o + Vector2(20, 1010), func():
		if live: PS.live_cc_card(ci, PS.CC_CARD.size, true, false, 0)
		else: Sprites.draw(ci, "pop_cc_card_on", PS.CC_CARD))
	_at(ci, o + Vector2(230, 1000), func():
		var c := Vector2(110, 110)
		if live:
			PS.live_album_ring(ci, c)
			ci.draw_colored_polygon(Art.ell(c, Vector2(88, 88), 210, 0.0, 32), Paint.ALBUM_COL[1])
			Art.dilate(ci, PS._ribbon(), 3.0, Art.INK)
			ci.draw_colored_polygon(PS._ribbon(), Art.MOSS)
		else:
			Sprites.at(ci, "pop_album_ring", c)
			Sprites.at(ci, "pop_album_disc", c, 1.0, 0.0, Paint.ALBUM_COL[1])
			Sprites.draw(ci, "pop_ribbon_base", PS.RIBBON)
			Sprites.draw(ci, "pop_ribbon_fill", PS.RIBBON, Art.MOSS))
	_at(ci, o + Vector2(470, 1010), func():
		if live:
			PS.live_ad_track(ci, Rect2(0, 0, 220, 26))
		else:
			Sprites.draw(ci, "pop_ad_track", Rect2(0, 0, 220, 26)))
	_at(ci, o + Vector2(380, 1300), func():
		if live: PS.live_ad_reward(ci, PS.AD_REWARD.size)
		else: Sprites.draw(ci, "pop_ad_reward", PS.AD_REWARD))
	# 玩法说明手 + 箭头（区域图，按原坐标平移过来）
	_at(ci, o + Vector2(-220, 470), func():
		if live:
			PS.live_howto_hand(ci)
			var a: Array = PS.HOWTO_ARROWS[2]
			PS.live_arrow(ci, a[0], a[1], a[2])
		else:
			Sprites.draw(ci, "pop_howto_hand", PS.HOWTO_HAND)
			var a: Array = PS.HOWTO_ARROWS[2]
			Sprites.draw(ci, "pop_howto_arrow2", PS.arrow_rect(a[0], a[1], a[2])))
