@tool
extends "res://addons/tribe_config/editor_base.gd"

const Files := preload("res://scripts/config/config_files.gd")

func refresh() -> void:
	var box := clear_ui()
	var people := _people()
	for li in data["levels"].size():
		var lv: Dictionary = data["levels"][li]
		var g := Ui.group(box)
		var head := Ui.row(g)
		Ui.lbl(head, "主角等级", 72)
		var sp := Ui.spin(head, int(lv["level"]), 1, 99, 80)
		sp.value_changed.connect(_set_num.bind(lv, "level"))
		Ui.btn(head, "上").pressed.connect(_move_at.bind(data["levels"], li, -1))
		Ui.btn(head, "下").pressed.connect(_move_at.bind(data["levels"], li, 1))
		Ui.btn(head, "删除这一级").pressed.connect(_remove_at.bind(data["levels"], li))
		for oi in lv["orders"].size():
			var o: Dictionary = lv["orders"][oi]
			var r := Ui.row(g)
			Ui.lbl(r, "订单 %d" % (oi + 1), 64)
			_who(r, o, people)
			Ui.lbl(r, "声望", 40)
			var xp := Ui.spin(r, int(o["xp"]), 0, 999, 70)
			xp.value_changed.connect(_set_num.bind(o, "xp"))
			Ui.lbl(r, "贝币", 40)
			var shell := Ui.spin(r, int(o["shell"]), 0, 9999, 80)
			shell.value_changed.connect(_set_num.bind(o, "shell"))
			Ui.lbl(r, "鼓", 24)
			var token := Ui.spin(r, int(o.get("token", 0)), 0, 99, 70)
			token.value_changed.connect(_set_opt.bind(o, "token"))
			Ui.btn(r, "删除").pressed.connect(_remove_at.bind(lv["orders"], oi))
			_ensure_rewards(o)
			string_rows(g, o["rewards"], "奖励")
			string_rows(g, o["items"], "物品")
		Ui.btn(g, "添加订单").pressed.connect(_add_order.bind(lv))
	Ui.btn(box, "添加等级").pressed.connect(_add_level)

func _who(parent: Node, o: Dictionary, people: Array) -> void:
	if people.is_empty():
		var who := Ui.spin(parent, int(o["who"]), 0, 20, 70)
		who.value_changed.connect(_set_num.bind(o, "who"))
		return
	var labels := PackedStringArray()
	for p in people:
		labels.append(str(p))
	var idx := clampi(int(o["who"]), 0, labels.size() - 1)
	var opt := Ui.option(parent, labels, idx, 160)
	opt.item_selected.connect(_set_num.bind(o, "who"))

func _people() -> Array:
	if host != null and host.pages.has(Files.PEOPLE) and host.pages[Files.PEOPLE] is Array:
		return host.pages[Files.PEOPLE]
	var loaded = Files.read(Files.PEOPLE)
	return loaded if loaded is Array else []

func _ensure_rewards(o: Dictionary) -> void:
	if o.has("rewards") and o["rewards"] is Array:
		o.erase("pack")
		return
	var rewards: Array = []
	for _i in int(o.get("pack", 0)):
		rewards.append("pack_1")
	o["rewards"] = rewards
	o.erase("pack")

func _set_opt(v: Variant, o: Dictionary, key: String) -> void:
	if int(v) <= 0:
		o.erase(key)
	else:
		o[key] = int(v)
	touch()

func _add_order(lv: Dictionary) -> void:
	lv["orders"].append({"who": 0, "items": ["fruit_2"], "xp": 1, "shell": 1, "rewards": []})
	touch()
	rebuild()

func _add_level() -> void:
	var n := 1
	for lv in data["levels"]:
		n = maxi(n, int(lv["level"]) + 1)
	data["levels"].append({"level": n, "orders": []})
	touch()
	rebuild()

func validate() -> String:
	var seen := {}
	for lv in data["levels"]:
		var n := int(lv["level"])
		if seen.has(n):
			return "主角等级重复：%d" % n
		seen[n] = true
		for o in lv["orders"]:
			if o["items"].is_empty():
				return "%d 级有订单没有物品" % n
	return ""
