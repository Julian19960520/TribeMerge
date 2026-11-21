extends PopupBase
const PS := preload("res://scripts/sprites/popups.gd")
## 储物洞：山洞石壁上一层层木搁板，每层 5 格，往下无限加层；同排同价，每排 +10 琥珀。
## 已开的格子是石壁里凿出的小龛；下一格是可扩建的虚线格（点它或底部按钮扩建）；同一层剩下的位置是碎石堵着。
## 只给看得见的几层建控件（POOL_ROWS 层循环复用），格子再多界面节点数也不变。
const COLS := Data.STORAGE_COLS
const ROW_H := 126.0
const POOL_ROWS := 8
const SLOT := 108.0
const GAP_X := 122.0
const FR := Rect2(30, 300, 660, 880)
## 木牌下方到扩建按钮上方。标题下的说明和底部石台去掉后，格子区占满洞口。
const VIEW := Rect2(50, 372, 620, 676)
const DRAG_LIFT := Vector2(0, -28)
var scroll: Scroller
var slots: Array = []
var shelves: Array = []
var unlock: TButton
var _pad: Control
var _ghost: DrawBox
var _first_row := -1
var _busy := false
var _press_index := -1
var _press_pos := Vector2.ZERO
var _dragging := false
var _drag_from := -1
var _drag_id := ""
var _drag_chest := false
var _hover := -1
var _pops := {}

func _ready() -> void:
	UI.box(box, Rect2(0, 0, 720, 1480), _paint_frame)
	UI.title(box, TextCatalog.source("ui.inventorypopup.817cda7be380"), Rect2(230, 275, 260, 64), 42, Color.WHITE)
	var close_btn := UI.hit(box, Rect2(FR.end.x - 56, FR.position.y - 18, 70, 70), close)
	close_btn.extra = func(ci, sz): Paint.close_btn(ci, sz * 0.5, 28)
	scroll = Scroller.new()
	scroll.position = VIEW.position
	scroll.size = VIEW.size
	box.add_child(scroll)
	for r in POOL_ROWS:
		var sh := UI.box(scroll.content, Rect2(0, 0, VIEW.size.x, ROW_H), func(ci, sz): _paint_shelf(ci, sz), false)
		sh.set_meta("row", -1)
		shelves.append(sh)
	for k in POOL_ROWS * COLS:
		var b := UI.btn(scroll.content, Rect2(0, 0, SLOT, SLOT), "", "none", Callable())
		b.set_meta("slot", -1)
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.extra = func(ci, sz): _paint_slot(ci, sz, int(b.get_meta("slot")))
		slots.append(b)
	_pad = Control.new()
	_pad.mouse_filter = Control.MOUSE_FILTER_STOP
	_pad.size = VIEW.size
	_pad.gui_input.connect(_gesture)
	scroll.add_child(_pad)
	_ghost = UI.box(box, Rect2(Vector2.ZERO, box.size), _paint_ghost, false)
	_ghost.z_index = 40
	_ghost.visible = false
	unlock = UI.btn(box, Rect2(210, 1064, 300, 82), "", "green", _expand, 28)
	unlock.res = Art.AMBER_ICON
	unlock.name = "storage_expand"
	G.changed.connect(_refresh)
	G.board_changed.connect(_refresh)
	_refresh()

## 山洞外框：粗糙石壁 + 洞里暗处；顶上挂皮袋和木牌
func _paint_frame(ci: CanvasItem, _sz: Vector2) -> void:
	# 石壁、石块纹理、洞口
	Sprites.draw(ci, "pop_inv_frame", PS.INV_FRAME)
	Paint.vgrad(ci, Rect2(VIEW.position + Vector2(10, -12), Vector2(VIEW.size.x - 20, 40)), Color("2c2018"), Color("3a2a1f"))
	# 木牌 + 皮袋
	Sprites.draw(ci, "pop_inv_sign", PS.INV_SIGN)
	Paint.pouch(ci, Vector2(176, 307), 0.8)

## 一层木搁板：板子横穿整行，两头石钉托着（不再是每格一小截橙条）
func _paint_shelf(ci: CanvasItem, _sz: Vector2) -> void:
	Sprites.draw(ci, "pop_inv_shelf", PS.INV_SHELF)

