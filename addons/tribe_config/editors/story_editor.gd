@tool
extends "res://addons/tribe_config/editor_base.gd"

const Files := preload("res://scripts/config/config_files.gd")

func refresh() -> void:
	var box := clear_ui()
	var people := _people()
	for li in data["levels"].size():
		var lv: Dictionary = data["levels"][li]
		var g := Ui.group(box)
		var head := Ui.row(g)
		Ui.lbl(head, TextCatalog.source("developer.story_editor.34243df4d613"), 72)
		var sp := Ui.spin(head, int(lv["level"]), 1, 99, 80)
		sp.value_changed.connect(_set_num.bind(lv, "level"))
		Ui.btn(head, TextCatalog.source("developer.editor_base.db5ba671d244")).pressed.connect(_move_at.bind(data["levels"], li, -1))
		Ui.btn(head, TextCatalog.source("developer.editor_base.13c12b064b63")).pressed.connect(_move_at.bind(data["levels"], li, 1))
		Ui.btn(head, TextCatalog.source("developer.story_editor.bd5e14852e49")).pressed.connect(_remove_at.bind(data["levels"], li))
		for oi in lv["orders"].size():
			var o: Dictionary = lv["orders"][oi]
			var r := Ui.row(g)
			Ui.lbl(r, TextCatalog.fill(TextCatalog.source("developer.story_editor.de16c9bfd599"), (oi + 1)), 64)
			_who(r, o, people)
			Ui.lbl(r, TextCatalog.source("developer.story_editor.22cc9072ab1e"), 40)
			var xp := Ui.spin(r, int(o["xp"]), 0, 999, 70)
			xp.value_changed.connect(_set_num.bind(o, "xp"))
			Ui.lbl(r, TextCatalog.source("developer.story_editor.22536fcb6a75"), 40)
			var shell := Ui.spin(r, int(o["shell"]), 0, 9999, 80)
			shell.value_changed.connect(_set_num.bind(o, "shell"))
			Ui.lbl(r, TextCatalog.source("developer.story_editor.0b87ebe91204"), 24)
			var token := Ui.spin(r, int(o.get("token", 0)), 0, 99, 70)
			token.value_changed.connect(_set_opt.bind(o, "token"))
			Ui.btn(r, TextCatalog.source("developer.editor_base.2f9daa828907")).pressed.connect(_remove_at.bind(lv["orders"], oi))
			_ensure_rewards(o)
			string_rows(g, o["rewards"], TextCatalog.source("developer.story_editor.a21911780672"))
			string_rows(g, o["items"], TextCatalog.source("developer.store_editor.7c89d6ebe1f9"))
		Ui.btn(g, TextCatalog.source("developer.story_editor.1efd44d36eda")).pressed.connect(_add_order.bind(lv))
	Ui.btn(box, TextCatalog.source("developer.levels_editor.ef75ff3c4186")).pressed.connect(_add_level)

func _who(parent: Node, o: Dictionary, people: Array) -> void:
	if people.is_empty():
		var who := Ui.spin(parent, int(o["who"]), 0, 20, 70)
		who.value_changed.connect(_set_num.bind(o, "who"))
		return
	var labels := PackedStringArray()
	for p in people:
		labels.append(str(p))
	var idx := clampi(int(o["who"]), 0, labels.size() - 1)
	var opt := Ui.option(parent, labels, idx, 160)
	opt.item_selected.connect(_set_num.bind(o, "who"))

func _people() -> Array:
	if host != null and host.pages.has(Files.PEOPLE) and host.pages[Files.PEOPLE] is Array:
		return host.pages[Files.PEOPLE]
	var loaded = Files.read(Files.PEOPLE)
	return loaded if loaded is Array else []

func _ensure_rewards(o: Dictionary) -> void:
	if o.has("rewards") and o["rewards"] is Array:
		o.erase("pack")
		return
	var rewards: Array = []
	for _i in int(o.get("pack", 0)):
		rewards.append("pack_1")
	o["rewards"] = rewards
	o.erase("pack")

func _set_opt(v: Variant, o: Dictionary, key: String) -> void:
	if int(v) <= 0:
		o.erase(key)
	else:
		o[key] = int(v)
	touch()

func _add_order(lv: Dictionary) -> void:
	lv["orders"].append({"who": 0, "items": ["fruit_2"], "xp": 1, "shell": 1, "rewards": []})
	touch()
	rebuild()

func _add_level() -> void:
	var n := 1
	for lv in data["levels"]:
		n = maxi(n, int(lv["level"]) + 1)
	data["levels"].append({"level": n, "orders": []})
	touch()
	rebuild()

func validate() -> String:
	var seen := {}
	for lv in data["levels"]:
		var n := int(lv["level"])
		if seen.has(n):
			return TextCatalog.fill(TextCatalog.source("developer.levels_editor.c5259ed5a980"), n)
		seen[n] = true
		for o in lv["orders"]:
			if o["items"].is_empty():
				return TextCatalog.fill(TextCatalog.source("developer.story_editor.0bdf0264fde8"), n)
	return ""
