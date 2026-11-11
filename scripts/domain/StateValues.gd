extends RefCounted
## Identical numeric representation for live values, checkpoints and hash snapshots.
static func number(value: float):
	var snapped := snappedf(value, 0.000001)
	return int(snapped) if snapped == floor(snapped) else snapped

static func copy(value, sorted_keys := false):
	if value is Dictionary:
		var out := {}
		var keys: Array = value.keys()
		if sorted_keys: keys.sort()
		for key in keys: out[str(key)] = copy(value[key], sorted_keys)
		return out
	if value is Array:
		var out := []
		for entry in value: out.append(copy(entry, sorted_keys))
		return out
	return number(value) if value is float else value

static func in_place(value):
	if value is Dictionary:
		for key in value: value[key] = in_place(value[key])
	elif value is Array:
		for index in value.size(): value[index] = in_place(value[index])
	elif value is float:
		return number(value)
	return value
