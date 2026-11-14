@tool
extends "res://addons/tribe_config/editor_base.gd"

func refresh() -> void:
	var box := clear_ui()
	Ui.lbl(box, TextCatalog.source("developer.pass_editor.af2159fc5225"))
	for i in data["levels"].size():
		var lv: Dictionary = data["levels"][i]
		var g := Ui.group(box)
		var head := Ui.row(g)
		Ui.lbl(head, TextCatalog.source("developer.pass_editor.1445f628f6cc") % (i + 1), 72)
		Ui.lbl(head, TextCatalog.source("developer.pass_editor.10939f548645"), 40)
		var need := Ui.spin(head, int(lv.get("need", 8)), 1, 9999, 90)
		need.value_changed.connect(_set_num.bind(lv, "need"))
		Ui.btn(head, TextCatalog.source("developer.editor_base.db5ba671d244")).pressed.connect(_move_at.bind(data["levels"], i, -1))
		Ui.btn(head, TextCatalog.source("developer.editor_base.13c12b064b63")).pressed.connect(_move_at.bind(data["levels"], i, 1))
		Ui.btn(head, TextCatalog.source("developer.editor_base.2f9daa828907")).pressed.connect(_remove_at.bind(data["levels"], i))
		_rewards(g, lv, "free", TextCatalog.source("developer.pass_editor.649a0fc7237e"))
		_rewards(g, lv, "prem", TextCatalog.source("developer.pass_editor.f9beb133f609"))
	Ui.btn(box, TextCatalog.source("developer.amber_editor.5e0169c84b8a")).pressed.connect(_add_level)

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
		Ui.btn(r, TextCatalog.source("developer.editor_base.2f9daa828907")).pressed.connect(_remove_at.bind(items, i))
	Ui.btn(parent, TextCatalog.source("developer.editor_base.7a8a11ead507") + title).pressed.connect(_add_reward.bind(items))

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
			return TextCatalog.source("developer.pass_editor.3e4838ee6c56") % i
		if need <= prev:
			return TextCatalog.source("developer.pass_editor.e89040115048") % i
		prev = need
		for key in ["free", "prem"]:
			for rw in lv[key]:
				if str(rw[0]).strip_edges() == "":
					return TextCatalog.source("developer.pass_editor.421a347987e9")
				if int(rw[1]) < 1:
					return TextCatalog.source("developer.pass_editor.ee9f898c42ca")
	return ""
