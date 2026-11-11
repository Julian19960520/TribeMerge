@tool
extends RefCounted
## Current board configuration: explicit locks, dictionary rewards keyed by cell index.
static func lock_at(col: int, row: int, cols: int, rows: int) -> int:
	return 0 if row == rows / 2 and col in [cols / 2, cols / 2 + 1] else 2

static func lock_of(locks: Array, index: int, _col: int, _row: int, _cols: int, _rows: int) -> int:
	return int(locks[index])

static func ensure(locks: Array, index: int, cols: int, rows: int) -> void:
	if cols < 1 or rows < 1 or index < 0 or index >= cols * rows: return
	while locks.size() <= index:
		var cell := locks.size()
		locks.append(lock_at(cell % cols, cell / cols, cols, rows))

static func parse_reward(raw: Variant) -> Array:
	if not raw is Array or raw.size() != 2 or not raw[0] is String or int(raw[1]) < 1: return []
	return [raw[0], int(raw[1])]

static func rewards_map(raw: Variant) -> Dictionary:
	return raw.duplicate(true) if raw is Dictionary else {}

static func reward_of(rewards: Dictionary, index: int) -> Array:
	return parse_reward(rewards[str(index)]) if rewards.has(str(index)) else []

static func normalize_rewards(board: Dictionary, cols: int, rows: int) -> bool:
	if cols < 1 or rows < 1: return false
	var original: Dictionary = board.get("rewards", {})
	var result := {}
	var indices: Array = original.keys()
	indices.sort_custom(func(a, b): return int(a) < int(b))
	for key in indices:
		if str(key).is_valid_int() and int(key) >= 0 and int(key) < cols * rows:
			var reward := parse_reward(original[key])
			if not reward.is_empty(): result[str(int(key))] = reward
	var changed: bool = not board.has("rewards") or result != original
	board["rewards"] = result
	return changed

static func normalize(board: Dictionary, cols: int, rows: int) -> bool:
	if cols < 1 or rows < 1: return false
	var original: Array = board.get("locks", [])
	var locks := []
	for index in cols * rows:
		locks.append(clampi(int(original[index]), 0, 2) if index < original.size() else lock_at(index % cols, index / cols, cols, rows))
	var changed: bool = not board.has("locks") or locks != original
	board["locks"] = locks
	return changed
