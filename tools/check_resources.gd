extends SceneTree
## Residency, lazy startup and hidden-screen animation regression checks.

const TextureCache := preload("res://scripts/resources/TextureCache.gd")
var failures := 0

func _initialize() -> void:
	check.call_deferred()

func expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func check() -> void:
	var items := root.get_node("Items")
	var sprites := root.get_node("Sprites")
	var sfx := root.get_node("Sfx")
	var game := root.get_node("G")
	game.set_process(false)
	root.get_node("Replay").set_process(false)
	root.get_node("Cloud").set_process(false)
	expect(int(items.cache_stats()["textures"]) == 0, "Startup decoded item textures")
	expect(int(sprites.cache_stats()["textures"]) == 0, "Startup decoded UI textures")
	expect(sfx._streams.is_empty() and sfx._players.is_empty(), "Startup synthesized unused sounds")
	if "--replay-worker" in OS.get_cmdline_user_args():
		expect(items._ids.is_empty() and sprites._meta.is_empty(), "Replay loaded visual metadata")
		expect(sfx._music == null, "Replay initialized background music")
		expect(items.frame_texture("fruit_1", true, 0) == null, "Replay accepted a texture request")
		sfx.play("pop")
		sfx.refresh_music()
		expect(sfx._streams.is_empty() and sfx._players.is_empty() and sfx._music == null, "Replay initialized audio after a presentation request")
		print("PASS: replay worker has no image or audio residency")
		quit(1 if failures else 0)
		return
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/items/anim.json"))
	var id := str(manifest["ids"][0])
	var first: Texture2D = items.frame_texture(id, true, 0)
	expect(first != null and first.get_size() == Vector2(256, 256), "Requested frame failed to decode")
	expect(first == items.frame_texture(id, true, 0), "Repeated draws did not reuse the same texture")
	expect(int(items.cache_stats()["textures"]) == 1, "One draw decoded unrelated animation frames")
	var sample: Array = manifest["ids"].slice(0, 20)
	for phase in 100:
		for sample_id in sample:
			expect(items.frame_texture(str(sample_id), true, phase % items.frames) != null, "Animated working set failed to load")
	expect(int(items.cache_stats()["loads"]) == sample.size() * items.frames, "Animation working set repeatedly decoded cached frames")
	expect(int(items.cache_stats()["resident_bytes"]) <= int(items.cache_stats()["budget_bytes"]), "Animation working set exceeded cache budget")
	var cache = TextureCache.new(2 * 256 * 256 * 4)
	var paths := []
	for frame in 3:
		paths.append("res://assets/items/png/%s_r1_%d.png" % [id, frame])
	var kept: Texture2D = cache.fetch(paths[0])
	cache.fetch(paths[1])
	cache.fetch(paths[0])
	cache.fetch(paths[2])
	expect(cache.resident_bytes <= cache.budget_bytes and cache.evictions == 1, "LRU exceeded its memory budget")
	expect(kept == cache.fetch(paths[0]) and cache.loads == 3, "LRU evicted a recently displayed frame")
	var key := str(sprites._meta.keys()[0])
	var sprite: Texture2D = sprites.frame_texture(key, 0)
	expect(sprite != null and sprite == sprites.frame_texture(key, 0), "UI frame cache failed to reuse imported textures")
	var host := Control.new()
	host.size = Vector2(200, 200)
	host.clip_contents = true
	root.add_child(host)
	var box = load("res://scripts/ui/DrawBox.gd").new()
	box.size = Vector2(100, 100)
	host.add_child(box)
	var button = load("res://scripts/ui/TButton.gd").new()
	button.size = Vector2(100, 100)
	host.add_child(button)
	expect(game.boil_tick.is_connected(box._on_boil) and game.boil_tick.is_connected(button._on_boil), "Visible animated controls did not subscribe")
	host.hide()
	expect(not game.boil_tick.is_connected(box._on_boil) and not game.boil_tick.is_connected(button._on_boil), "Hidden controls retained animation subscriptions")
	host.show()
	expect(game.boil_tick.is_connected(box._on_boil) and game.boil_tick.is_connected(button._on_boil), "Shown controls did not resume animation")
	box.position = Vector2(300, 0)
	button.position = Vector2(300, 0)
	await process_frame
	expect(not game.boil_tick.is_connected(box._on_boil) and not game.boil_tick.is_connected(button._on_boil), "Clipped list entries retained animation subscriptions")
	box.position = Vector2.ZERO
	button.position = Vector2.ZERO
	await process_frame
	expect(game.boil_tick.is_connected(box._on_boil) and game.boil_tick.is_connected(button._on_boil), "Scrolled-in list entries did not resume animation")
	box.boil = false
	expect(not game.boil_tick.is_connected(box._on_boil), "Static painter retained animation subscription")
	box.boil = true
	host.remove_child(button)
	host.remove_child(box)
	button.hide()
	button.show()
	button.size = Vector2(110, 100)
	box.hide()
	box.show()
	box.size = Vector2(110, 100)
	expect(not game.boil_tick.is_connected(button._on_boil) and not game.boil_tick.is_connected(box._on_boil), "Detached controls retained animation subscriptions")
	host.add_child(button)
	host.add_child(box)
	expect(game.boil_tick.is_connected(button._on_boil) and game.boil_tick.is_connected(box._on_boil), "Reattached controls did not resume animation")
	host.free()
	print("PASS: zero startup textures, one-frame demand loading, bounded LRU and hidden controls")
	print("RESOURCE_STATS ", JSON.stringify({"items": items.cache_stats(), "sprites": sprites.cache_stats()}))
	quit(1 if failures else 0)
