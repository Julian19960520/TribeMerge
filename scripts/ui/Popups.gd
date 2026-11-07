class_name Popups
extends RefCounted
## 所有弹窗的构建函数。每个函数返回一个 PopupBase，由 Main.open() 打开。

const Layout := preload("res://scripts/config/board_layout.gd")
const HotDeals := preload("res://scripts/HotDeals.gd")

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
	var fs := 26
	var tw := float(text.length()) * float(fs)
	if G.font_body:
		tw = G.font_body.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var half := tw * 0.5 + 14.0
	var edge := 26.0
	UI.lbl(parent, text, Rect2(cx - 240, y, 480, 40), fs, col)
	UI.box(parent, Rect2(cx - 260, y, 520, 40), func(ci, sz):
		var mid: float = sz.x * 0.5
		var left_star := clampf(mid - half, edge + 18.0, mid - 36.0)
		var right_star := clampf(mid + half, mid + 36.0, sz.x - edge - 18.0)
		Art.ln(ci, Vector2(edge, 20), Vector2(left_star - 10.0, 20), 2.0, Color(col, 0.5), 1)
		Art.ln(ci, Vector2(right_star + 10.0, 20), Vector2(sz.x - edge, 20), 2.0, Color(col, 0.5), 2)
		ci.draw_colored_polygon(Art.star_pts(Vector2(left_star, 20), 6, 2.5, 4, 3), Color(col, 0.6))
		ci.draw_colored_polygon(Art.star_pts(Vector2(right_star, 20), 6, 2.5, 4, 4), Color(col, 0.6)))

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
	var price := G.energy_price()
	var b := UI.btn(p.box, Rect2(r.get_center().x - 150, r.position.y + 560, 300, 100), str(price), "green", Callable(), 44)
	b.res = Art.AMBER_ICON
	UI.lbl(p.box, "今天第 %d 次购买，每次涨价，零点恢复。" % (G.energy_buys + 1), Rect2(r.position.x + 30, r.position.y + 676, r.size.x - 60, 40), 22, Color("8a6a4a"))
	b.pressed.connect(func():
		if await G.buy_energy():
			Rewards.grant([["fire_2", 100]], func(_k): return Vector2(360, 760))
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
		Art.item(ci, "roast_7", Vector2(160, 300), 110)
		Paint.button(ci, Rect2(120, 360, 140, 56), "green")
		ci.draw_polyline(PackedVector2Array([Vector2(170, 384), Vector2(186, 398), Vector2(212, 372)]), Color.WHITE, 7.0, true)
		_arrow(ci, Vector2(330, 360), Vector2(500, 450), 0.4)
		Art.item(ci, "shell_4", Vector2(560, 540), 170)
		_arrow(ci, Vector2(520, 660), Vector2(380, 760), 0.4)
		Art.item(ci, "chest_1", Vector2(220, 830), 200)
		Art.item(ci, "fruit_2", Vector2(150, 720), 70)
		Art.item(ci, "amber_4", Vector2(290, 700), 70)
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
	UI.btn(root, Rect2(430, 396, 240, 80), "激活", "green", func(): G.main.open("pass_buy"), 38)
	section(root, "每日特惠", 516, Color("ffd23f"))
	G._check_day()
	# 每日特惠一排 5 张（顺序固定：广告 → 贝币买体力宝箱 → 贵宾琥珀 → 超级贵宾琥珀 → 免费体力）
	var deals := Data.daily_deals(G.level)
	var dn := maxi(1, deals.size())
	var dw := (660.0 - (dn - 1) * 10.0) / dn
	for k in deals.size():
		_daily_card(root, Rect2(30.0 + k * (dw + 10.0), 566, dw, 236), deals[k], k)
	var clocks: Array = []
	clocks.append(_refresh_bar(root, Rect2(30, 818, 660, 66), Color("6c492e"), "明天 0 点上新", func(): return [G.secs_to_midnight(), 86400], "", 0, Callable()))
	var y := 904.0
	# 贝币小摊：用贝币买低一级的普通货，库存少，每 8 小时按服务器时间补货；花少量琥珀可立即补货
	G.check_shell_period()
	section(root, "贝币小摊", y, Color("bfe3ff"))
	var sy := y + 44.0
	for k in Data.STORE_SHELL.size():
		var d: Dictionary = Data.STORE_SHELL[k]
		sy = y + 44.0 + (k / 3) * 270.0
		_shell_card(root, Rect2(30.0 + (k % 3) * 226.0, sy, 208, 250), d, "shell_%d" % k)
	if not Data.STORE_SHELL.is_empty():
		sy += 264.0
		var shell_bar: Array = []
		shell_bar.append(_refresh_bar(root, Rect2(30, sy, 660, 86), Color("405f70"), "小摊补货", func(): return [G.shell_secs_left(), Data.STORE_SHELL_HOURS * 3600], "补货", Data.STORE_SHELL_REFRESH, func():
			var rb: TButton = shell_bar[0]["btn"]
			rb.enabled = false
			var result: Dictionary = await G.refresh_shell()
			if not is_instance_valid(rb): return
			rb.enabled = true
			rb.queue_redraw()
			if result.get("ok", false): Sfx.play("pop")
			else: G.main.toast(str(result.get("message", "补货失败")))))
		clocks.append(shell_bar[0])
		y = sy + 108.0
	section(root, "热卖", y, Color("ffd23f"))
	var hot_root := Control.new()
	hot_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hot_root)
	var hot_state := {"sig": ""}
	var hot_y := y + 44.0
	var draw_hot := func():
		var hot: Array = HotDeals.today()
		var sig := G.today() + ":" + str(G.hot_revision) + JSON.stringify(hot)
		if sig == str(hot_state["sig"]): return
		hot_state["sig"] = sig
		for child in hot_root.get_children():
			hot_root.remove_child(child)
			child.queue_free()
		for k in hot.size():
			var d: Dictionary = hot[k]
			_store_card(hot_root, Rect2(30.0 + (k % 3) * 226.0, hot_y + (k / 3) * 270.0, 208, 250), d, "hot_%d" % k, false)
	draw_hot.call()
	y = hot_y + ceilf(float(Data.STORE_HOT.size()) / 3.0) * 270.0 - 6.0
	var hot_bar: Array = []
	hot_bar.append(_refresh_bar(root, Rect2(30, y, 660, 86), Color("6c492e"), "热卖刷新", func(): return [G.secs_to_midnight(), 86400], "刷新", 10, func():
		var rb: TButton = hot_bar[0]["btn"]
		rb.enabled = false
		var result: Dictionary = await G.refresh_hot()
		if not is_instance_valid(rb): return
		rb.enabled = true
		rb.queue_redraw()
		if result.get("ok", false):
			draw_hot.call()
			Sfx.play("pop")
		else:
			G.main.toast(str(result.get("message", "刷新失败")))))
	clocks.append(hot_bar[0])
	live(p, G.changed, func(): draw_hot.call())
	y += 108.0
	# 倒计时每秒走一次（不靠 G.changed，静止时也在走）
	var ticker := Timer.new()
	ticker.wait_time = 1.0
	ticker.autostart = true
	p.add_child(ticker)
	var tick := func():
		for c in clocks: _tick_bar(c)
	ticker.timeout.connect(tick)
	tick.call()
	section(root, "琥珀", y, Color("ffd23f"))
	y += 48.0
	for k in Data.AMBER_PACKS.size():
		var a: Dictionary = Data.AMBER_PACKS[k]
		_amber_card(root, Rect2(30.0 + (k % 3) * 226.0, y + (k / 3) * 280.0, 208, 260), a, k)
	y += 2 * 280.0 + 40.0
	sc.set_length(y - 128.0)
	return p

