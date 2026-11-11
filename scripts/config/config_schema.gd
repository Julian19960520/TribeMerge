@tool
extends RefCounted
## Shared startup/editor/release validation, independent of Data and mutable game state.
var errors := PackedStringArray()
var docs: Dictionary
var items := {}
var chains := {}
var chain_rows := {}
var lines := {}

static func validate(documents: Dictionary) -> PackedStringArray:
	var validator = new()
	validator.docs = documents
	validator._validate()
	return validator.errors

func _validate() -> void:
	var arrays := ["lines", "chains", "people", "albums", "amber_packs", "builds", "store", "dishes", "daily_deals"]
	for name in docs:
		var expected := TYPE_ARRAY if name in arrays else TYPE_DICTIONARY
		if typeof(docs[name]) != expected: _error(str(name), "expected %s" % type_string(expected))
	if not errors.is_empty(): return
	var required := {
		"story": {"levels": TYPE_ARRAY}, "levels": {"levels": TYPE_ARRAY},
		"pass": {"season": TYPE_DICTIONARY, "levels": TYPE_ARRAY},
		"random_orders": {"curves": TYPE_ARRAY, "slots": TYPE_ARRAY},
		"unlocks": {"levels": TYPE_INT, "rows": TYPE_ARRAY},
		"card_packs": {"cards_per_pack": TYPE_INT, "card_stars_by_slot": TYPE_ARRAY, "packs": TYPE_ARRAY},
		"seven_day": {"id": TYPE_STRING, "days": TYPE_ARRAY, "milestones": TYPE_ARRAY},
		"merge_events": {"version": TYPE_INT, "seasons": TYPE_ARRAY},
		"duel_race": {"order_thresholds": TYPE_ARRAY, "order_points": TYPE_ARRAY, "opponent_seconds": TYPE_ARRAY, "milestones": TYPE_ARRAY},
		"tiger_escape": {"stages": TYPE_ARRAY, "bots": TYPE_DICTIONARY},
		"fossil_dig": {"shapes": TYPE_ARRAY, "milestones": TYPE_ARRAY},
		"store_shell": {"items": TYPE_ARRAY, "refresh_hours": TYPE_INT, "refresh_amber": TYPE_INT},
		"special_chests": {"orderbox": TYPE_DICTIONARY, "premiumbox": TYPE_DICTIONARY, "energybox": TYPE_DICTIONARY, "chest": TYPE_DICTIONARY},
		"offers": {"spree": TYPE_DICTIONARY, "energy": TYPE_DICTIONARY},
		"gift_chain": {"cycle_days": TYPE_INT, "anchor_weekday": TYPE_INT, "visible": TYPE_INT, "steps": TYPE_ARRAY},
		"ufo_offer": {"enabled": TYPE_BOOL}, "race": {"rewards": TYPE_ARRAY, "shadow": TYPE_DICTIONARY, "names": TYPE_ARRAY},
		"replay_economy": {"album_reward": TYPE_ARRAY},
		"replay_build": {"protocol": TYPE_INT, "godot": TYPE_STRING, "code_sha256": TYPE_STRING}}
	for name in required: _fields(docs[name], name, required[name])
	if not errors.is_empty(): return
	_items()
	if not errors.is_empty(): return
	_core()
	if not errors.is_empty(): return
	_progression()
	if not errors.is_empty(): return
	_chests()
	if not errors.is_empty(): return
	_events()
	if not errors.is_empty(): return
	for name in docs: _walk(docs[name], str(name))

func _error(at: String, message: String) -> void:
	errors.append("%s: %s" % [at, message])

func _fields(value: Variant, at: String, fields: Dictionary) -> bool:
	if not value is Dictionary:
		_error(at, "expected object")
		return false
	var valid := true
	for key in fields:
		if not value.has(key) or typeof(value[key]) != int(fields[key]):
			_error(at + "." + str(key), "expected %s" % type_string(int(fields[key])))
			valid = false
	return valid

