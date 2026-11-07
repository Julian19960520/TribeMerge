extends SceneTree
var failures := 0
var shot_dir := "user://"
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func shot(name: String) -> void:
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shot_dir.path_join(name+".png"))
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="): shot_dir=arg.trim_prefix("--shots=")
	var g=root.get_node("G")
	g.new_game()
	g.font_body=load("res://assets/fonts/NotoSansCJKsc-Regular.otf")
	g.font_title=g.font_body
	g.tutorial_on=false
	g.seen_tutorial=true
	g.level=10
	var data=load("res://scripts/Data.gd")
	for ch in data.CHAINS:
		for lv in data.max_lv(ch): g.discovered["%s_%d"%[ch,lv+1]]=true
	var main=load("res://main.tscn").instantiate()
	root.add_child(main)
	var panel=main.open("item_info","basket_4")
	await shot("info-generator")
	var buttons=panel.find_children("related_*","",true,false)
	check(not buttons.is_empty(),"generator drops are clickable tiles")
	if not buttons.is_empty():
		buttons[0].pressed.emit()
		await shot("info-source")
	var item=main.open("item_info","fruit_3")
	await process_frame
	var sources=item.find_children("related_*","",true,false)
	check(sources.size()==1,"normal item has a clickable producer tile")
	if sources.size()==1:
		check(absf(sources[0].position.x+sources[0].size.x/2-360)<1,"single source horizontally centered")
		sources[0].pressed.emit()
		await process_frame
	item.queue_free()
	panel.queue_free()
	await process_frame
	var entry=load("res://scripts/ui/UfoEntry.gd").new()
	root.add_child(entry)
	entry.set_process(false)
	entry.hit.visible=true
	entry.timer.text="12:34"
	check(entry.timer.position.y+entry.timer.size.y<=entry.C.y+entry.RAD,"UFO timer inside bubble")
	await shot("info-ufo")
	main.close_all()
	await process_frame
	main.queue_free()
	entry.queue_free()
	await process_frame
	g.main=null
	print("RESULT: ",failures," failures")
	quit(1 if failures else 0)
