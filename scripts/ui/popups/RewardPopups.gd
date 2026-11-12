class_name RewardPopups
extends RefCounted
const Layout := preload("res://scripts/config/board_layout.gd")
const PS := preload("res://scripts/sprites/popups.gd")

static func levelup() -> PopupBase:
	var p := PopupBase.new()
	p.dim_alpha = 0.8
	var rewards := Data.level_rewards(G.level)
	var spots: Array[Vector2] = []
	for k in rewards.size():
		spots.append(Vector2(ItemPopups._spread_x(k, rewards.size(), 360.0, 156.0), 700.0))
	UI.box(p.box, Rect2(0, 0, 720, 1480), func(ci, _sz):
		var c := Vector2(360, 470)
		var rot := float(Time.get_ticks_msec()) / 3000.0
		for k in 14:
			var a := rot + TAU * float(k) / 14.0
			ci.draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a - 0.09), sin(a - 0.09)) * 420.0, c + Vector2(cos(a + 0.09), sin(a + 0.09)) * 420.0]), Color(1, 0.85, 0.4, 0.13))
		ci.draw_circle(c, 150, Color(1, 0.85, 0.4, 0.2))
		Paint.level_badge(ci, c, 220)
		Paint.heroine(ci, Vector2(250, 1260), 160))
	UI.title(p.box, "主角升级！", Rect2(0, 210, 720, 110), 76)
	UI.lbl(p.box, str(G.level), Rect2(260, 400, 200, 140), 96, Color("fff1c4"), HORIZONTAL_ALIGNMENT_CENTER, 16, Art.INK, true)
	for k in rewards.size():
		UI.icon(p.box, rewards[k][0], spots[k], 120)
		UI.lbl(p.box, "×%d" % rewards[k][1], Rect2(spots[k].x - 70, spots[k].y + 58, 140, 50), 34, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 10, Art.INK, true)
	var news := Data.level_unlocks(G.level)
	var hint_y := 850.0
	if not news.is_empty():
		UI.lbl(p.box, String.chr(10).join(news.slice(0, 3)), Rect2(60, 820, 600, 44 * mini(news.size(), 3)), 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 10, Art.INK, true)
		hint_y = 836.0 + 44.0 * float(mini(news.size(), 3))
	var hint := UI.lbl(p.box, "点击任意处领取", Rect2(0, hint_y, 720, 50), 28, Color("ffe7a8"), HORIZONTAL_ALIGNMENT_CENTER, 8, Art.INK)
	var tw := hint.create_tween().set_loops()
	tw.tween_property(hint, "modulate:a", 0.3, 0.6)
	tw.tween_property(hint, "modulate:a", 1.0, 0.6)
	Sfx.play("fanfare")
	var claiming := {"busy": false}
	p.on_tap = func():
		# 升级奖励由服务器发：连不上就先留着弹窗，稍后再点
		if claiming["busy"]:
			return
		claiming["busy"] = true
		var got = await G.claim_level(G.level)
		claiming["busy"] = false
		if got == null:
			return
		if not (got as Array).is_empty():
			RewardPresenter.present(got, func(k): return spots[k] if k < spots.size() else Vector2(360, 700))
		p.on_tap = Callable()
		p.close()
	var redraw := Timer.new()
	redraw.wait_time = 0.033
	redraw.autostart = true
	p.add_child(redraw)
	redraw.timeout.connect(func():
		for ch in p.box.get_children():
			if ch is DrawBox:
				ch.queue_redraw()
				break)
	return p

## 一批 [[id, 数量]]。和棋盘气泡用同一张全屏领奖。

static func reward_screen(rewards: Array) -> PopupBase:
	var entries: Array = []
	for rw in rewards:
		if not (rw is Array) or rw.size() < 2:
			continue
		var n := int(rw[1])
		if str(rw[0]) == "" or n < 1:
			continue
		entries.append({"i": -1, "id": str(rw[0]), "n": n})
	var p := board_reward(entries)
	if p != null:
		p.set_meta("reward_screen", true)
	return p

## 棋盘上的奖励解锁：全屏展示，点一下才领。entries 是 [{i, id, n}, ...]。
## 画面：柔和的旋转光芒 + 绳捆木板标题 + 每件奖励一个发光台座，依次弹出、轻轻浮动；底部「收下」按钮，点任意处也能领。

