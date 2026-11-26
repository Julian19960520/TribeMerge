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
const Voice := preload("res://scripts/ui/HeroVoice.gd")
const VINE3 := 23
## 头像 + 气泡贴在亮着的区域旁边（默认下方，放不下就上方；没有亮处时放底部）
const AVATAR := 120.0
const TALK_W := 620.0
## 气泡高度跟着字走：上边距 + 正文 + 间隔 + 「点击继续」一行 + 下边距，最矮和头像一样高
const TALK_MIN_H := 112.0
## 头像和气泡之间留的空：气泡尾巴伸出左边约 26px，头像圆右边到格子边还剩 7px，留够尾巴才不会被头像盖住
const TAIL_GAP := 26.0
const PAD_TOP := 18.0
const PAD_BOTTOM := 14.0
const HINT_H := 28.0
const HINT_GAP := 4.0
const TEXT_SIZE := 26
const LINE_GAP := 6

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
var _label: RichTextLabel
var _cont: Label
var _bust_home := Vector2.ZERO
var _t := 0.0
var _poll := 0.0
var _armed_at := 0
var _hole_press := false
var _over_popup := false
## 下一次 show_once 显示在弹窗上面（新活动开放时，先弹活动面板再在面板上讲）
var _force_over := false

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
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.scroll_active = false
	_label.mouse_filter = MOUSE_FILTER_IGNORE
	_label.add_theme_font_override("normal_font", G.font_body)
	_label.add_theme_font_override("bold_font", G.font_body)
	_label.add_theme_font_size_override("normal_font_size", TEXT_SIZE)
	_label.add_theme_color_override("default_color", Art.INK)
	add_child(_label)
	_label.add_theme_constant_override("line_spacing", LINE_GAP)
	_cont = UI.lbl(self, TextCatalog.source("ui.guide.b0daab78b94a"), Rect2(), 22, Color("4f9a3a"), HORIZONTAL_ALIGNMENT_RIGHT)

func seen(key: String) -> bool:
	return G.tips_seen.has(key)

func showing() -> bool:
	return visible

## 没看过就显示一次。target 返回要亮出来的全局矩形或矩形数组（可以为空），then 在玩家点掉文字提示后调用。
## until 有值时，它返回 false 提示就自动收起；drag 为真时点亮处不收，靠 until 收。
func show_once(key: String, text: String, target: Callable = Callable(), then: Callable = Callable(),
		until: Callable = Callable(), drag: bool = false) -> bool:
	if seen(key) or visible or G.tutorial_on and key not in ["energy_out", "energy_free"]:
		return false
	G.tips_seen[key] = true
	_key = key
	_over_popup = key == "energy_free" or _force_over
	_force_over = false
	_target = target
	_then = then
	_until = until
	_drag = drag
	IconText.set_rich(_label, UI.resource_rich(Voice.text("tips", key, text)))
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
	if visible and not _over_popup and G.main != null and (G.main.popup_layer.get_child_count() > 0 or G.main._rw_showing or G.main.level_pending):
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

