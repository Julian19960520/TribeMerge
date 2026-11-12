class_name Tips
extends Control
## 新手引导结束后的分阶段一次性提示：参考竞品，每到一个新阶段只教一件事。
## 和新手引导一样全屏蒙黑，只露出要操作的地方：
## - 点按提示：只能点亮着的地方，点下去照常生效，提示随之收起；
## - 拖动提示（drag）：亮出起点和终点，等棋盘状态变了（until 返回 false）才收起；
## - 只有文字的提示：点任意处继续。
## 看过的记在 G.tips_seen（本机展示记录，不进玩法快照）。
## 自动提示只在棋盘界面、没有弹窗和领奖时出现；体力用完、棋盘满了由棋盘直接触发。

const Meme := preload("res://scripts/Meme.gd")
const VINE3 := 23
## 头像 + 气泡贴在亮着的区域旁边（默认下方，放不下就上方；没有亮处时放底部）
const AVATAR := 120.0
const TALK_W := 620.0
const TALK_H := 140.0

var _key := ""
var _target := Callable()
var _then := Callable()
var _until := Callable()
var _drag := false
var _holes: Array[Rect2] = []
var _dim: ColorRect
var _mat: ShaderMaterial
var _frames: DrawBox
var _bubble: DrawBox
var _bust: DrawBox
var _label: Label
var _cont: Label
var _bust_home := Vector2.ZERO
var _t := 0.0
var _poll := 0.0
var _armed_at := 0
var _hole_press := false

func _ready() -> void:
	size = Vector2(720, 1480)
	visible = false
	mouse_filter = MOUSE_FILTER_STOP
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
	_frames.painter = func(_ci, _sz): pass
	add_child(_frames)
	_bubble = DrawBox.new()
	_bubble.mouse_filter = MOUSE_FILTER_IGNORE
	_bubble.painter = func(ci, sz): Paint.speech(ci, Rect2(Vector2.ZERO, sz), true)
	add_child(_bubble)
	_bust = DrawBox.new()
	_bust.mouse_filter = MOUSE_FILTER_IGNORE
	_bust.size = Vector2(AVATAR, AVATAR)
	_bust.painter = func(ci, sz): Meme.walker_portrait(ci, Meme.HERO, Vector2(sz.x * 0.5, sz.y - 6.0), sz.x - 14.0)
	add_child(_bust)
	_label = UI.lbl(self, "", Rect2(), 26, Art.INK)
	_label.add_theme_constant_override("line_spacing", 6)
	_cont = UI.lbl(self, "点击继续", Rect2(), 22, Color("4f9a3a"), HORIZONTAL_ALIGNMENT_RIGHT)

func seen(key: String) -> bool:
	return G.tips_seen.has(key)

func showing() -> bool:
	return visible

## 没看过就显示一次。target 返回要亮出来的全局矩形或矩形数组（可以为空），then 在玩家点掉文字提示后调用。
## until 有值时，它返回 false 提示就自动收起；drag 为真时点亮处不收，靠 until 收。
func show_once(key: String, text: String, target: Callable = Callable(), then: Callable = Callable(),
		until: Callable = Callable(), drag: bool = false) -> bool:
	if seen(key) or visible or G.tutorial_on:
		return false
	G.tips_seen[key] = true
	_key = key
	_target = target
	_then = then
	_until = until
	_drag = drag
	_label.text = text
	_t = 0.0
	_armed_at = Time.get_ticks_msec() + 350
	var host := get_parent()
	if host != null: host.move_child(self, host.get_child_count() - 1)
	visible = true
	_layout()
	Sfx.play("pop")
	return true

func _in_holes(point: Vector2) -> bool:
	for h in _holes:
		if h.grow(6).has_point(point): return true
	return false

## 亮着的地方放行给下面的按钮或棋盘；别处都被黑罩挡住。
func _has_point(point: Vector2) -> bool:
	if not visible:
		return false
	return not _in_holes(point)

## 点按提示：在亮处点下并松开，下面的控件照常处理这次点击，提示跟着收起，不再执行 then。
func _input(e: InputEvent) -> void:
	if not visible or _holes.is_empty() or _drag:
		return
	if not (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT):
		return
	var inside := _in_holes(get_local_mouse_position())
	if e.pressed:
		_hole_press = inside and Time.get_ticks_msec() >= _armed_at
	elif _hole_press and inside:
		_hole_press = false
		_close.call_deferred(false)

func _gui_input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	accept_event()
	if Time.get_ticks_msec() < _armed_at:
		return
	## 有亮处时只能操作亮处
	if not _holes.is_empty():
		return
	_close()

func _close(run_then: bool = true) -> void:
	if not visible:
		return
	visible = false
	_key = ""
	_hole_press = false
	var cb := _then
	_then = Callable()
	_target = Callable()
	_until = Callable()
	_drag = false
	if run_then and cb.is_valid(): cb.call()

