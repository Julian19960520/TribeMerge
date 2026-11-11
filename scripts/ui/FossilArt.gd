class_name FossilArt
extends RefCounted
## Vector fossils share exactly the same drawing in soil, collection silhouettes and flight.

static func plate(ci: CanvasItem, r: Rect2, color: Color, rim := Color("68452e"), radius := 18.0) -> void:
	ci.draw_colored_polygon(Art.rrect(r.grow(3), radius + 3, 984, 0), rim)
	ci.draw_colored_polygon(Art.rrect(r, radius, 985, 0), color)

static func shovel(ci: CanvasItem, c: Vector2, diameter: float, angle := -0.5) -> void:
	ci.draw_set_transform(c, angle, Vector2.ONE * diameter / 100.0)
	ci.draw_line(Vector2(0, -22), Vector2(0, 24), Color("443020"), 13, true)
	ci.draw_line(Vector2(-1, -22), Vector2(-1, 24), Color("d49b57"), 7, true)
	ci.draw_arc(Vector2(0, -30), 15, 0, TAU, 24, Color("443020"), 9, true)
	ci.draw_arc(Vector2(0, -30), 15, 0, TAU, 24, Color("edbd75"), 4, true)
	var blade := PackedVector2Array([Vector2(-19, 16), Vector2(19, 16), Vector2(20, 39), Vector2(0, 54), Vector2(-20, 39)])
	ci.draw_colored_polygon(blade, Color("c4d5c7"))
	ci.draw_polyline(PackedVector2Array([blade[0], blade[1], blade[2], blade[3], blade[4], blade[0]]), Color("443020"), 5, true)
	ci.draw_line(Vector2(0, 23), Vector2(0, 43), Color("eef3d9"), 3, true)
	ci.draw_set_transform(Vector2.ZERO)

static func piece(ci: CanvasItem, r: Rect2, p: Dictionary, shadow := false) -> void:
	var turn := int(p.get("turn", 0))
	var w := float(p.get("w", 1))
	var h := float(p.get("h", 2))
	var scale := minf(r.size.x / (w * 100.0), r.size.y / (h * 100.0)) * 0.86
	var original := Vector2(w, h) * 100.0 if turn == 0 else Vector2(h, w) * 100.0
	ci.draw_set_transform(r.get_center(), PI * 0.5 * turn, Vector2.ONE * scale)
	var ink := Color("473427") if shadow else Color("6a5037")
	var bone := Color("473427") if shadow else Color("f7e9bb")
	var light := bone if shadow else Color("fff9de")
	var kind := str(p.get("kind", "limb"))
	match kind:
		"skull":
			var pts := PackedVector2Array([Vector2(-65, -78), Vector2(-24, -89), Vector2(37, -83), Vector2(78, -48), Vector2(70, 12), Vector2(48, 53), Vector2(18, 79), Vector2(-41, 75), Vector2(-68, 31), Vector2(-79, -28)])
			ci.draw_colored_polygon(pts, bone)
			ci.draw_polyline(PackedVector2Array([pts[0],pts[1],pts[2],pts[3],pts[4],pts[5],pts[6],pts[7],pts[8],pts[9],pts[0]]), ink, 8, true)
			ci.draw_circle(Vector2(-33, -24), 25, Color("806240") if shadow else ink)
			ci.draw_circle(Vector2(32, -18), 24, Color("806240") if shadow else ink)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-10, 24), Vector2(14, 24), Vector2(3, 45)]), Color("806240") if shadow else ink)
			for x in [-32, -10, 12, 34]: _bone(ci, Vector2(x, 57), Vector2(x, 76), 7, ink, bone, light)
			if not shadow: ci.draw_line(Vector2(-46, -65), Vector2(-7, -74), light, 7, true)
		"ribs":
			var len := original.y * 0.37
			_bone(ci, Vector2(0, -len), Vector2(0, len), 13, ink, bone, light)
			for i in 5:
				var y := lerpf(-len * 0.8, len * 0.8, i / 4.0)
				var width := original.x * (0.37 - absf(i - 2) * 0.045)
				for side in [-1, 1]:
					var path := PackedVector2Array([Vector2(0, y - 8), Vector2(side * width * 0.68, y - 16), Vector2(side * width, y + 6), Vector2(side * width * 0.83, y + 32)])
					ci.draw_polyline(path, ink, 20, true)
					ci.draw_polyline(path, bone, 12, true)
		"pelvis":
			for side in [-1, 1]:
				var path := PackedVector2Array([Vector2(side * 13, -15), Vector2(side * 46, -97), Vector2(side * 101, -107), Vector2(side * 120, -43), Vector2(side * 96, 30), Vector2(side * 49, 96), Vector2(side * 12, 40)])
				ci.draw_colored_polygon(path, bone)
				var closed := path.duplicate(); closed.append(path[0])
				ci.draw_polyline(closed, ink, 10, true)
				ci.draw_circle(Vector2(side * 67, -15), 31, Color("806240") if shadow else ink)
			_bone(ci, Vector2(0, -66), Vector2(0, 89), 20, ink, bone, light)
		"spine":
			var count := maxi(3, int(original.y / 56))
			for i in count:
				var y := lerpf(-original.y * 0.39, original.y * 0.39, float(i) / (count - 1))
				_bone(ci, Vector2(-30, y - 8), Vector2(30, y + 8), 10, ink, bone, light)
				ci.draw_circle(Vector2(0, y), 19, ink)
				ci.draw_circle(Vector2(-1, y - 2), 13, bone)
		_:
			var length := original.y * 0.36
			_bone(ci, Vector2(0, -length), Vector2(0, length), 17, ink, bone, light)
			for y in [-length, length]:
				for x in [-15, 15]:
					ci.draw_circle(Vector2(x, y), 23, ink)
					ci.draw_circle(Vector2(x - 2, y - 3), 18, bone)
			if not shadow: ci.draw_line(Vector2(-6, -length + 25), Vector2(-6, length - 25), light, 5, true)
	ci.draw_set_transform(Vector2.ZERO)

