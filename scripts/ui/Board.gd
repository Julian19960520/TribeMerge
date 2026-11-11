class_name Board
extends Control
## 7×9 合成棋盘

const Layout := preload("res://scripts/config/board_layout.gd")
const DropRing := preload("res://scripts/ui/board/BoardDropRing.gd")
const MergeBurst := preload("res://scripts/ui/board/BoardMergeBurst.gd")

signal selected_changed(i: int)
signal activated(i: int)
signal dropped_outside(i: int, global_pos: Vector2)

const CELL := 96.0
const ITEM := 84.0

## Offline-baked assets. Runtime only submits textured quads; source art lives in tools/.
const BOARD_FRAMES := [preload("res://assets/board/frame_0.png"), preload("res://assets/board/frame_1.png"), preload("res://assets/board/frame_2.png"), preload("res://assets/board/frame_3.png")]
const ROCK_FRAMES := [preload("res://assets/board/rocks_0.png"), preload("res://assets/board/rocks_1.png"), preload("res://assets/board/rocks_2.png"), preload("res://assets/board/rocks_3.png")]
const FLOOR_TILE := preload("res://assets/board/floor.png")
const ROCK_CRACKS := preload("res://assets/board/cracks.png")
const ROCK_BITS := preload("res://assets/board/fragments.png")
const MAX_CROWN := preload("res://assets/ui/max_crown.svg")

var _base_layers: Array[DrawBox] = []
var _cell_layers: Array[DrawBox] = []
var _drop_ring := DropRing.new()
var _continuous_cells: Dictionary = {}
var _previous_live: Dictionary = {}
var _second := 0.0
var frame_updates := 0
var cell_paints := 0
var effect_paints := 0

var selected := -1
var press_cell := -1
var press_pos := Vector2.ZERO
var dragging := false
## 新手引导把拖着的物品画在遮罩上面，棋盘这边就不再画一份
var hide_drag := false
var drag_from := -1
var drag_pos := Vector2.ZERO
var drag_vis := Vector2.ZERO
var pops := {}
var hid := {}
var flights: Array = []
var moves: Array = []
var bursts: Array = []
var crumbles: Array = []
var gathers: Array = []
## 同一帧裂开的奖励收成一批，再弹出全屏领取面板
var _reward_q: Array = []
var _reward_flush := false
var shakes := {}
## 关掉物品信息后，来源生产器放大再收回
var bounces := {}
var _t := 0.0
var _idle := 0.0
var _hint_a := -1
var _hint_b := -1
var _hint_t := 0.0
var _hint_dirty := true

const DRAG_LIFT := Vector2(0, -14)
const MOVE_DUR := 0.26
## 物品只是某张订单的一部分，底色用普通绿。
const ORDER_PART := Color("a8d86a")
## 和上面同一个色相，更亮一些，饱和度只略高。这单需求已经齐了才用。
const ORDER_FULL := Color("aaf745")
## 石头先裂开，再碎开飞出去
const CRUMBLE_HOLD := 0.1
const CRUMBLE_DUR := 0.62
## 停手这么久，就让一对能合成的物品呼吸
const HINT_WAIT := 5.0

func _ready() -> void:
	size = Vector2(G.COLS * CELL, G.ROWS * CELL)
	mouse_filter = MOUSE_FILTER_STOP
	G.boil_tick.connect(_on_boil)
	G.board_changed.connect(_invalidate_base)
	G.orders_changed.connect(_invalidate_base)
	for phase in 4:
		var layer := UI.box(self, Rect2(Vector2.ZERO, size), func(ci, _sz):
			var previous := Art.boil
			Art.boil = phase
			_draw_base(ci)
			Art.boil = previous, false)
		layer.show_behind_parent = true
		_base_layers.append(layer)
	for i in G.board.size():
		var layer := UI.box(self, Rect2(Vector2.ZERO, size), func(ci, _sz): _paint_cell(ci, i), false)
		layer.show_behind_parent = true
		_cell_layers.append(layer)
	_refresh_continuous_cells()
	_sync_base()
	G.board_changed.connect(_redraw_cells)
	G.changed.connect(_redraw_cells)
	G.board_changed.connect(queue_redraw)
	G.orders_changed.connect(queue_redraw)
	call_deferred("_grant_loose_rewards")

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	frame_updates += 1
	_t += delta
	_tick_hint(delta)
	if dragging and not G.rules.board.can_move(drag_from):
		dragging = false
		drag_from = -1
		press_cell = -1
		queue_redraw()
	if dragging:
		drag_vis = drag_pos
	_tick_drop_ring(delta)
	for m in moves:
		m["t"] += delta / float(m["dur"])
	for m in moves.duplicate():
		if m["t"] >= 1.0:
			moves.erase(m)
			_move_done(m)
	for g in gathers:
		if float(g.get("delay", 0.0)) > 0.0:
			g["delay"] = maxf(float(g["delay"]) - delta, 0.0)
			continue
		g["t"] += delta / 0.36
	for g in gathers.duplicate():
		if g["t"] >= 1.0:
			gathers.erase(g)
	if not G.cooked_pop.is_empty():
		for i in G.cooked_pop:
			burst(int(i))
			pop(int(i))
		G.cooked_pop.clear()
	var busy := dragging or selected >= 0 or not flights.is_empty() or not bursts.is_empty() or not moves.is_empty() or not crumbles.is_empty() or not gathers.is_empty()
	for k in pops.keys():
		pops[k] += delta
		if pops[k] > 0.35:
			pops.erase(k)
	for k in shakes.keys():
		shakes[k] += delta
		if shakes[k] > 0.35:
			shakes.erase(k)
	for k in bounces.keys():
		bounces[k] = float(bounces[k]) + delta
		if float(bounces[k]) > 0.42:
			bounces.erase(k)
	for f in flights:
		if float(f.get("delay", 0.0)) > 0.0:
			f["delay"] = maxf(float(f["delay"]) - delta, 0.0)
			continue
		f["t"] += delta / 0.28
	for f in flights.duplicate():
		if f["t"] >= 1.0:
			flights.erase(f)
			_unhide(f["to"])
			pop(f["to"])
	for b in bursts:
		b["t"] += delta
	bursts = bursts.filter(func(b): return b["t"] < 0.6)
	var left: Array = []
	var cracked := false
	for c in crumbles:
		if float(c["delay"]) > 0.0:
			c["delay"] = float(c["delay"]) - delta
			if float(c["delay"]) > 0.0:
				left.append(c)
				continue
			c["delay"] = 0.0
			c["t"] = 0.0
			cracked = true
			_pay_crumble(c)
			left.append(c)
			continue
		_pay_crumble(c)
		c["t"] = float(c["t"]) + delta
		if float(c["t"]) < CRUMBLE_DUR:
			left.append(c)
	crumbles = left
	if cracked:
		Sfx.play("crumble", 0.94 + randf() * 0.08)
	_redraw_live_cells()
	_second += delta
	if _second >= 1.0:
		_second = fmod(_second, 1.0)
		_redraw_cells() # Generator countdown labels change at most once per second.
	if busy: queue_redraw()

