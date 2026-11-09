class_name Guide
extends Control
## 新手引导挂在棋盘界面上，离开棋盘就一起藏起来。
## 升级部落和回到棋盘这几步发生在棋盘外面，临时提到最上层。
## 强引导只有第一次合成和升级部落：半透明黑罩只留出该点的地方。
## 其余是弱引导，不盖黑罩，只留提示和箭头，棋盘可以照常操作。

const SRC := 28
const DST := 29
const VINE2 := 30
const PROD := 31
const SPAWN := 24
const BERRY := 32
const VINE3 := 23
const OPEN_LAND := [28, 22, 29]
const LADDER := [32, 33, 40, 39, 38, 37, 36]
const STRONG := ["merge1", "upgrade"]
const OFF_BOARD := ["to_build", "build", "rewarded", "back"]

var _step := ""
var _text := ""
var _holes: Array[Rect2] = []
var _pass: Array[Rect2] = []
var _anchor := Rect2()
var _sig := ""
var _arrow_on := false
var _arrow_a := Vector2.ZERO
var _arrow_b := Vector2.ZERO
var _merge_a := -1
var _merge_b := -1
var _dim: ColorRect
var _mat: ShaderMaterial
var _frames: DrawBox
var _bubble: DrawBox
var _bust: DrawBox
var _label: Label
var _ghost: DrawBox
var _ghost_id := ""
var _tilt := 0.0
var _point_left := true
var _bust_home := Vector2.ZERO
var _t := 0.0
var _done := false
var _reward_until := 0
var _stones_until := 0
## 全屏领奖盖住引导时先藏起来，领完再把「石头裂开」那一句补上
var _reward_cover := false
var _gave_seed_order := false
var _tw: Tween

func _ready() -> void:
	size = Vector2(720, 1480)
	visible = false
	mouse_filter = MOUSE_FILTER_IGNORE
	_dim = ColorRect.new()
	_dim.size = size
	_dim.mouse_filter = MOUSE_FILTER_IGNORE
	_dim.color = Color(0, 0, 0, 1)
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/dim_holes.gdshader")
	_dim.material = _mat
	add_child(_dim)
	_frames = DrawBox.new()
	_frames.boil = false
	_frames.mouse_filter = MOUSE_FILTER_IGNORE
	_frames.size = size
	_frames.painter = _paint_frames
	add_child(_frames)
	_bubble = DrawBox.new()
	_bubble.mouse_filter = MOUSE_FILTER_IGNORE
	_bubble.painter = func(ci, sz):
		Paint.speech(ci, Rect2(Vector2.ZERO, sz), _point_left)
	add_child(_bubble)
	_bust = DrawBox.new()
	_bust.mouse_filter = MOUSE_FILTER_IGNORE
	_bust.painter = func(ci, sz):
		Paint.bust(ci, sz * 0.5 + Vector2(0, 16), 122)
	add_child(_bust)
	_label = UI.lbl(self, "", Rect2(), 28, Art.INK)
	_label.add_theme_constant_override("line_spacing", 6)
	_ghost = DrawBox.new()
	_ghost.boil = false
	_ghost.mouse_filter = MOUSE_FILTER_IGNORE
	_ghost.visible = false
	_ghost.size = Vector2(140, 140)
	_ghost.painter = func(ci, sz):
		if _ghost_id == "":
			return
		Art.item(ci, _ghost_id, sz * 0.5, Board.ITEM * 1.15, true, _tilt)
	add_child(_ghost)
	G.board_changed.connect(_on_world)
	G.orders_changed.connect(_on_world)
	G.changed.connect(_on_world)

func present() -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	if not G.tutorial_on:
		visible = false
		return
	## 初始棋盘改过、对不上写死的格子时，强引导走不了。
	## 两张教学订单交完并升级部落之后，仍要补上正式订单。
	if not _layout_ok():
		_arm_plain()
		return
	_done = false
	_step = ""
	_sig = ""
	modulate.a = 1.0
	mouse_filter = MOUSE_FILTER_STOP
	visible = true
	var board: Board = G.main.board_screen.board
	board.hide_drag = true
	board.select(-1)
	_ghost.visible = false
	_enter(detect())

