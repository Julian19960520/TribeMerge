class_name Rewards
extends RefCounted
## Business-only reward settlement. Interfaces display committed rewards separately.
const RESOURCE_TYPES := ["energy", "shell", "amber", "sand"]

static func kind(id: String) -> String:
	return Data.type_of(id) if Data.is_known(id) else ""

static func is_resource(id: String) -> bool:
	return kind(id) in RESOURCE_TYPES

static func unit(id: String) -> String:
	return str({"energy": "点体力", "shell": "个不拿拿", "amber": "个琥珀", "sand": "个沙漏"}.get(kind(id), ""))

## 卡册 8 级才开：之前任何地方发的卡包（七日、通行证、礼包…）都换成藤编宝箱，暂存区里不会出现点不开的卡包。
static func before_cards(id: String) -> String:
	if G.rules == null or not Data.is_known(id) or Data.type_of(id) != "pack":
		return id
	return id if G.rules.progression.feature_unlocked(Data.CARD_LEVEL) else "chest_1"

static func items(ids: Array) -> Array:
	var out: Array = []
	for id in ids:
		if str(id) != "": out.append([str(id), 1, "item"])
	return out

static func settle(rewards: Array, delivery: Dictionary = {}) -> Dictionary:
	var report := {"placements": [], "overflow": 0, "leveled": false, "pack_count": 0}
	var origin := int(delivery.get("board_origin", -1))
	for reward in rewards:
		if not reward is Array or reward.size() < 2: continue
		var id := before_cards(str(reward[0]))
		var amount := int(reward[1])
		var type := kind(id)
		if amount <= 0 or type == "": continue
		var physical: bool = reward.size() > 2 and str(reward[2]) in ["item", "physical"]
		if Data.is_numeric_resource(id): physical = false
		if physical and str(reward[2]) == "item" and origin < 0 and type in RESOURCE_TYPES and Data.value_of(id) > 0:
			amount *= Data.value_of(id)
			physical = false
		if not physical and type in RESOURCE_TYPES:
			G.rules.progression.add_currency(type, amount)
		elif not physical and type == "xp":
			report["leveled"] = G.rules.progression.add_xp(amount) or report["leveled"]
		elif not physical and type == "token":
			report["pack_count"] += G.rules.progression.add_tokens(amount)
		else:
			for _index in amount:
				var to := G.rules.board.find_empty_near(origin) if origin >= 0 else -1
				if to >= 0:
					G.rules.board.discover(id)
					G.board[to]["id"] = id
					report["placements"].append({"origin": origin, "to": to, "id": id})
					G.present("board_spawn", {"origin": origin, "to": to, "id": id})
				else:
					G.stash.append(id)
					if origin >= 0: report["overflow"] += 1
	if int(report["pack_count"]) > 0:
		for _index in int(report["pack_count"]): G.stash.append(before_cards("pack_1"))
		G.present("packs_earned", {"count": report["pack_count"]})
	if int(report["overflow"]) > 0: G.present("overflow", {"count": report["overflow"]})
	if bool(report["leveled"]): G.present("level_up", {})
	G.dirty()
	return report

static func for_order(o: Dictionary) -> Array:
	var rw: Dictionary = o.get("rw", {})
	var out := []
	for pair in [["shell", "shell_2"], ["xp", "xp_1"], ["token", "token_1"]]:
		if int(rw.get(pair[0], 0)) > 0: out.append([pair[1], int(rw[pair[0]])])
	if rw.get("rewards") is Array and not rw["rewards"].is_empty(): out.append_array(Rewards.items(rw["rewards"]))
	elif int(rw.get("pack", 0)) > 0: out.append(["pack_1", int(rw["pack"])])
	return out
