class_name ProgressionPopups
extends RefCounted
const Layout := preload("res://scripts/config/board_layout.gd")
const PS := preload("res://scripts/sprites/popups.gd")

## 建造面板：只展示下一次要建的那件部件——大图是这次建完后的样子（没建满时是搭着脚手架的半成品），
## 下面是这件的进度格、落成奖励和价格。
static func build(id: String) -> PopupBase:
	var d := Data.build_def(id)
	if d.is_empty():
		return null
	var pr = G.rules.progression
	var parts := Data.build_parts(d)
	var total := parts.size()
	var st := clampi(int(G.builds.get(id, 0)), 0, total)
	var p := PopupBase.new()
	var done := st >= total
	var open: bool = pr.build_open(id)
	var r := Rect2(40, 330, 640, 880)
	Popups.frame(p, r, str(d.get("name", id)), Color("4f8fc0"))
	var line_name := ""
	for l in Data.LINES:
		if str(l.get("id", "")) == str(d.get("line", "")):
			line_name = str(l.get("name", ""))
	var prog: Dictionary = pr.build_progress(id)
	var sub := TextCatalog.fill(TextCatalog.source("ui.progressionpopups.57ac2277a313"), [int(prog["done"]), int(prog["total"])])
	if line_name != "":
		sub = "%s · %s" % [line_name, sub]
	UI.box(p.box, Rect2(190, r.position.y + 54, 340, 40), func(ci, sz):
		Sprites.draw(ci, "pop_pill20", Rect2(Vector2.ZERO, sz), Color(0.6, 0.45, 0.25, 0.25)))
	UI.lbl(p.box, sub, Rect2(190, r.position.y + 54, 340, 40), 22, Color("7a5a3a"))
	# 这次要建的是哪一件、建完是第几次
	var t: int = total - 1 if done else (pr.build_target(id) if open else st)
	t = clampi(t, 0, maxi(total - 1, 0))
	var part: Dictionary = parts[t] if total > 0 and parts[t] is Dictionary else {}
	var kind := str(part.get("id", ""))
	var steps := Data.part_steps(part)
	var have: int = steps if done else pr.part_step(id, t)
	var after := mini(have + (0 if done or not open else 1), steps)
	var frac := float(after) / float(steps)
	# 大图：暖色小场景里站着这件部件，后面一圈柔光
	var stage := Rect2(r.position.x + 40, r.position.y + 112, r.size.x - 80, 330)
	var t0 := Time.get_ticks_msec()
	var show := UI.box(p.box, stage, func(ci, sz):
		var full := Rect2(Vector2.ZERO, sz)
		ShopPopups._slot(ci, full, Color("f3e3bf"), Color(0.6, 0.4, 0.2, 0.35), true)
		Paint.vgrad(ci, full.grow(-6), Color("cfe6d8"), Color("f1deb3"))
		var ground := Vector2(sz.x * 0.5, sz.y - 46)
		ci.draw_colored_polygon(Art.ell(ground + Vector2(0, 8), Vector2(sz.x * 0.42, 34), 3, 0.0, 28), Color("d9b77c"))
		var glow := 0.5 + 0.5 * sin(float(Time.get_ticks_msec() - t0) / 600.0)
		for k in 5:
			ci.draw_circle(ground + Vector2(0, -110), 150.0 - k * 24.0, Color(1, 0.95, 0.7, (0.06 + 0.03 * glow) if open and not done else 0.04))
		Sprites.at(ci, "pop_spot_shadow", ground + Vector2(0, 4), 3.0, 0.0, Color(0, 0, 0, 0.12))
		TribeArt.icon(ci, kind, Rect2(sz.x * 0.5 - 200, 26, 400, sz.y - 52), not open and not done, frac, 2.6))
	var pulse := Timer.new()
	pulse.wait_time = 0.05
	pulse.autostart = true
	p.add_child(pulse)
	pulse.timeout.connect(show.queue_redraw)
	# 部件名字 + 进度格（建过的绿色、这次要建的金色、之后的空格）
	var name_y := stage.end.y + 14
	UI.lbl(p.box, TextCatalog.resolve(str(part.get("name", kind))), Rect2(r.position.x, name_y, r.size.x, 52), 36, Color("6b4a2a"), HORIZONTAL_ALIGNMENT_CENTER, 0, Art.INK, true)
	var pips_y := name_y + 72
	if steps > 1:
		UI.box(p.box, Rect2(r.position.x, pips_y - 20, r.size.x, 40), func(ci, sz):
			var gap := 44.0
			for k in steps:
				var c := Vector2(sz.x * 0.5 + (float(k) - float(steps - 1) * 0.5) * gap, 20)
				var built := k < have
				var now := k == have and open and not done
				ci.draw_circle(c, 15, Art.INK)
				ci.draw_circle(c, 12, Color("8fc04a") if built else (Color("ffd23f") if now else Color("e8d6b0")))
				if built: Paint.check_mark(ci, c, 0.55)
				if k < steps - 1: ci.draw_line(c + Vector2(16, 0), c + Vector2(gap - 16, 0), Color(0.42, 0.29, 0.16, 0.5), 3.0))
	# 落成奖励
	var box := Rect2(r.position.x + 36, pips_y + 36, r.size.x - 72, 150)
	UI.box(p.box, box, func(ci, sz):
		ShopPopups._slot(ci, Rect2(Vector2.ZERO, sz), Color("ecd9b3"), Color(0.6, 0.4, 0.2, 0.3), true))
	var rewards: Array = pr.build_piece_rewards(id) if open and not done else []
	var cost: int = pr.build_cost(id)
	if done:
		UI.lbl(p.box, TextCatalog.source("ui.progressionpopups.3ccc5138b117"), Rect2(box.position.x, box.position.y + 50, box.size.x, 50), 28, Color("6b4a2a"))
	elif not open and pr.build_blocker(id) != "" and pr.feature_unlocked(Data.build_unlock(d)):
		UI.lbl(p.box, TextCatalog.fill(TextCatalog.source("ui.progressionpopups.1a8b38a4cc36"), TextCatalog.resolve(str(Data.build_def(pr.build_blocker(id)).get("name", "")))), Rect2(box.position.x, box.position.y + 50, box.size.x, 50), 28, Color("6b4a2a"))
	elif not open:
		UI.lbl(p.box, TextCatalog.fill(TextCatalog.source("ui.progressionpopups.b8b2658befb0"), [Data.build_unlock(d), str(d.get("name", id))]), Rect2(box.position.x, box.position.y + 30, box.size.x, 50), 28, Color("6b4a2a"))
		UI.lbl(p.box, TextCatalog.fill(TextCatalog.source("ui.progressionpopups.9be6e988d0a4"), line_name) if line_name != "" else "", Rect2(box.position.x, box.position.y + 80, box.size.x, 40), 20, Color("8a6a4a"))
	else:
		var left := steps - after
		var head := TextCatalog.fill(TextCatalog.source("ui.progressionpopups.5c6a82c70419"), str(part.get("name", ""))) if left == 0 else TextCatalog.fill(TextCatalog.source("ui.progressionpopups.7cc2116641b8"), [left, TextCatalog.resolve(str(part.get("name", "")))])
		UI.lbl(p.box, head, Rect2(box.position.x, box.position.y + 6, box.size.x, 36), 22, Color("7a5a3a"))
		if rewards.is_empty():
			UI.lbl(p.box, TextCatalog.source("ui.progressionpopups.b537971039cc"), Rect2(box.position.x, box.position.y + 60, box.size.x, 50), 26, Color("6b4a2a"))
		var icon_s := 84.0 if rewards.size() <= 3 else 70.0
		for k in rewards.size():
			var c := Vector2(ItemPopups._spread_x(k, rewards.size(), box.get_center().x, 140.0), box.position.y + 84)
			var ic := UI.icon(p.box, str(rewards[k][0]), c, icon_s)
			var n_lbl := UI.lbl(p.box, "×%d" % int(rewards[k][1]), Rect2(c.x - 10, c.y + 14, 90, 36), 24, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 6, Art.INK)
			if left > 0:
				ic.modulate.a = 0.6
				n_lbl.modulate.a = 0.6
	var label := TextCatalog.source("ui.progressionpopups.c7161add6832") if done else ((TextCatalog.fill(TextCatalog.source("ui.homescreen.1f67da2b53a5"), Data.build_unlock(d)) if not pr.feature_unlocked(Data.build_unlock(d)) else TextCatalog.source("ui.progressionpopups.d82d79ae2707")) if not open else str(cost))
	var b := UI.btn(p.box, Rect2(r.get_center().x - 160, box.end.y + 22, 320, 100), label, "green" if open and not done else "grey", Callable(), 44)
	if open and not done:
		b.res = "shell_2"
	b.enabled = open and not done
	p.set_meta("build_rects", [Rect2(b.position, b.size)])
	b.pressed.connect(_buy_build.bind(p, id, b))
	return p