static func board_reward(entries: Array) -> PopupBase:
	if entries.is_empty():
		return null
	var p := PopupBase.new()
	p.dim_alpha = 0.86
	p.set_meta("board_reward", true)
	var n := entries.size()
	var cols := n if n <= 4 else (3 if n <= 6 else 4)
	var rows := int(ceil(float(n) / float(cols)))
	var slot := 210.0 if n == 1 else (156.0 if n <= 3 else 124.0)
	var show_name := n <= 4
	var gap_x := minf(slot + 34.0, 640.0 / float(cols))
	var gap_y := slot + (96.0 if show_name else 64.0)
	var origin_y := 740.0 - float(rows - 1) * gap_y * 0.5
	var spots: Array[Vector2] = []
	for k in n:
		var row := int(k / cols)
		var in_row := mini(cols, n - row * cols)
		var col := k % cols
		spots.append(Vector2(360.0 + (float(col) - float(in_row - 1) * 0.5) * gap_x, origin_y + float(row) * gap_y))
	var glow := Vector2(360, origin_y + float(rows - 1) * gap_y * 0.5)
	var grid_bottom := origin_y + float(rows - 1) * gap_y + slot * 0.5 + (70.0 if show_name else 40.0)
	var br := Rect2(170, 190, 380, 92)
	var t0 := Time.get_ticks_msec()
	# 背景：光晕、两层反向旋转的光芒、台座、闪烁的星点
	UI.box(p.box, Rect2(0, 0, 720, 1480), func(ci, _sz):
		var t := float(Time.get_ticks_msec() - t0) / 1000.0
		var open := clampf(t / 0.5, 0.0, 1.0)
		for k in 8:
			ci.draw_circle(glow, 320.0 - float(k) * 34.0, Color(1, 0.84, 0.45, 0.018 * open))
		# 光芒从中心向外渐隐，不画出硬边
		for layer in 2:
			var nr := 10 if layer == 0 else 8
			var rot := t * (0.12 if layer == 0 else -0.08) + float(layer) * 0.35
			var reach := 1100.0 * (0.5 + 0.5 * open)
			var half := 0.06 if layer == 0 else 0.09
			var a_in := (0.07 if layer == 0 else 0.035) * open
			var c_in := Color(1, 0.9, 0.55, a_in)
			var c_out := Color(1, 0.9, 0.55, 0.0)
			for k in nr:
				var a := rot + TAU * float(k) / float(nr)
				ci.draw_polygon(PackedVector2Array([
					glow + Vector2(cos(a), sin(a)) * 30.0,
					glow + Vector2(cos(a - half), sin(a - half)) * reach,
					glow + Vector2(cos(a + half), sin(a + half)) * reach,
				]), PackedColorArray([c_in, c_out, c_out]))
		for k in spots.size():
			var c: Vector2 = spots[k]
			var appear := clampf((t - 0.18 - 0.09 * float(k)) / 0.3, 0.0, 1.0)
			if appear <= 0.0:
				continue
			var r := slot * 0.5
			for j in 4:
				ci.draw_circle(c, r * (1.0 - 0.13 * float(j)), Color(1, 0.9, 0.55, 0.05 * appear))
			Sprites.at(ci, "pop_rw_burst", c, r / PS.RW_R, t * 0.5 + float(k), Color(1, 0.95, 0.7, 0.08 * appear))
			Sprites.at(ci, "pop_rw_plate", c + Vector2(0, r * 0.66), r / PS.RW_R, 0.0, Color(1, 1, 1, appear))
		for k in 14:
			var sp := Vector2(40.0 + Art.srnd(k * 7 + 1) * 640.0, 200.0 + Art.srnd(k * 13 + 5) * 900.0)
			if sp.distance_to(glow) < 120.0:
				continue
			var tw := 0.5 + 0.5 * sin(t * (2.0 + Art.srnd(k) * 2.0) + float(k) * 1.7)
			var sr := (3.0 + Art.srnd(k * 3) * 5.0) * (0.45 + 0.55 * tw) * open
			if sr > 2.4:
				Sprites.at(ci, "pop_sparkle", sp, sr / PS.SPARK_R, 0.0, Color(1, 0.95, 0.75, 0.6 * tw))
		Paint.banner(ci, br, Color("c4532e")))
	UI.title(p.box, "获得奖励", Rect2(br.position.x + 40, br.position.y + 4, br.size.x - 80, br.size.y - 10), 46, Color("fff1c4"))
	# 奖励：依次弹出，落地后轻轻浮动
	for k in n:
		var id := str(entries[k]["id"])
		var count := int(entries[k]["n"])
		var at: Vector2 = spots[k]
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.position = at - Vector2(slot, slot) * 0.5
		holder.size = Vector2(slot, slot)
		holder.pivot_offset = holder.size * 0.5
		holder.scale = Vector2.ZERO
		p.box.add_child(holder)
		var icon := UI.icon(holder, id, Vector2(slot, slot) * 0.5 + Vector2(0, -slot * 0.06), slot * 0.86)
		var bfs := 30 if n == 1 else (26 if n <= 3 else 22)
		var text := "×%d" % count
		var tw_px := float(text.length()) * bfs * 0.62
		if G.font_title:
			tw_px = G.font_title.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs).x
		var bw := tw_px + 26.0
		var bh := bfs + 16.0
		var badge := Rect2(slot * 0.5 + slot * 0.16, slot * 0.66 - bh * 0.5, bw, bh)
		badge.position.x = minf(badge.position.x, slot + 6.0 - bw)
		UI.box(holder, badge, func(ci, sz):
			Sprites.draw(ci, "pop_rw_badge", Rect2(Vector2(3, 3), sz - Vector2(6, 6))))
		UI.lbl(holder, text, badge, bfs, Color("ffe7a8"), HORIZONTAL_ALIGNMENT_CENTER, 0, Art.INK, true)
		var name_lbl: Label = null
		if show_name and Data.is_known(id):
			var nfs := 34 if n == 1 else 24
			name_lbl = UI.lbl(p.box, Data.name_of(id), Rect2(at.x - gap_x * 0.5, at.y + slot * 0.5 + 8, gap_x, nfs + 14), nfs, Color("fff1c4"), HORIZONTAL_ALIGNMENT_CENTER, 8, Art.INK, true)
			name_lbl.modulate.a = 0.0
		var delay := 0.18 + 0.09 * float(k)
		var pop := holder.create_tween()
		pop.tween_interval(delay)
		pop.tween_callback(func(): Sfx.play("pop", 1.0 + 0.08 * float(k)))
		pop.tween_property(holder, "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if name_lbl != null:
			var nl := name_lbl
			pop.parallel().tween_property(nl, "modulate:a", 1.0, 0.25).set_delay(0.12)
		var base_y := icon.position.y
		var period := 0.8 + 0.07 * float(k % 3)
		pop.tween_callback(func():
			if not is_instance_valid(icon):
				return
			var bob := icon.create_tween().set_loops()
			bob.tween_property(icon, "position:y", base_y - 6.0, period).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			bob.tween_property(icon, "position:y", base_y + 2.0, period).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT))
	# 底部：收下按钮 + 提示
	var by := clampf(grid_bottom + 30.0, 1190.0, 1250.0)
	var take := UI.btn(p.box, Rect2(220, by, 280, 96), "收下", "green", Callable(), 44)
	take.modulate.a = 0.0
	var hint := UI.lbl(p.box, "点击任意处领取", Rect2(0, by + 104, 720, 40), 22, Color("ffe7a8"), HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK)
	hint.modulate.a = 0.0
	var fade := take.create_tween()
	fade.tween_interval(0.3 + 0.09 * float(n))
	fade.tween_property(take, "modulate:a", 1.0, 0.25)
	fade.parallel().tween_property(hint, "modulate:a", 0.8, 0.25)
	var pulse := hint.create_tween().set_loops()
	pulse.tween_interval(0.8 + 0.09 * float(n))
	pulse.tween_property(hint, "modulate:a", 0.35, 0.7)
	pulse.tween_property(hint, "modulate:a", 0.8, 0.7)
	Sfx.play("fanfare")
	var given := {"ok": false}
	var give := func(fly: bool) -> void:
		if given["ok"]:
			return
		var rewards: Array = []
		for e in entries:
			var i := int(e["i"])
			if i >= 0:
				if i >= G.board.size():
					continue
				var cell: Dictionary = G.board[i]
				if Layout.parse_reward(cell.get("rw", null)).is_empty():
					continue
				var result: Dictionary = Replay.perform("bubble_reward", {"cell": i})
				if result.has("error"): continue
			rewards.append([str(e["id"]), int(e["n"])])
		given["ok"] = true
		if rewards.is_empty():
			return
		if fly: RewardPresenter.present(rewards, func(k): return spots[k] if k < spots.size() else glow)
	p.on_tap = func():
		give.call(true)
		p.on_tap = Callable()
		p.close()
	take.pressed.connect(func():
		if p.on_tap.is_valid():
			p.on_tap.call())
	p.tree_exiting.connect(func(): give.call(false))
	var redraw := Timer.new()
	redraw.wait_time = 0.033
	redraw.autostart = true
	p.add_child(redraw)
	redraw.timeout.connect(func():
		for ch in p.box.get_children():
			if ch is DrawBox:
				ch.queue_redraw()
				break)
	return p

