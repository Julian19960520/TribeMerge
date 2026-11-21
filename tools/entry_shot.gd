extends SceneTree
## 棋盘活动入口截图：GM 全开活动，双人竞速进行中，截棋盘顶部那一行（不碰真实存档）。
## Godot --path . --script tools/entry_shot.gd -- --save=user://entry_shot/s.json --cloud-off --rank-state=user://entry_shot/r.json --cloud-state=user://entry_shot/c.json --hot-file=user://entry_shot/h.json --shot=PATH
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var g = root.get_node("G")
	g.new_game()
	g.tutorial_on = false
	g.seen_tutorial = true
	g.level = 30
	g.gm_activities = true
	var duel = load("res://scripts/events/DuelRace.gd")
	await duel.act("join")
	var s: Dictionary = duel.state()
	if not s.get("match", {}).is_empty():
		s["match"]["me"] = 2600
		s["match"]["opponent"] = 3400
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout
	main.show_screen("board")
	await create_timer(2.0).timeout
	main.close_all()
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="): root.get_texture().get_image().save_png(arg.trim_prefix("--shot="))
	quit()
