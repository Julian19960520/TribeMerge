@tool
extends "res://addons/tribe_config/editor_base.gd"

func refresh() -> void:
	var box := clear_ui()
	Ui.lbl(box, TextCatalog.source("developer.levels_editor.8f3e470c7cb9"))
	if not data.has("levels") or not (data["levels"] is Array):
		data["levels"] = []
	var levels: Array = data["levels"]
	for i in levels.size():
		var lv: Dictionary = levels[i]
		if not (lv.get("rewards") is Array):
			lv["rewards"] = []
		var g := Ui.group(box)
		var head := Ui.row(g)
		Ui.lbl(head, TextCatalog.source("developer.levels_editor.d5a43ddba325"), 40)
		var n := Ui.spin(head, int(lv.get("level", 2)), 1, 99, 80)
		n.value_changed.connect(_set_num.bind(lv, "level"))
		Ui.btn(head, TextCatalog.source("developer.editor_base.db5ba671d244")).pressed.connect(_move_at.bind(levels, i, -1))
		Ui.btn(head, TextCatalog.source("developer.editor_base.13c12b064b63")).pressed.connect(_move_at.bind(levels, i, 1))
		Ui.btn(head, TextCatalog.source("developer.editor_base.2f9daa828907")).pressed.connect(_remove_at.bind(levels, i))
		reward_list(g, lv["rewards"])
	Ui.btn(box, TextCatalog.source("developer.levels_editor.ef75ff3c4186")).pressed.connect(_add)

func _add() -> void:
	var levels: Array = data["levels"]
	var n := 2
	for lv in levels:
		n = maxi(n, int(lv.get("level", 1)) + 1)
	levels.append({"level": n, "rewards": Data.default_level_rewards(n)})
	touch()
	rebuild()

func validate() -> String:
	var seen := {}
	for lv in data.get("levels", []):
		var n := int(lv.get("level", 0))
		if n < 1:
			return TextCatalog.source("developer.levels_editor.30bb5702b31a")
		if seen.has(n):
			return TextCatalog.source("developer.levels_editor.c5259ed5a980") % n
		seen[n] = true
		for rw in lv.get("rewards", []):
			if str(rw[0]).strip_edges() == "":
				return TextCatalog.source("developer.levels_editor.3efc42eb5606") % n
			if int(rw[1]) < 1:
				return TextCatalog.source("developer.levels_editor.7944311bf46c") % n
			if n < Data.CARD_LEVEL and Data.type_of(str(rw[0])) == "pack":
				return TextCatalog.source("developer.levels_editor.877270788d17") % [Data.CARD_LEVEL, n]
	return ""
