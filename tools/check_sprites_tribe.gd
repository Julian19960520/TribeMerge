extends SceneTree
## 对照：左边原始现场绘制，右边预生成贴图。godot --path . --script tools/check_sprites_tribe.gd
## 出两张：_shots/sprites/tribe_compare.png（零件）、tribe_village_compare.png（整个村庄）
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	await process_frame
	var dr = load("res://tools/check_sprites_tribe_draw.gd")
	await _shot(Vector2i(1440, 1480), dr.village, "res://_shots/sprites/tribe_village_compare.png")
	await _shot(Vector2i(1400, 1500), dr.parts, "res://_shots/sprites/tribe_compare.png")
	print("SAVED")
	quit()
func _shot(sz: Vector2i, painter: Callable, path: String) -> void:
	var vp := SubViewport.new()
	vp.size = sz
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var d = load("res://scripts/ui/DrawBox.gd").new()
	d.boil = false
	d.size = Vector2(sz)
	d.painter = painter
	vp.add_child(d)
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(path)
	vp.queue_free()
