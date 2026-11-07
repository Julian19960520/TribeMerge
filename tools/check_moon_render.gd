extends SceneTree
var draw_count := 0
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var g = root.get_node("G")
	g.new_game()
	g.font_body=load("res://assets/fonts/NotoSansCJKsc-Regular.otf")
	g.font_title=g.font_body
	g.set_process(false)
	g.tutorial_on = false
	g.seen_tutorial = true
	g.level = 10
	var ev = load("res://scripts/events/MergeEvent.gd")
	var cfg: Dictionary = ev.current()
	var state: Dictionary = ev.state(cfg)
	state["cells"][95] = {"id": "moon_1", "lock": 0}
	state["cells"][94] = {"id": "moon_1", "lock": 0}
	state["cells"][89] = {"id": "moon_1", "lock": 1}
	state["points"] = 8
	state["discovered"] = {"moon_1": true}
	var path := "res://scripts/ui/MergeEventBoard.gd"
	var tag := "after"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--baseline="):
			path = a.trim_prefix("--baseline=")
			tag = "before"
	var source := FileAccess.get_file_as_string(path).replace("class_name MergeEventBoard\n", "")
	source = source.replace("extends Control\n", "extends Control\nvar draw_usec := 0\n")
	source = source.replace("func _draw() -> void:\n", "func _draw() -> void:\n\tvar started := Time.get_ticks_usec()\n")
	source = source.replace("\nfunc _pop(", "\n\tdraw_usec = Time.get_ticks_usec() - started\n\nfunc _pop(")
	var measured := GDScript.new()
	measured.source_code = source
	assert(measured.reload() == OK)
	var board = measured.new()
	board.cfg = cfg
	board.size = Vector2(576, 672)
	root.add_child(board)
	board.draw.connect(func(): draw_count += 1)
	await process_frame
	await RenderingServer.frame_post_draw
	var count := draw_count
	for i in 10:
		g.boil_tick.emit()
		await process_frame
		await RenderingServer.frame_post_draw
	var idle := draw_count - count
	board.selected = 95
	var samples: Array = []
	for i in 60:
		board.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		if i >= 10: samples.append(board.draw_usec)
	samples.sort()
	print("MOON_PROFILE ", JSON.stringify({"version": tag, "idle_redraws": idle, "draw_median_us": samples[samples.size()/2], "draw_p90_us": samples[int(samples.size()*0.9)]}))
	if tag == "after": assert(idle == 0, "Idle board must not redraw on line-boil ticks")
	board.queue_free()
	await process_frame
	if tag == "after":
		var main = load("res://main.tscn").instantiate()
		root.add_child(main)
		var panel = main.open("merge_event")
		for i in 12: await process_frame
		await RenderingServer.frame_post_draw
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--shot="):
				root.get_texture().get_image().save_png(a.trim_prefix("--shot="))
		panel.close()
		main.queue_free()
		await process_frame
		g.main = null
	quit()