func _number(value: Variant, at: String, minimum: float, maximum := INF, integral := false) -> bool:
	if not (value is int or value is float) or not is_finite(float(value)):
		_error(at, "expected finite number")
		return false
	if float(value) < minimum or float(value) > maximum or (integral and float(value) != floor(float(value))):
		_error(at, "expected %s in [%s, %s]" % ["integer" if integral else "number", minimum, maximum])
		return false
	return true

func _positive(value: Variant, at: String) -> bool:
	return _number(value, at, 1, INF, true)

func _item(value: Variant, at: String, allow_empty := false) -> void:
	if allow_empty and value == "": return
	if not value is String or not items.has(value): _error(at, "unknown item '%s'" % str(value))

func _id(value: Variant, at: String, registry: Dictionary) -> void:
	if not value is String or str(value) == "": _error(at, "expected nonempty id")
	elif registry.has(value): _error(at, "duplicate id '%s'" % value)
	else: registry[value] = true

func _weights(values: Variant, at: String) -> void:
	if not values is Array or values.is_empty():
		_error(at, "expected nonempty weights")
		return
	var total := 0.0
	for i in values.size():
		_number(values[i], "%s[%d]" % [at, i], 0)
		if values[i] is int or values[i] is float: total += float(values[i])
	if total <= 0: _error(at, "weights must have a positive total")

func _items() -> void:
	for i in docs.chains.size():
		var row: Variant = docs.chains[i]
		var at := "chains[%d]" % i
		if not _fields(row, at, {"id": TYPE_STRING, "type": TYPE_STRING, "items": TYPE_ARRAY, "name": TYPE_STRING}): continue
		_id(row.id, at + ".id", chains)
		chain_rows[row.id] = row
		if row["items"].is_empty(): _error(at + ".items", "chain cannot be empty")
		for tier in row["items"].size():
			if not row["items"][tier] is String or str(row["items"][tier]) == "": _error(at + ".items", "item names must be nonempty strings")
			items["%s_%d" % [row.id, tier + 1]] = true
		if row.has("value"):
			if not row.value is Array or row.value.size() != row["items"].size(): _error(at + ".value", "one value required per tier")
			else:
				for value in row.value: _number(value, at + ".value", 0, INF, true)
	for row in docs.dishes:
		if not _fields(row, "dishes", {"id": TYPE_STRING, "name": TYPE_STRING, "mats": TYPE_ARRAY, "secs": TYPE_INT, "unlock": TYPE_INT}): continue
		_id(row.id, "dishes.id", items)
		_positive(row.secs, "dishes.secs")
		_positive(row.unlock, "dishes.unlock")
		if row.mats.is_empty(): _error("dishes.mats", "recipe cannot be empty")
	for id in docs.reward_resources:
		_id(id, "reward_resources." + str(id), items)
		_fields(docs.reward_resources[id], "reward_resources." + str(id), {"type": TYPE_STRING, "name": TYPE_STRING, "description": TYPE_STRING})
	for row in docs.dishes:
		if row is Dictionary and row.get("mats") is Array:
			for id in row.mats: _item(id, "dishes.mats")
	for row in docs.lines:
		if not _fields(row, "lines", {"id": TYPE_STRING, "gen": TYPE_STRING, "main": TYPE_STRING, "sub": TYPE_STRING, "unlock": TYPE_INT}): continue
		_id(row.id, "lines.id", lines)
		_positive(row.unlock, "lines.unlock")
		for key in ["gen", "main", "sub"]:
			if row[key] != "" and not chains.has(row[key]): _error("lines." + key, "unknown chain")
	if not errors.is_empty(): return
	for i in docs.chains.size():
		var row: Dictionary = docs.chains[i]
		var at := "chains[%d]" % i
		if row.get("line", "") != "" and not lines.has(row.line): _error(at + ".line", "unknown production line")
		if not row.has("prod"): continue
		if not row.prod is Array or row.prod.size() != row["items"].size():
			_error(at + ".prod", "one production slot required per tier")
			continue
		for slot in row.prod:
			if slot == null: continue
			if not _fields(slot, at + ".prod", {"drops": TYPE_ARRAY}): continue
			var weights := []
			for drop in slot.drops:
				if not _fields(drop, at + ".prod.drops", {"id": TYPE_STRING, "p": TYPE_INT}): continue
				_item(drop.id, at + ".prod.drops.id")
				weights.append(drop.p)
			_weights(weights, at + ".prod.drops.p")
			for key in ["charges", "refill_min"]:
				if slot.has(key): _positive(slot[key], at + ".prod." + key)

