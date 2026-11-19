@tool
extends "res://addons/tribe_config/editor_base.gd"

func refresh() -> void:
	var box := clear_ui()
	Ui.lbl(box, TextCatalog.source("developer.albums_editor.2a848bd74138"))
	for i in data.size():
		var a: Dictionary = data[i]
		var g := Ui.group(box)
		var head := Ui.row(g)
		Ui.lbl(head, TextCatalog.source("developer.albums_editor.0f23b37ed205"), 40)
		var nm := Ui.line(head, str(a["name"]))
		nm.text_changed.connect(_set_field.bind(a, "name"))
		Ui.btn(head, TextCatalog.source("developer.editor_base.db5ba671d244")).pressed.connect(_move_at.bind(data, i, -1))
		Ui.btn(head, TextCatalog.source("developer.editor_base.13c12b064b63")).pressed.connect(_move_at.bind(data, i, 1))
		Ui.btn(head, TextCatalog.source("developer.editor_base.2f9daa828907")).pressed.connect(_remove_at.bind(data, i))
		string_rows(g, a["cards"], TextCatalog.source("developer.albums_editor.bde12dd10076"))
	Ui.btn(box, TextCatalog.source("developer.albums_editor.2e5e95464724")).pressed.connect(_add)

func _add() -> void:
	data.append({"name": TextCatalog.source("developer.albums_editor.f79b3be245ae"), "cards": ["", "", "", "", "", "", "", "", ""]})
	touch()
	rebuild()

func validate() -> String:
	for a in data:
		if str(a.get("name", "")).strip_edges() == "":
			return TextCatalog.source("developer.albums_editor.c947d38e8923")
		if a["cards"].size() != 9:
			return TextCatalog.fill(TextCatalog.source("developer.albums_editor.a4e8336112c5"), [a["name"], a["cards"].size()])
	return ""
