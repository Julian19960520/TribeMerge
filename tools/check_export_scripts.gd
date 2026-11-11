extends SceneTree
## Run from an empty directory with --main-pack; source scripts cannot mask a
## missing or stale compiled script in the independently exported package.
func _initialize() -> void:
	check.call_deferred()

func check() -> void:
	var manifest_path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--manifest="): manifest_path = argument.trim_prefix("--manifest=")
	if manifest_path == "":
		push_error("Exported-script manifest was not supplied")
		quit(1)
		return
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	var paths: Array = manifest.get("scripts", []) if manifest is Dictionary else []
	if paths.is_empty():
		push_error("Exported-script manifest is empty")
		quit(1)
		return
	for path in paths:
		if not ResourceLoader.exists(str(path), "GDScript"):
			push_error("Export is missing current script: " + str(path))
			quit(1)
			return
		var script = ResourceLoader.load(str(path), "GDScript")
		if not script is GDScript or not script.can_instantiate():
			push_error("Exported script failed to load: " + str(path))
			quit(1)
			return
	for path in manifest["excluded"]:
		if FileAccess.file_exists(str(path)) or ResourceLoader.exists(str(path)):
			push_error("Export contains development resource: " + str(path))
			quit(1)
			return
	print("PASS: %d development resources excluded from package" % manifest["excluded"].size())
	var scene = ResourceLoader.load("res://main.tscn", "PackedScene")
	if not scene is PackedScene:
		push_error("Export is missing its current main scene")
		quit(1)
		return
	print("PASS: %d current compiled scripts and main scene loaded from independent package" % paths.size())
	quit.call_deferred(0)