func _core() -> void:
	var rules: Dictionary = docs.rules
	if not _fields(rules, "rules", {"merge_coin": TYPE_DICTIONARY, "merge_bubble": TYPE_DICTIONARY, "merge_sand": TYPE_DICTIONARY, "merge_resource_drops": TYPE_DICTIONARY, "merge_resource_lines": TYPE_ARRAY, "craft_sand": TYPE_ARRAY}): return
	for key in ["cols", "rows", "max_energy", "regen_sec", "token_step", "xp_base", "xp_div", "craft_level", "storage_initial", "rush_sec"]: _positive(rules.get(key), "rules." + key)
	if not errors.is_empty(): return
	var size := int(rules["cols"]) * int(rules["rows"])
	var board: Dictionary = docs.board
	if _fields(board, "board", {"cells": TYPE_ARRAY, "locks": TYPE_ARRAY, "rewards": TYPE_DICTIONARY}):
		if board.cells.size() != size: _error("board.cells", "expected %d cells" % size)
		if board.locks.size() != size: _error("board.locks", "expected %d locks" % size)
		for i in board.cells.size(): _item(board.cells[i], "board.cells[%d]" % i, true)
		for i in board.locks.size(): _number(board.locks[i], "board.locks[%d]" % i, 0, 2, true)
		for key in board.rewards:
			if not str(key).is_valid_int() or int(key) < 0 or int(key) >= size: _error("board.rewards." + str(key), "cell out of bounds")
			_reward(board.rewards[key], "board.rewards." + str(key))
	for key in ["order_cap_at", "craft_cap_at"]:
		var values: Variant = rules.get(key)
		if not values is Array or values.is_empty(): _error("rules." + key, "expected nonempty level thresholds")
		else:
			var previous := 0
			for value in values:
				if not _positive(value, "rules." + key): continue
				if int(value) < previous: _error("rules." + key, "thresholds must be sorted")
				previous = int(value)
	for key in ["merge_coin", "merge_bubble", "merge_sand"]:
		if not rules.get(key) is Dictionary: _error("rules." + key, "expected object"); continue
		_number(rules[key].get("chance"), "rules." + key + ".chance", 0, 1)
		for row in rules[key].get("tiers", []):
			if not row is Array or row.size() != 2: _error("rules." + key + ".tiers", "expected [minimum tier, item id]")
			else:
				_positive(row[0], "rules." + key + ".tiers")
				_item(row[1], "rules." + key + ".tiers")
	for scope in rules.get("merge_resource_drops", {}):
		if not rules.merge_resource_drops[scope] is Array:
			_error("rules.merge_resource_drops." + str(scope), "expected drop array")
			continue
		var total := 0.0
		for row in rules.merge_resource_drops[scope]:
			if not _fields(row, "rules.merge_resource_drops", {"item": TYPE_STRING}): continue
			_item(row.item, "rules.merge_resource_drops.item")
			if _number(row.get("chance"), "rules.merge_resource_drops.chance", 0, 1): total += float(row["chance"])
		if total > 1.000001: _error("rules.merge_resource_drops." + str(scope), "combined chance exceeds 1")
	for row in rules.get("craft_sand", []):
		if row is Array and row.size() == 2: _item(row[1], "rules.craft_sand")
		else: _error("rules.craft_sand", "expected [seconds, item id]")
	for line in rules.get("merge_resource_lines", []):
		if not lines.has(line): _error("rules.merge_resource_lines", "unknown production line")
	var random: Dictionary = docs.random_orders
	if _fields(random, "random_orders", {"curves": TYPE_ARRAY, "slots": TYPE_ARRAY}):
		if random.curves.is_empty() or random.slots.is_empty(): _error("random_orders", "curves and slots cannot be empty")
		for slot in random.slots: _number(slot, "random_orders.slots", 0, 1)
		for curve in random.curves:
			if _fields(curve, "random_orders.curves", {"diff": TYPE_ARRAY}):
				if curve.diff.is_empty(): _error("random_orders.curves.diff", "curve cannot be empty")
				for value in curve.diff: _positive(value, "random_orders.curves.diff")
	if _fields(docs.unlocks, "unlocks", {"levels": TYPE_INT, "rows": TYPE_ARRAY}):
		var used := {}
		for row in docs.unlocks.rows:
			if not _fields(row, "unlocks.rows", {"id": TYPE_STRING, "open": TYPE_ARRAY}): continue
			_id(row.id, "unlocks.rows.id", used)
			if not chains.has(row.id): _error("unlocks.rows.id", "unknown chain")
			if row.open.size() != int(docs.unlocks.levels): _error("unlocks.rows.open", "one flag required per level")
			for flag in row.open: _number(flag, "unlocks.rows.open", 0, 1, true)

