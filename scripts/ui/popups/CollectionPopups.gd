class_name CollectionPopups
extends RefCounted
const Layout := preload("res://scripts/config/board_layout.gd")
const PS := preload("res://scripts/sprites/popups.gd")

static func event() -> PopupBase:
	var p := PopupBase.new()
	p.dim_alpha = 1.0
	UI.box(p.box, Rect2(0, 0, 720, 1480), func(ci, sz): Paint.vgrad(ci, Rect2(Vector2.ZERO, sz), Color("4a4a8a"), Color("2f3a6a")), false)
	var fs := Popups.fullscreen(p)
	var sc: Scroller = fs[0]
	var root: Control = fs[1]
	UI.box(root, Rect2(0, 0, 720, 720), _paint_event)
	UI.title(root, "丰收祭", Rect2(0, 250, 720, 100), 72)
	UI.lbl(root, G.fmt_time(G.rules.clock.event_left()), Rect2(300, 350, 160, 44), 22, Art.INK)
	var info := UI.hit(root, Rect2(474, 342, 60, 60), func(): G.main.toast("开启兽皮卡包收集岩画卡牌，集齐卡册赢取大奖！"))
	info.extra = func(ci, sz): Paint.glyph(ci, "info", sz * 0.5, 1.2)
	var rw := [["fire_4", 800], ["amber_4", 250], ["chest_1", 1]]
	for k in 3:
		var x := 200.0 + k * 160.0
		UI.icon(root, rw[k][0], Vector2(x, 450), 90)
		UI.lbl(root, "×%d" % rw[k][1], Rect2(x - 70, 488, 140, 40), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 8, Art.INK, true)
	var total := UI.lbl(root, "%d/%d" % [G.rules.progression.cards_total(), Data.ALBUMS.size() * 9], Rect2(200, 548, 380, 40), 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK)
	Popups.live(p, G.changed, func(): total.text = "%d/%d" % [G.rules.progression.cards_total(), Data.ALBUMS.size() * 9])
	var got := G.tokens - G.token_claimed
	UI.lbl(root, "祭典鼓 %d/%d" % [got, G.TOKEN_STEP], Rect2(170, 616, 420, 36), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK)
	UI.lbl(root, "帮族人实现心愿收集祭典鼓，攒满换兽皮卡包", Rect2(60, 656, 600, 30), 18, Color("ffe7a8"), HORIZONTAL_ALIGNMENT_CENTER, 5, Art.INK)
	for a in Data.ALBUMS.size():
		var cx := 128.0 + (a % 3) * 232.0
		var cy := 840.0 + (a / 3) * 330.0
		var hit := UI.hit(root, Rect2(cx - 110, cy - 120, 220, 300), func():
			G.main.open("album", a))
		hit.extra = func(ci, sz):
			var c := Vector2(sz.x * 0.5, 110)
			Paint.collection_cover(ci, a, Rect2(c - Vector2(88, 88), Vector2(176, 176)))
			var ribbon_cols := [Art.OCHRE, Art.MOSS, Color("c463a5"), Color("8f6cd0"), Color("3fa0d8"), Art.CLAY]
			Sprites.draw(ci, "pop_ribbon_base", PS.RIBBON)
			Sprites.draw(ci, "pop_ribbon_fill", PS.RIBBON, ribbon_cols[a % ribbon_cols.size()])
			Paint.bar(ci, Rect2(20, 240, sz.x - 40, 32), float(G.rules.progression.album_count(a)) / 9.0, Art.MOSS)
		UI.lbl(hit, CardArtwork.title(a), Rect2(0, 168, 220, 56), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 8, Art.INK, true)
		var count := UI.lbl(hit, _collection_progress(a), Rect2(0, 240, 220, 32), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK)
		Popups.live(p, G.changed, func(): count.text = _collection_progress(a))
	sc.set_length(840.0 + 3 * 330.0 + 330.0 - 128.0)
	var shop := UI.hit(p.box, Rect2(414, 1340, 120, 130), func(): G.main.open("pack"))
	shop.extra = func(ci, sz):
		Art.item(ci, "pack_1", Vector2(sz.x * 0.5, 56), 100)
	UI.lbl(shop, "打开卡包", Rect2(0, 96, 120, 34), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK)
	CardStarUI.button(p)
	_gm_button(p.box, Rect2(24, 1352, 218, 60))
	return p