func note_merge() -> void:
	_on_world()

## 这一步正在教的那对合成。没有就是 (-1, -1)，棋盘不要另找一对。
func merge_hint() -> Vector2i:
	if not visible or _done:
		return Vector2i(-1, -1)
	return Vector2i(_merge_a, _merge_b)

func allows_drop(a: int, b: int) -> bool:
	if not visible or _done or not _strong():
		return true
	if a == b:
		return true
	match _step:
		"merge1":
			return a == SRC and b == DST
		"vine":
			return _vine_ok(a, b)
		"to_prod":
			return b == PROD and _same(a, b)
		"make_fruit2":
			return b == BERRY and _lock(b) == 1 and _same(a, b)
		"climb":
			var pair := _climb_pair()
			return pair.x >= 0 and a == pair.x and b == pair.y
		_:
			return false

func allows_activate(i: int) -> bool:
	if not visible or _done or not _strong():
		return true
	if _step != "produce" and _step != "produce_more":
		return false
	return i == PROD and spawn_cell() >= 0

func force_drop(i: int) -> String:
	if visible and not _done and _step == "byprod" and _id(i) == "basket_5":
		return "seed_1"
	return ""

func spawn_cell() -> int:
	if not visible or _done or not _strong():
		return -1
	if _step == "produce":
		return SPAWN if _vacant(SPAWN) else -1
	if _step == "produce_more":
		if _vacant(SPAWN):
			return SPAWN
		if _vacant(BERRY):
			return BERRY
	return -1

func _on_world() -> void:
	if Replay.active and Replay.executing: _on_world.call_deferred(); return
	if _done:
		return
	if _step == "plain":
		_check_plain()
		return
	if visible:
		_follow()

func cover_for_reward() -> void:
	if _done or _step == "":
		return
	_reward_cover = true
	visible = false

func _reward_panel_open() -> bool:
	if G.main == null:
		return false
	for p in G.main.popup_layer.get_children():
		if is_instance_valid(p) and (p.has_meta("board_reward") or p.has_meta("reward_screen")):
			return true
	return false

func _process(dt: float) -> void:
	if _done:
		return
	if _reward_panel_open():
		if not _reward_cover and _step != "":
			_reward_cover = true
			visible = false
		return
	if _reward_cover:
		_reward_cover = false
		if _step == "stones":
			_stones_until = Time.get_ticks_msec() + 1600
		if _step == "rewarded":
			_reward_until = Time.get_ticks_msec() + 1100
		if _step != "":
			visible = true
	if not visible:
		return
	_follow()
	_t += dt
	if _arrow_on and is_instance_valid(_frames):
		_frames.queue_redraw()
	if _bust.visible:
		_bust.position = _bust_home + Vector2(0, sin(_t * 2.3) * 5.0)
	var board: Board = G.main.board_screen.board
	if _strong() and board.dragging and board.drag_from >= 0:
		var id := G.cell_id(board.drag_from)
		_ghost.visible = true
		if id != _ghost_id:
			_ghost_id = id
			_ghost.queue_redraw()
		var tilt := clampf((board.drag_pos.x - board.drag_vis.x) * 0.004, -0.25, 0.25)
		if absf(tilt - _tilt) > 0.02:
			_tilt = tilt
			_ghost.queue_redraw()
		var at: Vector2 = board.get_global_transform() * (board.drag_vis + Board.DRAG_LIFT)
		_ghost.position = _to_local(at) - _ghost.size * 0.5
	elif _ghost.visible:
		_ghost.visible = false

func _gui_input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	if _step == "stones":
		_enter(detect())
		accept_event()

func _follow() -> void:
	if _step == "":
		return
	if _step == "stones" and Time.get_ticks_msec() < _stones_until:
		return
	var nxt := detect()
	if _step == "merge1" and nxt != "merge1":
		nxt = "stones"
	if nxt == "done":
		_finish()
		return
	if nxt != _step:
		_enter(nxt)
	else:
		_layout()

