extends SceneTree
## 七日任务面板 + 棋盘活动入口截图（独立存档，不碰真实存档）。
## Godot --path . --script tools/seven_shot.gd -- --save=user://seven_shot/s.json --cloud-off --rank-state=user://seven_shot/r.json --cloud-state=user://seven_shot/c.json --hot-file=user://seven_shot/h.json --out=DIR
var _started := false
var out := "."
func _process(_d: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false
func _shot(n: String) -> Image:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out + "/sd_" + n + ".png")
	print("shot ", n)
	return img
func _run() -> void:
	var g := root.get_node("G")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
	g.new_game()
	g.tutorial_on = false
	g.seen_tutorial = true
	g.level = 13
	var tasks = load("res://scripts/events/SevenDay.gd")
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout
	main.show_screen("board")
	await create_timer(2.0).timeout
	# 入口：活动未开（无 GM）→ 截一张；开 GM 后再截
	var img := _shot("board_plain")
	_crop(img, "entries_plain")
	g.gm_activities = true
	g.merge_event_changed.emit()
	for k in ["2026-11-01", "2026-11-02", "2026-11-03"]: tasks.login(k)
	tasks.record("orders", 40)
	tasks.record("merges", 700)
	tasks.record("xp", 22)
	tasks.record("shell", 5200)
	tasks.record("amber", 12)
	tasks.record("amber_spent", 10)
	for id in ["d1_1", "d1_2", "d1_3", "d1_4", "d1_5", "d2_2"]: await tasks.claim(id)
	g.changed.emit()
	await create_timer(1.0).timeout
	img = _shot("board")
	_crop(img, "entries")
	var p = main.open("seven_day")
	await create_timer(1.2).timeout
	_shot("panel_open")
	p.page = 0; p._refresh()
	await create_timer(0.5).timeout
	_shot("panel_day1")
	p.page = 6; p._refresh()
	await create_timer(0.5).timeout
	_shot("panel_day7")
	p._stage(tasks.config()["milestones"][-1])
	await create_timer(1.0).timeout
	_shot("stage_grand")
	print("DONE")
	quit(0)
func _crop(img: Image, n: String) -> void:
	var vs := Vector2(img.get_width(), img.get_height()) / Vector2(720, 1480)
	var r := Rect2i(Vector2i(0, int(120 * vs.y)), Vector2i(int(720 * vs.x), int(300 * vs.y)))
	var c := img.get_region(r)
	c.resize(c.get_width() * 2, c.get_height() * 2, Image.INTERPOLATE_LANCZOS)
	c.save_png(out + "/sd_" + n + ".png")
