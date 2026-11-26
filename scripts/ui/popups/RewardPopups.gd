class_name RewardPopups
extends RefCounted
const Layout := preload("res://scripts/config/board_layout.gd")
const PS := preload("res://scripts/sprites/popups.gd")
const FULL := Rect2(0, 0, 720, 1480)
const GOLD := Color("ffe7a8")
const CREAM := Color("fff1c4")
const RED_CLOTH := Color("c4532e")

# ---------------------------------------------------------------- 领奖舞台（几张全屏领奖页共用）

## 柔光、两层反向慢转的渐隐光芒、每个奖励位一个发光台座、闪烁的星点、顶部横幅。
## t 是弹出后过了几秒；spots 是台座上物品的中心，slot 是物品尺寸；br 为空就不画横幅。
static func _paint_stage(ci: CanvasItem, t: float, glow: Vector2, spots: Array, slot: float, br: Rect2, banner_col: Color) -> void:
	var open := clampf(t / 0.5, 0.0, 1.0)
	for k in 8:
		ci.draw_circle(glow, 320.0 - float(k) * 34.0, Color(1, 0.84, 0.45, 0.018 * open))
	# 光芒从中心向外渐隐，不画出硬边
	for layer in 2:
		var nr := 10 if layer == 0 else 8
		var rot := t * (0.12 if layer == 0 else -0.08) + float(layer) * 0.35
		var reach := 1100.0 * (0.5 + 0.5 * open)
		var half := 0.06 if layer == 0 else 0.09
		var c_in := Color(1, 0.9, 0.55, (0.07 if layer == 0 else 0.035) * open)
		var c_out := Color(1, 0.9, 0.55, 0.0)
		for k in nr:
			var a := rot + TAU * float(k) / float(nr)
			ci.draw_polygon(PackedVector2Array([
				glow + Vector2(cos(a), sin(a)) * 30.0,
				glow + Vector2(cos(a - half), sin(a - half)) * reach,
				glow + Vector2(cos(a + half), sin(a + half)) * reach,
			]), PackedColorArray([c_in, c_out, c_out]))
	for k in spots.size():
		_paint_plate(ci, spots[k], slot, clampf((t - 0.18 - 0.09 * float(k)) / 0.3, 0.0, 1.0), t * 0.5 + float(k))
	for k in 14:
		var sp := Vector2(40.0 + Art.srnd(k * 7 + 1) * 640.0, 200.0 + Art.srnd(k * 13 + 5) * 900.0)
		if sp.distance_to(glow) < 120.0:
			continue
		var tw := 0.5 + 0.5 * sin(t * (2.0 + Art.srnd(k) * 2.0) + float(k) * 1.7)
		var sr := (3.0 + Art.srnd(k * 3) * 5.0) * (0.45 + 0.55 * tw) * open
		if sr > 2.4:
			Sprites.at(ci, "pop_sparkle", sp, sr / PS.SPARK_R, 0.0, Color(1, 0.95, 0.75, 0.6 * tw))
	if br.size.x > 0.0:
		Paint.banner(ci, br, banner_col)

## 一个发光台座：物品中心 c、物品尺寸 slot；appear 0..1 淡入。
static func _paint_plate(ci: CanvasItem, c: Vector2, slot: float, appear: float, spin: float) -> void:
	if appear <= 0.0:
		return
	var r := slot * 0.5
	for j in 4:
		ci.draw_circle(c, r * (1.0 - 0.13 * float(j)), Color(1, 0.9, 0.55, 0.05 * appear))
	Sprites.at(ci, "pop_rw_burst", c, r / PS.RW_R, spin, Color(1, 0.95, 0.7, 0.08 * appear))
	Sprites.at(ci, "pop_rw_plate", c + Vector2(0, r * 0.66), r / PS.RW_R, 0.0, Color(1, 1, 1, appear))

## 奖励物品：依次弹到台座上，落地后轻轻浮动；右下角是数量签，名字在台座下方淡入。
static func _pop_reward(parent: Control, id: String, count: int, at: Vector2, slot: float, k: int, n: int, name_w: float, show_name: bool) -> void:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.position = at - Vector2(slot, slot) * 0.5
	holder.size = Vector2(slot, slot)
	holder.pivot_offset = holder.size * 0.5
	holder.scale = Vector2.ZERO
	parent.add_child(holder)
	var icon := UI.icon(holder, id, Vector2(slot, slot) * 0.5 + Vector2(0, -slot * 0.06), slot * 0.86)
	var name_lbl: Label = null
	if count > 0:
		var bfs := 30 if n == 1 else (26 if n <= 3 else 22)
		var text := "×%d" % count
		var tw_px := float(text.length()) * bfs * 0.62
		if G.font_title:
			tw_px = G.font_title.get_string_size(TextCatalog.resolve(text), HORIZONTAL_ALIGNMENT_LEFT, -1, bfs).x
		var bw := tw_px + 26.0
		var bh := bfs + 16.0
		var badge := Rect2(slot * 0.5 + slot * 0.16, slot * 0.66 - bh * 0.5, bw, bh)
		badge.position.x = minf(badge.position.x, slot + 6.0 - bw)
		UI.box(holder, badge, func(ci, sz):
			Sprites.draw(ci, "pop_rw_badge", Rect2(Vector2(3, 3), sz - Vector2(6, 6))))
		UI.lbl(holder, text, badge, bfs, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 0, Art.INK, true)
	if show_name and Data.is_known(id):
		var nfs := 34 if n == 1 else 24
		name_lbl = UI.lbl(parent, Data.name_of(id), Rect2(at.x - name_w * 0.5, at.y + slot * 0.5 + 8, name_w, nfs + 14), nfs, CREAM, HORIZONTAL_ALIGNMENT_CENTER, 8, Art.INK, true)
		name_lbl.modulate.a = 0.0
	var pop := holder.create_tween()
	pop.tween_interval(0.18 + 0.09 * float(k))
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

