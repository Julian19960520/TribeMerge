extends RefCounted
## Flush a complete replacement before atomically replacing the previous checkpoint.
static func write_json(path: String, value: Dictionary) -> Error:
	var error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if error != OK: return error
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(value))
	file.flush()
	error = file.get_error()
	file.close()
	if error != OK: return error
	return DirAccess.rename_absolute(temporary, path)
