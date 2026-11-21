@tool
extends "res://addons/tribe_config/editor_base.gd"

func refresh() -> void:
	var box := clear_ui()
	Ui.lbl(box, TextCatalog.source("developer.lines_editor.821dc5ee6c54"))
	for i in data.size():
		var line: Dictionary = data[i]
		var g := Ui.group(box)
		var r := Ui.row(g)
		Ui.lbl(r, TextCatalog.source("developer.builds_editor.a56145270ce6"), 28)
		var id := Ui.line(r, str(line["id"]), 100)
		id.text_changed.connect(_set_field.bind(line, "id"))
		Ui.lbl(r, TextCatalog.source("developer.builds_editor.d44e9b3d3b31"), 40)
		var nm := Ui.line(r, str(line["name"]), 120)
		nm.text_changed.connect(_set_field.bind(line, "name"))
		Ui.btn(r, TextCatalog.source("developer.editor_base.db5ba671d244")).pressed.connect(_move_at.bind(data, i, -1))
		Ui.btn(r, TextCatalog.source("developer.editor_base.13c12b064b63")).pressed.connect(_move_at.bind(data, i, 1))
		Ui.btn(r, TextCatalog.source("developer.editor_base.2f9daa828907")).pressed.connect(_remove_at.bind(data, i))
		var r2 := Ui.row(g)
		Ui.lbl(r2, TextCatalog.source("developer.lines_editor.bb7813711819"), 56)
		var gen := Ui.line(r2, str(line["gen"]), 100)
		gen.text_changed.connect(_set_field.bind(line, "gen"))
		Ui.lbl(r2, TextCatalog.source("developer.lines_editor.b8666991bd1c"), 120)
		var prods := Ui.line(r2, ", ".join(PackedStringArray(Data.products(line))), 220)
		prods.text_changed.connect(_set_products.bind(line))
		var r3 := Ui.row(g)
		line.erase("idle")
		Ui.lbl(r3, TextCatalog.source("developer.board_editor.c14c915da5fb"), 40)
		var unlock := Ui.spin(r3, int(line["unlock"]), 1, 99, 70)
		unlock.value_changed.connect(_set_num.bind(line, "unlock"))
		var cd := Ui.check(r3, bool(line.get("cooldown", false)), TextCatalog.source("developer.lines_editor.6cac16b39789"))
		cd.toggled.connect(_set_cd.bind(line))
	Ui.btn(box, TextCatalog.source("developer.lines_editor.537f9fc1679b")).pressed.connect(_add_line)

## 产物链写成一个列表；主力产物由生产器的掉率决定，不在这里配
func _set_products(text: String, line: Dictionary) -> void:
	var out: Array = []
	for part in text.split(","):
		if part.strip_edges() != "":
			out.append(part.strip_edges())
	line["products"] = out
	line.erase("main")
	line.erase("sub")
	touch()

func _set_cd(on: bool, line: Dictionary) -> void:
	if on:
		line["cooldown"] = true
	else:
		line.erase("cooldown")
	touch()

func _add_line() -> void:
	data.append({
		"id": "line_%d" % (data.size() + 1),
		"name": TextCatalog.source("developer.lines_editor.1b0ae7a1c59f"),
		"gen": "",
		"products": [],
		"unlock": 1,
	})
	touch()
	rebuild()

func validate() -> String:
	var seen := {}
	for line in data:
		var id := str(line.get("id", "")).strip_edges()
		line["id"] = id
		if id == "":
			return TextCatalog.source("developer.lines_editor.1a087cbcb7dc")
		if seen.has(id):
			return TextCatalog.source("developer.lines_editor.73b411659aee") + id
		seen[id] = true
	return ""
