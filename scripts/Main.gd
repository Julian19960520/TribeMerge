extends Control

const BakeItemsScript := preload("res://scripts/BakeItems.gd")
const BakeSpritesScript := preload("res://scripts/BakeSprites.gd")
const PassPopupScript := preload("res://scripts/ui/PassPopup.gd")
const CfgEditScript := preload("res://scripts/ui/CfgEdit.gd")
const GuideScript := preload("res://scripts/ui/Guide.gd")
const ScreenWipeScript := preload("res://scripts/ui/ScreenWipe.gd")

var home: HomeScreen
var board_screen: BoardScreen
var cfg_screen: Control
var topbar: TopBar
var popup_layer: Control
var pin: Control
var fx_layer: Control
var screen := "home"
var _curtain: ColorRect
var _wipe: Control
var _guide
var _fps_lbl: Label
## 全屏领奖一次只开一张，后面的排队
var _rw_q: Array = []
var _rw_showing := false
var _fps_shown := -1

func _ready() -> void:
	G.main = self
	size = Vector2(720, 1480)
	clip_contents = true
	var bake_args := OS.get_cmdline_user_args()
	if bake_args.has("--bake-items") or bake_args.has("--bake-sprites"):
		_bake(bake_args)
		return
	home = HomeScreen.new()
	add_child(home)
	board_screen = BoardScreen.new()
	board_screen.visible = false
	add_child(board_screen)
	cfg_screen = CfgEditScript.new()
	cfg_screen.visible = false
	add_child(cfg_screen)
	popup_layer = _layer()
	topbar = TopBar.new()
	add_child(topbar)
	pin = _layer()
	fx_layer = _layer()
	_curtain = ColorRect.new()
	_curtain.size = size
	_curtain.color = Color(0.23, 0.14, 0.08, 0.0)
	_curtain.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_curtain)
	_wipe = ScreenWipeScript.new()
	add_child(_wipe)
	_add_fps()
	_guide = GuideScript.new()
	board_screen.add_child(_guide)
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--shots="):
			_fps_lbl.get_parent().visible = false
			_run_shots(a.get_slice("=", 1).split(","))
			return
	if not G.seen_tutorial:
		begin_guide()

func begin_guide() -> void:
	if G.seen_tutorial or not G.tutorial_on or _guide == null:
		return
	for c in popup_layer.get_children():
		c.visible = false
		c.queue_free()
	show_screen("board", true)
	_guide.present()

func _add_fps() -> void:
	var host := Control.new()
	host.mouse_filter = MOUSE_FILTER_IGNORE
	host.size = size
	add_child(host)
	var box := Rect2(548, 2, 164, 34)
	_fps_lbl = UI.lbl(host, "-- FPS", Rect2(box.position.x + 3, box.position.y + 3, box.size.x - 6, box.size.y - 6), 20, Color(1, 1, 1, 0.55))

func _process(_dt: float) -> void:
	if _fps_lbl == null or not _fps_lbl.visible:
		return
	var fps := Engine.get_frames_per_second()
	if fps == _fps_shown:
		return
	_fps_shown = fps
	_fps_lbl.text = "%d FPS" % fps

func _layer() -> Control:
	var c := Control.new()
	c.size = size
	c.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(c)
	return c

func show_screen(name: String, instant: bool = false) -> void:
	if home != null: home.recall_go()
	if name == screen:
		return
	screen = name
	if instant:
		_apply_screen()
		return
	# 棋盘 ⇄ 部落用兽皮门转场；配置页还是简单的淡入淡出
	if name in ["board", "home"] and _wipe != null and not _wipe.running():
		_wipe.play(name, _apply_screen)
		return
	_curtain.mouse_filter = MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_curtain, "color:a", 1.0, 0.15)
	tw.tween_callback(_apply_screen)
	tw.tween_property(_curtain, "color:a", 0.0, 0.22)
	tw.tween_callback(func(): _curtain.mouse_filter = MOUSE_FILTER_IGNORE)
	Sfx.play("drum")

