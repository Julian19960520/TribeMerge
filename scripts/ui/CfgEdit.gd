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

var _pages := {}
var _dirty := {}
var _stack: Array = []
var _sc: Scroller
var _root: Control
var _title: Label
var _save_btn: TButton
var _keep_scroll := false
var _block_refresh := false
var _sheet: Control
var _dim: ColorRect
var _sheet_panel: Control
var _sheet_bg: DrawBox
var _sheet_title: Label
var _sheet_sc: Scroller
var _sheet_root: Control
var _sheet_tw: Tween
var _sheet_open := false
var _sheet_kind := ""
var _sheet_ci := -1
var _sheet_ii := -1
var _chooser
var _board_mode := "item"

func _ready() -> void:
	size = Vector2(720, 1480)
	mouse_filter = MOUSE_FILTER_STOP
	UI.box(self, Rect2(0, 0, 720, 1480), func(ci, sz):
		ci.draw_rect(Rect2(Vector2.ZERO, sz), Color("f6e7c8"))
		ci.draw_rect(Rect2(0, 0, sz.x, 140), Color("3b2314"))
	, false)
	var back := UI.btn(self, Rect2(16, 34, 120, 72), "返回", "hide", _on_back, 28)
	back.title_font = false
	_title = UI.lbl(self, "配置", Rect2(148, 34, 390, 72), 36, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 8, Art.INK, true)
	_save_btn = UI.btn(self, Rect2(548, 34, 156, 72), "保存", "green", _save, 28)
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
	var path := _page_path(str(_cur()["page"]))
	_save_btn.visible = path != ""
	_save_btn.text = "保存*" if path != "" and _dirty.has(path) else "保存"
	_save_btn.queue_redraw()

func _cur() -> Dictionary:
	return _stack[_stack.size() - 1]

func _render() -> void:
	var keep := _sc.offset if _keep_scroll else 0.0
	_keep_scroll = false
	_wipe(_root)
	var page := str(_cur()["page"])
	_title.text = _page_title(page)
	var bottom := 40.0
	match page:
		"hub": bottom = _hub()
		"chains": bottom = _chains()
		"people": bottom = _people()
		"story": bottom = _story()
		"unlock": bottom = _unlocks()
		"rand": bottom = _random_orders()
		"albums": bottom = _albums()
		"amber": bottom = _amber()
		"builds": bottom = _builds()
		"levels": bottom = _levels()
		"pass": bottom = _pass()
		"board": bottom = _board()
		"rules": bottom = _rules()
	_sc.set_length(bottom + 48.0)
	_sc.offset = clampf(keep, 0.0, _sc._max())
	if page != "chains":
		_hide_sheet()
	elif _sheet_open:
		var h := _sheet_height()
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
	var entries := _pick_entries(kind)
	if allow_empty:
		entries.insert(0, {"id": "", "name": "空", "icon": "", "pin": true})
	var title := "选择物品"
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

func _set_cell(id: String, i: int) -> void:
	var cells: Array = _pages[Files.BOARD]["cells"]
	while cells.size() <= i:
		cells.append("")
	cells[i] = id
	_touch(Files.BOARD)

func _board_item(i: int) -> String:
	var cells: Array = _pages[Files.BOARD].get("cells", [])
	if i < 0 or i >= cells.size():
		return ""
	return str(cells[i])

func _board_span() -> Vector2i:
	var rules: Dictionary = _pages[Files.RULES]
	return Vector2i(maxi(1, int(rules.get("cols", 7))), maxi(1, int(rules.get("rows", 9))))

func _board_locks() -> Array:
	var locks = _pages[Files.BOARD].get("locks", [])
	return locks if locks is Array else []

func _board_lock(n: int) -> int:
	var span := _board_span()
	return Layout.lock_of(_board_locks(), n, n % span.x, int(n / span.x), span.x, span.y)

func _paint_lock(n: int, lock: int) -> bool:
	var span := _board_span()
	if n < 0 or n >= span.x * span.y:
		return false
	lock = clampi(lock, 0, 2)
	var board: Dictionary = _pages[Files.BOARD]
	var locks := _board_locks()
	if Layout.lock_of(locks, n, n % span.x, int(n / span.x), span.x, span.y) == lock:
		return false
	if not (board.get("locks") is Array):
		board["locks"] = []
	locks = board["locks"]
	Layout.ensure(locks, n, span.x, span.y)
	locks[n] = lock
	_touch(Files.BOARD)
	return true

func _board_reward(n: int) -> Array:
	return Layout.reward_of(_pages[Files.BOARD].get("rewards", {}), n)

func _reward_dict() -> Dictionary:
	var board: Dictionary = _pages[Files.BOARD]
	if not (board.get("rewards") is Dictionary):
		board["rewards"] = {}
	return board["rewards"]

func _set_reward_item(id: String, i: int) -> void:
	var rewards := _reward_dict()
	var key := str(i)
	if id == "":
		rewards.erase(key)
		_touch(Files.BOARD)
		return
	var count := 1
	var prev := Layout.reward_of(rewards, i)
	if not prev.is_empty():
		count = int(prev[1])
	elif Data.CHAINS.has(Data.chain(id)) and Data.type_of(id) in VALUED:
		count = maxi(1, Data.value_of(id))
	rewards[key] = [id, count]
	_touch(Files.BOARD)

func _set_reward_count(n: int, i: int) -> void:
	var prev := _board_reward(i)
	if prev.is_empty() or int(prev[1]) == n:
		return
	_reward_dict()[str(i)] = [str(prev[0]), n]
	_touch(Files.BOARD)

func _swap_reward(a: int, b: int) -> bool:
	if a < 0 or b < 0 or a == b:
		return false
	var rewards := _reward_dict()
	var ra := Layout.reward_of(rewards, a)
	var rb := Layout.reward_of(rewards, b)
	if ra.is_empty() and rb.is_empty():
		return false
	if not ra.is_empty() and not rb.is_empty() and str(ra[0]) == str(rb[0]) and int(ra[1]) == int(rb[1]):
		return false
	var ka := str(a)
	var kb := str(b)
	if ra.is_empty():
		rewards.erase(kb)
	else:
		rewards[kb] = [str(ra[0]), int(ra[1])]
	if rb.is_empty():
		rewards.erase(ka)
	else:
		rewards[ka] = [str(rb[0]), int(rb[1])]
	_touch(Files.BOARD)
	return true

# ---------------------------------------------------------------- 页

func _hub() -> float:
	_h(_root, "点开一张表，改完在该页保存，只写入这一个文件。", 24, 12, 680, 24)
	if not _dirty.is_empty():
		var revert := UI.btn(_root, Rect2(24, 52, 200, 56), "放弃修改", "grey", _revert, 22)
		revert.title_font = false
	var y := 124.0
	var cats := _catalog()
	for i in cats.size():
		var c: Dictionary = cats[i]
		var col := i % 2
		var row := int(i / 2)
		var r := Rect2(20 + col * 348, y + row * 176, 332, 164)
		_card(_root, r, c["icon"], c["title"], _go.bind(c["id"], -1))
	return y + ceil(cats.size() / 2.0) * 176.0

func _revert() -> void:
	_load_pages()
	_dirty.clear()
	_stack = [{"page": "hub", "i": -1}]
	_keep_scroll = false
	call_deferred("_render")
	G.main.toast("已从文件重新读取")

func _chains() -> float:
	var y := 8.0
	_h(_root, "一条产业链分三列。从左到右是从低级到高级，点方格改这一级。", 24, y, 680, 22)
	y += 40
	var sq := 124.0
	var lines: Array = _pages[Files.LINES]
	var used := {}
	for line in lines:
		y = _chain_head(y, str(line.get("name", "")))
		var roles := [
			["生产器队列", str(line.get("gen", ""))],
			["主产物队列", str(line.get("main", ""))],
			["副产物队列", str(line.get("sub", ""))],
		]
		var qh := 46.0 + sq + 52.0
		var box_h := 12.0 + roles.size() * qh
		_panel(_root, Rect2(12, y, 696, box_h))
		var qy := y + 10.0
		for role in roles:
			var cid := str(role[1])
			if cid != "":
				used[cid] = true
			_queue(qy, str(role[0]), _chain_at(cid), sq)
			qy += qh
		y += box_h + 22.0
	var rest: Array = []
	var arr: Array = _pages[Files.CHAINS]
	for i in arr.size():
		var cid := str(arr[i].get("id", ""))
		if not used.has(cid):
			rest.append(i)
	if not rest.is_empty():
		y = _chain_head(y, "其他")
		for ci in rest:
			var c: Dictionary = arr[ci]
			_queue(y, str(c.get("name", c.get("id", ""))), int(ci), sq)
			y += 46.0 + sq + 52.0
		y += 8.0
	UI.btn(_root, Rect2(180, y, 360, 76), "添加物品链", "green", func():
		arr.append({"id": "chain_%d" % (arr.size() + 1), "name": "新链", "type": "item", "items": ["新物品"]})
		_touch(Files.CHAINS)
		_open_chain(arr.size() - 1)
	, 28).title_font = false
	return y + 96

func _chain_head(y: float, text: String) -> float:
	var lab := UI.lbl(_root, text, Rect2(24, y, 640, 40), 30, Art.INK, HORIZONTAL_ALIGNMENT_LEFT, 0, Art.INK, true)
	lab.clip_text = true
	UI.box(_root, Rect2(24, y + 38, 672, 10), func(ci, sz):
		Art.ln(ci, Vector2(0, 4), Vector2(sz.x, 4), 2.5, Color("c9a774"), 2)
	, false)
	return y + 52.0

func _chain_at(id: String) -> int:
	if id == "":
		return -1
	var arr: Array = _pages[Files.CHAINS]
	for i in arr.size():
		if str(arr[i].get("id", "")) == id:
			return i
	return -1

func _queue(y: float, label: String, ci: int, sq: float) -> void:
	var title := label
	if ci >= 0:
		var cname := str(_pages[Files.CHAINS][ci].get("name", ""))
		if cname != "" and cname != label:
			title = "%s · %s" % [label, cname]
		var edit := UI.btn(_root, Rect2(576, y, 116, 40), "编辑", "teal", func():
			_open_chain(ci)
		, 20)
		edit.title_font = false
		_icon_row(y + 44.0, ci, sq)
	else:
		UI.lbl(_root, "还没接上", Rect2(560, y, 140, 40), 18, Color("8a5a30"), HORIZONTAL_ALIGNMENT_RIGHT)
	var lab := UI.lbl(_root, title, Rect2(28, y, 530, 40), 22, Color("6b4a2a"), HORIZONTAL_ALIGNMENT_LEFT)
	lab.clip_text = true