func _progression() -> void:
	var used := {}
	for row in docs.builds:
		if not _fields(row, "builds", {"id": TYPE_STRING, "parts": TYPE_ARRAY}): continue
		_id(row.id, "builds.id", used)
		var part_ids := {}
		for part in row.parts:
			if _fields(part, "builds.parts", {"id": TYPE_STRING, "cost": TYPE_INT, "rewards": TYPE_ARRAY}):
				_id(part.id, "builds.parts.id", part_ids)
				_number(part.cost, "builds.parts.cost", 0, INF, true)
	for name in ["store", "daily_deals"]:
		var deal_keys := {}
		for row in docs[name]:
			if not _fields(row, name, {"id": TYPE_STRING, "price": TYPE_INT, "stock": TYPE_INT}): continue
			_item(row.id, name + ".id")
			_number(row.price, name + ".price", 0, INF, true)
			_positive(row.stock, name + ".stock")
			if name == "daily_deals": _id(row.get("key"), name + ".key", deal_keys)
	if _fields(docs.store_shell, "store_shell", {"items": TYPE_ARRAY, "refresh_hours": TYPE_INT, "refresh_amber": TYPE_INT}):
		_positive(docs.store_shell.refresh_hours, "store_shell.refresh_hours")
		_positive(docs.store_shell.refresh_amber, "store_shell.refresh_amber")
		for row in docs.store_shell["items"]:
			if _fields(row, "store_shell.items", {"id": TYPE_STRING, "price": TYPE_INT, "stock": TYPE_INT}):
				_item(row.id, "store_shell.items.id")
				_number(row.price, "store_shell.items.price", 0, INF, true)
				_positive(row.stock, "store_shell.items.stock")
	var previous := 0
	for row in docs.levels.get("levels", []):
		if not _fields(row, "levels.levels", {"level": TYPE_INT, "rewards": TYPE_ARRAY}): continue
		if int(row.level) <= previous: _error("levels.levels", "levels must be unique and increasing")
		previous = int(row.level)
	for level in docs.story.get("levels", []):
		if not _fields(level, "story.levels", {"level": TYPE_INT, "orders": TYPE_ARRAY}): continue
		_positive(level.level, "story.levels.level")
		for order in level.orders:
			if not _fields(order, "story.orders", {"who": TYPE_INT, "items": TYPE_ARRAY, "xp": TYPE_INT, "shell": TYPE_INT, "rewards": TYPE_ARRAY}): continue
			_number(order.who, "story.orders.who", 0, docs.people.size() - 1, true)
			for id in order["items"]: _item(id, "story.orders.items")
			_number(order.xp, "story.orders.xp", 0, INF, true)
			_number(order.shell, "story.orders.shell", 0, INF, true)
	for row in docs["pass"].get("levels", []):
		if _fields(row, "pass.levels", {"need": TYPE_INT, "free": TYPE_ARRAY, "prem": TYPE_ARRAY, "super": TYPE_ARRAY}): _positive(row.need, "pass.levels.need")
	if _fields(docs["pass"].get("season"), "pass.season", {"days": TYPE_INT, "start": TYPE_STRING}): _positive(docs["pass"].season.days, "pass.season.days")
	for row in docs.albums:
		if _fields(row, "albums", {"name": TYPE_STRING, "cards": TYPE_ARRAY}):
			if row.cards.size() != docs.card_packs.get("card_stars_by_slot", []).size(): _error("albums.cards", "card slots and star slots must have the same length")
			for card in row.cards:
				if not card is String or str(card) == "": _error("albums.cards", "card names must be nonempty strings")
			for field in ["art", "texts"]:
				if not row.has(field): continue
				if not row[field] is Array or row[field].size() != row.cards.size():
					_error("albums." + field, "one entry is required per card")
					continue
				for value in row[field]:
					if not value is String or str(value) == "": _error("albums." + field, "entries must be nonempty strings")
					elif field == "art" and not str(value).begins_with("res://assets/cards/"): _error("albums.art", "expected a card asset resource path")
	var packs: Dictionary = docs.card_packs
	if _fields(packs, "card_packs", {"cards_per_pack": TYPE_INT, "card_stars_by_slot": TYPE_ARRAY, "packs": TYPE_ARRAY}):
		_positive(packs.cards_per_pack, "card_packs.cards_per_pack")
		for star in packs.card_stars_by_slot: _number(star, "card_packs.card_stars_by_slot", 1, 5, true)
		for row in packs.packs:
			if _fields(row, "card_packs.packs", {"id": TYPE_STRING, "weights": TYPE_ARRAY}):
				_item(row.id, "card_packs.packs.id")
				if row.weights.size() != 5: _error("card_packs.packs.weights", "expected five star weights")
				_weights(row.weights, "card_packs.packs.weights")

