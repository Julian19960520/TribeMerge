extends Control


const GuideScript := preload("res://scripts/ui/Guide.gd")
const ScreenWipeScript := preload("res://scripts/ui/ScreenWipe.gd")
const OrderChestFx := preload("res://scripts/ui/OrderChestFx.gd")

var home: HomeScreen
var board_screen: BoardScreen
var cfg_screen: Control
var topbar: TopBar
var popup_layer: PopupStack
var pin: Control
var fx_layer: Control
var screen := "home"
var _curtain: ColorRect
var _wipe: Control
var _guide
## 引导结束后的分阶段一次性提示
var tips: Tips
var _fps_lbl: Label
## 全屏领奖一次只开一张，后面的排队
var _rw_q: Array = []
var _rw_showing := false
var _fps_shown := -1

func _ready() -> void:
	G.main = self
	G.presentation_event.connect(_on_presentation)
	Cloud.notice.connect(toast)
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
	board_screen.set_active(false)
	popup_layer = PopupStack.new()
	add_child(popup_layer)
	topbar = TopBar.new()
	add_child(topbar)
	popup_layer.topbar = topbar
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
	tips = Tips.new()
	add_child(tips)
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
	if not _guide.visible: _guide.present()

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
	home.set_active(screen == "home")
	board_screen.set_active(screen == "board")
	if screen == "cfg" and cfg_screen == null:
		cfg_screen = load("res://scripts/ui/CfgEdit.gd").new()
		add_child(cfg_screen)
	if cfg_screen != null:
		cfg_screen.visible = screen == "cfg"
		cfg_screen.process_mode = Node.PROCESS_MODE_INHERIT if screen == "cfg" else Node.PROCESS_MODE_DISABLED
	topbar.visible = screen != "cfg"
	if screen == "board":
		board_screen.board.select(-1)
		if _guide != null and not G.seen_tutorial and G.tutorial_on and not _guide.visible: _guide.present()
	topbar.set_sand_context(false)

## Configuration changes replace the entire test session, including pending UI callbacks.
func prepare_session_restart() -> void:
	if _guide != null:
		_guide.free()
		_guide = null
	_rw_q.clear()
	_rw_showing = false
	for popup in popup_layer.get_children(): popup.free()
	for effect in fx_layer.get_children(): effect.free()
	board_screen.board.select(-1)

func reset_session_views() -> void:
	var home_index := home.get_index()
	var board_index := board_screen.get_index()
	home.free()
	board_screen.free()
	home = HomeScreen.new()
	add_child(home)
	move_child(home, home_index)
	board_screen = BoardScreen.new()
	add_child(board_screen)
	move_child(board_screen, board_index)
	_guide = GuideScript.new()
	board_screen.add_child(_guide)
	_apply_screen()

func open(name: String, arg = null) -> PopupBase:
	var p := PopupRegistry.create(name, arg)
	if p != null: _attach_popup(p)
	return p

## 展示已提交的奖励；到账只由玩法命令负责。
func present_rewards(rewards: Array) -> void:
	var snap: Array = []
	for rw in rewards:
		if rw is Array and rw.size() >= 2 and str(rw[0]) != "" and int(rw[1]) > 0:
			snap.append([str(rw[0]), int(rw[1])])
	if snap.is_empty():
		return
	_rw_q.append(func(): return RewardPopups.reward_screen(snap))
	_pump_rewards()

## 棋盘石头上的奖励。entries 是 [{i, id, n}, ...]，领取前还挂在格子上。
func present_board_reward(entries: Array) -> void:
	if entries.is_empty():
		return
	var snap := entries.duplicate(true)
	_rw_q.append(func(): return RewardPopups.board_reward(snap))
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
	popup_layer.present(p)

func close_all() -> void:
	popup_layer.clear()

func _on_presentation(kind: String, payload: Dictionary) -> void:
	match kind:
		"notice": toast(str(payload.get("text", "")))
		"board_spawn":
			if screen == "board" and is_instance_valid(board_screen): board_screen.board.fly_in(int(payload["origin"]), int(payload["to"]), str(payload["id"]))
		"craft_complete":
			if screen == "board": Sfx.play("merge", 1.08)
		"order_chest":
			_play_order_chest(payload.get("items", []), int(payload.get("stashed", 0)))
		"level_up":
			_open_levelup_after_chest()
		"new_generator":
			var gid := str(payload.get("id", ""))
			_rw_q.append(func(): return RewardPopups.new_generator(gid))
			_pump_rewards()
		"packs_earned":
			var count := int(payload.get("count", 0))
			if count > 0: present_rewards([["pack_1", count]])
		"overflow":
			var count := int(payload.get("count", 0))
			if count > 0: toast("放不下的 %d 个物品进了暂存区" % count)

## 升级的订单宝箱（丰收圣筐全屏动画）播完的时刻
var _chest_until := 0
## 升级了、面板还没弹出来：这段时间一次性提示不许插进来
var level_pending := false

## 订单宝箱的物品真正落完（棋盘上没有在飞的物品）再弹升级面板；最多再等 3 秒兜底。
func _open_levelup_after_chest() -> void:
	level_pending = true
	if is_instance_valid(tips) and tips.visible: tips.yield_to_popup()
	await get_tree().create_timer(maxf(0.7, float(_chest_until - Time.get_ticks_msec()) / 1000.0 + 0.3)).timeout
	var deadline := Time.get_ticks_msec() + 3000
	while is_inside_tree() and is_instance_valid(board_screen) and not board_screen.board.flights.is_empty() and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.1).timeout
	if not is_inside_tree():
		return
	await get_tree().create_timer(0.25).timeout
	open("levelup")
	level_pending = false

func _play_order_chest(items: Array, stashed: int) -> void:
	if items.is_empty():
		if stashed > 0: toast("族人要的 %d 件东西放进了暂存区" % stashed)
		return
	if screen != "board" or not is_instance_valid(board_screen):
		return
	## 全屏「丰收圣筐」：落筐、开盖，材料一件件飞到棋盘；升级面板等它播完再弹
	var fx := OrderChestFx.new()
	fx.items = items
	fx.stashed = stashed
	fx_layer.add_child(fx)
	_chest_until = Time.get_ticks_msec() + int(fx.total() * 1000.0)

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
	UI.box(t, Rect2((620 - w) * 0.5, 0, w, 70), func(ci, sz): Sprites.draw(ci, "toast", Rect2(Vector2.ZERO, sz)))
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
				bd._drop(bd.cell_center(G.rules.board.find_empty_near(src)) + Vector2(30, 30))
				bd.dragging = false
				bd.drag_from = -1
				await get_tree().create_timer(0.08).timeout
			"story":
				show_screen("board", true)
				for r in 3:
					var o: Dictionary = G.orders[0]
					for id in o["items"]:
						G.board[G.rules.board.find_empty_near(0)]["id"] = id
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
	var BakeItemsScript = load("res://scripts/BakeItems.gd")
	var BakeSpritesScript = load("res://scripts/BakeSprites.gd")
	var only := false
	for a in args:
		only = only or a.begins_with("--only=")
	# 带 --only= 时只重画那几张界面图，物品图不动
	if args.has("--bake-items") and not only:
		await BakeItemsScript.new().start(self)
	if args.has("--bake-sprites"):
		await BakeSpritesScript.new().start(self, int(BakeItemsScript._cfg()["frames"]))
	get_tree().quit()