## 底部主按钮 + 一行闪烁的小提示，等奖励弹完再淡入。返回按钮。
## y 是按钮的顶；提示写在按钮正上方
static func _footer(p: PopupBase, y: float, text: String, hint_text: String, delay: float) -> TButton:
	var take := UI.btn(p.box, Rect2(210, y, 300, 96), text, "green", Callable(), 42)
	take.modulate.a = 0.0
	var hint := UI.lbl(p.box, hint_text, Rect2(0, y - 46, 720, 40), 22, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK)
	hint.modulate.a = 0.0
	var fade := take.create_tween()
	fade.tween_interval(delay)
	fade.tween_property(take, "modulate:a", 1.0, 0.25)
	fade.parallel().tween_property(hint, "modulate:a", 0.8, 0.25)
	var pulse := hint.create_tween().set_loops()
	pulse.tween_interval(delay + 0.5)
	pulse.tween_property(hint, "modulate:a", 0.35, 0.7)
	pulse.tween_property(hint, "modulate:a", 0.8, 0.7)
	take.pressed.connect(func():
		if p.on_tap.is_valid():
			p.on_tap.call())
	return take

static func _animate(p: PopupBase, stage: DrawBox) -> void:
	var redraw := Timer.new()
	redraw.wait_time = 0.033
	redraw.autostart = true
	p.add_child(redraw)
	redraw.timeout.connect(stage.queue_redraw)

static func _back_ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 + 2.70158 * pow(x - 1.0, 3.0) + 1.70158 * pow(x - 1.0, 2.0)

# ---------------------------------------------------------------- 升级