func _enter(step: String) -> void:
	if step == "done":
		_finish()
		return
	_step = step
	_sig = ""
	_attach()
	if step == "stones":
		_stones_until = Time.get_ticks_msec() + 1600
	if step == "take3":
		_raise_stash("basket_3")
	if step == "byprod" or step == "submit_seed":
		_ensure_seed_order()
		if step == "byprod" and G.energy < 1 and not Replay.active:
			G.energy = 5
			G.changed.emit()
	if step in ["submit1", "submit2", "submit_seed", "upgrade", "wait_pay", "take3", "byprod"]:
		G.main.board_screen.guide_focus_row()
	_layout()

func detect() -> String:
	if int(G.builds.get("fire", 0)) >= 2:
		var now := Time.get_ticks_msec()
		if _reward_until == 0:
			_reward_until = now + 1100
		if _popup_open() or now < _reward_until or G.main.home.is_building():
			return "rewarded"
		if G.main.screen != "board":
			return "back"
		if _has_open("basket_5"):
			## 草籽单交掉以后，棋盘上的草籽也没了。这时要结束引导，不能回到「掉草籽」再发一张。
			## 读档后 _gave_seed_order 会丢，用声望判断：教学单都不给声望，只有草籽单给 1 点。
			if _seed_order_alive():
				return "submit_seed" if _free("seed_1") else "byprod"
			if _gave_seed_order or G.xp > 0 or G.level > 1:
				return "done"
			return "byprod"
		if _free_count("basket_4") >= 2:
			return "merge5"
		if _free("basket_3") and _vine3_ready():
			return "merge3"
		if _stash_has("basket_3"):
			return "take3"
		return "done"
	if not _order_alive(1) and not _order_alive(2) and _shells_ready():
		if _build_popup():
			return "build"
		if G.main.screen == "home":
			return "to_build"
		var hammer: Control = G.main.board_screen._hammer_btn
		if hammer == null or not hammer.visible or hammer.scale.x < 0.85:
			return "wait_pay"
		return "upgrade"
	if not _order_alive(1) and not _order_alive(2):
		return "wait_pay"
	if not _order_alive(1):
		if _free("fruit_8"):
			return "submit2"
		if _free_count("fruit_1") >= 2 or _best_fruit() >= 2:
			return "climb"
		return "produce_more"
	if _free("fruit_2"):
		return "submit1"
	if _free("fruit_1"):
		return "make_fruit2"
	if _seen("basket_4"):
		return "produce"
	if _seen("basket_3"):
		return "to_prod"
	if _seen("basket_2"):
		return "vine"
	return "merge1"

func _layout() -> void:
	if _step in ["submit1", "submit2", "submit_seed", "upgrade", "wait_pay", "take3", "byprod"]:
		G.main.board_screen.guide_focus_row()
	_holes.clear()
	_pass.clear()
	_arrow_on = false
	_merge_a = -1
	_merge_b = -1
	_anchor = Rect2()
	_text = ""
	_fill_step()
	for h in _holes:
		_pass.append(h.grow(6))
	_label.text = _text
	if G.main != null and G.main.board_screen != null:
		G.main.board_screen.board.hide_drag = _strong()
	mouse_filter = MOUSE_FILTER_STOP if _strong() else MOUSE_FILTER_IGNORE
	var sig := _step + "|" + str(_holes)
	_sync_mask()
	if sig == _sig:
		return
	_sig = sig
	_place()
	_frames.queue_redraw()
	_bubble.queue_redraw()

