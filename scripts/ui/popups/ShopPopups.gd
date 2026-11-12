class_name ShopPopups
extends RefCounted
const Layout := preload("res://scripts/config/board_layout.gd")
const PS := preload("res://scripts/sprites/popups.gd")
const Payments := preload("res://scripts/net/Payments.gd")

static func energy() -> PopupBase:
	var p := PopupBase.new()
	var r := Rect2(46, 380, 628, 780)
	Popups.frame(p, r, "更多体力", Color("4f8fc0"), "fire")
	var left := G.rules.clock.energy_full_left()
	var txt := "体力已满，先去合成吧！" if left == 0 else "等待 %s 恢复到 100 点体力。" % G.fmt_time(left)
	UI.lbl(p.box, txt, Rect2(r.position.x + 30, r.position.y + 62, r.size.x - 60, 50), 26, Color("6b4a2a"))
	UI.box(p.box, Rect2(r.position.x + 44, r.position.y + 120, r.size.x - 88, 400), _energy_art)
	var tag := UI.lbl(p.box, "×100", Rect2(r.position.x + 92, r.position.y + 436, 150, 60), 40, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 10, Art.INK, true)
	tag.rotation = -0.06
	var price := G.rules.progression.energy_price()
	var free := not bool(Replay.meta.get("free_energy", false))
	var b := UI.btn(p.box, Rect2(r.get_center().x - 150, r.position.y + 560, 300, 100), "免费" if free else str(price), "green", Callable(), 44)
	if not free: b.res = Art.AMBER_ICON
	var note := "第一次补充免费！" if free else "今天第 %d 次购买，价格逐次上涨，每天 0 点恢复" % (G.energy_buys + 1)
	UI.lbl(p.box, note, Rect2(r.position.x + 30, r.position.y + 676, r.size.x - 60, 40), 22, Color("8a6a4a"))
	b.pressed.connect(func():
		if await G.buy_energy():
			RewardPresenter.present([["fire_2", 100]], func(_k): return Vector2(360, 760))
			p.close()
		else:
			G.main.toast("琥珀不够了！"))
	return p

static func _energy_art(ci: CanvasItem, sz: Vector2) -> void:
	var r := Rect2(Vector2.ZERO, sz)
	Sprites.draw(ci, "pop_energy_bg", r)
	Paint.hills(ci, sz.y * 0.5, sz.x, 20, Color("7fb48a"), 2, sz.y * 0.62)
	Sprites.draw(ci, "pop_energy_mid", r)
	Paint.palm(ci, Vector2(70, sz.y * 0.62), 140, 4, Color("4a8a4a"))
	var table := Rect2(0, sz.y * 0.62, sz.x, sz.y * 0.38)
	ci.draw_rect(table, Color("e9d3a3"))
	for i in 12:
		for j in 4:
			if (i + j) % 2 == 0:
				ci.draw_rect(Rect2(table.position + Vector2(i * 46, j * 40), Vector2(46, 40)), Color(0.85, 0.45, 0.3, 0.35))
	Art.item(ci, "basket_4", Vector2(sz.x * 0.52, sz.y * 0.6), 270)
	for k in 7:
		var x := sz.x * 0.52 + (float(k) - 3.0) * 30.0
		Art.item(ci, "fire_2", Vector2(x, sz.y * 0.36 - abs(float(k) - 3.0) * -6.0 - 20.0 + (k % 2) * 12.0), 70)
	for k in 3:
		Art.item(ci, "fire_1", Vector2(80 + k * 50, sz.y * 0.8 + (k % 2) * 16), 50)
	Sprites.draw(ci, "pop_energy_top", r)

# ---------------------------------------------------------------- 玩法说明

