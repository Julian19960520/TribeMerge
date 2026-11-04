class_name Board
extends Control
## 7×9 合成棋盘

const Layout := preload("res://scripts/config/board_layout.gd")

signal selected_changed(i: int)
signal activated(i: int)
signal dropped_outside(i: int, global_pos: Vector2)

const CELL := 96.0
const ITEM := 84.0

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

const DRAG_LIFT := Vector2(0, -14)
const MOVE_DUR := 0.26
## 物品只是某张订单的一部分，底色用普通绿。
const ORDER_PART := Color("a8d86a")
## 和上面同一个色相，更亮一些，饱和度只略高。这单需求已经齐了才用。
const ORDER_FULL := Color("aaf745")
## 石头先裂开，再碎开飞出去
const CRUMBLE_HOLD := 0.1
const CRUMBLE_DUR := 0.62
## 越大越跟手
const DRAG_FOLLOW := 32.0
## 停手这么久，就让一对能合成的物品呼吸
const HINT_WAIT := 5.0

func _ready() -> void:
	size = Vector2(G.COLS * CELL, G.ROWS * CELL)
	mouse_filter = MOUSE_FILTER_STOP
	G.boil_tick.connect(queue_redraw)
	G.board_changed.connect(queue_redraw)
	G.orders_changed.connect(queue_redraw)
	call_deferred("_grant_loose_rewards")

func _process(delta: float) -> void:
	_t += delta
	_tick_hint(delta)
	if dragging:
		drag_vis = drag_vis.lerp(drag_pos, 1.0 - exp(-delta * DRAG_FOLLOW))
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
	var cooking := false
	var bubbled := false
	for cell in G.board:
		if typeof(cell.get("ck")) == TYPE_DICTIONARY:
			cooking = true
		if not bubbled:
			var rw = cell.get("rw", null)
			if rw is Array and not rw.is_empty():
				bubbled = true
		if cooking and bubbled:
			break
	var busy := dragging or cooking or bubbled or _hint_a >= 0 or not pops.is_empty() or not bounces.is_empty() or not flights.is_empty() or not bursts.is_empty() or not shakes.is_empty() or not moves.is_empty() or not crumbles.is_empty() or not gathers.is_empty()
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
	if busy:
		queue_redraw()

func cell_rect(i: int) -> Rect2:
	return Rect2(Vector2(i % G.COLS, i / G.COLS) * CELL, Vector2(CELL, CELL))

func cell_center(i: int) -> Vector2:
	return cell_rect(i).get_center()

func cell_global(i: int) -> Vector2:
	return get_global_transform() * cell_center(i)

func cell_at(p: Vector2) -> int:
	if p.x < 0 or p.y < 0 or p.x >= size.x or p.y >= size.y:
		return -1
	return int(p.y / CELL) * G.COLS + int(p.x / CELL)

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
	var any := false
	for e in batch:
		var i := int(e["i"])
		if i < 0 or i >= G.board.size():
			continue
		var cell: Dictionary = G.board[i]
		if Layout.parse_reward(cell.get("rw", null)).is_empty():
			continue
		cell.erase("rw")
		var id := str(e["id"])
		var n := int(e["n"])
		var kind := ""
		if Data.DISHES.has(id) or Data.CHAINS.has(Data.chain(id)):
			kind = Data.type_of(id)
		if kind in ["energy", "shell", "amber", "sand"]:
			G.add_currency(kind, n)
		else:
			for _j in n:
				G.stash.append(id)
		any = true
	if any:
		G.dirty()
		G.changed.emit()

func _draw_reward_bubble(i: int, r: Rect2) -> void:
	var rw := Layout.parse_reward(G.board[i].get("rw", null))
	if rw.is_empty():
		return
	var rad := 30.0
	var c := r.position + Vector2(r.size.x * 0.62, r.size.y * 0.34)
	var lift := sin(_t * 3.2 + float(i) * 0.7) * 3.0
	Paint.reward_bubble(self, c, rad, rw[0], int(rw[1]), i, lift)

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
			Sfx.play("merge", 0.9 + 0.08 * float(Data.lv(G.cell_id(i))))
			burst(i)
			pop(i)
		"pop":
			pop(i)
	queue_redraw()

