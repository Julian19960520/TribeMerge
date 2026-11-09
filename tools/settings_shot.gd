extends SceneTree
## 设置弹窗截图，并检查沸腾线开关：关掉后 Art.boil 定格、不再发 boil_tick。
## godot --path . --script tools/settings_shot.gd -- --save=user://set_shot/s.json --cloud-off --out=DIR
var _started := false
var out := "."
func _process(_d: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false
func _run() -> void:
	var g := root.get_node("G")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
	g.tutorial_on = false
	g.seen_tutorial = true
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout
	main.open("settings")
	await create_timer(0.8).timeout
	root.get_viewport().get_texture().get_image().save_png(out + "/settings_on.png")
	var ticks := [0]
	g.boil_tick.connect(func(): ticks[0] += 1)
	g.set_boil(false)
	var after_off: int = ticks[0]
	var art = load("res://scripts/Art.gd")
	await create_timer(1.0).timeout
	print("BOIL OFF: boil=", art.boil, " ticks_during_1s=", ticks[0] - after_off)
	g.set_boil(true)
	ticks[0] = 0
	await create_timer(1.0).timeout
	print("BOIL ON: ticks_during_1s=", ticks[0])
	quit()
