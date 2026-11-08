extends RefCounted
const B := preload("res://scripts/sprites/board.gd")

static func _off(ci: CanvasItem, o: Vector2, fn: Callable) -> void:
	ci.draw_set_transform(o, 0.0, Vector2.ONE)
	fn.call()
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func paint(ci: CanvasItem, sz: Vector2) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, sz), Color("3f6e3a"))
	for side in 2:
		var o := Vector2(side * 750, 0)
		var live := side == 0
		# 场景（布帘 + 圆木），缩小到 0.5 看
		ci.draw_set_transform(o + Vector2(10, 10), 0.0, Vector2.ONE * 0.5)
		ci.draw_rect(Rect2(0, 0, 720, 430), Color("78c2c4"))
		if live:
			B.live_curtain(ci, 0, 720.0)
			B.live_curtain(ci, 1, 720.0)
			B.live_log(ci, 720.0)
		else:
			Sprites.draw(ci, "board_curtain_l", Rect2(0, 0, 90, 380))
			Sprites.draw(ci, "board_curtain_r", Rect2(630, 0, 90, 380))
			Sprites.draw(ci, "board_log", Rect2(-10, 372, 740, 50))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# 主角卡、升级卡、暂存区
		var p := o + Vector2(380, 10)
		if live: _off(ci, p, func(): B.live_hero_card(ci, Vector2(142, 226)))
		else: Sprites.draw(ci, "board_hero_card", Rect2(p, Vector2(142, 226)))
		p = o + Vector2(530, 10)
		if live: _off(ci, p, func(): B.live_hammer_card(ci, Vector2(130, 226)))
		else: Sprites.draw(ci, "board_hammer_card", Rect2(p, Vector2(130, 226)))
		p = o + Vector2(10, 250)
		if live:
			_off(ci, p, func():
				B.live_stash_tray(ci, Vector2(118, 226))
				B.live_stash_card(ci, Rect2(Vector2(21, 35), Vector2(82, 124)), 44, false)
				B.live_stash_card(ci, Rect2(Vector2(16, 44), Vector2(82, 124)), 43, true)
				B.live_stash_arrow(ci, Rect2(43, 196, 32, 22)))
		else:
			Sprites.draw(ci, "board_stash_tray", Rect2(p + Vector2(6, 26), Vector2(106, 192)))
			Sprites.at(ci, "board_stash_card", p + Rect2(Vector2(21, 35), Vector2(82, 124)).get_center(), 1.0, 0.0)
			Sprites.at(ci, "board_stash_card_top", p + Rect2(Vector2(16, 44), Vector2(82, 124)).get_center(), 1.0, 0.0)
			Sprites.draw(ci, "board_stash_arrow", Rect2(p + Vector2(43, 196), Vector2(32, 22)))
		# 信息栏
		p = o + Vector2(140, 250)
		if live: _off(ci, p, func(): B.live_info_panel(ci, Vector2(456, 170)); B.live_info_tag(ci))
		else:
			Sprites.draw(ci, "board_info_panel", Rect2(p, Vector2(456, 170)))
			Sprites.draw(ci, "board_info_tag", Rect2(p + Vector2(26, 4), Vector2(304, 40)))
		# 订单卡两种宽度
		var x := 10.0
		for w in [160.0, 300.0]:
			var r := Rect2(o + Vector2(x + 4, 450 + 20), Vector2(w - 8, 192))
			var bg := Color("eaf6c8") if w > 200 else Color("fbf0d6")
			if live:
				B.live_order_card(ci, r, 0, bg)
				B.live_head(ci, o + Vector2(x + 46, 488), 62, w > 200)
				B.live_hint_plate(ci, o + Vector2(x + 60, 580), 58, 0, false)
				B.live_aim_arrow(ci, o + Vector2(x + w - 90, 600), o + Vector2(x + w - 50, 560))
				ci.draw_colored_polygon(Art.rrect(Rect2(o + Vector2(x + 20, 640), Vector2(70, 28)), 14, 65, 0.4), Color(0.55, 0.35, 0.15, 0.18))
			else:
				Sprites.draw(ci, "board_card_base", r)
				Sprites.draw(ci, "board_card_fill", r, bg)
				Sprites.draw(ci, "board_card_dash", r)
				Sprites.at(ci, "board_head_story" if w > 200 else "board_head_npc", o + Vector2(x + 46, 488))
				Sprites.draw(ci, "board_plate", Rect2(o + Vector2(x + 31, 551), Vector2(58, 58)))
				var a := o + Vector2(x + w - 90, 600)
				var tip := o + Vector2(x + w - 50, 560)
				ci.draw_set_transform(a, (tip - a).angle(), Vector2.ONE)
				Sprites.draw(ci, "board_aim_arrow", Rect2(0, -8, (tip - a).length(), 16))
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				Sprites.draw(ci, "board_chip", Rect2(o + Vector2(x + 20, 640), Vector2(70, 28)))
			x += w + 10
		# 泡泡购买卡
		var card := Rect2(o + Vector2(10, 700), Vector2(340, 132))
		if live: B.live_offer(ci, card, 200.0)
		else:
			var tail := Rect2(card.position + Vector2(185, 128), Vector2(30, 20))
			Sprites.draw(ci, "board_offer_under", card)
			Sprites.draw(ci, "board_offer_tail_ink", tail)
			Sprites.draw(ci, "board_offer_top", card)
			Sprites.draw(ci, "board_offer_tail_fill", tail)
		# 双倍火种、托盘
		if live:
			B.live_boost(ci, o + Vector2(400, 740), true)
			B.live_boost(ci, o + Vector2(460, 740), false)
			B.live_hint_plate(ci, o + Vector2(560, 740), 76, 2, true)
		else:
			Sprites.at(ci, "board_boost_on", o + Vector2(400, 740))
			Sprites.at(ci, "board_boost_off", o + Vector2(460, 740))
			Sprites.draw(ci, "board_plate_hot", Rect2(o + Vector2(522, 702), Vector2(76, 76)))
		# 棋盘格子：藤蔓、陶锅、生产器光、小牌、闪星、光框
		for k in 4:
			var cr := Rect2(o + Vector2(10 + k * 100, 870), Vector2(96, 96))
			ci.draw_rect(cr, Art.HIDE)
			if live: B.live_vine(ci, cr, k, true)
			else: Sprites.draw(ci, "board_vine_b%d" % k, cr)
			Art.item(ci, "berry_2", cr.get_center(), 84)
			if live: B.live_vine(ci, cr, k, false)
			else: Sprites.draw(ci, "board_vine_f%d" % k, cr)
		var cr2 := Rect2(o + Vector2(10, 980), Vector2(96, 96))
		ci.draw_rect(cr2, Color("f6c56b"))
		var ctr := cr2.get_center() + Vector2(0, -10)
		if live:
			B.live_cook_pot(ci, ctr, 0)
			Art.fill(ci, Art.flame_pts(ctr + Vector2(0, 20), 7.0, 13.0, 4), Art.FIRE2, 2.0)
		else:
			Sprites.at(ci, "board_cook_pot", ctr)
			Sprites.draw(ci, "board_cook_flame", Rect2(ctr + Vector2(-8, 20.0 - 6.5), Vector2(16, 13)))
		var cr3 := Rect2(o + Vector2(110, 980), Vector2(96, 96))
		ci.draw_rect(cr3, Art.HIDE)
		var pill := Rect2(cr3.get_center().x - 30, cr3.end.y - 18, 60, 26)
		var bp := Rect2(o + Vector2(230, 1000), Vector2(64, 21))
		if live:
			B.live_prod_glow(ci, cr3.grow(-6), 0)
			Art.fill(ci, Art.flame_pts(cr3.position + Vector2(80, 78), 7, 18, 0), Art.FIRE_BOOST, 2.0)
			var sh := Art.rrect(pill, 11, 700, 0.3)
			Art.dilate(ci, sh, 2.0, Art.INK)
			ci.draw_colored_polygon(sh, Art.CLAY)
			var sh2 := Art.rrect(bp, 10, 600, 0.3)
			Art.dilate(ci, sh2, 2.0, Art.INK)
			ci.draw_colored_polygon(sh2, Color("2f6d93"))
			ci.draw_colored_polygon(Art.star_pts(o + Vector2(330, 1010), 12.0, 5.0, 4, 0), Art.FIRE2)
			B.live_glow(ci, Rect2(o + Vector2(363, 983), Vector2(90, 90)), Color("b8ff7a"), 0.8)
		else:
			Sprites.draw(ci, "board_prod_glow", cr3.grow(-6))
			Sprites.at(ci, "board_bolt_boost", cr3.position + Vector2(80, 78))
			Sprites.draw(ci, "board_epill_ink", pill)
			Sprites.draw(ci, "board_epill_fill", pill, Art.CLAY)
			Sprites.draw(ci, "board_bpill_ink", bp)
			Sprites.draw(ci, "board_bpill_fill", bp, Color("2f6d93"))
			Sprites.at(ci, "board_burst_star", o + Vector2(330, 1010), 1.0, 0.0, Art.FIRE2)
			Sprites.draw(ci, "board_glow", Rect2(o + Vector2(363, 983), Vector2(90, 90)), Color(Color("b8ff7a"), 0.8))
		# 小一号的托盘、影子
		if live:
			ci.draw_colored_polygon(Art.ell(o + Vector2(530, 1030), Vector2(24, 20.16), 63, 0.03, 18), Color(0.8, 0.65, 0.4, 0.35))
			B.live_hint_plate(ci, o + Vector2(620, 1030), 48, 0, false)
		else:
			Sprites.draw(ci, "board_spot_shadow", Rect2(o + Vector2(506, 1009.84), Vector2(48, 40.32)))
			Sprites.draw(ci, "board_plate", Rect2(o + Vector2(596, 1006), Vector2(48, 48)))
