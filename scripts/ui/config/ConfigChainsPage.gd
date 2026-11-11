class_name ConfigChainsPage
extends RefCounted
## chains configuration page and its editing actions.
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

func _chains() -> float:
	var y = 8.0
	editor._h(editor._root, "一条产业链分三列。从左到右是从低级到高级，点方格改这一级。", 24, y, 680, 22)
	y += 40
	var sq = 124.0
	var lines: Array = editor._pages[Files.LINES]
	var used = {}
	for line in lines:
		y = _chain_head(y, str(line.get("name", "")))
		var roles = [
			["生产器队列", str(line.get("gen", ""))],
			["主产物队列", str(line.get("main", ""))],
			["副产物队列", str(line.get("sub", ""))],
		]
		var qh = 46.0 + sq + 52.0
		var box_h = 12.0 + roles.size() * qh
		editor._panel(editor._root, Rect2(12, y, 696, box_h))
		var qy = y + 10.0
		for role in roles:
			var cid = str(role[1])
			if cid != "":
				used[cid] = true
			_queue(qy, str(role[0]), _chain_at(cid), sq)
			qy += qh
		y += box_h + 22.0
	var rest: Array = []
	var arr: Array = editor._pages[Files.CHAINS]
	for i in arr.size():
		var cid = str(arr[i].get("id", ""))
		if not used.has(cid):
			rest.append(i)
	if not rest.is_empty():
		y = _chain_head(y, "其他")
		for ci in rest:
			var c: Dictionary = arr[ci]
			_queue(y, str(c.get("name", c.get("id", ""))), int(ci), sq)
			y += 46.0 + sq + 52.0
		y += 8.0
	UI.btn(editor._root, Rect2(180, y, 360, 76), "添加物品链", "green", func():
		arr.append({"id": "chain_%d" % (arr.size() + 1), "name": "新链", "type": "item", "items": ["新物品"]})
		editor._touch(Files.CHAINS)
		editor._open_chain(arr.size() - 1)
	, 28).title_font = false
	return y + 96

func _chain_head(y: float, text: String) -> float:
	var lab = UI.lbl(editor._root, text, Rect2(24, y, 640, 40), 30, Art.INK, HORIZONTAL_ALIGNMENT_LEFT, 0, Art.INK, true)
	lab.clip_text = true
	UI.box(editor._root, Rect2(24, y + 38, 672, 10), func(ci, sz):
		Art.ln(ci, Vector2(0, 4), Vector2(sz.x, 4), 2.5, Color("c9a774"), 2)
	, false)
	return y + 52.0

func _chain_at(id: String) -> int:
	if id == "":
		return -1
	var arr: Array = editor._pages[Files.CHAINS]
	for i in arr.size():
		if str(arr[i].get("id", "")) == id:
			return i
	return -1

func _queue(y: float, label: String, ci: int, sq: float) -> void:
	var title = label
	if ci >= 0:
		var cname = str(editor._pages[Files.CHAINS][ci].get("name", ""))
		if cname != "" and cname != label:
			title = "%s · %s" % [label, cname]
		var edit = UI.btn(editor._root, Rect2(576, y, 116, 40), "编辑", "teal", func():
			editor._open_chain(ci)
		, 20)
		edit.title_font = false
		_icon_row(y + 44.0, ci, sq)
	else:
		UI.lbl(editor._root, "还没接上", Rect2(560, y, 140, 40), 18, Color("8a5a30"), HORIZONTAL_ALIGNMENT_RIGHT)
	var lab = UI.lbl(editor._root, title, Rect2(28, y, 530, 40), 22, Color("6b4a2a"), HORIZONTAL_ALIGNMENT_LEFT)
	lab.clip_text = true