func set_active(active: bool) -> void:
	if not active:
		dragging = false
		drag_from = -1
		press_cell = -1
		selected = -1
		hid.clear()
		moves.clear()
		flights.clear()
		gathers.clear()
		crumbles.clear() # Unclaimed stone rewards remain in business state.
		pops.clear()
		bounces.clear()
		shakes.clear()
		bursts.clear()
		_clear_drop_ring()
		_clear_hint()
	else:
		_refresh_continuous_cells()
		_invalidate_base()
		_redraw_cells()
		_sync_base()
		_grant_loose_rewards.call_deferred()
		queue_redraw()

func _on_boil() -> void:
	if not is_visible_in_tree(): return
	_sync_base()
	_redraw_cells()

func _refresh_continuous_cells() -> void:
	_continuous_cells.clear()
	for i in G.board.size():
		var cell: Dictionary = G.board[i]
		if cell.get("ck") is Dictionary or cell.has("rw") or int(cell.get("lock", 0)) == 3:
			_continuous_cells[i] = true

func _redraw_cells() -> void:
	if not is_visible_in_tree(): return
	for layer in _cell_layers: layer.queue_redraw()

func _redraw_live_cells() -> void:
	var live := _continuous_cells.duplicate()
	for transient in [pops, bounces, shakes, hid]:
		for i in transient: live[i] = true
	for crumble in crumbles: live[int(crumble["i"])] = true
	for i in [_hint_a, _hint_b, drag_from]:
		if i >= 0: live[i] = true
	for i in _previous_live:
		if not live.has(i) and int(i) < _cell_layers.size(): _cell_layers[i].queue_redraw()
	for i in live:
		if int(i) < _cell_layers.size(): _cell_layers[i].queue_redraw()
	_previous_live = live

func _paint_cell(ci: CanvasItem, i: int) -> void:
	if i >= G.board.size() or (i == drag_from and dragging) or hid.has(i): return
	cell_paints += 1
	_draw_cell(i, ci)

func cell_rect(i: int) -> Rect2:
	return Rect2(Vector2(i % G.COLS, i / G.COLS) * CELL, Vector2(CELL, CELL))

func cell_center(i: int) -> Vector2:
	return cell_rect(i).get_center()

func cell_global(i: int) -> Vector2:
	return get_global_transform() * cell_center(i)

func cell_at(p: Vector2) -> int:
	return MergeGrid.cell_at(p, CELL, G.COLS, G.ROWS)

func pop(i: int) -> void:
	pops[i] = 0.0

## 棋盘上这条生产器链的格子，各放大一次。面板先收起，所以晚一拍再开始。
func pulse_chain(chain_id: String) -> void:
	if chain_id == "":
		return
	for i in G.board.size():
		var id := str(G.board[i]["id"])
		if id == "" or int(G.board[i]["lock"]) == 2:
			continue
		if Data.chain(id) != chain_id:
			continue
		bounces[i] = -0.12
	if not bounces.is_empty():
		queue_redraw()

func shake(i: int) -> void:
	shakes[i] = 0.0

func burst(i: int) -> void:
	bursts.append({"p": cell_center(i), "t": 0.0, "seed": randi() % 1000})

## 石头已经不在了，奖励还挂着：上次裂到一半就存档，进棋盘时补发。
func _grant_loose_rewards() -> void:
	for i in G.board.size():
		var cell: Dictionary = G.board[i]
		if Layout.parse_reward(cell.get("rw", null)).is_empty():
			continue
		if int(cell["lock"]) == 2:
			continue
		if not _crumble_for(i).is_empty():
			continue
		_release_reward(i)

func _pay_crumble(c: Dictionary) -> void:
	if bool(c.get("paid", false)):
		return
	c["paid"] = true
	_release_reward(int(c["i"]))

## 气泡裂开：先弹出全屏领取面板，点一下再入账。奖励先留在格子上，关掉游戏也不会丢。
func _release_reward(i: int) -> void:
	if i < 0 or i >= G.board.size():
		return
	var rw := Layout.parse_reward(G.board[i].get("rw", null))
	if rw.is_empty():
		return
	for e in _reward_q:
		if int(e["i"]) == i:
			return
	_reward_q.append({"i": i, "id": str(rw[0]), "n": int(rw[1])})
	if _reward_flush:
		return
	_reward_flush = true
	call_deferred("_flush_rewards")

func _flush_rewards() -> void:
	_reward_flush = false
	if _reward_q.is_empty():
		return
	var batch: Array = _reward_q.duplicate()
	_reward_q.clear()
	if G.main == null:
		_grant_board_now(batch)
		return
	G.main.present_board_reward(batch)

func _grant_board_now(batch: Array) -> void:
	for entry in batch:
		var index := int(entry["i"])
		if index >= 0 and index < G.board.size(): Replay.perform("bubble_reward", {"cell": index})

func _draw_reward_bubble(i: int, r: Rect2, ci: CanvasItem = null) -> void:
	if ci == null: ci = self
	var rw := Layout.parse_reward(G.board[i].get("rw", null))
	if rw.is_empty():
		return
	var rad := 30.0
	var c := r.position + Vector2(r.size.x * 0.62, r.size.y * 0.34)
	var lift := sin(_t * 3.2 + float(i) * 0.7) * 3.0
	Paint.reward_bubble(ci, c, rad, rw[0], int(rw[1]), i, lift)

## 巨石崩开。delay 用来等到合成滑到位再裂
func crumble(i: int, delay: float = 0.0) -> void:
	crumbles.append({"i": i, "t": 0.0, "delay": delay})
	queue_redraw()

