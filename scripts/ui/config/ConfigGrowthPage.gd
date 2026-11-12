class_name ConfigGrowthPage
extends RefCounted
## growth configuration page and its editing actions.
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

func _albums() -> float:
	var y = 12.0
	editor._h(editor._root, "每本正好 9 张。三列排开，名字写在卡片下面。", 24, y, 680, 22)
	y += 40
	var arr: Array = editor._pages[Files.ALBUMS]
	var cols = 3
	var gap = 14.0
	var pad = 16.0
	var cw = (720.0 - pad * 2.0 - gap * float(cols - 1)) / float(cols)
	var art_h = 156.0
	var name_h = 48.0
	var row_h = art_h + 8.0 + name_h + 14.0
	for i in arr.size():
		var a: Dictionary = arr[i]
		var idx = i
		editor._line(editor._root, Rect2(24, y, 500, 56), str(a.get("name", "")), func(t):
			a["name"] = t
			editor._touch(Files.ALBUMS))
		UI.btn(editor._root, Rect2(540, y, 156, 56), "删除", "red", func():
			arr.remove_at(idx)
			editor._touch(Files.ALBUMS)
			editor._rerender()
		, 22).title_font = false
		y += 68
		if not a.has("cards") or not (a["cards"] is Array):
			a["cards"] = []
		var cards: Array = a["cards"]
		for k in cards.size():
			var kk = k
			var col = kk % cols
			var row = int(kk / cols)
			var x = pad + float(col) * (cw + gap)
			var cy = y + float(row) * row_h
			_album_face(editor._root, Rect2(x, cy, cw, art_h), idx, kk)
			var name_edit = editor._line(editor._root, Rect2(x, cy + art_h + 6.0, cw, name_h), str(cards[kk]), func(t):
				cards[kk] = t
				editor._touch(Files.ALBUMS))
			name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_edit.placeholder_text = "名字"
			var rm = UI.btn(editor._root, Rect2(x + cw - 40.0, cy + 4.0, 36, 36), "×", "red", func():
				cards.remove_at(kk)
				editor._touch(Files.ALBUMS)
				editor._rerender()
			, 22)
			rm.title_font = false
			rm.is_round = true
		var rows = int(ceil(float(maxi(cards.size(), 1)) / float(cols))) if not cards.is_empty() else 0
		y += float(rows) * row_h
		UI.btn(editor._root, Rect2(180, y, 360, 56), "加一张", "teal", func():
			cards.append("")
			editor._touch(Files.ALBUMS)
			editor._rerender()
		, 22).title_font = false
		y += 76
	UI.btn(editor._root, Rect2(180, y, 360, 72), "添加卡册", "green", func():
		arr.append({"name": "新卡册", "cards": ["", "", "", "", "", "", "", "", ""]})
		editor._touch(Files.ALBUMS)
		editor._rerender()
	, 28).title_font = false
	return y + 92

func _album_face(parent: Node, r: Rect2, album: int, idx: int) -> void:
	UI.box(parent, r, func(ci, sz):
		ci.draw_colored_polygon(Art.rrect(Rect2(Vector2(0, 5), sz), 12, album + idx, 0.0), Color(0, 0, 0, 0.22))
		var b = Art.rrect(Rect2(Vector2.ZERO, sz - Vector2(0, 5)), 12, album * 9 + idx, 0.5)
		Art.dilate(ci, b, 2.5, Art.INK)
		ci.draw_colored_polygon(b, Art.BONE)
		var ar = Rect2(Vector2(8, 8), Vector2(sz.x - 16, sz.y - 18))
		Paint.card_art(ci, album, idx, ar)
		ci.draw_rect(ar, Art.INK, false, 2.0)
	, false)

