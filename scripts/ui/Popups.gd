class_name Popups
extends RefCounted
## 所有弹窗的构建函数。每个函数返回一个 PopupBase，由 Main.open() 打开。

static func frame(p: PopupBase, r: Rect2, title: String, col: Color = Art.TEAL, mascot: String = "") -> void:
	var br := Rect2(r.get_center().x - 180, r.position.y - 34, 360, 78)
	UI.box(p.box, Rect2(0, 0, 720, 1480), func(ci, _sz):
		if mascot != "":
			if mascot == "fire":
				for k in 5:
					Art.item(ci, "fire_2", Vector2(br.position.x + 30 + k * 75, br.position.y + 6 - (k % 2) * 20), 56)
			Paint.mascot(ci, Vector2(r.get_center().x, br.position.y - 60), 120, "hammer" if mascot == "hammer" else "")
		Paint.panel(ci, r)
		Paint.banner(ci, br, col))
	UI.title(p.box, title, Rect2(br.position.x + 40, br.position.y + 4, br.size.x - 80, br.size.y - 10), 38, Color.WHITE)
	var x := UI.hit(p.box, Rect2(r.end.x - 52, r.position.y - 24, 70, 70), p.close)
	x.extra = func(ci, sz): Paint.close_btn(ci, sz * 0.5, 28)

static func section(parent: Control, text: String, y: float, col: Color = Color("8a5a30"), cx: float = 360.0) -> void:
	UI.lbl(parent, text, Rect2(cx - 160, y, 320, 40), 26, col)
	UI.box(parent, Rect2(cx - 260, y, 520, 40), func(ci, sz):
		Art.ln(ci, Vector2(30, 20), Vector2(150, 20), 2.0, Color(col, 0.5), 1)
		Art.ln(ci, Vector2(sz.x - 150, 20), Vector2(sz.x - 30, 20), 2.0, Color(col, 0.5), 2)
		ci.draw_colored_polygon(Art.star_pts(Vector2(156, 20), 6, 2.5, 4, 3), Color(col, 0.6))
		ci.draw_colored_polygon(Art.star_pts(Vector2(sz.x - 156, 20), 6, 2.5, 4, 4), Color(col, 0.6)))

# ---------------------------------------------------------------- 体力

static func energy() -> PopupBase:
	var p := PopupBase.new()
	var r := Rect2(46, 380, 628, 780)
	frame(p, r, "更多体力", Color("4f8fc0"), "fire")
	var left := G.energy_full_left()
	var txt := "体力已满，先去合成吧！" if left == 0 else "等待 %s 恢复到 100 点体力。" % G.fmt_time(left)
	UI.lbl(p.box, txt, Rect2(r.position.x + 30, r.position.y + 62, r.size.x - 60, 50), 26, Color("6b4a2a"))
	UI.box(p.box, Rect2(r.position.x + 44, r.position.y + 120, r.size.x - 88, 400), _energy_art)
	var tag := UI.lbl(p.box, "×100", Rect2(r.position.x + 92, r.position.y + 436, 150, 60), 40, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 10, Art.INK, true)
	tag.rotation = -0.06
	var b := UI.btn(p.box, Rect2(r.get_center().x - 150, r.position.y + 560, 300, 100), "20", "green", Callable(), 44)
	b.res = "amber_2"
	b.pressed.connect(func():
		if G.spend("amber", 20):
			G.main.fly("fire_2", Vector2(360, 760), G.main.topbar.target("energy"), func(): G.add_currency("energy", 100), 90)
			p.close()
		else:
			G.main.toast("琥珀不够了！"))
	return p

static func _energy_art(ci: CanvasItem, sz: Vector2) -> void:
	var r := Rect2(Vector2.ZERO, sz)
	var b := Art.rrect(r, 22, 101, 0.8)
	ci.draw_colored_polygon(b, Color("c9a06a"))
	var cave := PackedVector2Array()
	for k in 17:
		var a := PI + PI * float(k) / 16.0
		cave.append(Vector2(sz.x * 0.72, sz.y * 0.62) + Vector2(cos(a) * 130.0, sin(a) * 170.0))
	ci.draw_colored_polygon(cave, Color("8fd0d4"))
	Paint.hills(ci, sz.y * 0.5, sz.x, 20, Color("7fb48a"), 2, sz.y * 0.62)
	Art.outline(ci, cave, 4.0, Color(0.4, 0.25, 0.1, 0.6))
	Paint.palm(ci, Vector2(70, sz.y * 0.62), 140, 4, Color("4a8a4a"))
	var string := []
	for k in 9:
		string.append(Vector2(sz.x * float(k) / 8.0, 24 + sin(float(k) / 8.0 * PI) * 30.0))
	Art.pl(ci, string, 2.5, Art.WOOD_D, 3)
	for k in 8:
		var p: Vector2 = string[k].lerp(string[k + 1], 0.5)
		var cols := [Art.CLAY, Art.OCHRE, Art.TEAL, Art.BONE]
		ci.draw_colored_polygon(Art.poly([p + Vector2(-16, -4), p + Vector2(16, -4), p + Vector2(0, 26)], k), cols[k % 4])
	var table := Rect2(0, sz.y * 0.62, sz.x, sz.y * 0.38)
	ci.draw_rect(table, Color("e9d3a3"))
	for i in 12:
		for j in 4:
			if (i + j) % 2 == 0:
				ci.draw_rect(Rect2(table.position + Vector2(i * 46, j * 40), Vector2(46, 40)), Color(0.85, 0.45, 0.3, 0.35))
	Art.item(ci, "basket_3", Vector2(sz.x * 0.52, sz.y * 0.6), 270)
	for k in 7:
		var x := sz.x * 0.52 + (float(k) - 3.0) * 30.0
		Art.item(ci, "fire_2", Vector2(x, sz.y * 0.36 - abs(float(k) - 3.0) * -6.0 - 20.0 + (k % 2) * 12.0), 70)
	for k in 3:
		Art.item(ci, "fire_1", Vector2(80 + k * 50, sz.y * 0.8 + (k % 2) * 16), 50)
	var plank := Art.rrect(Rect2(40, sz.y * 0.76, 170, 70), 10, 102, 0.8)
	Art.dilate(ci, plank, 3.0, Art.INK)
	ci.draw_colored_polygon(plank, Art.WOOD)
	Art.ln(ci, Vector2(120, sz.y * 0.76), Vector2(120, sz.y * 0.70), 4.0, Art.ROPE, 1)
	Art.outline(ci, b, 3.0, Art.LEATHER_D)

# ---------------------------------------------------------------- 玩法说明

