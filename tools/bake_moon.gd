extends SceneTree
## Offline-only Godot renderer; generated PNGs are checked into the project.
var cfg: Dictionary
var output := "res://assets/events/moon/baked"

func _initialize() -> void:
	run.call_deferred()

func bake(key: String, dimensions: Vector2i, painter: Callable, pad := 8) -> void:
	var viewport := SubViewport.new()
	viewport.size = dimensions + Vector2i.ONE * pad * 2
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var art = load("res://tools/MoonBakeArt.gd").new()
	art.cfg = cfg
	art.size = Vector2(dimensions)
	art.position = Vector2.ONE * pad
	art.painter = painter
	viewport.add_child(art)
	await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	assert(not image.is_empty() and image.get_used_rect().size != Vector2i.ZERO)
	assert(image.save_png(output + "/" + key + ".png") == OK)
	print("BAKED ", key, " ", image.get_size())
	viewport.queue_free()
	await process_frame

func run() -> void:
	root.get_node("G").set_process(false)
	var draw_art = load("res://scripts/Art.gd")
	draw_art.boil = 0
	var events = load("res://scripts/events/MergeEvent.gd")
	cfg = events.definition("moon_relics:0")
	DirAccess.make_dir_recursive_absolute(output)
	await bake("tiles", Vector2i(512, 3072), func(ci, _sz):
		for layer in 6:
			for i in 16:
				ci.draw_set_transform(Vector2((i % 4) * 128 + 16, (layer * 4 + i / 4) * 128 + 16))
				var rect := Rect2(0, 0, 96, 96)
				match layer:
					0, 1: ci._floor(rect, i, layer)
					2: ci._recess(rect, i)
					3, 4: ci._slab(rect, i, 1.0, layer == 4)
					5:
						ci._vines(rect, i)
						ci._lock_badge(Vector2(76.8, 76.8))
		ci.draw_set_transform(Vector2.ZERO), 0)
	await bake("scene", Vector2i(632, 1180), func(ci, sz): ci._paint_scene(ci, sz))
	await bake("frame", Vector2i(596, 692), func(ci, sz): ci._paint_frame(ci, sz))
	await bake("corners", Vector2i(616, 60), func(ci, sz): ci._paint_corner_vines(ci, sz))
	await bake("track", Vector2i(608, 138), func(ci, sz): ci._paint_track(ci, sz))
	await bake("shelf", Vector2i(608, 74), func(ci, sz): ci._paint_collection(ci, sz))
	await bake("card", Vector2i(200, 166), func(ci, sz): ci._card(ci, sz, 640))
	await bake("earn", Vector2i(200, 166), func(ci, sz): ci._paint_earn(ci, sz, false))
	await bake("earn_glow", Vector2i(200, 166), func(ci, sz): ci._paint_earn(ci, sz, true))
	await bake("spawn_on", Vector2i(152, 164), func(ci, sz): ci._paint_spawn(ci, sz, true))
	await bake("spawn_off", Vector2i(152, 164), func(ci, sz): ci._paint_spawn(ci, sz, false))
	quit()
