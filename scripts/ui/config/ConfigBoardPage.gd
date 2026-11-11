class_name ConfigBoardPage
extends RefCounted
## board configuration page and its editing actions.
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

func _set_cell(id: String, i: int) -> void:
	if Data.is_numeric_resource(id):
		G.main.toast("声望和祭典积分是数值奖励，不能放到棋盘上")
		return
	var cells: Array = editor._pages[Files.BOARD]["cells"]
	while cells.size() <= i:
		cells.append("")
	cells[i] = id
	editor._touch(Files.BOARD)

func _board_item(i: int) -> String:
	var cells: Array = editor._pages[Files.BOARD].get("cells", [])
	if i < 0 or i >= cells.size():
		return ""
	return str(cells[i])

func _board_span() -> Vector2i:
	var rules: Dictionary = editor._pages[Files.RULES]
	return Vector2i(maxi(1, int(rules.get("cols", 7))), maxi(1, int(rules.get("rows", 9))))

func _board_locks() -> Array:
	var locks = editor._pages[Files.BOARD].get("locks", [])
	return locks if locks is Array else []

func _board_lock(n: int) -> int:
	var span = _board_span()
	return Layout.lock_of(_board_locks(), n, n % span.x, int(n / span.x), span.x, span.y)

func _paint_lock(n: int, lock: int) -> bool:
	var span = _board_span()
	if n < 0 or n >= span.x * span.y:
		return false
	lock = clampi(lock, 0, 2)
	var board: Dictionary = editor._pages[Files.BOARD]
	var locks = _board_locks()
	if Layout.lock_of(locks, n, n % span.x, int(n / span.x), span.x, span.y) == lock:
		return false
	if not (board.get("locks") is Array):
		board["locks"] = []
	locks = board["locks"]
	Layout.ensure(locks, n, span.x, span.y)
	locks[n] = lock
	editor._touch(Files.BOARD)
	return true

func _board_reward(n: int) -> Array:
	return Layout.reward_of(editor._pages[Files.BOARD].get("rewards", {}), n)

func _reward_dict() -> Dictionary:
	var board: Dictionary = editor._pages[Files.BOARD]
	if not (board.get("rewards") is Dictionary):
		board["rewards"] = {}
	return board["rewards"]

func _set_reward_item(id: String, i: int) -> void:
	var rewards = _reward_dict()
	var key = str(i)
	if id == "":
		rewards.erase(key)
		editor._touch(Files.BOARD)
		return
	var count = 1
	var prev = Layout.reward_of(rewards, i)
	if not prev.is_empty():
		count = int(prev[1])
	elif Data.CHAINS.has(Data.chain(id)) and Data.type_of(id) in VALUED:
		count = maxi(1, Data.value_of(id))
	rewards[key] = [id, count]
	editor._touch(Files.BOARD)

func _set_reward_count(n: int, i: int) -> void:
	var prev = _board_reward(i)
	if prev.is_empty() or int(prev[1]) == n:
		return
	_reward_dict()[str(i)] = [str(prev[0]), n]
	editor._touch(Files.BOARD)

func _swap_reward(a: int, b: int) -> bool:
	if a < 0 or b < 0 or a == b:
		return false
	var rewards = _reward_dict()
	var ra = Layout.reward_of(rewards, a)
	var rb = Layout.reward_of(rewards, b)
	if ra.is_empty() and rb.is_empty():
		return false
	if not ra.is_empty() and not rb.is_empty() and str(ra[0]) == str(rb[0]) and int(ra[1]) == int(rb[1]):
		return false
	var ka = str(a)
	var kb = str(b)
	if ra.is_empty():
		rewards.erase(kb)
	else:
		rewards[kb] = [str(ra[0]), int(ra[1])]
	if rb.is_empty():
		rewards.erase(ka)
	else:
		rewards[ka] = [str(rb[0]), int(rb[1])]
	editor._touch(Files.BOARD)
	return true

# ---------------------------------------------------------------- 页

