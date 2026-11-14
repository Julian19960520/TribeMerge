class_name UI
extends RefCounted
## 布局工厂：所有坐标都在 720×1480 的设计空间里。

static func resource_text(text: String) -> String:
	# Resource names read as nouns even when they sit inside spoken sentences.
	text = TextCatalog.resolve(text)
	var noun := TextCatalog.text("ui.choicechestpopup.2580a668b381")
	var quoted := "「" + noun + "」"
	return text.replace(quoted, noun).replace(noun, quoted)

static func canonical_resource_text(text: String) -> String:
	return text.replace(TextCatalog.source("ui.ui.1de156797f67"), TextCatalog.source("ui.choicechestpopup.2580a668b381")).replace(TextCatalog.source("ui.choicechestpopup.2580a668b381"), TextCatalog.source("ui.ui.1de156797f67"))

static func resource_rich(text: String) -> String:
	var quoted := "「" + TextCatalog.text("ui.choicechestpopup.2580a668b381") + "」"
	return resource_text(text).replace(quoted, "[color=#a35d16]" + quoted + "[/color]")

static func box(parent: Node, r: Rect2, painter: Callable, boil: bool = true) -> DrawBox:
	var d := DrawBox.new()
	d.boil = boil
	d.position = r.position
	d.size = r.size
	d.painter = painter
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(d)
	return d

static func lbl(parent: Node, text: String, r: Rect2, fs: int = 26, col: Color = Art.INK, align: int = HORIZONTAL_ALIGNMENT_CENTER,
		outline: int = 0, ocol: Color = Art.INK, title: bool = false) -> Label:
	var l := Label.new()
	l.text = resource_text(text)
	l.position = r.position
	l.size = r.size
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ls := LabelSettings.new()
	ls.font = G.font_title if title else G.font_body
	ls.font_size = fs
	ls.font_color = col
	ls.outline_size = outline
	ls.outline_color = ocol
	if outline > 0:
		ls.shadow_size = 0
		ls.shadow_offset = Vector2(0, 3)
		ls.shadow_color = Color(ocol, 0.6)
	l.label_settings = ls
	parent.add_child(l)
	return l

static func title(parent: Node, text: String, r: Rect2, fs: int = 52, col: Color = Color("ffd23f")) -> Label:
	return lbl(parent, text, r, fs, col, HORIZONTAL_ALIGNMENT_CENTER, 14, Art.INK, true)

static func btn(parent: Node, r: Rect2, text: String, style: String, cb: Callable, fs: int = 34) -> TButton:
	var b := TButton.new()
	b.position = r.position
	b.size = r.size
	b.text = TextCatalog.resolve(text)
	b.style = style
	b.font_size = fs
	if cb.is_valid():
		b.pressed.connect(cb)
	parent.add_child(b)
	return b

static func icon(parent: Node, id: String, c: Vector2, s: float, rim: bool = true) -> DrawBox:
	var d := box(parent, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), func(ci, sz): Art.item(ci, id, sz * 0.5, s * 0.92, rim))
	return d

static func hit(parent: Node, r: Rect2, cb: Callable) -> TButton:
	var b := TButton.new()
	b.position = r.position
	b.size = r.size
	b.style = "none"
	b.pressed.connect(cb)
	parent.add_child(b)
	return b
