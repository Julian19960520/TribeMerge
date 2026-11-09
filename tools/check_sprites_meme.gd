extends SceneTree
## 对照：左边原始现场绘制，右边预生成贴图。godot --path . --script tools/check_sprites_meme.gd
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	await process_frame
	var vp := SubViewport.new()
	vp.size = Vector2i(1500, 1250)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var d = load("res://scripts/ui/DrawBox.gd").new()
	d.boil = false
	d.size = Vector2(1500, 1250)
	d.painter = load("res://tools/check_sprites_meme_draw.gd").paint
	vp.add_child(d)
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png("res://_shots/sprites/meme_compare.png")
	print("SAVED")
	quit()