func _board() -> float:
	var span = _board_span()
	var cols = span.x
	var rows = span.y
	var y = 12.0
	var modes = [["item", "编辑物品"], ["lock", "编辑解锁"], ["reward", "编辑奖励"]]
	var bw = 216.0
	var bgap = 12.0
	var bx = (720.0 - bw * 3.0 - bgap * 2.0) * 0.5
	for i in modes.size():
		var mode_id: String = modes[i][0]
		var on = editor._board_mode == mode_id
		var b = UI.btn(editor._root, Rect2(bx + float(i) * (bw + bgap), y, bw, 56), modes[i][1], "green" if on else "grey", _pick_board_mode.bind(mode_id), 22)
		b.title_font = false
	y += 68.0
	if editor._board_mode == "item":
		editor._h(editor._root, "点格子换物品，按住拖到另一格交换。锁和奖励留在格子上。", 24, y, 680, 20)
		y += 40.0
	elif editor._board_mode == "lock":
		editor._h(editor._root, "点格子切换：开放、藤蔓、巨石。", 24, y, 680, 20)
		y += 40.0
	else:
		editor._h(editor._root, "点底部白框改数量。点气泡换奖励，按住拖到另一格。", 24, y, 680, 20)
		y += 32.0
		editor._h(editor._root, "体力、不拿拿、琥珀飞到顶栏，其他物品飞进暂存。", 24, y, 680, 20)
		y += 40.0
	var gap = 6.0
	var cw = minf(92.0, (688.0 - gap * float(cols - 1)) / float(cols))
	var ch = cw
	var x0 = (720.0 - (cw + gap) * float(cols) + gap) * 0.5
	var pad = BoardPad.new()
	pad.edit = self
	pad.cols = cols
	pad.rows = rows
	pad.cw = cw
	pad.ch = ch
	pad.gap = gap
	pad.x0 = x0
	pad.mode = editor._board_mode
	pad.position = Vector2(0, y)
	pad.size = Vector2(720, rows * (ch + gap))
	editor._root.add_child(pad)
	if editor._board_mode == "reward":
		_place_reward_counts(pad.position, cols, rows, cw, gap, x0)
	return y + rows * (ch + gap) + 24.0

func _place_reward_counts(origin: Vector2, cols: int, rows: int, cw: float, gap: float, x0: float) -> void:
	var step = cw + gap
	for row in rows:
		for col in cols:
			var n = row * cols + col
			var rw = _board_reward(n)
			if rw.is_empty():
				continue
			var cell = Rect2(origin.x + x0 + float(col) * step, origin.y + float(row) * step, cw, cw)
			var fh = 30.0
			var box = Rect2(cell.position.x + 5.0, cell.end.y - fh - 4.0, cell.size.x - 10.0, fh)
			_reward_count_box(box, int(rw[1]), n)

func _reward_count_box(r: Rect2, value: int, cell: int) -> void:
	var back = UI.box(editor._root, r, func(ci, sz):
		var b = Art.rrect(Rect2(Vector2(1, 1), sz - Vector2(2, 2)), 8, 2, 0.12)
		ci.draw_colored_polygon(b, Color.WHITE)
		Art.outline(ci, b, 2.0, Color("c9a774"))
	, false)
	back.z_index = 1
	back.set_meta("reward_cell", cell)
	var shown = str(clampi(value, 1, 9999))
	var e = LineEdit.new()
	e.position = r.position
	e.size = r.size
	e.text = shown
	e.alignment = HORIZONTAL_ALIGNMENT_CENTER
	e.caret_blink = true
	e.select_all_on_focus = true
	e.editable = true
	e.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	e.mouse_filter = Control.MOUSE_FILTER_STOP
	e.mouse_default_cursor_shape = Control.CURSOR_IBEAM
	e.z_index = 2
	e.focus_mode = Control.FOCUS_ALL
	e.add_theme_font_size_override("font_size", 20)
	e.add_theme_constant_override("caret_width", 2)
	e.add_theme_color_override("font_color", Art.INK)
	e.add_theme_color_override("font_selected_color", Art.INK)
	e.add_theme_color_override("caret_color", Art.INK)
	e.add_theme_color_override("selection_color", Color(0.92, 0.65, 0.24, 0.45))
	if G.font_body:
		e.add_theme_font_override("font", G.font_body)
	var empty = StyleBoxEmpty.new()
	e.add_theme_stylebox_override("normal", empty)
	e.add_theme_stylebox_override("focus", empty)
	e.add_theme_stylebox_override("read_only", empty)
	e.set_meta("reward_cell", cell)
	var ii = cell
	e.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			editor._sc.yield_gesture())
	e.text_changed.connect(func(_t):
		editor._apply_num(e, e.text, 1, 9999, func(v): _set_reward_count(v, ii)))
	e.focus_exited.connect(func():
		var v = 1
		if e.text.is_valid_int():
			v = clampi(int(e.text), 1, 9999)
		if e.text != str(v):
			e.text = str(v)
		_set_reward_count(v, ii))
	editor._root.add_child(e)

