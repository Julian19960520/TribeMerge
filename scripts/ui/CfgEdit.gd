class_name CfgEdit
extends Control
## 游戏里的配置编辑。物品链排成方格，点开后从底部拉起面板改这一级。
## 每一页的保存只写回自己的那一个 data/*.json，并立刻重新读入。
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

var chains_page
var board_page
var story_page
var growth_page
var _pages = {}
var _dirty = {}
var _stack: Array = []
var _sc: Scroller
var _root: Control
var _title: Label
var _save_btn: TButton
var _keep_scroll = false
var _block_refresh = false
var _sheet: Control
var _dim: ColorRect
var _sheet_panel: Control
var _sheet_bg: DrawBox
var _sheet_title: Label
var _sheet_sc: Scroller
var _sheet_root: Control
var _sheet_tw: Tween
var _sheet_open = false
var _sheet_kind = ""
var _sheet_ci = -1
var _sheet_ii = -1
var _chooser
var _board_mode = "item"

func _ready() -> void:
	chains_page = ConfigChainsPage.new(self)
	board_page = ConfigBoardPage.new(self)
	story_page = ConfigStoryPage.new(self)
	growth_page = ConfigGrowthPage.new(self)
	size = Vector2(720, 1480)
	mouse_filter = MOUSE_FILTER_STOP
	UI.box(self, Rect2(0, 0, 720, 1480), func(ci, sz):
		ci.draw_rect(Rect2(Vector2.ZERO, sz), Color("f6e7c8"))
		ci.draw_rect(Rect2(0, 0, sz.x, 140), Color("3b2314"))
	, false)
	var back = UI.btn(self, Rect2(16, 34, 120, 72), "返回", "hide", _on_back, 28)
	back.title_font = false
	_title = UI.lbl(self, "配置", Rect2(148, 34, 326, 72), 36, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 8, Art.INK, true)
	_save_btn = UI.btn(self, Rect2(482, 34, 222, 72), "保存并重开测试局", "green", _save, 21)
	_save_btn.title_font = false
	_sc = Scroller.new()
	_sc.position = Vector2(0, 140)
	_sc.size = Vector2(720, 1340)
	add_child(_sc)
	_root = _sc.content
	_load_pages()
	_build_sheet()
	_chooser = PickSheetSc.new()
	add_child(_chooser)
	_stack = [{"page": "hub", "i": -1}]
	_render()

func _load_pages() -> void:
	_pages.clear()
	for c in _catalog():
		var v = Files.read(c["path"])
		if v == null:
			v = {} if c["id"] in ["story", "pass", "board", "rules", "levels", "rand", "unlock"] else []
		_pages[c["path"]] = v
	var lines = Files.read(Files.LINES)
	_pages[Files.LINES] = lines if lines != null else []

func _catalog() -> Array:
	return [
		{"id": "chains", "title": "物品链", "icon": "chains", "path": Files.CHAINS},
		{"id": "board", "title": "初始棋盘", "icon": "board", "path": Files.BOARD},
		{"id": "story", "title": "剧情订单", "icon": "story", "path": Files.STORY},
		{"id": "unlock", "title": "产物解锁", "icon": "unlock", "path": Files.UNLOCKS},
		{"id": "rand", "title": "随机订单", "icon": "rand", "path": Files.RANDOM_ORDERS},
		{"id": "pass", "title": "通行证", "icon": "pass", "path": Files.PASS},
		{"id": "albums", "title": "卡册", "icon": "albums", "path": Files.ALBUMS},
		{"id": "people", "title": "人物", "icon": "people", "path": Files.PEOPLE},
		{"id": "builds", "title": "建筑", "icon": "builds", "path": Files.BUILDS},
		{"id": "levels", "title": "主角等级", "icon": "level", "path": Files.LEVELS},
		{"id": "amber", "title": "琥珀充值", "icon": "amber", "path": Files.AMBER},
		{"id": "rules", "title": "规则", "icon": "rules", "path": Files.RULES},
	]

func _on_back() -> void:
	if _chooser != null and _chooser.is_open():
		_chooser.close()
		return
	if _sheet_open:
		_close_sheet()
		return
	if _stack.size() > 1:
		_stack.pop_back()
		_keep_scroll = false
		call_deferred("_render")
	else:
		G.main.show_screen("home")

func _go(page: String, i: int = -1) -> void:
	_stack.append({"page": page, "i": i})
	_keep_scroll = false
	call_deferred("_render")

