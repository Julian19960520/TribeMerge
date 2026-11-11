extends RefCounted
## Crash-safe checkpoints and a checksummed append-only command journal.
## A new generation makes an old journal harmless after checkpoint replacement.

const AtomicFile := preload("res://scripts/storage/AtomicFile.gd")

static func write_checkpoint(path: String, state: Dictionary) -> Error:
	return AtomicFile.write_json(path, state)

static func append(path: String, generation: String, operation: Dictionary) -> Error:
	var file := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE_READ)
	if file == null: return FileAccess.get_open_error()
	var payload := JSON.stringify({"generation": generation, "op": operation})
	file.seek_end()
	file.store_line(JSON.stringify({"payload": payload, "checksum": payload.sha256_text()}))
	file.flush()
	var error := file.get_error()
	file.close()
	return error

static func rotate(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null: file.close()

static func read(path: String, generation: String, after_seq: int) -> Dictionary:
	var result := {"ops": [], "error": "", "truncated_tail": false}
	if not FileAccess.file_exists(path): return result
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		result["error"] = "无法读取本地操作日志"
		return result
	var expected := after_seq + 1
	while file.get_position() < file.get_length():
		var line := file.get_line()
		var envelope = _parse(line)
		var payload := str(envelope.get("payload", "")) if envelope is Dictionary else ""
		if payload == "" or str(envelope.get("checksum", "")) != payload.sha256_text():
			if file.get_position() >= file.get_length(): result["truncated_tail"] = true
			else: result["error"] = "本地操作日志校验失败，已保留最后完整操作"
			break
		var record = _parse(payload)
		if not record is Dictionary or not record.get("op") is Dictionary:
			result["error"] = "本地操作日志格式错误"
			break
		if str(record.get("generation", "")) != generation: continue
		var operation: Dictionary = record["op"]
		var sequence := int(operation.get("seq", -1))
		if sequence <= after_seq: continue
		if sequence != expected:
			result["error"] = "本地操作日志序号不连续"
			break
		if not operation.has_all(["at", "name", "args", "hash"]) or not operation["args"] is Dictionary:
			result["error"] = "本地操作日志缺少字段"
			break
		result["ops"].append(operation)
		expected += 1
	file.close()
	return result

static func _parse(text: String):
	var parser := JSON.new()
	return parser.data if parser.parse(text) == OK else null
