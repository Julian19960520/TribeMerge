@tool
extends "res://addons/tribe_config/editor_base.gd"

func refresh() -> void:
	var box := clear_ui()
	Ui.lbl(box, "丰收通行证。每一档单独填积分，后面的要比前面多。奖励是物品 id 和数量。")
	for i in data["levels"].size():
		var lv: Dictionary = data["levels"][i]
		var g := Ui.group(box)
		var head := Ui.row(g)
		Ui.lbl(head, "第 %d 档" % (i + 1), 72)
		Ui.lbl(head, "积分", 40)
		var need := Ui.spin(head, int(lv.get("need", 8)), 1, 9999, 90)
		need.value_changed.connect(_set_num.bind(lv, "need"))
		Ui.btn(head, "上").pressed.connect(_move_at.bind(data["levels"], i, -1))
		Ui.btn(head, "下").pressed.connect(_move_at.bind(data["levels"], i, 1))
		Ui.btn(head, "删除").pressed.connect(_remove_at.bind(data["levels"], i))
		_rewards(g, lv, "free", "免费")
		_rewards(g, lv, "prem", "付费")
	Ui.btn(box, "添加一档").pressed.connect(_add_level)

func _rewards(parent: Node, lv: Dictionary, key: String, title: String) -> void:
	Ui.lbl(parent, title)
	var items: Array = lv[key]
	for i in items.size():
		var rw: Array = items[i]
		var r := Ui.row(parent)
		var id := Ui.line(r, str(rw[0]), 140)
		id.text_changed.connect(_set_reward_id.bind(rw))
		var n := Ui.spin(r, int(rw[1]), 1, 9999, 90)
		n.value_changed.connect(_set_reward_n.bind(rw))
		Ui.btn(r, "删除").pressed.connect(_remove_at.bind(items, i))
	Ui.btn(parent, "添加" + title).pressed.connect(_add_reward.bind(items))

func _set_reward_id(text: String, rw: Array) -> void:
	rw[0] = text
	touch()

func _set_reward_n(v: Variant, rw: Array) -> void:
	rw[1] = int(v)
	touch()

func _add_reward(items: Array) -> void:
	items.append(["fruit_1", 1])
	touch()
	rebuild()

func _add_level() -> void:
	var levels: Array = data["levels"]
	levels.append({"need": _next_need(levels), "free": [], "prem": []})
	touch()
	rebuild()

func _next_need(levels: Array) -> int:
	if levels.is_empty():
		return 8
	return int(levels.back().get("need", 8)) + levels.size() + 1

func validate() -> String:
	var prev := 0
	var i := 0
	for lv in data["levels"]:
		i += 1
		var need := int(lv.get("need", 0))
		if need < 1:
			return "第 %d 档积分至少是 1" % i
		if need <= prev:
			return "第 %d 档积分要比上一档多" % i
		prev = need
		for key in ["free", "prem"]:
			for rw in lv[key]:
				if str(rw[0]).strip_edges() == "":
					return "有奖励没有物品 id"
				if int(rw[1]) < 1:
					return "奖励数量至少是 1"
	return ""
