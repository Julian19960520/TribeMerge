@tool
extends EditorExportPlugin

func _get_name() -> String:
	return "TribeItemFrames"

func _export_begin(_features: PackedStringArray, _debug: bool, _path: String, _flags: int) -> void:
	# These PNGs deliberately bypass Godot's texture importer. ItemAnim reads
	# their original bytes, so include them explicitly even under .gdignore.
	var manifest_path := "res://assets/items/anim.json"
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	add_file(manifest_path, FileAccess.get_file_as_bytes(manifest_path), false)
	for id in manifest["ids"]:
		for rim in [0, 1]:
			for frame in int(manifest["frames"]):
				var file := "res://assets/items/png/%s_r%d_%d.png" % [id, rim, frame]
				var bytes := FileAccess.get_file_as_bytes(file)
				if bytes.is_empty():
					push_error("Missing item frame: " + file)
					continue
				add_file(file, bytes, false)
