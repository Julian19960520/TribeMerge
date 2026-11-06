extends RefCounted
## 篝火竞速的香蕉（程序画）：月牙形的果身 + 两头的褐色果柄。c 是中心，s 是长度。

static func draw(ci: CanvasItem, c: Vector2, s: float, rot: float = 0.0, outline := true) -> void:
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var n := 12
	for i in n + 1:
		var u := float(i) / float(n)
		var a := lerpf(-1.05, 1.05, u)
		var th := sin(u * PI)  # 两头尖、中间粗
		outer.append(Vector2(sin(a) * s * 0.5, cos(a) * s * 0.34 - s * 0.16))
		inner.append(Vector2(sin(a) * s * 0.46, cos(a) * s * 0.34 - s * 0.16 - th * s * 0.32))
	var body := PackedVector2Array()
	for p in outer:
		body.append(c + p.rotated(rot))
	for i in range(inner.size() - 1, -1, -1):
		body.append(c + inner[i].rotated(rot))
	if outline:
		Art.dilate(ci, body, maxf(1.4, s * 0.06), Art.INK)
	ci.draw_colored_polygon(body, Color("ffd84a"))
	# 高光
	var hl := PackedVector2Array()
	for i in range(3, n - 2):
		var u := float(i) / float(n)
		var a := lerpf(-1.05, 1.05, u)
		hl.append(c + Vector2(sin(a) * s * 0.44, cos(a) * s * 0.34 - s * 0.16 - sin(u * PI) * s * 0.1).rotated(rot))
	if hl.size() >= 2:
		ci.draw_polyline(hl, Color(1, 1, 0.85, 0.8), maxf(1.0, s * 0.06), true)
	# 果柄和果尖
	var tip_a := c + inner[0].rotated(rot)
	var tip_b := c + outer[n].rotated(rot)
	ci.draw_circle(tip_a, maxf(1.2, s * 0.06), Color("6b4a2a"))
	ci.draw_line(tip_b, tip_b + Vector2(s * 0.1, -s * 0.08).rotated(rot), Color("6b4a2a"), maxf(1.5, s * 0.08), true)
