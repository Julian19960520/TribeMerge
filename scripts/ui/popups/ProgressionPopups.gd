class_name ProgressionPopups
extends RefCounted
const Layout := preload("res://scripts/config/board_layout.gd")
const PS := preload("res://scripts/sprites/popups.gd")

static func build(id: String) -> PopupBase:
	var d := Data.build_def(id)
	if d.is_empty():
		return null
	var parts := Data.build_parts(d)
	var total := parts.size()
	var st := clampi(int(G.builds.get(id, 0)), 0, total)
	var p := PopupBase.new()
	var done := st >= total
	var open := G.rules.progression.build_open(id)
	var r := Rect2(40, 390, 640, 780)
	Popups.frame(p, r, str(d.get("name", id)), Color("4f8fc0"))
	var line_name := ""
	for l in Data.LINES:
		if str(l.get("id", "")) == str(d.get("line", "")):
			line_name = str(l.get("name", ""))
	var prog: Dictionary = G.rules.progression.build_progress(id)
	var sub := TextCatalog.source("ui.progressionpopups.57ac2277a313") % [int(prog["done"]), int(prog["total"])]
	if line_name != "":
		sub = "%s · %s" % [line_name, sub]
	UI.box(p.box, Rect2(200, r.position.y + 54, 320, 40), func(ci, sz):
		Sprites.draw(ci, "pop_pill20", Rect2(Vector2.ZERO, sz), Color(0.6, 0.45, 0.25, 0.25)))
	UI.lbl(p.box, sub, Rect2(200, r.position.y + 54, 320, 40), 22, Color("7a5a3a"))
	# 部件卡片 3 列
	var cw := 180.0
	var chh := 168.0
	var gap := 14.0
	var cols := 3
	var x0 := 360.0 - (cw * cols + gap * (cols - 1)) * 0.5
	var y0 := r.position.y + 108
	var rows := int(ceil(float(total) / float(cols)))
	if rows > 2:
		chh = 120.0
	for k in total:
		var part: Dictionary = parts[k] if parts[k] is Dictionary else {}
		var cr := Rect2(x0 + (k % cols) * (cw + gap), y0 + int(k / cols) * (chh + gap), cw, chh)
		var kind := str(part.get("id", ""))
		var state := 0 if k < st else (1 if k == st else 2)
		UI.box(p.box, cr, func(ci, sz): _build_card(ci, sz, kind, state, open, k))
		var nm := TextCatalog.resolve(str(part.get("name", kind)))
		if state == 1 and open and Data.part_steps(part) > 1:
			nm += " %d/%d" % [G.rules.progression.build_step(id), Data.part_steps(part)]
		UI.lbl(p.box, nm, Rect2(cr.position.x, cr.end.y - 40, cw, 34), 22, Color.WHITE if state == 1 else Color("6b4a2a"),
			HORIZONTAL_ALIGNMENT_CENTER, 6 if state == 1 else 0, Art.INK)
	var by := y0 + rows * (chh + gap) + 4
	# 下一件的奖励
	var box := Rect2(r.position.x + 36, by, r.size.x - 72, 150)
	UI.box(p.box, box, func(ci, sz):
		ShopPopups._slot(ci, Rect2(Vector2.ZERO, sz), Color("ecd9b3"), Color(0.6, 0.4, 0.2, 0.3), true))
	var rewards := G.rules.progression.build_piece_rewards(id) if open and not done else []
	var cost := G.rules.progression.build_cost(id)
	if done:
		UI.lbl(p.box, TextCatalog.source("ui.progressionpopups.3ccc5138b117"), Rect2(box.position.x, box.position.y + 50, box.size.x, 50), 28, Color("6b4a2a"))
	elif not open and G.rules.progression.build_blocker(id) != "" and G.rules.progression.feature_unlocked(Data.build_unlock(d)):
		UI.lbl(p.box, TextCatalog.source("ui.progressionpopups.1a8b38a4cc36") % TextCatalog.resolve(str(Data.build_def(G.rules.progression.build_blocker(id)).get("name", ""))), Rect2(box.position.x, box.position.y + 50, box.size.x, 50), 28, Color("6b4a2a"))
	elif not open:
		UI.lbl(p.box, TextCatalog.source("ui.progressionpopups.b8b2658befb0") % [Data.build_unlock(d), str(d.get("name", id))], Rect2(box.position.x, box.position.y + 30, box.size.x, 50), 28, Color("6b4a2a"))
		UI.lbl(p.box, TextCatalog.source("ui.progressionpopups.9be6e988d0a4") % line_name if line_name != "" else "", Rect2(box.position.x, box.position.y + 80, box.size.x, 40), 20, Color("8a6a4a"))
	else:
		var nxt: Dictionary = parts[st]
		UI.lbl(p.box, TextCatalog.source("ui.progressionpopups.5c6a82c70419") % str(nxt.get("name", "")), Rect2(box.position.x, box.position.y + 6, box.size.x, 36), 22, Color("7a5a3a"))
		if rewards.is_empty():
			UI.lbl(p.box, TextCatalog.source("ui.progressionpopups.b537971039cc"), Rect2(box.position.x, box.position.y + 60, box.size.x, 50), 26, Color("6b4a2a"))
		var icon_s := 84.0 if rewards.size() <= 3 else 70.0
		for k in rewards.size():
			var c := Vector2(ItemPopups._spread_x(k, rewards.size(), box.get_center().x, 140.0), box.position.y + 84)
			UI.icon(p.box, str(rewards[k][0]), c, icon_s)
			UI.lbl(p.box, "×%d" % int(rewards[k][1]), Rect2(c.x - 10, c.y + 14, 90, 36), 24, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 6, Art.INK)
	var label := TextCatalog.source("ui.progressionpopups.c7161add6832") if done else ((TextCatalog.source("ui.homescreen.1f67da2b53a5") % Data.build_unlock(d) if not G.rules.progression.feature_unlocked(Data.build_unlock(d)) else TextCatalog.source("ui.progressionpopups.d82d79ae2707")) if not open else str(cost))
	var b := UI.btn(p.box, Rect2(r.get_center().x - 160, box.end.y + 18, 320, 100), label, "green" if open and not done else "grey", Callable(), 44)
	if open and not done:
		b.res = "shell_2"
	b.enabled = open and not done
	p.set_meta("build_rects", [Rect2(b.position, b.size)])
	b.pressed.connect(_buy_build.bind(p, id, b))
	return p

