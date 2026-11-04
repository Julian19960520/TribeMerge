@tool
extends RefCounted

static func scroll(parent: Node) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(sc)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	sc.add_child(box)
	return box

static func row(parent: Node) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	parent.add_child(h)
	return h

static func lbl(parent: Node, text: String, w: float = 0.0) -> Label:
	var l := Label.new()
	l.text = text
	if w > 0.0:
		l.custom_minimum_size.x = w
	parent.add_child(l)
	return l

static func line(parent: Node, text: String, w: float = 0.0) -> LineEdit:
	var e := LineEdit.new()
	e.text = text
	if w > 0.0:
		e.custom_minimum_size.x = w
	else:
		e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(e)
	return e

static func spin(parent: Node, value: int, lo: int, hi: int, w: float = 80.0) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.rounded = true
	s.allow_greater = false
	s.allow_lesser = false
	s.update_on_text_changed = true
	s.value = value
	s.custom_minimum_size.x = w
	parent.add_child(s)
	return s

static func check(parent: Node, on: bool, text: String) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = on
	parent.add_child(c)
	return c

static func btn(parent: Node, text: String) -> Button:
	var b := Button.new()
	b.text = text
	parent.add_child(b)
	return b

static func option(parent: Node, labels: PackedStringArray, index: int, w: float = 140.0) -> OptionButton:
	var o := OptionButton.new()
	for t in labels:
		o.add_item(t)
	o.select(maxi(0, index))
	o.custom_minimum_size.x = w
	parent.add_child(o)
	return o

static func group(parent: Node) -> VBoxContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(p)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 8)
	m.add_theme_constant_override("margin_right", 8)
	m.add_theme_constant_override("margin_top", 6)
	m.add_theme_constant_override("margin_bottom", 6)
	p.add_child(m)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	m.add_child(box)
	return box