func _rerender() -> void:
	_keep_scroll = true
	call_deferred("_render")

func _touch(path: String) -> void:
	if path == "":
		return
	_dirty[path] = true
	_refresh_save()

func _path_title(path: String) -> String:
	for c in _catalog():
		if str(c["path"]) == path:
			return str(c["title"])
	return path

func _page_path(page: String) -> String:
	for c in _catalog():
		if c["id"] == page:
			return str(c["path"])
	return ""

func _refresh_save() -> void:
	var path = _page_path(str(_cur()["page"]))
	_save_btn.visible = path != ""
	_save_btn.text = "保存并重开测试局*" if path != "" and _dirty.has(path) else "保存并重开测试局"
	_save_btn.enabled = not Cloud.enabled
	_save_btn.queue_redraw()

func _cur() -> Dictionary:
	return _stack[_stack.size() - 1]

func _render() -> void:
	var keep = _sc.offset if _keep_scroll else 0.0
	_keep_scroll = false
	_wipe(_root)
	var page = str(_cur()["page"])
	_title.text = _page_title(page)
	var bottom = 40.0
	match page:
		"hub": bottom = _hub()
		"chains": bottom = chains_page._chains()
		"people": bottom = story_page._people()
		"story": bottom = story_page._story()
		"unlock": bottom = story_page._unlocks()
		"rand": bottom = growth_page._random_orders()
		"albums": bottom = growth_page._albums()
		"amber": bottom = growth_page._amber()
		"builds": bottom = growth_page._builds()
		"levels": bottom = growth_page._levels()
		"pass": bottom = growth_page._pass()
		"board": bottom = board_page._board()
		"rules": bottom = growth_page._rules()
	_sc.set_length(bottom + 48.0)
	_sc.offset = clampf(keep, 0.0, _sc._max())
	if page != "chains":
		_hide_sheet()
	elif _sheet_open:
		var h = _sheet_height()
		_apply_sheet_height(h)
		if _sheet_tw == null or not _sheet_tw.is_valid() or not _sheet_tw.is_running():
			_sheet_panel.position.y = 1340.0 - h
		_fill_sheet()
	_refresh_save()

func _page_title(page: String) -> String:
	for c in _catalog():
		if c["id"] == page:
			return c["title"]
	return "配置"

func _open_pick(kind: String, cb: Callable, allow_empty: bool, current = null) -> void:
	var entries = chains_page._pick_entries(kind)
	if allow_empty:
		entries.insert(0, {"id": "", "name": "空", "icon": "", "pin": true})
	var title = "选择物品"
	if kind == "reward": title = "选择奖励"
	if kind == "chain":
		title = "选择物品链"
	elif kind == "pline":
		title = "选择产线"
	_chooser.open(title, entries, func(id):
		if cb.is_valid():
			cb.call(id)
		_rerender(), current)

func _shot_cell(empty: bool) -> void:
	_open_pick("item", func(_id): pass, empty)

func _assign(id: String, obj: Dictionary, key: String, path: String) -> void:
	obj[key] = id
	_touch(path)

func _assign_at(id: String, arr: Array, i: int, path: String) -> void:
	arr[i] = id
	_touch(path)

func _hub() -> float:
	_h(_root, "点开一张表，改完在该页保存，只写入这一个文件。", 24, 12, 680, 24)
	if not _dirty.is_empty():
		var revert = UI.btn(_root, Rect2(24, 52, 200, 56), "放弃修改", "grey", _revert, 22)
		revert.title_font = false
	var y = 124.0
	var cats = _catalog()
	for i in cats.size():
		var c: Dictionary = cats[i]
		var col = i % 2
		var row = int(i / 2)
		var r = Rect2(20 + col * 348, y + row * 176, 332, 164)
		_card(_root, r, c["icon"], c["title"], _go.bind(c["id"], -1))
	return y + ceil(cats.size() / 2.0) * 176.0

func _revert() -> void:
	_load_pages()
	_dirty.clear()
	_stack = [{"page": "hub", "i": -1}]
	_keep_scroll = false
	call_deferred("_render")
	G.main.toast("已从文件重新读取")