## 部件卡片。state：0 已建 1 下一件 2 之后

static func _build_card(ci: CanvasItem, sz: Vector2, kind: String, state: int, open: bool, _seed: int) -> void:
	var r := Rect2(4, 4, sz.x - 8, sz.y - 8)
	if state == 1 and open:
		Sprites.draw(ci, "pop_bcard_on", r)
	else:
		ShopPopups._slot(ci, r, Color("ecd9b3") if state == 0 else Color("dcc9a2"))
	var art := Rect2(r.position + Vector2(12, 8), Vector2(r.size.x - 24, r.size.y - 58))
	TribeArt.icon(ci, kind, art, state == 2 or not open)
	if state == 0:
		Paint.check_mark(ci, Vector2(sz.x - 24, 24), 0.8)
	elif state == 2 or not open:
		Paint.glyph(ci, "lock", Vector2(sz.x - 24, 24), 0.8)

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
		var info := TextCatalog.source("ui.progressionpopups.667da42b1672") % [built, stages] if open else (TextCatalog.source("ui.homescreen.1f67da2b53a5") % Data.build_unlock(d) if not G.rules.progression.feature_unlocked(Data.build_unlock(d)) else TextCatalog.source("ui.progressionpopups.bf9a2e890609"))
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
	# 这件部件还没建完：敲一下、弹窗刷新进度；建完最后一次才回主页播落成动画
	if not bool(result.get("finished", true)):
		Sfx.play("tap", 1.0)
		G.main.toast("%s %d/%d" % [TextCatalog.resolve(str(G.rules.progression.build_part(id).get("name", ""))), int(result["step"]), int(result["steps"])])
		p.close()
		G.main.open("build", id)
		return
	var parts := Data.build_parts(Data.build_def(id))
	var index := int(result["idx"])
	var part: Dictionary = parts[index]
	p.close()
	if G.main.screen != "home": G.main.show_screen("home", true)
	G.main.home.play_build(id, index, str(part["id"]), str(part["name"]), result["rewards"])
