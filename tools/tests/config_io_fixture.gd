extends SceneTree
const Files := preload("res://scripts/config/config_files.gd")
var failures := 0
var replacements := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func hashes(paths: Array) -> Dictionary:
	var result := {}
	for path in paths: result[path] = FileAccess.get_sha256(path)
	return result
func write_bytes(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
func reject_second(source: String, target: String) -> Error:
	replacements += 1
	return ERR_FILE_CANT_WRITE if replacements == 2 else DirAccess.rename_absolute(source, target)
func run() -> void:
	check(Files.refresh(), "isolated current configuration is valid")
	var paths := [Files.RULES, Files.BOARD]
	var originals := Files.capture_files(paths)
	var original_hashes := hashes(paths)
	check(originals.size() == 2 and originals[Files.RULES] is PackedByteArray, "capture returns exact byte payloads")
	for path in paths:
		write_bytes(path, ("\n " + originals[path].get_string_from_utf8() + "\n").to_utf8_buffer())
	var modified_hashes := hashes(paths)
	check(modified_hashes != original_hashes, "whitespace-only changes alter the raw rule fingerprints")
	var generation := Files.revision
	check(not Files._restore_files(originals, reject_second), "injected second-file commit failure is reported")
	check(replacements == 2 and hashes(paths) == modified_hashes, "failed multi-file restore rolls back already committed files")
	check(Files.revision == generation, "failed restore does not publish a cache generation")
	var bad := originals.duplicate(true)
	bad[Files.BOARD] = "not raw bytes"
	check(not Files.restore_files(bad) and hashes(paths) == modified_hashes, "invalid late payload rejects the whole restore before writing")
	check(not Files.restore_files({"res://data/../rules.json": originals[Files.RULES]}) and hashes(paths) == modified_hashes, "restore rejects unregistered or noncanonical paths")
	check(Files.capture_files([Files.RULES, "res://data/../rules.json"]).is_empty(), "failed capture does not return a partial backup")
	check(Files.restore_files(originals), "complete raw-byte restore succeeds")
	check(hashes(paths) == original_hashes, "restore preserves exact original SHA including formatting")
	check(Files.revision == generation + 1 and Files.refresh(), "successful restore invalidates once and the original rules validate")
	var rules: Dictionary = Files.read(Files.RULES)
	var board: Dictionary = Files.read(Files.BOARD)
	rules.energy_price += 5
	board.rewards["0"] = ["fire_2", 1]
	var before_write := Files.revision
	check(Files.write_batch({Files.RULES: rules, Files.BOARD: board}) == OK, "validated JSON writes use the byte transaction")
	check(Files.revision == before_write + 1, "batch write publishes exactly one cache generation")
	check(Files.shared(Files.RULES).energy_price == rules.energy_price and Files.shared(Files.BOARD).rewards["0"] == board.rewards["0"], "both JSON changes are committed together")
	var accepted_hashes := hashes(paths)
	board.cells.pop_back()
	check(Files.write_batch({Files.RULES: rules, Files.BOARD: board}) == ERR_INVALID_DATA and hashes(paths) == accepted_hashes, "invalid second JSON edit cannot partially commit the first")
	check(Files.restore_files(originals) and hashes(paths) == original_hashes, "JSON edits still restore the original raw rule bytes")
	var leftovers := []
	for name in DirAccess.get_files_at("res://data"):
		if ".restore-" in name: leftovers.append(name)
	check(leftovers.is_empty(), "successful and rolled-back transactions leave no temporary files")
	quit(0 if failures == 0 else 1)
