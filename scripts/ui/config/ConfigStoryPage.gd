class_name ConfigStoryPage
extends RefCounted
## story configuration page and its editing actions.
const Meme := preload("res://scripts/Meme.gd")

const Files := preload("res://scripts/config/config_files.gd")
const OrderCurvePadSc := preload("res://scripts/ui/OrderCurvePad.gd")
const Layout := preload("res://scripts/config/board_layout.gd")
const PickSheetSc := preload("res://scripts/ui/PickSheet.gd")

const VALUED := ["energy", "shell", "amber", "sand"]
const REWARD_COLS := 5
const REWARD_SQ := 120.0
const REWARD_PITCH_X := 132.0
const REWARD_PITCH_Y := 186.0

var editor
func _init(owner_editor) -> void:
	editor = owner_editor

func _people() -> float:
	var y = 12.0
	var arr: Array = editor._pages[Files.PEOPLE]
	editor._h(editor._root, "剧情订单用序号指人，0 是第一个。点名字改字。", 24, y, 680, 22)
	y += 40
	for i in arr.size():
		var idx = i
		editor._line(editor._root, Rect2(24, y, 500, 60), str(arr[i]), func(t):
			arr[idx] = t
			editor._touch(Files.PEOPLE))
		UI.btn(editor._root, Rect2(540, y, 156, 60), "删除", "red", func():
			if arr.size() <= 1:
				G.main.toast("至少留一个人物")
				return
			arr.remove_at(idx)
			editor._touch(Files.PEOPLE)
			editor._rerender()
		, 24).title_font = false
		y += 72
	UI.btn(editor._root, Rect2(180, y, 360, 72), "添加人物", "green", func():
		arr.append("新人物")
		editor._touch(Files.PEOPLE)
		editor._rerender()
	, 28).title_font = false
	return y + 92

func _unlocks() -> float:
	var book = _ensure_unlocks()
	var n = int(book["levels"])
	var rows: Array = book["rows"]
	var y = 12.0
	var hint = editor._h(editor._root, "左侧是每条产线的主产物和副产物。点格子切换，绿色是这个等级的订单可以要它，灰色不行。超过最后一列的等级沿用最后一列。", 16, y, 688, 20)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size.y = 64
	y += 72.0
	var label_w = 168.0
	var head_h = 40.0
	var row_h = 76.0
	var cell = 48.0
	var pitch = 54.0
	var grid_h = head_h + float(rows.size()) * row_h
	var sc = Scroller.new()
	sc.horizontal = true
	sc.position = Vector2(label_w, y)
	sc.size = Vector2(720.0 - label_w - 8.0, grid_h)
	sc.content.mouse_filter = Control.MOUSE_FILTER_PASS
	editor._root.add_child(sc)
	for col in n:
		var num = UI.lbl(sc.content, str(col + 1), Rect2(float(col) * pitch, 4, cell, 32), 16, Color("6b4a2a"))
		num.clip_text = true
	for ri in rows.size():
		var row: Dictionary = rows[ri]
		var cid = str(row.get("id", ""))
		var ry = head_h + float(ri) * row_h
		var icon_id = "%s_1" % cid
		UI.icon(editor._root, icon_id, Vector2(40, y + ry + 28), 52)
		var name = UI.lbl(editor._root, _chain_lv1_name(cid), Rect2(68, y + ry + 8, 96, 52), 18, Art.INK, HORIZONTAL_ALIGNMENT_LEFT)
		name.clip_text = true
		name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var flags: Array = row["open"]
		for col in n:
			_unlock_cell(sc.content, flags, col, Vector2(float(col) * pitch, ry + 8), cell)
	sc.set_length(float(n) * pitch + 8.0)
	return y + grid_h + 24.0

func _unlock_cell(parent: Node, flags: Array, col: int, at: Vector2, cell: float) -> void:
	var box = UI.box(parent, Rect2(at, Vector2(cell, cell)), func(ci, sz):
		var on = col < flags.size() and int(flags[col]) != 0
		var tile = Art.rrect(Rect2(2, 2, sz.x - 4, sz.y - 4), 8, col, 0.35)
		ci.draw_colored_polygon(tile, Color("6fbf3a") if on else Color("c4bbae"))
		Art.outline(ci, tile, 2.0, Color(0.35, 0.24, 0.14, 0.45))
	, false)
	UI.hit(parent, Rect2(at, Vector2(cell, cell)), func():
		while flags.size() <= col:
			flags.append(0)
		flags[col] = 0 if int(flags[col]) != 0 else 1
		editor._touch(Files.UNLOCKS)
		box.queue_redraw())

