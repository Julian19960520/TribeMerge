@tool
extends "res://addons/tribe_config/editor_base.gd"

func refresh() -> void:
	var box := clear_ui()
	Ui.lbl(box, "每本卡册正好 9 张。图鉴进度按这个数量算。")
	for i in data.size():
		var a: Dictionary = data[i]
		var g := Ui.group(box)
		var head := Ui.row(g)
		Ui.lbl(head, "册名", 40)
		var nm := Ui.line(head, str(a["name"]))
		nm.text_changed.connect(_set_field.bind(a, "name"))
		Ui.btn(head, "上").pressed.connect(_move_at.bind(data, i, -1))
		Ui.btn(head, "下").pressed.connect(_move_at.bind(data, i, 1))
		Ui.btn(head, "删除").pressed.connect(_remove_at.bind(data, i))
		string_rows(g, a["cards"], "卡牌")
	Ui.btn(box, "添加卡册").pressed.connect(_add)

func _add() -> void:
	data.append({"name": "新卡册", "cards": ["", "", "", "", "", "", "", "", ""]})
	touch()
	rebuild()

func validate() -> String:
	for a in data:
		if str(a.get("name", "")).strip_edges() == "":
			return "有卡册没有名字"
		if a["cards"].size() != 9:
			return "「%s」要正好 9 张，现在 %d 张" % [a["name"], a["cards"].size()]
	return ""
