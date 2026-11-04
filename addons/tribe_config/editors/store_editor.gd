@tool
extends "res://addons/tribe_config/editor_base.gd"

func refresh() -> void:
	var box := clear_ui()
	Ui.lbl(box, "集市热卖。物品 id 用链名_等级，例如 fruit_3。价格是琥珀。")
	for i in data.size():
		var it: Dictionary = data[i]
		var r := Ui.row(box)
		Ui.lbl(r, "物品", 40)
		var id := Ui.line(r, str(it["id"]), 120)
		id.text_changed.connect(_set_field.bind(it, "id"))
		Ui.lbl(r, "价格", 40)
		var price := Ui.spin(r, int(it["price"]), 0, 99999, 90)
		price.value_changed.connect(_set_num.bind(it, "price"))
		Ui.lbl(r, "库存", 40)
		var stock := Ui.spin(r, int(it["stock"]), 0, 999, 80)
		stock.value_changed.connect(_set_num.bind(it, "stock"))
		Ui.btn(r, "删除").pressed.connect(_remove_at.bind(data, i))
	Ui.btn(box, "添加商品").pressed.connect(_add)

func _add() -> void:
	data.append({"id": "fruit_1", "price": 1, "stock": 1})
	touch()
	rebuild()

func validate() -> String:
	for it in data:
		if str(it.get("id", "")).strip_edges() == "":
			return "有商品缺少物品 id"
	return ""