## 升级领奖：横幅标题、弹出的等级星、台座上的奖励，底部「收下」。
static func levelup() -> PopupBase:
	var p := PopupBase.new()
	p.dim_alpha = 0.86
	## 全屏领奖：新手引导和一次性提示看到它会先让开
	p.set_meta("reward_screen", true)
	var rewards := Data.level_rewards(G.level)
	var n := rewards.size()
	var slot := 186.0 if n == 1 else (150.0 if n <= 3 else 116.0)
	var gap_x := minf(slot + 44.0, 620.0 / float(maxi(n, 1)))
	var row_y := 830.0
	var spots: Array[Vector2] = []
	for k in n:
		spots.append(Vector2(360.0 + (float(k) - float(n - 1) * 0.5) * gap_x, row_y))
	var star := Vector2(360, 500)
	var br := Rect2(150, 236, 420, 96)
	var t0 := Time.get_ticks_msec()
	var stage := UI.box(p.box, FULL, func(ci, _sz):
		_paint_stage(ci, float(Time.get_ticks_msec() - t0) / 1000.0, star, spots, slot, br, RED_CLOTH))
	UI.title(p.box, TextCatalog.source("ui.rewardpopups.d1561ba802e8"), Rect2(br.position.x + 40, br.position.y + 4, br.size.x - 80, br.size.y - 10), 46, CREAM)
	# 等级星：弹出，之后轻轻呼吸
	var badge := Control.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.size = Vector2(260, 260)
	badge.position = star - badge.size * 0.5
	badge.pivot_offset = badge.size * 0.5
	badge.scale = Vector2.ZERO
	p.box.add_child(badge)
	UI.box(badge, Rect2(Vector2.ZERO, badge.size), func(ci, sz): Paint.level_badge(ci, sz * 0.5, 230))
	UI.lbl(badge, str(G.level), Rect2(30, 70, 200, 130), 92, CREAM, HORIZONTAL_ALIGNMENT_CENTER, 16, Art.INK, true)
	var grow := badge.create_tween()
	grow.tween_interval(0.05)
	grow.tween_property(badge, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	grow.tween_callback(func():
		var breathe := badge.create_tween().set_loops()
		breathe.tween_property(badge, "scale", Vector2.ONE * 1.04, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		breathe.tween_property(badge, "scale", Vector2.ONE, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT))
	for k in n:
		_pop_reward(p.box, str(rewards[k][0]), int(rewards[k][1]), spots[k], slot, k, n, gap_x, n <= 4)
	var by := row_y + slot * 0.5 + (120.0 if n <= 4 else 70.0)
	_footer(p, by, TextCatalog.source("ui.cardrewardpresentation.52251aeea31a"), TextCatalog.source("ui.rewardpopups.4296c369fe48"), 0.35 + 0.09 * float(n))
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
			RewardPresenter.present(got, func(k): return spots[k] if k < spots.size() else Vector2(360, row_y))
		p.on_tap = Callable()
		if G.rules.onboarding.active():
			p.tree_exited.connect(func(): G.main.open("orders_start"))
		p.close()
	_animate(p, stage)
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
	var stage := UI.box(p.box, FULL, func(ci, _sz):
		_paint_stage(ci, float(Time.get_ticks_msec() - t0) / 1000.0, glow, spots, slot, br, RED_CLOTH))
	UI.title(p.box, TextCatalog.source("ui.rewardpopups.f4d84602920a"), Rect2(br.position.x + 40, br.position.y + 4, br.size.x - 80, br.size.y - 10), 46, CREAM)
	for k in n:
		_pop_reward(p.box, str(entries[k]["id"]), int(entries[k]["n"]), spots[k], slot, k, n, gap_x, show_name)
	var by := clampf(grid_bottom + 66.0, 1200.0, 1290.0)
	_footer(p, by, TextCatalog.source("ui.cardrewardpresentation.52251aeea31a"), TextCatalog.source("ui.rewardpopups.4296c369fe48"), 0.3 + 0.09 * float(n))
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
	p.tree_exiting.connect(func(): give.call(false))
	_animate(p, stage)
	return p

# ---------------------------------------------------------------- 新道具 / 道具升级

## 拿到第一个能生产的道具，或道具升到能产出新东西的一级时弹出。
## 画面：横幅标题 → 台座上的道具（升级时旧的一缩、新的一弹）→ 名字和等级签 → 「能产出」一排产物（没见过的盖「新」章）→ 按钮。
static func new_generator(id: String) -> PopupBase:
	var st := Data.gen_stats(id)
	if st.is_empty():
		return null
	var lvl := Data.lv(id)
	var prev := "%s_%d" % [Data.chain(id), lvl - 1]
	var upgrade := lvl > 1 and not Data.gen_stats(prev).is_empty()
	var old_ids := {}
	if upgrade:
		for d in Data.gen_stats(prev).get("drops", []):
			old_ids[str(d["id"])] = true
	# 产物：没见过的优先，最多 5 件，保持原来的顺序
	var all: Array = []
	for d in st.get("drops", []):
		var pid := str(d["id"])
		if pid != "" and not all.has(pid):
			all.append(pid)
	var fresh := func(pid: String) -> bool: return not G.discovered.has(pid) and not old_ids.has(pid)
	var keep: Array = all.filter(func(pid): return fresh.call(pid)).slice(0, 5)
	for pid in all:
		if keep.size() >= 5: break
		if not keep.has(pid): keep.append(pid)
	var prods: Array = all.filter(func(pid): return keep.has(pid))
	var n := prods.size()

	var p := PopupBase.new()
	p.dim_alpha = 0.86
	p.set_meta("reward_screen", true)
	var br := Rect2(150, 236, 420, 96)
	var hero := Vector2(360, 520)
	var hero_slot := 240.0
	var slot := 150.0 if n <= 3 else 116.0
	var gap_x := minf(slot + 52.0, 640.0 / float(maxi(n, 1)))
	var row_y := 962.0
	var spots: Array[Vector2] = []
	for k in n:
		spots.append(Vector2(360.0 + (float(k) - float(n - 1) * 0.5) * gap_x, row_y))
	var t_hero := 0.55 if upgrade else 0.1
	var t_row := t_hero + 0.35
	var t0 := Time.get_ticks_msec()
	var stage := UI.box(p.box, FULL, func(ci, _sz):
		var t := float(Time.get_ticks_msec() - t0) / 1000.0
		_paint_stage(ci, t, hero, [], slot, br, RED_CLOTH)
		_paint_plate(ci, hero, hero_slot, clampf((t - 0.05) / 0.3, 0.0, 1.0), t * 0.4)
		for k in n:
			_paint_plate(ci, spots[k], slot, clampf((t - t_row - 0.09 * float(k)) / 0.3, 0.0, 1.0), t * 0.5 + float(k)))
	UI.title(p.box, TextCatalog.source("ui.rewardpopups.c9682466d406") if upgrade else TextCatalog.source("ui.rewardpopups.0689b5c65594"), Rect2(br.position.x + 40, br.position.y + 4, br.size.x - 80, br.size.y - 10), 46, CREAM)

	# 道具本身：升级时先露出上一级，一缩，再弹出新的
	var hero_box := Rect2(hero - Vector2(hero_slot, hero_slot) * 0.5, Vector2(hero_slot, hero_slot))
	var big := Control.new()
	big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	big.position = hero_box.position
	big.size = hero_box.size
	big.pivot_offset = big.size * 0.5
	big.scale = Vector2.ZERO
	p.box.add_child(big)
	var big_icon := UI.icon(big, id, big.size * 0.5 + Vector2(0, -hero_slot * 0.06), hero_slot * 0.86)
	var seq := big.create_tween()
	if upgrade:
		var old := Control.new()
		old.mouse_filter = Control.MOUSE_FILTER_IGNORE
		old.position = hero_box.position
		old.size = hero_box.size
		old.pivot_offset = old.size * 0.5
		old.scale = Vector2.ZERO
		p.box.add_child(old)
		UI.icon(old, prev, old.size * 0.5 + Vector2(0, -hero_slot * 0.06), hero_slot * 0.78)
		var out := old.create_tween()
		out.tween_property(old, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		out.tween_interval(0.12)
		out.tween_property(old, "scale", Vector2(0.2, 0.2), 0.16).set_ease(Tween.EASE_IN)
		out.parallel().tween_property(old, "modulate:a", 0.0, 0.16)
	seq.tween_interval(t_hero)
	seq.tween_callback(func(): Sfx.play("pop", 0.9))
	seq.tween_property(big, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var base_y := big_icon.position.y
	seq.tween_callback(func():
		if not is_instance_valid(big_icon):
			return
		var bob := big_icon.create_tween().set_loops()
		bob.tween_property(big_icon, "position:y", base_y - 8.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bob.tween_property(big_icon, "position:y", base_y + 2.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT))

	# 名字 + 等级签
	var name_lbl := UI.lbl(p.box, Data.name_of(id), Rect2(60, hero.y + hero_slot * 0.5 + 18, 600, 56), 42, CREAM, HORIZONTAL_ALIGNMENT_CENTER, 10, Art.INK, true)
	var chip_text := TextCatalog.fill(TextCatalog.source("ui.rewardpopups.b1f621272c9a") if upgrade else TextCatalog.source("ui.rewardpopups.7e0e60a0eb15"), lvl)
	var chip_fs := 26
	var chip_w := float(chip_text.length()) * chip_fs
	if G.font_title:
		chip_w = G.font_title.get_string_size(TextCatalog.resolve(chip_text), HORIZONTAL_ALIGNMENT_LEFT, -1, chip_fs).x
	chip_w += 44.0
	var chip := Rect2(360.0 - chip_w * 0.5, name_lbl.position.y + 64, chip_w, 44)
	var chip_col := Art.MOSS if upgrade else Color("8a5a30")
	var chip_box := UI.box(p.box, chip, func(ci, sz):
		Sprites.draw(ci, "pop_tag_base", Rect2(Vector2.ZERO, sz))
		Sprites.draw(ci, "pop_tag_fill", Rect2(Vector2.ZERO, sz), chip_col))
	var chip_lbl := UI.lbl(p.box, chip_text, chip, chip_fs, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK, true)
	for c: Control in [name_lbl, chip_box, chip_lbl]:
		c.modulate.a = 0.0
		var fade := c.create_tween()
		fade.tween_interval(t_hero + 0.2)
		fade.tween_property(c, "modulate:a", 1.0, 0.25)

	# 能产出
	var sec := Control.new()
	sec.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sec.size = Vector2(720, 60)
	sec.modulate.a = 0.0
	p.box.add_child(sec)
	Popups.section(sec, TextCatalog.source("ui.rewardpopups.15ff947c1097") if upgrade else TextCatalog.source("ui.rewardpopups.c06a76d5834d"), row_y - slot * 0.5 - 76.0, GOLD)
	var sec_in := sec.create_tween()
	sec_in.tween_interval(t_row - 0.1)
	sec_in.tween_property(sec, "modulate:a", 0.9, 0.25)
	for k in n:
		var pid := str(prods[k])
		_pop_product(p.box, pid, spots[k], slot, gap_x, t_row + 0.09 * float(k), k, fresh.call(pid))

	var by := row_y + slot * 0.5 + 110.0
	_footer(p, by, TextCatalog.source("ui.rewardpopups.536edaf7cdd1"), TextCatalog.source("ui.rewardpopups.05d840dae009"), t_row + 0.2 + 0.09 * float(n))
	Sfx.play("fanfare")
	p.on_tap = func():
		p.on_tap = Callable()
		p.close()
	_animate(p, stage)
	return p

## 一件产物：在台座上弹出，名字淡入，没见过的右上角盖一枚「新」章。
static func _pop_product(parent: Control, id: String, at: Vector2, slot: float, name_w: float, delay: float, k: int, is_new: bool) -> void:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.position = at - Vector2(slot, slot) * 0.5
	holder.size = Vector2(slot, slot)
	holder.pivot_offset = holder.size * 0.5
	holder.scale = Vector2.ZERO
	parent.add_child(holder)
	var icon := UI.icon(holder, id, Vector2(slot, slot) * 0.5 + Vector2(0, -slot * 0.08), slot)
	if is_new:
		var seal_c := Vector2(slot * 0.86, slot * 0.12)
		var sr := 30.0 if slot > 130.0 else 25.0
		UI.box(holder, Rect2(seal_c - Vector2(sr, sr), Vector2(sr, sr) * 2.0), func(ci, sz):
			Sprites.at(ci, "pop_seal", sz * 0.5, sr / 36.0))
		var nl := UI.lbl(holder, TextCatalog.source("ui.rewardpopups.3cc493bc5b3b"), Rect2(seal_c - Vector2(sr, sr), Vector2(sr, sr) * 2.0), int(sr * 0.8), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 5, Art.INK, true)
		nl.pivot_offset = nl.size * 0.5
		nl.rotation = -0.18
	var name_fs := 24 if slot > 130.0 else 22
	var name_lbl := UI.lbl(parent, Data.name_of(id), Rect2(at.x - name_w * 0.5, at.y + slot * 0.5 + 6, name_w, name_fs + 14), name_fs, CREAM, HORIZONTAL_ALIGNMENT_CENTER, 7, Art.INK, true)
	name_lbl.clip_text = true
	name_lbl.modulate.a = 0.0
	var pop := holder.create_tween()
	pop.tween_interval(delay)
	pop.tween_callback(func(): Sfx.play("pop", 1.0 + 0.08 * float(k)))
	pop.tween_property(holder, "scale", Vector2.ONE, 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.parallel().tween_property(name_lbl, "modulate:a", 1.0, 0.25).set_delay(0.12)
	var base_y := icon.position.y
	var period := 0.8 + 0.07 * float(k % 3)
	pop.tween_callback(func():
		if not is_instance_valid(icon):
			return
		var bob := icon.create_tween().set_loops()
		bob.tween_property(icon, "position:y", base_y - 5.0, period).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bob.tween_property(icon, "position:y", base_y + 2.0, period).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT))

## 主角等级面板（版式，从上往下）：
##   面板顶上压一条标题横幅，横幅上方是当前等级星；
##   插画铺满面板宽度（只留面板边框），阿焰站在部落前面，下沿把他的下半身裁掉；
##   插画下面直接在面板底色上：两行说明 → 进度条（左边大经验星，右边下一级星，绿箭头贴星的右下角）；
##   「下一级奖励」小标题 → 一条矮奖励栏，里面一排图标。
## （新手引导时说明和进度条那块会被引导框圈出来，面板自己不再加底色）
const LI_PANEL := Rect2(36, 260, 648, 910)
const LI_ART_H := 480.0
const LI_INFO_H := 120.0
const LI_STRIP_H := 132.0
const LI_XP_STAR := 100.0
const LI_NEXT_BADGE := 80.0

static func _li_art() -> Rect2:
	return Rect2(LI_PANEL.position.x + 18, LI_PANEL.position.y + 18, LI_PANEL.size.x - 36, LI_ART_H)

## 说明 + 进度条那块（引导高亮用的也是它）
static func _li_card() -> Rect2:
	var art := _li_art()
	return Rect2(LI_PANEL.position.x + 34, art.end.y + 8, LI_PANEL.size.x - 68, LI_INFO_H)

## 奖励栏：小标题在它上面 46px 处，留开不压边
static func _li_strip() -> Rect2:
	var card := _li_card()
	return Rect2(card.position.x + 20, card.end.y + 72, card.size.x - 40, LI_STRIP_H)

## 插画：清晨的天、太阳和云，两层远山，一排林梢，草地；左边草屋，右边棕榈。位置都按画框比例算。
static func _level_scene(ci: CanvasItem, art: Rect2) -> void:
	var w := art.size.x
	var h := art.size.y
	var o := art.position
	Paint.vgrad(ci, art, Color("94d3e0"), Color("fde3ac"))
	var sun := o + Vector2(w * 0.72, h * 0.2)
	for k in 3:
		ci.draw_circle(sun, 96.0 - 20.0 * k, Color(1.0, 0.95, 0.75, 0.16 + 0.1 * k))
	ci.draw_circle(sun, 44.0, Color("fff3c4"))
	for cl in [[o + Vector2(w * 0.2, h * 0.16), 1.1], [o + Vector2(w * 0.9, h * 0.1), 0.9], [o + Vector2(w * 0.5, h * 0.07), 0.7]]:
		var c: Vector2 = cl[0]
		var k: float = cl[1]
		for bb in [[Vector2(-34, 6), 26.0], [Vector2(0, -6), 32.0], [Vector2(36, 6), 24.0], [Vector2(4, 12), 28.0]]:
			ci.draw_colored_polygon(Art.ell(c + (bb[0] as Vector2) * k, Vector2(float(bb[1]) * 1.25, float(bb[1]) * 0.8) * k, 41, 0.05, 16), Color(1, 1, 1, 0.88))
	Paint.far_range(ci, o.y + h * 0.5, 720, h * 0.16, 3, Color("b3d5c6"), art.end.y)
	Paint.far_range(ci, o.y + h * 0.57, 720, h * 0.1, 8, Color("8fbe94"), art.end.y)
	Paint.treeline(ci, o.y + h * 0.64, 720, 5, Color("5b9353"), art.end.y)
	var field := PackedVector2Array()
	for k in 25:
		field.append(Vector2(o.x - 10.0 + (w + 20.0) * float(k) / 24.0, o.y + h * 0.63 + 7.0 * sin(float(k) * 0.9)))
	field.append(Vector2(art.end.x + 10, art.end.y + 10))
	field.append(Vector2(o.x - 10, art.end.y + 10))
	ci.draw_colored_polygon(field, Color("a5c96c"))
	ci.draw_colored_polygon(Art.ell(o + Vector2(w * 0.5, h * 0.9), Vector2(w * 0.42, h * 0.12), 52, 0.04, 28), Color("dcbc7c"))
	for t in [[o + Vector2(w * 0.05, h * 0.74), 1.1], [o + Vector2(w * 0.8, h * 0.7), 0.9]]:
		var c: Vector2 = t[0]
		var k: float = t[1]
		Art.fill(ci, Art.ell(c, Vector2(40, 26) * k, 61, 0.12, 16), Color("4f8f45"), 2.5)
		Art.fill(ci, Art.ell(c + Vector2(24, 8) * k, Vector2(28, 18) * k, 62, 0.12, 14), Color("62a352"), 2.5)
	Paint.palm(ci, o + Vector2(w * 0.93, h * 0.84), h * 0.6, 3, Color("4a8a4a"))
	Paint._spot_hut(ci, o + Vector2(w * 0.22, h * 0.58), 9)

static func level_info() -> PopupBase:
	var p := PopupBase.new()
	var r := LI_PANEL
	var art := _li_art()
	var card := _li_card()
	var strip := _li_strip()
	var cx := r.get_center().x
	UI.box(p.box, Rect2(0, 0, 720, 1480), func(ci, _sz): Paint.panel(ci, r))
	# 插画（裁剪框套一层；画法内部会重设变换，所以里面那层挪回屏幕原点，照屏幕坐标画）
	var clip := Control.new()
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.position = art.position
	clip.size = art.size
	clip.clip_contents = true
	p.box.add_child(clip)
	UI.box(clip, Rect2(-art.position, Vector2(720, 1480)), func(ci, _sz):
		_level_scene(ci, art)
		Paint.heroine(ci, art.position + Vector2(art.size.x * 0.56, art.size.y * 0.62), 165), false)
	# 插画四边一圈压暗的内描边，横幅、说明卡、奖励栏
	UI.box(p.box, Rect2(0, 0, 720, 1480), func(ci, _sz):
		ci.draw_rect(art, Color(0.3, 0.18, 0.08, 0.6), false, 4.0)
		Paint.banner(ci, Rect2(cx - 230, r.position.y - 30, 460, 84), Art.TEAL)
		var bar := _li_bar()
		Paint.bar(ci, bar, float(G.xp) / float(G.rules.progression.xp_need()), Art.MOSS)
		Art.item(ci, "xp_1", Vector2(bar.position.x - 4, bar.get_center().y), LI_XP_STAR)
		ShopPopups._slot(ci, strip, Color("ecd9b3"), Color(0.6, 0.4, 0.2, 0.4), true), false)
	UI.title(p.box, TextCatalog.source("developer.story_editor.34243df4d613"), Rect2(cx - 200, r.position.y - 20, 400, 60), 36, Color.WHITE)
	var tip := UI.lbl(p.box, TextCatalog.source("ui.rewardpopups.818a128bfe58"), Rect2(card.position.x + 24, card.position.y + 6, card.size.x - 48, 44), 25, Color("6b4a2a"))
	tip.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	var bar := _li_bar()
	UI.lbl(p.box, "%d/%d" % [G.xp, G.rules.progression.xp_need()], bar, 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK)
	p.set_meta("level_progress", card)
	p.set_meta("level_rewards", strip)
	p.set_meta("onboarding_close", Rect2(r.end.x - 52, r.position.y - 24, 70, 70))
	Popups.section(p.box, TextCatalog.source("ui.rewardpopups.18228135bddc"), strip.position.y - 46, Color("8a5a30"))
	var rw := Data.level_rewards(G.level + 1)
	for k in rw.size():
		var ix := ItemPopups._spread_x(k, rw.size(), cx, 150.0)
		var iy := strip.position.y + 56
		UI.icon(p.box, rw[k][0], Vector2(ix, iy), 96)
		UI.lbl(p.box, "×%d" % rw[k][1], Rect2(ix - 60, iy + 34, 120, 40), 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 7, Art.INK, true)
		var id: String = rw[k][0]
		var ib := UI.hit(p.box, Rect2(ix + 16, iy - 50, 38, 38), func(): G.main.open("item_info", id))
		ib.extra = func(ci, sz): Paint.glyph(ci, "info", sz * 0.5, 1.0)
	var x := UI.hit(p.box, Rect2(r.end.x - 52, r.position.y - 24, 70, 70), p.close)
	x.extra = func(ci, sz): Paint.close_btn(ci, sz * 0.5, 28)
	return p

## 说明卡里的进度条：左边让出灵感灯泡位置，右侧拉通
static func _li_bar() -> Rect2:
	var card := _li_card()
	return Rect2(card.position.x + 84, card.position.y + 64, card.size.x - 116, 44)

# ---------------------------------------------------------------- 丰收祭活动

## 新手引导里升完级：不盖面板。棋盘压暗，只露出左上角主角；主角冒气泡说「完成差事，攒经验升级！」，
## 下面的经验条一闪一闪。点任意处继续，气泡化成几颗星星飞到带经验的差事上。
static func orders_start() -> PopupBase:
	var p := PopupBase.new()
	p.dim_alpha = 0.0
	p.set_meta("reward_screen", true)
	var st := {"hero": Rect2(0, 230, 142, 226), "bubble": Rect2(), "bar": Rect2()}
	# 压暗层：四块拼成，中间挖出主角那一块；放在 p 上不跟着 box 缩放弹出，自己淡入淡出
	var shade := UI.box(p, FULL, func(ci, _sz):
		var h: Rect2 = (st["hero"] as Rect2).grow(8)
		var dark := Color(0.1, 0.05, 0.02, 0.62)
		ci.draw_rect(Rect2(0, 0, 720, h.position.y), dark)
		ci.draw_rect(Rect2(0, h.end.y, 720, 1480 - h.end.y), dark)
		ci.draw_rect(Rect2(0, h.position.y, h.position.x, h.size.y), dark)
		ci.draw_rect(Rect2(h.end.x, h.position.y, 720 - h.end.x, h.size.y), dark), false)
	p.move_child(shade, 1)
	shade.modulate.a = 0.0
	shade.create_tween().tween_property(shade, "modulate:a", 1.0, 0.2)
	# 经验条外圈的金色描边，呼吸闪烁
	var ring := UI.box(p.box, FULL, func(ci, _sz):
		var b: Rect2 = st["bar"]
		ci.draw_rect(b.grow(6), Color(1, 0.86, 0.35, 0.9), false, 5.0)
		ci.draw_rect(b.grow(12), Color(1, 0.86, 0.35, 0.35), false, 4.0), false)
	var rtw := ring.create_tween().set_loops()
	rtw.tween_property(ring, "modulate:a", 0.25, 0.55)
	rtw.tween_property(ring, "modulate:a", 1.0, 0.55)
	var bubble := UI.box(p.box, Rect2(), func(ci, sz): Paint.speech(ci, Rect2(Vector2.ZERO, sz), true), false)
	var title := UI.lbl(bubble, TextCatalog.source("ui.rewardpopups.14435c01c92c"), Rect2(28, 16, 400, 44), 30, Art.INK, HORIZONTAL_ALIGNMENT_LEFT, 0, Art.INK, true)
	var sub := UI.lbl(bubble, TextCatalog.source("ui.rewardpopups.807d2fcf1529"), Rect2(28, 64, 400, 34), 21, Color("7a5a3a"), HORIZONTAL_ALIGNMENT_LEFT)
	var hint := UI.lbl(p.box, TextCatalog.source("ui.guide.b0daab78b94a"), Rect2(0, 0, 400, 44), 28, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 8, Art.INK)
	var tw := hint.create_tween().set_loops()
	tw.tween_property(hint, "modulate:a", 0.35, 0.7)
	tw.tween_property(hint, "modulate:a", 1.0, 0.7)
	# 进树以后才知道主角在屏幕上的位置：按它摆气泡、描边和提示
	p.ready.connect(func():
		var inv := p.get_global_transform().affine_inverse()
		var bs = G.main.board_screen if G.main != null else null
		if bs != null and is_instance_valid(bs) and is_instance_valid(bs._base_btn) and bs._base_btn.is_visible_in_tree():
			var g: Rect2 = bs._base_btn.get_global_rect()
			var a: Vector2 = inv * g.position
			var b: Vector2 = inv * g.end
			st["hero"] = Rect2(a, b - a).abs()
		var h: Rect2 = st["hero"]
		var k := h.size.y / 226.0
		st["bar"] = Rect2(h.position + Vector2(12, 176) * k, Vector2(h.size.x - 24 * k, 24 * k))
		var bw := minf(470.0, 720.0 - 16.0 - (h.end.x + 26.0))
		var br := Rect2(h.end.x + 26.0, h.position.y + h.size.y * 0.5 - 70.0, bw, 112)
		st["bubble"] = br
		bubble.position = br.position
		bubble.size = br.size
		title.size.x = bw - 50.0
		sub.size.x = bw - 50.0
		hint.position = Vector2(br.get_center().x - 200.0, br.end.y + 18.0)
		# 从主角那里弹出来
		p.box.pivot_offset = h.get_center())
	p.on_tap = func():
		_xp_stars_to_orders(p, st["bubble"])
		shade.create_tween().tween_property(shade, "modulate:a", 0.0, 0.18)
		p.close()
	return p

## 关掉升级提示时：气泡里飞出几颗经验星，各自落到一张带经验的差事卡右上角的经验牌上
static func _xp_stars_to_orders(p: PopupBase, from: Rect2) -> void:
	if G.main == null or not is_instance_valid(G.main.board_screen) or not p.is_inside_tree():
		return
	var bs = G.main.board_screen
	var layer: Node = p.get_parent()
	if layer == null or not (layer is CanvasItem):
		return
	var inv := (layer as CanvasItem).get_global_transform().affine_inverse()
	var p_xf := p.get_global_transform()
	var origin: Vector2 = inv * (p_xf * (from.get_center() if from.size.x > 1.0 else Vector2(200, 340)))
	var targets: Array[Vector2] = []
	for oi in G.orders.size():
		var rw = G.orders[oi].get("rw", {})
		if not (rw is Dictionary) or int(rw.get("xp", 0)) <= 0:
			continue
		var r: Rect2 = bs.order_card_rect(oi)
		if r.size.x < 2.0:
			continue
		targets.append(inv * Vector2(r.end.x - 24.0, r.position.y + 22.0))
	if targets.is_empty():
		return
	var count := clampi(targets.size(), 3, 6)
	for n in count:
		var to: Vector2 = targets[n % targets.size()]
		var star := Control.new()
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		star.size = Vector2.ZERO
		star.position = origin + Vector2((Art.srnd(n * 7 + 1) - 0.5) * 120.0, (Art.srnd(n * 7 + 2) - 0.5) * 50.0)
		star.scale = Vector2(0.2, 0.2)
		star.draw.connect(func():
			star.draw_circle(Vector2.ZERO, 26.0, Color(1, 0.86, 0.4, 0.28))
			Art.item(star, "xp_1", Vector2.ZERO, 44))
		layer.add_child(star)
		var start := star.position
		var mid := (start + to) * 0.5 + Vector2(0, -140.0 - 40.0 * float(n % 2))
		var delay := 0.06 * float(n)
		var tw := star.create_tween()
		tw.tween_interval(delay)
		tw.tween_property(star, "scale", Vector2(1.15, 1.15), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_method(func(t: float):
			var u := 1.0 - t
			star.position = u * u * start + 2.0 * u * t * mid + t * t * to
			star.rotation = t * TAU * 0.5, 0.0, 1.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_callback(func(): Sfx.play("pop", 1.0 + 0.08 * float(n)))
		tw.tween_property(star, "scale", Vector2(1.6, 1.6), 0.08)
		tw.parallel().tween_property(star, "modulate:a", 0.0, 0.22)
		tw.tween_callback(star.queue_free)

static func onboarding_rescue() -> PopupBase:
	var p := PopupBase.new()
	p.set_meta("reward_screen", true)
	var reward: Array = G.rules.onboarding.config()["rescue"]["reward"]
	# 和其它领奖页同一套：慢转的光芒 + 发光台座，奖励在台座上轻轻浮动，主角在旁边探头
	var t0 := Time.get_ticks_msec()
	var stage := UI.box(p.box, Rect2(0, 0, 720, 1480), func(ci, _sz):
		var t := float(Time.get_ticks_msec() - t0) / 1000.0
		var c := Vector2(360, 680)
		for k in 14:
			var a := t * 0.25 + TAU * float(k) / 14.0
			ci.draw_polygon(PackedVector2Array([c + Vector2(cos(a), sin(a)) * 40.0,
				c + Vector2(cos(a - 0.1), sin(a - 0.1)) * 400.0, c + Vector2(cos(a + 0.1), sin(a + 0.1)) * 400.0]),
				PackedColorArray([Color(1, 0.88, 0.5, 0.24), Color(1, 0.88, 0.5, 0.0), Color(1, 0.88, 0.5, 0.0)]))
		for j in 4:
			ci.draw_circle(c, 120.0 * (1.0 - 0.13 * float(j)), Color(1, 0.9, 0.55, 0.06))
		Sprites.at(ci, "pop_rw_plate", c + Vector2(0, 92), 140.0 / PS.RW_R)
		Art.item(ci, str(reward[0]), c + Vector2(0, sin(t * 2.4) * 7.0), 180)
		Paint.bust(ci, Vector2(104, 1046), 100), false)
	var redraw := Timer.new()
	redraw.wait_time = 0.033
	redraw.autostart = true
	p.add_child(redraw)
	redraw.timeout.connect(stage.queue_redraw)
	UI.title(p.box, TextCatalog.source("ui.rewardpopups.2fc1d6a44679"), Rect2(0, 360, 720, 110), 54)
	UI.lbl(p.box, TextCatalog.fill(TextCatalog.source("ui.rewardpopups.51f1d25fd68d"), int(reward[1])), Rect2(0, 812, 720, 64), 38, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 8, Art.INK)
	p.on_tap = func():
		var result: Dictionary = Replay.perform("onboarding_rescue")
		if result.has("error"): return
		RewardPresenter.present(result["rewards"], func(_k): return Vector2(360, 680))
		p.on_tap = Callable()
		p.close()
	UI.btn(p.box, Rect2(210, 1030, 300, 100), TextCatalog.source("ui.rewardpopups.1a9195bf2ec1"), "green", func(): if p.on_tap.is_valid(): p.on_tap.call(), 38)
	return p
