extends RefCounted
## Offline CanvasItem command recorder; preserves procedural geometry without a GPU.
var transform := Transform2D.IDENTITY
var paths: Array[String] = []

func draw_set_transform(at: Vector2, rotation := 0.0, scale := Vector2.ONE) -> void:
	transform = Transform2D(rotation, scale, 0.0, at)

func draw_set_transform_matrix(value: Transform2D) -> void:
	transform = value

func _points(points: PackedVector2Array) -> String:
	var out := PackedStringArray()
	for point in points:
		var p := transform * point
		out.append("%.4f,%.4f" % [p.x, p.y])
	return " ".join(out)

func _color(color: Color) -> String:
	return "#" + color.to_html(false)

func draw_colored_polygon(points: PackedVector2Array, color: Color, _uvs = null, _texture = null) -> void:
	paths.append('<polygon points="%s" fill="%s" opacity="%.4f"/>' % [_points(points), _color(color), color.a])

func draw_polyline(points: PackedVector2Array, color: Color, width := 1.0, _antialiased := false) -> void:
	paths.append('<polyline points="%s" fill="none" stroke="%s" stroke-width="%.4f" stroke-linecap="butt" stroke-linejoin="round" opacity="%.4f"/>' % [_points(points), _color(color), float(width) * transform.get_scale().x, color.a])

func draw_line(from: Vector2, to: Vector2, color: Color, width := 1.0, antialiased := false) -> void:
	draw_polyline(PackedVector2Array([from, to]), color, width, antialiased)

func draw_circle(at: Vector2, radius: float, color: Color, filled := true, width := -1.0, antialiased := false) -> void:
	var points := PackedVector2Array()
	for k in 64: points.append(at + Vector2.from_angle(TAU * float(k) / 64) * radius)
	if filled: draw_colored_polygon(points, color)
	else:
		points.append(points[0]); draw_polyline(points, color, width, antialiased)

func draw_arc(at: Vector2, radius: float, start: float, end: float, count: int, color: Color, width := 1.0, antialiased := false) -> void:
	var points := PackedVector2Array()
	for k in count: points.append(at + Vector2.from_angle(lerpf(start, end, float(k) / float(count - 1))) * radius)
	draw_polyline(points, color, width, antialiased)

func svg(side: int) -> String:
	return '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">%s</svg>' % [side, side, side, side, "\n".join(paths)]