func fly_in(from_i: int, to_i: int, id: String) -> void:
	hid[to_i] = int(hid.get(to_i, 0)) + 1
	flights.append({"from": cell_center(from_i), "to": to_i, "id": id, "t": 0.0})

func play_gather(parts: Array) -> void:
	for p in parts:
		gathers.append({
			"from": cell_center(int(p["from"])),
			"to": int(p["to"]),
			"id": str(p["id"]),
			"t": 0.0,
			"delay": float(p.get("delay", 0.0)),
		})
	queue_redraw()

func fly_in_from(global_from: Vector2, to_i: int, id: String, delay: float = 0.0) -> void:
	hid[to_i] = int(hid.get(to_i, 0)) + 1
	flights.append({"from": get_global_transform().affine_inverse() * global_from, "to": to_i, "id": id, "t": 0.0, "delay": delay})

func conceal(i: int) -> void:
	hid[i] = int(hid.get(i, 0)) + 1

func arrive(i: int) -> void:
	_unhide(i)
	pop(i)
	queue_redraw()

func select(i: int) -> void:
	selected = i
	selected_changed.emit(i)
	queue_redraw()

## 物品从 from（本地坐标）滑到格子 to，带 back 缓动；滑动期间该格不绘制。cook 非空时滑的是制作中的锅。
func slide(id: String, from: Vector2, to: int, under: String = "", done: String = "pop", dur: float = MOVE_DUR, cook: Dictionary = {}) -> void:
	hid[to] = int(hid.get(to, 0)) + 1
	moves.append({"id": id, "from": from, "to": to, "under": under, "done": done, "t": 0.0, "dur": dur, "cook": cook})

func cancel_slides(i: int) -> void:
	for m in moves.duplicate():
		if m["to"] == i:
			moves.erase(m)
			_unhide(i)

## 玩家手快，格子上的动画还没播完就要拿或放：直接把裂石、滑入、飞入收尾，逻辑状态早已就绪。
## 返回这格现在能不能当作静止的格子来操作。
func _settle(i: int) -> bool:
	if i < 0:
		return false
	var kept: Array = []
	for c in crumbles:
		if int(c["i"]) == i:
			_pay_crumble(c)
		else:
			kept.append(c)
	crumbles = kept
	for m in moves.duplicate():
		if m["to"] == i:
			moves.erase(m)
			_move_done(m)
	for f in flights.duplicate():
		if f["to"] == i:
			flights.erase(f)
			_unhide(i)
			pop(i)
	queue_redraw()
	return not hid.has(i)

func _unhide(i: int) -> void:
	var n := int(hid.get(i, 0)) - 1
	if n <= 0:
		hid.erase(i)
	else:
		hid[i] = n

func _move_done(m: Dictionary) -> void:
	var i: int = m["to"]
	_unhide(i)
	match m["done"]:
		"merge":
			Sfx.play("merge", 0.9 + 0.08 * float(Data.lv(G.rules.board.cell_id(i))))
			burst(i)
			pop(i)
		"pop":
			pop(i)
	queue_redraw()

static func ease_back(t: float) -> float:
	return MergeGrid.ease_back(t)

# ---------------------------------------------------------------- 输入

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		dragging = false
		drag_from = -1
		press_cell = -1
		_clear_drop_ring()
		queue_redraw()

func _clear_drop_ring() -> void:
	_drop_ring.clear()
	queue_redraw()

## Mirror the actual drop branches without executing a command or changing rules.
func _drop_hover_kind(to: int) -> String:
	if not dragging or to < 0 or to >= G.board.size() or to == drag_from: return ""
	if not G.rules.board.can_move(drag_from) or G._chest_busy.has(to): return ""
	if not _guide_allows_drop(drag_from, to): return ""
	if G.rules.orders.cooking(drag_from) or G.rules.orders.cooking(to): return ""
	if G.rules.board.is_merge_bubble(drag_from) or G.rules.board.is_merge_bubble(to): return ""
	if Data.type_of(G.rules.board.cell_id(drag_from)) in ["upgrade", "scissors"]:
		return G.rules.board.tool_drop_kind(drag_from, to)
	return "merge" if MergeGrid.drop_kind(G.board, drag_from, to, Data.next_id) == "merge" else ""

func _tick_drop_ring(delta: float) -> void:
	if dragging and G.main != null and G.main.popup_layer != null and G.main.popup_layer.get_child_count() > 0:
		dragging = false
		drag_from = -1
		press_cell = -1
		queue_redraw()
	if not dragging:
		if _drop_ring.target >= 0: _clear_drop_ring()
		return
	var to := cell_at(drag_pos)
	var kind := _drop_hover_kind(to)
	if _drop_ring.tick(delta, to if kind != "" else -1, kind):
		queue_redraw()

func _input(e: InputEvent) -> void:
	var down := false
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		down = true
	elif e is InputEventScreenTouch and e.pressed:
		down = true
	if down:
		_clear_hint()

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			press_cell = cell_at(e.position)
			press_pos = e.position
			dragging = false
			_clear_drop_ring()
		else:
			if dragging:
				_drop(e.position)
			elif press_cell >= 0 and cell_at(e.position) == press_cell:
				_tap(press_cell)
			press_cell = -1
			dragging = false
			drag_from = -1
			_clear_drop_ring()
			queue_redraw()
	elif e is InputEventMouseMotion and press_cell >= 0:
		if not dragging and e.position.distance_to(press_pos) > 10.0:
			var c: Dictionary = G.board[press_cell]
			var held: bool = str(c["id"]) != "" or G.rules.orders.cooking(press_cell)
			if held and G.rules.board.can_move(press_cell) and _settle(press_cell):
				dragging = true
				drag_from = press_cell
				drag_vis = e.position
				select(press_cell)
				Sfx.play("tap", 1.3)
		if dragging:
			# 物品直接贴着手指，不做缓动
			drag_pos = e.position
			drag_vis = e.position
			queue_redraw()