## 每日特惠的一张小卡。边框颜色按类型：广告青、贝币蓝、会员紫、免费绿；会员卡顶上挂档位签。
static func _daily_card(parent: Control, r: Rect2, d: Dictionary, k: int) -> void:
	var key := str(d["key"])
	var tier := int(d.get("min_tier", 0))
	var member := tier > 0
	var ad := str(d.get("mode", "")) == "ad"
	var paid := int(d["price"]) > 0
	var col: Color = Color("4fa39a") if ad else (Color("6f9fb8") if paid else (Color("8a5bb8") if member else Color("7fb43a")))
	var state := {"claimed": false}
	var card := UI.box(parent, r, func(ci, sz):
		ci.draw_colored_polygon(Art.rrect(Rect2(Vector2(0, 8), sz), 18, 3, 0.0), Color(0, 0, 0, 0.3))
		var b := Art.rrect(Rect2(Vector2.ZERO, sz), 18, 105 + k, 0.8)
		Art.dilate(ci, b, 3.0, Art.INK)
		ci.draw_colored_polygon(b, col)
		var ir := Rect2(7, 7, sz.x - 14, 122)
		ci.draw_colored_polygon(Art.rrect(ir, 13, 110 + k, 0.5), Art.BONE)
		ci.draw_colored_polygon(Art.ell(Vector2(sz.x * 0.5, 110), Vector2(32, 6), 115 + k, 0.0, 14), Color(0, 0, 0, 0.1))
		Art.item(ci, str(d["id"]), Vector2(sz.x * 0.5, 72), 86)
		if member or ad:
			var tw := 100.0 if tier >= 2 else 64.0
			var t := Art.rrect(Rect2(sz.x * 0.5 - tw * 0.5, -13, tw, 28), 12, 120 + k, 0.4)
			Art.dilate(ci, t, 2.5, Art.INK)
			ci.draw_colored_polygon(t, Color("2a7469") if ad else (Color("f4c542") if tier >= 2 else Color("e0cdf5")))
		if state["claimed"]:
			ci.draw_colored_polygon(Art.rrect(ir, 13, 110 + k, 0.0), Color(0.25, 0.18, 0.1, 0.35))
			var cc := Vector2(sz.x * 0.5, 72)
			ci.draw_circle(cc, 26, Art.INK)
			ci.draw_circle(cc, 23, Art.MOSS)
			Paint.check_mark(ci, cc, 1.2))
	if member:
		UI.lbl(parent, str(d.get("badge", "会员")), Rect2(r.position.x, r.position.y - 13, r.size.x, 28), 17, Color("4a2266") if tier < 2 else Color("5a3300"), HORIZONTAL_ALIGNMENT_CENTER)
	elif ad:
		UI.lbl(parent, "广告", Rect2(r.position.x, r.position.y - 13, r.size.x, 28), 17, Color.WHITE)
	UI.hit(parent, Rect2(r.position + Vector2(6, 6), Vector2(r.size.x - 12, 120)), func(): G.main.open("item_info", str(d["id"])))
	UI.lbl(parent, str(d.get("title", Data.name_of(str(d["id"])))), Rect2(r.position + Vector2(0, 132), Vector2(r.size.x, 32)), 21, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 5, Art.INK)
	var b := UI.btn(parent, Rect2(r.position + Vector2(7, 170), Vector2(r.size.x - 14, 58)), "", "green", Callable(), 22)
	b.name = "daily_" + key
	var refresh := func():
		var claimed := G.deals_day == G.today() and int(G.deals_bought.get(key, 0)) >= int(d["stock"])
		var locked := member and G.pass_tier < tier
		state["claimed"] = claimed
		card.queue_redraw()
		if claimed: b.text = "已领取"
		elif locked: b.text = "开通"
		elif ad: b.text = "看广告"
		elif paid: b.text = str(int(d["price"]))
		else: b.text = "领取"
		b.res = ("shell_2" if str(d.get("currency", "amber")) == "shell" else Art.AMBER_ICON) if paid and not claimed else ""
		b.enabled = not claimed
		b.style = "grey" if claimed else ("orange" if locked else ("teal" if ad else "green"))
		b.queue_redraw()
	refresh.call()
	live(b, G.changed, refresh)
	b.pressed.connect(func():
		if member and G.pass_tier < tier:
			G.main.open("pass_buy")
			return
		if ad:
			G.main.open("daily_ad")
			return
		b.enabled = false
		var result: Dictionary = await DailyShop.claim(key, b.get_global_rect().get_center() - Vector2(0, 100))
		if not result.get("ok", false): G.main.toast(str(result.get("message", "领取失败")))
		if is_instance_valid(b): refresh.call())

