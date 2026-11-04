@tool
extends "res://addons/tribe_config/editor_base.gd"

func refresh() -> void:
	var box := clear_ui()
	Ui.lbl(box, "琥珀充值档。价格是展示用的文字。")
	for i in data.size():
		var a: Dictionary = data[i]
		var r := Ui.row(box)
		Ui.lbl(r, "琥珀", 40)
		var n := Ui.spin(r, int(a["n"]), 1, 999999, 110)
		n.value_changed.connect(_set_num.bind(a, "n"))
		Ui.lbl(r, "价格", 40)
		var price := Ui.line(r, str(a["price"]), 120)
		price.text_changed.connect(_set_field.bind(a, "price"))
		Ui.btn(r, "上").pressed.connect(_move_at.bind(data, i, -1))
		Ui.btn(r, "下").pressed.connect(_move_at.bind(data, i, 1))
		Ui.btn(r, "删除").pressed.connect(_remove_at.bind(data, i))
	Ui.btn(box, "添加一档").pressed.connect(_add)

func _add() -> void:
	data.append({"n": 100, "price": "¥6"})
	touch()
	rebuild()
