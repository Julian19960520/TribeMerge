class_name FossilDig
extends RefCounted
## The same reducer runs in the client and in the headless v2 replay worker.
## Layout hashes use their own seed and never consume another system's random stream.

static func config() -> Dictionary:
	return Data.ConfigFiles.shared("res://data/fossil_dig.json")

static func unlocked() -> bool:
	return G.gm_activities or G.level >= int(config()["unlock_level"])

static func state() -> Dictionary:
	return G.fossil_dig

static func board() -> Dictionary:
	return state().get("board", {})

static func cleared(b: Dictionary = {}) -> bool:
	if b.is_empty(): b = board()
	return not b.is_empty() and b.get("pieces", []).all(func(p): return bool(p.get("found", false)))

static func finished() -> bool:
	return int(state().get("stage", 1)) >= int(config()["stages"]) and cleared()

static func earning() -> bool:
	return unlocked() and not finished()

static func ready_rewards() -> Array:
	var s := state()
	return config()["milestones"].filter(func(row): return int(s.get("recovered", 0)) >= int(row["bones"]) and not int(row["bones"]) in s.get("claimed", []))

static func piece_cells(piece: Dictionary, n: int) -> Array:
	var cells := []
	for y in int(piece["h"]):
		for x in int(piece["w"]): cells.append((int(piece["y"]) + y) * n + int(piece["x"]) + x)
	return cells

static func make_board(seed: String, stage: int) -> Dictionary:
	var n := stage + 2
	var shapes: Array = config()["shapes"]
	var pool := mini(shapes.size(), stage + 1)
	var specs: Array = []
	for i in stage + 1:
		var piece: Dictionary = shapes[i % pool].duplicate(true)
		piece["id"] = i
		piece["found"] = false
		specs.append(piece)
	specs.sort_custom(func(a, b):
		var aa := int(a["w"]) * int(a["h"])
		var ba := int(b["w"]) * int(b["h"])
		return aa > ba if aa != ba else int(a["id"]) < int(b["id"]))
	for attempt in 64:
		var occupied := {}
		var pieces: Array = []
		for spec in specs:
			var best: Dictionary = {}
			var rank := ""
			for turn in (1 if spec["w"] == spec["h"] else 2):
				var w := int(spec["w"] if turn == 0 else spec["h"])
				var h := int(spec["h"] if turn == 0 else spec["w"])
				for y in range(n - h + 1):
					for x in range(n - w + 1):
						var candidate: Dictionary = spec.duplicate(true)
						candidate.merge({"w": w, "h": h, "x": x, "y": y, "turn": turn}, true)
						var cells := piece_cells(candidate, n)
						if cells.any(func(cell): return occupied.has(cell)): continue
						var hash_rank := ("%s:%d:%d:%d:%d:%d" % [seed, stage, attempt, int(spec["id"]), turn, y * n + x]).sha256_text()
						if rank == "" or hash_rank < rank:
							rank = hash_rank
							best = candidate
			if best.is_empty(): break
			pieces.append(best)
			for cell in piece_cells(best, n): occupied[cell] = true
		if pieces.size() == specs.size():
			pieces.sort_custom(func(a, b): return int(a["id"]) < int(b["id"]))
			return {"n": n, "pieces": pieces, "dug": []}
	return {}

static func initialize() -> void:
	if not G.fossil_dig.is_empty(): return
	var seed := ((G.random_seed if G.random_seed != "" else G.player_id) + ":fossil").sha256_text().substr(0, 16)
	G.fossil_dig = {"seed": seed, "stage": 1, "shovels": 0, "earned": 0, "spent": 0, "recovered": 0, "claimed": [], "board": make_board(seed, 1)}

static func on_order(_order: Dictionary) -> void:
	if not earning(): return
	initialize()
	var amount := int(config()["shovels_per_order"])
	G.fossil_dig["shovels"] = int(G.fossil_dig["shovels"]) + amount
	G.fossil_dig["earned"] = int(G.fossil_dig["earned"]) + amount
	G.dirty()

static func local_action(action: String, value := -1) -> Dictionary:
	if not unlocked(): return {"error": "%d级解锁恐龙化石" % int(config()["unlock_level"])}
	if not action in ["refresh", "dig", "next", "claim"]: return {"error": "未知操作"}
	initialize()
	var s := state()
	var b := board()
	if action == "refresh": return {}
	if action == "dig":
		var n := int(b["n"])
		if value < 0 or value >= n * n: return {"error": "请选择挖掘区内的格子"}
		if value in b["dug"]: return {"error": "这里已经挖开了"}
		if cleared(b): return {"error": "本关已完成"}
		var cost := int(config()["dig_cost"])
		if int(s["shovels"]) < cost: return {"error": "铲子不足，完成主棋盘订单获得铲子"}
		s["shovels"] = int(s["shovels"]) - cost
		s["spent"] = int(s["spent"]) + cost
		b["dug"].append(value)
		var found: Array = []
		for piece in b["pieces"]:
			if piece["found"] or not value in piece_cells(piece, n): continue
			if piece_cells(piece, n).all(func(cell): return cell in b["dug"]):
				piece["found"] = true
				s["recovered"] = int(s["recovered"]) + 1
				found.append(piece.duplicate(true))
		return {"cell": value, "found": found, "complete": cleared(b)}
	if action == "next":
		if not cleared(b): return {"error": "挖出本关全部骨头后解锁下一关"}
		if finished(): return {"error": "全部挖掘已完成"}
		var next_stage := int(s["stage"]) + 1
		var next_board := make_board(str(s["seed"]), next_stage)
		if next_board.is_empty(): return {"error": "挖掘区生成失败"}
		s["stage"] = next_stage
		s["board"] = next_board
		return {}
	for row in config()["milestones"]:
		if int(row["bones"]) != value: continue
		if value > int(s["recovered"]) or value in s["claimed"]: return {"error": "奖励尚未解锁或已经领取"}
		s["claimed"].append(value)
		return {"rewards": row["rewards"].duplicate(true)}
	return {"error": "奖励不存在"}

static func act(action: String, value := -1) -> Dictionary:
	if G.replay_input(): return Replay.perform("fossil", {"action": action, "value": value})
	var result := local_action(action, value)
	if not result.has("error"):
		Rewards.settle(result.get("rewards", []))
	return result