static func howto() -> PopupBase:
	var p := PopupBase.new()
	p.dim_alpha = 0.85
	p.set_meta("fullscreen", true)
	UI.title(p.box, "玩法说明", Rect2(0, 150, 720, 100), 64)
	UI.box(p.box, Rect2(0, 0, 720, 1480), func(ci, _sz):
		var card := Art.rrect(Rect2(90, 330, 200, 100), 20, 111, 0.8)
		Art.dilate(ci, card, 3.0, Art.INK)
		ci.draw_colored_polygon(card, Art.BONE)
		Art.item(ci, "meat_4", Vector2(160, 300), 110)
		Paint.button(ci, Rect2(120, 360, 140, 56), "green")
		ci.draw_polyline(PackedVector2Array([Vector2(170, 384), Vector2(186, 398), Vector2(212, 372)]), Color.WHITE, 7.0, true)
		_arrow(ci, Vector2(330, 360), Vector2(500, 450), 0.4)
		Art.item(ci, "shell_3", Vector2(560, 540), 170)
		_arrow(ci, Vector2(520, 660), Vector2(380, 760), 0.4)
		Art.item(ci, "chest_1", Vector2(220, 830), 200)
		Art.item(ci, "berry_2", Vector2(150, 720), 70)
		Art.item(ci, "amber_3", Vector2(290, 700), 70)
		var hand := Art.ell(Vector2(310, 880), Vector2(26, 34), 112, 0.08, 16, -0.6)
		Art.fill(ci, hand, Color("f1c49a"), 3.0)
		Art.fill(ci, Art.capsule(Vector2(296, 862), Vector2(270, 830), 8.0, 113), Color("f1c49a"), 3.0)
		_arrow(ci, Vector2(360, 960), Vector2(480, 1010), -0.4)
		Paint._spot_hut(ci, Vector2(560, 1080), 4)
		var bub := Art.ell(Vector2(620, 920), Vector2(36, 36), 114, 0.03, 18)
		Art.fill(ci, bub, Art.BONE, 3.0)
		Paint.hammer(ci, Vector2(620, 918), 0.5))
	UI.lbl(p.box, "完成订单！", Rect2(40, 440, 300, 50), 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 10, Art.INK)
	UI.lbl(p.box, "赚取贝币！", Rect2(410, 630, 300, 50), 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 10, Art.INK)
	UI.lbl(p.box, "开启宝箱！", Rect2(70, 940, 300, 50), 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 10, Art.INK)
	UI.lbl(p.box, "建设部落！", Rect2(410, 1150, 300, 50), 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 10, Art.INK)
	UI.lbl(p.box, "拖动两个相同的物品即可合成更高级的物品", Rect2(0, 250, 720, 40), 24, Color("ffe7a8"), HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK)
	var go := UI.btn(p.box, Rect2(210, 1250, 300, 104), "开始合成", "green", Callable(), 44)
	go.pressed.connect(func():
		G.seen_tutorial = true
		G.dirty()
		p.close()
		G.main.show_screen("board"))
	return p

static func _arrow(ci: CanvasItem, a: Vector2, b: Vector2, bend: float) -> void:
	var m := a.lerp(b, 0.5) + (b - a).orthogonal() * bend
	var pts := []
	for k in 13:
		var t := float(k) / 12.0
		pts.append(a.lerp(m, t).lerp(m.lerp(b, t), t))
	Art.pl(ci, pts, 18.0, Art.INK, 1)
	Art.pl(ci, pts, 11.0, Art.MOSS, 1)
	var d := (b - m).normalized()
	var n := d.orthogonal()
	var head := Art.poly([b + d * 22.0, b + n * 22.0, b - n * 22.0], 2)
	Art.fill(ci, head, Art.MOSS, 3.0)

# ---------------------------------------------------------------- 集市

## 全屏页面：内容放进竖向滚动区（从顶栏下方开始），返回一个使用绝对坐标的根节点
static func fullscreen(p: PopupBase, top: float = 128.0) -> Array:
	p.set_meta("fullscreen", true)
	var sc := Scroller.new()
	sc.position = Vector2(0, top)
	sc.size = Vector2(720, 1480 - top)
	p.box.add_child(sc)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.position = Vector2(0, -top)
	sc.content.add_child(root)
	return [sc, root]

## 连接全局信号，弹窗销毁时自动断开
static func live(p: Node, sig: Signal, cb: Callable) -> void:
	sig.connect(cb)
	p.tree_exiting.connect(func(): sig.disconnect(cb))

static func store() -> PopupBase:
	var p := PopupBase.new()
	p.dim_alpha = 0.9
	p.set_meta("store", true)
	var fs := fullscreen(p)
	var sc: Scroller = fs[0]
	var root: Control = fs[1]
	UI.title(root, "交易集市", Rect2(0, 140, 720, 80), 46)
	UI.box(root, Rect2(0, 0, 720, 520), _paint_store)
	UI.title(root, "篝火祭通行证", Rect2(50, 400, 360, 60), 34, Color.WHITE)
	UI.lbl(root, "×10", Rect2(440, 300, 80, 30), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK)
	UI.lbl(root, "订单额外 +1 贝币", Rect2(500, 304, 200, 30), 18, Color("ffe7a8"), HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK)
	UI.lbl(root, "¥ 30", Rect2(470, 344, 160, 44), 28, Color("5a3d24"), HORIZONTAL_ALIGNMENT_CENTER)
	UI.btn(root, Rect2(430, 396, 240, 80), "激活", "green", func(): G.main.toast("演示版本，暂未开放购买。"), 38)
	section(root, "每日特惠", 516, Color("ffd23f"))
	var deals := [{"id": "chest_1", "price": 10, "stock": 1}, {"id": "pack_1", "price": 15, "stock": 1}]
	for k in deals.size():
		var d: Dictionary = deals[k]
		var x := 110.0 + k * 270.0
		_store_card(root, Rect2(x, 560, 230, 250), d, "deal_%d" % k, true)
	var tl := UI.lbl(root, "", Rect2(160, 826, 400, 40), 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK)
	tl.text = "刷新倒计时：%s" % G.fmt_time(G.secs_to_midnight())
	section(root, "热卖", 880, Color("ffd23f"))
	var y := 924.0
	for k in Data.STORE_HOT.size():
		var d: Dictionary = Data.STORE_HOT[k]
		var x := 30.0 + (k % 3) * 226.0
		y = 924.0 + (k / 3) * 270.0
		_store_card(root, Rect2(x, y, 208, 250), d, "hot_%d" % k, false)
	y += 290.0
	section(root, "琥珀", y, Color("ffd23f"))
	y += 48.0
	for k in Data.AMBER_PACKS.size():
		var a: Dictionary = Data.AMBER_PACKS[k]
		_amber_card(root, Rect2(30.0 + (k % 3) * 226.0, y + (k / 3) * 280.0, 208, 260), a, k)
	y += 2 * 280.0 + 40.0
	sc.set_length(y - 128.0)
	return p