func _paint_slot(ci: CanvasItem, sz: Vector2, index: int) -> void:
	if index < 0: return
	var cap := G.inv_cap
	var r := Rect2(Vector2(4, 4), sz - Vector2(8, 6))
	if index < cap:
		# 凿出来的石龛
		Sprites.draw(ci, "pop_inv_niche", r)
		var id := _slot_id(index)
		var held := _dragging and index == _drag_from
		if id != "" and not held:
			var sc := 1.0
			if _pops.has(index):
				sc = 1.0 + 0.22 * sin(PI * clampf(float(_pops[index]) / 0.28, 0.0, 1.0))
			Sprites.at(ci, "pop_spot_shadow", Vector2(sz.x * 0.5, sz.y - 14), 1.0, 0.0, Color(0, 0, 0, 0.35))
			Art.item(ci, Art.chest_visual(id, G.inv_chests.has(str(index))), sz * 0.5 + Vector2(0, -2), 86.0 * sc)
		if _dragging and index == _hover:
			var col := Color("7dbe6a") if _can_merge(index) else Color("f0b429")
			ci.draw_arc(sz * 0.5 + Vector2(0, -2), 46.0, 0.0, TAU, 28, col, 5.0, true)
	elif index == cap:
		# 下一格：虚线框 + 加号 + 价格（点它扩建）
		Sprites.draw(ci, "pop_inv_next", r)
		Art.item(ci, Art.AMBER_ICON, Vector2(30, 82), 30, false)
		var f: Font = G.font_body
		var t := str(G.rules.progression.storage_price())
		ci.draw_string_outline(f, Vector2(46, 91), TextCatalog.resolve(t), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 5, Art.INK)
		ci.draw_string(f, Vector2(46, 91), TextCatalog.resolve(t), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	else:
		# 还没挖开：碎石堵着（离可扩建那格越远越暗）
		Sprites.draw(ci, "pop_inv_rocks", r)

func _process(delta: float) -> void:
	if scroll != null: _layout()
	_tick_drag(delta)

## 至少铺满可视区（后面几层是还没挖开的碎石壁），格子少时洞里也不会空一大片
func _rows() -> int:
	return maxi(int(ceil(float(G.inv_cap + 1) / COLS)), int(ceil(VIEW.size.y / ROW_H)))

func _layout(force := false) -> void:
	var first := maxi(0, int(scroll.offset / ROW_H) - 1)
	if first == _first_row and not force: return
	_first_row = first
	var rows := _rows()
	for r in shelves.size():
		var row := first + r
		var sh: DrawBox = shelves[r]
		sh.visible = row < rows
		sh.position = Vector2(0, 8 + row * ROW_H)
		sh.set_meta("row", row)
	for k in slots.size():
		var index := first * COLS + k
		var b: TButton = slots[k]
		b.visible = index < rows * COLS
		b.position = Vector2(8 + (index % COLS) * GAP_X, 8 + (index / COLS) * ROW_H)
		b.set_meta("slot", index)
		b.modulate = Color(0.72, 0.68, 0.64) if index / COLS > G.inv_cap / COLS else Color.WHITE
		b.queue_redraw()

func _refresh() -> void:
	if scroll == null: return
	unlock.text = TextCatalog.resolve(TextCatalog.fill(TextCatalog.source("ui.inventorypopup.4b4bdd4a1307"), G.rules.progression.storage_price()))
	unlock.enabled = not _busy
	unlock.queue_redraw()
	scroll.set_length(_rows() * ROW_H + 24)
	_layout(true)

func _take(index: int) -> void:
	if _busy: return
	if index == G.inv_cap:
		_expand()
		return
	if _slot_id(index) == "": return
	var to := G.rules.board.find_empty_near(G.rules.board.idx(3, 4))
	if to < 0:
		G.main.toast(TextCatalog.source("ui.inventorypopup.0b563d7d1026"))
		return
	var result: Dictionary = Replay.perform("inventory", {"index": index})
	if result.has("error"): G.main.toast(str(result["error"]))
	else: Sfx.play("pop")

func _expand() -> void:
	if _busy: return
	if G.amber < G.rules.progression.storage_price():
		G.main.toast(TextCatalog.source("ui.inventorypopup.ad2801cad3fd"))
		Sfx.play("deny")
		return
	_busy = true
	_refresh()
	var success := await G.expand_storage()
	if not is_instance_valid(self): return
	_busy = false
	if success:
		_refresh()
		var row := int(G.inv_cap / COLS)
		if row * ROW_H + ROW_H > scroll.offset + scroll.size.y: scroll.jump_to(row * ROW_H + ROW_H + 16 - scroll.size.y)
		_layout(true)
		Sfx.play("merge", 1.2)
	else:
		G.main.toast(TextCatalog.source("ui.inventorypopup.ad2801cad3fd"))
		_refresh()

func _slot_id(index: int) -> String:
	if index < 0 or index >= G.inv.size(): return ""
	return str(G.inv[index])

func _slot_at(local: Vector2) -> int:
	var p := local + Vector2(0, scroll.offset)
	var x := p.x - 8.0
	var y := p.y - 8.0
	if x < 0.0 or y < 0.0: return -1
	var col := int(x / GAP_X)
	var row := int(y / ROW_H)
	if col < 0 or col >= COLS: return -1
	if fposmod(x, GAP_X) >= SLOT or fposmod(y, ROW_H) >= SLOT: return -1
	var index := row * COLS + col
	if index < 0 or index >= _rows() * COLS: return -1
	return index

func _can_merge(index: int) -> bool:
	var id := _slot_id(index)
	return id != "" and id == _drag_id and Data.next_id(id) != "" and not _drag_chest and not G.inv_chests.has(str(index))

func _gesture(e: InputEvent) -> void:
	if _busy: return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_press_index = _slot_at(e.position)
			_press_pos = e.position
			_clear_drag()
			if _slot_id(_press_index) != "": scroll.yield_gesture()
			accept_event()
		else:
			var index := _slot_at(e.position)
			var from := _drag_from
			var moved := _dragging
			var tapped: bool = _press_index >= 0 and index == _press_index and e.position.distance_to(_press_pos) <= 12.0
			_clear_drag()
			if moved: _finish_drag(from, index)
			elif tapped: _take(_press_index)
			accept_event()
	elif e is InputEventMouseMotion and _press_index >= 0 and _slot_id(_press_index) != "":
		if not _dragging and e.position.distance_to(_press_pos) > 12.0:
			_dragging = true
			_drag_from = _press_index
			_drag_id = _slot_id(_press_index)
			_drag_chest = G.inv_chests.has(str(_press_index))
			scroll.yield_gesture()
			_ghost.visible = true
			Sfx.play("tap", 1.3)
			for b in slots: b.queue_redraw()
		if _dragging: accept_event()

func _finish_drag(from: int, index: int) -> void:
	if from < 0 or index < 0 or index >= G.inv_cap or index == from:
		if index != from: Sfx.play("deny")
		return
	var result: Dictionary = Replay.perform("inventory_move", {"from": from, "to": index})
	if result.has("error") or not result.get("ok", false):
		Sfx.play("deny")
		return
	_pops[index] = 0.0
	if str(result.get("kind", "")) == "merge": Sfx.play("merge", 1.05)
	else: Sfx.play("pop", 0.9)

func _clear_drag() -> void:
	_dragging = false
	_drag_from = -1
	_drag_id = ""
	_drag_chest = false
	_hover = -1
	if _ghost != null: _ghost.visible = false
	for b in slots: b.queue_redraw()

func _tick_drag(delta: float) -> void:
	var popping := not _pops.is_empty()
	for k in _pops.keys():
		_pops[k] = float(_pops[k]) + delta
		if float(_pops[k]) >= 0.28: _pops.erase(k)
	if popping:
		for b in slots: b.queue_redraw()
	if not _dragging or _pad == null: return
	var local := _pad.get_local_mouse_position()
	var edge := 72.0
	var speed := 0.0
	if local.y < edge: speed = -lerpf(120.0, 640.0, 1.0 - clampf(local.y / edge, 0.0, 1.0))
	elif local.y > _pad.size.y - edge: speed = lerpf(120.0, 640.0, clampf((local.y - (_pad.size.y - edge)) / edge, 0.0, 1.0))
	if speed != 0.0:
		scroll.offset = clampf(scroll.offset + speed * delta, 0.0, maxf(0.0, scroll.length - scroll.size.y))
		scroll.content.position = Vector2(0, -scroll.offset)
		_layout(true)
	var hover := _slot_at(local)
	_hover = hover if hover >= 0 and hover < G.inv_cap and hover != _drag_from else -1
	for b in slots: b.queue_redraw()
	_ghost.queue_redraw()

func _paint_ghost(ci: CanvasItem, _sz: Vector2) -> void:
	if not _dragging or _drag_id == "": return
	var at: Vector2 = _ghost.get_global_transform().affine_inverse() * _pad.get_global_mouse_position() + DRAG_LIFT
	Art.item(ci, Art.chest_visual(_drag_id, _drag_chest), at, 98.0, true)
