class_name Guide
extends Control
## 新手引导挂在棋盘界面上，离开棋盘就一起藏起来。
## 升级部落和回到棋盘这几步发生在棋盘外面，临时提到最上层。
## 流程照竞品：合成→打开石头里的东西→合出生产器（弹「新生产器」）→生产→交两单→第一次建设→讲订单和等级。
## 关键节点先说一句「点击继续」的剧情句。生产器升级放到第二次建设送礼物之后，由一次性提示（Tips）带。
## 每一步都是强引导：全屏黑罩只留出这一步要点、要拖的地方，别处点不动。
## 只有棋盘布局对不上、走「plain」兜底时不盖黑罩。

const Meme := preload("res://scripts/Meme.gd")
const SRC := 28
const DST := 29
const VINE2 := 30
const PROD := 31
const SPAWN := 24
const BERRY := 32
const VINE3 := 23
const OPEN_LAND := [28, 22, 29]
const LADDER := [32, 33, 40, 39, 38, 37, 36]
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
## 进入当前步骤的时刻（毫秒）
var _step_at := 0
## 正在说的剧情句（步骤名），空表示没有
var _beat := ""
var _beat_at := 0
var _cont: Label
## 教学订单客人的称呼缓存：订单交掉后还要说出名字
var _who_cache := {}
## 全屏领奖盖住引导时先藏起来，领完再把「石头裂开」那一句补上
var _reward_cover := false
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
		Meme.walker_portrait(ci, Meme.HERO, Vector2(sz.x * 0.5, sz.y - 6.0), sz.x - 14.0)
	add_child(_bust)
	_label = UI.lbl(self, "", Rect2(), 26, Art.INK)
	_label.add_theme_constant_override("line_spacing", 6)
	_cont = UI.lbl(self, "点击继续", Rect2(), 22, Color("4f9a3a"), HORIZONTAL_ALIGNMENT_RIGHT)
	_cont.visible = false
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
	if _beat != "":
		return false
	if a == b:
		return true
	match _step:
		"merge1":
			return a == SRC and b == DST
		"vine", "stones":
			## 石头刚裂开那一下也能接着合，不用等提示走完
			return _vine_ok(a, b)
		"to_prod":
			return b == PROD and _same(a, b)
		"make_fruit2":
			return b != BERRY and _lock(a) == 0 and _lock(b) == 0 and _same(a, b)
		"climb":
			var pair := _climb_pair()
			return pair.x >= 0 and a == pair.x and b == pair.y
		_:
			return false

func allows_activate(i: int) -> bool:
	if not visible or _done or not _strong():
		return true
	if _beat != "":
		return false
	## 爬藤时手上没有能合的果子（比如棋盘被打乱了），放开小草篓，免得卡死。
	if _step == "climb" and _climb_pair().x < 0:
		return i == PROD
	if _step != "produce" and _step != "produce_more":
		return false
	## 落点由规则决定（优先 24、32 格，满了就近放），这里只限定点小草篓
	return i == PROD

func force_drop(_i: int) -> String:
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
	if Replay.executing: _on_world.call_deferred(); return
	if not G.tutorial_on:
		_done = true
		_step = ""
		visible = false
		mouse_filter = MOUSE_FILTER_IGNORE
		_ghost.visible = false
		if G.main != null and G.main.board_screen != null: G.main.board_screen.board.hide_drag = false
		return
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
		var id := G.rules.board.cell_id(board.drag_from)
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
	if _beat != "":
		accept_event()
		if Time.get_ticks_msec() - _beat_at > 400:
			skip_beat()
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
		_open_build_if_stuck()

func _enter(step: String) -> void:
	if step == "done":
		_finish()
		return
	_step = step
	_step_at = Time.get_ticks_msec()
	_sig = ""
	_attach()
	if step == "stones":
		_stones_until = Time.get_ticks_msec() + 1600
	_beat = ""
	if _beat_text(step) != "" and not G.tips_seen.has("guide_beat_" + step):
		G.tips_seen["guide_beat_" + step] = true
		_beat = step
		_beat_at = Time.get_ticks_msec()
	if step in ["submit1", "submit2", "upgrade", "wait_pay", "level"]:
		G.main.board_screen.guide_focus_row()
	_layout()