func _icon_row(y: float, ci: int, sq: float) -> void:
	var arr: Array = _pages[Files.CHAINS]
	var c: Dictionary = arr[ci]
	if not c.has("items") or not (c["items"] is Array):
		c["items"] = []
	var items: Array = c["items"]
	var pitch := sq + 12.0
	var sc := Scroller.new()
	sc.horizontal = true
	sc.position = Vector2(20, y)
	sc.size = Vector2(680, sq + 42.0)
	_root.add_child(sc)
	var focus := -1.0
	for k in items.size():
		var kk := k
		var id := "%s_%d" % [str(c.get("id", "")), kk + 1]
		var on := _sheet_open and _sheet_kind == "item" and _sheet_ci == ci and _sheet_ii == kk
		if on:
			focus = float(kk) * pitch
		_sq(sc.content, kk * pitch, 0, sq, id, str(items[kk]), str(kk + 1), on, func():
			_open_item(ci, kk))
	sc.set_length(float(items.size()) * pitch + 8.0)
	if focus >= 0.0:
		sc.jump_to(focus + sq * 0.5 - sc.size.x * 0.5)

func _sq(parent: Node, x: float, y: float, sq: float, id: String, caption: String, mark: String, on: bool, cb: Callable) -> void:
	var b := UI.hit(parent, Rect2(x, y, sq, sq + 36.0), cb)
	b.extra = func(ci, sz):
		_draw_sq(ci, sz, id, on)
		if mark != "":
			var f: Font = G.font_title
			var pos := Vector2(14, 34)
			ci.draw_string_outline(f, pos, mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 6, Art.INK)
			ci.draw_string(f, pos, mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	var cap := UI.lbl(parent, caption, Rect2(x, y + sq - 2, sq, 32), 16, Color("6b4a2a"))
	cap.clip_text = true

func _sq_add(parent: Node, x: float, y: float, sq: float, cb: Callable) -> void:
	var b := UI.hit(parent, Rect2(x, y, sq, sq + 36.0), cb)
	b.extra = func(ci, sz):
		_draw_sq(ci, sz, "", false)
	var plus := UI.lbl(parent, "+", Rect2(x, y, sq, sq), 48, Art.INK, HORIZONTAL_ALIGNMENT_CENTER, 0, Art.INK, true)
	plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cap := UI.lbl(parent, "添加", Rect2(x, y + sq - 2, sq, 32), 16, Color("6b4a2a"))
	cap.clip_text = true

func _draw_sq(ci: CanvasItem, sz: Vector2, id: String, on: bool) -> void:
	var side := sz.x
	var box := Art.rrect(Rect2(Vector2(4, 6), Vector2(side - 8, side - 12)), 18, 6, 0.3)
	Art.dilate(ci, box, 3.0, Art.INK)
	ci.draw_colored_polygon(box, Art.BONE)
	Art.outline(ci, box, 5.0 if on else 2.5, Art.MOSS_D if on else Art.INK)
	if id != "":
		Art.item(ci, id, Vector2(side * 0.5, side * 0.48), side * 0.68)

func _shift_chain(dir: int) -> void:
	var i := _sheet_ci
	var j := i + dir
	var arr: Array = _pages[Files.CHAINS]
	if j < 0 or j >= arr.size():
		return
	var tmp = arr[i]
	arr[i] = arr[j]
	arr[j] = tmp
	_sheet_ci = j
	_touch(Files.CHAINS)
	_rerender()

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
		var b := Art.rrect(Rect2(Vector2(0, 10), Vector2(sz.x, sz.y)), 28, 8, 0.2)
		Art.dilate(ci, b, 3.0, Art.INK)
		ci.draw_colored_polygon(b, Art.BONE)
		Art.outline(ci, b, 3.0, Art.INK)
		var grip := Art.rrect(Rect2(sz.x * 0.5 - 40, 22, 80, 10), 5, 2, 0.2)
		ci.draw_colored_polygon(grip, Color("c9a774"))
	, false)
	_sheet_title = UI.lbl(_sheet_panel, "", Rect2(24, 40, 560, 52), 32, Art.INK, HORIZONTAL_ALIGNMENT_LEFT, 0, Art.INK, true)
	_sheet_title.clip_text = true
	var shut := UI.hit(_sheet_panel, Rect2(628, 30, 72, 72), _close_sheet)
	shut.extra = func(ci, sz): Paint.close_btn(ci, sz * 0.5, 26)
	_sheet_sc = Scroller.new()
	_sheet_sc.position = Vector2(0, 100)
	_sheet_sc.size = Vector2(720, 620)
	_sheet_panel.add_child(_sheet_sc)
	_sheet_root = _sheet_sc.content

func _chain_type(ci: int) -> String:
	var arr: Array = _pages[Files.CHAINS]
	if ci < 0 or ci >= arr.size():
		return ""
	return str(arr[ci].get("type", ""))

func _sheet_height() -> float:
	if _sheet_kind == "chain":
		return 556.0
	var t := _chain_type(_sheet_ci)
	if t == "gen":
		return 680.0
	var extra := t in VALUED or t == "item"
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
	var h := _sheet_height()
	_apply_sheet_height(h)
	var was := _sheet_open
	_sheet_open = true
	_sheet.visible = true
	if not was:
		_sheet_sc.offset = 0.0
	_fill_sheet()
	var dest := 1340.0 - h
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
		_fill_chain()
	else:
		_fill_item()

func _fill_item() -> void:
	var arr: Array = _pages[Files.CHAINS]
	if _sheet_ci < 0 or _sheet_ci >= arr.size():
		return
	var chain: Dictionary = arr[_sheet_ci]
	if not chain.has("items") or not (chain["items"] is Array):
		chain["items"] = []
	var items: Array = chain["items"]
	if _sheet_ii < 0 or _sheet_ii >= items.size():
		return
	_fit_value(chain)
	var ii := _sheet_ii
	if str(chain.get("type", "")) == "gen":
		_fill_gen(chain, ii)
		return
	_sheet_title.text = str(items[ii])
	var y := 8.0
	var icon := "%s_%d" % [str(chain.get("id", "")), ii + 1]
	y = _level_icon(y, icon, chain, items, ii)
	var name_edit := _row_edit(_sheet_root, y, "名字", str(items[ii]), func(t):
		items[ii] = t
		_sheet_title.text = t if t != "" else "未命名"
		_touch(Files.CHAINS))
	_refresh_on_blur(name_edit)
	y += 72
	if str(chain.get("type", "")) in VALUED:
		_row_step(_sheet_root, y, "收取", int(chain["value"][ii]), 0, 99999, func(n):
			chain["value"][ii] = n
			_touch(Files.CHAINS))
		y += 72
	elif str(chain.get("type", "")) == "item":
		_row_step(_sheet_root, y, "价值", int(chain["value"][ii]), 0, 99999, func(n):
			chain["value"][ii] = n
			_touch(Files.CHAINS))
		y += 72
	_sheet_sc.set_length(y + 24)

func _fill_gen(chain: Dictionary, ii: int) -> void:
	var items: Array = chain["items"]
	var level := ii + 1
	_sheet_title.text = str(items[ii])
	var y := 8.0
	var icon := "%s_%d" % [str(chain.get("id", "")), level]
	y = _level_icon(y, icon, chain, items, ii)
	var name_edit := _row_edit(_sheet_root, y, "名字", str(items[ii]), func(t):
		items[ii] = t
		_sheet_title.text = t if t != "" else "未命名"
		_touch(Files.CHAINS))
	_refresh_on_blur(name_edit)
	y += 72
	_fit_prod(chain)
	var prod_title := UI.lbl(_sheet_root, "产物", Rect2(24, y, 680, 40), 26, Color("6b4a2a"), HORIZONTAL_ALIGNMENT_LEFT)
	prod_title.clip_text = true
	y += 44
	y = _drop_row(y, chain, ii)
	var line := _line_by_id(str(chain.get("line", "")))
	var slot = chain["prod"][ii]
	if line.get("cooldown", false) and slot is Dictionary:
		y += 12
		_row_step(_sheet_root, y, "储量", int(slot.get("charges", 8)), 1, 99, func(n):
			slot["charges"] = n
			_touch(Files.CHAINS))
		y += 72
		_row_step(_sheet_root, y, "回满分", int(slot.get("refill_min", 12)), 1, 999, func(n):
			slot["refill_min"] = n
			_touch(Files.CHAINS))
		y += 72
	_sheet_sc.set_length(y + 24)

func _drop_row(y: float, chain: Dictionary, ii: int) -> float:
	var slot = chain["prod"][ii]
	var drops: Array = slot["drops"] if slot is Dictionary and slot.get("drops") is Array else []
	var sq := 108.0
	var pitch := 128.0
	var sc := Scroller.new()
	sc.horizontal = true
	sc.position = Vector2(16, y)
	sc.size = Vector2(688, sq + 68.0)
	_sheet_root.add_child(sc)
	for i in drops.size():
		_drop_cell(sc.content, float(i) * pitch, sq, drops[i], chain, ii, i)
	_sq_add(sc.content, drops.size() * pitch, 0, sq, func():
		_chooser.open("选择产物", _item_choices(), func(id):
			_add_drop(chain, ii, id)))
	sc.set_length(float(drops.size() + 1) * pitch + 8.0)
	return y + sq + 76.0

func _drop_cell(parent: Node, x: float, sq: float, drop: Dictionary, chain: Dictionary, ii: int, di: int) -> void:
	var id := str(drop.get("id", ""))
	_icon(parent, Rect2(x, 0, sq, sq), id)
	var rm := UI.btn(parent, Rect2(x + sq - 36, 2, 36, 36), "×", "red", func():
		_remove_drop(chain, ii, di)
	, 20)
	rm.is_round = true
	rm.title_font = false
	_num_field(parent, Rect2(x, sq + 8, sq, 48), int(drop.get("p", 0)), 0, 9999, func(n):
		drop["p"] = n
		_touch(Files.CHAINS))

func _add_drop(chain: Dictionary, ii: int, id: String) -> void:
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
	_touch(Files.CHAINS)
	_rerender()

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
	_touch(Files.CHAINS)
	_rerender()

func _line_names() -> Dictionary:
	var line_name := {}
	for line in _pages[Files.LINES]:
		if not (line is Dictionary):
			continue
		var lname := str(line.get("name", line.get("id", "")))
		for key in ["gen", "main", "sub"]:
			var ref := str(line.get(key, ""))
			if ref != "":
				line_name[ref] = lname
	return line_name

func _pick_entries(kind: String) -> Array:
	if kind == "chain":
		return _chain_choices()
	if kind == "pline":
		return _line_choices()
	return _item_choices()

func _chain_choices() -> Array:
	var line_name := _line_names()
	var out: Array = []
	for c in _pages[Files.CHAINS]:
		if not (c is Dictionary):
			continue
		var cid := str(c.get("id", ""))
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
	for line in _pages[Files.LINES]:
		if not (line is Dictionary):
			continue
		var id := str(line.get("id", ""))
		out.append({
			"id": id,
			"name": str(line.get("name", id)),
			"icon": _chain_icon(str(line.get("gen", ""))),
		})
	return out

