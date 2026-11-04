@tool
extends "res://addons/tribe_config/editor_base.gd"

func refresh() -> void:
	var box := clear_ui()
	Ui.lbl(box, "一条产线 = 生产器链 + 主产物链 + 副产物链。哪一级能生产写在生产器自己身上，没配就是不能点。开放等级是主角等级。勾上冷却后，储量用光要等回满。")
	for i in data.size():
		var line: Dictionary = data[i]
		var g := Ui.group(box)
		var r := Ui.row(g)
		Ui.lbl(r, "id", 28)
		var id := Ui.line(r, str(line["id"]), 100)
		id.text_changed.connect(_set_field.bind(line, "id"))
		Ui.lbl(r, "名称", 40)
		var nm := Ui.line(r, str(line["name"]), 120)
		nm.text_changed.connect(_set_field.bind(line, "name"))
		Ui.btn(r, "上").pressed.connect(_move_at.bind(data, i, -1))
		Ui.btn(r, "下").pressed.connect(_move_at.bind(data, i, 1))
		Ui.btn(r, "删除").pressed.connect(_remove_at.bind(data, i))
		var r2 := Ui.row(g)
		Ui.lbl(r2, "生产器", 56)
		var gen := Ui.line(r2, str(line["gen"]), 100)
		gen.text_changed.connect(_set_field.bind(line, "gen"))
		Ui.lbl(r2, "主产物", 56)
		var main := Ui.line(r2, str(line["main"]), 100)
		main.text_changed.connect(_set_field.bind(line, "main"))
		Ui.lbl(r2, "副产物", 56)
		var sub := Ui.line(r2, str(line["sub"]), 100)
		sub.text_changed.connect(_set_field.bind(line, "sub"))
		var r3 := Ui.row(g)
		line.erase("idle")
		Ui.lbl(r3, "开放", 40)
		var unlock := Ui.spin(r3, int(line["unlock"]), 1, 99, 70)
		unlock.value_changed.connect(_set_num.bind(line, "unlock"))
		var cd := Ui.check(r3, bool(line.get("cooldown", false)), "冷却")
		cd.toggled.connect(_set_cd.bind(line))
	Ui.btn(box, "添加产线").pressed.connect(_add_line)

func _set_cd(on: bool, line: Dictionary) -> void:
	if on:
		line["cooldown"] = true
	else:
		line.erase("cooldown")
	touch()

func _add_line() -> void:
	data.append({
		"id": "line_%d" % (data.size() + 1),
		"name": "新产线",
		"gen": "",
		"main": "",
		"sub": "",
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
			return "有产线缺少 id"
		if seen.has(id):
			return "产线 id 重复：" + id
		seen[id] = true
	return ""