## 刷新倒计时条：左边沙漏 + 标题 + 「07:12:33」+ 本轮剩余进度槽；右边可选的琥珀刷新按钮。
## left_fn 返回 [剩余秒数, 一轮总秒数]。返回的字典交给 _tick_bar 每秒更新。
static func _refresh_bar(root: Control, r: Rect2, col: Color, title: String, left_fn: Callable, btn_text: String, cost: int, cb: Callable) -> Dictionary:
	var st := {"t": 0.0}
	var has_btn := btn_text != ""
	var bar_w := r.size.x - (262.0 if has_btn else 110.0)
	var bar := UI.box(root, r, func(ci, sz):
		ci.draw_colored_polygon(Art.rrect(Rect2(Vector2(0, 6), sz), 18, 3, 0.0), Color(0, 0, 0, 0.28))
		var b := Art.rrect(Rect2(Vector2.ZERO, sz), 18, 125 + int(r.position.y) % 7, 0.6)
		Art.dilate(ci, b, 3.0, Art.INK)
		ci.draw_colored_polygon(b, col)
		ci.draw_colored_polygon(Art.rrect(Rect2(6, 5, sz.x - 12, sz.y * 0.4), 12, 126, 0.3), Color(1, 1, 1, 0.08))
		Art.item(ci, "sand_3", Vector2(42, sz.y * 0.5), minf(60.0, sz.y - 8.0), false)
		var tr := Rect2(80, sz.y - 22, bar_w, 12)
		ci.draw_colored_polygon(Art.rrect(tr, 6, 127, 0.0), Color(0, 0, 0, 0.35))
		var f: float = clampf(float(st["t"]), 0.0, 1.0)
		if f > 0.01:
			ci.draw_colored_polygon(Art.rrect(Rect2(tr.position, Vector2(maxf(12.0, tr.size.x * f), tr.size.y)), 6, 128, 0.0), Color("ffd23f")))
	var small := r.size.y < 80.0
	var ty := r.position.y + (6.0 if small else 10.0)
	UI.lbl(root, title, Rect2(r.position.x + 80, ty, 220, 32), 20, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_LEFT)
	var time := UI.lbl(root, "", Rect2(r.position.x + 80, ty - 2, bar_w, 36), 26 if small else 30, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 5, Art.INK)
	var out := {"time": time, "fn": left_fn, "bar": bar, "st": st, "btn": null}
	if has_btn:
		var rb := UI.btn(root, Rect2(r.end.x - 170, r.position.y + 11, 158, r.size.y - 22), "%d %s" % [cost, btn_text], "green", cb, 24)
		rb.res = Art.AMBER_ICON
		out["btn"] = rb
	return out

static func _tick_bar(c: Dictionary) -> void:
	var t: Array = (c["fn"] as Callable).call()
	var left := maxi(0, int(t[0]))
	(c["time"] as Label).text = "%02d:%02d:%02d" % [left / 3600, (left % 3600) / 60, left % 60]
	c["st"]["t"] = float(left) / maxf(1.0, float(t[1]))
	(c["bar"] as DrawBox).queue_redraw()

static func _amber_card(parent: Control, r: Rect2, a: Dictionary, k: int) -> void:
	# 礼包越大，堆的六边琥珀越多
	var piles := [[Art.AMBER_ICON, 1], [Art.AMBER_ICON, 2], [Art.AMBER_ICON, 3], [Art.AMBER_ICON, 4], [Art.AMBER_ICON, 5], [Art.AMBER_ICON, 6]]
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
	UI.hit(parent, Rect2(r.position + Vector2(8, 8), Vector2(r.size.x - 16, 114)), func(): G.main.open("item_info", Art.AMBER_ICON))
	if k >= 4:
		var hl := UI.lbl(parent, "超值", Rect2(r.position.x - 6, r.position.y + 8, 72, 36), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 5, Art.INK, true)
		hl.rotation = -0.2
	UI.lbl(parent, "×%d" % a["n"], Rect2(r.position.x, r.position.y + 128, r.size.x, 40), 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 8, Art.INK, true)
	var b := UI.btn(parent, Rect2(r.position.x + 22, r.position.y + 184, r.size.x - 44, 64), a["price"], "orange", Callable(), 30)
	b.title_font = false
	b.pressed.connect(func():
		# 服务器下单 → 支付回调到账（现在是 mock 支付），到账后再播飞入动画
		var got: int = await G.buy_amber_pack(k)
		if got <= 0:
			return
		Rewards.grant([[Art.AMBER_ICON, got]], func(_k): return b.get_global_rect().get_center() + Vector2(0, -100))
		G.main.toast("演示版本：琥珀 ×%d 已到账" % got))

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
		Art.item(ci, Art.AMBER_ICON, Vector2(70 + k * 34, 380 - (k % 2) * 10), 54)
	Art.item(ci, "fire_4", Vector2(270, 330), 80)
	var tag := Art.rrect(Rect2(470, 344, 160, 44), 10, 122, 0.6)
	Art.dilate(ci, tag, 2.5, Art.INK)
	ci.draw_colored_polygon(tag, Color("e9d8ff"))
	Art.item(ci, "pack_1", Vector2(480, 286), 60)

static func _store_card(parent: Control, r: Rect2, d: Dictionary, key: String, hot: bool) -> void:
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
			Art.fill(ci, seal, Art.CLAY, 3.0))
	if hot:
		var hl := UI.lbl(parent, "免费" if int(d["price"]) == 0 else "HOT", Rect2(r.position.x - 6, r.position.y + 6, 72, 36), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 5, Art.INK, true)
		hl.rotation = -0.2
	UI.hit(parent, Rect2(r.position + Vector2(8, 8), Vector2(r.size.x - 16, 114)), func(): G.main.open("item_info", str(d["id"])))
	var left_lbl := UI.lbl(parent, "", Rect2(r.position.x, r.position.y + 128, r.size.x, 34), 22, Color("6b4a2a"))
	var b := UI.btn(parent, Rect2(r.position.x + 22, r.position.y + 178, r.size.x - 44, 64), "", "green", Callable(), 30)
	var refresh := func():
		var book_of: Dictionary = G.deals_bought if hot else G.hot_bought
		var left: int = maxi(0, int(d["stock"]) - int(book_of.get(key, 0)))
		left_lbl.text = "剩余 %d" % left
		b.text = ("免费" if int(d["price"]) == 0 else str(d["price"])) if left > 0 else ("已领取" if int(d["price"]) == 0 else "售罄")
		b.res = Art.AMBER_ICON if left > 0 and int(d["price"]) > 0 else ""
		b.style = "green" if left > 0 else "grey"
		b.enabled = left > 0
		b.queue_redraw()
	refresh.call()
	live(b, G.changed, refresh)
	b.pressed.connect(func():
		var origin: Vector2 = b.get_global_rect().get_center() + Vector2(0, -110)
		if await _buy_offer(str(d["id"]), {"price": int(d["price"]), "key": key, "deal": hot}, origin):
			refresh.call())

