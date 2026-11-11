extends SceneTree
## Compatibility entry point: crops and cached frames use approved paintings.
## Use --python=/path/to/python when Pillow is in a dedicated environment.

func _initialize() -> void:
	var python := "python" if OS.get_name() == "Windows" else "python3"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--python="): python = argument.trim_prefix("--python=")
	var output: Array = []
	var result := OS.execute(python, PackedStringArray([
		ProjectSettings.globalize_path("res://tools/bake_character_sprites.py")]), output, true)
	for line in output: print(line)
	quit(result)
