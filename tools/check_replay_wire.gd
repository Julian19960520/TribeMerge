extends SceneTree
const Wire := preload("res://scripts/net/ReplayWire.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var input := ""; var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--input="): input = arg.trim_prefix("--input=")
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	var samples: Array = JSON.parse_string(FileAccess.get_file_as_string(input))
	var results := []
	for sample in samples:
		var raw := Wire.encode(sample)
		var compressed := raw.compress(FileAccess.COMPRESSION_GZIP) if not raw.is_empty() else PackedByteArray()
		results.append({"ok": not raw.is_empty(), "raw": Marshalls.raw_to_base64(raw),
			"gzip": Marshalls.raw_to_base64(compressed), "json_bytes": JSON.stringify(sample).to_utf8_buffer().size(),
			"compact_bytes": raw.size(), "gzip_bytes": compressed.size()})
	var f := FileAccess.open(output, FileAccess.WRITE)
	f.store_string(JSON.stringify(results)); f.close()
	quit(0)
