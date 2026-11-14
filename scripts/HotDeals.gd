extends RefCounted

const CATALOG_REVISION := 2

static func level_bonus(player_level: int) -> int:
	var step := maxi(1, int(Data.RULES.get("hot_level_step", 8)))
	return mini(maxi(0, player_level / step), maxi(0, int(Data.RULES.get("hot_level_max_bonus", 2))))

static func grade_floor(base: Array, slot: int, player_level: int) -> int:
	return Data.lv(str(base[slot]["id"])) + level_bonus(player_level)

static func goods_pool(tier: int, player_level: int) -> Array:
	var out: Array = []
	for line in Data.unlocked_lines(player_level):
		for field in ["main", "sub"]:
			var chain_id := str(line.get(field, ""))
			if chain_id == "" or not Data.product_open(player_level, chain_id) or tier > Data.max_lv(chain_id): continue
			var id := "%s_%d" % [chain_id, tier]
			if _is_goods(id): out.append(id)
	return out

static func available_goods(id: String, player_level: int) -> bool:
	return _is_goods(id) and goods_pool(Data.lv(id), player_level).has(id)

static func _row(base: Dictionary, id: String) -> Dictionary:
	var row := base.duplicate(true)
	row["id"] = id
	if not bool(row.get("random_generator", false)): row["price"] = price_of(id)
	return row

static func from_picks(base: Array, picks: Array, player_level: int) -> Array:
	var out: Array = []
	for k in base.size():
		var id := str(base[k]["id"])
		if not bool(base[k].get("random_generator", false)):
			var pool := goods_pool(grade_floor(base, k, player_level), player_level)
			if not pool.is_empty(): id = str(pool[0])
		out.append(_row(base[k], id))
	var fallback := out.duplicate(true)
	for pick in picks:
		if not pick is Dictionary: continue
		var slot := int(pick.get("slot", -1))
		var id := str(pick.get("id", ""))
		if slot < 0 or slot >= out.size(): continue
		if bool(base[slot].get("random_generator", false)):
			if generator_components(player_level).has(id): out[slot] = _row(base[slot], id)
		else:
			var floor_level := grade_floor(base, slot, player_level)
			if available_goods(id, player_level) and Data.lv(id) >= floor_level and Data.lv(id) <= floor_level + 1: out[slot] = _row(base[slot], id)
	return out if valid_rows(out, base, player_level) else fallback

static func roll(base: Array, wanted: Array, rng: RandomNumberGenerator, player_level: int, previous: Array = []) -> Array:
	var count := base.size() - 1
	var omit := rng.randi_range(0, count)
	if previous.size() == base.size():
		var same_grades := true
		for k in count:
			var tier := grade_floor(base, k, player_level) + (1 if k >= omit else 0)
			same_grades = same_grades and Data.lv(str(previous[k]["id"])) == tier
		if same_grades: omit = (omit + rng.randi_range(1, count)) % (count + 1)
	var out: Array = []
	var used_chains := {}
	for k in base.size():
		var old := str(previous[k]["id"]) if k < previous.size() else ""
		if bool(base[k].get("random_generator", false)):
			out.append(_row(base[k], random_component(rng, player_level, old)))
			continue
		var tier := grade_floor(base, k, player_level) + (1 if k >= omit else 0)
		var pool := goods_pool(tier, player_level)
		if pool.size() > 1: pool.erase(old)
		var id := _weighted_goods(pool, wanted, used_chains, rng)
		used_chains[Data.chain(id)] = true
		out.append(_row(base[k], id))
	return out

static func _weighted_goods(pool: Array, wanted: Array, used_chains: Dictionary, rng: RandomNumberGenerator) -> String:
	if pool.is_empty(): return ""
	var weights: Array = []
	var total := 0.0
	for id in pool:
		var weight := 1.0 if used_chains.has(Data.chain(str(id))) else 2.0
		for need in wanted:
			if Data.chain(str(need)) != Data.chain(str(id)): continue
			var gap := Data.lv(str(need)) - Data.lv(str(id))
			if gap == 1: weight *= 5.0; break
			if gap == 2: weight *= 3.0; break
		weights.append(weight); total += weight
	var point := rng.randf() * total
	for i in pool.size():
		point -= float(weights[i])
		if point <= 0.0: return str(pool[i])
	return str(pool.back())

static func valid_rows(rows: Array, base: Array, player_level: int) -> bool:
	if rows.size() != base.size(): return false
	var previous_level := 0
	for k in rows.size():
		var row: Variant = rows[k]
		if not row is Dictionary: return false
		var id := str(row.get("id", ""))
		if bool(base[k].get("random_generator", false)):
			if not generator_components(player_level).has(id) or int(row.get("price", -1)) != int(base[k]["price"]): return false
		else:
			var tier := Data.lv(id)
			var minimum := grade_floor(base, k, player_level)
			if not available_goods(id, player_level) or tier <= previous_level or tier < minimum or tier > minimum + 1 or int(row.get("price", -1)) != price_of(id): return false
			previous_level = tier
		if int(row.get("stock", -1)) != int(base[k]["stock"]): return false
	return true

static func generator_components(player_level: int) -> Array:
	var out: Array = []
	for line in Data.unlocked_lines(player_level):
		var id := "%s_1" % str(line["gen"])
		if Data.is_board_item(id): out.append(id)
	return out

static func random_component(rng: RandomNumberGenerator, player_level: int, previous := "") -> String:
	var pool := generator_components(player_level)
	if pool.size() > 1: pool.erase(previous)
	return str(pool[rng.randi_range(0, pool.size() - 1)]) if not pool.is_empty() else ""

static func price_of(id: String) -> int:
	return PriceBook.price(id)

static func _is_goods(id: String) -> bool:
	if id == "" or Data.is_dish(id): return false
	var chain_id := Data.chain(id)
	return Data.CHAINS.has(chain_id) and str(Data.CHAINS[chain_id].get("type", "")) == "item"

static func _base_sig() -> String:
	return "%s:%d:%d:%d" % [str(JSON.stringify(Data.STORE_HOT).hash()) + str(PriceBook.catalog.get("rules_version", "")), CATALOG_REVISION, int(Data.RULES.get("hot_level_step", 8)), int(Data.RULES.get("hot_level_max_bonus", 2))]
