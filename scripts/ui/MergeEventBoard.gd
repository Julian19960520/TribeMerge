class_name MergeEventBoard
extends Control
## 合成活动棋盘（火光岩画 / 月石遗迹共用）。三种格子状态一眼可分：
## 覆盖（lock=2）= 爬满藤蔓、刻着月纹的凸起石板，看不到物品；
## 显示但锁定（lock=1）= 凹陷的暗色石槽，物品冷色半透明，藤蔓缠角 + 石锁；
## 开放（lock=0）= 暖色砂岩地砖，物品全彩可拖动。
## 拖放、飞出、回弹、晃动、合成爆点和主棋盘共用 BoardMotion，手感一致。
signal selection_changed(id: String, locked: bool)
signal action_finished(result: Dictionary)
var cfg: Dictionary
var cell := 96.0
var camera := 0.0
var selected := -1
var pressed := -1
var press_pos := Vector2.ZERO
var dragging := false
var cursor := Vector2.ZERO
## 只在镜头推进时为真：这时挡住输入。飞行动画不挡。
var animating := false
var motion := BoardMotion.new()
## 覆盖石板掀开（0→1）。
var lifts: Dictionary = {}
## 从面板气泡飞进来的格子（飞行画在面板特效层，棋盘这边只藏格子）。
var incoming: Dictionary = {}
## 面板提供的特效层：fx.call(kind, 面板坐标, data)。
var fx: Callable
## 投放的遗物从这里（面板坐标）飞进棋盘。
var spawn_origin := Vector2.ZERO
var _t := 0.0
var _camera_tween: Tween
var _spawn_busy := false
var _bubbles := false
var _tap_busy := false
var _was_moving := false

const INK := Color("3b2314")

func _ready() -> void:
	clip_contents = true
	mouse_filter = MOUSE_FILTER_STOP
	cell = size.x / int(cfg["board"]["cols"])
	camera = float(MergeEvent.state(cfg)["view"])
	motion.landed = _landed
	G.merge_event_changed.connect(queue_redraw)

## 距离按主棋盘 96 像素格子等比缩放。
func _unit() -> float:
	return cell / BoardMotion.BASE_CELL

func _item_size() -> float:
	return cell * BoardMotion.ITEM_RATIO

func center(i: int) -> Vector2:
	var cols := int(cfg["board"]["cols"])
	return Vector2((i % cols + 0.5) * cell, (i / cols - camera + 0.5) * cell)

func at(p: Vector2) -> int:
	var visible_index := MergeGrid.cell_at(p, cell, int(cfg["board"]["cols"]), int(cfg["board"]["visible_rows"]))
	return visible_index + int(round(camera)) * int(cfg["board"]["cols"]) if visible_index >= 0 else -1

func _color(key: String, fallback: String) -> Color:
	return Color(str(cfg["theme"].get(key, fallback)))

func _fx(kind: String, local: Vector2, data: Dictionary = {}) -> void:
	if fx.is_valid(): fx.call(kind, position + local, data)