static func level_info() -> PopupBase:
	var p := PopupBase.new()
	var r := Rect2(40, 250, 640, 1010)
	UI.box(p.box, Rect2(0, 0, 720, 1480), func(ci, _sz):
		Paint.panel(ci, r)
		var br := Rect2(r.get_center().x - 220, r.position.y + 30, 440, 80)
		Paint.banner(ci, br, Art.TEAL)
		Paint.level_badge(ci, Vector2(r.get_center().x, r.position.y - 6), 130)
		var art := PS.LI_ART
		Sprites.draw(ci, "pop_li_art_base", art)
		Paint.vgrad(ci, art.grow(-3), Color("8fd0d4"), Color("f0deb0"))
		Sprites.draw(ci, "pop_li_ground", art)
		Paint._spot_hut(ci, Vector2(art.position.x + 120, art.position.y + 250), 6)
		Paint.palm(ci, Vector2(art.end.x - 40, art.end.y - 6), 170, 3, Color("4a8a4a"))
		Paint.heroine(ci, Vector2(art.get_center().x + 50, art.position.y + 160), 120)
		Paint.book(ci, Vector2(art.get_center().x + 50, art.position.y + 236), 1.1)
		Sprites.draw(ci, "pop_li_art_line", art)
		var bar := Rect2(r.position.x + 70, r.position.y + 560, 400, 44)
		Paint.bar(ci, bar, float(G.xp) / float(G.rules.progression.xp_need()), Art.MOSS)
		Art.item(ci, "xp_1", bar.position + Vector2(0, 22), 64)
		Paint.level_badge(ci, Vector2(bar.end.x + 70, bar.get_center().y), 92)
		Sprites.draw(ci, "pop_li_arrow", PS.LI_ARROW)
		ShopPopups._slot(ci, Rect2(r.position.x + 40, r.position.y + 680, r.size.x - 80, 280), Color("ecd9b3"), Color(0.6, 0.4, 0.2, 0.4), true))
	UI.title(p.box, "主角等级", Rect2(r.get_center().x - 200, r.position.y + 50, 400, 60), 38, Color.WHITE)
	UI.lbl(p.box, str(G.level), Rect2(r.get_center().x - 60, r.position.y - 44, 120, 80), 50, Color("fff1c4"), HORIZONTAL_ALIGNMENT_CENTER, 10, Art.INK, true)
	var tip := UI.lbl(p.box, "完成带 ★ 的订单，提升主角等级并领取奖励！", Rect2(r.position.x + 40, r.position.y + 446, r.size.x - 80, 90), 25, Color("6b4a2a"))
	tip.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	UI.lbl(p.box, "%d/%d" % [G.xp, G.rules.progression.xp_need()], Rect2(r.position.x + 70, r.position.y + 560, 400, 44), 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK)
	UI.lbl(p.box, str(G.level + 1), Rect2(r.position.x + 480, r.position.y + 548, 80, 60), 34, Color("fff1c4"), HORIZONTAL_ALIGNMENT_CENTER, 8, Art.INK, true)
	Popups.section(p.box, "下一级奖励", r.position.y + 640, Color("8a5a30"))
	var rw := Data.level_rewards(G.level + 1)
	for k in rw.size():
		var cx := ItemPopups._spread_x(k, rw.size(), r.get_center().x, 136.0)
		var cy := r.position.y + 790
		UI.icon(p.box, rw[k][0], Vector2(cx, cy), 110)
		UI.lbl(p.box, "×%d" % rw[k][1], Rect2(cx - 60, cy + 54, 120, 40), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 7, Art.INK, true)
		var id: String = rw[k][0]
		var ib := UI.hit(p.box, Rect2(cx + 22, cy - 72, 44, 44), func(): G.main.open("item_info", id))
		ib.extra = func(ci, sz): Paint.glyph(ci, "info", sz * 0.5, 1.0)
	var x := UI.hit(p.box, Rect2(r.end.x - 52, r.position.y - 24, 70, 70), p.close)
	x.extra = func(ci, sz): Paint.close_btn(ci, sz * 0.5, 28)
	return p

# ---------------------------------------------------------------- 丰收祭活动