static func _amber_card(parent: Control, r: Rect2, a: Dictionary, k: int) -> void:
	var piles := [["amber_1", 1], ["amber_2", 1], ["amber_2", 3], ["amber_3", 2], ["amber_3", 4], ["amber_3", 6]]
	UI.box(parent, r, func(ci, sz):
		var b := Art.rrect(Rect2(Vector2.ZERO, sz), 20, 300 + k, 1.0)
		ci.draw_colored_polygon(Art.rrect(Rect2(Vector2(0, 8), sz), 20, 3, 0.0), Color(0, 0, 0, 0.3))
		Art.dilate(ci, b, 3.0, Art.INK)
		ci.draw_colored_polygon(b, Color("c9894a") if k < 5 else Color("d9a54a"))
		var ir := Rect2(10, 10, sz.x - 20, sz.y - 96)
		ci.draw_colored_polygon(Art.rrect(ir, 14, 310 + k, 0.6), Color("fff3d6"))
		var pid: String = piles[k][0]
		var n: int = piles[k][1]
		for j in n:
			var off := Vector2((float(j % 3) - float(mini(n, 3) - 1) * 0.5) * 40.0, -float(j / 3) * 24.0 + 10.0)
			Art.item(ci, pid, Vector2(sz.x * 0.5, 84) + off, 92.0 - n * 4.0)
		if k >= 4:
			var seal := Art.star_pts(Vector2(30, 26), 36, 30, 12, 5)
			Art.fill(ci, seal, Art.CLAY, 3.0))
	if k >= 4:
		var hl := UI.lbl(parent, "超值", Rect2(r.position.x - 6, r.position.y + 8, 72, 36), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 5, Art.INK, true)
		hl.rotation = -0.2
	UI.lbl(parent, "×%d" % a["n"], Rect2(r.position.x, r.position.y + 128, r.size.x, 40), 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 8, Art.INK, true)
	var b := UI.btn(parent, Rect2(r.position.x + 22, r.position.y + 184, r.size.x - 44, 64), a["price"], "orange", Callable(), 30)
	b.title_font = false
	b.pressed.connect(func():
		G.main.fly("amber_2", b.get_global_rect().get_center() + Vector2(0, -100), G.main.topbar.target("amber"), func(): G.add_currency("amber", a["n"]), 80)
		G.main.toast("演示版本：琥珀 ×%d 已到账" % a["n"]))

static func _paint_store(ci: CanvasItem, _sz: Vector2) -> void:
	var r := Rect2(30, 236, 660, 262)
	var b := Art.rrect(r, 24, 121, 1.0)
	ci.draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(0, 10), r.size), 24, 121, 0.0), Color(0, 0, 0, 0.35))
	Art.dilate(ci, b, 3.0, Art.INK)
	ci.draw_colored_polygon(b, Art.OCHRE)
	var ir := Rect2(r.position + Vector2(12, 12), Vector2(r.size.x - 24, 150))
	Paint.vgrad(ci, ir, Color("2c3b78"), Color("6a4d9a"))
	for i in 20:
		ci.draw_circle(ir.position + Vector2(Art.srnd(i) * ir.size.x, Art.srnd(i + 40) * ir.size.y), 1.5 + Art.srnd(i + 9) * 1.5, Color(1, 1, 0.8, 0.7))
	Art.item(ci, "chest_1", Vector2(150, 316), 180)
	for k in 6:
		Art.item(ci, "amber_2", Vector2(70 + k * 34, 380 - (k % 2) * 10), 54)
	Art.item(ci, "fire_3", Vector2(270, 330), 80)
	var tag := Art.rrect(Rect2(470, 344, 160, 44), 10, 122, 0.6)
	Art.dilate(ci, tag, 2.5, Art.INK)
	ci.draw_colored_polygon(tag, Color("e9d8ff"))
	Art.item(ci, "pack_1", Vector2(480, 286), 60)

static func _store_card(parent: Control, r: Rect2, d: Dictionary, key: String, hot: bool) -> void:
	var book_of: Dictionary = G.deals_bought if hot else G.hot_bought
	UI.box(parent, r, func(ci, sz):
		var b := Art.rrect(Rect2(Vector2.ZERO, sz), 20, int(r.position.x), 1.0)
		ci.draw_colored_polygon(Art.rrect(Rect2(Vector2(0, 8), sz), 20, 3, 0.0), Color(0, 0, 0, 0.3))
		Art.dilate(ci, b, 3.0, Art.INK)
		ci.draw_colored_polygon(b, Art.OCHRE)
		var ir := Rect2(10, 10, sz.x - 20, sz.y - 86)
		ci.draw_colored_polygon(Art.rrect(ir, 14, 4, 0.6), Art.BONE)
		Art.item(ci, d["id"], Vector2(sz.x * 0.5, 82), 112)
		if hot:
			var seal := Art.star_pts(Vector2(30, 24), 38, 32, 12, 5)
			Art.fill(ci, seal, Art.CLAY, 3.0)
		Paint.glyph(ci, "info", Vector2(sz.x - 18, 18), 1.1))
	if hot:
		var hl := UI.lbl(parent, "HOT", Rect2(r.position.x - 6, r.position.y + 6, 72, 36), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 5, Art.INK, true)
		hl.rotation = -0.2
	var left_lbl := UI.lbl(parent, "", Rect2(r.position.x, r.position.y + 128, r.size.x, 34), 22, Color("6b4a2a"))
	var b := UI.btn(parent, Rect2(r.position.x + 22, r.position.y + 178, r.size.x - 44, 64), "", "green", Callable(), 30)
	var refresh := func():
		var left: int = int(d["stock"]) - int(book_of.get(key, 0))
		left_lbl.text = "剩余 %d" % left
		b.text = str(d["price"]) if left > 0 else "售罄"
		b.res = "amber_2" if left > 0 else ""
		b.style = "green" if left > 0 else "grey"
		b.enabled = left > 0
		b.queue_redraw()
	refresh.call()
	b.pressed.connect(func():
		if not G.spend("amber", d["price"]):
			G.main.toast("琥珀不够了！")
			return
		book_of[key] = int(book_of.get(key, 0)) + 1
		G.discover(d["id"])
		G.stash_push(d["id"])
		G.main.fly(d["id"], b.get_global_rect().get_center() + Vector2(0, -110), Vector2(64, 260), Callable(), 90)
		G.main.toast("已放入暂存区：%s" % Data.name_of(d["id"]))
		refresh.call())

# ---------------------------------------------------------------- 设置

static func settings() -> PopupBase:
	var p := PopupBase.new()
	var r := Rect2(46, 300, 628, 820)
	frame(p, r, "设置", Art.TEAL)
	var keys := ["music", "sound", "vibrate", "hint"]
	for k in 4:
		var key: String = keys[k]
		var b := UI.btn(p.box, Rect2(122 + k * 126, r.position.y + 90, 96, 96), "", "teal" if G.settings[key] else "grey", Callable())
		b.is_round = true
		b.glyph = key
		b.pressed.connect(func():
			G.settings[key] = not G.settings[key]
			b.style = "teal" if G.settings[key] else "grey"
			b.queue_redraw()
			G.dirty()
			if key == "music":
				Sfx.refresh_music())
	var labels := [["联系我们", "chat"], ["语言：简体中文", "globe"]]
	for k in 2:
		var b := UI.btn(p.box, Rect2(106, r.position.y + 250 + k * 130, 508, 88), labels[k][0], "orange", Callable(), 34)
		var g: String = labels[k][1]
		b.extra = func(ci, sz): Paint.glyph(ci, g, Vector2(56, sz.y * 0.5 - 3), 1.6)
		if k == 0:
			b.pressed.connect(func(): G.main.toast("对着篝火喊三声，酋长就会来找你。"))
		else:
			b.pressed.connect(func(): G.main.toast("目前仅支持简体中文。"))
	var terms := UI.lbl(p.box, "条款与隐私", Rect2(260, r.position.y + 590, 200, 40), 24, Color("2f7f8a"))
	UI.box(p.box, Rect2(290, r.position.y + 626, 140, 6), func(ci, sz): ci.draw_line(Vector2(0, 2), Vector2(sz.x, 2), Color("2f7f8a"), 2.0))
	UI.lbl(p.box, "玩家ID：%s" % G.player_id, Rect2(r.position.x, r.position.y + 650, r.size.x, 34), 20, Color("8a7a66"))
	UI.lbl(p.box, "V0.1.0", Rect2(r.position.x, r.position.y + 688, r.size.x, 34), 22, Color("8a7a66"))
	var reset := UI.btn(p.box, Rect2(r.end.x - 170, r.position.y + 690, 130, 50), "重新开始", "grey", Callable(), 20)
	reset.title_font = false
	reset.pressed.connect(func():
		G.reset_game()
		p.close()
		G.main.toast("新的部落诞生了！"))
	return p