func _item_choices() -> Array:
	var line_name := _line_names()
	var out: Array = []
	var arr: Array = _pages[Files.CHAINS]
	for c in arr:
		if not (c is Dictionary):
			continue
		var cid := str(c.get("id", ""))
		if cid == "":
			continue
		var items: Array = c.get("items", [])
		var group := str(c.get("name", cid))
		var tab := str(line_name.get(cid, "其他"))
		for i in items.size():
			var id := "%s_%d" % [cid, i + 1]
			out.append({"id": id, "name": str(items[i]), "icon": id, "group": group, "tab": tab})
	return out

func _shot_pick() -> void:
	_open_item(0, 2)
	_chooser.open("选择产物", _item_choices(), func(_id): pass)

func _level_icon(y: float, id: String, chain: Dictionary, items: Array, ii: int) -> float:
	var side := 148.0
	var btn := 76.0
	var icon_x := 286.0
	var by := y + (side - btn) * 0.5
	var left := UI.btn(_sheet_root, Rect2(icon_x - 96, by, btn, btn), "<", "grey", func():
		_shift_level(chain, items, ii, -1)
	, 40)
	left.title_font = false
	left.is_round = true
	left.enabled = ii > 0
	_icon(_sheet_root, Rect2(icon_x, y, side, side), id)
	var right := UI.btn(_sheet_root, Rect2(icon_x + side + 20, by, btn, btn), ">", "grey", func():
		_shift_level(chain, items, ii, 1)
	, 40)
	right.title_font = false
	right.is_round = true
	right.enabled = ii < items.size() - 1
	return y + side + 20

func _shift_level(chain: Dictionary, items: Array, ii: int, dir: int) -> void:
	var j := ii + dir
	if j < 0 or j >= items.size():
		return
	_swap(items, ii, dir)
	_swap_value(chain, ii, dir)
	_swap_prod(chain, ii, dir)
	_sheet_ii = j
	_touch(Files.CHAINS)
	_rerender()

func _line_by_id(id: String) -> Dictionary:
	if id == "":
		return {}
	for ln in _pages[Files.LINES]:
		if str(ln.get("id", "")) == id:
			return ln
	return {}

func _gen_form(ci: int, ii: int) -> bool:
	var arr: Array = _pages[Files.CHAINS]
	if ci < 0 or ci >= arr.size() or ii < 0:
		return false
	var prod = arr[ci].get("prod", [])
	return prod is Array and ii < prod.size() and prod[ii] is Dictionary

func _fill_chain() -> void:
	var arr: Array = _pages[Files.CHAINS]
	if _sheet_ci < 0 or _sheet_ci >= arr.size():
		return
	var chain: Dictionary = arr[_sheet_ci]
	if not chain.has("items") or not (chain["items"] is Array):
		chain["items"] = []
	_fit_value(chain)
	_fit_prod(chain)
	_sheet_title.text = str(chain.get("name", ""))
	var y := 12.0
	var id_edit := _row_edit(_sheet_root, y, "id", str(chain.get("id", "")), func(t):
		chain["id"] = t.strip_edges()
		_touch(Files.CHAINS))
	_refresh_on_blur(id_edit)
	y += 72
	var name_edit := _row_edit(_sheet_root, y, "名字", str(chain.get("name", "")), func(t):
		chain["name"] = t
		_sheet_title.text = t if t != "" else "未命名"
		_touch(Files.CHAINS))
	_refresh_on_blur(name_edit)
	y += 72
	var line_edit := _row_edit(_sheet_root, y, "产线", str(chain.get("line", "")), func(t):
		_set_opt(chain, "line", t)
		_touch(Files.CHAINS))
	_refresh_on_blur(line_edit)
	y += 80
	UI.btn(_sheet_root, Rect2(24, y, 160, 56), "上移", "grey", _shift_chain.bind(-1), 22).title_font = false
	UI.btn(_sheet_root, Rect2(200, y, 160, 56), "下移", "grey", _shift_chain.bind(1), 22).title_font = false
	UI.btn(_sheet_root, Rect2(460, y, 236, 56), "删除这条链", "red", func():
		arr.remove_at(_sheet_ci)
		_touch(Files.CHAINS)
		_close_sheet()
	, 22).title_font = false
	_sheet_sc.set_length(y + 80)

func _set_opt(chain: Dictionary, key: String, text: String) -> void:
	var s := text.strip_edges()
	if s == "":
		chain.erase(key)
	else:
		chain[key] = s

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

func _people() -> float:
	var y := 12.0
	var arr: Array = _pages[Files.PEOPLE]
	_h(_root, "剧情订单用序号指人，0 是第一个。点名字改字。", 24, y, 680, 22)
	y += 40
	for i in arr.size():
		var idx := i
		_line(_root, Rect2(24, y, 500, 60), str(arr[i]), func(t):
			arr[idx] = t
			_touch(Files.PEOPLE))
		UI.btn(_root, Rect2(540, y, 156, 60), "删除", "red", func():
			if arr.size() <= 1:
				G.main.toast("至少留一个人物")
				return
			arr.remove_at(idx)
			_touch(Files.PEOPLE)
			_rerender()
		, 24).title_font = false
		y += 72
	UI.btn(_root, Rect2(180, y, 360, 72), "添加人物", "green", func():
		arr.append("新人物")
		_touch(Files.PEOPLE)
		_rerender()
	, 28).title_font = false
	return y + 92

func _unlocks() -> float:
	var book := _ensure_unlocks()
	var n := int(book["levels"])
	var rows: Array = book["rows"]
	var y := 12.0
	var hint := _h(_root, "左侧是每条产线的主产物和副产物。点格子切换，绿色是这个等级的订单可以要它，灰色不行。超过最后一列的等级沿用最后一列。", 16, y, 688, 20)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size.y = 64
	y += 72.0
	var label_w := 168.0
	var head_h := 40.0
	var row_h := 76.0
	var cell := 48.0
	var pitch := 54.0
	var grid_h := head_h + float(rows.size()) * row_h
	var sc := Scroller.new()
	sc.horizontal = true
	sc.position = Vector2(label_w, y)
	sc.size = Vector2(720.0 - label_w - 8.0, grid_h)
	sc.content.mouse_filter = Control.MOUSE_FILTER_PASS
	_root.add_child(sc)
	for col in n:
		var num := UI.lbl(sc.content, str(col + 1), Rect2(float(col) * pitch, 4, cell, 32), 16, Color("6b4a2a"))
		num.clip_text = true
	for ri in rows.size():
		var row: Dictionary = rows[ri]
		var cid := str(row.get("id", ""))
		var ry := head_h + float(ri) * row_h
		var icon_id := "%s_1" % cid
		UI.icon(_root, icon_id, Vector2(40, y + ry + 28), 52)
		var name := UI.lbl(_root, _chain_lv1_name(cid), Rect2(68, y + ry + 8, 96, 52), 18, Art.INK, HORIZONTAL_ALIGNMENT_LEFT)
		name.clip_text = true
		name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var flags: Array = row["open"]
		for col in n:
			_unlock_cell(sc.content, flags, col, Vector2(float(col) * pitch, ry + 8), cell)
	sc.set_length(float(n) * pitch + 8.0)
	return y + grid_h + 24.0

func _unlock_cell(parent: Node, flags: Array, col: int, at: Vector2, cell: float) -> void:
	var box := UI.box(parent, Rect2(at, Vector2(cell, cell)), func(ci, sz):
		var on := col < flags.size() and int(flags[col]) != 0
		var tile := Art.rrect(Rect2(2, 2, sz.x - 4, sz.y - 4), 8, col, 0.35)
		ci.draw_colored_polygon(tile, Color("6fbf3a") if on else Color("c4bbae"))
		Art.outline(ci, tile, 2.0, Color(0.35, 0.24, 0.14, 0.45))
	, false)
	UI.hit(parent, Rect2(at, Vector2(cell, cell)), func():
		while flags.size() <= col:
			flags.append(0)
		flags[col] = 0 if int(flags[col]) != 0 else 1
		_touch(Files.UNLOCKS)
		box.queue_redraw())

func _ensure_unlocks() -> Dictionary:
	var book = _pages.get(Files.UNLOCKS, {})
	if not (book is Dictionary):
		book = {}
		_pages[Files.UNLOCKS] = book
	var n := maxi(1, int(book.get("levels", 40)))
	book["levels"] = n
	var old: Array = book.get("rows", []) if book.get("rows") is Array else []
	var by_id := {}
	for row in old:
		if row is Dictionary and str(row.get("id", "")) != "":
			by_id[str(row["id"])] = row
	var rows: Array = []
	var changed := false
	for line in _pages[Files.LINES]:
		if not (line is Dictionary):
			continue
		var from_lv := maxi(1, int(line.get("unlock", 1)))
		for key in ["main", "sub"]:
			var cid := str(line.get(key, ""))
			if cid == "":
				continue
			var start := from_lv if key == "main" else Data.sub_unlock_level(from_lv)
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
			var before := open.size()
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
		_touch(Files.UNLOCKS)
	return book

func _chain_lv1_name(cid: String) -> String:
	for c in _pages[Files.CHAINS]:
		if c is Dictionary and str(c.get("id", "")) == cid:
			var items: Array = c.get("items", [])
			if not items.is_empty():
				return str(items[0])
			return str(c.get("name", cid))
	return cid

func _editor_product_open(level: int, chain_id: String) -> bool:
	if chain_id == "":
		return false
	var book = _pages.get(Files.UNLOCKS, {})
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
	for e in _item_choices():
		if _editor_product_open(level, Data.chain(str(e.get("id", "")))):
			entries.append(e)
	if entries.is_empty():
		G.main.toast("%d 级还没有能进订单的产物" % level)
		return
	_chooser.open("选择物品", entries, func(id):
		if cb.is_valid():
			cb.call(id)
		_rerender(), current)

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
	_touch(Files.STORY)

func _story_default_item(level: int) -> String:
	if _editor_product_open(level, "fruit"):
		return "fruit_2"
	for line in _pages[Files.LINES]:
		if not (line is Dictionary):
			continue
		for key in ["main", "sub"]:
			var cid := str(line.get(key, ""))
			if cid != "" and _editor_product_open(level, cid):
				return "%s_1" % cid
	return "fruit_2"

