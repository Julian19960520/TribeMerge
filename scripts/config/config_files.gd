@tool
extends RefCounted
## 玩法配置文件。编辑器写入这里，游戏启动时读走。

const LINES := "res://data/lines.json"
const CHAINS := "res://data/chains.json"
const PEOPLE := "res://data/people.json"
const STORY := "res://data/story.json"
const ALBUMS := "res://data/albums.json"
const AMBER := "res://data/amber_packs.json"
const BUILDS := "res://data/builds.json"
const LEVELS := "res://data/levels.json"
const STORE := "res://data/store.json"
const PASS := "res://data/pass.json"
const BOARD := "res://data/board.json"
const RULES := "res://data/rules.json"
const DISHES := "res://data/dishes.json"
const RANDOM_ORDERS := "res://data/random_orders.json"
const UNLOCKS := "res://data/unlocks.json"

## preload 让导出包带上这些 json。编辑器里优先读磁盘，这样刚保存的内容不会被旧导入挡住。
const RES_LINES = preload("res://data/lines.json")
const RES_CHAINS = preload("res://data/chains.json")
const RES_PEOPLE = preload("res://data/people.json")
const RES_STORY = preload("res://data/story.json")
const RES_ALBUMS = preload("res://data/albums.json")
const RES_AMBER = preload("res://data/amber_packs.json")
const RES_BUILDS = preload("res://data/builds.json")
const RES_LEVELS = preload("res://data/levels.json")
const RES_STORE = preload("res://data/store.json")
const RES_PASS = preload("res://data/pass.json")
const RES_BOARD = preload("res://data/board.json")
const RES_RULES = preload("res://data/rules.json")
const RES_DISHES = preload("res://data/dishes.json")
const RES_RANDOM_ORDERS = preload("res://data/random_orders.json")
const RES_UNLOCKS = preload("res://data/unlocks.json")

static func read(path: String) -> Variant:
	if FileAccess.file_exists(path):
		var text := FileAccess.get_file_as_string(path)
		if text != "":
			var parsed = JSON.parse_string(text)
			if parsed != null:
				return ints(parsed)
	var res = _imported(path)
	if res != null and "data" in res and res.data != null:
		return ints(res.data)
	push_error("打不开配置 " + path)
	return null

static func write(path: String, data: Variant) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(data, "\t") + "\n")
	return OK

static func ints(v: Variant) -> Variant:
	if v is float:
		var n := int(v)
		if is_equal_approx(v, float(n)):
			return n
		return v
	if v is Array:
		var a := []
		for x in v:
			a.append(ints(x))
		return a
	if v is Dictionary:
		var d := {}
		for k in v:
			d[k] = ints(v[k])
		return d
	return v

static func _imported(path: String) -> Resource:
	match path:
		LINES:
			return RES_LINES
		CHAINS:
			return RES_CHAINS
		PEOPLE:
			return RES_PEOPLE
		STORY:
			return RES_STORY
		ALBUMS:
			return RES_ALBUMS
		AMBER:
			return RES_AMBER
		BUILDS:
			return RES_BUILDS
		LEVELS:
			return RES_LEVELS
		STORE:
			return RES_STORE
		PASS:
			return RES_PASS
		BOARD:
			return RES_BOARD
		RULES:
			return RES_RULES
		DISHES:
			return RES_DISHES
		RANDOM_ORDERS:
			return RES_RANDOM_ORDERS
		UNLOCKS:
			return RES_UNLOCKS
	return null