# ---------------------------------------------------------------- 建造

static func build(id: String) -> PopupBase:
	var p := PopupBase.new()
	var d := Data.build_def(id)
	var st: int = G.builds.get(id, 0)
	var done: bool = st >= int(d["stages"])
	var r := Rect2(46, 470, 628, 600)
	frame(p, r, d["name"], Color("4f8fc0"), "hammer")
	UI.box(p.box, Rect2(260, r.position.y + 60, 200, 40), func(ci, sz):
		var b := Art.rrect(Rect2(Vector2.ZERO, sz), 20, 131, 0.6)
		ci.draw_colored_polygon(b, Color(0.6, 0.45, 0.25, 0.25)))
	UI.lbl(p.box, "阶段 %d/%d" % [min(st + 1, d["stages"]), d["stages"]], Rect2(260, r.position.y + 60, 200, 40), 22, Color("7a5a3a"))
	section(p.box, "奖励", r.position.y + 116)
	var reward := G.build_reward(id)
	UI.box(p.box, Rect2(r.position.x + 60, r.position.y + 166, r.size.x - 120, 200), func(ci, sz):
		var b := Art.rrect(Rect2(Vector2.ZERO, sz), 18, 132, 0.8)
		ci.draw_colored_polygon(b, Color("ecd9b3"))
		Art.outline(ci, b, 2.0, Color(0.6, 0.4, 0.2, 0.3))
		Art.item(ci, "fire_2", Vector2(sz.x * 0.5 - 70, 86), 110)
		Art.item(ci, "amber_1", Vector2(sz.x * 0.5 + 70, 86), 90))
	UI.lbl(p.box, "×%d" % reward, Rect2(r.position.x + 160, r.position.y + 300, 140, 40), 28, Color("6b4a2a"))
	UI.lbl(p.box, "×1", Rect2(r.position.x + 310, r.position.y + 300, 140, 40), 28, Color("6b4a2a"))
	var cost := G.build_cost(id)
	var b := UI.btn(p.box, Rect2(r.get_center().x - 160, r.position.y + 410, 320, 104), "已完工" if done else str(cost), "green", Callable(), 44)
	if not done:
		b.res = "shell_1"
	b.enabled = not done
	b.pressed.connect(func():
		if not G.spend("shell", cost):
			G.main.toast("贝币不够，去完成订单吧！")
			return
		G.builds[id] = st + 1
		G.dirty()
		G.changed.emit()
		Sfx.play("fanfare")
		G.main.fly("fire_2", Vector2(360, 740), G.main.topbar.target("energy"), func(): G.add_currency("energy", reward), 90)
		G.main.fly("amber_1", Vector2(420, 740), G.main.topbar.target("amber"), func(): G.add_currency("amber", 1), 70)
		G.main.toast("%s 建好了新阶段！" % d["name"])
		p.close())
	return p

# ---------------------------------------------------------------- 图鉴

static func book(tab: int = 0) -> PopupBase:
	var p := PopupBase.new()
	var r := Rect2(24, 240, 672, 1040)
	UI.box(p.box, Rect2(0, 0, 720, 1480), func(ci, _sz):
		var cover := Art.rrect(r.grow(8), 26, 141, 1.0)
		ci.draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(0, 16), r.size), 26, 141, 0.0), Color(0, 0, 0, 0.35))
		Art.dilate(ci, cover, 3.0, Art.INK)
		ci.draw_colored_polygon(cover, Art.LEATHER)
		var page := Art.rrect(Rect2(r.position + Vector2(10, 6), r.size - Vector2(24, 18)), 18, 142, 0.8)
		ci.draw_colored_polygon(page, Art.HIDE)
		Art.outline(ci, page, 2.5, Art.LEATHER_D)
		for i in 4:
			Art.ln(ci, Vector2(r.position.x + 18 + i * 3, r.position.y + 20), Vector2(r.position.x + 18 + i * 3, r.end.y - 20), 1.5, Color(0.5, 0.3, 0.1, 0.25), i)
		var strap := Art.rrect(Rect2(r.end.x - 20, r.position.y + 300, 48, 90), 14, 143, 0.8)
		Art.dilate(ci, strap, 3.0, Art.INK)
		ci.draw_colored_polygon(strap, Art.LEATHER_D)
		ci.draw_circle(Vector2(r.end.x + 4, r.position.y + 345), 10, Art.OCHRE)
		ci.draw_circle(Vector2(r.end.x + 4, r.position.y + 345), 10, Art.INK, false, 2.5, true))
	var x := UI.hit(p.box, Rect2(r.end.x - 110, r.position.y - 40, 76, 84), p.close)
	x.extra = func(ci, sz):
		var tagp := Art.rrect(Rect2(8, 0, sz.x - 16, sz.y - 6), 12, 144, 0.8)
		Art.dilate(ci, tagp, 3.0, Art.INK)
		ci.draw_colored_polygon(tagp, Art.LEATHER_D)
		Art.ln(ci, Vector2(26, 26), Vector2(50, 50), 6.0, Art.BONE, 1)
		Art.ln(ci, Vector2(50, 26), Vector2(26, 50), 6.0, Art.BONE, 2)
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.box.add_child(holder)
	var tabs := ["物品", "生产器"]
	var tab_btns: Array[TButton] = []
	var state := {"tab": clampi(tab, 0, 1)}
	for k in 2:
		var b := UI.btn(p.box, Rect2(130 + k * 250, r.end.y - 30, 210, 74), tabs[k], "wood", Callable(), 30)
		tab_btns.append(b)
		b.pressed.connect(func():
			if k == state["tab"]:
				return
			state["tab"] = k
			_book_tabs(tab_btns, k)
			_book_page(holder, r, k))
	_book_tabs(tab_btns, state["tab"])
	_book_page(holder, r, state["tab"])
	return p

static func _book_tabs(btns: Array[TButton], tab: int) -> void:
	for k in btns.size():
		btns[k].style = "orange" if k == tab else "wood"
		btns[k].queue_redraw()