func _tap(i: int) -> void:
	_settle(i)
	var c: Dictionary = G.board[i]
	if G.rules.orders.cooking(i):
		if selected == i:
			if G.main:
				G.main.toast("还在制作，还要 %s" % _sec_text(G.rules.orders.cook_left(i)))
			shake(i)
			Sfx.play("deny")
			return
		Sfx.play("tap")
		select(i)
		return
	if c["id"] == "" and int(c["lock"]) != 2:
		select(-1)
		return
	if int(c["lock"]) == 2:
		# 巨石只能看说明，晃一下表示推不动
		Sfx.play("tap")
		shake(i)
		select(i)
		return
	if (selected == i or Data.type_of(str(c["id"])) in ["choice", "chest"]) and c["lock"] == 0:
		pop(i)
		activated.emit(i)
	else:
		Sfx.play("tap")
		pop(i)
		select(i)

func _drop(p: Vector2) -> void:
	var from := drag_from
	if not G.rules.board.can_move(from):
		select(-1)
		return
	var vis := drag_vis + DRAG_LIFT
	var id_from := G.rules.board.cell_id(from)
	var cook_from := _cook_copy(from)
	var to := cell_at(p)
	if to < 0:
		slide(id_from, vis, from, "", "pop", MOVE_DUR, cook_from)
		dropped_outside.emit(from, get_global_transform() * p)
		return
	if to != from:
		_settle(to)
	if not _guide_allows_drop(from, to):
		slide(id_from, vis, from, "", "pop", MOVE_DUR, cook_from)
		if to != from:
			Sfx.play("deny")
			shake(to)
		return
	var id_to := G.rules.board.cell_id(to)
	var cook_to := _cook_copy(to)
	var res := G.try_drop(from, to)
	match res:
		"upgrade":
			slide(id_from, vis, to, id_to, "merge", 0.16)
			select(to)
		"split":
			Sfx.play("pop", 0.85)
			slide(G.rules.board.cell_id(from), cell_center(to), from, "", "pop", MOVE_DUR)
			slide(G.rules.board.cell_id(to), cell_center(to), to, "", "pop", MOVE_DUR)
			burst(to)
			select(to)
		"merge":
			var merge_t := 0.16
			slide(id_from, vis, to, id_to, "merge", merge_t)
			for k in G.opened:
				crumble(int(k), merge_t)
			select(to)
			if G.main:
				G.main.on_merged(to)
		"move", "swap":
			Sfx.play("pop", 0.9)
			slide(id_from, vis, to, "", "pop", MOVE_DUR, cook_from)
			if res == "swap":
				slide(id_to, cell_center(to), from, "", "pop", MOVE_DUR, cook_to)
			_retarget_gathers(from, to, cook_from, cook_to)
			select(to)
		_:
			slide(id_from, vis, from, "", "pop", MOVE_DUR, cook_from)
			if to != from:
				Sfx.play("deny")
				shake(to)

func _cook_copy(i: int) -> Dictionary:
	if not G.rules.orders.cooking(i):
		return {}
	return (G.board[i]["ck"] as Dictionary).duplicate(true)

func _retarget_gathers(from: int, to: int, cook_from: Dictionary, cook_to: Dictionary) -> void:
	for g in gathers:
		var dest: int = int(g["to"])
		if not cook_from.is_empty() and dest == from:
			g["to"] = to
		elif not cook_to.is_empty() and dest == to:
			g["to"] = from

# ---------------------------------------------------------------- 绘制

func _draw_base(ci: CanvasItem) -> void:
	ci.draw_texture_rect(BOARD_FRAMES[Art.boil % 4], Rect2(Vector2(-20, -20), size + Vector2(40, 40)), false)
	var tone := G.rules.orders.order_cell_tone()
	for i in G.board.size():
		var r := cell_rect(i)
		var c: Dictionary = G.board[i]
		var col := Art.HIDE if (i % G.COLS + i / G.COLS) % 2 == 0 else Color("f0dcb4")
		if typeof(c.get("ck")) == TYPE_DICTIONARY:
			col = Color("f6c56b")
		elif c["lock"] == 0 and not hid.has(i) and i < tone.size():
			if tone[i] == 2:
				col = ORDER_FULL
			elif tone[i] == 1:
				col = ORDER_PART
		ci.draw_texture_rect_region(FLOOR_TILE, r, _floor_region(i), col)
	for i in G.board.size():
		if int(G.board[i]["lock"]) == 2:
			_paint_rock(ci, cell_rect(i), i)

func _sync_base() -> void:
	for phase in _base_layers.size():
		RenderingServer.canvas_item_set_visible(_base_layers[phase].get_canvas_item(), phase == Art.boil)

func _invalidate_base() -> void:
	_hint_dirty = true
	_refresh_continuous_cells()
	for layer in _base_layers:
		layer.queue_redraw()

func _draw() -> void:
	effect_paints += 1
	var sel_c := cell_center(selected) if selected >= 0 else Vector2.ZERO
	for m in moves:
		var to := cell_center(m["to"])
		var p: Vector2 = m["from"].lerp(to, ease_back(clampf(m["t"], 0.0, 1.0)))
		if m["under"] != "":
			Art.item(self, m["under"], to, ITEM)
		var cook: Dictionary = m.get("cook", {})
		if not cook.is_empty():
			_draw_cook(int(m["to"]), Rect2(p - Vector2(CELL, CELL) * 0.5, Vector2(CELL, CELL)), cook)
		elif G.rules.board.is_merge_bubble(int(m["to"])):
			_draw_merge_bubble(int(m["to"]), p, 1.0)
		else:
			Art.item(self, m["id"], p, ITEM * lerpf(1.15, 1.0, clampf(m["t"] * 1.5, 0.0, 1.0)))
		if m["to"] == selected and m["under"] == "":
			sel_c = p
	if selected >= 0 and not dragging:
		var pulse := 1.0 + 0.04 * sin(_t * 6.0)
		var sz := Vector2(CELL, CELL) * pulse
		Paint.cell_bracket(self, Rect2(sel_c - sz * 0.5, sz).grow(-4))
	for f in flights:
		if float(f.get("delay", 0.0)) > 0.0:
			continue
		var t: float = f["t"]
		var e := 1.0 - pow(1.0 - t, 3.0)
		var to := cell_center(f["to"])
		var p: Vector2 = f["from"].lerp(to, e) + Vector2(0, -80.0 * sin(PI * t))
		Art.item(self, f["id"], p, ITEM * (0.7 + 0.3 * e))
	for g in gathers:
		if float(g.get("delay", 0.0)) > 0.0:
			Art.item(self, str(g["id"]), g["from"], ITEM)
			continue
		var gt: float = clampf(g["t"], 0.0, 1.0)
		var ge := 1.0 - pow(1.0 - gt, 3.0)
		var gto := cell_center(int(g["to"])) + Vector2(0, -10)
		var gp: Vector2 = (g["from"] as Vector2).lerp(gto, ge)
		gp.y -= 40.0 * sin(PI * gt)
		Art.item(self, str(g["id"]), gp, ITEM * lerpf(1.0, 0.28, gt))
	for b in bursts:
		_draw_burst(b)
	for c in crumbles:
		if float(c["delay"]) <= 0.0 and float(c["t"]) >= CRUMBLE_HOLD:
			_draw_crumble(c)
	if _drop_ring.target >= 0:
		_drop_ring.paint(self, cell_center(_drop_ring.target), CELL)
	if dragging and drag_from >= 0:
		var r0 := cell_rect(drag_from)
		draw_rect(r0.grow(-6), Color(0.3, 0.2, 0.1, 0.12))
		if not hide_drag:
			var at := drag_vis + DRAG_LIFT
			if G.rules.orders.cooking(drag_from):
				_draw_cook(drag_from, Rect2(at - Vector2(CELL, CELL) * 0.5, Vector2(CELL, CELL)), G.board[drag_from]["ck"])
			elif G.rules.board.is_merge_bubble(drag_from):
				_draw_merge_bubble(drag_from, at, 1.15)
			else:
				var tilt := clampf((drag_pos.x - drag_vis.x) * 0.004, -0.25, 0.25)
				Art.item(self, G.board[drag_from]["id"], at, ITEM * 1.15, true, tilt)

