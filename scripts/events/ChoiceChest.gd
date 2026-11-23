class_name ChoiceChest
extends RefCounted
## 自选宝箱点开时随机三件产线物品。宝箱等级就是物品等级；掉率低于 20 的低一级，低于 5 的再低一级。
## 抽到的三件记在格子的 offer 上，关掉再打开还是这三件，合成或丢弃后才重新抽。
const RARE_WEIGHT := 20
const SCARCE_WEIGHT := 5

static func definition(id: String) -> Dictionary:
	return Data.ConfigFiles.shared("res://data/choice_chests.json").get(id, {})

static func item_level(grade: int, chain_id: String) -> int:
	var level := grade
	var weight := drop_weight(chain_id)
	if weight < RARE_WEIGHT: level -= 1
	if weight < SCARCE_WEIGHT: level -= 1
	return clampi(level, 1, maxi(1, Data.max_lv(chain_id)))

static func candidates(box_id: String) -> Array:
	var grade := Data.lv(box_id)
	var out: Array = []
	for chain_id in _product_chains():
		out.append("%s_%d" % [chain_id, item_level(grade, chain_id)])
	return out

static func offer(cell: int) -> Dictionary:
	if G.replay_input(): return Replay.perform("choice_offer", {"cell": cell})
	var box_id := ""
	if cell >= 0 and cell < G.board.size(): box_id = str(G.board[cell].get("id", ""))
	return _ensure(cell, box_id)

static func choose(cell: int, box_id: String, option: int) -> Dictionary:
	if G.replay_input(): return Replay.perform("choice", {"cell": cell, "option": option})
	var ready := _ensure(cell, box_id)
	if ready.has("error"): return ready
	var choices: Array = ready["choices"]
	if option < 0 or option >= choices.size(): return {"error": TextCatalog.source("notice.choicechest.1ee417b396d7")}
	var id := str(choices[option])
	G.board[cell]["id"] = ""
	G.board[cell].erase("offer")
	Rewards.settle(Rewards.items([id]), {"board_origin": cell})
	G.dirty()
	return {"id": id}

static func drop_weight(chain_id: String) -> int:
	var best := 0
	for row in Data.CHAINS.values():
		var slots: Variant = row.get("prod", [])
		if not slots is Array: continue
		for slot in slots:
			if not slot is Dictionary: continue
			var drops: Variant = slot.get("drops", [])
			if not drops is Array: continue
			for drop in drops:
				if not drop is Dictionary: continue
				if Data.chain(str(drop.get("id", ""))) != chain_id: continue
				best = maxi(best, int(drop.get("p", 0)))
	return best

static func _product_chains() -> Array:
	var out: Array = []
	var seen := {}
	for line in Data.LINES:
		for chain_id in Data.products(line):
			if seen.has(chain_id): continue
			if str(Data.CHAINS.get(chain_id, {}).get("type", "")) != "item": continue
			if Data.max_lv(chain_id) < 1: continue
			seen[chain_id] = true
			out.append(chain_id)
	return out

static func _roll(box_id: String) -> Array:
	var grade := Data.lv(box_id)
	var open := {}
	for line in Data.unlocked_lines(G.level):
		for chain_id in Data.products(line):
			open[chain_id] = true
	var first: Array = []
	var later: Array = []
	for chain_id in _product_chains():
		if open.has(chain_id): first.append(chain_id)
		else: later.append(chain_id)
	var rng := G.random_for("choice_chests")
	_shuffle(first, rng)
	_shuffle(later, rng)
	var out: Array = []
	for chain_id in first + later:
		if out.size() >= 3: break
		out.append("%s_%d" % [chain_id, item_level(grade, chain_id)])
	return out

static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for index in range(items.size() - 1, 0, -1):
		var swap := rng.randi_range(0, index)
		var held = items[index]
		items[index] = items[swap]
		items[swap] = held

static func _stored_offer(cell: int) -> Array:
	var raw: Variant = G.board[cell].get("offer")
	if not raw is Array or raw.size() != 3: return []
	var seen := {}
	for item in raw:
		var id := str(item)
		if not Data.is_board_item(id) or Data.type_of(id) != "item" or seen.has(Data.chain(id)): return []
		seen[Data.chain(id)] = true
	return raw

static func _ensure(cell: int, box_id: String) -> Dictionary:
	if cell < 0 or cell >= G.board.size() or G.rules.board.cell_id(cell) != box_id or Data.type_of(box_id) != "choice" or int(G.board[cell].get("lock", 0)) != 0 or G.rules.board.is_merge_bubble(cell):
		return {"error": TextCatalog.source("notice.boardrules.d50c3a1211d1")}
	var stored := _stored_offer(cell)
	if not stored.is_empty(): return {"choices": stored}
	var choices := _roll(box_id)
	if choices.size() != 3: return {"error": TextCatalog.source("notice.choicechest.1ee417b396d7")}
	G.board[cell]["offer"] = choices
	G.dirty()
	return {"choices": choices}