func _ensure_unlocks() -> Dictionary:
	var book = editor._pages.get(Files.UNLOCKS, {})
	if not (book is Dictionary):
		book = {}
		editor._pages[Files.UNLOCKS] = book
	var n = maxi(1, int(book.get("levels", 40)))
	book["levels"] = n
	var old: Array = book.get("rows", []) if book.get("rows") is Array else []
	var by_id = {}
	for row in old:
		if row is Dictionary and str(row.get("id", "")) != "":
			by_id[str(row["id"])] = row
	var rows: Array = []
	var changed = false
	for line in editor._pages[Files.LINES]:
		if not (line is Dictionary):
			continue
		var from_lv = maxi(1, int(line.get("unlock", 1)))
		for key in ["main", "sub"]:
			var cid = str(line.get(key, ""))
			if cid == "":
				continue
			var start = from_lv if key == "main" else Data.sub_unlock_level(from_lv)
			var row: Dictionary = by_id.get(cid, {})
			if row.is_empty():
				row = {"id": cid, "open": []}
				changed = true
			if str(row.get("id", "")) != cid:
				row["id"] = cid
			var open: Array = []
			var raw_open = row.get("open", [])
			if raw_open is Array:
				open = raw_open
			else:
				changed = true
			var before = open.size()
			while open.size() < n:
				open.append(1 if open.size() + 1 >= start else 0)
			while open.size() > n:
				open.pop_back()
			if open.size() != before:
				changed = true
			row["open"] = open
			rows.append(row)
			by_id.erase(cid)
	if not by_id.is_empty() or rows.size() != old.size():
		changed = true
	book["rows"] = rows
	if changed:
		editor._touch(Files.UNLOCKS)
	return book

func _chain_lv1_name(cid: String) -> String:
	for c in editor._pages[Files.CHAINS]:
		if c is Dictionary and str(c.get("id", "")) == cid:
			var items: Array = c.get("items", [])
			if not items.is_empty():
				return str(items[0])
			return str(c.get("name", cid))
	return cid

func _editor_product_open(level: int, chain_id: String) -> bool:
	if chain_id == "":
		return false
	var book = editor._pages.get(Files.UNLOCKS, {})
	if not (book is Dictionary):
		return true
	for row in book.get("rows", []):
		if not (row is Dictionary) or str(row.get("id", "")) != chain_id:
			continue
		var open = row.get("open", [])
		if not (open is Array) or open.is_empty() or level < 1:
			return false
		return int(open[mini(level - 1, open.size() - 1)]) != 0
	return true

func _open_story_item(level: int, cb: Callable, current = null) -> void:
	var entries: Array = []
	for e in editor.chains_page._item_choices():
		if _editor_product_open(level, Data.chain(str(e.get("id", "")))):
			entries.append(e)
	if entries.is_empty():
		G.main.toast("%d 级还没有能进订单的产物" % level)
		return
	editor._chooser.open("选择物品", entries, func(id):
		if cb.is_valid():
			cb.call(id)
		editor._rerender(), current)

func _assign_story_item(id: String, arr: Array, i: int, level: int) -> void:
	if id == "":
		return
	if not _editor_product_open(level, Data.chain(id)):
		G.main.toast("%d 级还不能要%s" % [level, Data.name_of(id)])
		return
	if i >= 0 and i < arr.size():
		arr[i] = id
	else:
		arr.append(id)
	editor._touch(Files.STORY)

func _story_default_item(level: int) -> String:
	if _editor_product_open(level, "fruit"):
		return "fruit_2"
	for line in editor._pages[Files.LINES]:
		if not (line is Dictionary):
			continue
		for key in ["main", "sub"]:
			var cid = str(line.get(key, ""))
			if cid != "" and _editor_product_open(level, cid):
				return "%s_1" % cid
	return "fruit_2"

