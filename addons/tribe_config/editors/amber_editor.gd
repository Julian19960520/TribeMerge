@tool
extends "res://addons/tribe_config/editor_base.gd"

func refresh() -> void:
	var box := clear_ui()
	Ui.lbl(box, TextCatalog.source("developer.amber_editor.56e02905e038"))
	for i in data.size():
		var a: Dictionary = data[i]
		var r := Ui.row(box)
		Ui.lbl(r, TextCatalog.source("developer.amber_editor.089f621992ac"), 40)
		var n := Ui.spin(r, int(a["n"]), 1, 999999, 110)
		n.value_changed.connect(_set_num.bind(a, "n"))
		Ui.lbl(r, TextCatalog.source("developer.amber_editor.0f4371a7a9cf"), 40)
		var price := Ui.line(r, str(a["price"]), 120)
		price.text_changed.connect(_set_field.bind(a, "price"))
		Ui.btn(r, TextCatalog.source("developer.editor_base.db5ba671d244")).pressed.connect(_move_at.bind(data, i, -1))
		Ui.btn(r, TextCatalog.source("developer.editor_base.13c12b064b63")).pressed.connect(_move_at.bind(data, i, 1))
		Ui.btn(r, TextCatalog.source("developer.editor_base.2f9daa828907")).pressed.connect(_remove_at.bind(data, i))
	Ui.btn(box, TextCatalog.source("developer.amber_editor.5e0169c84b8a")).pressed.connect(_add)

func _add() -> void:
	data.append({"n": 100, "price": "¥6"})
	touch()
	rebuild()
