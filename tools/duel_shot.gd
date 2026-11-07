extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var g=root.get_node("G")
	g.new_game()
	g.font_body=load("res://assets/fonts/NotoSansCJKsc-Regular.otf")
	g.font_title=g.font_body
	g.level=8
	g.seen_tutorial=true
	g.tutorial_on=false
	var duel=load("res://scripts/events/DuelRace.gd")
	var phase:="progress"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="): phase=arg.trim_prefix("--phase=")
	if phase!="start": await duel.act("join")
	var s: Dictionary=duel.state()
	s["wins"]=5
	s["claimed"]=["2"]
	if phase!="start":
		s["match"]["me"]=18
		s["match"]["opponent"]=12
		if phase in ["won","lost"]: s["match"]["status"]=phase
	if phase=="matching": load("res://scripts/ui/DuelPopup.gd").matching_until=Time.get_ticks_msec()+3000
	var main=load("res://main.tscn").instantiate()
	root.add_child(main)
	var p=main.open("duel")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--bubble="): p._toggle_reward(int(arg.trim_prefix("--bubble=")))
	await create_timer(0.6).timeout
	for i in 10: await process_frame
	await RenderingServer.frame_post_draw
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="): root.get_texture().get_image().save_png(arg.trim_prefix("--shot="))
	main.close_all()
	await process_frame
	main.queue_free()
	await process_frame
	quit()