func _fill_step() -> void:
	match _step:
		"merge1":
			_text = "把左边的干草束\n拖到右边合成"
			_merge_a = SRC
			_merge_b = DST
			_add_cells([DST, SRC])
			if not _holes.is_empty():
				var u := _holes[0]
				_arrow_on = true
				_arrow_a = u.position + Vector2(u.size.x * 0.22, -34)
				_arrow_b = u.position + Vector2(u.size.x * 0.78, -34)
			_anchor = _union()
		"stones":
			_text = "旁边的石头裂开了"
			_add_cells([DST, VINE2, SRC, 22, 36])
			_anchor = _union()
		"vine":
			_text = "拖到藤蔓上可以合成\n空地也可以放物品"
			_add_cells([DST, VINE2, SRC, 22, 36])
			_aim(_open_id("basket_2"), VINE2 if _lock(VINE2) == 1 and _id(VINE2) == "basket_2" else -1)
			_anchor = _union()
		"to_prod":
			_text = "再合成，做出4级小草篓\n小草篓才能生产"
			_add_cells([VINE2, PROD])
			_aim(_open_id("basket_3"), PROD if _id(PROD) == "basket_3" and _lock(PROD) != 2 else -1)
			_anchor = _union()
		"produce":
			_text = "点一下小草篓\n野莓会落到旁边"
			_add_cells([PROD, SPAWN])
			_anchor = _cell_local(PROD)
		"make_fruit2":
			_text = "把两颗野莓合成樱桃\n就能交订单"
			_add_cells([SPAWN, BERRY])
			_aim_fruit2()
			_anchor = _union()
		"submit1":
			_text = "点订单上的对勾\n把樱桃交出去"
			_add_cells(_free_cells("fruit_2"))
			_add_global(G.main.board_screen.guide_deliver_rect())
			_anchor = _holes.back() if not _holes.is_empty() else Rect2()
		"produce_more":
			_text = "再点小草篓，多做几颗野莓\n合成更高级的水果"
			_add_cells([PROD, SPAWN, BERRY])
			_anchor = _cell_local(PROD)
		"climb":
			_text = "继续拖到藤蔓上合成\n一路做到8级石榴"
			var pair := _climb_pair()
			if pair.x >= 0:
				_add_cells([pair.x, pair.y])
				_aim(pair.x, pair.y)
			_anchor = _union()
		"submit2":
			_text = "石榴做好了\n交给订单"
			_add_cells(_free_cells("fruit_8"))
			_add_global(G.main.board_screen.guide_deliver_rect())
			_anchor = _holes.back() if not _holes.is_empty() else Rect2()
		"wait_pay":
			_text = "贝币正在回来\n刚好够升级部落"
			_add_global(_shell_rect())
			_anchor = _union()
		"upgrade":
			_text = "贝币刚好够了\n点这里升级部落"
			_add_ctrl(G.main.board_screen._hammer_btn)
			_anchor = _union()
		"to_build":
			_text = "正在打开部落升级"
			_anchor = Rect2(160, 280, 400, 80)
		"build":
			_text = "点绿色按钮升级\n还有一只半编草篓"
			for pp in G.main.popup_layer.get_children():
				if pp.has_meta("build_rects"):
					for br in pp.get_meta("build_rects"):
						_add_popup((br as Rect2).grow(6))
			_anchor = _union()
		"rewarded":
			_text = "半编草篓进了暂存区"
			_anchor = Rect2(150, 280, 420, 80)
		"back":
			_text = "回到棋盘\n把半编草篓合成上去"
			if G.main.home != null and G.main.home.go != null:
				_add_ctrl(G.main.home.go)
			_anchor = _union()
		"take3":
			_text = "升级送了半编草篓\n点暂存区放到棋盘"
			_add_global(G.main.board_screen._stash_wrap.get_global_rect())
			_anchor = _union()
		"merge3":
			_text = "拖到藤蔓上的半编草篓\n合成4级小草篓"
			var src3 := _open_id("basket_3")
			var cells3: Array = []
			if src3 >= 0:
				cells3.append(src3)
			if _vine3_ready():
				cells3.append(VINE3)
			_add_cells(cells3)
			_aim(src3, VINE3 if _vine3_ready() else -1)
			_anchor = _union()
		"merge5":
			_text = "再和你的4级小草篓合成\n5级才会掉副产物"
			var pair := _basket4_pair()
			if pair.x >= 0:
				_add_cells([pair.x, pair.y])
				_aim(pair.x, pair.y)
			_anchor = _union()
		"byprod":
			_text = "点一下藤篮\n这次掉出的是草籽"
			var gen := _open_id("basket_5")
			if gen >= 0:
				_add_cells([gen])
			_anchor = _union()
		"submit_seed":
			_text = "草籽是副产物\n交给这张有经验的订单"
			_add_cells(_free_cells("seed_1"))
			_add_global(G.main.board_screen.guide_deliver_rect())
			_anchor = _holes.back() if not _holes.is_empty() else Rect2()