static func _paint_event(ci: CanvasItem, sz: Vector2) -> void:
	Paint.vgrad(ci, Rect2(0, 0, sz.x, 600), Color("1f2a5a"), Color("5a4f9a"))
	Paint.vgrad(ci, Rect2(0, 600, sz.x, 120), Color("5a4f9a"), Color("4a4a8a"))
	for i in 40:
		ci.draw_circle(Vector2(Art.srnd(i) * sz.x, 130 + Art.srnd(i + 50) * 140), 1.2 + Art.srnd(i + 7) * 2.0, Color(1, 1, 0.85, 0.5 + 0.5 * Art.srnd(i + 3)))
	ci.draw_circle(Vector2(600, 180), 50, Color(1, 0.95, 0.75, 0.25))
	ci.draw_circle(Vector2(600, 180), 36, Color("fff1c4"))
	Paint.hills(ci, 240, sz.x, 40, Color("2a2f5a"), 4, 300)
	Sprites.draw(ci, "pop_event_flags", PS.EVENT_FLAGS)
	Art.item(ci, "fire_4", Vector2(360, 190), 130)
	for k in 4:
		var x := 120.0 + k * 160.0
		if k == 1 or k == 2:
			x += (1 if k == 2 else -1) * 60.0
		Paint._hunter(ci, Vector2(x, 210), 1.6, Color("1a1430"), k)
	Paint.mascot(ci, Vector2(90, 200), 80)
	Sprites.draw(ci, "pop_event_panel", PS.EVENT_PANEL)
	Paint.glyph(ci, "clock", Vector2(318, 372), 1.0)
	Paint.bar(ci, Rect2(170, 552, 420, 34), float(G.rules.progression.cards_total()) / float(Data.ALBUMS.size() * 9), Art.MOSS)
	Paint.cards_icon(ci, Vector2(160, 568), 0.6)
	var got := G.tokens - G.token_claimed
	Paint.bar(ci, Rect2(170, 616, 420, 36), float(got) / float(G.TOKEN_STEP), Art.OCHRE)
	Art.item(ci, "token_1", Vector2(160, 630), 64)
	Art.item(ci, "pack_1", Vector2(610, 630), 64)

static func album(a: int) -> PopupBase:
	var p := PopupBase.new()
	var r := Rect2(30, 180, 660, 1140)
	Popups.frame(p, r, CardArtwork.title(a), Paint.ALBUM_COL[a].darkened(0.2))
	var cover := UI.box(p.box, Rect2(62, r.position.y + 48, 176, 176), func(ci, sz): Paint.collection_cover(ci, a, Rect2(Vector2.ZERO, sz)), false)
	cover.name = "album_cover"
	var reward_state := UI.lbl(p.box, "", Rect2(254, r.position.y + 54, 396, 32), 24, Color("7a5a3a"))
	reward_state.name = "album_reward_state"
	var rewards: Array = Data.ConfigFiles.shared("res://data/replay_economy.json")["album_reward"]
	var reward_icons: Array[Control] = []
	for k in rewards.size():
		var x := 290.0 + float(k) * 380.0 / float(rewards.size())
		reward_icons.append(UI.icon(p.box, str(rewards[k][0]), Vector2(x, r.position.y + 124), 64))
		UI.lbl(p.box, "×%d" % int(rewards[k][1]), Rect2(x + 34, r.position.y + 104, 100, 40), 27, Art.INK, HORIZONTAL_ALIGNMENT_LEFT)
	var progress := UI.box(p.box, Rect2(254, r.position.y + 170, 244, 32), func(ci, sz):
		Paint.bar(ci, Rect2(Vector2.ZERO, sz), float(G.rules.progression.album_count(a)) / 9.0, Art.MOSS), false)
	progress.name = "album_progress"
	var count := UI.lbl(p.box, "", Rect2(254, r.position.y + 170, 244, 32), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 5, Art.INK)
	count.name = "album_progress_count"
	var claim := UI.btn(p.box, Rect2(514, r.position.y + 162, 136, 48), "未集齐", "grey", Callable(), 28)
	claim.name = "album_claim"
	claim.pressed.connect(func():
		var result: Dictionary = Replay.perform("album_claim", {"album": a})
		if result.has("error"):
			G.main.toast(str(result["error"]))
			return
		Sfx.play("coin")
		RewardPresenter.present(result.get("rewards", []), func(k): return reward_icons[k].get_global_rect().get_center()))
	var refresh_header := func():
		var collected := G.rules.progression.album_count(a)
		var claimed := bool(Replay.meta.get("album:%d" % a, false))
		var ready := collected == 9 and not claimed
		count.text = ("已集齐 %d/9" if collected == 9 else "已收集 %d/9") % collected
		reward_state.text = "奖励已领取" if claimed else "集齐奖励"
		claim.text = "已领取" if claimed else ("领取" if ready else "未集齐")
		claim.enabled = ready
		claim.style = "green" if ready else "grey"
		claim.queue_redraw()
		progress.queue_redraw()
	refresh_header.call()
	_gm_button(p.box, Rect2(236, r.end.y + 20, 248, 52), a)
	CardStarUI.button(p)
	var holder := Control.new()
	holder.name = "album_cards"
	holder.size = Vector2(720, 1480)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.box.add_child(holder)
	_album_cards(holder, a, r)
	Popups.live(p, G.changed, func():
		refresh_header.call()
		_album_cards(holder, a, r))
	return p