func _story() -> float:
	var y := 12.0
	_h(_root, "点头像换人，点物品更换，点数字修改。", 24, y, 680, 20)
	y += 36
	var levels: Array = _pages[Files.STORY].get("levels", [])
	for li in levels.size():
		var lv: Dictionary = levels[li]
		var lix := li
		_h(_root, "主角等级", 24, y, 140, 24)
		_stepper(_root, 180, y, "", int(lv["level"]), 1, 99, func(n):
			lv["level"] = n
			_touch(Files.STORY))
		UI.btn(_root, Rect2(520, y, 176, 52), "删除等级", "red", func():
			levels.remove_at(lix)
			_touch(Files.STORY)
			_rerender()
		, 22).title_font = false
		y += 68
		if not lv.has("orders") or not (lv["orders"] is Array):
			lv["orders"] = []
		var orders: Array = lv["orders"]
		for oi in orders.size():
			y = _story_card(y, orders, oi, int(lv["level"]))
		UI.btn(_root, Rect2(180, y, 360, 64), "添加订单", "teal", func():
			orders.append({"who": 0, "items": [_story_default_item(int(lv["level"]))], "xp": 1, "shell": 1, "rewards": []})
			_touch(Files.STORY)
			_rerender()
		, 24).title_font = false
		y += 88
	UI.btn(_root, Rect2(180, y, 360, 76), "添加等级", "green", func():
		var n := 1
		for lv in levels:
			n = maxi(n, int(lv["level"]) + 1)
		levels.append({"level": n, "orders": []})
		_touch(Files.STORY)
		_rerender()
	, 28).title_font = false
	return y + 96

func _albums() -> float:
	var y := 12.0
	_h(_root, "每本正好 9 张。三列排开，名字写在卡片下面。", 24, y, 680, 22)
	y += 40
	var arr: Array = _pages[Files.ALBUMS]
	var cols := 3
	var gap := 14.0
	var pad := 16.0
	var cw := (720.0 - pad * 2.0 - gap * float(cols - 1)) / float(cols)
	var art_h := 156.0
	var name_h := 48.0
	var row_h := art_h + 8.0 + name_h + 14.0
	for i in arr.size():
		var a: Dictionary = arr[i]
		var idx := i
		_line(_root, Rect2(24, y, 500, 56), str(a.get("name", "")), func(t):
			a["name"] = t
			_touch(Files.ALBUMS))
		UI.btn(_root, Rect2(540, y, 156, 56), "删除", "red", func():
			arr.remove_at(idx)
			_touch(Files.ALBUMS)
			_rerender()
		, 22).title_font = false
		y += 68
		if not a.has("cards") or not (a["cards"] is Array):
			a["cards"] = []
		var cards: Array = a["cards"]
		for k in cards.size():
			var kk := k
			var col := kk % cols
			var row := int(kk / cols)
			var x := pad + float(col) * (cw + gap)
			var cy := y + float(row) * row_h
			_album_face(_root, Rect2(x, cy, cw, art_h), idx, kk)
			var name_edit := _line(_root, Rect2(x, cy + art_h + 6.0, cw, name_h), str(cards[kk]), func(t):
				cards[kk] = t
				_touch(Files.ALBUMS))
			name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_edit.placeholder_text = "名字"
			var rm := UI.btn(_root, Rect2(x + cw - 40.0, cy + 4.0, 36, 36), "×", "red", func():
				cards.remove_at(kk)
				_touch(Files.ALBUMS)
				_rerender()
			, 22)
			rm.title_font = false
			rm.is_round = true
		var rows := int(ceil(float(maxi(cards.size(), 1)) / float(cols))) if not cards.is_empty() else 0
		y += float(rows) * row_h
		UI.btn(_root, Rect2(180, y, 360, 56), "加一张", "teal", func():
			cards.append("")
			_touch(Files.ALBUMS)
			_rerender()
		, 22).title_font = false
		y += 76
	UI.btn(_root, Rect2(180, y, 360, 72), "添加卡册", "green", func():
		arr.append({"name": "新卡册", "cards": ["", "", "", "", "", "", "", "", ""]})
		_touch(Files.ALBUMS)
		_rerender()
	, 28).title_font = false
	return y + 92

func _album_face(parent: Node, r: Rect2, album: int, idx: int) -> void:
	UI.box(parent, r, func(ci, sz):
		ci.draw_colored_polygon(Art.rrect(Rect2(Vector2(0, 5), sz), 12, album + idx, 0.0), Color(0, 0, 0, 0.22))
		var b := Art.rrect(Rect2(Vector2.ZERO, sz - Vector2(0, 5)), 12, album * 9 + idx, 0.5)
		Art.dilate(ci, b, 2.5, Art.INK)
		ci.draw_colored_polygon(b, Art.BONE)
		var ar := Rect2(Vector2(8, 8), Vector2(sz.x - 16, sz.y - 18))
		Paint.card_art(ci, album, idx, ar)
		ci.draw_rect(ar, Art.INK, false, 2.0)
	, false)

func _amber() -> float:
	var y := 12.0
	var arr: Array = _pages[Files.AMBER]
	# 和集市的琥珀礼包一样：都是六边琥珀，礼包越大堆得越多
	var piles := [
		[Art.AMBER_ICON, 1],
		[Art.AMBER_ICON, 2],
		[Art.AMBER_ICON, 3],
		[Art.AMBER_ICON, 4],
		[Art.AMBER_ICON, 5],
		[Art.AMBER_ICON, 6],
	]
	for i in arr.size():
		var a: Dictionary = arr[i]
		var idx := i
		var pile: Array = piles[mini(idx, piles.size() - 1)]
		_panel(_root, Rect2(16, y, 688, 116))
		_amber_pile(_root, Rect2(28, y + 12, 92, 92), str(pile[0]), int(pile[1]))
		_h(_root, "数量", 136, y + 8, 220, 20)
		_num_field(_root, Rect2(136, y + 48, 200, 52), int(a.get("n", 0)), 0, 999999, func(n):
			a["n"] = n
			_touch(Files.AMBER))
		_h(_root, "价格", 356, y + 8, 160, 20)
		_line(_root, Rect2(356, y + 48, 160, 52), str(a.get("price", "")), func(t):
			a["price"] = t
			_touch(Files.AMBER))
		UI.btn(_root, Rect2(536, y + 48, 148, 52), "删除", "red", func():
			arr.remove_at(idx)
			_touch(Files.AMBER)
			_rerender()
		, 22).title_font = false
		y += 128
	UI.btn(_root, Rect2(180, y, 360, 72), "添加一档", "green", func():
		arr.append({"n": 100, "price": "¥6"})
		_touch(Files.AMBER)
		_rerender()
	, 28).title_font = false
	return y + 92

func _amber_pile(parent: Node, r: Rect2, id: String, n: int) -> void:
	UI.box(parent, r, func(ci, sz):
		var box := Art.rrect(Rect2(Vector2.ZERO, sz), 14, 3, 0.3)
		ci.draw_colored_polygon(box, Color("fff3d6"))
		Art.outline(ci, box, 2.0, Art.INK)
		var count := maxi(1, n)
		for j in count:
			var cols := mini(count, 3)
			var off := Vector2((float(j % 3) - float(cols - 1) * 0.5) * 20.0, -float(j / 3) * 16.0 + 4.0)
			Art.item(ci, id, sz * 0.5 + off, 48.0 - float(count) * 2.0)
	, false)