func _finish() -> void:
	if _done:
		return
	_done = true
	_step = ""
	if Replay.active:
		Replay.perform("tutorial_finish")
	else:
		G.seen_tutorial = true
		G.tutorial_on = false
	if G.main != null and G.main.board_screen != null:
		G.main.board_screen.board.hide_drag = false
	_ghost.visible = false
	mouse_filter = MOUSE_FILTER_IGNORE
	_grant_normal_orders()
	G.dirty()
	_tw = create_tween()
	_tw.tween_property(self, "modulate:a", 0.0, 0.32)
	_tw.tween_callback(func():
		visible = false
		modulate.a = 1.0)

## 棋盘布局和写死的教学路线不一致。不盖黑罩，等部落升过一次、两张教学订单都交掉，再发正式订单。
func _arm_plain() -> void:
	_done = false
	_step = "plain"
	visible = false
	mouse_filter = MOUSE_FILTER_IGNORE
	if G.main != null and G.main.board_screen != null:
		G.main.board_screen.board.hide_drag = false
	_check_plain()

func _check_plain() -> void:
	if int(G.builds.get("fire", 0)) < 2:
		return
	if _order_alive(1) or _order_alive(2):
		return
	_finish()

func _grant_normal_orders() -> void:
	if not Replay.active: G.refill_orders()

func _place() -> void:
	var bust_sz := Vector2(200, 292)
	var bw := 500.0
	var bh := 148.0
	var margin := 16.0
	## 棋盘中部是解开的空地。角色和气泡固定贴在底部，只压住还锁着的最下两排。
	var top := 1124.0
	var h := _anchor
	if h.size.x > 1.0 and Rect2(0, top, size.x, size.y - top).intersects(h):
		top = h.position.y - bust_sz.y - 8.0
	top = clampf(top, 96.0, size.y - 120.0)
	_bust.visible = true
	_bust.size = bust_sz
	_bust.position = Vector2(-20, top)
	_bust_home = _bust.position
	var bx := 168.0
	var by := clampf(top + 108.0, top + 8.0, size.y - bh - margin)
	_set_bubble(Rect2(bx, by, minf(bw, size.x - bx - margin), bh), true)

func _set_bubble(r: Rect2, point_left: bool) -> void:
	_point_left = point_left
	_bubble.position = r.position
	_bubble.size = r.size
	_label.position = r.position + Vector2(28, 12)
	_label.size = r.size - Vector2(56, 24)

func _paint_frames(ci: CanvasItem, _sz: Vector2) -> void:
	if _strong():
		for h in _holes:
			var frame := Art.rrect(h.grow(7), 16, 4, 0.45)
			Art.outline(ci, frame, 6.0, Color("ffe7a8"))
			Art.outline(ci, frame, 2.6, Art.INK)
	if not _arrow_on:
		return
	_paint_merge_arrow(ci)

## 合成指引：两格柔光 + 一条弯弯的贴纸箭头（墨线 / 奶白边 / 赭黄芯），箭身上有小箭头往前流动。
## 合并引导：一支简单的白色弧形箭头（细墨边），从起点格指向终点格，随呼吸轻轻往前顶。
func _paint_merge_arrow(ci: CanvasItem) -> void:
	var a := _arrow_a
	var b := _arrow_b
	var d := b - a
	if d.length() < 8.0:
		return
	var pulse := 0.5 + 0.5 * sin(_t * 4.0)
	var n := d.normalized().orthogonal()
	if n.y > 0.0:
		n = -n
	var ctrl := (a + b) * 0.5 + n * minf(40.0, d.length() * 0.3)
	var pts := PackedVector2Array()
	for k in 21:
		var u := float(k) / 20.0
		pts.append(a.lerp(ctrl, u).lerp(ctrl.lerp(b, u), u))
	var push := (pts[20] - pts[18]).normalized() * pulse * 4.0
	var tip := pts[20] + push
	var tdir := (pts[20] - pts[18]).normalized()
	var tn := tdir.orthogonal()
	var head_len := 24.0
	var base := tip - tdir * head_len
	var body := PackedVector2Array()
	for p in pts:
		if (p - a).length() < (base - push - a).length():
			body.append(p + push * 0.5)
	body.append(base)
	# 箭身：尾巴尖、往箭头方向逐渐变粗，整支是一块多边形
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for k in body.size():
		var u := float(k) / float(body.size() - 1)
		var dir := (body[mini(k + 1, body.size() - 1)] - body[maxi(k - 1, 0)]).normalized()
		var w := lerpf(0.5, 5.5, sqrt(u))
		left.append(body[k] + dir.orthogonal() * w)
		right.append(body[k] - dir.orthogonal() * w)
	var shape := PackedVector2Array()
	shape.append_array(left)
	shape.append(base + tn * 17.0)
	shape.append(tip)
	shape.append(base - tn * 17.0)
	right.reverse()
	shape.append_array(right)
	Art.dilate(ci, shape, 3.0, Art.INK)
	ci.draw_colored_polygon(shape, Color.WHITE)

