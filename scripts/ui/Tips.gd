class_name Tips
extends Control
## 新手引导结束后的分阶段一次性提示：参考竞品，每到一个新阶段只教一件事。
## 不锁操作，点任意处继续。看过的记在 G.tips_seen（本机展示记录，不进玩法快照）。
## 自动提示只在棋盘界面、没有弹窗和领奖时出现；体力用完、棋盘满了由棋盘直接触发。

var _key := ""
var _target := Callable()
var _then := Callable()
var _hole := Rect2()
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
	_frames.painter = func(ci, _sz):
		if _hole.size.x > 1.0:
			Sprites.draw(ci, "pop_guide_frame", _hole.grow(7))
	add_child(_frames)
	_bubble = DrawBox.new()
	_bubble.mouse_filter = MOUSE_FILTER_IGNORE
	_bubble.painter = func(ci, sz): Paint.speech(ci, Rect2(Vector2.ZERO, sz), true)
	add_child(_bubble)
	_bust = DrawBox.new()
	_bust.mouse_filter = MOUSE_FILTER_IGNORE
	_bust.size = Vector2(200, 292)
	_bust.painter = func(ci, sz): Paint.bust(ci, sz * 0.5 + Vector2(0, 16), 122)
	add_child(_bust)
	_label = UI.lbl(self, "", Rect2(), 28, Art.INK)
	_label.add_theme_constant_override("line_spacing", 6)
	_cont = UI.lbl(self, "点击继续", Rect2(), 22, Color("4f9a3a"), HORIZONTAL_ALIGNMENT_RIGHT)

func seen(key: String) -> bool:
	return G.tips_seen.has(key)

func showing() -> bool:
	return visible

## 没看过就显示一次。target 返回要圈出来的全局矩形（可以为空），then 在玩家点掉提示后调用。
func show_once(key: String, text: String, target: Callable = Callable(), then: Callable = Callable()) -> bool:
	if seen(key) or visible or G.tutorial_on:
		return false
	G.tips_seen[key] = true
	_key = key
	_target = target
	_then = then
	_label.text = text
	_t = 0.0
	_armed_at = Time.get_ticks_msec() + 350
	var host := get_parent()
	if host != null: host.move_child(self, host.get_child_count() - 1)
	visible = true
	_layout()
	Sfx.play("pop")
	return true

func _gui_input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	accept_event()
	if Time.get_ticks_msec() < _armed_at:
		return
	_close()

func _close() -> void:
	visible = false
	_key = ""
	var cb := _then
	_then = Callable()
	_target = Callable()
	if cb.is_valid(): cb.call()

func _process(dt: float) -> void:
	if visible:
		_t += dt
		_bust.position = _bust_home + Vector2(0, sin(_t * 2.3) * 5.0)
		var h := _target_rect()
		if h != _hole: _layout()
		return
	_poll += dt
	if _poll < 0.5:
		return
	_poll = 0.0
	_auto()

func _target_rect() -> Rect2:
	if not _target.is_valid():
		return Rect2()
	var g = _target.call()
	if not (g is Rect2) or g.size.x < 2.0:
		return Rect2()
	var inv := get_global_transform().affine_inverse()
	var a: Vector2 = inv * g.position
	var b: Vector2 = inv * (g.position + g.size)
	return Rect2(a, b - a).abs()

