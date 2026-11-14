extends "res://scripts/domain/RuleModule.gd"
## One saved lifetime and refill clock, including time spent in the reward queue.
const META := "starter_generator"

func config() -> Dictionary:
	return Data.RULES.get("starter_generator", {})

func is_item(id: String) -> bool:
	return id != "" and id == str(config().get("item", ""))

func progress() -> Dictionary:
	return context.meta().get(META, {})

func grant() -> void:
	if not progress().is_empty(): return
	var start: float = context.now()
	context.meta()[META] = {"started_at": start, "expires_at": start + float(config()["lifetime_sec"]), "cycle": 0, "used": 0}
	state.dirty()

func _period() -> float:
	return float(Data.gen_stats(str(config()["item"]))["refill"]) * 60.0

func _cycle() -> int:
	return maxi(0, int(floor((context.now() - float(progress()["started_at"])) / _period())))

func expired() -> bool:
	return not progress().is_empty() and context.now() >= float(progress()["expires_at"])

func time_left() -> int:
	return maxi(0, int(ceil(float(progress().get("expires_at", context.now())) - context.now())))

func left() -> int:
	if expired(): return 0
	var cap := int(Data.gen_stats(str(config()["item"]))["charges"])
	if progress().is_empty() or int(progress()["cycle"]) != _cycle(): return cap
	return maxi(0, cap - int(progress()["used"]))

func wait() -> int:
	if progress().is_empty() or expired() or left() > 0: return 0
	return maxi(1, int(ceil(float(progress()["started_at"]) + float(_cycle() + 1) * _period() - context.now())))

func use() -> void:
	if progress().is_empty(): grant()
	tick()
	progress()["used"] = int(progress()["used"]) + 1
	state.dirty()

func tick() -> void:
	if config().is_empty() or state.level < int(config()["reward_level"]): return
	if progress().is_empty():
		var owned: bool = state.stash.has(str(config()["item"])) or state.inv.has(str(config()["item"]))
		if not owned:
			for cell in state.board:
				if is_item(str(cell["id"])): owned = true; break
		# Restore the producer for active beginners whose old one-shot lesson consumed it.
		var consumed: bool = state.tutorial_on and bool(context.onboarding.progress().get("energy_gift", false))
		if not owned and not consumed: return
		grant()
		if consumed and not owned: context.board.stash_push(str(config()["item"]))
	if expired():
		if bool(progress().get("expired", false)): return
		for cell in state.board:
			if is_item(str(cell["id"])):
				cell["id"] = ""
				cell.erase("gm")
		state.stash = state.stash.filter(func(id): return not is_item(str(id)))
		var kept: Array = []
		var chests := {}
		for i in state.inv.size():
			if is_item(str(state.inv[i])): continue
			if state.inv_chests.has(str(i)): chests[str(kept.size())] = state.inv_chests[str(i)]
			kept.append(state.inv[i])
		state.inv = kept
		state.inv_chests = chests
		progress()["expired"] = true
		state.dirty()
		state.board_changed.emit()
		return
	var cycle := _cycle()
	if int(progress()["cycle"]) != cycle:
		progress()["cycle"] = cycle
		progress()["used"] = 0
		state.dirty()
		state.board_changed.emit()