## 正文按气泡宽度折行后的高度
func _text_height(width: float) -> float:
	var font: Font = G.font_body
	var plain := _label.get_parsed_text()
	if font == null or plain == "":
		return float(TEXT_SIZE)
	var lines := 0
	for para in plain.split("
"):
		var w := font.get_string_size(TextCatalog.resolve(para), HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE).x
		lines += maxi(1, int(ceil(w / maxf(1.0, width - 4.0))))
	var line_h := font.get_height(TEXT_SIZE)
	return line_h * lines + LINE_GAP * (lines - 1)

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
	_cont.text = TextCatalog.resolve("" if _drag else (TextCatalog.source("ui.guide.946b258d1513") if n > 0 else TextCatalog.source("ui.guide.b0daab78b94a")))
	var text_w := TALK_W - AVATAR - TAIL_GAP - 56.0
	var text_h := _text_height(text_w)
	var hint_h := HINT_GAP + HINT_H if _cont.text != "" else 0.0
	var talk_h := maxf(TALK_MIN_H, PAD_TOP + text_h + hint_h + PAD_BOTTOM)
	var x := (size.x - TALK_W) * 0.5
	var y := 1120.0
	if n > 0:
		x = clampf(span.get_center().x - TALK_W * 0.5, 16.0, size.x - 16.0 - TALK_W)
		y = span.end.y + 22.0
		if y + talk_h > size.y - 30.0:
			y = span.position.y - 22.0 - talk_h
		y = clampf(y, 90.0, size.y - talk_h - 30.0)
	_bust_home = Vector2(x, y + (talk_h - AVATAR) * 0.5)
	_bust.position = _bust_home
	var br := Rect2(x + AVATAR + TAIL_GAP, y, TALK_W - AVATAR - TAIL_GAP, talk_h)
	_bubble.position = br.position
	_bubble.size = br.size
	# 正文在「点击继续」上方那块里竖直居中；只有一行时整块气泡也就一行高
	var body_h := talk_h - PAD_TOP - PAD_BOTTOM - hint_h
	_label.position = br.position + Vector2(28, PAD_TOP + (body_h - text_h) * 0.5 - 2.0)
	_label.size = Vector2(text_w, text_h + 8.0)
	_cont.position = Vector2(br.position.x + 28, br.end.y - PAD_BOTTOM - HINT_H)
	_cont.size = Vector2(text_w, HINT_H)
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
	# 礼物在暂存区 → 拿出来合进生产器 → 生产器升级（竞品第二次装修后的那一段）
	if not G.stash.is_empty() and show_once("stash", TextCatalog.source("ui.tips.9fe521e1e574"),
			func(): return bs._stash_wrap.get_global_rect()):
		return
	if _merge3_pair().x >= 0 and show_once("gen_merge3", TextCatalog.source("ui.tips.272590e9c636"),
			func(): var p := _merge3_pair(); return [_cell_rect(p.x), _cell_rect(p.y)],
			Callable(), func(): return _merge3_pair().x >= 0, true):
		return
	if _pair_of("basket_4").x >= 0 and seen("gen_merge3") and show_once("gen_merge5", TextCatalog.source("ui.tips.88f65828f2ec"),
			func(): var p := _pair_of("basket_4"); return [_cell_rect(p.x), _cell_rect(p.y)],
			Callable(), func(): return _pair_of("basket_4").x >= 0, true):
		return
	var b5 := _find_id("basket_5")
	if b5 >= 0 and show_once("gen_tap", TextCatalog.source("ui.tips.d36e5bcb2a01"),
			func(): return _cell_rect(b5)):
		return
	var craft := _order_index(func(o): return str(o.get("kind", "")) == "craft")
	if craft >= 0 and not seen("craft"): _focus_card(craft)
	if craft >= 0 and show_once("craft", TextCatalog.source("ui.tips.d70f9c36bf8d"),
			func(): return G.main.board_screen.focus_order_card(craft)):
		return
	var cook := _order_index(func(o): return str(o.get("kind", "")) == "craft" and str(o.get("phase", "")) == "cook")
	if cook >= 0 and not seen("craft_cook"): _focus_card(cook)
	if cook >= 0 and show_once("craft_cook", TextCatalog.source("ui.tips.697386576ae7"),
			func(): return G.main.board_screen.focus_order_card(cook)):
		return
	var dish := _order_index(func(o): return str(o.get("kind", "")) == "craft" and str(o.get("phase", "")) == "ready")
	if dish >= 0 and not seen("craft_ready"): _focus_card(dish)
	if dish >= 0 and show_once("craft_ready", TextCatalog.source("ui.tips.93438950d84b"),
			func(): return G.main.board_screen.focus_order_card(dish)):
		return
	var egen := _find_type("egen")
	if egen >= 0 and show_once("egen", TextCatalog.source("ui.tips.31ac2f00f702"),
			func(): return _cell_rect(egen)):
		return
	if bs._hammer_btn != null and bs._hammer_btn.visible and show_once("build", TextCatalog.source("ui.tips.801dfe512415"),
			func(): return bs._hammer_btn.get_global_rect()):
		return
	if _gen_steps(6, "carve", TextCatalog.source("names.chains.cba4a159fc2b"), TextCatalog.source("names.chains.e327de5aac1f"), TextCatalog.source("names.chains.c13396e297b0")):
		return
	if _gen_steps(11, "anvil", TextCatalog.source("names.chains.a1f3622ce7b9"), TextCatalog.source("names.chains.c2706b8deb1f"), TextCatalog.source("names.chains.1a4e1d4d4469")):
		return
	if _bubble_tip():
		return
	if _feature_intros():
		return

# ---------------------------------------------------------------- 6~12 级：竞品逐级教的内容

## 生产器合到 5 级出副产物（竞品 6 级的饮料机、11 级的渔具）：
## 奖励的 3 级 + 藤蔓里的 3 级 → 4 级，再和已有的 4 级 → 5 级，点一下出新东西。
func _gen_steps(min_level: int, gen: String, gen_name: String, main_name: String, sub_name: String) -> bool:
	if G.level < min_level:
		return false
	var p3 := _gen_pair(gen + "_3")
	if p3.x >= 0 and show_once("%s_merge3" % gen, TextCatalog.fill(TextCatalog.source("ui.tips.b598283fb668"), [gen_name, main_name, sub_name]),
			func(): var p := _gen_pair(gen + "_3"); return [_cell_rect(p.x), _cell_rect(p.y)],
			Callable(), func(): return _gen_pair(gen + "_3").x >= 0, true):
		return true
	var p4 := _gen_pair(gen + "_4")
	if p4.x >= 0 and seen("%s_merge3" % gen) and show_once("%s_merge5" % gen, TextCatalog.source("ui.tips.c3a657c0748c"),
			func(): var p := _gen_pair(gen + "_4"); return [_cell_rect(p.x), _cell_rect(p.y)],
			Callable(), func(): return _gen_pair(gen + "_4").x >= 0, true):
		return true
	var g5 := _find_id(gen + "_5")
	if g5 >= 0 and seen("%s_merge5" % gen) and show_once("%s_tap5" % gen, TextCatalog.fill(TextCatalog.source("ui.tips.cdead436e45f"), [gen_name, main_name, sub_name]),
			func(): return _cell_rect(g5)):
		return true
	return false

## 同一种生产器：一个摆开的 + 藤蔓里的一个优先，否则两个摆开的
func _gen_pair(id: String) -> Vector2i:
	var free: Array[int] = []
	var vine := -1
	for i in G.board.size():
		if str(G.board[i]["id"]) != id: continue
		var lock := int(G.board[i]["lock"])
		if lock == 0: free.append(i)
		elif lock == 1 and vine < 0: vine = i
	if not free.is_empty() and vine >= 0:
		return Vector2i(free[0], vine)
	return Vector2i(free[0], free[1]) if free.size() >= 2 else Vector2i(-1, -1)

## 第一个合成泡泡（免费，见 BoardRules._maybe_spawn_bubble）：圈出来让玩家点开
func _bubble_tip() -> bool:
	for i in G.board.size():
		if G.rules.board.is_merge_bubble(i) and int(G.board[i]["bubble"].get("price", 1)) <= 0:
			var at := i
			return show_once("bubble_free", TextCatalog.source("ui.tips.d02e0f576b40"), func(): return _cell_rect(at))
	return false

## 新内容开放（7 集市、8 卡册、9 七日任务、10 七日签到、11 化石、12 双人竞速）：
## 先弹出它的面板，再在面板上一句一句讲，点任意处继续。
func _feature_intros() -> bool:
	# 按真实等级：GM 全开活动时不一个个弹
	if G.level >= Data.feature_level("shop") and _intro("intro_shop", "store", [
			TextCatalog.source("ui.tips.8a150aa4be15"),
			TextCatalog.source("ui.tips.7f51eb882472")]):
		return true
	if G.level >= Data.CARD_LEVEL and _intro("intro_cards", "event", [
			TextCatalog.source("ui.tips.2d4811b5fc2e"),
			TextCatalog.source("ui.tips.b68560f542e3")]):
		return true
	if G.level >= Data.feature_level("seven") and _intro("intro_seven", "seven_day", [
			TextCatalog.source("ui.tips.4f9a53a9364c"),
			TextCatalog.source("ui.tips.7d5aad110ead")]):
		return true
	if G.level >= Data.feature_level("login") and LoginGift.visible() and _intro("intro_login", "login_gift", [
			TextCatalog.source("ui.tips.bd9d4b635eb0"),
			TextCatalog.source("ui.tips.3645567dc56d")]):
		G.tips_seen["login_day"] = str(G.rules.clock.today())
		return true
	# 开放以后每天第一次回到棋盘、今天还没签到：自动弹签到面板
	if G.level >= Data.feature_level("login") and LoginGift.can_claim() and str(G.tips_seen.get("login_day", "")) != str(G.rules.clock.today()):
		G.tips_seen["login_day"] = str(G.rules.clock.today())
		G.main.open("login_gift")
		return true
	if G.level >= int(FossilDig.config()["unlock_level"]) and FossilDig.visible() and _intro("intro_fossil", "fossil", [
			TextCatalog.source("ui.tips.b6532ca45ac8"),
			TextCatalog.source("ui.tips.1f6f9627cf15")]):
		return true
	if G.level >= int(DuelRace.config()["unlock_level"]) and DuelRace.visible() and _intro("intro_duel", "duel", [
			TextCatalog.source("ui.tips.1c093997cbc0"),
			TextCatalog.source("ui.tips.f3e7b4c278f4"),
			TextCatalog.source("ui.tips.c36240bb0816")]):
		return true
	return false

func _intro(key: String, popup: String, lines: Array) -> bool:
	if seen(key):
		return false
	G.tips_seen[key] = true
	if G.main.open(popup) == null:
		return true
	_intro_line(key, lines, 0)
	return true

func _intro_line(key: String, lines: Array, k: int) -> void:
	if k >= lines.size() or not is_instance_valid(G.main) or G.main.popup_layer.get_child_count() == 0:
		return
	_force_over = true
	if not show_once("%s_%d" % [key, k], str(lines[k]), Callable(), func(): _intro_line(key, lines, k + 1)):
		_force_over = false

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
	if not show_once("energy_out", TextCatalog.source("ui.tips.ded9480b98f0"), pill, open):
		open.call()

## 生产器因为棋盘满了掉不出东西时调用。
func board_full(message: String) -> void:
	G.main.toast(message)

func energy_free(rect: Rect2) -> void:
	show_once("energy_free", TextCatalog.source("ui.tips.25546713bb54"), func(): return rect)
