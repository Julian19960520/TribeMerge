extends SceneTree
## 部落建造截图：建造面板 + 村庄（不碰真实存档）。
## Godot --path . --script tools/build_shot.gd -- --save=user://bd_shot/s.json --cloud-off --rank-state=user://bd_shot/r.json --cloud-state=user://bd_shot/c.json --hot-file=user://bd_shot/h.json --out=DIR [--tag=x] [--builds=JSON] [--level=N]
var out := "."
var tag := "a"
var builds := {"fire": 4, "_steps": {"fire": 1}}
var lv := 8
var buy := false
var g
var main

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
		if a.begins_with("--tag="): tag = a.trim_prefix("--tag=")
		if a.begins_with("--level="): lv = int(a.trim_prefix("--level="))
		if a == "--buy": buy = true
		if a.begins_with("--builds="): builds = JSON.parse_string(a.trim_prefix("--builds="))
	_run.call_deferred()

func _shot(n: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out + "/bd_%s_%s.png" % [tag, n])
	print("shot ", n)

func _run() -> void:
	g = root.get_node("G")
	g.new_game()
	g.tutorial_on = false
	g.seen_tutorial = true
	g.level = lv
	g.shells = 500
	g.builds = builds
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout
	main.show_screen("home")
	await create_timer(1.2).timeout
	for c in main.popup_layer.get_children(): c.queue_free()
	await create_timer(0.2).timeout
	await _shot("home")
	var id: String = g.rules.progression.next_build_id()
	main.open("build", id if id != "" else "fire")
	await create_timer(0.8).timeout
	await _shot("panel")
	if buy:
		# 点建造：面板关掉、回部落播动画；中途和结束各截一张
		var popup = main.popup_layer.top()
		var b = _find_buy(popup)
		b.pressed.emit()
		await create_timer(0.7).timeout
		await _shot("anim_hammer")
		await create_timer(0.7).timeout
		await _shot("anim_pop")
		await create_timer(1.6).timeout
		await _shot("anim_after")
		print("panel_open_after=", main.popup_layer.top() != null, " building=", main.home.is_building())
	quit()

func _find_buy(node: Node):
	if node is Control and node.has_signal("pressed") and node.get("res") == "shell_2": return node
	for child in node.get_children():
		var f = _find_buy(child)
		if f != null: return f
	return null
