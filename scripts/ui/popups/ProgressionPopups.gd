class_name ProgressionPopups
extends RefCounted
const Layout := preload("res://scripts/config/board_layout.gd")
const PS := preload("res://scripts/sprites/popups.gd")

static func build(id: String) -> PopupBase:
	var p := PopupBase.new()
	var d := Data.build_def(id)
	if d.is_empty():
		return null
	var parts := Data.build_parts(d)
	var total := parts.size()
	var st := clampi(int(G.builds.get(id, 0)), 0, total)
	var done := st >= total
	var open := G.rules.progression.build_open(id)
	var r := Rect2(40, 390, 640, 780)
	Popups.frame(p, r, str(d.get("name", id)), Color("4f8fc0"))
	var line_name := ""
	for l in Data.LINES:
		if str(l.get("id", "")) == str(d.get("line", "")):
			line_name = str(l.get("name", ""))
	var sub := "已建 %d/%d" % [st, total]
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
		chh = 150.0
	for k in total:
		var part: Dictionary = parts[k] if parts[k] is Dictionary else {}
		var cr := Rect2(x0 + (k % cols) * (cw + gap), y0 + int(k / cols) * (chh + gap), cw, chh)
		var kind := str(part.get("id", ""))
		var state := 0 if k < st else (1 if k == st else 2)
		UI.box(p.box, cr, func(ci, sz): _build_card(ci, sz, kind, state, open, k))
		var nm := str(part.get("name", kind))
		UI.lbl(p.box, nm, Rect2(cr.position.x, cr.end.y - 40, cw, 34), 22, Color.WHITE if state == 1 else Color("6b4a2a"),
			HORIZONTAL_ALIGNMENT_CENTER, 6 if state == 1 else 0, Art.INK)
	var by := y0 + rows * (chh + gap) + 4
	# 下一件的奖励
	var box := Rect2(r.position.x + 36, by, r.size.x - 72, 150)
	UI.box(p.box, box, func(ci, sz):
		ShopPopups._slot(ci, Rect2(Vector2.ZERO, sz), Color("ecd9b3"), Color(0.6, 0.4, 0.2, 0.3), true))
	var rewards := G.rules.progression.build_rewards(id) if open and not done else []
	var cost := G.rules.progression.build_cost(id)
	if done:
		UI.lbl(p.box, "这里已经全部建好啦！", Rect2(box.position.x, box.position.y + 50, box.size.x, 50), 28, Color("6b4a2a"))
	elif not open:
		UI.lbl(p.box, "主角 %d 级开放「%s」" % [Data.build_unlock(d), str(d.get("name", id))], Rect2(box.position.x, box.position.y + 30, box.size.x, 50), 28, Color("6b4a2a"))
		UI.lbl(p.box, "开放后这里会送%s类的好东西" % line_name if line_name != "" else "", Rect2(box.position.x, box.position.y + 80, box.size.x, 40), 20, Color("8a6a4a"))
	else:
		var nxt: Dictionary = parts[st]
		UI.lbl(p.box, "建好「%s」获得" % str(nxt.get("name", "")), Rect2(box.position.x, box.position.y + 6, box.size.x, 36), 22, Color("7a5a3a"))
		if rewards.is_empty():
			UI.lbl(p.box, "这次没有奖励", Rect2(box.position.x, box.position.y + 60, box.size.x, 50), 26, Color("6b4a2a"))
		var icon_s := 84.0 if rewards.size() <= 3 else 70.0
		for k in rewards.size():
			var c := Vector2(ItemPopups._spread_x(k, rewards.size(), box.get_center().x, 140.0), box.position.y + 84)
			UI.icon(p.box, str(rewards[k][0]), c, icon_s)
			UI.lbl(p.box, "×%d" % int(rewards[k][1]), Rect2(c.x - 10, c.y + 14, 90, 36), 24, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 6, Art.INK)
	var label := "已完工" if done else (("Lv.%d 开放" % Data.build_unlock(d)) if not open else str(cost))
	var b := UI.btn(p.box, Rect2(r.get_center().x - 160, box.end.y + 18, 320, 100), label, "green" if open and not done else "grey", Callable(), 44)
	if open and not done:
		b.res = "shell_2"
	b.enabled = open and not done
	p.set_meta("build_rects", [box, Rect2(b.position, b.size)])
	b.pressed.connect(func():
		if G.shells < cost:
			Sfx.play("deny")
			G.main.toast("不拿拿还不够，多帮几位族人吧！")
			return
		var res: Dictionary = await G.do_build(id)
		if res.is_empty():
			return
		var idx := int(res["idx"])
		var part: Dictionary = parts[idx] if idx < parts.size() and parts[idx] is Dictionary else {}
		var got: Array = res["rewards"]
		p.close()
		if G.main.screen == "home" and G.main.home != null:
			G.main.home.play_build(id, idx, str(part.get("id", "")), str(part.get("name", "")), got)
		elif got.is_empty():
			G.main.toast("%s 建好了！" % str(part.get("name", "")))
		else:
			G.main.present_rewards(got))
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
