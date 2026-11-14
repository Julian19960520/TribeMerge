@tool
extends "res://addons/tribe_config/editor_base.gd"

func refresh() -> void:
	var box := clear_ui()
	Ui.lbl(box, TextCatalog.source("developer.builds_editor.54627a242c58"))
	for i in data.size():
		var b: Dictionary = data[i]
		_fit(b)
		var g := Ui.group(box)
		var r := Ui.row(g)
		Ui.lbl(r, TextCatalog.source("developer.builds_editor.a56145270ce6"), 24)
		var id := Ui.line(r, str(b["id"]), 100)
		id.text_changed.connect(_set_field.bind(b, "id"))
		Ui.lbl(r, TextCatalog.source("developer.builds_editor.d44e9b3d3b31"), 40)
		var nm := Ui.line(r, str(b["name"]), 140)
		nm.text_changed.connect(_set_field.bind(b, "name"))
		Ui.lbl(r, TextCatalog.source("developer.builds_editor.59eb8d03efea"), 40)
		var st := Ui.spin(r, int(b["stages"]), 1, 30, 70)
		st.value_changed.connect(_on_stages.bind(b))
		Ui.btn(r, TextCatalog.source("developer.editor_base.db5ba671d244")).pressed.connect(_move_at.bind(data, i, -1))
		Ui.btn(r, TextCatalog.source("developer.editor_base.13c12b064b63")).pressed.connect(_move_at.bind(data, i, 1))
		Ui.btn(r, TextCatalog.source("developer.editor_base.2f9daa828907")).pressed.connect(_remove_at.bind(data, i))
		var rewards: Array = b["rewards"]
		for s in rewards.size():
			Ui.lbl(g, TextCatalog.source("developer.builds_editor.8b89e8795e16") % (s + 1))
			reward_list(g, rewards[s])
	Ui.btn(box, TextCatalog.source("developer.builds_editor.18bf12451adb")).pressed.connect(_add)

func _on_stages(v: Variant, b: Dictionary) -> void:
	b["stages"] = int(v)
	_fit(b)
	touch()
	rebuild()

func _fit(b: Dictionary) -> void:
	var n := clampi(int(b.get("stages", 1)), 1, 30)
	b["stages"] = n
	if not (b.get("rewards") is Array):
		b["rewards"] = []
	var rewards: Array = b["rewards"]
	while rewards.size() < n:
		var st := rewards.size()
		rewards.append([["fire_2", 15 + st * 5], ["amber_1", 1]])
	while rewards.size() > n:
		rewards.pop_back()

func _add() -> void:
	var b := {"id": "build_%d" % (data.size() + 1), "name": TextCatalog.source("developer.builds_editor.d7033c6bb47e"), "stages": 5, "rewards": []}
	_fit(b)
	data.append(b)
	touch()
	rebuild()

func validate() -> String:
	var seen := {}
	for b in data:
		var id := str(b.get("id", "")).strip_edges()
		b["id"] = id
		if id == "":
			return TextCatalog.source("developer.builds_editor.599f855c7963")
		if seen.has(id):
			return TextCatalog.source("developer.builds_editor.53dc3d9f25e0") + id
		seen[id] = true
		_fit(b)
		for step in b["rewards"]:
			for rw in step:
				if str(rw[0]).strip_edges() == "":
					return TextCatalog.source("developer.builds_editor.df7e16d07749") % b.get("name", id)
				if int(rw[1]) < 1:
					return TextCatalog.source("developer.builds_editor.02ef744476a3") % b.get("name", id)
	return ""