# ---------------------------------------------------------------- 图鉴

## Compact region map opened after the first three construction stages.
static func region_map() -> PopupBase:
	var p := PopupBase.new()
	Popups.frame(p, Rect2(40, 260, 640, 1000), TextCatalog.source("ui.progressionpopups.45b03cb6af96"), Art.TEAL)
	for k in Data.BUILDS.size():
		var d: Dictionary = Data.BUILDS[k]
		var id := str(d["id"])
		var rect := Rect2(64 + (k % 2) * 302, 340 + (k / 2) * 218, 288, 202)
		var open := G.rules.progression.build_open(id)
		var tile := UI.btn(p.box, rect, "", "hide", func():
			p.close()
			G.main.open("build", id))
		# 每块地一张卡：开放的是暖色卡 + 建设进度条，没开放的灰卡 + 锁和开放等级
		var prog: Dictionary = G.rules.progression.build_progress(id)
		var built := int(prog["done"])
		var stages := maxi(int(prog["total"]), 1)
		var done := built >= stages
		tile.extra = func(ci, sz):
			var full := Rect2(Vector2.ZERO, sz)
			Sprites.draw(ci, "pop_card18_base", full)
			Sprites.draw(ci, "pop_card18_fill", full, (Color("7fb43a") if done else Color("e0a24a")) if open else Color("a39a8c"))
			var ir := Rect2(7, 7, sz.x - 14, 118)
			Sprites.draw(ci, "pop_inner14", ir, Art.BONE if open else Color("e4ddd0"))
			Sprites.at(ci, "pop_spot_shadow", Vector2(sz.x * 0.5, 112), 1.4, 0.0, Color(0, 0, 0, 0.1))
			var parts := Data.build_parts(d)
			if not parts.is_empty(): TribeArt.icon(ci, str(parts[0]["id"]), Rect2(64, 10, sz.x - 128, 110), not open)
			if not open:
				ci.draw_circle(Vector2(sz.x - 32, 32), 20, Color(0, 0, 0, 0.25))
				Paint.glyph(ci, "lock", Vector2(sz.x - 32, 30), 0.8)
			elif done:
				Paint.check_mark(ci, Vector2(sz.x - 30, 30), 0.8)
			else:
				Paint.bar(ci, Rect2(16, 166, sz.x - 32, 22), float(built) / float(stages), Art.MOSS)
		UI.lbl(tile, str(d["name"]), Rect2(4, 128, rect.size.x - 8, 34), 25, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK)
		var info := TextCatalog.fill(TextCatalog.source("ui.progressionpopups.667da42b1672"), [built, stages]) if open else (TextCatalog.fill(TextCatalog.source("ui.homescreen.1f67da2b53a5"), Data.build_unlock(d)) if not G.rules.progression.feature_unlocked(Data.build_unlock(d)) else TextCatalog.source("ui.progressionpopups.bf9a2e890609"))
		UI.lbl(tile, info, Rect2(4, 162, rect.size.x - 8, 30), 18 if open and not done else 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 5, Art.INK)
	return p

static func _buy_build(p: PopupBase, id: String, button: TButton) -> void:
	if not button.enabled or p._closing or G.main.home.is_building(): return
	if G.shells < G.rules.progression.build_cost(id):
		Sfx.play("deny")
		G.main.toast(TextCatalog.source("ui.progressionpopups.e9d4961d0095"))
		return
	button.enabled = false
	var target := button.get_global_rect().get_center()
	var result: Dictionary = await G.do_build(id)
	if result.is_empty():
		if is_instance_valid(button): button.enabled = true
		return
	G.main.fly("shell_2", TopBar.PILLS["shell"].get_center(), target)
	# 每建一次都关面板、回部落播施工动画：没建完的这件长到新的进度，建完最后一次才发奖
	var parts := Data.build_parts(Data.build_def(id))
	var index := int(result["idx"])
	var part: Dictionary = parts[index]
	var steps := maxi(1, int(result.get("steps", 1)))
	var step := int(result.get("step", steps))
	p.close()
	if G.main.screen != "home": G.main.show_screen("home", true)
	G.main.home.play_build(id, index, str(part["id"]), str(part["name"]), result["rewards"], float(step - 1) / float(steps), float(step) / float(steps), "" if step >= steps else "%d/%d" % [step, steps])