func _pick_board_mode(mode_id: String) -> void:
	if editor._board_mode == mode_id:
		return
	editor._board_mode = mode_id
	editor._rerender()

func _swap_board(a: int, b: int) -> bool:
	if a < 0 or b < 0 or a == b:
		return false
	var cells: Array = editor._pages[Files.BOARD]["cells"]
	var need = maxi(a, b) + 1
	while cells.size() < need:
		cells.append("")
	if str(cells[a]) == str(cells[b]):
		return false
	var tmp = cells[a]
	cells[a] = cells[b]
	cells[b] = tmp
	editor._touch(Files.BOARD)
	return true

func _fit_board() -> void:
	var rules: Dictionary = editor._pages[Files.RULES]
	var need = maxi(1, int(rules.get("cols", 7))) * maxi(1, int(rules.get("rows", 9)))
	var board: Dictionary = editor._pages[Files.BOARD]
	var cells: Array = board.get("cells", [])
	var before = cells.duplicate()
	while cells.size() < need:
		cells.append("")
	if cells.size() > need:
		board["cells"] = cells.slice(0, need)
		cells = board["cells"]
	if str(cells) != str(before):
		editor._dirty[Files.BOARD] = true
	var span = _board_span()
	if Layout.normalize(board, span.x, span.y):
		editor._dirty[Files.BOARD] = true
	if Layout.normalize_rewards(board, span.x, span.y):
		editor._dirty[Files.BOARD] = true

