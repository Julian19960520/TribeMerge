extends SceneTree
## Offline texture bake. Requires a rendering display; never run by gameplay/export.
## godot --path . --script tools/bake_board.gd -- --cloud-off --save=/tmp/board-bake.json [--dir=res://assets/board]
const ROCK_SCALE := 1.08
var art
var draw_art
func _initialize() -> void:
	run.call_deferred()
func bake(path: String, dimensions: Vector2i, painter: Callable) -> void:
	var viewport := SubViewport.new()
	viewport.size = dimensions
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var draw = load("res://scripts/ui/DrawBox.gd").new()
	draw.boil = false
	draw.size = Vector2(dimensions)
	draw.painter = painter
	viewport.add_child(draw)
	await process_frame
	await RenderingServer.frame_post_draw
	var img := viewport.get_texture().get_image()
	assert(img.save_png(path) == OK)
	print("BAKED ", path, " ", img.get_size())
	viewport.queue_free()
	await process_frame
func run() -> void:
	root.get_node("G").set_process(false)
	draw_art = load("res://scripts/Art.gd")
	art = load("res://tools/BoardBakeArt.gd")
	var dir := "res://assets/board"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dir="): dir = a.trim_prefix("--dir=")
	DirAccess.make_dir_recursive_absolute(dir)
	for phase in 4:
		draw_art.boil = phase
		await bake(dir + "/rocks_%d.png" % phase, Vector2i(1152, 896), func(ci, _sz):
			for i in 63:
				# 石头放大一点，几乎占满格子，挡路的感觉更明确
				ci.draw_set_transform(Vector2((i % 9) * 128 + 16, (i / 9) * 128 + 16) + Vector2(48, 52) * (1.0 - ROCK_SCALE), 0.0, Vector2.ONE * ROCK_SCALE)
				art.rock(ci, Rect2(0, 0, 96, 96), i))
		await bake(dir + "/frame_%d.png" % phase, Vector2i(712, 904), func(ci, _sz):
			ci.draw_set_transform(Vector2(20, 20))
			art.frame(ci, Vector2(672, 864)))
	await bake(dir + "/cracks.png", Vector2i(1152, 896), func(ci, _sz):
		for i in 63:
			ci.draw_set_transform(Vector2((i % 9) * 128 + 16, (i / 9) * 128 + 16) + Vector2(48, 52) * (1.0 - ROCK_SCALE), 0.0, Vector2.ONE * ROCK_SCALE)
			art.cracks(ci, Rect2(0, 0, 96, 96), i, 0.6))
	await bake(dir + "/fragments.png", Vector2i(512, 64), func(ci, _sz):
		for k in 8:
			ci.draw_set_transform(Vector2(k * 64, 0))
			art.fragment(ci, k))
	await bake(dir + "/floor.png", Vector2i(384, 96), func(ci, _sz):
		for k in 4:
			ci.draw_set_transform(Vector2(k * 96, 0))
			art.floor_tile(ci, k))
	quit()