static func _bone(ci: CanvasItem, a: Vector2, b: Vector2, radius: float, ink: Color, bone: Color, light: Color) -> void:
	ci.draw_line(a, b, ink, radius * 2 + 7, true)
	ci.draw_circle(a, radius + 3, ink); ci.draw_circle(b, radius + 3, ink)
	ci.draw_line(a, b, bone, radius * 2, true)
	ci.draw_circle(a, radius, bone); ci.draw_circle(b, radius, bone)
	if light != bone: ci.draw_line(a + Vector2(-3, 0), b + Vector2(-3, 0), light, maxf(3, radius * 0.3), true)

static func dirt(ci: CanvasItem, r: Rect2, cell: int) -> void:
	ci.draw_rect(r, Color("735036"))
	var face := r.grow(-2)
	var tint: Color = [Color("b6844b"), Color("bf8d53"), Color("b18048"), Color("c2945a")][cell % 4]
	ci.draw_colored_polygon(Art.rrect(face, minf(12, r.size.x * 0.12), cell + 710, 0), tint)
	ci.draw_line(face.position + Vector2(7, 3), face.position + Vector2(face.size.x - 7, 3), Color("d9ac6d"), 3, true)
	ci.draw_line(face.position + Vector2(4, face.size.y - 4), face.end - Vector2(4, 4), Color("93643b"), 4, true)
	for i in 3:
		var x := fmod(cell * 23.0 + i * 43.0 + 13, 79) / 100.0 + 0.1
		var y := fmod(cell * 17.0 + i * 31.0 + 29, 73) / 100.0 + 0.1
		var c := face.position + face.size * Vector2(x, y)
		ci.draw_circle(c, maxf(1.4, r.size.x * (0.015 + i * 0.006)), Color("93683f"))
	if r.size.x > 70:
		var c := face.get_center() + Vector2(face.size.x * 0.16, -face.size.y * 0.06)
		ci.draw_polyline(PackedVector2Array([c + Vector2(-12, -7), c, c + Vector2(-5, 14)]), Color("a27143"), 2, true)