static func _collection_progress(a: int) -> String:
	var count := G.rules.progression.album_count(a)
	if count == 9 and not bool(Replay.meta.get("album:%d" % a, false)): return "9/9 · 可领取"
	return "%d/9" % count

static func _album_cards(holder: Control, a: int, r: Rect2) -> void:
	for child in holder.get_children(): child.free()
	for k in 9:
		var cx := r.position.x + 120 + (k % 3) * 210
		var cy := r.position.y + 280 + (k / 3) * 270
		var key := "%d_%d" % [a, k]
		var owned := G.cards.has(key)
		var tile := UI.hit(holder, Rect2(cx - 90, cy, 180, 250), func():
			if G.cards.has(key): G.main.open("card", {"album": a, "index": k})
			else: G.main.toast("收集后可查看"))
		tile.name = "card_%d_%d" % [a, k]
		tile.extra = func(ci, sz): Paint.card(ci, Rect2(Vector2(4, 8), sz - Vector2(8, 10)), a, k, owned)
		UI.lbl(tile, CardArtwork.card_name(a, k) if owned else "？？？", Rect2(14, 190, 152, 46), 21, Color("5a3a1e") if owned else Color("a08868"), HORIZONTAL_ALIGNMENT_CENTER)
		if owned and int(G.cards[key]) > 1:
			UI.lbl(tile, "×%d" % int(G.cards[key]), Rect2(118, 150, 56, 34), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.CLAY)

static func card(album: int, index: int) -> PopupBase:
	if album < 0 or album >= Data.ALBUMS.size() or index < 0 or index >= Data.ALBUMS[album]["cards"].size(): return null
	var key := "%d_%d" % [album, index]
	if not G.cards.has(key): return null
	var p := PopupBase.new()
	p.name = "collection_card_detail"
	var r := Rect2(24, 328, 672, 672)
	var art := UI.box(p.box, r, func(ci, sz):
		Paint.collection_picture(ci, Rect2(Vector2.ZERO, sz), album, index), false)
	art.name = "card_art"
	var br := Rect2(180, r.position.y - 34, 360, 78)
	UI.box(p.box, br, func(ci, sz): Paint.banner(ci, Rect2(Vector2.ZERO, sz), Paint.ALBUM_COL[album].darkened(0.2)))
	UI.title(p.box, CardArtwork.card_name(album, index), Rect2(220, br.position.y + 4, 280, 68), 38, Color.WHITE)
	var close := UI.hit(p.box, Rect2(r.end.x - 52, r.position.y - 24, 70, 70), p.close)
	close.extra = func(ci, sz): Paint.close_btn(ci, sz * 0.5, 28)
	# 星级横幅压在画框下沿，下面一块兽皮说明牌
	var stars := CardPacks.stars(album, index)
	UI.box(p.box, Rect2(0, 0, 720, 1480), func(ci, _sz):
		var plate := Rect2(44, r.end.y + 34, 632, 196)
		var pp := Art.rrect(plate, 22, 77, 0.5)
		Art.dilate(ci, pp, 3.0, Art.INK)
		ci.draw_colored_polygon(pp, Art.HIDE)
		Art.dashed(ci, Art.rrect(plate.grow(-8), 16, 78, 0.0), 7, 5, Art.HIDE2.darkened(0.15), 2.0)
		var rw := 40.0 + float(stars) * 30.0
		Sprites.draw(ci, "alb_ribbon", Rect2(360 - rw * 0.5, r.end.y - 6, rw, 40))
		for k in stars:
			Sprites.at(ci, "paint_card_star", Vector2(360 + (float(k) - float(stars - 1) * 0.5) * 30.0, r.end.y + 13), 0.95), false)
	var text := UI.lbl(p.box, CardArtwork.caption(album, index), Rect2(68, r.end.y + 58, 584, 160), 34, Color("4a2f18"), HORIZONTAL_ALIGNMENT_CENTER)
	var bold := FontVariation.new()
	bold.base_font = G.font_body
	bold.variation_embolden = 1.0
	text.label_settings.font = bold
	text.name = "card_text"
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	return p

