extends SceneTree

func _initialize() -> void:
	check.call_deferred()

func check() -> void:
	var path := "res://assets/items/anim.json"
	if not FileAccess.file_exists(path):
		push_error("Export is missing the item manifest")
		quit(1)
		return
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var checked := 0
	for id in manifest["ids"]:
		for rim in [0, 1]:
			for frame in int(manifest["frames"]):
				var file := "res://assets/items/png/%s_r%d_%d.png" % [id, rim, frame]
				var img := Image.new()
				if not FileAccess.file_exists(file) or img.load_png_from_buffer(FileAccess.get_file_as_bytes(file)) != OK or img.get_used_rect().size == Vector2i.ZERO:
					push_error("Missing, invalid, or blank exported frame: " + file)
					quit(1)
					return
				checked += 1
	var items := root.get_node("Items")
	if items._tex.size() != manifest["ids"].size():
		push_error("ItemAnim did not load every exported item")
		quit(1)
		return
	for id in manifest["ids"]:
		for rim in [0, 1]:
			if not items._tex[id].has(rim) or items._tex[id][rim].size() != int(manifest["frames"]):
				push_error("Incomplete ItemAnim frame cache: " + str(id))
				quit(1)
				return
	var board_paths := ["floor", "cracks", "fragments"]
	for frame in 4:
		board_paths.append("frame_%d" % frame)
		board_paths.append("rocks_%d" % frame)
	for name in board_paths:
		var texture = load("res://assets/board/%s.png" % name)
		if not texture is Texture2D or texture.get_image().get_used_rect().size == Vector2i.ZERO:
			push_error("Missing or blank board texture: " + name)
			quit(1)
			return
		if str(name).begins_with("rocks_"):
			for index in 63:
				var region := Rect2i((index % 9) * 128, (index / 9) * 128, 128, 128)
				if texture.get_image().get_region(region).get_used_rect().size == Vector2i.ZERO:
					push_error("Blank rock atlas cell: %s/%d" % [name, index])
					quit(1)
					return
	var extra_paths: Array = ["res://assets/events/moon/vines.svg", "res://assets/events/ufo/saucer.svg", "res://assets/events/entries/banana.svg", "res://assets/events/entries/ruins.svg", "res://assets/events/entries/seven.svg", "res://assets/ui/energy_chest.svg"]
	var events: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/merge_events.json"))
	for season in events["seasons"]:
		extra_paths.append(str(season["theme"]["point_icon"]))
		for entry in season["chain"]: extra_paths.append(str(entry["icon"]))
	var chests: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/choice_chests.json"))
	for chest in chests.values(): extra_paths.append(str(chest["icon"]))
	for file in extra_paths:
		var tex = load(str(file))
		if not tex is Texture2D or tex.get_image().get_used_rect().size == Vector2i.ZERO:
			push_error("Missing or blank event/chest texture: " + str(file))
			quit(1)
			return
	print("PASS: %d activity/chest textures loaded from export" % extra_paths.size())
	var moon = load("res://scripts/ui/MoonArt.gd")
	for key in moon.NAMES:
		var tex: Texture2D = moon.texture(key)
		if tex == null or tex.get_image().get_used_rect().size == Vector2i.ZERO:
			push_error("Missing moon prerender: " + str(key))
			quit(1)
			return
	if moon.texture("tiles").get_size() != Vector2(512, 3072):
		push_error("Moon tile atlas dimensions changed")
		quit(1)
		return
	print("PASS: 11 baked moon textures and 96 tile regions exported")
	for config_path in ["res://data/daily_deals.json", "res://data/ufo_offer.json", "res://data/race.json"]:
		if not FileAccess.file_exists(config_path):
			push_error("Missing feature config: "+config_path)
			quit(1)
			return
	var seven: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/seven_day.json"))
	if seven.get("days", []).size() != 7:
		push_error("Seven-day task configuration missing from export")
		quit(1)
		return
	for day in seven["days"]:
		if day["tasks"].size() != 5:
			push_error("Every task page must contain five tasks")
			quit(1)
			return
	print("PASS: seven task pages and 35 tasks exported")
	print("PASS: 11 board textures loaded; 252 rock frames verified")
	print("PASS: %d exported PNG frames decoded; %d item animations loaded" % [checked, items._tex.size()])
	quit(0)