func _sync_mask() -> void:
	var arr := PackedVector4Array()
	arr.resize(8)
	var n := mini(_holes.size(), 8)
	for i in n:
		var h := _holes[i]
		arr[i] = Vector4(h.position.x, h.position.y, h.size.x, h.size.y)
	var strong := _strong()
	_dim.visible = strong
	_mat.set_shader_parameter("holes", arr)
	_mat.set_shader_parameter("hole_count", n if strong else 0)
	_mat.set_shader_parameter("screen_px", size)
	_mat.set_shader_parameter("dim_a", 0.76 if strong else 0.0)

func _attach() -> void:
	if G.main == null or G.main.board_screen == null:
		return
	var on_board := not (_step in OFF_BOARD)
	var host: Node = G.main.board_screen if on_board else G.main
	if get_parent() != host:
		if get_parent() != null:
			get_parent().remove_child(self)
		host.add_child(self)
	host.move_child(self, host.get_child_count() - 1)

func _strong() -> bool:
	return _step in STRONG

func _open_id(id: String) -> int:
	for i in G.board.size():
		if _lock(i) == 0 and _id(i) == id:
			return i
	return -1

func _aim(a: int, b: int) -> void:
	if a < 0 or b < 0:
		return
	_merge_a = a
	_merge_b = b
	var ca := _cell_local(a).get_center()
	var cb := _cell_local(b).get_center()
	var dir := cb - ca
	if dir.length() < 8.0:
		return
	var n := dir.normalized().orthogonal()
	if n.y > 0.0:
		n = -n
	var lift := n * 30.0
	_arrow_on = true
	_arrow_a = ca + lift
	_arrow_b = cb - dir.normalized() * 18.0 + lift

func _aim_fruit2() -> void:
	var from := -1
	var ones := _free_cells("fruit_1")
	for i in ones:
		if int(i) != BERRY:
			from = int(i)
			break
	var to := BERRY if _lock(BERRY) == 1 and _id(BERRY) == "fruit_1" else -1
	if to < 0 and ones.size() >= 2:
		from = int(ones[0])
		to = int(ones[1])
	_aim(from, to)

func _has_point(point: Vector2) -> bool:
	if _done or not visible or not _strong():
		return false
	for r in _pass:
		if r.has_point(point):
			return false
	return true

func _add_cells(indices: Array) -> void:
	var rs: Array[Rect2] = []
	for i in indices:
		rs.append(_cell_local(int(i)))
	if rs.is_empty():
		return
	var u := rs[0]
	var area := 0.0
	for r in rs:
		u = u.merge(r)
		area += r.size.x * r.size.y
	if absf(u.get_area() - area) < 8.0:
		_holes.append(u)
	else:
		for r in rs:
			_holes.append(r)

func _add_global(g: Rect2) -> void:
	if g.size.x < 2.0 or g.size.y < 2.0:
		return
	var a := _to_local(g.position)
	var b := _to_local(g.position + g.size)
	_holes.append(Rect2(a, b - a).abs())