func _builds() -> float:
	var y := 12.0
	_h(_root, "每个区域一串部件，按顺序建。产线填产线 id，随产线开放。", 24, y, 680, 20)
	y += 36
	_h(_root, "部件 id 决定画法（TribeArt.gd）。篝火广场第 1 件开局已建。", 24, y, 680, 20)
	y += 44
	var arr: Array = _pages[Files.BUILDS]
	for i in arr.size():
		var b: Dictionary = arr[i]
		var idx := i
		_fit_parts(b)
		var parts: Array = b["parts"]
		var h := 160.0 + 70.0
		for part in parts:
			h += 64.0 + float(_reward_rows(part["rewards"], REWARD_COLS)) * REWARD_PITCH_Y + 12.0
		_panel(_root, Rect2(16, y, 688, h))
		_line(_root, Rect2(28, y + 16, 180, 52), str(b["id"]), func(t):
			b["id"] = t.strip_edges()
			_touch(Files.BUILDS))
		_line(_root, Rect2(220, y + 16, 300, 52), str(b["name"]), func(t):
			b["name"] = t
			_touch(Files.BUILDS))
		UI.btn(_root, Rect2(540, y + 16, 148, 52), "删除", "red", func():
			arr.remove_at(idx)
			_touch(Files.BUILDS)
			_rerender()
		, 22).title_font = false
		_h(_root, "产线", 28, y + 84, 80, 22)
		_line(_root, Rect2(100, y + 80, 160, 48), str(b.get("line", "")), func(t):
			b["line"] = t.strip_edges()
			_touch(Files.BUILDS))
		_h(_root, "开放等级 %d（随产线）" % Data.build_unlock(b), 280, y + 84, 400, 20)
		var sy := y + 148.0
		for k in parts.size():
			var part: Dictionary = parts[k]
			var pk := k
			_line(_root, Rect2(36, sy, 170, 48), str(part["id"]), func(t):
				part["id"] = t.strip_edges()
				_touch(Files.BUILDS))
			_line(_root, Rect2(214, sy, 200, 48), str(part["name"]), func(t):
				part["name"] = t
				_touch(Files.BUILDS))
			_h(_root, "贝币", 424, sy + 10, 60, 20)
			_line(_root, Rect2(480, sy, 110, 48), str(int(part["cost"])), func(t):
				if t.strip_edges().is_valid_int():
					part["cost"] = maxi(0, int(t))
					_touch(Files.BUILDS))
			UI.btn(_root, Rect2(604, sy, 84, 48), "删除", "grey", func():
				parts.remove_at(pk)
				_touch(Files.BUILDS)
				_rerender()
			, 20).title_font = false
			sy += 60.0
			sy = _reward_board(36.0, sy, part["rewards"], Files.BUILDS) + 12.0
		UI.btn(_root, Rect2(200, sy + 4, 320, 56), "添加部件", "green", func():
			parts.append({"id": "part_%d" % (parts.size() + 1), "name": "新部件", "cost": 100 + parts.size() * 50, "rewards": [["fire_2", 15]]})
			_touch(Files.BUILDS)
			_rerender()
		, 22).title_font = false
		y += h + 16.0
	UI.btn(_root, Rect2(180, y, 360, 72), "添加区域", "green", func():
		var b := {"id": "area_%d" % (arr.size() + 1), "name": "新区域", "line": "", "parts": []}
		_fit_parts(b)
		arr.append(b)
		_touch(Files.BUILDS)
		_rerender()
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
	var y := 12.0
	_h(_root, "升到这一级时发放。没单独写的更高等级，仍按原来的公式。", 24, y, 680, 22)
	y += 40
	var page: Dictionary = _pages[Files.LEVELS]
	if not page.has("levels") or not (page["levels"] is Array):
		page["levels"] = []
	var levels: Array = page["levels"]
	for i in levels.size():
		var row: Dictionary = levels[i]
		var idx := i
		if not (row.get("rewards") is Array):
			row["rewards"] = []
		var rewards: Array = row["rewards"]
		var h := 112.0 + float(_reward_rows(rewards, REWARD_COLS)) * REWARD_PITCH_Y
		_panel(_root, Rect2(16, y, 688, h))
		_stepper(_root, 28, y + 16, "升到", int(row.get("level", 2)), 1, 99, func(n):
			row["level"] = n
			_touch(Files.LEVELS))
		UI.btn(_root, Rect2(540, y + 16, 148, 52), "删除", "red", func():
			levels.remove_at(idx)
			_touch(Files.LEVELS)
			_rerender()
		, 22).title_font = false
		_reward_board(36.0, y + 84.0, rewards, Files.LEVELS)
		y += h + 16.0
	UI.btn(_root, Rect2(180, y, 360, 72), "添加等级", "green", func():
		var n := 2
		for row in levels:
			n = maxi(n, int(row.get("level", 1)) + 1)
		levels.append({"level": n, "rewards": Data.default_level_rewards(n)})
		_touch(Files.LEVELS)
		_rerender()
	, 28).title_font = false
	return y + 92

func _pass() -> float:
	var y := 12.0
	_h(_root, "每一档单独填积分，后面要比前面多。", 24, y, 680, 22)
	y += 44
	var levels: Array = _pages[Files.PASS].get("levels", [])
	for i in levels.size():
		var lv: Dictionary = levels[i]
		var idx := i
		var row := lv
		_h(_root, "第 %d 档" % (i + 1), 24, y + 4, 150, 26)
		_stepper(_root, 180, y, "积分", int(row.get("need", 8)), 1, 9999, func(n):
			row["need"] = n
			_touch(Files.PASS))
		UI.btn(_root, Rect2(540, y, 156, 48), "删除", "red", func():
			levels.remove_at(idx)
			_touch(Files.PASS)
			_rerender()
		, 22).title_font = false
		y += 60
		y = _pass_sides(y, lv)
	UI.btn(_root, Rect2(180, y, 360, 72), "添加一档", "green", func():
		levels.append({"need": _next_pass_need(levels), "free": [], "prem": [], "super": []})
		_touch(Files.PASS)
		_rerender()
	, 28).title_font = false
	return y + 92

func _next_pass_need(levels: Array) -> int:
	if levels.is_empty():
		return 8
	return int(levels.back().get("need", 8)) + levels.size() + 1

## 一档的三列奖励：免费、贵宾（prem）、超级贵宾（super）
func _pass_sides(y: float, lv: Dictionary) -> float:
	var keys := ["free", "prem", "super"]
	var names := ["免费", "贵宾", "超级贵宾"]
	var fills := [Color("e4d0aa"), Art.BONE, Color("f6d48a")]
	for key in keys:
		if not lv.has(key) or not (lv[key] is Array):
			lv[key] = []
	var cols := 2
	var margin := 12.0
	var gap := 8.0
	var pane_w := (720.0 - margin * 2.0 - gap * 2.0) / 3.0
	var pad := 10.0
	var col_gap := 6.0
	var sq := (pane_w - pad * 2.0 - col_gap) * 0.5
	var pitch_x := sq + col_gap
	var pitch_y := sq + 62.0
	var head := 44.0
	var rows := 1
	for key in keys:
		rows = maxi(rows, _reward_rows(lv[key], cols))
	var h := head + float(rows) * pitch_y + 10.0
	for k in keys.size():
		var x := margin + float(k) * (pane_w + gap)
		_pass_pane(Rect2(x, y, pane_w, h), fills[k])
		UI.lbl(_root, names[k], Rect2(x + pad, y + 8, pane_w - pad * 2.0, 32), 22, Art.INK, HORIZONTAL_ALIGNMENT_LEFT, 0, Art.INK, true)
		_reward_grid(x + pad, y + head, sq, pitch_x, pitch_y, cols, lv[keys[k]], Files.PASS)
	return y + h + 12.0

func _reward_rows(items: Array, cols: int) -> int:
	return int(ceil(float(items.size() + 1) / float(cols)))

func _pass_pane(r: Rect2, fill: Color) -> void:
	UI.box(_root, r, func(ci, sz):
		var b := Art.rrect(Rect2(Vector2(2, 4), sz - Vector2(4, 8)), 16, 7, 0.35)
		ci.draw_colored_polygon(b, fill)
		Art.outline(ci, b, 2.5, Art.INK)
	, false)

func _reward_grid(x0: float, y0: float, sq: float, pitch_x: float, pitch_y: float, cols: int, items: Array, path: String) -> void:
	for i in items.size():
		_reward_cell(x0 + float(i % cols) * pitch_x, y0 + float(i / cols) * pitch_y, sq, items, i, path)
	var a := items.size()
	_reward_add(x0 + float(a % cols) * pitch_x, y0 + float(a / cols) * pitch_y, sq, items, path)

func _reward_cell(x: float, y: float, sq: float, items: Array, i: int, path: String) -> void:
	var id := str(items[i][0])
	var hit := UI.hit(_root, Rect2(x, y, sq, sq), _pick_reward.bind(items, i, path))
	hit.extra = func(ci, sz):
		_draw_sq(ci, sz, id, false)
	var kill := UI.hit(_root, Rect2(x + sq - 42, y + 4, 38, 38), _remove_reward.bind(items, i, path))
	kill.extra = _paint_reward_x
	_num_field(_root, Rect2(x, y + sq + 8.0, sq, 46), int(items[i][1]), 1, 9999, func(n):
		items[i][1] = n
		_touch(path))

func _reward_add(x: float, y: float, sq: float, items: Array, path: String) -> void:
	var b := UI.hit(_root, Rect2(x, y, sq, sq), _append_reward.bind(items, path))
	b.extra = func(ci, sz):
		_draw_sq(ci, sz, "", false)
	var plus := UI.lbl(_root, "+", Rect2(x, y, sq, sq), 48, Art.INK, HORIZONTAL_ALIGNMENT_CENTER, 0, Art.INK, true)
	plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cap := UI.lbl(_root, "添加", Rect2(x, y + sq + 8, sq, 46), 18, Color("6b4a2a"), HORIZONTAL_ALIGNMENT_CENTER)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _paint_reward_x(ci: CanvasItem, sz: Vector2) -> void:
	var c := sz * 0.5
	var rad := minf(sz.x, sz.y) * 0.5 - 1.0
	ci.draw_circle(c + Vector2(0, 2), rad, Color(0, 0, 0, 0.28))
	ci.draw_circle(c, rad - 1.0, Color("c4452e"))
	var f: Font = G.font_title
	var fs := 18
	var text := "×"
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := Vector2(c.x - tw * 0.5, c.y + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5)
	ci.draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Art.INK)
	ci.draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)

func _pick_reward(items: Array, i: int, path: String) -> void:
	if i < 0 or i >= items.size():
		return
	_open_pick("item", _set_reward_id.bind(items[i], path), false, str(items[i][0]))

func _remove_reward(items: Array, i: int, path: String) -> void:
	if i < 0 or i >= items.size():
		return
	items.remove_at(i)
	_touch(path)
	_rerender()

func _append_reward(items: Array, path: String) -> void:
	items.append(["fruit_1", 1])
	_touch(path)
	_rerender()

func _set_reward_id(id: String, rw: Array, path: String) -> void:
	rw[0] = id
	_touch(path)

func _board() -> float:
	var span := _board_span()
	var cols := span.x
	var rows := span.y
	var y := 12.0
	var modes := [["item", "编辑物品"], ["lock", "编辑解锁"], ["reward", "编辑奖励"]]
	var bw := 216.0
	var bgap := 12.0
	var bx := (720.0 - bw * 3.0 - bgap * 2.0) * 0.5
	for i in modes.size():
		var mode_id: String = modes[i][0]
		var on := _board_mode == mode_id
		var b := UI.btn(_root, Rect2(bx + float(i) * (bw + bgap), y, bw, 56), modes[i][1], "green" if on else "grey", _pick_board_mode.bind(mode_id), 22)
		b.title_font = false
	y += 68.0
	if _board_mode == "item":
		_h(_root, "点格子换物品，按住拖到另一格交换。锁和奖励留在格子上。", 24, y, 680, 20)
		y += 40.0
	elif _board_mode == "lock":
		_h(_root, "点格子切换：开放、藤蔓、巨石。", 24, y, 680, 20)
		y += 40.0
	else:
		_h(_root, "点底部白框改数量。点气泡换奖励，按住拖到另一格。", 24, y, 680, 20)
		y += 32.0
		_h(_root, "体力、贝币、琥珀飞到顶栏，其他物品飞进暂存。", 24, y, 680, 20)
		y += 40.0
	var gap := 6.0
	var cw := minf(92.0, (688.0 - gap * float(cols - 1)) / float(cols))
	var ch := cw
	var x0 := (720.0 - (cw + gap) * float(cols) + gap) * 0.5
	var pad := BoardPad.new()
	pad.edit = self
	pad.cols = cols
	pad.rows = rows
	pad.cw = cw
	pad.ch = ch
	pad.gap = gap
	pad.x0 = x0
	pad.mode = _board_mode
	pad.position = Vector2(0, y)
	pad.size = Vector2(720, rows * (ch + gap))
	_root.add_child(pad)
	if _board_mode == "reward":
		_place_reward_counts(pad.position, cols, rows, cw, gap, x0)
	return y + rows * (ch + gap) + 24.0

func _place_reward_counts(origin: Vector2, cols: int, rows: int, cw: float, gap: float, x0: float) -> void:
	var step := cw + gap
	for row in rows:
		for col in cols:
			var n := row * cols + col
			var rw := _board_reward(n)
			if rw.is_empty():
				continue
			var cell := Rect2(origin.x + x0 + float(col) * step, origin.y + float(row) * step, cw, cw)
			var fh := 30.0
			var box := Rect2(cell.position.x + 5.0, cell.end.y - fh - 4.0, cell.size.x - 10.0, fh)
			_reward_count_box(box, int(rw[1]), n)

func _reward_count_box(r: Rect2, value: int, cell: int) -> void:
	var back := UI.box(_root, r, func(ci, sz):
		var b := Art.rrect(Rect2(Vector2(1, 1), sz - Vector2(2, 2)), 8, 2, 0.12)
		ci.draw_colored_polygon(b, Color.WHITE)
		Art.outline(ci, b, 2.0, Color("c9a774"))
	, false)
	back.z_index = 1
	back.set_meta("reward_cell", cell)
	var shown := str(clampi(value, 1, 9999))
	var e := LineEdit.new()
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
	var empty := StyleBoxEmpty.new()
	e.add_theme_stylebox_override("normal", empty)
	e.add_theme_stylebox_override("focus", empty)
	e.add_theme_stylebox_override("read_only", empty)
	e.set_meta("reward_cell", cell)
	var ii := cell
	e.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_sc.yield_gesture())
	e.text_changed.connect(func(_t):
		_apply_num(e, e.text, 1, 9999, func(v): _set_reward_count(v, ii)))
	e.focus_exited.connect(func():
		var v := 1
		if e.text.is_valid_int():
			v = clampi(int(e.text), 1, 9999)
		if e.text != str(v):
			e.text = str(v)
		_set_reward_count(v, ii))
	_root.add_child(e)

