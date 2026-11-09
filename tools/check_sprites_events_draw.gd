extends RefCounted
const E := preload("res://scripts/sprites/events.gd")
const RaceP := preload("res://scripts/ui/RacePopup.gd")

static func paint(ci: CanvasItem, sz: Vector2) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, sz), Color("f3e6cc"))
	ci.draw_line(Vector2(700, 0), Vector2(700, sz.y), Color(0, 0, 0, 0.3), 2)
	for side in 2:
		var o := Vector2(side * 700 + 10, 10)
		var live := side == 0
		# 活动入口主题图 + 状态小牌
		var kinds := [["duel", false], ["race", false], ["ruins", true], ["seven", false]]
		for i in kinds.size():
			var g := o + Vector2(70 + i * 150, 130)
			if live:
				E.live_entry(ci, kinds[i][0], kinds[i][1], g)
				E.live_entry_pill(ci, Rect2(g + Vector2(-40, -9), Vector2(80, 26)), ["go", "num", "lock", "gold"][i])
			else:
				Sprites.at(ci, "ev_entry_%s%s" % [kinds[i][0], "_grey" if kinds[i][1] else ""], g + Vector2(0, -54))
				Sprites.draw(ci, "ev_pill_" + ["go", "num", "lock", "gold"][i], Rect2(g + Vector2(-40, -9), Vector2(80, 26)))
		# 通行证：卡、节点、循环宝箱底
		var r1 := Rect2(o + Vector2(10, 200), Vector2(202, 148))
		var r2 := Rect2(o + Vector2(240, 200), Vector2(202, 148))
		if live:
			E.live_pass_card(ci, r1, "free", false)
			E.live_pass_card(ci, r2, "prem", true)
			E.live_pass_node(ci, o + Vector2(500, 230), "done")
			E.live_pass_node(ci, o + Vector2(500, 320), "cur")
			E.live_pass_endless(ci, o + Vector2(610, 270), true)
		else:
			Sprites.draw(ci, "ev_pass_card_free_idle", r1)
			Sprites.draw(ci, "ev_pass_card_prem_ready", r2)
			Sprites.draw(ci, "ev_pass_node_done", Rect2(o + Vector2(466, 196), Vector2(68, 68)))
			Sprites.draw(ci, "ev_pass_node_cur", Rect2(o + Vector2(466, 286), Vector2(68, 68)))
			Sprites.draw(ci, "ev_pass_endless_lit", Rect2(o + Vector2(558, 218), Vector2(104, 104)))
		# 外星入口、星章、宝箱、头像、奖牌
		var u := o + Vector2(10, 390)
		if live:
			ci.draw_set_transform(u)
			E.live_ufo_back(ci)
			ci.draw_set_transform(u + E.UFO_C + Vector2(0, -12))
			E.live_ufo_saucer(ci)
			ci.draw_set_transform(Vector2.ZERO)
			E.live_ufo_front(ci, u)
			ci.draw_set_transform(o + Vector2(180, 390))
			E.live_ufo_star(ci, Vector2(64, 64))
			ci.draw_set_transform(Vector2.ZERO)
			E.live_race_chest(ci, o + Vector2(380, 450), 0, 62.0)
			E.live_rank_avatar(ci, o + Vector2(480, 450), 42.0, 1, false)
			E.live_medal(ci, o + Vector2(580, 450), 22.0, E.MEDAL[1])
		else:
			Sprites.draw(ci, "ev_ufo_back", Rect2(u, Vector2(150, 140)))
			Sprites.draw(ci, "ev_ufo_saucer", Rect2(u + E.UFO_C + Vector2(-44, -38), Vector2(88, 44)))
			Sprites.draw(ci, "ev_ufo_front", Rect2(u, Vector2(150, 140)))
			Sprites.draw(ci, "ev_ufo_star", Rect2(o + Vector2(180, 390), Vector2(128, 128)))
			RaceP._rank_chest(ci, o + Vector2(380, 450), 0, 62.0)
			RankPopup._paint_avatar(ci, o + Vector2(480, 450), 42.0, 1, false)
			Sprites.draw(ci, "ev_medal_1", Rect2(o + Vector2(558, 428), Vector2(44, 44)))
		# 七日任务一行
		var row := Rect2(o + Vector2(10, 560), Vector2(624, 124))
		if live:
			ci.draw_set_transform(row.position)
			E.live_sd_row(ci, row.size, "ready")
			E.live_sd_tag(ci, Vector2(56, 62), E.SD_TIER[25], false)
			ci.draw_set_transform(Vector2.ZERO)
		else:
			Sprites.draw(ci, "ev_sd_row_ready", row)
			Sprites.draw(ci, "ev_sd_tag_25", Rect2(row.position + Vector2(16, 20), Vector2(80, 84)))
		# 部落界面两张小卡、最划算丝带
		var cpos := o + Vector2(10, 710)
		if live:
			ci.draw_set_transform(cpos)
			E.live_spree_card_back(ci)
			E.live_spree_card_front(ci)
			ci.draw_set_transform(cpos + Vector2(120, 0))
			E.live_giftcard_base(ci)
			E.live_giftcard_box(ci)
			ci.draw_set_transform(Vector2.ZERO)
		else:
			Sprites.draw(ci, "ev_spree_card_back", Rect2(cpos, Vector2(100, 100)))
			Sprites.draw(ci, "ev_spree_card_front", Rect2(cpos, Vector2(100, 100)))
			Sprites.draw(ci, "ev_giftcard_base", Rect2(cpos + Vector2(120, 0), Vector2(100, 100)))
			Sprites.draw(ci, "ev_giftcard_box", Rect2(cpos + Vector2(120, 0), Vector2(100, 100)))
		# 竹筒（九宫格拉到 300 高）、月石进度槽
		var tr := Rect2(o + Vector2(260, 700), Vector2(84, 300))
		var gr := Rect2(o + Vector2(370, 720), Vector2(300, 20))
		if live:
			E.live_race_tube(ci, tr, true)
			var gp := Art.rrect(gr, 10, 408, 0.3)
			Art.dilate(ci, gp, 3.0, Art.INK)
			ci.draw_colored_polygon(gp, Color("10232a"))
			ci.draw_colored_polygon(Art.rrect(Rect2(gr.position, Vector2(180, 20)), 10, 409, 0.2), Color("8cdece"))
			E.live_me_node(ci, o + Vector2(420, 800), 36.0, 1)
			E.live_duel_vs(ci, o + Vector2(540, 800), 40.0)
		else:
			Sprites.draw(ci, "ev_race_tube_me", tr)
			Sprites.draw(ci, "ev_me_groove", gr)
			Sprites.draw(ci, "ev_me_fill", Rect2(gr.position, Vector2(180, 20)), Color("8cdece"))
			Sprites.draw(ci, "ev_me_node_big_1", Rect2(o + Vector2(384, 764), Vector2(72, 72)))
			Sprites.at(ci, "ev_duel_vs", o + Vector2(540, 802))
		# 礼包链卡（锁着）
		var gc := o + Vector2(10, 1020)
		if live:
			ci.draw_set_transform(gc)
			E.live_gift_card(ci, Vector2(580, 236), false)
			E.live_gift_lock(ci, Vector2(580, 236))
			ci.draw_set_transform(Vector2.ZERO)
		else:
			Sprites.draw(ci, "ev_gift_card_lock", Rect2(gc, Vector2(580, 236)))
			Sprites.draw(ci, "ev_gift_lock", Rect2(gc, Vector2(580, 236)))
		# 通行证柱脚
		if live:
			E.live_pass_base(ci, o + Vector2(300, 1300))
		else:
			Sprites.draw(ci, "ev_pass_base", Rect2(o + Vector2(300 - 136, 1306), Vector2(272, 70)))
