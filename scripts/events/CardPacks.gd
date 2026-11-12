class_name CardPacks
extends RefCounted

static func config() -> Dictionary:
	return Data.ConfigFiles.shared("res://data/card_packs.json")

static func definition(id: String) -> Dictionary:
	for pack in config()["packs"]:
		if str(pack["id"]) == id: return pack
	return {}

static func probabilities(id: String) -> Array:
	var weights: Array = definition(id).get("weights", [])
	var total := 0.0
	for weight in weights: total += float(weight)
	var out := []
	for weight in weights: out.append(float(weight) / total if total > 0.0 else 0.0)
	return out

static func stars(album: int, index: int) -> int:
	var slots: Array = Data.ALBUMS[album].get("stars", config()["card_stars_by_slot"])
	return clampi(int(slots[index]), 1, 5)

static func duplicate_value(album: int, index: int) -> int:
	return int(config()["duplicate_stars_by_rarity"][stars(album, index) - 1])

static func exchange_offer(cost: int) -> Dictionary:
	for offer in config()["star_exchange"]:
		if int(offer["cost"]) == cost: return offer
	return {}

static func star_at_roll(id: String, roll: float) -> int:
	var cursor := 0.0
	var probabilities := probabilities(id)
	for i in probabilities.size():
		cursor += float(probabilities[i])
		if roll < cursor: return i + 1
	return 1

static func draw(id: String, rng: RandomNumberGenerator) -> Array:
	var star := star_at_roll(id, rng.randf())
	var pool := []
	for album in Data.ALBUMS.size():
		for index in Data.ALBUMS[album]["cards"].size():
			if stars(album, index) == star: pool.append([album, index])
	return pool[int(rng.randi() % pool.size())] if not pool.is_empty() else []

static func probability_text(id: String) -> String:
	var out: PackedStringArray = []
	var chances := probabilities(id)
	for i in chances.size():
		if float(chances[i]) > 0.0: out.append("%d星 %.2f%%" % [i + 1, float(chances[i]) * 100.0])
	return "　".join(out)
