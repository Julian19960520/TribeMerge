class_name ItemPopups
extends RefCounted
const Layout := preload("res://scripts/config/board_layout.gd")
const PS := preload("res://scripts/sprites/popups.gd")

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

static func _book_tab_draw(ci: CanvasItem, sz: Vector2, on: bool, icon: String, _seed: int) -> void:
	Sprites.draw(ci, "pop_booktab_on" if on else "pop_booktab_off", Rect2(0, 3, sz.x + 18, sz.y - 6))
	Art.item(ci, icon, Vector2(sz.x * 0.5 - 6.0, sz.y * 0.52), 58.0)

## 每条产线右缘页签上的图。

static func _book_icon(line: Dictionary) -> String:
	var known := {
		"food": "fruit_6",
		"tool": "tool_5",
		"cloth": "cloth_7",
		"hunt": "beast_6",
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
	Popups.section(page, "%s（%d/%d）" % [str(c["name"]), n, items.size()], y, Color("8a5a30"), mid)
	y += 52
	for l in items.size():
		var lv := l
		var id := "%s_%d" % [chain_id, lv + 1]
		var cx := _book_cell_x(r, lv % 4)
		_book_slot(page, Rect2(cx - 52, y, 104, 104), id, lv)
		if lv % 4 == 3 and lv < items.size() - 1:
			y += 116
	return y + 126.0

static func _book_slot(page: Control, cell: Rect2, id: String, _seed: int) -> void:
	var box := UI.box(page, cell, func(ci, sz):
		ShopPopups._slot(ci, Rect2(Vector2.ZERO, sz), Color("ecd9b3"))
		if not G.discovered.has(id):
			var f: Font = G.font_title
			ci.draw_string(f, Vector2(sz.x * 0.5 - 18, sz.y * 0.5 + 20), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 60, Color(0.7, 0.55, 0.35, 0.6))
		elif G.rules.board.book_prize(id):
			Paint.gift(ci, sz * 0.5, 86)
		else:
			Art.item(ci, id, sz * 0.5, 86))
	var slot := {"b": null}
	var btn := UI.hit(page, cell, func():
		if not G.discovered.has(id): return
		var b: Control = slot["b"]
		if not G.rules.board.book_prize(id):
			G.main.open("item_info", id)
			return
		var fire: int = await G.claim_book(id)
		if fire <= 0:
			return
		box.queue_redraw()
		Sfx.play("coin")
		var from := b.get_global_rect().get_center() if is_instance_valid(b) else Vector2(360, 700)
		RewardPresenter.present([["fire_2", fire]], func(_k): return from))
	slot["b"] = btn

# ---------------------------------------------------------------- 储物洞

static func inventory() -> PopupBase:
	return load("res://scripts/ui/InventoryPopup.gd").new()

# ---------------------------------------------------------------- 物品详情

static func _dish_info(id: String) -> PopupBase:
	var p := PopupBase.new()
	var r := Rect2(70, 460, 580, 460)
	Popups.frame(p, r, Data.name_of(id), Art.OCHRE)
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
			ShopPopups._slot(ci, Rect2(Vector2(3, 3), sz - Vector2(6, 6)), Color("ecd9b3"))
			Art.item(ci, item_id, sz * 0.5, 76)
		if entry.has("p"):
			UI.lbl(parent, "%s%%" % str(entry["p"]), Rect2(x, y + 96, tile, 26), 18, Color("7a5a3a"))
	return top + ceilf(float(entries.size()) / columns) * 126.0

static func item_info(id: String) -> PopupBase:
	if Data.is_numeric_resource(id):
		var numeric := PopupBase.new()
		var rect := Rect2(100, 480, 520, 460)
		Popups.frame(numeric, rect, Data.name_of(id), Art.TEAL)
		UI.icon(numeric.box, id, Vector2(360, 620), 112)
		var description := UI.lbl(numeric.box, Data.describe(id), Rect2(140, 710, 440, 150), 27, Art.INK)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		return numeric
	if Data.is_dish(id):
		return _dish_info(id)
	var p := PopupBase.new()
	var ch := Data.chain(id)
	var c: Dictionary = Data.CHAINS[ch]
	var r := Rect2(80, 340, 560, 780)
	Popups.frame(p, r, c["name"], Art.TEAL)
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
				Popups.section(lower, "还不能生产", y)
				var nxt := Data.first_prod_lv(Data.chain(cur_id))
				if nxt <= 0:
					UI.lbl(lower, "这一级没有配置产物", Rect2(r.position.x, y + 50, r.size.x, 50), 24, Color("7a5a3a"))
				else:
					UI.lbl(lower, "合成到 %d 级后才能点击生产" % nxt, Rect2(r.position.x, y + 50, r.size.x, 50), 24, Color("7a5a3a"))
					UI.icon(lower, "%s_%d" % [Data.chain(cur_id), nxt], Vector2(r.get_center().x, y + 160), 100)
			else:
				Popups.section(lower, "产出", y)
				var drops: Array = st["drops"]
				y = _info_item_grid(lower, drops, y + 48, r.get_center().x)
				if st.has("charges"):
					UI.lbl(lower, "满储 %d 次，用完 %d 分钟后回满" % [st["charges"], st["refill"]], Rect2(r.position.x, y, r.size.x, 36), 22, Color("7a5a3a"))
					y += 40
		elif t == "item":
			Popups.section(lower, "获取途径：", y)
			var sources: Array = []
			for source in Data.producers_of(ch): sources.append({"id":source})
			y = _info_item_grid(lower, sources, y + 48, r.get_center().x)
		elif t in ["pack", "chest", "upgrade", "scissors"]:
			Popups.section(lower, "用途", y)
			var usage := UI.lbl(lower, Data.describe(cur_id), Rect2(r.position.x + 18, y + 50, r.size.x - 36, 160), 23, Art.INK)
			usage.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			y += 210
		else:
			Popups.section(lower, "获取途径：", y)
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
			var cur: bool = slot_id == str(state["id"])
			var owned := _board_count(slot_id)
			var seen := cur or G.discovered.has(slot_id) or owned > 0
			ShopPopups._slot(ci, Rect2(4, 4, sz.x - 8, sz.y - 8), Color("a8d86a") if cur else Color("ecd9b3"))
			if seen:
				Art.item(ci, slot_id, sz * 0.5, 76)
			else:
				ci.draw_string(G.font_title, Vector2(sz.x * 0.5 - 16, sz.y * 0.5 + 18), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 52, Color(0.7, 0.55, 0.35, 0.6))
			if cur:
				Paint.cell_bracket(ci, Rect2(Vector2.ZERO, sz).grow(-2))
			if owned > 0:
				_draw_count(ci, Vector2(15, 15), owned)
			if lv % cols != cols - 1 and lv < items.size() - 1:
				Sprites.draw(ci, "pop_info_arrow", Rect2(sz.x + 3, sz.y * 0.5 - 7, 11, 14)))
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
	var hot: Array = G.shop_view()
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
	# 琥珀栏没有（或卖完）才看不拿拿小摊
	for k in Data.STORE_SHELL.size():
		if str(Data.STORE_SHELL[k].get("id", "")) == id:
			var o := _shell_offer("shell_%d" % k)
			if not o.is_empty():
				return o
	return {}