static func _gm_button(parent: Control, rect: Rect2, album: int = -1) -> void:
	if not bool(Replay.meta.get("allow_gm", false)): return
	var button := UI.btn(parent, rect, "GM 随机获取", "teal", func():
		var result: Dictionary = Replay.perform("gm", {"action": "card", "album": album})
		if result.has("error"):
			G.main.toast(str(result["error"]))
			return
		var received: Array = result.get("cards", [])
		if not received.is_empty():
			var rewards: Array = result.get("card_rewards", [])
			if not rewards.is_empty() and int(rewards[0]["stars"]) > 0: G.main.open("card_received", result)
			else: G.main.open("card", {"album": int(received[0][0]), "index": int(received[0][1])}), 21)
	button.name = "gm_random_card"

# ---------------------------------------------------------------- 开卡包

static func pack(request: Dictionary = {}) -> PopupBase:
	var p := PopupBase.new()
	p.dim_alpha = 0.82
	var source := G.rules.progression.find_pack_source(str(request.get("id", "")), int(request.get("cell", -1)), int(request.get("stash", -1)))
	var pack_id := str(source.get("id", "pack_1"))
	var title := UI.title(p.box, Data.name_of(pack_id), Rect2(70, 250, 580, 80), 40, Color.WHITE)
	var chance := UI.lbl(p.box, "卡片星级概率\n" + CardPacks.probability_text(pack_id), Rect2(80, 880, 560, 170), 24, Color("ffe7a8"), HORIZONTAL_ALIGNMENT_CENTER, 5, Art.INK)
	chance.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var state := {"open": false, "t": 0.0}
	var pack_box := UI.box(p.box, Rect2(160, 360, 400, 500), func(ci, sz):
		if state["open"]:
			return
		var c: Vector2 = sz * 0.5
		var rot := float(Time.get_ticks_msec()) / 2500.0
		for k in 12:
			var a := rot + TAU * float(k) / 12.0
			ci.draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a - 0.1), sin(a - 0.1)) * 300.0, c + Vector2(cos(a + 0.1), sin(a + 0.1)) * 300.0]), Color(1, 0.85, 0.4, 0.14))
		var wob := sin(float(Time.get_ticks_msec()) / 120.0) * 0.06
		Art.item(ci, pack_id, c, 300, true, wob))
	var hint := UI.lbl(p.box, "点击打开", Rect2(0, 1080, 720, 60), 36, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 10, Art.INK, true)
	var timer := Timer.new()
	timer.wait_time = 0.033
	timer.autostart = true
	p.add_child(timer)
	timer.timeout.connect(pack_box.queue_redraw)
	p.on_tap = func():
		if state["open"]:
			return
		state["open"] = true
		Sfx.play("merge", 1.3)
		hint.visible = false
		chance.hide()
		var result: Dictionary = await G.open_pack_result(pack_id, int(source.get("cell", -1)), int(source.get("stash", -1)))
		if not is_instance_valid(p) or not p.is_inside_tree(): return
		if result.has("error") or result.get("cards", []).is_empty():
			p.close()
			return
		timer.stop()
		pack_box.hide()
		title.text = "获得卡牌"
		CardRewardPresentation.fill(p, result.get("card_rewards", []))
	return p

## 计时制作的订单成品，和普通合成链分开。