class BoardPad extends Control:
	const LIFT := Vector2(0, -14)

	var edit: ConfigBoardPage
	var cols := 7
	var rows := 9
	var cw := 92.0
	var ch := 0.0
	var gap := 6.0
	var x0 := 16.0
	var press_cell := -1
	var press_pos := Vector2.ZERO
	var dragging := false
	var drag_from := -1
	var drag_pos := Vector2.ZERO
	var drag_vis := Vector2.ZERO
	var hover := -1
	var mode := "item"

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_STOP
		mouse_default_cursor_shape = CURSOR_POINTING_HAND
		G.boil_tick.connect(queue_redraw)

	func _process(delta: float) -> void:
		if not dragging:
			return
		drag_vis = drag_pos
		queue_redraw()

	func _gui_input(e: InputEvent) -> void:
		if mode == "lock":
			_lock_input(e)
			return
		if mode == "reward":
			_reward_input(e)
			return
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				press_cell = _cell_at(e.position)
				press_pos = e.position
				dragging = false
				drag_from = -1
				hover = -1
				if press_cell >= 0:
					edit.editor._sc.yield_gesture()
				accept_event()
			else:
				if dragging:
					_drop(_cell_at(e.position))
				elif press_cell >= 0 and _cell_at(e.position) == press_cell:
					Sfx.play("tap")
					edit.editor._open_pick("item", edit._set_cell.bind(press_cell), true, edit._board_item(press_cell))
				press_cell = -1
				dragging = false
				drag_from = -1
				hover = -1
				mouse_default_cursor_shape = CURSOR_POINTING_HAND
				queue_redraw()
				accept_event()
		elif e is InputEventMouseMotion and press_cell >= 0:
			if not dragging and e.position.distance_to(press_pos) > 10.0:
				dragging = true
				drag_from = press_cell
				drag_pos = e.position
				drag_vis = e.position
				hover = _cell_at(e.position)
				mouse_default_cursor_shape = CURSOR_DRAG
				Sfx.play("tap", 1.3)
			if dragging:
				drag_pos = e.position
				var next := _cell_at(e.position)
				if next != hover:
					hover = next
					queue_redraw()
			accept_event()

	func _reward_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				press_cell = _cell_at(e.position)
				press_pos = e.position
				dragging = false
				drag_from = -1
				hover = press_cell
				if press_cell >= 0:
					edit.editor._sc.yield_gesture()
			else:
				if dragging:
					_drop_reward(_cell_at(e.position))
				elif press_cell >= 0 and _cell_at(e.position) == press_cell:
					var cur := ""
					var rw := edit._board_reward(press_cell)
					if not rw.is_empty():
						cur = str(rw[0])
					var at := press_cell
					Sfx.play("tap")
					edit.editor._open_pick("reward", edit._set_reward_item.bind(at), true, cur)
				press_cell = -1
				dragging = false
				drag_from = -1
				hover = -1
				mouse_default_cursor_shape = CURSOR_POINTING_HAND
				queue_redraw()
			accept_event()
		elif e is InputEventMouseMotion and press_cell >= 0:
			if not dragging and e.position.distance_to(press_pos) > 10.0 and not edit._board_reward(press_cell).is_empty():
				dragging = true
				drag_from = press_cell
				drag_pos = e.position
				drag_vis = e.position
				hover = _cell_at(e.position)
				mouse_default_cursor_shape = CURSOR_DRAG
				_reward_nums(press_cell, false)
				Sfx.play("tap", 1.3)
			if dragging:
				drag_pos = e.position
				var next := _cell_at(e.position)
				if next != hover:
					hover = next
					queue_redraw()
			elif _cell_at(e.position) != hover:
				hover = _cell_at(e.position)
				queue_redraw()
			accept_event()

	func _reward_nums(cell: int, show: bool) -> void:
		for c in edit.editor._root.get_children():
			if c.has_meta("reward_cell") and int(c.get_meta("reward_cell")) == cell:
				c.visible = show

	func _drop_reward(to: int) -> void:
		var from := drag_from
		if from >= 0 and to >= 0 and from != to and edit._swap_reward(from, to):
			Sfx.play("pop", 0.9)
			edit.editor._rerender()
			return
		_reward_nums(from, true)

	func _lock_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				var n := _cell_at(e.position)
				hover = n
				if n >= 0:
					edit.editor._sc.yield_gesture()
					if edit._paint_lock(n, (edit._board_lock(n) + 1) % 3):
						Sfx.play("tap", 1.2)
			else:
				hover = _cell_at(e.position)
			queue_redraw()
			accept_event()
		elif e is InputEventMouseMotion:
			var n := _cell_at(e.position)
			if n != hover:
				hover = n
				queue_redraw()
			accept_event()

	func _drop(to: int) -> void:
		var from := drag_from
		if from >= 0 and to >= 0 and from != to and edit._swap_board(from, to):
			Sfx.play("pop", 0.9)

	func _rect(col: int, row: int) -> Rect2:
		var step_y := (ch if ch > cw else cw) + gap
		return Rect2(x0 + col * (cw + gap), row * step_y, cw, cw)

	func _cell_at(p: Vector2) -> int:
		if p.x < 0.0 or p.y < 0.0:
			return -1
		var step := cw + gap
		var col := int((p.x - x0) / step)
		var row := int(p.y / step)
		if col < 0 or row < 0 or col >= cols or row >= rows:
			return -1
		if not _rect(col, row).has_point(p):
			return -1
		return row * cols + col

	func _icon_center(n: int) -> Vector2:
		var r := _rect(n % cols, int(n / cols))
		return r.position + r.size * 0.5

	func _id_at(n: int) -> String:
		var cells: Array = edit.editor._pages[ConfigBoardPage.Files.BOARD]["cells"]
		if n < 0 or n >= cells.size():
			return ""
		return str(cells[n])

	const CHAIN_COLOR := {
		"basket": Color("1f8f84"), "fruit": Color("d23b45"), "seed": Color("c9922a"),
		"anvil": Color("3e5166"), "tool": Color("3a78d0"), "gem": Color("7b45c4"),
		"loom": Color("a6844a"), "cloth": Color("d45a8c"), "armor": Color("8d4a22"),
		"trap": Color("6a8a28"), "beast": Color("e07058"), "bird": Color("3aa0c4"),
		"hearth": Color("e25822"), "veg": Color("c6a820"), "roast": Color("b85a28"),
		"carve": Color("b97a3f"), "furn": Color("d4896a"), "craft": Color("e0a020"),
		"kiln": Color("a33b32"), "pot": Color("c46a48"), "ware": Color("e090a8"),
		"fire": Color("ff7b22"), "shell": Color("e8b090"), "amber": Color("f39a1f"),
		"chest": Color("8a5a2b"), "pack": Color("7a4a86"), "token": Color("9a3050"),
		"xp": Color("3a7eae"),
	}

	func _chain_def(cid: String) -> Dictionary:
		for c in edit.editor._pages[ConfigBoardPage.Files.CHAINS]:
			if c is Dictionary and str(c.get("id", "")) == cid:
				return c
		return Data.CHAINS.get(cid, {})

	func _level_wash(id: String) -> Color:
		var ch := Data.chain(id)
		var lv := maxi(1, Data.lv(id))
		var def := _chain_def(ch)
		var items = def.get("items", [])
		var maxlv := lv
		if items is Array and not items.is_empty():
			maxlv = maxi(items.size(), lv)
		var span := maxi(1, maxlv - 1)
		var t := clampf(float(lv - 1) / float(span), 0.0, 1.0)
		var col := _chain_color(ch)
		col.a = lerpf(0.22, 1.0, t)
		return col

	func _chain_color(ch: String) -> Color:
		if CHAIN_COLOR.has(ch):
			return CHAIN_COLOR[ch]
		return Color.from_hsv(float(absi(ch.hash()) % 360) / 360.0, 0.55, 0.75)

	## 左上角白字描墨边，和物品链方格上的等级数字同一套。
	func _draw_lv(origin: Vector2, side: float, id: String) -> void:
		var lv := Data.lv(id)
		if lv <= 0:
			return
		var f: Font = G.font_title
		var fs := int(clampf(round(side * 0.30), 14.0, 22.0))
		var mark := str(lv)
		var pos := origin + Vector2(side * 0.06, float(fs) + 2.0)
		draw_string_outline(f, pos, mark, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(4, fs / 5), Art.INK)
		draw_string(f, pos, mark, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)

	func _draw_lock(r: Rect2, n: int, lock: int) -> void:
		if lock == 0:
			_mark(r, "开")
			return
		var inset := Rect2(r.position, r.size).grow(-4)
		var plate := Art.rrect(inset, 10, n, 0.2)
		if lock == 2:
			draw_colored_polygon(plate, Color(0.42, 0.39, 0.34, 0.55))
			Art.outline(self, plate, 3.5, Color("5c564c"))
			_mark(r, "石")
		else:
			draw_colored_polygon(plate, Color(0.25, 0.45, 0.16, 0.34))
			_vines(r, n)
			Art.outline(self, plate, 3.5, Art.LEAF_D)
			_mark(r, "蔓")

	func _vines(r: Rect2, i: int) -> void:
		var s := r.size.x / 96.0
		var p := r.position
		var a := p + Vector2(4, 30) * s
		var b := p + Vector2(30, 46) * s
		var c := p + Vector2(56, 34) * s
		var d := p + Vector2(90, 52) * s
		Art.pl(self, [a, b, c, d], maxf(3.0, 5.0 * s), Art.INK, i)
		Art.pl(self, [a, b, c, d], maxf(2.0, 3.0 * s), Art.LEAF_D, i)
		var e := p + Vector2(10, 88) * s
		var f2 := p + Vector2(34, 64) * s
		var g := p + Vector2(64, 74) * s
		var h := p + Vector2(86, 8) * s
		Art.pl(self, [e, f2, g, h], maxf(3.0, 5.0 * s), Art.INK, i + 3)
		Art.pl(self, [e, f2, g, h], maxf(2.0, 3.0 * s), Art.LEAF_D, i + 3)

	func _mark(r: Rect2, text: String, at_top: bool = false) -> void:
		var f: Font = G.font_title
		if f == null:
			return
		var fs := int(clampf(round(r.size.x * 0.26), 13.0, 20.0))
		var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos := Vector2(r.end.x - tw - r.size.x * 0.08, r.position.y + float(fs) + 2.0 if at_top else r.end.y - 6.0)
		draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(3, fs / 5), Art.INK)
		draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)

	func _draw() -> void:
		for row in rows:
			for col in cols:
				var n: int = row * cols + col
				var id := _id_at(n)
				var r := _rect(col, row)
				var box := Art.rrect(Rect2(r.position, r.size), 12, 4, 0.3)
				Art.dilate(self, box, 2.5, Art.INK)
				var fill := Color("e4d2b0") if dragging and n == drag_from else Color("fff7e6")
				draw_colored_polygon(box, fill)
				if id != "" and mode != "reward":
					var wash := _level_wash(id)
					if dragging and n == drag_from:
						wash.a *= 0.4
					draw_colored_polygon(box, wash)
				if dragging and hover == n and n != drag_from:
					draw_colored_polygon(Art.rrect(Rect2(r.position, r.size).grow(-3), 10, n, 0.0), Color(1, 0.82, 0.25, 0.35))
				if id != "" and mode != "reward" and not (dragging and n == drag_from):
					var side := minf(r.size.x, r.size.y)
					Art.item(self, id, r.position + r.size * 0.5, side * 0.78)
					_draw_lv(r.position, side, id)
				if mode == "lock":
					_draw_lock(r, n, edit._board_lock(n))
				var rw := edit._board_reward(n)
				var side0 := minf(r.size.x, r.size.y)
				if mode == "reward":
					_mark(r, ["开", "蔓", "石"][edit._board_lock(n)], true)
					var bob := sin(float(Time.get_ticks_msec()) / 280.0 + float(n)) * 2.0
					if not rw.is_empty() and not (dragging and n == drag_from):
						Paint.reward_bubble(self, r.position + Vector2(side0 * 0.5, side0 * 0.30), side0 * 0.24, str(rw[0]), 1, n, bob)
					elif hover == n and not dragging:
						Paint.reward_bubble(self, r.position + Vector2(side0 * 0.55, side0 * 0.42), side0 * 0.26, "", 0, n, bob)
				elif not rw.is_empty() and not (dragging and n == drag_from):
					Paint.reward_bubble(self, r.position + Vector2(side0 * 0.78, side0 * 0.26), side0 * 0.2, str(rw[0]), int(rw[1]), n, 0.0)
				if dragging and hover == n and n != drag_from:
					Art.outline(self, Art.rrect(Rect2(r.position, r.size).grow(-4), 10, n, 0.0), 3.5, Color("c47a12"))
				elif (mode == "lock" or mode == "reward") and hover == n:
					Art.outline(self, Art.rrect(Rect2(r.position, r.size).grow(-4), 10, n, 0.0), 3.5, Color("c47a12"))
		if dragging and drag_from >= 0 and mode == "reward":
			var rw := edit._board_reward(drag_from)
			if not rw.is_empty():
				Paint.reward_bubble(self, drag_vis + LIFT, cw * 0.36, str(rw[0]), int(rw[1]), drag_from, 0.0)
		elif dragging and drag_from >= 0:
			var gid := _id_at(drag_from)
			var p := drag_vis + LIFT
			var tilt := clampf((drag_pos.x - drag_vis.x) * 0.004, -0.25, 0.25)
			if gid != "":
				var side := cw * 0.9
				Art.item(self, gid, p, side, true, tilt)
				_draw_lv(p - Vector2(side, side) * 0.5, side, gid)
			else:
				var plate := Art.rrect(Rect2(p - Vector2(cw, cw) * 0.28, Vector2(cw, cw) * 0.56), 10, 2, 0.2)
				draw_colored_polygon(plate, Color("fff7e6"))
				Art.outline(self, plate, 2.0, Art.INK)