func _draw_cell(i: int, ci: CanvasItem = null) -> void:
	if ci == null: ci = self
	var c: Dictionary = G.board[i]
	var r := cell_rect(i)
	var ctr := r.get_center()
	var sc := 1.0
	if pops.has(i):
		var t: float = pops[i] / 0.35
		sc = 1.0 + 0.28 * sin(PI * t) * (1.0 - t * 0.5)
	if bounces.has(i):
		var bt: float = float(bounces[i])
		if bt >= 0.0:
			sc *= 1.0 + 0.34 * sin(PI * clampf(bt / 0.42, 0.0, 1.0))
	if shakes.has(i):
		ctr.x += sin(shakes[i] * 60.0) * 6.0 * (1.0 - shakes[i] / 0.35)
	var cu := _crumble_for(i)
	var cracking := not cu.is_empty() and float(cu["delay"]) <= 0.0 and float(cu["t"]) < CRUMBLE_HOLD
	if c["lock"] == 2 or (not cu.is_empty() and float(cu["delay"]) > 0.0) or cracking:
		var rr := r
		if cracking:
			var u := float(cu["t"]) / CRUMBLE_HOLD
			rr.position.x += sin(float(cu["t"]) * 90.0) * 3.0 * (1.0 - u)
		if int(c["lock"]) != 2 or cracking:
			_draw_rock(rr, i, ci)
		if cracking:
			_draw_rock_cracks(rr, i, float(cu["t"]) / CRUMBLE_HOLD, ci)
		_draw_reward_bubble(i, rr, ci)
		return
	var reveal := 1.0
	if not cu.is_empty() and float(cu["delay"]) <= 0.0:
		reveal = clampf((float(cu["t"]) - CRUMBLE_HOLD) / 0.22, 0.0, 1.0)
		sc *= lerpf(0.62, 1.0, reveal)
	if typeof(c.get("ck")) == TYPE_DICTIONARY:
		_draw_cook(i, r, c["ck"], ci)
		return
	if c["id"] == "":
		return
	if G.rules.board.is_merge_bubble(i):
		_draw_merge_bubble(i, ctr, sc, ci)
		return
	var prod := not Data.gen_stats(c["id"]).is_empty()
	if c["lock"] == 0 and prod and reveal > 0.65:
		Sprites.draw(ci, "board_prod_glow", r.grow(-6))
	var breath := 1.0
	var nudge := Vector2.ZERO
	if i == _hint_a or i == _hint_b:
		breath = _breath_scale()
		nudge = _breath_nudge(i)
		sc *= breath
	if c["lock"] == 1:
		if breath != 1.0 or nudge != Vector2.ZERO:
			ci.draw_set_transform(ctr * (1.0 - breath) + nudge, 0.0, Vector2(breath, breath))
		_draw_vine(r, i, true, ci) # 后面那根：先画，被物品挡住中段
		if breath != 1.0 or nudge != Vector2.ZERO:
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	Art.item(ci, c["id"], ctr + nudge, ITEM * sc)
	if c["lock"] == 1:
		if breath != 1.0 or nudge != Vector2.ZERO:
			ci.draw_set_transform(ctr * (1.0 - breath) + nudge, 0.0, Vector2(breath, breath))
		_draw_vine(r, i, false, ci)
		if breath != 1.0 or nudge != Vector2.ZERO:
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	elif reveal > 0.65 and _is_max_currency(str(c["id"])):
		_draw_max_badge(r, ci)
	elif prod and reveal > 0.65:
		var wait := G.rules.board.gen_wait(i)
		var free := Data.type_of(str(c["id"])) == "egen"
		if wait > 0 and free:
			_draw_egen_pill(r, i, G.fmt_time(wait), Color("4b3a2e"), ci)
		elif wait > 0:
			_draw_rest(r.position + Vector2(78, 78), 1.0 - float(wait) / (float(Data.gen_stats(c["id"])["refill"]) * 60.0), ci)
		elif free:
			_draw_egen_pill(r, i, "×%d" % G.rules.board.gen_left(i), Art.CLAY, ci)
		else:
			# 开了冷却的产线：底部显示剩余可点次数
			if G.rules.board.gen_left(i) >= 0:
				_draw_egen_pill(r, i, "×%d" % G.rules.board.gen_left(i), Art.CLAY, ci)
			if G.energy >= G.rules.board.gen_cost():
				# 双倍火种模式：右下角换成紫火
				Sprites.at(ci, "board_bolt_boost" if G.rules.board.boost_on() else "board_bolt", r.position + Vector2(80, 78))

## 不拿拿、琥珀、沙漏、火种合到最高级后不能再合，右下角显示皇冠标志
const MAX_BADGE_CHAINS := ["shell", "amber", "sand", "fire"]