## Every chest grade has one explicit definition; there is no flat legacy format.
func _chests() -> void:
	for family in ["orderbox", "premiumbox", "energybox", "chest"]:
		var at: String = "special_chests." + family
		var definition: Dictionary = docs.special_chests[family]
		if not _fields(definition, at, {"levels": TYPE_ARRAY}): continue
		for key in definition:
			if key != "levels" and not str(key).begins_with("_"): _error(at + "." + str(key), "grade fields belong inside levels")
		if not chain_rows.has(family):
			_error(at, "missing chest item chain")
			continue
		if definition.levels.size() != chain_rows[family]["items"].size(): _error(at + ".levels", "one definition is required for every chest grade")
		var previous_count := 0
		for index in definition.levels.size():
			var row: Variant = definition.levels[index]
			var level_at := "%s.levels[%d]" % [at, index]
			if not row is Dictionary:
				_error(level_at, "expected object")
				continue
			var count := 0
			if family == "energybox":
				if not _fields(row, level_at, {"items": TYPE_ARRAY}): continue
				count = row["items"].size()
				for id in row["items"]:
					_item(id, level_at + ".items")
					var resource: Dictionary = chain_rows.get(str(id).get_slice("_", 0), {})
					if resource.get("type") != "energy": _error(level_at + ".items", "energy chests can contain only energy items")
			else:
				if not _fields(row, level_at, {"count": TYPE_INT}): continue
				count = row.count
				_positive(count, level_at + ".count")
				match family:
					"orderbox": _number(row.get("high_tier_bias"), level_at + ".high_tier_bias", 0)
					"premiumbox": _premium_chest(row, level_at)
					"chest": _wicker_chest(row, level_at)
			if count <= previous_count: _error(level_at, "higher chest grades must provide more items")
			previous_count = count
	if not chain_rows.has("choice"):
		_error("choice_chests", "missing choice item chain")
		return
	if docs.choice_chests.size() != chain_rows.choice["items"].size(): _error("choice_chests", "one definition is required for every choice grade")
	for grade in chain_rows.choice["items"].size():
		var id := "choice_%d" % (grade + 1)
		if not docs.choice_chests.has(id):
			_error("choice_chests." + id, "missing grade definition")
			continue
		var row: Variant = docs.choice_chests[id]
		if not _fields(row, "choice_chests." + id, {"title": TYPE_STRING, "choices": TYPE_ARRAY, "icon": TYPE_STRING}): continue
		if row.choices.size() != 3: _error("choice_chests." + id + ".choices", "expected exactly three choices")
		var seen := {}
		for choice in row.choices:
			_item(choice, "choice_chests." + id + ".choices")
			if seen.has(choice): _error("choice_chests." + id + ".choices", "choices must be distinct")
			seen[choice] = true
	for id in docs.choice_chests:
		if not str(id).begins_with("choice_") or not items.has(id): _error("choice_chests." + str(id), "unknown choice chest grade")

