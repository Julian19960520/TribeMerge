class_name SpecialChests
extends RefCounted

const ORDER_SLOT := "@order"
static func config() -> Dictionary:
	return Data.ConfigFiles.shared("res://data/special_chests.json")

static func is_order(id: String) -> bool:
	return Data.chain(id) == "orderbox" and Data.is_board_item(id)

static func order_definition(id: String) -> Dictionary:
	return definition(id) if is_order(id) else {}

static func definition(id: String) -> Dictionary:
	var levels: Array = config().get(Data.chain(id), {}).get("levels", [])
	return levels[Data.lv(id) - 1] if Data.lv(id) >= 1 and Data.lv(id) <= levels.size() else {}

static func count(id: String) -> int:
	var def := definition(id)
	return def.get("items", []).size() if def.has("items") else int(def.get("count", 0))

static func needs(game) -> Dictionary:
	var needed := {}
	for order in game.orders:
		if str(order.get("kind", "")) == "craft" and str(order.get("phase", "need")) != "need": continue
		for entry in order.get("items", []):
			var id := str(entry)
			if Data.is_board_item(id) and Data.type_of(id) in ["item", "dish"]: needed[id] = int(needed.get(id, 0)) + 1
	for cell in game.board:
		var id := str(cell.get("id", ""))
		if int(cell.get("lock", 0)) == 0 and not cell.get("ck") is Dictionary and needed.has(id): needed[id] = maxi(0, int(needed[id]) - 1)
	for entry in game.inv + game.stash:
		var id := str(entry)
		if needed.has(id): needed[id] = maxi(0, int(needed[id]) - 1)
	for id in needed.keys():
		if int(needed[id]) <= 0: needed.erase(id)
	return needed

static func order_weights(id: String, needed: Dictionary) -> Dictionary:
	var out := {}
	var bias := float(order_definition(id).get("high_tier_bias", 0))
	for item in needed: out[item] = float(needed[item]) * pow(float(maxi(1, Data.lv(str(item)))), bias)
	return out

static func weighted(weights: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for value in weights.values(): total += float(value)
	if total <= 0: return ""
	var roll := rng.randf() * total
	for key in weights:
		roll -= float(weights[key])
		if roll < 0: return str(key)
	return str(weights.keys().back())

static func order_drop(id: String, game) -> String:
	return weighted(order_weights(id, needs(game)), game.random_for("order_chests"))

static func contents(id: String, game = null) -> Array:
	if is_order(id):
		var out := []
		out.resize(int(order_definition(id)["count"]))
		out.fill(ORDER_SLOT)
		return out
	var def := definition(id)
	if Data.chain(id) == "energybox": return def.get("items", []).duplicate()
	if Data.chain(id) == "chest": return wicker_contents(id, game)
	if Data.chain(id) != "premiumbox": return []
	var rng: RandomNumberGenerator = game.random_for("premium_chests")
	var tier_weights := {}
	for i in def["tier_weights"].size(): tier_weights[str(i + 1)] = def["tier_weights"][i]
	var out := []
	for i in int(def["count"]):
		var resource := str(def["guaranteed_resources"][i]) if i < def["guaranteed_resources"].size() else weighted(def["resource_weights"], rng)
		out.append(resource + "_" + weighted(tier_weights, rng))
	return out

static func wicker_contents(id: String, game) -> Array:
	var def := definition(id)
	var pool: Array = def["base_pool"].duplicate()
	var opened := Data.unlocked_lines(game.level)
	for line in opened:
		for tier in def["main_tiers"]: pool.append("%s_%d" % [line["main"], tier])
		for tier in def["sub_tiers"]: pool.append("%s_%d" % [line["sub"], tier])
	var rng: RandomNumberGenerator = game.random_for("chests")
	var out := []
	for i in int(def["count"]):
		if not opened.is_empty() and rng.randf() < float(def["gen_chance"]):
			out.append("%s_%d" % [opened[rng.randi() % opened.size()]["gen"], int(def["gen_tier"])])
		else:
			out.append(pool[rng.randi() % pool.size()])
	return out