static func _is_max_currency(id: String) -> bool:
	if id == "" or Data.DISHES.has(id):
		return false
	var ch := Data.chain(id)
	return ch in MAX_BADGE_CHAINS and Data.CHAINS.has(ch) and Data.lv(id) >= Data.max_lv(ch)

## 皇冠贴在右下角，略微歪一点，像贴纸
func _draw_max_badge(r: Rect2, ci: CanvasItem = null) -> void:
	if ci == null: ci = self
	ci.draw_set_transform(r.end - Vector2(24, 21), 0.2, Vector2.ONE)
	ci.draw_texture_rect(MAX_CROWN, Rect2(-23, -18, 46, 36), false)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func _sec_text(sec: int) -> String:
	sec = maxi(sec, 0)
	if sec >= 3600:
		return "%d时%02d分" % [sec / 3600, sec % 3600 / 60]
	if sec >= 60:
		return "%d分%02d秒" % [sec / 60, sec % 60]
	return "%d秒" % sec

## 材料聚在这一格：陶锅搅拌，底下是制作进度
func _draw_cook(i: int, r: Rect2, ck: Dictionary, ci: CanvasItem = null) -> void:
	if ci == null: ci = self
	var seed: int = i
	if str(ck.get("uid", "")) != "":
		seed = absi(str(ck["uid"]).hash()) % 4096
	var ctr := r.get_center() + Vector2(0, -10) + Vector2(0, sin(_t * 7.0) * 1.2)
	var into := G.now() - float(ck["t0"])
	var secs := maxf(float(ck["secs"]), 0.1)
	Sprites.at(ci, "board_cook_pot", ctr)
	if into > 0.0:
		for k in 3:
			var ph := fmod(_t * 0.5 + float(k) * 0.33, 1.0)
			var puff := ctr + Vector2(sin(_t * 2.4 + float(k) * 2.1) * 10.0, -16.0 - ph * 24.0)
			ci.draw_circle(puff, 3.0 + ph * 5.0, Color(1, 1, 1, 0.32 * (1.0 - ph)))
		var mats: Array = ck.get("mats", [])
		var u := clampf(into / secs, 0.0, 1.0)
		if u < 0.9 and not mats.is_empty():
			var rad := lerpf(24.0, 7.0, u)
			var spin := _t * 2.3
			for k in mats.size():
				var a := spin + TAU * float(k) / float(mats.size())
				var p := ctr + Vector2(cos(a), sin(a) * 0.62) * rad
				Art.item(ci, str(mats[k]), p, 34.0 * lerpf(1.0, 0.4, u), false)
		var ang := _t * 4.6
		var dir := Vector2(cos(ang), sin(ang) * 0.7)
		ci.draw_line(ctr + dir * 6.0, ctr + dir * 22.0 + Vector2(0, -16), Art.WOOD_D, 4.0, true)
		ci.draw_circle(ctr + dir * 22.0 + Vector2(0, -16), 4.5, Art.WOOD)
		var fh := 10.0 + sin(_t * 16.0) * 3.0
		# 火苗图按 10 高生成，跳动时上下拉伸
		Sprites.draw(ci, "board_cook_flame", Rect2(ctr + Vector2(-8, 20.0 - fh * 0.5), Vector2(16, fh)))
	var frac := 0.0 if into <= 0.0 else clampf(into / secs, 0.0, 1.0)
	Paint.bar(ci, Rect2(r.position.x + 10, r.end.y - 16, r.size.x - 20, 11), frac, Art.MOSS, seed + 9)

## 生产器休息中：右下角的小表盘，亮弧是恢复进度
## 体力生产器底部的小牌：休息时是倒计时，能点时是剩余次数（样式同合成泡泡的倒计时牌）。
## 小牌随本格更新；其他格子的连续动画不会重画这段文字。

func _draw_egen_pill(r: Rect2, i: int, label: String, col: Color, ci: CanvasItem = null) -> void:
	if ci == null: ci = self
	var fs := 20
	var f: Font = G.font_title
	var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pill := Rect2(r.get_center().x - tw * 0.5 - 8, r.end.y - 18, tw + 16, 26)
	Sprites.draw(ci, "board_epill_ink", pill)
	Sprites.draw(ci, "board_epill_fill", pill, col)
	var base := pill.position.y + 13.0 + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5
	ci.draw_string(f, Vector2(pill.position.x + 7, base), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)

func _draw_rest(c: Vector2, t: float, ci: CanvasItem = null) -> void:
	if ci == null: ci = self
	ci.draw_circle(c, 13.0, Art.INK)
	ci.draw_circle(c, 10.5, Color("4b3a2e"))
	if t > 0.0:
		ci.draw_arc(c, 7.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(t, 0.0, 1.0), 20, Art.FIRE2, 4.0, true)
	ci.draw_line(c, c + Vector2(0, -5), Art.BONE, 2.0, true)
	ci.draw_line(c, c + Vector2(4, 0), Art.BONE, 2.0, true)

## 巨石：不规则多边形大石 + 小石块 + 裂纹 + 青苔
func _draw_rock(r: Rect2, i: int, ci: CanvasItem = null) -> void:
	if ci == null: ci = self
	_paint_rock(ci, r, i)

func _paint_rock(ci: CanvasItem, r: Rect2, i: int) -> void:
	ci.draw_texture_rect_region(ROCK_FRAMES[Art.boil % 4], Rect2(r.position - Vector2(16, 16), Vector2(128, 128)), _rock_region(i))

## floor.png 一行 4 块地砖，按格子错开取，避免整齐重复
static func _floor_region(i: int) -> Rect2:
	return Rect2(posmod(i * 7 + (i / G.COLS) * 3, 4) * 96, 0, 96, 96)

static func _rock_region(i: int) -> Rect2:
	var variant := posmod(i, 63)
	return Rect2((variant % 9) * 128, (variant / 9) * 128, 128, 128)

func _crumble_for(i: int) -> Dictionary:
	for c in crumbles:
		if int(c["i"]) == i:
			return c
	return {}

## 裂开那一下：裂纹变亮、变深
func _draw_rock_cracks(r: Rect2, i: int, u: float, ci: CanvasItem = null) -> void:
	if ci == null: ci = self
	ci.draw_texture_rect_region(ROCK_CRACKS, Rect2(r.position - Vector2(16, 16), Vector2(128, 128)), _rock_region(i), Color(1, 1, 1, lerpf(0.6, 1.0, u)))

