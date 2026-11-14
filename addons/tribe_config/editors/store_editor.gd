@tool
extends "res://addons/tribe_config/editor_base.gd"

func refresh() -> void:
	var box := clear_ui()
	Ui.lbl(box, TextCatalog.source("developer.store_editor.f4aa3f403dd0"))
	for i in data.size():
		var it: Dictionary = data[i]
		var r := Ui.row(box)
		Ui.lbl(r, TextCatalog.source("developer.store_editor.7c89d6ebe1f9"), 40)
		var id := Ui.line(r, str(it["id"]), 120)
		id.text_changed.connect(_set_field.bind(it, "id"))
		Ui.lbl(r, TextCatalog.source("developer.amber_editor.0f4371a7a9cf"), 40)
		var price := Ui.spin(r, int(it["price"]), 0, 99999, 90)
		price.value_changed.connect(_set_num.bind(it, "price"))
		Ui.lbl(r, TextCatalog.source("developer.store_editor.780c5fd5b105"), 40)
		var stock := Ui.spin(r, int(it["stock"]), 0, 999, 80)
		stock.value_changed.connect(_set_num.bind(it, "stock"))
		Ui.btn(r, TextCatalog.source("developer.editor_base.2f9daa828907")).pressed.connect(_remove_at.bind(data, i))
	Ui.btn(box, TextCatalog.source("developer.store_editor.bb3c6134b70f")).pressed.connect(_add)

func _add() -> void:
	data.append({"id": "fruit_1", "price": 1, "stock": 1})
	touch()
	rebuild()

func validate() -> String:
	for it in data:
		if str(it.get("id", "")).strip_edges() == "":
			return TextCatalog.source("developer.store_editor.d9852d9fd665")
	return ""
