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
	var chip_text := (TextCatalog.source("ui.rewardpopups.b1f621272c9a") if upgrade else TextCatalog.source("ui.rewardpopups.7e0e60a0eb15")) % lvl
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

static func level_info() -> PopupBase:
	var p := PopupBase.new()
	var r := Rect2(40, 250, 640, 1010)
	UI.box(p.box, Rect2(0, 0, 720, 1480), func(ci, _sz):
		Paint.panel(ci, r)
		var br := Rect2(r.get_center().x - 220, r.position.y + 30, 440, 80)
		Paint.banner(ci, br, Art.TEAL)
		Paint.level_badge(ci, Vector2(r.get_center().x, r.position.y - 14), 120)
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
	UI.title(p.box, TextCatalog.source("developer.story_editor.34243df4d613"), Rect2(r.get_center().x - 200, r.position.y + 50, 400, 60), 38, Color.WHITE)
	UI.lbl(p.box, str(G.level), Rect2(r.get_center().x - 60, r.position.y - 54, 120, 80), 44, Color("fff1c4"), HORIZONTAL_ALIGNMENT_CENTER, 10, Art.INK, true)
	var tip := UI.lbl(p.box, TextCatalog.source("ui.rewardpopups.818a128bfe58"), Rect2(r.position.x + 40, r.position.y + 446, r.size.x - 80, 90), 25, Color("6b4a2a"))
	tip.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	UI.lbl(p.box, "%d/%d" % [G.xp, G.rules.progression.xp_need()], Rect2(r.position.x + 70, r.position.y + 560, 400, 44), 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK)
	UI.lbl(p.box, str(G.level + 1), Rect2(r.position.x + 500, r.position.y + 552, 80, 60), 32, Color("fff1c4"), HORIZONTAL_ALIGNMENT_CENTER, 8, Art.INK, true)
	p.set_meta("level_progress", Rect2(80, 790, 560, 100))
	p.set_meta("level_rewards", Rect2(80, 920, 560, 280))
	p.set_meta("onboarding_close", Rect2(r.end.x - 52, r.position.y - 24, 70, 70))
	UI.lbl(p.box, TextCatalog.source("ui.rewardpopups.60b51c111d6e"), Rect2(80, 1160, 560, 38), 21, Color("7a5a3a"))
	Popups.section(p.box, TextCatalog.source("ui.rewardpopups.18228135bddc"), r.position.y + 640, Color("8a5a30"))
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

## 新手引导里升完级：一张小木牌告诉玩家现在几级、声望攒到哪了，点任意处继续。
static func orders_start() -> PopupBase:
	var p := PopupBase.new()
	p.dim_alpha = 0.72
	p.set_meta("reward_screen", true)
	var need: int = maxi(1, G.rules.progression.xp_need())
	var r := Rect2(90, 560, 540, 330)
	var br := Rect2(160, r.position.y - 48, 400, 96)
	var badge := Vector2(r.position.x + 116, r.position.y + 156)
	var bar := Rect2(r.position.x + 210, r.position.y + 150, 290, 44)
	UI.box(p.box, FULL, func(ci, _sz):
		Paint.panel(ci, r)
		Paint.banner(ci, br, RED_CLOTH)
		Paint.level_badge(ci, badge, 150)
		Paint.bar(ci, bar, float(G.xp) / float(need), Art.MOSS))
	UI.title(p.box, TextCatalog.source("ui.rewardpopups.14435c01c92c"), Rect2(br.position.x + 30, br.position.y + 4, br.size.x - 60, br.size.y - 10), 44, CREAM)
	UI.lbl(p.box, str(G.level), Rect2(badge.x - 60, badge.y - 40, 120, 80), 52, CREAM, HORIZONTAL_ALIGNMENT_CENTER, 10, Art.INK, true)
	UI.lbl(p.box, TextCatalog.fill(TextCatalog.source("ui.rewardpopups.cfd127110aa7"), G.level), Rect2(bar.position.x, bar.position.y - 50, bar.size.x, 44), 26, Color("6b4a2a"), HORIZONTAL_ALIGNMENT_LEFT)
	UI.lbl(p.box, "%d/%d" % [G.xp, need], bar, 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK)
	UI.lbl(p.box, TextCatalog.source("ui.rewardpopups.807d2fcf1529"), Rect2(r.position.x + 30, r.position.y + 222, r.size.x - 60, 44), 24, Color("7a5a3a"))
	var hint := UI.lbl(p.box, TextCatalog.source("ui.guide.b0daab78b94a"), Rect2(0, r.end.y + 34, 720, 50), 28, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 8, Art.INK)
	var tw := hint.create_tween().set_loops()
	tw.tween_property(hint, "modulate:a", 0.35, 0.7)
	tw.tween_property(hint, "modulate:a", 1.0, 0.7)
	p.on_tap = p.close
	return p

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