func _amber() -> float:
	var y = 12.0
	var arr: Array = editor._pages[Files.AMBER]
	# 和集市的琥珀礼包一样：都是六边琥珀，礼包越大堆得越多
	var piles = [
		[Art.AMBER_ICON, 1],
		[Art.AMBER_ICON, 2],
		[Art.AMBER_ICON, 3],
		[Art.AMBER_ICON, 4],
		[Art.AMBER_ICON, 5],
		[Art.AMBER_ICON, 6],
	]
	for i in arr.size():
		var a: Dictionary = arr[i]
		var idx = i
		var pile: Array = piles[mini(idx, piles.size() - 1)]
		editor._panel(editor._root, Rect2(16, y, 688, 116))
		_amber_pile(editor._root, Rect2(28, y + 12, 92, 92), str(pile[0]), int(pile[1]))
		editor._h(editor._root, "数量", 136, y + 8, 220, 20)
		editor._num_field(editor._root, Rect2(136, y + 48, 200, 52), int(a.get("n", 0)), 0, 999999, func(n):
			a["n"] = n
			editor._touch(Files.AMBER))
		editor._h(editor._root, "价格", 356, y + 8, 160, 20)
		editor._line(editor._root, Rect2(356, y + 48, 160, 52), str(a.get("price", "")), func(t):
			a["price"] = t
			editor._touch(Files.AMBER))
		UI.btn(editor._root, Rect2(536, y + 48, 148, 52), "删除", "red", func():
			arr.remove_at(idx)
			editor._touch(Files.AMBER)
			editor._rerender()
		, 22).title_font = false
		y += 128
	UI.btn(editor._root, Rect2(180, y, 360, 72), "添加一档", "green", func():
		arr.append({"n": 100, "price": "¥6"})
		editor._touch(Files.AMBER)
		editor._rerender()
	, 28).title_font = false
	return y + 92

func _amber_pile(parent: Node, r: Rect2, id: String, n: int) -> void:
	UI.box(parent, r, func(ci, sz):
		var box = Art.rrect(Rect2(Vector2.ZERO, sz), 14, 3, 0.3)
		ci.draw_colored_polygon(box, Color("fff3d6"))
		Art.outline(ci, box, 2.0, Art.INK)
		var count = maxi(1, n)
		for j in count:
			var cols = mini(count, 3)
			var off = Vector2((float(j % 3) - float(cols - 1) * 0.5) * 20.0, -float(j / 3) * 16.0 + 4.0)
			Art.item(ci, id, sz * 0.5 + off, 48.0 - float(count) * 2.0)
	, false)

func _builds() -> float:
	var y = 12.0
	editor._h(editor._root, "每个区域一串部件，按顺序建。产线填产线 id，随产线开放。", 24, y, 680, 20)
	y += 36
	editor._h(editor._root, "部件 id 决定画法（TribeArt.gd）。篝火广场第 1 件开局已建。", 24, y, 680, 20)
	y += 44
	var arr: Array = editor._pages[Files.BUILDS]
	for i in arr.size():
		var b: Dictionary = arr[i]
		var idx = i
		_fit_parts(b)
		var parts: Array = b["parts"]
		var h = 160.0 + 70.0
		for part in parts:
			h += 64.0 + float(_reward_rows(part["rewards"], REWARD_COLS)) * REWARD_PITCH_Y + 12.0
		editor._panel(editor._root, Rect2(16, y, 688, h))
		editor._line(editor._root, Rect2(28, y + 16, 180, 52), str(b["id"]), func(t):
			b["id"] = t.strip_edges()
			editor._touch(Files.BUILDS))
		editor._line(editor._root, Rect2(220, y + 16, 300, 52), str(b["name"]), func(t):
			b["name"] = t
			editor._touch(Files.BUILDS))
		UI.btn(editor._root, Rect2(540, y + 16, 148, 52), "删除", "red", func():
			arr.remove_at(idx)
			editor._touch(Files.BUILDS)
			editor._rerender()
		, 22).title_font = false
		editor._h(editor._root, "产线", 28, y + 84, 80, 22)
		editor._line(editor._root, Rect2(100, y + 80, 160, 48), str(b.get("line", "")), func(t):
			b["line"] = t.strip_edges()
			editor._touch(Files.BUILDS))
		editor._h(editor._root, "开放等级 %d（随产线）" % Data.build_unlock(b), 280, y + 84, 400, 20)
		var sy = y + 148.0
		for k in parts.size():
			var part: Dictionary = parts[k]
			var pk = k
			editor._line(editor._root, Rect2(36, sy, 170, 48), str(part["id"]), func(t):
				part["id"] = t.strip_edges()
				editor._touch(Files.BUILDS))
			editor._line(editor._root, Rect2(214, sy, 200, 48), str(part["name"]), func(t):
				part["name"] = t
				editor._touch(Files.BUILDS))
			editor._h(editor._root, "不拿拿", 424, sy + 10, 60, 20)
			editor._line(editor._root, Rect2(480, sy, 110, 48), str(int(part["cost"])), func(t):
				if t.strip_edges().is_valid_int():
					part["cost"] = maxi(0, int(t))
					editor._touch(Files.BUILDS))
			UI.btn(editor._root, Rect2(604, sy, 84, 48), "删除", "grey", func():
				parts.remove_at(pk)
				editor._touch(Files.BUILDS)
				editor._rerender()
			, 20).title_font = false
			sy += 60.0
			sy = _reward_board(36.0, sy, part["rewards"], Files.BUILDS) + 12.0
		UI.btn(editor._root, Rect2(200, sy + 4, 320, 56), "添加部件", "green", func():
			parts.append({"id": "part_%d" % (parts.size() + 1), "name": "新部件", "cost": 100 + parts.size() * 50, "rewards": [["fire_2", 15]]})
			editor._touch(Files.BUILDS)
			editor._rerender()
		, 22).title_font = false
		y += h + 16.0
	UI.btn(editor._root, Rect2(180, y, 360, 72), "添加区域", "green", func():
		var b = {"id": "area_%d" % (arr.size() + 1), "name": "新区域", "line": "", "parts": []}
		_fit_parts(b)
		arr.append(b)
		editor._touch(Files.BUILDS)
		editor._rerender()
	, 28).title_font = false
	return y + 92