static func _book_page(holder: Control, r: Rect2, tab: int) -> void:
	for c in holder.get_children():
		c.queue_free()
	var groups := [["berry", "stone", "meat", "fish"], ["basket", "hunt"]]
	var y := r.position.y + 40
	for ch in groups[tab]:
		var c: Dictionary = Data.CHAINS[ch]
		var n := 0
		for l in c["items"].size():
			if G.discovered.has("%s_%d" % [ch, l + 1]):
				n += 1
		section(holder, "%s（%d/%d）" % [c["name"], n, c["items"].size()], y)
		y += 52
		for l in c["items"].size():
			var id := "%s_%d" % [ch, l + 1]
			var cx: float = r.position.x + 90 + (l % 5) * 120
			var known := G.discovered.has(id)
			UI.box(holder, Rect2(cx - 52, y, 104, 104), func(ci, sz):
				var b := Art.rrect(Rect2(Vector2.ZERO, sz), 18, l + 150, 0.6)
				ci.draw_colored_polygon(b, Color("ecd9b3"))
				Art.outline(ci, b, 2.0, Color(0.6, 0.4, 0.2, 0.35))
				if known:
					Art.item(ci, id, sz * 0.5, 86)
				else:
					var f: Font = G.font_title
					ci.draw_string(f, Vector2(sz.x * 0.5 - 18, sz.y * 0.5 + 20), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 60, Color(0.7, 0.55, 0.35, 0.6)))
			if known:
				UI.hit(holder, Rect2(cx - 52, y, 104, 104), func(): G.main.open("item_info", id))
			if l % 5 == 4 and l < c["items"].size() - 1:
				y += 116
		y += 126
	holder.modulate.a = 0.0
	holder.create_tween().tween_property(holder, "modulate:a", 1.0, 0.15)

# ---------------------------------------------------------------- 储物洞