func _apply_screen() -> void:
	home.visible = screen == "home"
	board_screen.visible = screen == "board"
	cfg_screen.visible = screen == "cfg"
	topbar.visible = screen != "cfg"
	if screen == "board":
		board_screen.board.select(-1)
	topbar.set_sand_context(false)

func open(name: String, arg = null) -> PopupBase:
	if name in ["album", "pack"] and G.level < Data.CARD_LEVEL:
		toast("典藏卡在 %d 级解锁" % Data.CARD_LEVEL)
		return null
	var p: PopupBase
	match name:
		"choice_chest":
			p = preload("res://scripts/ui/ChoiceChestPopup.gd").new()
			p.cell = int(arg)
			p.box_id = G.cell_id(int(arg))
		"ufo":
			p = preload("res://scripts/ui/UfoPopup.gd").new()
		"daily_ad":
			p = preload("res://scripts/ui/DailyAdPopup.gd").new()
		"duel": p = preload("res://scripts/ui/DuelPopup.gd").new()
		"seven_day":
			p = preload("res://scripts/ui/SevenDayPopup.gd").new()
		"merge_event":
			p = preload("res://scripts/ui/MergeEventPopup.gd").new()
			if arg is String: p.period_key = arg
		"energy":
			# 火种大礼包这期能买就先弹它（开期要问服务器，异步打开），否则琥珀买体力
			if Offers.wants_energy():
				Offers.open_energy()
				return null
			p = Popups.energy()
		"energy_amber": p = Popups.energy()
		"energy_offer": p = preload("res://scripts/ui/EnergyOfferPopup.gd").new()
		"spree": p = preload("res://scripts/ui/SpreePopup.gd").new()
		"howto": p = Popups.howto()
		"store": p = Popups.store()
		"settings": p = Popups.settings()
		"build": p = Popups.build(arg)
		"book": p = Popups.book(0 if arg == null else arg)
		"inventory": p = Popups.inventory()
		"item_info": p = Popups.item_info(arg)
		"levelup": p = Popups.levelup()
		"board_reward": p = Popups.board_reward(arg if arg is Array else [])
		"event":
			if G.level < Data.CARD_LEVEL:
				toast("典藏卡册 %d 级开放" % Data.CARD_LEVEL)
				return null
			p = Popups.event()
		"pass": p = PassPopupScript.screen()
		"pass_buy": p = PassPopupScript.buy()
		"album": p = Popups.album(arg)
		"pack": p = Popups.pack()
		"level": p = Popups.level_info()
		_: return null
	if p == null:
		return null
	_attach_popup(p)
	return p

## 全屏领奖。rewards 是 [[物品 id, 数量], ...]。apply 为假时物品已经入账，面板只负责飞行动画。
func present_rewards(rewards: Array, apply := true) -> void:
	var snap: Array = []
	for rw in rewards:
		if rw is Array and rw.size() >= 2 and str(rw[0]) != "" and int(rw[1]) > 0:
			snap.append([str(rw[0]), int(rw[1])])
	if snap.is_empty():
		return
	var do_apply := apply
	_rw_q.append(func(): return Popups.reward_screen(snap, do_apply))
	_pump_rewards()

## 棋盘石头上的奖励。entries 是 [{i, id, n}, ...]，领取前还挂在格子上。
func present_board_reward(entries: Array) -> void:
	if entries.is_empty():
		return
	var snap := entries.duplicate(true)
	_rw_q.append(func(): return Popups.board_reward(snap))
	_pump_rewards()

func _pump_rewards() -> void:
	if _rw_showing or _rw_q.is_empty():
		return
	var make: Callable = _rw_q.pop_front()
	var p: PopupBase = make.call()
	if p == null:
		_pump_rewards()
		return
	_rw_showing = true
	_attach_popup(p)
	if _guide != null:
		_guide.cover_for_reward()
	var claim := func():
		if not is_instance_valid(p):
			return
		if p.on_tap.is_valid():
			p.on_tap.call()
		else:
			p.close()
	topbar.push_close(claim)
	p.tree_exiting.connect(func(): topbar.pop_close(claim))
	p.tree_exited.connect(func():
		_rw_showing = false
		_pump_rewards())