## 「正往部落里走」蒙着黑、别处点不动：到了部落 1.5 秒还没弹出升级窗，就由引导直接打开，不能卡住
func _open_build_if_stuck() -> void:
	if _step != "to_build" or Time.get_ticks_msec() - _step_at < 1500:
		return
	if G.main.screen != "home" or _popup_open() or G.main.home.is_building():
		return
	var id := G.rules.progression.next_build_id()
	if id == "":
		return
	_step_at = Time.get_ticks_msec()
	G.main.open("build", id)

func detect() -> String:
	if int(G.builds.get("fire", 0)) >= 2:
		var now := Time.get_ticks_msec()
		if _reward_until == 0:
			_reward_until = now + 1100
		## 玩家点开了等级详情：引导到此结束
		if _step == "level" and _popup_open():
			G.tips_seen["guide_level"] = true
			return "done"
		if _popup_open() or now < _reward_until or G.main.home.is_building():
			return "rewarded"
		if G.main.screen != "board":
			return "back"
		if not G.tips_seen.has("guide_level"):
			return "level"
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
		if _free_count("fruit_1") >= 2 or _best_fruit() >= 2 or (_free("fruit_1") and _berry_ready()):
			return "climb"
		return "produce_more"
	if _free("fruit_2"):
		return "submit1"
	## 第一张单的樱桃用两颗摘下来的野莓在空地上合，不碰藤蔓：藤蔓下的樱桃要等交完单爬藤时才露出来，
	## 免得同一颗樱桃「交单」和「开藤蔓」只能选一个。
	if _free_count("fruit_1") >= 2:
		return "make_fruit2"
	if _seen("basket_4"):
		return "produce"
	if _seen("basket_3"):
		return "to_prod"
	if _seen("basket_2"):
		return "vine"
	return "merge1"