static func inventory() -> PopupBase:
	var p := PopupBase.new()
	var r := Rect2(30, 300, 660, 860)
	UI.box(p.box, Rect2(0, 0, 720, 1480), func(ci, _sz):
		ci.draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(0, 14), r.size), 34, 161, 0.0), Color(0, 0, 0, 0.35))
		var b := Art.rrect(r, 34, 161, 1.2)
		Art.dilate(ci, b, 3.5, Art.INK)
		Art.shade(ci, b, Color("8f9a8c"), 1)
		for i in 30:
			var q := r.position + Vector2(Art.srnd(i * 3) * r.size.x, Art.srnd(i * 5 + 1) * r.size.y)
			ci.draw_circle(q, 3.0 + Art.srnd(i) * 9.0, Color(0, 0, 0, 0.06))
		var hdr := Art.rrect(Rect2(r.position + Vector2(20, 20), Vector2(r.size.x - 40, 150)), 22, 162, 0.8)
		ci.draw_colored_polygon(hdr, Color("6d7a6c"))
		var shelf := Rect2(r.position + Vector2(24, 180), Vector2(r.size.x - 48, 520))
		ci.draw_colored_polygon(Art.rrect(shelf, 18, 163, 0.8), Color("4b3a2e"))
		for row in 2:
			var sy := shelf.position.y + 150 + row * 250
			var pl := Art.rrect(Rect2(shelf.position.x - 6, sy, shelf.size.x + 12, 26), 8, 164 + row, 0.8)
			Art.dilate(ci, pl, 3.0, Art.INK)
			Art.shade(ci, pl, Art.WOOD, 1)
		var tab := Art.rrect(Rect2(r.position + Vector2(40, 724), Vector2(280, 84)), 18, 166, 0.8)
		Art.dilate(ci, tab, 3.0, Art.INK)
		ci.draw_colored_polygon(tab, Art.HIDE)
		Art.item(ci, "berry_4", r.position + Vector2(90, 766), 64)
		Paint.pouch(ci, Vector2(360, 290), 1.0))
	UI.title(p.box, "储物洞", Rect2(200, 330, 320, 70), 44, Color.WHITE)
	UI.lbl(p.box, "物品", Rect2(130, 1024, 180, 84), 30, Art.INK)
	UI.lbl(p.box, "拖动棋盘上的物品到皮袋即可收起", Rect2(330, 1024, 340, 84), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 5, Art.INK)
	var x := UI.hit(p.box, Rect2(r.end.x - 80, r.position.y + 10, 70, 70), p.close)
	x.extra = func(ci, sz): Paint.close_btn(ci, sz * 0.5, 28)
	UI.box(p.box, Rect2(130, 400, 460, 56), func(ci, _sz):
		for k in 2:
			var pr := Rect2(10 + k * 230, 6, 200, 44)
			var b := Art.rrect(pr, 22, 170 + k, 0.6)
			ci.draw_colored_polygon(b, Color(0, 0, 0, 0.3))
		Art.item(ci, "amber_2", Vector2(30, 28), 50)
		Art.item(ci, "shell_1", Vector2(260, 28), 50))
	var am_lbl := UI.lbl(p.box, "", Rect2(180, 406, 140, 44), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK)
	var sh_lbl := UI.lbl(p.box, "", Rect2(410, 406, 140, 44), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK)
	var slots: Array[DrawBox] = []
	var centers: Array[Vector2] = []
	for k in G.INV_MAX:
		var c := Vector2(r.position.x + 90 + (k % 5) * 120, 580 + (k / 5) * 250)
		centers.append(c)
		var slot := Rect2(c - Vector2(52, 60), Vector2(104, 110))
		var box := UI.box(p.box, slot, func(ci, sz):
			var b := Art.rrect(Rect2(Vector2(2, 8), sz - Vector2(4, 8)), 18, 180 + k, 0.8)
			Art.dilate(ci, b, 2.5, Art.INK)
			if k >= G.inv_cap:
				Art.shade(ci, b, Color("8a8378"), 1)
				Paint.glyph(ci, "lock", Vector2(sz.x - 18, 22), 1.0)
			else:
				ci.draw_colored_polygon(b, Color("6a5444"))
				ci.draw_colored_polygon(Art.ell(Vector2(sz.x * 0.5, sz.y - 20), Vector2(36, 9), k, 0.0, 14), Color(0, 0, 0, 0.25))
				if k < G.inv.size():
					Art.item(ci, G.inv[k], Vector2(sz.x * 0.5, sz.y * 0.5), 90))
		box.pivot_offset = slot.size * 0.5
		slots.append(box)
		UI.hit(p.box, slot, func():
			if k >= G.inv.size():
				return
			var to := G.find_empty_near(G.idx(3, 4))
			if to < 0:
				G.main.toast("棋盘满了！")
				return
			var id: String = G.inv[k]
			G.inv.remove_at(k)
			G.board[to]["id"] = id
			G.dirty()
			G.board_changed.emit()
			Sfx.play("pop"))
	var unlock := UI.btn(p.box, Rect2(0, 0, 108, 54), "50", "green", Callable(), 26)
	unlock.res = "amber_2"
	var refresh := func():
		am_lbl.text = str(G.amber)
		sh_lbl.text = str(G.shells)
		for s in slots:
			s.queue_redraw()
		unlock.visible = G.inv_cap < G.INV_MAX
		if unlock.visible:
			unlock.position = centers[G.inv_cap] + Vector2(-54, 30)
	refresh.call()
	unlock.pressed.connect(func():
		if G.spend("amber", 50):
			var k := G.inv_cap
			G.inv_cap += 1
			G.dirty()
			G.board_changed.emit()
			Sfx.play("merge", 1.2)
			var tw := slots[k].create_tween()
			tw.tween_property(slots[k], "scale", Vector2(1.15, 1.15), 0.1)
			tw.tween_property(slots[k], "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			G.main.toast("琥珀不够了！"))
	live(p, G.changed, refresh)
	live(p, G.board_changed, refresh)
	return p

# ---------------------------------------------------------------- 物品详情

static func item_info(id: String) -> PopupBase:
	var p := PopupBase.new()
	var ch := Data.chain(id)
	var c: Dictionary = Data.CHAINS[ch]
	var r := Rect2(40, 280, 640, 880)
	frame(p, r, c["name"], Art.TEAL)
	UI.lbl(p.box, "%s · 第 %d 级" % [Data.name_of(id), Data.lv(id)], Rect2(r.position.x, r.position.y + 54, r.size.x, 40), 26, Color("7a5a3a"))
	var items: Array = c["items"]
	var y0 := r.position.y + 110
	for l in items.size():
		var iid := "%s_%d" % [ch, l + 1]
		var cx := r.position.x + 92 + (l % 4) * 152
		var cy := y0 + (l / 4) * 124
		var known := G.discovered.has(iid)
		var cur := iid == id
		UI.box(p.box, Rect2(cx - 56, cy, 112, 112), func(ci, sz):
			var b := Art.rrect(Rect2(4, 4, sz.x - 8, sz.y - 8), 18, 190 + l, 0.6)
			ci.draw_colored_polygon(b, Color("a8d86a") if cur else Color("ecd9b3"))
			Art.outline(ci, b, 2.0, Color(0.6, 0.4, 0.2, 0.35))
			if known:
				Art.item(ci, iid, sz * 0.5, 90)
			else:
				ci.draw_string(G.font_title, Vector2(sz.x * 0.5 - 18, sz.y * 0.5 + 20), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 60, Color(0.7, 0.55, 0.35, 0.6))
			if cur:
				Paint.cell_bracket(ci, Rect2(Vector2.ZERO, sz).grow(-2))
			if l % 4 != 3 and l < items.size() - 1:
				ci.draw_colored_polygon(Art.poly([Vector2(sz.x + 10, sz.y * 0.5 - 9), Vector2(sz.x + 24, sz.y * 0.5), Vector2(sz.x + 10, sz.y * 0.5 + 9)], l), Color(0.75, 0.6, 0.4, 0.8)))
	var y := y0 + (int((items.size() - 1) / 4) + 1) * 124 + 20
	var t := c["type"] as String
	if t == "gen":
		section(p.box, "可以生产：", y)
		var outs := Data.gen_outputs(id)
		for k in outs.size():
			var oid := "%s_1" % outs[k]
			UI.icon(p.box, oid, Vector2(r.get_center().x + (float(k) - (outs.size() - 1) * 0.5) * 130, y + 110), 110)
		y += 190
		var nx := Data.next_id(id)
		if nx != "":
			var more := []
			for o in Data.gen_outputs(nx):
				if not (o in outs):
					more.append(o)
			if not more.is_empty():
				section(p.box, "下一级还能生产：", y)
				UI.icon(p.box, "%s_1" % more[0], Vector2(r.get_center().x, y + 110), 110)
				UI.lbl(p.box, "NEW", Rect2(r.get_center().x, y + 44, 80, 30), 22, Art.CLAY, HORIZONTAL_ALIGNMENT_CENTER, 6, Color.WHITE, true)
	elif t == "item":
		section(p.box, "获取途径：", y)
		var prods := Data.producers_of(ch)
		for k in prods.size():
			UI.icon(p.box, prods[k], Vector2(r.get_center().x + (float(k) - (prods.size() - 1) * 0.5) * 130, y + 110), 110)
	else:
		section(p.box, "获取途径：", y)
		UI.lbl(p.box, "生产器随机掉落、开启宝箱、升级奖励", Rect2(r.position.x, y + 60, r.size.x, 60), 24, Color("7a5a3a"))
	return p

# ---------------------------------------------------------------- 升级

static func levelup() -> PopupBase:
	var p := PopupBase.new()
	p.dim_alpha = 0.8
	var rewards := Data.level_rewards(G.level)
	UI.box(p.box, Rect2(0, 0, 720, 1480), func(ci, _sz):
		var c := Vector2(360, 470)
		var rot := float(Time.get_ticks_msec()) / 3000.0
		for k in 14:
			var a := rot + TAU * float(k) / 14.0
			ci.draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a - 0.09), sin(a - 0.09)) * 420.0, c + Vector2(cos(a + 0.09), sin(a + 0.09)) * 420.0]), Color(1, 0.85, 0.4, 0.13))
		ci.draw_circle(c, 150, Color(1, 0.85, 0.4, 0.2))
		Paint.level_badge(ci, c, 220)
		Paint.heroine(ci, Vector2(250, 1260), 160))
	UI.title(p.box, "部落升级！", Rect2(0, 210, 720, 110), 76)
	UI.lbl(p.box, str(G.level), Rect2(260, 400, 200, 140), 96, Color("fff1c4"), HORIZONTAL_ALIGNMENT_CENTER, 16, Art.INK, true)
	for k in rewards.size():
		var x := 105.0 + k * 170.0
		UI.icon(p.box, rewards[k][0], Vector2(x, 700), 130)
		UI.lbl(p.box, "×%d" % rewards[k][1], Rect2(x - 70, 760, 140, 50), 34, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 10, Art.INK, true)
	var hint := UI.lbl(p.box, "点击任意处领取", Rect2(0, 850, 720, 50), 28, Color("ffe7a8"), HORIZONTAL_ALIGNMENT_CENTER, 8, Art.INK)
	var tw := hint.create_tween().set_loops()
	tw.tween_property(hint, "modulate:a", 0.3, 0.6)
	tw.tween_property(hint, "modulate:a", 1.0, 0.6)
	Sfx.play("fanfare")
	p.on_tap = func():
		grant_rewards(rewards, func(k): return Vector2(105.0 + k * 170.0, 700))
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

## 发放奖励：体力/贝币/琥珀飞向顶栏，其他物品进暂存区
static func grant_rewards(rewards: Array, from: Callable) -> void:
	for k in rewards.size():
		var id: String = rewards[k][0]
		var n: int = rewards[k][1]
		var t := Data.type_of(id)
		var pos: Vector2 = from.call(k)
		if t in ["energy", "shell", "amber"]:
			G.main.fly(id, pos, G.main.topbar.target(t), func(): G.add_currency(t, n), 100)
		else:
			for j in n:
				G.stash.append(id)
			G.main.fly(id, pos, Vector2(64, 260), Callable(), 90)
	G.dirty()
	G.changed.emit()