func _attach_popup(p: PopupBase) -> void:
	popup_layer.add_child(p)
	popup_layer.move_child(p, popup_layer.get_child_count() - 1)
	topbar.on_popup_opened()
	p.tree_exited.connect(topbar.on_popup_exited, CONNECT_ONE_SHOT)
	if p.has_meta("fullscreen"):
		var cb := p.close
		topbar.push_close(cb)
		p.tree_exiting.connect(func(): topbar.pop_close(cb))
	p.open()

func close_all() -> void:
	for c in popup_layer.get_children():
		c.queue_free()

func fly(id: String, from: Vector2, to: Vector2, cb: Callable = Callable(), s: float = 70.0) -> void:
	var d := DrawBox.new()
	d.size = Vector2(s, s)
	d.position = from - d.size * 0.5
	d.pivot_offset = d.size * 0.5
	d.painter = func(ci, sz): Art.item(ci, id, sz * 0.5, s * 0.92)
	fx_layer.add_child(d)
	var mid := from.lerp(to, 0.5) + Vector2(randf_range(-90, 90), -140)
	var step := func(t: float):
		var q := from.lerp(mid, t).lerp(mid.lerp(to, t), t)
		d.position = q - d.size * 0.5
		d.scale = Vector2.ONE * (1.0 + 0.3 * sin(PI * t) - 0.3 * t)
	var tw := d.create_tween()
	tw.tween_method(step, 0.0, 1.0, 0.65).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		if cb.is_valid():
			cb.call()
			Sfx.play("coin", 1.1)
		d.queue_free())

func toast(text: String) -> void:
	var t := Control.new()
	t.mouse_filter = MOUSE_FILTER_IGNORE
	t.size = Vector2(620, 70)
	t.position = Vector2(50, 640)
	fx_layer.add_child(t)
	var w: float = min(600.0, G.font_body.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x + 70.0)
	UI.box(t, Rect2((620 - w) * 0.5, 0, w, 70), func(ci, sz):
		var b := Art.rrect(Rect2(Vector2.ZERO, sz), 28, 301, 0.8)
		Art.dilate(ci, b, 3.0, Art.INK)
		ci.draw_colored_polygon(b, Color(0.24, 0.15, 0.08, 0.92))
		Art.dashed(ci, Art.rrect(Rect2(Vector2.ZERO, sz).grow(-6), 22, 302, 0.0), 8, 6, Color(1, 0.85, 0.6, 0.5), 2.0))
	UI.lbl(t, text, Rect2(0, 0, 620, 70), 26, Color("fff1c4"))
	t.modulate.a = 0.0
	var tw := t.create_tween()
	tw.tween_property(t, "modulate:a", 1.0, 0.15)
	tw.parallel().tween_property(t, "position:y", 600.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.4)
	tw.tween_property(t, "modulate:a", 0.0, 0.3)
	tw.tween_callback(t.queue_free)

func on_merged(i: int) -> void:
	board_screen.on_merged(i)
	if _guide != null:
		_guide.note_merge()

# ---------------------------------------------------------------- 截图自检

