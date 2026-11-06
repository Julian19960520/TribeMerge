extends RefCounted
## Offline-only source art. Never loaded by gameplay.

static func rock(ci: CanvasItem, r: Rect2, i: int) -> void:
	var c := r.get_center() + Vector2(0, 4)
	var base := []
	for k in 9:
		var a := TAU * float(k) / 9.0 + Art.srnd(i * 13 + k) * 0.3
		var rad := 36.0 + Art.srnd(i * 7 + k) * 8.0
		base.append(c + Vector2(cos(a) * rad * 1.08, sin(a) * rad * 0.9))
	var big := Art.poly(base, i, 0.8)
	ci.draw_colored_polygon(Art.ell(c + Vector2(0, 30), Vector2(38, 9), i, 0.0, 14), Color(0, 0, 0, 0.18))
	var small := Art.poly([c + Vector2(18, 14), c + Vector2(38, 8), c + Vector2(46, 26), c + Vector2(30, 36), c + Vector2(14, 30)], i + 5, 0.6)
	Art.sil(ci, [Art.P(big, Color("a39b8d"), 1), Art.P(small, Color("8c8476"), 1)], false, 3.0)
	var top := Art.poly([c + Vector2(-26, -18), c + Vector2(-6, -32), c + Vector2(18, -26), c + Vector2(6, -10), c + Vector2(-16, -6)], i + 9, 0.6)
	ci.draw_colored_polygon(top, Color(1, 1, 1, 0.22))
	var crack := Color(0.25, 0.2, 0.15, 0.75)
	Art.pl(ci, [c + Vector2(-4, -10), c + Vector2(4, 4), c + Vector2(-2, 14), c + Vector2(6, 26)], 2.4, crack, i + 2)
	Art.pl(ci, [c + Vector2(4, 4), c + Vector2(16, 0)], 2.0, crack, i + 3)
	Art.pl(ci, [c + Vector2(-30, 6), c + Vector2(-20, 12), c + Vector2(-22, 22)], 2.0, crack, i + 4)
	var moss := Art.ell(c + Vector2(-20, -24), Vector2(15, 7), i + 6, 0.12, 12, -0.4)
	Art.fill(ci, moss, Art.MOSS, 2.0)
	ci.draw_colored_polygon(Art.ell(c + Vector2(-24, -26), Vector2(6, 3), i + 7, 0.0, 8, -0.4), Color(1, 1, 1, 0.35))
	for k in 3:
		ci.draw_circle(c + Vector2(-8 + k * 12, 22 - (k % 2) * 6), 1.6, Color(0.3, 0.25, 0.2, 0.5))

static func cracks(ci: CanvasItem, r: Rect2, i: int, u: float) -> void:
	var c := r.get_center() + Vector2(0, 4)
	var flash := Color(1, 0.95, 0.82, 0.85 * (1.0 - u))
	var deep := Color(0.15, 0.1, 0.08, 0.9)
	var w := lerpf(2.0, 4.5, u)
	Art.pl(ci, [c + Vector2(-8, -22), c + Vector2(2, -4), c + Vector2(-6, 16), c + Vector2(8, 30)], w, deep, i + 11)
	Art.pl(ci, [c + Vector2(2, -4), c + Vector2(22, -8), c + Vector2(34, 6)], w * 0.8, deep, i + 12)
	Art.pl(ci, [c + Vector2(-28, 2), c + Vector2(-12, 10), c + Vector2(-18, 28)], w * 0.8, deep, i + 13)
	Art.pl(ci, [c + Vector2(-6, -18), c, c + Vector2(4, 12)], w * 0.45, flash, i + 14)

static func frame(ci: CanvasItem, size: Vector2) -> void:
	var shape := Art.rrect(Rect2(-14, -14, size.x + 28, size.y + 28), 22, 77, 1.0)
	Art.dilate(ci, shape, 3.0, Art.INK)
	ci.draw_colored_polygon(shape, Art.LEATHER)
	Art.dashed(ci, Art.rrect(Rect2(-7, -7, size.x + 14, size.y + 14), 16, 78, 0.0), 11, 7, Color("f3d7a2"), 2.2)
	ci.draw_rect(Rect2(Vector2.ZERO, size), Art.HIDE2)

static func fragment(ci: CanvasItem, k: int) -> void:
	if k == 6:
		ci.draw_circle(Vector2(32, 32), 15, Color("3b2314"))
		ci.draw_circle(Vector2(32, 32), 12, Color("9a9284"))
	elif k == 7:
		ci.draw_circle(Vector2(32, 32), 28, Color(0.72, 0.66, 0.56, 1))
	else:
		var pts := PackedVector2Array([Vector2(14 + k, 12), Vector2(53, 18 + k), Vector2(29, 52 - k)])
		ci.draw_colored_polygon(pts, Color("a39b8d") if k % 2 == 0 else Color("8a8274"))
		ci.draw_polyline(PackedVector2Array([pts[0],pts[1],pts[2],pts[0]]), Color("3b2314"), 2, true)
		if k % 2 == 0: ci.draw_circle(Vector2(30, 26), 3, Color(1, 1, 1, 0.28))
