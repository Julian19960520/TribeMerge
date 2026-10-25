extends Control

var home: HomeScreen
var board_screen: BoardScreen
var topbar: TopBar
var popup_layer: Control
var fx_layer: Control
var screen := "home"
var _curtain: ColorRect

func _ready() -> void:
	G.main = self
	size = Vector2(720, 1480)
	clip_contents = true
	home = HomeScreen.new()
	add_child(home)
	board_screen = BoardScreen.new()
	board_screen.visible = false
	add_child(board_screen)
	topbar = TopBar.new()
	add_child(topbar)
	popup_layer = _layer()
	fx_layer = _layer()
	_curtain = ColorRect.new()
	_curtain.size = size
	_curtain.color = Color(0.23, 0.14, 0.08, 0.0)
	_curtain.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_curtain)
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--shots="):
			_run_shots(a.get_slice("=", 1).split(","))
			return
	if not G.seen_tutorial:
		open.call_deferred("howto")

func _layer() -> Control:
	var c := Control.new()
	c.size = size
	c.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(c)
	return c

func show_screen(name: String, instant: bool = false) -> void:
	if name == screen:
		return
	screen = name
	if instant:
		_apply_screen()
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
	if screen == "board":
		board_screen.board.select(-1)

func open(name: String, arg = null) -> PopupBase:
	var p: PopupBase
	match name:
		"energy": p = Popups.energy()
		"howto": p = Popups.howto()
		"store": p = Popups.store()
		"settings": p = Popups.settings()
		"build": p = Popups.build(arg)
		"book": p = Popups.book(0 if arg == null else arg)
		"inventory": p = Popups.inventory()
		"item_info": p = Popups.item_info(arg)
		"levelup": p = Popups.levelup()
		"event": p = Popups.event()
		"album": p = Popups.album(arg)
		"pack": p = Popups.pack()
		_: return null
	popup_layer.add_child(p)
	p.open()
	return p

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
				G.orders[0]["items"] = ["berry_2"]
				G.orders_changed.emit()
				bd.select(0)
			"deliver":
				show_screen("board", true)
				board_screen._on_deliver(0)
				await get_tree().create_timer(0.5).timeout
			"pack_open":
				show_screen("board", true)
				var pp := open("pack")
				await get_tree().create_timer(0.5).timeout
				pp.on_tap.call()
			_:
				show_screen("board" if what in ["item_info", "inventory", "levelup", "pack"] else "home", true)
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