## 把区域整理成 parts 格式（旧的 stages + rewards 会折成部件）

func _fit_parts(b: Dictionary) -> void:
	if not (b.get("parts") is Array):
		b["parts"] = Data.build_parts(b).duplicate(true)
		b.erase("stages")
		b.erase("rewards")
	var parts: Array = b["parts"]
	if parts.is_empty():
		parts.append({"id": "part_1", "name": "新部件", "cost": 100, "rewards": [["fire_2", 15]]})
	for k in parts.size():
		if parts[k] is not Dictionary:
			parts[k] = {}
		var part: Dictionary = parts[k]
		if str(part.get("id", "")) == "":
			part["id"] = "part_%d" % (k + 1)
		if not part.has("name"):
			part["name"] = str(part["id"])
		part["cost"] = maxi(0, int(part.get("cost", 100)))
		if not (part.get("rewards") is Array):
			part["rewards"] = []
	if not b.has("line"):
		b["line"] = ""

func _reward_board(x: float, y: float, items: Array, path: String) -> float:
	_reward_grid(x, y, REWARD_SQ, REWARD_PITCH_X, REWARD_PITCH_Y, REWARD_COLS, items, path)
	return y + float(_reward_rows(items, REWARD_COLS)) * REWARD_PITCH_Y

func _levels() -> float:
	var y = 12.0
	editor._h(editor._root, "升到这一级时发放。没单独写的更高等级，仍按原来的公式。", 24, y, 680, 22)
	y += 40
	var page: Dictionary = editor._pages[Files.LEVELS]
	if not page.has("levels") or not (page["levels"] is Array):
		page["levels"] = []
	var levels: Array = page["levels"]
	for i in levels.size():
		var row: Dictionary = levels[i]
		var idx = i
		if not (row.get("rewards") is Array):
			row["rewards"] = []
		var rewards: Array = row["rewards"]
		var h = 112.0 + float(_reward_rows(rewards, REWARD_COLS)) * REWARD_PITCH_Y
		editor._panel(editor._root, Rect2(16, y, 688, h))
		editor._stepper(editor._root, 28, y + 16, "升到", int(row.get("level", 2)), 1, 99, func(n):
			row["level"] = n
			editor._touch(Files.LEVELS))
		UI.btn(editor._root, Rect2(540, y + 16, 148, 52), "删除", "red", func():
			levels.remove_at(idx)
			editor._touch(Files.LEVELS)
			editor._rerender()
		, 22).title_font = false
		_reward_board(36.0, y + 84.0, rewards, Files.LEVELS)
		y += h + 16.0
	UI.btn(editor._root, Rect2(180, y, 360, 72), "添加等级", "green", func():
		var n = 2
		for row in levels:
			n = maxi(n, int(row.get("level", 1)) + 1)
		levels.append({"level": n, "rewards": Data.default_level_rewards(n)})
		editor._touch(Files.LEVELS)
		editor._rerender()
	, 28).title_font = false
	return y + 92

func _pass() -> float:
	var y = 12.0
	editor._h(editor._root, "每一档单独填积分，后面要比前面多。", 24, y, 680, 22)
	y += 44
	var levels: Array = editor._pages[Files.PASS].get("levels", [])
	for i in levels.size():
		var lv: Dictionary = levels[i]
		var idx = i
		var row = lv
		editor._h(editor._root, "第 %d 档" % (i + 1), 24, y + 4, 150, 26)
		editor._stepper(editor._root, 180, y, "积分", int(row.get("need", 8)), 1, 9999, func(n):
			row["need"] = n
			editor._touch(Files.PASS))
		UI.btn(editor._root, Rect2(540, y, 156, 48), "删除", "red", func():
			levels.remove_at(idx)
			editor._touch(Files.PASS)
			editor._rerender()
		, 22).title_font = false
		y += 60
		y = _pass_sides(y, lv)
	UI.btn(editor._root, Rect2(180, y, 360, 72), "添加一档", "green", func():
		levels.append({"need": _next_pass_need(levels), "free": [], "prem": [], "super": []})
		editor._touch(Files.PASS)
		editor._rerender()
	, 28).title_font = false
	return y + 92