func _add_ctrl(c: Control) -> void:
	if c == null or not is_instance_valid(c):
		return
	var parent := c.get_parent() as Control
	if parent == null:
		_add_global(c.get_global_rect())
		return
	var xf := parent.get_global_transform()
	var a: Vector2 = xf * c.position
	var b: Vector2 = xf * (c.position + c.size)
	_add_global(Rect2(a, b - a).abs())

func _add_popup(local: Rect2) -> void:
	for p in G.main.popup_layer.get_children():
		if not (p is PopupBase):
			continue
		var box: Control = (p as PopupBase).box
		var xf := box.get_global_transform()
		var a: Vector2 = xf * local.position
		var b: Vector2 = xf * (local.position + local.size)
		_add_global(Rect2(a, b - a).abs())
		return

func _cell_local(i: int) -> Rect2:
	var board: Board = G.main.board_screen.board
	var r := board.cell_rect(i)
	var xf := board.get_global_transform()
	var a: Vector2 = xf * r.position
	var b: Vector2 = xf * (r.position + r.size)
	return Rect2(_to_local(a), _to_local(b) - _to_local(a)).abs()

func _to_local(g: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * g

func _union() -> Rect2:
	if _holes.is_empty():
		return Rect2()
	var u := _holes[0]
	for i in range(1, _holes.size()):
		u = u.merge(_holes[i])
	return u

## 初始棋盘（data/board.json）是否还对得上写死的教学路线。返回问题列表，空数组表示没问题。
## 配置页保存棋盘时会调用，提醒策划：路线对不上时新玩家会跳过整段引导。
static func layout_problems(cells: Array, locks: Array) -> Array:
	var need := {
		SRC: ["basket_1", 0], DST: ["basket_1", 0], VINE2: ["basket_2", 2], PROD: ["basket_3", 2],
		SPAWN: ["", 2], VINE3: ["basket_3", 2], 22: ["", 2],
	}
	for k in LADDER.size():
		need[LADDER[k]] = ["fruit_%d" % (k + 1), 2]
	var out: Array = []
	for i in need:
		var id := str(cells[i]) if i < cells.size() else ""
		var lk := int(locks[i]) if i < locks.size() else 2
		var want: Array = need[i]
		if id != str(want[0]) or lk != int(want[1]):
			var name := "空格" if str(want[0]) == "" else Data.name_of(str(want[0]))
			out.append("第 %d 行第 %d 列应是%s%s" % [i / 7 + 1, i % 7 + 1, name, "（开放）" if int(want[1]) == 0 else "（巨石下）"])
	return out

func _layout_ok() -> bool:
	if _id(SRC) == "basket_1" and _id(DST) == "basket_1" and _lock(SRC) == 0 and _lock(DST) == 0:
		return true
	if _id(PROD).begins_with("basket_") and _lock(PROD) != 2:
		return true
	for i in LADDER:
		if _id(i).begins_with("fruit_") and _lock(i) != 2:
			return true
	return false

func _shell_rect() -> Rect2:
	return TopBar.PILLS["shell"]

func _vine_ok(a: int, b: int) -> bool:
	if b == VINE2 and _lock(b) == 1 and _same(a, b):
		return true
	return _lock(b) == 0 and _id(b) == "" and b in OPEN_LAND

func _climb_pair() -> Vector2i:
	var ones: Array[int] = []
	for i in G.board.size():
		if _lock(i) == 0 and _id(i) == "fruit_1":
			ones.append(i)
	if ones.size() >= 2:
		var target := ones[1]
		if ones.has(BERRY):
			target = BERRY
		var src := ones[0] if ones[0] != target else ones[1]
		return Vector2i(src, target)
	var best_from := -1
	var best_to := -1
	var best_lv := -1
	for i in G.board.size():
		if _lock(i) != 0 or not _id(i).begins_with("fruit_"):
			continue
		var v := _vine_beside(i)
		if v < 0:
			continue
		var lv := Data.lv(_id(i))
		if lv > best_lv:
			best_lv = lv
			best_from = i
			best_to = v
	return Vector2i(best_from, best_to)

func _vine_beside(i: int) -> int:
	var id := _id(i)
	var found := -1
	var c := i % G.COLS
	var r := int(i / G.COLS)
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nc: int = c + d.x
		var nr: int = r + d.y
		if nc < 0 or nr < 0 or nc >= G.COLS or nr >= G.ROWS:
			continue
		var k := G.idx(nc, nr)
		if _lock(k) == 1 and _id(k) == id:
			if k in LADDER:
				return k
			if found < 0:
				found = k
	return found

func _same(a: int, b: int) -> bool:
	return _id(a) != "" and _id(a) == _id(b)

func _id(i: int) -> String:
	return str(G.board[i]["id"])

func _lock(i: int) -> int:
	return int(G.board[i]["lock"])

func _vacant(i: int) -> bool:
	return _id(i) == "" and _lock(i) == 0

func _free(id: String) -> bool:
	return not _free_cells(id).is_empty()

func _free_cells(id: String) -> Array:
	var out := []
	for i in G.board.size():
		if _lock(i) == 0 and _id(i) == id:
			out.append(i)
	return out

func _free_count(id: String) -> int:
	return _free_cells(id).size()

func _best_fruit() -> int:
	var best := 0
	for i in G.board.size():
		if _lock(i) != 0 or not _id(i).begins_with("fruit_"):
			continue
		best = maxi(best, Data.lv(_id(i)))
	return best

func _seen(id: String) -> bool:
	for i in G.board.size():
		if i == VINE3 and _id(i) == "basket_3" and _lock(i) == 1:
			continue
		if _id(i) == id and _lock(i) != 2:
			return true
	return false

func _has_open(id: String) -> bool:
	for i in G.board.size():
		if _id(i) == id and _lock(i) != 2:
			return true
	return false

func _vine3_ready() -> bool:
	return _id(VINE3) == "basket_3" and _lock(VINE3) == 1

func _stash_has(id: String) -> bool:
	for it in G.stash:
		if str(it) == id:
			return true
	return false

func _raise_stash(id: String) -> void:
	if Replay.active: return
	var at := -1
	for i in range(G.stash.size() - 1, -1, -1):
		if str(G.stash[i]) == id:
			at = i
			break
	if at < 0 or at == G.stash.size() - 1:
		return
	var item = G.stash[at]
	G.stash.remove_at(at)
	G.stash.append(item)
	G.dirty()
	G.changed.emit()

func _seed_order_alive() -> bool:
	for o in G.orders:
		var items: Array = o.get("items", [])
		if items.size() == 1 and str(items[0]) == "seed_1":
			return true
	return false

## 引导最后一步的副产物订单。它是教学的一部分，不看速查表开没开草籽；声望算进 1 级要的 3 点里。
func _ensure_seed_order() -> void:
	if Replay.active: return
	_gave_seed_order = true
	if _seed_order_alive():
		return
	G.orders.insert(0, {"who": 1, "items": ["seed_1"], "rw": {"xp": 1, "shell": 50}, "story": true, "say": "草籽能种出新的果树，你学得真快！"})
	G.orders_changed.emit()
	G.dirty()

func _basket4_pair() -> Vector2i:
	var cells := _free_cells("basket_4")
	if cells.size() < 2:
		return Vector2i(-1, -1)
	var target := int(cells[1])
	if _id(PROD) == "basket_4" and _lock(PROD) == 0:
		target = PROD
	var src := int(cells[0])
	if src == target:
		src = int(cells[1])
	return Vector2i(src, target)

func _order_alive(n: int) -> bool:
	for o in G.orders:
		if int(o.get("tutorial", 0)) == n:
			return true
	return false

func _shells_ready() -> bool:
	var id := G.next_build_id()
	return id != "" and G.shells >= G.build_cost(id)

func _popup_open() -> bool:
	return G.main != null and G.main.popup_layer.get_child_count() > 0

func _build_popup() -> bool:
	if not _popup_open():
		return false
	for p in G.main.popup_layer.get_children():
		if _find_shell_btn(p) != null:
			return true
	return false

func _find_shell_btn(n: Node) -> TButton:
	if n is TButton and str((n as TButton).res) == "shell_2":
		return n
	for c in n.get_children():
		var f := _find_shell_btn(c)
		if f != null:
			return f
	return null