static func howto() -> PopupBase:
	var p := PopupBase.new()
	p.dim_alpha = 0.85
	p.set_meta("fullscreen", true)
	UI.title(p.box, "玩法说明", Rect2(0, 150, 720, 100), 64)
	UI.box(p.box, Rect2(0, 0, 720, 1480), func(ci, _sz):
		Sprites.draw(ci, "pop_howto_card", PS.HOWTO_CARD)
		Art.item(ci, "roast_7", Vector2(160, 300), 110)
		Paint.button(ci, Rect2(120, 360, 140, 56), "green")
		ci.draw_polyline(PackedVector2Array([Vector2(170, 384), Vector2(186, 398), Vector2(212, 372)]), Color.WHITE, 7.0, true)
		_arrow(ci, 0)
		Art.item(ci, "shell_4", Vector2(560, 540), 170)
		_arrow(ci, 1)
		Art.item(ci, "chest_1", Vector2(220, 830), 200)
		Art.item(ci, "fruit_2", Vector2(150, 720), 70)
		Art.item(ci, "amber_4", Vector2(290, 700), 70)
		Sprites.draw(ci, "pop_howto_hand", PS.HOWTO_HAND)
		_arrow(ci, 2)
		Paint._spot_hut(ci, Vector2(560, 1080), 4)
		Sprites.draw(ci, "pop_howto_bub", PS.HOWTO_BUB)
		Paint.hammer(ci, Vector2(620, 918), 0.5))
	UI.lbl(p.box, "心愿实现啦！", Rect2(40, 440, 300, 50), 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 10, Art.INK)
	UI.lbl(p.box, "赚取不拿拿！", Rect2(410, 630, 300, 50), 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 10, Art.INK)
	UI.lbl(p.box, "开启宝箱！", Rect2(70, 940, 300, 50), 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 10, Art.INK)
	UI.lbl(p.box, "建设部落！", Rect2(410, 1150, 300, 50), 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 10, Art.INK)
	UI.lbl(p.box, "拖动两个相同的物品即可合成更高级的物品", Rect2(0, 250, 720, 40), 24, Color("ffe7a8"), HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK)
	var go := UI.btn(p.box, Rect2(210, 1250, 300, 104), "开始合成", "green", Callable(), 44)
	go.pressed.connect(func():
		Replay.perform("tutorial_finish")
		p.close()
		G.main.show_screen("board"))
	return p

## 玩法说明里的第 k 支弯箭头（起止点见 PS.HOWTO_ARROWS）

static func _arrow(ci: CanvasItem, k: int) -> void:
	var a: Array = PS.HOWTO_ARROWS[k]
	Sprites.draw(ci, "pop_howto_arrow%d" % k, PS.arrow_rect(a[0], a[1], a[2]))

# ---------------------------------------------------------------- 集市

## 全屏页面：内容放进竖向滚动区（从顶栏下方开始），返回一个使用绝对坐标的根节点

