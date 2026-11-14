class_name ChoiceChest
extends RefCounted
static func definition(id: String) -> Dictionary:
	return Data.ConfigFiles.shared("res://data/choice_chests.json").get(id, {})

static func choose(cell: int, box_id: String, option: int) -> Dictionary:
	if G.replay_input(): return Replay.perform("choice", {"cell": cell, "option": option})
	var choices: Array = definition(box_id).get("choices", [])
	if cell < 0 or cell >= G.board.size() or G.rules.board.cell_id(cell) != box_id or int(G.board[cell]["lock"]) != 0 or G.rules.board.is_merge_bubble(cell): return {"error": TextCatalog.source("notice.boardrules.d50c3a1211d1")}
	if option < 0 or option >= choices.size(): return {"error": TextCatalog.source("notice.choicechest.1ee417b396d7")}
	var id := str(choices[option])
	G.board[cell]["id"] = ""
	Rewards.settle(Rewards.items([id]), {"board_origin": cell})
	G.dirty()
	return {"id": id}
