class_name Guide
extends Control
## Presentation for data/onboarding.json. All durable transitions pass through Replay.
const Meme := preload("res://scripts/Meme.gd")
const Voice := preload("res://scripts/ui/HeroVoice.gd")
const DIM_ALPHA := 0.44
var _step := ""
var _mode := ""
var _holes: Array[Rect2] = []
var _pass: Array[Rect2] = []
var _merge_a := -1
var _merge_b := -1
var _t := 0.0
var _step_at := 0
var _busy := false
var _dim: ColorRect
var _mat: ShaderMaterial
var _art: DrawBox
var _bubble: DrawBox
var _bust: DrawBox
var _label: RichTextLabel
var _cont: Label
var _formula: DrawBox
var _formula_ids: Array = []
var _target := Rect2()
var _ghost: DrawBox
var _ghost_id := ""

func _ready() -> void:
	size = Vector2(720, 1480)
	mouse_filter = MOUSE_FILTER_IGNORE
	_dim = ColorRect.new()
	_dim.size = size
	_dim.mouse_filter = MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/dim_holes.gdshader")
	_dim.material = _mat
	add_child(_dim)
	_art = UI.box(self, Rect2(Vector2.ZERO, size), _paint_pointer, false)
	_bubble = UI.box(self, Rect2(), func(ci, sz): Paint.speech(ci, Rect2(Vector2.ZERO, sz), true), false)
	_bust = UI.box(self, Rect2(0, 0, 112, 112), func(ci, sz): Meme.walker_portrait(ci, Meme.HERO, Vector2(sz.x * 0.5, sz.y - 4), sz.x - 8), false)
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.mouse_filter = MOUSE_FILTER_IGNORE
	_label.add_theme_font_override("normal_font", G.font_body)
	_label.add_theme_font_override("bold_font", G.font_body)
	_label.add_theme_font_size_override("normal_font_size", 25)
	_label.add_theme_color_override("default_color", Art.INK)
	_label.scroll_active = false
	add_child(_label)
	_formula = UI.box(self, Rect2(), _paint_formula, false)
	_cont = UI.lbl(self, TextCatalog.source("ui.guide.b0daab78b94a"), Rect2(), 22, Color("4f9a3a"), HORIZONTAL_ALIGNMENT_RIGHT)
	_ghost = UI.box(self, Rect2(0, 0, 120, 120), func(ci, sz): Art.item(ci, _ghost_id, sz * 0.5, 112), false)
	_ghost.visible = false
	present()

func present() -> void:
	if G.main == null: return
	if get_parent() != G.main: reparent(G.main)
	_refresh()

func _rules(): return G.rules.onboarding
func _strong() -> bool: return _mode not in ["", "free", "animation", "complete", "howto", "build_preview"]
func note_merge() -> void: _refresh()
func cover_for_reward() -> void: visible = false
func merge_hint() -> Vector2i: return Vector2i(_merge_a, _merge_b) if visible else Vector2i(-1, -1)
func spawn_cell() -> int: return -1
func force_drop(_i: int) -> String: return ""
func allows_drop(a: int, b: int) -> bool:
	return not visible or not _strong() or _mode == "merge" and a == _merge_a and b == _merge_b
func allows_activate(i: int) -> bool:
	if not visible or not _strong(): return true
	if _mode in ["produce", "energy_gen", "collect", "take_dish"]:
		return _cell_target() == i
	return false
func _has_point(point: Vector2) -> bool:
	if not visible or not _strong(): return false
	for h in _pass:
		if h.has_point(point): return false
	return true
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		if _mode in ["dialog", "banner"] and Time.get_ticks_msec() - _step_at > 350: _ack()
func skip_beat() -> void:
	if _mode in ["dialog", "banner"]: _ack()
func _ack() -> void:
	if _busy: return
	_busy = true
	var result = Replay.perform("onboarding_next", {"step": _step})
	_busy = false
	# A refused step stays put; retrying from inside _refresh recursed until the
	# stack overflowed. The next frame's _process tries again instead.
	if result is Dictionary and result.has("error"): return
	_refresh()

func _process(dt: float) -> void:
	_t += dt
	_refresh()
	if not visible: return
	_art.queue_redraw()
	var board: Board = G.main.board_screen.board
	_ghost.visible = board.dragging and _mode == "merge"
	if _ghost.visible:
		_ghost_id = G.rules.board.cell_id(board.drag_from)
		_ghost.position = board.get_global_transform() * (board.drag_vis + Board.DRAG_LIFT) - _ghost.size * 0.5
		_ghost.queue_redraw()