func _next_pass_need(levels: Array) -> int:
	if levels.is_empty():
		return 8
	return int(levels.back().get("need", 8)) + levels.size() + 1

## 一档的三列奖励：免费、贵宾（prem）、超级贵宾（super）

func _pass_sides(y: float, lv: Dictionary) -> float:
	var keys = ["free", "prem", "super"]
	var names = ["免费", "贵宾", "超级贵宾"]
	var fills = [Color("e4d0aa"), Art.BONE, Color("f6d48a")]
	for key in keys:
		if not lv.has(key) or not (lv[key] is Array):
			lv[key] = []
	var cols = 2
	var margin = 12.0
	var gap = 8.0
	var pane_w = (720.0 - margin * 2.0 - gap * 2.0) / 3.0
	var pad = 10.0
	var col_gap = 6.0
	var sq = (pane_w - pad * 2.0 - col_gap) * 0.5
	var pitch_x = sq + col_gap
	var pitch_y = sq + 62.0
	var head = 44.0
	var rows = 1
	for key in keys:
		rows = maxi(rows, _reward_rows(lv[key], cols))
	var h = head + float(rows) * pitch_y + 10.0
	for k in keys.size():
		var x = margin + float(k) * (pane_w + gap)
		_pass_pane(Rect2(x, y, pane_w, h), fills[k])
		UI.lbl(editor._root, names[k], Rect2(x + pad, y + 8, pane_w - pad * 2.0, 32), 22, Art.INK, HORIZONTAL_ALIGNMENT_LEFT, 0, Art.INK, true)
		_reward_grid(x + pad, y + head, sq, pitch_x, pitch_y, cols, lv[keys[k]], Files.PASS)
	return y + h + 12.0

func _reward_rows(items: Array, cols: int) -> int:
	return int(ceil(float(items.size() + 1) / float(cols)))

func _pass_pane(r: Rect2, fill: Color) -> void:
	UI.box(editor._root, r, func(ci, sz):
		var b = Art.rrect(Rect2(Vector2(2, 4), sz - Vector2(4, 8)), 16, 7, 0.35)
		ci.draw_colored_polygon(b, fill)
		Art.outline(ci, b, 2.5, Art.INK)
	, false)

func _reward_grid(x0: float, y0: float, sq: float, pitch_x: float, pitch_y: float, cols: int, items: Array, path: String) -> void:
	for i in items.size():
		_reward_cell(x0 + float(i % cols) * pitch_x, y0 + float(i / cols) * pitch_y, sq, items, i, path)
	var a = items.size()
	_reward_add(x0 + float(a % cols) * pitch_x, y0 + float(a / cols) * pitch_y, sq, items, path)

func _reward_cell(x: float, y: float, sq: float, items: Array, i: int, path: String) -> void:
	var id = str(items[i][0])
	var hit = UI.hit(editor._root, Rect2(x, y, sq, sq), _pick_reward.bind(items, i, path))
	hit.extra = func(ci, sz):
		editor.chains_page._draw_sq(ci, sz, id, false)
	var kill = UI.hit(editor._root, Rect2(x + sq - 42, y + 4, 38, 38), _remove_reward.bind(items, i, path))
	kill.extra = _paint_reward_x
	editor._num_field(editor._root, Rect2(x, y + sq + 8.0, sq, 46), int(items[i][1]), 1, 9999, func(n):
		items[i][1] = n
		editor._touch(path))

