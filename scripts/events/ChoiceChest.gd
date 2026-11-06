class_name ChoiceChest
extends RefCounted
static var _config: Dictionary = {}
static var busy := false
static func definition(id: String) -> Dictionary:
	if _config.is_empty():
		var raw = JSON.parse_string(FileAccess.get_file_as_string("res://data/choice_chests.json"))
		if raw is Dictionary: _config = raw
	return _config.get(id, {})
static func choose(cell: int, box_id: String, option: int) -> Dictionary:
	if busy: return {"error": ""}
	var c := definition(box_id)
	var choices: Array = c.get("choices", [])
	if cell < 0 or cell >= G.board.size() or G.cell_id(cell) != box_id or int(G.board[cell]["lock"]) != 0 or G.is_merge_bubble(cell): return {"error": "宝箱已不在原位置"}
	if choices.size() != 3 or option < 0 or option >= 3: return {"error": "宝箱配置无效"}
	var id := str(choices[option])
	busy = true
	if G.server_mode():
		var r: Dictionary = await G._cloud().act("/v1/chest/choose", {"box": box_id, "option": option})
		if not r.get("ok", false):
			busy = false
			return {"error": str(r.get("message", "打开失败"))}
	# Reward replaces the consumed chest in its exact cell, even with a full board.
	if G.cell_id(cell) == box_id:
		G.board[cell]["id"] = ""
		Rewards.grant(Rewards.items([id]), Callable(), false, true, {"board_origin": cell})
	else:
		Rewards.grant([[id, 1, "physical"]], Callable(), false)
	G.discover(id)
	G.dirty()
	G.save_game()
	G.board_changed.emit()
	busy = false
	return {"id": id}
