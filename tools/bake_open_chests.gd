extends SceneTree
## Record existing procedural art as vectors for the paired headless Python bake.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	for node in root.get_children(): node.set_process(false)
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
	assert(out != "")
	DirAccess.make_dir_recursive_absolute(out)
	var art := GDScript.new()
	art.source_code = FileAccess.get_file_as_string("res://scripts/Art.gd").replace("class_name Art\n", "").replace("ci: CanvasItem", "ci")
	assert(art.reload() == OK)
	var recorder = load("res://tools/SvgRecorder.gd")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/items/anim.json"))
	var count := 0
	for chain in Data.CHAINS:
		if str(Data.CHAINS[chain]["type"]) != "chest": continue
		for lv in Data.max_lv(chain):
			var id := "%s_%d_open" % [chain, lv + 1]
			for rim in [0, 1]:
				for frame in int(manifest["frames"]):
					art.boil = frame
					art.wobble = float(manifest["amplitude"])
					var draw = recorder.new()
					art.draw_item(draw, id, Vector2.ONE * float(manifest["px"]) * 0.5, float(manifest["bake_size"]), bool(rim))
					var file := FileAccess.open(out.path_join("%s_r%d_%d.svg" % [id, rim, frame]), FileAccess.WRITE)
					file.store_string(draw.svg(int(manifest["px"]))); file.close()
			count += 1
	print("BAKED %d opened chest variants" % count)
	quit()