func _run_shots(names: PackedStringArray) -> void:
	var dir := ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(dir)
	await get_tree().create_timer(0.5).timeout
	for n in names:
		close_all()
		var parts := n.split(":")
		var what := parts[0]
		match what:
			"home":
				show_screen("home", true)
			"cfg":
				show_screen("cfg", true)
				if parts.size() > 1:
					cfg_screen.call("_go", parts[1])
					if parts.size() > 2:
						await get_tree().process_frame
						await get_tree().process_frame
						if parts[2] == "edit":
							cfg_screen.call("_open_chain", 0)
						elif parts[2] == "item":
							cfg_screen.call("_open_item", 21, 0)
						elif parts[2] == "gen":
							cfg_screen.call("_open_item", 0, 2)
						elif parts[2] == "idle":
							cfg_screen.call("_open_item", 0, 0)
						elif parts[2] == "fruit":
							cfg_screen.call("_open_item", 1, 0)
						elif parts[2] == "pick":
							cfg_screen.call("_shot_pick")
							if parts.size() > 3:
								cfg_screen.get("_chooser").call_deferred("_pick_tab", parts[3])
						elif parts[2] == "cell":
							cfg_screen.call("_shot_cell", parts.size() > 3 and parts[3] == "empty")
			"board":
				show_screen("board", true)
			"board_sel":
				show_screen("board", true)
				board_screen.board.select(8)
			"sim":
				show_screen("board", true)
				var bd := board_screen.board
				G.try_drop(14, 0)
				bd.burst(0)
				for k in 6:
					bd.select(8)
					board_screen._on_activate(8)
				G.orders[0]["items"] = ["fruit_2"]
				G.orders_changed.emit()
				bd.select(0)
			"deliver":
				show_screen("board", true)
				board_screen._on_deliver(0)
				await get_tree().create_timer(0.5).timeout
			"store_bottom", "event_bottom":
				show_screen("home", true)
				var sp := open(what.get_slice("_", 0))
				await get_tree().create_timer(0.4).timeout
				for c in sp.box.get_children():
					if c is Scroller:
						c.offset = c._max()
			"drag":
				show_screen("board", true)
				var bd := board_screen.board
				var src := -1
				for k in G.board.size():
					if G.board[k]["id"] != "" and G.board[k]["lock"] == 0 and Data.type_of(G.board[k]["id"]) == "item":
						src = k
						break
				bd.drag_from = src
				bd.dragging = true
				bd.drag_vis = bd.cell_center(src) + Vector2(150, 120)
				bd._drop(bd.cell_center(G.find_empty_near(src)) + Vector2(30, 30))
				bd.dragging = false
				bd.drag_from = -1
				await get_tree().create_timer(0.08).timeout
			"story":
				show_screen("board", true)
				for r in 3:
					var o: Dictionary = G.orders[0]
					for id in o["items"]:
						G.board[G.find_empty_near(0)]["id"] = id
					G.board_changed.emit()
					board_screen._on_deliver(0)
					await get_tree().create_timer(1.6).timeout
				board_screen._on_stash()
				await get_tree().create_timer(0.5).timeout
			"inv_unlock":
				show_screen("board", true)
				var ip := open("inventory")
				await get_tree().create_timer(0.4).timeout
				for c in ip.box.get_children():
					if c is TButton and c.text == "50":
						c.pressed.emit()
			"orders_end":
				show_screen("board", true)
				var osc: Scroller = board_screen._orders
				osc.offset = osc._max()
			"pack_open":
				show_screen("board", true)
				var pp := open("pack")
				await get_tree().create_timer(0.5).timeout
				pp.on_tap.call()
			_:
				show_screen("board" if what in ["item_info", "inventory", "levelup", "pack", "level"] else "home", true)
				var arg = null
				if parts.size() > 1:
					arg = parts[1]
					if what in ["album", "book"]:
						arg = int(parts[1])
				open(what, arg)
		await get_tree().create_timer(0.9).timeout
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(dir.path_join(n.replace(":", "_") + ".png"))
	get_tree().quit()

## 「生成物品图.bat」：物品图和界面图都从原始绘制代码画成 PNG，画完退出。
func _bake(args: PackedStringArray) -> void:
	var only := false
	for a in args:
		only = only or a.begins_with("--only=")
	# 带 --only= 时只重画那几张界面图，物品图不动
	if args.has("--bake-items") and not only:
		await BakeItemsScript.new().start(self)
	if args.has("--bake-sprites"):
		await BakeSpritesScript.new().start(self, int(BakeItemsScript._cfg()["frames"]))
	get_tree().quit()