## 贝币小摊的一格：样子同热卖卡片，换成浅蓝底、价格按钮用贝币图标
static func _shell_card(parent: Control, r: Rect2, d: Dictionary, key: String) -> void:
	UI.box(parent, r, func(ci, sz):
		var b := Art.rrect(Rect2(Vector2.ZERO, sz), 20, int(r.position.x) + 7, 1.0)
		ci.draw_colored_polygon(Art.rrect(Rect2(Vector2(0, 8), sz), 20, 3, 0.0), Color(0, 0, 0, 0.3))
		Art.dilate(ci, b, 3.0, Art.INK)
		ci.draw_colored_polygon(b, Color("6f9fb8"))
		var ir := Rect2(10, 10, sz.x - 20, sz.y - 86)
		ci.draw_colored_polygon(Art.rrect(ir, 14, 5, 0.6), Color("eef6f2"))
		Art.item(ci, d["id"], Vector2(sz.x * 0.5, 82), 112))
	UI.hit(parent, Rect2(r.position + Vector2(8, 8), Vector2(r.size.x - 16, 114)), func(): G.main.open("item_info", str(d["id"])))
	var left_lbl := UI.lbl(parent, "", Rect2(r.position.x, r.position.y + 128, r.size.x, 34), 22, Color("2f4f60"))
	var b := UI.btn(parent, Rect2(r.position.x + 22, r.position.y + 178, r.size.x - 44, 64), "", "green", Callable(), 30)
	var refresh := func():
		G.check_shell_period()
		var left: int = int(d["stock"]) - int(G.shell_bought.get(key, 0))
		left_lbl.text = "剩余 %d" % left
		b.text = str(int(d["price"])) if left > 0 else "售罄"
		b.res = "shell_2" if left > 0 else ""
		b.style = "green" if left > 0 else "grey"
		b.enabled = left > 0
		b.queue_redraw()
	refresh.call()
	live(b, G.changed, refresh)
	b.pressed.connect(func():
		var origin: Vector2 = b.get_global_rect().get_center() + Vector2(0, -110)
		if await _buy_offer(str(d["id"]), _shell_offer(key), origin):
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
	var cfg := UI.btn(p.box, Rect2(r.position.x + 36, r.position.y + 690, 180, 50), "数据配置", "teal", Callable(), 22)
	cfg.title_font = false
	cfg.pressed.connect(func():
		p.close()
		G.main.show_screen("cfg"))
	var acct := UI.btn(p.box, Rect2(106, r.position.y + 510, 508, 70), "账号与数据", "teal", Callable(), 30)
	acct.pressed.connect(func():
		p.close()
		load("res://scripts/ui/AccountPopup.gd").open())
	var reset := UI.btn(p.box, Rect2(r.end.x - 170, r.position.y + 690, 130, 50), "重新开始", "grey", Callable(), 20)
	reset.title_font = false
	reset.pressed.connect(func():
		G.reset_game()
		G.main.call_deferred("begin_guide"))
	return p

# ---------------------------------------------------------------- 建造

## 部落建造：一个区域的全部部件。已建好的亮着、下一件高亮、之后的是剪影。花贝币建下一件 → 主页播建造动画 → 领奖。
static func build(id: String) -> PopupBase:
	var p := PopupBase.new()
	var d := Data.build_def(id)
	if d.is_empty():
		return null
	var parts := Data.build_parts(d)
	var total := parts.size()
	var st := clampi(int(G.builds.get(id, 0)), 0, total)
	var done := st >= total
	var open := G.build_open(id)
	var r := Rect2(40, 390, 640, 780)
	frame(p, r, str(d.get("name", id)), Color("4f8fc0"), "hammer")
	var line_name := ""
	for l in Data.LINES:
		if str(l.get("id", "")) == str(d.get("line", "")):
			line_name = str(l.get("name", ""))
	var sub := "已建 %d/%d" % [st, total]
	if line_name != "":
		sub = "%s产线 · %s" % [line_name, sub]
	UI.box(p.box, Rect2(200, r.position.y + 54, 320, 40), func(ci, sz):
		ci.draw_colored_polygon(Art.rrect(Rect2(Vector2.ZERO, sz), 20, 131, 0.6), Color(0.6, 0.45, 0.25, 0.25)))
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
		var b := Art.rrect(Rect2(Vector2.ZERO, sz), 18, 132, 0.8)
		ci.draw_colored_polygon(b, Color("ecd9b3"))
		Art.outline(ci, b, 2.0, Color(0.6, 0.4, 0.2, 0.3)))
	var rewards := G.build_rewards(id) if open and not done else []
	var cost := G.build_cost(id)
	if done:
		UI.lbl(p.box, "这里已经全部建好啦！", Rect2(box.position.x, box.position.y + 50, box.size.x, 50), 28, Color("6b4a2a"))
	elif not open:
		UI.lbl(p.box, "主角 %d 级开放「%s」" % [Data.build_unlock(d), str(d.get("name", id))], Rect2(box.position.x, box.position.y + 30, box.size.x, 50), 28, Color("6b4a2a"))
		UI.lbl(p.box, "开放后这里的部件会送%s产线的物品" % line_name if line_name != "" else "", Rect2(box.position.x, box.position.y + 80, box.size.x, 40), 20, Color("8a6a4a"))
	else:
		var nxt: Dictionary = parts[st]
		UI.lbl(p.box, "建好「%s」获得" % str(nxt.get("name", "")), Rect2(box.position.x, box.position.y + 6, box.size.x, 36), 22, Color("7a5a3a"))
		if rewards.is_empty():
			UI.lbl(p.box, "这次没有奖励", Rect2(box.position.x, box.position.y + 60, box.size.x, 50), 26, Color("6b4a2a"))
		var icon_s := 84.0 if rewards.size() <= 3 else 70.0
		for k in rewards.size():
			var c := Vector2(_spread_x(k, rewards.size(), box.get_center().x, 140.0), box.position.y + 84)
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
			G.main.toast("贝币不够，去完成订单吧！")
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
static func _build_card(ci: CanvasItem, sz: Vector2, kind: String, state: int, open: bool, seed: int) -> void:
	var r := Rect2(4, 4, sz.x - 8, sz.y - 8)
	var b := Art.rrect(r, 16, 140 + seed, 0.7)
	if state == 1 and open:
		Art.dilate(ci, b, 4.0, Color("ffd23f"))
		Art.dilate(ci, b, 2.0, Art.INK)
		ci.draw_colored_polygon(b, Color("8cc6a0"))
	else:
		ci.draw_colored_polygon(b, Color("ecd9b3") if state == 0 else Color("dcc9a2"))
		Art.outline(ci, b, 2.0, Color(0.6, 0.4, 0.2, 0.35))
	var art := Rect2(r.position + Vector2(12, 8), Vector2(r.size.x - 24, r.size.y - 58))
	TribeArt.icon(ci, kind, art, state == 2 or not open)
	if state == 0:
		Paint.check_mark(ci, Vector2(sz.x - 24, 24), 0.8)
	elif state == 2 or not open:
		Paint.glyph(ci, "lock", Vector2(sz.x - 24, 24), 0.8)

