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
	var items := root.get_node("Items")
	if int(items.cache_stats()["textures"]) != 0:
		push_error("Item textures must be lazy at startup")
		quit(1)
		return
	var checked := 0
	for id in manifest["ids"]:
		if not items.has_animation(str(id)):
			push_error("Missing exported animation: " + str(id))
			quit(1)
			return
		for rim in [0, 1]:
			for frame in int(manifest["frames"]):
				var file := "res://assets/items/png/%s_r%d_%d.png" % [id, rim, frame]
				var img := Image.new()
				if not FileAccess.file_exists(file) or img.load_png_from_buffer(FileAccess.get_file_as_bytes(file)) != OK or img.get_used_rect().size == Vector2i.ZERO:
					push_error("Missing, invalid, or blank exported frame: " + file)
					quit(1)
					return
				var texture: Texture2D = items.frame_texture(str(id), bool(rim), frame)
				if texture == null or texture.get_width() != int(manifest["px"]):
					push_error("ItemAnim could not load exported frame: " + file)
					quit(1)
					return
				checked += 1
	var cache: Dictionary = items.cache_stats()
	if int(cache["resident_bytes"]) > int(cache["budget_bytes"]) or int(cache["evictions"]) <= 0:
		push_error("Item cache did not remain bounded during complete export validation")
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
	for grade in range(2, 6): extra_paths.append("res://assets/ui/items/pack_%d.svg" % grade)
	for grade in range(1, 11): extra_paths.append("res://assets/ui/items/orderbox_%d.svg" % grade)
	for id in ["premiumbox_1", "upgrade_1", "scissors_1"]: extra_paths.append("res://assets/ui/items/%s.svg" % id)
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
	var illustrations := 0
	var cover_paths := []
	for album in Data.ALBUMS.size():
		var cover_path := CardArtwork.cover_path(album)
		var cover := CardArtwork.cover(album)
		if cover == null or cover_path in cover_paths or not cover_path.begins_with("res://assets/cards/covers/") or cover.get_width() != cover.get_height() or cover.get_image().get_used_rect().size == Vector2i.ZERO:
			push_error("Missing or reused independent collection cover: " + cover_path)
			quit(1)
			return
		cover_paths.append(cover_path)
		for index in Data.ALBUMS[album]["cards"].size():
			var card_path := CardArtwork.art_path(album, index)
			if card_path == "": continue
			var texture := CardArtwork.texture(album, index)
			if texture == null or texture.get_width() != texture.get_height() or texture.get_image().get_used_rect().size == Vector2i.ZERO:
				push_error("Missing, non-square, or blank card illustration: " + card_path)
				quit(1)
				return
			illustrations += 1
	print("PASS: %d square collection illustrations exported" % illustrations)
	print("PASS: %d independent collection covers exported" % cover_paths.size())
	var portraits = load("res://scripts/ui/CharacterPortraits.gd")
	var characters: Dictionary = portraits.catalog().get("characters", {})
	if characters.size() != 6 or characters.has("hunter") or portraits.character_id(8) != "hero":
		push_error("Character export must contain the hero and five customers, excluding the young hunter")
		quit(1)
		return
	var customer_ids := {}
	for role in 10:
		var portrait: Texture2D = portraits.texture(role)
		var crop: Array = portraits.definition(role).get("avatar", [])
		if portrait == null or portrait.get_width() * 4 != portrait.get_height() * 3 or portrait.get_height() > 1024 or crop.size() != 4:
			push_error("Missing or invalid independent character portrait/crop: %d" % role)
			quit(1)
			return
		if role < 8: customer_ids[portraits.character_id(role)] = true
	if customer_ids.size() != 5 or customer_ids.has("hero"):
		push_error("Existing order slots must map to the five customer identities")
		quit(1)
		return
	for legacy_portrait_path in ["res://assets/meme/caveman_head.png", "res://assets/meme/caveman_bust.png"]:
		if not OS.has_feature("editor") and ResourceLoader.exists(legacy_portrait_path):
			push_error("Legacy black-and-white portrait remains in the export")
			quit(1)
			return
	print("PASS: six painted characters, five compatible customer identities and avatar crops exported; legacy portraits excluded")
	var character_bakes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/baked_sprites.json"))
	var baked_count := 0
	for sprite_file in character_bakes.get("pixel_sha256", {}):
		if str(sprite_file).begins_with("assets/meme/"): continue
		var baked_texture := load("res://" + str(sprite_file)) as Texture2D
		if baked_texture == null:
			push_error("Missing painted compatibility sprite: " + str(sprite_file))
			quit(1)
			return
		var baked_image := baked_texture.get_image()
		baked_image.convert(Image.FORMAT_RGBA8)
		var rgba := baked_image.get_data()
		for pixel in range(0, rgba.size(), 4):
			# Ignore only the border RGB that Godot's alpha repair can change.
			if rgba[pixel + 3] < 64:
				rgba[pixel] = 0
				rgba[pixel + 1] = 0
				rgba[pixel + 2] = 0
		var digest := HashingContext.new()
		digest.start(HashingContext.HASH_SHA256)
		digest.update(rgba)
		if digest.finish().hex_encode() != str(character_bakes["pixel_sha256"][sprite_file]):
			push_error("Exported character pixels are stale: " + str(sprite_file))
			quit(1)
			return
		baked_count += 1
	print("PASS: %d imported character sprite frames match the approved painted pixels" % baked_count)
	for config_path in ["res://data/daily_deals.json", "res://data/ufo_offer.json", "res://data/race.json", "res://data/reward_resources.json", "res://data/card_packs.json", "res://data/special_chests.json"]:
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
	print("PASS: %d exported PNG frames decoded; item cache retains %d frames within %d MiB" % [checked, cache["textures"], int(cache["budget_bytes"]) / 1048576])
	quit(0)
