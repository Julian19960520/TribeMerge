extends RefCounted
## 对照画法：左边原始现场绘制，右边贴图
const Meme := preload("res://scripts/Meme.gd")
const MS := preload("res://scripts/sprites/meme.gd")

static func paint(ci: CanvasItem, sz: Vector2) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, sz), Color("f3e6cc"))
	for side in 2:
		var o := Vector2(side * 750, 0)
		var live := side == 0
		ci.draw_rect(Rect2(o, Vector2(750, 640)), Color("203e35"))
		# 头像：大号 5 个一排 ×2，小号一排
		for role in 10:
			var c := o + Vector2(75 + (role % 5) * 145, 130 + (role / 5) * 230)
			if live: Meme.live_portrait(ci, role, c, 140)
			else: Meme.portrait(ci, role, c, 140)
			var c2 := o + Vector2(40 + role * 72, 560)
			if live: Meme.live_portrait(ci, role, c2, 56)
			else: Meme.portrait(ci, role, c2, 56)
		# 剑齿虎
		for k in 2:
			var s := 134.0 if k == 0 else 82.0
			var c := o + Vector2(100 + k * 160, 730)
			if live: MS.live_tiger(ci, c, s)
			else: TigerArt.draw(ci, c, s)
		# 落脚点、碎石、草丛
		var at := o + Vector2(560, 720)
		if live: MS.live_node(ci, at, 0)
		else: Sprites.at(ci, "tiger_node", at + MS.NODE_BOX.get_center())
		for j in 4:
			var f := o + Vector2(420 + (j - 1.5) * 37, 830 + (j % 2) * 22)
			if live: MS.live_frag(ci, f, 0, j * 0.4)
			else: Sprites.at(ci, "tiger_frag", f, 1.0, j * 0.4)
		for k in 2:
			var b := o + Vector2(620, 850 + k * 60)
			var rot := 0.7 if k == 0 else -0.7
			if live: MS.live_bush(ci, b, 0, rot)
			else: Sprites.at(ci, "tiger_bush", b, 1.0, rot)
		var hr := Rect2(o + Vector2(40, 960), MS.HEADER_SIZE * 0.95)
		if live:
			ci.draw_set_transform(hr.position, 0, Vector2.ONE * 0.95)
			MS.live_header(ci, Rect2(Vector2.ZERO, MS.HEADER_SIZE))
			ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		else: Sprites.draw(ci, "tiger_header", hr)
