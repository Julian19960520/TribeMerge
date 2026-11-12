extends RefCounted
## Replay known pre-24-unlock journals against their original configuration.
const FROM_RULES := "29eedf78ed1787e345ecce0ac5408767793ad0d48b4b9a314e9db230f893f7e1"
const TO_RULES := "abdb072fabf8603a575f3325b536dbe42681bc7f12fb96248ebd2abf689a5e07"
const PREVIOUS_ROWS := {"res://data/lines.json": {"field": "", "key": "id", "rows": [{"id": "fire", "name": "火堆", "gen": "hearth", "main": "veg", "sub": "roast", "unlock": 21}]}, "res://data/levels.json": {"field": "levels", "key": "level", "rows": [{"level": 21, "rewards": [["fire_2", 68], ["chest_1", 1], ["pack_1", 1], ["hearth_4", 1], ["sand_2", 10]]}, {"level": 23, "rewards": [["fire_2", 74], ["chest_1", 1], ["pack_1", 1], ["hearth_4", 1], ["sand_2", 10]]}, {"level": 24, "rewards": [["fire_2", 77], ["chest_1", 1], ["pack_1", 1], ["trap_2", 1], ["amber_3", 5], ["sand_2", 11]]}]}, "res://data/unlocks.json": {"field": "rows", "key": "id", "rows": [{"id": "veg", "open": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]}, {"id": "roast", "open": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]}]}, "res://data/dishes.json": {"field": "", "key": "id", "rows": [{"id": "platter", "name": "果蔬烤盘", "mats": ["fruit_4", "veg_3", "beast_1"], "secs": 2700, "unlock": 21}, {"id": "grill", "name": "海陆双拼烤肉", "mats": ["beast_2", "veg_2", "bird_1"], "secs": 3000, "unlock": 22}, {"id": "skewer", "name": "烤肉串拼盘", "mats": ["roast_3", "veg_4", "seed_2"], "secs": 3600, "unlock": 23}]}, "res://data/story.json": {"field": "levels", "key": "level", "rows": [{"level": 21, "orders": [{"items": ["veg_7", "armor_3"], "rewards": [], "say": "火塘生起来了，烤得真香！", "shell": 464, "who": 0, "xp": 1}, {"items": ["veg_8", "veg_5", "tool_2"], "rewards": ["pack_1"], "say": "火塘边香喷喷的。", "shell": 584, "who": 0, "xp": 1}, {"items": ["beast_4", "veg_4", "fruit_4"], "rewards": [], "say": "阿石叔叔好厉害！", "shell": 96, "who": 3, "xp": 1}, {"items": ["veg_6", "bird_1"], "rewards": [], "say": "热乎的吃了不生病。", "shell": 178, "who": 1, "xp": 1}, {"items": ["tool_7", "beast_3", "veg_3"], "rewards": [], "say": "今天收获不错！", "shell": 288, "who": 2, "xp": 1}, {"items": ["beast_4", "veg_2"], "rewards": [], "say": "够全部落吃三天。", "shell": 40, "who": 0, "xp": 1}, {"items": ["veg_9", "veg_7"], "rewards": [], "say": "烤得真香！", "shell": 1280, "who": 3, "xp": 2, "token": 12}]}, {"level": 22, "orders": [{"items": ["fruit_8", "veg_6"], "rewards": [], "say": "丰收的季节到了。", "shell": 640, "who": 0, "xp": 1}, {"items": ["veg_7", "bird_1"], "rewards": ["pack_1"], "say": "热乎的吃了不生病。", "shell": 306, "who": 1, "xp": 1}, {"items": ["tool_8", "veg_2"], "rewards": [], "say": "磨得真快，能削木头了。", "shell": 520, "who": 2, "xp": 1}, {"items": ["veg_8", "bird_1"], "rewards": [], "say": "火塘边香喷喷的。", "shell": 560, "who": 0, "xp": 1}, {"items": ["cloth_7", "veg_6"], "rewards": [], "say": "新衣服好软！", "shell": 384, "who": 3, "xp": 1}, {"items": ["cloth_8", "veg_5", "cloth_5"], "rewards": [], "say": "冬天不怕冷了。", "shell": 640, "who": 1, "xp": 1}, {"items": ["veg_9", "seed_3"], "rewards": [], "say": "烤得真香！", "shell": 1232, "who": 3, "xp": 2, "token": 13}]}, {"level": 23, "orders": [{"items": ["veg_8", "gem_1"], "rewards": [], "say": "火塘边香喷喷的。", "shell": 564, "who": 0, "xp": 1}, {"items": ["veg_8", "tool_5"], "rewards": ["pack_1"], "say": "热乎的吃了不生病。", "shell": 576, "who": 1, "xp": 1}, {"items": ["beast_4", "veg_4"], "rewards": [], "say": "阿石叔叔好厉害！", "shell": 64, "who": 3, "xp": 1}, {"items": ["beast_3", "veg_3", "gem_3"], "rewards": [], "say": "够全部落吃三天。", "shell": 239, "who": 0, "xp": 1}, {"items": ["veg_7", "fruit_7", "roast_3"], "rewards": [], "say": "烤得真香！", "shell": 720, "who": 3, "xp": 1}, {"items": ["veg_8", "fruit_6", "fruit_5"], "rewards": [], "say": "烤得真香！", "shell": 704, "who": 3, "xp": 1}, {"items": ["veg_9", "veg_2", "gem_2"], "rewards": [], "say": "热乎的吃了不生病。", "shell": 1136, "who": 1, "xp": 2, "token": 13}]}]}}

static func applies(saved_rules: String, current_rules: String, older_rules: Array) -> bool:
	return current_rules == TO_RULES and (saved_rules == FROM_RULES or saved_rules in older_rules)

static func begin() -> Dictionary:
	var current: Dictionary = Data.ConfigFiles._cache
	var previous := current.duplicate()
	for path in PREVIOUS_ROWS:
		var spec: Dictionary = PREVIOUS_ROWS[path]
		var doc: Variant = current[path].duplicate(true)
		var rows: Array = doc if spec["field"] == "" else doc[spec["field"]]
		for i in rows.size():
			for old_row in spec["rows"]:
				if rows[i][spec["key"]] == old_row[spec["key"]]: rows[i] = old_row.duplicate(true)
		Data.ConfigFiles._freeze(doc)
		previous[path] = doc
	Data.ConfigFiles._cache = previous
	Data._load()
	return current

static func finish(current: Dictionary) -> void:
	Data.ConfigFiles._cache = current
	Data._load()
