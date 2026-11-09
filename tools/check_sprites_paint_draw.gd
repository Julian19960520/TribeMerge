extends RefCounted
const PS := preload("res://scripts/sprites/paint.gd")

static func paint(ci: CanvasItem, sz: Vector2) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, sz), Color("f3e6cc"))
	ci.draw_line(Vector2(600, 0), Vector2(600, sz.y), Color(0, 0, 0, 0.3), 2.0)
	for side in 2:
		var o := Vector2(side * 600, 0)
		var live := side == 0
		# 背景：山丘 + 棕榈
		if live:
			PS.live_hills(ci, 120, 600, 40, Color("7fb48a"), 2, 190)
			PS.live_palm(ci, o + Vector2(60, 180), 110, 3, Color("3f7a40"))
			PS.live_palm(ci, o + Vector2(540, 180), 80, 725, Color("17302f"))
		else:
			ci.draw_set_transform(o, 0.0, Vector2.ONE)
			Paint.hills(ci, 120, 600, 40, Color("7fb48a"), 2, 190)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			Paint.palm(ci, o + Vector2(60, 180), 110, 3, Color("3f7a40"))
			Paint.palm(ci, o + Vector2(540, 180), 80, 725, Color("17302f"))
		# 小图标
		var gi := 0
		for kind in PS.GLYPHS:
			var c := o + Vector2(40 + (gi % 6) * 60, 230 + (gi / 6) * 60)
			ci.draw_circle(c, 26, Art.TEAL)
			if live: PS.live_glyph(ci, kind, c, 1.3, Color.WHITE)
			else: Paint.glyph(ci, kind, c, 1.3, Color.WHITE)
			gi += 1
		# 大图标
		var icons := ["gift", "hammer", "book", "cards", "hut", "pouch", "home"]
		for i in icons.size():
			var c := o + Vector2(50 + (i % 4) * 140, 400 + (i / 4) * 120)
			match icons[i]:
				"gift": (PS.live_gift(ci, c, 86) if live else Paint.gift(ci, c, 86))
				"hammer": (PS.live_hammer(ci, c, 0.9) if live else Paint.hammer(ci, c, 0.9))
				"book": (PS.live_book(ci, c, 0.9) if live else Paint.book(ci, c, 0.9))
				"cards": (PS.live_cards_icon(ci, c, 0.85) if live else Paint.cards_icon(ci, c, 0.85))
				"hut": (PS.live_hut_icon(ci, c, 0.85) if live else Paint.hut_icon(ci, c, 0.85))
				"pouch": (PS.live_pouch(ci, c, 1.0) if live else Paint.pouch(ci, c, 1.0))
				"home": (PS.live_home_icon(ci, c, 0.85) if live else Paint.home_icon(ci, c, 0.85))
		# 配置图标
		for i in PS.CFG_KINDS.size():
			var c := o + Vector2(45 + (i % 6) * 90, 650 + (i / 6) * 90)
			if live: PS.live_cfg(ci, PS.CFG_KINDS[i], c, 0.7)
			else: Paint.cfg_icon(ci, PS.CFG_KINDS[i], c, 70)
		# 脸 / 头像
		if live:
			PS.live_face(ci, o + Vector2(60, 860), 30, Color("d39a6a"), 0)
			PS.live_portrait(ci, 0, o + Vector2(170, 860), 70)
			PS.live_portrait(ci, 3, o + Vector2(260, 860), 70)
		else:
			Paint.face(ci, o + Vector2(60, 860), 30, Color("d39a6a"), 0)
			Paint.portrait(ci, 0, o + Vector2(170, 860), 70)
			Paint.portrait(ci, 3, o + Vector2(260, 860), 70)
		# 角色
		if live:
			PS.live_mascot(ci, o + Vector2(380, 880), 90, "hammer")
			PS.live_bust(ci, o + Vector2(510, 880), 70)
			PS.live_heroine(ci, o + Vector2(110, 1060), 76)
		else:
			Paint.mascot(ci, o + Vector2(380, 880), 90, "hammer")
			Paint.bust(ci, o + Vector2(510, 880), 70)
			Paint.heroine(ci, o + Vector2(110, 1060), 76)
		# 卡牌
		for k in 3:
			var r := Rect2(o + Vector2(250 + k * 115, 980), Vector2(105, 150))
			var owned := k != 2
			if live: PS.live_card(ci, r, k, k * 2, owned)
			else: Paint.card(ci, r, k, k * 2, owned)
		for k in 3:
			var r := Rect2(o + Vector2(20 + k * 100, 1180), Vector2(90, 90))
			if live: PS.live_card_art(ci, k + 3, k, r)
			else: Paint.card_art(ci, k + 3, k, r)
		# 小屋 + 气泡 + 岩画小人
		if live:
			PS.live_spot_hut(ci, o + Vector2(420, 1300), 6)
			PS.live_reward_bubble(ci, o + Vector2(60, 1400), 40, "", 0, 1)
			PS.live_hunter(ci, o + Vector2(160, 1400), 1.6, Color("1a1430"), 0)
			PS.live_campfire_scene(ci, o + Vector2(260, 1400), 0.6)
		else:
			Paint._spot_hut(ci, o + Vector2(420, 1300), 6)
			Paint.reward_bubble(ci, o + Vector2(60, 1400), 40, "", 0, 1)
			Paint._hunter(ci, o + Vector2(160, 1400), 1.6, Color("1a1430"), 0)
			Paint.campfire_scene(ci, o + Vector2(260, 1400), 0.6)