func _layout() -> void:
	if _step in ["submit1", "submit2", "upgrade", "wait_pay", "level"]:
		G.main.board_screen.guide_focus_row()
	_holes.clear()
	_pass.clear()
	_arrow_on = false
	_merge_a = -1
	_merge_b = -1
	_anchor = Rect2()
	_text = ""
	_fill_step()
	if _beat != "":
		_text = _beat_text(_beat)
		_arrow_on = false
		_merge_a = -1
		_merge_b = -1
	## 等不拿拿飞回来、剧情句时只亮出来给玩家看，不让点。
	if _step != "wait_pay" and _beat == "":
		for h in _holes:
			_pass.append(h.grow(6))
	_label.text = _text
	_cont.visible = _beat != "" or _step == "stones"
	if G.main != null and G.main.board_screen != null:
		G.main.board_screen.board.hide_drag = _strong()
	mouse_filter = MOUSE_FILTER_STOP if _strong() else MOUSE_FILTER_IGNORE
	var sig := _step + "|" + _beat + "|" + str(_holes)
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
			_text = "把两个一样的东西拖到一起\n就能合成更高级的！"
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
			_text = "在石头旁边合成\n就能把石头震开！"
			_add_cells([DST, VINE2, SRC, 22, 36])
			_anchor = _union()
		"vine":
			_text = "石头里露出了东西\n拖一样的过去就能打开它"
			_add_cells([DST, VINE2, SRC, 22, 36])
			_aim(_open_id("basket_2"), VINE2 if _lock(VINE2) == 1 and _id(VINE2) == "basket_2" else -1)
			_anchor = _union()
		"to_prod":
			_text = "再合一次就是小草篓\n小草篓能摘出野莓！"
			_add_cells([VINE2, PROD])
			_aim(_open_id("basket_3"), PROD if _id(PROD) == "basket_3" and _lock(PROD) != 2 else -1)
			_anchor = _union()
		"produce":
			_text = "点一下小草篓\n摘点野莓来！" if not _free("fruit_1") else "再点一下\n多摘一颗野莓！"
			_add_cells([PROD, SPAWN])
			_anchor = _cell_local(PROD)
		"make_fruit2":
			_text = "继续合成，发现新东西！\n两颗野莓能合成樱桃"
			var ones := _fruit2_pair()
			if ones.x >= 0:
				_add_cells([ones.x, ones.y])
				_aim(ones.x, ones.y)
			_anchor = _union()
		"submit1":
			_text = "樱桃好啦！\n点对勾交给%s" % _who(1)
			_add_cells(_free_cells("fruit_2"))
			_add_global(G.main.board_screen.guide_deliver_rect())
			_anchor = _holes.back() if not _holes.is_empty() else Rect2()
		"produce_more":
			_text = "点小草篓摘更多野莓\n继续帮族人实现心愿吧！"
			_add_cells([PROD, SPAWN, BERRY])
			_anchor = _cell_local(PROD)
		"climb":
			_text = "顺着藤蔓一路合上去\n合出8级石榴！"
			var pair := _climb_pair()
			if pair.x >= 0:
				_add_cells([pair.x, pair.y])
				_aim(pair.x, pair.y)
			else:
				_add_cells([PROD])
			_anchor = _union()
		"submit2":
			_text = "石榴做好了！\n点对勾交给%s" % _who(2)
			_add_cells(_free_cells("fruit_8"))
			_add_global(G.main.board_screen.guide_deliver_rect())
			_anchor = _holes.back() if not _holes.is_empty() else Rect2()
		"wait_pay":
			_text = "族人的谢礼到手啦！"
			_add_global(_shell_rect())
			_anchor = _union()
		"upgrade":
			_text = "点这里\n开始建设部落"
			_add_ctrl(G.main.board_screen._hammer_btn)
			_anchor = _union()
		"to_build":
			_text = "正在前往部落……"
			_anchor = Rect2(160, 280, 400, 80)
		"build":
			_text = "先把柴火堆建起来\n点绿色按钮"
			for pp in G.main.popup_layer.get_children():
				if pp.has_meta("build_rects"):
					for br in pp.get_meta("build_rects"):
						_add_popup((br as Rect2).grow(6))
			_anchor = _union()
		"rewarded":
			_text = "建好啦！\n部落有点模样了"
			_anchor = Rect2(150, 280, 420, 80)
		"back":
			_text = "点这里回到棋盘\n继续帮族人"
			if G.main.home != null and G.main.home.go != null:
				_add_ctrl(G.main.home.go)
			_anchor = _union()
		"level":
			_text = "帮族人实现心愿能涨经验，再实现 %d 个就升级\n点这里看看升级能拿什么" % maxi(1, G.rules.progression.xp_need() - G.xp)
			_add_ctrl(G.main.board_screen._base_btn)
			_anchor = _union()

## 竞品式「点击继续」剧情句：进入这些步骤前先说一句，目标亮着但点不了，点任意处才开始操作。每句只说一次。
func _beat_text(step: String) -> String:
	match step:
		"merge1": return "你就是新来的伙伴吧！\n部落正缺人手，快来帮帮我"
		"produce": return "太棒了！有了小草篓\n我们就能摘到野莓啦"
		"produce_more": return "第一个心愿实现啦！\n%s吃得可开心了" % _who(1)
		"upgrade": return "不拿拿攒够了！\n是时候把我们的部落建起来了"
		"back": return "多帮族人、多攒不拿拿\n部落就会越来越热闹"
		"level": return "部落热闹起来啦！\n东西备齐了，记得点对勾送给族人"
	return ""

## 跳过当前剧情句（点任意处）
func skip_beat() -> void:
	if _beat == "":
		return
	_beat = ""
	_sig = ""
	_layout()

