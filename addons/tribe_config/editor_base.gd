@tool
extends VBoxContainer

const Ui := preload("res://addons/tribe_config/ui.gd")

var data: Variant
var host: Node

func edit(next: Variant, next_host: Node) -> void:
	data = next
	host = next_host
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_EXPAND_FILL
	refresh()

func refresh() -> void:
	pass

func rebuild() -> void:
	call_deferred("refresh")

func touch() -> void:
	if host != null and host.has_method("touch"):
		host.touch()

func clear_ui() -> VBoxContainer:
	while get_child_count() > 0:
		get_child(0).free()
	return Ui.scroll(self)

func string_rows(parent: Node, items: Array, title: String) -> void:
	Ui.lbl(parent, title)
	for i in items.size():
		var r := Ui.row(parent)
		Ui.lbl(r, str(i + 1), 28)
		var e := Ui.line(r, str(items[i]))
		e.text_changed.connect(_set_text.bind(items, i))
		Ui.btn(r, "上").pressed.connect(_move_at.bind(items, i, -1))
		Ui.btn(r, "下").pressed.connect(_move_at.bind(items, i, 1))
		Ui.btn(r, "删除").pressed.connect(_remove_at.bind(items, i))
	Ui.btn(parent, "添加" + title).pressed.connect(_add_to.bind(items, ""))

func int_spins(parent: Node, items: Array, title: String, lo: int, hi: int) -> void:
	var r := Ui.row(parent)
	Ui.lbl(r, title, 120)
	for i in items.size():
		var s := Ui.spin(r, int(items[i]), lo, hi, 68)
		s.value_changed.connect(_set_int_at.bind(items, i))
	Ui.btn(r, "+").pressed.connect(_add_to.bind(items, 0))
	if not items.is_empty():
		Ui.btn(r, "−").pressed.connect(_pop_end.bind(items))

func _set_text(text: String, items: Array, i: int) -> void:
	items[i] = text
	touch()

func _set_int_at(v: Variant, items: Array, i: int) -> void:
	items[i] = int(v)
	touch()

func _add_to(items: Array, blank: Variant = "") -> void:
	items.append(blank)
	touch()
	rebuild()

func _remove_at(items: Array, i: int) -> void:
	if i < 0 or i >= items.size():
		return
	items.remove_at(i)
	touch()
	rebuild()

func _move_at(items: Array, i: int, dir: int) -> void:
	var j := i + dir
	if j < 0 or j >= items.size():
		return
	var tmp = items[i]
	items[i] = items[j]
	items[j] = tmp
	touch()
	rebuild()

func _pop_end(items: Array) -> void:
	if items.is_empty():
		return
	items.pop_back()
	touch()
	rebuild()

func reward_list(parent: Node, items: Array) -> void:
	for i in items.size():
		var rw: Array = items[i]
		if rw.size() < 2:
			while rw.size() < 2:
				rw.append(1 if rw.size() == 1 else "fruit_1")
		var r := Ui.row(parent)
		var id := Ui.line(r, str(rw[0]), 160)
		id.text_changed.connect(_set_pair_id.bind(rw))
		var n := Ui.spin(r, int(rw[1]), 1, 9999, 80)
		n.value_changed.connect(_set_pair_n.bind(rw))
		Ui.btn(r, "删除").pressed.connect(_remove_at.bind(items, i))
	Ui.btn(parent, "添加奖励").pressed.connect(_add_pair.bind(items))

func _set_pair_id(text: String, rw: Array) -> void:
	rw[0] = text.strip_edges()
	touch()

func _set_pair_n(v: Variant, rw: Array) -> void:
	rw[1] = int(v)
	touch()

func _add_pair(items: Array) -> void:
	items.append(["fruit_1", 1])
	touch()
	rebuild()

func _set_field(text: String, obj: Dictionary, key: String) -> void:
	obj[key] = text
	touch()

func _set_num(v: Variant, obj: Dictionary, key: String) -> void:
	obj[key] = int(v)
	touch()