# ---------------------------------------------------------------- 图鉴

static func book(tab: int = 0) -> PopupBase:
	var p := PopupBase.new()
	var r := Rect2(24, 240, 672, 1040)
	var br := Rect2(r.get_center().x - 130, r.position.y - 34, 260, 78)
	UI.box(p.box, Rect2(0, 0, 720, 1480), func(ci, _sz):
		Paint.panel(ci, r)
		Paint.banner(ci, br, Color("a85a30"), 8))
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.box.add_child(holder)
	var lines: Array = Data.LINES.duplicate()
	lines.append({"id": "craft", "gen": "salad"})
	var state := {"line": clampi(tab, 0, maxi(lines.size() - 1, 0))}
	var tab_btns: Array[TButton] = []
	for i in lines.size():
		var idx := i
		var line: Dictionary = lines[i]
		var icon := "salad" if str(line.get("id", "")) == "craft" else _book_icon(line)
		var b := UI.hit(p.box, _book_tab_rect(i, lines.size(), i == int(state["line"])), func():
			if idx == int(state["line"]):
				return
			state["line"] = idx
			_book_place_tabs(tab_btns, idx)
			_book_page(holder, r, idx))
		b.extra = func(ci, sz): _book_tab_draw(ci, sz, idx == int(state["line"]), icon, idx)
		tab_btns.append(b)
	_book_page(holder, r, int(state["line"]))
	var heading := UI.title(p.box, "图鉴", Rect2(br.position.x + 16, br.position.y + 2, br.size.x - 32, br.size.y - 6), 40, Color.WHITE)
	var x := UI.hit(p.box, Rect2(r.end.x - 52, r.position.y - 24, 70, 70), p.close)
	x.extra = func(ci, sz): Paint.close_btn(ci, sz * 0.5, 28)
	return p

## 右边缘的产线页签。选中的一页往左探出来。
static func _book_tab_rect(i: int, n: int, on: bool) -> Rect2:
	var w := 84.0
	var h := 88.0
	var gap := 14.0
	var stack := float(n) * h + float(maxi(n - 1, 0)) * gap
	var y0 := 240.0 + (1040.0 - stack) * 0.5
	var x := 720.0 - w + (0.0 if on else 16.0)
	return Rect2(x, y0 + float(i) * (h + gap), w, h)

static func _book_place_tabs(btns: Array[TButton], line: int) -> void:
	for i in btns.size():
		var rect := _book_tab_rect(i, btns.size(), i == line)
		btns[i].position = rect.position
		btns[i].size = rect.size
		btns[i].pivot_offset = rect.size * 0.5
		btns[i].queue_redraw()

static func _book_tab_draw(ci: CanvasItem, sz: Vector2, on: bool, icon: String, seed: int) -> void:
	var tag := Art.rrect(Rect2(0, 3, sz.x + 18, sz.y - 6), 14, 180 + seed, 0.7)
	Art.dilate(ci, tag, 3.0, Art.INK)
	ci.draw_colored_polygon(tag, Color("c47a3a") if on else Art.LEATHER_D)
	var plate := Art.rrect(Rect2(7, 9, sz.x - 20, sz.y - 18), 12, 190 + seed, 0.5)
	ci.draw_colored_polygon(plate, Color("f0d7b0") if on else Color("8a5a32"))
	Art.item(ci, icon, Vector2(sz.x * 0.5 - 6.0, sz.y * 0.52), 58.0)

## 每条产线右缘页签上的图。
static func _book_icon(line: Dictionary) -> String:
	var known := {
		"food": "fruit_6",
		"tool": "tool_5",
		"cloth": "cloth_7",
		"hunt": "beast_10",
		"fire": "hearth_5",
		"wood": "furn_10",
		"pot": "pot_6",
	}
	var id := str(line.get("id", ""))
	if known.has(id):
		return str(known[id])
	return "%s_1" % str(line.get("gen", "fruit"))

static func _book_cell_x(r: Rect2, col: int) -> float:
	return r.position.x + 122.0 + float(col) * 126.0

static func _book_page(holder: Control, r: Rect2, line_i: int) -> void:
	for c in holder.get_children():
		c.queue_free()
	if line_i == Data.LINES.size():
		_book_dishes(holder, r)
		return
	if Data.LINES.is_empty():
		return
	var line: Dictionary = Data.LINES[clampi(line_i, 0, Data.LINES.size() - 1)]
	var top := r.position.y + 58
	var sc := Scroller.new()
	sc.position = Vector2(0, top)
	sc.size = Vector2(630, r.end.y - 20 - top)
	holder.add_child(sc)
	var page := sc.content
	var y := 16.0
	y = _book_chain(page, r, str(line["gen"]), y)
	y = _book_chain(page, r, str(line["main"]), y)
	y = _book_chain(page, r, str(line["sub"]), y)
	sc.set_length(y + 8.0)
	holder.modulate.a = 0.0
	holder.create_tween().tween_property(holder, "modulate:a", 1.0, 0.15)

## 一页里的一条链。格子每行 4 个。
static func _book_chain(page: Control, r: Rect2, chain_id: String, y: float) -> float:
	var c: Dictionary = Data.CHAINS[chain_id]
	var items: Array = c["items"]
	var n := 0
	for l in items.size():
		if G.discovered.has("%s_%d" % [chain_id, l + 1]):
			n += 1
	var mid := _book_cell_x(r, 0) + 126.0 * 1.5
	section(page, "%s（%d/%d）" % [str(c["name"]), n, items.size()], y, Color("8a5a30"), mid)
	y += 52
	for l in items.size():
		var lv := l
		var id := "%s_%d" % [chain_id, lv + 1]
		var cx := _book_cell_x(r, lv % 4)
		_book_slot(page, Rect2(cx - 52, y, 104, 104), id, lv)
		if lv % 4 == 3 and lv < items.size() - 1:
			y += 116
	return y + 126.0