## 有弹窗、领奖、或者升级面板马上要弹的时候不出提示
func _blocked() -> bool:
	return G.main.screen != "board" or G.main.popup_layer.get_child_count() > 0 or G.main._rw_showing or G.main.level_pending

## 正在显示的提示被弹窗顶掉：先收起，记录作废，等弹窗关了条件还在就会再出
func yield_to_popup() -> void:
	if not visible:
		return
	var key := _key
	_close(false)
	G.tips_seen.erase(key)

func _process(dt: float) -> void:
	## 提示要教的事已经做完了（比如合成完立刻弹了「生产器升级」）：算看过，正常收起
	if visible and _until.is_valid() and not _until.call():
		_close(false)
		return
	if visible and G.main != null and (G.main.popup_layer.get_child_count() > 0 or G.main._rw_showing or G.main.level_pending):
		yield_to_popup()
		return
	if visible:
		_t += dt
		_bust.position = _bust_home + Vector2(0, sin(_t * 2.3) * 5.0)
		if _target_rects() != _holes: _layout()
		return
	_poll += dt
	if _poll < 0.5:
		return
	_poll = 0.0
	_auto()

func _target_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if not _target.is_valid():
		return out
	var got = _target.call()
	var list: Array = got if got is Array else [got]
	var inv := get_global_transform().affine_inverse()
	var screen := Rect2(Vector2.ZERO, size)
	for g in list:
		if not (g is Rect2) or g.size.x < 2.0:
			continue
		var a: Vector2 = inv * g.position
		var b: Vector2 = inv * (g.position + g.size)
		var r := Rect2(a, b - a).abs()
		## 只亮屏幕里真正看得见的部分；露出来不到一半就当没有目标，改成点任意处继续，免得卡住
		var seen_part := r.intersection(screen)
		if seen_part.get_area() < r.get_area() * 0.5 or seen_part.size.x < 24.0 or seen_part.size.y < 24.0:
			continue
		out.append(seen_part)
	return out

func _layout() -> void:
	_holes = _target_rects()
	var arr := PackedVector4Array()
	arr.resize(8)
	var n := mini(_holes.size(), 8)
	var span := Rect2()
	for k in n:
		var h := _holes[k].grow(6)
		arr[k] = Vector4(h.position.x, h.position.y, h.size.x, h.size.y)
		span = h if k == 0 else span.merge(h)
	_mat.set_shader_parameter("holes", arr)
	_mat.set_shader_parameter("hole_count", n)
	_mat.set_shader_parameter("screen_px", size)
	_mat.set_shader_parameter("dim_a", 0.76)
	_cont.text = "" if _drag else ("点亮着的地方" if n > 0 else "点击继续")
	var x := (size.x - TALK_W) * 0.5
	var y := 1120.0
	if n > 0:
		x = clampf(span.get_center().x - TALK_W * 0.5, 16.0, size.x - 16.0 - TALK_W)
		y = span.end.y + 22.0
		if y + TALK_H > size.y - 30.0:
			y = span.position.y - 22.0 - TALK_H
		y = clampf(y, 90.0, size.y - TALK_H - 30.0)
	_bust_home = Vector2(x, y + (TALK_H - AVATAR) * 0.5)
	_bust.position = _bust_home
	var br := Rect2(x + AVATAR + 8.0, y, TALK_W - AVATAR - 8.0, TALK_H)
	_bubble.position = br.position
	_bubble.size = br.size
	_label.position = br.position + Vector2(28, 10)
	_label.size = br.size - Vector2(56, 42)
	_cont.position = Vector2(br.position.x + 28, br.end.y - 40)
	_cont.size = Vector2(br.size.x - 56, 32)
	_frames.queue_redraw()
	_bubble.queue_redraw()

# ---------------------------------------------------------------- 自动提示

