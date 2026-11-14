@tool
extends "res://addons/tribe_config/editor_base.gd"

const VALUED := ["energy", "shell", "amber", "sand"]

var _index := 0
var _list: ItemList

func refresh() -> void:
	while get_child_count() > 0:
		get_child(0).free()
	if data.is_empty():
		_index = -1
	else:
		_index = clampi(_index, 0, data.size() - 1)
	var split := HSplitContainer.new()
	split.size_flags_horizontal = SIZE_EXPAND_FILL
	split.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(split)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 220
	left.size_flags_vertical = SIZE_EXPAND_FILL
	split.add_child(left)
	_list = ItemList.new()
	_list.size_flags_vertical = SIZE_EXPAND_FILL
	_list.select_mode = ItemList.SELECT_SINGLE
	left.add_child(_list)
	for c in data:
		_list.add_item(TextCatalog.resolve("%s  %s" % [c["id"], c["name"]]))
	if _index >= 0:
		_list.select(_index)
	_list.item_selected.connect(_on_pick)
	var buttons := Ui.row(left)
	Ui.btn(buttons, TextCatalog.source("developer.chains_editor.f853a70b1204")).pressed.connect(_move_chain.bind(-1))
	Ui.btn(buttons, TextCatalog.source("developer.chains_editor.e75e8b4e5c97")).pressed.connect(_move_chain.bind(1))
	Ui.btn(left, TextCatalog.source("developer.chains_editor.3f6c0c1baaf8")).pressed.connect(_add_chain)
	Ui.btn(left, TextCatalog.source("developer.chains_editor.0f3971741071")).pressed.connect(_remove_chain)
	var right := Ui.scroll(split)
	if _index < 0:
		Ui.lbl(right, TextCatalog.source("developer.chains_editor.af49484e0bdb"))
		return
	var chain: Dictionary = data[_index]
	_fit_value(chain)
	Ui.lbl(right, TextCatalog.source("developer.chains_editor.b15dab78caf6"))
	var r := Ui.row(right)
	Ui.lbl(r, TextCatalog.source("developer.builds_editor.a56145270ce6"), 48)
	var id := Ui.line(r, str(chain["id"]), 160)
	id.text_changed.connect(_set_id.bind(chain))
	Ui.lbl(r, TextCatalog.source("developer.builds_editor.d44e9b3d3b31"), 40)
	var nm := Ui.line(r, str(chain["name"]))
	nm.text_changed.connect(_set_name.bind(chain))
	var r2 := Ui.row(right)
	Ui.lbl(r2, TextCatalog.source("developer.chains_editor.77ca877fdd41"), 40)
	var line := Ui.line(r2, str(chain.get("line", "")), 100)
	line.text_changed.connect(_set_line.bind(chain))
	chain.erase("kind")
	var items: Array = chain["items"]
	for i in items.size():
		var ir := Ui.row(right)
		Ui.lbl(ir, TextCatalog.source("developer.chains_editor.b4d436ea2c00") % (i + 1), 48)
		var e := Ui.line(ir, str(items[i]))
		e.text_changed.connect(_set_text.bind(items, i))
		if chain.has("value"):
			var vs := Ui.spin(ir, int(chain["value"][i]), 0, 99999, 80)
			vs.value_changed.connect(_set_value.bind(chain, i))
		Ui.btn(ir, TextCatalog.source("developer.editor_base.db5ba671d244")).pressed.connect(_move_item.bind(chain, i, -1))
		Ui.btn(ir, TextCatalog.source("developer.editor_base.13c12b064b63")).pressed.connect(_move_item.bind(chain, i, 1))
		Ui.btn(ir, TextCatalog.source("developer.editor_base.2f9daa828907")).pressed.connect(_remove_item.bind(chain, i))
	Ui.btn(right, TextCatalog.source("developer.chains_editor.a8755f6844db")).pressed.connect(_add_item.bind(chain))

func _on_pick(i: int) -> void:
	if i == _index:
		return
	_index = i
	rebuild()

func _set_id(text: String, chain: Dictionary) -> void:
	chain["id"] = text.strip_edges()
	touch()
	_retitle(chain)

func _set_name(text: String, chain: Dictionary) -> void:
	chain["name"] = text
	touch()
	_retitle(chain)

func _retitle(chain: Dictionary) -> void:
	if is_instance_valid(_list) and _index >= 0 and _index < _list.item_count:
		_list.set_item_text(_index, TextCatalog.resolve("%s  %s" % [chain["id"], chain["name"]]))

func _set_line(text: String, chain: Dictionary) -> void:
	if text == "":
		chain.erase("line")
	else:
		chain["line"] = text
	touch()

func _set_value(v: Variant, chain: Dictionary, i: int) -> void:
	chain["value"][i] = int(v)
	touch()

func _fit_value(chain: Dictionary) -> void:
	if not chain.has("items") or not (chain["items"] is Array):
		chain["items"] = []
	if str(chain.get("type", "")) in VALUED:
		if not chain.has("value") or not (chain["value"] is Array):
			chain["value"] = []
		while chain["value"].size() < chain["items"].size():
			chain["value"].append(0)
		while chain["value"].size() > chain["items"].size():
			chain["value"].pop_back()
	else:
		chain.erase("value")

func _add_item(chain: Dictionary) -> void:
	chain["items"].append(TextCatalog.source("developer.chains_editor.b66f478587fb"))
	_fit_value(chain)
	touch()
	rebuild()

func _remove_item(chain: Dictionary, i: int) -> void:
	chain["items"].remove_at(i)
	if chain.has("value") and i < chain["value"].size():
		chain["value"].remove_at(i)
	_fit_value(chain)
	touch()
	rebuild()

func _move_item(chain: Dictionary, i: int, dir: int) -> void:
	var items: Array = chain["items"]
	var j := i + dir
	if j < 0 or j >= items.size():
		return
	var tmp = items[i]
	items[i] = items[j]
	items[j] = tmp
	if chain.has("value") and chain["value"].size() == items.size():
		var tv = chain["value"][i]
		chain["value"][i] = chain["value"][j]
		chain["value"][j] = tv
	touch()
	rebuild()

func _add_chain() -> void:
	data.append({
		"id": "chain_%d" % (data.size() + 1),
		"name": TextCatalog.source("developer.chains_editor.24fa72755e59"),
		"type": "item",
		"items": [TextCatalog.source("developer.chains_editor.b66f478587fb")],
	})
	_index = data.size() - 1
	touch()
	rebuild()

func _remove_chain() -> void:
	if data.is_empty():
		return
	data.remove_at(_index)
	_index = mini(_index, data.size() - 1)
	touch()
	rebuild()

func _move_chain(dir: int) -> void:
	var j := _index + dir
	if _index < 0 or j < 0 or j >= data.size():
		return
	var tmp = data[_index]
	data[_index] = data[j]
	data[j] = tmp
	_index = j
	touch()
	rebuild()

func validate() -> String:
	var seen := {}
	for c in data:
		var id := str(c.get("id", "")).strip_edges()
		c["id"] = id
		if id == "":
			return TextCatalog.source("developer.chains_editor.a16a53bf8e06")
		if seen.has(id):
			return TextCatalog.source("developer.chains_editor.4bda17884ac6") + id
		seen[id] = true
		if c.get("items", []).is_empty():
			return TextCatalog.source("developer.chains_editor.bf3f32f315b4") % id
	return ""