func _layout() -> void:
	_hole = _target_rect()
	var arr := PackedVector4Array()
	arr.resize(8)
	if _hole.size.x > 1.0:
		var h := _hole.grow(6)
		arr[0] = Vector4(h.position.x, h.position.y, h.size.x, h.size.y)
	_mat.set_shader_parameter("holes", arr)
	_mat.set_shader_parameter("hole_count", 1 if _hole.size.x > 1.0 else 0)
	_mat.set_shader_parameter("screen_px", size)
	_mat.set_shader_parameter("dim_a", 0.55)
	# 角色和气泡默认贴底；目标在下半屏就挪到目标上方
	var top := 1124.0
	if _hole.size.x > 1.0 and _hole.end.y > top - 20.0:
		top = _hole.position.y - _bust.size.y - 8.0
	top = clampf(top, 96.0, size.y - 300.0)
	_bust_home = Vector2(-20, top)
	_bust.position = _bust_home
	var br := Rect2(168, top + 108, 536, 160)
	_bubble.position = br.position
	_bubble.size = br.size
	_label.position = br.position + Vector2(28, 12)
	_label.size = br.size - Vector2(56, 50)
	_cont.position = Vector2(br.position.x + 28, br.end.y - 44)
	_cont.size = Vector2(br.size.x - 56, 32)
	_frames.queue_redraw()
	_bubble.queue_redraw()

# ---------------------------------------------------------------- 自动提示

func _auto() -> void:
	if G.main == null or G.tutorial_on or not G.seen_tutorial:
		return
	if G.main.screen != "board" or G.main.popup_layer.get_child_count() > 0 or G.main._rw_showing:
		return
	var bs = G.main.board_screen
	if bs == null:
		return
	# 引导刚结束：先讲一遍玩法循环（订单→不拿拿→宝箱→建设）
	if not seen("howto"):
		G.tips_seen["howto"] = true
		G.main.open("howto")
		return
	if not G.stash.is_empty() and show_once("stash", "升级送的礼物放在暂存区\n点这里把它们放到棋盘上",
			func(): return bs._stash_wrap.get_global_rect()):
		return
	var news := Data.level_unlocks(G.level)
	if G.level >= 2 and not news.is_empty() and show_once("unlock_%d" % G.level,
			"%d 级解锁了新内容：\n%s" % [G.level, "，".join(news.slice(0, 2))]):
		return
	var craft := _order_index(func(o): return str(o.get("kind", "")) == "craft")
	if craft >= 0 and show_once("craft", "这张是制作订单！先备齐左边的材料\n再点订单上的按钮开始做菜",
			func(): return _card_rect(craft)):
		return
	var cook := _order_index(func(o): return str(o.get("kind", "")) == "craft" and str(o.get("phase", "")) == "cook")
	if cook >= 0 and show_once("craft_cook", "正在做菜，等一会儿就好\n有沙漏可以点它加速",
			func(): return _card_rect(cook)):
		return
	var dish := _order_index(func(o): return str(o.get("kind", "")) == "craft" and str(o.get("phase", "")) == "ready")
	if dish >= 0 and show_once("craft_ready", "菜做好了！它留在棋盘上\n点订单的对勾交给客人",
			func(): return _card_rect(dish)):
		return
	var egen := _find_type("egen")
	if egen >= 0 and show_once("egen", "这是火种罐\n点一下就会掉出体力",
			func(): return _cell_rect(egen)):
		return
	if bs._hammer_btn != null and bs._hammer_btn.visible and show_once("build", "不拿拿够了！\n去升级部落，解锁更多订单和奖励",
			func(): return bs._hammer_btn.get_global_rect()):
		return

func _order_index(pred: Callable) -> int:
	for k in G.orders.size():
		if pred.call(G.orders[k]): return k
	return -1

func _card_rect(oi: int) -> Rect2:
	var bs = G.main.board_screen
	if oi < 0 or oi >= bs._cards.size() or not is_instance_valid(bs._cards[oi]):
		return Rect2()
	return bs._cards[oi].get_global_rect()

func _find_type(t: String) -> int:
	for i in G.board.size():
		if int(G.board[i]["lock"]) == 0 and Data.type_of(str(G.board[i]["id"])) == t:
			return i
	return -1

func _cell_rect(i: int) -> Rect2:
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
	if not show_once("energy_out", "体力用完了！\n点体力图标补充，第一次免费", pill, open):
		open.call()

## 生产器因为棋盘满了掉不出东西时调用。
func board_full(message: String) -> void:
	if not show_once("board_full", "棋盘满了！\n把用不上的物品存进仓库或卖掉，腾出空位"):
		G.main.toast(message)