func _auto() -> void:
	if G.main == null or G.tutorial_on or not G.seen_tutorial:
		return
	if _blocked():
		return
	var bs = G.main.board_screen
	if bs == null:
		return
	# 引导刚结束：先讲一遍玩法循环（订单→不拿拿→宝箱→建设）
	if not seen("howto"):
		G.tips_seen["howto"] = true
		G.main.open("howto")
		return
	# 礼物在暂存区 → 拿出来合进生产器 → 生产器升级（竞品第二次装修后的那一段）
	if not G.stash.is_empty() and show_once("stash", "我们得到了奖励！\n点这里看看是什么",
			func(): return bs._stash_wrap.get_global_rect()):
		return
	if _merge3_pair().x >= 0 and show_once("gen_merge3", "太好了！把它合到藤蔓上那只\n我们的草篓就能升级！",
			func(): var p := _merge3_pair(); return [_cell_rect(p.x), _cell_rect(p.y)],
			Callable(), func(): return _merge3_pair().x >= 0, true):
		return
	if _pair_of("basket_4").x >= 0 and seen("gen_merge3") and show_once("gen_merge5", "再合一步\n更高级的藤篮在等着我们",
			func(): var p := _pair_of("basket_4"); return [_cell_rect(p.x), _cell_rect(p.y)],
			Callable(), func(): return _pair_of("basket_4").x >= 0, true):
		return
	var b5 := _find_id("basket_5")
	if b5 >= 0 and show_once("gen_tap", "升级后的藤篮能摘出新东西！\n点一下看看",
			func(): return _cell_rect(b5)):
		return
	var craft := _order_index(func(o): return str(o.get("kind", "")) == "craft")
	if craft >= 0 and not seen("craft"): _focus_card(craft)
	if craft >= 0 and show_once("craft", "这位族人想吃顿好的\n先备齐左边的材料，再点他开始下锅",
			func(): return G.main.board_screen.focus_order_card(craft)):
		return
	var cook := _order_index(func(o): return str(o.get("kind", "")) == "craft" and str(o.get("phase", "")) == "cook")
	if cook >= 0 and not seen("craft_cook"): _focus_card(cook)
	if cook >= 0 and show_once("craft_cook", "正在做，留意一下时间\n用沙漏可以加速",
			func(): return G.main.board_screen.focus_order_card(cook)):
		return
	var dish := _order_index(func(o): return str(o.get("kind", "")) == "craft" and str(o.get("phase", "")) == "ready")
	if dish >= 0 and not seen("craft_ready"): _focus_card(dish)
	if dish >= 0 and show_once("craft_ready", "做好啦！\n点对勾端给客人",
			func(): return G.main.board_screen.focus_order_card(dish)):
		return
	var egen := _find_type("egen")
	if egen >= 0 and show_once("egen", "我们收到一个火种罐！\n点它就能获得体力",
			func(): return _cell_rect(egen)):
		return
	if bs._hammer_btn != null and bs._hammer_btn.visible and show_once("build", "不拿拿够了！\n去建设部落，会有更多族人来许愿",
			func(): return bs._hammer_btn.get_global_rect()):
		return

## 拿出来的半编草篓和藤蔓上那只；藤蔓那只不在了就找两只摆开的
func _merge3_pair() -> Vector2i:
	var src := _find_id("basket_3")
	if src >= 0 and str(G.board[VINE3]["id"]) == "basket_3" and int(G.board[VINE3]["lock"]) == 1:
		return Vector2i(src, VINE3)
	return _pair_of("basket_3")

func _pair_of(id: String) -> Vector2i:
	var cells: Array[int] = []
	for i in G.board.size():
		if int(G.board[i]["lock"]) == 0 and str(G.board[i]["id"]) == id:
			cells.append(i)
	return Vector2i(cells[0], cells[1]) if cells.size() >= 2 else Vector2i(-1, -1)

func _find_id(id: String) -> int:
	for i in G.board.size():
		if int(G.board[i]["lock"]) == 0 and str(G.board[i]["id"]) == id:
			return i
	return -1

func _order_index(pred: Callable) -> int:
	for k in G.orders.size():
		if pred.call(G.orders[k]): return k
	return -1

func _card_rect(oi: int) -> Rect2:
	return G.main.board_screen.order_card_rect(oi)

## 要圈订单卡的提示：先把那张卡滚进订单栏可见范围
func _focus_card(oi: int) -> int:
	if oi >= 0: G.main.board_screen.focus_order_card(oi)
	return oi

func _find_type(t: String) -> int:
	for i in G.board.size():
		if int(G.board[i]["lock"]) == 0 and Data.type_of(str(G.board[i]["id"])) == t:
			return i
	return -1

func _cell_rect(i: int) -> Rect2:
	if i < 0:
		return Rect2()
	var board = G.main.board_screen.board
	var r: Rect2 = board.cell_rect(i)
	var xf: Transform2D = board.get_global_transform()
	return Rect2(xf * r.position, xf * (r.position + r.size) - xf * r.position).abs()

## 棋盘上体力不够时调用。第一次先指一下体力图标，点掉后再打开补体力。
func energy_out() -> void:
	var open := func(): G.main.open("energy", "exhausted")
	var pill := func():
		var tb = G.main.topbar
		var r: Rect2 = TopBar.PILLS["energy"]
		var xf: Transform2D = tb.get_global_transform()
		return Rect2(xf * r.position, xf * r.end - xf * r.position).abs()
	if not show_once("energy_out", "哎呀，体力用完了！\n点体力图标补充，这次免费", pill, open):
		open.call()

## 生产器因为棋盘满了掉不出东西时调用。
func board_full(message: String) -> void:
	if not show_once("board_full", "棋盘满啦！\n把用不上的收进仓库，或者卖掉"):
		G.main.toast(message)
