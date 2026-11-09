class_name PickSheet
extends Control
## 屏幕中间的通用选择弹窗。
## 每条是 {id, name, icon, group, tab}。
## 有 tab 时，顶部按 tab 切页，同一页里 group 相同的排在一个小标题下。
## 没有 tab 就整表平铺，group 相同的仍排在一个小标题下。
## pin 为真的条目钉在每一页最前面，不跟切页走。
## 点一个方格会关上弹窗，并调用打开时传入的回调，参数是这条的 id。
## current 不是 null 时，打开后切到那一条所在的页，滚到它并描上选中框。空字符串表示当前是「空」。

var _title: Label
var _search: LineEdit
var _search_box: DrawBox
var _tabs: Scroller
var _sc: Scroller
var _root: Control
var _panel: Control
var _dim: ColorRect
var _tw: Tween
var _entries: Array = []
var _cb: Callable
var _tab := ""
var _current := ""
var _mark := false
var _pending_jump := false
var _shown := false

func _ready() -> void:
	visible = false
	z_index = 8
	position = Vector2.ZERO
	size = Vector2(720, 1480)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim = ColorRect.new()
	_dim.color = Color(0.08, 0.04, 0.02, 0.0)
	_dim.size = size
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			close())
	add_child(_dim)
	_panel = Control.new()
	_panel.position = Vector2(40, 170)
	_panel.size = Vector2(640, 1140)
	_panel.pivot_offset = _panel.size * 0.5
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	UI.box(_panel, Rect2(Vector2.ZERO, _panel.size), func(ci, sz):
		Sprites.draw(ci, "pop_sheet", Rect2(Vector2.ZERO, sz))
	, false)
	_title = UI.lbl(_panel, "", Rect2(24, 28, 500, 52), 32, Art.INK, HORIZONTAL_ALIGNMENT_LEFT, 0, Art.INK, true)
	_title.clip_text = true
	var shut := UI.hit(_panel, Rect2(552, 16, 72, 72), close)
	shut.extra = func(ci, sz): Paint.close_btn(ci, sz * 0.5, 26)
	_tabs = Scroller.new()
	_tabs.horizontal = true
	_tabs.position = Vector2(16, 84)
	_tabs.size = Vector2(608, 72)
	_tabs.visible = false
	_panel.add_child(_tabs)
	_search_box = UI.box(_panel, Rect2(24, 96, 592, 56), func(ci, sz):
		Sprites.draw(ci, "pop_field", Rect2(Vector2(1, 1), sz - Vector2(2, 2)))
	, false)
	_search = LineEdit.new()
	_search.position = Vector2(24, 96)
	_search.size = Vector2(592, 56)
	_search.placeholder_text = "搜索名字或 id"
	_search.caret_blink = true
	var fs := 26
	_search.add_theme_font_size_override("font_size", fs)
	_search.add_theme_constant_override("caret_width", maxi(2, int(round(float(fs) / 6.5))))
	_search.add_theme_color_override("font_color", Art.INK)
	_search.add_theme_color_override("caret_color", Art.INK)
	_search.add_theme_color_override("font_placeholder_color", Color("a09080"))
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = 16
	empty.content_margin_right = 16
	empty.content_margin_top = 8
	empty.content_margin_bottom = 8
	_search.add_theme_stylebox_override("normal", empty)
	_search.add_theme_stylebox_override("focus", empty)
	if G.font_body:
		_search.add_theme_font_override("font", G.font_body)
	_search.text_changed.connect(func(_t): _fill())
	_panel.add_child(_search)
	_sc = Scroller.new()
	_sc.position = Vector2(0, 168)
	_sc.size = Vector2(640, 948)
	_panel.add_child(_sc)
	_root = _sc.content

func is_open() -> bool:
	return _shown