static func store() -> PopupBase:
	var p := PopupBase.new()
	p.dim_alpha = 0.9
	p.set_meta("store", true)
	var fs := Popups.fullscreen(p)
	var sc: Scroller = fs[0]
	var root: Control = fs[1]
	UI.title(root, "交易集市", Rect2(0, 140, 720, 80), 46)
	UI.box(root, Rect2(0, 0, 720, 520), _paint_store)
	UI.title(root, "篝火祭通行证", Rect2(50, 400, 360, 60), 34, Color.WHITE)
	UI.lbl(root, "×10", Rect2(440, 300, 80, 30), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK)
	UI.lbl(root, "每个心愿额外 +1 不拿拿", Rect2(500, 304, 200, 30), 18, Color("ffe7a8"), HORIZONTAL_ALIGNMENT_CENTER, 6, Art.INK)
	UI.lbl(root, "¥ 30", Rect2(470, 344, 160, 44), 28, Color("5a3d24"), HORIZONTAL_ALIGNMENT_CENTER)
	UI.btn(root, Rect2(430, 396, 240, 80), "激活", "green", func(): G.main.open("pass_buy"), 38)
	Popups.section(root, "每日特惠", 516, Color("ffd23f"))
	G.rules.clock._check_day()
	# 每日特惠一排 5 张（顺序固定：广告 → 不拿拿买体力宝箱 → 贵宾琥珀 → 超级贵宾琥珀 → 免费体力）
	var deals := Data.daily_deals(G.level)
	var dn := maxi(1, deals.size())
	var dw := (660.0 - (dn - 1) * 10.0) / dn
	for k in deals.size():
		_daily_card(root, Rect2(30.0 + k * (dw + 10.0), 566, dw, 236), deals[k], k)
	var clocks: Array = []
	clocks.append(_refresh_bar(root, Rect2(30, 818, 660, 66), Color("6c492e"), "明天 0 点上新", func(): return [G.rules.clock.secs_to_midnight(), 86400], "", 0, Callable()))
	var y := 904.0
	# 不拿拿小摊：用不拿拿买低一级的普通货，库存少，每 8 小时按服务器时间补货；花少量琥珀可立即补货
	G.rules.clock.check_shell_period()
	Popups.section(root, "不拿拿小摊", y, Color("bfe3ff"))
	var sy := y + 44.0
	for k in Data.STORE_SHELL.size():
		var d: Dictionary = Data.STORE_SHELL[k]
		sy = y + 44.0 + (k / 3) * 270.0
		_shell_card(root, Rect2(30.0 + (k % 3) * 226.0, sy, 208, 250), d, "shell_%d" % k)
	if not Data.STORE_SHELL.is_empty():
		sy += 264.0
		var shell_bar: Array = []
		shell_bar.append(_refresh_bar(root, Rect2(30, sy, 660, 86), Color("405f70"), "小摊补货", func(): return [G.rules.clock.shell_secs_left(), Data.STORE_SHELL_HOURS * 3600], "补货", Data.STORE_SHELL_REFRESH, func():
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
	Popups.section(root, "热卖", y, Color("ffd23f"))
	var hot_root := Control.new()
	hot_root.name = "HotGoods"
	hot_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hot_root)
	var hot_state := {"sig": "", "count": 0}
	var hot_y := y + 44.0
	var draw_hot := func():
		var hot: Array = G.shop_view()
		hot_state["count"] = hot.size()
		var sig := G.rules.clock.today() + ":" + str(G.hot_revision) + JSON.stringify(hot)
		if sig == str(hot_state["sig"]): return
		hot_state["sig"] = sig
		for child in hot_root.get_children():
			hot_root.remove_child(child)
			child.queue_free()
		for k in hot.size():
			var d: Dictionary = hot[k]
			_store_card(hot_root, Rect2(30.0 + (k % 3) * 226.0, hot_y + (k / 3) * 270.0, 208, 250), d, "hot_%d" % k, false)
	draw_hot.call()
	y = hot_y + ceilf(float(hot_state["count"]) / 3.0) * 270.0 - 6.0
	var hot_bar: Array = []
	hot_bar.append(_refresh_bar(root, Rect2(30, y, 660, 86), Color("6c492e"), "热卖刷新", func(): return [G.rules.clock.secs_to_midnight(), 86400], "刷新", 10, func():
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
	Popups.live(p, G.changed, func(): draw_hot.call())
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
	Popups.section(root, "琥珀", y, Color("ffd23f"))
	y += 48.0
	for k in Data.AMBER_PACKS.size():
		var a: Dictionary = Data.AMBER_PACKS[k]
		_amber_card(root, Rect2(30.0 + (k % 3) * 226.0, y + (k / 3) * 280.0, 208, 260), a, k)
	y += 2 * 280.0 + 40.0
	sc.set_length(y - 128.0)
	return p

## 每日特惠的一张小卡。边框颜色按类型：广告青、不拿拿蓝、会员紫、免费绿；会员卡顶上挂档位签。

static func _daily_card(parent: Control, r: Rect2, d: Dictionary, k: int) -> void:
	var key := str(d["key"])
	var tier := int(d.get("min_tier", 0))
	var member := tier > 0
	var ad := str(d.get("mode", "")) == "ad"
	var paid := int(d["price"]) > 0
	var col: Color = Color("4fa39a") if ad else (Color("6f9fb8") if paid else (Color("8a5bb8") if member else Color("7fb43a")))
	var state := {"claimed": false}
	var card := UI.box(parent, r, func(ci, sz):
		var full := Rect2(Vector2.ZERO, sz)
		Sprites.draw(ci, "pop_card18_base", full)
		Sprites.draw(ci, "pop_card18_fill", full, col)
		var ir := Rect2(7, 7, sz.x - 14, 122)
		Sprites.draw(ci, "pop_inner14", ir, Art.BONE)
		Sprites.at(ci, "pop_spot_shadow", Vector2(sz.x * 0.5, 110), 1.0, 0.0, Color(0, 0, 0, 0.1))
		Art.item(ci, str(d["id"]), Vector2(sz.x * 0.5, 72), 86)
		if member or ad:
			var tw := 100.0 if tier >= 2 else 64.0
			var t := Rect2(sz.x * 0.5 - tw * 0.5, -13, tw, 28)
			Sprites.draw(ci, "pop_tag_base", t)
			Sprites.draw(ci, "pop_tag_fill", t, Color("2a7469") if ad else (Color("f4c542") if tier >= 2 else Color("e0cdf5")))
		if state["claimed"]:
			Sprites.draw(ci, "pop_inner14", ir, Color(0.25, 0.18, 0.1, 0.35))
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
		var claimed := G.deals_day == G.rules.clock.today() and int(G.deals_bought.get(key, 0)) >= int(d["stock"])
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
	Popups.live(b, G.changed, refresh)
	b.pressed.connect(func():
		if member and G.pass_tier < tier:
			G.main.open("pass_buy")
			return
		if ad:
			G.main.open("daily_ad")
			return
		b.enabled = false
		var result: Dictionary = await DailyShop.claim(key)
		if result.get("ok", false): RewardPresenter.present(result.get("rewards", []), func(_k): return b.get_global_rect().get_center() - Vector2(0, 100))
		if not result.get("ok", false): G.main.toast(str(result.get("message", "没领成，再试一次")))
		if is_instance_valid(b): refresh.call())

## 刷新倒计时条：左边沙漏 + 标题 + 「07:12:33」+ 本轮剩余进度槽；右边可选的琥珀刷新按钮。
## left_fn 返回 [剩余秒数, 一轮总秒数]。返回的字典交给 _tick_bar 每秒更新。

static func _refresh_bar(root: Control, r: Rect2, col: Color, title: String, left_fn: Callable, btn_text: String, cost: int, cb: Callable) -> Dictionary:
	var st := {"t": 0.0}
	var has_btn := btn_text != ""
	var bar_w := r.size.x - (262.0 if has_btn else 110.0)
	var bar := UI.box(root, r, func(ci, sz):
		var full := Rect2(Vector2.ZERO, sz)
		Sprites.draw(ci, "pop_card18_base", full)
		Sprites.draw(ci, "pop_card18_fill", full, col)
		Sprites.draw(ci, "pop_bar_hl", Rect2(6, 5, sz.x - 12, sz.y * 0.4), Color(1, 1, 1, 0.08))
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
		_card20(ci, sz, Color("c9894a") if k < 5 else Color("d9a54a"))
		Sprites.draw(ci, "pop_inner14", Rect2(10, 10, sz.x - 20, sz.y - 96), Color("fff3d6"))
		var pid: String = piles[k][0]
		var n: int = piles[k][1]
		for j in n:
			var off := Vector2((float(j % 3) - float(mini(n, 3) - 1) * 0.5) * 40.0, -float(j / 3) * 24.0 + 10.0)
			Art.item(ci, pid, Vector2(sz.x * 0.5, 84) + off, 92.0 - n * 4.0)
		if k >= 4:
			Sprites.at(ci, "pop_seal", Vector2(30, 26)))
	UI.hit(parent, Rect2(r.position + Vector2(8, 8), Vector2(r.size.x - 16, 114)), func(): G.main.open("item_info", Art.AMBER_ICON))
	if k >= 4:
		var hl := UI.lbl(parent, "超值", Rect2(r.position.x - 6, r.position.y + 8, 72, 36), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 5, Art.INK, true)
		hl.rotation = -0.2
	UI.lbl(parent, "×%d" % a["n"], Rect2(r.position.x, r.position.y + 128, r.size.x, 40), 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 8, Art.INK, true)
	var b := UI.btn(parent, Rect2(r.position.x + 22, r.position.y + 184, r.size.x - 44, 64), a["price"], "orange", Callable(), 30)
	b.title_font = false
	b.pressed.connect(func():
		if not b.enabled: return
		b.enabled = false
		b.queue_redraw()
		# Only grants the server issued and this save applied are presented.
		var paid: Dictionary = await Payments.buy("amber:%d" % k)
		if not is_instance_valid(b): return
		b.enabled = true
		b.queue_redraw()
		if not paid.get("ok", false):
			G.main.toast(str(paid.get("message", "没买成，再试一次")))
			return
		RewardPresenter.present([[Art.AMBER_ICON, int(paid["amber"])]], func(_k): return b.get_global_rect().get_center() + Vector2(0, -100)))

## 集市卡片外框：阴影 + 墨边 + 按 col 染色的身子

static func _card20(ci: CanvasItem, sz: Vector2, col: Color) -> void:
	var full := Rect2(Vector2.ZERO, sz)
	Sprites.draw(ci, "pop_card20_base", full)
	Sprites.draw(ci, "pop_card20_fill", full, col)

## 浅色格子：身子 + 细描边。big 用大圆角那套（奖励框、说明框）

static func _slot(ci: CanvasItem, r: Rect2, fill: Color, line: Color = Color(0.6, 0.4, 0.2, 0.35), big := false) -> void:
	Sprites.draw(ci, "pop_slot22_fill" if big else "pop_slot16_fill", r, fill)
	Sprites.draw(ci, "pop_slot22_line" if big else "pop_slot16_line", r, line)

static func _paint_store(ci: CanvasItem, _sz: Vector2) -> void:
	var r := PS.STORE_HERO
	Sprites.draw(ci, "pop_store_hero", r)
	var ir := Rect2(r.position + Vector2(12, 12), Vector2(r.size.x - 24, 150))
	Paint.vgrad(ci, ir, Color("2c3b78"), Color("6a4d9a"))
	for i in 20:
		ci.draw_circle(ir.position + Vector2(Art.srnd(i) * ir.size.x, Art.srnd(i + 40) * ir.size.y), 1.5 + Art.srnd(i + 9) * 1.5, Color(1, 1, 0.8, 0.7))
	Art.item(ci, "chest_1", Vector2(150, 316), 180)
	for k in 6:
		Art.item(ci, Art.AMBER_ICON, Vector2(70 + k * 34, 380 - (k % 2) * 10), 54)
	Art.item(ci, "fire_4", Vector2(270, 330), 80)
	var tag := Rect2(470, 344, 160, 44)
	Sprites.draw(ci, "pop_tag_base", tag)
	Sprites.draw(ci, "pop_tag_fill", tag, Color("e9d8ff"))
	Art.item(ci, "pack_1", Vector2(480, 286), 60)

static func _store_card(parent: Control, r: Rect2, d: Dictionary, key: String, hot: bool) -> void:
	UI.box(parent, r, func(ci, sz):
		_card20(ci, sz, Art.OCHRE)
		Sprites.draw(ci, "pop_inner14", Rect2(10, 10, sz.x - 20, sz.y - 86), Art.BONE)
		Art.item(ci, d["id"], Vector2(sz.x * 0.5, 82), 112)
		if hot:
			Sprites.at(ci, "pop_seal", Vector2(30, 24), 38.0 / 36.0))
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
	Popups.live(b, G.changed, refresh)
	b.pressed.connect(func():
		var origin: Vector2 = b.get_global_rect().get_center() + Vector2(0, -110)
		if await ItemPopups._buy_offer(str(d["id"]), {"price": int(d["price"]), "key": key, "deal": hot}, origin):
			refresh.call())

## 不拿拿小摊的一格：样子同热卖卡片，换成浅蓝底、价格按钮用不拿拿图标

static func _shell_card(parent: Control, r: Rect2, d: Dictionary, key: String) -> void:
	UI.box(parent, r, func(ci, sz):
		_card20(ci, sz, Color("6f9fb8"))
		Sprites.draw(ci, "pop_inner14", Rect2(10, 10, sz.x - 20, sz.y - 86), Color("eef6f2"))
		Art.item(ci, d["id"], Vector2(sz.x * 0.5, 82), 112))
	UI.hit(parent, Rect2(r.position + Vector2(8, 8), Vector2(r.size.x - 16, 114)), func(): G.main.open("item_info", str(d["id"])))
	var left_lbl := UI.lbl(parent, "", Rect2(r.position.x, r.position.y + 128, r.size.x, 34), 22, Color("2f4f60"))
	var b := UI.btn(parent, Rect2(r.position.x + 22, r.position.y + 178, r.size.x - 44, 64), "", "green", Callable(), 30)
	var refresh := func():
		G.rules.clock.check_shell_period()
		var left: int = int(d["stock"]) - int(G.shell_bought.get(key, 0))
		left_lbl.text = "剩余 %d" % left
		b.text = str(int(d["price"])) if left > 0 else "售罄"
		b.res = "shell_2" if left > 0 else ""
		b.style = "green" if left > 0 else "grey"
		b.enabled = left > 0
		b.queue_redraw()
	refresh.call()
	Popups.live(b, G.changed, refresh)
	b.pressed.connect(func():
		var origin: Vector2 = b.get_global_rect().get_center() + Vector2(0, -110)
		if await ItemPopups._buy_offer(str(d["id"]), ItemPopups._shell_offer(key), origin):
			refresh.call())

# ---------------------------------------------------------------- 设置
