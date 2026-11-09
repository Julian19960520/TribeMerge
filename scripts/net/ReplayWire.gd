extends RefCounted
## TRP1: implicit sequence, delta time, fixed opcodes/fields, shared strings,
## raw hash bytes and varints. Compressed bytes go straight into the HTTP body.
const MIME := "application/x-tribe-replay"
const STRINGS := ["id", "key", "track", "season", "action", "kind"]
const BOOLEANS := ["on", "stage"]
static var _schema: Array = []

static func schema() -> Array:
	if _schema.is_empty():
		_schema = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/net/replay_wire.json"))
	return _schema

static func _integer(v, minimum := 0, maximum := 0x7fffffffffffffff) -> bool:
	if v is float and absf(v) >= 9007199254740992.0: return false
	return (v is int or v is float) and v >= minimum and v <= maximum and v == floor(v)

static func encode(body: Dictionary) -> PackedByteArray:
	var ops: Array = body.get("ops", [])
	if ops.is_empty() or ops.size() > 256 or not _integer(body.get("base")): return PackedByteArray()
	for pair in [["rules", 64], ["hash", 64], ["batch", 32]]:
		var value := str(body.get(pair[0], ""))
		if value.length() != int(pair[1]) or value != value.to_lower() or not value.is_valid_hex_number(false): return PackedByteArray()
	var first = ops[0]
	if not _integer(first.get("seq"), 1) or not _integer(first.get("at")): return PackedByteArray()
	var definitions := schema()
	var names := []
	for row in definitions: names.append(row[0])
	var strings := []
	var indexes := {}
	var previous := int(first["at"])
	for i in ops.size():
		var op: Dictionary = ops[i]
		if not _integer(op.get("seq"), 1) or int(op["seq"]) != int(first["seq"]) + i: return PackedByteArray()
		if not _integer(op.get("at"), previous): return PackedByteArray()
		previous = int(op["at"])
		var code := names.find(str(op.get("name", "")))
		if code < 0: return PackedByteArray()
		var args: Dictionary = op.get("args", {})
		var fields: Array = definitions[code][1]
		for key in args:
			if not fields.has(key): return PackedByteArray()
			var value = args[key]
			if STRINGS.has(key):
				if not value is String or value.to_utf8_buffer().size() > 1024: return PackedByteArray()
				if not indexes.has(value):
					indexes[value] = strings.size(); strings.append(value)
			elif BOOLEANS.has(key):
				if not value is bool: return PackedByteArray()
			elif not _integer(value, -2147483648, 2147483647): return PackedByteArray()
	var out := "TRP1".to_utf8_buffer()
	_put(out, int(body["base"]))
	for key in ["rules", "hash", "batch"]: out.append_array(str(body[key]).hex_decode())
	_put(out, int(first["seq"])); _put(out, int(first["at"])); _put(out, ops.size())
	_put(out, strings.size())
	for value in strings:
		var bytes: PackedByteArray = value.to_utf8_buffer()
		_put(out, bytes.size()); out.append_array(bytes)
	previous = int(first["at"])
	for op in ops:
		_put(out, int(op["at"]) - previous); previous = int(op["at"])
		var code := names.find(str(op["name"]))
		out.append(code)
		var fields: Array = definitions[code][1]
		if fields.is_empty(): continue
		var args: Dictionary = op.get("args", {})
		var mask := 0
		for i in fields.size():
			if args.has(fields[i]): mask |= 1 << i
		_put(out, mask)
		for key in fields:
			if not args.has(key): continue
			if STRINGS.has(key): _put(out, int(indexes[args[key]]))
			elif BOOLEANS.has(key): out.append(1 if args[key] else 0)
			else:
				var n := int(args[key])
				_put(out, n * 2 if n >= 0 else -n * 2 - 1)
	return out

static func _put(bytes: PackedByteArray, n: int) -> void:
	while n >= 128:
		bytes.append((n & 127) | 128); n >>= 7
	bytes.append(n)