func _story() -> float:
	var y = 12.0
	editor._h(editor._root, "点头像换人，点物品更换，点数字修改。", 24, y, 680, 20)
	y += 36
	var levels: Array = editor._pages[Files.STORY].get("levels", [])
	for li in levels.size():
		var lv: Dictionary = levels[li]
		var lix = li
		editor._h(editor._root, "主角等级", 24, y, 140, 24)
		editor._stepper(editor._root, 180, y, "", int(lv["level"]), 1, 99, func(n):
			lv["level"] = n
			editor._touch(Files.STORY))
		UI.btn(editor._root, Rect2(520, y, 176, 52), "删除等级", "red", func():
			levels.remove_at(lix)
			editor._touch(Files.STORY)
			editor._rerender()
		, 22).title_font = false
		y += 68
		if not lv.has("orders") or not (lv["orders"] is Array):
			lv["orders"] = []
		var orders: Array = lv["orders"]
		for oi in orders.size():
			y = _story_card(y, orders, oi, int(lv["level"]))
		UI.btn(editor._root, Rect2(180, y, 360, 64), "添加订单", "teal", func():
			orders.append({"who": 0, "items": [_story_default_item(int(lv["level"]))], "xp": 1, "shell": 1, "rewards": []})
			editor._touch(Files.STORY)
			editor._rerender()
		, 24).title_font = false
		y += 88
	UI.btn(editor._root, Rect2(180, y, 360, 76), "添加等级", "green", func():
		var n = 1
		for lv in levels:
			n = maxi(n, int(lv["level"]) + 1)
		levels.append({"level": n, "orders": []})
		editor._touch(Files.STORY)
		editor._rerender()
	, 28).title_font = false
	return y + 96

func _ensure_rewards(o: Dictionary) -> void:
	if o.has("rewards") and o["rewards"] is Array:
		o.erase("pack")
		return
	var rewards: Array = []
	for _i in int(o.get("pack", 0)):
		rewards.append("pack_1")
	o["rewards"] = rewards
	o.erase("pack")

func _story_card(y: float, orders: Array, oi: int, level: int) -> float:
	var o: Dictionary = orders[oi]
	var oix = oi
	if not (o.get("items") is Array):
		o["items"] = []
	var items: Array = o["items"]
	_ensure_rewards(o)
	var rewards: Array = o["rewards"]
	var groups = _reward_groups(rewards)
	var layout = _order_layout(items.size())
	layout["seed"] = oi
	var w = float(layout["w"])
	var h = float(layout["h"])
	var origin = Vector2((720.0 - w) * 0.5, y)
	UI.box(editor._root, Rect2(origin, Vector2(w, h)), func(ci, sz):
		_paint_story_card(ci, sz, o, items, layout))
	var who_r: Rect2 = layout["who"]
	UI.hit(editor._root, _shift(origin, who_r), func():
		var n = maxi(1, editor._pages[Files.PEOPLE].size())
		o["who"] = (int(o.get("who", 0)) + 1) % n
		editor._touch(Files.STORY)
		editor._rerender())
	var name_r: Rect2 = layout["name"]
	var name = UI.lbl(editor._root, _who_short(int(o.get("who", 0))), _shift(origin, name_r), 30, Art.INK, HORIZONTAL_ALIGNMENT_LEFT)
	name.clip_text = true
	var xp_r: Rect2 = layout["xp"]
	var xp_edit = editor._bare_num(editor._root, _shift(origin, xp_r), int(o.get("xp", 0)), 0, 999, 28, Color.WHITE, Art.INK, func(n):
		o["xp"] = n
		editor._touch(Files.STORY))
	xp_edit.z_index = 2
	xp_edit.mouse_filter = Control.MOUSE_FILTER_STOP
	var star: Vector2 = layout["star"]
	var star_s = float(layout["star_s"])
	var zone = Rect2(xp_r.position.x, star.y - star_s * 0.5, star.x + star_s * 0.5 - xp_r.position.x, star_s)
	var star_hit = UI.hit(editor._root, _shift(origin, zone), func():
		xp_edit.grab_focus())
	star_hit.z_index = 3
	star_hit.mouse_filter = Control.MOUSE_FILTER_STOP
	var kill_r: Rect2 = layout["kill"]
	var del = UI.hit(editor._root, _shift(origin, kill_r), func():
		orders.remove_at(oix)
		editor._touch(Files.STORY)
		editor._rerender())
	del.extra = editor.growth_page._paint_reward_x
	for k in items.size():
		var kk = k
		var ir = _item_rect(layout, kk)
		UI.hit(editor._root, _shift(origin, ir), func():
			_open_story_item(level, func(id):
				_assign_story_item(id, items, kk, level), str(items[kk])))
		var xb = UI.hit(editor._root, _shift(origin, Rect2(ir.position.x + ir.size.x - 30, ir.position.y - 2, 34, 34)), func():
			if kk < 0 or kk >= items.size():
				return
			items.remove_at(kk)
			editor._touch(Files.STORY)
			editor._rerender())
		xb.extra = editor.growth_page._paint_reward_x
	var pr = _item_rect(layout, items.size())
	UI.hit(editor._root, _shift(origin, pr), func():
		_open_story_item(level, func(id):
			_assign_story_item(id, items, items.size(), level)))
	var plus = UI.lbl(editor._root, "+", _shift(origin, pr), int(pr.size.y * 0.4), Art.INK, HORIZONTAL_ALIGNMENT_CENTER, 0, Art.INK, true)
	plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return _story_rewards(y + h + 4.0, origin.x, w, o, rewards, groups)