static func _book_slot(page: Control, cell: Rect2, id: String, seed: int) -> void:
	var box := UI.box(page, cell, func(ci, sz):
		var b := Art.rrect(Rect2(Vector2.ZERO, sz), 18, seed + 150, 0.6)
		ci.draw_colored_polygon(b, Color("ecd9b3"))
		Art.outline(ci, b, 2.0, Color(0.6, 0.4, 0.2, 0.35))
		if not G.discovered.has(id):
			var f: Font = G.font_title
			ci.draw_string(f, Vector2(sz.x * 0.5 - 18, sz.y * 0.5 + 20), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 60, Color(0.7, 0.55, 0.35, 0.6))
		elif G.book_prize(id):
			Paint.gift(ci, sz * 0.5, 86)
		else:
			Art.item(ci, id, sz * 0.5, 86))
	var slot := {"b": null}
	var btn := UI.hit(page, cell, func():
		if not G.discovered.has(id): return
		var b: Control = slot["b"]
		if not G.book_prize(id):
			G.main.open("item_info", id)
			return
		var fire: int = await G.claim_book(id)
		if fire <= 0:
			return
		box.queue_redraw()
		Sfx.play("coin")
		var from := b.get_global_rect().get_center() if is_instance_valid(b) else Vector2(360, 700)
		Rewards.grant([["fire_2", fire]], func(_k): return from))
	slot["b"] = btn

# ---------------------------------------------------------------- 储物洞

static func inventory() -> PopupBase:
	return load("res://scripts/ui/InventoryPopup.gd").new()

# ---------------------------------------------------------------- 物品详情

static func _dish_info(id: String) -> PopupBase:
	var p := PopupBase.new()
	var r := Rect2(70, 460, 580, 460)
	frame(p, r, Data.name_of(id), Art.OCHRE)
	UI.icon(p.box, id, Vector2(360, r.position.y + 170), 160)
	var desc := UI.lbl(p.box, Data.describe(id), Rect2(r.position.x + 36, r.position.y + 280, r.size.x - 72, 130), 26, Color("6b4a2a"), HORIZONTAL_ALIGNMENT_CENTER)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return p

## Center each row independently; all related items navigate through the popup stack.
static func _info_item_grid(parent: Control, entries: Array, top: float, center_x: float) -> float:
	var columns := 4
	var pitch := 112.0
	var tile := 96.0
	for k in entries.size():
		var entry: Dictionary = entries[k]
		var item_id := str(entry["id"])
		var row := k / columns
		var count := mini(columns, entries.size() - row * columns)
		var x := center_x + (float(k % columns) - float(count - 1) * 0.5) * pitch - tile * 0.5
		var y := top + row * 126.0
		var hit := UI.hit(parent, Rect2(x, y, tile, tile), func(): G.main.open("item_info", item_id))
		hit.name = "related_" + item_id
		hit.extra = func(ci, sz):
			var shape := Art.rrect(Rect2(Vector2(3, 3), sz - Vector2(6, 6)), 16, 191, 0.0)
			ci.draw_colored_polygon(shape, Color("ecd9b3"))
			Art.outline(ci, shape, 2.0, Color(0.6, 0.4, 0.2, 0.35))
			Art.item(ci, item_id, sz * 0.5, 76)
		if entry.has("p"):
			UI.lbl(parent, "%s%%" % str(entry["p"]), Rect2(x, y + 96, tile, 26), 18, Color("7a5a3a"))
	return top + ceilf(float(entries.size()) / columns) * 126.0

static func item_info(id: String) -> PopupBase:
	if Data.is_dish(id):
		return _dish_info(id)
	var p := PopupBase.new()
	var ch := Data.chain(id)
	var c: Dictionary = Data.CHAINS[ch]
	var r := Rect2(80, 340, 560, 780)
	frame(p, r, c["name"], Art.TEAL)
	var state := {"id": id}
	var shown: String = state["id"]
	var name_lbl := UI.lbl(p.box, "%s · 第 %d 级" % [Data.name_of(shown), Data.lv(shown)], Rect2(r.position.x, r.position.y + 48, r.size.x, 36), 24, Color("7a5a3a"))
	var items: Array = c["items"]
	var cols := 4
	var step := 112.0
	var cell_w := 96.0
	var half := cell_w * 0.5
	var pitch := 110.0
	var x0 := r.position.x + (r.size.x - (step * float(cols - 1) + cell_w)) * 0.5 + half
	var y0 := r.position.y + 100.0
	var lower_y := y0 + float(int((maxi(items.size(), 1) - 1) / cols) + 1) * pitch + 4.0
	var lower_scroll := Scroller.new()
	lower_scroll.position = Vector2(0, lower_y)
	lower_scroll.size = Vector2(720, maxf(80, r.end.y - lower_y - 24))
	var lower := lower_scroll.content
	var cells: Array[DrawBox] = []
	var rebuild := func():
		for child in lower.get_children():
			lower.remove_child(child)
			child.queue_free()
		var cur_id: String = state["id"]
		var t := c["type"] as String
		var y := 0.0
		if t == "gen":
			var st := Data.gen_stats(cur_id)
			if st.is_empty():
				section(lower, "还不能生产", y)
				var nxt := Data.first_prod_lv(Data.chain(cur_id))
				if nxt <= 0:
					UI.lbl(lower, "这一级没有配置产物", Rect2(r.position.x, y + 50, r.size.x, 50), 24, Color("7a5a3a"))
				else:
					UI.lbl(lower, "合成到 %d 级后才能点击生产" % nxt, Rect2(r.position.x, y + 50, r.size.x, 50), 24, Color("7a5a3a"))
					UI.icon(lower, "%s_%d" % [Data.chain(cur_id), nxt], Vector2(r.get_center().x, y + 160), 100)
			else:
				section(lower, "产出", y)
				var drops: Array = st["drops"]
				y = _info_item_grid(lower, drops, y + 48, r.get_center().x)
				if st.has("charges"):
					UI.lbl(lower, "满储 %d 次，用完 %d 分钟后回满" % [st["charges"], st["refill"]], Rect2(r.position.x, y, r.size.x, 36), 22, Color("7a5a3a"))
					y += 40
		elif t == "item":
			section(lower, "获取途径：", y)
			var sources: Array = []
			for source in Data.producers_of(ch): sources.append({"id":source})
			y = _info_item_grid(lower, sources, y + 48, r.get_center().x)
		else:
			section(lower, "获取途径：", y)
			UI.lbl(lower, "生产器随机掉落、开启宝箱、升级奖励", Rect2(r.position.x, y + 60, r.size.x, 60), 24, Color("7a5a3a"))
		lower_scroll.set_length(maxf(y + 24, 220))
	var buys: Array = []
	var refresh_buys := func() -> void:
		for b in buys:
			if not is_instance_valid(b):
				continue
			b.visible = not _shop_offer(str(b.get_meta("iid"))).is_empty()
	for l in items.size():
		var lv := l
		var slot_id := "%s_%d" % [ch, lv + 1]
		var cx := x0 + float(lv % cols) * step
		var cy := y0 + float(lv / cols) * pitch
		var cell := UI.box(p.box, Rect2(cx - half, cy, cell_w, cell_w), func(ci, sz):
			var b := Art.rrect(Rect2(4, 4, sz.x - 8, sz.y - 8), 16, 190 + lv, 0.6)
			var cur: bool = slot_id == str(state["id"])
			var owned := _board_count(slot_id)
			var seen := cur or G.discovered.has(slot_id) or owned > 0
			ci.draw_colored_polygon(b, Color("a8d86a") if cur else Color("ecd9b3"))
			Art.outline(ci, b, 2.0, Color(0.6, 0.4, 0.2, 0.35))
			if seen:
				Art.item(ci, slot_id, sz * 0.5, 76)
			else:
				ci.draw_string(G.font_title, Vector2(sz.x * 0.5 - 16, sz.y * 0.5 + 18), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 52, Color(0.7, 0.55, 0.35, 0.6))
			if cur:
				Paint.cell_bracket(ci, Rect2(Vector2.ZERO, sz).grow(-2))
			if owned > 0:
				_draw_count(ci, Vector2(15, 15), owned)
			if lv % cols != cols - 1 and lv < items.size() - 1:
				ci.draw_colored_polygon(Art.poly([Vector2(sz.x + 3, sz.y * 0.5 - 7), Vector2(sz.x + 14, sz.y * 0.5), Vector2(sz.x + 3, sz.y * 0.5 + 7)], lv), Color(0.75, 0.6, 0.4, 0.8)))
		cells.append(cell)
		var hit := UI.hit(p.box, Rect2(cx - half, cy, cell_w, cell_w), func():
			if not G.discovered.has(slot_id) and _board_count(slot_id) <= 0:
				return
			if slot_id == state["id"]:
				return
			state["id"] = slot_id
			var now: String = state["id"]
			name_lbl.text = "%s · 第 %d 级" % [Data.name_of(now), Data.lv(now)]
			for cell_box in cells:
				cell_box.queue_redraw()
			rebuild.call()
			Sfx.play("tap"))
		hit.sound = ""
		var offer := _shop_offer(slot_id)
		if not offer.is_empty():
			var bought_id := slot_id
			var price := int(offer["price"])
			var cap_h := 24.0
			var buy := UI.btn(p.box, Rect2(cx - 40.0, cy + cell_w - cap_h * 0.5, 80, cap_h), str(price), "green", Callable(), 15)
			buy.title_font = false
			buy.res = str(offer.get("res", Art.AMBER_ICON))
			buy.z_index = 3
			buy.set_meta("iid", bought_id)
			buy.pressed.connect(func():
				var from := buy.get_global_rect().get_center()
				if await _buy_from_shop(bought_id, from):
					refresh_buys.call()
					for cell_box in cells:
						cell_box.queue_redraw())
			buys.append(buy)
	p.box.add_child(lower_scroll)
	rebuild.call()
	if str(c.get("type", "")) == "item":
		var prods: Array = Data.producers_of(ch)
		if not prods.is_empty():
			p.on_close = _pulse_source.bind(Data.chain(str(prods[0])))
	return p