static func level_info() -> PopupBase:
	var p := PopupBase.new()
	var r := Rect2(40, 250, 640, 1010)
	UI.box(p.box, Rect2(0, 0, 720, 1480), func(ci, _sz):
		Paint.panel(ci, r)
		var br := Rect2(r.get_center().x - 220, r.position.y + 30, 440, 80)
		Paint.banner(ci, br, Art.TEAL)
		Paint.level_badge(ci, Vector2(r.get_center().x, r.position.y - 6), 130)
		var art := Rect2(r.position.x + 40, r.position.y + 130, r.size.x - 80, 300)
		var ab := Art.rrect(art, 22, 401, 0.8)
		Art.dilate(ci, ab, 3.0, Art.INK)
		Paint.vgrad(ci, art.grow(-3), Color("8fd0d4"), Color("f0deb0"))
		var ground := []
		for k in 13:
			ground.append(Vector2(lerpf(art.position.x + 4, art.end.x - 4, float(k) / 12.0), art.position.y + 200 + sin(float(k) * 0.9) * 10.0))
		ground.append(art.end - Vector2(4, 4))
		ground.append(Vector2(art.position.x + 4, art.end.y - 4))
		ci.draw_colored_polygon(Art.poly(ground, 404, 0.5), Color("8bb39a"))
		Paint._spot_hut(ci, Vector2(art.position.x + 120, art.position.y + 250), 6)
		Paint.palm(ci, Vector2(art.end.x - 40, art.end.y - 6), 170, 3, Color("4a8a4a"))
		Paint.heroine(ci, Vector2(art.get_center().x + 50, art.position.y + 160), 120)
		Paint.book(ci, Vector2(art.get_center().x + 50, art.position.y + 236), 1.1)
		Art.outline(ci, ab, 3.0, Art.LEATHER_D)
		var bar := Rect2(r.position.x + 70, r.position.y + 560, 400, 44)
		Paint.bar(ci, bar, float(G.xp) / float(G.xp_need()), Art.MOSS)
		Art.item(ci, "xp_1", bar.position + Vector2(0, 22), 64)
		Paint.level_badge(ci, Vector2(bar.end.x + 70, bar.get_center().y), 92)
		var arr := Art.poly([Vector2(bar.end.x + 100, bar.position.y + 4), Vector2(bar.end.x + 122, bar.position.y - 20), Vector2(bar.end.x + 144, bar.position.y + 4), Vector2(bar.end.x + 130, bar.position.y + 4), Vector2(bar.end.x + 130, bar.position.y + 24), Vector2(bar.end.x + 114, bar.position.y + 24), Vector2(bar.end.x + 114, bar.position.y + 4)], 402)
		Art.fill(ci, arr, Art.MOSS, 3.0)
		var rb := Art.rrect(Rect2(r.position.x + 40, r.position.y + 680, r.size.x - 80, 280), 22, 403, 0.8)
		ci.draw_colored_polygon(rb, Color("ecd9b3"))
		Art.outline(ci, rb, 2.0, Color(0.6, 0.4, 0.2, 0.4)))
	UI.title(p.box, "部落等级", Rect2(r.get_center().x - 200, r.position.y + 50, 400, 60), 38, Color.WHITE)
	UI.lbl(p.box, str(G.level), Rect2(r.get_center().x - 60, r.position.y - 44, 120, 80), 50, Color("fff1c4"), HORIZONTAL_ALIGNMENT_CENTER, 10, Art.INK, true)
	var tip := UI.lbl(p.box, "完成带 ★ 的部落订单，提升部落等级并领取奖励！", Rect2(r.position.x + 40, r.position.y + 446, r.size.x - 80, 90), 25, Color("6b4a2a"))
	tip.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	UI.lbl(p.box, "%d/%d" % [G.xp, G.xp_need()], Rect2(r.position.x + 70, r.position.y + 560, 400, 44), 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK)
	UI.lbl(p.box, str(G.level + 1), Rect2(r.position.x + 480, r.position.y + 548, 80, 60), 34, Color("fff1c4"), HORIZONTAL_ALIGNMENT_CENTER, 8, Art.INK, true)
	section(p.box, "下一级奖励", r.position.y + 640, Color("8a5a30"))
	var rw := Data.level_rewards(G.level + 1)
	for k in rw.size():
		var cx := r.get_center().x + (float(k) - (rw.size() - 1) * 0.5) * 136.0
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

static func event() -> PopupBase:
	var p := PopupBase.new()
	p.dim_alpha = 1.0
	UI.box(p.box, Rect2(0, 0, 720, 1480), func(ci, sz): Paint.vgrad(ci, Rect2(Vector2.ZERO, sz), Color("4a4a8a"), Color("2f3a6a")), false)
	var fs := fullscreen(p)
	var sc: Scroller = fs[0]
	var root: Control = fs[1]
	UI.box(root, Rect2(0, 0, 720, 720), _paint_event)
	UI.title(root, "丰收祭", Rect2(0, 250, 720, 100), 72)
	UI.lbl(root, G.fmt_time(G.event_left()), Rect2(300, 350, 160, 44), 22, Art.INK)
	var info := UI.hit(root, Rect2(474, 342, 60, 60), func(): G.main.toast("开启兽皮卡包收集岩画卡牌，集齐卡册赢取大奖！"))
	info.extra = func(ci, sz): Paint.glyph(ci, "info", sz * 0.5, 1.2)
	var rw := [["fire_3", 800], ["amber_3", 250], ["chest_1", 1]]
	for k in 3:
		var x := 200.0 + k * 160.0
		UI.icon(root, rw[k][0], Vector2(x, 450), 90)
		UI.lbl(root, "×%d" % rw[k][1], Rect2(x - 70, 488, 140, 40), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 8, Art.INK, true)
	UI.lbl(root, "%d/%d" % [G.cards_total(), Data.ALBUMS.size() * 9], Rect2(200, 548, 380, 40), 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK)
	var got := G.tokens - G.token_claimed
	UI.lbl(root, "祭典鼓 %d/%d" % [got, G.TOKEN_STEP], Rect2(170, 616, 420, 36), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK)
	UI.lbl(root, "完成订单收集祭典鼓，攒满换兽皮卡包", Rect2(60, 656, 600, 30), 18, Color("ffe7a8"), HORIZONTAL_ALIGNMENT_CENTER, 5, Art.INK)
	for a in Data.ALBUMS.size():
		var cx := 128.0 + (a % 3) * 232.0
		var cy := 840.0 + (a / 3) * 330.0
		var hit := UI.hit(root, Rect2(cx - 110, cy - 120, 220, 300), func():
			G.main.open("album", a))
		hit.extra = func(ci, sz):
			var c := Vector2(sz.x * 0.5, 110)
			var circ := Art.ell(c, Vector2(100, 100), 200 + a, 0.02, 32)
			Art.dilate(ci, circ, 4.0, Art.INK)
			ci.draw_colored_polygon(circ, Art.BONE)
			ci.draw_colored_polygon(Art.ell(c, Vector2(88, 88), 210 + a, 0.0, 32), Paint.ALBUM_COL[a])
			Paint.card_art(ci, a, 0, Rect2(c - Vector2(62, 62), Vector2(124, 124)))
			var ribbon_cols := [Art.OCHRE, Art.MOSS, Color("c463a5"), Color("8f6cd0"), Color("3fa0d8"), Art.CLAY]
			var rr := Rect2(-6, 168, sz.x + 12, 56)
			var rb := Art.poly([rr.position, Vector2(rr.end.x, rr.position.y), Vector2(rr.end.x - 14, rr.get_center().y), rr.end, Vector2(rr.position.x, rr.end.y), Vector2(rr.position.x + 14, rr.get_center().y)], a)
			Art.dilate(ci, rb, 3.0, Art.INK)
			ci.draw_colored_polygon(rb, ribbon_cols[a % ribbon_cols.size()])
			Paint.bar(ci, Rect2(20, 240, sz.x - 40, 32), float(G.album_count(a)) / 9.0, Art.MOSS)
		UI.lbl(hit, Data.ALBUMS[a]["name"], Rect2(0, 168, 220, 56), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 8, Art.INK, true)
		UI.lbl(hit, "%d/9" % G.album_count(a), Rect2(0, 240, 220, 32), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK)
	sc.set_length(840.0 + 3 * 330.0 + 330.0 - 128.0)
	var shop := UI.hit(p.box, Rect2(590, 1340, 120, 130), func(): G.main.open("pack"))
	shop.extra = func(ci, sz):
		Art.item(ci, "pack_1", Vector2(sz.x * 0.5, 56), 100)
	UI.lbl(shop, "试开卡包", Rect2(0, 96, 120, 34), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK)
	return p