static func ease_back(t: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(t - 1.0, 3.0) + c1 * pow(t - 1.0, 2.0)

# ---------------------------------------------------------------- 输入

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
		else:
			if dragging:
				_drop(e.position)
			elif press_cell >= 0 and cell_at(e.position) == press_cell:
				_tap(press_cell)
			press_cell = -1
			dragging = false
			drag_from = -1
			queue_redraw()
	elif e is InputEventMouseMotion and press_cell >= 0:
		if not dragging and e.position.distance_to(press_pos) > 10.0:
			var c: Dictionary = G.board[press_cell]
			var held: bool = str(c["id"]) != "" or G.cooking(press_cell)
			if held and c["lock"] == 0 and not hid.has(press_cell) and _crumble_for(press_cell).is_empty():
				dragging = true
				drag_from = press_cell
				drag_vis = cell_center(press_cell) - DRAG_LIFT
				select(press_cell)
				Sfx.play("tap", 1.3)
		if dragging:
			drag_pos = e.position

func _tap(i: int) -> void:
	var c: Dictionary = G.board[i]
	if not _crumble_for(i).is_empty():
		shake(i)
		Sfx.play("deny")
		return
	if G.cooking(i):
		if selected == i:
			if G.main:
				G.main.toast("还在制作，还要 %s" % _sec_text(G.cook_left(i)))
			shake(i)
			Sfx.play("deny")
			return
		Sfx.play("tap")
		select(i)
		return
	if c["id"] == "":
		select(-1)
		return
	if selected == i and c["lock"] == 0:
		pop(i)
		activated.emit(i)
	else:
		Sfx.play("tap")
		pop(i)
		select(i)

func _drop(p: Vector2) -> void:
	var from := drag_from
	var vis := drag_vis + DRAG_LIFT
	var id_from := G.cell_id(from)
	var cook_from := _cook_copy(from)
	var to := cell_at(p)
	if to < 0:
		slide(id_from, vis, from, "", "pop", MOVE_DUR, cook_from)
		dropped_outside.emit(from, get_global_transform() * p)
		return
	if not _crumble_for(to).is_empty():
		slide(id_from, vis, from, "", "pop", MOVE_DUR, cook_from)
		Sfx.play("deny")
		shake(to)
		return
	if not _guide_allows_drop(from, to):
		slide(id_from, vis, from, "", "pop", MOVE_DUR, cook_from)
		if to != from:
			Sfx.play("deny")
			shake(to)
		return
	var id_to := G.cell_id(to)
	var cook_to := _cook_copy(to)
	var res := G.try_drop(from, to)
	match res:
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
	if not G.cooking(i):
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

func _draw() -> void:
	var frame := Art.rrect(Rect2(-14, -14, size.x + 28, size.y + 28), 22, 77, 1.0)
	Art.dilate(self, frame, 3.0, Art.INK)
	draw_colored_polygon(frame, Art.LEATHER)
	Art.dashed(self, Art.rrect(Rect2(-7, -7, size.x + 14, size.y + 14), 16, 78, 0.0), 11, 7, Color("f3d7a2"), 2.2)
	draw_rect(Rect2(Vector2.ZERO, size), Art.HIDE2)
	var tone := G.order_cell_tone()
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
		draw_rect(r.grow(-1.5), col)
	for i in G.board.size():
		if i == drag_from and dragging:
			continue
		if hid.has(i):
			continue
		_draw_cell(i)
	var sel_c := cell_center(selected) if selected >= 0 else Vector2.ZERO
	for m in moves:
		var to := cell_center(m["to"])
		var p: Vector2 = m["from"].lerp(to, ease_back(clampf(m["t"], 0.0, 1.0)))
		if m["under"] != "":
			Art.item(self, m["under"], to, ITEM)
		var cook: Dictionary = m.get("cook", {})
		if not cook.is_empty():
			_draw_cook(int(m["to"]), Rect2(p - Vector2(CELL, CELL) * 0.5, Vector2(CELL, CELL)), cook)
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
	if dragging and drag_from >= 0:
		var r0 := cell_rect(drag_from)
		draw_rect(r0.grow(-6), Color(0.3, 0.2, 0.1, 0.12))
		var hov := cell_at(drag_pos)
		if hov >= 0 and hov != drag_from and not G.cooking(drag_from):
			var ok: bool = G.board[hov]["id"] == G.board[drag_from]["id"] and Data.next_id(G.board[drag_from]["id"]) != "" and G.board[hov]["lock"] != 2 and _crumble_for(hov).is_empty()
			if ok:
				draw_colored_polygon(Art.rrect(cell_rect(hov).grow(-3), 16, hov, 0.0), Color(1, 0.85, 0.2, 0.45))
		if not hide_drag:
			var at := drag_vis + DRAG_LIFT
			if G.cooking(drag_from):
				_draw_cook(drag_from, Rect2(at - Vector2(CELL, CELL) * 0.5, Vector2(CELL, CELL)), G.board[drag_from]["ck"])
			else:
				var tilt := clampf((drag_pos.x - drag_vis.x) * 0.004, -0.25, 0.25)
				Art.item(self, G.board[drag_from]["id"], at, ITEM * 1.15, true, tilt)

func _draw_cell(i: int) -> void:
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
		_draw_rock(rr, i)
		if cracking:
			_draw_rock_cracks(rr, i, float(cu["t"]) / CRUMBLE_HOLD)
		_draw_reward_bubble(i, rr)
		return
	var reveal := 1.0
	if not cu.is_empty() and float(cu["delay"]) <= 0.0:
		reveal = clampf((float(cu["t"]) - CRUMBLE_HOLD) / 0.22, 0.0, 1.0)
		sc *= lerpf(0.62, 1.0, reveal)
	if typeof(c.get("ck")) == TYPE_DICTIONARY:
		_draw_cook(i, r, c["ck"])
		return
	if c["id"] == "":
		return
	var prod := not Data.gen_stats(c["id"]).is_empty()
	if c["lock"] == 0 and prod and reveal > 0.65:
		draw_colored_polygon(Art.rrect(r.grow(-6), 14, i, 0.6), Color(1, 0.86, 0.45, 0.55))
		Art.outline(self, Art.rrect(r.grow(-6), 14, i, 0.6), 2.0, Color(0.7, 0.45, 0.1, 0.6))
	var breath := 1.0
	var nudge := Vector2.ZERO
	if i == _hint_a or i == _hint_b:
		breath = _breath_scale()
		nudge = _breath_nudge(i)
		sc *= breath
	Art.item(self, c["id"], ctr + nudge, ITEM * sc)
	if c["lock"] == 1:
		if breath != 1.0 or nudge != Vector2.ZERO:
			draw_set_transform(ctr * (1.0 - breath) + nudge, 0.0, Vector2(breath, breath))
		_draw_vine(r, i)
		if breath != 1.0 or nudge != Vector2.ZERO:
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	elif prod and reveal > 0.65:
		var wait := G.gen_wait(i)
		if wait > 0:
			_draw_rest(r.position + Vector2(78, 78), 1.0 - float(wait) / (float(Data.gen_stats(c["id"])["refill"]) * 60.0))
		elif G.energy > 0:
			var bolt := Art.flame_pts(r.position + Vector2(80, 78), 7, 18, i)
			Art.fill(self, bolt, Art.FIRE2, 2.0)

static func _sec_text(sec: int) -> String:
	sec = maxi(sec, 0)
	if sec >= 60:
		return "%d分%02d秒" % [sec / 60, sec % 60]
	return "%d秒" % sec

## 材料聚在这一格：陶锅搅拌，底下是制作进度
func _draw_cook(i: int, r: Rect2, ck: Dictionary) -> void:
	var seed: int = i
	if str(ck.get("uid", "")) != "":
		seed = absi(str(ck["uid"]).hash()) % 4096
	var ctr := r.get_center() + Vector2(0, -10) + Vector2(0, sin(_t * 7.0) * 1.2)
	var into := G.now() - float(ck["t0"])
	var secs := maxf(float(ck["secs"]), 0.1)
	var pot := Art.poly([ctr + Vector2(-24, -2), ctr + Vector2(24, -2), ctr + Vector2(16, 18), ctr + Vector2(-16, 18)], seed, 0.7)
	var lip := Art.ell(ctr + Vector2(0, -2), Vector2(24, 8), seed + 1, 0.04, 16)
	Art.sil(self, [Art.P(pot, Art.CLAY, 1), Art.P(lip, Art.OCHRE, 0)], false, 2.4)
	draw_colored_polygon(Art.ell(ctr + Vector2(0, 0), Vector2(14, 5), seed + 2, 0.03, 12), Color("e07a3a"))
	if into > 0.0:
		for k in 3:
			var ph := fmod(_t * 0.5 + float(k) * 0.33, 1.0)
			var puff := ctr + Vector2(sin(_t * 2.4 + float(k) * 2.1) * 10.0, -16.0 - ph * 24.0)
			draw_circle(puff, 3.0 + ph * 5.0, Color(1, 1, 1, 0.32 * (1.0 - ph)))
		var mats: Array = ck.get("mats", [])
		var u := clampf(into / secs, 0.0, 1.0)
		if u < 0.9 and not mats.is_empty():
			var rad := lerpf(24.0, 7.0, u)
			var spin := _t * 2.3
			for k in mats.size():
				var a := spin + TAU * float(k) / float(mats.size())
				var p := ctr + Vector2(cos(a), sin(a) * 0.62) * rad
				Art.item(self, str(mats[k]), p, 34.0 * lerpf(1.0, 0.4, u), false)
		var ang := _t * 4.6
		var dir := Vector2(cos(ang), sin(ang) * 0.7)
		draw_line(ctr + dir * 6.0, ctr + dir * 22.0 + Vector2(0, -16), Art.WOOD_D, 4.0, true)
		draw_circle(ctr + dir * 22.0 + Vector2(0, -16), 4.5, Art.WOOD)
		var fh := 10.0 + sin(_t * 16.0) * 3.0
		var flame := Art.flame_pts(ctr + Vector2(0, 20), 7.0, fh, seed + 4)
		Art.fill(self, flame, Art.FIRE2, 2.0)
	var frac := 0.0 if into <= 0.0 else clampf(into / secs, 0.0, 1.0)
	Paint.bar(self, Rect2(r.position.x + 10, r.end.y - 16, r.size.x - 20, 11), frac, Art.MOSS, seed + 9)

## 生产器休息中：右下角的小表盘，亮弧是恢复进度
func _draw_rest(c: Vector2, t: float) -> void:
	draw_circle(c, 13.0, Art.INK)
	draw_circle(c, 10.5, Color("4b3a2e"))
	if t > 0.0:
		draw_arc(c, 7.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(t, 0.0, 1.0), 20, Art.FIRE2, 4.0, true)
	draw_line(c, c + Vector2(0, -5), Art.BONE, 2.0, true)
	draw_line(c, c + Vector2(4, 0), Art.BONE, 2.0, true)

## 巨石：不规则多边形大石 + 小石块 + 裂纹 + 青苔
func _draw_rock(r: Rect2, i: int) -> void:
	var c := r.get_center() + Vector2(0, 4)
	var base := []
	for k in 9:
		var a := TAU * float(k) / 9.0 + Art.srnd(i * 13 + k) * 0.3
		var rad := 36.0 + Art.srnd(i * 7 + k) * 8.0
		base.append(c + Vector2(cos(a) * rad * 1.08, sin(a) * rad * 0.9))
	var big := Art.poly(base, i, 0.8)
	draw_colored_polygon(Art.ell(c + Vector2(0, 30), Vector2(38, 9), i, 0.0, 14), Color(0, 0, 0, 0.18))
	var small := Art.poly([c + Vector2(18, 14), c + Vector2(38, 8), c + Vector2(46, 26), c + Vector2(30, 36), c + Vector2(14, 30)], i + 5, 0.6)
	Art.sil(self, [Art.P(big, Color("a39b8d"), 1), Art.P(small, Color("8c8476"), 1)], false, 3.0)
	var top := Art.poly([c + Vector2(-26, -18), c + Vector2(-6, -32), c + Vector2(18, -26), c + Vector2(6, -10), c + Vector2(-16, -6)], i + 9, 0.6)
	draw_colored_polygon(top, Color(1, 1, 1, 0.22))
	var crack := Color(0.25, 0.2, 0.15, 0.75)
	Art.pl(self, [c + Vector2(-4, -10), c + Vector2(4, 4), c + Vector2(-2, 14), c + Vector2(6, 26)], 2.4, crack, i + 2)
	Art.pl(self, [c + Vector2(4, 4), c + Vector2(16, 0)], 2.0, crack, i + 3)
	Art.pl(self, [c + Vector2(-30, 6), c + Vector2(-20, 12), c + Vector2(-22, 22)], 2.0, crack, i + 4)
	var moss := Art.ell(c + Vector2(-20, -24), Vector2(15, 7), i + 6, 0.12, 12, -0.4)
	Art.fill(self, moss, Art.MOSS, 2.0)
	draw_colored_polygon(Art.ell(c + Vector2(-24, -26), Vector2(6, 3), i + 7, 0.0, 8, -0.4), Color(1, 1, 1, 0.35))
	for k in 3:
		draw_circle(c + Vector2(-8 + k * 12, 22 - (k % 2) * 6), 1.6, Color(0.3, 0.25, 0.2, 0.5))

func _crumble_for(i: int) -> Dictionary:
	for c in crumbles:
		if int(c["i"]) == i:
			return c
	return {}

## 裂开那一下：裂纹变亮、变深
func _draw_rock_cracks(r: Rect2, i: int, u: float) -> void:
	var c := r.get_center() + Vector2(0, 4)
	var flash := Color(1, 0.95, 0.82, 0.85 * (1.0 - u))
	var deep := Color(0.15, 0.1, 0.08, 0.9)
	var w := lerpf(2.0, 4.5, u)
	Art.pl(self, [c + Vector2(-8, -22), c + Vector2(2, -4), c + Vector2(-6, 16), c + Vector2(8, 30)], w, deep, i + 11)
	Art.pl(self, [c + Vector2(2, -4), c + Vector2(22, -8), c + Vector2(34, 6)], w * 0.8, deep, i + 12)
	Art.pl(self, [c + Vector2(-28, 2), c + Vector2(-12, 10), c + Vector2(-18, 28)], w * 0.8, deep, i + 13)
	Art.pl(self, [c + Vector2(-6, -18), c, c + Vector2(4, 12)], w * 0.45, flash, i + 14)

## 巨石崩成碎块，向外飞并落下
func _draw_crumble(c: Dictionary) -> void:
	var i: int = int(c["i"])
	var lin := clampf((float(c["t"]) - CRUMBLE_HOLD) / (CRUMBLE_DUR - CRUMBLE_HOLD), 0.0, 1.0)
	var t := lerpf(0.14, 1.0, 1.0 - pow(1.0 - lin, 2.0))
	var ctr := cell_rect(i).get_center() + Vector2(0, 4)
	var fade := 1.0 - smoothstep(0.45, 1.0, t)
	var pieces := 6
	for k in pieces:
		var a0 := TAU * float(k) / float(pieces) + Art.srnd(i * 17 + k) * 0.4
		var a1 := TAU * float(k + 1) / float(pieces) + Art.srnd(i * 17 + k + 1) * 0.4
		var rad := 30.0 + Art.srnd(i * 19 + k) * 12.0
		var mid := (a0 + a1) * 0.5
		var dir := Vector2(cos(mid), sin(mid) * 0.88)
		var travel := dir * (22.0 * t + 150.0 * t * t) + Vector2(0, 96.0 * t * t)
		var spin := (Art.srnd(i * 23 + k) - 0.5) * 3.4 * t
		var o := ctr + travel
		var p0 := o + Vector2(cos(a0), sin(a0) * 0.9).rotated(spin) * rad
		var p1 := o + Vector2(cos(a1), sin(a1) * 0.9).rotated(spin) * rad * (0.82 + Art.srnd(i * 29 + k) * 0.28)
		var inset := o + dir.rotated(spin) * (5.0 + 10.0 * t)
		var poly := PackedVector2Array([inset, p0, p1])
		var col := Color("a39b8d") if k % 2 == 0 else Color("8a8274")
		col.a = fade
		draw_colored_polygon(poly, col)
		draw_polyline(PackedVector2Array([inset, p0, p1, inset]), Color(0.16, 0.12, 0.09, fade * 0.9), 2.0, true)
		if k % 2 == 0:
			var hl := inset.lerp(p0, 0.45).lerp(p1, 0.2)
			draw_circle(hl, 3.2 * (1.0 - t * 0.4), Color(1, 1, 1, 0.28 * fade))
	for k in 5:
		var a := TAU * float(k) / 5.0 + Art.srnd(i * 31 + k) * 0.8
		var dir := Vector2(cos(a), sin(a) * 0.85)
		var q := ctr + dir * (8.0 + 78.0 * t) + Vector2(0, 120.0 * t * t)
		var rr := (3.2 + Art.srnd(i * 37 + k) * 3.4) * (1.0 - t * 0.25)
		draw_circle(q, rr + 1.2, Color(0.12, 0.09, 0.07, fade * 0.7))
		draw_circle(q, rr, Color(Color("9a9284"), fade))
	for k in 4:
		var a := TAU * float(k) / 4.0 + 0.5
		var q := ctr + Vector2(cos(a), sin(a) * 0.7) * (12.0 + 46.0 * t) + Vector2(0, 18.0 * t * t)
		draw_circle(q, 7.0 + 16.0 * t, Color(0.72, 0.66, 0.56, 0.32 * (1.0 - t)))

func _draw_vine(r: Rect2, i: int) -> void:
	draw_rect(r.grow(-3), Color(0.25, 0.4, 0.1, 0.28))
	var p := r.position
	Art.pl(self, [p + Vector2(4, 30), p + Vector2(30, 46), p + Vector2(56, 34), p + Vector2(92, 52)], 7.0, Art.INK, i)
	Art.pl(self, [p + Vector2(4, 30), p + Vector2(30, 46), p + Vector2(56, 34), p + Vector2(92, 52)], 4.0, Art.LEAF_D, i)
	Art.pl(self, [p + Vector2(10, 92), p + Vector2(34, 66), p + Vector2(64, 76), p + Vector2(88, 6)], 7.0, Art.INK, i + 3)
	Art.pl(self, [p + Vector2(10, 92), p + Vector2(34, 66), p + Vector2(64, 76), p + Vector2(88, 6)], 4.0, Art.LEAF_D, i + 3)
	for lp in [Vector2(30, 46), Vector2(64, 76), Vector2(80, 30)]:
		var v := Art.ell(p + lp, Vector2(9, 5), i + int(lp.x), 0.05, 10, 0.6)
		Art.fill(self, v, Art.LEAF, 2.0)

func _draw_burst(b: Dictionary) -> void:
	var t: float = b["t"] / 0.6
	var p: Vector2 = b["p"]
	var rr := 20.0 + 70.0 * t
	draw_arc(p, rr, 0, TAU, 32, Color(1, 0.9, 0.4, 1.0 - t), 6.0 * (1.0 - t) + 1.0, true)
	for k in 8:
		var a := TAU * float(k) / 8.0 + float(b["seed"])
		var q := p + Vector2(cos(a), sin(a)) * (30.0 + 80.0 * t)
		var star := Art.star_pts(q, 10.0 * (1.0 - t) + 2.0, 4.0 * (1.0 - t) + 1.0, 4, k)
		draw_colored_polygon(star, Color(Art.FIRE2, 1.0 - t))
	for k in 5:
		var a := TAU * float(k) / 5.0 + 0.4 + float(b["seed"])
		var q := p + Vector2(cos(a), sin(a)) * (20.0 + 50.0 * t) + Vector2(0, 30.0 * t * t)
		draw_circle(q, 8.0 * (1.0 - t) + 2.0, Color(1, 1, 1, 0.8 * (1.0 - t)))

# ---------------------------------------------------------------- 停手提示

func _clear_hint() -> void:
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
	if i < 0 or i >= G.board.size() or hid.has(i) or G.cooking(i):
		return false
	if not _crumble_for(i).is_empty():
		return false
	var c: Dictionary = G.board[i]
	var id := str(c["id"])
	if id == "" or int(c["lock"]) == 2 or Data.is_dish(id):
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
	var wanted := G.wanted_ids()
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
		if str(c["id"]) != id or int(c["lock"]) != 0 or G.cooking(i):
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