func _pick_board_mode(mode_id: String) -> void:
	if _board_mode == mode_id:
		return
	_board_mode = mode_id
	_rerender()

func _swap_board(a: int, b: int) -> bool:
	if a < 0 or b < 0 or a == b:
		return false
	var cells: Array = _pages[Files.BOARD]["cells"]
	var need := maxi(a, b) + 1
	while cells.size() < need:
		cells.append("")
	if str(cells[a]) == str(cells[b]):
		return false
	var tmp = cells[a]
	cells[a] = cells[b]
	cells[b] = tmp
	_touch(Files.BOARD)
	return true

func _random_orders() -> float:
	var page = _pages[Files.RANDOM_ORDERS]
	if page is not Dictionary:
		page = {}
		_pages[Files.RANDOM_ORDERS] = page
	var pad := OrderCurvePadSc.new()
	pad.edit = self
	pad.page = page
	pad.position = Vector2.ZERO
	var h := _sc.size.y
	if h < 100.0:
		h = 1340.0
	pad.size = Vector2(720, h)
	_root.add_child(pad)
	return h

func _rules() -> float:
	var d: Dictionary = _pages[Files.RULES]
	var y := 12.0
	_h(_root, "列和行用奇数，中心格才唯一。改大小后保存，棋盘会按新尺寸裁好。", 24, y, 680, 22)
	y += 48
	y = _rule(d, y, "cols", "列数", 1, 15)
	y = _rule(d, y, "rows", "行数", 1, 20)
	y = _rule(d, y, "max_energy", "火种上限", 1, 9999)
	y = _rule(d, y, "regen_sec", "恢复秒数", 1, 9999)
	y = _rule(d, y, "random_orders", "随机订单张数", 0, 12)
	y = _rule(d, y, "craft_level", "制作单开放等级", 1, 40)
	y = _rule(d, y, "xp_base", "升级声望起点", 1, 99)
	y = _rule(d, y, "xp_div", "每几级声望+1", 1, 20)
	y = _rule(d, y, "energy_price", "火种首次价格", 1, 999)
	y = _rule(d, y, "energy_price_step", "火种每次涨价", 0, 999)
	y = _rule(d, y, "energy_price_max", "火种最高价格", 1, 999)
	y = _rule(d, y, "token_step", "鼓换卡包", 1, 999)
	y = _rule(d, y, "storage_expand_price", "储物首次价格", 1, 999)
	y = _rule(d, y, "storage_expand_step", "储物每格涨价", 1, 999)
	return y + 20

func _rule(d: Dictionary, y: float, key: String, label: String, lo: int, hi: int) -> float:
	_stepper(_root, 24, y, label, int(d.get(key, 0)), lo, hi, func(n):
		d[key] = n
		_touch(Files.RULES))
	return y + 68

# ---------------------------------------------------------------- 控件

func _h(parent: Node, text: String, x: float, y: float, w: float, fs: int) -> Label:
	return UI.lbl(parent, text, Rect2(x, y, w, 40), fs, Color("6b4a2a"), HORIZONTAL_ALIGNMENT_LEFT)

func _panel(parent: Node, r: Rect2) -> void:
	UI.box(parent, r, func(ci, sz):
		var b := Art.rrect(Rect2(Vector2(2, 4), sz - Vector2(4, 8)), 16, 5, 0.35)
		ci.draw_colored_polygon(b, Color("fff7e6"))
		Art.outline(ci, b, 2.5, Art.INK)
	, false)

func _card(parent: Node, r: Rect2, icon: String, title: String, cb: Callable) -> void:
	var b := UI.hit(parent, r, cb)
	b.extra = func(ci, sz):
		var box := Art.rrect(Rect2(Vector2(2, 4), sz - Vector2(4, 8)), 18, 8, 0.35)
		Art.dilate(ci, box, 3.0, Art.INK)
		ci.draw_colored_polygon(box, Color("fff7e6"))
		if icon != "":
			Paint.cfg_icon(ci, icon, Vector2(62, sz.y * 0.5), minf(100.0, sz.y * 0.7))
	UI.lbl(parent, title, Rect2(r.position.x + 118, r.position.y + (r.size.y - 48.0) * 0.5, r.size.x - 132, 48), 30, Art.INK, HORIZONTAL_ALIGNMENT_LEFT, 0, Art.INK, true)

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
	var oix := oi
	if not (o.get("items") is Array):
		o["items"] = []
	var items: Array = o["items"]
	_ensure_rewards(o)
	var rewards: Array = o["rewards"]
	var groups := _reward_groups(rewards)
	var layout := _order_layout(items.size())
	layout["seed"] = oi
	var w := float(layout["w"])
	var h := float(layout["h"])
	var origin := Vector2((720.0 - w) * 0.5, y)
	UI.box(_root, Rect2(origin, Vector2(w, h)), func(ci, sz):
		_paint_story_card(ci, sz, o, items, layout))
	var who_r: Rect2 = layout["who"]
	UI.hit(_root, _shift(origin, who_r), func():
		var n := maxi(1, _pages[Files.PEOPLE].size())
		o["who"] = (int(o.get("who", 0)) + 1) % n
		_touch(Files.STORY)
		_rerender())
	var name_r: Rect2 = layout["name"]
	var name := UI.lbl(_root, _who_short(int(o.get("who", 0))), _shift(origin, name_r), 30, Art.INK, HORIZONTAL_ALIGNMENT_LEFT)
	name.clip_text = true
	var xp_r: Rect2 = layout["xp"]
	var xp_edit := _bare_num(_root, _shift(origin, xp_r), int(o.get("xp", 0)), 0, 999, 28, Color.WHITE, Art.INK, func(n):
		o["xp"] = n
		_touch(Files.STORY))
	xp_edit.z_index = 2
	xp_edit.mouse_filter = Control.MOUSE_FILTER_STOP
	var star: Vector2 = layout["star"]
	var star_s := float(layout["star_s"])
	var zone := Rect2(xp_r.position.x, star.y - star_s * 0.5, star.x + star_s * 0.5 - xp_r.position.x, star_s)
	var star_hit := UI.hit(_root, _shift(origin, zone), func():
		xp_edit.grab_focus())
	star_hit.z_index = 3
	star_hit.mouse_filter = Control.MOUSE_FILTER_STOP
	var kill_r: Rect2 = layout["kill"]
	var del := UI.hit(_root, _shift(origin, kill_r), func():
		orders.remove_at(oix)
		_touch(Files.STORY)
		_rerender())
	del.extra = _paint_reward_x
	for k in items.size():
		var kk := k
		var ir := _item_rect(layout, kk)
		UI.hit(_root, _shift(origin, ir), func():
			_open_story_item(level, func(id):
				_assign_story_item(id, items, kk, level), str(items[kk])))
		var xb := UI.hit(_root, _shift(origin, Rect2(ir.position.x + ir.size.x - 30, ir.position.y - 2, 34, 34)), func():
			if kk < 0 or kk >= items.size():
				return
			items.remove_at(kk)
			_touch(Files.STORY)
			_rerender())
		xb.extra = _paint_reward_x
	var pr := _item_rect(layout, items.size())
	UI.hit(_root, _shift(origin, pr), func():
		_open_story_item(level, func(id):
			_assign_story_item(id, items, items.size(), level)))
	var plus := UI.lbl(_root, "+", _shift(origin, pr), int(pr.size.y * 0.4), Art.INK, HORIZONTAL_ALIGNMENT_CENTER, 0, Art.INK, true)
	plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return _story_rewards(y + h + 4.0, origin.x, w, o, rewards, groups)

func _order_layout(item_n: int) -> Dictionary:
	var item_s := 112.0
	var item_gap := 14.0
	var slots := item_n + 1
	var items_span := float(slots) * item_s + float(maxi(slots - 1, 0)) * item_gap
	var w := clampf(items_span + 96.0, 480.0, 688.0)
	var inner := w - 64.0
	if items_span > inner:
		item_gap = 8.0
		item_s = (inner - float(maxi(slots - 1, 0)) * item_gap) / float(maxi(slots, 1))
		items_span = float(slots) * item_s + float(maxi(slots - 1, 0)) * item_gap
	var items_cy := 168.0
	var h := items_cy + item_s * 0.5 + 36.0
	var star := Vector2(w - 116.0, 54.0)
	var xp := Rect2(star.x - 120.0, star.y - 26.0, 82.0, 52.0)
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
	var s := float(layout["item_s"])
	var gap := float(layout["item_gap"])
	var x := (float(layout["w"]) - float(layout["items_span"])) * 0.5 + float(index) * (s + gap)
	var y := float(layout["items_cy"]) - s * 0.5
	return Rect2(x, y, s, s)

func _text_px(text: String, fs: int) -> float:
	if G.font_body == null:
		return float(maxi(text.length(), 1)) * float(fs) * 0.62
	return G.font_body.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x

## 胶囊按图标和数字收紧。没有图标的是加号，收成一颗圆。
func _capsule_metrics(text: String, icon: bool, with_x: bool) -> Dictionary:
	var h := 46.0
	if not icon:
		return {"w": h, "h": h, "num": Rect2()}
	var num := Rect2(34.0, 0.0, _text_px(text, 22) + 8.0, h)
	var w := num.end.x + (30.0 if with_x else 10.0)
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
	var gap := 8.0
	var max_row := 688.0
	var lines: Array = []
	var line: Array = []
	var line_w := 0.0
	for i in specs.size():
		var cw := float(metrics[i]["w"])
		var add := cw if line.is_empty() else cw + gap
		if not line.is_empty() and line_w + add > max_row:
			lines.append({"idx": line.duplicate(), "w": line_w})
			line = []
			line_w = 0.0
			add = cw
		line.append(i)
		line_w += add
	if not line.is_empty():
		lines.append({"idx": line, "w": line_w})
	var ch := 46.0
	var yy := y
	for ln in lines:
		var idxs: Array = ln["idx"]
		var tw := float(ln["w"])
		var x := clampf(card_x + (card_w - tw) * 0.5, 16.0, 704.0 - tw)
		var row := Rect2(x, yy, tw, ch)
		var paint_idx: Array = idxs.duplicate()
		UI.box(_root, row, _paint_reward_row.bind(paint_idx, metrics, specs))
		var px := x
		for j in idxs.size():
			var ii: int = idxs[j]
			var m: Dictionary = metrics[ii]
			_bind_capsule(Rect2(px, yy, float(m["w"]), ch), m, specs[ii], o, rewards)
			px += float(m["w"]) + gap
		yy += ch + 8.0
	return yy + 6.0