## 不拿拿小摊这一格本轮还剩的，卖完返回 {}

static func _shell_offer(key: String) -> Dictionary:
	var k := int(key.trim_prefix("shell_"))
	if k < 0 or k >= Data.STORE_SHELL.size():
		return {}
	G.rules.clock.check_shell_period()
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
	var r: Dictionary = G.shop_buy(str(offer["key"]), id)
	if not r.get("ok", false):
		var err := str(r.get("error", ""))
		var msg := "琥珀不够了！" if err == "not_enough_amber" else ("不拿拿不够了！" if err == "not_enough_shell" else str(r.get("message", "连不上服务器，请稍后再试")))
		G.main.toast(msg)
		return false
	G.rules.board.discover(id)
	RewardPresenter.present(Rewards.items([id]), func(_k): return origin)
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
	Popups.section(sc.content, "订单成品（%d/%d）" % [discovered, ids.size()], 16, Color("8a5a30"), mid)
	var heading: Label = sc.content.get_child(0)
	Popups.live(sc, G.board_changed, func():
		var count := 0
		for id in ids:
			if G.discovered.has(id): count += 1
		heading.text = "订单成品（%d/%d）" % [count, ids.size()])
	for k in ids.size():
		var cell := Rect2(_book_cell_x(r, k % 4) - 52, 68 + (k / 4) * 116, 104, 104)
		_book_slot(sc.content, cell, str(ids[k]), k)
	sc.set_length(68 + ceilf(ids.size() / 4.0) * 116 + 10)
