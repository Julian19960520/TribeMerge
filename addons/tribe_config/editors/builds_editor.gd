@tool
extends "res://addons/tribe_config/editor_base.gd"

func refresh() -> void:
	var box := clear_ui()
	Ui.lbl(box, "村庄建筑。阶段数是锤子能点多少下。第 1 次是从阶段 0 升级时给的奖励，篝火开局已经是阶段 1。")
	for i in data.size():
		var b: Dictionary = data[i]
		_fit(b)
		var g := Ui.group(box)
		var r := Ui.row(g)
		Ui.lbl(r, "id", 24)
		var id := Ui.line(r, str(b["id"]), 100)
		id.text_changed.connect(_set_field.bind(b, "id"))
		Ui.lbl(r, "名称", 40)
		var nm := Ui.line(r, str(b["name"]), 140)
		nm.text_changed.connect(_set_field.bind(b, "name"))
		Ui.lbl(r, "阶段", 40)
		var st := Ui.spin(r, int(b["stages"]), 1, 30, 70)
		st.value_changed.connect(_on_stages.bind(b))
		Ui.btn(r, "上").pressed.connect(_move_at.bind(data, i, -1))
		Ui.btn(r, "下").pressed.connect(_move_at.bind(data, i, 1))
		Ui.btn(r, "删除").pressed.connect(_remove_at.bind(data, i))
		var rewards: Array = b["rewards"]
		for s in rewards.size():
			Ui.lbl(g, "第 %d 次" % (s + 1))
			reward_list(g, rewards[s])
	Ui.btn(box, "添加建筑").pressed.connect(_add)

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
	var b := {"id": "build_%d" % (data.size() + 1), "name": "新建筑", "stages": 5, "rewards": []}
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
			return "有建筑缺少 id"
		if seen.has(id):
			return "建筑 id 重复：" + id
		seen[id] = true
		_fit(b)
		for step in b["rewards"]:
			for rw in step:
				if str(rw[0]).strip_edges() == "":
					return "%s 有奖励没有物品" % b.get("name", id)
				if int(rw[1]) < 1:
					return "%s 的奖励数量至少是 1" % b.get("name", id)
	return ""