func _icon_row(y: float, ci: int, sq: float) -> void:
	var arr: Array = editor._pages[Files.CHAINS]
	var c: Dictionary = arr[ci]
	if not c.has("items") or not (c["items"] is Array):
		c["items"] = []
	var items: Array = c["items"]
	var pitch = sq + 12.0
	var sc = Scroller.new()
	sc.horizontal = true
	sc.position = Vector2(20, y)
	sc.size = Vector2(680, sq + 42.0)
	editor._root.add_child(sc)
	var focus = -1.0
	for k in items.size():
		var kk = k
		var id = "%s_%d" % [str(c.get("id", "")), kk + 1]
		var on = editor._sheet_open and editor._sheet_kind == "item" and editor._sheet_ci == ci and editor._sheet_ii == kk
		if on:
			focus = float(kk) * pitch
		_sq(sc.content, kk * pitch, 0, sq, id, str(items[kk]), str(kk + 1), on, func():
			editor._open_item(ci, kk))
	sc.set_length(float(items.size()) * pitch + 8.0)
	if focus >= 0.0:
		sc.jump_to(focus + sq * 0.5 - sc.size.x * 0.5)

func _sq(parent: Node, x: float, y: float, sq: float, id: String, caption: String, mark: String, on: bool, cb: Callable) -> void:
	var b = UI.hit(parent, Rect2(x, y, sq, sq + 36.0), cb)
	b.extra = func(ci, sz):
		_draw_sq(ci, sz, id, on)
		if mark != "":
			var f: Font = G.font_title
			var pos = Vector2(14, 34)
			ci.draw_string_outline(f, pos, mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 6, Art.INK)
			ci.draw_string(f, pos, mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	var cap = UI.lbl(parent, caption, Rect2(x, y + sq - 2, sq, 32), 16, Color("6b4a2a"))
	cap.clip_text = true

func _sq_add(parent: Node, x: float, y: float, sq: float, cb: Callable) -> void:
	var b = UI.hit(parent, Rect2(x, y, sq, sq + 36.0), cb)
	b.extra = func(ci, sz):
		_draw_sq(ci, sz, "", false)
	var plus = UI.lbl(parent, "+", Rect2(x, y, sq, sq), 48, Art.INK, HORIZONTAL_ALIGNMENT_CENTER, 0, Art.INK, true)
	plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cap = UI.lbl(parent, "添加", Rect2(x, y + sq - 2, sq, 32), 16, Color("6b4a2a"))
	cap.clip_text = true

func _draw_sq(ci: CanvasItem, sz: Vector2, id: String, on: bool) -> void:
	var side = sz.x
	var box = Art.rrect(Rect2(Vector2(4, 6), Vector2(side - 8, side - 12)), 18, 6, 0.3)
	Art.dilate(ci, box, 3.0, Art.INK)
	ci.draw_colored_polygon(box, Art.BONE)
	Art.outline(ci, box, 5.0 if on else 2.5, Art.MOSS_D if on else Art.INK)
	if id != "":
		Art.item(ci, id, Vector2(side * 0.5, side * 0.48), side * 0.68)

func _shift_chain(dir: int) -> void:
	var i = editor._sheet_ci
	var j = i + dir
	var arr: Array = editor._pages[Files.CHAINS]
	if j < 0 or j >= arr.size():
		return
	var tmp = arr[i]
	arr[i] = arr[j]
	arr[j] = tmp
	editor._sheet_ci = j
	editor._touch(Files.CHAINS)
	editor._rerender()

func _chain_type(ci: int) -> String:
	var arr: Array = editor._pages[Files.CHAINS]
	if ci < 0 or ci >= arr.size():
		return ""
	return str(arr[ci].get("type", ""))

func _fill_item() -> void:
	var arr: Array = editor._pages[Files.CHAINS]
	if editor._sheet_ci < 0 or editor._sheet_ci >= arr.size():
		return
	var chain: Dictionary = arr[editor._sheet_ci]
	if not chain.has("items") or not (chain["items"] is Array):
		chain["items"] = []
	var items: Array = chain["items"]
	if editor._sheet_ii < 0 or editor._sheet_ii >= items.size():
		return
	_fit_value(chain)
	var ii = editor._sheet_ii
	if str(chain.get("type", "")) == "gen":
		_fill_gen(chain, ii)
		return
	editor._sheet_title.text = str(items[ii])
	var y = 8.0
	var icon = "%s_%d" % [str(chain.get("id", "")), ii + 1]
	y = _level_icon(y, icon, chain, items, ii)
	var name_edit = editor._row_edit(editor._sheet_root, y, "名字", str(items[ii]), func(t):
		items[ii] = t
		editor._sheet_title.text = t if t != "" else "未命名"
		editor._touch(Files.CHAINS))
	editor._refresh_on_blur(name_edit)
	y += 72
	if str(chain.get("type", "")) in VALUED:
		editor._row_step(editor._sheet_root, y, "收取", int(chain["value"][ii]), 0, 99999, func(n):
			chain["value"][ii] = n
			editor._touch(Files.CHAINS))
		y += 72
	elif str(chain.get("type", "")) == "item":
		editor._row_step(editor._sheet_root, y, "价值", int(chain["value"][ii]), 0, 99999, func(n):
			chain["value"][ii] = n
			editor._touch(Files.CHAINS))
		y += 72
	editor._sheet_sc.set_length(y + 24)

func _fill_gen(chain: Dictionary, ii: int) -> void:
	var items: Array = chain["items"]
	var level = ii + 1
	editor._sheet_title.text = str(items[ii])
	var y = 8.0
	var icon = "%s_%d" % [str(chain.get("id", "")), level]
	y = _level_icon(y, icon, chain, items, ii)
	var name_edit = editor._row_edit(editor._sheet_root, y, "名字", str(items[ii]), func(t):
		items[ii] = t
		editor._sheet_title.text = t if t != "" else "未命名"
		editor._touch(Files.CHAINS))
	editor._refresh_on_blur(name_edit)
	y += 72
	_fit_prod(chain)
	var prod_title = UI.lbl(editor._sheet_root, "产物", Rect2(24, y, 680, 40), 26, Color("6b4a2a"), HORIZONTAL_ALIGNMENT_LEFT)
	prod_title.clip_text = true
	y += 44
	y = _drop_row(y, chain, ii)
	var line = _line_by_id(str(chain.get("line", "")))
	var slot = chain["prod"][ii]
	if line.get("cooldown", false) and slot is Dictionary:
		y += 12
		editor._row_step(editor._sheet_root, y, "储量", int(slot.get("charges", 8)), 1, 99, func(n):
			slot["charges"] = n
			editor._touch(Files.CHAINS))
		y += 72
		editor._row_step(editor._sheet_root, y, "回满分", int(slot.get("refill_min", 12)), 1, 999, func(n):
			slot["refill_min"] = n
			editor._touch(Files.CHAINS))
		y += 72
	editor._sheet_sc.set_length(y + 24)

func _drop_row(y: float, chain: Dictionary, ii: int) -> float:
	var slot = chain["prod"][ii]
	var drops: Array = slot["drops"] if slot is Dictionary and slot.get("drops") is Array else []
	var sq = 108.0
	var pitch = 128.0
	var sc = Scroller.new()
	sc.horizontal = true
	sc.position = Vector2(16, y)
	sc.size = Vector2(688, sq + 68.0)
	editor._sheet_root.add_child(sc)
	for i in drops.size():
		_drop_cell(sc.content, float(i) * pitch, sq, drops[i], chain, ii, i)
	_sq_add(sc.content, drops.size() * pitch, 0, sq, func():
		editor._chooser.open("选择产物", _item_choices(), func(id):
			_add_drop(chain, ii, id)))
	sc.set_length(float(drops.size() + 1) * pitch + 8.0)
	return y + sq + 76.0

func _drop_cell(parent: Node, x: float, sq: float, drop: Dictionary, chain: Dictionary, ii: int, di: int) -> void:
	var id = str(drop.get("id", ""))
	editor._icon(parent, Rect2(x, 0, sq, sq), id)
	var rm = UI.btn(parent, Rect2(x + sq - 36, 2, 36, 36), "×", "red", func():
		_remove_drop(chain, ii, di)
	, 20)
	rm.is_round = true
	rm.title_font = false
	editor._num_field(parent, Rect2(x, sq + 8, sq, 48), int(drop.get("p", 0)), 0, 9999, func(n):
		drop["p"] = n
		editor._touch(Files.CHAINS))

func _add_drop(chain: Dictionary, ii: int, id: String) -> void:
	if Data.is_numeric_resource(id):
		G.main.toast("数值资源不能作为生产器产物")
		return
	if id == "":
		return
	_fit_prod(chain)
	var slot = chain["prod"][ii]
	if not (slot is Dictionary):
		slot = {"drops": [], "charges": 8, "refill_min": 12}
		chain["prod"][ii] = slot
	if not slot.has("drops") or not (slot["drops"] is Array):
		slot["drops"] = []
	for d in slot["drops"]:
		if str(d.get("id", "")) == id:
			G.main.toast("已经加过了")
			return
	slot["drops"].append({"id": id, "p": 1})
	editor._touch(Files.CHAINS)
	editor._rerender()

func _remove_drop(chain: Dictionary, ii: int, di: int) -> void:
	var slot = chain["prod"][ii]
	if not (slot is Dictionary):
		return
	var drops: Array = slot.get("drops", [])
	if di < 0 or di >= drops.size():
		return
	drops.remove_at(di)
	if drops.is_empty():
		chain["prod"][ii] = null
	editor._touch(Files.CHAINS)
	editor._rerender()

func _line_names() -> Dictionary:
	var line_name = {}
	for line in editor._pages[Files.LINES]:
		if not (line is Dictionary):
			continue
		var lname = str(line.get("name", line.get("id", "")))
		for key in ["gen", "main", "sub"]:
			var ref = str(line.get(key, ""))
			if ref != "":
				line_name[ref] = lname
	return line_name

func _pick_entries(kind: String) -> Array:
	if kind == "reward": return _reward_choices()
	if kind == "chain":
		return _chain_choices()
	if kind == "pline":
		return _line_choices()
	return _item_choices()

func _chain_choices() -> Array:
	var line_name = _line_names()
	var out: Array = []
	for c in editor._pages[Files.CHAINS]:
		if not (c is Dictionary):
			continue
		if str(c.get("type", "")) in ["xp", "token"]: continue
		var cid = str(c.get("id", ""))
		if cid == "":
			continue
		out.append({
			"id": cid,
			"name": str(c.get("name", cid)),
			"icon": _chain_icon(cid),
			"tab": str(line_name.get(cid, "其他")),
		})
	return out

func _line_choices() -> Array:
	var out: Array = []
	for line in editor._pages[Files.LINES]:
		if not (line is Dictionary):
			continue
		var id = str(line.get("id", ""))
		out.append({
			"id": id,
			"name": str(line.get("name", id)),
			"icon": _chain_icon(str(line.get("gen", ""))),
		})
	return out

func _item_choices() -> Array:
	var line_name = _line_names()
	var out: Array = []
	var arr: Array = editor._pages[Files.CHAINS]
	for c in arr:
		if not (c is Dictionary):
			continue
		if str(c.get("type", "")) in ["xp", "token"]: continue
		var cid = str(c.get("id", ""))
		if cid == "":
			continue
		var items: Array = c.get("items", [])
		var group = str(c.get("name", cid))
		var tab = str(line_name.get(cid, "其他"))
		for i in items.size():
			var id = "%s_%d" % [cid, i + 1]
			out.append({"id": id, "name": str(items[i]), "icon": id, "group": group, "tab": tab})
	return out

func _reward_choices() -> Array:
	var out = _item_choices()
	for id in Data.REWARD_RESOURCES:
		out.append({"id": str(id), "name": Data.name_of(str(id)), "icon": str(id), "group": "数值资源", "tab": "数值资源"})
	return out

func _level_icon(y: float, id: String, chain: Dictionary, items: Array, ii: int) -> float:
	var side = 148.0
	var btn = 76.0
	var icon_x = 286.0
	var by = y + (side - btn) * 0.5
	var left = UI.btn(editor._sheet_root, Rect2(icon_x - 96, by, btn, btn), "<", "grey", func():
		_shift_level(chain, items, ii, -1)
	, 40)
	left.title_font = false
	left.is_round = true
	left.enabled = ii > 0
	editor._icon(editor._sheet_root, Rect2(icon_x, y, side, side), id)
	var right = UI.btn(editor._sheet_root, Rect2(icon_x + side + 20, by, btn, btn), ">", "grey", func():
		_shift_level(chain, items, ii, 1)
	, 40)
	right.title_font = false
	right.is_round = true
	right.enabled = ii < items.size() - 1
	return y + side + 20

func _shift_level(chain: Dictionary, items: Array, ii: int, dir: int) -> void:
	var j = ii + dir
	if j < 0 or j >= items.size():
		return
	editor._swap(items, ii, dir)
	_swap_value(chain, ii, dir)
	_swap_prod(chain, ii, dir)
	editor._sheet_ii = j
	editor._touch(Files.CHAINS)
	editor._rerender()

func _line_by_id(id: String) -> Dictionary:
	if id == "":
		return {}
	for ln in editor._pages[Files.LINES]:
		if str(ln.get("id", "")) == id:
			return ln
	return {}

func _gen_form(ci: int, ii: int) -> bool:
	var arr: Array = editor._pages[Files.CHAINS]
	if ci < 0 or ci >= arr.size() or ii < 0:
		return false
	var prod = arr[ci].get("prod", [])
	return prod is Array and ii < prod.size() and prod[ii] is Dictionary

func _fill_chain() -> void:
	var arr: Array = editor._pages[Files.CHAINS]
	if editor._sheet_ci < 0 or editor._sheet_ci >= arr.size():
		return
	var chain: Dictionary = arr[editor._sheet_ci]
	if not chain.has("items") or not (chain["items"] is Array):
		chain["items"] = []
	_fit_value(chain)
	_fit_prod(chain)
	editor._sheet_title.text = str(chain.get("name", ""))
	var y = 12.0
	var id_edit = editor._row_edit(editor._sheet_root, y, "id", str(chain.get("id", "")), func(t):
		chain["id"] = t.strip_edges()
		editor._touch(Files.CHAINS))
	editor._refresh_on_blur(id_edit)
	y += 72
	var name_edit = editor._row_edit(editor._sheet_root, y, "名字", str(chain.get("name", "")), func(t):
		chain["name"] = t
		editor._sheet_title.text = t if t != "" else "未命名"
		editor._touch(Files.CHAINS))
	editor._refresh_on_blur(name_edit)
	y += 72
	var line_edit = editor._row_edit(editor._sheet_root, y, "产线", str(chain.get("line", "")), func(t):
		_set_opt(chain, "line", t)
		editor._touch(Files.CHAINS))
	editor._refresh_on_blur(line_edit)
	y += 80
	UI.btn(editor._sheet_root, Rect2(24, y, 160, 56), "上移", "grey", _shift_chain.bind(-1), 22).title_font = false
	UI.btn(editor._sheet_root, Rect2(200, y, 160, 56), "下移", "grey", _shift_chain.bind(1), 22).title_font = false
	UI.btn(editor._sheet_root, Rect2(460, y, 236, 56), "删除这条链", "red", func():
		arr.remove_at(editor._sheet_ci)
		editor._touch(Files.CHAINS)
		editor._close_sheet()
	, 22).title_font = false
	editor._sheet_sc.set_length(y + 80)

func _set_opt(chain: Dictionary, key: String, text: String) -> void:
	var s = text.strip_edges()
	if s == "":
		chain.erase(key)
	else:
		chain[key] = s

func _fit_value(chain: Dictionary) -> void:
	var t = str(chain.get("type", ""))
	if t in VALUED or t == "item":
		if not chain.has("value") or not (chain["value"] is Array):
			chain["value"] = []
		while chain["value"].size() < chain["items"].size():
			chain["value"].append(0)
		while chain["value"].size() > chain["items"].size():
			chain["value"].pop_back()
	else:
		chain.erase("value")

func _fit_prod(chain: Dictionary) -> void:
	if str(chain.get("type", "")) != "gen":
		chain.erase("prod")
		return
	if not chain.has("items") or not (chain["items"] is Array):
		chain["items"] = []
	if not chain.has("prod") or not (chain["prod"] is Array):
		chain["prod"] = []
	while chain["prod"].size() < chain["items"].size():
		chain["prod"].append(null)
	while chain["prod"].size() > chain["items"].size():
		chain["prod"].pop_back()

func _swap_value(chain: Dictionary, i: int, dir: int) -> void:
	if not chain.has("value"):
		return
	editor._swap(chain["value"], i, dir)

func _swap_prod(chain: Dictionary, i: int, dir: int) -> void:
	if not chain.has("prod"):
		return
	editor._swap(chain["prod"], i, dir)

func _chain_icon(cid: String) -> String:
	if cid == "":
		return ""
	return "%s_1" % cid
