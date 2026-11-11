extends RefCounted
## Shared visual language for a completed merge and its lighter hover preview.

static func paint(ci: CanvasItem, center: Vector2, t: float, seed: float,
		hover: bool = false, alpha: float = 1.0, unit: float = 1.0) -> void:
	var fade := (1.0 - t) * alpha
	var radius := (30.0 + 22.0 * t if hover else 20.0 + 70.0 * t) * unit
	var width := ((4.0 if hover else 6.0) * (1.0 - t) + 1.0) * unit
	ci.draw_arc(center, radius, 0, TAU, 32, Color(1, 0.9, 0.4, fade), width, true)
	var stars := 5 if hover else 8
	for k in stars:
		var angle := TAU * float(k) / float(stars) + seed
		var distance := (34.0 + 22.0 * t if hover else 30.0 + 80.0 * t) * unit
		var point := center + Vector2(cos(angle), sin(angle)) * distance
		var star_size := ((6.0 if hover else 10.0) * (1.0 - t) + 2.0) * unit
		Sprites.at(ci, "board_burst_star", point, star_size / 12.0, 0.0, Color(Art.FIRE2, fade))
	var dots := 3 if hover else 5
	for k in dots:
		var angle := TAU * float(k) / float(dots) + 0.4 + seed
		var distance := (30.0 + 22.0 * t if hover else 20.0 + 50.0 * t) * unit
		var fall := (10.0 if hover else 30.0) * t * t * unit
		var point := center + Vector2(cos(angle), sin(angle)) * distance + Vector2(0, fall)
		var dot_size := (3.0 * (1.0 - t) + 1.0 if hover else 8.0 * (1.0 - t) + 2.0) * unit
		ci.draw_circle(point, dot_size, Color(1, 1, 1, 0.8 * fade))
