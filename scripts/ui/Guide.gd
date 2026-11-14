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
	Replay.perform("onboarding_next", {"step": _step})
	_busy = false
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
			var pair := _pair(str(s["pair"][0]))
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

func _place() -> void:
	var h := 210.0 if not _formula_ids.is_empty() else 148.0
	var y := 1110.0
	if _target.size.x > 0:
		y = _target.end.y + 28
		if y + h > 1440: y = _target.position.y - h - 28
	# Keep narration away from the cells and the operation button.
	y = clampf(y, 154, 1430 - h)
	_bust.position = Vector2(26, y + (h - 112) * 0.5)
	_bubble.position = Vector2(148, y)
	_bubble.size = Vector2(546, h)
	_label.position = Vector2(174, y + 14)
	_label.size = Vector2(494, 86)
	_cont.position = Vector2(174, y + h - 37)
	_cont.size = Vector2(494, 30)
	_cont.text = TextCatalog.resolve(TextCatalog.source("ui.guide.b0daab78b94a") if _mode in ["dialog", "banner"] else (TextCatalog.source("ui.guide.a5fcfcc6068c") if _mode == "merge" else TextCatalog.source("ui.guide.946b258d1513")))
	_formula.visible = not _formula_ids.is_empty()
	_formula.position = Vector2(250, y + 100)
	_formula.size = Vector2(310, 66)
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

func _paint_formula(ci: CanvasItem, _sz: Vector2) -> void:
	for i in _formula_ids.size():
		Art.item(ci, str(_formula_ids[i]), Vector2(24 + i * 112, 32), 52)
		if i < 2: ci.draw_string(G.font_body, Vector2(64 + i * 112, 42), TextCatalog.resolve("+" if i == 0 else "→"), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Art.INK)

func _paint_pointer(ci: CanvasItem, _sz: Vector2) -> void:
	if _holes.is_empty(): return
	var at := _holes[0].get_center()
	if _mode == "merge" and _merge_a >= 0:
		var a := _cell_rect(_merge_a).get_center()
		var b := _cell_rect(_merge_b).get_center()
		var u := clampf(fmod(_t, 1.8) / 1.2, 0, 1)
		at = a.lerp(b, u)
		ci.draw_line(a, b, Color(1, 1, 1, 0.7), 4, true)
	elif _mode in ["dialog", "banner"]: return
	else: at += Vector2(0, sin(_t * 5) * 6)
	# Familiar white fingertip, drawn above the exact tap/drag target.
	ci.draw_circle(at, 17, Color(1, 0.85, 0.3, 0.45 + 0.15 * sin(_t * 5)))
	ci.draw_line(at + Vector2(23, 52), at + Vector2(4, 9), Art.INK, 24, true)
	ci.draw_line(at + Vector2(23, 52), at + Vector2(4, 9), Color.WHITE, 17, true)
	ci.draw_circle(at + Vector2(24, 49), 18, Color.WHITE)