## 碎石和尘土也是图片，只更新位置、旋转、缩放和透明度。
func _draw_crumble(c: Dictionary) -> void:
	var i: int = int(c["i"])
	var lin := clampf((float(c["t"]) - CRUMBLE_HOLD) / (CRUMBLE_DUR - CRUMBLE_HOLD), 0.0, 1.0)
	var t := lerpf(0.14, 1.0, 1.0 - pow(1.0 - lin, 2.0))
	var ctr := cell_rect(i).get_center() + Vector2(0, 4)
	var fade := 1.0 - smoothstep(0.45, 1.0, t)
	for k in 6:
		var angle := TAU * (float(k) + 0.5) / 6.0 + Art.srnd(i * 17 + k) * 0.4
		var dir := Vector2(cos(angle), sin(angle) * 0.88)
		var travel := dir * (22.0 * t + 150.0 * t * t) + Vector2(0, 96.0 * t * t)
		var spin := (Art.srnd(i * 23 + k) - 0.5) * 3.4 * t
		_draw_fragment(k, ctr + travel, angle + spin, 0.85 + Art.srnd(i * 19 + k) * 0.35, fade)
	for k in 5:
		var angle := TAU * float(k) / 5.0 + Art.srnd(i * 31 + k) * 0.8
		var dir := Vector2(cos(angle), sin(angle) * 0.85)
		var pos := ctr + dir * (8.0 + 78.0 * t) + Vector2(0, 120.0 * t * t)
		var radius := (3.2 + Art.srnd(i * 37 + k) * 3.4) * (1.0 - t * 0.25)
		_draw_fragment(6, pos, 0, radius / 12.0, fade)
	for k in 4:
		var angle := TAU * float(k) / 4.0 + 0.5
		var pos := ctr + Vector2(cos(angle), sin(angle) * 0.7) * (12.0 + 46.0 * t) + Vector2(0, 18.0 * t * t)
		_draw_fragment(7, pos, 0, (7.0 + 16.0 * t) / 28.0, 0.32 * (1.0 - t))

func _draw_fragment(k: int, pos: Vector2, rotation_value: float, scale_value: float, alpha: float) -> void:
	draw_set_transform(pos, rotation_value, Vector2.ONE * scale_value)
	draw_texture_rect_region(ROCK_BITS, Rect2(-32, -32, 64, 64), Rect2(k * 64, 0, 64, 64), Color(1, 1, 1, alpha))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

## 藤蔓：两根绕过物品的藤（画法见 scripts/sprites/board.gd）。back 是物品后面那段。
## 按格子序号取一种样子，单双数决定镜像。
func _draw_vine(r: Rect2, i: int, back: bool, ci: CanvasItem = null) -> void:
	if ci == null: ci = self
	Sprites.draw(ci, "board_vine_%s%d" % ["b" if back else "f", posmod(i, 8)], r)

func _draw_burst(b: Dictionary) -> void:
	MergeBurst.paint(self, b["p"], float(b["t"]) / 0.6, float(b["seed"]))

# ---------------------------------------------------------------- 停手提示

func _clear_hint() -> void:
	_hint_dirty = true
	_idle = 0.0
	if _hint_a < 0 and _hint_b < 0:
		return
	_hint_a = -1
	_hint_b = -1
	queue_redraw()

func _set_hint(a: int, b: int) -> void:
	if _hint_a == a and _hint_b == b:
		return
	if a >= 0:
		_hint_t = _t
	_hint_a = a
	_hint_b = b
	queue_redraw()

func _hint_context() -> bool:
	if not is_visible_in_tree():
		return false
	if not bool(G.settings.get("hint", true)):
		return false
	if G.main == null or G.main.screen != "board":
		return false
	if G.main.popup_layer != null and G.main.popup_layer.get_child_count() > 0:
		return false
	return true

func _guide_playing() -> bool:
	return G.main != null and G.main._guide != null and G.main._guide.visible and not G.main._guide._done

func _tick_hint(delta: float) -> void:
	if not _hint_context():
		_clear_hint()
		return
	if dragging or press_cell >= 0:
		_clear_hint()
		return
	if not moves.is_empty() or not flights.is_empty() or not crumbles.is_empty() or not gathers.is_empty():
		_set_hint(-1, -1)
		return
	if _hint_a < 0:
		_idle += delta
		if _idle < HINT_WAIT:
			return
	if not _hint_dirty and not _guide_playing() and _pair_ok(_hint_a, _hint_b): return
	_hint_dirty = false
	var pair := _pick_pair()
	if not _pair_ok(pair.x, pair.y):
		_set_hint(-1, -1)
		return
	_set_hint(pair.x, pair.y)

## 引导正在教合成时，就呼吸那一对。其余时候在棋盘上找一对。
func _pick_pair() -> Vector2i:
	if _guide_playing():
		var g: Vector2i = G.main._guide.merge_hint()
		if g.x >= 0 and _pair_ok(g.x, g.y):
			return g
		return Vector2i(-1, -1)
	return _find_hint_pair()

func _hint_cell_ok(i: int) -> bool:
	if i < 0 or i >= G.board.size() or hid.has(i) or G.rules.orders.cooking(i):
		return false
	if not _crumble_for(i).is_empty():
		return false
	var c: Dictionary = G.board[i]
	var id := str(c["id"])
	if id == "" or int(c["lock"]) >= 2 or Data.is_dish(id):
		return false
	var ch := Data.chain(id)
	if not Data.CHAINS.has(ch) or Data.next_id(id) == "":
		return false
	return true

func _pair_ok(a: int, b: int) -> bool:
	if a == b or not _hint_cell_ok(a) or not _hint_cell_ok(b):
		return false
	if str(G.board[a]["id"]) != str(G.board[b]["id"]):
		return false
	return int(G.board[a]["lock"]) == 0 or int(G.board[b]["lock"]) == 0