func _order_layout(item_n: int) -> Dictionary:
	var item_s = 112.0
	var item_gap = 14.0
	var slots = item_n + 1
	var items_span = float(slots) * item_s + float(maxi(slots - 1, 0)) * item_gap
	var w = clampf(items_span + 96.0, 480.0, 688.0)
	var inner = w - 64.0
	if items_span > inner:
		item_gap = 8.0
		item_s = (inner - float(maxi(slots - 1, 0)) * item_gap) / float(maxi(slots, 1))
		items_span = float(slots) * item_s + float(maxi(slots - 1, 0)) * item_gap
	var items_cy = 168.0
	var h = items_cy + item_s * 0.5 + 36.0
	var star = Vector2(w - 116.0, 54.0)
	var xp = Rect2(star.x - 120.0, star.y - 26.0, 82.0, 52.0)
	return {
		"w": w, "h": h, "seed": 0,
		"head": Vector2(82.0, 54.0), "head_r": 40.0,
		"name": Rect2(134.0, 28.0, 120.0, 52.0),
		"who": Rect2(24.0, 8.0, 220.0, 96.0),
		"star": star, "star_s": 64.0, "xp": xp,
		"kill": Rect2(w - 52.0, 30.0, 38.0, 38.0),
		"item_s": item_s, "item_gap": item_gap, "slots": slots,
		"items_span": items_span, "items_cy": items_cy,
	}

func _item_rect(layout: Dictionary, index: int) -> Rect2:
	var s = float(layout["item_s"])
	var gap = float(layout["item_gap"])
	var x = (float(layout["w"]) - float(layout["items_span"])) * 0.5 + float(index) * (s + gap)
	var y = float(layout["items_cy"]) - s * 0.5
	return Rect2(x, y, s, s)

func _text_px(text: String, fs: int) -> float:
	if G.font_body == null:
		return float(maxi(text.length(), 1)) * float(fs) * 0.62
	return G.font_body.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x

## 胶囊按图标和数字收紧。没有图标的是加号，收成一颗圆。

func _capsule_metrics(text: String, icon: bool, with_x: bool) -> Dictionary:
	var h = 46.0
	if not icon:
		return {"w": h, "h": h, "num": Rect2()}
	var num = Rect2(34.0, 0.0, _text_px(text, 22) + 8.0, h)
	var w = num.end.x + (30.0 if with_x else 10.0)
	return {"w": maxf(w, h), "h": h, "num": num}

func _shift(origin: Vector2, r: Rect2) -> Rect2:
	return Rect2(origin + r.position, r.size)