func _refresh() -> void:
	if not is_instance_valid(_dim) or G.main == null: return
	# The config editor sits on this same screen. A tutorial veil would swallow Save.
	if G.main.screen == "cfg":
		visible = false
		mouse_filter = MOUSE_FILTER_IGNORE
		if is_instance_valid(G.main.board_screen) and is_instance_valid(G.main.board_screen.board):
			G.main.board_screen.board.hide_drag = false
		return
	var active: bool = _rules().active()
	if not active:
		visible = false
		G.main.board_screen.board.hide_drag = false
		return
	var s: Dictionary = _rules().stage()
	if str(s.get("key", "")) == "free_energy_gift" and _rules().energy_lesson_needed() and G.stash.has(str(_rules().config()["energy_generator"])) and G.rules.board.find_empty_near(0) >= 0:
		s = s.duplicate(true)
		s["mode"] = "stash"
	var key := str(s.get("key", ""))
	_mode = str(s.get("mode", ""))
	if key != _step:
		_step = key
		_step_at = Time.get_ticks_msec()
		var tip_keys := {"howto": "howto", "stash": "stash", "gen_merge3": "gen_merge3", "gen_merge5": "gen_merge5", "gen_tap": "gen_tap", "recipe_open": "craft", "cook_wait": "craft_cook", "take_dish": "craft_ready", "energy_gift": "egen", "build1": "build"}
		if tip_keys.has(key): G.tips_seen[str(tip_keys[key])] = true
		if _mode == "merge":
			G.main.board_screen.board.select(-1)
	var main = G.main
	# Reward screens, scene wipes and construction animations own their input.
	var reward: bool = main._rw_showing or main.level_pending or main.home.is_building() or main._wipe.running()
	if _mode == "animation":
		visible = false
		if not reward and main.popup_layer.get_child_count() == 0 and Time.get_ticks_msec() - _step_at > 700: _ack()
		return
	if reward:
		visible = false
		return
	if _mode in ["build_preview", "howto"]:
		# Retain saved step keys, but construction follows the tribe's original
		# click -> automatic animation -> rewards flow, without extra modals.
		visible = false
		if main.popup_layer.get_child_count() == 0: _ack()
		return
	if active and _rules().progress().get("rescue_pending", false) and main.popup_layer.get_child_count() == 0:
		visible = false
		main.open("onboarding_rescue")
		return
	var popup = main.popup_layer.top()
	# An opening lesson may only advance into its own modal. In particular the
	# level-up screen is opened outside the reward queue, so _rw_showing alone
	# cannot protect it from a recipe lesson targeting an order underneath.
	var modal := ""
	if _step == "build1" or _mode == "open_build": modal = "build_rects"
	elif _step in ["level_rule", "level_preview", "level_close"] or _mode == "level_open": modal = "level_progress"
	elif _step in ["recipe_mats", "recipe_time", "recipe_ready", "recipe_close"] or _mode == "recipe_open": modal = "recipe_mats"
	if popup != null and (popup._closing or modal == "" or not popup.has_meta(modal)):
		visible = false
		return
	if _mode == "enter_board" and main.screen == "board": _ack(); return
	if _mode == "open_build" and popup != null and popup.has_meta("build_rects"): _ack(); return
	if _mode == "back" and main.screen == "board": _ack(); return
	if _mode == "level_open" and popup != null and popup.has_meta("level_progress"): _ack(); return
	if _mode == "level_close" and popup == null: _ack(); return
	if _mode == "recipe_open" and popup != null and popup.has_meta("recipe_mats"): _ack(); return
	if _mode == "recipe_close" and popup == null: _ack(); return
	visible = _strong()
	mouse_filter = MOUSE_FILTER_STOP if visible else MOUSE_FILTER_IGNORE
	main.board_screen.board.hide_drag = visible and _mode == "merge"
	if not visible: return
	if get_parent() != main: reparent(main)
	main.move_child(self, main.get_child_count() - 1)
	_holes.clear(); _pass.clear(); _merge_a = -1; _merge_b = -1
	_target = Rect2()
	match _mode:
		"enter_board", "back": _hole(main.home.go.get_global_rect(), true)
		"open_build":
			if main.screen == "board":
				main.board_screen.guide_focus_row()
				_hole(main.board_screen._hammer_btn.get_global_rect(), true)
			elif popup == null and Time.get_ticks_msec() - _step_at > 1500:
				main.open("build", G.rules.progression.next_build_id())
		"build":
			if popup != null:
				for rect in popup.get_meta("build_rects", []): _hole(rect, true)
		"merge":
			# 一步可以列多组（先合低级再合高级），用第一组还凑得出来的
			var pair := Vector2i(-1, -1)
			for p in s.get("pairs", [s.get("pair", [""])]):
				pair = _pair(str(p[0]))
				if pair.x >= 0 and pair.y >= 0: break
			_merge_a = pair.x; _merge_b = pair.y
			if pair.x >= 0:
				_hole(_cell_rect(pair.x), true); _hole(_cell_rect(pair.y), true)
				if main.board_screen.board.selected != pair.x: main.board_screen.board.select(pair.x)
		"produce", "collect", "energy_gen", "take_dish":
			var cell := _cell_target()
			if cell >= 0: _hole(_cell_rect(cell), true)
		"submit", "cook", "recipe_open":
			var oi := _order_index()
			if oi >= 0:
				var card = main.board_screen._cards[oi] if oi < main.board_screen._cards.size() else null
				if card != null:
					var button = card._make_host if _mode == "cook" else (card._recipe_button if _mode == "recipe_open" else card._deliver_host)
					main.board_screen.focus_order_card(oi, button if _mode == "recipe_open" else null)
					if _mode == "recipe_open":
						_hole(card.recipe_icon_global_rect(), false)
						_pass.append(button.get_global_rect().intersection(main.board_screen.order_card_rect(oi)))
					else:
						_hole(button.get_global_rect(), true)
						_hole(main.board_screen.order_card_rect(oi), false)
						for at in G.rules.orders.order_cells(G.orders[oi]): _hole(_cell_rect(int(at)), false)
		"stash": _hole(main.board_screen._stash_wrap.get_global_rect(), true)
		"level_open": _hole(main.board_screen._base_btn.get_global_rect(), true)
		"level_close", "recipe_close":
			if popup != null: _hole(popup.get_meta("onboarding_close", Rect2(626, 240, 70, 70)), true)
		"dialog":
			var target := str(s.get("target", ""))
			if target == "order" and not G.orders.is_empty(): _hole(main.board_screen.focus_order_card(0), false)
			elif target == "xp":
				var base: Rect2 = main.board_screen._base_btn.get_global_rect()
				_hole(Rect2(base.position + Vector2(16, 170), Vector2(base.size.x - 24, 36)), false)
			elif popup != null and popup.has_meta(target): _hole(popup.get_meta(target), false)
	# An action step with nothing to point at must not hold the whole screen:
	# let the player play until the board catches up (or the rules skip it).
	if _holes.is_empty() and _mode not in ["dialog", "banner", "level_close", "recipe_close"]:
		visible = false
		mouse_filter = MOUSE_FILTER_IGNORE
		main.board_screen.board.hide_drag = false
		return
	if _holes.size() > 0:
		_target = _holes[0]
		for hole in _holes: _target = _target.merge(hole)
	_label.text = UI.resource_rich(Voice.text("onboarding", _step, str(s.get("text", "")))).replace(TextCatalog.source("ui.guide.384323c39a6b"), TextCatalog.source("ui.guide.78768adaa164")).replace(TextCatalog.source("ui.guide.16742e9df6c7"), TextCatalog.source("ui.guide.bf9ce4952017"))
	_formula_ids = s.get("formula", [])
	_place()
	var packed := PackedVector4Array(); packed.resize(8)
	for i in mini(8, _holes.size()):
		var h := _holes[i].grow(5)
		packed[i] = Vector4(h.position.x, h.position.y, h.size.x, h.size.y)
	_mat.set_shader_parameter("holes", packed)
	_mat.set_shader_parameter("hole_count", mini(8, _holes.size()))
	_mat.set_shader_parameter("screen_px", size)
	_mat.set_shader_parameter("dim_a", DIM_ALPHA)
	_mat.set_shader_parameter("corner", (_holes[0].size.x + 10.0) * 0.5 if _mode == "recipe_open" and not _holes.is_empty() else 18.0)

