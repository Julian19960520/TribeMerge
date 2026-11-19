extends SceneTree
## 主角等级面板截图。
## Godot --path . --script tools/level_info_shot.gd -- --cloud-off --save=user://li_shot/s.json --cloud-state=user://li_shot/c.json --rank-state=user://li_shot/r.json --hot-file=user://li_shot/h.json [--name=xxx]
var g
var main
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var tag := "now"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--name="): tag = a.trim_prefix("--name=")
	g = root.get_node("G")
	g.new_game(); g.tutorial_on = false; g.seen_tutorial = true
	g.tips_seen["howto"] = true
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.6).timeout
	main.show_screen("board", true)
	await create_timer(0.4).timeout
	main.close_all()
	main.open("level")
	await create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://_shots/level_info")
	DirAccess.make_dir_recursive_absolute(dir)
	root.get_viewport().get_texture().get_image().save_png(dir + "/li_" + tag + ".png")
	print("shot ", dir + "/li_" + tag + ".png")
	quit()