func _paint_reward_row(ci: CanvasItem, _sz: Vector2, idxs: Array, metrics: Array, specs: Array) -> void:
	var gap := 8.0
	var ch := 46.0
	var px := 0.0
	for j in idxs.size():
		var ii: int = idxs[j]
		var m: Dictionary = metrics[ii]
		var r := Rect2(px, 0, float(m["w"]), ch)
		_paint_capsule(ci, r, str(specs[ii]["icon"]), ii)
		px += float(m["w"]) + gap

func _bind_capsule(r: Rect2, m: Dictionary, spec: Dictionary, o: Dictionary, rewards: Array) -> void:
	var kind := str(spec["kind"])
	if kind == "add":
		UI.hit(_root, r, func():
			_open_pick("item", func(id):
				if id == "":
					return
				rewards.append(id)
				_touch(Files.STORY)
			, false))
		var plus := UI.lbl(_root, "+", r, 32, Art.INK, HORIZONTAL_ALIGNMENT_CENTER, 0, Art.INK, true)
		plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	var num: Rect2 = m["num"]
	var field := Rect2(r.position + num.position, num.size)
	var shown := str(spec["text"])
	if kind == "shell":
		_bare_num(_root, field, int(o.get("shell", 0)), 0, 9999, 22, Art.INK, Color.WHITE, func(n):
			o["shell"] = n
			_touch(Files.STORY)
		, shown)
	elif kind == "token":
		_bare_num(_root, field, int(o.get("token", 0)), 0, 99, 22, Art.INK, Color.WHITE, func(n):
			_opt(o, "token", n)
			_touch(Files.STORY)
		, shown)
	else:
		var gid := str(spec["id"])
		UI.hit(_root, Rect2(r.position, Vector2(34, r.size.y)), func():
			_open_pick("item", func(id):
				_retarget_reward(rewards, gid, id)
			, false, gid))
		_bare_num(_root, field, int(spec["n"]), 1, 999, 22, Art.INK, Color.WHITE, func(n):
			_set_group_count(rewards, gid, n)
			_touch(Files.STORY)
		, shown)
		var rx := UI.hit(_root, Rect2(r.end.x - 28, r.position.y + (r.size.y - 28) * 0.5, 26, 28), func():
			_drop_reward(rewards, gid))
		rx.extra = _paint_reward_x

func _paint_capsule(ci: CanvasItem, r: Rect2, icon: String, seed: int) -> void:
	var pill := Art.rrect(r, r.size.y * 0.5, 70 + seed, 0.35)
	ci.draw_colored_polygon(pill, Color(0.55, 0.35, 0.15, 0.22))
	if icon != "":
		Art.item(ci, icon, Vector2(r.position.x + 18, r.get_center().y), 34, false)

func _paint_story_card(ci: CanvasItem, sz: Vector2, o: Dictionary, items: Array, layout: Dictionary) -> void:
	var seed := int(layout.get("seed", 0)) * 17 + int(o.get("who", 0))
	var r := Rect2(6, 24, sz.x - 12, sz.y - 36)
	ci.draw_colored_polygon(Art.rrect(Rect2(r.position + Vector2(0, 7), r.size), 18, seed, 0.0), Color(0, 0, 0, 0.28))
	var b := Art.rrect(r, 18, seed + 1, 0.9)
	Art.dilate(ci, b, 3.0, Art.INK)
	ci.draw_colored_polygon(b, Color("ffe9a8"))
	Art.dashed(ci, Art.rrect(r.grow(-6), 12, seed + 2, 0.0), 8, 6, Color(0.65, 0.4, 0.2, 0.45), 2.0)
	var head_c: Vector2 = layout["head"]
	var head_rad := float(layout["head_r"])
	var head := Art.ell(head_c, Vector2(head_rad, head_rad), seed + 3, 0.02, 20)
	Art.dilate(ci, head, 3.0, Art.INK)
	ci.draw_colored_polygon(head, Art.OCHRE.lightened(0.28))
	Meme.portrait(ci, int(o.get("who", 0)), head_c + Vector2(0, -2), head_rad * 1.62)
	var star: Vector2 = layout["star"]
	Art.item(ci, "xp_1", star, float(layout["star_s"]))
	for k in items.size():
		var ir := _item_rect(layout, k)
		var c := ir.get_center()
		var s := ir.size.x
		ci.draw_colored_polygon(Art.ell(c + Vector2(0, 5), Vector2(s * 0.4, s * 0.28), seed + 8 + k, 0.03, 16), Color(0.8, 0.65, 0.4, 0.35))
		Art.item(ci, str(items[k]), c, s * 0.94)
	var slot := _item_rect(layout, items.size())
	var pc := slot.get_center()
	var rad := slot.size.x * 0.32
	var ring := Art.ell(pc, Vector2(rad, rad * 0.94), seed + 4, 0.04, 18)
	ci.draw_colored_polygon(ring, Color(1, 0.97, 0.9, 0.55))
	Art.outline(ci, ring, 2.5, Art.INK)

func _reward_groups(rewards: Array) -> Array:
	var out: Array = []
	var index := {}
	for id in rewards:
		var s := str(id)
		if s == "":
			continue
		if not index.has(s):
			index[s] = out.size()
			out.append({"id": s, "n": 0})
		var at: int = index[s]
		out[at]["n"] = int(out[at]["n"]) + 1
	return out

func _set_group_count(rewards: Array, id: String, n: int) -> void:
	var have := 0
	var first := -1
	for i in rewards.size():
		if str(rewards[i]) == id:
			have += 1
			if first < 0:
				first = i
	if n == have:
		return
	if n > have:
		var at := first if first >= 0 else rewards.size()
		for _k in n - have:
			rewards.insert(at, id)
		return
	var drop := have - n
	var i := rewards.size() - 1
	while i >= 0 and drop > 0:
		if str(rewards[i]) == id:
			rewards.remove_at(i)
			drop -= 1
		i -= 1

func _drop_reward(rewards: Array, id: String) -> void:
	var i := rewards.size() - 1
	while i >= 0:
		if str(rewards[i]) == id:
			rewards.remove_at(i)
		i -= 1
	_touch(Files.STORY)
	_rerender()

func _retarget_reward(rewards: Array, id: String, new_id: String) -> void:
	if new_id == "" or new_id == id:
		return
	for i in rewards.size():
		if str(rewards[i]) == id:
			rewards[i] = new_id
	_touch(Files.STORY)

func _icon(parent: Node, r: Rect2, id: String) -> void:
	UI.box(parent, r, func(ci, sz):
		var box := Art.rrect(Rect2(Vector2.ZERO, sz), 12, 3, 0.3)
		ci.draw_colored_polygon(box, Color("fff7e6"))
		Art.outline(ci, box, 2.0, Art.INK)
		if id != "":
			Art.item(ci, id, sz * 0.5, minf(sz.x, sz.y) * 0.82)
	, true)

func _slot(parent: Node, x: float, y: float, caption: String, id: String, cb: Callable) -> void:
	_cell(parent, Rect2(x, y, 150, 118), caption, id, cb)

func _cell(parent: Node, r: Rect2, caption: String, id: String, cb: Callable) -> void:
	var b := UI.hit(parent, r, cb)
	b.extra = func(ci, sz):
		var box := Art.rrect(Rect2(Vector2(0, 0), Vector2(sz.x, sz.y - 22)), 12, 4, 0.3)
		Art.dilate(ci, box, 2.5, Art.INK)
		ci.draw_colored_polygon(box, Color("fff7e6"))
		if id != "":
			Art.item(ci, id, Vector2(sz.x * 0.5, (sz.y - 22) * 0.5), minf(sz.x, sz.y - 22) * 0.78)
	UI.lbl(parent, caption, Rect2(r.position.x, r.position.y + r.size.y - 24, r.size.x, 24), 16, Color("6b4a2a"))

func _row_edit(parent: Node, y: float, title: String, text: String, cb: Callable) -> LineEdit:
	var lab := UI.lbl(parent, title, Rect2(24, y, 150, 56), 26, Color("6b4a2a"), HORIZONTAL_ALIGNMENT_LEFT)
	lab.clip_text = true
	return _line(parent, Rect2(180, y, 516, 56), text, cb)

func _row_step(parent: Node, y: float, title: String, value: int, lo: int, hi: int, apply: Callable) -> void:
	var lab := UI.lbl(parent, title, Rect2(24, y, 150, 56), 26, Color("6b4a2a"), HORIZONTAL_ALIGNMENT_LEFT)
	lab.clip_text = true
	_num_field(parent, Rect2(180, y, 240, 56), value, lo, hi, apply)

func _line(parent: Node, r: Rect2, text: String, cb: Callable) -> LineEdit:
	var back := UI.box(parent, r, func(ci, sz):
		var b := Art.rrect(Rect2(Vector2(1, 1), sz - Vector2(2, 2)), 12, 2, 0.15)
		ci.draw_colored_polygon(b, Color.WHITE)
		Art.outline(ci, b, 2.0, Color("c9a774"))
	, false)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var e := LineEdit.new()
	e.position = r.position
	e.size = r.size
	e.text = text
	e.caret_blink = true
	var fs := 26
	e.add_theme_font_size_override("font_size", fs)
	e.add_theme_constant_override("caret_width", maxi(2, int(round(float(fs) / 6.5))))
	e.add_theme_color_override("font_color", Art.INK)
	e.add_theme_color_override("caret_color", Art.INK)
	e.add_theme_color_override("font_placeholder_color", Color("a09080"))
	var empty := StyleBoxEmpty.new()
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
	var bx := x
	if label != "":
		_h(parent, label, x, y, 110, 22)
		bx = x + 118
	_num_field(parent, Rect2(bx, y, 150, 48), value, lo, hi, apply)

