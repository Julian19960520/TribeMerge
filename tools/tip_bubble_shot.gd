extends SceneTree
## 提示气泡排版截图：一行 / 两行 / 带亮处。
## Godot --path . --script tools/tip_bubble_shot.gd -- --cloud-off --save=user://tip_shot/s.json --cloud-state=user://tip_shot/c.json --rank-state=user://tip_shot/r.json --hot-file=user://tip_shot/h.json
var g
var main
func _initialize() -> void:
	run.call_deferred()
func _shot(n: String) -> void:
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://_shots/tips")
	DirAccess.make_dir_recursive_absolute(dir)
	root.get_viewport().get_texture().get_image().save_png(dir + "/tip_" + n + ".png")
	print("shot ", dir + "/tip_" + n + ".png")
func run() -> void:
	g = root.get_node("G")
	g.set_process(false)
	var replay = root.get_node("Replay")
	replay.set_process(false); root.get_node("Cloud").set_process(false)
	replay.active = true; replay.worker = false; replay.authorized = true; replay.executing = true
	g.simulation_time = 1793577600.0; replay.clock = int(g.simulation_time)
	g.new_game(); g.tutorial_on = false; g.seen_tutorial = true
	replay.advance(); replay.executing = false
	g.tips_seen["howto"] = true
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout
	main.show_screen("board", true)
	await create_timer(0.4).timeout
	main.close_all()
	var tips = main.tips
	for k in g.tips_seen.keys(): pass
	tips.visible = false
	tips.show_once("shot_one", "「不那那」够了。点那个锤子。")
	await _shot("one_line")
	tips.visible = false
	tips.show_once("shot_two", "订单要的东西棋盘上都有了，点一下订单卡就能交单，拿到不那那和经验。")
	await _shot("two_lines")
	tips.visible = false
	var bs = main.board_screen
	tips.show_once("shot_target", "「不那那」够了。点那个锤子。", func(): return bs.board.get_global_rect().grow(-300))
	await _shot("target")
	quit()