func _premium_chest(row: Dictionary, at: String) -> void:
	if not _fields(row, at, {"resource_weights": TYPE_DICTIONARY, "tier_weights": TYPE_ARRAY, "guaranteed_resources": TYPE_ARRAY}): return
	_weights(row.resource_weights.values(), at + ".resource_weights")
	_weights(row.tier_weights, at + ".tier_weights")
	for resource in row.resource_weights:
		var chain: Dictionary = chain_rows.get(resource, {})
		if not chain.get("type") in ["energy", "amber"]:
			_error(at + ".resource_weights", "premium chests can contain only energy or amber chains")
			continue
		if row.tier_weights.size() != chain["items"].size(): _error(at + ".tier_weights", "one weight is required for each resource tier")
	if row.guaranteed_resources.size() > int(row.count): _error(at + ".guaranteed_resources", "guarantees exceed chest capacity")
	for resource in row.guaranteed_resources:
		if not row.resource_weights.has(resource): _error(at + ".guaranteed_resources", "guaranteed resource must belong to the weighted resource pool")

func _wicker_chest(row: Dictionary, at: String) -> void:
	if not _fields(row, at, {"base_pool": TYPE_ARRAY, "main_tiers": TYPE_ARRAY, "sub_tiers": TYPE_ARRAY, "gen_tier": TYPE_INT}): return
	if row.base_pool.is_empty(): _error(at + ".base_pool", "resource pool cannot be empty")
	for id in row.base_pool:
		_item(id, at + ".base_pool")
		if docs.reward_resources.has(id): _error(at + ".base_pool", "chest contents must be physical board items")
	_number(row.get("gen_chance"), at + ".gen_chance", 0, 1)
	for role in ["main", "sub"]:
		var tiers: Array = row[role + "_tiers"]
		if tiers.is_empty(): _error(at + "." + role + "_tiers", "tier list cannot be empty")
		for tier in tiers:
			for line in docs.lines:
				var chain: Dictionary = chain_rows.get(line[role], {})
				_number(tier, at + "." + role + "_tiers", 1, chain.get("items", []).size(), true)
	for line in docs.lines:
		_number(row.gen_tier, at + ".gen_tier", 1, chain_rows[line.gen]["items"].size(), true)