static func _board_count(id: String) -> int:
	var n := 0
	for c in G.board:
		if str(c.get("id", "")) == id and int(c.get("lock", 0)) != 2:
			n += 1
	return n

static func _draw_count(ci: CanvasItem, c: Vector2, n: int) -> void:
	ci.draw_circle(c, 12.0, Color(0.28, 0.18, 0.1, 0.45))
	ci.draw_circle(c, 10.5, Color(0.42, 0.3, 0.18, 0.72))
	var f: Font = G.font_title
	if f == null:
		return
	var label := str(n)
	var fs := 15 if n < 10 else 12
	var w := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var baseline := c.y + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5
	ci.draw_string(f, Vector2(c.x - w * 0.5, baseline), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("f4ead8"))

## 集市里还买得到的这一件。deal 为真时记在每日特惠，否则记在热卖。
static func _shop_offer(id: String) -> Dictionary:
	var rows: Array = Data.daily_deals(G.level)
	var hot: Array = HotDeals.today()
	for k in hot.size():
		var d: Dictionary = hot[k]
		rows.append({
			"id": str(d.get("id", "")),
			"price": int(d.get("price", 0)),
			"stock": int(d.get("stock", 0)),
			"key": "hot_%d" % k,
			"deal": false,
		})
	for row in rows:
		if str(row["id"]) != id:
			continue
		var deal := bool(row["deal"])
		var book: Dictionary = G.deals_bought if deal else G.hot_bought
		var left := int(row["stock"]) - int(book.get(row["key"], 0))
		if left > 0:
			return {"price": int(row["price"]), "left": left, "key": str(row["key"]), "deal": deal}
	# 琥珀栏没有（或卖完）才看贝币小摊
	for k in Data.STORE_SHELL.size():
		if str(Data.STORE_SHELL[k].get("id", "")) == id:
			var o := _shell_offer("shell_%d" % k)
			if not o.is_empty():
				return o
	return {}

## 贝币小摊这一格本轮还剩的，卖完返回 {}
static func _shell_offer(key: String) -> Dictionary:
	var k := int(key.trim_prefix("shell_"))
	if k < 0 or k >= Data.STORE_SHELL.size():
		return {}
	G.check_shell_period()
	var d: Dictionary = Data.STORE_SHELL[k]
	var left := int(d.get("stock", 0)) - int(G.shell_bought.get(key, 0))
	if left <= 0:
		return {}
	return {"price": int(d.get("price", 0)), "left": left, "key": key, "deal": false, "res": "shell_2"}

static func _buy_from_shop(id: String, origin: Vector2) -> bool:
	return await _buy_offer(id, _shop_offer(id), origin)

static func _buy_offer(id: String, offer: Dictionary, origin: Vector2) -> bool:
	if offer.is_empty() or G.main == null:
		return false
	var r: Dictionary = await G.shop_buy(str(offer["key"]), id, int(offer["price"]), bool(offer["deal"]))
	if not r.get("ok", false):
		var err := str(r.get("error", ""))
		var msg := "琥珀不够了！" if err == "not_enough_amber" else ("贝币不够了！" if err == "not_enough_shell" else str(r.get("message", "连不上服务器，请稍后再试")))
		G.main.toast(msg)
		return false
	G.discover(id)
	Rewards.grant(Rewards.items([id]), func(_k): return origin)
	if Rewards.is_resource(id) and Data.value_of(id) > 0:
		G.main.toast("获得 %d%s" % [Data.value_of(id), Rewards.unit(id)])
	else:
		G.main.toast("已放入暂存区：%s" % Data.name_of(id))
	return true

static func _pulse_source(chain_id: String) -> void:
	if G.main == null or G.main.board_screen == null or G.main.board_screen.board == null:
		return
	G.main.board_screen.board.pulse_chain(chain_id)