static func _paint_event(ci: CanvasItem, sz: Vector2) -> void:
	Paint.vgrad(ci, Rect2(0, 0, sz.x, 600), Color("1f2a5a"), Color("5a4f9a"))
	Paint.vgrad(ci, Rect2(0, 600, sz.x, 120), Color("5a4f9a"), Color("4a4a8a"))
	for i in 40:
		ci.draw_circle(Vector2(Art.srnd(i) * sz.x, 130 + Art.srnd(i + 50) * 140), 1.2 + Art.srnd(i + 7) * 2.0, Color(1, 1, 0.85, 0.5 + 0.5 * Art.srnd(i + 3)))
	ci.draw_circle(Vector2(600, 180), 50, Color(1, 0.95, 0.75, 0.25))
	ci.draw_circle(Vector2(600, 180), 36, Color("fff1c4"))
	Paint.hills(ci, 240, sz.x, 40, Color("2a2f5a"), 4, 300)
	var string := []
	for k in 9:
		string.append(Vector2(sz.x * float(k) / 8.0, 200 + sin(float(k) / 8.0 * PI) * 40.0))
	Art.pl(ci, string, 2.5, Art.BONE, 3)
	for k in 8:
		var q: Vector2 = string[k].lerp(string[k + 1], 0.5)
		var cols := [Art.CLAY, Art.OCHRE, Art.TEAL, Art.BONE]
		ci.draw_colored_polygon(Art.poly([q + Vector2(-16, -4), q + Vector2(16, -4), q + Vector2(0, 26)], k), cols[k % 4])
	ci.draw_colored_polygon(Art.ell(Vector2(360, 250), Vector2(200, 40), 1, 0.0, 24), Color(1, 0.6, 0.2, 0.25))
	Art.item(ci, "fire_3", Vector2(360, 190), 130)
	for k in 4:
		var x := 120.0 + k * 160.0
		if k == 1 or k == 2:
			x += (1 if k == 2 else -1) * 60.0
		Paint._hunter(ci, Vector2(x, 210), 1.6, Color("1a1430"), k)
	Paint.mascot(ci, Vector2(90, 200), 80)
	var tp := Art.rrect(Rect2(296, 350, 168, 44), 22, 220, 0.6)
	Art.dilate(ci, tp, 2.5, Art.INK)
	ci.draw_colored_polygon(tp, Art.BONE)
	Paint.glyph(ci, "clock", Vector2(318, 372), 1.0)
	var rb := Art.rrect(Rect2(60, 404, 600, 136), 22, 221, 0.8)
	ci.draw_colored_polygon(rb, Color(0.1, 0.1, 0.25, 0.5))
	Art.outline(ci, rb, 2.0, Color(1, 1, 1, 0.2))
	Paint.bar(ci, Rect2(170, 552, 420, 34), float(G.cards_total()) / float(Data.ALBUMS.size() * 9), Art.MOSS)
	Paint.cards_icon(ci, Vector2(160, 568), 0.6)
	var got := G.tokens - G.token_claimed
	Paint.bar(ci, Rect2(170, 616, 420, 36), float(got) / float(G.TOKEN_STEP), Art.OCHRE)
	Art.item(ci, "token_1", Vector2(160, 630), 64)
	Art.item(ci, "pack_1", Vector2(610, 630), 64)

static func album(a: int) -> PopupBase:
	var p := PopupBase.new()
	var r := Rect2(30, 250, 660, 1000)
	frame(p, r, Data.ALBUMS[a]["name"], Paint.ALBUM_COL[a].darkened(0.2))
	UI.lbl(p.box, "已收集 %d/9" % G.album_count(a), Rect2(r.position.x, r.position.y + 56, r.size.x, 40), 24, Color("7a5a3a"))
	for k in 9:
		var cx := r.position.x + 120 + (k % 3) * 210
		var cy := r.position.y + 120 + (k / 3) * 280
		var key := "%d_%d" % [a, k]
		var owned := G.cards.has(key)
		UI.box(p.box, Rect2(cx - 90, cy, 180, 250), func(ci, sz): Paint.card(ci, Rect2(Vector2(4, 4), sz - Vector2(8, 8)), a, k, owned))
		UI.lbl(p.box, Data.ALBUMS[a]["cards"][k] if owned else "？？？", Rect2(cx - 90, cy + 196, 180, 44), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK)
		if owned and int(G.cards[key]) > 1:
			UI.lbl(p.box, "×%d" % int(G.cards[key]), Rect2(cx + 30, cy + 4, 60, 34), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.CLAY)
	return p

# ---------------------------------------------------------------- 开卡包

static func pack() -> PopupBase:
	var p := PopupBase.new()
	p.dim_alpha = 0.82
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
		Art.item(ci, "pack_1", c, 300, true, wob))
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
		var got := G.open_pack()
		for k in got.size():
			var ab: int = got[k][0]
			var ix: int = got[k][1]
			var cr := Rect2(110 + k * 270, 520, 230, 320)
			var cb := UI.box(p.box, cr, func(ci, sz): Paint.card(ci, Rect2(Vector2(6, 6), sz - Vector2(12, 12)), ab, ix, true))
			var nl := UI.lbl(cb, Data.ALBUMS[ab]["cards"][ix], Rect2(0, 252, 230, 50), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 8, Art.INK, true)
			nl.position.y = 250
			cb.pivot_offset = cr.size * 0.5
			cb.scale = Vector2(0.0, 1.0)
			var tw := cb.create_tween()
			tw.tween_interval(0.15 + k * 0.2)
			tw.tween_property(cb, "scale", Vector2(1.1, 1.1), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(cb, "scale", Vector2.ONE, 0.1)
			UI.lbl(p.box, Data.ALBUMS[ab]["name"], Rect2(cr.position.x, cr.position.y - 50, cr.size.x, 40), 22, Color("ffe7a8"), HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK)
		var btn := UI.btn(p.box, Rect2(210, 1100, 300, 104), "收下", "green", p.close, 44)
		btn.scale = Vector2.ZERO
		btn.create_tween().tween_property(btn, "scale", Vector2.ONE, 0.25).set_delay(0.6).set_trans(Tween.TRANS_BACK)
	return p