func _events() -> void:
	for name in ["tiger_escape", "duel_race", "fossil_dig", "race"]: _positive(docs[name].get("unlock_level"), name + ".unlock_level")
	var seven: Dictionary = docs.seven_day
	if _fields(seven, "seven_day", {"id": TYPE_STRING, "days": TYPE_ARRAY, "milestones": TYPE_ARRAY}):
		if seven.days.size() != 7: _error("seven_day.days", "expected seven days")
		var task_ids := {}
		for index in seven.days.size():
			var day: Variant = seven.days[index]
			if not _fields(day, "seven_day.days", {"day": TYPE_INT, "tasks": TYPE_ARRAY}): continue
			if int(day.day) != index + 1: _error("seven_day.days.day", "days must be consecutive")
			for task in day.tasks:
				if _fields(task, "seven_day.tasks", {"id": TYPE_STRING, "metric": TYPE_STRING, "target": TYPE_INT, "points": TYPE_INT, "rewards": TYPE_ARRAY}):
					_id(task.id, "seven_day.tasks.id", task_ids)
					_positive(task.target, "seven_day.tasks.target")
					_positive(task.points, "seven_day.tasks.points")
	for row in docs.fossil_dig.get("shapes", []):
		if _fields(row, "fossil_dig.shapes", {"w": TYPE_INT, "h": TYPE_INT, "kind": TYPE_STRING, "name": TYPE_STRING}):
			_number(row.w, "fossil_dig.shapes.w", 1, 12, true)
			_number(row.h, "fossil_dig.shapes.h", 1, 12, true)
	for key in ["dig_cost", "stages", "shovels_per_order"]: _positive(docs.fossil_dig.get(key), "fossil_dig." + key)
	for season in docs.merge_events.get("seasons", []):
		if not _fields(season, "merge_events.seasons", {"id": TYPE_STRING, "board": TYPE_DICTIONARY, "chain": TYPE_ARRAY, "points": TYPE_DICTIONARY}): continue
		var at := "merge_events." + str(season.id)
		var board: Dictionary = season.board
		for key in ["cols", "visible_rows", "total_rows", "reveal_rows"]: _positive(board.get(key), at + ".board." + key)
		if not errors.is_empty(): return
		if int(board.get("visible_rows", 0)) > int(board.get("total_rows", 0)): _error(at + ".board", "visible rows exceed total rows")
		var chain_ids := {}
		for row in season.chain:
			if _fields(row, at + ".chain", {"id": TYPE_STRING, "name": TYPE_STRING}): _id(row.id, at + ".chain.id", chain_ids)
		for layer in board.get("layers", []):
			if _fields(layer, at + ".board.layers", {"rows": TYPE_INT, "tiers": TYPE_ARRAY}):
				_positive(layer.rows, at + ".board.layers.rows")
				for tier in layer.tiers: _number(tier, at + ".board.layers.tiers", 1, season.chain.size(), true)
		if not _fields(season.points, at + ".points", {"spawn_cost": TYPE_INT, "spawn_tier": TYPE_INT, "order_thresholds": TYPE_ARRAY, "order_rewards": TYPE_ARRAY}): continue
		_positive(season.points.get("spawn_cost"), at + ".points.spawn_cost")
		_number(season.points.get("spawn_tier"), at + ".points.spawn_tier", 1, season.chain.size(), true)
		if season.points.get("order_thresholds", []).size() + 1 != season.points.get("order_rewards", []).size(): _error(at + ".points", "one reward required per threshold interval")
	var duel: Dictionary = docs.duel_race
	if duel.get("order_thresholds", []).size() + 1 != duel.get("order_points", []).size(): _error("duel_race.order_points", "one score required per threshold interval")
	for pair in [["target", duel], ["attack_interval_sec", docs.tiger_escape], ["points_per_order", docs.tiger_escape], ["duration_sec", docs.race], ["target", docs.race], ["group_size", docs.race]]: _positive(pair[1].get(pair[0]), "events." + str(pair[0]))
	_number(docs.race.get("podium"), "race.podium", 1, int(docs.race.get("group_size", 0)), true)

func _reward(value: Variant, at: String) -> void:
	if value is String: _item(value, at)
	elif value is Array and value.size() >= 2 and value[0] is String:
		_item(value[0], at + "[0]")
		_positive(value[1], at + "[1]")
		if value.size() > 3 or (value.size() == 3 and not str(value[2]) in ["item", "physical"]): _error(at, "invalid reward delivery mode")
	else: _error(at, "expected item id or [item id, positive amount]")

func _rewards(values: Variant, at: String) -> void:
	if not values is Array: _error(at, "expected reward array"); return
	for i in values.size():
		var value: Variant = values[i]
		if value is Array and not value.is_empty() and value[0] is Array: _rewards(value, "%s[%d]" % [at, i])
		else: _reward(value, "%s[%d]" % [at, i])

func _walk(value: Variant, at: String) -> void:
	if value is Array:
		for i in value.size(): _walk(value[i], "%s[%d]" % [at, i])
	elif value is Dictionary:
		for key in value:
			var location := at + "." + str(key)
			if str(key).begins_with("_") or location == "board.rewards": continue
			if str(key) in ["rewards", "free", "prem", "super", "win_rewards", "lose_rewards", "album_reward"]: _rewards(value[key], location)
			elif str(key) == "opens" and value[key] is Array:
				for id in value[key]: _item(id, location)
			else: _walk(value[key], location)
