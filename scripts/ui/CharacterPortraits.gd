extends RefCounted
## Complete painted characters and non-destructive normalized avatar crops.
## Presentation-only: legacy role IDs and gameplay configuration stay unchanged.
const CONFIG := "res://assets/characters/portraits.json"
const TextureCache := preload("res://scripts/resources/TextureCache.gd")
static var _catalog: Dictionary = {}
static var _cache = TextureCache.new(24 * 1024 * 1024)

static func catalog() -> Dictionary:
	if _catalog.is_empty():
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
		if value is Dictionary and value.get("roles") is Array and value.get("characters") is Dictionary:
			_catalog = value
		else:
			push_error("Invalid character portrait catalog")
	return _catalog

static func character_id(role: int) -> String:
	var roles: Array = catalog().get("roles", [])
	return str(roles[posmod(role, roles.size())]) if not roles.is_empty() else ""

static func definition(role: int) -> Dictionary:
	return catalog().get("characters", {}).get(character_id(role), {})

static func person_name(role: int) -> String:
	return str(definition(role).get("name", "族人"))

static func texture(role: int) -> Texture2D:
	if "--replay-worker" in OS.get_cmdline_user_args(): return null
	var path := str(definition(role).get("art", ""))
	return _cache.fetch(path) if path != "" else null

static func fitted_rect(texture_size: Vector2, bounds: Rect2) -> Rect2:
	var scale := minf(bounds.size.x / texture_size.x, bounds.size.y / texture_size.y)
	var size := texture_size * scale
	return Rect2(bounds.get_center() - size * 0.5, size)

static func draw(ci: CanvasItem, role: int, bounds: Rect2) -> void:
	var art := texture(role)
	if art != null:
		ci.draw_texture_rect(art, fitted_rect(art.get_size(), bounds), false)

static func chest(ci: CanvasItem, role: int, bounds: Rect2) -> void:
	var art := texture(role)
	if art == null: return
	var crop: Array = definition(role).get("chest", [0.08, 0.0, 0.84, 0.65])
	var source := Rect2(Vector2(float(crop[0]), float(crop[1])) * art.get_size(),
		Vector2(float(crop[2]), float(crop[3])) * art.get_size())
	ci.draw_texture_rect_region(art, fitted_rect(source.size, bounds), source)

static func face(ci: CanvasItem, role: int, center: Vector2, diameter: float) -> void:
	var art := texture(role)
	if art == null: return
	var crop: Array = definition(role).get("avatar", [0.2, 0.0, 0.6, 0.45])
	var uv_origin := Vector2(float(crop[0]), float(crop[1]))
	var uv_size := Vector2(float(crop[2]), float(crop[3]))
	var points := PackedVector2Array()
	var uv := PackedVector2Array()
	for i in 64:
		var unit := Vector2.from_angle(TAU * float(i) / 64.0)
		points.append(center + unit * diameter * 0.5)
		uv.append(uv_origin + (unit * 0.5 + Vector2.ONE * 0.5) * uv_size)
	ci.draw_polygon(points, PackedColorArray([Color.WHITE]), uv, art)