func open(title: String, entries: Array, cb: Callable, current = null) -> void:
	_entries = entries
	_cb = cb
	_mark = current != null
	_current = str(current) if _mark else ""
	_pending_jump = _mark
	_tab = _tab_of(_current) if _mark else ""
	_title.text = title
	_search.set_block_signals(true)
	_search.text = ""
	_search.set_block_signals(false)
	_tabs.jump_to(0.0)
	_sc.jump_to(0.0)
	_fill()
	_shown = true
	visible = true
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_panel.scale = Vector2(0.86, 0.86)
	_panel.modulate.a = 0.0
	_dim.color.a = 0.0
	_tw = create_tween().set_parallel(true)
	_tw.tween_property(_panel, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw.tween_property(_panel, "modulate:a", 1.0, 0.16)
	_tw.tween_property(_dim, "color:a", 0.45, 0.2)
	Sfx.play("whoosh")

func close() -> void:
	if not _shown:
		return
	_shown = false
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween().set_parallel(true)
	_tw.tween_property(_panel, "scale", Vector2(0.9, 0.9), 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tw.tween_property(_panel, "modulate:a", 0.0, 0.16)
	_tw.tween_property(_dim, "color:a", 0.0, 0.16)
	_tw.chain().tween_callback(func():
		if not _shown:
			visible = false)

func shut() -> void:
	_shown = false
	if _tw != null and _tw.is_valid():
		_tw.kill()
	visible = false
	_dim.color.a = 0.0
	_panel.scale = Vector2.ONE
	_panel.modulate.a = 1.0

func _tab_names() -> Array:
	var order: Array = []
	var seen := {}
	for e in _entries:
		if not (e is Dictionary) or not e.has("tab"):
			continue
		var t := str(e.get("tab", ""))
		if t == "":
			t = "其他"
		if seen.has(t):
			continue
		seen[t] = true
		order.append(t)
	return order

func _place(has_tabs: bool) -> void:
	_tabs.visible = has_tabs
	var search_y := 168.0 if has_tabs else 96.0
	var list_y := 236.0 if has_tabs else 168.0
	_search_box.position = Vector2(24, search_y)
	_search.position = Vector2(24, search_y)
	_sc.position = Vector2(0, list_y)
	_sc.size = Vector2(640, 1140.0 - list_y - 20.0)

func _tab_of(id: String) -> String:
	for e in _entries:
		if not (e is Dictionary) or str(e.get("id", "")) != id:
			continue
		if bool(e.get("pin", false)) or not e.has("tab"):
			return ""
		var t := str(e.get("tab", ""))
		return "其他" if t == "" else t
	return ""

func _pick_tab(name: String) -> void:
	if _tab == name:
		return
	_tab = name
	_sc.jump_to(0.0)
	call_deferred("_fill")

func _paint_tabs(names: Array) -> void:
	var keep := _tabs.offset
	for c in _tabs.content.get_children():
		c.free()
	var x := 8.0
	var sel_x := 0.0
	var sel_w := 0.0
	for n in names:
		var w := _tab_chip(x, str(n), str(n) == _tab)
		if str(n) == _tab:
			sel_x = x
			sel_w = w
		x += w + 8.0
	_tabs.set_length(x + 8.0)
	var view := _tabs.size.x
	if sel_w > 0.0 and (sel_x < keep or sel_x + sel_w > keep + view - 8.0):
		_tabs.jump_to(sel_x + sel_w * 0.5 - view * 0.5)
	else:
		_tabs.jump_to(keep)

func _tab_chip(x: float, text: String, on: bool) -> float:
	var f: Font = G.font_body
	var w := 96.0
	if f != null:
		w = maxf(96.0, f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 40.0)
	var b := UI.btn(_tabs.content, Rect2(x, 6, w, 52), text, "teal" if on else "grey", func():
		_pick_tab(text)
	, 22)
	b.title_font = false
	return w

func _fill() -> void:
	for c in _root.get_children():
		c.free()
	var tabs := _tab_names()
	var has_tabs := not tabs.is_empty()
	_place(has_tabs)
	if has_tabs:
		if _tab == "" or not tabs.has(_tab):
			_tab = str(tabs[0])
		_paint_tabs(tabs)
	else:
		_tab = ""
		for c in _tabs.content.get_children():
			c.free()
	var q := _search.text.strip_edges().to_lower()
	var order: Array = []
	var grouped := {}
	var pins: Array = []
	for e in _entries:
		if not (e is Dictionary):
			continue
		var name := str(e.get("name", ""))
		var id := str(e.get("id", ""))
		if q != "" and not name.to_lower().contains(q) and not id.to_lower().contains(q):
			continue
		if bool(e.get("pin", false)):
			pins.append(e)
			continue
		if has_tabs:
			var tab := str(e.get("tab", ""))
			if tab == "":
				tab = "其他"
			if tab != _tab:
				continue
		var g := str(e.get("group", ""))
		if not grouped.has(g):
			grouped[g] = []
			order.append(g)
		grouped[g].append(e)
	if not pins.is_empty():
		var rest: Array = grouped.get("", [])
		pins.append_array(rest)
		grouped[""] = pins
		order.erase("")
		order.insert(0, "")
	var y := 8.0
	var jump_y := -1.0
	if order.is_empty():
		UI.lbl(_root, "没有这个物品", Rect2(24, y, 592, 40), 24, Color("6b4a2a"), HORIZONTAL_ALIGNMENT_LEFT)
		_sc.set_length(80)
		_settle_jump(-1.0, 0.0)
		return
	var sq := 124.0
	var cols := 4
	var pitch := 148.0
	var left := 28.0
	var cell_h := sq + 36.0
	for g in order:
		if str(g) != "":
			var head := UI.lbl(_root, str(g), Rect2(left, y, 584, 36), 26, Art.INK, HORIZONTAL_ALIGNMENT_LEFT, 0, Art.INK, true)
			head.clip_text = true
			y += 40
		var list: Array = grouped[g]
		for i in list.size():
			var e: Dictionary = list[i]
			var col := i % cols
			var row := int(i / cols)
			var x := left + float(col) * pitch
			var yy := y + float(row) * (sq + 44.0)
			var pick_id := str(e.get("id", ""))
			var icon := str(e.get("icon", pick_id))
			var nm := str(e.get("name", pick_id))
			var on := _mark and pick_id == _current
			if on and jump_y < 0.0:
				jump_y = yy
			_choice(Rect2(x, yy, sq, cell_h), pick_id, icon, nm, on)
		var rows := int((list.size() + cols - 1) / cols)
		y += float(rows) * (sq + 44.0) + 8.0
	_sc.set_length(y + 24)
	_settle_jump(jump_y, cell_h)

func _settle_jump(jump_y: float, cell_h: float) -> void:
	if not _pending_jump:
		return
	_pending_jump = false
	if jump_y < 0.0:
		_sc.jump_to(0.0)
		return
	_sc.jump_to(jump_y + cell_h * 0.5 - _sc.size.y * 0.5)

func _choice(r: Rect2, pick_id: String, icon: String, nm: String, on: bool) -> void:
	var b := UI.hit(_root, r, func():
		var cb := _cb
		close()
		if cb.is_valid():
			cb.call(pick_id))
	b.extra = func(ci, sz):
		var side: float = sz.x
		Sprites.draw(ci, "pop_choice_on" if on else "pop_choice_off", Rect2(Vector2(4, 6), Vector2(side - 8, side - 12)))
		if icon != "":
			Art.item(ci, icon, Vector2(side * 0.5, side * 0.46), side * 0.66)
	var cap := UI.lbl(_root, nm, Rect2(r.position.x, r.position.y + r.size.x - 4, r.size.x, 32), 16, Art.MOSS_D if on else Color("6b4a2a"))
	cap.clip_text = true
