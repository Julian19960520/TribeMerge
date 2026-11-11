class_name ItemActionPanel
extends DrawBox
## Selected item instructions, independent of board input and order layout.
var action: Dictionary = {}
func _ready() -> void:
	painter = _paint_item_action
	super._ready()
func set_action(value: Dictionary) -> void:
	if action == value: return
	action = value.duplicate(true)
	queue_redraw()

const HINT_INK := Color("6b4a2a")

## 图标底下的浅色圆角托盘，让每个图标都有同样大小的“格子”
static func _hint_plate(ci: CanvasItem, c: Vector2, s: float, seed: int, hot: bool = false) -> void:
	Sprites.draw(ci, "board_plate_hot" if hot else "board_plate", Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)))

## 手绘的 + / = 号：白芯墨边，和标题字一个风格
static func _hint_op(ci: CanvasItem, c: Vector2, op: String) -> void:
	var bars: Array = []
	if op == "+":
		bars = [[c + Vector2(-10, 0), c + Vector2(10, 0)], [c + Vector2(0, -10), c + Vector2(0, 10)]]
	else:
		bars = [[c + Vector2(-10, -5), c + Vector2(10, -5)], [c + Vector2(-10, 5), c + Vector2(10, 5)]]
	for b in bars:
		ci.draw_line(b[0], b[1], Art.INK, 9.0, true)
		ci.draw_circle(b[0], 4.5, Art.INK)
		ci.draw_circle(b[1], 4.5, Art.INK)
	for b in bars:
		ci.draw_line(b[0], b[1], Art.BONE, 4.0, true)
		ci.draw_circle(b[0], 2.0, Art.BONE)
		ci.draw_circle(b[1], 2.0, Art.BONE)

static func _hint_text(ci: CanvasItem, pos: Vector2, text: String, fs: int, col: Color = HINT_INK, outline := false) -> float:
	var f: Font = G.font_title if outline else G.font_body
	if outline:
		ci.draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Art.INK)
	ci.draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	return f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x

static func _text_w(text: String, fs: int, title := false) -> float:
	var f: Font = G.font_title if title else G.font_body
	return f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x

## 文字基线：让 fs 号字在 y 处垂直居中
static func _mid_base(y: float, fs: int, title := false) -> float:
	var f: Font = G.font_title if title else G.font_body
	return y + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5

func _paint_item_action(ci: CanvasItem, sz: Vector2) -> void:
	if action.is_empty(): return
	var mode := str(action["mode"])
	var items: Array = action["items"]
	var y := sz.y * 0.5
	if mode == "merge":
		# 3 个 78 托盘 + 2 个 33 运算符 = 300
		var plate := 76.0
		var op_w := (sz.x - plate * 3.0) * 0.5
		for k in 3:
			var cx := plate * 0.5 + k * (plate + op_w)
			_hint_plate(ci, Vector2(cx, y), plate, k, k == 2)
			Art.item(ci, str(items[k]), Vector2(cx, y), plate * 0.86, false)
		_hint_op(ci, Vector2(plate + op_w * 0.5, y), "+")
		_hint_op(ci, Vector2(plate * 2.0 + op_w * 1.5, y), "=")
	elif mode == "produce":
		var label := "点击生产"
		var fs := 22
		var lw := _text_w(label, fs)
		_hint_text(ci, Vector2(0, _mid_base(y, fs)), label, fs)
		var x0 := lw + 8.0
		var area := sz.x - x0
		var n := items.size()
		var rows := 1 if n <= 4 else 2
		var cols := ceili(float(n) / float(rows))
		var step := minf(area / float(cols), 62.0 if rows == 1 else 52.0)
		var plate := step - 4.0
		var row_h := sz.y / float(rows)
		var used := step * float(cols)
		for k in n:
			var row := k / cols
			var col := k % cols
			# 第二行少一个时也居中
			var in_row := cols if row < rows - 1 else n - cols * (rows - 1)
			var cx := x0 + (area - used) * 0.5 + (float(col) + 0.5 + (cols - in_row) * 0.5) * step
			var cy := row_h * (float(row) + 0.5)
			_hint_plate(ci, Vector2(cx, cy), plate, k)
			Art.item(ci, str(items[k]), Vector2(cx, cy), plate * 0.94, false)
	elif mode == "collect":
		var plate := 72.0
		_hint_plate(ci, Vector2(plate * 0.5, y), plate, 3, true)
		Art.item(ci, str(items[0]), Vector2(plate * 0.5, y), plate * 0.86, false)
		var a := "点击获得"
		var num := str(int(action["n"]))
		var b := str(action["unit"])
		var fa := 22
		var fn := 32
		var total := _text_w(a, fa) + 6.0 + _text_w(num, fn, true) + 4.0 + _text_w(b, fa)
		var x := plate + maxf(10.0, (sz.x - plate - total) * 0.5)
		x += _hint_text(ci, Vector2(x, _mid_base(y, fa)), a, fa) + 6.0
		x += _hint_text(ci, Vector2(x, _mid_base(y, fn, true)), num, fn, Art.FIRE2, true) + 4.0
		_hint_text(ci, Vector2(x, _mid_base(y, fa)), b, fa)
	else:
		var plate := 76.0
		_hint_plate(ci, Vector2(plate * 0.5, y), plate, 5, true)
		Art.item(ci, str(items[0]), Vector2(plate * 0.5, y), plate * 0.86, false)
		ci.draw_texture_rect(Board.MAX_CROWN, Rect2(plate - 30, y - plate * 0.5 - 8, 38, 30), false)
		var t := "已达最高级"
		var fs := 24
		_hint_text(ci, Vector2(plate + (sz.x - plate - _text_w(t, fs)) * 0.5, _mid_base(y, fs)), t, fs)