func _sync_camera() -> void:
	var to := float(MergeEvent.state(cfg)["view"])
	if is_equal_approx(to, camera): return
	animating = true
	selected = -1
	selection_changed.emit("", false)
	if _camera_tween and _camera_tween.is_valid(): _camera_tween.kill()
	_camera_tween = create_tween()
	_camera_tween.tween_method(func(v): camera = v; queue_redraw(), camera, to, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_camera_tween.tween_callback(func():
		animating = false
		_fx("text", Vector2(size.x / 2, cell * 0.9), {"text": TextCatalog.source("ui.mergeeventboard.519c2ec5a775"), "color": Color("bff3f0"), "size": 30}))
	Sfx.play("whoosh")

func _moving() -> bool:
	return not (motion.moves.is_empty() and motion.flights.is_empty() and incoming.is_empty())

func _process(delta: float) -> void:
	_t += delta
	var busy := motion.busy() or not lifts.is_empty() or dragging
	motion.tick(delta)
	for k in lifts.keys():
		lifts[k] = float(lifts[k]) + delta / 0.5
		if float(lifts[k]) >= 1: lifts.erase(k)
	# 东西都落地了再推进镜头。
	var moving := _moving()
	if _was_moving and not moving: _sync_camera()
	_was_moving = moving
	if busy or _bubbles or _hint_id() != "" or _brush_ready() or selected >= 0: queue_redraw()

## 落地（BoardMotion 回调）：回弹；合成再加爆点、解锁落叶、揭开石板。
func _landed(e: Dictionary) -> void:
	var i := int(e["to"])
	motion.pop(i)
	var r: Dictionary = e.get("result", {})
	if str(r.get("kind", "")) != "merge": return
	var at_px := center(i)
	Sfx.play("merge", 0.9 + 0.08 * float(_tier(str(MergeEvent.state(cfg)["cells"][i]["id"]))))
	motion.burst(at_px)
	if bool(r.get("unlocked", false)):
		_fx("leaves", at_px, {"color": _color("vine", "7fae5a")})
		_fx("text", at_px + Vector2(0, -cell * 0.45), {"text": TextCatalog.source("ui.mergeeventboard.0ee51c1f367c"), "color": Color("fff3a6"), "size": 30})
		Sfx.play("crumble")
	for k in r.get("revealed", []):
		lifts[int(k)] = 0.0
		_fx("dust", center(int(k)), {"color": _color("covered", "6e8d93")})

## 合成音高随等级升高（同主棋盘）。
func _tier(id: String) -> int:
	for line in [cfg.get("chain", []), cfg.get("mural", []), cfg.get("shards", [])]:
		for k in line.size():
			if str(line[k]["id"]) == id: return k + 1
	return Data.lv(id) if MergeEvent.kind(cfg, id) == "reward" else 1

func _hint_id() -> String:
	var s := MergeEvent.state(cfg)
	var k := pressed if dragging else selected
	if k < 0 or k >= s["cells"].size(): return ""
	var c: Dictionary = s["cells"][k]
	return str(c["id"]) if int(c["lock"]) == 0 else ""

func _draw() -> void:
	if cfg.is_empty(): return
	var s := MergeEvent.state(cfg)
	var cells: Array = s["cells"]
	var cols := int(cfg["board"]["cols"])
	var unit := _unit()
	var item := _item_size()
	draw_rect(Rect2(Vector2.ZERO, size), _color("recess", "2f5058").darkened(0.55))
	var hint := _hint_id()
	var pulse := 0.5 + 0.5 * sin(_t * 6.0)
	_bubbles = false
	var first := maxi(0, int(floor(camera)))
	var last := mini(int(cfg["board"]["total_rows"]), int(ceil(camera)) + int(cfg["board"]["visible_rows"]))
	for row in range(first, last):
		for col in cols:
			var i := row * cols + col
			var c: Dictionary = cells[i]
			var ctr := center(i)
			var r := Rect2(ctr - Vector2.ONE * cell / 2, Vector2.ONE * cell)
			var lock := int(c["lock"])
			var id := str(c["id"])
			if lock == 0: MoonArt.tile(self, r, i, MoonArt.FLOOR if (row + col) % 2 == 0 else MoonArt.FLOOR_ALT)
			else: MoonArt.tile(self, r, i, MoonArt.RECESS)
			var hidden := (dragging and i == pressed) or motion.hid.has(i)
			if lock == 0:
				if hint != "" and id == hint and i != pressed and i != selected:
					_glow(r, Color("fff3a6"), 0.25 + 0.35 * pulse)
				if id != "" and not hidden:
					var k := MergeEvent.kind(cfg, id)
					if k == "brush" and _brush_ready(): _glow(r, Color("ffc46a"), 0.3 + 0.4 * pulse)
					var at_px := ctr + motion.shake_offset(i, unit)
					MergeEventArt.draw_item(self, cfg, id, at_px, item * motion.pop_scale(i), Color.WHITE, _t)
					if k == "reward" and MergeEvent.is_bubble(cfg, id): _bubbles = true
					if k == "brush": _draw_charges(ctr, s)
			elif lock == 1:
				if hint != "" and id == hint: _glow(r, Color("b8ff7a"), 0.45 + 0.5 * pulse)
				if not hidden: MergeEventArt.draw_item(self, cfg, id, ctr + motion.shake_offset(i, unit), cell * 0.72, Color(0.66, 0.86, 0.95, 0.82))
				MoonArt.tile(self, r, i, MoonArt.LOCK)
			else:
				MoonArt.tile(self, r, i, MoonArt.FRONTIER if _frontier(cells, i, cols) else MoonArt.SLAB)
			if lifts.has(i):
				var t := float(lifts[i])
				draw_set_transform(ctr + Vector2(0, -t * cell * 0.35), (Art.srnd(i) - 0.5) * t * 0.6, Vector2.ONE * (1.0 + 0.2 * t))
				MoonArt.tile(self, Rect2(-Vector2.ONE * cell / 2, Vector2.ONE * cell), i, MoonArt.SLAB, 1.0 - t)
				draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	var sel_c := center(selected) if selected >= 0 else Vector2.ZERO
	for m in motion.moves:
		if BoardMotion.waiting(m): continue
		var p := BoardMotion.move_pos(m, center(int(m["to"])))
		MergeEventArt.draw_item(self, cfg, str(m["id"]), p, item * BoardMotion.move_scale(m), Color.WHITE, _t)
		if int(m["to"]) == selected: sel_c = p
	if selected >= 0 and not dragging: BoardMotion.draw_selection(self, sel_c, cell, _t, Color("ffe58a"))
	for f in motion.flights:
		if BoardMotion.waiting(f): continue
		MergeEventArt.draw_item(self, cfg, str(f["id"]), BoardMotion.fly_pos(f, center(int(f["to"])), unit), item * BoardMotion.fly_scale(f), Color.WHITE, _t)
	motion.draw_bursts(self, unit)
	if dragging and pressed >= 0:
		MergeEventArt.draw_item(self, cfg, str(cells[pressed]["id"]), cursor + BoardMotion.DRAG_LIFT * unit, item * BoardMotion.DRAG_SCALE)

func _brush_ready() -> bool:
	var s := MergeEvent.state(cfg)
	return s.has("brush") and int(s["brush"]["charges"]) > 0

## 生产器右下角：还有存货时显示还能点几下；空了显示 0/1，等一颗宝石（颜料）升级装填。
func _draw_charges(ctr: Vector2, s: Dictionary) -> void:
	var n := int(s.get("brush", {}).get("charges", 0))
	var r := Rect2(ctr + Vector2(-cell * 0.02, cell * 0.2), Vector2(cell * 0.5, cell * 0.25))
	draw_colored_polygon(Art.rrect(r, r.size.y / 2, 7, 0.0), Color(0.18, 0.09, 0.05, 0.85))
	draw_circle(r.position + Vector2(r.size.y / 2, r.size.y / 2), r.size.y * 0.32, Color("e0703a") if n > 0 else Color("6fd08a"))
	var fs := int(cell * 0.2)
	var txt := "×%d" % n if n > 0 else "0/1"
	var w := G.font_title.get_string_size(TextCatalog.resolve(txt), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(G.font_title, Vector2(r.position.x + r.size.y + (r.size.x - r.size.y - w) / 2, r.position.y + r.size.y * 0.8), TextCatalog.resolve(txt), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("fff1d6"))

func _frontier(cells: Array, i: int, cols: int) -> bool:
	for k in MergeGrid.neighbors(i, cols, cells.size()):
		if int(cells[k]["lock"]) == 0: return true
	return false

func _glow(r: Rect2, col: Color, a: float) -> void:
	# 白色光框图，按颜色和亮度染色
	Sprites.draw(self, "board_glow", r.grow(-3), Color(col, a))

func _gui_input(e: InputEvent) -> void:
	if animating: return
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_LEFT and e.device != -1:
			if e.pressed: _press(e.position)
			else: _release(e.position)
			accept_event()
	elif e is InputEventMouseMotion and e.device != -1: _motion(e.position)
	elif e is InputEventScreenTouch:
		if e.index != 0: return
		if e.pressed: _press(e.position)
		else: _release(e.position)
		accept_event()
	elif e is InputEventScreenDrag and e.index == 0: _motion(e.position); accept_event()

## 手快时格子上的飞入还没播完：直接收尾，逻辑状态早已就绪（同主棋盘）。
func _settle(i: int) -> void:
	if i < 0: return
	motion.settle(i)
	if incoming.has(i):
		incoming.erase(i)
		motion.unhide(i)
		motion.pop(i)

func _press(p: Vector2) -> void:
	pressed = at(p)
	_settle(pressed)
	press_pos = p
	cursor = p
	dragging = false

func _motion(p: Vector2) -> void:
	if pressed < 0: return
	var c: Dictionary = MergeEvent.state(cfg)["cells"][pressed]
	if not dragging and p.distance_to(press_pos) > BoardMotion.DRAG_START and int(c["lock"]) == 0 and str(c["id"]) != "":
		dragging = true
		Sfx.play("tap", 1.3)
	cursor = p
	queue_redraw()

func _release(p: Vector2) -> void:
	if pressed < 0: return
	var a := pressed
	var b := at(p)
	var held := dragging
	dragging = false
	pressed = -1
	if held:
		var s := MergeEvent.state(cfg)
		var id := str(s["cells"][a]["id"])
		var from := cursor + BoardMotion.DRAG_LIFT * _unit()
		_settle(b)
		var result: Dictionary = await MergeEvent.act(cfg, "drop", {"from": a, "to": b, "view": int(round(camera))})
		if not is_instance_valid(self): return
		if result.has("error"):
			motion.slide(id, from, a)
			if str(result["error"]) != "": G.main.toast(str(result["error"]))
			if b >= 0 and b != a:
				Sfx.play("deny")
				motion.shake(b)
		else:
			var kind := str(result["kind"])
			motion.slide(id, from, b, 0.16 if kind == "merge" else BoardMotion.MOVE_DUR, {"result": result})
			if kind == "swap": motion.slide(str(result["under"]), center(b), a)
			if kind in ["move", "swap"]: Sfx.play("pop", 0.9)
			_animate_extras(result, b)
			if kind == "feed":
				Sfx.play("merge")
				motion.burst(center(b))
				_fx("text", center(b) + Vector2(0, -cell * 0.5), {"text": TextCatalog.source("ui.mergeeventboard.b14cf6838e54") if bool(result.get("level_up", false)) else TextCatalog.fill(TextCatalog.source("ui.mergeeventboard.0d1fd47477ac"), int(result["charges"])), "color": Color("ffd68a"), "size": 28})
			selected = b
			action_finished.emit(result)
	elif b == a:
		var again := selected == b
		selected = b
		if not await _tap(b, again): return
	var cells: Array = MergeEvent.state(cfg)["cells"]
	if selected >= 0: selection_changed.emit("" if int(cells[selected]["lock"]) == 2 else str(cells[selected]["id"]), int(cells[selected]["lock"]) != 0)
	queue_redraw()

## 合成掉出的特殊物品 / 奖励、洞口排队出来的物品：和主棋盘生产器出货同一条飞行轨迹，依次飞出。
func _animate_extras(result: Dictionary, origin: int) -> void:
	var delay := 0.16
	for p in result.get("placed", []):
		motion.fly(str(p["id"]), center(origin), int(p["to"]), delay)
		delay += 0.12
	for p in result.get("flushed", []):
		motion.fly(str(p["id"]), Vector2(size.x / 2, size.y + cell * 0.6), int(p["to"]), delay)
		delay += 0.12
	if int(result.get("queued", 0)) > 0:
		_fx("text", Vector2(size.x / 2, cell * 0.9), {"text": TextCatalog.fill(TextCatalog.source("ui.mergeeventboard.6d14fa859d57"), int(result["queued"])), "color": Color("ffd68a"), "size": 26})
	if int(result.get("stashed", 0)) > 0:
		_fx("text", Vector2(size.x / 2, size.y - cell * 0.6), {"text": TextCatalog.fill(TextCatalog.source("ui.mergeeventboard.94653c8dc2ba"), int(result["stashed"])), "color": Color("ffd68a"), "size": 26})

## 点格子：生产器点一下出货；箱子气泡点一下收进暂存区；
## 资源先选中，再点一下领取；最高级的灯 / 壁画选中后再点挂上岩壁。返回 false 表示已自行收尾。
func _tap(i: int, again: bool) -> bool:
	var s := MergeEvent.state(cfg)
	var c: Dictionary = s["cells"][i]
	var id := str(c["id"])
	if int(c["lock"]) == 2:
		# 同主棋盘：盖着的格子晃一下表示动不了
		Sfx.play("tap")
		motion.shake(i)
		return true
	if int(c["lock"]) != 0 or id == "" or _tap_busy: return true
	motion.pop(i)
	var k := MergeEvent.kind(cfg, id)
	var action := ""
	if k == "brush": action = "brush"
	elif k == "reward" and (again or MergeEvent.is_bubble(cfg, id)): action = "collect"
	elif k in ["light", "mural"] and again and MergeEvent.next_id(cfg, id) == "": action = "collect"
	if action == "":
		Sfx.play("tap")
		return true
	_tap_busy = true
	var result: Dictionary = await MergeEvent.act(cfg, action, {"cell": i, "view": int(round(camera))})
	_tap_busy = false
	if not is_instance_valid(self): return false
	if result.has("error"):
		if str(result["error"]) != "": G.main.toast(str(result["error"]))
		Sfx.play("deny")
		motion.shake(i)
		return true
	match str(result["kind"]):
		"brush":
			motion.fly(str(result["id"]), center(i), int(result["to"]))
			Sfx.play("pop")
		"collect":
			selected = -1
			motion.burst(center(i))
			_fx("collect", center(i), {"id": id, "text": TextCatalog.source("ui.mergeeventboard.81b7fd46fcd1") if bool(result.get("bubble", false)) else ""})
			Sfx.play("pop")
		"hang":
			selected = -1
			motion.burst(center(i))
			_fx("text", center(i) + Vector2(0, -cell * 0.5), {"text": TextCatalog.source("ui.mergeeventboard.21ea3ee33e08"), "color": Color("ffd68a"), "size": 30})
			Sfx.play("fanfare")
	_animate_extras(result, i)
	action_finished.emit(result)
	selection_changed.emit("" if selected < 0 else id, false)
	queue_redraw()
	return selected >= 0

func spawn() -> void:
	# 飞入动画不阻塞下一次投放；逻辑先占格，每次点击都落在独立空格。
	if _spawn_busy or dragging or animating: return
	_spawn_busy = true
	var result: Dictionary = await MergeEvent.act(cfg, "spawn", {"view": int(round(camera))})
	if not is_instance_valid(self): return
	_spawn_busy = false
	if result.has("error"):
		if str(result["error"]) != "": G.main.toast(str(result["error"]))
		Sfx.play("deny")
		return
	var to := int(result["to"])
	Sfx.play("pop")
	if fx.is_valid():
		# 气泡在棋盘外面，飞行画在面板特效层；棋盘这边先藏住目标格。
		incoming[to] = true
		motion.conceal(to)
		fx.call("fly", position + center(to), {"id": str(result["id"]), "from": spawn_origin, "done": func():
			if not is_instance_valid(self): return
			if incoming.has(to): # 玩家手快动过这格时已经收尾
				incoming.erase(to)
				motion.unhide(to)
				motion.pop(to)
			queue_redraw()})
	else:
		motion.fly(str(result["id"]), Vector2(size.x / 2, size.y + cell), to)
	action_finished.emit(result)