func _find_hint_pair() -> Vector2i:
	var wanted := G.rules.orders.wanted_ids()
	var by := {}
	for i in G.board.size():
		if not _hint_cell_ok(i):
			continue
		var id := str(G.board[i]["id"])
		if not by.has(id):
			by[id] = []
		(by[id] as Array).append(i)
	var best := -1.0e9
	var pair := Vector2i(-1, -1)
	for id in by:
		var cells: Array = by[id]
		if cells.size() < 2:
			continue
		var sid := str(id)
		var need := _order_need(sid)
		var free_n := _free_copies(sid)
		var worth := _merge_worth(sid, wanted)
		for ia in cells.size():
			var a: int = cells[ia]
			var free_a := int(G.board[a]["lock"]) == 0
			for ib in range(ia + 1, cells.size()):
				var b: int = cells[ib]
				var free_b := int(G.board[b]["lock"]) == 0
				if not free_a and not free_b:
					continue
				var spend := 2 if free_a and free_b else 1
				if free_n - spend < need:
					continue
				var ca := Vector2(a % G.COLS, a / G.COLS)
				var cb := Vector2(b % G.COLS, b / G.COLS)
				var dist := absf(ca.x - cb.x) + absf(ca.y - cb.y)
				var score := worth + 100.0 - dist * 18.0 - float(Data.lv(sid)) * 1.5
				if int(G.board[a]["lock"]) == 1 or int(G.board[b]["lock"]) == 1:
					score += 36.0
				if score > best:
					best = score
					pair = Vector2i(a, b)
	return pair

func _order_need(id: String) -> int:
	var n := 0
	for o in G.orders:
		if str(o.get("kind", "")) == "craft":
			var phase := str(o.get("phase", "need"))
			if phase == "ready" and str(o.get("dish", "")) == id:
				n += 1
			elif phase == "need":
				for m in o.get("mats", []):
					if str(m) == id:
						n += 1
			continue
		for it in o.get("items", []):
			if str(it) == id:
				n += 1
	return n

func _free_copies(id: String) -> int:
	var n := 0
	for i in G.board.size():
		var c: Dictionary = G.board[i]
		if str(c["id"]) != id or int(c["lock"]) != 0 or G.rules.orders.cooking(i):
			continue
		n += 1
	return n

## 合成结果能交差，或顺着同一条链靠近订单，就优先提示。
func _merge_worth(id: String, wanted: Dictionary) -> float:
	var nx := Data.next_id(id)
	if nx != "" and wanted.has(nx):
		return 1000.0
	var ch := Data.chain(id)
	if not Data.CHAINS.has(ch):
		return 0.0
	var lv := Data.lv(id)
	var best := 0.0
	for wid in wanted:
		var w := str(wid)
		if w == "" or Data.is_dish(w) or Data.chain(w) != ch:
			continue
		var gap := Data.lv(w) - lv
		if gap > 1:
			best = maxf(best, 480.0 - float(gap) * 40.0)
	return best

## 从 0 开始、速度也是 0，提示出现时不会从半路跳进来。
func _breath_amount() -> float:
	return 0.5 - 0.5 * cos((_t - _hint_t) * 2.6)

func _breath_scale() -> float:
	return lerpf(1.0, 1.14, _breath_amount())

## 两格以内才互相靠拢，再远只做缩放。
func _breath_nudge(i: int) -> Vector2:
	var other := _hint_b if i == _hint_a else _hint_a
	if other < 0:
		return Vector2.ZERO
	var delta := cell_center(other) - cell_center(i)
	var dist := delta.length()
	if dist < 1.0 or dist > CELL * 2.0 + 1.0:
		return Vector2.ZERO
	return delta / dist * 13.0 * _breath_amount()

func _guide_allows_drop(from_i: int, to_i: int) -> bool:
	if G.main == null or G.main._guide == null or not G.main._guide.visible:
		return true
	return G.main._guide.allows_drop(from_i, to_i)

## 合成泡泡（#08 #18）：物品裹在一颗会轻轻晃动的肥皂泡里，底下挂着倒计时小牌；最后 10 秒变红并加快晃动。
const BUBBLE_RIM := Color("3f86b4")
func _draw_merge_bubble(i: int, ctr: Vector2, sc: float, ci: CanvasItem = null) -> void:
	if ci == null: ci = self
	var seconds := G.rules.board.bubble_left(i)
	var urgent := seconds <= 10
	var ph := _t * (5.0 if urgent else 2.6) + float(i) * 0.9
	var wob := Vector2(1.0 + 0.035 * sin(ph), 1.0 - 0.035 * sin(ph)) * sc
	var c := ctr + Vector2(0, -4 + sin(ph * 0.5) * 1.5)
	var radius := 40.0
	ci.draw_colored_polygon(Art.ell(ctr + Vector2(0, 38), Vector2(26, 5), i, 0.0, 14, 0.0, 0.0), Color(0.15, 0.3, 0.45, 0.16))
	ci.draw_set_transform(c, 0.0, wob)
	ci.draw_circle(Vector2.ZERO, radius, Color(0.62, 0.88, 1.0, 0.28))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	Art.item(ci, str(G.board[i]["id"]), c + Vector2(0, 2), ITEM * 0.74 * sc, false)
	ci.draw_set_transform(c, 0.0, wob)
	# 泡泡下半圈有一点天蓝反光，上半圈是一条白色亮弧和一颗亮点
	ci.draw_arc(Vector2.ZERO, radius - 4.0, PI * 0.15, PI * 0.85, 18, Color(0.55, 0.85, 1.0, 0.55), 5.0, true)
	ci.draw_arc(Vector2.ZERO, radius, 0, TAU, 48, Color(BUBBLE_RIM, 0.9), 3.0, true)
	ci.draw_arc(Vector2.ZERO, radius - 7.0, PI * 1.08, PI * 1.42, 12, Color(1, 1, 1, 0.92), 5.0, true)
	ci.draw_circle(Vector2(-12, -30), 3.2, Color(1, 1, 1, 0.95))
	ci.draw_circle(Vector2(24, 20), 2.2, Color(1, 1, 1, 0.6))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 倒计时小牌
	var label := "%d:%02d" % [seconds / 60, seconds % 60]
	var fs := 16
	var f: Font = G.font_title
	var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pill := Rect2(ctr.x - tw * 0.5 - 7, ctr.y + 19, tw + 14, 21)
	Sprites.draw(ci, "board_bpill_ink", pill)
	Sprites.draw(ci, "board_bpill_fill", pill, Art.CLAY if urgent else Color("2f6d93"))
	var base := pill.position.y + 10.5 + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5
	ci.draw_string(f, Vector2(pill.position.x + 7, base), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