func _build_sheet() -> void:
	_sheet = Control.new()
	_sheet.position = Vector2(0, 140)
	_sheet.size = Vector2(720, 1340)
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.clip_contents = true
	_sheet.visible = false
	_sheet.z_index = 5
	add_child(_sheet)
	_dim = ColorRect.new()
	_dim.color = Color(0.08, 0.04, 0.02, 0.0)
	_dim.size = Vector2(720, 1340)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_close_sheet())
	_sheet.add_child(_dim)
	_sheet_panel = Control.new()
	_sheet_panel.position = Vector2(0, 1340)
	_sheet_panel.size = Vector2(720, 740)
	_sheet_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_sheet.add_child(_sheet_panel)
	_sheet_bg = UI.box(_sheet_panel, Rect2(0, 0, 720, 740), func(ci, sz):
		var b = Art.rrect(Rect2(Vector2(0, 10), Vector2(sz.x, sz.y)), 28, 8, 0.2)
		Art.dilate(ci, b, 3.0, Art.INK)
		ci.draw_colored_polygon(b, Art.BONE)
		Art.outline(ci, b, 3.0, Art.INK)
		var grip = Art.rrect(Rect2(sz.x * 0.5 - 40, 22, 80, 10), 5, 2, 0.2)
		ci.draw_colored_polygon(grip, Color("c9a774"))
	, false)
	_sheet_title = UI.lbl(_sheet_panel, "", Rect2(24, 40, 560, 52), 32, Art.INK, HORIZONTAL_ALIGNMENT_LEFT, 0, Art.INK, true)
	_sheet_title.clip_text = true
	var shut = UI.hit(_sheet_panel, Rect2(628, 30, 72, 72), _close_sheet)
	shut.extra = func(ci, sz): Paint.close_btn(ci, sz * 0.5, 26)
	_sheet_sc = Scroller.new()
	_sheet_sc.position = Vector2(0, 100)
	_sheet_sc.size = Vector2(720, 620)
	_sheet_panel.add_child(_sheet_sc)
	_sheet_root = _sheet_sc.content

func _sheet_height() -> float:
	if _sheet_kind == "chain":
		return 556.0
	var t = chains_page._chain_type(_sheet_ci)
	if t == "gen":
		return 680.0
	var extra = t in VALUED or t == "item"
	return 500.0 if extra else 420.0

func _apply_sheet_height(h: float) -> void:
	_sheet_panel.size.y = h
	_sheet_bg.size = Vector2(720, h)
	_sheet_bg.queue_redraw()
	_sheet_sc.position = Vector2(0, 108)
	_sheet_sc.size = Vector2(720, maxf(40.0, h - 124.0))

func _open_item(ci: int, ii: int) -> void:
	_open_sheet("item", ci, ii)

func _open_chain(ci: int) -> void:
	_open_sheet("chain", ci, -1)