func _story_rewards(y: float, card_x: float, card_w: float, o: Dictionary, rewards: Array, groups: Array) -> float:
	var specs: Array = []
	specs.append({"kind": "shell", "icon": "shell_2", "text": str(int(o.get("shell", 0))), "x": false})
	for g in groups:
		specs.append({
			"kind": "reward", "id": str(g["id"]), "n": int(g["n"]),
			"icon": str(g["id"]), "text": str(int(g["n"])), "x": true,
		})
	specs.append({"kind": "token", "icon": "token_1", "text": str(int(o.get("token", 0))), "x": false})
	specs.append({"kind": "add", "icon": "", "text": "+", "x": false})
	var metrics: Array = []
	for s in specs:
		var spec: Dictionary = s
		metrics.append(_capsule_metrics(str(spec["text"]), str(spec["icon"]) != "", bool(spec["x"])))
	var gap = 8.0
	var max_row = 688.0
	var lines: Array = []
	var line: Array = []
	var line_w = 0.0
	for i in specs.size():
		var cw = float(metrics[i]["w"])
		var add = cw if line.is_empty() else cw + gap
		if not line.is_empty() and line_w + add > max_row:
			lines.append({"idx": line.duplicate(), "w": line_w})
			line = []
			line_w = 0.0
			add = cw
		line.append(i)
		line_w += add
	if not line.is_empty():
		lines.append({"idx": line, "w": line_w})
	var ch = 46.0
	var yy = y
	for ln in lines:
		var idxs: Array = ln["idx"]
		var tw = float(ln["w"])
		var x = clampf(card_x + (card_w - tw) * 0.5, 16.0, 704.0 - tw)
		var row = Rect2(x, yy, tw, ch)
		var paint_idx: Array = idxs.duplicate()
		UI.box(editor._root, row, _paint_reward_row.bind(paint_idx, metrics, specs))
		var px = x
		for j in idxs.size():
			var ii: int = idxs[j]
			var m: Dictionary = metrics[ii]
			_bind_capsule(Rect2(px, yy, float(m["w"]), ch), m, specs[ii], o, rewards)
			px += float(m["w"]) + gap
		yy += ch + 8.0
	return yy + 6.0

func _paint_reward_row(ci: CanvasItem, _sz: Vector2, idxs: Array, metrics: Array, specs: Array) -> void:
	var gap = 8.0
	var ch = 46.0
	var px = 0.0
	for j in idxs.size():
		var ii: int = idxs[j]
		var m: Dictionary = metrics[ii]
		var r = Rect2(px, 0, float(m["w"]), ch)
		_paint_capsule(ci, r, str(specs[ii]["icon"]), ii)
		px += float(m["w"]) + gap

func _bind_capsule(r: Rect2, m: Dictionary, spec: Dictionary, o: Dictionary, rewards: Array) -> void:
	var kind = str(spec["kind"])
	if kind == "add":
		UI.hit(editor._root, r, func():
			editor._open_pick("item", func(id):
				if id == "":
					return
				rewards.append(id)
				editor._touch(Files.STORY)
			, false))
		var plus = UI.lbl(editor._root, "+", r, 32, Art.INK, HORIZONTAL_ALIGNMENT_CENTER, 0, Art.INK, true)
		plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	var num: Rect2 = m["num"]
	var field = Rect2(r.position + num.position, num.size)
	var shown = str(spec["text"])
	if kind == "shell":
		editor._bare_num(editor._root, field, int(o.get("shell", 0)), 0, 9999, 22, Art.INK, Color.WHITE, func(n):
			o["shell"] = n
			editor._touch(Files.STORY)
		, shown)
	elif kind == "token":
		editor._bare_num(editor._root, field, int(o.get("token", 0)), 0, 99, 22, Art.INK, Color.WHITE, func(n):
			editor._opt(o, "token", n)
			editor._touch(Files.STORY)
		, shown)
	else:
		var gid = str(spec["id"])
		UI.hit(editor._root, Rect2(r.position, Vector2(34, r.size.y)), func():
			editor._open_pick("item", func(id):
				_retarget_reward(rewards, gid, id)
			, false, gid))
		editor._bare_num(editor._root, field, int(spec["n"]), 1, 999, 22, Art.INK, Color.WHITE, func(n):
			_set_group_count(rewards, gid, n)
			editor._touch(Files.STORY)
		, shown)
		var rx = UI.hit(editor._root, Rect2(r.end.x - 28, r.position.y + (r.size.y - 28) * 0.5, 26, 28), func():
			_drop_reward(rewards, gid))
		rx.extra = editor.growth_page._paint_reward_x

