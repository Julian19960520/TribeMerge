class_name TigerArt
extends RefCounted
## 与游戏墨线、土色贴纸一致的剑齿虎；坐标原点在脸部中央。
static func draw(ci: CanvasItem, center: Vector2, size: float) -> void:
	var scale := size / 120.0
	ci.draw_set_transform(center, 0, Vector2.ONE * scale)
	var orange := Color("e7a23e")
	for side in [-1, 1]:
		Art.fill(ci, Art.ell(Vector2(side * 39, -35), Vector2(20, 22), 12, 0, 18), Art.WOOD_D, 3)
		ci.draw_circle(Vector2(side * 39, -35), 12, Color("cf7951"))
	Art.fill(ci, Art.ell(Vector2(0, 0), Vector2(57, 46), 7, 0.02, 30), orange, 4)
	ci.draw_colored_polygon(Art.ell(Vector2(0, 15), Vector2(42, 25), 13, 0, 24), Color("ffdea1"))
	for side in [-1, 1]:
		for k in 3:
			var y := -17 + k * 14
			ci.draw_colored_polygon(PackedVector2Array([Vector2(side * 51, y - 7), Vector2(side * 30, y), Vector2(side * 52, y + 6)]), Art.WOOD_D)
		ci.draw_line(Vector2(side * 29, -13), Vector2(side * 12, -8), Art.INK, 6, true)
		ci.draw_circle(Vector2(side * 22, -4), 5, Art.INK)
		ci.draw_circle(Vector2(side * 23, -6), 1.8, Color.WHITE)
		var tooth := PackedVector2Array([Vector2(side * 17, 19), Vector2(side * 30, 18), Vector2(side * 22, 60), Vector2(side * 16, 48)])
		Art.dilate(ci, tooth, 3, Art.INK)
		ci.draw_colored_polygon(tooth, Color("fff5d7"))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-10, 7), Vector2(10, 7), Vector2(0, 17)]), Art.INK)
	ci.draw_line(Vector2(0, 16), Vector2(0, 26), Art.INK, 3, true)
	for k in 3:
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-6 + k * 7, -43), Vector2(-2 + k * 5, -20), Vector2(3 + k * 6, -43)]), Art.WOOD_D)
	ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