func _open_sheet(kind: String, ci: int, ii: int) -> void:
	_sheet_kind = kind
	_sheet_ci = ci
	_sheet_ii = ii
	var h = _sheet_height()
	_apply_sheet_height(h)
	var was = _sheet_open
	_sheet_open = true
	_sheet.visible = true
	if not was:
		_sheet_sc.offset = 0.0
	_fill_sheet()
	var dest = 1340.0 - h
	if _sheet_tw != null and _sheet_tw.is_valid():
		_sheet_tw.kill()
	_sheet_tw = create_tween().set_parallel(true)
	if not was:
		_sheet_panel.position.y = 1340.0
		_dim.color.a = 0.0
	_sheet_tw.tween_property(_sheet_panel, "position:y", dest, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_sheet_tw.tween_property(_dim, "color:a", 0.45, 0.2)
	if not was:
		Sfx.play("whoosh")
	_rerender()

func _close_sheet() -> void:
	if not _sheet_open:
		return
	_sheet_open = false
	if _chooser != null:
		_chooser.shut()
	if _sheet_tw != null and _sheet_tw.is_valid():
		_sheet_tw.kill()
	_sheet_tw = create_tween().set_parallel(true)
	_sheet_tw.tween_property(_sheet_panel, "position:y", 1340.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_sheet_tw.tween_property(_dim, "color:a", 0.0, 0.18)
	_sheet_tw.chain().tween_callback(func():
		if not _sheet_open:
			_sheet.visible = false)
	_rerender()

func _hide_sheet() -> void:
	if _chooser != null:
		_chooser.shut()
	if _sheet == null:
		return
	_sheet_open = false
	if _sheet_tw != null and _sheet_tw.is_valid():
		_sheet_tw.kill()
	_sheet.visible = false
	_dim.color.a = 0.0
	_sheet_panel.position.y = 1340.0

func _fill_sheet() -> void:
	_wipe(_sheet_root)
	if _sheet_kind == "chain":
		chains_page._fill_chain()
	else:
		chains_page._fill_item()

func _shot_pick() -> void:
	_open_item(0, 2)
	_chooser.open("选择产物", chains_page._item_choices(), func(_id): pass)

func _refresh_on_blur(e: LineEdit) -> void:
	e.focus_exited.connect(func():
		if _block_refresh or not _sheet_open:
			return
		_rerender())

func _wipe(node: Node) -> void:
	_block_refresh = true
	while node.get_child_count() > 0:
		node.get_child(0).free()
	_block_refresh = false

func _h(parent: Node, text: String, x: float, y: float, w: float, fs: int) -> Label:
	return UI.lbl(parent, text, Rect2(x, y, w, 40), fs, Color("6b4a2a"), HORIZONTAL_ALIGNMENT_LEFT)

func _panel(parent: Node, r: Rect2) -> void:
	UI.box(parent, r, func(ci, sz):
		var b = Art.rrect(Rect2(Vector2(2, 4), sz - Vector2(4, 8)), 16, 5, 0.35)
		ci.draw_colored_polygon(b, Color("fff7e6"))
		Art.outline(ci, b, 2.5, Art.INK)
	, false)

func _card(parent: Node, r: Rect2, icon: String, title: String, cb: Callable) -> void:
	var b = UI.hit(parent, r, cb)
	b.extra = func(ci, sz):
		var box = Art.rrect(Rect2(Vector2(2, 4), sz - Vector2(4, 8)), 18, 8, 0.35)
		Art.dilate(ci, box, 3.0, Art.INK)
		ci.draw_colored_polygon(box, Color("fff7e6"))
		if icon != "":
			Paint.cfg_icon(ci, icon, Vector2(62, sz.y * 0.5), minf(100.0, sz.y * 0.7))
	UI.lbl(parent, title, Rect2(r.position.x + 118, r.position.y + (r.size.y - 48.0) * 0.5, r.size.x - 132, 48), 30, Art.INK, HORIZONTAL_ALIGNMENT_LEFT, 0, Art.INK, true)

func _icon(parent: Node, r: Rect2, id: String) -> void:
	UI.box(parent, r, func(ci, sz):
		var box = Art.rrect(Rect2(Vector2.ZERO, sz), 12, 3, 0.3)
		ci.draw_colored_polygon(box, Color("fff7e6"))
		Art.outline(ci, box, 2.0, Art.INK)
		if id != "":
			Art.item(ci, id, sz * 0.5, minf(sz.x, sz.y) * 0.82)
	, true)

func _slot(parent: Node, x: float, y: float, caption: String, id: String, cb: Callable) -> void:
	_cell(parent, Rect2(x, y, 150, 118), caption, id, cb)

func _cell(parent: Node, r: Rect2, caption: String, id: String, cb: Callable) -> void:
	var b = UI.hit(parent, r, cb)
	b.extra = func(ci, sz):
		var box = Art.rrect(Rect2(Vector2(0, 0), Vector2(sz.x, sz.y - 22)), 12, 4, 0.3)
		Art.dilate(ci, box, 2.5, Art.INK)
		ci.draw_colored_polygon(box, Color("fff7e6"))
		if id != "":
			Art.item(ci, id, Vector2(sz.x * 0.5, (sz.y - 22) * 0.5), minf(sz.x, sz.y - 22) * 0.78)
	UI.lbl(parent, caption, Rect2(r.position.x, r.position.y + r.size.y - 24, r.size.x, 24), 16, Color("6b4a2a"))

func _row_edit(parent: Node, y: float, title: String, text: String, cb: Callable) -> LineEdit:
	var lab = UI.lbl(parent, title, Rect2(24, y, 150, 56), 26, Color("6b4a2a"), HORIZONTAL_ALIGNMENT_LEFT)
	lab.clip_text = true
	return _line(parent, Rect2(180, y, 516, 56), text, cb)

func _row_step(parent: Node, y: float, title: String, value: int, lo: int, hi: int, apply: Callable) -> void:
	var lab = UI.lbl(parent, title, Rect2(24, y, 150, 56), 26, Color("6b4a2a"), HORIZONTAL_ALIGNMENT_LEFT)
	lab.clip_text = true
	_num_field(parent, Rect2(180, y, 240, 56), value, lo, hi, apply)

func _line(parent: Node, r: Rect2, text: String, cb: Callable) -> LineEdit:
	var back = UI.box(parent, r, func(ci, sz):
		var b = Art.rrect(Rect2(Vector2(1, 1), sz - Vector2(2, 2)), 12, 2, 0.15)
		ci.draw_colored_polygon(b, Color.WHITE)
		Art.outline(ci, b, 2.0, Color("c9a774"))
	, false)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var e = LineEdit.new()
	e.position = r.position
	e.size = r.size
	e.text = text
	e.caret_blink = true
	var fs = 26
	e.add_theme_font_size_override("font_size", fs)
	e.add_theme_constant_override("caret_width", maxi(2, int(round(float(fs) / 6.5))))
	e.add_theme_color_override("font_color", Art.INK)
	e.add_theme_color_override("caret_color", Art.INK)
	e.add_theme_color_override("font_placeholder_color", Color("a09080"))
	var empty = StyleBoxEmpty.new()
	empty.content_margin_left = 14
	empty.content_margin_right = 14
	empty.content_margin_top = 8
	empty.content_margin_bottom = 8
	e.add_theme_stylebox_override("normal", empty)
	e.add_theme_stylebox_override("focus", empty)
	e.add_theme_stylebox_override("read_only", empty)
	if G.font_body:
		e.add_theme_font_override("font", G.font_body)
	e.text_changed.connect(cb)
	parent.add_child(e)
	return e

func _stepper(parent: Node, x: float, y: float, label: String, value: int, lo: int, hi: int, apply: Callable) -> void:
	var bx = x
	if label != "":
		_h(parent, label, x, y, 110, 22)
		bx = x + 118
	_num_field(parent, Rect2(bx, y, 150, 48), value, lo, hi, apply)

func _ink_label(parent: Node, text: String, r: Rect2, fs: int, col: Color, ocol: Color, align: HorizontalAlignment) -> Label:
	var l = Label.new()
	l.text = text
	l.position = r.position
	l.size = r.size
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.clip_text = true
	var ls = LabelSettings.new()
	if G.font_body:
		ls.font = G.font_body
	ls.font_size = fs
	ls.font_color = col
	ls.outline_size = 4
	ls.outline_color = ocol
	l.label_settings = ls
	parent.add_child(l)
	return l

func _bare_line(parent: Node, r: Rect2, text: String, fs: int, align: HorizontalAlignment, cb: Callable) -> LineEdit:
	var e = LineEdit.new()
	e.position = r.position
	e.size = r.size
	e.text = text
	e.alignment = align
	e.caret_blink = true
	e.select_all_on_focus = true
	e.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	e.add_theme_font_size_override("font_size", fs)
	e.add_theme_constant_override("caret_width", maxi(2, int(round(float(fs) / 6.5))))
	var clear = Color(0, 0, 0, 0)
	e.add_theme_color_override("font_color", clear)
	e.add_theme_color_override("font_selected_color", clear)
	e.add_theme_color_override("font_placeholder_color", clear)
	e.add_theme_color_override("font_uneditable_color", clear)
	e.add_theme_color_override("caret_color", Art.INK)
	e.add_theme_color_override("selection_color", Color(0.92, 0.65, 0.24, 0.45))
	if G.font_body:
		e.add_theme_font_override("font", G.font_body)
	var empty = StyleBoxEmpty.new()
	e.add_theme_stylebox_override("normal", empty)
	e.add_theme_stylebox_override("focus", empty)
	e.add_theme_stylebox_override("read_only", empty)
	e.text_changed.connect(cb)
	parent.add_child(e)
	return e

func _bare_num(parent: Node, r: Rect2, value: int, lo: int, hi: int, fs: int, col: Color, ocol: Color, apply: Callable, fit_to: String = "") -> LineEdit:
	var shown = str(clampi(value, lo, hi))
	var lab = _ink_label(parent, shown, r, fs, col, ocol, HORIZONTAL_ALIGNMENT_CENTER)
	var edit: LineEdit
	edit = _bare_line(parent, r, shown, fs, HORIZONTAL_ALIGNMENT_CENTER, func(_t):
		_apply_num(edit, edit.text, lo, hi, apply)
		lab.text = edit.text)
	edit.focus_exited.connect(func():
		var n = lo
		if edit.text.is_valid_int():
			n = clampi(int(edit.text), lo, hi)
		if edit.text != str(n):
			edit.text = str(n)
		lab.text = str(n)
		apply.call(n)
		if fit_to != "" and str(n) != fit_to:
			_rerender())
	return edit

func _num_field(parent: Node, r: Rect2, value: int, lo: int, hi: int, apply: Callable) -> LineEdit:
	var edit: LineEdit
	edit = _line(parent, r, str(clampi(value, lo, hi)), func(t):
		_apply_num(edit, t, lo, hi, apply))
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	edit.focus_exited.connect(func():
		var n = lo
		if edit.text.is_valid_int():
			n = clampi(int(edit.text), lo, hi)
		if edit.text != str(n):
			edit.text = str(n)
		apply.call(n))
	return edit

func _apply_num(edit: LineEdit, t: String, lo: int, hi: int, apply: Callable) -> void:
	var digits = ""
	for ch in t:
		if ch >= "0" and ch <= "9":
			digits += ch
	if digits == "":
		if edit.text != "":
			edit.text = ""
		return
	var n = int(digits)
	if n > hi:
		digits = str(hi)
		n = hi
	if edit.text != digits:
		edit.text = digits
		edit.caret_column = digits.length()
		return
	if n < lo:
		return
	apply.call(n)

func _weights(parent: Node, y: float, title: String, arr: Array) -> float:
	_h(parent, title, 24, y, 200, 22)
	y += 32
	var x = 24.0
	for i in arr.size():
		var idx = i
		if x > 540:
			x = 24
			y += 56
		_num_field(parent, Rect2(x, y, 100, 46), int(arr[idx]), 0, 9999, func(n):
			arr[idx] = n
			_touch(Files.CHAINS))
		x += 112
	y += 52
	UI.btn(parent, Rect2(24, y, 72, 44), "+", "teal", func():
		arr.append(0)
		_touch(Files.CHAINS)
		_rerender()
	, 22).title_font = false
	if arr.size() > 1:
		UI.btn(parent, Rect2(108, y, 72, 44), "−", "grey", func():
			arr.pop_back()
			_touch(Files.CHAINS)
			_rerender()
		, 22).title_font = false
	return y + 56

func _opt(o: Dictionary, key: String, n: int) -> void:
	if n <= 0:
		o.erase(key)
	else:
		o[key] = n

func _swap(arr: Array, i: int, dir: int) -> void:
	var j = i + dir
	if j < 0 or j >= arr.size():
		return
	var tmp = arr[i]
	arr[i] = arr[j]
	arr[j] = tmp

func _save() -> void:
	if Cloud.enabled:
		G.main.toast("联网模式不能修改测试配置")
		return
	var path := _page_path(str(_cur()["page"]))
	if path == "": return
	var paths: Array = [path]
	if path == Files.CHAINS and _dirty.has(Files.LINES): paths.append(Files.LINES)
	if path in [Files.BOARD, Files.RULES]:
		board_page._fit_board()
		if _dirty.has(Files.BOARD) and not paths.has(Files.BOARD): paths.append(Files.BOARD)
		var saved_rules: Dictionary = Files.shared(Files.RULES)
		var edited_rules: Dictionary = _pages[Files.RULES]
		if int(saved_rules["cols"]) != int(edited_rules["cols"]) or int(saved_rules["rows"]) != int(edited_rules["rows"]):
			if not paths.has(Files.RULES): paths.append(Files.RULES)
	var changes := {}
	for candidate in paths:
		if _dirty.has(candidate): changes[str(candidate)] = _pages[candidate]
	if changes.is_empty():
		G.main.toast("没有要保存的修改")
		return
	if not Files.validate(changes):
		G.main.toast(str(Files.last_errors[0]))
		return
	var originals := Files.capture_files(changes.keys())
	if originals.size() != changes.size():
		G.main.toast("无法备份配置，未保存修改")
		return
	G.main.prepare_session_restart()
	var error := Files.write_batch(changes)
	var refreshed := error == OK and Data.refresh()
	var restarted := refreshed and Replay.restart_local_rules()
	if not restarted:
		var restored := Files.restore_files(originals) and Data.refresh()
		var usable := restored and Replay.restore_rules_edit_authorization()
		if not usable: Replay.authorized = false
		G.main.reset_session_views()
		G.main.toast("保存失败，已恢复原配置" if usable else "配置恢复失败，请重新打开工程")
		return
	for candidate in changes: _dirty.erase(candidate)
	G.main.reset_session_views()
	_refresh_save()
	G.main.toast("配置已保存，测试局已重新开始")