func _paint_capsule(ci: CanvasItem, r: Rect2, icon: String, seed: int) -> void:
	var pill = Art.rrect(r, r.size.y * 0.5, 70 + seed, 0.35)
	ci.draw_colored_polygon(pill, Color(0.55, 0.35, 0.15, 0.22))
	if icon != "":
		Art.item(ci, icon, Vector2(r.position.x + 18, r.get_center().y), 34, false)

func _paint_story_card(ci: CanvasItem, sz: Vector2, o: Dictionary, items: Array, layout: Dictionary) -> void:
	var seed = int(layout.get("seed", 0)) * 17 + int(o.get("who", 0))
	var r = Rect2(6, 24, sz.x - 12, sz.y - 36)
	ci.draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(0, 7), r.size), 18, seed, 0.0), Color(0, 0, 0, 0.28))
	var b = Art.rrect(r, 18, seed + 1, 0.9)
	Art.dilate(ci, b, 3.0, Art.INK)
	ci.draw_colored_polygon(b, Color("ffe9a8"))
	Art.dashed(ci, Art.rrect(r.grow(-6), 12, seed + 2, 0.0), 8, 6, Color(0.65, 0.4, 0.2, 0.45), 2.0)
	var head_c: Vector2 = layout["head"]
	var head_rad = float(layout["head_r"])
	var head = Art.ell(head_c, Vector2(head_rad, head_rad), seed + 3, 0.02, 20)
	Art.dilate(ci, head, 3.0, Art.INK)
	ci.draw_colored_polygon(head, Art.OCHRE.lightened(0.28))
	Meme.portrait(ci, int(o.get("who", 0)), head_c + Vector2(0, -2), head_rad * 1.62)
	var star: Vector2 = layout["star"]
	Art.item(ci, "xp_1", star, float(layout["star_s"]))
	for k in items.size():
		var ir = _item_rect(layout, k)
		var c = ir.get_center()
		var s = ir.size.x
		ci.draw_colored_polygon(Art.ell(c + Vector2(0, 5), Vector2(s * 0.4, s * 0.28), seed + 8 + k, 0.03, 16), Color(0.8, 0.65, 0.4, 0.35))
		Art.item(ci, str(items[k]), c, s * 0.94)
	var slot = _item_rect(layout, items.size())
	var pc = slot.get_center()
	var rad = slot.size.x * 0.32
	var ring = Art.ell(pc, Vector2(rad, rad * 0.94), seed + 4, 0.04, 18)
	ci.draw_colored_polygon(ring, Color(1, 0.97, 0.9, 0.55))
	Art.outline(ci, ring, 2.5, Art.INK)

func _reward_groups(rewards: Array) -> Array:
	var out: Array = []
	var index = {}
	for id in rewards:
		var s = str(id)
		if s == "":
			continue
		if not index.has(s):
			index[s] = out.size()
			out.append({"id": s, "n": 0})
		var at: int = index[s]
		out[at]["n"] = int(out[at]["n"]) + 1
	return out

func _set_group_count(rewards: Array, id: String, n: int) -> void:
	var have = 0
	var first = -1
	for i in rewards.size():
		if str(rewards[i]) == id:
			have += 1
			if first < 0:
				first = i
	if n == have:
		return
	if n > have:
		var at = first if first >= 0 else rewards.size()
		for _k in n - have:
			rewards.insert(at, id)
		return
	var drop = have - n
	var i = rewards.size() - 1
	while i >= 0 and drop > 0:
		if str(rewards[i]) == id:
			rewards.remove_at(i)
			drop -= 1
		i -= 1

func _drop_reward(rewards: Array, id: String) -> void:
	var i = rewards.size() - 1
	while i >= 0:
		if str(rewards[i]) == id:
			rewards.remove_at(i)
		i -= 1
	editor._touch(Files.STORY)
	editor._rerender()

func _retarget_reward(rewards: Array, id: String, new_id: String) -> void:
	if new_id == "" or new_id == id:
		return
	for i in rewards.size():
		if str(rewards[i]) == id:
			rewards[i] = new_id
	editor._touch(Files.STORY)

func _who_name(i: int) -> String:
	var people: Array = editor._pages[Files.PEOPLE]
	if i >= 0 and i < people.size():
		return str(people[i])
	return "人物 %d" % i

func _who_short(i: int) -> String:
	var name = _who_name(i)
	if name.contains(" "):
		var part = name.get_slice(" ", 1)
		if part != "":
			return part
	return name