func _hole(rect: Rect2, interactive: bool) -> void:
	if rect.size.x < 2 or rect.size.y < 2: return
	_holes.append(rect)
	if interactive: _pass.append(rect.grow(5))

## 正文按气泡宽度折行后的高度（字号 25）
func _text_height(width: float) -> float:
	var font: Font = G.font_body
	var plain := _label.get_parsed_text()
	if font == null or plain == "":
		return 25.0
	var lines := 0
	for para in plain.split("
"):
		var w := font.get_string_size(para, HORIZONTAL_ALIGNMENT_LEFT, -1, 25).x
		lines += maxi(1, int(ceil(w / maxf(1.0, width - 4.0))))
	return font.get_height(25) * lines + 4.0 * (lines - 1)

const FORMULA_ICON := 84.0
const FORMULA_STEP := 150.0
const FORMULA_H := 100.0

func _place() -> void:
	# 气泡高度跟着字走（带配方图的那种固定高）；正文在「点击继续」上方竖直居中
	var text_h := _text_height(478.0)
	var row_h := FORMULA_H + 10.0 if not _formula_ids.is_empty() else 0.0
	var h := maxf(112.0, 18.0 + text_h + row_h + 4.0 + 28.0 + 14.0)
	var y := 1110.0
	if _target.size.x > 0:
		y = _target.end.y + 28
		if y + h > 1440: y = _target.position.y - h - 28
	# Keep narration away from the cells and the operation button.
	y = clampf(y, 154, 1430 - h)
	_bust.position = Vector2(26, y + (h - 112) * 0.5)
	# 气泡离头像留出尾巴的长度（尾巴伸出左边约 26px），免得尖角被头像盖住
	_bubble.position = Vector2(164, y)
	_bubble.size = Vector2(530, h)
	# 从上往下：正文 → 配方一行（有的话）→ 「点击继续」；正文在剩下的空里竖直居中
	var body_h := h - 18.0 - 14.0 - 32.0 - row_h
	_label.position = Vector2(190, y + 18.0 + (body_h - text_h) * 0.5 - 2.0)
	_label.size = Vector2(478, text_h + 8.0)
	_cont.position = Vector2(190, y + h - 14.0 - 28.0)
	_cont.size = Vector2(478, 28)
	_cont.text = TextCatalog.resolve(TextCatalog.source("ui.guide.b0daab78b94a") if _mode in ["dialog", "banner"] else (TextCatalog.source("ui.guide.a5fcfcc6068c") if _mode == "merge" else TextCatalog.source("ui.guide.946b258d1513")))
	_formula.visible = not _formula_ids.is_empty()
	_formula.position = Vector2(190, y + 18.0 + body_h + 6.0)
	_formula.size = Vector2(478, FORMULA_H)
	_formula.queue_redraw()
	_bubble.queue_redraw()

func _cell_rect(i: int) -> Rect2:
	var board: Board = G.main.board_screen.board
	return Rect2(board.get_global_transform() * board.cell_rect(i).position, board.cell_rect(i).size)

func _pair(id: String) -> Vector2i:
	var cells: Array = _rules().stage().get("cells", [])
	if cells.size() == 2:
		var a := int(cells[0]); var b := int(cells[1])
		if a >= 0 and b >= 0 and a < G.board.size() and b < G.board.size() and int(G.board[a]["lock"]) == 0 and int(G.board[b]["lock"]) < 2 and str(G.board[a]["id"]) == id and str(G.board[b]["id"]) == id:
			return Vector2i(a, b)
	# Existing saves retain their old layout; find the same merge there instead
	# of pointing at the new opening coordinates on an already-started board.
	var free: Array[int] = []; var locked: Array[int] = []
	for i in G.board.size():
		if str(G.board[i]["id"]) != id: continue
		if int(G.board[i]["lock"]) == 0: free.append(i)
		elif int(G.board[i]["lock"]) == 1: locked.append(i)
	if free.is_empty(): return Vector2i(-1, -1)
	if not locked.is_empty(): return Vector2i(free[0], locked[0])
	# Older openings have two free components beside a covered next-level
	# component. Keep the merge next to that component so it can be revealed.
	if free.size() > 1:
		for destination in free:
			for neighbor in MergeGrid.neighbors(destination, G.COLS, G.board.size()):
				if int(G.board[int(neighbor)]["lock"]) == 2 and str(G.board[int(neighbor)]["id"]) == Data.next_id(id):
					return Vector2i(free[1] if destination == free[0] else free[0], destination)
	return Vector2i(free[0], free[1]) if free.size() > 1 else Vector2i(-1, -1)

func _cell_target() -> int:
	var target := str(_rules().stage().get("target", ""))
	for i in G.board.size():
		if _mode == "take_dish" and G.rules.orders.cooking(i) and G.rules.orders.cook_left(i) == 0: return i
		if int(G.board[i]["lock"]) != 0: continue
		var id := str(G.board[i]["id"])
		if _mode == "energy_gen" and id == str(_rules().config()["energy_generator"]): return i
		if target != "" and id == target or _mode == "collect" and Data.type_of(id) == target: return i
	return -1

func _order_index() -> int:
	for i in G.orders.size():
		var o: Dictionary = G.orders[i]
		if _mode == "recipe_open" and str(o.get("kind", "")) == "craft": return i
		if _mode == "cook" and G.rules.orders.craft_mats_ready(o): return i
		if _mode == "submit" and G.rules.orders.order_ready(o): return i
	return -1

## 配方一行：物品 + 物品 → 结果，在气泡里横向居中、等距排开，底下垫一条浅色底
func _paint_formula(ci: CanvasItem, sz: Vector2) -> void:
	var n := _formula_ids.size()
	if n == 0: return
	ci.draw_colored_polygon(Art.rrect(Rect2(Vector2.ZERO, sz), 20, 951, 0.0), Color(0.55, 0.38, 0.2, 0.1))
	var mid := sz.x * 0.5
	var cy := sz.y * 0.5
	for i in n:
		var cx := mid + (float(i) - float(n - 1) * 0.5) * FORMULA_STEP
		Art.item(ci, str(_formula_ids[i]), Vector2(cx, cy), FORMULA_ICON)
		if i < n - 1:
			var ox := cx + FORMULA_STEP * 0.5
			var op := TextCatalog.resolve("+" if i < n - 2 else "→")
			ci.draw_string(G.font_title, Vector2(ox - 30, cy + 14), op, HORIZONTAL_ALIGNMENT_CENTER, 60, 40, Art.INK)

func _paint_pointer(ci: CanvasItem, _sz: Vector2) -> void:
	if _holes.is_empty(): return
	var at := _holes[0].get_center()
	var press := 0.0
	if _mode == "merge" and _merge_a >= 0:
		var a := _cell_rect(_merge_a).get_center()
		var b := _cell_rect(_merge_b).get_center()
		var u := clampf((fmod(_t, 1.8) - 0.25) / 1.1, 0, 1)
		u = u * u * (3.0 - 2.0 * u)
		at = a.lerp(b, u)
		_paint_drag_path(ci, a, b)
		# 起点按下、终点松开：两头各一圈涟漪
		_paint_ripple(ci, a, fmod(_t, 1.8) / 0.5)
		_paint_ripple(ci, b, (fmod(_t, 1.8) - 1.35) / 0.45)
		press = 1.0 if u > 0.0 and u < 1.0 else 0.0
	elif _mode in ["dialog", "banner"]: return
	else:
		# 点按：手抬起 → 按下（涟漪）→ 停一下
		var cyc := fmod(_t, 1.2)
		press = clampf(1.0 - absf(cyc - 0.35) / 0.25, 0.0, 1.0)
		_paint_ripple(ci, at, (cyc - 0.35) / 0.6)
	var lift := (1.0 - press) * 12.0
	var rot := -0.38
	var s := 0.92 - press * 0.06
	var tip_off: Vector2 = (GuideArt.GUIDE_TIP + Vector2(8, 8) - (GuideArt.GUIDE_HAND + Vector2(16, 16)) * 0.5) * s
	var tip := at + Vector2(10, 14) * (lift / 12.0) + Vector2(2, 4)
	Sprites.at(ci, "guide_hand", tip - tip_off.rotated(rot), s, rot)

const GuideArt := preload("res://scripts/sprites/popups.gd")

## 点按涟漪：k 从 0 到 1 扩散变淡
func _paint_ripple(ci: CanvasItem, c: Vector2, k: float) -> void:
	if k < 0.0 or k > 1.0: return
	var r := 14.0 + 30.0 * k
	ci.draw_arc(c, r, 0, TAU, 32, Color(1, 0.93, 0.55, 0.9 * (1.0 - k)), 5.0 * (1.0 - k) + 1.5, true)
	ci.draw_circle(c, 12.0 * (1.0 - k), Color(1, 1, 0.85, 0.35 * (1.0 - k)))

## 拖动路线：一串往前流动的小圆点，末端一个箭头
func _paint_drag_path(ci: CanvasItem, a: Vector2, b: Vector2) -> void:
	var d := b - a
	var n := maxi(int(d.length() / 18.0), 2)
	var flow := fmod(_t * 1.6, 1.0)
	for i in n:
		var t := (float(i) + flow) / float(n)
		if t > 0.88: continue
		var p := a.lerp(b, t)
		ci.draw_circle(p, 6.0, Art.INK)
		ci.draw_circle(p, 4.0, Color(1, 0.97, 0.88))
	var dir := d.normalized()
	var tipp := b - dir * 20.0
	var side := dir.orthogonal() * 11.0
	var head := PackedVector2Array([tipp + dir * 12.0, tipp - dir * 4.0 + side, tipp - dir * 4.0 - side])
	Art.dilate(ci, head, 2.5, Art.INK)
	ci.draw_colored_polygon(head, Color(1, 0.97, 0.88))
