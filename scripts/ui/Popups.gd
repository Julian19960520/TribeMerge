class_name Popups
extends RefCounted
## Shared popup chrome and scoped signal subscriptions. Feature views live in popups/.

static func frame(p: PopupBase, r: Rect2, title: String, col: Color = Art.TEAL, mascot: String = "") -> void:
	var br := Rect2(r.get_center().x - 180, r.position.y - 34, 360, 78)
	UI.box(p.box, Rect2(0, 0, 720, 1480), func(ci, _sz):
		if mascot != "":
			if mascot == "fire":
				for k in 5:
					Art.item(ci, "fire_2", Vector2(br.position.x + 30 + k * 75, br.position.y + 6 - (k % 2) * 20), 56)
			Paint.mascot(ci, Vector2(r.get_center().x, br.position.y - 60), 120, "hammer" if mascot == "hammer" else "")
		Paint.panel(ci, r)
		Paint.banner(ci, br, col))
	UI.title(p.box, title, Rect2(br.position.x + 40, br.position.y + 4, br.size.x - 80, br.size.y - 10), 38, Color.WHITE)
	var x := UI.hit(p.box, Rect2(r.end.x - 52, r.position.y - 24, 70, 70), p.close)
	x.extra = func(ci, sz): Paint.close_btn(ci, sz * 0.5, 28)

static func section(parent: Control, text: String, y: float, col: Color = Color("8a5a30"), cx: float = 360.0) -> void:
	var fs := 26
	var tw := float(text.length()) * float(fs)
	if G.font_body:
		tw = G.font_body.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var half := tw * 0.5 + 14.0
	var edge := 26.0
	UI.lbl(parent, text, Rect2(cx - 240, y, 480, 40), fs, col)
	UI.box(parent, Rect2(cx - 260, y, 520, 40), func(ci, sz):
		var mid: float = sz.x * 0.5
		var left_star := clampf(mid - half, edge + 18.0, mid - 36.0)
		var right_star := clampf(mid + half, mid + 36.0, sz.x - edge - 18.0)
		Sprites.draw(ci, "pop_sec_line", Rect2(edge, 17, left_star - 10.0 - edge, 6), Color(col, 0.5))
		Sprites.draw(ci, "pop_sec_line", Rect2(right_star + 10.0, 17, sz.x - edge - right_star - 10.0, 6), Color(col, 0.5))
		Sprites.at(ci, "pop_sec_star", Vector2(left_star, 20), 1.0, 0.0, Color(col, 0.6))
		Sprites.at(ci, "pop_sec_star", Vector2(right_star, 20), 1.0, 0.0, Color(col, 0.6)))

# ---------------------------------------------------------------- 体力

static func fullscreen(p: PopupBase, top: float = 128.0) -> Array:
	p.set_meta("fullscreen", true)
	var sc := Scroller.new()
	sc.position = Vector2(0, top)
	sc.size = Vector2(720, 1480 - top)
	p.box.add_child(sc)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.position = Vector2(0, -top)
	sc.content.add_child(root)
	return [sc, root]

## 连接全局信号，弹窗销毁时自动断开

static func live(p: Node, sig: Signal, cb: Callable) -> void:
	sig.connect(cb)
	p.tree_exiting.connect(func(): sig.disconnect(cb))