func _ink_label(parent: Node, text: String, r: Rect2, fs: int, col: Color, ocol: Color, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.text = text
	l.position = r.position
	l.size = r.size
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.clip_text = true
	var ls := LabelSettings.new()
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
	var e := LineEdit.new()
	e.position = r.position
	e.size = r.size
	e.text = text
	e.alignment = align
	e.caret_blink = true
	e.select_all_on_focus = true
	e.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	e.add_theme_font_size_override("font_size", fs)
	e.add_theme_constant_override("caret_width", maxi(2, int(round(float(fs) / 6.5))))
	var clear := Color(0, 0, 0, 0)
	e.add_theme_color_override("font_color", clear)
	e.add_theme_color_override("font_selected_color", clear)
	e.add_theme_color_override("font_placeholder_color", clear)
	e.add_theme_color_override("font_uneditable_color", clear)
	e.add_theme_color_override("caret_color", Art.INK)
	e.add_theme_color_override("selection_color", Color(0.92, 0.65, 0.24, 0.45))
	if G.font_body:
		e.add_theme_font_override("font", G.font_body)
	var empty := StyleBoxEmpty.new()
	e.add_theme_stylebox_override("normal", empty)
	e.add_theme_stylebox_override("focus", empty)
	e.add_theme_stylebox_override("read_only", empty)
	e.text_changed.connect(cb)
	parent.add_child(e)
	return e

func _bare_num(parent: Node, r: Rect2, value: int, lo: int, hi: int, fs: int, col: Color, ocol: Color, apply: Callable, fit_to: String = "") -> LineEdit:
	var shown := str(clampi(value, lo, hi))
	var lab := _ink_label(parent, shown, r, fs, col, ocol, HORIZONTAL_ALIGNMENT_CENTER)
	var edit: LineEdit
	edit = _bare_line(parent, r, shown, fs, HORIZONTAL_ALIGNMENT_CENTER, func(_t):
		_apply_num(edit, edit.text, lo, hi, apply)
		lab.text = edit.text)
	edit.focus_exited.connect(func():
		var n := lo
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
		var n := lo
		if edit.text.is_valid_int():
			n = clampi(int(edit.text), lo, hi)
		if edit.text != str(n):
			edit.text = str(n)
		apply.call(n))
	return edit

func _apply_num(edit: LineEdit, t: String, lo: int, hi: int, apply: Callable) -> void:
	var digits := ""
	for ch in t:
		if ch >= "0" and ch <= "9":
			digits += ch
	if digits == "":
		if edit.text != "":
			edit.text = ""
		return
	var n := int(digits)
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
	var x := 24.0
	for i in arr.size():
		var idx := i
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

func _chain_icon(cid: String) -> String:
	if cid == "":
		return ""
	return "%s_1" % cid

func _who_name(i: int) -> String:
	var people: Array = _pages[Files.PEOPLE]
	if i >= 0 and i < people.size():
		return str(people[i])
	return "人物 %d" % i

func _who_short(i: int) -> String:
	var name := _who_name(i)
	if name.contains(" "):
		var part := name.get_slice(" ", 1)
		if part != "":
			return part
	return name

func _opt(o: Dictionary, key: String, n: int) -> void:
	if n <= 0:
		o.erase(key)
	else:
		o[key] = n

func _fit_value(chain: Dictionary) -> void:
	var t := str(chain.get("type", ""))
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

func _swap(arr: Array, i: int, dir: int) -> void:
	var j := i + dir
	if j < 0 or j >= arr.size():
		return
	var tmp = arr[i]
	arr[i] = arr[j]
	arr[j] = tmp

func _swap_value(chain: Dictionary, i: int, dir: int) -> void:
	if not chain.has("value"):
		return
	_swap(chain["value"], i, dir)

func _swap_prod(chain: Dictionary, i: int, dir: int) -> void:
	if not chain.has("prod"):
		return
	_swap(chain["prod"], i, dir)

func _save() -> void:
	var page := str(_cur()["page"])
	var path := _page_path(page)
	if path == "":
		return
	var paths: Array = [path]
	if path == Files.CHAINS:
		for extra in [Files.LINES]:
			if _dirty.has(extra):
				paths.append(extra)
	for p in paths:
		var msg := _validate(str(p))
		if msg != "":
			G.main.toast(msg)
			return
	if path == Files.BOARD:
		_fit_board()
	var wrote: Array = []
	var board_saved := false
	for p in paths:
		if not _dirty.has(p):
			continue
		var err := Files.write(str(p), _pages[p])
		if err != OK:
			G.main.toast("保存失败")
			return
		if str(p) == Files.BOARD:
			board_saved = true
		wrote.append(_path_title(str(p)))
		_dirty.erase(p)
	if wrote.is_empty():
		G.main.toast("没有要保存的修改")
		return
	_refresh_save()
	Data.reload()
	G._apply_rules()
	var toast := "已写入%s" % "、".join(wrote)
	if board_saved:
		toast += "。新棋盘要重新开始才换上。"
		var bp: Dictionary = _pages[Files.BOARD]
		var probs: Array = Guide.layout_problems(bp.get("cells", []), bp.get("locks", []))
		if not probs.is_empty():
			toast = "已保存。注意：引导路线对不上，新玩家会跳过引导"
			push_warning("新手引导路线对不上：" + "；".join(probs))
	G.main.toast(toast)

func _validate(path: String) -> String:
	var seen := {}
	if path == Files.CHAINS:
		for c in _pages[Files.CHAINS]:
			var id := str(c.get("id", "")).strip_edges()
			c["id"] = id
			if id == "":
				return "有物品链没有 id"
			if seen.has(id):
				return "物品链 id 重复：" + id
			seen[id] = true
			if c.get("items", []).is_empty():
				return "%s 至少要有一级" % id
	elif path == Files.LINES:
		for line in _pages[Files.LINES]:
			var id := str(line.get("id", "")).strip_edges()
			line["id"] = id
			if id == "":
				return "有产线没有 id"
			if seen.has(id):
				return "产线 id 重复：" + id
			seen[id] = true
	elif path == Files.ALBUMS:
		for a in _pages[Files.ALBUMS]:
			if a.get("cards", []).size() != 9:
				return "「%s」要正好 9 张卡" % a.get("name", "")
	elif path == Files.PEOPLE:
		if _pages[Files.PEOPLE].is_empty():
			return "至少留一个人物"
	elif path == Files.BUILDS:
		var seen_b := {}
		for b in _pages[Files.BUILDS]:
			var id := str(b.get("id", "")).strip_edges()
			b["id"] = id
			if id == "":
				return "有建筑缺少 id"
			if seen_b.has(id):
				return "建筑 id 重复：" + id
			seen_b[id] = true
			_fit_parts(b)
			var seen_p := {}
			var groups: Array = []
			for part in b["parts"]:
				var pid := str(part["id"]).strip_edges()
				part["id"] = pid
				if seen_p.has(pid):
					return "%s 的部件 id 重复：%s" % [b.get("name", id), pid]
				seen_p[pid] = true
				groups.append(part["rewards"])
			var build_msg := _check_rewards(groups, b.get("name", id))
			if build_msg != "":
				return build_msg
	elif path == Files.LEVELS:
		var seen_lv := {}
		for row in _pages[Files.LEVELS].get("levels", []):
			var n := int(row.get("level", 0))
			if n < 1:
				return "主角等级至少是 1"
			if seen_lv.has(n):
				return "主角等级重复：%d" % n
			seen_lv[n] = true
			if not (row.get("rewards") is Array):
				row["rewards"] = []
			var level_msg := _check_rewards([row["rewards"]], "升到 %d 级" % n)
			if level_msg != "":
				return level_msg
	elif path == Files.RANDOM_ORDERS:
		var curves = _pages[path].get("curves", [])
		if not (curves is Array) or curves.size() != 2:
			return "要有下限和上限两条线"
		var lows = curves[0].get("diff", [])
		var highs = curves[1].get("diff", [])
		if not (lows is Array) or not (highs is Array) or lows.is_empty() or highs.size() != lows.size():
			return "上下限的等级对不上"
		for i in lows.size():
			if int(lows[i]) < 1 or int(highs[i]) < 1:
				return "难度至少是 1 火苗"
			if int(highs[i]) < int(lows[i]):
				return "%d 级的上限低于下限" % (i + 1)
	elif path == Files.BOARD:
		var board_msg := _check_board_rewards(_pages[Files.BOARD])
		if board_msg != "":
			return board_msg
	elif path == Files.PASS:
		var prev := 0
		var i := 0
		for lv in _pages[Files.PASS].get("levels", []):
			i += 1
			var need := int(lv.get("need", 0))
			if need < 1:
				return "第 %d 档积分至少是 1" % i
			if need <= prev:
				return "第 %d 档积分要比上一档多" % i
			prev = need
	return ""

func _check_board_rewards(board: Dictionary) -> String:
	var rewards = board.get("rewards", {})
	if rewards == null:
		return ""
	if not (rewards is Dictionary):
		return "棋盘奖励格式不对"
	var span := _board_span()
	var need := span.x * span.y
	for k in rewards:
		var key := str(k).strip_edges()
		if not key.is_valid_int():
			return "棋盘奖励下标不对"
		var i := int(key)
		if i < 0 or i >= need:
			return "棋盘奖励超出格子"
		var rw = rewards[k]
		if not (rw is Array) or rw.size() < 2 or str(rw[0]).strip_edges() == "":
			return "第 %d 格奖励没有物品" % (i + 1)
		if int(rw[1]) < 1:
			return "第 %d 格奖励数量至少是 1" % (i + 1)
		rw[0] = str(rw[0]).strip_edges()
		rw[1] = int(rw[1])
	return ""

func _check_rewards(groups: Array, where: String) -> String:
	for group in groups:
		if group is not Array:
			return "%s 的奖励格式不对" % where
		for rw in group:
			if rw is not Array or rw.size() < 2 or str(rw[0]).strip_edges() == "":
				return "%s 有奖励没有物品" % where
			rw[0] = str(rw[0]).strip_edges()
			if int(rw[1]) < 1:
				return "%s 的奖励数量至少是 1" % where
	return ""

func _fit_board() -> void:
	var rules: Dictionary = _pages[Files.RULES]
	var need := maxi(1, int(rules.get("cols", 7))) * maxi(1, int(rules.get("rows", 9)))
	var board: Dictionary = _pages[Files.BOARD]
	var cells: Array = board.get("cells", [])
	var before := cells.duplicate()
	while cells.size() < need:
		cells.append("")
	if cells.size() > need:
		board["cells"] = cells.slice(0, need)
		cells = board["cells"]
	if str(cells) != str(before):
		_dirty[Files.BOARD] = true
	var span := _board_span()
	if Layout.normalize(board, span.x, span.y):
		_dirty[Files.BOARD] = true
	if Layout.normalize_rewards(board, span.x, span.y):
		_dirty[Files.BOARD] = true

class BoardPad extends Control:
	const LIFT := Vector2(0, -14)

	var edit: CfgEdit
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
					edit._sc.yield_gesture()
				accept_event()
			else:
				if dragging:
					_drop(_cell_at(e.position))
				elif press_cell >= 0 and _cell_at(e.position) == press_cell:
					Sfx.play("tap")
					edit._open_pick("item", edit._set_cell.bind(press_cell), true, edit._board_item(press_cell))
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
					edit._sc.yield_gesture()
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
					edit._open_pick("item", edit._set_reward_item.bind(at), true, cur)
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
		for c in edit._root.get_children():
			if c.has_meta("reward_cell") and int(c.get_meta("reward_cell")) == cell:
				c.visible = show

	func _drop_reward(to: int) -> void:
		var from := drag_from
		if from >= 0 and to >= 0 and from != to and edit._swap_reward(from, to):
			Sfx.play("pop", 0.9)
			edit._rerender()
			return
		_reward_nums(from, true)

	func _lock_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				var n := _cell_at(e.position)
				hover = n
				if n >= 0:
					edit._sc.yield_gesture()
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
		var cells: Array = edit._pages[CfgEdit.Files.BOARD]["cells"]
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
		for c in edit._pages[CfgEdit.Files.CHAINS]:
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
