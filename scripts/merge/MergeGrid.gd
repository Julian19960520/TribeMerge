class_name MergeGrid
extends RefCounted
## Shared, presentation-free grid rules used by the main board and seasonal boards.
static func neighbors(i: int, cols: int, count: int) -> Array:
	var out: Array = []
	for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var x: int = i % cols + offset.x
		var y: int = i / cols + offset.y
		var k := y * cols + x
		if x >= 0 and x < cols and y >= 0 and k < count: out.append(k)
	return out

## One merge reveals only covered orthogonal neighbors. A revealed item stays locked.
static func reveal_neighbors(cells: Array, at: int, cols: int) -> Array:
	var revealed: Array = []
	for k in neighbors(at, cols, cells.size()):
		if int(cells[k]["lock"]) != 2: continue
		cells[k]["lock"] = 0 if str(cells[k]["id"]) == "" else 1
		revealed.append(k)
	return revealed

static func cell_at(p: Vector2, cell: float, cols: int, rows: int) -> int:
	if p.x < 0 or p.y < 0 or p.x >= cols * cell or p.y >= rows * cell: return -1
	return int(p.y / cell) * cols + int(p.x / cell)

static func nearest_empty(cells: Array, cols: int, origin: int, allowed: Callable = Callable()) -> int:
	var best := -1
	var distance := INF
	var start := Vector2(origin % cols, origin / cols)
	for k in cells.size():
		var c: Dictionary = cells[k]
		if str(c.get("id", "")) != "" or int(c.get("lock", 0)) != 0 or c.get("ck") is Dictionary: continue
		if allowed.is_valid() and not allowed.call(k): continue
		var d := start.distance_squared_to(Vector2(k % cols, k / cols)) + k * 0.0001
		if d < distance:
			distance = d
			best = k
	return best

static func drop_kind(cells: Array, a: int, b: int, next_id: Callable) -> String:
	if a < 0 or b < 0 or a >= cells.size() or b >= cells.size() or a == b: return ""
	var ca: Dictionary = cells[a]
	var cb: Dictionary = cells[b]
	var id := str(ca.get("id", ""))
	if id == "" or int(ca.get("lock", 0)) != 0 or int(cb.get("lock", 0)) >= 2: return ""
	if id == str(cb.get("id", "")) and str(next_id.call(id)) != "": return "merge"
	if int(cb.get("lock", 0)) != 0: return ""
	return "move" if str(cb.get("id", "")) == "" else "swap"

static func apply_drop(cells: Array, a: int, b: int, result: String, next_id: Callable) -> void:
	if result == "merge":
		cells[b]["id"] = str(next_id.call(str(cells[a]["id"])))
		cells[b]["lock"] = 0
		cells[a]["id"] = ""
	elif result in ["move", "swap"]:
		var id: String = cells[a]["id"]
		cells[a]["id"] = cells[b]["id"]
		cells[b]["id"] = id

static func ease_back(t: float) -> float:
	return 1.0 + 2.70158 * pow(t - 1.0, 3.0) + 1.70158 * pow(t - 1.0, 2.0)
