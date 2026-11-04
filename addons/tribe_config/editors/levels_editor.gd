@tool
extends "res://addons/tribe_config/editor_base.gd"

func refresh() -> void:
	var box := clear_ui()
	Ui.lbl(box, "主角升到这一级时发放的奖励。没单独写的更高等级，游戏仍按原来的公式给。")
	if not data.has("levels") or not (data["levels"] is Array):
		data["levels"] = []
	var levels: Array = data["levels"]
	for i in levels.size():
		var lv: Dictionary = levels[i]
		if not (lv.get("rewards") is Array):
			lv["rewards"] = []
		var g := Ui.group(box)
		var head := Ui.row(g)
		Ui.lbl(head, "升到", 40)
		var n := Ui.spin(head, int(lv.get("level", 2)), 1, 99, 80)
		n.value_changed.connect(_set_num.bind(lv, "level"))
		Ui.btn(head, "上").pressed.connect(_move_at.bind(levels, i, -1))
		Ui.btn(head, "下").pressed.connect(_move_at.bind(levels, i, 1))
		Ui.btn(head, "删除").pressed.connect(_remove_at.bind(levels, i))
		reward_list(g, lv["rewards"])
	Ui.btn(box, "添加等级").pressed.connect(_add)

func _add() -> void:
	var levels: Array = data["levels"]
	var n := 2
	for lv in levels:
		n = maxi(n, int(lv.get("level", 1)) + 1)
	levels.append({"level": n, "rewards": Data.default_level_rewards(n)})
	touch()
	rebuild()

func validate() -> String:
	var seen := {}
	for lv in data.get("levels", []):
		var n := int(lv.get("level", 0))
		if n < 1:
			return "主角等级至少是 1"
		if seen.has(n):
			return "主角等级重复：%d" % n
		seen[n] = true
		for rw in lv.get("rewards", []):
			if str(rw[0]).strip_edges() == "":
				return "%d 级有奖励没有物品" % n
			if int(rw[1]) < 1:
				return "%d 级的奖励数量至少是 1" % n
	return ""