func _reward_add(x: float, y: float, sq: float, items: Array, path: String) -> void:
	var b = UI.hit(editor._root, Rect2(x, y, sq, sq), _append_reward.bind(items, path))
	b.extra = func(ci, sz):
		editor.chains_page._draw_sq(ci, sz, "", false)
	var plus = UI.lbl(editor._root, "+", Rect2(x, y, sq, sq), 48, Art.INK, HORIZONTAL_ALIGNMENT_CENTER, 0, Art.INK, true)
	plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cap = UI.lbl(editor._root, "添加", Rect2(x, y + sq + 8, sq, 46), 18, Color("6b4a2a"), HORIZONTAL_ALIGNMENT_CENTER)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _paint_reward_x(ci: CanvasItem, sz: Vector2) -> void:
	var c = sz * 0.5
	var rad = minf(sz.x, sz.y) * 0.5 - 1.0
	ci.draw_circle(c + Vector2(0, 2), rad, Color(0, 0, 0, 0.28))
	ci.draw_circle(c, rad - 1.0, Color("c4452e"))
	var f: Font = G.font_title
	var fs = 18
	var text = "×"
	var tw = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos = Vector2(c.x - tw * 0.5, c.y + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5)
	ci.draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Art.INK)
	ci.draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)

func _pick_reward(items: Array, i: int, path: String) -> void:
	if i < 0 or i >= items.size():
		return
	editor._open_pick("reward", _set_reward_id.bind(items[i], path), false, str(items[i][0]))

func _remove_reward(items: Array, i: int, path: String) -> void:
	if i < 0 or i >= items.size():
		return
	items.remove_at(i)
	editor._touch(path)
	editor._rerender()

func _append_reward(items: Array, path: String) -> void:
	items.append(["fruit_1", 1])
	editor._touch(path)
	editor._rerender()

func _set_reward_id(id: String, rw: Array, path: String) -> void:
	rw[0] = id
	editor._touch(path)

func _random_orders() -> float:
	var page = editor._pages[Files.RANDOM_ORDERS]
	if page is not Dictionary:
		page = {}
		editor._pages[Files.RANDOM_ORDERS] = page
	var pad = OrderCurvePadSc.new()
	pad.edit = editor
	pad.page = page
	pad.position = Vector2.ZERO
	var h = editor._sc.size.y
	if h < 100.0:
		h = 1340.0
	pad.size = Vector2(720, h)
	editor._root.add_child(pad)
	return h

func _rules() -> float:
	var d: Dictionary = editor._pages[Files.RULES]
	var y = 12.0
	editor._h(editor._root, "列和行用奇数，中心格才唯一。改大小后保存，棋盘会按新尺寸裁好。", 24, y, 680, 22)
	y += 48
	y = _rule(d, y, "cols", "列数", 1, 15)
	y = _rule(d, y, "rows", "行数", 1, 20)
	y = _rule(d, y, "max_energy", "体力上限", 1, 9999)
	y = _rule(d, y, "regen_sec", "恢复秒数", 1, 9999)
	y = _order_capacity_rules(d, y)
	y = _rule(d, y, "craft_level", "制作单开放等级", 1, 40)
	y = _rule(d, y, "xp_base", "升级声望起点", 1, 99)
	y = _rule(d, y, "xp_div", "每几级声望+1", 1, 20)
	y = _rule(d, y, "energy_price", "体力首次价格", 1, 999)
	y = _rule(d, y, "energy_price_step", "体力每次涨价", 0, 999)
	y = _rule(d, y, "energy_price_max", "体力最高价格", 1, 999)
	y = _rule(d, y, "token_step", "鼓换卡包", 1, 999)
	y = _rule(d, y, "storage_expand_price", "储物首次价格", 1, 999)
	y = _rule(d, y, "storage_expand_step", "储物每排涨价", 1, 999)
	return y + 20

func _order_capacity_rules(d: Dictionary, y: float) -> float:
	if not d.get("order_cap_at") is Array: d["order_cap_at"] = [1, 1, 4, 10, 20]
	var caps: Array = d["order_cap_at"]
	editor._h(editor._root, "最大订单数", 24, y, 280, 22)
	editor._num_field(editor._root, Rect2(320, y, 150, 48), caps.size(), 1, 12, func(n):
		while caps.size() < n: caps.append(1 if caps.is_empty() else mini(99, int(caps.back()) + 5))
		caps.resize(n)
		editor._touch(Files.RULES)
		editor._rerender())
	y += 68
	for i in caps.size():
		var index = i
		editor._h(editor._root, "第 %d 单开放等级" % (i + 1), 24, y, 280, 22)
		editor._num_field(editor._root, Rect2(320, y, 150, 48), int(caps[i]), 1, 99, func(n):
			caps[index] = n
			editor._touch(Files.RULES))
		y += 68
	return y

func _rule(d: Dictionary, y: float, key: String, label: String, lo: int, hi: int) -> float:
	editor._stepper(editor._root, 24, y, label, int(d.get(key, 0)), lo, hi, func(n):
		d[key] = n
		editor._touch(Files.RULES))
	return y + 68

# ---------------------------------------------------------------- 控件