func _finish() -> void:
	if _done:
		return
	_done = true
	_step = ""
	Replay.perform("tutorial_finish")
	if G.main != null and G.main.board_screen != null:
		G.main.board_screen.board.hide_drag = false
	_ghost.visible = false
	mouse_filter = MOUSE_FILTER_IGNORE
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

## 头像 + 气泡贴在这一步要操作的区域旁边：默认放在下方，下面放不下就放上方；没有目标时放在底部。
const AVATAR := 120.0
const TALK_W := 620.0
const TALK_H := 140.0

func _place() -> void:
	var h := _anchor
	var x := (size.x - TALK_W) * 0.5
	var y := 1120.0
	if h.size.x > 1.0:
		x = clampf(h.get_center().x - TALK_W * 0.5, 16.0, size.x - 16.0 - TALK_W)
		y = h.end.y + 22.0
		if y + TALK_H > size.y - 30.0:
			y = h.position.y - 22.0 - TALK_H
		y = clampf(y, 90.0, size.y - TALK_H - 30.0)
	_bust.visible = true
	_bust.size = Vector2(AVATAR, AVATAR)
	_bust.position = Vector2(x, y + (TALK_H - AVATAR) * 0.5)
	_bust_home = _bust.position
	_set_bubble(Rect2(x + AVATAR + 8.0, y, TALK_W - AVATAR - 8.0, TALK_H), true)

func _set_bubble(r: Rect2, point_left: bool) -> void:
	_point_left = point_left
	_bubble.position = r.position
	_bubble.size = r.size
	_label.position = r.position + Vector2(28, 10)
	_label.size = r.size - Vector2(56, 40)
	_cont.position = Vector2(r.position.x + 28, r.end.y - 38)
	_cont.size = Vector2(r.size.x - 56, 30)

func _paint_frames(ci: CanvasItem, _sz: Vector2) -> void:
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
	return _step != "" and _step != "plain"

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

## 两颗摊开的野莓，优先合到 24 格（离藤蔓樱桃远，不会把它震出来）
func _fruit2_pair() -> Vector2i:
	var ones := _free_cells("fruit_1")
	if ones.size() < 2:
		return Vector2i(-1, -1)
	var to := int(ones[1])
	if ones.has(SPAWN):
		to = SPAWN
	var from := int(ones[0]) if int(ones[0]) != to else int(ones[1])
	return Vector2i(from, to)

func _has_point(point: Vector2) -> bool:
	if _done or not visible or not _strong():
		return false
	if G.main != null and G.main.board_screen != null:
		var gm: Control = G.main.board_screen.get_node_or_null("gm_activities")
		if gm != null and gm.is_visible_in_tree() and gm.get_global_rect().has_point(get_global_transform() * point):
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

func _berry_ready() -> bool:
	return _id(BERRY) == "fruit_1" and _lock(BERRY) == 1

func _climb_pair() -> Vector2i:
	var ones: Array[int] = []
	for i in G.board.size():
		if _lock(i) == 0 and _id(i) == "fruit_1":
			ones.append(i)
	## 先把野莓合到藤蔓上那颗：樱桃落在藤蔓樱桃旁边，后面一路往上爬
	if not ones.is_empty() and _berry_ready():
		return Vector2i(ones[0], BERRY)
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
		var k := G.rules.board.idx(nc, nr)
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

func _vine3_ready() -> bool:
	return _id(VINE3) == "basket_3" and _lock(VINE3) == 1

## 教学订单客人的称呼（取订单上的人物，和订单卡上显示的名字一致）
func _who(n: int) -> String:
	for o in G.orders:
		if int(o.get("tutorial", 0)) == n:
			_who_cache[n] = Meme.customer_name(int(o.get("who", 0)), true)
	return str(_who_cache.get(n, "大伙"))

func _order_alive(n: int) -> bool:
	for o in G.orders:
		if int(o.get("tutorial", 0)) == n:
			return true
	return false

func _shells_ready() -> bool:
	var id := G.rules.progression.next_build_id()
	return id != "" and G.shells >= G.rules.progression.build_cost(id)

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
