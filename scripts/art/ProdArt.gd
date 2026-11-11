class_name ProdArt
extends RefCounted
## 运行时矢量后备图与本地烘焙共用的产线物品绘制入口。kind 是 "G"（生产器）、"M"（主产物）、"S"（副产物）。

static func draw(ci: CanvasItem, line: String, kind: String, lv: int, c: Vector2, size: float, rim: bool = true) -> void:
	var t := Transform2D(0.0, Vector2.ONE * (size / 100.0), 0.0, c)
	PA.xf = t
	ci.draw_set_transform_matrix(t)
	ci.draw_colored_polygon(Art.ell(Vector2(0, 40), Vector2(30, 6), 1, 0.0, 14, 0.0, 0.0), Color(0.2, 0.1, 0.0, 0.18))
	var s: int = abs((line + kind).hash()) % 97 + lv * 7
	var done := true
	match line:
		"food": _route(PAFood, ci, kind, lv, s, rim)
		"tool": _route(PATool, ci, kind, lv, s, rim)
		"cloth": _route(PACloth, ci, kind, lv, s, rim)
		"hunt": _route(PAHunt, ci, kind, lv, s, rim)
		"fire": _route(PAFire, ci, kind, lv, s, rim)
		"wood": _route(PAWood, ci, kind, lv, s, rim)
		"pot": _route(PAPot, ci, kind, lv, s, rim)
		_: done = false
	if not done:
		Art.sil(ci, [Art.P(Art.ell(Vector2.ZERO, Vector2(30, 30), s), Art.STONE)], rim)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	PA.xf = Transform2D.IDENTITY

static func _route(cls, ci: CanvasItem, kind: String, lv: int, s: int, rim: bool) -> void:
	match kind:
		"G": cls.gen(ci, lv, s, rim)
		"M": cls.main(ci, lv, s, rim)
		"S": cls.sub(ci, lv, s, rim)