# ---------------------------------------------------------------- 升级

static func _spread_x(k: int, n: int, center: float, gap: float) -> float:
	if n <= 1:
		return center
	var step := minf(gap, 620.0 / float(n))
	return center + (float(k) - (n - 1) * 0.5) * step

static func levelup() -> PopupBase:
	var p := PopupBase.new()
	p.dim_alpha = 0.8
	var rewards := Data.level_rewards(G.level)
	var spots: Array[Vector2] = []
	for k in rewards.size():
		spots.append(Vector2(_spread_x(k, rewards.size(), 360.0, 156.0), 700.0))
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
			Rewards.grant(got, func(k): return spots[k] if k < spots.size() else Vector2(360, 700))
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
static func reward_screen(rewards: Array, apply := true) -> PopupBase:
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
		p.set_meta("reward_apply", apply)
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
			var burst := Art.star_pts(c, r * 0.98, r * 0.62, 8, 40 + k, t * 0.5 + float(k))
			ci.draw_colored_polygon(burst, Color(1, 0.95, 0.7, 0.08 * appear))
			var plate := Art.ell(c + Vector2(0, r * 0.66), Vector2(r * 0.72, r * 0.2), 60 + k, 0.03, 22, 0.0, 0.0)
			Art.dilate(ci, plate, 3.0, Color(Art.INK, appear))
			ci.draw_colored_polygon(plate, Color(Art.LEATHER, appear))
			ci.draw_colored_polygon(Art.ell(c + Vector2(0, r * 0.63), Vector2(r * 0.6, r * 0.12), 70 + k, 0.03, 20, 0.0, 0.0), Color(Art.OCHRE, appear * 0.9))
		for k in 14:
			var sp := Vector2(40.0 + Art.srnd(k * 7 + 1) * 640.0, 200.0 + Art.srnd(k * 13 + 5) * 900.0)
			if sp.distance_to(glow) < 120.0:
				continue
			var tw := 0.5 + 0.5 * sin(t * (2.0 + Art.srnd(k) * 2.0) + float(k) * 1.7)
			var sr := (3.0 + Art.srnd(k * 3) * 5.0) * (0.45 + 0.55 * tw) * open
			if sr > 2.4:
				ci.draw_colored_polygon(Art.star_pts(sp, sr * 2.2, sr * 0.6, 4, k), Color(1, 0.95, 0.75, 0.6 * tw))
		Paint.mascot(ci, Vector2(br.end.x - 36, br.position.y - 8), 74)
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
			var b := Art.rrect(Rect2(Vector2(3, 3), sz - Vector2(6, 6)), (sz.y - 6) * 0.5, 80 + k, 0.5)
			Art.dilate(ci, b, 3.0, Art.INK)
			ci.draw_colored_polygon(b, Color("5a3416"))
			ci.draw_colored_polygon(Art.rrect(Rect2(Vector2(9, 6), Vector2(sz.x - 18, sz.y * 0.28)), 6, 81 + k, 0.2), Color(1, 1, 1, 0.14)))
		UI.lbl(holder, text, badge, bfs, Color("ffe7a8"), HORIZONTAL_ALIGNMENT_CENTER, 0, Art.INK, true)
		var name_lbl: Label = null
		if show_name and (Data.DISHES.has(id) or Data.CHAINS.has(Data.chain(id))):
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
				cell.erase("rw")
				G.cloud_event({"type": "bubble", "cell": i})
			rewards.append([str(e["id"]), int(e["n"])])
		given["ok"] = true
		if rewards.is_empty():
			return
		var apply := true
		if p.has_meta("reward_apply"):
			apply = bool(p.get_meta("reward_apply"))
		Rewards.grant(rewards, func(k): return spots[k] if k < spots.size() else glow, fly, apply)
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
	UI.title(p.box, "主角等级", Rect2(r.get_center().x - 200, r.position.y + 50, 400, 60), 38, Color.WHITE)
	UI.lbl(p.box, str(G.level), Rect2(r.get_center().x - 60, r.position.y - 44, 120, 80), 50, Color("fff1c4"), HORIZONTAL_ALIGNMENT_CENTER, 10, Art.INK, true)
	var tip := UI.lbl(p.box, "完成带 ★ 的订单，提升主角等级并领取奖励！", Rect2(r.position.x + 40, r.position.y + 446, r.size.x - 80, 90), 25, Color("6b4a2a"))
	tip.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	UI.lbl(p.box, "%d/%d" % [G.xp, G.xp_need()], Rect2(r.position.x + 70, r.position.y + 560, 400, 44), 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK)
	UI.lbl(p.box, str(G.level + 1), Rect2(r.position.x + 480, r.position.y + 548, 80, 60), 34, Color("fff1c4"), HORIZONTAL_ALIGNMENT_CENTER, 8, Art.INK, true)
	section(p.box, "下一级奖励", r.position.y + 640, Color("8a5a30"))
	var rw := Data.level_rewards(G.level + 1)
	for k in rw.size():
		var cx := _spread_x(k, rw.size(), r.get_center().x, 136.0)
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
	var rw := [["fire_4", 800], ["amber_4", 250], ["chest_1", 1]]
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
	Art.item(ci, "fire_4", Vector2(360, 190), 130)
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
		var got: Array = await G.open_pack()
		if got.is_empty():
			# 连不上服务器：卡包放回暂存区
			G.stash_push("pack_1")
			p.close()
			return
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

## 计时制作的订单成品，和普通合成链分开。
static func _book_dishes(holder: Control, r: Rect2) -> void:
	var sc := Scroller.new()
	sc.position = Vector2(0, r.position.y + 58)
	sc.size = Vector2(630, r.size.y - 78)
	holder.add_child(sc)
	var ids := Data.DISHES.keys()
	var discovered := 0
	for id in ids:
		if G.discovered.has(id): discovered += 1
	var mid := _book_cell_x(r, 0) + 126.0 * 1.5
	section(sc.content, "订单成品（%d/%d）" % [discovered, ids.size()], 16, Color("8a5a30"), mid)
	var heading: Label = sc.content.get_child(0)
	live(sc, G.board_changed, func():
		var count := 0
		for id in ids:
			if G.discovered.has(id): count += 1
		heading.text = "订单成品（%d/%d）" % [count, ids.size()])
	for k in ids.size():
		var cell := Rect2(_book_cell_x(r, k % 4) - 52, 68 + (k / 4) * 116, 104, 104)
		_book_slot(sc.content, cell, str(ids[k]), k)
	sc.set_length(68 + ceilf(ids.size() / 4.0) * 116 + 10)
