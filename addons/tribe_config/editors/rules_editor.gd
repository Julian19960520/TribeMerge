@tool
extends "res://addons/tribe_config/editor_base.gd"

func refresh() -> void:
	var box := clear_ui()
	Ui.lbl(box, TextCatalog.source("developer.rules_editor.7586249d7de9"))
	_field(box, "cols", TextCatalog.source("developer.rules_editor.2810f4da3323"), 1, 15)
	_field(box, "rows", TextCatalog.source("developer.rules_editor.b64884b06989"), 1, 20)
	_field(box, "max_energy", TextCatalog.source("developer.rules_editor.4236bdbf02eb"), 1, 9999)
	_field(box, "regen_sec", TextCatalog.source("developer.rules_editor.f4696423ff8e"), 1, 9999)
	_field(box, "random_orders", TextCatalog.source("developer.rules_editor.d97cd9537082"), 0, 12)
	_field(box, "token_step", TextCatalog.source("developer.rules_editor.06a4fb75f6e5"), 1, 999)
	_field(box, "inv_max", TextCatalog.source("developer.rules_editor.73fe6c835d30"), 1, 50)

func _field(box: Node, key: String, label: String, lo: int, hi: int) -> void:
	var r := Ui.row(box)
	Ui.lbl(r, label, 140)
	var s := Ui.spin(r, int(data[key]), lo, hi, 100)
	s.value_changed.connect(_set_num.bind(data, key))

func validate() -> String:
	if int(data["cols"]) < 1 or int(data["rows"]) < 1:
		return TextCatalog.source("developer.rules_editor.bebf9164c67a")
	if int(data["max_energy"]) < 1:
		return TextCatalog.source("developer.rules_editor.db676750d4b5")
	if int(data["regen_sec"]) < 1:
		return TextCatalog.source("developer.rules_editor.9919ed64e879")
	return ""
