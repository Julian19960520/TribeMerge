class_name TButton
extends Control
## 石子按钮：自绘外观，按下有压扁回弹。

signal pressed

var style := "green"
var text := ""
var font_size := 34
var is_round := false
var res := ""
var glyph := ""
var extra: Callable
var sound := "tap"
var enabled := true
var title_font := true
var _down := false

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	pivot_offset = size * 0.5
	G.boil_tick.connect(_on_boil)

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_down = true
			var tw := create_tween()
			tw.tween_property(self, "scale", Vector2(0.92, 0.88), 0.06)
			accept_event()
		elif _down:
			_down = false
			var tw := create_tween()
			tw.tween_property(self, "scale", Vector2(1.06, 1.04), 0.08)
			tw.tween_property(self, "scale", Vector2.ONE, 0.1)
			accept_event()
			if Rect2(Vector2.ZERO, size).has_point(e.position) and not G.scroll_drag:
				if enabled:
					Sfx.play(sound)
					pressed.emit()
				else:
					Sfx.play("deny")

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var st := style if enabled else "grey"
	if is_round:
		Paint.round_btn(self, size * 0.5, size.x * 0.5 - 3, st, get_instance_id() % 50)
	elif st != "none":
		Paint.button(self, r, st, get_instance_id() % 50)
	var cy := size.y * 0.5 - (3.0 if not is_round and st != "none" else 0.0)
	var f: Font = G.font_title if title_font else G.font_body
	var tw := 0.0
	if text != "":
		tw = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var icon_w := 0.0
	if res != "":
		icon_w = font_size * 1.5
	var x0 := size.x * 0.5 - (tw + icon_w) * 0.5
	if res != "":
		Art.item(self, res, Vector2(x0 + icon_w * 0.45, cy), font_size * 1.55, false)
	if glyph != "":
		Paint.glyph(self, glyph, Vector2(size.x * 0.5, cy), size.y / 70.0)
	if text != "":
		var base := cy + (f.get_ascent(font_size) - f.get_descent(font_size)) * 0.5
		var pos := Vector2(x0 + icon_w, base)
		draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 8, Art.INK)
		draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
	if extra.is_valid():
		extra.call(self, size)

func _on_boil() -> void:
	if is_visible_in_tree():
		queue_redraw()
